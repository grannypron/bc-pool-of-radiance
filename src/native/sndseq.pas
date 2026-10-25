{ The native build's sound sequencer: sounddrv.asm and its speaker and Tandy parts (sndspk.inc, sndtdy.inc) in Pascal,
  whose routines SoundDrv forwards to. The tunes are the assembly's own bytes: tools/snd2pas.py assembles them into an
  image of the driver's segment (SNDIMAGE.INC, in obj), and the sequencer steps the streams and keeps the voice blocks
  in that image as the assembly does in its segment, so the streams' pointers and field offsets work unchanged. Each
  routine follows its assembly line by line, registers as variables, 16-bit arithmetic wrapping as the 8086's does.

  The port writes go to PortWrite (SndChip's speaker and SN76489 emulation, which SdlSound sets up), or, once
  SetTraceBuffer has been called, into its buffer, as the TASM trace build's do: tests/sndtrc.pas forwards to the trace
  entries here, so TSndSeq checks this sequencer against the record taken from SSI's.

  The timer interrupt is Tick, which the sound output runs 236.7 times a second of sound (SndChip.Render); it runs only
  while InstallSoundTimer has the timer "hooked". With no sound output (Rendered False: no audio device, or the tests),
  SoundTimerTicks and SoundVoiceTune run the ticks the clock owes instead, so the game's waits and its music's end still
  come. The output runs on its own thread: Lock and Unlock (SdlSound's) keep a tick out of the entries, as seqBusy does
  on DOS. Objfpc mode for the procedure variables' nil. Free Pascal only. }
{$MODE OBJFPC}
{$H-}
{$R-}
{$Q-}
unit SndSeq;

interface

type
  TPortWrite = procedure(port, value: Byte);
  TLockProc = procedure;

var
  { where the sequencer's port writes go outside a trace (SndChip.Write); nil drops them }
  PortWrite: TPortWrite;
  { serialise the entries with Tick on the output's thread (SdlSound's stream lock); nil when there is no thread }
  Lock: TLockProc;
  Unlock: TLockProc;
  { True while a sound output runs Tick; False runs the ticks the clock owes when SoundTimerTicks is read }
  Rendered: Boolean;

procedure InstallSoundTimer;
procedure UninstallSoundTimer;
procedure ProgramSpeakerVoices(tuneId: Word);
procedure ProgramTandyVoices(tuneId: Word);
procedure OplWrite(reg, value: Word);
procedure OplReset;
procedure SetSoundOutputEnabled(enabledValue: Word);
function SoundTimerTicks: Word;
function SoundTimerHooked: Boolean;
procedure SetSoundDevice(mode: Word);
function SoundVoiceTune(voice: Word): Word;

{ The timer interrupt, for the sound output: count the tick and, while the timer is hooked, run the device's tick. }
procedure Tick;

{ The trace build's entries (SndTrc): record the port writes into buf, capacity words (the port high, the value low),
  from its start, instead of sending them to PortWrite; the words recorded; one tick's sequencing on demand. }
procedure SetTraceBuffer(buf: Pointer; capacity: Word);
function TraceCount: Word;
procedure TraceTick;

implementation

uses SysUtils, C_SOUND;

{$I SNDIMAGE.INC}

const
  { device values, as C_SOUND's MODE_TANDY, MODE_SPEAKER, MODE_DISABLED and MODE_ADLIB }
  DEV_TANDY = 0;
  DEV_SPEAKER = 1;
  DEV_NONE = 2;
  DEV_ADLIB = 3;
  { the voices a device steps }
  VOICES = 4;
  { SSET's field 0 is vfDuration: SWAIT }
  FIELD_DURATION = 0;
  { the envelope's release: its 5th (value, ticks) pair }
  ENV_RELEASE = $10;
  { stream bytes 0FAh and up are commands }
  CMD_FIRST = $FA;
  CMD_RESET = $FA;
  CMD_RET = $FB;
  CMD_CALL = $FC;
  CMD_CLEAR = $FD;
  CMD_LOOP = $FE;
  CMD_SET = $FF;
  LAST_FLAG = $80;
  PITCH_MASK = $7F;
  { the SN76489's latch bytes: full attenuation on each voice }
  TANDY_SILENCE: array[0..3] of Byte = ($9F, $BF, $DF, $FF);

var
  { the driver's segment: the image at SND_ORG, the rest zero }
  mem: array[0..65535] of Byte;
  { the driver's variables, as sounddrv.asm names them }
  voiceLeft: Byte;
  curTune: Word;
  seqVoice: Word;
  voiceBase: Word;
  freqBase: Word;
  seqRet: Word;
  voiceTune: array[0..VOICES - 1] of Byte;
  outputOn: Byte;
  device: Byte;
  spkrVoice: Word;
  hooked: Boolean;
  drvTicks: Word;
  seqBusy: Boolean;
  { the speaker gate's state, as port 61h reads back }
  gate: Byte;
  { the trace: its buffer, capacity and length, and whether one is set }
  traceBuf: ^Word;
  traceCap: Word;
  traceLen: Word;
  tracing: Boolean;
  { the clock's ticks: when the timer was hooked, in ms, and the ticks run since }
  clockStart: QWord;
  clockRun: QWord;

function W(a: Word): Word; inline;
begin
  W := mem[a] or (Word(mem[Word(a + 1)]) shl 8);
end;

procedure SetW(a, v: Word); inline;
begin
  mem[a] := Lo(v);
  mem[Word(a + 1)] := Hi(v);
end;

procedure EnterSeq;
begin
  if Assigned(Lock) then
    Lock;
end;

procedure LeaveSeq;
begin
  if Assigned(Unlock) then
    Unlock;
end;

{ PORT_OUT: the trace's buffer, or the chips }
procedure PortOut(port, value: Byte);
begin
  if tracing then begin
    if traceLen < traceCap then begin
      traceBuf[traceLen] := (Word(port) shl 8) or value;
      Inc(traceLen);
    end;
  end else begin
    if port = C_SOUND.PORT_GATE then
      gate := value;
    if Assigned(PortWrite) then
      PortWrite(port, value);
  end;
end;

{ PORT_IN 61h: the trace build reads 0 }
function GateIn: Byte;
begin
  if tracing then
    GateIn := 0
  else
    GateIn := gate;
end;

{ seq_end: store the stream pointer, or end the voice when its duration is 0. si is the voice seq_proc started on. }
procedure SeqEnd(var si: Word; di: Word);
begin
  si := seqVoice;
  if W(si + VF_DURATION) = 0 then begin
    voiceTune[(VOICES - voiceLeft) and (VOICES - 1)] := 0;
    di := 0;
  end;
  SetW(si + VF_STREAM, di);
end;

{ seq_proc: run this voice's stream until it yields. }
procedure SeqProc(var si: Word);
var
  di: Word;
  bl: Byte;
  bx: Word;
  ax: Word;
  cx: Word;
  cl: Byte;
  target: Word;
  borrow: Boolean;
begin
  di := W(si + VF_STREAM);
  if di = 0 then
    Exit;
  seqVoice := si;
  while True do begin
    bl := mem[di];
    Inc(di);
    if bl < CMD_FIRST then begin
      { seq_note: records back to back until one carries the last flag }
      while True do begin
        target := Word(Word(bl shr 5) * VOICE_SIZE + voiceBase);
        bx := di;
        ax := W(si + VF_TEMPO);
        if Lo(ax) > 1 then
          ax := Word(Lo(ax) * mem[Word(bx + 1)])
        else
          ax := mem[Word(bx + 1)];
        SetW(si + VF_DURATION, ax);
        ax := mem[bx] and PITCH_MASK;
        if ax <> REST then begin
          cx := W(si + VF_DURATION);
          SetW(target + VF_DURATION, cx);
          { the release starts that many ticks early; a lead longer than the note gives none }
          if cx >= W(target + VF_RELEASE_LEAD) then
            cx := Word(cx - W(target + VF_RELEASE_LEAD))
          else
            cx := 0;
          SetW(target + VF_GATE_LEN, cx);
          ax := Word(ax + W(target + VF_TRANSPOSE));
          SetW(target + VF_ENV_POS, 0);
          SetW(target + VF_ENV_WAIT, 1);
          { CL = octave, AX = semitone }
          cl := $FF;
          repeat
            cl := Byte(cl + 1);
            borrow := ax < OCT;
            ax := Word(ax - OCT);
          until borrow;
          ax := Word(ax + OCT);
          ax := W(Word(freqBase + Word(ax + ax)));
          { the 386's shift: the count taken modulo 32, and a word shifted 16 or more is 0 }
          if cl and 31 >= 16 then
            ax := 0
          else
            ax := ax shr (cl and 31);
          SetW(target + VF_PERIOD, ax);
          SetW(target + VF_OUT_PERIOD, ax);
        end;
        { sn_tail }
        di := bx;
        bl := mem[di];
        di := Word(di + 2);
        if bl and LAST_FLAG <> 0 then begin
          SeqEnd(si, di);
          Exit;
        end;
        bl := mem[di];
        Inc(di);
      end;
    end;
    case bl of
      CMD_LOOP: begin
        bx := mem[di];
        Inc(di);
        ax := W(di);
        di := Word(di + 2);
        if W(Word(bx + si)) = 0 then
          di := ax
        else begin
          SetW(Word(bx + si), Word(W(Word(bx + si)) - 1));
          if W(Word(bx + si)) <> 0 then
            di := ax;
        end;
      end;
      CMD_CLEAR, CMD_RESET: begin
        if bl = CMD_CLEAR then begin
          si := Word(W(di) + voiceBase);
          di := Word(di + 2);
        end;
        { vfDuration, vfStream, vfTempo, vfGateLen and both loop counters survive a reset }
        SetW(si + VF_PERIOD, 0);
        SetW(si + VF_PERIOD_ADD, 0);
        SetW(si + VF_OUT_PERIOD, 0);
        SetW(si + VF_LEVEL, 0);
        SetW(si + VF_LEVEL_ADD, 0);
        SetW(si + VF_RELEASE_LEAD, 0);
        SetW(si + VF_TRANSPOSE, 0);
        SetW(si + VF_ENV_BASE, 0);
        SetW(si + VF_ENV_POS, 0);
        SetW(si + VF_ENV_WAIT, 0);
        SetW(si + VF_LFO_TABLE, 0);
        SetW(si + VF_LFO_PHASE, 0);
        SetW(si + VF_LFO_RATE, 0);
        SetW(si + VF_LFO_DEPTH, 0);
        SetW(si + VF_LFO_WRAP, 0);
      end;
      CMD_SET: begin
        bx := mem[di];
        Inc(di);
        ax := W(di);
        di := Word(di + 2);
        SetW(Word(bx + si), ax);
        { a SWAIT always yields }
        if bx = FIELD_DURATION then begin
          SeqEnd(si, di);
          Exit;
        end;
      end;
      CMD_RET: begin
        di := seqRet;
        seqRet := 0;
        { nothing to return to: end the voice rather than run from a stale pointer }
        if di = 0 then begin
          si := seqVoice;
          SetW(si + VF_DURATION, 0);
          SeqEnd(si, di);
          Exit;
        end;
      end;
      CMD_CALL: begin
        ax := W(di);
        di := Word(di + 2);
        seqRet := di;
        di := ax;
      end;
    end;
  end;
end;

{ voice_step: one tick of one voice. }
procedure VoiceStep(var si: Word);
var
  ax: Word;
  dx: Word;
  bx: Word;
  product: LongInt;
begin
  SetW(si + VF_LEVEL, Word(W(si + VF_LEVEL) + W(si + VF_LEVEL_ADD)));
  SetW(si + VF_PERIOD, Word(W(si + VF_PERIOD) + W(si + VF_PERIOD_ADD)));
  dx := 0;
  ax := Word(W(si + VF_LFO_PHASE) + W(si + VF_LFO_RATE));
  if ax <> 0 then begin
    if ax >= W(si + VF_LFO_WRAP) then
      ax := Word(ax - W(si + VF_LFO_WRAP));
    SetW(si + VF_LFO_PHASE, ax);
    { phase >> 4 (arithmetic) indexes the waveform; the sample in AH times the depth leaves the pitch's share in DX }
    ax := Word(Word(SarSmallint(SmallInt(ax), 4)) + W(si + VF_LFO_TABLE));
    product := LongInt(SmallInt(Word(mem[ax]) shl 8)) * SmallInt(W(si + VF_LFO_DEPTH));
    dx := Word(LongWord(product) shr 16);
  end;
  SetW(si + VF_OUT_PERIOD, Word(dx + W(si + VF_PERIOD)));
  if W(si + VF_GATE_LEN) <> 0 then begin
    SetW(si + VF_GATE_LEN, Word(W(si + VF_GATE_LEN) - 1));
    if W(si + VF_GATE_LEN) = 0 then begin
      SetW(si + VF_ENV_POS, ENV_RELEASE);
      SetW(si + VF_ENV_WAIT, 1);
    end;
  end;
  SetW(si + VF_DURATION, Word(W(si + VF_DURATION) - 1));
  if W(si + VF_DURATION) = 0 then
    SeqProc(si);
  if W(si + VF_ENV_WAIT) <> 0 then begin
    SetW(si + VF_ENV_WAIT, Word(W(si + VF_ENV_WAIT) - 1));
    if W(si + VF_ENV_WAIT) = 0 then begin
      while True do begin
        bx := Word(W(si + VF_ENV_BASE) + W(si + VF_ENV_POS));
        if W(Word(bx + 2)) <> ENV_SETLEVEL then
          Break;
        ax := W(bx);
        SetW(si + VF_LEVEL, ax);
        { a zero level stops the slide with it }
        if ax = 0 then
          SetW(si + VF_LEVEL_ADD, 0);
        SetW(si + VF_ENV_POS, Word(W(si + VF_ENV_POS) + 4));
      end;
      SetW(si + VF_LEVEL_ADD, W(bx));
      SetW(si + VF_ENV_WAIT, W(Word(bx + 2)));
      SetW(si + VF_ENV_POS, Word(W(si + VF_ENV_POS) + 4));
    end;
  end;
end;

{ tick_spkr: step the four speaker voices, then drive PIT channel 2 from the first that came out of voice_step with a
  level and a duration left. }
procedure TickSpeaker;
var
  si: Word;
  bl: Byte;
  ax: Word;
begin
  bl := 0;
  if curTune <> 0 then begin
    spkrVoice := 0;
    voiceLeft := VOICES;
    freqBase := SPKR_FREQ;
    si := SPKR_BLOCKS;
    voiceBase := si;
    repeat
      if W(si + VF_DURATION) <> 0 then begin
        VoiceStep(si);
        if (spkrVoice = 0) and (W(si + VF_LEVEL) <> 0) and (W(si + VF_DURATION) <> 0) then
          spkrVoice := si;
      end;
      si := Word(si + VOICE_SIZE);
      Dec(voiceLeft);
    until voiceLeft = 0;
    if (outputOn <> 0) and (spkrVoice <> 0) then begin
      si := spkrVoice;
      ax := W(si + VF_OUT_PERIOD);
      PortOut(C_SOUND.PORT_PIT2, Lo(ax));
      PortOut(C_SOUND.PORT_PIT2, Hi(ax));
      { the low two bits are the 61h gate bits }
      bl := W(si + VF_LEVEL) and 3;
    end;
  end;
  PortOut(C_SOUND.PORT_GATE, (GateIn and $FC) or bl);
end;

{ tick_tandy: step the four Tandy voices, then write all four to the SN76489. dl walks the latch bytes 80h, 0A0h, 0C0h,
  0E0h; 0E0h is the noise voice, which takes no second period byte. }
procedure TickTandy;
var
  si: Word;
  ax: Word;
  al: Byte;
  dl: Byte;
  i: Byte;
begin
  if curTune <> 0 then begin
    voiceLeft := VOICES;
    freqBase := TANDY_FREQ;
    si := TANDY_BLOCKS;
    voiceBase := si;
    repeat
      if W(si + VF_DURATION) <> 0 then
        VoiceStep(si);
      si := Word(si + VOICE_SIZE);
      Dec(voiceLeft);
    until voiceLeft = 0;
    if outputOn <> 0 then begin
      voiceLeft := VOICES;
      si := TANDY_BLOCKS;
      dl := $80;
      repeat
        { the period shifted left 6: the low 4 period bits in AL and the high 6 in AH }
        ax := W(si + VF_OUT_PERIOD) shr 2;
        al := Lo(ax) shr 4;
        PortOut(C_SOUND.PORT_TANDY, al xor dl);
        if dl <> $E0 then
          PortOut(C_SOUND.PORT_TANDY, Hi(ax));
        { the chip attenuates, so invert the level, and keep its top 4 bits }
        ax := Word($FFFF - W(si + VF_LEVEL));
        PortOut(C_SOUND.PORT_TANDY, Byte(((Hi(ax) shr 4) xor dl) + $10));
        dl := Byte(dl + $20);
        si := Word(si + VOICE_SIZE);
        Dec(voiceLeft);
      until voiceLeft = 0;
      Exit;
    end;
  end;
  for i := 0 to 3 do
    PortOut(C_SOUND.PORT_TANDY, TANDY_SILENCE[i]);
end;

{ the configured device's tick (tickProc); the AdLib is not played natively, and ticks nothing }
procedure DeviceTick;
begin
  if seqBusy then
    Exit;
  seqBusy := True;
  case device of
    DEV_TANDY: TickTandy;
    DEV_SPEAKER: TickSpeaker;
  end;
  seqBusy := False;
end;

procedure Tick;
begin
  if not hooked then
    Exit;
  drvTicks := Word(drvTicks + 1);
  DeviceTick;
end;

{ With no sound output, the ticks the clock owes since the timer was hooked. }
procedure CatchUp;
var
  due: QWord;
begin
  if Rendered or not hooked then
    Exit;
  { the PIT's clocks in the milliseconds since, over the driver's divisor }
  due := (GetTickCount64 - clockStart) * C_SOUND.PIT_HZ div (C_SOUND.TIMER_DIVISOR * 1000);
  while clockRun < due do begin
    Inc(clockRun);
    Tick;
  end;
end;

{ ProgramSpeakerVoices and ProgramTandyVoices: clear each voice block the tune gives a stream for, point it at that
  stream and arm it to step on the next tick. An id past the last row plays tune 0, silence. }
procedure ProgramVoices(tuneId, table, rows, blocks: Word);
var
  v: Byte;
  stream: Word;
  di: Word;
begin
  EnterSeq;
  if tuneId >= rows then
    tuneId := 0;
  curTune := tuneId;
  di := blocks;
  for v := 0 to VOICES - 1 do begin
    stream := W(Word(table + tuneId * 8 + v * 2));
    if stream <> 0 then begin
      FillChar(mem[di], VOICE_SIZE, 0);
      SetW(di + VF_STREAM, stream);
      voiceTune[v] := Lo(curTune);
      SetW(di + VF_DURATION, 1);
    end;
    di := Word(di + VOICE_SIZE);
  end;
  LeaveSeq;
end;

procedure ProgramSpeakerVoices(tuneId: Word);
begin
  ProgramVoices(tuneId, SONG_TABLE_A, SONG_ROWS_A, SPKR_BLOCKS);
end;

procedure ProgramTandyVoices(tuneId: Word);
begin
  ProgramVoices(tuneId, SONG_TABLE_B, SONG_ROWS_B, TANDY_BLOCKS);
end;

procedure InstallSoundTimer;
begin
  EnterSeq;
  if not hooked then begin
    hooked := True;
    clockStart := GetTickCount64;
    clockRun := 0;
  end;
  LeaveSeq;
end;

{ Unhook, dropping the speaker's gates and, on the Tandy, silencing the chip: plain OUTs, never traced. }
procedure UninstallSoundTimer;
var
  i: Byte;
  saved: Boolean;
begin
  EnterSeq;
  if hooked then begin
    hooked := False;
    saved := tracing;
    tracing := False;
    PortOut(C_SOUND.PORT_GATE, gate and $FC);
    if device = DEV_TANDY then
      for i := 0 to 3 do
        PortOut(C_SOUND.PORT_TANDY, TANDY_SILENCE[i]);
    tracing := saved;
  end;
  LeaveSeq;
end;

{ The AdLib is not played natively: SndDig plays the Tandy arrangements on the SN76489 instead. }
procedure OplWrite(reg, value: Word);
begin
end;

procedure OplReset;
begin
end;

procedure SetSoundOutputEnabled(enabledValue: Word);
begin
  EnterSeq;
  outputOn := Lo(enabledValue);
  LeaveSeq;
end;

function SoundTimerTicks: Word;
begin
  CatchUp;
  SoundTimerTicks := drvTicks;
end;

function SoundTimerHooked: Boolean;
begin
  SoundTimerHooked := hooked;
end;

{ Leaving the speaker drops its gate, so no note hangs on when a driver moves a sound to another device. }
procedure SetSoundDevice(mode: Word);
var
  dev: Byte;
begin
  EnterSeq;
  dev := Lo(mode);
  if dev > DEV_ADLIB then
    dev := DEV_NONE;
  if (dev <> device) and (device = DEV_SPEAKER) then
    PortOut(C_SOUND.PORT_GATE, GateIn and $FC);
  device := dev;
  LeaveSeq;
end;

function SoundVoiceTune(voice: Word): Word;
begin
  CatchUp;
  SoundVoiceTune := voiceTune[voice and (VOICES - 1)];
end;

procedure SetTraceBuffer(buf: Pointer; capacity: Word);
begin
  traceBuf := buf;
  traceCap := capacity;
  traceLen := 0;
  tracing := True;
end;

function TraceCount: Word;
begin
  TraceCount := traceLen;
end;

procedure TraceTick;
begin
  DeviceTick;
end;

begin
  FillChar(mem, SizeOf(mem), 0);
  Move(SND_IMAGE, mem[SND_ORG], SND_IMAGE_BYTES);
  outputOn := 1;
  device := DEV_NONE;
end.

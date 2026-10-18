{ The Sound Blaster sound driver: AdLib music through the card's OPL2, as SndOpl plays it, and the effects as SSI's
  recorded samples (SBSFX.DAT, built by tools/sbsfx.py from Pools of Darkness and Dark Queen of Krynn, which play
  their effects the same way), each one DMA transfer the DSP plays at the sample's rate. Effects with no sample play
  on the speaker. The driver never hooks the card's IRQ: a single-cycle transfer needs only the port and the DMA
  channel, from BLASTER (A220 D1 by default). GameBoot installs it when POOL.CFG names S; with no DSP answering, the
  AdLib's driver is installed instead (phase 7 of docs/refactor-plan.md). }
{$F+,I-}
unit SndSb;

interface

{ Make this the sound driver if a DSP answers, else the AdLib's (or the speaker's): fill GDVars.sound. }
procedure Install;

implementation

uses Dos, C_Sound, GDVars, FileUtil, SoundDrv, SndOpl;

const
  EFFECTS_FILE = 'SBSFX.DAT';
  EFFECTS_SIG = 'SBFX';
  EFFECTS_VERSION = 1;
  { the tunes SBSFX.DAT may have a sample for: the effects (music starts at C_Sound.MUSIC_TITLE) }
  LAST_EFFECT = 20;
  { the DSP's ports, from its base }
  DSP_RESET = $6;
  DSP_READ = $A;
  DSP_WRITE = $C;
  DSP_READY = $E;
  { the DSP's reply to a reset }
  DSP_READY_BYTE = $AA;
  { DSP commands: the time constant, an 8-bit single-cycle DMA output, halt DMA, speaker on }
  DSP_TIME_CONSTANT = $40;
  DSP_DMA_8BIT = $14;
  DSP_HALT_DMA = $D0;
  DSP_SPEAKER_ON = $D1;
  { polls of a DSP port before giving up on it }
  DSP_WAIT = 2000;
  { the 8237's ports for channels 0 to 3: mask, flip-flop clear and mode, and each channel's address, count and page }
  DMA_MASK = $0A;
  DMA_MODE = $0B;
  DMA_FLIP_FLOP = $0C;
  { mode: single transfer, read (memory to the card), plus the channel }
  DMA_SINGLE_READ = $48;
  DMA_MASK_ON = $04;
  DMA_ADDR: array[0..3] of Byte = ($00, $02, $04, $06);
  DMA_COUNT: array[0..3] of Byte = ($01, $03, $05, $07);
  DMA_PAGE: array[0..3] of Byte = ($87, $83, $81, $82);
  { the card BLASTER names, or the usual one }
  DEFAULT_BASE = $220;
  DEFAULT_DMA = 1;
  { heap blocks given up looking for one that crosses no 64 KB page, before the effects go to the speaker }
  PLACE_TRIES = 4;

type
  TEffect = record
    rate: Word;
    len: Word;
    { offset of its bytes in the loaded file; 0 for none }
    start: Word;
  end;

var
  base: Word;
  dma: Byte;
  { SBSFX.DAT in memory once the first effect asks for it, in a block that crosses no 64 KB page; nil before, or if
    it could not be loaded (the effects then play on the speaker) }
  store: ^Byte;
  storeSize: Word;
  loadTried: Boolean;
  effects: array[1..LAST_EFFECT] of TEffect;
  { the exit procedure SndSb.SbExit hands on to }
  sbExitSaved: Pointer;

{ Write v to the DSP once it is ready for it; False if it never is. }
function DspWrite(v: Byte): Boolean;
var
  i: Word;
begin
  DspWrite := False;
  for i := 1 to DSP_WAIT do
    if Port[base + DSP_WRITE] and $80 = 0 then begin
      Port[base + DSP_WRITE] := v;
      DspWrite := True;
      Exit;
    end;
end;

{ Reset the DSP at base: True when it answers AAh, as a Sound Blaster's does. }
function DspReset: Boolean;
var
  i: Word;
  b: Byte;
begin
  DspReset := False;
  Port[base + DSP_RESET] := 1;
  { at least 3 microseconds }
  for i := 1 to 8 do
    b := Port[base + DSP_RESET];
  Port[base + DSP_RESET] := 0;
  for i := 1 to DSP_WAIT do
    if Port[base + DSP_READY] and $80 <> 0 then begin
      DspReset := Port[base + DSP_READ] = DSP_READY_BYTE;
      Exit;
    end;
end;

{ The card's port and DMA channel from BLASTER (A220 I7 D1 T3...), or the usual ones. }
procedure ReadBlaster;
var
  s: String;
  i: Byte;
  v: Word;
  code: Integer;
  k: Byte;
begin
  base := DEFAULT_BASE;
  dma := DEFAULT_DMA;
  s := GetEnv('BLASTER') + ' ';
  i := 1;
  while i < Length(s) do begin
    k := i + 1;
    while (k <= Length(s)) and (s[k] <> ' ') do
      Inc(k);
    case UpCase(s[i]) of
      'A': begin
             Val('$' + Copy(s, i + 1, k - i - 1), v, code);
             if code = 0 then
               base := v;
           end;
      'D': begin
             Val(Copy(s, i + 1, k - i - 1), v, code);
             if (code = 0) and (v <= 3) then
               dma := v;
           end;
    end;
    i := k + 1;
  end;
end;

{ The 20-bit physical address of p. }
function Physical(p: Pointer): LongInt;
begin
  Physical := LongInt(Seg(p^)) * 16 + Ofs(p^);
end;

{ Load SBSFX.DAT into a block that crosses no 64 KB page, so every sample plays in place; on any failure the store
  stays nil and the effects go to the speaker. Blocks that cross one are held while another is tried, then freed. }
procedure LoadEffects;
var
  f: file;
  size: LongInt;
  got: Word;
  tries: Byte;
  held: array[1..PLACE_TRIES] of Pointer;
  nHeld: Byte;
  p: ^Byte;
  sig: string[4];
  count: Byte;
  i: Byte;
  rec: ^Byte;
  tune: Byte;
  ok: Boolean;
  ioRes: Integer;
begin
  loadTried := True;
  FillChar(effects, SizeOf(effects), 0);
  if not FileUtil.OpenReadOnly(f, GDVars.gameDir + EFFECTS_FILE) then Exit;
  size := FileSize(f);
  if (IOResult <> 0) or (size < 6) or (size > $FFF0) or (size > MaxAvail) then begin
    Close(f);
    ioRes := IOResult;
    Exit;
  end;
  storeSize := size;
  nHeld := 0;
  p := nil;
  for tries := 1 to PLACE_TRIES do
    if (p = nil) and (MaxAvail >= storeSize) then begin
      GetMem(p, storeSize);
      if (Physical(p) and $FFFF) + storeSize > $10000 then begin
        Inc(nHeld);
        held[nHeld] := p;
        p := nil;
      end;
    end;
  for i := 1 to nHeld do
    FreeMem(held[i], storeSize);
  if p = nil then begin
    Close(f);
    ioRes := IOResult;
    Exit;
  end;
  BlockRead(f, p^, storeSize, got);
  Close(f);
  ok := (IOResult = 0) and (got = storeSize);
  if ok then begin
    sig[0] := #4;
    Move(p^, sig[1], 4);
    rec := Ptr(Seg(p^), Ofs(p^) + 4);
    ok := (sig = EFFECTS_SIG) and (rec^ = EFFECTS_VERSION);
    Inc(Word(rec));
    count := rec^;
    Inc(Word(rec));
    ok := ok and (6 + 7 * Word(count) <= storeSize);
  end;
  if not ok then begin
    FreeMem(p, storeSize);
    Exit;
  end;
  { each entry: tune, rate, length, offset }
  for i := 1 to count do begin
    tune := rec^;
    if (tune >= 1) and (tune <= LAST_EFFECT) then begin
      Move(Ptr(Seg(rec^), Ofs(rec^) + 1)^, effects[tune].rate, 2);
      Move(Ptr(Seg(rec^), Ofs(rec^) + 3)^, effects[tune].len, 2);
      Move(Ptr(Seg(rec^), Ofs(rec^) + 5)^, effects[tune].start, 2);
      with effects[tune] do
        if (len = 0) or (rate < 4000) or (LongInt(start) + len > storeSize) then
          start := 0;
    end;
    Inc(Word(rec), 7);
  end;
  store := Pointer(p);
end;

{ Play len bytes at p, rate samples a second, as one single-cycle DMA transfer. }
procedure PlaySample(p: Pointer; len, rate: Word);
var
  phys: LongInt;
  b: Byte;
  ok: Boolean;
begin
  phys := Physical(p);
  { acknowledge the last transfer's end, and stop one still playing }
  b := Port[base + DSP_READY];
  ok := DspWrite(DSP_HALT_DMA);
  Port[DMA_MASK] := DMA_MASK_ON or dma;
  Port[DMA_FLIP_FLOP] := 0;
  Port[DMA_MODE] := DMA_SINGLE_READ or dma;
  Port[DMA_ADDR[dma]] := Lo(Word(phys));
  Port[DMA_ADDR[dma]] := Hi(Word(phys));
  Port[DMA_PAGE[dma]] := phys shr 16;
  Port[DMA_COUNT[dma]] := Lo(len - 1);
  Port[DMA_COUNT[dma]] := Hi(len - 1);
  Port[DMA_MASK] := dma;
  ok := DspWrite(DSP_TIME_CONSTANT) and DspWrite(256 - (1000000 div rate)) and DspWrite(DSP_DMA_8BIT) and
        DspWrite(Lo(len - 1)) and DspWrite(Hi(len - 1));
end;

{ Music on the AdLib, as SndOpl plays it; an effect with a sample on the DSP, the AdLib's voices silenced first so the
  effect ends the music as every effect does; any other effect, and silence, on the speaker. }
procedure Play(tune: Word);
var
  ok: Boolean;
begin
  if (tune >= 1) and (tune <= LAST_EFFECT) then begin
    if not loadTried then
      SndSb.LoadEffects;
    if (store <> nil) and (effects[tune].start <> 0) then begin
      SoundDrv.SetSoundDevice(C_Sound.MODE_ADLIB);
      SoundDrv.ProgramTandyVoices(0);
      with effects[tune] do
        SndSb.PlaySample(Ptr(Seg(store^), Ofs(store^) + start), len, rate);
      Exit;
    end;
  end;
  if tune = 0 then
    ok := DspWrite(DSP_HALT_DMA);
  SndOpl.Play(tune);
end;

{ Stop a sample still playing on every way out of the program. }
procedure SbExit;
var
  ok: Boolean;
begin
  ExitProc := sbExitSaved;
  ok := DspWrite(DSP_HALT_DMA);
end;

procedure Install;
var
  ok: Boolean;
begin
  ReadBlaster;
  if SndSb.DspReset then begin
    ok := DspWrite(DSP_SPEAKER_ON);
    { the card's OPL2 plays the music; without one it is the speaker's, and the effects still the DSP's }
    SndOpl.Install;
    if GDVars.sound.mode = C_Sound.MODE_ADLIB then
      GDVars.sound.name := 'Sound Blaster'
    else begin
      GDVars.sound.mode := C_Sound.MODE_ADLIB;
      GDVars.sound.name := 'Blaster (no AdLib)';
    end;
    GDVars.sound.Play := SndSb.Play;
    sbExitSaved := ExitProc;
    ExitProc := @SndSb.SbExit;
  end else begin
    SndOpl.Install;
    if GDVars.sound.mode = C_Sound.MODE_ADLIB then
      GDVars.sound.name := 'AdLib (no Blaster)';
  end;
end;

begin
  store := nil;
  loadTried := False;
end.

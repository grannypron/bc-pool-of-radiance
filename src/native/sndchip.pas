{ The native build's sound hardware: the PC speaker (PIT channel 2 and port 61h's gates) and the Tandy's SN76489,
  emulated from the sequencer's port writes (SndSeq.PortWrite), and one recorded sample playing beside them, as the
  Sound Blaster's DSP plays one. Render makes the sound: it runs the sequencer's timer interrupt (SndSeq.Tick) 236.7
  times a second of sound, at the sample it falls on, so each write lands where the DOS machine's tick would put it,
  and mixes the chips and the sample into signed 16-bit mono at RATE. Each chip is stepped at its own clock (the PIT's
  1193182 Hz, the SN76489's 3579545 Hz / 16) and averaged over each output sample, which keeps their square waves
  from aliasing. SdlSound calls Render from the audio thread with the stream locked, and the game's calls reach the
  chips only through the sequencer's entries, which take the same lock. No floating point, so the audio thread
  needs none of the RTL's state. Objfpc mode. Free Pascal only. }
{$MODE OBJFPC}
{$H-}
{$R-}
{$Q-}
unit SndChip;

interface

const
  { output samples a second }
  RATE = 48000;

type
  PSmallInts = ^SmallInt;

{ A port write from the sequencer: 42h PIT channel 2's divisor (low byte, then high), 61h the speaker's gates, 0C0h
  the SN76489. }
procedure Write(port, value: Byte);

{ Play a recorded sample, unsigned 8-bit at rate Hz, replacing one still playing; len 0 stops it. The bytes must stay
  put while it plays. }
procedure PlaySample(data: Pointer; len: LongWord; rate: LongWord);

{ count samples of sound into buf, running the sequencer's ticks as they fall. }
procedure Render(buf: PSmallInts; count: LongInt);

implementation

uses SndSeq;

const
  PIT_HZ = 1193182;
  { the PIT's channel 0 divisor while the sequencer has it: 236.7 ticks a second }
  TICK_DIVISOR = 5041;
  { the SN76489's input clock, and the divider before its counters }
  TANDY_HZ = 3579545;
  TANDY_DIVIDER = 16;
  { peak levels: the speaker's one level, a Tandy voice at no attenuation, a sample's full swing }
  SPEAKER_PEAK = 5000;
  TANDY_PEAK = 4500;
  SAMPLE_PEAK = 20000;
  { the SN76489's attenuation, 2 dB a step, as levels of TANDY_PEAK; 15 is off }
  TANDY_LEVELS: array[0..15] of LongInt = (4500, 3574, 2839, 2255, 1791, 1423, 1130, 898, 713, 566, 450, 357, 284,
    225, 179, 0);
  { the noise generator's 15-bit shift register's seed, and its taps for white noise }
  NOISE_SEED = $4000;

var
  { the sequencer's tick: PIT clocks (times RATE) since the last }
  tickAcc: LongInt;

  { the speaker: channel 2's divisor (0 is 65536), the gates in 61h's low bits, the square's half-period count down
    and its level, the low byte of a divisor half written, and PIT clocks (times RATE) owed }
  spkDivisor: LongWord;
  spkGates: Byte;
  spkCount: LongWord;
  spkHigh: Boolean;
  spkLowByte: Byte;
  spkSecond: Boolean;
  spkAcc: LongInt;

  { the SN76489: the three tone periods and the noise control, the four attenuations, the latched register, each
    counter and its output, the noise's shift register, and chip steps (times RATE) owed }
  tdyTone: array[0..2] of Word;
  tdyNoise: Byte;
  tdyAtt: array[0..3] of Byte;
  tdyLatch: Byte;
  tdyCount: array[0..3] of Word;
  tdyOut: array[0..3] of Boolean;
  tdyShift: Word;
  tdyAcc: LongInt;

  { the sample: its bytes, length and position (in 1/RATE of its own samples, so its rate steps it exactly) }
  smpData: PByte;
  smpLen: LongWord;
  smpRate: LongWord;
  smpPos: QWord;

procedure WriteTandy(value: Byte);
var
  reg: Byte;
  voice: Byte;
begin
  if value and $80 <> 0 then begin
    tdyLatch := (value shr 4) and 7;
    reg := tdyLatch;
    voice := reg shr 1;
    if reg and 1 <> 0 then
      tdyAtt[voice] := value and $F
    else if voice < 3 then
      tdyTone[voice] := (tdyTone[voice] and $3F0) or (value and $F)
    else begin
      tdyNoise := value and 7;
      { writing the noise control resets its shift register }
      tdyShift := NOISE_SEED;
    end;
  end else begin
    reg := tdyLatch;
    voice := reg shr 1;
    if reg and 1 <> 0 then
      tdyAtt[voice] := value and $F
    else if voice < 3 then
      tdyTone[voice] := (tdyTone[voice] and $F) or ((Word(value) and $3F) shl 4)
    else begin
      tdyNoise := value and 7;
      tdyShift := NOISE_SEED;
    end;
  end;
end;

procedure Write(port, value: Byte);
begin
  case port of
    $42: if not spkSecond then begin
           spkLowByte := value;
           spkSecond := True;
         end else begin
           spkDivisor := spkLowByte or (Word(value) shl 8);
           if spkDivisor = 0 then
             spkDivisor := 65536;
           spkSecond := False;
         end;
    $61: spkGates := value and 3;
    $C0: WriteTandy(value);
  end;
end;

procedure PlaySample(data: Pointer; len: LongWord; rate: LongWord);
var
  locked: Boolean;
begin
  locked := Assigned(SndSeq.Lock);
  if locked then
    SndSeq.Lock;
  smpData := data;
  smpLen := len;
  smpRate := rate;
  smpPos := 0;
  if locked then
    SndSeq.Unlock;
end;

{ The speaker over one output sample: the square's level averaged over the PIT clocks it spans, or 0 with either gate
  shut. }
function SpeakerSample: LongInt;
var
  clocks: LongInt;
  high: LongInt;
  n: LongInt;
  half: LongWord;
begin
  spkAcc := spkAcc + PIT_HZ;
  clocks := spkAcc div RATE;
  spkAcc := spkAcc mod RATE;
  if spkGates <> 3 then begin
    SpeakerSample := 0;
    Exit;
  end;
  half := spkDivisor div 2;
  if half = 0 then
    half := 1;
  high := 0;
  for n := 1 to clocks do begin
    if spkCount <= 1 then begin
      spkCount := half;
      spkHigh := not spkHigh;
    end else
      Dec(spkCount);
    if spkHigh then
      Inc(high);
  end;
  if clocks = 0 then
    SpeakerSample := 0
  else
    SpeakerSample := (2 * high - clocks) * SPEAKER_PEAK div clocks;
end;

{ The SN76489 over one output sample: each voice's square (the noise's shift register's bit) at its attenuation,
  averaged over the chip steps it spans. }
function TandySample: LongInt;
var
  steps: LongInt;
  n: LongInt;
  v: Byte;
  sum: LongInt;
  period: Word;
  feedback: Word;
begin
  tdyAcc := tdyAcc + TANDY_HZ;
  steps := tdyAcc div (RATE * TANDY_DIVIDER);
  tdyAcc := tdyAcc mod (RATE * TANDY_DIVIDER);
  sum := 0;
  for n := 1 to steps do begin
    for v := 0 to 3 do begin
      if v < 3 then
        period := tdyTone[v]
      else
        case tdyNoise and 3 of
          0: period := $10;
          1: period := $20;
          2: period := $40;
        else
          period := tdyTone[2];
        end;
      if period = 0 then
        period := $400;
      if tdyCount[v] <= 1 then begin
        tdyCount[v] := period;
        tdyOut[v] := not tdyOut[v];
        { the noise steps its shift register on each rising edge: white noise feeds back bits 0 and 1 }
        if (v = 3) and tdyOut[v] then begin
          if tdyNoise and 4 <> 0 then
            feedback := (tdyShift xor (tdyShift shr 1)) and 1
          else
            feedback := tdyShift and 1;
          tdyShift := (tdyShift shr 1) or (feedback shl 14);
        end;
      end else
        Dec(tdyCount[v]);
      if v < 3 then begin
        if tdyOut[v] then
          sum := sum + TANDY_LEVELS[tdyAtt[v]]
        else
          sum := sum - TANDY_LEVELS[tdyAtt[v]];
      end else if tdyShift and 1 <> 0 then
        sum := sum + TANDY_LEVELS[tdyAtt[3]]
      else
        sum := sum - TANDY_LEVELS[tdyAtt[3]];
    end;
  end;
  if steps = 0 then
    TandySample := 0
  else
    TandySample := sum div steps;
end;

{ The sample at this output sample, its neighbours interpolated; 0 once it has ended. }
function SampleSample: LongInt;
var
  i: LongWord;
  frac: LongInt;
  a: LongInt;
  b: LongInt;
begin
  SampleSample := 0;
  if smpLen = 0 then
    Exit;
  i := smpPos div RATE;
  if i >= smpLen then begin
    smpLen := 0;
    Exit;
  end;
  frac := smpPos mod RATE;
  a := LongInt(smpData[i]) - 128;
  if i + 1 < smpLen then
    b := LongInt(smpData[i + 1]) - 128
  else
    b := a;
  SampleSample := (a * (RATE - frac) + b * frac) div RATE * SAMPLE_PEAK div 128;
  smpPos := smpPos + smpRate;
end;

procedure Render(buf: PSmallInts; count: LongInt);
var
  i: LongInt;
  s: LongInt;
begin
  for i := 0 to count - 1 do begin
    tickAcc := tickAcc + PIT_HZ;
    if tickAcc >= TICK_DIVISOR * RATE then begin
      tickAcc := tickAcc - TICK_DIVISOR * RATE;
      SndSeq.Tick;
    end;
    s := SpeakerSample + TandySample + SampleSample;
    if s > 32767 then
      s := 32767
    else if s < -32768 then
      s := -32768;
    buf[i] := s;
  end;
end;

begin
  spkDivisor := 65536;
  tdyShift := NOISE_SEED;
  FillChar(tdyAtt, SizeOf(tdyAtt), $F);
end.

{ Tests for the AdLib's rendering of the Tandy arrangements (refactor phase 7, step 3): each tune is played on the
  Tandy and then on the AdLib through the trace build (SndTrc), and the writes decoded tick by tick. The SN76489's
  writes give each tone voice's period and attenuation; the OPL2's give each channel's fnum, block and carrier level.
  Wherever a Tandy tone voice sounds, the AdLib channel must play its pitch within 1% at the level SN76489 attenuation
  maps to; where it is silent, the channel must be silent too. The noise voice plays the OPL's snare drum: its level
  must follow the same way, with the rhythm register keying it. Only the first CHECK_TICKS ticks of each tune are
  compared. }
{$I COMPILER.INC}
program TSndOpl;

uses C_Sound, SndTrc, TestKit;

const
  LAST_TUNE = 28;
  CHECK_TICKS = 400;
  BUF_WORDS = 64;
  BIG_WORDS = 1024;
  { SN76489 tone: 3579545 / (32 n) Hz; OPL2: fnum * 49716 / 2^(20 - block) Hz }
  SN_CLOCK = 111860.78;
  OPL_CLOCK = 49716.0;
  { the carrier level registers of channels 0..2 (40h + the carrier's offset) }
  CARRIER: array[0..2] of Byte = ($43, $44, $45);
  { the noise voice: the snare drum's level register (40h + operator 14h), and the rhythm register keying it }
  SNARE_LEVEL = $54;
  RHYTHM = $BD;
  SNARE_KEYED = $28;
  { SN76489 attenuation -> OPL total level, as sndopl.inc's oplAtt }
  ATT: array[0..15] of Byte = (0, 3, 5, 8, 11, 13, 16, 19, 21, 24, 27, 29, 32, 35, 37, 63);

type
  TVoiceTicks = array[1..CHECK_TICKS, 0..3] of Word;

var
  buf: array[0..BUF_WORDS - 1] of Word;
  big: array[0..BIG_WORDS - 1] of Word;
  log: Text;
  period: ^TVoiceTicks;
  atten: ^TVoiceTicks;
  regs: array[0..255] of Byte;
  lastReg: Byte;
  shown: Word;
  ticks: Word;
  tune: Word;
  bad: Word;
  badPitch: Word;
  badLevel: Word;
  badNoise: Word;
  noisy: LongInt;
  checked: LongInt;
  s: String;

{ Run the loaded tune for CHECK_TICKS ticks, decoding each tick's SN76489 writes into every voice's period and
  attenuation. }
procedure RunTandy;
var
  t: Word;
  i: Word;
  w: Byte;
  ch: Byte;
  latch: Byte;
  cur: array[0..3] of Word;
  att: array[0..3] of Word;
begin
  FillChar(cur, SizeOf(cur), 0);
  for i := 0 to 3 do
    att[i] := 15;
  latch := 0;
  t := 0;
  repeat
    Inc(t);
    SndTrc.SetTraceBuffer(@buf, BUF_WORDS);
    SndTrc.TraceTick;
    { a while loop: with no writes, TraceCount - 1 would be 65535 }
    i := 0;
    while i < SndTrc.TraceCount do begin
      w := Lo(buf[i]);
      if w and $80 <> 0 then begin
        latch := w;
        ch := (w shr 5) and 3;
        if w and $10 <> 0 then
          att[ch] := w and $0F
        else
          cur[ch] := (cur[ch] and $3F0) or (w and $0F);
      end else begin
        ch := (latch shr 5) and 3;
        cur[ch] := (cur[ch] and $0F) or (Word(w and $3F) shl 4);
      end;
      Inc(i);
    end;
    for ch := 0 to 3 do begin
      period^[t, ch] := cur[ch];
      atten^[t, ch] := att[ch];
    end;
  until t >= CHECK_TICKS;
  ticks := t;
end;

{ Fold the recorded OPL writes into regs. A tick that changes nothing writes nothing, so the loop is a while: with
  TraceCount 0, TraceCount - 1 would be 65535. }
procedure Apply;
var
  i: Word;
begin
  i := 0;
  while i < SndTrc.TraceCount do begin
    if Hi(buf[i]) = $88 then
      lastReg := Lo(buf[i])
    else
      regs[lastReg] := Lo(buf[i]);
    Inc(i);
  end;
end;

{ Run the same tune on the AdLib, from the reset's registers, and compare each tick with the Tandy's. }
procedure RunOpl;
var
  t: Word;
  i: Word;
  ch: Byte;
  fnum: Word;
  block: Byte;
  fT: Real;
  fO: Real;
  level: Byte;
begin
  FillChar(regs, SizeOf(regs), 0);
  lastReg := 0;
  { the reset's writes are more than a tick's buffer holds, so they go to the big one }
  SndTrc.SetTraceBuffer(@big, BIG_WORDS);
  SndTrc.OplReset;
  for i := 0 to SndTrc.TraceCount - 1 do
    if Hi(big[i]) = $88 then
      lastReg := Lo(big[i])
    else
      regs[lastReg] := Lo(big[i]);
  for t := 1 to ticks do begin
    SndTrc.SetTraceBuffer(@buf, BUF_WORDS);
    SndTrc.TraceTick;
    Apply;
    for ch := 0 to 2 do begin
      level := regs[CARRIER[ch]] and $3F;
      if atten^[t, ch] = 15 then begin
        if level <> 63 then
          Inc(badLevel);
      end else begin
        Inc(checked);
        if level <> ATT[atten^[t, ch]] then
          Inc(badLevel);
        fnum := regs[$A0 + ch] or (Word(regs[$B0 + ch] and 3) shl 8);
        block := (regs[$B0 + ch] shr 2) and 7;
        if period^[t, ch] = 0 then
          fT := SN_CLOCK / 1024
        else
          fT := SN_CLOCK / period^[t, ch];
        fO := fnum * OPL_CLOCK / (LongInt(1) shl (20 - block));
        { the OPL's top note bounds the highest Tandy pitches }
        if (fT < 6000) and ((fO < fT * 0.99) or (fO > fT * 1.01)) then begin
          Inc(badPitch);
          if shown < 8 then begin
            Inc(shown);
            WriteLn(log, 'tune ', tune, ' tick ', t, ' ch ', ch, ' n ', period^[t, ch], ' tandy ', fT:0:1,
                    ' Hz, opl fnum ', fnum, ' block ', block, ' ', fO:0:1, ' Hz');
          end;
        end;
        if regs[$B0 + ch] and $20 = 0 then
          Inc(badPitch);
      end;
    end;
    { the noise voice on the snare: its level follows, keyed by the rhythm register }
    level := regs[SNARE_LEVEL] and $3F;
    if atten^[t, 3] = 15 then begin
      if level <> 63 then
        Inc(badNoise);
    end else begin
      Inc(noisy);
      if (level <> ATT[atten^[t, 3]]) or (regs[RHYTHM] <> SNARE_KEYED) then
        Inc(badNoise);
    end;
  end;
end;

begin
  TestKit.Start('TSNDOPL');
  New(period);
  New(atten);
  Assign(log, 'SNDOPL.TXT');
  Rewrite(log);
  shown := 0;
  SndTrc.SetTraceBuffer(@big, BIG_WORDS);
  SndTrc.OplReset;
  { 245 registers cleared, waveform select, 4 channels of 10 patch pairs, a feedback and (noise) a modulator }
  TestKit.Check(SndTrc.TraceCount > 2 * 280, 'the reset writes the registers');
  checked := 0;
  noisy := 0;
  for tune := 1 to LAST_TUNE do begin
    badPitch := 0;
    badLevel := 0;
    badNoise := 0;
    SndTrc.SetSoundDevice(C_Sound.MODE_TANDY);
    SndTrc.ProgramTandyVoices(tune);
    RunTandy;
    SndTrc.SetSoundDevice(C_Sound.MODE_ADLIB);
    SndTrc.ProgramTandyVoices(tune);
    RunOpl;
    Str(tune, s);
    TestKit.CheckEqualsL(0, badPitch, 'tune ' + s + ': AdLib pitch within 1% of the Tandy''s, keyed on');
    TestKit.CheckEqualsL(0, badLevel, 'tune ' + s + ': AdLib level as the Tandy''s attenuation maps');
    TestKit.CheckEqualsL(0, badNoise, 'tune ' + s + ': the snare as the Tandy''s noise voice');
  end;
  TestKit.Check(checked > 1000, 'enough sounding ticks were compared');
  TestKit.Check(noisy > 100, 'enough noisy ticks were compared');
  SndTrc.SetSoundDevice(C_Sound.MODE_DISABLED);
  Close(log);
  TestKit.Done;
end.

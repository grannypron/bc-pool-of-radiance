{ The native build's Digital Audio driver: the music and any effect without a recording as the Tandy's SN76489 plays
  them (SSI's own arrangements, emulated by SndChip), and the effects SBSFX.DAT has a recording for as the Sound
  Blaster's DSP plays them (SndSb's samples: Dark Queen of Krynn's, and the first of Pools of Darkness's step thumps).
  An effect with a recording silences the Tandy's voices first, so it ends the music as every effect does. Without
  SBSFX.DAT every effect is the Tandy's. GameBoot installs it when POOL.CFG names T, A or B. Free Pascal only. }
{$F+,I-}
{$I COMPILER.INC}
unit SndDig;

interface

{ Make this the sound driver: fill GameVars.sound. }
procedure Install;

implementation

uses Types, C_SOUND, GameVars, SfxFile, SoundDrv, SndChip;

const
  { the DSP's 4-bit ADPCM, as DOSBox decodes it: each code (with the step, 0, 16, 32 or 48) moves the level by
    ADPCM_DELTA and the step by ADPCM_STEP (240 is -16) }
  ADPCM_DELTA: array[0..63] of ShortInt = (
    0, 1, 2, 3, 4, 5, 6, 7, 0, -1, -2, -3, -4, -5, -6, -7,
    1, 3, 5, 7, 9, 11, 13, 15, -1, -3, -5, -7, -9, -11, -13, -15,
    2, 6, 10, 14, 18, 22, 26, 30, -2, -6, -10, -14, -18, -22, -26, -30,
    4, 12, 20, 28, 36, 44, 52, 60, -4, -12, -20, -28, -36, -44, -52, -60);
  ADPCM_STEP: array[0..63] of Byte = (
    0, 0, 0, 0, 0, 16, 16, 16, 0, 0, 0, 0, 0, 16, 16, 16,
    240, 0, 0, 0, 0, 16, 16, 16, 240, 0, 0, 0, 0, 16, 16, 16,
    240, 0, 0, 0, 0, 16, 16, 16, 240, 0, 0, 0, 0, 16, 16, 16,
    240, 0, 0, 0, 0, 0, 0, 0, 240, 0, 0, 0, 0, 0, 0, 0);

type
  TEffect = record
    { its unsigned 8-bit samples, decoded; nil for none }
    data: Types.PBytes;
    len: Word;
    rate: Word;
  end;

var
  loadTried: Boolean;
  effects: array[1..C_SOUND.SFX_LAST] of TEffect;

{ The 4-bit ADPCM bytes src^[start..start + len - 1], the reference byte first, as unsigned 8-bit samples in dst. }
procedure DecodeAdpcm(src: Types.PBytes; start, len: Word; dst: Types.PBytes);
var
  level: Integer;
  step: Byte;
  i: Word;
  n: Word;
  half: Byte;
  code: Byte;
  k: Byte;
begin
  level := src^[start];
  step := 0;
  dst^[0] := level;
  n := 1;
  for i := 1 to len - 1 do
    for half := 0 to 1 do begin
      if half = 0 then
        code := src^[start + i] shr 4
      else
        code := src^[start + i] and $F;
      k := code + step;
      if k > 63 then
        k := 63;
      level := level + ADPCM_DELTA[k];
      if level > 255 then
        level := 255
      else if level < 0 then
        level := 0;
      step := Byte(step + ADPCM_STEP[k]);
      dst^[n] := level;
      Inc(n);
    end;
end;

{ Load SBSFX.DAT's samples, decoding the ADPCM ones; on any failure of the file every effect stays the Tandy's. }
procedure LoadEffects;
var
  p: Types.PBytes;
  size: Word;
  count: Byte;
  i: Byte;
  e: SfxFile.TSfxEntry;
  fx: ^TEffect;
begin
  loadTried := True;
  FillChar(effects, SizeOf(effects), 0);
  if not SfxFile.Load(p, size, count) then Exit;
  for i := 1 to count do
    if SfxFile.GetEntry(p, size, i - 1, e) then begin
      fx := @effects[e.tune];
      { a second entry for the same effect replaces the first }
      if fx^.data <> nil then
        FreeMem(fx^.data, fx^.len);
      fx^.rate := 1000000 div (256 - e.timeConstant);
      if e.format = C_SOUND.SFX_ADPCM4 then
        fx^.len := 2 * (e.len - 1) + 1
      else
        fx^.len := e.len;
      GetMem(fx^.data, fx^.len);
      if e.format = C_SOUND.SFX_ADPCM4 then
        DecodeAdpcm(p, e.start, e.len, fx^.data)
      else
        Move(p^[e.start], fx^.data^, e.len);
    end;
  FreeMem(p, size);
end;

{ An effect with a recording on the DSP, the Tandy's voices silenced first; the music, every other effect, and silence
  (which also stops a recording) on the Tandy. }
procedure Play(tune: Word);
begin
  if (tune >= 1) and (tune <= C_SOUND.SFX_LAST) then begin
    if not loadTried then
      SndDig.LoadEffects;
    if effects[tune].data <> nil then begin
      SoundDrv.ProgramTandyVoices(0);
      SndChip.PlaySample(effects[tune].data, effects[tune].len, effects[tune].rate);
      Exit;
    end;
  end;
  if tune = 0 then
    SndChip.PlaySample(nil, 0, 0);
  SoundDrv.ProgramTandyVoices(tune);
end;

procedure Install;
begin
  GameVars.sound.name := 'Digital Audio';
  GameVars.sound.mode := C_SOUND.MODE_TANDY;
  GameVars.sound.Play := SndDig.Play;
  { the recorded step plays once a step, as the Sound Blaster's does (POR-0170) }
  GameVars.sound.singleStep := True;
end;

begin
  loadTried := False;
end.

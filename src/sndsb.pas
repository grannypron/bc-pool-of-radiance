{ The Sound Blaster sound driver: AdLib music through the card's OPL2, as SndOpl plays it, and the effects as SSI's
  recorded samples (SBSFX.DAT, built by tools/sbsfx.py: Dark Queen of Krynn's, in its own 4-bit ADPCM, and the first of
  Pools of Darkness's step thumps), each one DMA transfer the DSP plays at the sample's rate. Effects with no sample
  play on the speaker. The driver never hooks the card's IRQ: a single-cycle transfer needs only the port and the DMA
  channel, from BLASTER (A220 D1 by default). GameBoot installs it when POOL.CFG names B; with no DSP answering, the
  AdLib's driver is installed instead (phase 7 of docs/refactor-plan.md). }
{$F+,I-}
{$I COMPILER.INC}
unit SndSb;

interface

{ Make this the sound driver if a DSP answers, else the AdLib's (or the speaker's): fill GameVars.sound. }
procedure Install;

implementation

uses {$IFDEF FPC}TpCompat, PortIO, {$ENDIF}Dos, Types, C_SOUND, GameVars, SfxFile, SoundDrv, SndOpl;

const
  { the DSP's ports, from its base }
  DSP_RESET = $6;
  DSP_READ = $A;
  DSP_WRITE = $C;
  DSP_READY = $E;
  { the DSP's reply to a reset }
  DSP_READY_BYTE = $AA;
  { DSP commands: the time constant; single-cycle DMA output of 8-bit PCM and of 4-bit ADPCM with its reference byte;
    halt DMA; speaker on }
  DSP_TIME_CONSTANT = $40;
  DSP_DMA_8BIT = $14;
  DSP_DMA_ADPCM4_REF = $75;
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
  { blocks tried for a bounce buffer that crosses no 64 KB page }
  PLACE_TRIES = 4;

var
  base: Word;
  dma: Byte;
  { SBSFX.DAT in memory once the first effect asks for it; nil before, or if it could not be loaded (the effects then
    play on the speaker) }
  store: Types.PBytes;
  storeSize: Word;
  { a buffer that crosses no 64 KB page, as long as the longest sample whose bytes in store cross one (which DMA
    cannot): such a sample is copied here to play; nil when none crosses, or none could be placed, and such a sample
    then plays on the speaker }
  bounce: ^Byte;
  bounceSize: Word;
  loadTried: Boolean;
  { each effect's recording; start 0 for none }
  effects: array[1..C_SOUND.SFX_LAST] of SfxFile.TSfxEntry;
  { the music's driver, which plays every effect with no recording too: SndOpl's, or with no OPL2 the speaker's }
  musicPlay: Types.TSoundPlay;
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
  { Words, so a 255-character BLASTER cannot wrap them }
  i: Word;
  v: Word;
  code: Integer;
  k: Word;
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

{ The 20-bit physical address of p. A native program has no DMA, nor physical addresses: 0. }
function Physical(p: Pointer): LongInt;
begin
{$IFDEF FPC}
  Physical := 0;
{$ELSE}
  Physical := LongInt(Seg(p^)) * 16 + Ofs(p^);
{$ENDIF}
end;

{ True when len bytes at p cross a 64 KB page, which one DMA transfer cannot. }
function Crosses(p: Pointer; len: Word): Boolean;
begin
  Crosses := (Physical(p) and $FFFF) + len > $10000;
end;

{ A block of size bytes that crosses no 64 KB page, or nil: blocks that cross one are held while another is tried, then
  freed. }
function PlaceBlock(size: Word): Pointer;
var
  held: array[1..PLACE_TRIES] of Pointer;
  nHeld: Byte;
  tries: Byte;
  i: Byte;
  p: Pointer;
begin
  nHeld := 0;
  p := nil;
  for tries := 1 to PLACE_TRIES do
    if (p = nil) and (MaxAvail >= size) then begin
      GetMem(p, size);
      if SndSb.Crosses(p, size) then begin
        Inc(nHeld);
        held[nHeld] := p;
        p := nil;
      end;
    end;
  for i := 1 to nHeld do
    FreeMem(held[i], size);
  PlaceBlock := p;
end;

{ Load SBSFX.DAT, then a bounce buffer for the longest sample that crosses a 64 KB page in it; on any failure of the
  file the store stays nil and the effects go to the speaker. }
procedure LoadEffects;
var
  count: Byte;
  i: Byte;
  e: SfxFile.TSfxEntry;
begin
  loadTried := True;
  FillChar(effects, SizeOf(effects), 0);
  if not SfxFile.Load(store, storeSize, count) then Exit;
  bounceSize := 0;
  for i := 1 to count do
    if SfxFile.GetEntry(store, storeSize, i - 1, e) then begin
      effects[e.tune] := e;
      if SndSb.Crosses(@store^[e.start], e.len) and (e.len > bounceSize) then
        bounceSize := e.len;
    end;
  if bounceSize > 0 then
    bounce := SndSb.PlaceBlock(bounceSize);
end;

{ Play the effect as one single-cycle DMA transfer: its bytes in place, or copied to the bounce buffer when they cross a
  64 KB page. False when it cannot be played (crossing, with no bounce buffer) or the DSP did not take the commands
  that start it. }
function PlayEffect(var e: SfxFile.TSfxEntry): Boolean;
var
  p: Pointer;
  phys: LongInt;
  b: Byte;
  ok: Boolean;
begin
  PlayEffect := False;
  p := @store^[e.start];
  if SndSb.Crosses(p, e.len) then begin
    if bounce = nil then Exit;
    Move(p^, bounce^, e.len);
    p := bounce;
  end;
  phys := SndSb.Physical(p);
  { acknowledge the last transfer's end, and stop one still playing (the commands that start this one say whether the
    DSP is there) }
  b := Port[base + DSP_READY];
  ok := DspWrite(DSP_HALT_DMA);
  Port[DMA_MASK] := DMA_MASK_ON or dma;
  Port[DMA_FLIP_FLOP] := 0;
  Port[DMA_MODE] := DMA_SINGLE_READ or dma;
  Port[DMA_ADDR[dma]] := Lo(Word(phys));
  Port[DMA_ADDR[dma]] := Hi(Word(phys));
  Port[DMA_PAGE[dma]] := phys shr 16;
  Port[DMA_COUNT[dma]] := Lo(e.len - 1);
  Port[DMA_COUNT[dma]] := Hi(e.len - 1);
  Port[DMA_MASK] := dma;
  ok := DspWrite(DSP_TIME_CONSTANT) and DspWrite(e.timeConstant);
  if e.format = C_SOUND.SFX_ADPCM4 then
    ok := ok and DspWrite(DSP_DMA_ADPCM4_REF)
  else
    ok := ok and DspWrite(DSP_DMA_8BIT);
  ok := ok and DspWrite(Lo(e.len - 1)) and DspWrite(Hi(e.len - 1));
  PlayEffect := ok;
end;

{ An effect with a sample on the DSP, the music's voices silenced first so the effect ends the music as every effect
  does; the music, any other effect, and silence as the music's driver plays them: SndOpl's (the music on the AdLib, the
  rest on the speaker), or with no OPL2 the speaker's. }
procedure Play(tune: Word);
var
  ok: Boolean;
begin
  if (tune >= 1) and (tune <= C_SOUND.SFX_LAST) then begin
    if not loadTried then
      SndSb.LoadEffects;
    if (store <> nil) and (effects[tune].start <> 0) then begin
      musicPlay(0);
      if SndSb.PlayEffect(effects[tune]) then
        Exit;
    end;
  end;
  if tune = 0 then
    ok := DspWrite(DSP_HALT_DMA);
  musicPlay(tune);
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
    { the card's OPL2 plays the music; without one it is the speaker's (SndOpl.Install leaves its mode and Play), and
      the effects still the DSP's }
    SndOpl.Install;
    musicPlay := GameVars.sound.Play;
    if GameVars.sound.mode = C_SOUND.MODE_ADLIB then
      GameVars.sound.name := 'Sound Blaster'
    else
      GameVars.sound.name := 'Blaster (no AdLib)';
    GameVars.sound.Play := SndSb.Play;
    GameVars.sound.singleStep := True;
    sbExitSaved := ExitProc;
    ExitProc := @SndSb.SbExit;
  end else begin
    SndOpl.Install;
    if GameVars.sound.mode = C_SOUND.MODE_ADLIB then
      GameVars.sound.name := 'AdLib (no Blaster)';
  end;
end;

begin
  store := nil;
  bounce := nil;
  loadTried := False;
end.

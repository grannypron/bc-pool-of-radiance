{ The startup advisory (#1173): a screen before the main menu saying that this is a modified version of the game, which
  GOG, Steam and SNEG can't help with, and where to send questions and bug reports instead, shown on the first start and
  after each new version; and, under DOS, whenever the speed check finds this computer slower than the game needs, how
  to raise DOSBox's cycles. AdvPlan decides which parts are due. }
{$O+,F+}
{$I COMPILER.INC}
unit Advisory;

interface

uses Types;

const
  { where questions and bug reports go: email only, as the forge's address does not fit in 40 columns }
  SUPPORT_EMAIL = 'talonius@brazencrows.com';

var
  { the PIT clocks the speed check's loop took (Measure); 0 when it did not run }
  speedClocks: LongInt;

{ The speed check (DOS only): time a fixed loop, about a tenth of a second at DOSBox's default speed, against the PIT,
  into speedClocks. Natively, or while the sound timer has the PIT at its own rate, speedClocks is 0. }
procedure Measure;

{ The speed check's time as the System page shows it: milliseconds to a tenth, SLOW after it when AdvPlan.SpeedSlow;
  N/A when it did not run. }
function SpeedText: Types.TStr20;

{ Draw s at column col of row in color in the game font, as TextRend.DisplayString does, but an '@' as AT_BITMAP, an at
  sign the font lacks: its 6-bit table has no place for one, and its glyph 64, the nearest, reads as a C (#1173). }
procedure DisplayText(col, row, color: Byte; s: string);

{ The advisory: when the support part (AdvPlan.SupportDue) or the speed part (AdvPlan.SpeedSlow) is due, a screen
  showing the parts due, held until a key; once the support part is shown, POOLOPT.CFG records the version
  (Options.SetAdvised). No screen when neither is due, nor under STING without ADVISE. }
procedure Show;

implementation

uses Crt, GameDefs, GameVars, TextRend, GameIo, SoundDrv, Options, AdvPlan, StrUtil;

const
  { The at sign DisplayText draws, in the font's 8x8 rows and its two-pixel strokes. Every video driver draws a glyph
    from gameFont as it stands, so DisplayText lends it AT_SLOT's rows for the one character: glyph 64, past the 64
    characters DisplayString reaches, which SSI's font draws as a C-like at sign. }
  AT_SLOT = 64;
  AT_BITMAP: array[0..7] of Byte = ($3C, $66, $DB, $DB, $DE, $C0, $7C, $00);
  { the text colours: the game's name, the version, the paragraphs, the address and the prompt }
  NAME_COLOR = Yellow;
  VERSION_COLOR = LightCyan;
  TEXT_COLOR = LightGreen;
  KEY_COLOR = White;
  { the paragraphs' column, and their lines }
  TEXT_COL = 1;
  PART_LINES = 4;

{$IFNDEF FPC}
const
  { The speed check's loop: CHUNKS runs of CHUNK_LOOPS passes, each run timed on its own, so that none outlasts the
    27.5 ms the PIT's counter takes to run down once (PitCount). 16 runs of 1700 passes take about a tenth of a second
    at DOSBox's default speed, 3000 cycles. }
  CHUNKS = 16;
  CHUNK_LOOPS = 1700;
  { the PIT clocks of one BIOS tick }
  TICK_CLOCKS = 65536;

var
  { the loop's result, kept so the loop is not empty }
  sink: Word;

{ PIT channel 0's counter, latched. At the BIOS's rate it runs in mode 3, down from 65536 by two a clock, twice a
  tick. }
function PitCount: Word;
var
  lo: Byte;
  hi: Byte;
begin
  inline($FA);  { cli }
  Port[$43] := 0;
  lo := Port[$40];
  hi := Port[$40];
  inline($FB);  { sti }
  PitCount := Word(hi) shl 8 or lo;
end;

{ One run of the speed check's loop. }
procedure Chunk;
var
  i: Word;
  x: Word;
begin
  x := 0;
  for i := 1 to CHUNK_LOOPS do
    x := (x xor i) + (x shr 3);
  sink := x;
end;
{$ENDIF}

procedure Measure;
{$IFNDEF FPC}
var
  n: Byte;
  before: Word;
  after: Word;
  total: LongInt;
  ticks: LongInt;
{$ENDIF}
begin
  speedClocks := 0;
{$IFNDEF FPC}
  { the sound timer runs the PIT faster than the BIOS, and its counter would wrap within a run }
  if SoundDrv.SoundTimerHooked then Exit;
  total := 0;
  ticks := TextRend.TickCount;
  for n := 1 to CHUNKS do begin
    before := PitCount;
    Chunk;
    after := PitCount;
    { the counter runs down by two a clock }
    Inc(total, ((LongInt(before) - after) and $FFFF) div 2);
  end;
  ticks := TextRend.TickCount - ticks;
  { a run longer than the counter's 27.5 ms reads short, on a computer far too slow; the BIOS ticks then give the time,
    to a tick (a reading below the start means the count restarted at midnight) }
  if (ticks > 0) and (ticks * TICK_CLOCKS > total + 2 * TICK_CLOCKS) then
    total := ticks * TICK_CLOCKS;
  if total < 1 then
    total := 1;
  speedClocks := total;
{$ENDIF}
end;

function SpeedText: Types.TStr20;
var
  tenths: LongInt;
  text: Types.TStr20;
begin
  if speedClocks = 0 then
    SpeedText := 'N/A'
  else begin
    { 1193.182 clocks a millisecond }
    tenths := (speedClocks * 10 + 596) div 1193;
    text := StrUtil.Grouped(tenths div 10) + '.' + Chr(Ord('0') + tenths mod 10) + ' ms';
    if AdvPlan.SpeedSlow(speedClocks) then
      text := text + ' SLOW';
    SpeedText := text;
  end;
end;

procedure DisplayText(col, row, color: Byte; s: string);
var
  i: Byte;
  r: Byte;
  saved: array[0..7] of Byte;
begin
  for i := 1 to Length(s) do begin
    if (s[i] = '@') and (GameVars.gameFont <> nil) then begin
      { AT_SLOT holds the at sign while it is drawn, and its own rows again after }
      for r := 0 to 7 do begin
        saved[r] := GameVars.gameFont^[AT_SLOT][r];
        GameVars.gameFont^[AT_SLOT][r] := AT_BITMAP[r];
      end;
      TextRend.RenderChar(col, row, color, Black, 1, AT_SLOT, 0);
      for r := 0 to 7 do
        GameVars.gameFont^[AT_SLOT][r] := saved[r];
    end else
      TextRend.RenderChar(col, row, color, Black, 1, Ord(s[i]), 1);
    Inc(col);
  end;
end;

procedure Show;
var
  support: Boolean;
  slow: Boolean;
  row: Byte;
  key: Char;
begin
  if GameVars.stingArg and not GameVars.adviseArg then Exit;
  support := AdvPlan.SupportDue(Options.AdvisedVersion, GameDefs.BUILD_VERSION);
  slow := AdvPlan.SpeedSlow(speedClocks);
  if not support and not slow then Exit;
  TextRend.ClearScreen;
  { the name, the version and the prompt, and a blank line and the lines of each part, centred on the screen's rows }
  row := (25 - 4 - (PART_LINES + 1) * (Ord(support) + Ord(slow))) div 2;
  TextRend.DisplayCentered(0, 39, row, NAME_COLOR, 'POOL OF RADIANCE');
  TextRend.DisplayCentered(0, 39, row + 1, VERSION_COLOR, 'this version: ' + GameDefs.BUILD_VERSION);
  Inc(row, 3);
  if support then begin
    Advisory.DisplayText(TEXT_COL, row, TEXT_COLOR, 'This is a modified version of the game.');
    Advisory.DisplayText(TEXT_COL, row + 1, TEXT_COLOR, 'GOG, Steam and SNEG can''t help with it.');
    Advisory.DisplayText(TEXT_COL, row + 2, TEXT_COLOR, 'Please send questions and bug reports');
    Advisory.DisplayText(TEXT_COL, row + 3, TEXT_COLOR, 'to ' + SUPPORT_EMAIL + '.');
    Inc(row, PART_LINES + 1);
  end;
  if slow then begin
    Advisory.DisplayText(TEXT_COL, row, TEXT_COLOR, 'This computer is running slower than');
    Advisory.DisplayText(TEXT_COL, row + 1, TEXT_COLOR, 'this version needs. In DOSBox, raise');
    Advisory.DisplayText(TEXT_COL, row + 2, TEXT_COLOR, 'the CPU cycles: cycles=max, or for');
    Advisory.DisplayText(TEXT_COL, row + 3, TEXT_COLOR, 'example cycles=fixed 20000.');
    Inc(row, PART_LINES + 1);
  end;
  TextRend.DisplayCentered(0, 39, row, KEY_COLOR, 'PRESS ANY KEY TO GO ON');
  key := GameIo.ReadAnyKey;
  while KeyPressed do
    GameIo.DiscardPendingKeys;
  if support then
    Options.SetAdvised(GameDefs.BUILD_VERSION);
  TextRend.ClearScreen;
end;

end.

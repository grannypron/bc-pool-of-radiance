{ The Command Keys window (#855): F1 on the map menus and the camp menu lists the keys that work there. The lines come
  from a table, so a key added later adds its line in one place, as F2's Bestiary (#842) did. }
{$O+,F+}
{$I COMPILER.INC}
unit KeyHelp;

interface

const
  { When a line shows: always; only where the menu takes quick save and load (the map menus); only while the
    Companion Tools setting is on; only under STING; only when POOL.CFG names a sound device. }
  SHOW_ALWAYS = 0;
  SHOW_QUICK = 1;
  SHOW_COMPANION = 2;
  SHOW_STING = 3;
  SHOW_SOUND = 4;
  { the table's lines }
  KEY_LINES = 7;

type
  { A line of the window: the key, padded to where its description starts, the description and when it shows. }
  TKeyLine = record
    key: string[7];
    what: string[16];
    show: Byte;
  end;

const
  { The lines, in the window's order. }
  KEYS: array[1..KEY_LINES] of TKeyLine = (
    (key: 'F1  '; what: 'This Screen'; show: SHOW_ALWAYS),
    (key: 'F2  '; what: 'Bestiary'; show: SHOW_ALWAYS),
    (key: 'F5  '; what: 'Quick Save'; show: SHOW_QUICK),
    (key: 'F6  '; what: 'Companion Tools'; show: SHOW_COMPANION),
    (key: 'F8  '; what: 'Quick Load'; show: SHOW_QUICK),
    (key: 'CTRL-S '; what: 'Sound On/Off'; show: SHOW_SOUND),
    (key: 'CTRL-Y '; what: 'Memory Stats'; show: SHOW_STING));

{ Whether table line n shows now, on a menu that takes F5 and F8 when quickKeys is set. }
function LineShown(n: Byte; quickKeys: Boolean): Boolean;

{ Clear the screen and show the Command Keys window at its top, framed as the Settings screen is and as tall as the
  lines LineShown gives, until Exit or Escape on the 'Help:' line. quickKeys: the menu it was opened from takes F5 and
  F8. The caller redraws its screen afterwards. }
procedure ShowKeys(quickKeys: Boolean);

implementation

uses {$IFDEF FPC}TpCompat, {$ENDIF}Crt, C_KEYS, C_SOUND, GameVars, TextRend, Border, MenuCore;

const
  { The window's frame and rows, as the Settings screen's: the title on TOP_ROW, a blank row, the lines from FIRST_ROW
    and a blank row after them. Keys start at KEY_COL. }
  LEFT_COL = 1;
  RIGHT_COL = 38;
  TOP_ROW = 1;
  FIRST_ROW = TOP_ROW + 2;
  KEY_COL = 2;
  TITLE_COLOR = White;
  KEY_COLOR = White;
  LINE_COLOR = LightGreen;

function LineShown(n: Byte; quickKeys: Boolean): Boolean;
begin
  case KEYS[n].show of
    SHOW_QUICK: LineShown := quickKeys;
    SHOW_COMPANION: LineShown := GameVars.companionOn <> 0;
    SHOW_STING: LineShown := GameVars.stingArg;
    SHOW_SOUND: LineShown := GameVars.sound.mode <> C_SOUND.MODE_DISABLED;
  else
    LineShown := True;
  end;
end;

procedure ShowKeys(quickKeys: Boolean);
var
  n: Byte;
  count: Byte;
  row: Byte;
  ch: Char;
  ext: Boolean;
  savedChoice: Byte;
begin
  savedChoice := GameVars.horizChoice;
  count := 0;
  for n := 1 to KEY_LINES do
    if KeyHelp.LineShown(n, quickKeys) then
      Inc(count);
  { the whole screen, as a window over the map's would run into its frames }
  Border.ClearBox(0, 0, 39, 23);
  Border.DrawBorder(LEFT_COL, TOP_ROW, RIGHT_COL, FIRST_ROW + count, 0);
  TextRend.DisplayCentered(LEFT_COL, RIGHT_COL, TOP_ROW, TITLE_COLOR, 'Command Keys');
  row := FIRST_ROW;
  for n := 1 to KEY_LINES do
    if KeyHelp.LineShown(n, quickKeys) then begin
      TextRend.DisplayString(KEY_COL, row, KEY_COLOR, KEYS[n].key);
      TextRend.DisplayString(KEY_COL + Length(KEYS[n].key), row, LINE_COLOR, KEYS[n].what);
      Inc(row);
    end;
  repeat
    { F1 here is this window already }
    MenuCore.helpToCaller := True;
    ch := MenuCore.MenuHorizontal('Help: ', 'Exit', LightMagenta, LightGreen, White, False, False, ext);
  until not ext and (ch in [C_KEYS.NONE, 'E']);
  TextRend.ClearBottomLine;
  GameVars.horizChoice := savedChoice;
end;

end.

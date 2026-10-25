{ The Command Keys window (#855): F1 on the map menus and the camp menu lists the keys that work there. The lines come
  from a table, so a key added later adds its line in one place, as F2's Bestiary (#842) did. }
{$O+,F+}
{$I COMPILER.INC}
unit KeyHelp;

interface

const
  { When a line shows: always; only where the menu takes quick save and load (the map menus); only while the
    Companion Tools setting is on; only under STING; only when POOL.CFG names a sound device; only while the Combat Log
    setting is on (#903). }
  SHOW_ALWAYS = 0;
  SHOW_QUICK = 1;
  SHOW_COMPANION = 2;
  SHOW_STING = 3;
  SHOW_SOUND = 4;
  SHOW_LOG = 5;
  { the table's lines }
  KEY_LINES = 8;

type
  { A line of the window: the key, padded to where its description starts, the description and when it shows. }
  TKeyLine = record
    key: string[7];
    what: string[24];
    show: Byte;
  end;

const
  { The lines, in the window's order. }
  KEYS: array[1..KEY_LINES] of TKeyLine = (
    (key: 'F1  '; what: 'This Screen'; show: SHOW_ALWAYS),
    (key: 'F2  '; what: 'Bestiary'; show: SHOW_ALWAYS),
    (key: 'F5  '; what: 'Quick Save'; show: SHOW_QUICK),
    (key: 'F6  '; what: 'Companion Tools'; show: SHOW_COMPANION),
    (key: 'F7  '; what: 'Action Log (Combat Only)'; show: SHOW_LOG),
    (key: 'F8  '; what: 'Quick Load'; show: SHOW_QUICK),
    (key: 'CTRL-S '; what: 'Sound On/Off'; show: SHOW_SOUND),
    (key: 'CTRL-Y '; what: 'Memory Stats'; show: SHOW_STING));

{ Whether table line n shows now, on a menu that takes F5 and F8 when quickKeys is set. }
function LineShown(n: Byte; quickKeys: Boolean): Boolean;

{ Clear the screen and show the Command Keys window full screen, framed as the Quests page and the Load/Save menu are: a
  title box over a box to the bottom of the screen holding the lines LineShown gives, the function keys and then, after
  a blank row, the Ctrl keys, until Exit or Escape on the 'Help:' line. quickKeys: the menu it was opened from takes F5
  and F8. The caller redraws its screen afterwards. }
procedure ShowKeys(quickKeys: Boolean);

implementation

uses {$IFDEF FPC}TpCompat, {$ENDIF}Crt, C_KEYS, C_SOUND, GameVars, TextRend, Border, MenuCore;

const
  { The window's frame and rows, as the Quests page's (#855): the title box on TITLE_ROW, the lines' box from LIST_TOP
    to BOTTOM_ROW, and the lines from a blank row into it. Keys start at KEY_COL. }
  LEFT_COL = 1;
  RIGHT_COL = 38;
  TITLE_ROW = 1;
  LIST_TOP = 3;
  BOTTOM_ROW = 22;
  FIRST_ROW = LIST_TOP + 1;
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
    SHOW_LOG: LineShown := GameVars.combatLogOn <> 0;
  else
    LineShown := True;
  end;
end;

procedure ShowKeys(quickKeys: Boolean);
var
  n: Byte;
  row: Byte;
  { the first character of the last line shown: F for a function key, C for a Ctrl key }
  group: Char;
  ch: Char;
  ext: Boolean;
  savedChoice: Byte;
begin
  savedChoice := GameVars.horizChoice;
  { the whole screen, as a window over the map's would run into its frames; the lines' box first, then the title's, so
    the corners stay where the borders meet }
  Border.ClearBox(0, 0, 39, 23);
  Border.DrawBorder(LEFT_COL, LIST_TOP, RIGHT_COL, BOTTOM_ROW, 0);
  Border.DrawBorder(LEFT_COL, TITLE_ROW, RIGHT_COL, TITLE_ROW, 0);
  TextRend.DisplayCentered(LEFT_COL, RIGHT_COL, TITLE_ROW, TITLE_COLOR, 'Command Keys');
  row := FIRST_ROW;
  group := ' ';
  for n := 1 to KEY_LINES do
    if KeyHelp.LineShown(n, quickKeys) then begin
      { a blank row between the function keys and the Ctrl keys }
      if (group <> ' ') and (KEYS[n].key[1] <> group) then
        Inc(row);
      group := KEYS[n].key[1];
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

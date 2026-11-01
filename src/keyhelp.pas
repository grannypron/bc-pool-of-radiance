{ Implements the Command Keys window opened with F1 from the map and camp
  menus (#855). Key descriptions live in one table so new commands only need
  to be added in one place. }
{$O+,F+}
{$I COMPILER.INC}
unit KeyHelp;

interface

const
  { Conditions that control whether a help line is visible. }
  SHOW_ALWAYS = 0;
  SHOW_QUICK = 1;
  SHOW_COMPANION = 2;
  SHOW_STING = 3;
  SHOW_SOUND = 4;
  SHOW_LOG = 5;
  { Number of entries in KEYS. }
  KEY_LINES = 16;

type
  { One row in the help window. }
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
    (key: 'ALT-1  '; what: 'View PC 1''s inventory'; show: SHOW_ALWAYS),
    (key: 'ALT-2  '; what: 'View PC 2''s inventory'; show: SHOW_ALWAYS),
    (key: 'ALT-3  '; what: 'View PC 3''s inventory'; show: SHOW_ALWAYS),
    (key: 'ALT-4  '; what: 'View PC 4''s inventory'; show: SHOW_ALWAYS),
    (key: 'ALT-5  '; what: 'View PC 5''s inventory'; show: SHOW_ALWAYS),
    (key: 'ALT-6  '; what: 'View PC 6''s inventory'; show: SHOW_ALWAYS),
    (key: 'ALT-7  '; what: 'View PC 7''s inventory'; show: SHOW_ALWAYS),
    (key: 'ALT-8  '; what: 'View PC 8''s inventory'; show: SHOW_ALWAYS),
    (key: 'CTRL-S '; what: 'Sound On/Off'; show: SHOW_SOUND),
    (key: 'CTRL-Y '; what: 'Memory Stats'; show: SHOW_STING));

{ Returns whether help line n applies to the current settings and menu. }
function LineShown(n: Byte; quickKeys: Boolean): Boolean;

{ Shows the full-screen Command Keys window until Exit or Escape. quickKeys is
  True when the calling menu supports F5/F8 quick save and load. The caller is
  responsible for redrawing its screen afterward. }
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
  { the first character of the last line shown: F for a function key, A for an Alt key, C for a Ctrl key }
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
      { a blank row between groups: the function keys, the Alt keys (#1175) and the Ctrl keys }
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

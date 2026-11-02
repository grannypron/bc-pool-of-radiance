{ The party menu's commands, in its two forms. The start-up menu, after the title screen and after the party is
  destroyed, is SSI's: one column under the roster, only the commands offered, each by its first letter (#885). The
  menu of a training hall in a game in play is in two columns, PARTY and GAME on the left and CHARACTER on the right,
  with Settings and Exit to DOS on a row of their own, Begin Adventuring at the foot and the version on the bottom
  line (mocks/training-hall.txt, #879, #885). CharGen.MainMenu says which commands are offered and carries them out.
  Overlaid. }
{$O+,F+}
{$I COMPILER.INC}
unit PartyMnu;

interface

const
  { the commands, in the order the highlight of the two-column menu moves down through them: the left column (PARTY,
    GAME, Settings and Begin Adventuring), then the right (CHARACTER and Exit to DOS) }
  CMD_ADD = 0;
  CMD_REMOVE = 1;
  CMD_SAVE = 2;
  CMD_LOAD = 3;
  CMD_SETTINGS = 4;
  CMD_BEGIN = 5;
  CMD_CREATE = 6;
  CMD_VIEW = 7;
  CMD_MODIFY = 8;
  CMD_DROP = 9;
  CMD_TRAIN = 10;
  CMD_DUAL = 11;
  CMD_EXIT = 12;
  CMD_LAST = 12;
  { each command's key, by command (index CMD_ + 1), as the two-column menu's Command Key has them }
  cmdKeys: string[CMD_LAST + 1] = 'ARSLGBCVMDTUE';
  { the row of the PARTY and CHARACTER headings under a roster of up to five, as the mock-up has it (#1071) }
  MENU_TOP = 10;
  { the row of SSI's menu's first command, under a roster of up to eight }
  LIST_TOP = 12;

type
  TCmdSet = set of CMD_ADD..CMD_LAST;

{ The commands the party menu offers: Create, Add, Settings and Exit to DOS always; with a character selected View,
  Modify, Drop, Remove, Save and Begin Adventuring, Train with a training hall here or free training on (atHall, #765),
  and Dual Class on the two-column menu (inGame); with none, Load. SSI's start-up menu never offers Dual Class (#885),
  and the two-column menu does not without a character, who would be the one to change class. Train Anywhere's menu
  (anywhere, #1212) offers Train, View and Dual Class with a character, and Exit, which leaves it (ExitLeaves): the
  rest would add, drop or remake characters, or load and save, away from the hall. }
procedure OfferedCmds(hasChar, atHall, inGame, anywhere: Boolean; var offered: TCmdSet);

{ True when offered is Train Anywhere's menu (OfferedCmds), told by its Exit without Settings, which every other form
  offers: Exit is then drawn 'Exit' and leaves the menu, and Escape chooses it. }
function ExitLeaves(offered: TCmdSet): Boolean;

{ The row of the PARTY and CHARACTER headings under a roster of members creatures (CharDisp.DisplayParty's, from row 4
  on the two-column menu, #1071): MENU_TOP, or lower, so a blank row stays between, for a party of six or seven. Under
  eight there is no room for the blank row: the headings follow the roster at once, so Begin Adventuring stays in the
  window. }
function MenuTop(members: Byte): Byte;

{ Returns the screen row for cmd when the headings are on row top. }
function CmdRow(cmd, top: Byte): Byte;

{ Finds the next offered command in the requested vertical direction, wrapping
  between the first and last commands. Returns cmd if no other command is
  offered. }
function StepCmd(offered: TCmdSet; cmd: Byte; step: ShortInt): Byte;

{ Finds the offered command nearest cmd's row in the other column. Ties choose
  the upper command; if the other column is empty, cmd is returned. }
function OtherColumn(offered: TCmdSet; cmd, top: Byte): Byte;

{ Draw the two-column menu with the headings on row top: the headings in light magenta, so the highlighted command
  stands out (#1071), a command offered in light green with its key in white, cur in inverse video (black on white,
  #1160), and one not offered in dark gray. }
procedure Draw(offered: TCmdSet; top, cur: Byte);

{ Wait for a command of the two-column menu with the version (GameDefs.GAME_VERSION) on the bottom line. Up and Down
  move the highlight (cur, a command offered, as Draw drew it) through the commands offered, and Left and Right
  between the columns (StepCmd, OtherColumn). A command's key (cmdKeys), or Enter for cur, returns that key when the
  command is offered, and makes it cur; a key of one not offered is ignored, and so are Escape and Space. J (CharGen's
  free training) returns J. Any other extended key, such as Home and End, returns its scan code with ext set. On Train
  Anywhere's menu (ExitLeaves) Escape returns Exit's key. }
function ChooseCmd(offered: TCmdSet; top: Byte; var cur: Byte; var ext: Boolean): Char;

{ The row of SSI's menu's first command when count are listed: LIST_TOP, or higher so the last stays in the window. }
function ListTop(count: Byte): Byte;

{ Draw SSI's menu: the commands of offered in SSI's order, one to a row from ListTop, the first letter in white and
  the rest in light green, as START.EXE drew them. }
procedure DrawList(offered: TCmdSet);

{ Wait for a command of SSI's menu with 'pool of radiance' and the version on the bottom line, as before #879. The
  first letter of a command listed returns that command's key in cmdKeys; a letter of one not listed is ignored, and
  so are Escape, Space and Enter. J (CharGen's free training) returns J, and an extended key, such as Home, End, Up
  and Down, its scan code with ext set. With idle set (no party, and the demo there), C_DEMO.IDLE_TIME without a
  command returns C_DEMO.START_KEY, for the demo (#1109); under DEMO (GameVars.demoArg), after C_DEMO.ARG_IDLE_TIME. }
function ChooseListed(offered: TCmdSet; idle: Boolean; var ext: Boolean): Char;

implementation

uses Crt, C_KEYS, C_MSG, C_DEMO, GameDefs, GameVars, MenuCore, StrUtil, TextRend;

const
  cmdNames: array[CMD_ADD..CMD_LAST] of string[17] = (
    'Add', 'Remove', 'Save', 'Load', 'Settings', 'Begin Adventuring', 'Create', 'View', 'Modify', 'Drop', 'Train',
    'Dual Class', 'Exit to DOS');
  { each command's row below the headings', and its column }
  cmdRows: array[CMD_ADD..CMD_LAST] of Byte = (1, 2, 5, 6, 8, 10, 1, 2, 3, 4, 5, 6, 8);
  cmdCols: array[CMD_ADD..CMD_LAST] of Byte = (4, 4, 4, 4, 2, 2, 22, 22, 22, 22, 22, 22, 20);
  { the columns of the headings }
  LEFT_HEAD_COL = 2;
  RIGHT_HEAD_COL = 20;
  { the GAME heading's row below the PARTY heading's }
  GAME_HEAD_ROW = 4;
  { the row of the roster's first member (CharDisp.DisplayParty's, its headers two rows above) }
  ROSTER_ROW = 4;
  { the commands of the left column; the others are the right's }
  leftCmds: TCmdSet = [CMD_ADD..CMD_BEGIN];
  { SSI's menu: its commands in its order, and their names (START.EXE's, with the port's Game Settings); Dual Class is
    on the training hall's menu alone }
  LIST_LAST = 11;
  listCmds: array[0..LIST_LAST] of Byte = (CMD_CREATE, CMD_DROP, CMD_MODIFY, CMD_TRAIN, CMD_VIEW, CMD_ADD,
    CMD_REMOVE, CMD_LOAD, CMD_SAVE, CMD_BEGIN, CMD_SETTINGS, CMD_EXIT);
  listNames: array[0..LIST_LAST] of string[27] = (
    'Create New Character', 'Drop Character', 'Modify Character', 'Train Character', 'View Character',
    'Add Character to Party', 'Remove Character from Party', 'Load Saved Game', 'Save Current Game',
    'BEGIN Adventuring', 'Game Settings', 'Exit to DOS');
  { SSI's menu's keys, given as the bottom-line menu's options in black so that none shows }
  LIST_KEYS = 'C D M T V A R L S B G E J';

procedure OfferedCmds(hasChar, atHall, inGame, anywhere: Boolean; var offered: TCmdSet);
begin
  if anywhere then begin
    offered := [CMD_EXIT];
    if hasChar then
      offered := offered + [CMD_TRAIN, CMD_VIEW, CMD_DUAL];
    Exit;
  end;
  offered := [CMD_CREATE, CMD_ADD, CMD_SETTINGS, CMD_EXIT];
  if hasChar then begin
    offered := offered + [CMD_VIEW, CMD_MODIFY, CMD_DROP, CMD_REMOVE, CMD_SAVE, CMD_BEGIN];
    if atHall then
      offered := offered + [CMD_TRAIN];
    if inGame then
      offered := offered + [CMD_DUAL];
  end else
    offered := offered + [CMD_LOAD];
end;

function ExitLeaves(offered: TCmdSet): Boolean;
begin
  ExitLeaves := (CMD_EXIT in offered) and not (CMD_SETTINGS in offered);
end;

function MenuTop(members: Byte): Byte;
var
  top: Byte;
begin
  { the members from ROSTER_ROW, then a blank row }
  top := ROSTER_ROW + members + 1;
  if top < MENU_TOP then
    top := MENU_TOP;
  if top + cmdRows[CMD_BEGIN] > C_MSG.TEXT_BOTTOM then
    top := C_MSG.TEXT_BOTTOM - cmdRows[CMD_BEGIN];
  MenuTop := top;
end;

function CmdRow(cmd, top: Byte): Byte;
begin
  CmdRow := top + cmdRows[cmd];
end;

function StepCmd(offered: TCmdSet; cmd: Byte; step: ShortInt): Byte;
var
  n: Byte;
  k: Byte;
begin
  StepCmd := cmd;
  n := cmd;
  for k := 1 to CMD_LAST do begin
    n := (n + CMD_LAST + 1 + step) mod (CMD_LAST + 1);
    if n in offered then begin
      StepCmd := n;
      Exit;
    end;
  end;
end;

function OtherColumn(offered: TCmdSet; cmd, top: Byte): Byte;
var
  c: Byte;
  best: Integer;
  dist: Integer;
  row: Integer;
begin
  OtherColumn := cmd;
  best := MaxInt;
  row := PartyMnu.CmdRow(cmd, top);
  { CmdRow rises with the command within a column, so the first of two as near is the upper }
  for c := CMD_ADD to CMD_LAST do
    if (c in offered) and ((c in leftCmds) <> (cmd in leftCmds)) then begin
      dist := Abs(PartyMnu.CmdRow(c, top) - row);
      if dist < best then begin
        best := dist;
        OtherColumn := c;
      end;
    end;
end;

{ Draw command cmd of the two-column menu: offered in light green with its key in white, or in inverse video (black on
  white) as the highlighted one, or dark gray when not offered. }
procedure DrawCmd(offered: TCmdSet; top, cmd, cur: Byte);
var
  col: Byte;
  row: Byte;
  i: Byte;
  name: string[17];
begin
  name := cmdNames[cmd];
  if (cmd = CMD_EXIT) and PartyMnu.ExitLeaves(offered) then
    name := 'Exit';
  row := PartyMnu.CmdRow(cmd, top);
  col := cmdCols[cmd];
  if not (cmd in offered) then
    TextRend.DisplayString(col, row, DarkGray, name)
  else if cmd = cur then
    TextRend.DisplayStringOn(col, row, Black, White, name)
  else begin
    TextRend.DisplayString(col, row, LightGreen, name);
    i := 1;
    while UpCase(name[i]) <> cmdKeys[cmd + 1] do
      Inc(i);
    TextRend.DisplayString(col + i - 1, row, White, name[i]);
  end;
end;

procedure Draw(offered: TCmdSet; top, cur: Byte);
var
  cmd: Byte;
begin
  TextRend.DisplayString(LEFT_HEAD_COL, top, LightMagenta, 'Party');
  TextRend.DisplayString(LEFT_HEAD_COL, top + GAME_HEAD_ROW, LightMagenta, 'Game');
  TextRend.DisplayString(RIGHT_HEAD_COL, top, LightMagenta, 'Character');
  for cmd := CMD_ADD to CMD_LAST do
    PartyMnu.DrawCmd(offered, top, cmd, cur);
end;

function ChooseCmd(offered: TCmdSet; top: Byte; var cur: Byte; var ext: Boolean): Char;
var
  ch: Char;
  was: Byte;
  cmd: Byte;
begin
  repeat
    was := cur;
    MenuCore.arrowsToCaller := True;
    MenuCore.enterToCaller := True;
    MenuCore.extraKeys := cmdKeys + 'J';
    ch := MenuCore.MenuHorizontal(StrUtil.PadLeft(GameDefs.GAME_VERSION, 40), '', Cyan, 0, White, True, False, ext);
    if ext then begin
      case ch of
        C_KEYS.UP: cur := PartyMnu.StepCmd(offered, cur, -1);
        C_KEYS.DOWN: cur := PartyMnu.StepCmd(offered, cur, 1);
        C_KEYS.LEFT, C_KEYS.RIGHT: cur := PartyMnu.OtherColumn(offered, cur, top);
      else
        ChooseCmd := ch;
        Exit;
      end;
    end else if ch = C_KEYS.ENTER then begin
      ChooseCmd := cmdKeys[cur + 1];
      Exit;
    end else if ch = 'J' then begin
      ChooseCmd := ch;
      Exit;
    end else if (ch = C_KEYS.NONE) and PartyMnu.ExitLeaves(offered) then begin
      ChooseCmd := cmdKeys[CMD_EXIT + 1];
      Exit;
    end else begin
      cmd := Pos(ch, cmdKeys);
      if (ch <> C_KEYS.NONE) and (cmd > 0) and (cmd - 1 in offered) then begin
        cur := cmd - 1;
        PartyMnu.DrawCmd(offered, top, was, cur);
        PartyMnu.DrawCmd(offered, top, cur, cur);
        ChooseCmd := ch;
        Exit;
      end;
    end;
    if cur <> was then begin
      PartyMnu.DrawCmd(offered, top, was, cur);
      PartyMnu.DrawCmd(offered, top, cur, cur);
    end;
  until False;
end;

function ListTop(count: Byte): Byte;
begin
  if LIST_TOP + count - 1 > C_MSG.TEXT_BOTTOM then
    ListTop := C_MSG.TEXT_BOTTOM + 1 - count
  else
    ListTop := LIST_TOP;
end;

procedure DrawList(offered: TCmdSet);
var
  i: Byte;
  count: Byte;
  row: Byte;
begin
  count := 0;
  for i := 0 to LIST_LAST do
    if listCmds[i] in offered then
      Inc(count);
  row := PartyMnu.ListTop(count);
  for i := 0 to LIST_LAST do
    if listCmds[i] in offered then begin
      TextRend.DisplayString(2, row, White, listNames[i][1]);
      TextRend.DisplayString(3, row, LightGreen, Copy(listNames[i], 2, Length(listNames[i]) - 1));
      Inc(row);
    end;
end;

function ChooseListed(offered: TCmdSet; idle: Boolean; var ext: Boolean): Char;
var
  ch: Char;
  i: Byte;
begin
  repeat
    { the wait for a command ends in the demo, sooner the first time under DEMO (#1109) }
    if idle then begin
      if GameVars.demoArg then
        MenuCore.menuTimeout := C_DEMO.ARG_IDLE_TIME
      else
        MenuCore.menuTimeout := C_DEMO.IDLE_TIME;
      MenuCore.menuDefaultKey := C_DEMO.START_KEY;
    end;
    ch := MenuCore.MenuHorizontal('pool of radiance ' + GameDefs.GAME_VERSION, LIST_KEYS, Cyan, Black, Black, True,
                                  False, ext);
    if ext or (ch = 'J') or (ch = C_DEMO.START_KEY) then begin
      ChooseListed := ch;
      Exit;
    end;
    if ch <> C_KEYS.NONE then
      for i := 0 to LIST_LAST do
        if (listCmds[i] in offered) and (listNames[i][1] = ch) then begin
          ChooseListed := cmdKeys[listCmds[i] + 1];
          Exit;
        end;
  until False;
end;

end.

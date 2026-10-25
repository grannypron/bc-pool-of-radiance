{ The party menu's commands (#879): the start-up screen's and the training halls' menu under the party roster, in two
  columns, CHARACTER on the left and PARTY and GAME on the right, with Begin Adventuring at the foot of the window and
  the version on the bottom line (mocks/training-hall.txt). It replaces SSI's single column, which ran off the window
  at a hall with a human selected. CharGen.MainMenu says which commands are offered and carries them out. Overlaid. }
{$O+,F+}
{$I COMPILER.INC}
unit PartyMnu;

interface

const
  { the commands, in the order the highlight moves down through them: the CHARACTER column, then PARTY and GAME, then
    Begin Adventuring }
  CMD_CREATE = 0;
  CMD_VIEW = 1;
  CMD_MODIFY = 2;
  CMD_DROP = 3;
  CMD_TRAIN = 4;
  CMD_DUAL = 5;
  CMD_ADD = 6;
  CMD_REMOVE = 7;
  CMD_SAVE = 8;
  CMD_LOAD = 9;
  CMD_SETTINGS = 10;
  CMD_EXIT = 11;
  CMD_BEGIN = 12;
  CMD_LAST = 12;
  { each command's key, by command (index CMD_ + 1) }
  cmdKeys: string[CMD_LAST + 1] = 'CVMDTUARSLGEB';
  { the row of the CHARACTER and PARTY headings under a roster of up to five, as the mock-up has it }
  MENU_TOP = 8;

type
  TCmdSet = set of CMD_CREATE..CMD_LAST;

{ The row of the CHARACTER and PARTY headings under a roster of members creatures (CharDisp.DisplayParty's, from row 2
  on the party menu): MENU_TOP, or lower, so a blank row stays between, for a party of six to eight. }
function MenuTop(members: Byte): Byte;

{ The row of command cmd with the headings on row top: Begin Adventuring's is the window's last, whatever top is. }
function CmdRow(cmd, top: Byte): Byte;

{ The next command of offered from cmd, down the columns (step 1) or up them (step -1), wrapping from Begin
  Adventuring to Create and back; cmd when no other is offered. }
function StepCmd(offered: TCmdSet; cmd: Byte; step: ShortInt): Byte;

{ The command of offered in the other column (Begin Adventuring is in the CHARACTER column) whose row is nearest cmd's,
  the upper of two as near; cmd when that column offers none. }
function OtherColumn(offered: TCmdSet; cmd, top: Byte): Byte;

{ Draw the headings (white) and the commands with the headings on row top: a command offered in light green with its
  key in white, cur wholly in white, and one not offered in dark gray. }
procedure Draw(offered: TCmdSet; top, cur: Byte);

{ Wait for a command with the version (GameDefs.GAME_VERSION) on the bottom line. Up and Down move the highlight
  (cur, a command offered, as Draw drew it) through the commands offered, and Left and Right between the columns
  (StepCmd, OtherColumn). A command's key (cmdKeys), or Enter for cur, returns that key when the command is offered,
  and makes it cur; a key of one not offered is ignored, and so are Escape and Space. J (CharGen's free training)
  returns J. Any other extended key, such as Home and End, returns its scan code with ext set. }
function ChooseCmd(offered: TCmdSet; top: Byte; var cur: Byte; var ext: Boolean): Char;

implementation

uses Crt, C_KEYS, C_MSG, GameDefs, MenuCore, StrUtil, TextRend;

const
  cmdNames: array[CMD_CREATE..CMD_LAST] of string[17] = (
    'Create', 'View', 'Modify', 'Drop', 'Train', 'Dual Class', 'Add', 'Remove', 'Save', 'Load', 'Settings',
    'Exit to DOS', 'Begin Adventuring');
  { each command's row below the headings' (Begin Adventuring's is the window's last) }
  cmdRows: array[CMD_CREATE..CMD_EXIT] of Byte = (1, 2, 3, 4, 5, 6, 1, 2, 5, 6, 7, 8);
  { the columns of the headings and commands }
  LEFT_HEAD_COL = 2;
  LEFT_COL = 4;
  RIGHT_HEAD_COL = 20;
  RIGHT_COL = 22;
  { the GAME heading's row below the PARTY heading's }
  GAME_HEAD_ROW = 4;
  { the commands of the CHARACTER column; the others are the PARTY and GAME column's }
  leftCmds: TCmdSet = [CMD_CREATE..CMD_DUAL, CMD_BEGIN];

function MenuTop(members: Byte): Byte;
begin
  if members + 3 > MENU_TOP then
    MenuTop := members + 3
  else
    MenuTop := MENU_TOP;
end;

function CmdRow(cmd, top: Byte): Byte;
begin
  if cmd = CMD_BEGIN then
    CmdRow := C_MSG.TEXT_BOTTOM
  else
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
  for c := CMD_CREATE to CMD_LAST do
    if (c in offered) and ((c in leftCmds) <> (cmd in leftCmds)) then begin
      dist := Abs(PartyMnu.CmdRow(c, top) - row);
      if dist < best then begin
        best := dist;
        OtherColumn := c;
      end;
    end;
end;

{ Draw command cmd: offered in light green with its key in white, or wholly white as the highlighted one, or dark gray
  when not offered. }
procedure DrawCmd(offered: TCmdSet; top, cmd, cur: Byte);
var
  col: Byte;
  row: Byte;
  i: Byte;
  name: string[17];
begin
  name := cmdNames[cmd];
  row := PartyMnu.CmdRow(cmd, top);
  if cmd = CMD_BEGIN then
    col := LEFT_HEAD_COL
  else if cmd in leftCmds then
    col := LEFT_COL
  else
    col := RIGHT_COL;
  if not (cmd in offered) then
    TextRend.DisplayString(col, row, DarkGray, name)
  else if cmd = cur then
    TextRend.DisplayString(col, row, White, name)
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
  TextRend.DisplayString(LEFT_HEAD_COL, top, White, 'Character');
  TextRend.DisplayString(RIGHT_HEAD_COL, top, White, 'Party');
  TextRend.DisplayString(RIGHT_HEAD_COL, top + GAME_HEAD_ROW, White, 'Game');
  for cmd := CMD_CREATE to CMD_LAST do
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

end.

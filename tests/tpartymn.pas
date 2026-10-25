{ Tests for the party menu's layout and highlight (PartyMnu, #879): where the headings go under the roster
  (MenuTop), the commands' rows (CmdRow), Up and Down through the commands offered (StepCmd) and Left and Right between
  the columns (OtherColumn). }
{$I COMPILER.INC}
program TPartyMn;

uses C_MSG, PartyMnu, TestKit;

var
  all: PartyMnu.TCmdSet;
  start: PartyMnu.TCmdSet;
  hall: PartyMnu.TCmdSet;

begin
  TestKit.Start('TPARTYMN');
  all := [PartyMnu.CMD_CREATE..PartyMnu.CMD_LAST];
  { no party: Create, Dual Class, Add, Load, Settings and Exit to DOS }
  start := [PartyMnu.CMD_CREATE, PartyMnu.CMD_DUAL, PartyMnu.CMD_ADD, PartyMnu.CMD_LOAD, PartyMnu.CMD_SETTINGS,
            PartyMnu.CMD_EXIT];
  { a party away from a hall: all but Train and Load }
  hall := all - [PartyMnu.CMD_TRAIN, PartyMnu.CMD_LOAD];

  { the layout }
  TestKit.CheckEqualsL(8, PartyMnu.MenuTop(0), 'the headings on row 8 with no party');
  TestKit.CheckEqualsL(8, PartyMnu.MenuTop(5), 'and under five, as the mock-up has them');
  TestKit.CheckEqualsL(9, PartyMnu.MenuTop(6), 'a row lower under six, a blank row between');
  TestKit.CheckEqualsL(11, PartyMnu.MenuTop(8), 'and on row 11 under eight');
  TestKit.CheckEqualsL(9, PartyMnu.CmdRow(PartyMnu.CMD_CREATE, 8), 'Create under CHARACTER');
  TestKit.CheckEqualsL(14, PartyMnu.CmdRow(PartyMnu.CMD_DUAL, 8), 'Dual Class on row 14');
  TestKit.CheckEqualsL(9, PartyMnu.CmdRow(PartyMnu.CMD_ADD, 8), 'Add beside Create');
  TestKit.CheckEqualsL(13, PartyMnu.CmdRow(PartyMnu.CMD_SAVE, 8), 'Save under GAME, beside Train');
  TestKit.CheckEqualsL(16, PartyMnu.CmdRow(PartyMnu.CMD_EXIT, 8), 'Exit to DOS on row 16');
  TestKit.CheckEqualsL(19, PartyMnu.CmdRow(PartyMnu.CMD_EXIT, 11), 'and on row 19 under a party of eight');
  TestKit.CheckEqualsL(C_MSG.TEXT_BOTTOM, PartyMnu.CmdRow(PartyMnu.CMD_BEGIN, 11),
                       'Begin Adventuring on the window''s last row, wherever the headings are');
  TestKit.CheckEqualsS('U', PartyMnu.cmdKeys[PartyMnu.CMD_DUAL + 1], 'Dual Class is U');
  TestKit.CheckEqualsS('G', PartyMnu.cmdKeys[PartyMnu.CMD_SETTINGS + 1], 'Settings is G');
  TestKit.CheckEqualsS('B', PartyMnu.cmdKeys[PartyMnu.CMD_BEGIN + 1], 'Begin Adventuring is B');

  { Up and Down }
  TestKit.CheckEqualsL(PartyMnu.CMD_VIEW, PartyMnu.StepCmd(all, PartyMnu.CMD_CREATE, 1), 'Down from Create is View');
  TestKit.CheckEqualsL(PartyMnu.CMD_ADD, PartyMnu.StepCmd(all, PartyMnu.CMD_DUAL, 1),
                       'down the CHARACTER column, then the PARTY column');
  TestKit.CheckEqualsL(PartyMnu.CMD_BEGIN, PartyMnu.StepCmd(all, PartyMnu.CMD_EXIT, 1), 'Exit to DOS, then Begin');
  TestKit.CheckEqualsL(PartyMnu.CMD_CREATE, PartyMnu.StepCmd(all, PartyMnu.CMD_BEGIN, 1), 'and back to Create');
  TestKit.CheckEqualsL(PartyMnu.CMD_BEGIN, PartyMnu.StepCmd(all, PartyMnu.CMD_CREATE, -1), 'Up from Create is Begin');
  TestKit.CheckEqualsL(PartyMnu.CMD_DUAL, PartyMnu.StepCmd(hall, PartyMnu.CMD_DROP, 1),
                       'a command not offered is passed over');
  TestKit.CheckEqualsL(PartyMnu.CMD_DROP, PartyMnu.StepCmd(hall, PartyMnu.CMD_DUAL, -1), 'going up too');
  TestKit.CheckEqualsL(PartyMnu.CMD_DUAL, PartyMnu.StepCmd(start, PartyMnu.CMD_CREATE, 1),
                       'with no party, Create, then Dual Class');
  TestKit.CheckEqualsL(PartyMnu.CMD_CREATE, PartyMnu.StepCmd(start, PartyMnu.CMD_EXIT, 1),
                       'and Exit to DOS wraps to Create when Begin is not offered');
  TestKit.CheckEqualsL(PartyMnu.CMD_EXIT, PartyMnu.StepCmd([PartyMnu.CMD_EXIT], PartyMnu.CMD_EXIT, 1),
                       'a lone command stays');

  { Left and Right }
  TestKit.CheckEqualsL(PartyMnu.CMD_ADD, PartyMnu.OtherColumn(all, PartyMnu.CMD_CREATE, 8), 'Create to Add');
  TestKit.CheckEqualsL(PartyMnu.CMD_CREATE, PartyMnu.OtherColumn(all, PartyMnu.CMD_ADD, 8), 'and back');
  TestKit.CheckEqualsL(PartyMnu.CMD_REMOVE, PartyMnu.OtherColumn(all, PartyMnu.CMD_MODIFY, 8),
                       'Modify, beside no command, to the nearer: Remove above');
  TestKit.CheckEqualsL(PartyMnu.CMD_SAVE, PartyMnu.OtherColumn(all, PartyMnu.CMD_DROP, 8),
                       'Drop, beside the GAME heading, to Save below it, the nearest');
  TestKit.CheckEqualsL(PartyMnu.CMD_LOAD, PartyMnu.OtherColumn(all, PartyMnu.CMD_DUAL, 8), 'Dual Class to Load');
  TestKit.CheckEqualsL(PartyMnu.CMD_DUAL, PartyMnu.OtherColumn(all, PartyMnu.CMD_EXIT, 8),
                       'Exit to DOS to the nearest of the CHARACTER column: Dual Class');
  TestKit.CheckEqualsL(PartyMnu.CMD_EXIT, PartyMnu.OtherColumn(all, PartyMnu.CMD_BEGIN, 8),
                       'Begin Adventuring to Exit to DOS');
  TestKit.CheckEqualsL(PartyMnu.CMD_SAVE, PartyMnu.OtherColumn(hall, PartyMnu.CMD_DUAL, 8),
                       'Load not offered: Dual Class to Save, the upper of Save and Settings, as near');
  TestKit.CheckEqualsL(PartyMnu.CMD_CREATE, PartyMnu.OtherColumn([PartyMnu.CMD_CREATE], PartyMnu.CMD_CREATE, 8),
                       'a column with nothing offered keeps the highlight');
  TestKit.Done;
end.

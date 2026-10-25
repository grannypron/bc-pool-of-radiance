{ Tests for the party menu's layouts and highlight (PartyMnu, #879, #885): where the two-column menu's headings go under
  the roster (MenuTop), its commands' rows (CmdRow), Up and Down through the commands offered (StepCmd), Left and Right
  between the columns (OtherColumn), and where SSI's one-column menu starts (ListTop). }
{$I COMPILER.INC}
program TPartyMn;

uses C_MSG, PartyMnu, TestKit;

var
  all: PartyMnu.TCmdSet;
  start: PartyMnu.TCmdSet;
  hall: PartyMnu.TCmdSet;

begin
  TestKit.Start('TPARTYMN');
  all := [PartyMnu.CMD_ADD..PartyMnu.CMD_LAST];
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
  TestKit.CheckEqualsL(9, PartyMnu.CmdRow(PartyMnu.CMD_ADD, 8), 'Add under PARTY');
  TestKit.CheckEqualsL(9, PartyMnu.CmdRow(PartyMnu.CMD_CREATE, 8), 'Create beside it, under CHARACTER');
  TestKit.CheckEqualsL(13, PartyMnu.CmdRow(PartyMnu.CMD_SAVE, 8), 'Save under GAME, beside Train');
  TestKit.CheckEqualsL(13, PartyMnu.CmdRow(PartyMnu.CMD_TRAIN, 8), 'Train on row 13');
  TestKit.CheckEqualsL(14, PartyMnu.CmdRow(PartyMnu.CMD_LOAD, 8), 'Load beside Dual Class');
  TestKit.CheckEqualsL(14, PartyMnu.CmdRow(PartyMnu.CMD_DUAL, 8), 'Dual Class on row 14');
  TestKit.CheckEqualsL(16, PartyMnu.CmdRow(PartyMnu.CMD_SETTINGS, 8), 'Settings on row 16');
  TestKit.CheckEqualsL(16, PartyMnu.CmdRow(PartyMnu.CMD_EXIT, 8), 'Exit to DOS beside it');
  TestKit.CheckEqualsL(18, PartyMnu.CmdRow(PartyMnu.CMD_BEGIN, 8), 'Begin Adventuring two rows below');
  TestKit.CheckEqualsL(21, PartyMnu.CmdRow(PartyMnu.CMD_BEGIN, 11), 'and on row 21 under a party of eight');
  TestKit.CheckEqualsS('ARSLGBCVMDTUE', PartyMnu.cmdKeys, 'the keys of the Command Key');
  TestKit.CheckEqualsS('U', PartyMnu.cmdKeys[PartyMnu.CMD_DUAL + 1], 'Dual Class is U');
  TestKit.CheckEqualsS('B', PartyMnu.cmdKeys[PartyMnu.CMD_BEGIN + 1], 'Begin Adventuring is B');

  { Up and Down }
  TestKit.CheckEqualsL(PartyMnu.CMD_REMOVE, PartyMnu.StepCmd(all, PartyMnu.CMD_ADD, 1), 'Down from Add is Remove');
  TestKit.CheckEqualsL(PartyMnu.CMD_SETTINGS, PartyMnu.StepCmd(all, PartyMnu.CMD_LOAD, 1), 'Load, then Settings');
  TestKit.CheckEqualsL(PartyMnu.CMD_BEGIN, PartyMnu.StepCmd(all, PartyMnu.CMD_SETTINGS, 1), 'then Begin');
  TestKit.CheckEqualsL(PartyMnu.CMD_CREATE, PartyMnu.StepCmd(all, PartyMnu.CMD_BEGIN, 1),
                       'down the left column, then the right');
  TestKit.CheckEqualsL(PartyMnu.CMD_EXIT, PartyMnu.StepCmd(all, PartyMnu.CMD_DUAL, 1), 'Dual Class, then Exit to DOS');
  TestKit.CheckEqualsL(PartyMnu.CMD_ADD, PartyMnu.StepCmd(all, PartyMnu.CMD_EXIT, 1), 'and back to Add');
  TestKit.CheckEqualsL(PartyMnu.CMD_EXIT, PartyMnu.StepCmd(all, PartyMnu.CMD_ADD, -1), 'Up from Add is Exit to DOS');
  TestKit.CheckEqualsL(PartyMnu.CMD_DUAL, PartyMnu.StepCmd(hall, PartyMnu.CMD_DROP, 1),
                       'a command not offered is passed over');
  TestKit.CheckEqualsL(PartyMnu.CMD_DROP, PartyMnu.StepCmd(hall, PartyMnu.CMD_DUAL, -1), 'going up too');
  TestKit.CheckEqualsL(PartyMnu.CMD_SETTINGS, PartyMnu.StepCmd(hall, PartyMnu.CMD_SAVE, 1), 'Save, then Settings');
  TestKit.CheckEqualsL(PartyMnu.CMD_LOAD, PartyMnu.StepCmd(start, PartyMnu.CMD_ADD, 1),
                       'with no party, Add, then Load');
  TestKit.CheckEqualsL(PartyMnu.CMD_CREATE, PartyMnu.StepCmd(start, PartyMnu.CMD_SETTINGS, 1),
                       'and Settings to Create when Begin is not offered');
  TestKit.CheckEqualsL(PartyMnu.CMD_EXIT, PartyMnu.StepCmd([PartyMnu.CMD_EXIT], PartyMnu.CMD_EXIT, 1),
                       'a lone command stays');

  { Left and Right }
  TestKit.CheckEqualsL(PartyMnu.CMD_CREATE, PartyMnu.OtherColumn(all, PartyMnu.CMD_ADD, 8), 'Add to Create');
  TestKit.CheckEqualsL(PartyMnu.CMD_ADD, PartyMnu.OtherColumn(all, PartyMnu.CMD_CREATE, 8), 'and back');
  TestKit.CheckEqualsL(PartyMnu.CMD_REMOVE, PartyMnu.OtherColumn(all, PartyMnu.CMD_MODIFY, 8),
                       'Modify, beside no command, to the nearer: Remove above');
  TestKit.CheckEqualsL(PartyMnu.CMD_SAVE, PartyMnu.OtherColumn(all, PartyMnu.CMD_DROP, 8),
                       'Drop, beside the GAME heading, to Save below it, the nearest');
  TestKit.CheckEqualsL(PartyMnu.CMD_LOAD, PartyMnu.OtherColumn(all, PartyMnu.CMD_DUAL, 8), 'Dual Class to Load');
  TestKit.CheckEqualsL(PartyMnu.CMD_SETTINGS, PartyMnu.OtherColumn(all, PartyMnu.CMD_EXIT, 8),
                       'Exit to DOS to Settings, on its row');
  TestKit.CheckEqualsL(PartyMnu.CMD_EXIT, PartyMnu.OtherColumn(all, PartyMnu.CMD_SETTINGS, 8), 'and back');
  TestKit.CheckEqualsL(PartyMnu.CMD_EXIT, PartyMnu.OtherColumn(all, PartyMnu.CMD_BEGIN, 8),
                       'Begin Adventuring to Exit to DOS');
  TestKit.CheckEqualsL(PartyMnu.CMD_SAVE, PartyMnu.OtherColumn(hall, PartyMnu.CMD_DUAL, 8),
                       'Load not offered: Dual Class to Save, the nearer');
  TestKit.CheckEqualsL(PartyMnu.CMD_ADD, PartyMnu.OtherColumn(all - [PartyMnu.CMD_REMOVE], PartyMnu.CMD_MODIFY, 8),
                       'Remove not offered: Modify to Add, the upper of Add and Save, as near');
  TestKit.CheckEqualsL(PartyMnu.CMD_CREATE, PartyMnu.OtherColumn([PartyMnu.CMD_CREATE], PartyMnu.CMD_CREATE, 8),
                       'a column with nothing offered keeps the highlight');

  { SSI's menu }
  TestKit.CheckEqualsL(PartyMnu.LIST_TOP, PartyMnu.ListTop(10), 'SSI''s menu starts on row 12');
  TestKit.CheckEqualsL(PartyMnu.LIST_TOP, PartyMnu.ListTop(11), 'eleven commands end on the window''s last row');
  TestKit.CheckEqualsL(C_MSG.TEXT_BOTTOM - 11, PartyMnu.ListTop(12), 'twelve start a row higher, to stay in it');
  TestKit.Done;
end.

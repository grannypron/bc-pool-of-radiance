{ Tests for JrnlList: the kinds, numbers, labels and titles of the Journal's items, and that every item's text has lines
  that fit the Journal pane (C_JRNL.JOURNAL_WIDTH). }
{$I COMPILER.INC}
program TJrnl;

uses C_JRNL, JrnlList, StrUtil, TestKit;

var
  i: Integer;
  n: Integer;
  k: Integer;
  nothingPast: Boolean;
  allHaveLines: Boolean;
  widest: Integer;
  where: String;

begin
  TestKit.Start('TJRNL');
  TestKit.CheckEqualsL(C_JRNL.KIND_PROCLAMATION, JrnlList.EntryKind(1), 'item 1 is a proclamation');
  TestKit.CheckEqualsL(C_JRNL.KIND_PROCLAMATION, JrnlList.EntryKind(18), 'item 18 is the last proclamation');
  TestKit.CheckEqualsL(C_JRNL.KIND_ENTRY, JrnlList.EntryKind(19), 'item 19 is the first journal entry');
  TestKit.CheckEqualsL(C_JRNL.KIND_ENTRY, JrnlList.EntryKind(76), 'item 76 is the last');
  TestKit.CheckEqualsL(C_JRNL.KIND_TALE, JrnlList.EntryKind(77), 'item 77 is the first tavern tale');
  TestKit.CheckEqualsL(C_JRNL.KIND_TALE, JrnlList.EntryKind(C_JRNL.JOURNAL_COUNT), 'the last item is a tale');
  TestKit.CheckEqualsL(C_JRNL.KIND_NONE, JrnlList.EntryKind(0), 'item 0 is none');
  TestKit.CheckEqualsL(C_JRNL.KIND_NONE, JrnlList.EntryKind(C_JRNL.JOURNAL_COUNT + 1), 'nor one past the list');

  TestKit.CheckEqualsL(59, JrnlList.EntryNumber(1), 'proclamation 1 is LIX');
  TestKit.CheckEqualsL(1, JrnlList.EntryNumber(19), 'journal entries count from 1');
  TestKit.CheckEqualsL(23, JrnlList.EntryNumber(C_JRNL.JOURNAL_COUNT), 'there are 23 tavern tales');
  TestKit.CheckEqualsS('LIX', JrnlList.EntryLabel(1), 'a proclamation''s label is its numeral');
  TestKit.CheckEqualsS('CI', JrnlList.EntryLabel(4), '101 is CI');
  TestKit.CheckEqualsS('CXC', JrnlList.EntryLabel(15), '190 is CXC');
  TestKit.CheckEqualsS('ENTRY 1', JrnlList.EntryLabel(19), 'a journal entry''s label');
  TestKit.CheckEqualsS('TALE 1', JrnlList.EntryLabel(77), 'a tale''s label');
  TestKit.CheckEqualsS('', JrnlList.EntryLabel(0), 'no label outside the list');
  TestKit.CheckEqualsS('PROCLAMATION CCXIV', JrnlList.EntryTitle(18), 'a proclamation''s title');
  TestKit.CheckEqualsS('JOURNAL ENTRY 58', JrnlList.EntryTitle(76), 'a journal entry''s title');
  TestKit.CheckEqualsS('TAVERN TALE 23', JrnlList.EntryTitle(99), 'a tale''s title');

  { every item's text: some lines, none wider than the pane, and nothing past the last }
  nothingPast := True;
  allHaveLines := True;
  widest := 0;
  where := '';
  for i := 1 to C_JRNL.JOURNAL_COUNT do begin
    n := JrnlList.LineCount(i);
    if n <= 0 then begin
      allHaveLines := False;
      where := where + ' ' + StrUtil.NumStr(i);
    end;
    for k := 1 to n do
      if Length(JrnlList.TextLine(i, k)) > widest then
        widest := Length(JrnlList.TextLine(i, k));
    if JrnlList.TextLine(i, n + 1) <> '' then
      nothingPast := False;
  end;
  TestKit.Check(allHaveLines, 'every item has text lines;' + where);
  TestKit.Check(widest <= C_JRNL.JOURNAL_WIDTH, 'every line fits the pane (widest ' + StrUtil.NumStr(widest) + ')');
  TestKit.Check(nothingPast, 'no item has a line past its LineCount');
  TestKit.CheckEqualsL(0, JrnlList.LineCount(0), 'no lines outside the list');
  TestKit.Done;
end.

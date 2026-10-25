{ Tests for JrnlList: the kinds, numbers, labels and titles of the Journal's items, and that every item's text has lines
  that fit the Journal pane (C_JRNL.JOURNAL_WIDTH), as many as its text unit's LineCount says. }
{$I COMPILER.INC}
program TJrnl;

uses C_JRNL, JrnlList, Journal1, Journal2, Journal3, Journal4, StrUtil, TestKit;

var
  i: Integer;
  n: Integer;
  k: Integer;
  nothingPast: Boolean;
  allHaveLines: Boolean;
  widest: Integer;
  where: String;
  { the items whose LineCount is wrong }
  wrong: String;
  chunk: String;
  { the lines in an item's last run }
  runLines: Integer;

{ Item index's run of lines chunk, from the text unit that holds it, as JrnlList reads it. }
function Run(index, chunk: Integer): String;
begin
  if index <= C_JRNL.PART1_LAST then
    Run := Journal1.TextChunk(index, chunk)
  else if index <= C_JRNL.PART2_LAST then
    Run := Journal2.TextChunk(index, chunk)
  else if index <= C_JRNL.PART3_LAST then
    Run := Journal3.TextChunk(index, chunk)
  else
    Run := Journal4.TextChunk(index, chunk);
end;

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

  { every item's text: some lines, none wider than the pane, and its LineCount the lines its runs hold: the last run
    (of 9) holds the rest, and none follows it }
  nothingPast := True;
  allHaveLines := True;
  widest := 0;
  where := '';
  wrong := '';
  for i := 1 to C_JRNL.JOURNAL_COUNT do begin
    n := JrnlList.LineCount(i);
    if n <= 0 then begin
      allHaveLines := False;
      where := where + ' ' + StrUtil.NumStr(i);
    end;
    for k := 1 to n do
      if Length(JrnlList.TextLine(i, k)) > widest then
        widest := Length(JrnlList.TextLine(i, k));
    if n > 0 then begin
      chunk := Run(i, (n - 1) div 9);
      runLines := 1;
      for k := 1 to Length(chunk) do
        if chunk[k] = #13 then
          Inc(runLines);
      if (chunk = '') or (runLines <> (n - 1) mod 9 + 1) or (Run(i, (n - 1) div 9 + 1) <> '') then begin
        nothingPast := False;
        wrong := wrong + ' ' + StrUtil.NumStr(i);
      end;
    end;
  end;
  TestKit.Check(allHaveLines, 'every item has text lines;' + where);
  TestKit.Check(widest <= C_JRNL.JOURNAL_WIDTH, 'every line fits the pane (widest ' + StrUtil.NumStr(widest) + ')');
  TestKit.Check(nothingPast, 'every LineCount is the lines its item holds;' + wrong);
  TestKit.CheckEqualsL(0, JrnlList.LineCount(0), 'no lines outside the list');
  TestKit.Done;
end.

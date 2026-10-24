{ Tests for CbtLog and LogWrap (#841): the ring keeping the newest entries, colour changes inside an entry, pieces put
  together, headings, entries longer than a slot, and wrapping again at a page's width. Under DOS the ring is in EMS,
  which DOSBox-X gives the tests; natively it is on the heap. }
{$I COMPILER.INC}
program TCbtLog;

uses CbtLog, LogWrap, TestKit;

const
  M = CbtLog.COLOR_MARK;
  GREEN = 10;
  CYAN = 11;
  YELLOW = 14;
  WHITE = 15;

var
  s: string;
  i: Byte;
  n: Byte;
  lines: LogWrap.TWrapLines;
  num: string[3];

{ s with its colour changes taken out. }
function Plain(s: string): string;
var
  { an Integer, so it can step past a 255-character s }
  i: Integer;
  t: string;
begin
  t := '';
  i := 1;
  while i <= Length(s) do
    if s[i] = M then
      Inc(i, 2)
    else begin
      t := t + s[i];
      Inc(i);
    end;
  Plain := t;
end;

begin
  TestKit.Start('TCBTLOG');
  CbtLog.Startup;
  TestKit.Check(CbtLog.Usable, 'the ring has a store (EMS under DOS, the heap natively)');

  { nothing is kept while the history is off }
  CbtLog.Clear(50, False);
  CbtLog.Add(GREEN, 'ignored');
  CbtLog.NewEntry;
  TestKit.Check(not CbtLog.Active, 'off: not active');
  TestKit.CheckEqualsL(0, CbtLog.Count, 'off: nothing kept');

  { a message in pieces: a name, then text shown on the next line, then text carrying on along it }
  CbtLog.Clear(50, True);
  TestKit.Check(CbtLog.Active, 'on: active');
  CbtLog.NewEntry;
  CbtLog.Add(CYAN, 'GINS');
  CbtLog.NextLine;
  CbtLog.Add(GREEN, 'Attacks');
  CbtLog.NextLine;
  CbtLog.Add(YELLOW, 'ORC');
  CbtLog.NextLine;
  CbtLog.Add(GREEN, 'and Misses');
  CbtLog.Add(GREEN, '!');
  TestKit.CheckEqualsL(1, CbtLog.Count, 'the entry being built counts');
  CbtLog.Entry(1, s);
  TestKit.CheckEqualsS(M + Chr(CYAN) + 'GINS ' + M + Chr(GREEN) + 'Attacks ' + M + Chr(YELLOW) + 'ORC ' + M + Chr(GREEN)
                       + 'and Misses!', s, 'pieces join with colour changes, a space before each new line');
  CbtLog.NewEntry;
  CbtLog.NewEntry;
  TestKit.CheckEqualsL(1, CbtLog.Count, 'an empty entry is not kept');
  CbtLog.Heading(WHITE, 'Round 2');
  TestKit.CheckEqualsL(2, CbtLog.Count, 'a heading is an entry');
  CbtLog.Entry(2, s);
  TestKit.CheckEqualsS(M + Chr(WHITE) + 'Round 2', s, 'the heading');
  CbtLog.NextLine;
  CbtLog.Add(GREEN, 'x');
  CbtLog.Entry(3, s);
  TestKit.CheckEqualsS(M + Chr(GREEN) + 'x', s, 'NextLine at the start of an entry adds nothing');
  CbtLog.Entry(4, s);
  TestKit.CheckEqualsS('', s, 'past the newest is empty');
  CbtLog.Entry(0, s);
  TestKit.CheckEqualsS('', s, 'entry 0 is empty');

  { the ring keeps the newest capacity entries, oldest first }
  CbtLog.Clear(10, True);
  for i := 1 to 25 do begin
    Str(i, num);
    CbtLog.Add(GREEN, 'msg ' + num);
    CbtLog.NewEntry;
  end;
  TestKit.CheckEqualsL(10, CbtLog.Count, 'a full ring holds its capacity');
  CbtLog.Entry(1, s);
  TestKit.CheckEqualsS('msg 16', Plain(s), 'the oldest kept');
  CbtLog.Entry(10, s);
  TestKit.CheckEqualsS('msg 25', Plain(s), 'the newest');
  CbtLog.Add(GREEN, 'building');
  TestKit.CheckEqualsL(11, CbtLog.Count, 'the entry being built comes after a full ring');
  CbtLog.Entry(11, s);
  TestKit.CheckEqualsS('building', Plain(s), 'and is the newest');
  CbtLog.Clear(5, True);
  TestKit.CheckEqualsL(0, CbtLog.Count, 'Clear empties it');
  for i := 1 to 15 do begin
    CbtLog.Add(GREEN, 'm');
    CbtLog.NewEntry;
  end;
  TestKit.CheckEqualsL(CbtLog.MIN_ENTRIES, CbtLog.Count, 'a capacity below the least is the least');
  CbtLog.Clear(200, True);
  for i := 1 to 70 do begin
    Str(i, num);
    CbtLog.Add(GREEN, num);
    CbtLog.NewEntry;
  end;
  TestKit.CheckEqualsL(CbtLog.MAX_ENTRIES, CbtLog.Count, 'a capacity above the most is the most');
  CbtLog.Entry(1, s);
  TestKit.CheckEqualsS('11', Plain(s), 'the most: the oldest kept');
  CbtLog.Entry(CbtLog.MAX_ENTRIES, s);
  TestKit.CheckEqualsS('70', Plain(s), 'the most: the newest');

  { an entry longer than a slot is cut at it }
  CbtLog.Clear(10, True);
  for i := 1 to 30 do
    CbtLog.Add(GREEN, 'abcdefghij');
  CbtLog.NewEntry;
  CbtLog.Entry(1, s);
  TestKit.CheckEqualsL(255, Length(s), 'a long entry fills its slot');
  TestKit.CheckEqualsL(253, Length(Plain(s)), 'less its colour change');

  { wrapping again at a page's width }
  n := LogWrap.WrapEntry(M + Chr(CYAN) + 'GINS ' + M + Chr(GREEN) + 'Attacks ' + M + Chr(YELLOW) + 'ORC LEADER ' + M
                        + Chr(GREEN) + '(from behind) Hitting for 7 points of damage', 37, lines);
  TestKit.CheckEqualsL(2, n, 'two lines at 37');
  TestKit.CheckEqualsS('GINS Attacks ORC LEADER (from behind)', Plain(lines[1]), 'the first line');
  TestKit.CheckEqualsS('Hitting for 7 points of damage', Plain(lines[2]), 'the second line');
  TestKit.CheckEqualsS(M + Chr(GREEN), Copy(lines[2], 1, 2), 'a line starts in the colour where it begins');
  TestKit.CheckEqualsS(M + Chr(CYAN) + 'GINS ' + M + Chr(GREEN) + 'Attacks', Copy(lines[1], 1, 16),
                       'colours stay with their words');
  n := LogWrap.WrapEntry(M + Chr(GREEN) + '  two   spaces  ', 37, lines);
  TestKit.CheckEqualsL(1, n, 'spaces: one line');
  TestKit.CheckEqualsS('two spaces', Plain(lines[1]), 'runs of spaces are one, none at either end');
  n := LogWrap.WrapEntry(M + Chr(GREEN) + 'abcdefghijKLMNO' + M + Chr(YELLOW) + 'pqrst', 10, lines);
  TestKit.CheckEqualsL(2, n, 'a word wider than a line is split');
  TestKit.CheckEqualsS('abcdefghij', Plain(lines[1]), 'its first part');
  TestKit.CheckEqualsS('KLMNOpqrst', Plain(lines[2]), 'its second part');
  TestKit.CheckEqualsS(M + Chr(GREEN) + 'KLMNO' + M + Chr(YELLOW) + 'pqrst', lines[2],
                       'the colour change inside it is kept');
  n := LogWrap.WrapEntry('', 37, lines);
  TestKit.CheckEqualsL(1, n, 'an empty entry is one empty line');
  TestKit.CheckEqualsS('', lines[1], 'with nothing on it');
  n := LogWrap.WrapEntry('one two three', 3, lines);
  TestKit.CheckEqualsL(4, n, 'a narrow page');
  TestKit.CheckEqualsS('two', lines[2], 'a word that just fits');
  TestKit.CheckEqualsS('thr', lines[3], 'split at the width');
  TestKit.CheckEqualsS('ee', lines[4], 'the rest');
  s := '';
  for i := 1 to 50 do
    s := s + 'ab ';
  n := LogWrap.WrapEntry(s, 3, lines);
  TestKit.CheckEqualsL(LogWrap.WRAP_LINES, n, 'lines past WRAP_LINES are dropped');
  TestKit.Done;
end.

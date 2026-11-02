{ Tests for StrUtil: numbers, numbers with commas, attacks a round, two-digit padding, nouns for a count, padding to a
  width, '~'-hotkey menus, a script menu option's hotkey marked so that no two options share one, and the span a
  menu option lights. }
{$I COMPILER.INC}
program TStrUtil;

uses StrUtil, TestKit;

var
  menu: String;
  opts: String;
  short: string[5];
  taken: String;
  hlFirst: Byte;
  hlLast: Byte;

{ The span OptionSpan last gave is first..last. }
procedure CheckSpan(first, last: Byte; what: String);
begin
  TestKit.CheckEqualsL(first, hlFirst, what + ': first');
  TestKit.CheckEqualsL(last, hlLast, what + ': last');
end;

begin
  TestKit.Start('TSTRUTIL');
  TestKit.CheckEqualsS('0', StrUtil.NumStr(0), 'zero');
  TestKit.CheckEqualsS('-42', StrUtil.NumStr(-42), 'a negative number');
  TestKit.CheckEqualsS('2147483647', StrUtil.NumStr(MaxLongInt), 'MaxLongInt');
  TestKit.CheckEqualsS('999', StrUtil.Grouped(999), 'three digits have no comma');
  TestKit.CheckEqualsS('2,500', StrUtil.Grouped(2500), 'four digits have one');
  TestKit.CheckEqualsS('2,147,483,647', StrUtil.Grouped(MaxLongInt), 'MaxLongInt has three');
  TestKit.CheckEqualsS('1', StrUtil.HalvesStr(2), 'two half attacks are one a round');
  TestKit.CheckEqualsS('3/2', StrUtil.HalvesStr(3), 'three are three every two rounds');
  TestKit.CheckEqualsS('2', StrUtil.HalvesStr(4), 'four are two a round');
  TestKit.CheckEqualsS('-2147483648', StrUtil.NumStr(-MaxLongInt - 1), 'the most negative LongInt');
  TestKit.CheckEqualsS('07', StrUtil.ZeroPad2(7), 'one digit gets a 0 in front');
  TestKit.CheckEqualsS('42', StrUtil.ZeroPad2(42), 'two digits as they are');
  TestKit.CheckEqualsS('00', StrUtil.ZeroPad2(100), '100 shows as 00 (exceptional strength 18/00)');
  TestKit.CheckEqualsS('59', StrUtil.ZeroPad2(159), 'only the last two digits of a larger number');
  TestKit.CheckEqualsS('ENEMY', StrUtil.Pluralize(1, 'ENEMY', 'ENEMIES'), 'one takes the singular');
  TestKit.CheckEqualsS('ENEMIES', StrUtil.Pluralize(2, 'ENEMY', 'ENEMIES'), 'two the plural');
  TestKit.CheckEqualsS('ALLIES', StrUtil.Pluralize(0, 'ALLY', 'ALLIES'), 'and none the plural too');
  TestKit.CheckEqualsS('1 SQUARE', StrUtil.Count(1, 'SQUARE', 'SQUARES'), 'Count puts the number first');
  TestKit.CheckEqualsS('12 points', StrUtil.Count(12, 'point', 'points'), 'with the plural past one');
  TestKit.CheckEqualsS('-1 points', StrUtil.Count(-1, 'point', 'points'), 'and below one');
  TestKit.CheckEqualsS('ab   ', StrUtil.PadRight('ab', 5), 'PadRight pads');
  TestKit.CheckEqualsS('abc', StrUtil.PadRight('abcdef', 3), 'PadRight cuts');
  TestKit.CheckEqualsS('   ab', StrUtil.PadLeft('ab', 5), 'PadLeft pads');
  TestKit.CheckEqualsS(' 7', StrUtil.PadLeft(StrUtil.NumStr(7), 2), 'a count kept in its place');
  TestKit.CheckEqualsS('abc', StrUtil.PadLeft('abcdef', 3), 'PadLeft cuts from the start');
  menu := '~YES ~NO';
  StrUtil.MenuToOptions(menu, opts);
  TestKit.CheckEqualsS('Yes No', menu, 'a menu is lowercased but for its hotkeys');
  TestKit.CheckEqualsS('YN', opts, 'and the hotkeys are collected');
  menu := '~ROOM 12 ~1ST';
  StrUtil.MenuToOptions(menu, opts);
  TestKit.CheckEqualsS('Room 12 1st', menu, 'digits keep their glyphs (#810)');
  TestKit.CheckEqualsS('R1', opts, 'a digit hotkey is collected as it is');
  menu := '~A ~';
  StrUtil.MenuToOptions(menu, opts);
  TestKit.CheckEqualsS('A ', menu, 'a closing ~ with nothing after it is dropped');
  TestKit.CheckEqualsS('A', opts, 'and adds no hotkey');

  { MarkHotkey: the Nomad Camp's tripwire menu (ECL7 block 17), ATTACK after ADVANCE CAUTIOUSLY }
  taken := '';
  menu := StrUtil.MarkHotkey('FLEE', taken) + ' ' + StrUtil.MarkHotkey('ADVANCE CAUTIOUSLY', taken) + ' ' +
          StrUtil.MarkHotkey('ATTACK', taken);
  TestKit.CheckEqualsS('~FLEE ~ADVANCE CAUTIOUSLY A~TTACK', menu, 'ATTACK takes its T, as A is taken');
  TestKit.CheckEqualsS('FAT', taken, 'every key once');
  StrUtil.MenuToOptions(menu, opts);
  TestKit.CheckEqualsS('Flee Advance cautiously aTtack', menu, 'shown as aTtack');
  TestKit.CheckEqualsS('FAT', opts, 'and chosen by T');
  taken := '';
  menu := StrUtil.MarkHotkey('YES', taken) + ' ' + StrUtil.MarkHotkey('NO', taken);
  TestKit.CheckEqualsS('~YES ~NO', menu, 'options with their own initials keep them');
  taken := 'ABC';
  TestKit.CheckEqualsS('~CAB', StrUtil.MarkHotkey('CAB', taken), 'with no free key it keeps its first');
  TestKit.CheckEqualsS('ABCC', taken, 'which is noted again');
  taken := '';
  TestKit.CheckEqualsS('~', StrUtil.MarkHotkey('', taken), 'an empty option is marked as before');
  TestKit.CheckEqualsS('', taken, 'and takes no key');
  taken := 'A';
  TestKit.CheckEqualsS('a~2', StrUtil.MarkHotkey('a2', taken), 'a digit can be the key');
  taken := 'P';
  TestKit.CheckEqualsS('P~ASS ON BY', StrUtil.MarkHotkey('PASS ON BY', taken),
                       'the first free letter of the option, not of a later word');

  { OptionSpan: the inverse runs from the hotkey's word to the option's last word (#1216) }
  StrUtil.OptionSpan('coMbat sYstem', 3, 9, hlFirst, hlLast);
  CheckSpan(1, 6, 'coMbat lights its word alone (#1198)');
  StrUtil.OptionSpan('coMbat sYstem', 9, 0, hlFirst, hlLast);
  CheckSpan(8, 13, 'and sYstem its word');
  StrUtil.OptionSpan('Advance cautiously aTtack', 1, 21, hlFirst, hlLast);
  CheckSpan(1, 18, 'a two-word option lights both words');
  StrUtil.OptionSpan('Advance cautiously aTtack', 21, 0, hlFirst, hlLast);
  CheckSpan(20, 25, 'and aTtack from the start of its word');
  StrUtil.OptionSpan('Press <enter>/<return> to continue', 1, 0, hlFirst, hlLast);
  CheckSpan(1, 34, 'a script''s continue prompt lights whole');
  StrUtil.OptionSpan('Yes No', 1, 5, hlFirst, hlLast);
  CheckSpan(1, 3, 'Yes');
  StrUtil.OptionSpan('Yes No', 5, 0, hlFirst, hlLast);
  CheckSpan(5, 6, 'No');
  StrUtil.OptionSpan('Game Exit   ', 6, 0, hlFirst, hlLast);
  CheckSpan(6, 9, 'trailing spaces are left out');
  StrUtil.OptionSpan('Yes  No', 1, 6, hlFirst, hlLast);
  CheckSpan(1, 3, 'and the spaces between options');
  StrUtil.OptionSpan('aBC', 2, 3, hlFirst, hlLast);
  CheckSpan(1, 2, 'two hotkeys in one word part before the next');
  TestKit.CheckEqualsS('AB', StrUtil.RemoveAll('A....B', '.'), 'RemoveAll takes every period in a row (#960)');
  TestKit.CheckEqualsS('SIRBOB', StrUtil.RemoveAll('SIR  BOB', ' '), 'and every space');
  TestKit.CheckEqualsS('ab', StrUtil.RemoveAll('xaxxbx', 'x'), 'at either end too');
  TestKit.CheckEqualsS('c', StrUtil.RemoveAll('aabbc', 'ab'), 'and what a removal brings together');
  TestKit.CheckEqualsS('abc', StrUtil.RemoveAll('abc', ''), 'an empty del removes nothing');
  TestKit.CheckEqualsS('', StrUtil.RemoveAll('', '..'), 'nor from an empty string');
  short := 'abc';
  TestKit.Check(StrUtil.FitLength(short, SizeOf(short) - 1), 'a string within its field fits');
  TestKit.CheckEqualsS('abc', short, 'and is left as it is');
  short[0] := #6;
  TestKit.Check(not StrUtil.FitLength(short, SizeOf(short) - 1), 'a length byte one past its field does not (#917)');
  TestKit.CheckEqualsL(5, Length(short), 'and is cut to the field');
  short[0] := #255;
  TestKit.Check(not StrUtil.FitLength(short, SizeOf(short) - 1), 'nor does $FF');
  TestKit.CheckEqualsL(5, Length(short), 'cut to the field too');
  TestKit.Done;
end.

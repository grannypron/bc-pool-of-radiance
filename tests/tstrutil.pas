{ Tests for StrUtil: numbers, numbers with commas, attacks a round, two-digit padding, nouns for a count, padding to a
  width, and '~'-hotkey menus. }
{$I COMPILER.INC}
program TStrUtil;

uses StrUtil, TestKit;

var
  menu: String;
  opts: String;

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
  TestKit.CheckEqualsS('AB', StrUtil.RemoveAll('A....B', '.'), 'RemoveAll takes every period in a row (#960)');
  TestKit.CheckEqualsS('SIRBOB', StrUtil.RemoveAll('SIR  BOB', ' '), 'and every space');
  TestKit.CheckEqualsS('ab', StrUtil.RemoveAll('xaxxbx', 'x'), 'at either end too');
  TestKit.CheckEqualsS('c', StrUtil.RemoveAll('aabbc', 'ab'), 'and what a removal brings together');
  TestKit.CheckEqualsS('abc', StrUtil.RemoveAll('abc', ''), 'an empty del removes nothing');
  TestKit.CheckEqualsS('', StrUtil.RemoveAll('', '..'), 'nor from an empty string');
  TestKit.Done;
end.

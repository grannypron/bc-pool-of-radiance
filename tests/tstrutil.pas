{ Tests for StrUtil: numbers, two-digit padding, and padding to a width. }
program TStrUtil;

uses StrUtil, TestKit;

begin
  TestKit.Start('TSTRUTIL');
  TestKit.CheckEqualsS('0', StrUtil.NumStr(0), 'zero');
  TestKit.CheckEqualsS('-42', StrUtil.NumStr(-42), 'a negative number');
  TestKit.CheckEqualsS('2147483647', StrUtil.NumStr(MaxLongInt), 'MaxLongInt');
  TestKit.CheckEqualsS('-2147483648', StrUtil.NumStr(-MaxLongInt - 1), 'the most negative LongInt');
  TestKit.CheckEqualsS('07', StrUtil.ZeroPad2(7), 'one digit gets a 0 in front');
  TestKit.CheckEqualsS('42', StrUtil.ZeroPad2(42), 'two digits as they are');
  TestKit.CheckEqualsS('00', StrUtil.ZeroPad2(100), '100 shows as 00 (exceptional strength 18/00)');
  TestKit.CheckEqualsS('59', StrUtil.ZeroPad2(159), 'only the last two digits of a larger number');
  TestKit.CheckEqualsS('ab   ', StrUtil.PadRight('ab', 5), 'PadRight pads');
  TestKit.CheckEqualsS('abc', StrUtil.PadRight('abcdef', 3), 'PadRight cuts');
  TestKit.CheckEqualsS('   ab', StrUtil.PadLeft('ab', 5), 'PadLeft pads');
  TestKit.CheckEqualsS(' 7', StrUtil.PadLeft(StrUtil.NumStr(7), 2), 'a count kept in its place');
  TestKit.CheckEqualsS('abc', StrUtil.PadLeft('abcdef', 3), 'PadLeft cuts from the start');
  TestKit.Done;
end.

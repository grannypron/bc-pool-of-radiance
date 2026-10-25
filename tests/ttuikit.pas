{ Tests for TuiKit.MoveInList, POOLCFG's list movement: Up and Down wrapping at either end, Home and End, and other keys
  leaving the item alone. }
{$I COMPILER.INC}
program TTuiKit;

uses C_KEYS, TuiKit, TestKit;

var
  sel: Byte;

{ sel after key ch, from item start of a list of count. }
function After(start: Byte; ch: Char; count: Byte): Byte;
begin
  sel := start;
  TuiKit.MoveInList(ch, sel, count);
  After := sel;
end;

begin
  TestKit.Start('TTUIKIT');
  TestKit.CheckEqualsL(2, After(3, C_KEYS.UP, 5), 'Up moves up one');
  TestKit.CheckEqualsL(5, After(1, C_KEYS.UP, 5), 'Up from the first wraps to the last');
  TestKit.CheckEqualsL(4, After(3, C_KEYS.DOWN, 5), 'Down moves down one');
  TestKit.CheckEqualsL(1, After(5, C_KEYS.DOWN, 5), 'Down from the last wraps to the first');
  TestKit.CheckEqualsL(1, After(4, C_KEYS.HOME, 5), 'Home goes to the first');
  TestKit.CheckEqualsL(5, After(2, C_KEYS.END_KEY, 5), 'End goes to the last');
  TestKit.CheckEqualsL(3, After(3, C_KEYS.LEFT, 5), 'Left is not a move');
  TestKit.CheckEqualsL(3, After(3, C_KEYS.F10, 5), 'F10 is not a move');
  TestKit.CheckEqualsL(1, After(1, C_KEYS.DOWN, 1), 'a list of one stays put');
  TestKit.Done;
end.

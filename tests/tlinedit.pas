{ Tests for LineEdit (#876), POOLCFG's line editor: typing in insert and overwrite modes, moving, Backspace at the start
  and Del at the end, the length limit, and the keys left to the caller. }
{$I COMPILER.INC}
program TLinEdit;

uses C_KEYS, LineEdit, TestKit;

var
  text: string;
  pos: Byte;
  insertMode: Boolean;

{ Apply a typed key (not extended) and an extended one. }
function Typed(ch: Char): Boolean;
begin
  Typed := LineEdit.EditKey(text, pos, insertMode, 8, ch, False);
end;

function Moved(ch: Char): Boolean;
begin
  Moved := LineEdit.EditKey(text, pos, insertMode, 8, ch, True);
end;

begin
  TestKit.Start('TLINEDIT');
  text := 'C:\';
  pos := 3;
  insertMode := True;
  TestKit.Check(Typed('A') and Typed('B'), 'printable keys are the editor''s');
  TestKit.CheckEqualsS('C:\AB', text, 'typed at the end');
  TestKit.CheckEqualsL(5, pos, 'the cursor after them');
  TestKit.Check(Moved(C_KEYS.HOME), 'Home');
  TestKit.CheckEqualsL(0, pos, 'goes to the start');
  TestKit.Check(Typed(C_KEYS.BACKSPACE), 'Backspace at the start');
  TestKit.CheckEqualsS('C:\AB', text, 'deletes nothing');
  TestKit.Check(Typed('D'), 'insert');
  TestKit.CheckEqualsS('DC:\AB', text, 'puts the character in before the cursor''s');
  TestKit.Check(Moved(C_KEYS.INS), 'Ins');
  TestKit.Check(not insertMode, 'turns overwrite on');
  TestKit.Check(Typed('E'), 'overwrite');
  TestKit.CheckEqualsS('DE:\AB', text, 'replaces the character under the cursor');
  TestKit.Check(Moved(C_KEYS.END_KEY), 'End');
  TestKit.CheckEqualsL(6, pos, 'goes to the end');
  TestKit.Check(Typed('F'), 'overwrite at the end');
  TestKit.CheckEqualsS('DE:\ABF', text, 'adds the character');
  TestKit.Check(Moved(C_KEYS.DEL), 'Del at the end');
  TestKit.CheckEqualsS('DE:\ABF', text, 'deletes nothing');
  TestKit.Check(Moved(C_KEYS.LEFT) and Moved(C_KEYS.LEFT), 'Left');
  TestKit.CheckEqualsL(5, pos, 'moves back');
  TestKit.Check(Moved(C_KEYS.DEL), 'Del');
  TestKit.CheckEqualsS('DE:\AF', text, 'deletes the character under the cursor');
  TestKit.Check(Typed(C_KEYS.BACKSPACE), 'Backspace');
  TestKit.CheckEqualsS('DE:\F', text, 'deletes the character before it');
  TestKit.CheckEqualsL(4, pos, 'and moves back');
  TestKit.Check(Moved(C_KEYS.RIGHT) and Moved(C_KEYS.RIGHT), 'Right');
  TestKit.CheckEqualsL(5, pos, 'stops at the end');
  insertMode := True;
  TestKit.Check(Typed('1') and Typed('2') and Typed('3') and Typed('4'), 'typing to the limit');
  TestKit.CheckEqualsS('DE:\F123', text, 'stops at 8 characters');
  TestKit.Check(not Typed(C_KEYS.ENTER), 'Enter is the caller''s');
  TestKit.Check(not Typed(C_KEYS.ESCAPE), 'Escape is the caller''s');
  TestKit.Check(not Moved(C_KEYS.F10), 'F10 is the caller''s');
  TestKit.Done;
end.

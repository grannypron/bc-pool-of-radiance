{ Tests for KeyHelp (#855): the Command Keys window lists a key only where and while it works. }
{$I COMPILER.INC}
program TKeyHelp;

uses C_SOUND, GameVars, KeyHelp, TestKit;

{ The table line whose key starts with k, or 0 for none. }
function LineOf(k: string): Byte;
var
  n: Byte;
begin
  LineOf := 0;
  for n := 1 to KeyHelp.KEY_LINES do
    if Copy(KeyHelp.KEYS[n].key, 1, Length(k)) = k then
      LineOf := n;
end;

{ Whether the line for key k shows, on a menu that takes F5 and F8 when quickKeys is set. }
function Shows(k: string; quickKeys: Boolean): Boolean;
begin
  Shows := (LineOf(k) <> 0) and KeyHelp.LineShown(LineOf(k), quickKeys);
end;

begin
  TestKit.Start('TKEYHELP');
  GameVars.companionOn := 0;
  GameVars.stingArg := False;
  GameVars.sound.mode := C_SOUND.MODE_DISABLED;
  TestKit.Check(Shows('F1 ', True) and Shows('F1 ', False), 'F1 always shows');
  TestKit.Check(Shows('F5 ', True) and Shows('F8 ', True), 'F5 and F8 show on the map menus');
  TestKit.Check(not Shows('F5 ', False) and not Shows('F8 ', False), 'but not in camp');
  TestKit.Check(not Shows('F6 ', True), 'F6 not with the Companion Tools off');
  GameVars.companionOn := 1;
  TestKit.Check(Shows('F6 ', True) and Shows('F6 ', False), 'and with them on, on either menu');
  TestKit.Check(not Shows('CTRL-Y', True), 'Ctrl-Y not without STING');
  GameVars.stingArg := True;
  TestKit.Check(Shows('CTRL-Y', True), 'and under STING');
  TestKit.Check(not Shows('CTRL-S', True), 'Ctrl-S not without a sound device');
  GameVars.sound.mode := C_SOUND.MODE_ADLIB;
  TestKit.Check(Shows('CTRL-S', True), 'and with one');
  TestKit.Check(LineOf('F2 ') = 0, 'no F2 line until the bestiary is in (#842)');
  TestKit.Done;
end.

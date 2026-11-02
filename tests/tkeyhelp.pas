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
  TestKit.Check(Shows('F2 ', True) and Shows('F2 ', False), 'F2, the Bestiary, shows on either menu (#842)');
  GameVars.combatLogOn := 0;
  TestKit.Check(not Shows('F7 ', True), 'F7 not with the Combat Log off');
  GameVars.combatLogOn := 1;
  TestKit.Check(Shows('F7 ', True) and Shows('F7 ', False), 'and with it on, on either menu (#903)');
  TestKit.Check((LineOf('ALT-1 ') <> 0) and (LineOf('ALT-8 ') <> 0), 'Alt-1 to Alt-8 are listed (#1175)');
  TestKit.Check(KeyHelp.KEYS[LineOf('ALT-1 ')].what = 'View PC 1''s inventory', 'as the member''s inventory');
  TestKit.Check(Shows('ALT-8 ', True) and Shows('ALT-8 ', False), 'on either menu');
  TestKit.Check(LineOf('ALT-1 ') = LineOf('F8 ') + 1, 'after the function keys');
  TestKit.Check(Shows('F3 ', True) and Shows('F3 ', False), 'F3, the combat minimap, shows on either menu (#1210)');
  TestKit.Check(LineOf('F3 ') = LineOf('F2 ') + 1, 'in key order');
  TestKit.Check(not KeyHelp.GroupGaps(True), 'with every line shown the groups lose their blank rows, to fit');
  GameVars.stingArg := False;
  GameVars.companionOn := 0;
  TestKit.Check(KeyHelp.GroupGaps(True) and KeyHelp.GroupGaps(False), 'with fewer they keep them');
  TestKit.Done;
end.

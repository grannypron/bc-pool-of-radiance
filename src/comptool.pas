{ The Companion Tools (phase 8 of docs/refactor-plan.md): the port's own versions of the Gold Box Companion's tools,
  which can no longer attach to it. F6 on the map and camp menus opens the Tools screen, outside combat, while the
  Companion Tools setting is on. }
{$O+,F+,I-}
unit CompTool;

interface

{ The Tools screen: Map (the whole area, explored squares and events marked), Notes (the player's notes on squares)
  and Character (the character editor), until Exit or Escape. Nothing happens with the setting off. The caller redraws
  its screen afterwards. }
procedure ToolsMenu;

implementation

uses Crt, C_Keys, C_Msg, GDVars, TextRend, Border, MenuCore;

{ The Tools screen's frame and title. }
procedure DrawTools;
begin
  TextRend.ClearScreen;
  Border.DrawBorder(C_Msg.TEXT_LEFT, C_Msg.TEXT_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, 0);
  TextRend.DisplayCentered(C_Msg.TEXT_LEFT, C_Msg.TEXT_RIGHT, 2, White, 'Companion Tools');
  TextRend.DisplayString(3, 5, LightGreen, 'Map        the whole area');
  TextRend.DisplayString(3, 6, LightGreen, 'Notes      your notes on it');
  TextRend.DisplayString(3, 7, LightGreen, 'Character  edit a character');
end;

{ A tool not built yet. }
procedure NotYet;
begin
  TextRend.DisplayAndPause(Yellow, 'Not built yet.');
  TextRend.ClearBottomLine;
end;

procedure ToolsMenu;
var
  ch: Char;
  ext: Boolean;
begin
  if GDVars.companionOn = 0 then Exit;
  DrawTools;
  repeat
    ch := MenuCore.MenuHorizontal('Tools: ', 'Map Notes Character Exit', LightMagenta, LightGreen, White, False,
                                  False, ext);
    case ch of
      'M', 'N', 'C': NotYet;
    end;
  until ch in [C_Keys.NONE, 'E'];
  TextRend.ClearBottomLine;
end;

end.

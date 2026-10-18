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

uses Crt, Types, C_Area, C_Dir, C_Keys, C_Msg, GDConsts, GDVars, TextRend, Border, MenuCore, Blit, View3D, AreaName,
  Explored, StrUtil;

const
  { the map's top-left character cell; a square is one 8x8 symbol }
  MAP_COL = 2;
  MAP_ROW = 3;
  { the legend's column, right of the map }
  LEGEND_COL = 20;
  { symbol set 4 (GDConsts.symSetFirst[4] = 256): the party's arrows by facing div 2, then the sixteen wall
    combinations, 260 + N + E * 2 + S * 4 + W * 8, as View3D.DrawAutoMap draws them }
  SYM_SET = 4;
  SYM_ARROW = 256;
  SYM_WALLS = 260;

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

{ Draw symbol at (col, row), straight to the screen, a step darker when dim; in CGA's four colours, which draw both
  greys alike, a square not dim has white walls instead. }
procedure ShowSymbol(col, row: ShortInt; symbol: Word; dim: Boolean);
var
  symbols: Types.PImgBuf;
  glyph: Types.PImgBuf;
  fromT: Types.TColorTab;
  toT: Types.TColorTab;
  c: Byte;
begin
  symbols := GDVars.dsSymbolSetPtrs[SYM_SET];
  glyph := GDVars.dsCurrent8x8SymbolPtr2;
  if (symbols = nil) or (glyph = nil) then Exit;
  Move(symbols^.data[(symbol - GDConsts.symSetFirst[SYM_SET]) * symbols^.imgSize], glyph^.data, symbols^.imgSize);
  { the set's colour map, which CGA's remap translates the tables' colours through }
  glyph^.map := symbols^.map;
  for c := 0 to 15 do begin
    fromT[c] := c;
    toT[c] := c;
  end;
  if GDVars.video.colours >= 16 then begin
    { the symbols draw light grey and white walls on a dark grey square: dimmed, the walls go dark grey and the square
      black }
    if dim then begin
      toT[DarkGray] := Black;
      toT[LightGray] := DarkGray;
      toT[White] := DarkGray;
      Blit.RemapPic(fromT, toT, 0, False, glyph);
    end;
  end else if not dim then begin
    { CGA draws both greys in one of its colours, so they look alike: there a visited square's light grey walls are
      white instead }
    toT[LightGray] := White;
    Blit.RemapPic(fromT, toT, 0, False, glyph);
  end;
  Blit.ShowPic(col, row, glyph);
end;

{ The whole current 3D area: every square's walls (secret ones too, as the map data holds them), the visited squares
  in their colours and the rest dimmed, the party's arrow on its square, and a legend. }
procedure DrawMap;
var
  mx: ShortInt;
  my: ShortInt;
  sym: Word;
  script: Byte;
  map: Byte;
begin
  TextRend.ClearScreen;
  Border.DrawBorder(C_Msg.TEXT_LEFT, C_Msg.TEXT_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, 0);
  TextRend.DisplayString(MAP_COL, 1, White, AreaName.CurrentArea);
  script := GDVars.eclScriptId;
  map := GDVars.zone0^.mapId.lo;
  for my := 0 to 15 do
    for mx := 0 to 15 do begin
      sym := SYM_WALLS;
      if View3D.GetWallType(mx, my, C_Dir.NORTH) > 0 then Inc(sym);
      if View3D.GetWallType(mx, my, C_Dir.EAST) > 0 then Inc(sym, 2);
      if View3D.GetWallType(mx, my, C_Dir.SOUTH) > 0 then Inc(sym, 4);
      if View3D.GetWallType(mx, my, C_Dir.WEST) > 0 then Inc(sym, 8);
      ShowSymbol(MAP_COL + mx, MAP_ROW + my, sym, not Explored.Visited(script, map, mx, my));
    end;
  ShowSymbol(MAP_COL + GDVars.gMapX, MAP_ROW + GDVars.gMapY, SYM_ARROW + GDVars.gFacing div 2, False);
  TextRend.DisplayString(LEGEND_COL, MAP_ROW, LightGreen, 'Bright: visited');
  TextRend.DisplayString(LEGEND_COL, MAP_ROW + 1, DarkGray, 'Dim: not yet');
  TextRend.DisplayString(LEGEND_COL, MAP_ROW + 3, LightGreen, 'Party at ' + StrUtil.NumStr(GDVars.gMapX) + ',' +
                         StrUtil.NumStr(GDVars.gMapY));
end;

{ The Map tool: the whole area until Exit or Escape. The wilderness has its own map, so there it only says so. }
procedure MapTool;
var
  ch: Char;
  ext: Boolean;
begin
  if GDVars.gLocType <> C_Area.LOC_3D_MAP then begin
    TextRend.DisplayAndPause(Yellow, 'The wilderness has its own map.');
    TextRend.ClearBottomLine;
    Exit;
  end;
  DrawMap;
  repeat
    ch := MenuCore.MenuHorizontal('Map: ', 'Exit', LightMagenta, LightGreen, White, False, False, ext);
  until ch in [C_Keys.NONE, 'E'];
  TextRend.ClearBottomLine;
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
      'M': begin
             MapTool;
             DrawTools;
           end;
      'N', 'C': NotYet;
    end;
  until ch in [C_Keys.NONE, 'E'];
  TextRend.ClearBottomLine;
end;

end.

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
  Explored, EvtKind, StrUtil;

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
  { the square colour of each event kind, EvtKind's KIND_EVENT to KIND_EXIT, and its legend }
  KIND_COLOURS: array[EvtKind.KIND_EVENT..EvtKind.KIND_EXIT] of Byte = (Blue, Cyan, Red, Brown, Green, Magenta,
                                                                         LightBlue);
  { CGA's: its three colours besides black, shared by kinds alike (people, danger, places) }
  KIND_COLOURS_CGA: array[EvtKind.KIND_EVENT..EvtKind.KIND_EXIT] of Byte = (Cyan, Cyan, Magenta, White, White,
                                                                             Magenta, White);
  KIND_NAMES: array[EvtKind.KIND_EVENT..EvtKind.KIND_EXIT] of string[8] = ('event', 'message', 'trap', 'treasure',
                                                                           'service', 'fight', 'exit');

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

{ Draw symbol at (col, row), straight to the screen, a step darker when dim, on a square of colour fill unless fill is
  DarkGray (the symbols' own); in CGA's four colours, which draw both greys alike, a square not dim has white walls
  instead. }
procedure ShowSymbol(col, row: ShortInt; symbol: Word; dim: Boolean; fill: Byte);
var
  symbols: Types.PImgBuf;
  glyph: Types.PImgBuf;
  fromT: Types.TColorTab;
  toT: Types.TColorTab;
  c: Byte;
  remap: Boolean;
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
    end;
  end else if not dim then
    { CGA draws both greys in one of its colours, so they look alike: there a visited square's light grey walls are
      white instead }
    toT[LightGray] := White;
  if fill <> DarkGray then
    toT[DarkGray] := fill;
  remap := False;
  for c := 0 to 15 do
    if toT[c] <> c then
      remap := True;
  if remap then
    Blit.RemapPic(fromT, toT, 0, False, glyph);
  Blit.ShowPic(col, row, glyph);
end;

{ The square colour of event kind in the current video mode. }
function KindColour(kind: Byte): Byte;
begin
  if GDVars.video.colours >= 16 then
    KindColour := KIND_COLOURS[kind]
  else
    KindColour := KIND_COLOURS_CGA[kind];
end;

{ The whole current 3D area: every square's walls (secret ones too, as the map data holds them), the visited squares
  in their colours and the rest dimmed, each event square coloured by what its event does (EvtKind), the party's arrow
  on its square, and a legend. }
procedure DrawMap;
var
  mx: ShortInt;
  my: ShortInt;
  sym: Word;
  script: Byte;
  map: Byte;
  kind: Byte;
  fill: Byte;
  used: array[EvtKind.KIND_EVENT..EvtKind.KIND_EXIT] of Boolean;
  row: Byte;
begin
  EvtKind.Prepare;
  FillChar(used, SizeOf(used), False);
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
      kind := EvtKind.Kind(View3D.GetMapEvent(mx, my));
      fill := DarkGray;
      if kind <> EvtKind.KIND_NONE then begin
        fill := KindColour(kind);
        used[kind] := True;
      end;
      ShowSymbol(MAP_COL + mx, MAP_ROW + my, sym, not Explored.Visited(script, map, mx, my), fill);
    end;
  ShowSymbol(MAP_COL + GDVars.gMapX, MAP_ROW + GDVars.gMapY, SYM_ARROW + GDVars.gFacing div 2, False, DarkGray);
  TextRend.DisplayString(LEGEND_COL, MAP_ROW, LightGreen, 'Bright: visited');
  TextRend.DisplayString(LEGEND_COL, MAP_ROW + 1, DarkGray, 'Dim: not yet');
  TextRend.DisplayString(LEGEND_COL, MAP_ROW + 3, LightGreen, 'Party at ' + StrUtil.NumStr(GDVars.gMapX) + ',' +
                         StrUtil.NumStr(GDVars.gMapY));
  { the kinds this area has, each beside a square of its colour }
  row := MAP_ROW + 5;
  for kind := EvtKind.KIND_EVENT to EvtKind.KIND_EXIT do
    if used[kind] then begin
      ShowSymbol(LEGEND_COL, row, SYM_WALLS, False, KindColour(kind));
      TextRend.DisplayString(LEGEND_COL + 2, row, LightGreen, KIND_NAMES[kind]);
      Inc(row);
    end;
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

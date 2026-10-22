{ Update dungeon and wilderness views from the current map state. }
{$O+,F+}
{$I COMPILER.INC}
unit MapView;

interface

{ Draw the 3D view (location type 1, or any location while zone0^.view3dFlag is set) or the wilderness map (types
  2..4) }
procedure DisplayMapView;

{ Draw the party's animated icon on the wilderness map, advance the 6-step animation frame and flush the view }
procedure DisplayWildMapView;

implementation

uses Crt, C_AREA, GameDefs, GameVars, Wilds, View3D, Blit, MapTiles;

{ Draw the party icon at its cell wx/wy in the 5x5 view. The view is centered on the party except near a map edge, where
  DisplayMapView pins it and the icon moves off center: below 2 the icon keeps the party's own cell, and 42/43 and 34/35
  are the last two columns and rows of GameDefs.wildMap. Nothing is drawn outside a wilderness location. }
procedure DisplayWildMapView;
var
  wx: ShortInt;
  wy: Byte;
begin
  if not (GameVars.gLocType in [C_AREA.LOC_WILD_WEST..C_AREA.LOC_WILD_EAST]) then Exit;
  wx := GameDefs.wildColOfs[GameVars.gLocType] + GameVars.zone0^.partyX.value;
  if wx < 2 then
  else if wx < 42 then wx := 2
  else if wx < 43 then wx := 3
  else wx := 4;
  if GameVars.zone0^.partyY.value < 2 then wy := GameVars.zone0^.partyY.value
  else if GameVars.zone0^.partyY.value < 34 then wy := 2
  else if GameVars.zone0^.partyY.value < 35 then wy := 3
  else wy := 4;
  MapTiles.DrawIconAnimSprite(wx, wy, GameVars.gFacing, GameVars.wildAnimFrame mod 2,
                              GameVars.wildAnimFrame div 2 + 9);
  GameVars.wildAnimFrame := (GameVars.wildAnimFrame + 1) mod 6;
  Blit.FlushView;
end;

{ Draw the current map view. For the 3D view, take the sky or ceiling color from the zone (its alternate color when the
  cell's event value is above $7F; a selector counts modulo 16), recompute the ceiling, floor and wall colors from their
  selectors while picRegionW is set, and pass all four to View3D.SetView3DColors before View3D.Display3DMapView draws.
  For the wilderness, center the 5x5 view on the party, clamped to the map, then draw the party icon. }
procedure DisplayMapView;
const
  { Display color for each zone sky/ceiling selector; selectors 8..15 repeat 0..7. }
  skyCeilingColors: array[0..15] of Byte = (
    Black,
    White,
    LightRed,
    LightCyan,
    LightMagenta,
    LightGreen,
    LightBlue,
    Yellow,
    Black,
    White,
    LightRed,
    LightCyan,
    LightMagenta,
    LightGreen,
    LightBlue,
    Yellow);
var
  wx: ShortInt;
  wy: ShortInt;
  loc: Byte;

  { Ceiling color for a ceiling/floor color selector. }
  function CeilColor(w: Byte): Byte;
  begin
    case w of
      8: CeilColor := Black;
      65: CeilColor := Black;
      232: CeilColor := White;
      else CeilColor := White;
    end;
  end;

  { Floor color for a ceiling/floor color selector. }
  function FloorColor(w: Byte): Byte;
  begin
    case w of
      8: FloorColor := DarkGray;
      65: FloorColor := LightGray;
      232: FloorColor := LightGray;
      else FloorColor := LightGray;
    end;
  end;

  { Wall color for a wall color selector. }
  function WallColor(w: Byte): Byte;
  begin
    case w of
      11: WallColor := DarkGray;
      9: WallColor := Brown;
      219: WallColor := Brown;
      6: WallColor := Blue;
      else WallColor := Brown;
    end;
  end;

begin
  loc := GameVars.gLocType;
  if GameVars.zone0^.view3dFlag <> 0 then loc := C_AREA.LOC_3D_MAP;
  case loc of
    C_AREA.LOC_3D_MAP: begin
      GameVars.eventAtCell := View3D.GetMapEvent(GameVars.gMapX, GameVars.gMapY);
      if GameVars.eventAtCell > $7F then
        View3D.colorSkyCeiling := skyCeilingColors[GameVars.zone0^.alternateSkyColor and $0F]
      else
        View3D.colorSkyCeiling := skyCeilingColors[GameVars.zone0^.skyCeilingColor and $0F];
      if GameVars.picRegionW then begin
        View3D.wallColorA := CeilColor(GameVars.ceilFloorColorSel);
        View3D.wallColorB := FloorColor(GameVars.ceilFloorColorSel);
        View3D.wallColorC := WallColor(GameVars.wallColorSel);
      end;
      View3D.SetView3DColors(View3D.colorSkyCeiling, View3D.wallColorA, View3D.wallColorB, View3D.wallColorC);
      if GameVars.zone0^.noAutomap <> 0 then GameVars.automapOn := False;
      View3D.Display3DMapView(GameVars.gMapX, GameVars.gMapY, GameVars.gFacing);
    end;
    C_AREA.LOC_WILD_WEST..C_AREA.LOC_WILD_EAST: begin
      wx := GameDefs.wildColOfs[loc] + GameVars.zone0^.partyX.value - 1 - 1;
      if wx < 0 then wx := 0;
      { last column origin for the 5-wide view }
      if wx > 39 then wx := 39;
      wy := GameVars.zone0^.partyY.value - 1 - 1;
      if wy < 0 then wy := 0;
      { last row origin for the 5-tall view }
      if wy > 31 then wy := 31;
      Wilds.BuildWildernessMap(wx, wy);
      MapView.DisplayWildMapView;
    end;
  end;
end;

end.

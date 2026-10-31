{ Update dungeon and wilderness views from the current map state. }
{$O+,F+}
{$I COMPILER.INC}
unit MapView;

interface

{ Draws either the 3D view or the wilderness map for the current location. }
procedure DisplayMapView;

{ Draws and advances the party's six-frame wilderness animation. }
procedure DisplayWildMapView;

{ Resets the wilderness animation for a new game. }
procedure ResetGame;

implementation

uses Crt, C_AREA, GameDefs, GameVars, Wilds, View3D, Blit, MapTiles, JrnlSeen;

var
  { Party icon frame, 0..5: parity selects the icon frame, div 2 the icon animation. }
  wildAnimFrame: Byte;

{ The party's map cell, column (col) and row, in the wilderness of location type loc. }
procedure PartyCell(loc: Byte; var col, row: Integer);
begin
  col := GameDefs.wildColOfs[loc] + Integer(GameVars.zone0^.partyX.value);
  row := Integer(GameVars.zone0^.partyY.value);
end;

{ The corner of the 5x5 view centered on map cell cell, along a map side whose last cell is last, moved inside the map
  as Wilds.BuildWildernessMap moves it. }
function CenteredCorner(cell, last: Integer): Integer;
begin
  CenteredCorner := Wilds.ViewCorner(cell - C_AREA.WILD_VIEW_LAST div 2, last);
end;

{ Draw the party icon at its cell in the 5x5 view. The view is centered on the party except near a map edge, where it
  is moved inside the map (CenteredCorner) and the icon moves off center. Nothing is drawn outside a wilderness
  location. }
procedure DisplayWildMapView;
var
  col: Integer;
  row: Integer;
begin
  if not (GameVars.gLocType in [C_AREA.LOC_WILD_WEST..C_AREA.LOC_WILD_EAST]) then Exit;
  MapView.PartyCell(GameVars.gLocType, col, row);
  MapTiles.DrawIconAnimSprite(col - MapView.CenteredCorner(col, C_AREA.WILD_LAST_COL),
                              row - MapView.CenteredCorner(row, C_AREA.WILD_LAST_ROW), GameVars.gFacing,
                              wildAnimFrame mod 2, wildAnimFrame div 2 + MapTiles.FIRST_WILD_ICON);
  wildAnimFrame := (wildAnimFrame + 1) mod 6;
  Blit.FlushView;
end;

{ Draw the current map view. For the 3D view, take the sky or ceiling color from the zone (its alternate color when the
  cell's event value is above $7F; a selector counts modulo 8), recompute the horizon line, horizon band and floor
  colors from their selectors while picRegionW is set, and pass all four to View3D.SetView3DColors before
  View3D.Display3DMapView draws. For the wilderness, center the 5x5 view on the party, moved inside the map, then draw
  the party icon. }
procedure DisplayMapView;
const
  { Display color for each zone sky/ceiling selector, counted modulo 8. }
  skyColors: array[0..7] of Byte = (
    Black,
    White,
    LightRed,
    LightCyan,
    LightMagenta,
    LightGreen,
    LightBlue,
    Yellow);
var
  col: Integer;
  row: Integer;
  loc: Byte;

  { The horizon line's color (View3D.ceilingBandColor) for a ceiling/floor color selector; SSI's code also named 232, as
    White. }
  function CeilColor(w: Byte): Byte;
  begin
    if w in [8, 65] then
      CeilColor := Black
    else
      CeilColor := White;
  end;

  { The horizon band's color (View3D.midBandColor) for a ceiling/floor color selector; SSI's code also named 65 and 232,
    as LightGray. }
  function FloorColor(w: Byte): Byte;
  begin
    if w = 8 then
      FloorColor := DarkGray
    else
      FloorColor := LightGray;
  end;

  { The floor band's color (View3D.floorBandColor) for a wall color selector; SSI's code also named 9 and 219, as
    Brown. }
  function WallColor(w: Byte): Byte;
  begin
    case w of
      11: WallColor := DarkGray;
      6: WallColor := Blue;
    else
      WallColor := Brown;
    end;
  end;

begin
  loc := GameVars.gLocType;
  if GameVars.zone0^.view3dFlag <> 0 then loc := C_AREA.LOC_3D_MAP;
  case loc of
    C_AREA.LOC_3D_MAP: begin
      GameVars.eventAtCell := View3D.GetMapEvent(GameVars.gMapX, GameVars.gMapY);
      if GameVars.eventAtCell > $7F then
        View3D.skyCeilingColor := skyColors[GameVars.zone0^.alternateSkyColor and 7]
      else
        View3D.skyCeilingColor := skyColors[GameVars.zone0^.skyCeilingColor and 7];
      if GameVars.picRegionW then begin
        View3D.ceilingBandColor := CeilColor(GameVars.ceilFloorColorSel);
        View3D.midBandColor := FloorColor(GameVars.ceilFloorColorSel);
        View3D.floorBandColor := WallColor(GameVars.wallColorSel);
      end;
      View3D.SetView3DColors(View3D.skyCeilingColor, View3D.ceilingBandColor, View3D.midBandColor,
                             View3D.floorBandColor);
      if not JrnlSeen.AreaMapAllowed then GameVars.automapOn := False;
      View3D.Display3DMapView(GameVars.gMapX, GameVars.gMapY, GameVars.gFacing);
    end;
    C_AREA.LOC_WILD_WEST..C_AREA.LOC_WILD_EAST: begin
      MapView.PartyCell(loc, col, row);
      Wilds.BuildWildernessMap(MapView.CenteredCorner(col, C_AREA.WILD_LAST_COL),
                               MapView.CenteredCorner(row, C_AREA.WILD_LAST_ROW));
      MapView.DisplayWildMapView;
    end;
  end;
end;

procedure ResetGame;
begin
  wildAnimFrame := 0;
end;

end.

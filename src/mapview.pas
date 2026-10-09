{ Update dungeon and wilderness views from the current map state. }
{$O+,F+}
unit MapView;

interface

uses Crt, C_Area, GDConsts, GDVars, Wilds, View3D;

{ Draw the 3D view (location type 1, or any location while zone0^.view3dFlag is set) or the wilderness map (types
  2..4) }
procedure DisplayMapView;

{ Draw the party's animated icon on the wilderness map, advance the 6-step animation frame and flush the view }
procedure DisplayWildMapView;

implementation

{ Draw the party icon at its cell wx/wy in the 5x5 view. The view is centered on the party except near a map edge, where
  DisplayMapView pins it and the icon moves off center: below 2 the icon keeps the party's own cell, and 42/43 and 34/35
  are the last two columns and rows of GDConsts.wildMap. }
procedure DisplayWildMapView;
var
  wx: ShortInt;
  wy: Byte;
begin
  wx := GDConsts.wildColOfs[GDVars.gLocType] + GDVars.zone0^.partyX.value;
  if wx < 2 then
  else if wx < 42 then wx := 2
  else if wx < 43 then wx := 3
  else wx := 4;
  if GDVars.zone0^.partyY.value < 2 then wy := GDVars.zone0^.partyY.value
  else if GDVars.zone0^.partyY.value < 34 then wy := 2
  else if GDVars.zone0^.partyY.value < 35 then wy := 3
  else wy := 4;
  MapTiles.DrawIconAnimSprite(wx, wy, GDVars.gFacing, GDVars.dsWildAnimFrame mod 2,
                              GDVars.dsWildAnimFrame div 2 + 9);
  GDVars.dsWildAnimFrame := (GDVars.dsWildAnimFrame + 1) mod 6;
  Blit.FlushView;
end;

{ Draw the current map view. For the 3D view, take the sky or ceiling color from the zone (its alternate color when the
  cell's event value is above $7F), recompute the ceiling, floor and wall colors from their selectors while picRegionW
  is set, and pass all four to View3D.SetView3DColors before View3D.Display3DMapView draws. For the wilderness, center
  the 5x5 view on the party, clamped to the map, then draw the party icon. }
procedure DisplayMapView;
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
  loc := GDVars.gLocType;
  if GDVars.zone0^.view3dFlag <> 0 then loc := C_Area.LOC_3D_MAP;
  case loc of
    C_Area.LOC_3D_MAP: begin
      GDVars.eventAtCell := View3D.GetMapEvent(GDVars.gMapX, GDVars.gMapY);
      if GDVars.eventAtCell > $7F then
        GDVars.dsColorSkyCeiling := GDConsts.skyCeilingColors[GDVars.zone0^.alternateSkyColor]
      else
        GDVars.dsColorSkyCeiling := GDConsts.skyCeilingColors[GDVars.zone0^.skyCeilingColor];
      if GDVars.picRegionW then begin
        GDVars.dsWallColorA := CeilColor(GDVars.ceilFloorColorSel);
        GDVars.dsWallColorB := FloorColor(GDVars.ceilFloorColorSel);
        GDVars.dsWallColorC := WallColor(GDVars.wallColorSel);
      end;
      View3D.SetView3DColors(GDVars.dsColorSkyCeiling, GDVars.dsWallColorA, GDVars.dsWallColorB,
                             GDVars.dsWallColorC);
      if GDVars.zone0^.noAutomap <> 0 then GDVars.automapOn := False;
      View3D.Display3DMapView(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing);
    end;
    C_Area.LOC_WILD_WEST..C_Area.LOC_WILD_EAST: begin
      wx := GDConsts.wildColOfs[loc] + GDVars.zone0^.partyX.value - 1 - 1;
      if wx < 0 then wx := 0;
      { last column origin for the 5-wide view }
      if wx > 39 then wx := 39;
      wy := GDVars.zone0^.partyY.value - 1 - 1;
      if wy < 0 then wy := 0;
      { last row origin for the 5-tall view }
      if wy > 31 then wy := 31;
      Wilds.BuildWildernessMap(wx, wy);
      MapView.DisplayWildMapView;
    end;
  end;
end;

end.

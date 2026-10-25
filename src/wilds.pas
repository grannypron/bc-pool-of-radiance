{ Build and display the wilderness map. }
{$O+,F+}
{$I COMPILER.INC}
unit Wilds;

interface

{ Build the wilderness view: walk the 5x5 cells from map cell (ulX, ulY), look each up in GameDefs.wildMap, apply the
  special-location overrides gated on zone-0 quest flags, and draw each 24x24 tile three character cells apart through
  MapTiles.Copy2DTile. The corner is first moved so the 5x5 view lies inside the 44x36 map (ViewCorner). }
procedure BuildWildernessMap(ulX, ulY: Integer);

{ Corner ul of the 5x5 wilderness view, along a map side whose last cell is last (C_AREA.WILD_LAST_COL or
  WILD_LAST_ROW), moved so that the view lies inside the map. }
function ViewCorner(ul, last: Integer): Integer;

{ Draw the empty bordered windows of the wilderness screen: two side by side at the top and the message area. }
procedure DrawWildWindows;

implementation

uses Types, Crt, C_AREA, C_MSG, GameDefs, GameVars, Border, MapTiles, TextRend;

const
  { 10,9 = western 10,9, in Dragon Den Pass }
  WILD_SILVER_DRAGON_DEN = 1;
  { 3,32 = western 3,32 }
  WILD_ZHENTIL_OUTPOST = 2;
  { 12,31 = western 12,31 }
  WILD_BUCCANEERS_BASE = 3;
  { 25,11 = central 12,11 }
  WILD_NOMAD_CAMP = 4;
  { 32,15 = eastern 6,15 }
  WILD_KOBOLD_CAVES = 5;
  { Hills icon, always drawn at this location. }
  WILD_UNNAMED_SITE = 6;
  { 37,8 = eastern 11,8 }
  WILD_LIZARD_MAN_KEEP = 7;
  { 19,16 = central 6,16, Yarash's island }
  WILD_SORCERERS_ISLAND = 8;
  { 25,27 = central 12,27 }
  WILD_PHLAN = 9;
  { the last special location }
  WILD_LAST_SITE = WILD_PHLAN;

function ViewCorner(ul, last: Integer): Integer;
begin
  if ul > last - C_AREA.WILD_VIEW_LAST then ul := last - C_AREA.WILD_VIEW_LAST;
  if ul < 0 then ul := 0;
  ViewCorner := ul;
end;

{ GameDefs.wildMap and the override table both hold 1-based tile ids, hence each - 1. }
procedure BuildWildernessMap(ulX, ulY: Integer);
const
  { Special-location overrides on the 44x36 wilderness map, indexed by the WILD_* constants. Entries 1 and 2 have no
    case arm in BuildWildernessMap, so their icons are never applied. x/y are map cells; icon is a 1-based tile id. }
  wildernessSpecialLocations: array[1..WILD_LAST_SITE] of Types.TSpecLoc = (
    { 1 WILD_SILVER_DRAGON_DEN }  (x: 10; y:  9; icon: 240),
    { 2 WILD_ZHENTIL_OUTPOST }    (x:  3; y: 32; icon:   2),
    { 3 WILD_BUCCANEERS_BASE }    (x: 12; y: 31; icon:   2),
    { 4 WILD_NOMAD_CAMP }         (x: 25; y: 11; icon:   1),
    { 5 WILD_KOBOLD_CAVES }       (x: 32; y: 15; icon: 165),
    { 6 WILD_UNNAMED_SITE }       (x: 33; y: 23; icon: 157),
    { 7 WILD_LIZARD_MAN_KEEP }    (x: 37; y:  8; icon: 147),
    { 8 WILD_SORCERERS_ISLAND }   (x: 19; y: 16; icon: 247),
    { 9 WILD_PHLAN }              (x: 25; y: 27; icon: 256)
  );
var
  viewX: ShortInt;
  viewY: ShortInt;
  k: ShortInt;
  mapX: ShortInt;
  mapY: ShortInt;
  icon: Byte;
  col: Byte;
  row: Byte;
begin
  ulX := Wilds.ViewCorner(ulX, C_AREA.WILD_LAST_COL);
  ulY := Wilds.ViewCorner(ulY, C_AREA.WILD_LAST_ROW);
  viewY := 0;
  for row := 0 to C_AREA.WILD_VIEW_LAST do begin
    viewX := 0;
    for col := 0 to C_AREA.WILD_VIEW_LAST do begin
      mapX := col + ulX;
      mapY := row + ulY;
      icon := GameDefs.wildMap[mapY, mapX] - 1;
      for k := 1 to WILD_LAST_SITE do begin
        if (mapX = wildernessSpecialLocations[k].x) and
            (mapY = wildernessSpecialLocations[k].y) then begin
          case k of
            WILD_BUCCANEERS_BASE: begin
              if GameVars.zone0^.buccaneersBaseVisible <> 255 then
                icon := wildernessSpecialLocations[k].icon - 1;
            end;
            WILD_NOMAD_CAMP: begin
              if (GameVars.zone0^.nomadCampPresent <> 0) or ((GameVars.zone0^.nomadCampFlags and 8) <> 0)
                 or (GameVars.zone0^.nomadCampGate = 0) then
                icon := wildernessSpecialLocations[k].icon - 1;
            end;
            WILD_KOBOLD_CAVES: begin
              if (GameVars.zone0^.easternSitesGate and 2) = 0 then
                icon := wildernessSpecialLocations[k].icon - 1;
            end;
            WILD_UNNAMED_SITE: icon := wildernessSpecialLocations[k].icon - 1;
            WILD_LIZARD_MAN_KEEP: begin
              if (GameVars.zone0^.easternSitesGate and 1) = 0 then
                icon := wildernessSpecialLocations[k].icon - 1;
            end;
            WILD_SORCERERS_ISLAND, WILD_PHLAN: begin
              if GameVars.zone0^.yarashMissionDone > 253 then
                icon := wildernessSpecialLocations[k].icon - 1;
            end;
          end;
        end;
      end;
      MapTiles.Copy2DTile(viewX, viewY, icon, 1);
      Inc(viewX, 3);
    end;
    Inc(viewY, 3);
  end;
end;

procedure DrawWildWindows;
begin
  Border.DrawWindow(1, 1, 15, 15, 0, Black, '');
  Border.DrawWindow(17, 1, 38, 15, 0, Black, '');
  Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.MESSAGE_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0, Black, '');
end;

end.

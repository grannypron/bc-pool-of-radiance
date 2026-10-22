{ Build and display the wilderness map. }
{$O+,F+}
{$I COMPILER.INC}
unit Wilds;

interface

{ Build the wilderness view: walk the 5x5 cells from map cell (ulX, ulY), look each up in GDConsts.wildMap, apply the
  special-location overrides gated on zone-0 quest flags, and draw each 24x24 tile three character cells apart through
  MapTiles.Copy2DTile. The corner is first moved so the 5x5 view lies inside the 44x36 map. }
procedure BuildWildernessMap(ulX, ulY: Integer);

{ Draw the empty bordered windows of the wilderness screen: two side by side at the top and the message area. }
procedure DrawWildWindows;

implementation

uses Types, Crt, C_Msg, GDConsts, GDVars, Border, MapTiles, TextRend;

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

{ GDConsts.wildMap and the override table both hold 1-based tile ids, hence each - 1. }
procedure BuildWildernessMap(ulX, ulY: Integer);
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
  if ulX < 0 then ulX := 0;
  { last column origin for the 5-wide view }
  if ulX > 39 then ulX := 39;
  if ulY < 0 then ulY := 0;
  { last row origin for the 5-tall view }
  if ulY > 31 then ulY := 31;
  viewY := 0;
  for row := 0 to 4 do begin
    viewX := 0;
    for col := 0 to 4 do begin
      mapX := col + ulX;
      mapY := row + ulY;
      icon := GDConsts.wildMap[mapY, mapX] - 1;
      { 9 = High(wildernessSpecialLocations) }
      for k := 1 to 9 do begin
        if (mapX = GDConsts.wildernessSpecialLocations[k].x) and
            (mapY = GDConsts.wildernessSpecialLocations[k].y) then begin
          case k of
            WILD_BUCCANEERS_BASE: begin
              if GDVars.zone0^.buccaneersBaseGate <> 255 then
                icon := GDConsts.wildernessSpecialLocations[k].icon - 1;
            end;
            WILD_NOMAD_CAMP: begin
              if (GDVars.zone0^.nomadCampPresent <> 0) or ((GDVars.zone0^.nomadCampFlags and 8) <> 0)
                 or (GDVars.zone0^.nomadCampGate = 0) then
                icon := GDConsts.wildernessSpecialLocations[k].icon - 1;
            end;
            WILD_KOBOLD_CAVES: begin
              if (GDVars.zone0^.easternSitesGate and 2) = 0 then
                icon := GDConsts.wildernessSpecialLocations[k].icon - 1;
            end;
            WILD_UNNAMED_SITE: icon := GDConsts.wildernessSpecialLocations[k].icon - 1;
            WILD_LIZARD_MAN_KEEP: begin
              if (GDVars.zone0^.easternSitesGate and 1) = 0 then
                icon := GDConsts.wildernessSpecialLocations[k].icon - 1;
            end;
            WILD_SORCERERS_ISLAND, WILD_PHLAN: begin
              if GDVars.zone0^.yarashMissionDone > 253 then
                icon := GDConsts.wildernessSpecialLocations[k].icon - 1;
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
  Border.DrawWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, 0, Black, '');
end;

end.

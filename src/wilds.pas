{ Build and display the wilderness map. }
{$O+,F+}
{$I COMPILER.INC}
unit Wilds;

interface

{ Draws a 5x5 wilderness view from the 44x36 map. Clamp the requested corner,
  apply quest-dependent location icons, then draw each 24x24 tile. }
procedure BuildWildernessMap(ulX, ulY: Integer);

{ Clamps one coordinate of the 5x5 view so it remains inside the map. }
function ViewCorner(ul, last: Integer): Integer;

{ Draw the empty bordered windows of the wilderness screen: two side by side at the top and the message area. }
procedure DrawWildWindows;

const
  { What a wilderness step meets (TileStep, StepTo): open ground; impassable terrain; the river, while its stench
    drives the party back; a diagonal between two cells that are not open (#1159). }
  STEP_OPEN = 0;
  STEP_BLOCKED = 1;
  STEP_RIVER = 2;
  STEP_CORNER = 3;
  { the hours a straight step takes, and a diagonal one (#1159) }
  STEP_HOURS = 12;
  DIAGONAL_HOURS = 18;

{ What wilderness map tile (GameDefs.wildMap's 1-based id) is to a step: STEP_BLOCKED for an impassable glyph,
  STEP_RIVER for the river's while riverShut, else STEP_OPEN. }
function TileStep(tile: Byte; riverShut: Boolean): Byte;

{ A step from (x, y) toward dir (C_DIR) in the region whose 16-column window starts at map column colOfs. nx and ny
  get the cell it ends on, held to the region (columns 0..C_AREA.WILD_REGION_LAST_COL, rows 0..C_AREA.WILD_LAST_ROW);
  the result is TileStep of that cell, except that a step that ends diagonally from (x, y), with both orthogonal cells
  beside it not STEP_OPEN, is STEP_CORNER: the party can't cut that corner. One open side lets it past (#1159). }
function StepTo(x, y: ShortInt; dir, colOfs: Byte; riverShut: Boolean; var nx, ny: ShortInt): Byte;

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
  { Quest-dependent wilderness icons, indexed by the WILD_* constants. x/y are
    map cells and icon is a one-based tile ID. Entries 1 and 2 intentionally
    have no case arm and are never applied. }
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
      MapTiles.Copy2DTile(viewX, viewY, icon);
      Inc(viewX, 3);
    end;
    Inc(viewY, 3);
  end;
end;

function TileStep(tile: Byte; riverShut: Boolean): Byte;
begin
  case tile of
    78, 126..128, 130..132, 168..172, 174..179, 188, 221..222, 225..233, 245: TileStep := STEP_BLOCKED;
    102..108, 114: if riverShut then
                     TileStep := STEP_RIVER
                   else
                     TileStep := STEP_OPEN;
  else
    TileStep := STEP_OPEN;
  end;
end;

function StepTo(x, y: ShortInt; dir, colOfs: Byte; riverShut: Boolean; var nx, ny: ShortInt): Byte;
var
  meets: Byte;
begin
  nx := x + GameDefs.dirDX[dir];
  ny := y + GameDefs.dirDY[dir];
  if nx < 0 then nx := 0;
  if nx > C_AREA.WILD_REGION_LAST_COL then nx := C_AREA.WILD_REGION_LAST_COL;
  if ny < 0 then ny := 0;
  if ny > C_AREA.WILD_LAST_ROW then ny := C_AREA.WILD_LAST_ROW;
  meets := Wilds.TileStep(GameDefs.wildMap[ny, nx + colOfs], riverShut);
  { the cells beside a diagonal step are (nx, y) and (x, ny), both on the map once nx and ny are }
  if (meets = STEP_OPEN) and (nx <> x) and (ny <> y) and
     (Wilds.TileStep(GameDefs.wildMap[y, nx + colOfs], riverShut) <> STEP_OPEN) and
     (Wilds.TileStep(GameDefs.wildMap[ny, x + colOfs], riverShut) <> STEP_OPEN) then
    meets := STEP_CORNER;
  StepTo := meets;
end;

procedure DrawWildWindows;
begin
  { the message window first, as the 3D screen's (CharDisp.DrawNoncombatWindows): the map window's corner at (16,16)
    goes over its top edge (#1172) }
  Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.MESSAGE_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0, Black, '');
  Border.DrawWindow(1, 1, 15, 15, 0, Black, '');
  Border.DrawWindow(17, 1, 38, 15, 0, Black, '');
end;

end.

{ Build and display the wilderness map. }
{$O+,F+}
{$I COMPILER.INC}
unit Wilds;

interface

{ Draws a wilderness view five tiles tall and viewLast + 1 wide from the 44x36 map: C_AREA.WILD_VIEW_LAST for the 5x5
  view, C_AREA.WILD_WIDE_LAST for Move mode's wide one (#1186). Clamp the requested corner, apply quest-dependent
  location icons, then draw each 24x24 tile, clipped to the view buffer. }
procedure BuildWildernessMap(ulX, ulY, viewLast: Integer);

{ Clamps one coordinate of a view whose last column or row is viewLast so it remains inside a map side whose last cell
  is last. }
function ViewCorner(ul, last, viewLast: Integer): Integer;

{ The corner of a view whose last column or row is viewLast, centred on map cell cell along a map side whose last cell
  is last, moved inside the map as BuildWildernessMap moves it: the party's cell is cell - CenteredCorner. }
function CenteredCorner(cell, last, viewLast: Integer): Integer;

{ The last column of the view on screen: C_AREA.WILD_WIDE_LAST while the wide view is shown, else
  C_AREA.WILD_VIEW_LAST. }
function ViewLast: Integer;

{ Draw the empty bordered windows of the wilderness screen: the message area, then the map and party windows side by
  side at the top, or one window across the top while the wide view is shown (DrawTopWindows). }
procedure DrawWildWindows;

{ Draw the top of the wilderness screen's windows as DrawWildWindows does, leaving the message area and its text. }
procedure DrawTopWindows;

{ Show the wide view (#1186), or the 5x5 one: the view buffer is freed and allocated again at the size that view takes,
  C_AREA.WILD_WIDE_ROWS by WILD_WIDE_CELLS or VIEW_ROWS by VIEW_CELLS, so the wide view costs its extra bytes only while
  it is shown. When the heap cannot spare the wide buffer, the 5x5 one comes back, as its own freed block holds it, and
  wideWanted is cleared: Move mode goes on in the 5x5 view. The buffer starts blank and no span is dirty; the caller
  draws. Nothing happens when that view is already shown. }
procedure ShowWide(wide: Boolean);

{ True for a script command that draws nothing outside the message window, or no more than the map view again
  (MapView.DisplayMapView), so the wide view can stay while it runs: flow, tests and arithmetic, the party checks, the
  clock, PRINT, PICTURE (which narrows the view itself before it shows a picture), SPRITE OFF and CALL (which narrows
  it itself for a duel). Any other command narrows the view first (EclVm.CallEclScript), so a menu, a monster, combat or
  a new area gets the screen with the party list. }
function KeepsWide(opcode: Byte): Boolean;

var
  { Move mode wants the wide view (Explore.MapMainMenu); CharDisp.DisplayWildernessInterface shows it while set }
  wideWanted: Boolean;
  { the wide view is on screen, and the view buffer is its size (ShowWide) }
  wideShown: Boolean;

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

uses Types, Crt, C_AREA, C_ECL, C_MSG, GameDefs, GameVars, Blit, Border, MapTiles,
  TextRend{$IFDEF FPC}, TpCompat{$ENDIF};

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

function ViewCorner(ul, last, viewLast: Integer): Integer;
begin
  if ul > last - viewLast then ul := last - viewLast;
  if ul < 0 then ul := 0;
  ViewCorner := ul;
end;

function CenteredCorner(cell, last, viewLast: Integer): Integer;
begin
  { the middle column: 2 in the 5x5 view, 6 in the wide one, where the 13th tile is cut off }
  CenteredCorner := Wilds.ViewCorner(cell - viewLast div 2, last, viewLast);
end;

function ViewLast: Integer;
begin
  if wideShown then
    ViewLast := C_AREA.WILD_WIDE_LAST
  else
    ViewLast := C_AREA.WILD_VIEW_LAST;
end;

procedure ShowWide(wide: Boolean);
begin
  if wide = wideShown then Exit;
  { the second tile set first, which the wider view is likelier to need: its blocks are small (MapTiles.SHEET_BLOCK),
    but loaded first they still leave the wide buffer the heap's largest block, which that buffer takes apart (from
    70,904 bytes to 34,392 on VGA in the central wilderness) }
  if wide then
    MapTiles.LoadSecondSheet;
  Blit.FreePic(GameVars.viewBuffer);
  wideShown := wide and (MaxAvail >= LongInt(Blit.FrameBytes(C_AREA.WILD_WIDE_ROWS, C_AREA.WILD_WIDE_CELLS)) +
                                      SizeOf(Types.TImgBuf) - SizeOf(GameVars.viewBuffer^.data));
  if wideShown then
    Blit.AllocPic(C_AREA.WILD_WIDE_ROWS, C_AREA.WILD_WIDE_CELLS, 1, 0, GameVars.viewBuffer)
  else begin
    Blit.AllocPic(C_AREA.VIEW_ROWS, C_AREA.VIEW_CELLS, 1, 0, GameVars.viewBuffer);
    if wide then
      wideWanted := False;
  end;
  { what was dirty was the freed buffer's }
  Blit.ClearSpans;
end;

function KeepsWide(opcode: Byte): Boolean;
begin
  case opcode of
    C_ECL.OP_EXIT, C_ECL.OP_GOTO, C_ECL.GOSUB, C_ECL.RETURN, C_ECL.ON_GOTO, C_ECL.ON_GOSUB,
    C_ECL.COMPARE, C_ECL.COMPARE_AND, C_ECL.IF_EQ..C_ECL.IF_GE,
    C_ECL.ADD, C_ECL.SUBTRACT, C_ECL.DIVIDE, C_ECL.MULTIPLY, C_ECL.OP_RANDOM, C_ECL.SAVE, C_ECL.OP_AND, C_ECL.OP_OR,
    C_ECL.GET_TABLE, C_ECL.SAVE_TABLE,
    C_ECL.CHECK_PARTY, C_ECL.PARTY_STRENGTH, C_ECL.SURPRISE, C_ECL.PARTY_SURPRISE, C_ECL.FIND_ITEM, C_ECL.SPELL,
    C_ECL.CLEAR_MONSTERS, C_ECL.CLOCK,
    C_ECL.PRINT, C_ECL.PRINT_CLEAR, C_ECL.PRINT_RETURN, C_ECL.PICTURE, C_ECL.SPRITE_OFF, C_ECL.CALL:
      KeepsWide := True;
  else
    KeepsWide := False;
  end;
end;

{ GameDefs.wildMap and the override table both hold 1-based tile ids, hence each - 1. }
procedure BuildWildernessMap(ulX, ulY, viewLast: Integer);
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
  ulX := Wilds.ViewCorner(ulX, C_AREA.WILD_LAST_COL, viewLast);
  ulY := Wilds.ViewCorner(ulY, C_AREA.WILD_LAST_ROW, C_AREA.WILD_VIEW_LAST);
  viewY := 0;
  for row := 0 to C_AREA.WILD_VIEW_LAST do begin
    viewX := 0;
    for col := 0 to viewLast do begin
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
      MapTiles.Copy2DTileClipped(viewX, viewY, icon);
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
  Wilds.DrawTopWindows;
end;

procedure DrawTopWindows;
begin
  if wideShown then begin
    { the top cleared to its bottom edge first, which also tells Border that no map window's corner is left at
      (16,16) for an edge across it to put back (#1172) }
    Border.ClearBox(0, 0, 39, 16);
    Border.DrawWindow(1, 1, C_AREA.WILD_WIDE_CELLS, 15, 0, Black, '');
  end else begin
    Border.DrawWindow(1, 1, 15, 15, 0, Black, '');
    Border.DrawWindow(17, 1, 38, 15, 0, Black, '');
  end;
end;

begin
  { Turbo Pascal clears no variable }
  wideWanted := False;
  wideShown := False;
end.

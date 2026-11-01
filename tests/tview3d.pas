{ Tests for View3D's map reads, which wrap a square off the map onto it from the other edge however far off it lies
  (POR-0227), for Wilds.ViewCorner, which keeps the 5x5 wilderness view inside the map, and for Wilds.StepTo, a
  wilderness step in any of eight directions (#1159). }
{$I COMPILER.INC}
program TView3D;

uses Types, C_AREA, C_DIR, GameDefs, GameVars, View3D, Wilds, TestKit;

{ The square (x, y) wraps onto, as two letters: A for 0. }
function Wrapped(x, y: ShortInt): String;
begin
  View3D.WrapCoords(x, y);
  Wrapped := Chr(Ord('A') + x) + Chr(Ord('A') + y);
end;

const
  { the central wilderness's window on the map, and its open cells around (1, 1) }
  CENTRAL = 13;
  { an impassable glyph, and one of the river's }
  ROCK = 78;
  RIVER = 102;

var
  nx: ShortInt;
  ny: ShortInt;

{ What a step from (x, y) toward dir in the central wilderness meets, the river shut when shut; nx, ny where it ends. }
function Step(x, y: ShortInt; dir: Byte; shut: Boolean): Byte;
begin
  Step := Wilds.StepTo(x, y, dir, CENTRAL, shut, nx, ny);
end;

{ The tile on the central wilderness's cell (x, y). }
function Peek(x, y: ShortInt): Byte;
begin
  Peek := GameDefs.wildMap[y, x + CENTRAL];
end;

{ Put tile on the central wilderness's cell (x, y). }
procedure Poke(x, y: ShortInt; tile: Byte);
begin
  GameDefs.wildMap[y, x + CENTRAL] := tile;
end;

var
  north: Byte;
  east: Byte;
  northEast: Byte;

begin
  TestKit.Start('TVIEW3D');
  TestKit.CheckEqualsS('FI', Wrapped(5, 8), 'a square on the map stays');
  TestKit.CheckEqualsS('PA', Wrapped(-1, 16), 'one off wraps to the far edge');
  TestKit.CheckEqualsS('OB', Wrapped(-2, 17), 'two off wraps one in from it (POR-0227)');
  TestKit.CheckEqualsS('MD', Wrapped(-4, 19), 'and four off, four');
  GetMem(GameVars.map3d, SizeOf(Types.TGeoMap));
  FillChar(GameVars.map3d^, SizeOf(Types.TGeoMap), 0);
  { a north wall of type 3 on square (1, 2), an event on (14, 2) }
  GameVars.map3d^.wallsNE[2][1] := $30;
  GameVars.map3d^.events[2][14] := 7;
  GameVars.eclScriptId := 18;
  TestKit.CheckEqualsL(3, View3D.GetWallType(1, 2, C_DIR.NORTH), 'the wall on the map');
  TestKit.CheckEqualsL(3, View3D.GetWallType(17, 2, C_DIR.NORTH), 'and read two squares past the east edge');
  TestKit.CheckEqualsL(0, View3D.GetWallType(16, 2, C_DIR.NORTH), 'not one square past it');
  TestKit.CheckEqualsL(7, View3D.GetMapEvent(-2, 2), 'an event read two squares past the west edge');
  TestKit.CheckEqualsL(1, View3D.GetBarrierType(-2, 2, C_DIR.NORTH), 'a square with no wall is passable');
  GameVars.eclScriptId := 0;
  TestKit.CheckEqualsL(0, View3D.GetWallType(17, 2, C_DIR.NORTH), 'New Phlan reads off-map squares as none');
  TestKit.CheckEqualsL(0, View3D.GetBarrierType(-1, 2, C_DIR.NORTH), 'and their barriers as closed');
  TestKit.CheckEqualsL(3, View3D.GetWallType(1, 2, C_DIR.NORTH), 'but the map itself as it is');
  FreeMem(GameVars.map3d, SizeOf(Types.TGeoMap));
  TestKit.CheckEqualsL(0, Wilds.ViewCorner(-2, C_AREA.WILD_LAST_COL), 'the view stops at the west edge');
  TestKit.CheckEqualsL(20, Wilds.ViewCorner(20, C_AREA.WILD_LAST_COL), 'goes where it is put inside the map');
  TestKit.CheckEqualsL(39, Wilds.ViewCorner(41, C_AREA.WILD_LAST_COL), 'and stops at the east edge');
  TestKit.CheckEqualsL(31, Wilds.ViewCorner(33, C_AREA.WILD_LAST_ROW), 'and the south');

  { wilderness steps (#1159), around the central wilderness's (1, 1), open on every side in the shipped map }
  TestKit.CheckEqualsL(Wilds.STEP_BLOCKED, Wilds.TileStep(ROCK, False), 'an impassable glyph blocks');
  TestKit.CheckEqualsL(Wilds.STEP_RIVER, Wilds.TileStep(RIVER, True), 'the river does while it is shut');
  TestKit.CheckEqualsL(Wilds.STEP_OPEN, Wilds.TileStep(RIVER, False), 'and not after');
  TestKit.CheckEqualsL(Wilds.STEP_OPEN, Step(1, 1, C_DIR.NORTH, True), 'a straight step on open ground');
  TestKit.Check((nx = 1) and (ny = 0), 'ends a cell north');
  TestKit.CheckEqualsL(Wilds.STEP_OPEN, Step(1, 1, C_DIR.NORTHEAST, True), 'a diagonal one');
  TestKit.Check((nx = 2) and (ny = 0), 'ends a cell north-east');
  TestKit.CheckEqualsL(Wilds.STEP_OPEN, Step(1, 1, C_DIR.SOUTHWEST, True), 'and the other way');
  TestKit.Check((nx = 0) and (ny = 2), 'a cell south-west');
  north := Peek(1, 0);
  east := Peek(2, 1);
  northEast := Peek(2, 0);
  Poke(1, 0, ROCK);
  Poke(2, 1, ROCK);
  TestKit.CheckEqualsL(Wilds.STEP_CORNER, Step(1, 1, C_DIR.NORTHEAST, True), 'no cutting between two blocked cells');
  TestKit.CheckEqualsL(Wilds.STEP_OPEN, Step(1, 1, C_DIR.SOUTHEAST, True), 'a diagonal with one side blocked goes');
  Poke(1, 0, north);
  TestKit.CheckEqualsL(Wilds.STEP_OPEN, Step(1, 1, C_DIR.NORTHEAST, True), 'and so with the other side');
  Poke(1, 0, RIVER);
  TestKit.CheckEqualsL(Wilds.STEP_CORNER, Step(1, 1, C_DIR.NORTHEAST, True), 'the shut river counts as blocked');
  TestKit.CheckEqualsL(Wilds.STEP_OPEN, Step(1, 1, C_DIR.NORTHEAST, False), 'the open river does not');
  Poke(1, 0, north);
  Poke(2, 1, east);
  Poke(2, 0, RIVER);
  TestKit.CheckEqualsL(Wilds.STEP_RIVER, Step(1, 1, C_DIR.NORTHEAST, True), 'a diagonal into the shut river');
  Poke(2, 0, ROCK);
  TestKit.CheckEqualsL(Wilds.STEP_BLOCKED, Step(1, 1, C_DIR.NORTHEAST, True), 'and into impassable terrain');
  Poke(2, 0, northEast);
  TestKit.CheckEqualsL(Wilds.STEP_OPEN, Step(0, 1, C_DIR.NORTHWEST, True), 'a diagonal at the west edge');
  TestKit.Check((nx = 0) and (ny = 0), 'is held to the region: a step north');
  TestKit.CheckEqualsL(Wilds.STEP_OPEN, Step(C_AREA.WILD_REGION_LAST_COL, 0, C_DIR.NORTHEAST, True),
                       'a diagonal at the north-east corner');
  TestKit.Check((nx = C_AREA.WILD_REGION_LAST_COL) and (ny = 0), 'and in the corner goes nowhere');
  TestKit.Done;
end.

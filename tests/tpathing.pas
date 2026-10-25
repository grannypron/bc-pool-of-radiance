{ Tests for Pathing's line stepping and direction tests, which need no arena: SignOf, PathFind and NextPathStep (2 a
  straight step, 3 a diagonal one), IsDirToward, DirToward and GetIconTileDelta; and RouteStep's walks on an arena of
  the test's own, with walls and bodies (#668), and the hard cases of #769; and BuildTargetList on it (#807); and
  OnArena, LastSlot, SaveTargets and RestoreTargets. }
{$I COMPILER.INC}
program TPathing;

uses Types, C_DIR, C_TERR, GameDefs, GameVars, Pathing, StrUtil, TestKit;

const
  { RouteStep's arena: open ground (terrain 5, cost 1) and wall (terrain 1, cost 255) }
  GROUND = 5;
  WALL = 1;
  WALKER = 1;
  TARGET = 2;
  BLOCKER = 3;
  FRONT = 4;

var
  dx: ShortInt;
  dy: ShortInt;
  { each arena cell's creature, by slot }
  occ: array[0..24, 0..49] of Byte;
  dir: Byte;
  goal: Byte;

{ Walk from (sx, sy) to (ex, ey) and check the steps, the doubled distance and the end cell. }
procedure CheckWalk(sx, sy, ex, ey: Integer; steps, dist: Integer; what: String);
var
  req: Types.TPathReq;
  n: Integer;
begin
  FillChar(req, SizeOf(req), 0);
  req.sx := sx;
  req.sy := sy;
  req.ex := ex;
  req.ey := ey;
  Pathing.PathFind(req);
  n := 0;
  while Pathing.NextPathStep(req) and (n < 100) do
    Inc(n);
  TestKit.CheckEqualsL(steps, n, what + ': steps');
  TestKit.CheckEqualsL(dist, req.dist, what + ': doubled distance');
  TestKit.Check((req.cx = ex) and (req.cy = ey), what + ': ends on the target');
end;

{$F+}
function TestOccupant(x, y: ShortInt): Byte;
begin
  if (x < 0) or (x > 49) or (y < 0) or (y > 24) then
    TestOccupant := 0
  else
    TestOccupant := occ[y, x];
end;
{$F-}

{ Open ground everywhere and nobody on it. }
procedure ClearArena;
begin
  FillChar(GameVars.arenaPtr^.cells, SizeOf(GameVars.arenaPtr^.cells), GROUND);
  FillChar(occ, SizeOf(occ), 0);
  FillChar(GameVars.arenaLoc, SizeOf(GameVars.arenaLoc), 0);
end;

{ Put slot's body of size with its corner at (x, y), taking it off where it was. }
procedure Place(slot: Byte; x, y: ShortInt; size: Byte);
var
  i: Byte;
  cx: ShortInt;
  cy: ShortInt;
begin
  for cy := 0 to 24 do
    for cx := 0 to 49 do
      if occ[cy, cx] = slot then
        occ[cy, cx] := 0;
  GameVars.arenaLoc[slot].x := x;
  GameVars.arenaLoc[slot].y := y;
  GameVars.arenaLoc[slot].size := size;
  for i := 0 to 3 do
    if Pathing.GetIconTileDelta(size, i, dx, dy) then
      occ[y + dy, x + dx] := slot;
end;

{ A wall from (x, y1) down to (x, y2). }
procedure WallColumn(x, y1, y2: ShortInt);
var
  y: ShortInt;
begin
  for y := y1 to y2 do
    GameVars.arenaPtr^.cells[y, x] := WALL;
end;

{ Walk WALKER to one of goals a RouteStep at a time, through the bodies in open and keeping off terrain avoid; the steps
  taken until it arrives or its next step is onto a body (where the AI waits), or -1 when it takes more than limit or
  lands on a wall or on avoid. }
function WalkSteps(goals, open: Pathing.TSlotSet; avoid: Byte; limit: Integer): Integer;
var
  n: Integer;
  x: ShortInt;
  y: ShortInt;
begin
  n := 0;
  while Pathing.RouteStep(WALKER, goals, open, avoid, TestOccupant, dir, goal) and (n <= limit) do begin
    x := GameVars.arenaLoc[WALKER].x + GameDefs.dirDX[dir];
    y := GameVars.arenaLoc[WALKER].y + GameDefs.dirDY[dir];
    if (GameVars.arenaPtr^.cells[y, x] = WALL) or (GameVars.arenaPtr^.cells[y, x] = avoid) then begin
      WalkSteps := -1;
      Exit;
    end;
    if (occ[y, x] <> 0) and (occ[y, x] <> WALKER) then begin
      WalkSteps := n;
      Exit;
    end;
    Place(WALKER, x, y, GameVars.arenaLoc[WALKER].size);
    Inc(n);
  end;
  if n > limit then
    n := -1;
  WalkSteps := n;
end;

{ RouteStep from WALKER to TARGET alone, past every body and on any terrain. }
function RouteToTarget: Boolean;
begin
  RouteToTarget := Pathing.RouteStep(WALKER, [TARGET], [], 0, TestOccupant, dir, goal);
end;

{ A wall from (x1, y) across to (x2, y). }
procedure WallRow(y, x1, x2: ShortInt);
var
  x: ShortInt;
begin
  for x := x1 to x2 do
    GameVars.arenaPtr^.cells[y, x] := WALL;
end;

{ #769: a dead-end corridor, one cell wide, from (19, 10) east to (30, 10), walled at (31, 10); TARGET at its end with
  FRONT in front of it, and WALKER out in the open at (5, 10). }
procedure CorridorArena;
begin
  ClearArena;
  WallRow(9, 19, 31);
  WallRow(11, 19, 31);
  GameVars.arenaPtr^.cells[10, 31] := WALL;
  Place(WALKER, 5, 10, 1);
  Place(TARGET, 30, 10, 1);
  Place(FRONT, 29, 10, 1);
end;

{ Monsters reach a party they can reach (#769): a target hemmed in by its own side, a corridor blocked by the walker's
  own side, and a Stinking Cloud in the short way. }
procedure CheckReachable;
begin
  { the target is shut in behind FRONT: no walk to it, but one to FRONT, which becomes the goal }
  CorridorArena;
  TestKit.Check(not RouteToTarget,
                'a target shut in behind its own side cannot be walked to');
  goal := 0;
  TestKit.Check(Pathing.RouteStep(WALKER, [TARGET, FRONT], [], 0, TestOccupant, dir, goal) and (goal = FRONT) and
                (dir = C_DIR.EAST), 'but the one in front of it can');
  TestKit.CheckEqualsL(23, WalkSteps([TARGET, FRONT], [], 0, 60), 'and 23 steps bring the walker to it');
  TestKit.Check(GameVars.arenaLoc[WALKER].x = 28, 'beside the front one');
  { of two goals the nearer one is reached }
  ClearArena;
  Place(WALKER, 10, 10, 1);
  Place(TARGET, 30, 10, 1);
  Place(FRONT, 4, 10, 1);
  TestKit.Check(Pathing.RouteStep(WALKER, [TARGET, FRONT], [], 0, TestOccupant, dir, goal) and (goal = FRONT) and
                (dir = C_DIR.WEST), 'of two goals the walk is to the nearer');
  { next to one goal already: no step }
  Place(FRONT, 11, 11, 1);
  TestKit.Check(not Pathing.RouteStep(WALKER, [TARGET, FRONT], [], 0, TestOccupant, dir, goal),
                'next to a goal there is no step to take');
  { one of the walker's own side in the corridor: no walk past it, but a walk through it closes up behind it }
  CorridorArena;
  Place(BLOCKER, 25, 10, 1);
  TestKit.Check(not Pathing.RouteStep(WALKER, [TARGET, FRONT], [], 0, TestOccupant, dir, goal),
                'its own side in the corridor shuts the walk');
  TestKit.Check(Pathing.RouteStep(WALKER, [TARGET, FRONT], [BLOCKER], 0, TestOccupant, dir, goal) and
                (goal = FRONT) and (dir = C_DIR.EAST), 'a walk through its own side heads up the corridor');
  TestKit.CheckEqualsL(19, WalkSteps([TARGET, FRONT], [BLOCKER], 0, 60), 'and 19 steps close up behind it');
  TestKit.Check((GameVars.arenaLoc[WALKER].x = 24) and (dir = C_DIR.EAST), 'where the next step is onto it: it waits');
  { the ally moves on (here it is gone): the walk goes on to FRONT }
  Place(BLOCKER, 0, 0, 0);
  occ[0, 0] := 0;
  TestKit.CheckEqualsL(4, WalkSteps([TARGET, FRONT], [], 0, 60), 'once it has gone the walk goes on');
  { a Stinking Cloud in the near gap of a wall: through it for a walker that does not mind it, round by the far gap for
    one that keeps out }
  ClearArena;
  WallColumn(8, 0, 4);
  WallColumn(8, 6, 19);
  WallColumn(8, 21, 24);
  GameVars.arenaPtr^.cells[5, 8] := C_TERR.STINK_CLOUD;
  Place(WALKER, 5, 5, 1);
  Place(TARGET, 11, 5, 1);
  TestKit.Check(RouteToTarget and (dir = C_DIR.EAST),
                'a walker that does not mind the cloud goes through it');
  TestKit.Check(Pathing.RouteStep(WALKER, [TARGET], [], C_TERR.STINK_CLOUD, TestOccupant, dir, goal) and
                (dir in [C_DIR.SOUTHWEST, C_DIR.SOUTH, C_DIR.SOUTHEAST]), 'one that keeps out heads for the far gap');
  TestKit.CheckEqualsL(29, WalkSteps([TARGET], [], C_TERR.STINK_CLOUD, 60), 'and goes round by it');
end;

{ BuildTargetList from WALKER's cell: every creature it sees, nearest first, with the doubled distance and the facing
  toward it; a wall hides one unless distMode is 1, as CbtMap.CalcDistance sets it (#807). }
procedure CheckTargetList;
begin
  ClearArena;
  GameVars.arenaPtr^.distMode := 0;
  GameVars.arenaCount := 3;
  Place(WALKER, 5, 5, 1);
  Place(TARGET, 10, 5, 1);
  { a 2x2 body whose nearest cell, (5, 9), is 4 cells south }
  Place(BLOCKER, 4, 9, 4);
  Pathing.BuildTargetList(5, 5, 127, 255, 1, GameVars.arenaPtr);
  TestKit.CheckEqualsL(3, GameVars.targetCount, 'the target list holds everyone in sight, the looker too');
  TestKit.Check((GameVars.targetList[1].idx = WALKER) and (GameVars.targetList[1].dist = 0), 'the looker first, at 0');
  TestKit.Check((GameVars.targetList[2].idx = BLOCKER) and (GameVars.targetList[2].dist = 8) and
                (GameVars.targetList[2].dir = C_DIR.SOUTH), 'then the 2x2 body, by its nearest cell, to the south');
  TestKit.Check((GameVars.targetList[3].idx = TARGET) and (GameVars.targetList[3].dist = 10) and
                (GameVars.targetList[3].dir = C_DIR.EAST), 'then the one 5 cells east');
  WallColumn(8, 0, 7);
  Pathing.BuildTargetList(5, 5, 127, 255, 1, GameVars.arenaPtr);
  TestKit.CheckEqualsL(2, GameVars.targetCount, 'a wall hides the one behind it');
  GameVars.arenaPtr^.distMode := 1;
  Pathing.BuildTargetList(5, 5, 127, 255, 1, GameVars.arenaPtr);
  TestKit.CheckEqualsL(3, GameVars.targetCount, 'unless distMode looks through walls');
  GameVars.arenaPtr^.distMode := 0;
  Pathing.BuildTargetList(5, 5, 2, 255, 1, GameVars.arenaPtr);
  TestKit.CheckEqualsL(1, GameVars.targetCount, 'and a range of 2 reaches the looker alone');
end;

{ OnArena's bounds, LastSlot's cap on arenaCount, and a target list saved and put back round another one. }
procedure CheckHelpers;
var
  snap: Types.TTargetSnapshot;
begin
  TestKit.Check(Pathing.OnArena(0, 0) and Pathing.OnArena(49, 24), 'the arena''s corners are on it');
  TestKit.Check(not Pathing.OnArena(-1, 0) and not Pathing.OnArena(50, 0) and not Pathing.OnArena(0, 25),
                'a cell past any edge is not');
  GameVars.arenaCount := 4;
  TestKit.CheckEqualsL(4, Pathing.LastSlot, 'LastSlot is arenaCount');
  GameVars.arenaCount := Types.ARENA_SLOTS + 1;
  TestKit.CheckEqualsL(Types.ARENA_SLOTS, Pathing.LastSlot, 'kept within the slots on a full arena');
  ClearArena;
  GameVars.arenaPtr^.distMode := 0;
  GameVars.arenaCount := 3;
  Place(WALKER, 5, 5, 1);
  Place(TARGET, 10, 5, 1);
  Pathing.BuildTargetList(5, 5, 127, 255, 1, GameVars.arenaPtr);
  Pathing.SaveTargets(snap);
  Pathing.BuildTargetList(5, 5, 2, 255, 1, GameVars.arenaPtr);
  TestKit.CheckEqualsL(1, GameVars.targetCount, 'a shorter list built in between');
  Pathing.RestoreTargets(snap);
  TestKit.Check((GameVars.targetCount = 2) and (GameVars.targetList[2].idx = TARGET) and
                (GameVars.targetList[2].dist = 10), 'RestoreTargets puts the list and its count back');
end;

procedure CheckRoutes;
begin
  GetMem(GameVars.arenaPtr, SizeOf(Types.TArena));
  { open ground: straight at it }
  ClearArena;
  Place(WALKER, 5, 5, 1);
  Place(TARGET, 10, 5, 1);
  TestKit.Check(RouteToTarget and (dir = C_DIR.EAST),
                'on open ground the first step is straight at the target');
  TestKit.CheckEqualsL(4, WalkSteps([TARGET], [], 0, 50), 'and four steps bring it alongside');
  TestKit.Check(not RouteToTarget, 'alongside, there is no step to take');
  { a wall between them, open only at its foot: the walk goes round }
  ClearArena;
  WallColumn(8, 0, 15);
  Place(WALKER, 5, 5, 1);
  Place(TARGET, 11, 5, 1);
  TestKit.Check(RouteToTarget and (dir in [C_DIR.SOUTH, C_DIR.SOUTHEAST]),
                'a wall in the way: the first step heads for the gap');
  { 11 steps down to the gap at (8, 16) and 10 back up beside the target }
  TestKit.CheckEqualsL(21, WalkSteps([TARGET], [], 0, 60), 'and the walk goes round the wall''s foot');
  { a dead end: a pocket walled north, south and east (the long wall), open to the west, away from the target; the walk
    backs out of it, where heading at the target would only push into the wall }
  ClearArena;
  WallColumn(8, 0, 15);
  GameVars.arenaPtr^.cells[3, 5] := WALL;
  GameVars.arenaPtr^.cells[3, 6] := WALL;
  GameVars.arenaPtr^.cells[3, 7] := WALL;
  GameVars.arenaPtr^.cells[7, 5] := WALL;
  GameVars.arenaPtr^.cells[7, 6] := WALL;
  GameVars.arenaPtr^.cells[7, 7] := WALL;
  Place(WALKER, 6, 5, 1);
  Place(TARGET, 11, 5, 1);
  TestKit.Check(RouteToTarget and (dir in [C_DIR.SOUTHWEST, C_DIR.WEST,
                C_DIR.NORTHWEST]), 'in a dead end the first step is back out of it');
  TestKit.Check(WalkSteps([TARGET], [], 0, 60) > 0, 'out of a dead end and round the wall');
  { walled in: no walk }
  ClearArena;
  WallColumn(9, 0, 24);
  Place(WALKER, 5, 5, 1);
  Place(TARGET, 12, 5, 1);
  TestKit.Check(not RouteToTarget, 'a wall across the arena: no walk');
  { a body in the only gap blocks it }
  ClearArena;
  WallColumn(8, 0, 9);
  WallColumn(8, 11, 24);
  Place(WALKER, 5, 5, 1);
  Place(TARGET, 11, 5, 1);
  TestKit.Check(RouteToTarget, 'a one-cell gap lets a one-cell body through');
  Place(BLOCKER, 8, 10, 1);
  TestKit.Check(not RouteToTarget, 'and a body standing in it blocks it');
  { a 2x2 body does not fit a one-cell gap }
  Place(BLOCKER, 0, 0, 0);
  occ[0, 0] := 0;
  Place(WALKER, 4, 5, 4);
  TestKit.Check(not RouteToTarget, 'a 2x2 body does not fit a one-cell gap');
  WallColumn(8, 11, 11);
  GameVars.arenaPtr^.cells[11, 8] := GROUND;
  TestKit.Check(RouteToTarget, 'but fits a two-cell one');
  CheckReachable;
  CheckTargetList;
  CheckHelpers;
  FreeMem(GameVars.arenaPtr, SizeOf(Types.TArena));
end;

begin
  TestKit.Start('TPATHING');
  TestKit.CheckEqualsL(-1, Pathing.SignOf(-7), 'SignOf of a negative');
  TestKit.CheckEqualsL(0, Pathing.SignOf(0), 'SignOf of 0');
  TestKit.CheckEqualsL(1, Pathing.SignOf(32000), 'SignOf of a positive');

  CheckWalk(0, 0, 3, 0, 3, 6, 'three cells east');
  CheckWalk(5, 5, 5, 1, 4, 8, 'four cells north');
  CheckWalk(0, 0, 3, 3, 3, 9, 'three diagonal cells');
  CheckWalk(0, 0, 4, 2, 4, 10, 'two diagonal and two straight steps');
  CheckWalk(10, 10, 10, 10, 0, 0, 'no walk to the start cell');

  TestKit.Check(Pathing.IsDirToward(10, 10, 15, 10, C_DIR.EAST), 'east is toward a cell east');
  TestKit.Check(not Pathing.IsDirToward(10, 10, 15, 10, C_DIR.WEST), 'west is not');
  TestKit.Check(Pathing.IsDirToward(10, 10, 15, 10, C_DIR.CENTER), 'no direction is always toward');
  TestKit.Check(not Pathing.IsDirToward(10, 10, 50, 10, C_DIR.EAST), 'a target off the arena is never toward');
  { DirToward, the facing a caster and an attacker turn to (#922) }
  TestKit.CheckEqualsL(C_DIR.EAST, Pathing.DirToward(10, 10, 15, 10), 'DirToward: a cell east is east');
  TestKit.CheckEqualsL(C_DIR.NORTH, Pathing.DirToward(10, 10, 10, 10), 'DirToward: the same cell is north');
  TestKit.CheckEqualsL(C_DIR.CENTER, Pathing.DirToward(10, 10, 50, 10),
                       'DirToward: a target off the arena has no direction, and the search ends');

  TestKit.Check(Pathing.GetIconTileDelta(1, 0, dx, dy) and (dx = 0) and (dy = 0),
                'a one-cell icon''s only tile is at its corner');
  TestKit.Check(not Pathing.GetIconTileDelta(0, 0, dx, dy), 'an inactive icon has no tiles');
  TestKit.Check(not Pathing.GetIconTileDelta(5, 0, dx, dy), 'nor a size past 4');
  CheckRoutes;
  TestKit.Done;
end.

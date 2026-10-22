{ Combat pathfinding, line stepping and target-list construction and sorting. }
{$O+,F+}
{$I COMPILER.INC}
unit Pathing;

interface

uses Types;

type
  { The creature on arena cell (x, y): its slot in GDVars.arenaLoc, 0 for none (CbtMap.OccupantAt). }
  TOccupant = function(x, y: ShortInt): Byte;
  { Arena slots (GDVars.arenaLoc): RouteStep's goals, and the bodies it may plan a walk through. }
  TSlotSet = set of Byte;

{ Return the sign of an Integer: -1, 0 or 1. }
function SignOf(v: Integer): Integer;

{ Initialize the line's direction, current point, Bresenham error terms and zero distance. }
procedure PathFind(var req: Types.TPathReq);

{ Advance one cell toward the endpoint. Add 3 to distance for a diagonal step or 2 for a straight step, and record the
  direction. Return False once the endpoint has been reached. }
function NextPathStep(var req: Types.TPathReq): Boolean;

{ True when dir (0..7) is a best direction from (x,y) toward (tx,ty), by a 90-degree cone test around the cell one step
  in dir; 8 and above (no direction) is always True. False if any coordinate is outside 0..49 / 0..24. }
function IsDirToward(x, y, tx, ty: ShortInt; dir: Byte): Boolean;

{ Walk a line until terrain or the distance budget blocks it. On entry dist is the budget in cells; the walk fails once
  the doubled distance (2 per straight step, 3 per diagonal) exceeds dist * 2 + 1, or, when the arena's distMode is 0,
  at a cell whose terrain blocking exceeds the start cell's clearance. On failure, return the blocking cell in tx,ty and
  the doubled distance in dist; reaching the target returns True with the doubled distance. An endpoint outside 0..49 /
  0..24 fails at once, with dist 0 and tx,ty unchanged. }
function WalkLine(x, y: ShortInt; var tx, ty: ShortInt; var dist: Word; view: Pointer): Boolean;

{ Build the potential-target list by testing icon-tile pairs for direction, line of sight and range. Keep each
  creature's shortest distance and best facing, then sort by distance. }
procedure BuildTargetList(x, y: ShortInt; range: Word; filter: Byte; size: Byte; view: Pointer);

{ Map an icon tile to its cell offset from the upper-left corner. Return False for an inactive icon or an unused tile
  with a negative X offset. }
function GetIconTileDelta(size, idx: Byte; var dx, dy: ShortInt): Boolean;

{ Make the spell's targets everyone within radius of cell (x, y), as BuildTargetList walks it: targetCreaturePtr and
  spellTargetCount. }
procedure TargetArea(x, y: ShortInt; radius: Byte);

{ The first step of a shortest walk that brings the creature in arena slot slot next to one of the creatures in goals
  (some cell of each body within one step of the other's), found breadth first over the arena (#668); goal returns which
  one. A cell the creature's body would cover must be on the arena, not a wall (terrain cost 255), not terrain avoid (0
  for none) and not another creature's (occupant) unless that one is in open (#769); the steps are the eight directions,
  the ones nearest the heading straight at the nearest goal tried first. False, with dir and goal unchanged, when the
  creature is next to a goal already or no walk reaches one. }
function RouteStep(slot: Byte; goals, open: TSlotSet; avoid: Byte; occupant: TOccupant;
                   var dir, goal: Byte): Boolean;

implementation

uses GDConsts, GDVars, C_DIR;

function SignOf(v: Integer): Integer;
begin
  if v < 0 then
    SignOf := -1
  else if v > 0 then
    SignOf := 1
  else
    SignOf := 0;
end;

{ Exchange-sort the target list ascending by doubled distance. On a distance tie, entry j moves ahead of entry i only
  when its direction is lower and it would not put a diagonal (odd) facing ahead of a cardinal (even) one. }
procedure SortTargets;
var
  i: Byte;
  j: Byte;
  auxJ: Byte;
  auxI: Byte;
  tmp: Types.TCombatTarget;
begin
  if GDVars.targetCount <= 1 then Exit;
  for i := 1 to GDVars.targetCount - 1 do
    for j := i + 1 to GDVars.targetCount do begin
      auxI := GDVars.targetList[i].dir;
      auxJ := GDVars.targetList[j].dir;
      if (GDVars.targetList[j].dist < GDVars.targetList[i].dist) or
          ((GDVars.targetList[j].dist = GDVars.targetList[i].dist) and (auxJ < auxI) and
           (auxJ mod 2 <= auxI mod 2)) then begin
        tmp := GDVars.targetList[i];
        GDVars.targetList[i] := GDVars.targetList[j];
        GDVars.targetList[j] := tmp;
      end;
    end;
end;

procedure PathFind(var req: Types.TPathReq);
begin
  with req do begin
    dist := 0;
    adx := Abs(ex - sx);
    ady := Abs(ey - sy);
    stepX := Pathing.SignOf(ex - sx);
    stepY := Pathing.SignOf(ey - sy);
    cx := sx;
    cy := sy;
    if adx > ady then begin
      err := ady * 2 - adx;
      incD := (ady - adx) * 2;
      incS := ady * 2;
    end else begin
      err := adx * 2 - ady;
      incD := (adx - ady) * 2;
      incS := adx * 2;
    end;
  end;
end;

function NextPathStep(var req: Types.TPathReq): Boolean;
var
  dx8: ShortInt;
  dy8: ShortInt;
begin
  dx8 := 0;
  dy8 := 0;
  NextPathStep := False;
  with req do begin
    if adx > ady then
    { x-major walk }
    begin
      if cx <> ex then begin
        dx8 := stepX;
        if err >= 0 then begin
          dy8 := stepY;
          Inc(cy, stepY);
          Inc(err, incD);
          Inc(dist, 3);
        end else begin
          Inc(err, incS);
          Inc(dist, 2);
        end;
        Inc(cx, stepX);
        NextPathStep := True;
      end;
    end else
    { y-major walk }
    begin
      if cy <> ey then begin
        dy8 := stepY;
        if err >= 0 then begin
          dx8 := stepX;
          Inc(cx, stepX);
          Inc(err, incD);
          Inc(dist, 3);
        end else begin
          Inc(err, incS);
          Inc(dist, 2);
        end;
        Inc(cy, stepY);
        NextPathStep := True;
      end;
    end;
    step := GDConsts.dirByDelta[dy8 + 1, dx8 + 1];
  end;
end;

function WalkLine(x, y: ShortInt; var tx, ty: ShortInt; var dist: Word; view: Pointer): Boolean;
var
  walk: Types.TPathReq;
  meter: Types.TPathReq;
  done: Boolean;
  maxDist: Word;
begin
  if (x < 0) or (x > 49) or (y < 0) or (y > 24) or (tx < 0) or (tx > 49) or (ty < 0) or (ty > 24) then begin
    dist := 0;
    WalkLine := False;
    Exit;
  end;
  maxDist := dist * 2 + 1;
  walk.sx := x;
  walk.sy := y;
  walk.ex := tx;
  walk.ey := ty;
  Pathing.PathFind(walk);
  meter.sx := 0;
  meter.sy := GDConsts.terrainInfo[Types.PArena(view)^.cells[y, x]].clearance;
  if walk.adx > walk.ady then
    meter.ex := walk.adx
  else
    meter.ex := walk.ady;
  meter.ey := GDConsts.terrainInfo[Types.PArena(view)^.cells[y, x]].clearance;
  Pathing.PathFind(meter);
  done := False;
  repeat
    if ((Types.PArena(view)^.distMode = 0) and
        (GDConsts.terrainInfo[Types.PArena(view)^.cells[walk.cy, walk.cx]].blocking > meter.cy)) or
          (walk.dist > maxDist) then begin
      tx := walk.cx;
      ty := walk.cy;
      dist := walk.dist;
      WalkLine := False;
      Exit;
    end;
    if Pathing.NextPathStep(meter) then ;
    done := not Pathing.NextPathStep(walk);
  until done;
  dist := walk.dist;
  WalkLine := True;
end;

function IsDirToward(x, y, tx, ty: ShortInt; dir: Byte): Boolean;
var
  nx: ShortInt;
  ny: ShortInt;
begin
  if (x < 0) or (x > 49) or (y < 0) or (y > 24) or (tx < 0) or (tx > 49) or (ty < 0) or (ty > 24) then begin
    IsDirToward := False;
    Exit;
  end;
  if dir > C_DIR.CENTER then
    dir := C_DIR.CENTER;
  nx := x + GDConsts.dirDX[dir];
  ny := y + GDConsts.dirDY[dir];
  if ((x = tx) and (y = ty)) or ((nx = tx) and (ny = ty)) then begin
    IsDirToward := True;
    Exit;
  end;
  { Test the 90-degree cone for the requested direction. }
  case dir of
    C_DIR.NORTH: IsDirToward := ((tx >= nx) and (ty <= (nx - tx) + ny)) or ((tx <= nx) and (ty <= (tx - nx) + ny));
    C_DIR.NORTHEAST: IsDirToward := ((tx >= nx) and (ty <= (nx - tx) + ny)) or
      ((tx >= (nx + ny) - ty) and (ty <= ny));
    C_DIR.EAST: IsDirToward := ((tx >= (nx + ny) - ty) and (ty <= ny)) or ((tx >= (nx + ty) - ny) and (ty >= ny));
    C_DIR.SOUTHEAST: IsDirToward := ((tx >= (nx + ty) - ny) and (ty >= ny)) or
      ((tx >= nx) and (ty >= (tx - nx) + ny));
    C_DIR.SOUTH: IsDirToward := ((tx >= nx) and (ty >= (tx - nx) + ny)) or ((tx <= nx) and (ty >= (nx - tx) + ny));
    C_DIR.SOUTHWEST: IsDirToward := ((tx <= nx) and (ty >= (nx - tx) + ny)) or
      ((tx <= (nx + ny) - ty) and (ty >= ny));
    C_DIR.WEST: IsDirToward := ((tx <= (nx + ny) - ty) and (ty >= ny)) or ((tx <= (nx + ty) - ny) and (ty <= ny));
    C_DIR.NORTHWEST: IsDirToward := ((tx <= (nx + ty) - ny) and (ty <= ny)) or
      ((tx <= nx) and (ty <= (tx - nx) + ny));
    C_DIR.CENTER: IsDirToward := True;
  end;
end;

procedure BuildTargetList(x, y: ShortInt; range: Word; filter: Byte; size: Byte; view: Pointer);
var
  i: Byte;
  bestDir: Byte;
  k: Byte;
  j: Byte;
  bestK: Byte;
  bestJ: Byte;
  found: Boolean;
  tx: ShortInt;
  ty: ShortInt;
  dx8: ShortInt;
  dy8: ShortInt;
  myX: array[0..3] of ShortInt;
  myY: array[0..3] of ShortInt;
  tgX: array[0..3] of ShortInt;
  tgY: array[0..3] of ShortInt;
  dist: Word;
  bestDist: Word;
  last: Byte;
begin
  for k := 0 to 3 do
    if Pathing.GetIconTileDelta(size, k, dx8, dy8) then begin
      myX[k] := x + dx8;
      myY[k] := y + dy8;
    end else
      myX[k] := -1;
  GDVars.targetCount := 0;
  last := GDVars.arenaCount;
  if last > Types.ARENA_SLOTS then
    last := Types.ARENA_SLOTS;
  for i := 1 to last do
    if GDVars.arenaLoc[i].size > 0 then begin
      found := False;
      bestDist := 0;
      bestK := 0;
      bestJ := 0;
      for j := 0 to 3 do
        if Pathing.GetIconTileDelta(GDVars.arenaLoc[i].size, j, dx8, dy8) then begin
          tgX[j] := GDVars.arenaLoc[i].x + dx8;
          tgY[j] := GDVars.arenaLoc[i].y + dy8;
        end else
          tgX[j] := -1;
      for j := 0 to 3 do
        if tgX[j] >= 0 then
          for k := 0 to 3 do
            if myX[k] >= 0 then
              if Pathing.IsDirToward(myX[k], myY[k], tgX[j], tgY[j], filter) then begin
                tx := tgX[j];
                ty := tgY[j];
                dist := range;
                if Pathing.WalkLine(myX[k], myY[k], tx, ty, dist, view) then
                  if not found or (dist < bestDist) then begin
                    found := True;
                    bestDist := dist;
                    bestK := k;
                    bestJ := j;
                  end;
              end;
      if found then begin
        Inc(GDVars.targetCount);
        GDVars.targetList[GDVars.targetCount].idx := i;
        GDVars.targetList[GDVars.targetCount].dist := bestDist;
        bestDir := 0;
        if filter < C_DIR.CENTER then
          bestDir := filter
        else
          while not Pathing.IsDirToward(myX[bestK], myY[bestK], tgX[bestJ], tgY[bestJ], bestDir) do
            Inc(bestDir);
        GDVars.targetList[GDVars.targetCount].dir := bestDir;
      end;
    end;
  Pathing.SortTargets;
end;

function GetIconTileDelta(size, idx: Byte; var dx, dy: ShortInt): Boolean;
begin
  GetIconTileDelta := False;
  { iconDelta's rows are sizes 1..4 }
  if (size = 0) or (size > 4) then Exit;
  dx := GDConsts.iconDelta[size, idx].dx;
  dy := GDConsts.iconDelta[size, idx].dy;
  if dx >= 0 then
    GetIconTileDelta := True;
end;

procedure TargetArea(x, y: ShortInt; radius: Byte);
var
  k: Byte;
begin
  Pathing.BuildTargetList(x, y, radius, 255, 1, GDVars.arenaPtr);
  for k := 1 to GDVars.targetCount do
    GDVars.targetCreaturePtr[k] := GDVars.creatureArr[GDVars.targetList[k].idx];
  GDVars.spellTargetCount := GDVars.targetCount;
end;

const
  { the arena's cells (TArena.cells) }
  ARENA_LAST_X = 49;
  ARENA_LAST_Y = 24;
  { a wall's terrain cost }
  WALL_COST = 255;
  { RouteStep's marks: a cell not reached yet, and the start }
  UNREACHED = 255;
  START = 8;
  { the steps from a cell, as turns from the heading at the target: straight on first, round to straight back }
  TURNS: array[0..7] of Byte = (0, 1, 7, 2, 6, 3, 5, 4);

type
  { per cell, the first step of the walk that reached it; or the goal next to it }
  TRouteMarks = array[0..ARENA_LAST_Y, 0..ARENA_LAST_X] of Byte;
  { the cells to visit, x + 50 * y }
  TRouteQueue = array[0..(ARENA_LAST_X + 1) * (ARENA_LAST_Y + 1) - 1] of Word;

{ True when a body of size, its upper-left cell at (x, y), fits there: every cell on the arena, not terrain 0, no wall,
  not terrain avoid, and nobody on it but slot itself and the creatures in open. }
function CanStand(x, y: ShortInt; size, slot: Byte; open: TSlotSet; avoid: Byte; occupant: TOccupant): Boolean;
var
  i: Byte;
  dx: ShortInt;
  dy: ShortInt;
  cx: ShortInt;
  cy: ShortInt;
  t: Byte;
  c: Byte;
begin
  CanStand := False;
  for i := 0 to 3 do
    if Pathing.GetIconTileDelta(size, i, dx, dy) then begin
      cx := x + dx;
      cy := y + dy;
      if (cx < 0) or (cx > ARENA_LAST_X) or (cy < 0) or (cy > ARENA_LAST_Y) then
        Exit;
      t := GDVars.arenaPtr^.cells[cy, cx];
      if (t = 0) or (t = avoid) or (GDConsts.terrainInfo[t].cost = WALL_COST) then
        Exit;
      c := occupant(cx, cy);
      if (c <> 0) and (c <> slot) and not (c in open) then
        Exit;
    end;
  CanStand := True;
end;

{ The goal a body of size at (x, y) is next to, by near (per cell, the goal within one step of it, or 0); 0 for none. }
function Reaches(x, y: ShortInt; size: Byte; var near: TRouteMarks): Byte;
var
  i: Byte;
  dx: ShortInt;
  dy: ShortInt;
begin
  Reaches := 0;
  for i := 0 to 3 do
    if Pathing.GetIconTileDelta(size, i, dx, dy) then
      if near[y + dy, x + dx] <> 0 then begin
        Reaches := near[y + dy, x + dx];
        Exit;
      end;
end;

{ Mark in near each cell within one step of a goal's body with that goal (the first goal marked keeps a cell), and point
  heading from (sx, sy) straight at the nearest goal. }
procedure MarkGoals(goals: TSlotSet; sx, sy: ShortInt; var near: TRouteMarks; var heading: Byte);
var
  s: Byte;
  i: Byte;
  dx: ShortInt;
  dy: ShortInt;
  x: ShortInt;
  y: ShortInt;
  d: Byte;
  span: Integer;
  best: Integer;
  tx: ShortInt;
  ty: ShortInt;
begin
  FillChar(near, SizeOf(TRouteMarks), 0);
  best := MaxInt;
  tx := sx;
  ty := sy;
  for s := 1 to Types.ARENA_SLOTS do
    if (s in goals) and (GDVars.arenaLoc[s].size <> 0) then begin
      for i := 0 to 3 do
        if Pathing.GetIconTileDelta(GDVars.arenaLoc[s].size, i, dx, dy) then
          for y := GDVars.arenaLoc[s].y + dy - 1 to GDVars.arenaLoc[s].y + dy + 1 do
            for x := GDVars.arenaLoc[s].x + dx - 1 to GDVars.arenaLoc[s].x + dx + 1 do
              if (x >= 0) and (x <= ARENA_LAST_X) and (y >= 0) and (y <= ARENA_LAST_Y) then
                if near[y, x] = 0 then
                  near[y, x] := s;
      span := Abs(GDVars.arenaLoc[s].x - sx);
      if Abs(GDVars.arenaLoc[s].y - sy) > span then
        span := Abs(GDVars.arenaLoc[s].y - sy);
      if span < best then begin
        best := span;
        tx := GDVars.arenaLoc[s].x;
        ty := GDVars.arenaLoc[s].y;
      end;
    end;
  heading := C_DIR.NORTH;
  for d := C_DIR.NORTH to C_DIR.NORTHWEST do
    if (GDConsts.dirDX[d] = Pathing.SignOf(tx - sx)) and (GDConsts.dirDY[d] = Pathing.SignOf(ty - sy)) then
      heading := d;
end;

function RouteStep(slot: Byte; goals, open: TSlotSet; avoid: Byte; occupant: TOccupant;
                   var dir, goal: Byte): Boolean;
var
  marks: ^TRouteMarks;
  near: ^TRouteMarks;
  queue: ^TRouteQueue;
  head: Word;
  tail: Word;
  sx: ShortInt;
  sy: ShortInt;
  x: ShortInt;
  y: ShortInt;
  nx: ShortInt;
  ny: ShortInt;
  size: Byte;
  heading: Byte;
  d: Byte;
  k: Byte;
  first: Byte;
  reached: Byte;
begin
  RouteStep := False;
  sx := GDVars.arenaLoc[slot].x;
  sy := GDVars.arenaLoc[slot].y;
  size := GDVars.arenaLoc[slot].size;
  if size = 0 then
    Exit;
  GetMem(near, SizeOf(TRouteMarks));
  MarkGoals(goals, sx, sy, near^, heading);
  { next to a goal already: no step to take }
  if Reaches(sx, sy, size, near^) = 0 then begin
    GetMem(marks, SizeOf(TRouteMarks));
    GetMem(queue, SizeOf(TRouteQueue));
    FillChar(marks^, SizeOf(TRouteMarks), UNREACHED);
    marks^[sy, sx] := START;
    queue^[0] := sx + (ARENA_LAST_X + 1) * sy;
    head := 0;
    tail := 1;
    reached := 0;
    while (head < tail) and (reached = 0) do begin
      x := queue^[head] mod (ARENA_LAST_X + 1);
      y := queue^[head] div (ARENA_LAST_X + 1);
      Inc(head);
      k := 0;
      while (k <= 7) and (reached = 0) do begin
        d := (heading + TURNS[k]) mod 8;
        nx := x + GDConsts.dirDX[d];
        ny := y + GDConsts.dirDY[d];
        if (nx >= 0) and (nx <= ARENA_LAST_X) and (ny >= 0) and (ny <= ARENA_LAST_Y) then
          if (marks^[ny, nx] = UNREACHED) and CanStand(nx, ny, size, slot, open, avoid, occupant) then begin
            first := marks^[y, x];
            if first = START then
              first := d;
            marks^[ny, nx] := first;
            reached := Reaches(nx, ny, size, near^);
            if reached <> 0 then begin
              dir := first;
              goal := reached;
              RouteStep := True;
            end else begin
              queue^[tail] := nx + (ARENA_LAST_X + 1) * ny;
              Inc(tail);
            end;
          end;
        Inc(k);
      end;
    end;
    FreeMem(queue, SizeOf(TRouteQueue));
    FreeMem(marks, SizeOf(TRouteMarks));
  end;
  FreeMem(near, SizeOf(TRouteMarks));
end;

end.

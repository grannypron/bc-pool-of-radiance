{ Combat pathfinding, line stepping and target-list construction and sorting. }
{$O+,F+}
unit Pathing;

interface

uses Types;

{ Return the sign of an Integer: -1, 0 or 1. }
function SignOf(v: Integer): Integer;

{ Initialize the line's direction, current point, Bresenham error terms and zero distance. }
procedure PathFind(var req: Types.TPathReq);

{ Advance one cell toward the endpoint. Add 3 to distance for a diagonal step or 2 for a straight step, and record the
  direction. Return False once the endpoint has been reached. }
function NextPathStep(var req: Types.TPathReq): Boolean;

{ True when dir (0..7) is a best direction from (x,y) toward (tx,ty), by a 90-degree cone test around the cell one step
  in dir; 8 and above (no direction) is always True. False if any coordinate is outside 0..49 / 0..24 }
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

implementation


uses GDConsts, GDVars, C_Dir;
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
  stepped: Boolean;
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
    stepped := Pathing.NextPathStep(meter);
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
  if dir > C_Dir.CENTER then
    dir := C_Dir.CENTER;
  nx := x + GDConsts.dirDX[dir];
  ny := y + GDConsts.dirDY[dir];
  if ((x = tx) and (y = ty)) or ((nx = tx) and (ny = ty)) then begin
    IsDirToward := True;
    Exit;
  end;
  { Test the 90-degree cone for the requested direction. }
  case dir of
    C_Dir.NORTH: IsDirToward := ((tx >= nx) and (ty <= (nx - tx) + ny)) or ((tx <= nx) and (ty <= (tx - nx) + ny));
    C_Dir.NORTHEAST: IsDirToward := ((tx >= nx) and (ty <= (nx - tx) + ny)) or
      ((tx >= (nx + ny) - ty) and (ty <= ny));
    C_Dir.EAST: IsDirToward := ((tx >= (nx + ny) - ty) and (ty <= ny)) or ((tx >= (nx + ty) - ny) and (ty >= ny));
    C_Dir.SOUTHEAST: IsDirToward := ((tx >= (nx + ty) - ny) and (ty >= ny)) or
      ((tx >= nx) and (ty >= (tx - nx) + ny));
    C_Dir.SOUTH: IsDirToward := ((tx >= nx) and (ty >= (tx - nx) + ny)) or ((tx <= nx) and (ty >= (nx - tx) + ny));
    C_Dir.SOUTHWEST: IsDirToward := ((tx <= nx) and (ty >= (nx - tx) + ny)) or
      ((tx <= (nx + ny) - ty) and (ty >= ny));
    C_Dir.WEST: IsDirToward := ((tx <= (nx + ny) - ty) and (ty >= ny)) or ((tx <= (nx + ty) - ny) and (ty <= ny));
    C_Dir.NORTHWEST: IsDirToward := ((tx <= (nx + ty) - ny) and (ty <= ny)) or
      ((tx <= nx) and (ty <= (tx - nx) + ny));
    C_Dir.CENTER: IsDirToward := True;
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
      bestDist := 255;
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
                if Pathing.WalkLine(myX[k], myY[k], tx, ty, dist, view) then begin
                  found := True;
                  if dist < bestDist then begin
                    bestDist := dist;
                    bestK := k;
                    bestJ := j;
                  end;
                end;
              end;
      if found then begin
        Inc(GDVars.targetCount);
        GDVars.targetList[GDVars.targetCount].idx := i;
        GDVars.targetList[GDVars.targetCount].dist := bestDist;
        bestDir := 0;
        if filter < C_Dir.CENTER then
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

end.

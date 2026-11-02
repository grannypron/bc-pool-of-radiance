{ Tests for the combat minimap (#1210): the colours CbtMini.Build gives the arena's cells, walls and creatures, and
  where PixelColor puts the 100 x 50 pixel map in the panel's cells. }
{$I COMPILER.INC}
program TCbtMini;

uses Crt, Types, GameVars, CbtMini, TestKit;

const
  { open ground (terrain 5, cost 1) and wall (terrain 1, cost 255), as TPathing's arena }
  GROUND = 5;
  WALL = 1;

var
  grid: CbtMini.TMiniGrid;
  member: Types.PCharRecord;
  foe: Types.PCharRecord;
  downed: Types.PCharRecord;
  current: Types.PCharRecord;
  { the creatures no check names }
  under: Types.PCharRecord;
  bad: Integer;
  x: Byte;
  y: Byte;

{ A blank creature on side hostile, enabled or not, in slot with its corner at (x, y) and footprint size. }
function Place(slot: Byte; hostile, enabled: Byte; ax, ay: ShortInt; size: Byte): Types.PCharRecord;
var
  c: Types.PCharRecord;
begin
  GetMem(c, SizeOf(Types.TCharRecord));
  FillChar(c^, SizeOf(Types.TCharRecord), 0);
  c^.hostile := hostile;
  c^.enabled := enabled;
  GameVars.creatureArr[slot] := c;
  GameVars.arenaLoc[slot].x := ax;
  GameVars.arenaLoc[slot].y := ay;
  GameVars.arenaLoc[slot].size := size;
  Place := c;
end;

begin
  TestKit.Start('TCBTMINI');
  GetMem(GameVars.arenaPtr, SizeOf(Types.TArena));
  FillChar(GameVars.arenaPtr^, SizeOf(Types.TArena), 0);
  FillChar(GameVars.arenaPtr^.cells, SizeOf(GameVars.arenaPtr^.cells), GROUND);
  FillChar(GameVars.arenaLoc, SizeOf(GameVars.arenaLoc), 0);
  FillChar(GameVars.creatureArr, SizeOf(GameVars.creatureArr), 0);
  { a wall down column 10, and a cell off the arena (terrain 0) }
  for y := 0 to Types.ARENA_LAST_Y do
    GameVars.arenaPtr^.cells[y, 10] := WALL;
  GameVars.arenaPtr^.cells[5, 20] := 0;
  member := Place(1, 0, 1, 0, 0, 1);
  { size 4 is the 2 x 2 footprint, here in the arena's far corner }
  foe := Place(2, 1, 1, 48, 23, 4);
  downed := Place(3, 1, 0, 30, 12, 1);
  current := Place(4, 0, 1, 31, 12, 1);
  { a creature out of action under one in it: the living one shows }
  under := Place(5, 0, 0, 0, 0, 1);
  { a slot out of play (size 0) is not drawn }
  under := Place(6, 1, 1, 40, 2, 0);
  GameVars.arenaCount := 6;

  CbtMini.Build(grid, current, CbtMini.NO_CURSOR, CbtMini.NO_CURSOR);
  TestKit.CheckEqualsL(CbtMini.WALL_COLOR, grid[0, 10], 'a wall is blue');
  TestKit.CheckEqualsL(CbtMini.WALL_COLOR, grid[24, 10], 'down the whole column');
  TestKit.CheckEqualsL(CbtMini.FLOOR_COLOR, grid[5, 20], 'terrain 0 stays floor');
  TestKit.CheckEqualsL(CbtMini.FLOOR_COLOR, grid[0, 1], 'ground is floor');
  TestKit.CheckEqualsL(CbtMini.PARTY_COLOR, grid[0, 0], 'a party member at (0, 0) is light cyan, over a fallen one');
  TestKit.Check((grid[23, 48] = CbtMini.ENEMY_COLOR) and (grid[23, 49] = CbtMini.ENEMY_COLOR) and
                (grid[24, 48] = CbtMini.ENEMY_COLOR) and (grid[24, 49] = CbtMini.ENEMY_COLOR),
                'a 2 x 2 enemy fills its four cells to the corner, in yellow');
  TestKit.CheckEqualsL(CbtMini.DOWN_COLOR, grid[12, 30], 'one out of action is light red');
  TestKit.CheckEqualsL(CbtMini.CURRENT_COLOR, grid[12, 31], 'the creature whose turn it is white');
  TestKit.CheckEqualsL(CbtMini.FLOOR_COLOR, grid[2, 40], 'a slot out of play is not drawn');
  TestKit.CheckEqualsL(Yellow, CbtMini.ENEMY_COLOR, 'enemies as their names are coloured');
  TestKit.CheckEqualsL(Blue, CbtMini.WALL_COLOR, 'walls blue, as Brian chose');

  CbtMini.Build(grid, current, 48, 23);
  TestKit.CheckEqualsL(CbtMini.CURSOR_COLOR, grid[23, 48], 'the aim cursor is light magenta over the creature');
  TestKit.CheckEqualsL(CbtMini.ENEMY_COLOR, grid[24, 49], 'which keeps the rest of its footprint');
  CbtMini.Build(grid, current, -1, 30);
  TestKit.CheckEqualsL(CbtMini.FLOOR_COLOR, grid[0, 1], 'a cursor off the arena marks nothing');

  { the layout: 2 pixels a cell, 100 x 50, centred in the 13 x 7 text cells }
  TestKit.CheckEqualsL(100, CbtMini.MAP_WIDTH, 'the map is 100 pixels wide');
  TestKit.CheckEqualsL(50, CbtMini.MAP_HEIGHT, 'and 50 high');
  TestKit.CheckEqualsL(2, CbtMini.LEFT_PX, 'two pixels in from the left');
  TestKit.CheckEqualsL(3, CbtMini.TOP_PX, 'three down from the top');
  TestKit.Check((CbtMini.FIRST_COL >= 23) and (CbtMini.LAST_COL <= 38) and (CbtMini.FIRST_ROW > 11) and
                (CbtMini.LAST_ROW <= 21), 'inside the panel, below its status row');
  CbtMini.Build(grid, current, CbtMini.NO_CURSOR, CbtMini.NO_CURSOR);
  TestKit.CheckEqualsL(CbtMini.PARTY_COLOR, CbtMini.PixelColor(grid, 2, 3), 'cell (0, 0) at the map''s corner');
  TestKit.CheckEqualsL(CbtMini.PARTY_COLOR, CbtMini.PixelColor(grid, 3, 4), 'two pixels each way');
  TestKit.CheckEqualsL(CbtMini.FLOOR_COLOR, CbtMini.PixelColor(grid, 4, 3), 'and no more');
  TestKit.CheckEqualsL(CbtMini.FLOOR_COLOR, CbtMini.PixelColor(grid, 1, 3), 'the margin is floor');
  TestKit.CheckEqualsL(CbtMini.ENEMY_COLOR, CbtMini.PixelColor(grid, 101, 52), 'the far corner''s last pixel');
  TestKit.CheckEqualsL(CbtMini.FLOOR_COLOR, CbtMini.PixelColor(grid, 102, 52), 'then the margin');
  TestKit.CheckEqualsL(CbtMini.FLOOR_COLOR, CbtMini.PixelColor(grid, 101, 53), 'below it too');
  bad := 0;
  for y := 0 to 55 do
    for x := 0 to 103 do
      if (CbtMini.PixelColor(grid, x, y) = CbtMini.WALL_COLOR) <> ((x - 2) div 2 = 10) and (x >= 2) and (y >= 3) and
         (y < 53) then
        Inc(bad);
  TestKit.CheckEqualsL(0, bad, 'the wall column is pixels 22 and 23 the map''s height, and nothing else');
  TestKit.Done;
end.

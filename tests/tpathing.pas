{ Tests for Pathing's line stepping and direction tests, which need no arena: SignOf, PathFind and NextPathStep (2 a
  straight step, 3 a diagonal one), IsDirToward and GetIconTileDelta. }
program TPathing;

uses Types, C_Dir, Pathing, StrUtil, TestKit;

var
  dx: ShortInt;
  dy: ShortInt;

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

  TestKit.Check(Pathing.IsDirToward(10, 10, 15, 10, C_Dir.EAST), 'east is toward a cell east');
  TestKit.Check(not Pathing.IsDirToward(10, 10, 15, 10, C_Dir.WEST), 'west is not');
  TestKit.Check(Pathing.IsDirToward(10, 10, 15, 10, C_Dir.CENTER), 'no direction is always toward');
  TestKit.Check(not Pathing.IsDirToward(10, 10, 50, 10, C_Dir.EAST), 'a target off the arena is never toward');

  TestKit.Check(Pathing.GetIconTileDelta(1, 0, dx, dy) and (dx = 0) and (dy = 0),
                'a one-cell icon''s only tile is at its corner');
  TestKit.Check(not Pathing.GetIconTileDelta(0, 0, dx, dy), 'an inactive icon has no tiles');
  TestKit.Check(not Pathing.GetIconTileDelta(5, 0, dx, dy), 'nor a size past 4');
  TestKit.Done;
end.

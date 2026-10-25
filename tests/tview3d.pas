{ Tests for View3D's map reads, which wrap a square off the map onto it from the other edge however far off it lies
  (POR-0227), and for Wilds.ViewCorner, which keeps the 5x5 wilderness view inside the map. }
{$I COMPILER.INC}
program TView3D;

uses Types, C_AREA, C_DIR, GameVars, View3D, Wilds, TestKit;

{ The square (x, y) wraps onto, as two letters: A for 0. }
function Wrapped(x, y: ShortInt): String;
begin
  View3D.WrapCoords(x, y);
  Wrapped := Chr(Ord('A') + x) + Chr(Ord('A') + y);
end;

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
  TestKit.Done;
end.

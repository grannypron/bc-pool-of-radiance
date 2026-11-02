{ Tests for the combat view's two shapes (#1211): the 7x7 view and the full-width one, 13 columns by 6 rows. Their
  sizes and centres (CbtMap.SetLayout, CenterX, CenterY), which view cells are on screen (ViewCoordsValid), where
  BuildViewBuffer puts the view at each edge of the arena, and when it moves it (ScrollView's band, the full-width
  view's cut-off 13th column outside it). No tile set is loaded, so nothing is drawn: the buffer only gives its
  width. }
{$I COMPILER.INC}
program TCbtView;

uses Types, GameVars, CbtMap, TextRend, TestKit;

const
  { open ground: terrain 5, cost 1, tile 4 (the first tile set's, which is not loaded) }
  GROUND = 5;

{ Rebuild the view on (x, y) and check its corner. }
procedure CheckCorner(x, y, ox, oy: ShortInt; what: string);
var
  rebuilt: Boolean;
begin
  rebuilt := CbtMap.BuildViewBuffer(x, y, 255);
  TestKit.Check(rebuilt, what + ': rebuilt');
  TestKit.CheckEqualsL(ox, GameVars.arenaPtr^.ox, what + ': its left column');
  TestKit.CheckEqualsL(oy, GameVars.arenaPtr^.oy, what + ': its top row');
end;

begin
  TestKit.Start('TCBTVIEW');
  GetMem(GameVars.arenaPtr, SizeOf(Types.TArena));
  FillChar(GameVars.arenaPtr^, SizeOf(Types.TArena), 0);
  FillChar(GameVars.arenaPtr^.cells, SizeOf(GameVars.arenaPtr^.cells), GROUND);
  GetMem(GameVars.viewBuffer, SizeOf(Types.TImgBuf));
  FillChar(GameVars.viewBuffer^, SizeOf(Types.TImgBuf), 0);

  { the 7x7 view }
  GameVars.viewBuffer^.width := 21;
  TestKit.Check(not CbtMap.wideLayout, 'the 7x7 view to start with');
  TestKit.Check(not TextRend.pageByDelay, 'its messages page on a key');
  TestKit.CheckEqualsL(6, CbtMap.viewLastX, '7x7: the last column 6');
  TestKit.CheckEqualsL(6, CbtMap.viewLastY, '7x7: the last row 6');
  TestKit.CheckEqualsL(3, CbtMap.halfX, '7x7: the centre column 3');
  TestKit.CheckEqualsL(3, CbtMap.halfY, '7x7: the centre row 3');
  TestKit.Check(CbtMap.ViewCoordsValid(6, 6), '7x7: (6,6) in view');
  TestKit.Check(not CbtMap.ViewCoordsValid(7, 0), '7x7: (7,0) not');
  TestKit.Check(not CbtMap.ViewCoordsValid(0, 7), '7x7: (0,7) not');
  TestKit.Check(not CbtMap.ViewCoordsValid(-1, 0), '7x7: (-1,0) not');
  CheckCorner(0, 0, 0, 0, '7x7 at the upper left');
  CheckCorner(Types.ARENA_LAST_X, Types.ARENA_LAST_Y, Types.ARENA_LAST_X - 6, Types.ARENA_LAST_Y - 6,
              '7x7 at the lower right');
  CheckCorner(25, 12, 22, 9, '7x7 in the middle');
  TestKit.CheckEqualsL(25, CbtMap.CenterX, '7x7: its centre column');
  TestKit.CheckEqualsL(12, CbtMap.CenterY, '7x7: its centre row');
  { SSI's band: delta cells either side of the centre }
  TestKit.Check(not CbtMap.BuildViewBuffer(28, 15, 3), '7x7: a corner cell needs no scroll at delta 3');
  TestKit.Check(not CbtMap.BuildViewBuffer(27, 14, 2), '7x7: two from the centre needs none at delta 2');
  TestKit.Check(CbtMap.BuildViewBuffer(28, 12, 2), '7x7: three from it scrolls at delta 2');
  TestKit.CheckEqualsL(28 - 3, GameVars.arenaPtr^.ox, '7x7: centred on it');
  TestKit.CheckEqualsL(12 - 3, GameVars.arenaPtr^.oy, '7x7: its row kept');

  { the full-width view }
  GameVars.viewBuffer^.width := CbtMap.WIDE_CELLS;
  CbtMap.SetLayout(True);
  TestKit.Check(CbtMap.wideLayout, 'the full-width view');
  TestKit.Check(TextRend.pageByDelay, 'its two message lines page on the text delay');
  TestKit.CheckEqualsL(12, CbtMap.viewLastX, 'wide: the last column 12');
  TestKit.CheckEqualsL(5, CbtMap.viewLastY, 'wide: the last row 5');
  TestKit.CheckEqualsL(11, CbtMap.viewFullX, 'wide: the last whole column 11');
  TestKit.CheckEqualsL(6, CbtMap.halfX, 'wide: the centre column 6');
  TestKit.CheckEqualsL(2, CbtMap.halfY, 'wide: the centre row 2');
  TestKit.CheckEqualsL(144, CbtMap.WIDE_ROWS, 'wide: 6 rows of 24 scanlines');
  TestKit.Check(CbtMap.ViewCoordsValid(12, 5), 'wide: (12,5) in view');
  TestKit.Check(not CbtMap.ViewCoordsValid(13, 0), 'wide: (13,0) not');
  TestKit.Check(not CbtMap.ViewCoordsValid(0, 6), 'wide: (0,6) not');
  CheckCorner(0, 0, 0, 0, 'wide at the upper left');
  CheckCorner(Types.ARENA_LAST_X, 0, Types.ARENA_LAST_X - 12, 0, 'wide at the upper right');
  CheckCorner(0, Types.ARENA_LAST_Y, 0, Types.ARENA_LAST_Y - 5, 'wide at the lower left');
  CheckCorner(Types.ARENA_LAST_X, Types.ARENA_LAST_Y, Types.ARENA_LAST_X - 12, Types.ARENA_LAST_Y - 5,
              'wide at the lower right');
  CheckCorner(25, 12, 19, 10, 'wide in the middle');
  TestKit.CheckEqualsL(25, CbtMap.CenterX, 'wide: its centre column');
  TestKit.CheckEqualsL(12, CbtMap.CenterY, 'wide: its centre row');
  { at delta 3 the band is the whole view but the cut-off column }
  TestKit.Check(not CbtMap.BuildViewBuffer(19 + 11, 10 + 5, 3), 'wide: the last whole column needs no scroll');
  TestKit.Check(not CbtMap.BuildViewBuffer(19, 10, 3), 'wide: nor the first');
  TestKit.Check(CbtMap.BuildViewBuffer(19 + 12, 12, 3), 'wide: the cut-off column scrolls');
  TestKit.CheckEqualsL(19 + 12 - 6, GameVars.arenaPtr^.ox, 'wide: centred on it');
  TestKit.CheckEqualsL(10, GameVars.arenaPtr^.oy, 'wide: the rows kept');
  { at delta 2 a cell's margin from the edges }
  TestKit.Check(not CbtMap.BuildViewBuffer(25 + 10, 10 + 4, 2), 'wide: a cell in from the edges needs none at delta 2');
  TestKit.Check(CbtMap.BuildViewBuffer(25 + 1, 10 + 5, 2), 'wide: the bottom row scrolls at delta 2');
  TestKit.CheckEqualsL(25, GameVars.arenaPtr^.ox, 'wide: the columns kept');
  TestKit.CheckEqualsL(15 - 2, GameVars.arenaPtr^.oy, 'wide: centred on its row');
  { a corner left outside the arena (CombatSt's first one) is brought inside }
  GameVars.arenaPtr^.ox := -3;
  GameVars.arenaPtr^.oy := Types.ARENA_LAST_Y;
  CheckCorner(3, Types.ARENA_LAST_Y + 2, 0, Types.ARENA_LAST_Y - 5, 'wide from a corner off the arena');

  CbtMap.SetLayout(False);
  TestKit.Check(not CbtMap.wideLayout and not TextRend.pageByDelay, 'back to the 7x7 view');
  TestKit.CheckEqualsL(6, CbtMap.viewLastX, 'its last column again');
  FreeMem(GameVars.viewBuffer, SizeOf(Types.TImgBuf));
  FreeMem(GameVars.arenaPtr, SizeOf(Types.TArena));
  TestKit.Done;
end.

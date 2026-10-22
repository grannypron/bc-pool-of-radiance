{ Dungeon view and automap rendering, with GEO map and WALLDEF wall-set loading. }
{$O+,F+,I-}
{$I COMPILER.INC}
unit View3D;

interface

{ Stores the four 3D-view band colours (sky, horizon line, horizon band, floor). FixMain's boot sequence passes
  (11,0,7,6) for the default palette; MapView re-sets them for each 3D view }
procedure SetView3DColors(cSky, cHorz1, cHorz2, cFloor: Byte);

{ Wall type 0..15 (0 = no wall) on the given side of square (x, y) }
function GetWallType(x, y: ShortInt; facing: Byte): Byte;

{ Barrier type 0..3 on the given side of square (x, y); 1 is passable }
function GetBarrierType(x, y: ShortInt; facing: Byte): Byte;

{ Reads the square's EVENT byte; callers store the result in eventAtCell }
function GetMapEvent(x, y: ShortInt): Byte;

{ The 3D wall renderer }
procedure Display3DMapView(x, y: ShortInt; facing: Byte);

{ Load a WALLDEF wall set into slot wsSlot (1..3); any other slot is ignored }
procedure LoadWallSet(fileId, wsSlot: Byte);

{ Load GEO map mapId into the 3D map }
procedure Load3DMap(mapId: Byte);

{ Bring a square one step off the 16 by 16 map back on at the other edge (x or y of -1 becomes MAP_LAST, MAP_LAST + 1
  becomes 0), as the party walks off one side of a map and on at the other. }
procedure WrapCoords(var x, y: ShortInt);

implementation

uses Types, GDConsts, GDVars, Blit, Sym8x8, C_Dir, DaxIo, GameIo, StrUtil, Explored;

procedure DisplayViewBuf; forward;

{ The 11x11 automap, drawn at char (2,2) of the view buffer and then flushed: wall symbols 260 + N|E*2|S*4|W*8 from the
  wall-TYPE nibbles, then the party arrow 256 + facing div 2. 256 is symSetFirst[4], so the four arrows are 256..259 and
  the sixteen wall combinations 260..275, all inside 8x8 symbol set 4. The window origin clamps to 0..5 (16-wide map,
  11-wide window). }
procedure DrawAutoMap(x, y: ShortInt; facing: Byte);
var
  pwx: ShortInt;
  pwy: ShortInt;
  wx: ShortInt;
  wy: ShortInt;
  xLo: ShortInt;
  yLo: ShortInt;
  mx: ShortInt;
  my: ShortInt;
  sym: Word;
begin
  xLo := x - 5;
  if xLo < 0 then xLo := 0;
  if xLo > 5 then xLo := 5;
  pwx := x - xLo;
  yLo := y - 5;
  if yLo < 0 then yLo := 0;
  if yLo > 5 then yLo := 5;
  pwy := y - yLo;
  for wy := 0 to 10 do begin
    my := wy + yLo;
    for wx := 0 to 10 do begin
      mx := wx + xLo;
      sym := 260;
      if View3D.GetWallType(mx, my, C_Dir.NORTH) > 0 then Inc(sym);
      if View3D.GetWallType(mx, my, C_Dir.EAST) > 0 then Inc(sym, 2);
      if View3D.GetWallType(mx, my, C_Dir.SOUTH) > 0 then Inc(sym, 4);
      if View3D.GetWallType(mx, my, C_Dir.WEST) > 0 then Inc(sym, 8);
      Sym8x8.Put8x8Sym(wx + 3 - 1, wy + 3 - 1, sym, True, False);
    end;
  end;
  Sym8x8.Put8x8Sym(pwx + 3 - 1, pwy + 3 - 1, facing div 2 + 256, True, False);
  View3D.DisplayViewBuf;
end;

procedure SetView3DColors(cSky, cHorz1, cHorz2, cFloor: Byte);
begin
  GDVars.colorSkyCeiling := cSky;
  GDVars.wallColorA := cHorz1;
  GDVars.wallColorB := cHorz2;
  GDVars.wallColorC := cFloor;
end;

{ Fill the four 3D-view bands into the view buffer: sky rows 16..58, horizon rows 59 and 60..61, floor rows 62..103;
  x=2, width=11 chars. }
procedure DrawBackdrop;
begin
  Blit.FillPicRect(2, 16, 11, 43, GDVars.colorSkyCeiling, GDConsts.iconColorMap,
                   GDVars.viewImageBufferPtr);
  Blit.FillPicRect(2, 59, 11, 1, GDVars.wallColorA, GDConsts.iconColorMap, GDVars.viewImageBufferPtr);
  Blit.FillPicRect(2, 60, 11, 2, GDVars.wallColorB, GDConsts.iconColorMap, GDVars.viewImageBufferPtr);
  Blit.FillPicRect(2, 62, 11, 42, GDVars.wallColorC, GDConsts.iconColorMap, GDVars.viewImageBufferPtr);
end;

{ Blit view slot slot's symbol rectangle for wallType at char (x+2, y+2), walking the 156-cell slice from
  viewSlotGeom.start[slot], skipping zero symbols and cells outside the 11x11 view. cnt advances on every cell, drawn or
  clipped. }
procedure DrawWallSlice(x, y: ShortInt; wallType, slot: Byte);
var
  colLim: Integer;
  rowLim: Integer;
  col: Integer;
  row: Integer;
  cnt: Byte;
begin
  cnt := GDConsts.viewSlotGeom.start[slot];
  colLim := GDConsts.viewSlotGeom.cols[slot] + x - 1;
  rowLim := GDConsts.viewSlotGeom.rows[slot] + y - 1;
  for row := y to rowLim do
    for col := x to colLim do begin
      if (row >= 0) and (row <= 10) and (col >= 0) and (col <= 10) and (GDVars.wallGfx^[wallType][cnt] > 0) then
        Sym8x8.Put8x8Sym(col + 3 - 1, row + 3 - 1, GDVars.wallGfx^[wallType][cnt], True, True);
      Inc(cnt);
    end;
end;

procedure WrapCoords(var x, y: ShortInt);
begin
  if x > Types.MAP_LAST then x := 0;
  if x < 0 then x := Types.MAP_LAST;
  if y > Types.MAP_LAST then y := 0;
  if y < 0 then y := Types.MAP_LAST;
end;

{ True when (x, y) lies on the 16x16 map }
function Valid3DCoords(x, y: ShortInt): Boolean;
begin
  if (x > Types.MAP_LAST) or (x < 0) or (y > Types.MAP_LAST) or (y < 0) then
    Valid3DCoords := False
  else
    Valid3DCoords := True;
end;

{ The 2-bit barrier field for the facing, defaulting to 1 (passable) when the square has no wall graphic in that facing.
  Out-of-range coords wrap to the far edge, except under ECL script 0 or 10, where they read as 0. }
function GetBarrierType(x, y: ShortInt; facing: Byte): Byte;
var
  b: Byte;
begin
  if not View3D.Valid3DCoords(x, y) and ((GDVars.eclScriptId = 0) or (GDVars.eclScriptId = 10)) then
    GetBarrierType := 0
  else begin
    View3D.WrapCoords(x, y);
    b := 1;
    if View3D.GetWallType(x, y, facing) > 0 then
      case facing of
        C_Dir.WEST: b := (GDVars.map3d^.barriers[y][x] and $C0) shr 6;
        C_Dir.SOUTH: b := (GDVars.map3d^.barriers[y][x] and $30) shr 4;
        C_Dir.EAST: b := (GDVars.map3d^.barriers[y][x] and $0C) shr 2;
        C_Dir.NORTH: b := GDVars.map3d^.barriers[y][x] and $03;
      end;
    GetBarrierType := b;
  end;
end;

{ The wall-type nibble 0..15 (0 = no wall) for the facing, from wallsNE/wallsSW, with the same coordinate guard and wrap
  as GetBarrierType; 0 for a facing that is not a cardinal direction. }
function GetWallType(x, y: ShortInt; facing: Byte): Byte;
begin
  if not View3D.Valid3DCoords(x, y) and ((GDVars.eclScriptId = 0) or (GDVars.eclScriptId = 10)) then
    GetWallType := 0
  else begin
    View3D.WrapCoords(x, y);
    GetWallType := 0;
    case facing of
      C_Dir.NORTH: GetWallType := (GDVars.map3d^.wallsNE[y][x] and $F0) shr 4;
      C_Dir.EAST: GetWallType := GDVars.map3d^.wallsNE[y][x] and $0F;
      C_Dir.SOUTH: GetWallType := (GDVars.map3d^.wallsSW[y][x] and $F0) shr 4;
      C_Dir.WEST: GetWallType := GDVars.map3d^.wallsSW[y][x] and $0F;
    end;
  end;
end;

{ The EVENT byte of the square, with the same coordinate guard and wrap as GetBarrierType. MapView tests bit 7 of this
  for the sky colour choice. }
function GetMapEvent(x, y: ShortInt): Byte;
begin
  if not View3D.Valid3DCoords(x, y) and ((GDVars.eclScriptId = 0) or (GDVars.eclScriptId = 10)) then
    GetMapEvent := 0
  else begin
    View3D.WrapCoords(x, y);
    GetMapEvent := GDVars.map3d^.events[y][x];
  end;
end;

{ Flush the view buffer to the screen }
procedure DisplayViewBuf;
begin
  Blit.FlushView;
end;

{ Draw the automap when enabled. Otherwise draw the backdrop and wall slices from far to near, including fronts and side
  walls in each row. }
procedure Display3DMapView(x, y: ShortInt; facing: Byte);
var
  fL: Byte;
  fR: Byte;
  fB: Byte;
  cxPos: Integer;
  cyPos: Integer;
  dxF: Word;
  dyF: Word;
  dist: Byte;

  { The far row's fronts and their corner slot 9, from the centre cell walking walk (left or right) four cells; other
    is the opposite side, corner the corner slice's column offset (+1 walking left, -1 right), step the fronts' column
    step (-2, +2). }
  procedure FarFronts(walk, other: Byte; corner, step: Integer);
  var
    wx: Integer;
    wy: Integer;
    side: Byte;
    symOfs: Integer;
    wallFront: Byte;
    prevWall: Byte;
  begin
    wx := cxPos;
    wy := cyPos;
    side := 0;
    symOfs := 0;
    prevWall := 0;
    while side < 4 do begin
      wallFront := View3D.GetWallType(wx, wy, facing);
      if not View3D.Valid3DCoords(wx, wy) and (View3D.GetWallType(wx, wy, other) = 0) then
        prevWall := 0;
      if wallFront <> 0 then begin
        if prevWall > 0 then
          View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[9] + symOfs + corner, GDConsts.viewSlotGeom.yRow[9],
                               prevWall, 9);
        prevWall := wallFront;
        View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[0] + symOfs, GDConsts.viewSlotGeom.yRow[0], wallFront, 0);
      end else begin
        if (prevWall > 0) and
           (View3D.GetWallType(wx - GDConsts.dirDX[walk], wy - GDConsts.dirDY[walk], walk) <> 0) then
          View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[9] + symOfs + corner, GDConsts.viewSlotGeom.yRow[9],
                               prevWall, 9);
        prevWall := 0;
      end;
      Inc(side);
      Inc(symOfs, step);
      wx := wx + GDConsts.dirDX[walk];
      wy := wy + GDConsts.dirDY[walk];
    end;
  end;

  { The far row's side walls facing dir (left, slot 1; right, slot 2), from the centre cell walking dir three cells;
    step is the column step (-2, +2) and adjust the extra column past the centre cell (-1, +1). }
  procedure FarSides(dir, slot: Byte; step, adjust: Integer);
  var
    wx: Integer;
    wy: Integer;
    side: Byte;
    symOfs: Integer;
    wallSide: Byte;
  begin
    wx := cxPos;
    wy := cyPos;
    side := 0;
    symOfs := 0;
    while side < 3 do begin
      wallSide := View3D.GetWallType(wx, wy, dir);
      if wallSide <> 0 then
        if side = 0 then
          View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[slot] + symOfs, GDConsts.viewSlotGeom.yRow[slot], wallSide,
                               slot)
        else
          View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[slot] + symOfs + adjust, GDConsts.viewSlotGeom.yRow[slot],
                               wallSide, slot);
      Inc(side);
      Inc(symOfs, step);
      wx := wx + GDConsts.dirDX[dir];
      wy := wy + GDConsts.dirDY[dir];
    end;
  end;

  { A middle or near row's fronts (frontSlot) and the side walls facing sideDir (sideSlot): count cells from cells
    cells toward start, scanning toward scan, the columns from symStart in steps of symStep. }
  procedure FrontsAndSides(start, cells, count: Byte; symStart, symStep: Integer; frontSlot, sideDir, sideSlot,
                           scan: Byte);
  var
    wx: Integer;
    wy: Integer;
    side: Byte;
    symOfs: Integer;
    wallFront: Byte;
    wallSide: Byte;
  begin
    wx := cxPos;
    wy := cyPos;
    for side := 1 to cells do begin
      wx := wx + GDConsts.dirDX[start];
      wy := wy + GDConsts.dirDY[start];
    end;
    side := 0;
    symOfs := symStart;
    while side < count do begin
      wallFront := View3D.GetWallType(wx, wy, facing);
      if wallFront <> 0 then
        View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[frontSlot] + symOfs, GDConsts.viewSlotGeom.yRow[frontSlot],
                             wallFront, frontSlot);
      wallSide := View3D.GetWallType(wx, wy, sideDir);
      if wallSide <> 0 then
        View3D.DrawWallSlice(GDConsts.viewSlotGeom.xCol[sideSlot] + symOfs, GDConsts.viewSlotGeom.yRow[sideSlot],
                             wallSide, sideSlot);
      Inc(side);
      Inc(symOfs, symStep);
      wx := wx + GDConsts.dirDX[scan];
      wy := wy + GDConsts.dirDY[scan];
    end;
  end;

begin
  { the Companion Tools' map remembers every square the view is drawn from (phase 8) }
  Explored.Mark(x, y);
  if GDVars.automapOn then
    View3D.DrawAutoMap(x, y, facing)
  else begin
    View3D.DrawBackdrop;
    fL := (facing + 6) mod 8;
    fB := (facing + 4) mod 8;
    fR := (facing + 2) mod 8;
    cxPos := x;
    cyPos := y;
    dxF := GDConsts.dirDX[facing];
    dyF := GDConsts.dirDY[facing];
    dist := 2;
    Inc(cxPos, dist * dxF);
    Inc(cyPos, dist * dyF);
    repeat
      case dist of
        2: begin
          FarFronts(fL, fR, 1, -2);
          FarFronts(fR, fL, -1, 2);
          FarSides(fL, 1, -2, -1);
          FarSides(fR, 2, 2, 1);
        end;
        1: begin
          { middle row: from 2-left scanning right, fronts slot 3 + left sides slot 4; then from 2-right scanning left,
            right sides slot 5 }
          FrontsAndSides(fL, 2, 3, -6, 3, 3, fL, 4, fR);
          FrontsAndSides(fR, 2, 3, 6, -3, 3, fR, 5, fL);
        end;
        0: begin
          { near row: the left cell and the centre, fronts slot 6 + left slot 7; then the right cell and the centre,
            right slot 8 }
          FrontsAndSides(fL, 1, 2, -7, 7, 6, fL, 7, fR);
          FrontsAndSides(fR, 1, 2, 7, -7, 6, fR, 8, fL);
        end;
      end;
      cxPos := cxPos + GDConsts.dirDX[fB];
      cyPos := cyPos + GDConsts.dirDY[fB];
      Dec(dist);
    { Byte dist wrapping past 0 }
    until dist = 255;
    View3D.DisplayViewBuf;
  end;
end;

{ Load WALLDEF<disk>.DAX record fileId into wallset slot wsSlot (1..3; each wall-def block fills one slot of 5 wall
  types, and further blocks fill the following slots), remap every symbol past set 0 (>= symSetFirst[1], 46) by wsSlot's
  8x8-set base offset, load the matching 8x8 set(s), and stamp the slot cache. The size guard refuses a record that is
  not whole blocks or whose blocks would run past slot 3. A multi-block load composes each 8x8-set id as fileId*10 + i,
  with file 0 spelled as 10 for that product, so such a record above 25 is refused too; the cache is stamped with fileId
  itself. }
procedure LoadWallSet(fileId, wsSlot: Byte);
var
  sizeRead: Word;
  data: Types.PByteArr;
  offset: Word;
  symOfs: Word;
  row: Byte;
  i: Word;
  col: Integer;
  count: Byte;
  setFile: Byte;
begin
  if (wsSlot < 1) or (wsSlot > 3) then Exit;
  DaxIo.LoadDax('WALLDEF' + StrUtil.NumStr(GDVars.virtualDisk), '.dax', fileId, sizeRead, data);
  if (sizeRead = 0) or (sizeRead mod SizeOf(Types.TView3dWallDef) <> 0) or
      (sizeRead div SizeOf(Types.TView3dWallDef) + wsSlot > 4) or
      ((sizeRead > SizeOf(Types.TView3dWallDef)) and (fileId > 25)) then begin
    GameIo.FatalError('Unable to load wallset in LoadWallSet.');
  end;
  symOfs := GDConsts.symSetFirst[wsSlot] - GDConsts.symSetFirst[1];
  offset := 0;
  i := 1;
  repeat
    { slot wsSlot + i - 1's five wall types start at wall type 5 * (wsSlot + i - 2) + 1 }
    Move(data^[offset], GDVars.wallGfx^[5 * (wsSlot + i - 2) + 1], SizeOf(Types.TView3dWallDef));
    Inc(offset, SizeOf(Types.TView3dWallDef));
    Inc(i);
  until offset >= sizeRead;
  FreeMem(data, sizeRead);
  count := i - 1;
  for i := 1 to count do
    if (wsSlot + i - 1) in [1..3] then begin
      GDVars.wallSetCache[wsSlot + i - 1].wallDefId := -1;
      GDVars.wallSetCache[wsSlot + i - 1].symbolSlot := -1;
      for row := 1 to 5 do
        for col := 0 to 155 do begin
          { set 0's symbols (1..45) are shared by every slot; SSI also moved its last one, 45, into another slot's
            set (#727) }
          if GDVars.wallGfx^[5 * (wsSlot + i - 2) + row][col] >= GDConsts.symSetFirst[1] then
            Inc(GDVars.wallGfx^[5 * (wsSlot + i - 2) + row][col], symOfs);
        end;
      if count > 1 then begin
        if fileId = 0 then
          setFile := 10
        else
          setFile := fileId;
        Sym8x8.Load8x8Set(setFile * 10 + i, wsSlot + i - 1);
      end else
        Sym8x8.Load8x8Set(fileId, wsSlot + i - 1);
    end;
  GDVars.wallSetCache[wsSlot].wallDefId := fileId;
  GDVars.wallSetCache[wsSlot].symbolSlot := wsSlot;
end;

{ Load GEO<disk>.DAX record mapId (must decompress to exactly 1026 = 2-byte header + the four 256-byte planes of a
  TGeoMap), copy the planes, free the record, and record the map id in the GBVM mapId variable. }
procedure Load3DMap(mapId: Byte);
var
  sizeRead: Word;
  data: Types.PByteArr;
  offset: Word;
begin
  DaxIo.LoadDax('GEO' + StrUtil.NumStr(GDVars.virtualDisk), '.dax', mapId, sizeRead, data);
  if (sizeRead = 0) or (sizeRead <> SizeOf(Types.TGeoMap) + 2) then begin
    GameIo.FatalError('Unable to load geo in Load3DMap.');
  end;
  offset := 2;
  Move(data^[offset], GDVars.map3d^.wallsNE, SizeOf(Types.TGeoPlane));
  Inc(offset, SizeOf(Types.TGeoPlane));
  Move(data^[offset], GDVars.map3d^.wallsSW, SizeOf(Types.TGeoPlane));
  Inc(offset, SizeOf(Types.TGeoPlane));
  Move(data^[offset], GDVars.map3d^.events, SizeOf(Types.TGeoPlane));
  Inc(offset, SizeOf(Types.TGeoPlane));
  Move(data^[offset], GDVars.map3d^.barriers, SizeOf(Types.TGeoPlane));
  FreeMem(data, sizeRead);
  GDVars.zone0^.mapId.value := mapId;
end;

end.

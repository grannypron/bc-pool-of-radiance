{ Build dungeon and wilderness combat arenas, load terrain tiles and place creatures. }
{$O+,F+}
{$I COMPILER.INC}
unit CombatSt;

interface

procedure CombatStart;

implementation

uses Types, Crt, C_Area, C_Npc, C_Terr, C_Cond, GDConsts, GDVars, CbtActs, SaveLoad, FxEngine, Portrait, View3D,
  MapTiles, Blit, GameIo, C_Ifc, C_Gbvm, C_Dir, C_Sound, SoundDrv, CbtMap, CharHlp, MenuCore, TextRend, CharDisp, Dice;

var
  { wildMap cell under party }
  terrainChar: Byte;

var
  { Combat placement, by team }
  { quad occupancy [team, ring 0..3, qy 0..5, qx 0..10]; 1 = free }
  quadFree: array[0..1, 0..3, 0..5, 0..10] of Byte;
  { per team }
  placeX: array[0..1] of ShortInt;
  placeY: array[0..1] of ShortInt;
  teamRows: array[0..1] of ShortInt;
  teamDir: array[0..1] of ShortInt;

{ On every arena cell whose terrain tile is 22 (grass), roll 1d100: 98 gives terrain 26, 99 gives 27, and 100 (unless
  eclScriptId = 10) gives a further 1% chance of 28 (1d10 = 1..6) or 29 (7..10). }
procedure SprinkleRareFeatures;
var
  col: ShortInt;
  row: ShortInt;
  roll: Byte;
begin
  for col := 0 to 49 do
    for row := 0 to 24 do
      if GDConsts.terrainInfo[GDVars.arenaPtr^.cells[row, col]].tileId = 22 then begin
        roll := Dice.RollDice(1, 100);
        case roll of
          1..97: ;
          98: GDVars.arenaPtr^.cells[row, col] := 26;
          99: GDVars.arenaPtr^.cells[row, col] := 27;
          100: if GDVars.eclScriptId <> 10 then
                 if Dice.RollDice(1, 100) = 1 then
                   case Dice.RollDice(1, 10) of
                     1..6: GDVars.arenaPtr^.cells[row, col] := 28;
                     7..10: GDVars.arenaPtr^.cells[row, col] := 29;
                   end;
        end;
      end;
end;

{ The wall kind between dungeon cell (x, y) and its dir neighbour: probe the edge from both sides (the cell facing dir,
  the neighbour facing (dir + 4) mod 8) and OR the two kinds. Kinds: 0 = open, 1 = solid, 3 = door (wall present but
  barrier passable); solid on one side and a door on the other ORs to 3. }
function WallBetween(x, y: ShortInt; dir: Byte): Byte;
var
  k1: Byte;
  k2: Byte;
  opp: Byte;

  { Classify one side of an edge in the 16x16 map: barrier type 0 = solid (1), no wall = open (0), else 3. Outside the
    map, east/west probes on the party's row are open; all other cells are solid. }
  function GetWallKind(px, py: ShortInt; pdir: Byte): Byte;
  begin
    if (px >= 0) and (px <= 15) and (py >= 0) and (py <= 15) then begin
      if View3D.GetBarrierType(px, py, pdir) = 0 then
        GetWallKind := 1
      else if View3D.GetWallType(px, py, pdir) = 0 then
        GetWallKind := 0
      else
        GetWallKind := 3;
    end else begin
      if (py = GDVars.gMapY) and ((pdir = C_Dir.EAST) or (pdir = C_Dir.WEST)) then
        GetWallKind := 0
      else
        GetWallKind := 1;
    end;
  end;

begin
  opp := (dir + 4) mod 8;
  k1 := GetWallKind(x, y, dir);
  k2 := GetWallKind(x + GDConsts.dirDX[dir], y + GDConsts.dirDY[dir], opp);
  WallBetween := k1 or k2;
end;

{ Build a dungeon arena from a 13x5 window around the party. Map each dungeon cell into a skewed 6x5 block, draw its
  walls and add rare terrain features. }
procedure BuildDungeonArena;
var
  dx: ShortInt;
  dy: ShortInt;
  cellX: ShortInt;
  cellY: ShortInt;
  wallN: Byte;
  wallW: Byte;
  wallE: Byte;

  { Plot terrain t+1 at spot (i, j) of the current cell's skewed block, clipped to the arena }
  procedure PlotCell(i, j, t: Byte);
  var
    x: ShortInt;
    y: ShortInt;
  begin
    x := dx * 6 + dy * 5 + 21 + i;
    y := dy * 5 + 10 + j;
    if (x >= 0) and (x <= 49) and (y >= 0) and (y <= 24) then
      GDVars.arenaPtr^.cells[y, x] := t + 1;
  end;

  { The cell's floor (spots 0..5, rows 2..4) and its WEST wall }
  procedure DrawFloorWestWall;
  var
    c: Byte;
    r: Byte;
  begin
    for r := 2 to 4 do
      for c := 0 to 5 do
        PlotCell(c, r, 22);
    if wallW = 1 then begin
      for r := 2 to 4 do begin
        PlotCell(r - 1, r, 4);
        PlotCell(r, r, 3);
        PlotCell(r + 1, r, 13);
      end;
    end else if wallW = 3 then begin
      PlotCell(1, 2, 8);
      PlotCell(5, 4, 0);
    end;
  end;

  { The NORTH wall band (spots (3..4, 0..1)): wall terrain when solid, floor otherwise }
  procedure DrawNorthWall;
  begin
    if wallN = 1 then begin
      PlotCell(3, 0, 5);
      PlotCell(4, 0, 5);
      PlotCell(3, 1, 10);
      PlotCell(4, 1, 10);
    end else begin
      PlotCell(3, 0, 22);
      PlotCell(4, 0, 22);
      PlotCell(3, 1, 22);
      PlotCell(4, 1, 22);
    end;
  end;

  { NW corner: spots (1..2, 0..1). open = both far-side edges open (N-neighbour's W wall and W-neighbour's N wall) }
  procedure FillCornerNW;
  var
    k: Byte;
    c1: Byte;
    c3: Byte;
    c2: Byte;
    c4: Byte;
    open: Byte;
  begin
    if (CombatSt.WallBetween(cellX, cellY - 1, C_Dir.WEST) = 0) and
        (CombatSt.WallBetween(cellX - 1, cellY, C_Dir.NORTH) = 0) then
      open := 1
    else
      open := 0;
    for k := 1 to 4 do
      case k of
        1: case wallN of
             0: case wallW of
                  0: c1 := 22;
                  3: c1 := 13;
                  1: if open <> 0 then c1 := 0 else c1 := 13;
                end;
             3, 1: if wallW = 0 then begin
                     if open <> 0 then c1 := 15 else c1 := 5;
                   end else begin
                     if open <> 0 then c1 := 18 else c1 := 2;
                   end;
           end;
        2: case wallN of
             0: c2 := 22;
             3: c2 := 17;
             1: c2 := 5;
           end;
        3: case wallW of
             0: if wallN = 0 then
                  c3 := 22
                else if open <> 0 then
                  c3 := 16
                else
                  c3 := 10;
             3: if open <> 0 then c3 := 20 else c3 := 7;
             1: if open <> 0 then c3 := 1 else c3 := 3;
           end;
        4: case wallW of
             0, 3: case wallN of
                     0: c4 := 22;
                     3: c4 := 23;
                     1: c4 := 10;
                   end;
             1: case wallN of
                  0: c4 := 13;
                  3: c4 := 21;
                  1: c4 := 6;
                end;
           end;
      end;
    PlotCell(1, 0, c1);
    PlotCell(2, 0, c2);
    PlotCell(1, 1, c3);
    PlotCell(2, 1, c4);
  end;

  { NE corner: spots (5..6, 0..1); spot x=6 spills into the next cell's block. kN = N-neighbour's E wall, kE =
    E-neighbour's N wall; open = both are open }
  procedure FillCornerNE;
  var
    k: Byte;
    c1: Byte;
    c3: Byte;
    c2: Byte;
    c4: Byte;
    open: Byte;
    kN: Byte;
    kE: Byte;
  begin
    kN := CombatSt.WallBetween(cellX, cellY - 1, C_Dir.EAST);
    kE := CombatSt.WallBetween(cellX + 1, cellY, C_Dir.NORTH);
    if (kN = 0) and (kE = 0) then
      open := 1
    else
      open := 0;
    for k := 1 to 4 do
      case k of
        1: case wallN of
             0: if kN = 1 then c1 := 4 else c1 := 22;
             3: c1 := 15;
             1: c1 := 5;
           end;
        2: if wallN = 0 then begin
             case kN of
               0: c2 := 22;
               3: if (wallE = 0) and (kE <> 0) then
                    c2 := 24
                  else
                    c2 := 1;
               1: if (wallE = 0) and (kE <> 0) then
                    c2 := 11
                  else
                    c2 := 3;
             end;
           end else begin
             if wallE <> 0 then
               c2 := 9
             else if kE <> 0 then
               c2 := 5
             else if open <> 0 then
               c2 := 17
             else
               c2 := 19;
           end;
        3: case wallN of
             0: c3 := 22;
             3: c3 := 16;
             1: c3 := 10;
           end;
        4: if wallN = 0 then begin
             if kN = 0 then
               c4 := 22
             else if wallE <> 0 then
               c4 := 4
             else if kE = 0 then
               c4 := 8
             else
               c4 := 12;
           end else begin
             if wallE <> 0 then
               c4 := 14
             else if kE = 0 then
               c4 := 23
             else
               c4 := 10;
           end;
      end;
    PlotCell(5, 0, c1);
    PlotCell(6, 0, c2);
    PlotCell(5, 1, c3);
    PlotCell(6, 1, c4);
  end;

begin
  for dy := -2 to 2 do
    for dx := -6 to 6 do begin
      cellX := GDVars.gMapX + dx;
      cellY := GDVars.gMapY + dy;
      wallW := CombatSt.WallBetween(cellX, cellY, C_Dir.WEST);
      wallN := CombatSt.WallBetween(cellX, cellY, C_Dir.NORTH);
      wallE := CombatSt.WallBetween(cellX, cellY, C_Dir.EAST);
      DrawFloorWestWall;
      DrawNorthWall;
      FillCornerNW;
      FillCornerNE;
    end;
  CombatSt.SprinkleRareFeatures;
end;

{ Map the wilderness terrain char under the party to a feature-class bitmask steering the random-arena generators; an
  unmatched terrainChar (the special sites' tiles) is plain ground, $01. Once zone0^.yarashMissionDone is 255, bit 7
  classes collapse to bit 0. }
function TerrainClassOf: Byte;
var
  cls: Byte;
begin
  { SSI repeated some values in later arms, where the first arm took them; those are left out }
  case terrainChar of
    1..2, 40..41, 79..86, 91..92, 43, 241:
      cls := $01;
    168..177:
      cls := $21;
    185, 187, 188..192:
      cls := $11;
    3..4, 5, 6..7, 8..9, 19..21, 23..25:
      cls := $03;
    10..18, 22, 26..36, 201..208:
      cls := $02;
    209..213:
      cls := $12;
    37, 57, 64, 154..158, 164..165, 180, 243, 239..240, 250, 252:
      cls := $04;
    39, 42, 44, 153, 159:
      cls := $05;
    45..46, 51..56, 67..77, 93..97:
      cls := $44;
    181..184, 186, 193..200:
      cls := $14;
    47..50, 98..101, 242:
      cls := $40;
    38:
      cls := $41;
    178..179:
      cls := $60;
    58..60, 65..66:
      cls := $48;
    61..63, 121..124, 135..137, 139, 141, 144..147, 149, 151..152,
    160..162, 166..167, 214..216, 238:
      cls := $08;
    87..90, 163, 224:
      cls := $88;
    125, 134, 138, 140, 142, 143, 148, 150:
      cls := $09;
    126..133, 229..231:
      cls := $28;
    217..223:
      cls := $18;
    78, 245, 232..233:
      cls := $20;
    109, 244, 246:
      cls := $80;
    110..113, 115..120:
      cls := $81;
    102..108, 114:
      cls := $90;
    225..228, 234..237:
      cls := $A0;
  else
    cls := $01;
  end;
  if cls and $80 <> 0 then
    if GDVars.zone0^.yarashMissionDone = 255 then begin
      Dec(cls, $80);
      cls := cls or 1;
    end;
  TerrainClassOf := cls;
end;

{ Lay a diagonal river (terrain pair 50/51, drifting one column per row) with 2-row fords (52/53: a 1-in-20 roll starts
  one and the odd fordCnt forces the next row), forcing a 2-row ford if none was rolled. Chance: class bit 5 gives 35%,
  bit 4 gives 75%, otherwise no river. }
procedure PlaceRiver;
var
  thresh: Byte;
  fordCnt: Byte;
  startCol: ShortInt;
  col: ShortInt;
  row: ShortInt;

  { Place a ford pair at adjacent cells and increment fordCnt. }
  procedure PlotFord(r, c: ShortInt);
  begin
    GDVars.arenaPtr^.cells[r, c] := 52;
    GDVars.arenaPtr^.cells[r, c + 1] := 53;
    Inc(fordCnt);
  end;

begin
  thresh := 0;
  fordCnt := 0;
  if CombatSt.TerrainClassOf and $20 <> 0 then thresh := 35;
  if CombatSt.TerrainClassOf and $10 <> 0 then thresh := 75;
  if Dice.RollDice(1, 100) > thresh then Exit;
  col := 34 - Dice.RollDice(5, 4);
  while (col + 2) mod 7 > 0 do
    Dec(col);
  startCol := col;
  for row := 0 to 24 do begin
    { the pair takes col and col + 1; at col 49 the second would land in the next row's column 0 }
    if col <= 48 then begin
      GDVars.arenaPtr^.cells[row, col] := 50;
      GDVars.arenaPtr^.cells[row, col + 1] := 51;
      if (Dice.RollDice(1, 20) = 1) or Odd(fordCnt) then
        PlotFord(row, col);
      Inc(col);
    end;
  end;
  if fordCnt = 0 then begin
    row := 12 - Dice.RollDice(1, 9) + 4;
    col := startCol + row;
    PlotFord(row, col);
    PlotFord(row + 1, col + 1);
  end;
end;

{ Plant trees on vertical grass pairs; density by class bits (2/4/$40/8/$80 give 1/3/4/7/0%, later bits win). Height: a
  1d10 roll of 9..10 gives 1d2+4, else (roll+1) div 2; class $40 overrides with 1d3+3. Bottom = h+31+4, top (h < 5 only)
  = h+31. }
procedure PlaceTrees;
var
  dens: Byte;
  h: Byte;
  col: ShortInt;
  row: ShortInt;
begin
  dens := 1;
  if CombatSt.TerrainClassOf and $02 <> 0 then dens := 1;
  if CombatSt.TerrainClassOf and $04 <> 0 then dens := 3;
  if CombatSt.TerrainClassOf and $40 <> 0 then dens := 4;
  if CombatSt.TerrainClassOf and $08 <> 0 then dens := 7;
  if CombatSt.TerrainClassOf and $80 <> 0 then dens := 0;
  for col := 0 to 49 do
    for row := 1 to 24 do
      if (GDConsts.terrainInfo[GDVars.arenaPtr^.cells[row, col]].tileId = 22) and
          (GDConsts.terrainInfo[GDVars.arenaPtr^.cells[row - 1, col]].tileId = 22) and
          (Dice.RollDice(1, 100) <= dens) then begin
        h := Dice.RollDice(1, 10);
        if h > 8 then
          h := Dice.RollDice(1, 2) + 4
        else
          h := (h + 1) div 2;
        if CombatSt.TerrainClassOf and $40 <> 0 then
          h := Dice.RollDice(1, 3) + 3;
        GDVars.arenaPtr^.cells[row, col] := h + 31 + 4;
        if h < 5 then
          GDVars.arenaPtr^.cells[row - 1, col] := h + 31;
      end;
end;

{ For each grass cell roll 1d255 against five stacked probability bands (weights tuned by the terrain class): swamp pool
  (61..63, or on a 4 a 2-tall pool 64/65 when the cell above is grass), rocks (55..57), bushes (42..45), mounds (57..60
  via (1d10-1) div 3 + 1) and scrub (46..49; 49 only for class $40). }
procedure ScatterFeatures;
var
  tSwamp: Byte;
  tA: Byte;
  tB: Byte;
  tC: Byte;
  tD: Byte;
  r: Byte;
  col: ShortInt;
  row: ShortInt;
begin
  tSwamp := 0;
  tA := 6;
  tB := 15;
  tC := 40;
  tD := 0;
  if CombatSt.TerrainClassOf and $02 <> 0 then begin
    tB := 45;
    tC := 10;
  end;
  if CombatSt.TerrainClassOf and $04 <> 0 then
    tB := 25;
  if CombatSt.TerrainClassOf and $40 <> 0 then begin
    tC := 5;
    tD := 30;
  end;
  if CombatSt.TerrainClassOf and $80 <> 0 then begin
    tSwamp := 15;
    tC := 25;
    tB := 10;
  end;
  for col := 0 to 49 do
    for row := 0 to 24 do
      if GDConsts.terrainInfo[GDVars.arenaPtr^.cells[row, col]].tileId = 22 then begin
        r := Dice.RollDice(1, 255);
        if r <= tSwamp then begin
          r := Dice.RollDice(1, 4);
          if (r = 4) and (row > 0) and
              (GDConsts.terrainInfo[GDVars.arenaPtr^.cells[row - 1, col]].tileId = 22) then begin
            GDVars.arenaPtr^.cells[row - 1, col] := 65;
            GDVars.arenaPtr^.cells[row, col] := 64;
          end;
          if r < 4 then
            GDVars.arenaPtr^.cells[row, col] := r + 31 + 29;
        end else if r <= tA + tSwamp then
          GDVars.arenaPtr^.cells[row, col] := Dice.RollDice(1, 3) + 31 + 23
        else if r <= tB + tSwamp + tA then
          GDVars.arenaPtr^.cells[row, col] := Dice.RollDice(1, 4) + 31 + 10
        else if r <= tD + tB + tSwamp + tA then begin
          r := (Dice.RollDice(1, 10) - 1) div 3 + 1;
          GDVars.arenaPtr^.cells[row, col] := r + 31 + 25;
        end else if r <= tA + (tC + tD + tB + tSwamp) then begin
          r := Dice.RollDice(1, 4);
          if (r = 4) and (CombatSt.TerrainClassOf and $40 = 0) then
            r := Dice.RollDice(1, 3);
          GDVars.arenaPtr^.cells[row, col] := r + 31 + 14;
        end;
      end;
end;

{ Fill the arena with terrain 23, read the wilderness terrain char under the party (columns offset by 13 for the central
  map and 26 for the east map) and run the river, tree, scatter and rare-feature generators. }
procedure BuildWildernessArena;
var
  mapX: ShortInt;
  mapY: ShortInt;
begin
  FillChar(GDVars.arenaPtr^.cells, SizeOf(GDVars.arenaPtr^.cells), 23);
  mapX := GDVars.zone0^.partyX.lo;
  mapY := GDVars.zone0^.partyY.lo;
  if GDVars.gLocType = C_Area.LOC_WILD_CENTRAL then Inc(mapX, 13);
  if GDVars.gLocType = C_Area.LOC_WILD_EAST then Inc(mapX, 26);
  terrainChar := GDConsts.wildMap[mapY, mapX];
  CombatSt.PlaceRiver;
  CombatSt.PlaceTrees;
  CombatSt.ScatterFeatures;
  CombatSt.SprinkleRareFeatures;
end;

{ Load dungeon or wilderness terrain tiles and the random-feature set, allocate the arena and run the appropriate
  terrain generator. }
procedure LoadCombatTileSet;
begin
  { combat's terrain is tiles 0..39 of the first set; the second is loaded again when next needed }
  MapTiles.FreeSecondSheet;
  if GDVars.gLocType = C_Area.LOC_3D_MAP then
    MapTiles.Load24x24Set('DungCom', 0, 24)
  else
    MapTiles.Load24x24Set('WildCom', 0, 33);
  MapTiles.Load24x24Set('RandCom', 34, 5);
  GetMem(GDVars.arenaPtr, SizeOf(Types.TArena));
  GDVars.arenaPtr^.cursorOn := False;
  GDVars.arenaPtr^.cursorSize := 1;
  GDVars.arenaPtr^.distMode := 0;
  if GDVars.gLocType = C_Area.LOC_3D_MAP then
    CombatSt.BuildDungeonArena
  else
    CombatSt.BuildWildernessArena;
end;

{ Recalculate each creature's statistics and initialize its combat record; creatures past the party size get notPcNpc =
  1. Non-hostile creatures face quadDir[gFacing div 2]; hostiles face the opposite way. Friendly non-party creatures
  whose morale is 0 or above 102 get the morale threshold plus C_Npc.FLAG. }
procedure InitCreatureCombatData;
var
  p: Types.PCharRecord;
  count: Byte;
  m: Byte;
begin
  p := GDVars.creatureList;
  count := 0;
  while p <> nil do begin
    CharHlp.RecalcStats(p);
    Inc(count);
    GetMem(p^.combatAddr, SizeOf(Types.TCombatRec));
    FillChar(p^.combatAddr^, SizeOf(Types.TCombatRec), 0);
    if count > GDVars.zone1^[C_Gbvm.PARTY_SIZE] then
      p^.combatAddr^.notPcNpc := 1;
    p^.combatAddr^.direction := GDConsts.quadDir[GDVars.gFacing div 2];
    if p^.hostile = 1 then
      p^.combatAddr^.direction := (p^.combatAddr^.direction + 4) mod 8;
    m := p^.npc and C_Npc.MORALE_MASK;
    if (p^.hostile = 0) and (p^.combatAddr^.notPcNpc = 1) and ((m = 0) or (m > 102)) then
      p^.npc := GDVars.zone1^[C_Gbvm.MORALE_THRESHOLD] + C_Npc.FLAG;
    p := p^.nextCharAddr;
  end;
end;

{ True only when both quad coordinates are outside the 11x6 grid (x outside 0..10 and y outside 0..5); either axis in
  range gives False. }
function QuadFullyOff(qx, qy: ShortInt): Boolean;
begin
  if ((qx >= 0) and (qx < 11)) or ((qy >= 0) and (qy < 6)) then
    QuadFullyOff := False
  else
    QuadFullyOff := True;
end;

{ Try to put creature slot on quad (qx, qy) of the given ring for team. The quad must be in the grid and free; its arena
  spot (the same 6/5 skew mapping as the dungeon builder, +22/+10) is stored into arenaLoc before the probe, and
  CbtMap.ProbeDirection must find no creature there and passable terrain (cost < 255). On success mark the quad used and
  return 1, else 0. }
function TryPlaceAt(team: ShortInt; slot: Byte; qx, qy, bqx, bqy: ShortInt; ring: Byte): Byte;
var
  crIdx: Byte;
  terrIdx: Byte;
begin
  if (qx < 0) or (qy < 0) or (qx > 10) or (qy > 5) or (quadFree[team, ring, qy, qx] = 0) then
    TryPlaceAt := 0
  else begin
    { Store coordinates before probing }
    GDVars.arenaLoc[slot].x := qx + bqx * 6 + bqy * 5 + 22;
    GDVars.arenaLoc[slot].y := qy + bqy * 5 + 10;
    CbtMap.ProbeDirection(GDVars.creatureArr[slot], C_Dir.CENTER, crIdx, terrIdx);
    if (crIdx = 0) and (terrIdx > 0) and (GDConsts.terrainInfo[terrIdx].cost < 255) then begin
      TryPlaceAt := 1;
      quadFree[team, ring, qy, qx] := 0;
    end else
      TryPlaceAt := 0;
  end;
end;

{ Search for a free quad for slot on team's grid in zigzag legs. A leg starts at startQX/startQY for the
  ring's quadrant, shifted legShift steps along quadDir[(quad + 2) mod 4], then alternates outward along quadDir[(quad
  + 1) mod 4] and quadDir[(quad + 3) mod 4], trying TryPlaceAt at each in-grid quad. A leg ends at a partially-off quad
  or after teamRows quads (first leg) or 12 (later legs); the next leg starts one step further, or two on team 0's
  first leg in ring 0 when Odd(teamDir[0]) and any ringDirTbl direction 1..3 is not a solid wall. A fully-off quad
  advances to the next ring (up to 3) whose ringDirTbl direction is not a solid wall (always, outdoors), re-basing the
  grid one step that way. Return False when no ring remains. }
function FindPlacement(team: ShortInt; slot: Byte): Boolean;
var
  placed: Byte;
  firstPass: Byte;
  giveUp: Byte;
  offGrid: Byte;
  open: Byte;
  state: Byte;
  dir: Byte;
  quad: Byte;
  k: Byte;
  stepX: ShortInt;
  stepY: ShortInt;
  wallX: ShortInt;
  wallY: ShortInt;
  legShift: Byte;
  legLen: Byte;
  baseQX: ShortInt;
  baseQY: ShortInt;
  tries: Byte;
  ring: Byte;
  legX: ShortInt;
  legY: ShortInt;
  qx: ShortInt;
  qy: ShortInt;
begin
  firstPass := 1;
  giveUp := 0;
  state := 1;
  legShift := 0;
  ring := 0;
  baseQX := placeX[team];
  baseQY := placeY[team];
  repeat
    quad := GDConsts.ringStart[teamDir[team], ring] div 2;
    case state of
      1: begin
           stepX := GDConsts.dirDX[GDConsts.quadDir[(quad + 2) mod 4]];
           stepY := GDConsts.dirDY[GDConsts.quadDir[(quad + 2) mod 4]];
           legX := GDConsts.startQX[ring > 0, quad] + stepX * legShift;
           legY := GDConsts.startQY[ring > 0, quad] + stepY * legShift;
           qx := legX;
           qy := legY;
           legLen := 1;
           state := 2;
           tries := 1;
         end;
      2: begin
           stepX := GDConsts.dirDX[GDConsts.quadDir[(quad + 1) mod 4]];
           stepY := GDConsts.dirDY[GDConsts.quadDir[(quad + 1) mod 4]];
           qx := legX + stepX * legLen;
           qy := legY + stepY * legLen;
           state := 3;
           Inc(tries);
         end;
      3: begin
           stepX := GDConsts.dirDX[GDConsts.quadDir[(quad + 3) mod 4]];
           stepY := GDConsts.dirDY[GDConsts.quadDir[(quad + 3) mod 4]];
           qx := legX + stepX * legLen;
           qy := legY + stepY * legLen;
           state := 2;
           Inc(legLen);
           Inc(tries);
         end;
    end;
    if (qx < 0) or (qy < 0) or (qx > 10) or (qy > 5) then
      offGrid := 1
    else
      offGrid := 0;
    if state > 1 then begin
      { leg exhausted? (a partially-off quad, or out of tries) }
      if ((offGrid <> 0) and (not CombatSt.QuadFullyOff(qx,
                                                        qy))) or ((firstPass <> 0) and
                                                                  (tries >= teamRows[team])) or
          ((firstPass = 0) and (tries > 11)) then begin
        Inc(legShift);
        if (team = 0) and Odd(teamDir[0]) and (ring = 0) and (legShift = 1) then begin
          wallX := placeX[team] + GDVars.gMapX;
          wallY := placeY[team] + GDVars.gMapY;
          open := 0;
          for k := 1 to 3 do begin
            dir := GDConsts.ringDirTbl[teamDir[team], k];
            if (GDVars.gLocType > C_Area.LOC_3D_MAP) or (CombatSt.WallBetween(wallX, wallY, dir) <> 1) then
              open := 1;
          end;
          if open <> 0 then
            Inc(legShift);
        end;
        state := 1;
        firstPass := 0;
      end;
    end;
    { Outside the state > 1 guard: advance the search ring when the quad lies fully outside the grid. }
    if (offGrid <> 0) and CombatSt.QuadFullyOff(qx, qy) then begin
        placed := 0;
        state := 0;
        while (ring < 3) and (state <> 1) do begin
          Inc(ring);
          wallX := placeX[team] + GDVars.gMapX;
          wallY := placeY[team] + GDVars.gMapY;
          dir := GDConsts.ringDirTbl[teamDir[team], ring];
          if (GDVars.gLocType > C_Area.LOC_3D_MAP) or (CombatSt.WallBetween(wallX, wallY, dir) <> 1) then begin
            baseQX := placeX[team] + GDConsts.dirDX[dir];
            baseQY := placeY[team] + GDConsts.dirDY[dir];
            legShift := 0;
            state := 1;
          end;
        end;
        if state <> 1 then
          giveUp := 1;
    end;
    if offGrid = 0 then
      placed := CombatSt.TryPlaceAt(team, slot, qx, qy, baseQX, baseQY, ring);
  until (placed <> 0) or (giveUp <> 0);
  if giveUp <> 0 then
    FindPlacement := False
  else
    FindPlacement := True;
end;

{ Place the party (team 0, at the origin) and the opposing team (C_Gbvm.MONSTER_DIST steps along gFacing, facing back)
  and seed each team's quad grids from rowBand. Register creatures and find a valid cell for each. Disabled party
  members become corpses outside duels; non-party creatures that cannot be placed are removed, unplaced party members
  keep their slot with size 0. Terminate the surviving creature list afterward. }
procedure PlaceAllCreatures;
var
  team: ShortInt;
  x: ShortInt;
  y: ShortInt;
  prev: Types.PCharRecord;
  p: Types.PCharRecord;
  next: Types.PCharRecord;
  slot: Byte;
  g: Byte;
  d: Byte;
  placedCnt: Byte;
  removedCnt: Byte;
begin
  CharHlp.CountTeams;
  removedCnt := 0;
  placedCnt := 0;
  for slot := 1 to Types.ARENA_SLOTS do
    GDVars.arenaLoc[slot].size := 0;
  CbtMap.BuildArenaArrays;
  placeX[0] := 0;
  placeY[0] := 0;
  teamDir[0] := GDVars.gFacing div 2;
  placeX[1] := GDConsts.dirDX[GDVars.gFacing] * GDVars.zone1^[C_Gbvm.MONSTER_DIST] + placeX[0];
  placeY[1] := GDConsts.dirDY[GDVars.gFacing] * GDVars.zone1^[C_Gbvm.MONSTER_DIST] + placeY[0];
  teamDir[1] := (GDVars.gFacing + 4) mod 8 div 2;
  for team := 0 to 1 do
    teamRows[team] := (teamCount[team] + 1) div 2;
  for team := 0 to 1 do
    for g := 0 to 3 do begin
      if g = 1 then
        d := 4
      else
        d := teamDir[team];
      { y = quad row qy here }
      for y := 0 to 5 do
        { x = quad column qx here }
        for x := 0 to 10 do
          if (GDConsts.rowBand[d, y].lo > x) or (GDConsts.rowBand[d, y].hi < x) then
            quadFree[team, g, y, x] := 0
          else
            quadFree[team, g, y, x] := 1;
    end;
  slot := 1;
  GDVars.arenaCount := 1;
  prev := nil;
  p := GDVars.creatureList;
  { placing stops at the last slot, and the list is cut after the last creature placed }
  while (p <> nil) and (slot <= Types.ARENA_SLOTS) do begin
    GameIo.DiscardPendingKeys;
    { read before a removal frees p }
    next := p^.nextCharAddr;
    GDVars.creatureArr[slot] := p;
    { teamCount, teamRows and the placement tables have teams 0 and 1 }
    team := p^.hostile and 1;
    GDVars.arenaLoc[slot].slotIndex := slot;
    GDVars.arenaLoc[slot].size := p^.iconDimensions and 7;
    if CombatSt.FindPlacement(team, slot) then begin
      prev := p;
      if p^.enabled = 0 then begin
        GDVars.arenaLoc[slot].size := 0;
        if (not GDVars.duelFlag) and (p^.combatAddr^.notPcNpc = 0) then begin
          x := GDVars.arenaLoc[slot].x;
          y := GDVars.arenaLoc[slot].y;
          CbtMap.RegisterDowned(p, x, y);
        end;
      end;
      CbtMap.BuildArenaArrays;
      Inc(slot);
      Inc(GDVars.arenaCount);
      Inc(placedCnt);
    end else begin
      GDVars.arenaLoc[slot].size := 0;
      if p^.combatAddr^.notPcNpc = 1 then begin
        Inc(removedCnt);
        GDVars.creatureArr[slot] := nil;
        GDVars.curChar := p;
        SaveLoad.RemoveCreature(True, False);
      end else begin
        prev := p;
        Inc(slot);
        Inc(GDVars.arenaCount);
      end;
    end;
    p := next;
  end;
  if prev <> nil then
    prev^.nextCharAddr := nil;
end;

{ Prepare combat: release the animation and portrait pictures, clear combat state, build the arena, initialize and place
  creatures, and allocate the moving-icon frames. Centre the view on the first creature, draw the combat interface,
  trigger start-of-combat effects and calculate the hostile hit-point percentage. }
procedure CombatStart;
var
  p: Types.PCharRecord;
begin
  Portrait.FreeAnimation(GDVars.animData);
  Blit.FreePic(GDVars.dsPortraitCache[1].pic);
  Blit.FreePic(GDVars.dsPortraitCache[2].pic);
  GDVars.dsPortraitCache[1].pictureId := 255;
  GDVars.dsPortraitCache[2].pictureId := 255;
  TextRend.ClearBottomLine;
  TextRend.PauseOnly;
  TextRend.DisplayString(0, 24, LightGreen, 'A battle begins...');
  { the battle music runs until the first sound of the fight cuts it }
  SoundDrv.PlayMusic(C_Sound.MUSIC_BATTLE);
  { the Quick Mode Magic setting; Alt-M changes it for this fight only }
  GDVars.quickMagic := GDVars.quickMagicOn <> 0;
  GDVars.roundCounter := 0;
  GDVars.gAttackRoll := 0;
  GDVars.downedCount := 0;
  GDVars.stinkHead := nil;
  GDVars.lastMissileItem := nil;
  FillChar(GDVars.downed, SizeOf(GDVars.downed), 0);
  GDVars.zone1^[C_Gbvm.ATTACKED_ALLIES] := 0;
  if GDVars.zone1^[C_Gbvm.MORALE_THRESHOLD] > 100 then
    GDVars.zone1^[C_Gbvm.MORALE_THRESHOLD] := 100;
  CombatSt.LoadCombatTileSet;
  GameIo.DiscardPendingKeys;
  CombatSt.InitCreatureCombatData;
  GameIo.DiscardPendingKeys;
  CombatSt.PlaceAllCreatures;
  GameIo.DiscardPendingKeys;
  Blit.AllocPic(24, 3, 4, 1, GDVars.dsMoveIconSheet);
  GDVars.arenaPtr^.ox := CbtMap.CombatCellX(GDVars.creatureList) - 3;
  GDVars.arenaPtr^.oy := CbtMap.CombatCellY(GDVars.creatureList) - 3;
  CharDisp.DisplayCombatInterface;
  p := GDVars.creatureList;
  while p <> nil do begin
    FxEngine.TriggerEffectsWithCondition(C_Cond.COMBAT_START, p);
    p := p^.nextCharAddr;
  end;
  CbtActs.CalcHostileHpPercent;
  GDVars.ifcState := C_Ifc.COMBAT;
end;

end.

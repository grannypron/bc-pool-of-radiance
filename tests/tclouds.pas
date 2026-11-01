{ Tests for FxEngine.FreeCloudNumber (#761): each of a caster's stinking clouds gets its own number, the list's last
  node counted too, so ending one cloud clears that cloud and not an older one. And for FxEngine.CloudStrength (#762): a
  caster level above 15 does not carry into the cloud's number. And who a cloud cannot touch (CloudProof) or does
  nothing to now (CloudSpares), which ConsiderStinkingCloud and CombatAi share.

  And the clouds of either size (#1193): their cells (CbtMap.CloudCell), laying one over the arena and another over it
  (CbtMap.SpreadCloud), lifting them (CbtMap.LiftCloud) with a corpse under one, finding one under a large creature
  (CbtMap.ProbeTerrain), and Cloudkill's rules: who it cannot touch (CloudkillProof) and what it does by level
  (CloudkillFate). }
{$I COMPILER.INC}
program TClouds;

uses Types, C_DIR, C_EFFECT, C_SPELL, C_TERR, GameVars, FxEngine, CbtMap, TestKit;

const
  { open ground: terrain 5, cost 1; a wall: terrain 1, cost 255 }
  GROUND = 5;
  WALL = 1;

var
  a: Types.PCharRecord;
  b: Types.PCharRecord;

{ Append a cloud of caster cr numbered idx to the cloudHead list. }
procedure AddCloud(cr: Types.PCharRecord; idx: Byte);
var
  node: Types.PCloudRec;
  tail: Types.PCloudRec;
begin
  GetMem(node, SizeOf(Types.TCloudRec));
  FillChar(node^, SizeOf(Types.TCloudRec), 0);
  node^.caster := cr;
  node^.idx := idx;
  if GameVars.cloudHead = nil then
    GameVars.cloudHead := node
  else begin
    tail := GameVars.cloudHead;
    while tail^.next <> nil do
      tail := tail^.next;
    tail^.next := node;
  end;
end;

procedure FreeClouds;
var
  node: Types.PCloudRec;
begin
  while GameVars.cloudHead <> nil do begin
    node := GameVars.cloudHead^.next;
    FreeMem(GameVars.cloudHead, SizeOf(Types.TCloudRec));
    GameVars.cloudHead := node;
  end;
end;

{ The cell (x, y) of cell i of a cloud of side aimed at (10, 10). }
procedure CheckCell(side, i: Byte; x, y: ShortInt; what: String);
var
  cx: ShortInt;
  cy: ShortInt;
begin
  CbtMap.CloudCell(side, i, 10, 10, cx, cy);
  TestKit.Check((cx = x) and (cy = y), what);
end;

{ A cloud of caster a, side and terrain aimed at (x, y), spread over the arena. }
function Lay(side, terrain: Byte; x, y: ShortInt): Types.PCloudRec;
var
  node: Types.PCloudRec;
  crIdx: Types.TCloudCells;
begin
  node := CbtMap.AppendCloud;
  node^.caster := a;
  node^.side := side;
  node^.terrain := terrain;
  node^.ulX := x;
  node^.ulY := y;
  CbtMap.SpreadCloud(node, crIdx);
  Lay := node;
end;

{ True when every cell of the rectangle (x1, y1)..(x2, y2) holds terrain t. }
function AllAre(x1, y1, x2, y2: ShortInt; t: Byte): Boolean;
var
  x: ShortInt;
  y: ShortInt;
begin
  AllAre := True;
  for y := y1 to y2 do
    for x := x1 to x2 do
      if GameVars.arenaPtr^.cells[y, x] <> t then
        AllAre := False;
end;

{ CloudkillFate for level: fate and save modifier. }
procedure CheckFate(level: ShortInt; fate: Byte; saveMod: ShortInt; what: String);
var
  m: ShortInt;
begin
  TestKit.Check((FxEngine.CloudkillFate(level, m) = fate) and (m = saveMod), what);
end;

{ CloudkillProof for b with effect id alone (0: none). }
procedure CheckKillProof(id: Byte; proof: Boolean; what: String);
var
  e: Types.TEffectRec;
begin
  FillChar(e, SizeOf(e), 0);
  e.id := id;
  if id = 0 then
    b^.effectsAddr := nil
  else
    b^.effectsAddr := @e;
  TestKit.Check(FxEngine.CloudkillProof(b) = proof, what);
  b^.effectsAddr := nil;
end;

{ CloudProof and CloudSpares for b with effect id alone (0: none). }
procedure CheckSpared(id: Byte; proof, spares: Boolean; what: String);
var
  e: Types.TEffectRec;
begin
  FillChar(e, SizeOf(e), 0);
  e.id := id;
  if id = 0 then
    b^.effectsAddr := nil
  else
    b^.effectsAddr := @e;
  TestKit.Check(FxEngine.CloudProof(b) = proof, what + ': proof');
  TestKit.Check(FxEngine.CloudSpares(b) = spares, what + ': spared');
  b^.effectsAddr := nil;
end;

var
  i: Byte;
  stink: Types.PCloudRec;
  kill: Types.PCloudRec;
  crIdx: Byte;
  terrIdx: Byte;

begin
  TestKit.Start('TCLOUDS');
  GetMem(a, SizeOf(Types.TCharRecord));
  GetMem(b, SizeOf(Types.TCharRecord));
  GameVars.cloudHead := nil;
  TestKit.CheckEqualsL(0, FxEngine.FreeCloudNumber(a), 'no clouds: number 0');
  AddCloud(a, 0);
  TestKit.CheckEqualsL(1, FxEngine.FreeCloudNumber(a), 'the caster''s one cloud, the list''s last node, is counted');
  TestKit.CheckEqualsL(0, FxEngine.FreeCloudNumber(b), 'another caster''s cloud is not');
  AddCloud(b, 0);
  AddCloud(a, 1);
  TestKit.CheckEqualsL(2, FxEngine.FreeCloudNumber(a), 'two clouds of the caster: number 2');
  FreeClouds;
  AddCloud(a, 1);
  TestKit.CheckEqualsL(0, FxEngine.FreeCloudNumber(a), 'cloud 0 has ended: its number is free again');
  AddCloud(a, 0);
  TestKit.CheckEqualsL(2, FxEngine.FreeCloudNumber(a), 'numbers 1 and 0 taken, in either order: number 2');
  FreeClouds;
  for i := 0 to 15 do
    AddCloud(a, i);
  TestKit.CheckEqualsL(15, FxEngine.FreeCloudNumber(a), 'never above 15, the most the strength''s high nibble holds');
  FreeClouds;
  TestKit.CheckEqualsL(9 + 2 * 16, FxEngine.CloudStrength(9, 2), 'level 9, cloud 2');
  TestKit.CheckEqualsL(15 + 2 * 16, FxEngine.CloudStrength(15, 2), 'level 15 still fits the low nibble');
  TestKit.CheckEqualsL(2, FxEngine.CloudStrength(16, 2) div 16, 'level 16 leaves the number 2');
  TestKit.CheckEqualsL(15, FxEngine.CloudStrength(20, 0) and $F, 'level 20 is stored as 15');
  TestKit.CheckEqualsL(15 + 15 * 16, FxEngine.CloudStrength(255, 15), 'level 255, cloud 15: no wrap');
  FillChar(b^, SizeOf(Types.TCharRecord), 0);
  b^.enabled := 1;
  CheckSpared(0, False, False, 'a plain creature');
  CheckSpared(C_EFFECT.ANIMATE_DEAD, True, True, 'animated dead');
  CheckSpared(C_EFFECT.STINKING_CLOUD_COUGH, True, True, 'one coughing already');
  CheckSpared(C_EFFECT.NO_PARA_POISON, True, True, 'one immune to paralysis and poison');
  CheckSpared(C_EFFECT.NO_CHARM_POISON, True, True, 'one immune to charm and poison');
  CheckSpared(C_EFFECT.HELPLESS, False, True, 'one nauseated already, who may still walk in');
  b^.enabled := 0;
  CheckSpared(0, False, True, 'a disabled creature');
  b^.enabled := 1;

  { Cloudkill's rules, by the 1st-edition PHB (#1193) }
  CheckKillProof(0, False, 'Cloudkill: a plain creature breathes it');
  CheckKillProof(C_EFFECT.ANIMATE_DEAD, True, 'not the animated dead');
  CheckKillProof(C_EFFECT.NO_PARA_POISON, True, 'nor one immune to paralysis and poison');
  CheckKillProof(C_EFFECT.NO_CHARM_POISON, True, 'nor one immune to charm and poison');
  CheckKillProof(C_EFFECT.STINKING_CLOUD_COUGH, False, 'coughing keeps no Cloudkill off');
  CheckFate(0, C_SPELL.CLOUDKILL_KILLS, 0, 'level 0 dies');
  CheckFate(-1, C_SPELL.CLOUDKILL_KILLS, 0, 'so does a level below it');
  CheckFate(4, C_SPELL.CLOUDKILL_KILLS, 0, 'level 4 dies');
  CheckFate(5, C_SPELL.CLOUDKILL_SAVE, -4, 'level 5 saves at -4');
  CheckFate(6, C_SPELL.CLOUDKILL_SAVE, 0, 'level 6 saves at 0');
  CheckFate(7, C_SPELL.CLOUDKILL_HURTS, 0, 'level 7 is hurt');
  CheckFate(12, C_SPELL.CLOUDKILL_HURTS, 0, 'level 12 too');

  { the clouds' cells }
  CheckCell(C_SPELL.STINKING_CLOUD_SIDE, 1, 10, 10, 'Stinking Cloud: the aim cell first');
  CheckCell(C_SPELL.STINKING_CLOUD_SIDE, 2, 11, 10, 'then east');
  CheckCell(C_SPELL.STINKING_CLOUD_SIDE, 3, 11, 11, 'southeast');
  CheckCell(C_SPELL.STINKING_CLOUD_SIDE, 4, 10, 11, 'and south');
  CheckCell(C_SPELL.CLOUDKILL_SIDE, 1, 10, 10, 'Cloudkill: the aim cell first');
  CheckCell(C_SPELL.CLOUDKILL_SIDE, 2, 10, 9, 'then north');
  CheckCell(C_SPELL.CLOUDKILL_SIDE, 5, 11, 11, 'southeast');
  CheckCell(C_SPELL.CLOUDKILL_SIDE, 9, 9, 9, 'and northwest last');
  TestKit.CheckEqualsL(C_TERR.CLOUDKILL, CbtMap.CloudTerrain(C_SPELL.CLOUDKILL), 'Cloudkill lays its own terrain');
  TestKit.CheckEqualsL(C_TERR.STINKING_CLOUD, CbtMap.CloudTerrain(C_SPELL.STINKING_CLOUD), 'Stinking Cloud its own');

  { laying and lifting: a Stinking Cloud at (10, 10) with a wall on its east cell, then a Cloudkill round (11, 11)
    over it }
  GetMem(GameVars.arenaPtr, SizeOf(Types.TArena));
  FillChar(GameVars.arenaPtr^, SizeOf(Types.TArena), 0);
  FillChar(GameVars.arenaPtr^.cells, SizeOf(GameVars.arenaPtr^.cells), GROUND);
  FillChar(GameVars.arenaLoc, SizeOf(GameVars.arenaLoc), 0);
  GameVars.arenaCount := 0;
  GameVars.downedCount := 0;
  CbtMap.BuildArenaArrays;
  GameVars.cloudHead := nil;
  GameVars.arenaPtr^.cells[10, 11] := WALL;
  stink := Lay(C_SPELL.STINKING_CLOUD_SIDE, C_TERR.STINKING_CLOUD, 10, 10);
  TestKit.Check((GameVars.arenaPtr^.cells[10, 10] = C_TERR.STINKING_CLOUD) and
                AllAre(10, 11, 11, 11, C_TERR.STINKING_CLOUD), 'the stinking cloud fills its passable cells');
  TestKit.Check((GameVars.arenaPtr^.cells[10, 11] = WALL) and (stink^.exists[2] = 0), 'but not the wall');
  TestKit.Check((stink^.under[1] = GROUND) and (GameVars.arenaPtr^.cells[9, 9] = GROUND), 'and keeps the ground');
  GameVars.arenaPtr^.cells[10, 12] := C_TERR.CORPSE;
  GameVars.downedCount := 1;
  GameVars.downed[1].cr := b;
  GameVars.downed[1].x := 12;
  GameVars.downed[1].y := 10;
  GameVars.downed[1].terrain := GROUND;
  kill := Lay(C_SPELL.CLOUDKILL_SIDE, C_TERR.CLOUDKILL, 11, 11);
  TestKit.Check(AllAre(10, 11, 12, 12, C_TERR.CLOUDKILL) and (GameVars.arenaPtr^.cells[10, 10] = C_TERR.CLOUDKILL) and
                (GameVars.arenaPtr^.cells[10, 12] = C_TERR.CLOUDKILL), 'the Cloudkill fills its 3x3 block');
  TestKit.Check((GameVars.arenaPtr^.cells[10, 11] = WALL) and AllAre(13, 10, 13, 12, GROUND), 'and no more');
  TestKit.Check((kill^.under[1] = GROUND) and (kill^.under[9] = GROUND) and (kill^.under[3] = GROUND),
                'over the stinking cloud and the corpse it keeps the ground beneath them');
  TestKit.CheckEqualsL(1, FxEngine.FreeCloudNumber(a), 'its caster''s next number counts both kinds');

  { a large creature with a stinking cloud and a Cloudkill under it: ProbeDirection names the stinking cloud,
    ProbeTerrain finds both }
  GameVars.arenaCount := 1;
  GameVars.creatureArr[1] := b;
  GameVars.arenaLoc[1].x := 9;
  GameVars.arenaLoc[1].y := 9;
  GameVars.arenaLoc[1].size := 4;
  CbtMap.BuildArenaArrays;
  CbtMap.ProbeDirection(b, C_DIR.CENTER, crIdx, terrIdx);
  TestKit.CheckEqualsL(C_TERR.CLOUDKILL, terrIdx, 'a 2x2 body whose one cloud cell is a Cloudkill''s');
  TestKit.Check(CbtMap.ProbeTerrain(b, C_DIR.CENTER, C_TERR.CLOUDKILL), 'which ProbeTerrain finds');
  TestKit.Check(not CbtMap.ProbeTerrain(b, C_DIR.CENTER, C_TERR.STINKING_CLOUD), 'and no stinking cloud');
  GameVars.arenaPtr^.cells[9, 9] := C_TERR.STINKING_CLOUD;
  CbtMap.ProbeDirection(b, C_DIR.CENTER, crIdx, terrIdx);
  TestKit.CheckEqualsL(C_TERR.STINKING_CLOUD, terrIdx, 'with a stinking cloud cell too, ProbeDirection names it');
  TestKit.Check(CbtMap.ProbeTerrain(b, C_DIR.CENTER, C_TERR.CLOUDKILL), 'and ProbeTerrain still finds the Cloudkill');
  TestKit.Check(not CbtMap.ProbeTerrain(b, C_DIR.WEST, C_TERR.CLOUDKILL), 'but none a step west');
  GameVars.arenaPtr^.cells[9, 9] := GROUND;
  GameVars.arenaCount := 0;
  CbtMap.BuildArenaArrays;

  CbtMap.LiftCloud(kill);
  TestKit.Check((GameVars.arenaPtr^.cells[10, 10] = C_TERR.STINKING_CLOUD) and
                AllAre(10, 11, 11, 11, C_TERR.STINKING_CLOUD), 'lifting the Cloudkill leaves the stinking cloud');
  TestKit.Check((GameVars.arenaPtr^.cells[10, 12] = C_TERR.CORPSE) and AllAre(12, 11, 12, 12, GROUND) and
                (GameVars.arenaPtr^.cells[12, 10] = GROUND), 'the corpse and the ground back');
  TestKit.Check((GameVars.cloudHead = stink) and (stink^.next = nil), 'and the stinking cloud alone on the list');
  CbtMap.LiftCloud(stink);
  TestKit.Check(AllAre(10, 11, 11, 11, GROUND) and (GameVars.arenaPtr^.cells[10, 10] = GROUND) and
                (GameVars.arenaPtr^.cells[10, 11] = WALL),
                'lifting the stinking cloud leaves the ground and the wall');
  TestKit.Check(GameVars.cloudHead = nil, 'and the list empty');
  GameVars.downedCount := 0;
  FreeMem(GameVars.arenaPtr, SizeOf(Types.TArena));
  GameVars.arenaPtr := nil;
  FreeMem(a, SizeOf(Types.TCharRecord));
  FreeMem(b, SizeOf(Types.TCharRecord));
  TestKit.Done;
end.

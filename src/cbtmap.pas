{ Combat map display: a 7x7 viewport over the 50x25 arena, with creature icons, scrolling, a movement cursor and corpse
  tracking. }
{$O+,F+}
{$I COMPILER.INC}
unit CbtMap;

interface

uses Types;

var
  { A bolt or cone spell's cells for the spell-aim preview; GameInit sets it to Magic.TraceBolt, so CbtMap does not
    call Magic }
  boltTracer: Types.TCellTracer;
  { Who the spell being aimed will catch, for the spell-aim preview's count on line 23 (#840); GameInit sets it to
    CbtActs.ReportAreaCatch, so CbtMap does not call CbtActs }
  aimReport: Types.TAimReport;
  { view-relative X deltas }
  gridX: array[1..Types.ARENA_SLOTS] of ShortInt;
  { view-relative Y deltas }
  gridY: array[1..Types.ARENA_SLOTS] of ShortInt;

{ Where the mode has a palette (EGA), swap palette registers 0 and 8 so the combat map background is dark gray and
  register 8 black. }
procedure SetCombatPalette;

{ Where the mode has a palette (EGA), restore palette register 0 to black and register 8 to dark gray. }
procedure SetNoncombatPalette;

{ Redraw one arena cell from scratch: repaint its terrain (the whole icon footprint when a creature stands there, via
  UpdateCombatMapTile), then the creature sprite if it is visible. (x, y) are arena coordinates. Combat.CreatureAction
  calls it after each creature's action to erase the turn cursor. }
procedure RedrawArenaCell(x, y: ShortInt);

{ Rebuild the arena's creature-index grid and each creature's cached view coordinates. }
procedure BuildArenaArrays;

{ Return the creature and terrain indices at an arena cell. Both are zero outside the arena. }
procedure GetArenaContents(x, y: ShortInt; var crIdx, terrIdx: Byte);

{ The creature on arena cell (x, y), its arena slot, or 0 for none or off the arena: Pathing.RouteStep's occupant. }
function OccupantAt(x, y: ShortInt): Byte;

{ Repaint the terrain under every visible tile of a creature's icon (erasing its sprite), or under the single view cell
  (x, y) when no creature is there. (x, y) are view coordinates; when crIdx is zero the creature is first looked up at
  that cell, and for a creature redraw (x, y) are replaced by the creature's own view coordinates. }
procedure UpdateCombatMapTile(x, y: ShortInt; crIdx: Byte);

{ Return True when both coordinates lie inside the 7x7 viewport. }
function ViewCoordsValid(x, y: ShortInt): Boolean;

{ Test whether a creature's icon is visible. A nonzero whole requires every tile to be in view; zero requires only one
  tile. }
function CombatIconVisible(creature: Types.PCharRecord; whole: Byte): Boolean;

{ Target the arena cell one step in dir from (x, y) (dir 8 = the cell itself) and rebuild the view if the target lies
  more than delta cells from the view center (delta=3: anywhere off the 7x7 view; 255: always rebuild), redrawing every
  visible icon after a rebuild. Then redraw cell (x, y), draw the cursor at the target (clamped to the arena) and
  flush. }
procedure ScrollView(x, y: ShortInt; delta, dir: Byte);

{ Turn a creature: scroll it into view unless it is wholly visible, repaint its terrain when the facing crosses the
  mirror boundary (div 4), frame <> 0 or eraseOnly <> 0, store the new facing and, unless eraseOnly, draw its sprite and
  flush when it is wholly visible. }
procedure SetCreatureFacing(creature: Types.PCharRecord; dir, frame, eraseOnly: Byte);

{ Return the creature's arena X coordinate. }
function CombatCellX(creature: Types.PCharRecord): ShortInt;

{ Return the creature's arena Y coordinate. }
function CombatCellY(creature: Types.PCharRecord): ShortInt;

{ Return the creature's icon size (0 = not on the map). }
function GetIconSize(creature: Types.PCharRecord): Byte;

{ Return the creature's slot in the combat arrays (creatureArr, arenaLoc), or 0 when it is not among them. }
function CombatSlot(creature: Types.PCharRecord): Byte;

{ Probe the cells one step in dir from each of the creature's icon tiles. crIdx returns an adjacent creature (0 = none;
  the creature itself is ignored and the last one found wins). terrIdx returns the dominant terrain: 0 (off the arena)
  beats everything, then C_TERR.STINKING_CLOUD, otherwise the highest cost wins (the later tile on a tie). The preset
  pair is terrIdx 23 / best 1: terrainInfo[23] is a cost-1 passable entry, so any real terrain of cost >= 1 replaces it.
  Combat.MoveMenu uses it for bump attacks and terrain cost; IsValidCreatureLoc probes dir 8, the creature's own
  cells. }
procedure ProbeDirection(creature: Types.PCharRecord; dir: Byte; var crIdx, terrIdx: Byte);

{ Record a downed party member's corpse at (x, y): the cell's terrain is kept and the cell becomes C_TERR.CORPSE (a
  stinking cloud is left as it is). A creature already in GameVars.downed is not added again, and a slot cleared when
  its creature got up is reused, so the eight slots are never overrun; with all eight in use the corpse is not
  recorded. }
procedure RegisterDowned(creature: Types.PCharRecord; x, y: Byte);

{ Outside combat, play the downed sound and pause. In combat, flash the skull sprite over the creature, register a
  corpse (party side, notPcNpc = 0, only) and remove it from the arena. Rebuild the view and clear initiative, movement,
  casting and guarding state. }
procedure CreatureDowned(creature: Types.PCharRecord);

{ Try to place the creature at the requested arena cell; always True outside combat. A rejected placement removes its
  icon (size 0). On a successful move, clear its corpse entries and restore the terrain they covered. }
function IsValidCreatureLoc(creature: Types.PCharRecord; x, y: Byte; moving: Boolean): Boolean;

{ Scroll the view to the creature (ScrollView with delta, dir 8), drawing the cursor over its icon footprint when cursor
  is set; afterwards the cursor is reset to off with size 1. }
procedure DisplayMapViewCentered(creature: Types.PCharRecord; delta: Byte; cursor: Boolean);

{ Spell-aim preview, for the player aiming a spell. Each time the cursor is drawn the preview restarts there: the cells
  the spell will reach light up ring by ring outward from the cursor cell in combat sprite areaCell, hold, clear, and
  the cycle repeats. AimBlast reaches every cell within radius of the cursor cell by the Pathing.WalkLine test
  Pathing.BuildTargetList applies, so walls cut it the same way; radius 0 is the cursor cell alone. AimBolt follows
  spell's bolt (Lightning Bolt's, or the Javelin of Lightning's) from the cursor cell, or covers its cone from the
  caster toward the cursor cell (Fear, Cone of Cold), as boltTracer gives them. AimCloud covers the
  passable cells of Magic.SpellStinkingCloud's 2x2 block and draws them with the stinking-cloud terrain tile instead
  of areaCell. The frames are drawn from MenuCore.MenuHorizontal's idle hook. With report set, each restart also hands
  aimReport the creatures the spell will catch there (#840): for a blast everyone Pathing.BuildAreaList gathers at
  radius, over the whole arena and not just the view, as the spell gathers them; for a bolt or cloud the creatures on
  its cells. }
procedure StartSpellPreview(shape: Types.TAimShape; spell, radius, areaCell: Byte; report: Boolean);

{ Advance the spell-aim preview by one frame once enough time has passed since the last one. }
procedure TickSpellPreview;

{ End the spell-aim preview: remove the idle hook, repaint every cell it drew over and, when it reported who the spell
  catches, clear line 23. }
procedure StopSpellPreview;

{ Build the potential-target list around creature within range, keep only creatures on the opposing team, and copy their
  indices into GameVars.combatTargetSlots. Return the remaining count. }
function CountTargets(creature: Types.PCharRecord; range: Byte): Byte;

{ Find the distance to another creature by temporarily rebuilding the target list with terrain ignored (distMode 1).
  Restore the previous list afterward. Stored distances are doubled, so halve the result; 255 when other is not in the
  list (nil, or off the map). The list's count is restored with it (SSI left the rebuilt list's count). }
function CalcDistance(creature, other: Types.PCharRecord): Byte;

implementation

uses Crt, C_TERR, GameDefs, GameVars, MapTiles, TextRend, SoundDrv, C_IFC, C_DIR, C_SOUND, Pathing, MenuCore,
  Blit, CharHlp, Border;

var
  { creature slot per arena cell }
  crIdxArr: array[0..Types.ARENA_LAST_Y, 0..Types.ARENA_LAST_X] of Byte;

const
  { The cursor sprite cell in GameVars.iconAnimation ([24, 0] is the COMSPR 11 skull) }
  CURSOR_CELL = 25;
  { Hundredths of a second between preview frames }
  PREVIEW_PACE = 12;
  { Frames the whole area stays lit, then blank frames before the next cycle }
  PREVIEW_HOLD = 3;
  PREVIEW_GAP = 2;
  { The most area cells the preview lights }
  AREA_CELLS = 64;

var
  { Spell-aim preview settings (StartSpellPreview). }
  previewOn: Boolean;
  previewRadius: Byte;
  previewShape: Types.TAimShape;
  previewSpell: Byte;
  areaArt: Byte;
  previewReport: Boolean;
  { The cursor cell and footprint size the preview is aimed at; aimSet is clear until a cursor draw sets them. }
  aimSet: Boolean;
  aimX: ShortInt;
  aimY: ShortInt;
  aimSize: Byte;
  { The cells the spell reaches and the ring (frame of the cycle) each lights up on. }
  areaCount: Byte;
  areaX: array[1..AREA_CELLS] of ShortInt;
  areaY: array[1..AREA_CELLS] of ShortInt;
  areaRing: array[1..AREA_CELLS] of Byte;
  ringCount: Byte;
  { How many rings are lit now. }
  ringsShown: Byte;
  { Frame within the cycle and the tick count when it was drawn. }
  frameNo: Byte;
  lastTick: LongInt;

{ True when arena cell (x, y) is under the preview's cursor footprint. }
function InAimFootprint(x, y: ShortInt): Boolean;
var
  i: Byte;
  tdx: ShortInt;
  tdy: ShortInt;
begin
  InAimFootprint := False;
  if aimSet then
    for i := 0 to 3 do
      if Pathing.GetIconTileDelta(aimSize, i, tdx, tdy) then
        if (aimX + tdx = x) and (aimY + tdy = y) then
          InAimFootprint := True;
end;

{ Redraw the creature standing on arena cell (x, y), when its icon is visible. }
procedure DrawCellCreature(x, y: ShortInt);
var
  c: Byte;
  t: Byte;
begin
  CbtMap.GetArenaContents(x, y, c, t);
  if c > 0 then
    if CbtMap.CombatIconVisible(GameVars.creatureArr[c], 0) then
      MapTiles.DrawIconAnimSprite(gridX[c], gridY[c], GameVars.creatureArr[c]^.combatAddr^.direction,
                                  0, GameVars.creatureArr[c]^.orderNumber);
end;

{ Put back what belongs on top of a view cell after its terrain was drawn: the cursor box when the cell is under the aim
  footprint, then the creature standing on the cell. relX, relY are the cell's view coordinates. }
procedure DrawCellTop(x, y, relX, relY: ShortInt);
begin
  if InAimFootprint(x, y) then
    MapTiles.DrawIconAnimSprite(relX, relY, 0, 0, CURSOR_CELL);
  DrawCellCreature(x, y);
end;

{ Repaint arena cell (x, y), when it is in view, as it is without the preview. }
procedure RepaintCell(x, y: ShortInt);
var
  relX: ShortInt;
  relY: ShortInt;
begin
  relX := x - GameVars.arenaPtr^.ox;
  relY := y - GameVars.arenaPtr^.oy;
  if CbtMap.ViewCoordsValid(relX, relY) then begin
    MapTiles.Copy2DTile(relX * 3, relY * 3, GameDefs.terrainInfo[GameVars.arenaPtr^.cells[y, x]].tileId);
    DrawCellTop(x, y, relX, relY);
  end;
end;

{ Draw frame half of combat sprite art over arena cell (x, y), when it is in view; a facing of 4 or more mirrors it. The
  creature on the cell is put back over the art, but the cursor box is not: under the aim footprint the cell already
  shows the cursor box (DrawCursorCell, RepaintCell), so the art lies on top of it. }
procedure DrawPreviewArt(x, y: ShortInt; art, facing, half: Byte);
var
  relX: ShortInt;
  relY: ShortInt;
begin
  relX := x - GameVars.arenaPtr^.ox;
  relY := y - GameVars.arenaPtr^.oy;
  if CbtMap.ViewCoordsValid(relX, relY) then begin
    MapTiles.DrawIconAnimSprite(relX, relY, facing, half, art);
    DrawCellCreature(x, y);
  end;
end;

{ Light area cell i in frame half of the area art, or, for Stinking Cloud, as the cloud terrain it will become. }
procedure DrawAreaCell(i, half: Byte);
var
  relX: ShortInt;
  relY: ShortInt;
begin
  if previewShape = Types.AimCloud then begin
    relX := areaX[i] - GameVars.arenaPtr^.ox;
    relY := areaY[i] - GameVars.arenaPtr^.oy;
    if CbtMap.ViewCoordsValid(relX, relY) then begin
      MapTiles.Copy2DTile(relX * 3, relY * 3, GameDefs.terrainInfo[C_TERR.STINKING_CLOUD].tileId);
      DrawCellTop(areaX[i], areaY[i], relX, relY);
    end;
  end else
    DrawPreviewArt(areaX[i], areaY[i], areaArt, 0, half);
end;

{ Repaint every lit area cell, leaving nothing of the preview on screen. }
procedure EraseSpellPreview;
var
  i: Byte;
begin
  for i := 1 to areaCount do
    if areaRing[i] < ringsShown then
      RepaintCell(areaX[i], areaY[i]);
  ringsShown := 0;
end;

{ Add an area cell lighting up on the given ring; cells past the table's end are dropped. }
procedure AddAreaCell(x, y: ShortInt; ring: Byte);
begin
  if areaCount < AREA_CELLS then begin
    Inc(areaCount);
    areaX[areaCount] := x;
    areaY[areaCount] := y;
    areaRing[areaCount] := ring;
    if ring >= ringCount then
      ringCount := ring + 1;
  end;
end;

{ Add arena slot c to list, unless it is there already. }
procedure AddCaught(var list: Types.TSlotList; c: Byte);
var
  i: Byte;
begin
  for i := 1 to list.count do
    if list.slot[i] = c then
      Exit;
  if list.count < Types.ARENA_SLOTS then begin
    Inc(list.count);
    list.slot[list.count] := c;
  end;
end;

{ Hand aimReport the creatures the spell aimed at arena cell (x, y) will catch, nearest first. A blast gathers them with
  Pathing.BuildAreaList, as the spell does, over the whole arena (the lit cells cover only the view), and puts the
  target list back as it was, as CalcDistance does; a bolt or cloud takes the creatures on its area cells, each once. }
procedure ReportCaught(x, y: ShortInt);
var
  caught: Types.TSlotList;
  saved: Types.TTargetSnapshot;
  i: Byte;
  c: Byte;
  t: Byte;
begin
  caught.count := 0;
  if previewShape = Types.AimBlast then begin
    Pathing.SaveTargets(saved);
    Pathing.BuildAreaList(x, y, previewRadius);
    for i := 1 to GameVars.targetCount do
      AddCaught(caught, GameVars.targetList[i].idx);
    Pathing.RestoreTargets(saved);
  end else
    for i := 1 to areaCount do begin
      CbtMap.GetArenaContents(areaX[i], areaY[i], c, t);
      if c > 0 then
        AddCaught(caught, c);
    end;
  CbtMap.aimReport(caught);
end;

{ Aim the preview at arena cell (x, y): work out the area, report who it catches when asked to, and start the cycle
  over. }
procedure RestartSpellPreview(x, y: ShortInt);
var
  bolt: Types.TCellList;
  relX: ShortInt;
  relY: ShortInt;
  tx: ShortInt;
  ty: ShortInt;
  dist: Word;
  i: Byte;
  c: Byte;
  t: Byte;
begin
  aimSet := True;
  aimX := x;
  aimY := y;
  aimSize := GameVars.arenaPtr^.cursorSize;
  areaCount := 0;
  ringCount := 0;
  case previewShape of
    Types.AimBolt: begin
        AddAreaCell(x, y, 0);
        CbtMap.boltTracer(previewSpell, x, y, bolt);
        { two cells a frame }
        for i := 1 to bolt.count do
          AddAreaCell(bolt.x[i], bolt.y[i], (i + 1) div 2);
      end;
    Types.AimCloud:
      for i := 1 to 4 do begin
        tx := x + GameDefs.dirDX[GameDefs.cloudDir[i]];
        ty := y + GameDefs.dirDY[GameDefs.cloudDir[i]];
        CbtMap.GetArenaContents(tx, ty, c, t);
        { the aim cell first, then the other three }
        if t > 0 then
          if GameDefs.terrainInfo[t].cost < 255 then
            AddAreaCell(tx, ty, Ord(i > 1));
      end;
  else
    for relY := 0 to 6 do
      for relX := 0 to 6 do begin
        tx := GameVars.arenaPtr^.ox + relX;
        ty := GameVars.arenaPtr^.oy + relY;
        dist := previewRadius;
        { on success dist returns the doubled distance, so dist div 2 is the ring }
        if Pathing.WalkLine(x, y, tx, ty, dist, GameVars.arenaPtr) then
          AddAreaCell(GameVars.arenaPtr^.ox + relX, GameVars.arenaPtr^.oy + relY, dist div 2);
      end;
  end;
  if previewReport then
    ReportCaught(x, y);
  frameNo := 0;
  lastTick := TextRend.GetTicks - PREVIEW_PACE;
end;

procedure StartSpellPreview(shape: Types.TAimShape; spell, radius, areaCell: Byte; report: Boolean);
begin
  CbtMap.StopSpellPreview;
  previewShape := shape;
  previewSpell := spell;
  previewRadius := radius;
  areaArt := areaCell;
  previewReport := report;
  aimSet := False;
  ringsShown := 0;
  areaCount := 0;
  previewOn := True;
  MenuCore.idleHook := CbtMap.TickSpellPreview;
end;

procedure TickSpellPreview;
var
  now: LongInt;
  ring: Byte;
  i: Byte;
begin
  if not (previewOn and aimSet) then Exit;
  now := TextRend.GetTicks;
  { the tick count restarts at midnight }
  if (now >= lastTick) and (now - lastTick < PREVIEW_PACE) then Exit;
  lastTick := now;
  ring := frameNo;
  if ring <= ringCount then begin
    { the newest ring shows the sprite's first frame; the ring before it settles into the second }
    for i := 1 to areaCount do
      if areaRing[i] + 1 = ring then begin
        RepaintCell(areaX[i], areaY[i]);
        DrawAreaCell(i, 1);
      end else if areaRing[i] = ring then
        DrawAreaCell(i, 0);
    if ring < ringCount then
      ringsShown := ring + 1;
  end else if ring = ringCount + PREVIEW_HOLD then
    EraseSpellPreview
  else if ring >= ringCount + PREVIEW_HOLD + PREVIEW_GAP then begin
    frameNo := 0;
    Exit;
  end;
  Inc(frameNo);
  Blit.FlushView;
end;

procedure StopSpellPreview;
begin
  if previewOn then begin
    @MenuCore.idleHook := nil;
    aimSet := False;
    EraseSpellPreview;
    Blit.FlushView;
    if previewReport then
      Border.ClearBox(0, 23, 39, 23);
    previewReport := False;
    previewOn := False;
  end;
end;

{ Recompute every creature's view coordinates from its arena location and the view origin. }
procedure CalcGridDeltas;
var
  i: Byte;
begin
  for i := 1 to Pathing.LastSlot do begin
    gridX[i] := GameVars.arenaLoc[i].x - GameVars.arenaPtr^.ox;
    gridY[i] := GameVars.arenaLoc[i].y - GameVars.arenaPtr^.oy;
  end;
end;

procedure SetCombatPalette;
begin
  Blit.SetPaletteRegister(0, DarkGray);
  Blit.SetPaletteRegister(8, Black);
end;

procedure SetNoncombatPalette;
begin
  Blit.SetPaletteRegister(0, Black);
  Blit.SetPaletteRegister(8, DarkGray);
end;

{ Repaint the terrain under the cursor footprint at arena cell (x, y), draw the cursor there when it is enabled, then
  redraw the creature standing on (x, y) itself if it is visible. }
procedure DrawCursorCell(x, y: ShortInt);
var
  relX: ShortInt;
  relY: ShortInt;
  tdx: ShortInt;
  tdy: ShortInt;
  i: Byte;
begin
  { the cursor is moving: take the preview down, without redrawing the cursor where it was }
  if previewOn then begin
    aimSet := False;
    EraseSpellPreview;
  end;
  relX := x - GameVars.arenaPtr^.ox;
  relY := y - GameVars.arenaPtr^.oy;
  for i := 0 to 3 do begin
    if Pathing.GetIconTileDelta(GameVars.arenaPtr^.cursorSize, i, tdx, tdy) then
      if CbtMap.ViewCoordsValid(relX + tdx, relY + tdy) then begin
        MapTiles.Copy2DTile((relX + tdx) * 3, (relY + tdy) * 3,
                            GameDefs.terrainInfo[GameVars.arenaPtr^.cells[y + tdy, x + tdx]].tileId);
        if GameVars.arenaPtr^.cursorOn then
          MapTiles.DrawIconAnimSprite(relX + tdx, relY + tdy, 0, 0, CURSOR_CELL);
      end;
  end;
  DrawCellCreature(x, y);
  if previewOn and GameVars.arenaPtr^.cursorOn then
    RestartSpellPreview(x, y);
end;

procedure RedrawArenaCell(x, y: ShortInt);
var
  relX: ShortInt;
  relY: ShortInt;
begin
  relX := x - GameVars.arenaPtr^.ox;
  relY := y - GameVars.arenaPtr^.oy;
  CbtMap.UpdateCombatMapTile(relX, relY, 0);
  DrawCellCreature(x, y);
end;

procedure BuildArenaArrays;
var
  i: Byte;
  j: Byte;
  tdx: ShortInt;
  tdy: ShortInt;
begin
  FillChar(crIdxArr, SizeOf(crIdxArr), 0);
  for i := 1 to Pathing.LastSlot do
    if GameVars.arenaLoc[i].size > 0 then
      for j := 0 to 3 do
        if Pathing.GetIconTileDelta(GameVars.arenaLoc[i].size, j, tdx, tdy) then
          crIdxArr[GameVars.arenaLoc[i].y + tdy, GameVars.arenaLoc[i].x + tdx] := i;
  CbtMap.CalcGridDeltas;
end;

procedure GetArenaContents(x, y: ShortInt; var crIdx, terrIdx: Byte);
begin
  if Pathing.OnArena(x, y) then begin
    terrIdx := GameVars.arenaPtr^.cells[y, x];
    crIdx := crIdxArr[y, x];
  end else begin
    crIdx := 0;
    terrIdx := 0;
  end;
end;

function OccupantAt(x, y: ShortInt): Byte;
var
  c: Byte;
  t: Byte;
begin
  CbtMap.GetArenaContents(x, y, c, t);
  OccupantAt := c;
end;

procedure UpdateCombatMapTile(x, y: ShortInt; crIdx: Byte);
var
  absX: ShortInt;
  absY: ShortInt;
  tdx: ShortInt;
  tdy: ShortInt;
  i: Byte;
  t: Byte;
  size: Byte;
begin
  if crIdx = 0 then begin
    absX := x + GameVars.arenaPtr^.ox;
    absY := y + GameVars.arenaPtr^.oy;
    CbtMap.GetArenaContents(absX, absY, crIdx, t);
  end;
  if crIdx > 0 then begin
    x := gridX[crIdx];
    y := gridY[crIdx];
    absX := x + GameVars.arenaPtr^.ox;
    absY := y + GameVars.arenaPtr^.oy;
    size := GameVars.arenaLoc[crIdx].size;
    for i := 0 to 3 do
      if Pathing.GetIconTileDelta(size, i, tdx, tdy) then
        if CbtMap.ViewCoordsValid(x + tdx, y + tdy) then
          MapTiles.Copy2DTile((x + tdx) * 3, (y + tdy) * 3,
                              GameDefs.terrainInfo[GameVars.arenaPtr^.cells[absY + tdy, absX + tdx]].tileId);
  end else if CbtMap.ViewCoordsValid(x, y) then
    MapTiles.Copy2DTile(x * 3, y * 3, GameDefs.terrainInfo[GameVars.arenaPtr^.cells[absY, absX]].tileId);
end;

function ViewCoordsValid(x, y: ShortInt): Boolean;
begin
  if (x < 0) or (x > 6) or (y < 0) or (y > 6) then
    ViewCoordsValid := False
  else
    ViewCoordsValid := True;
end;

function CombatIconVisible(creature: Types.PCharRecord; whole: Byte): Boolean;
var
  i: Byte;
  slot: Byte;
  tdx: ShortInt;
  tdy: ShortInt;
begin
  CombatIconVisible := True;
  slot := CbtMap.CombatSlot(creature);
  { slot 0: not on the map }
  if (slot = 0) or (GameVars.arenaLoc[slot].size = 0) then
    CombatIconVisible := False
  else
    for i := 0 to 3 do begin
      if Pathing.GetIconTileDelta(GameVars.arenaLoc[slot].size, i, tdx, tdy) then
        if not CbtMap.ViewCoordsValid(gridX[slot] + tdx, gridY[slot] + tdy) then begin
          CombatIconVisible := False;
          if whole <> 0 then Exit;
        end else begin
          CombatIconVisible := True;
          if whole = 0 then Exit;
        end;
    end;
end;

{ Rebuild the viewport when the requested position falls outside its center band (delta cells either side of the view
  center); return True when it rebuilds. delta=255 forces a rebuild. Move the center toward the position, clamped so the
  full 7x7 view stays inside the arena, then repaint every tile into the buffer. }
function BuildViewBuffer(x, y: ShortInt; delta: Byte): Boolean;
var
  d: Byte;
  pixX: ShortInt;
  pixY: ShortInt;
  i: Byte;
  j: Byte;
  cX: ShortInt;
  cY: ShortInt;
  minX: ShortInt;
  maxX: ShortInt;
  minY: ShortInt;
  maxY: ShortInt;
begin
  BuildViewBuffer := False;
  cX := GameVars.arenaPtr^.ox + 3;
  cY := GameVars.arenaPtr^.oy + 3;
  d := delta;
  if delta = 255 then
    d := 0;
  minX := cX - d;
  maxX := cX + d;
  minY := cY - d;
  maxY := cY + d;
  if (delta <> 255) and (x >= minX) and (x <= maxX)
     and (y >= minY) and (y <= maxY) then Exit;
  if x < minX then
    while (x < cX) and (cX > 3) do Dec(cX)
  else if x > maxX then
    while (x > cX) and (cX < Types.ARENA_LAST_X - 3) do Inc(cX);
  if y < minY then
    while (y < cY) and (cY > 3) do Dec(cY)
  else if y > maxY then
    while (y > cY) and (cY < Types.ARENA_LAST_Y - 3) do Inc(cY);
  GameVars.arenaPtr^.ox := cX - 3;
  GameVars.arenaPtr^.oy := cY - 3;
  pixY := 0;
  cY := GameVars.arenaPtr^.oy;
  for j := 0 to 6 do begin
    pixX := 0;
    cX := GameVars.arenaPtr^.ox;
    for i := 0 to 6 do begin
      MapTiles.Copy2DTile(pixX, pixY, GameDefs.terrainInfo[GameVars.arenaPtr^.cells[cY, cX]].tileId);
      Inc(pixX, 3);
      Inc(cX);
    end;
    Inc(pixY, 3);
    Inc(cY);
  end;
  CbtMap.CalcGridDeltas;
  BuildViewBuffer := True;
end;

procedure ScrollView(x, y: ShortInt; delta, dir: Byte);
var
  p: Types.PCharRecord;
  i: Byte;
  tx: ShortInt;
  ty: ShortInt;
begin
  tx := x + GameDefs.dirDX[dir];
  ty := y + GameDefs.dirDY[dir];
  if CbtMap.BuildViewBuffer(tx, ty, delta) then begin
    for i := 1 to Pathing.LastSlot do begin
      p := GameVars.creatureArr[i];
      { arenaCount's own slot is past the last creature placed, and nil in a session's first fight: size first }
      if (GameVars.arenaLoc[i].size > 0) and (p <> nil) then
        if (p^.enabled <> 0) and CbtMap.CombatIconVisible(p, 0) then
          MapTiles.DrawIconAnimSprite(gridX[i], gridY[i], p^.combatAddr^.direction, 0, p^.orderNumber);
    end;
  end;
  CbtMap.RedrawArenaCell(x, y);
  if not CbtMap.ViewCoordsValid(tx - GameVars.arenaPtr^.ox, ty - GameVars.arenaPtr^.oy) then begin
    if tx > Types.ARENA_LAST_X then tx := Types.ARENA_LAST_X;
    if tx < 0 then tx := 0;
    if ty > Types.ARENA_LAST_Y then ty := Types.ARENA_LAST_Y;
    if ty < 0 then ty := 0;
  end;
  CbtMap.DrawCursorCell(tx, ty);
  Blit.FlushView;
end;

{ div 4 = the icon mirror boundary: facings 4..7 draw mirrored (MapTiles.DrawIconAnimSprite) }
procedure SetCreatureFacing(creature: Types.PCharRecord; dir, frame, eraseOnly: Byte);
var
  slot: Byte;
begin
  slot := CbtMap.CombatSlot(creature);
  if slot = 0 then begin
    { not on the map: nothing to draw }
    creature^.combatAddr^.direction := dir;
    Exit;
  end;
  if not CbtMap.CombatIconVisible(creature, 1) then
    CbtMap.ScrollView(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 3, C_DIR.CENTER);
  if (creature^.combatAddr^.direction div 4 <> dir div 4)
     or (frame <> 0) or (eraseOnly <> 0) then
    CbtMap.UpdateCombatMapTile(0, 0, slot);
  if dir <> creature^.combatAddr^.direction then
    creature^.combatAddr^.direction := dir;
  if eraseOnly = 0 then
    if CbtMap.CombatIconVisible(creature, 1) then begin
      MapTiles.DrawIconAnimSprite(gridX[slot], gridY[slot], dir, frame, creature^.orderNumber);
      Blit.FlushView;
    end;
end;

{ A creature not on the map (slot 0) gives cell 0, 0 and size 0. }
function CombatCellX(creature: Types.PCharRecord): ShortInt;
var
  slot: Byte;
begin
  slot := CbtMap.CombatSlot(creature);
  if slot = 0 then
    CombatCellX := 0
  else
    CombatCellX := GameVars.arenaLoc[slot].x;
end;

function CombatCellY(creature: Types.PCharRecord): ShortInt;
var
  slot: Byte;
begin
  slot := CbtMap.CombatSlot(creature);
  if slot = 0 then
    CombatCellY := 0
  else
    CombatCellY := GameVars.arenaLoc[slot].y;
end;

function GetIconSize(creature: Types.PCharRecord): Byte;
var
  slot: Byte;
begin
  slot := CbtMap.CombatSlot(creature);
  if slot = 0 then
    GetIconSize := 0
  else
    GetIconSize := GameVars.arenaLoc[slot].size;
end;

{ nil is in no slot: arenaCount's own slot, past the last creature placed, can hold nil }
function CombatSlot(creature: Types.PCharRecord): Byte;
var
  i: Byte;
begin
  CombatSlot := 0;
  if creature <> nil then
    for i := 1 to Pathing.LastSlot do
      if GameVars.creatureArr[i] = creature then begin
        CombatSlot := i;
        Exit;
      end;
end;

procedure ProbeDirection(creature: Types.PCharRecord; dir: Byte; var crIdx, terrIdx: Byte);
var
  i: Byte;
  slot: Byte;
  c: Byte;
  t: Byte;
  best: Byte;
  nx: ShortInt;
  ny: ShortInt;
  x: ShortInt;
  y: ShortInt;
  tdx: ShortInt;
  tdy: ShortInt;
begin
  crIdx := 0;
  terrIdx := 23;
  best := 1;
  slot := CbtMap.CombatSlot(creature);
  if slot = 0 then begin
    { not on the map: nothing to probe from }
    terrIdx := 0;
    Exit;
  end;
  x := GameVars.arenaLoc[slot].x;
  y := GameVars.arenaLoc[slot].y;
  for i := 0 to 3 do begin
    if Pathing.GetIconTileDelta(GameVars.arenaLoc[slot].size, i, tdx, tdy) then begin
      nx := x + tdx + GameDefs.dirDX[dir];
      ny := y + tdy + GameDefs.dirDY[dir];
      CbtMap.GetArenaContents(nx, ny, c, t);
      if c = slot then
        c := 0;
      if c > 0 then
        crIdx := c;
      if (t = 0) or (terrIdx = 0) then
        terrIdx := 0
      else if (t = C_TERR.STINKING_CLOUD) or (terrIdx = C_TERR.STINKING_CLOUD) then
        terrIdx := C_TERR.STINKING_CLOUD
      else if GameDefs.terrainInfo[t].cost >= best then begin
        best := GameDefs.terrainInfo[t].cost;
        terrIdx := t;
      end;
    end;
  end;
end;

procedure RegisterDowned(creature: Types.PCharRecord; x, y: Byte);
var
  k: Byte;
  free: Byte;
begin
  free := 0;
  for k := 1 to GameVars.downedCount do
    if GameVars.downed[k].cr = creature then
      Exit
    else if (GameVars.downed[k].cr = nil) and (free = 0) then
      free := k;
  if free = 0 then begin
    if GameVars.downedCount >= Types.DOWNED_SLOTS then Exit;
    Inc(GameVars.downedCount);
    free := GameVars.downedCount;
  end;
  GameVars.downed[free].terrain := GameVars.arenaPtr^.cells[y, x];
  if GameVars.arenaPtr^.cells[y, x] <> C_TERR.STINKING_CLOUD then
    GameVars.arenaPtr^.cells[y, x] := C_TERR.CORPSE;
  GameVars.downed[free].cr := creature;
  GameVars.downed[free].x := x;
  GameVars.downed[free].y := y;
end;

{ Mark a downed creature: in combat, flash the skull over it and, for the party side, record its corpse once in
  GameVars.downed (CbtMap.RegisterDowned). }
procedure CreatureDowned(creature: Types.PCharRecord);
var
  slot: Byte;
  k: Byte;
  tdx: ShortInt;
  tdy: ShortInt;
  cellX: ShortInt;
  cellY: ShortInt;
begin
  SoundDrv.SoundSetAutoStop(0);
  if GameVars.ifcState <> C_IFC.IN_COMBAT then begin
    SoundDrv.SoundEffect(GameDefs.soundIds.combat[C_SOUND.DOWNED], C_SOUND.GROUP_DEATH);
    TextRend.PauseOnly;
  end else begin
    for k := 1 to GameVars.downedCount do
      if GameVars.downed[k].cr = creature then begin
        { already listed (a body hit again): put the sound timer back as the normal path does, or the BIOS clock stays
          stopped and the next SoundDelay waits for ever }
        SoundDrv.SoundSetAutoStop(10);
        Exit;
      end;
    slot := CbtMap.CombatSlot(creature);
    if slot = 0 then begin
      { not on the map }
      SoundDrv.SoundSetAutoStop(10);
      Exit;
    end;
    cellX := CbtMap.CombatCellX(creature);
    cellY := CbtMap.CombatCellY(creature);
    if not CbtMap.CombatIconVisible(creature, 1) then
      CbtMap.ScrollView(cellX, cellY, 3, C_DIR.CENTER);
    CbtMap.UpdateCombatMapTile(0, 0, slot);
    for k := 0 to 3 do
      if Pathing.GetIconTileDelta(GameVars.arenaLoc[slot].size, k, tdx, tdy) then
        Blit.BlitTileClipped((gridX[slot] + tdx) * 3, (gridY[slot] + tdy) * 3, 0, 5,
                             GameVars.iconAnimation[24, 0],
                             GameVars.viewBuffer);
    Blit.FlushView;
    if creature^.combatAddr^.notPcNpc = 0 then
      CbtMap.RegisterDowned(creature, cellX, cellY);
    SoundDrv.SoundEffect(GameDefs.soundIds.combat[C_SOUND.DOWNED], C_SOUND.GROUP_DEATH);
    TextRend.PauseOnly;
    CbtMap.UpdateCombatMapTile(0, 0, slot);
    GameVars.arenaLoc[slot].size := 0;
    CbtMap.BuildArenaArrays;
    CbtMap.ScrollView(GameVars.arenaPtr^.ox + 3, GameVars.arenaPtr^.oy + 3, 3, C_DIR.CENTER);
    creature^.combatAddr^.initiative := 0;
    creature^.combatAddr^.movement := 0;
    creature^.combatAddr^.spellCast := 0;
    creature^.combatAddr^.guarding := 0;
  end;
  SoundDrv.SoundSetAutoStop(10);
end;

{ Non-combat: True, nothing else. Combat: places the creature at (x, y) (icon size = the low 7 bits of iconDimensions),
  probes its own tiles (dir 8) and rejects on any creature, terrain 0 or cost 255 by zeroing the icon size. On success
  with moving set and notPcNpc = 0, clear the creature's corpse entries and, if no other corpse sits at (x, y), write
  the terrain it saved into that cell (the probed terrain when none was saved or the saved one is C_TERR.CORPSE). }
function IsValidCreatureLoc(creature: Types.PCharRecord; x, y: Byte; moving: Boolean): Boolean;
var
  slot: Byte;
  i: Byte;
  c: Byte;
  t: Byte;
  found: Boolean;
begin
  if GameVars.ifcState = C_IFC.IN_COMBAT then begin
    IsValidCreatureLoc := False;
    slot := CbtMap.CombatSlot(creature);
    { not in the combat arrays }
    if slot = 0 then
      Exit;
    GameVars.arenaLoc[slot].size := creature^.iconDimensions and $7F;
    GameVars.arenaLoc[slot].x := x;
    GameVars.arenaLoc[slot].y := y;
    CbtMap.ProbeDirection(creature, C_DIR.CENTER, c, t);
    if (c <> 0) or (t = 0) or (GameDefs.terrainInfo[t].cost = 255) then
      GameVars.arenaLoc[slot].size := 0
    else begin
      IsValidCreatureLoc := True;
      if moving then
        if creature^.combatAddr^.notPcNpc = 0 then begin
          for i := 1 to GameVars.downedCount do
            if GameVars.downed[i].cr = creature then begin
              if GameVars.downed[i].terrain <> C_TERR.CORPSE then
                t := GameVars.downed[i].terrain;
              FillChar(GameVars.downed[i], SizeOf(GameVars.downed[i]), 0);
            end;
          found := False;
          for i := 1 to GameVars.downedCount do
            if (GameVars.downed[i].cr <> nil) and (GameVars.downed[i].x = x)
               and (GameVars.downed[i].y = y) then
              found := True;
          if not found then
            GameVars.arenaPtr^.cells[y, x] := t;
        end;
      CbtMap.BuildArenaArrays;
    end;
  end else
    IsValidCreatureLoc := True;
end;

procedure DisplayMapViewCentered(creature: Types.PCharRecord; delta: Byte; cursor: Boolean);
begin
  GameVars.arenaPtr^.cursorOn := cursor;
  GameVars.arenaPtr^.cursorSize := CbtMap.GetIconSize(creature);
  CbtMap.ScrollView(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), delta, C_DIR.CENTER);
  GameVars.arenaPtr^.cursorOn := False;
  GameVars.arenaPtr^.cursorSize := 1;
end;

function CountTargets(creature: Types.PCharRecord; range: Byte): Byte;
var
  n: Byte;
  cnt: Byte;
  i: Byte;
begin
  Pathing.BuildTargetList(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), range, 255,
                          CbtMap.GetIconSize(creature), GameVars.arenaPtr);
  n := GameVars.targetCount;
  cnt := 0;
  if n > 0 then begin
    for i := 1 to n do
      if CharHlp.EnemyTeam(creature) = CharHlp.Team(GameVars.creatureArr[GameVars.targetList[i].idx]) then begin
        Inc(cnt);
        Move(GameVars.targetList[i], GameVars.targetList[cnt], SizeOf(GameVars.targetList[i]));
      end;
    n := cnt;
    GameVars.targetCount := cnt;
  end;
  CountTargets := n;
  for i := 1 to n do
    GameVars.combatTargetSlots[i] := GameVars.targetList[i].idx;
end;

function CalcDistance(creature, other: Types.PCharRecord): Byte;
var
  saved: Types.TTargetSnapshot;
  i: Byte;
begin
  Pathing.SaveTargets(saved);
  GameVars.arenaPtr^.distMode := 1;
  Pathing.BuildTargetList(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 255, 255,
                          CbtMap.GetIconSize(creature), GameVars.arenaPtr);
  GameVars.arenaPtr^.distMode := 0;
  i := 1;
  while (i <= GameVars.targetCount) and (GameVars.creatureArr[GameVars.targetList[i].idx] <> other) do
    Inc(i);
  if i <= GameVars.targetCount then
    CalcDistance := GameVars.targetList[i].dist shr 1
  else
    CalcDistance := 255;
  Pathing.RestoreTargets(saved);
end;

begin
  previewOn := False;
  previewReport := False;
  aimSet := False;
  FillChar(gridX, SizeOf(gridX), 0);
  FillChar(gridY, SizeOf(gridY), 0);
end.

{ Combat map display: a 7x7 viewport over the 50x25 arena, with creature icons, scrolling, a movement cursor and corpse
  tracking. }
{$O+,F+}
unit CbtMap;

interface

uses Types;

var
  { Lightning Bolt's path for the spell-aim preview; GameInit sets it to Magic.TraceLightningBolt, so CbtMap does not
    call Magic }
  boltTracer: Types.TCellTracer;

{ On EGA, swap palette registers 0 and 8 so the combat map background is dark gray and register 8 black. }
procedure SetCombatPalette;

{ On EGA, restore palette register 0 to black and register 8 to dark gray. }
procedure SetNoncombatPalette;

{ Redraw one arena cell from scratch: repaint its terrain (the whole icon footprint when a creature stands there, via
  UpdateCombatMapTile), then the creature sprite if it is visible. (x, y) are arena coordinates. Combat.CreatureAction
  calls it after each creature's action to erase the turn cursor. }
procedure RedrawArenaCell(x, y: ShortInt);

{ Rebuild the arena's creature-index grid and each creature's cached view coordinates. }
procedure BuildArenaArrays;

{ Return the creature and terrain indices at an arena cell. Both are zero outside the arena. }
procedure GetArenaContents(x, y: ShortInt; var crIdx, terrIdx: Byte);

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
  beats everything, then C_Terr.STINK_CLOUD, otherwise the highest cost wins (the later tile on a tie). The preset pair
  is terrIdx 23 / best 1: terrainInfo[23] is a cost-1 passable entry, so any real terrain of cost >= 1 replaces it.
  Combat.MoveMenu uses it for bump attacks and terrain cost; IsValidCreatureLoc probes dir 8, the creature's own
  cells. }
procedure ProbeDirection(creature: Types.PCharRecord; dir: Byte; var crIdx, terrIdx: Byte);

{ Record a downed party member's corpse at (x, y): the cell's terrain is kept and the cell becomes C_Terr.CORPSE (a
  stinking cloud is left as it is). A creature already in GDVars.downed is not added again, and a slot cleared when its
  creature got up is reused, so the eight slots are never overrun; with all eight in use the corpse is not recorded. }
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
  Lightning Bolt's path from the cursor cell (boltTracer). AimCloud covers the passable cells of
  Magic.StinkingCloudHandler's 2x2 block and draws them with the stinking-cloud terrain tile instead of areaCell. The
  frames are drawn from MenuCore.MenuHorizontal's idle hook. }
procedure StartSpellPreview(shape: Types.TAimShape; radius, areaCell: Byte);

{ Advance the spell-aim preview by one frame once enough time has passed since the last one. }
procedure TickSpellPreview;

{ End the spell-aim preview: remove the idle hook and repaint every cell it drew over. }
procedure StopSpellPreview;

implementation

uses Crt, C_Terr, GDConsts, GDVars, MapTiles, TextRend, SoundDrv, C_Ifc, C_Dir, C_Sound, Pathing, MenuCore,
  Blit;

const
  { The cursor sprite cell in GDVars.dsIconAnimation }
  CURSOR_CELL = 25;
  { Hundredths of a second between preview frames }
  PREVIEW_PACE = 12;
  { Frames the whole area stays lit, then blank frames before the next cycle }
  PREVIEW_HOLD = 3;
  PREVIEW_GAP = 2;

var
                                           { [24,0] = COMSPR 11 skull;
                                             [25] = the cursor sprite   }
  { Spell-aim preview settings (StartSpellPreview). }
  previewOn: Boolean;
  previewRadius: Byte;
  previewShape: Types.TAimShape;
  areaArt: Byte;
  { The cursor cell and footprint size the preview is aimed at; aimSet is clear until a cursor draw sets them. }
  aimSet: Boolean;
  aimX: ShortInt;
  aimY: ShortInt;
  aimSize: Byte;
  { The cells the spell reaches and the ring (frame of the cycle) each lights up on. }
  areaCount: Byte;
  areaX: array[1..64] of ShortInt;
  areaY: array[1..64] of ShortInt;
  areaRing: array[1..64] of Byte;
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
    if CbtMap.CombatIconVisible(GDVars.creatureArr[c], 0) then
      MapTiles.DrawIconAnimSprite(GDVars.gridX[c], GDVars.gridY[c], GDVars.creatureArr[c]^.combatAddr^.direction,
                                  0, GDVars.creatureArr[c]^.orderNumber);
end;

{ Put back what belongs on top of a view cell after its terrain was drawn: the cursor box when the cell is under the
  aim footprint, then the creature standing on the cell. relX, relY are the cell's view coordinates. }
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
  relX := x - GDVars.arenaPtr^.ox;
  relY := y - GDVars.arenaPtr^.oy;
  if CbtMap.ViewCoordsValid(relX, relY) then begin
    MapTiles.Copy2DTile(relX * 3, relY * 3, GDConsts.terrainInfo[GDVars.arenaPtr^.cells[y, x]].tileId, 0);
    DrawCellTop(x, y, relX, relY);
  end;
end;

{ Draw frame half of combat sprite art over arena cell (x, y), when it is in view; a facing of 4 or more mirrors it.
  The creature on the cell is put back over the art, but the cursor box is not: under the aim footprint the cell
  already shows the cursor box (DrawCursorCell, RepaintCell), so the art lies on top of it. }
procedure DrawPreviewArt(x, y: ShortInt; art, facing, half: Byte);
var
  relX: ShortInt;
  relY: ShortInt;
begin
  relX := x - GDVars.arenaPtr^.ox;
  relY := y - GDVars.arenaPtr^.oy;
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
    relX := areaX[i] - GDVars.arenaPtr^.ox;
    relY := areaY[i] - GDVars.arenaPtr^.oy;
    if CbtMap.ViewCoordsValid(relX, relY) then begin
      MapTiles.Copy2DTile(relX * 3, relY * 3, GDConsts.terrainInfo[C_Terr.STINK_CLOUD].tileId, 0);
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
  if areaCount < SizeOf(areaX) then begin
    Inc(areaCount);
    areaX[areaCount] := x;
    areaY[areaCount] := y;
    areaRing[areaCount] := ring;
    if ring >= ringCount then
      ringCount := ring + 1;
  end;
end;

{ Aim the preview at arena cell (x, y): work out the area and start the cycle over. }
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
  aimSize := GDVars.arenaPtr^.cursorSize;
  areaCount := 0;
  ringCount := 0;
  case previewShape of
    Types.AimBolt: begin
         AddAreaCell(x, y, 0);
         CbtMap.boltTracer(x, y, bolt);
         { two cells a frame }
         for i := 1 to bolt.count do
           AddAreaCell(bolt.x[i], bolt.y[i], (i + 1) div 2);
       end;
    Types.AimCloud:
      for i := 1 to 4 do begin
        tx := x + GDConsts.dirDX[GDConsts.cloudDir[i]];
        ty := y + GDConsts.dirDY[GDConsts.cloudDir[i]];
        CbtMap.GetArenaContents(tx, ty, c, t);
        { the aim cell first, then the other three }
        if t > 0 then
          if GDConsts.terrainInfo[t].cost < 255 then
            AddAreaCell(tx, ty, Ord(i > 1));
      end;
  else
    for relY := 0 to 6 do
      for relX := 0 to 6 do begin
        tx := GDVars.arenaPtr^.ox + relX;
        ty := GDVars.arenaPtr^.oy + relY;
        dist := previewRadius;
        { on success dist returns the doubled distance, so dist div 2 is the ring }
        if Pathing.WalkLine(x, y, tx, ty, dist, GDVars.arenaPtr) then
          AddAreaCell(GDVars.arenaPtr^.ox + relX, GDVars.arenaPtr^.oy + relY, dist div 2);
      end;
  end;
  frameNo := 0;
  lastTick := TextRend.GetTicks - PREVIEW_PACE;
end;

procedure StartSpellPreview(shape: Types.TAimShape; radius, areaCell: Byte);
begin
  CbtMap.StopSpellPreview;
  previewShape := shape;
  previewRadius := radius;
  areaArt := areaCell;
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
    previewOn := False;
  end;
end;

{ Recompute every creature's view coordinates from its arena location and the view origin. }
procedure CalcGridDeltas;
var
  i: Byte;
begin
  for i := 1 to GDVars.arenaCount do begin
    GDVars.gridX[i] := GDVars.arenaLoc[i].x - GDVars.arenaPtr^.ox;
    GDVars.gridY[i] := GDVars.arenaLoc[i].y - GDVars.arenaPtr^.oy;
  end;
end;

procedure SetCombatPalette;
begin
  case GDVars.videoMode of
    Types.vmEGA: begin
         Blit.SetPaletteRegister(0, DarkGray);
         Blit.SetPaletteRegister(8, Black);
       end;
  end;
end;

procedure SetNoncombatPalette;
begin
  case GDVars.videoMode of
    Types.vmEGA: begin
         Blit.SetPaletteRegister(0, Black);
         Blit.SetPaletteRegister(8, DarkGray);
       end;
  end;
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
  relX := x - GDVars.arenaPtr^.ox;
  relY := y - GDVars.arenaPtr^.oy;
  for i := 0 to 3 do begin
    if Pathing.GetIconTileDelta(GDVars.arenaPtr^.cursorSize, i, tdx, tdy) then
      if CbtMap.ViewCoordsValid(relX + tdx, relY + tdy) then begin
        MapTiles.Copy2DTile((relX + tdx) * 3, (relY + tdy) * 3,
                            GDConsts.terrainInfo[GDVars.arenaPtr^.cells[y + tdy, x + tdx]].tileId, 0);
        if GDVars.arenaPtr^.cursorOn then
          MapTiles.DrawIconAnimSprite(relX + tdx, relY + tdy, 0, 0, CURSOR_CELL);
      end;
  end;
  DrawCellCreature(x, y);
  if previewOn and GDVars.arenaPtr^.cursorOn then
    RestartSpellPreview(x, y);
end;

procedure RedrawArenaCell(x, y: ShortInt);
var
  relX: ShortInt;
  relY: ShortInt;
begin
  relX := x - GDVars.arenaPtr^.ox;
  relY := y - GDVars.arenaPtr^.oy;
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
  FillChar(GDVars.crIdxArr, SizeOf(GDVars.crIdxArr), 0);
  for i := 1 to GDVars.arenaCount do begin
    if GDVars.arenaLoc[i].size > 0 then begin
      for j := 0 to 3 do
        if Pathing.GetIconTileDelta(GDVars.arenaLoc[i].size, j, tdx, tdy) then
          GDVars.crIdxArr[GDVars.arenaLoc[i].y + tdy, GDVars.arenaLoc[i].x + tdx] := i;
      GDVars.gridX[i] := GDVars.arenaLoc[i].x - GDVars.arenaPtr^.ox;
      GDVars.gridY[i] := GDVars.arenaLoc[i].y - GDVars.arenaPtr^.oy;
    end;
  end;
end;

procedure GetArenaContents(x, y: ShortInt; var crIdx, terrIdx: Byte);
begin
  if (x >= 0) and (x <= 49) and (y >= 0) and (y <= 24) then begin
    terrIdx := GDVars.arenaPtr^.cells[y, x];
    crIdx := GDVars.crIdxArr[y, x];
  end else begin
    crIdx := 0;
    terrIdx := 0;
  end;
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
    absX := x + GDVars.arenaPtr^.ox;
    absY := y + GDVars.arenaPtr^.oy;
    CbtMap.GetArenaContents(absX, absY, crIdx, t);
  end;
  if crIdx > 0 then begin
    x := GDVars.gridX[crIdx];
    y := GDVars.gridY[crIdx];
    absX := x + GDVars.arenaPtr^.ox;
    absY := y + GDVars.arenaPtr^.oy;
    size := GDVars.arenaLoc[crIdx].size;
    for i := 0 to 3 do
      if Pathing.GetIconTileDelta(size, i, tdx, tdy) then
        if CbtMap.ViewCoordsValid(x + tdx, y + tdy) then
          MapTiles.Copy2DTile((x + tdx) * 3, (y + tdy) * 3,
                              GDConsts.terrainInfo[GDVars.arenaPtr^.cells[absY + tdy, absX + tdx]].tileId, 0);
  end else if CbtMap.ViewCoordsValid(x, y) then
    MapTiles.Copy2DTile(x * 3, y * 3, GDConsts.terrainInfo[GDVars.arenaPtr^.cells[absY, absX]].tileId, 0);
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
  if (slot = 0) or (GDVars.arenaLoc[slot].size = 0) then
    CombatIconVisible := False
  else
    for i := 0 to 3 do begin
      if Pathing.GetIconTileDelta(GDVars.arenaLoc[slot].size, i, tdx, tdy) then
        if not CbtMap.ViewCoordsValid(GDVars.gridX[slot] + tdx, GDVars.gridY[slot] + tdy) then begin
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
  cX := GDVars.arenaPtr^.ox + 3;
  cY := GDVars.arenaPtr^.oy + 3;
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
    while (x > cX) and (cX < 46) do Inc(cX);
  if y < minY then
    while (y < cY) and (cY > 3) do Dec(cY)
  else if y > maxY then
    while (y > cY) and (cY < 21) do Inc(cY);
  GDVars.arenaPtr^.ox := cX - 3;
  GDVars.arenaPtr^.oy := cY - 3;
  pixY := 0;
  cY := GDVars.arenaPtr^.oy;
  for j := 0 to 6 do begin
    pixX := 0;
    cX := GDVars.arenaPtr^.ox;
    for i := 0 to 6 do begin
      MapTiles.Copy2DTile(pixX, pixY, GDConsts.terrainInfo[GDVars.arenaPtr^.cells[cY, cX]].tileId, 1);
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
  tx := x + GDConsts.dirDX[dir];
  ty := y + GDConsts.dirDY[dir];
  if CbtMap.BuildViewBuffer(tx, ty, delta) then begin
    for i := 1 to GDVars.arenaCount do begin
      p := GDVars.creatureArr[i];
      if (p^.enabled <> 0) and (GDVars.arenaLoc[i].size > 0) then
        if CbtMap.CombatIconVisible(p, 0) then
          MapTiles.DrawIconAnimSprite(GDVars.gridX[i], GDVars.gridY[i], p^.combatAddr^.direction, 0,
                                      p^.orderNumber);
    end;
  end;
  CbtMap.RedrawArenaCell(x, y);
  if not CbtMap.ViewCoordsValid(tx - GDVars.arenaPtr^.ox, ty - GDVars.arenaPtr^.oy) then begin
    if tx > 49 then tx := 49;
    if tx < 0 then tx := 0;
    if ty > 24 then ty := 24;
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
    CbtMap.ScrollView(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 3, C_Dir.CENTER);
  if (creature^.combatAddr^.direction div 4 <> dir div 4)
     or (frame <> 0) or (eraseOnly <> 0) then
    CbtMap.UpdateCombatMapTile(0, 0, slot);
  if dir <> creature^.combatAddr^.direction then
    creature^.combatAddr^.direction := dir;
  if eraseOnly = 0 then
    if CbtMap.CombatIconVisible(creature, 1) then begin
      MapTiles.DrawIconAnimSprite(GDVars.gridX[slot], GDVars.gridY[slot], dir, frame, creature^.orderNumber);
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
    CombatCellX := GDVars.arenaLoc[slot].x;
end;

function CombatCellY(creature: Types.PCharRecord): ShortInt;
var
  slot: Byte;
begin
  slot := CbtMap.CombatSlot(creature);
  if slot = 0 then
    CombatCellY := 0
  else
    CombatCellY := GDVars.arenaLoc[slot].y;
end;

function GetIconSize(creature: Types.PCharRecord): Byte;
var
  slot: Byte;
begin
  slot := CbtMap.CombatSlot(creature);
  if slot = 0 then
    GetIconSize := 0
  else
    GetIconSize := GDVars.arenaLoc[slot].size;
end;

function CombatSlot(creature: Types.PCharRecord): Byte;
var
  i: Byte;
begin
  CombatSlot := 0;
  { 72 = High(creatureArr) }
  for i := 1 to GDVars.arenaCount do
    if i <= 72 then
      if GDVars.creatureArr[i] = creature then begin
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
  x := GDVars.arenaLoc[slot].x;
  y := GDVars.arenaLoc[slot].y;
  for i := 0 to 3 do begin
    if Pathing.GetIconTileDelta(GDVars.arenaLoc[slot].size, i, tdx, tdy) then begin
      nx := x + tdx + GDConsts.dirDX[dir];
      ny := y + tdy + GDConsts.dirDY[dir];
      CbtMap.GetArenaContents(nx, ny, c, t);
      if c = slot then
        c := 0;
      if c > 0 then
        crIdx := c;
      if (t = 0) or (terrIdx = 0) then
        terrIdx := 0
      else if (t = C_Terr.STINK_CLOUD) or (terrIdx = C_Terr.STINK_CLOUD) then
        terrIdx := C_Terr.STINK_CLOUD
      else if GDConsts.terrainInfo[t].cost >= best then begin
        best := GDConsts.terrainInfo[t].cost;
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
  for k := 1 to GDVars.downedCount do
    if GDVars.downed[k].cr = creature then
      Exit
    else if (GDVars.downed[k].cr = nil) and (free = 0) then
      free := k;
  if free = 0 then begin
    if GDVars.downedCount >= 8 then Exit;
    Inc(GDVars.downedCount);
    free := GDVars.downedCount;
  end;
  GDVars.downed[free].terrain := GDVars.arenaPtr^.cells[y, x];
  if GDVars.arenaPtr^.cells[y, x] <> C_Terr.STINK_CLOUD then
    GDVars.arenaPtr^.cells[y, x] := C_Terr.CORPSE;
  GDVars.downed[free].cr := creature;
  GDVars.downed[free].x := x;
  GDVars.downed[free].y := y;
end;

{ Mark a downed creature: in combat, draw its corpse and record it once in GDVars.downed (CbtMap.RegisterDowned). }
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
  if GDVars.ifcState <> C_Ifc.COMBAT then begin
    SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.DOWNED]);
    TextRend.PauseOnly;
  end else begin
    for k := 1 to GDVars.downedCount do
      if GDVars.downed[k].cr = creature then begin
        { already listed (a body hit again): put the sound timer back as the normal path does, or the BIOS clock
          stays stopped and the next SoundDelay waits for ever }
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
      CbtMap.ScrollView(cellX, cellY, 3, C_Dir.CENTER);
    CbtMap.UpdateCombatMapTile(0, 0, slot);
    for k := 0 to 3 do
      if Pathing.GetIconTileDelta(GDVars.arenaLoc[slot].size, k, tdx, tdy) then
        Blit.BlitTileClipped((GDVars.gridX[slot] + tdx) * 3, (GDVars.gridY[slot] + tdy) * 3, 0, 5,
                             GDVars.dsIconAnimation[24, 0],
                             GDVars.dsViewImageBufferPtr);
    Blit.FlushView;
    if creature^.combatAddr^.notPcNpc = 0 then
      CbtMap.RegisterDowned(creature, cellX, cellY);
    SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.DOWNED]);
    TextRend.PauseOnly;
    CbtMap.UpdateCombatMapTile(0, 0, slot);
    GDVars.arenaLoc[slot].size := 0;
    CbtMap.BuildArenaArrays;
    CbtMap.ScrollView(GDVars.arenaPtr^.ox + 3, GDVars.arenaPtr^.oy + 3, 3, C_Dir.CENTER);
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
  the terrain it saved into that cell (the probed terrain when none was saved or the saved one is C_Terr.CORPSE). }
function IsValidCreatureLoc(creature: Types.PCharRecord; x, y: Byte; moving: Boolean): Boolean;
var
  slot: Byte;
  i: Byte;
  c: Byte;
  t: Byte;
  found: Boolean;
begin
  if GDVars.ifcState = C_Ifc.COMBAT then begin
    IsValidCreatureLoc := False;
    slot := CbtMap.CombatSlot(creature);
    { not in the combat arrays }
    if slot = 0 then
      Exit;
    GDVars.arenaLoc[slot].size := creature^.iconDimensions and $7F;
    GDVars.arenaLoc[slot].x := x;
    GDVars.arenaLoc[slot].y := y;
    CbtMap.ProbeDirection(creature, C_Dir.CENTER, c, t);
    if (c <> 0) or (t = 0) or (GDConsts.terrainInfo[t].cost = 255) then
      GDVars.arenaLoc[slot].size := 0
    else begin
      IsValidCreatureLoc := True;
      if moving then
        if creature^.combatAddr^.notPcNpc = 0 then begin
          for i := 1 to GDVars.downedCount do
            if GDVars.downed[i].cr = creature then begin
              if GDVars.downed[i].terrain <> C_Terr.CORPSE then
                t := GDVars.downed[i].terrain;
              FillChar(GDVars.downed[i], SizeOf(GDVars.downed[i]), 0);
            end;
          found := False;
          for i := 1 to GDVars.downedCount do
            if (GDVars.downed[i].cr <> nil) and (GDVars.downed[i].x = x)
               and (GDVars.downed[i].y = y) then
              found := True;
          if not found then
            GDVars.arenaPtr^.cells[y, x] := t;
        end;
      CbtMap.BuildArenaArrays;
    end;
  end else
    IsValidCreatureLoc := True;
end;

procedure DisplayMapViewCentered(creature: Types.PCharRecord; delta: Byte; cursor: Boolean);
begin
  GDVars.arenaPtr^.cursorOn := cursor;
  GDVars.arenaPtr^.cursorSize := CbtMap.GetIconSize(creature);
  CbtMap.ScrollView(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), delta, C_Dir.CENTER);
  GDVars.arenaPtr^.cursorOn := False;
  GDVars.arenaPtr^.cursorSize := 1;
end;

begin
  previewOn := False;
  aimSet := False;
end.

{ The party's screens: the party list, a creature's name, hit points and armor class, the noncombat, wilderness and
  combat layouts, the message window and bottom-line messages, and combat's moving icons. Overlaid; split from CharHlp,
  whose resident core keeps the stats, inventory and damage. }
{$O+,F+}
{$I COMPILER.INC}
unit CharDisp;

interface

uses Types;

var
  { Portrait head ID. }
  currentPortraitHead: Byte;
  { Portrait body ID. }
  currentPortraitHead2: Byte;
  { Set while the party menu is a training hall's in a game in play, the two-column one, and clear while it is SSI's
    start-up menu (CharGen.MainMenu, #885): DisplayParty draws the roster of the one or the other. }
  hallMenu: Boolean;

procedure DisplayParty(hl: Types.PCharRecord);

procedure PrintArmorClass(creature: Types.PCharRecord; col, row: Byte);

procedure PrintHitPoints(creature: Types.PCharRecord; col, row: Byte; hotPink: Boolean);

procedure DisplayCreatureName(creature: Types.PCharRecord; col, row: Byte; possessive: Boolean);

{ Add the creature's name to the combat log's message (#841) in the colour DisplayCreatureName gives it, on a line of
  its own as the combat window shows it. }
procedure LogCreatureName(creature: Types.PCharRecord);

procedure CombatPrintCreatureInfo(creature: Types.PCharRecord);

procedure PrintNameString(creature: Types.PCharRecord; s: string; row: Byte; pause: Boolean);

procedure PrintMessage(s: string);

{ Show s in color in the message window (the combat window in combat, else the bottom window), word-wrapped. first
  clears and opens the window; otherwise s carries on from where the last part stopped, so a message can be shown in
  parts of different colors. MessageWait then waits for a key. }
procedure MessageText(s: string; color: Byte; first: Boolean);

{ Wait for a key at the 'Press any key to continue' prompt and clear the prompt; the window keeps the text. }
procedure MessageWait;

{ Show line1 and then line2 from the start of the next line, both in light green, in the message window as MessageText
  does (cleared first), pause (TextRend.PauseOnly) and clear the window. }
procedure PrintTwoLines(line1, line2: string);

procedure PrintBottomLine(s: Types.TStr40);

{ PrintBottomLine for something creature does in combat ('Guarding'): the bottom line shows s as ever, and the combat
  log's message names the creature first, in the colour names have in combat, then says logged, as
  "MORRIGAN is Guarding" (#875). Outside combat it is PrintBottomLine. }
procedure PrintActionLine(creature: Types.PCharRecord; s: Types.TStr40; logged: string);

procedure ClearMessageWindow;

procedure CopyIconFacing(cell, half, row: Byte; mirror: Boolean);

procedure BuildIconFacings(cell: Byte);

procedure CombatAnimateMovingIcon(startX, startY, endX, endY: ShortInt; frames, pace: Byte);

procedure PrintNameStringAnim(creature: Types.PCharRecord; effect: Boolean; s: string);

procedure PrintHpRestoreMsg(creature: Types.PCharRecord);

{ Out of combat, redraw the party list with the current character highlighted (DisplayParty), after a change to its hit
  points or status; in combat nothing. }
procedure RedrawPartyOutOfCombat;

procedure DrawNoncombatWindows(inset: Boolean);

procedure DisplayNoncombatInterface;

procedure PrintMiscInfo;

procedure DisplayWildernessInterface;

procedure DisplayCombatInterface;

procedure SelectChar(query: Types.TStr40; addExit: Boolean; var sel: Types.PCharRecord);

{ Build the item's label (CharHlp.ItemLabel, not as an inventory line) and print it in light green at (col, row). }
procedure PrintItemLabel(item: Types.PItemRec; col, row: Byte);

{ CharHlp.faultHook: show msg in yellow on the bottom line and wait for a key. }
procedure ShowFault(msg: Types.TStr40);

implementation

uses CharHlp, Crt, C_AREA, C_MSG, GameDefs, GameVars, MenuCore, MapView, Pathing, CbtMap, C_EQUIP, C_KEYS, C_IFC, Blit,
  Border, Portrait, SoundDrv, C_SOUND, C_SPELL, TextRend, Wilds, StrUtil, C_GBVM, Party, C_DIR, CbtLog;

var
  { the bottom message window's top row, from MessageText's first part for the parts after it }
  messageTop: Byte;

{ Draw the party roster panel: 'Name' / 'AC HP' headers, then one row per creature -- the name (hl in white, others
  colored by DisplayCreatureName), then AC and HP right-aligned by nudging their columns by their digit counts. Clear
  each row first, and one extra row after the last. On a training hall's two-column party menu (C_IFC.MAIN_MENU with
  hallMenu set, #885) the roster is the mock-up's (mocks/training-hall.txt, #879): the headers on row 1 and the
  creatures from row 2, the names from column 2 and AC and HP a column further left. On SSI's start-up menu the
  headers are on row 2 and the creatures from row 4, the names from column 1; elsewhere the same rows, right of the
  view. }
procedure DisplayParty(hl: Types.PCharRecord);
var
  p: Types.PCharRecord;
  col: Byte;
  row: Byte;
  band: Byte;
  { 1 on the two-column party menu, which moves AC and HP a column left }
  left: Byte;
begin
  col := 17;
  row := 2;
  left := 0;
  if GameVars.ifcState = C_IFC.MAIN_MENU then
    if CharDisp.hallMenu then begin
      col := 2;
      row := 1;
      left := 1;
    end else
      col := 1;
  TextRend.DisplayString(col, row, White, 'Name');
  TextRend.DisplayString(33 - left, row, White, 'AC  HP');
  Inc(row, 2 - left);
  p := GameVars.creatureList;
  while p <> nil do begin
    Border.ClearBox(col, row, 38, row);
    if p = hl then
      TextRend.DisplayString(col, row, White, p^.name)
    else
      CharDisp.DisplayCreatureName(p, col, row, False);
    case p^.acCur of
      0..50: band := 1;
      51..60: band := 2;
      61..69: band := 1;
    else
      band := 0;
    end;
    CharDisp.PrintArmorClass(p, band + 32 - left, row);
    case p^.hpCur of
      0..9: band := 2;
      10..99: band := 1;
    else
      band := 0;
    end;
    CharDisp.PrintHitPoints(p, band + 36 - left, row, False);
    Inc(row);
    p := p^.nextCharAddr;
  end;
  Border.ClearBox(col, row, 38, row);
end;

{ Print the creature's armor class in light green. AC is stored biased by 60, so print Abs(acCur - 60), with a '-'
  prepended for ACs below 0 (acCur > 60). }
procedure PrintArmorClass(creature: Types.PCharRecord; col, row: Byte);
var
  s: String;
begin
  s := StrUtil.NumStr(Abs(creature^.acCur - 60));
  if creature^.acCur > 60 then
    s := '-' + s;
  TextRend.DisplayString(col, row, LightGreen, s);
end;

{ Print the creature's current hit points: yellow when injured, light green at full health, light magenta when hotPink
  is set. }
procedure PrintHitPoints(creature: Types.PCharRecord; col, row: Byte; hotPink: Boolean);
var
  color: Byte;
begin
  if creature^.hpCur < creature^.hpMax then
    color := Yellow
  else
    color := LightGreen;
  if hotPink then
    color := LightMagenta;
  TextRend.DisplayString(col, row, color, StrUtil.NumStr(creature^.hpCur));
end;

{ Show the creature's name, hit points, armor class, equipped weapon and status in the combat information panel. }
procedure CombatPrintCreatureInfo(creature: Types.PCharRecord);
var
  row: Byte;
begin
  Border.ClearBox(23, 1, 38, 21);
  row := 1;
  CharDisp.PrintNameString(creature, ' ', row, False);
  Inc(row);
  TextRend.DisplayString(23, row + 1, LightGreen, 'Hitpoints');
  CharDisp.PrintHitPoints(creature, 33, row + 1, False);
  Inc(row, 2);
  TextRend.DisplayString(23, row + 1, LightGreen, 'AC');
  CharDisp.PrintArmorClass(creature, 26, row + 1);
  GameVars.curRow := row + 1;
  if creature^.equipped[C_EQUIP.WEAPON] <> nil then begin
    Inc(row, 2);
    CharHlp.ItemLabel(creature^.equipped[C_EQUIP.WEAPON], False);
    TextRend.DisplayMessageWindow(23, row + 1, 38, row + 3, LightGreen, True,
                                  creature^.equipped[C_EQUIP.WEAPON]^.name);
  end;
  row := GameVars.curRow + 1;
  if creature^.enabled = 0 then
    TextRend.DisplayString(23, row + 1, White, GameDefs.statusStrs[creature^.status])
  else if CharHlp.IsHelpless(creature) then
    TextRend.DisplayString(23, row + 1, White, '(Helpless)');
end;

{ Show s on the bottom row in light green, pause on the text delay (TextRend.PauseOnly; no key is read), then clear the
  row again. }
procedure ShowBottomLine(s: Types.TStr40);
begin
  Border.ClearBox(0, 24, 39, 24);
  TextRend.DisplayString(0, 24, LightGreen, s);
  TextRend.PauseOnly;
  Border.ClearBox(0, 24, 39, 24);
end;

{ Show a message on the bottom row in light green, pause on the text delay (no key is read), then clear the row again.
  In combat it is a combat log message of its own (#841). }
procedure PrintBottomLine(s: Types.TStr40);
begin
  if GameVars.ifcState = C_IFC.COMBAT then begin
    CbtLog.NewEntry;
    CbtLog.Add(LightGreen, s);
    CbtLog.NewEntry;
  end;
  CharDisp.ShowBottomLine(s);
end;

procedure PrintActionLine(creature: Types.PCharRecord; s: Types.TStr40; logged: string);
begin
  if GameVars.ifcState = C_IFC.COMBAT then begin
    CbtLog.NewEntry;
    CharDisp.LogCreatureName(creature);
    CbtLog.NextLine;
    CbtLog.Add(LightGreen, logged);
    CbtLog.NewEntry;
  end;
  CharDisp.ShowBottomLine(s);
end;

{ Ready the bottom message window outside combat and return its top row: row MESSAGE_TOP + 1 when
  suppressDrawingBorderFlag is set, else MESSAGE_TOP with the border drawn round it; the window is cleared. }
function OpenMessageWindow: Byte;
var
  top: Byte;
begin
  if GameVars.suppressDrawingBorderFlag <> 0 then
    top := C_MSG.MESSAGE_TOP + 1
  else begin
    top := C_MSG.MESSAGE_TOP;
    Border.DrawBorder(C_MSG.TEXT_LEFT, top, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0);
  end;
  Border.ClearBox(C_MSG.TEXT_LEFT, top, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
  OpenMessageWindow := top;
end;

{ Show "<name> <text>" in the message window: in combat, the combat window from column 23 at row; otherwise the
  full-width bottom window (bordered unless suppressDrawingBorderFlag is set), the name on its first line and the text
  word-wrapped below. With pause, wait for a key and clear the window. In combat's message rows (not the creature's
  panel above them) it starts a combat log message (#841). }
procedure PrintNameString(creature: Types.PCharRecord; s: string; row: Byte; pause: Boolean);
var
  top: Byte;
begin
  if GameVars.ifcState = C_IFC.COMBAT then begin
    if row >= C_MSG.COMBAT_MESSAGE_TOP then begin
      CbtLog.NewEntry;
      CharDisp.LogCreatureName(creature);
      CbtLog.NextLine;
      CbtLog.Add(LightGreen, s);
    end;
    Border.ClearBox(C_MSG.COMBAT_LEFT, row, C_MSG.TEXT_RIGHT, C_MSG.COMBAT_BOTTOM);
    CharDisp.DisplayCreatureName(creature, C_MSG.COMBAT_LEFT, row, False);
    TextRend.DisplayMessageWindow(C_MSG.COMBAT_LEFT, row + 1, C_MSG.TEXT_RIGHT, C_MSG.COMBAT_BOTTOM, LightGreen, True,
                                  s);
  end else begin
    top := CharDisp.OpenMessageWindow;
    CharDisp.DisplayCreatureName(creature, 1, top + 1, False);
    TextRend.DisplayMessageWindow(C_MSG.TEXT_LEFT, top + 1 + 1, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, LightGreen, True,
                                  s);
  end;
  if pause then begin
    TextRend.PauseOnly;
    CharDisp.ClearMessageWindow;
  end;
end;

{ Show s in light green in the message window, cleared first, as PrintNameString does but without the name line, and
  leave it there: no key is waited for (#681). curRow is left on its last line. }
procedure PrintMessage(s: string);
begin
  CharDisp.MessageText(s, LightGreen, True);
end;

procedure MessageText(s: string; color: Byte; first: Boolean);
begin
  if GameVars.ifcState = C_IFC.COMBAT then begin
    if first then
      CbtLog.NewEntry;
    CbtLog.Add(color, s);
    if first then
      Border.ClearBox(C_MSG.COMBAT_LEFT, C_MSG.COMBAT_MESSAGE_TOP, C_MSG.TEXT_RIGHT, C_MSG.COMBAT_BOTTOM);
    TextRend.DisplayMessageWindow(C_MSG.COMBAT_LEFT, C_MSG.COMBAT_MESSAGE_TOP, C_MSG.TEXT_RIGHT, C_MSG.COMBAT_BOTTOM,
                                  color, first, s);
  end else begin
    if first then
      messageTop := CharDisp.OpenMessageWindow;
    TextRend.DisplayMessageWindow(C_MSG.TEXT_LEFT, messageTop + 1, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, color, first,
                                  s);
  end;
end;

procedure MessageWait;
begin
  TextRend.DisplayAndPause(LightMagenta, 'Press any key to continue');
  Border.ClearBox(0, 24, 39, 24);
end;

procedure PrintTwoLines(line1, line2: string);
var
  left: Byte;
begin
  if GameVars.ifcState = C_IFC.COMBAT then
    left := C_MSG.COMBAT_LEFT
  else
    left := C_MSG.TEXT_LEFT;
  CharDisp.MessageText(line1, LightGreen, True);
  { a line that ended short of the window's edge leaves the cursor on it: line2 starts on the next }
  if GameVars.curCol <> left then begin
    GameVars.curCol := left;
    Inc(GameVars.curRow);
  end;
  if GameVars.ifcState = C_IFC.COMBAT then
    CbtLog.NextLine;
  CharDisp.MessageText(line2, LightGreen, False);
  TextRend.PauseOnly;
  CharDisp.ClearMessageWindow;
end;

{ Clear whichever message window is active (combat or bottom), leaving its border alone. }
procedure ClearMessageWindow;
begin
  if GameVars.ifcState = C_IFC.COMBAT then
    Border.ClearBox(C_MSG.COMBAT_LEFT, C_MSG.COMBAT_MESSAGE_TOP, C_MSG.TEXT_RIGHT, C_MSG.COMBAT_BOTTOM)
  else
    Border.ClearBox(C_MSG.TEXT_LEFT, C_MSG.MESSAGE_TOP + 1, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
end;

{ The colour of the creature's name: light red (out of action, enabled = 0), yellow (hostile), light magenta (ready to
  train) or light cyan (friendly). }
function NameColor(creature: Types.PCharRecord): Byte;
begin
  if creature^.enabled = 0 then
    NameColor := LightRed
  else if creature^.hostile = 1 then
    NameColor := Yellow
  else if CharHlp.CanTrain(creature) then
    { ready to train, as in Pools of Darkness }
    NameColor := LightMagenta
  else
    NameColor := LightCyan;
end;

procedure LogCreatureName(creature: Types.PCharRecord);
begin
  CbtLog.NextLine;
  CbtLog.Add(CharDisp.NameColor(creature), creature^.name);
end;

{ Print the creature's name in its colour (NameColor), optionally followed by the possessive 's. }
procedure DisplayCreatureName(creature: Types.PCharRecord; col, row: Byte; possessive: Boolean);
var
  color: Byte;
begin
  color := CharDisp.NameColor(creature);
  TextRend.DisplayString(col, row, color, creature^.name);
  if possessive then
    TextRend.DisplayString(col + Length(creature^.name), row, color, '''s');
end;

{ Copy one icon half (GameVars.iconAnimation[cell, half]) into frame row of the moving-icon sheet
  (GameVars.moveIconSheet), mirrored through a scratch picture when asked. The pixel data copies imgSize bytes; the
  transparency mask copies Blit.MaskBytes of that. }
procedure CopyIconFacing(cell, half, row: Byte; mirror: Boolean);
var
  tmp: Types.PImgBuf;
  stride4: Word;
  stride: Word;
begin
  stride := GameVars.moveIconSheet^.imgSize;
  stride4 := Blit.MaskBytes(stride);
  if mirror then begin
    Blit.AllocPic(24, 3, 1, 1, tmp);
    Blit.MirrorPic(GameVars.iconAnimation[cell, half], tmp);
    Move(tmp^.data, GameVars.moveIconSheet^.data[row * stride], stride);
    Move(tmp^.transp^, GameVars.moveIconSheet^.transp^[row * stride4], stride4);
    Blit.FreePic(tmp);
  end else begin
    Move(GameVars.iconAnimation[cell, half]^.data, GameVars.moveIconSheet^.data[row * stride], stride);
    Move(GameVars.iconAnimation[cell, half]^.transp^, GameVars.moveIconSheet^.transp^[row * stride4], stride4);
  end;
end;

{ Assemble the four-frame facing sheet for an icon: half 0 straight and mirrored, then half 1 mirrored and straight. }
procedure BuildIconFacings(cell: Byte);
begin
  CharDisp.CopyIconFacing(cell, 0, 0, False);
  CharDisp.CopyIconFacing(cell, 0, 1, True);
  CharDisp.CopyIconFacing(cell, 1, 2, True);
  CharDisp.CopyIconFacing(cell, 1, 3, False);
end;

{ Fly an icon from the start cell to the end cell in the combat view. Trace the line at third-of-a-cell resolution
  (Pathing.PathFind sets it up, Pathing.NextPathStep yields one direction per step), scroll the view toward a focus
  point, then walk the icon one 8-pixel column per step: blit the facing frame from the moving-icon sheet, flush, delay,
  restore the background, cycle frames. startX/startY track the current cell. When the walk leaves the 0..18 column
  window before the end, rescroll and repeat; at the end, draw the icon on the end cell. }
procedure CombatAnimateMovingIcon(startX, startY, endX, endY: ShortInt; frames, pace: Byte);
var
  { a 49-cell span takes 148 steps; the last slot stays 8 (no move) for the walk's read one past count }
  steps: array[0..148] of Byte;
  req: Types.TPathReq;
  n: Byte;
  count: Byte;
  frame: Byte;
  lastPass: Boolean;
  done: Boolean;
  camX: ShortInt;
  camY: ShortInt;
  prevX: ShortInt;
  prevY: ShortInt;
  accX: ShortInt;
  accY: ShortInt;
  dirX: ShortInt;
  dirY: ShortInt;
  stepX: ShortInt;
  stepY: ShortInt;
  pixX: ShortInt;
  pixY: ShortInt;
begin
  prevX := startX;
  prevY := startY;
  FillChar(steps, SizeOf(steps), 8);
  FillChar(req, SizeOf(req), 0);
  n := 0;
  frame := 0;
  req.sx := startX * 3;
  req.sy := startY * 3;
  req.ex := endX * 3;
  req.ey := endY * 3;
  Pathing.PathFind(req);
  repeat
    done := not Pathing.NextPathStep(req);
    steps[n] := req.step;
    Inc(n);
    { a longer path than the arena allows is cut short }
    if n >= SizeOf(steps) - 1 then
      done := True;
  until done;
  count := n;
  if count < 2 then Exit;
  dirX := endX - startX;
  dirY := endY - startY;
  if not CbtMap.ViewCoordsValid(startX - GameVars.arenaPtr^.ox, startY - GameVars.arenaPtr^.oy) or
      not CbtMap.ViewCoordsValid(endX - GameVars.arenaPtr^.ox, endY - GameVars.arenaPtr^.oy) then begin
    if (Abs(dirX) <= 6) and (Abs(dirY) <= 6) then begin
      lastPass := True;
      camX := startX + dirX div 2;
      camY := startY + dirY div 2;
    end else begin
      lastPass := False;
      camX := GameVars.arenaPtr^.ox + 3;
      camY := GameVars.arenaPtr^.oy + 3;
    end;
  end else begin
    lastPass := True;
    camX := GameVars.arenaPtr^.ox + 3;
    camY := GameVars.arenaPtr^.oy + 3;
  end;
  CbtMap.ScrollView(camX, camY, 255, 8);
  n := 0;
  accX := 0;
  accY := 0;
  repeat
    pixX := (startX - GameVars.arenaPtr^.ox) * 3 + accX;
    pixY := (startY - GameVars.arenaPtr^.oy) * 3 + accY;
    prevX := startX;
    prevY := startY;
    done := False;
    repeat
      if (pace > 0) or (pixX mod 3 = 0) or (pixY mod 3 = 0) then begin
        Blit.BlitTileClipped(pixX, pixY, frame, 5, GameVars.moveIconSheet, GameVars.viewImageBufferPtr);
        Blit.FlushView;
        Delay(pace);
        Blit.BlitTileClipped(pixX, pixY, 0, 0, GameVars.iconImageBufferPtr, GameVars.viewImageBufferPtr);
        Inc(frame);
        if frame >= frames then
          frame := 0;
      end;
      Inc(n);
      stepX := GameDefs.dirDX[steps[n]];
      stepY := GameDefs.dirDY[steps[n]];
      Inc(pixX, stepX);
      Inc(pixY, stepY);
      if (pixX < 0) or (pixX > 18) or (pixY < 0) or (pixY > 18) then
        done := True;
      if not done and (n < count) then begin
        Inc(accX, stepX);
        Inc(accY, stepY);
        if Abs(accX) = 3 then begin
          Inc(startX, Pathing.SignOf(accX));
          Inc(camX, Pathing.SignOf(accX));
          accX := 0;
        end;
        if Abs(accY) = 3 then begin
          Inc(startY, Pathing.SignOf(accY));
          Inc(camY, Pathing.SignOf(accY));
          accY := 0;
        end;
      end;
    until (n >= count) or done;
    if n < count then begin
      dirX := Pathing.SignOf(prevX - startX);
      dirY := Pathing.SignOf(prevY - startY);
      if dirX <> 0 then begin
        if startX >= GameVars.arenaPtr^.ox + 6 then
          camX := startX + 3
        else if startX <= GameVars.arenaPtr^.ox then
          camX := startX - 3;
      end;
      if dirY <> 0 then begin
        if startY >= GameVars.arenaPtr^.oy + 6 then
          camY := startY + 3
        else if startY <= GameVars.arenaPtr^.oy then
          camY := startY - 3;
      end;
      CbtMap.ScrollView(camX, camY, 255, 8);
    end else begin
      lastPass := True;
      if not CbtMap.ViewCoordsValid(endX - GameVars.arenaPtr^.ox, endY - GameVars.arenaPtr^.oy) then
        CbtMap.ScrollView(endX, endY, 3, 8);
      pixX := (endX - GameVars.arenaPtr^.ox) * 3;
      pixY := (endY - GameVars.arenaPtr^.oy) * 3;
      Blit.BlitTileClipped(pixX, pixY, frame, 5, GameVars.moveIconSheet, GameVars.viewImageBufferPtr);
      if pace > 0 then begin
        Blit.FlushView;
        Delay(pace);
        Blit.BlitTileClipped(pixX, pixY, 0, 0, GameVars.iconImageBufferPtr, GameVars.viewImageBufferPtr);
      end;
    end;
  until lastPass;
  Blit.FlushView;
end;

{ Show "<name> <text>" with the damage or effect flash: build the facings from icon cell 23 (damage) or 22 (effect),
  scroll the creature on screen if needed, play the sound, print, then flash the four facing frames at the creature's
  grid cell (gameDelay + 1 times for an effect, once for damage, which then pauses on the text delay). The effect's
  sound, the spells' own wherever it plays, and a spell's damage are of the Settings screen's Spell Effects kind (#854);
  other damage, a breath's or a touch's, follows the Sound setting alone.
  SoundDrv.SoundSetAutoStop(0) keeps the sound driver resident during the flash, then 10 restores per-sound cleanup. Out
  of combat it is just PrintNameString with a pause. }
procedure PrintNameStringAnim(creature: Types.PCharRecord; effect: Boolean; s: string);
var
  gx: ShortInt;
  gy: ShortInt;
  cell: Byte;
  j: Byte;
  i: Byte;
  reps: Byte;
  slot: Byte;
begin
  if GameVars.ifcState = C_IFC.COMBAT then begin
    SoundDrv.SoundSetAutoStop(0);
    if effect then
      cell := 22
    else
      cell := 23;
    CharDisp.BuildIconFacings(cell);
    if not CbtMap.CombatIconVisible(creature, 1) then
      CbtMap.ScrollView(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 3, 8);
    if effect then
      SoundDrv.SoundEffect(GameDefs.soundIds.combat[0], C_SOUND.GROUP_SPELL)
    else if GameVars.currentSpellBeing <> C_SPELL.NONE then
      SoundDrv.SoundEffect(GameDefs.soundIds.damage, C_SOUND.GROUP_SPELL)
    else
      SoundDrv.SoundCommand(GameDefs.soundIds.damage);
    CharDisp.PrintNameString(creature, s, 10, False);
    if effect then
      reps := GameVars.gameDelay
    else
      reps := 0;
    slot := CbtMap.CombatSlot(creature);
    { slot 0: not on the map, so there is no cell to flash }
    if slot > 0 then begin
      gx := CbtMap.gridX[slot] * 3;
      gy := CbtMap.gridY[slot] * 3;
      for i := 0 to reps do
        for j := 0 to 3 do begin
          Blit.BlitTileClipped(gx, gy, j, 5, GameVars.moveIconSheet, GameVars.viewImageBufferPtr);
          Blit.FlushView;
          Delay(70);
          Blit.BlitTileClipped(gx, gy, 0, 0, GameVars.iconImageBufferPtr, GameVars.viewImageBufferPtr);
        end;
    end;
    SoundDrv.SoundSetAutoStop(10);
    Blit.FlushView;
    if reps = 0 then
      TextRend.PauseOnly;
  end else
    CharDisp.PrintNameString(creature, s, 10, True);
end;

{ Announce that the creature is fully or partially healed, and refresh the party panel outside combat. }
procedure PrintHpRestoreMsg(creature: Types.PCharRecord);
var
  s: Types.TStr40;
begin
  if creature^.hpCur = creature^.hpMax then
    s := 'is fully healed'
  else
    s := 'is partially healed';
  CharDisp.PrintNameString(creature, s, 10, True);
  CharDisp.RedrawPartyOutOfCombat;
end;

procedure RedrawPartyOutOfCombat;
begin
  if GameVars.ifcState <> C_IFC.COMBAT then
    CharDisp.DisplayParty(GameVars.curChar);
end;

{ Draw the three standard noncombat windows (full screen minus the bottom line, message window, 3D/picture view), plus
  the picture inset border when asked. }
procedure DrawNoncombatWindows(inset: Boolean);
begin
  Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0, White, '');
  Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.MESSAGE_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0, White, '');
  Border.DrawWindow(1, 1, 15, 15, 0, White, '');
  if inset then
    Border.DrawWindow(3, 3, 13, 13, 0, White, '');
end;

{ Redraw the screen for the current interface state: the main-menu frame; the shop, temple or vault windows with the
  portrait; the camp picture, party and status line; the indoor or outdoor map view, party and status line; or the loot
  picture and party. }
procedure DisplayNoncombatInterface;
begin
  case GameVars.ifcState of
    C_IFC.MAIN_MENU: Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM,
                                       0, White, '');
    C_IFC.SHOP_TEMPLE, C_IFC.VAULT: begin
      CharDisp.DrawNoncombatWindows(True);
      Portrait.LoadPortraitBufs(currentPortraitHead, currentPortraitHead2);
      Portrait.DisplayPortraitBufs(3, 3, True);
    end;
    C_IFC.CAMPING: begin
      CharDisp.DrawNoncombatWindows(True);
      Portrait.LoadAnimation('PIC', 29, 0, GameVars.animData);
      { the campfire now, not only once an animating menu draws it: a plain prompt may come first (#666) }
      if GameVars.animData.current > 0 then
        Portrait.DisplayImageBuf(3, 3, True, GameVars.animData.frames[GameVars.animData.current].pic);
      CharDisp.DisplayParty(GameVars.curChar);
      CharDisp.PrintMiscInfo;
    end;
    C_IFC.INDOORS: begin
      CharDisp.DrawNoncombatWindows(True);
      MapView.DisplayMapView;
      CharDisp.DisplayParty(GameVars.curChar);
      CharDisp.PrintMiscInfo;
    end;
    C_IFC.OUTDOORS: begin
      CharDisp.DrawNoncombatWindows(False);
      MapView.DisplayMapView;
      CharDisp.DisplayParty(GameVars.curChar);
      CharDisp.PrintMiscInfo;
    end;
    C_IFC.LOOT: begin
      CharDisp.DrawNoncombatWindows(True);
      Portrait.LoadAnimation('PIC', 1, 0, GameVars.animData);
      CharDisp.DisplayParty(GameVars.curChar);
    end;
  end;
end;

{ Print the party-window status line on row 15 of the upper-right window: coordinates (omitted when the zone's noAutomap
  is set; above location type 1 they come from the zone-0 party position, +13 for type 3 and +26 for type 4), compass
  facing, the zero-padded HH:MM clock, and the camping or search tag. }
procedure PrintMiscInfo;
const
  { clockwise facing codes 0..7, starting at north }
  dirNames: array[C_DIR.NORTH..C_DIR.NORTHWEST] of string[2] = (
    'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW');
var
  x: Byte;
  y: Byte;
  hrs: string[2];
  mins: string[2];
  info: Types.TStr40;
begin
  info := '';
  x := GameVars.gMapX;
  y := GameVars.gMapY;
  if GameVars.gLocType > C_AREA.LOC_3D_MAP then begin
    x := GameVars.zone0^.partyX.lo;
    y := GameVars.zone0^.partyY.lo;
    if GameVars.gLocType = C_AREA.LOC_WILD_CENTRAL then
      Inc(x, 13);
    if GameVars.gLocType = C_AREA.LOC_WILD_EAST then
      Inc(x, 26);
  end;
  hrs := StrUtil.ZeroPad2(GameVars.zone0^.clock.hour);
  { A turn is ten minutes and the minute counter rolls over at ten, so turn * 10 + minute is the minute of the hour (see
    GameDefs.unitScale). }
  mins := StrUtil.ZeroPad2(10 * GameVars.zone0^.clock.turn + GameVars.zone0^.clock.minute);
  if GameVars.zone0^.noAutomap = 0 then
    info := StrUtil.NumStr(x) + ',' + StrUtil.NumStr(y) + ' ';
  info := info + dirNames[GameVars.gFacing] + ' ';
  info := info + hrs + ':' + mins;
  { the STING trace log is on (Ctrl-L), as Curse shows it }
  if GameVars.debugTraceEnabled then
    info := info + '*';
  if GameVars.ifcState = C_IFC.CAMPING then
    info := info + ' camping'
  else if GameVars.zone1^[C_GBVM.SEARCH_FLAGS] and 1 > 0 then
    info := info + ' search';
  Border.ClearBox(17, 15, 38, 15);
  TextRend.DisplayString(17, 15, LightGreen, info);
end;

{ Switch to the outdoor interface and draw it: the wilderness windows and map views, status line and party. }
procedure DisplayWildernessInterface;
begin
  GameVars.ifcState := C_IFC.OUTDOORS;
  Wilds.DrawWildWindows;
  MapView.DisplayMapView;
  MapView.DisplayWildMapView;
  CharDisp.PrintMiscInfo;
  CharDisp.DisplayParty(GameVars.curChar);
end;

{ Draw the combat screen: combat palette, the two combat windows, the cleared bottom rows, and a forced rebuild of the
  combat view centered on its current origin + 3. }
procedure DisplayCombatInterface;
begin
  CbtMap.SetCombatPalette;
  Border.DrawWindow(1, 1, 21, 21, 0, Black, '');
  Border.DrawWindow(23, 1, 38, 21, 0, Black, '');
  Border.ClearBox(0, 23, 39, 24);
  CbtMap.ScrollView(GameVars.arenaPtr^.ox + 3, GameVars.arenaPtr^.oy + 3, 255, 8);
end;

{ Let the player pick a character on the horizontal menu, starting from sel: End and Home (also keypad 1 and 7) cycle
  next/previous through the creature list. Return, Exit and Select leave the loop, Exit with sel nil. With addExit,
  Escape (which MenuHorizontal returns as C_KEYS.NONE) leaves like Exit; without it there is no way out but choosing,
  and Escape is ignored (a script's WHO needs a character). Does not set the current character. }
procedure SelectChar(query: Types.TStr40; addExit: Boolean; var sel: Types.PCharRecord);
var
  ch: Char;
  ext: Boolean;
  anim: Boolean;
  p: Types.PCharRecord;
  exitStr: Types.TStr40;
begin
  ch := ' ';
  exitStr := '';
  if addExit then
    exitStr := ' Exit';
  { open on Select: the highlight is shared by every menu, and Enter takes it }
  GameVars.horizChoice := 1;
  while not ((ch in [C_KEYS.ENTER, 'E', 'S']) or ((ch = C_KEYS.NONE) and addExit)) do
  begin
    CharDisp.DisplayParty(sel);
    if (GameVars.ifcState = C_IFC.CAMPING) or (GameVars.ifcState = C_IFC.LOOT) then
      anim := True
    else
      anim := False;
    ch := MenuCore.MenuHorizontal(query + ' ', 'Select' + exitStr, LightMagenta, LightGreen, White, True,
                                  anim, ext);
    p := sel;
    if ext then
      case ch of
        { End: next character, wrapping to the head }
        C_KEYS.END_KEY: p := Party.NextCreature(p);
        { Home: previous character, wrapping to the tail }
        C_KEYS.HOME: p := Party.PrevCreature(sel);
      end else if ((ch = 'E') or (ch = C_KEYS.NONE)) and addExit then
      p := nil;
    sel := p;
  end;
end;

procedure PrintItemLabel(item: Types.PItemRec; col, row: Byte);
begin
  CharHlp.ItemLabel(item, False);
  TextRend.DisplayString(col, row, LightGreen, item^.name);
end;

procedure ShowFault(msg: Types.TStr40);
begin
  TextRend.DisplayAndPause(Yellow, msg);
end;

begin
  { Turbo Pascal clears no variable }
  currentPortraitHead := 0;
  currentPortraitHead2 := 0;
end.

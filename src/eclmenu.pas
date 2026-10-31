{ ECL variable decoding, game-memory access, script menus, comparisons and subroutine calls. }
{$O+,F+}
{$I COMPILER.INC}
unit EclMenu;

interface

uses Types;

var
  { eq, ne, lt, gt, le, ge; cleared together by FillChar }
  cmpFlags: array[0..5] of Boolean;
  { Current icon animation slot. }
  iconAnimId: Byte;
  { Monster display flags used by the ECL VM; EclVm and EclMenu clear both together }
  monsterFlags: Types.TMonFlags;
  { picture-drawn flag: gates ECL animation }
  picDrawn: Boolean;
  { Set when EclProtection moves its text into the 3D box (after a CLEAR BOX); EclExit then redraws the borders and
    clears it }
  protTextShown: Byte;

{ Reset ECL state, read the script entry addresses (C_ECL.ENTRY_*) from the header at the script's start
  (C_GBVM.SCRIPT_FIRST) and, unless a saved game was just loaded, zero the area's cells (C_GBVM.AREA_CELLS_FIRST..LAST
  and AREA_TEMPS_FIRST..LAST) }
procedure EclInit;

{ Load ECL script block scriptId from ECL<disk>.dax; a block missing from that disk is taken from the first disk that
  has it, which becomes current, and a block on no disk stops the game with a message }
procedure LoadEclScript(scriptId: Byte);

{ Allocate + load creature id, returning the record and its inventory/effects list heads }
procedure InitCreature(id: Byte; var creature: Types.PCharRecord; var inv: Types.PItemRec;
                       var effect: Types.PEffectRec);

{ Farthest distance (0..2) monsters may appear in front of the party: 2 when view3dFlag = 0 (also stored in
  C_GBVM.MONSTER_DIST), else the open cells ahead before the first wall, at most 2 }
function MaxMonsterDist(x, y, facing: Byte): Byte;

{ Load and show the portrait with this head and body, remembering both for later redraws. }
procedure DisplayPortrait(headId, bodyId: Byte);

{ Draw monster sprite SPRIT sprId at distance dist + 1 (2 when gLocType <> 1) until a close-up is shown; at dist 0 in
  gLocType 1, show the close-up: PIC picId, or the portrait with head C_GBVM.PIC_LOADING and body picId when that byte
  is not 255. flags: [0] sprite loaded, [1] close-up shown }
procedure DisplayMonster(sprId, picId, dist: Byte; var flags: Types.TMonFlags);

{ Horizontal '~'-hotkey menu; extended keys switch the current character. Returns the 0-based index of the pressed
  hotkey, 0 for Enter (only when enterOk) and 255 for a letter or digit that is not a hotkey }
function MenuHorizontalCharacterSelect(query: Types.TStr40; menu: String; qCol, mCol, hlCol: Byte;
                                       enterOk, animate: Boolean): Byte;

{ Set the six comparison flags from s1 and s2. }
procedure EclCompareStr(s1, s2: String);

{ Set the six comparison flags from v1 and v2. }
procedure EclCompareInt(v1, v2: Word);

procedure EclGosub(varIdx: Byte);

{ Disable every creature whose name differs from the current character's; mirror <> 0 then appends a hostile ROLF
  clone }
procedure CharFightsAlone(mirror: ShortInt);

{ Script CALL C_GBVM.CALL_MOVE_FORWARD: step the party forward one cell with 0..15 wraparound, then refresh the event
  and wall bytes }
procedure EclMoveForward;

{ Scale all 7 coin slots by fraction, truncating }
procedure RobMoney(fraction: Real; creature: Types.PCharRecord);

{ Chance% per item to steal it; heavy items (weight > 255 / > 24 coins) reduce the chance }
procedure RobItems(chance: Byte; creature: Types.PCharRecord);

{ Highest/lowest movement in GameVars.creatureList, as Haste and Slow make it (CharHlp.HasteSlowRate); 0 and 255 for an
  empty list }
procedure MoveExtremes(var hiMove, loMove: Byte);

{ Damage message + damage + party panel refresh; dead creatures are skipped }
procedure EclInflictDamage(dmg: Word; creature: Types.PCharRecord);

{ Load creature id from MON<disk>CHA/SPC/ITM.dax (a missing or short CHA record exits the game); nil the list pointers,
  derive iconSize from race, roll random icon colours (slot 4, hair, is fixed at $C4), convert effects/items to lists,
  ignoring a trailing part record, then call the effect handler of each readied special item (special > $7F) but an
  aligned weapon or a boulder. }
procedure LoadCreatureData(id: Byte; creature: Types.PCharRecord);

{ GetMem + LoadCreatureData + random portrait head and body by gender and a randomly picked class + AddCharToParty +
  LoadCharIconAnim(True). No-op when the party already has 8 members (C_GBVM.PARTY_SIZE > 7). }
procedure AddCreatureToParty(id: Byte);

implementation

uses Crt, C_AREA, C_ECL, C_NPC, C_MSG, GameVars, MapView, SaveLoad, C_EFFECT, C_KEYS, C_STATUS, C_GBVM, C_DIR,
  C_MONEY, CharHlp, DaxIo, FxEngine, GameIo, MapTiles, MenuCore, Portrait, TextRend, View3D, EclVars, CharDisp, Party,
  C_RACE, C_LEVEL, StrUtil, Dice, DiskRec{$IFDEF FPC}, TpRand{$ENDIF};

var
  { Picture id last shown, copied from C_GBVM.PIC_LOADING }
  picIdShown: Byte;

{ A just-loaded save (loadedSave <> 0) keeps its script words; the flag is cleared instead }
procedure EclInit;
var
  i: Word;
begin
  GameVars.eclGraphics := False;
  protTextShown := 0;
  GameVars.dumpCr6C00 := False;
  GameVars.dumpCr6B00 := False;
  GameVars.wallColorSel := 65;
  GameVars.ceilFloorColorSel := 9;
  GameVars.picRegionW := True;
  FillChar(monsterFlags, SizeOf(monsterFlags), 0);
  iconAnimId := MapTiles.FIRST_MONSTER_ICON;
  GameVars.eclIp := C_GBVM.SCRIPT_FIRST;
  GameVars.scriptReturnStack := nil;
  GameVars.prevScriptReturnStack := nil;
  FillChar(cmpFlags, SizeOf(cmpFlags), 0);
  { No portrait head (255), so DisplayMonster shows the PIC close-up }
  GameVars.zone1^[C_GBVM.PIC_LOADING] := 255;
  { rest interruption }
  GameVars.zone1^[C_GBVM.REST_SAFE_TIME] := 0;
  GameVars.zone1^[C_GBVM.REST_INTERRUPT_PCT] := 0;
  GameVars.zone0^.antimagic := 0;
  for i := 1 to C_ECL.ENTRY_COUNT do begin
    EclVars.LoadEclVars(1);
    GameVars.scriptEntryAddrs[i] := EclVars.CombineBytesToWord(GameVars.varLo[1], GameVars.varHi[1]);
  end;
  { Select the 3D view (MapView treats view3dFlag <> 0 as location type 1) }
  GameVars.zone0^.view3dFlag := 1;
  if GameVars.loadedSave = 0 then begin
    for i := C_GBVM.AREA_CELLS_FIRST to C_GBVM.AREA_CELLS_LAST do
      GameVars.zone0^.words[i] := 0;
    for i := C_GBVM.AREA_TEMPS_FIRST to C_GBVM.AREA_TEMPS_LAST do
      GameVars.zone1^[i] := 0;
  end else
    GameVars.loadedSave := 0;
end;

{ Clears the script zone first; the first 2 bytes of the block are skipped, and no more than the zone holds is copied.
  The original retried the current disk forever when the block was not there, which hung at "Loading...Please Wait".
  With the merged ECL.DAX in use, the disk still moves to the one whose own ECL archive holds the script, as it does
  with the per-disk archives. A current disk outside 1..8 has no archive or insert-disk prompt, so disk 1 is taken
  first. }
procedure LoadEclScript(scriptId: Byte);
var
  s: String[3];
  sizeRead: Word;
  data: Types.PByteArr;
  disk: Byte;
  n: Word;
  found: Boolean;
begin
  FillChar(GameVars.zone3^, SizeOf(Types.TZone3), 0);
  GameVars.suppressDiskPrompt := False;
  TextRend.ClearBottomLine;
  TextRend.DisplayString(0, 24, White, 'Loading...Please Wait');
  if not (GameVars.diskIndex in [1..Types.LAST_DISK]) then
    DaxIo.PushState(1);
  Str(GameVars.diskIndex, s);
  { the merged ECL.DAX holds every disk's scripts, so the search below would not run }
  if DaxIo.ArchiveName('ECL' + s) <> 'ECL' + s then
    if not DaxIo.DiskHasBlock('ECL' + s, scriptId) then begin
      disk := 1;
      found := False;
      while (disk <= Types.LAST_DISK) and not found do begin
        Str(disk, s);
        found := DaxIo.DiskHasBlock('ECL' + s, scriptId);
        if found then
          DaxIo.PushState(disk);
        Inc(disk);
      end;
      Str(GameVars.diskIndex, s);
    end;
  DaxIo.LoadDax('ECL' + s, '.dax', scriptId, sizeRead, data);
  if sizeRead < 2 then begin
    { not on this disk: a script changed area without setting the disk first (Stojanow Gate's flee); take the first disk
      that has the block, without the insert-disk prompt }
    GameVars.suppressDiskPrompt := True;
    disk := 1;
    while (sizeRead < 2) and (disk <= Types.LAST_DISK) do begin
      if disk <> GameVars.diskIndex then begin
        Str(disk, s);
        DaxIo.LoadDax('ECL' + s, '.dax', scriptId, sizeRead, data);
        if sizeRead >= 2 then
          DaxIo.PushState(disk);
      end;
      Inc(disk);
    end;
    GameVars.suppressDiskPrompt := False;
    if sizeRead < 2 then begin
      Str(scriptId, s);
      DaxIo.PromptBox(Yellow, 'Script area ' + s + ' is missing');
      GameIo.ExitGame;
    end;
  end;
  n := sizeRead - 2;
  if n > SizeOf(Types.TZone3) then
    n := SizeOf(Types.TZone3);
  Move(data^[2], GameVars.zone3^, n);
  FreeMem(data, sizeRead);
  TextRend.ClearBottomLine;
end;

procedure InitCreature(id: Byte; var creature: Types.PCharRecord; var inv: Types.PItemRec;
                       var effect: Types.PEffectRec);
begin
  creature := nil;
  GetMem(creature, SizeOf(Types.TCharRecord));
  EclMenu.LoadCreatureData(id, creature);
  inv := creature^.itemsAddr;
  effect := creature^.effectsAddr;
end;

{ Count open cells ahead of (x, y) in facing, stopping at a wall or at 2 }
function MaxMonsterDist(x, y, facing: Byte): Byte;
var
  blocked: Boolean;
  dist: Byte;
begin
  dist := 0;
  blocked := False;
  MaxMonsterDist := 0;
  if GameVars.zone0^.view3dFlag = 0 then begin
    MaxMonsterDist := 2;
    GameVars.zone1^[C_GBVM.MONSTER_DIST] := 2;
  end else
    while (dist < 2) and (not blocked) do begin
      if View3D.GetWallType(x, y, facing) = 0 then begin
        Inc(dist);
        MaxMonsterDist := dist;
        case facing of
          C_DIR.NORTH: Dec(y);
          C_DIR.EAST: Inc(x);
          C_DIR.SOUTH: Inc(y);
          C_DIR.WEST: Dec(x);
        end;
      end else
        blocked := True;
    end;
end;

procedure DisplayPortrait(headId, bodyId: Byte);
begin
  picDrawn := False;
  CharDisp.portraitHeadId := headId;
  CharDisp.portraitBodyId := bodyId;
  Portrait.LoadPortraitBufs(headId, bodyId);
  Portrait.DisplayPortraitBufs(3, 3, True);
end;

{ Select the monster sprite with sprId and its close-up picture with picId. }
procedure DisplayMonster(sprId, picId, dist: Byte; var flags: Types.TMonFlags);
var
  d3: Byte;
begin
  if (not flags[1]) and flags[0] then
    MapView.DisplayMapView;
  d3 := dist + 1;
  if not flags[1] then begin
    if not flags[0] then begin
      if GameVars.automapOn then begin
        GameVars.automapOn := False;
        MapView.DisplayMapView;
      end;
      Portrait.LoadAnimation('SPRIT', sprId, 1, GameVars.animData);
      flags[0] := True;
      GameVars.sprShown := True;
    end;
    if GameVars.gLocType = C_AREA.LOC_3D_MAP then
      Portrait.Show3DSprite(d3, GameVars.animData)
    else
      Portrait.Show3DSprite(2, GameVars.animData);
  end;
  if flags[1] then
    if picIdShown = GameVars.zone1^[C_GBVM.PIC_LOADING] then
      Exit;
  if dist <> 0 then Exit;
  if GameVars.gLocType <> C_AREA.LOC_3D_MAP then Exit;
  if (GameVars.inEncMenu <> 0) and ((GameVars.portraitsAll = 0) or (GameVars.monsterPics = 0)) then Exit;
  picIdShown := Byte(GameVars.zone1^[C_GBVM.PIC_LOADING]);
  GameVars.eclGraphics := True;
  if GameVars.zone1^[C_GBVM.PIC_LOADING] = 255 then begin
    Portrait.LoadAnimation('PIC', picId, 0, GameVars.animData);
    flags[1] := True;
    Portrait.DisplayImageBuf(3, 3, True, GameVars.animData.frames[1].pic);
  end else begin
    EclMenu.DisplayPortrait(Byte(GameVars.zone1^[C_GBVM.PIC_LOADING]), picId);
    flags[1] := True;
    picDrawn := False;
  end;
end;

{ Horizontal menu with character selection; query is limited to 40 characters and menu text to 255. Each script menu
  starts with its first option highlighted, so Enter never takes a highlight another menu left behind; switching
  characters keeps the highlight. }
function MenuHorizontalCharacterSelect(query: Types.TStr40; menu: String; qCol, mCol, hlCol: Byte;
                                       enterOk, animate: Boolean): Byte;
var
  opts: String;
  idx: Byte;
  ch: Char;
  ext: Boolean;
begin
  StrUtil.MenuToOptions(menu, opts);
  GameVars.horizChoice := 1;
  repeat
    ch := MenuCore.MenuHorizontal(query, menu, qCol, mCol, hlCol, True, animate, ext);
    if ext then begin
      Party.SelectPrevNextChar(ch);
      CharDisp.DisplayParty(GameVars.curChar);
      ch := C_KEYS.NONE;
    end;
  until (ch in ['0'..'9', 'A'..'Z']) or ((ch = C_KEYS.ENTER) and enterOk);
  case ch of
    C_KEYS.ENTER: MenuHorizontalCharacterSelect := 0;
  else begin
    idx := 1;
    while (idx <= Length(opts)) and (opts[idx] <> ch) do
      Inc(idx);
    if idx <= Length(opts) then
      MenuHorizontalCharacterSelect := idx - 1
    else
      MenuHorizontalCharacterSelect := 255;
  end;
  end;
end;

{ Set each of the six comparison flags: equal, not equal, less, greater, less or equal, greater or equal }
procedure EclCompareStr(s1, s2: String);
begin
  FillChar(cmpFlags, SizeOf(cmpFlags), 0);
  if s1 = s2 then cmpFlags[0] := True;
  if s1 <> s2 then cmpFlags[1] := True;
  if s1 < s2 then cmpFlags[2] := True;
  if s1 > s2 then cmpFlags[3] := True;
  if s1 <= s2 then cmpFlags[4] := True;
  if s1 >= s2 then cmpFlags[5] := True;
end;

procedure EclCompareInt(v1, v2: Word);
begin
  FillChar(cmpFlags, SizeOf(cmpFlags), 0);
  if v1 = v2 then cmpFlags[0] := True;
  if v1 <> v2 then cmpFlags[1] := True;
  if v1 < v2 then cmpFlags[2] := True;
  if v1 > v2 then cmpFlags[3] := True;
  if v1 <= v2 then cmpFlags[4] := True;
  if v1 >= v2 then cmpFlags[5] := True;
end;

{ Push IP on the ECL return stack, then jump to the address word in variable varIdx }
procedure EclGosub(varIdx: Byte);
begin
  GameVars.prevScriptReturnStack := GameVars.scriptReturnStack;
  GetMem(GameVars.scriptReturnStack, SizeOf(Types.TEclRet));
  GameVars.scriptReturnStack^.next := GameVars.prevScriptReturnStack;
  GameVars.scriptReturnStack^.addr := GameVars.eclIp;
  GameVars.eclIp := EclVars.CombineBytesToWord(GameVars.varLo[varIdx], GameVars.varHi[varIdx]);
end;

{ Step with 0..15 wraparound, then refresh the event and wall-ahead bytes for the new cell }
procedure EclMoveForward;
begin
  case GameVars.gFacing of
    C_DIR.NORTH: if GameVars.gMapY > 0 then Dec(GameVars.gMapY) else GameVars.gMapY := 15;
    C_DIR.EAST: if GameVars.gMapX < 15 then Inc(GameVars.gMapX) else GameVars.gMapX := 0;
    C_DIR.SOUTH: if GameVars.gMapY < 15 then Inc(GameVars.gMapY) else GameVars.gMapY := 0;
    C_DIR.WEST: if GameVars.gMapX > 0 then Dec(GameVars.gMapX) else GameVars.gMapX := 15;
  end;
  GameVars.eventAtCell := View3D.GetMapEvent(GameVars.gMapX, GameVars.gMapY);
  GameVars.wallAhead := View3D.GetWallType(GameVars.gMapX, GameVars.gMapY, GameVars.gFacing);
end;

{ Sets duelFlag and C_GBVM.MIRROR_DUEL. A mirror duel appends a copy of the current character as hostile "ROLF" with the
  CPIC 11 icon, in the next monster icon slot or, when they are used up, the last (items fully cloned, but prepended, so
  the clone's list is reversed; effects not cloned) }
procedure CharFightsAlone(mirror: ShortInt);
var
  p: Types.PCharRecord;
  clone: Types.PCharRecord;
  cur: Types.PCharRecord;
  srcIt: Types.PItemRec;
  { the clone's combat icon slot }
  slot: Byte;
begin
  GameVars.duelFlag := True;
  GameVars.zone1^[C_GBVM.MIRROR_DUEL] := mirror;
  cur := GameVars.curChar;
  p := GameVars.creatureList;
  while p <> nil do begin
    if p^.name <> cur^.name then
      p^.enabled := 0;
    p := p^.nextCharAddr;
  end;
  if mirror = 0 then Exit;
  { after a fifth monster kind the clone shares the last monster slot; SSI loaded it over the first combat sprite
    (#725) }
  slot := iconAnimId;
  if slot > MapTiles.LAST_MONSTER_ICON then
    slot := MapTiles.LAST_MONSTER_ICON;
  MapTiles.LoadIconAnim('CPIC', 11, slot);
  p := Party.LastCreature;
  GetMem(clone, SizeOf(Types.TCharRecord));
  clone^ := cur^;
  clone^.enabled := 1;
  clone^.nextCharAddr := nil;
  clone^.name := 'ROLF';
  clone^.quickfight := 1;
  clone^.hostile := 1;
  clone^.npc := C_NPC.ANIMATED_NPC;
  clone^.orderNumber := slot;
  clone^.effectsAddr := nil;
  clone^.itemsAddr := nil;
  p^.nextCharAddr := clone;
  p := p^.nextCharAddr;
  srcIt := cur^.itemsAddr;
  while srcIt <> nil do begin
    CharHlp.PrependItemCopy(p^.itemsAddr, srcIt);
    srcIt := srcIt^.next;
  end;
end;

procedure RobMoney(fraction: Real; creature: Types.PCharRecord);
begin
  creature^.coins[C_MONEY.COPPER] := Trunc(creature^.coins[C_MONEY.COPPER] * fraction);
  creature^.coins[C_MONEY.SILVER] := Trunc(creature^.coins[C_MONEY.SILVER] * fraction);
  creature^.coins[C_MONEY.ELECTRUM] := Trunc(creature^.coins[C_MONEY.ELECTRUM] * fraction);
  creature^.coins[C_MONEY.GOLD] := Trunc(creature^.coins[C_MONEY.GOLD] * fraction);
  creature^.coins[C_MONEY.PLATINUM] := Trunc(creature^.coins[C_MONEY.PLATINUM] * fraction);
  creature^.coins[C_MONEY.GEMS] := Trunc(creature^.coins[C_MONEY.GEMS] * fraction);
  creature^.coins[C_MONEY.JEWELRY] := Trunc(creature^.coins[C_MONEY.JEWELRY] * fraction);
end;

{ Each item is taken on a 1d100 roll within its own chance (CharHlp.TheftChance: heavy items are harder to steal; SSI
  took the penalties off chance itself, so they accumulated over the walk, POR-0163). A readied item is unreadied before
  it is taken, so a ring's, cloak's or gauntlets' effect goes with it, as FxEngine.ToggleReadyItem does. }
procedure RobItems(chance: Byte; creature: Types.PCharRecord);
var
  roll: Byte;
  item: Types.PItemRec;
  nxt: Types.PItemRec;
begin
  item := creature^.itemsAddr;
  while item <> nil do begin
    roll := Dice.RollDice(1, 100);
    nxt := item^.next;
    if roll <= CharHlp.TheftChance(chance, item^.weight) then begin
      if item^.equipped <> 0 then begin
        item^.equipped := 0;
        if item^.special > $7F then
          FxEngine.CallEffectHandler(item^.special, creature, item, True);
      end;
      CharHlp.RemoveItem(creature, item);
    end;
    item := nxt;
  end;
end;

procedure MoveExtremes(var hiMove, loMove: Byte);
var
  p: Types.PCharRecord;
  m: Byte;
begin
  { only the adjusted values count: SSI started from the first member's unadjusted movement, so an all-hasted party's
    slowest, or a slowed first member's fastest, stayed at that member's normal rate (#758) }
  hiMove := 0;
  loMove := 255;
  p := GameVars.creatureList;
  while p <> nil do begin
    m := CharHlp.HasteSlowRate(p, p^.movementCur);
    if m > hiMove then hiMove := m;
    if m < loMove then loMove := m;
    p := p^.nextCharAddr;
  end;
end;

{ "dies" when dmg > hpCur + 10, else the hit message; then apply the damage, clear the panel at (17,1)-(38,15) and
  redraw the party. A dead, stoned or gone character is left alone, with no message. }
procedure EclInflictDamage(dmg: Word; creature: Types.PCharRecord);
var
  msg: String;
  pause: Boolean;
begin
  { a dead, stoned or gone character takes no damage, as in CharHlp.InflictDamage }
  if creature^.status in [C_STATUS.DEAD_STATUS, C_STATUS.STONED, C_STATUS.GONE] then Exit;
  if creature^.hpCur + 10 < dmg then
    msg := '  ' + creature^.name + ' dies. '
  else
    msg := '  ' + creature^.name + ' is hit FOR ' + StrUtil.NumStr(dmg) + ' points of Damage.';
  if GameVars.curRow > C_MSG.TEXT_BOTTOM then begin
    GameVars.curRow := C_MSG.MESSAGE_TOP;
    pause := True;
    TextRend.DisplayAndPause(White, C_MSG.CONTINUE_PROMPT);
  end else
    pause := False;
  GameVars.curCol := C_MSG.TEXT_RIGHT;
  TextRend.ShowMessage(White, pause, msg);
  CharHlp.InflictDamage(creature, dmg);
  TextRend.ClearRect(17, 1, 38, 15);
  CharDisp.DisplayParty(GameVars.curChar);
end;

procedure LoadCreatureData(id: Byte; creature: Types.PCharRecord);
const
  { the displacer beast's disk and MON<disk>CHA block }
  DISPLACER_DISK = 7;
  DISPLACER_BEAST = 68;
var
  size: Word;
  data: Types.PByteArr;
  offset: Word;
  item: Types.PItemRec;
  effect: Types.PEffectRec;
  numStr: String[1];
  i: Byte;
  roll: Byte;
begin
  Str(GameVars.diskIndex, numStr);
  DaxIo.LoadDax('MON' + numStr + 'CHA', '.dax', id, size, data);
  if size < DiskRec.CHAR_DISK_BYTES then begin
    TextRend.DisplayAndPause(White, 'Unable to load monster');
    GameIo.ExitGame;
  end;
  DiskRec.CharFromDisk(data^, creature^);
  with creature^ do begin
    itemsAddr := nil;
    effectsAddr := nil;
    nextCharAddr := nil;
    combatAddr := nil;
    case race of
      C_RACE.DWARF, C_RACE.GNOME, C_RACE.HALFLING: iconSize := 1;
      C_RACE.ELF, C_RACE.HALF_ELF, C_RACE.HALF_ORC, C_RACE.HUMAN: iconSize := 2;
    end;
    for i := 1 to 6 do
      if i = 4 then
        iconColors1[i] := $C4
      else begin
        roll := Dice.RollDice(1, 6);
        iconColors1[i] := roll + (roll + 8) shl 4;
      end;
  end;
  FreeMem(data, size);
  GameVars.suppressDiskPrompt := True;
  DaxIo.LoadDax('MON' + numStr + 'SPC', '.dax', id, size, data);
  if size <> 0 then begin
    if size >= DiskRec.EFFECT_DISK_BYTES then begin
      offset := 0;
      GetMem(creature^.effectsAddr, SizeOf(Types.TEffectRec));
      effect := creature^.effectsAddr;
      repeat
        DiskRec.EffectFromDisk(data^[offset], effect^);
        effect^.next := nil;
        Inc(offset, DiskRec.EFFECT_DISK_BYTES);
        if size - offset >= DiskRec.EFFECT_DISK_BYTES then begin
          GetMem(effect^.next, SizeOf(Types.TEffectRec));
          effect := effect^.next;
        end;
      until size - offset < DiskRec.EFFECT_DISK_BYTES;
    end;
    FreeMem(data, size);
  end;
  { SSI's data gives the displacer beast (MON7CHA block 68, the game's only one) no MON7SPC block, so it never had
    effect 89, its displacement: the first attack on it each combat misses. DataBld patches only blocks that are there,
    so the effect is granted here (#1136). }
  if (GameVars.diskIndex = DISPLACER_DISK) and (id = DISPLACER_BEAST)
     and not CharHlp.HasEffect(creature, C_EFFECT.DISPLACED, effect) then
    FxEngine.AddEffect(creature, C_EFFECT.DISPLACED, 0, 0, False);
  DaxIo.LoadDax('MON' + numStr + 'ITM', '.dax', id, size, data);
  if size <> 0 then begin
    if size >= DiskRec.ITEM_DISK_BYTES then begin
      offset := 0;
      GetMem(creature^.itemsAddr, SizeOf(Types.TItemRec));
      item := creature^.itemsAddr;
      repeat
        DiskRec.ItemFromDisk(data^[offset], item^);
        item^.next := nil;
        Inc(offset, DiskRec.ITEM_DISK_BYTES);
        if size - offset >= DiskRec.ITEM_DISK_BYTES then begin
          GetMem(item^.next, SizeOf(Types.TItemRec));
          item := item^.next;
        end;
      until size - offset < DiskRec.ITEM_DISK_BYTES;
    end;
    FreeMem(data, size);
  end;
  GameVars.suppressDiskPrompt := False;
  { the readied special items take effect, as when readied (FxEngine.ToggleReadyItem): SSI skipped this, and a monster
    never had the displacement, Strength or fire resistance of the cloak, gauntlets or ring it wore (#747). An aligned
    weapon's and a boulder's handlers only test whether the creature may ready them, shocking it or printing a message
    when not: a monster comes armed as its data has it (#788). }
  item := creature^.itemsAddr;
  while item <> nil do begin
    if (item^.equipped <> 0) and (item^.special > $7F)
       and not (item^.special in [C_EFFECT.ALIGNED_WEAPON, C_EFFECT.BOULDER]) then
      FxEngine.CallEffectHandler(item^.special, creature, item, False);
    item := item^.next;
  end;
end;

procedure AddCreatureToParty(id: Byte);
const
  { portrait-head selectors indexed by gender (male, female) and a 1d8 roll }
  npcPortraitHeads: array[0..1, 1..8] of Byte = (
    (1, 2, 3, 4, 5, 8, 11, 12),
    (6, 7, 9, 10, 13, 14, 6, 7));
  { cleric portrait-body selectors indexed by gender (male, female) and a 1d5 roll }
  npcClericBodies: array[0..1, 1..5] of Byte = (
    (2, 4, 2, 4, 2),
    (2, 4, 8, 2, 4));
  { fighter portrait-body selectors, also the fallback for classes other than cleric, magic-user and thief; indexed by
    gender (male, female) and a 1d5 roll }
  npcFighterBodies: array[0..1, 1..5] of Byte = (
    (1, 3, 4, 5, 6),
    (7, 9, 11, 7, 9));
  { magic-user portrait-body selectors indexed by gender (male, female) and a 1d5 roll }
  npcMageBodies: array[0..1, 1..5] of Byte = (
    (2, 2, 2, 2, 2),
    (8, 10, 12, 8, 10));
  { thief portrait-body selectors indexed by gender (male, female) and a 1d5 roll }
  npcThiefBodies: array[0..1, 1..5] of Byte = (
    (6, 6, 6, 6, 6),
    (8, 10, 8, 10, 8));
var
  creature: Types.PCharRecord;
  cnt: Byte;
  i: ShortInt;
  classes: array[1..4] of Byte;
begin
  if GameVars.zone1^[C_GBVM.PARTY_SIZE] >= Types.MAX_PARTY then Exit;
  GetMem(creature, SizeOf(Types.TCharRecord));
  EclMenu.LoadCreatureData(id, creature);
  with creature^ do begin
    randByte := Random(256);
    cnt := 0;
    { classes holds 4; shipped monsters have at most 4 class levels set, and none a monk's }
    for i := C_LEVEL.CLERIC to C_LEVEL.THIEF do
      if (classLevels[i] > 0) and (cnt < 4) then begin
        Inc(cnt);
        classes[cnt] := i;
      end;
    if cnt = 0 then begin
      cnt := 1;
      classes[cnt] := C_LEVEL.FIGHTER;
    end;
    cnt := Dice.RollDice(1, cnt);
    case classes[cnt] of
      C_LEVEL.CLERIC: portraitBody := npcClericBodies[genderSp, Dice.RollDice(1, 5)];
      C_LEVEL.MAGE: portraitBody := npcMageBodies[genderSp, Dice.RollDice(1, 5)];
      C_LEVEL.THIEF: portraitBody := npcThiefBodies[genderSp, Dice.RollDice(1, 5)];
      else portraitBody := npcFighterBodies[genderSp, Dice.RollDice(1, 5)];
    end;
    portraitHead := npcPortraitHeads[genderSp, Dice.RollDice(1, 8)];
  end;
  SaveLoad.AddCharToParty(creature);
  SaveLoad.LoadCharIconAnim(True);
end;

begin
  { Turbo Pascal clears no variable }
  FillChar(cmpFlags, SizeOf(cmpFlags), 0);
  iconAnimId := 0;
  FillChar(monsterFlags, SizeOf(monsterFlags), 0);
  picDrawn := False;
  protTextShown := 0;
  picIdShown := 0;
end.

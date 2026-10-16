{ ECL variable decoding, game-memory access, script menus, comparisons and subroutine calls. }
{$O+,F+}
unit EclMenu;

interface

uses Types;

{ Reset ECL state, read the five script entry addresses from the header at $9900 and, unless a saved game was just
  loaded, zero GBVM $4A00..$4A1F and $6E79..$6E82 }
procedure EclInit;

{ Load ECL script block scriptId from ECL<disk>.dax; a block missing from that disk is taken from the first disk that
  has it, which becomes current, and a block on no disk stops the game with a message }
procedure LoadEclScript(scriptId: Byte);

{ Allocate + load creature id, returning the record and its inventory/effects list heads }
procedure InitCreature(id: Byte; var creature: Types.PCharRecord; var inv: Types.PItemRec;
                       var effect: Types.PEffectRec);

{ Farthest distance (0..2) monsters may appear in front of the party: 2 when view3dFlag = 0 (also stored in
  C_Gbvm.MONSTER_DIST), else the open cells ahead before the first wall, at most 2 }
function MaxMonsterDist(x, y, facing: Byte): Byte;

{ Load and show the portrait with this head and body, remembering both for later redraws. }
procedure DisplayPortrait(headId, bodyId: Byte);

{ Draw monster sprite SPRIT sprId at distance dist + 1 (2 when gLocType <> 1) until a close-up is shown; at dist 0 in
  gLocType 1, show the close-up: PIC picId, or the portrait with head C_Gbvm.PIC_LOADING and body picId when that byte
  is not 255. flags: [0] sprite loaded, [1] close-up shown }
procedure DisplayMonster(sprId, picId, dist: Byte; var flags: Types.TMonFlags);

{ Horizontal '~'-hotkey menu; extended keys switch the current character. Returns the 0-based index of the pressed
  hotkey, 0 for Enter (only when enterOk) and 255 for a letter or digit that is not a hotkey }
function MenuHorizontalCS(query: Types.TStr40; menu: String; qCol, mCol, hlCol: Byte; enterOk, animate: Boolean): Byte;

{ ECL vertical menu -- thin wrapper over MenuCore.MenuVertical (result char discarded) }
procedure EclVerticalMenu(query: Types.TStr40; menu: String; qCol, mCol, hlCol: Byte; ulCol, ulRow, lrCol,
                          lrRow: ShortInt; list: Types.PItemRec; addExit: Boolean; var redraw: Boolean;
                          var idx: Integer; var sel: Types.PItemRec);

{ Set the six comparison flags from s1 and s2. }
procedure EclCompareStr(s1, s2: String);

{ Set the six comparison flags from v1 and v2. }
procedure EclCompareInt(v1, v2: Word);

procedure EclGosub(varIdx: Byte);

{ Disable every creature whose name differs from the current character's; mirror <> 0 then appends a hostile ROLF
  clone }
procedure CharFightsAlone(mirror: ShortInt);

{ Script CALL $C01E: step the party forward one cell with 0..15 wraparound, then refresh the event and wall bytes }
procedure EclMoveForward;

{ Scale all 7 coin slots by fraction, truncating }
procedure RobMoney(fraction: Real; creature: Types.PCharRecord);

{ Chance% per item to steal it; heavy items (weight > 255 / > 24 coins) reduce the chance }
procedure RobItems(chance: Byte; creature: Types.PCharRecord);

{ Highest/lowest movement in GDVars.creatureList (haste doubles, else slow halves); hiMove/loMove start from the head's
  unadjusted movementCur, so that value always lies within the bounds }
procedure MoveExtremes(var hiMove, loMove: Byte);

{ Damage message + damage + party panel refresh; dead creatures are skipped }
procedure EclInflictDamage(dmg: Word; creature: Types.PCharRecord);

{ Load creature id from MON<disk>CHA/SPC/ITM.dax (a missing or short CHA record exits the game); nil the list pointers,
  derive iconSize from race, roll random icon colours (slot 4, hair, is fixed at $C4), convert effects/items to lists,
  ignoring a trailing part record. }
procedure LoadCreatureData(id: Byte; creature: Types.PCharRecord);

{ GetMem + LoadCreatureData + random portrait head and body by gender and a randomly picked class + AddCharToParty +
  LoadCharIconAnim(True). No-op when the party already has 8 members (C_Gbvm.PARTY_SIZE > 7). }
procedure AddCreatureToParty(id: Byte);

implementation

uses Crt, C_Area, C_Npc, C_Msg, GDVars, MapView, SaveLoad, C_Effect, C_Ecl, C_Keys, C_Status, C_Gbvm, C_Dir,
  C_Money, CharHlp, DaxIo, FxEngine, GameIo, MapTiles, MenuCore, Portrait, TextRend, View3D, EclVars, CharDisp, Party,
  C_Race, C_Level, GDConsts, StrUtil;

{ A just-loaded save (loadedSave <> 0) keeps its script words; the flag is cleared instead }
procedure EclInit;
var
  i: Word;
begin
  GDVars.eclGraphics := False;
  GDVars.protTextShown := 0;
  GDVars.dumpCr6C00 := False;
  GDVars.dumpCr6B00 := False;
  GDVars.wallColorSel := 65;
  GDVars.ceilFloorColorSel := 9;
  GDVars.picRegionW := True;
  FillChar(GDVars.dsMonsterFlags, SizeOf(GDVars.dsMonsterFlags), 0);
  GDVars.gIconAnim := 8;
  GDVars.eclIp := $9900;
  GDVars.breathAim := False;
  GDVars.dsEclStackTopPtr := nil;
  GDVars.dsEclStackSecondPtr := nil;
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  { No portrait head (255), so DisplayMonster shows the PIC close-up }
  GDVars.zone1^[C_Gbvm.PIC_LOADING] := 255;
  { rest interruption }
  GDVars.zone1^[C_Gbvm.REST_SAFE_TIME] := 0;
  GDVars.zone1^[C_Gbvm.REST_INTERRUPT_PCT] := 0;
  GDVars.zone0^.antimagic := 0;
  EclVars.LoadEclVars(1);
  GDVars.scriptEntryAddrs[1] := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[1], GDVars.dsGbvmUpperByte[1]);
  EclVars.LoadEclVars(1);
  GDVars.scriptEntryAddrs[C_Ecl.ENTRY_SEARCH] := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[1],
                                                                            GDVars.dsGbvmUpperByte[1]);
  EclVars.LoadEclVars(1);
  GDVars.scriptEntryAddrs[3] := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[1], GDVars.dsGbvmUpperByte[1]);
  EclVars.LoadEclVars(1);
  GDVars.scriptEntryAddrs[4] := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[1], GDVars.dsGbvmUpperByte[1]);
  EclVars.LoadEclVars(1);
  GDVars.scriptEntryAddrs[5] := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[1], GDVars.dsGbvmUpperByte[1]);
  { Select the 3D view (MapView treats view3dFlag <> 0 as location type 1) }
  GDVars.zone0^.view3dFlag := 1;
  if GDVars.loadedSave = 0 then begin
    for i := 1 to 32 do
      { GBVM $4A00..$4A1F }
      GDVars.zone0^.words[i + $49FF] := 0;
    for i := 0 to 9 do
      { GBVM $6E79..$6E82 }
      GDVars.zone1^[i + $6E79] := 0;
  end else
    GDVars.loadedSave := 0;
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
begin
  FillChar(GDVars.zone3^, SizeOf(Types.TZone3), 0);
  GDVars.dsSuppressingInsertDiskFlag := False;
  TextRend.ClearBottomLine;
  TextRend.DisplayString(0, 24, White, 'Loading...Please Wait');
  if not (GDVars.virtualDisk in [1..Types.LAST_DISK]) then
    DaxIo.PushState(1);
  Str(GDVars.virtualDisk, s);
  { the merged ECL.DAX holds every disk's scripts, so the search below would not run }
  if DaxIo.ArchiveName('ECL' + s) <> 'ECL' + s then
    if not DaxIo.DiskHasBlock('ECL' + s, scriptId) then begin
      disk := 1;
      while disk <= 8 do begin
        Str(disk, s);
        if DaxIo.DiskHasBlock('ECL' + s, scriptId) then begin
          DaxIo.PushState(disk);
          disk := 8;
        end;
        Inc(disk);
      end;
      Str(GDVars.virtualDisk, s);
    end;
  DaxIo.LoadDax('ECL' + s, '.dax', scriptId, sizeRead, data);
  if sizeRead < 2 then begin
    { not on this disk: a script changed area without setting the disk first (Stojanow Gate's flee); take the first
      disk that has the block, without the insert-disk prompt }
    GDVars.dsSuppressingInsertDiskFlag := True;
    disk := 1;
    while (sizeRead < 2) and (disk <= 8) do begin
      if disk <> GDVars.virtualDisk then begin
        Str(disk, s);
        DaxIo.LoadDax('ECL' + s, '.dax', scriptId, sizeRead, data);
        if sizeRead >= 2 then
          DaxIo.PushState(disk);
      end;
      Inc(disk);
    end;
    GDVars.dsSuppressingInsertDiskFlag := False;
    if sizeRead < 2 then begin
      Str(scriptId, s);
      DaxIo.PromptBox(Yellow, 'Script area ' + s + ' is missing');
      GameIo.ExitGame;
    end;
  end;
  n := sizeRead - 2;
  if n > SizeOf(Types.TZone3) then
    n := SizeOf(Types.TZone3);
  Move(data^[2], GDVars.zone3^, n);
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
  if GDVars.zone0^.view3dFlag = 0 then begin
    MaxMonsterDist := 2;
    GDVars.zone1^[C_Gbvm.MONSTER_DIST] := 2;
  end else
    while (dist < 2) and (not blocked) do begin
      if View3D.GetWallType(x, y, facing) = 0 then begin
        Inc(dist);
        MaxMonsterDist := dist;
        case facing of
          C_Dir.NORTH: Dec(y);
          C_Dir.EAST: Inc(x);
          C_Dir.SOUTH: Inc(y);
          C_Dir.WEST: Dec(x);
        end;
      end else
        blocked := True;
    end;
end;

procedure DisplayPortrait(headId, bodyId: Byte);
begin
  GDVars.picDrawn := False;
  GDVars.dsCurrentPortraitHead := headId;
  GDVars.dsCurrentPortraitHead2 := bodyId;
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
      if GDVars.automapOn then begin
        GDVars.automapOn := False;
        MapView.DisplayMapView;
      end;
      Portrait.LoadAnimation('SPRIT', sprId, 1, GDVars.animData);
      flags[0] := True;
      GDVars.sprShown := True;
    end;
    if GDVars.gLocType = C_Area.LOC_3D_MAP then
      Portrait.Show3DSprite(d3, GDVars.animData)
    else
      Portrait.Show3DSprite(2, GDVars.animData);
  end;
  if flags[1] then
    if GDVars.picIdShown = GDVars.zone1^[C_Gbvm.PIC_LOADING] then
      Exit;
  if dist <> 0 then Exit;
  if GDVars.gLocType <> C_Area.LOC_3D_MAP then Exit;
  if (GDVars.inEncMenu <> 0) and (GDVars.monsterPics = 0) then Exit;
  GDVars.picIdShown := Byte(GDVars.zone1^[C_Gbvm.PIC_LOADING]);
  GDVars.eclGraphics := True;
  if GDVars.zone1^[C_Gbvm.PIC_LOADING] = 255 then begin
    Portrait.LoadAnimation('PIC', picId, 0, GDVars.animData);
    flags[1] := True;
    Portrait.DisplayImageBuf(3, 3, True, GDVars.animData.frames[1].pic);
  end else begin
    EclMenu.DisplayPortrait(Byte(GDVars.zone1^[C_Gbvm.PIC_LOADING]), picId);
    flags[1] := True;
    GDVars.picDrawn := False;
  end;
end;

{ Lowercase menu (digits shift by 32 too), delete each '~' and uppercase the hotkey after it, collecting the hotkeys in
  opts }
procedure MenuToOptions(var menu: String; var opts: Types.TStr40);
var
  i: Byte;
begin
  opts := '';
  for i := 1 to Length(menu) do begin
    if menu[i] in ['0'..'9', 'A'..'Z'] then
      menu[i] := Chr(Ord(menu[i]) + 32);
    if menu[i] = '~' then begin
      Delete(menu, i, 1);
      menu[i] := UpCase(menu[i]);
      opts := opts + menu[i];
    end;
  end;
end;

{ Horizontal menu with character selection; query is limited to 40 characters and menu text to 255. Each script menu
  starts with its first option highlighted, so Enter never takes a highlight another menu left behind; switching
  characters keeps the highlight. }
function MenuHorizontalCS(query: Types.TStr40; menu: String; qCol, mCol, hlCol: Byte; enterOk, animate: Boolean): Byte;
var
  opts: Types.TStr40;
  idx: Byte;
  ch: Char;
  ext: Boolean;
begin
  EclMenu.MenuToOptions(menu, opts);
  GDVars.horizChoice := 1;
  repeat
    ch := MenuCore.MenuHorizontal(query, menu, qCol, mCol, hlCol, True, animate, ext);
    if ext then begin
      Party.SelectPrevNextChar(ch);
      CharDisp.DisplayParty(GDVars.curChar);
      ch := C_Keys.NONE;
    end;
  until (ch in ['0'..'9', 'A'..'Z']) or ((ch = C_Keys.ENTER) and enterOk);
  case ch of
    C_Keys.ENTER: MenuHorizontalCS := 0;
  else begin
    idx := 1;
    while (idx <= Length(opts)) and (opts[idx] <> ch) do
      Inc(idx);
    if idx <= Length(opts) then
      MenuHorizontalCS := idx - 1
    else
      MenuHorizontalCS := 255;
  end;
  end;
end;

{ MenuToOptions edits menu; opts and MenuVertical's returned character are discarded }
procedure EclVerticalMenu(query: Types.TStr40; menu: String; qCol, mCol, hlCol: Byte; ulCol, ulRow, lrCol,
                          lrRow: ShortInt; list: Types.PItemRec; addExit: Boolean; var redraw: Boolean;
                          var idx: Integer; var sel: Types.PItemRec);
var
  ch: Char;
  opts: Types.TStr40;
begin
  EclMenu.MenuToOptions(menu, opts);
  ch := MenuCore.MenuVertical(query, menu, qCol, mCol, hlCol, ulCol, ulRow, lrCol, lrRow, list, addExit, redraw, idx,
                              sel);
end;

{ Set each of the six comparison flags: equal, not equal, less, greater, less or equal, greater or equal }
procedure EclCompareStr(s1, s2: String);
begin
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  if s1 = s2 then GDVars.cmpFlags[0] := True;
  if s1 <> s2 then GDVars.cmpFlags[1] := True;
  if s1 < s2 then GDVars.cmpFlags[2] := True;
  if s1 > s2 then GDVars.cmpFlags[3] := True;
  if s1 <= s2 then GDVars.cmpFlags[4] := True;
  if s1 >= s2 then GDVars.cmpFlags[5] := True;
end;

procedure EclCompareInt(v1, v2: Word);
begin
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  if v1 = v2 then GDVars.cmpFlags[0] := True;
  if v1 <> v2 then GDVars.cmpFlags[1] := True;
  if v1 < v2 then GDVars.cmpFlags[2] := True;
  if v1 > v2 then GDVars.cmpFlags[3] := True;
  if v1 <= v2 then GDVars.cmpFlags[4] := True;
  if v1 >= v2 then GDVars.cmpFlags[5] := True;
end;

{ Push IP on the ECL return stack, then jump to the address word in variable varIdx }
procedure EclGosub(varIdx: Byte);
begin
  if GDVars.dsEclStackTopPtr = nil then begin
    GetMem(GDVars.dsEclStackTopPtr, SizeOf(Types.TEclRet));
    GDVars.dsEclStackTopPtr^.next := nil;
  end else begin
    GDVars.dsEclStackSecondPtr := GDVars.dsEclStackTopPtr;
    GetMem(GDVars.dsEclStackTopPtr, SizeOf(Types.TEclRet));
    GDVars.dsEclStackTopPtr^.next := GDVars.dsEclStackSecondPtr;
  end;
  GDVars.dsEclStackTopPtr^.addr := GDVars.eclIp;
  GDVars.eclIp := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[varIdx], GDVars.dsGbvmUpperByte[varIdx]);
end;

{ Step with 0..15 wraparound, then refresh the event and wall-ahead bytes for the new cell }
procedure EclMoveForward;
begin
  case GDVars.gFacing of
    C_Dir.NORTH: if GDVars.gMapY > 0 then Dec(GDVars.gMapY) else GDVars.gMapY := 15;
    C_Dir.EAST: if GDVars.gMapX < 15 then Inc(GDVars.gMapX) else GDVars.gMapX := 0;
    C_Dir.SOUTH: if GDVars.gMapY < 15 then Inc(GDVars.gMapY) else GDVars.gMapY := 0;
    C_Dir.WEST: if GDVars.gMapX > 0 then Dec(GDVars.gMapX) else GDVars.gMapX := 15;
  end;
  GDVars.eventAtCell := View3D.GetMapEvent(GDVars.gMapX, GDVars.gMapY);
  GDVars.wallAhead := View3D.GetWallType(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing);
end;

{ Sets duelFlag and C_Gbvm.MIRROR_DUEL. A mirror duel appends a copy of the current character as hostile "ROLF" with the
  CPIC 11 icon (items fully cloned, but prepended, so the clone's list is reversed; effects not cloned) }
procedure CharFightsAlone(mirror: ShortInt);
var
  p: Types.PCharRecord;
  clone: Types.PCharRecord;
  cur: Types.PCharRecord;
  srcIt: Types.PItemRec;
begin
  GDVars.duelFlag := True;
  GDVars.zone1^[C_Gbvm.MIRROR_DUEL] := mirror;
  cur := GDVars.curChar;
  p := GDVars.creatureList;
  while p <> nil do begin
    if p^.name <> cur^.name then
      p^.enabled := 0;
    p := p^.nextCharAddr;
  end;
  if mirror = 0 then Exit;
  MapTiles.LoadIconAnim('CPIC', 11, GDVars.gIconAnim);
  p := Party.LastCreature;
  GetMem(clone, SizeOf(Types.TCharRecord));
  clone^ := cur^;
  clone^.enabled := 1;
  clone^.nextCharAddr := nil;
  clone^.name := 'ROLF';
  clone^.quickfight := 1;
  clone^.hostile := 1;
  clone^.npc := C_Npc.ANIMATED_NPC;
  clone^.orderNumber := GDVars.gIconAnim;
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
  creature^.coins[C_Money.COPPER] := Trunc(creature^.coins[C_Money.COPPER] * fraction);
  creature^.coins[C_Money.SILVER] := Trunc(creature^.coins[C_Money.SILVER] * fraction);
  creature^.coins[C_Money.ELECTRUM] := Trunc(creature^.coins[C_Money.ELECTRUM] * fraction);
  creature^.coins[C_Money.GOLD] := Trunc(creature^.coins[C_Money.GOLD] * fraction);
  creature^.coins[C_Money.PLATINUM] := Trunc(creature^.coins[C_Money.PLATINUM] * fraction);
  creature^.coins[C_Money.GEMS] := Trunc(creature^.coins[C_Money.GEMS] * fraction);
  creature^.coins[C_Money.JEWELRY] := Trunc(creature^.coins[C_Money.JEWELRY] * fraction);
end;

{ Heavy items are harder to steal: weight > 255 coins knocks 90 off the chance, > 24 knocks 50. SSI quirk, kept: the
  penalties come off chance itself, so they accumulate over the walk. A readied item is unreadied before it is taken, so
  a ring's, cloak's or gauntlets' effect goes with it, as FxEngine.ToggleReadyItem does. }
procedure RobItems(chance: Byte; creature: Types.PCharRecord);
var
  roll: Byte;
  item: Types.PItemRec;
  nxt: Types.PItemRec;
begin
  item := creature^.itemsAddr;
  while item <> nil do begin
    if item^.weight > 255 then begin
      if chance > 90 then
        chance := chance - 90
      else
        chance := 0;
    end else if item^.weight > 24 then begin
      if chance > 50 then
        chance := chance - 50
      else
        chance := 0;
    end;
    roll := FxEngine.RollDice(1, 100);
    nxt := item^.next;
    if roll <= chance then begin
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

{ The list head is read before the nil check, so callers must supply a nonempty list }
procedure MoveExtremes(var hiMove, loMove: Byte);
var
  p: Types.PCharRecord;
  effect: Types.PEffectRec;
  m: Byte;
begin
  p := GDVars.creatureList;
  hiMove := p^.movementCur;
  loMove := p^.movementCur;
  while p <> nil do begin
    m := p^.movementCur;
    if CharHlp.HasEffect(p, C_Effect.HASTED, effect) then
      m := m * 2
    else if CharHlp.HasEffect(p, C_Effect.SLOWED, effect) then
      m := m div 2;
    if m > hiMove then hiMove := m;
    if m < loMove then loMove := m;
    p := p^.nextCharAddr;
  end;
end;

{ "dies" when dmg > hpCur + 10, else the hit message (dmgStr holds at most 3 digits); then apply the damage, clear the
  panel at (17,1)-(38,15) and redraw the party. A dead, stoned or gone character is left alone, with no message. }
procedure EclInflictDamage(dmg: Word; creature: Types.PCharRecord);
var
  msg: String;
  pause: Boolean;
begin
  { a dead, stoned or gone character takes no damage, as in CharHlp.InflictDamage }
  if creature^.status in [C_Status.DEAD, C_Status.STONED, C_Status.GONE] then Exit;
  pause := False;
  if creature^.hpCur + 10 < dmg then
    msg := '  ' + creature^.name + ' dies. '
  else
    msg := '  ' + creature^.name + ' is hit FOR ' + StrUtil.NumStr(dmg) + ' points of Damage.';
  if GDVars.curRow > C_Msg.TEXT_BOTTOM then begin
    GDVars.curRow := C_Msg.MESSAGE_TOP;
    pause := True;
    TextRend.DisplayAndPause(White, 'press <enter>/<return> to continue');
  end else
    pause := False;
  GDVars.curCol := C_Msg.TEXT_RIGHT;
  TextRend.ShowMessage(White, pause, msg);
  CharHlp.InflictDamage(creature, dmg);
  TextRend.ClearRect(17, 1, 38, 15);
  CharDisp.DisplayParty(GDVars.curChar);
end;

procedure LoadCreatureData(id: Byte; creature: Types.PCharRecord);
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
  Str(GDVars.virtualDisk, numStr);
  DaxIo.LoadDax('MON' + numStr + 'CHA', '.dax', id, size, data);
  if size < SizeOf(Types.TCharRecord) then begin
    TextRend.DisplayAndPause(White, 'Unable to load monster');
    GameIo.ExitGame;
  end;
  Move(data^, creature^, SizeOf(Types.TCharRecord));
  with creature^ do begin
    itemsAddr := nil;
    effectsAddr := nil;
    nextCharAddr := nil;
    combatAddr := nil;
    case race of
      C_Race.DWARF, C_Race.GNOME, C_Race.HALFLING: iconSize := 1;
      C_Race.ELF, C_Race.HALFELF, C_Race.HALFORC, C_Race.HUMAN: iconSize := 2;
    end;
    for i := 1 to 3 do begin
      roll := FxEngine.RollDice(1, 6);
      iconColors1[i] := roll + (roll + 8) shl 4;
    end;
    iconColors1[4] := $C4;
    for i := 5 to 6 do begin
      roll := FxEngine.RollDice(1, 6);
      iconColors1[i] := roll + (roll + 8) shl 4;
    end;
  end;
  FreeMem(data, size);
  GDVars.dsSuppressingInsertDiskFlag := True;
  DaxIo.LoadDax('MON' + numStr + 'SPC', '.dax', id, size, data);
  if size <> 0 then begin
    if size >= SizeOf(Types.TEffectRec) then begin
      offset := 0;
      GetMem(creature^.effectsAddr, SizeOf(Types.TEffectRec));
      effect := creature^.effectsAddr;
      repeat
        Move(data^[offset], effect^, SizeOf(Types.TEffectRec));
        effect^.next := nil;
        Inc(offset, SizeOf(Types.TEffectRec));
        if size - offset >= SizeOf(Types.TEffectRec) then begin
          GetMem(effect^.next, SizeOf(Types.TEffectRec));
          effect := effect^.next;
        end;
      until size - offset < SizeOf(Types.TEffectRec);
    end;
    FreeMem(data, size);
  end;
  DaxIo.LoadDax('MON' + numStr + 'ITM', '.dax', id, size, data);
  if size <> 0 then begin
    if size >= SizeOf(Types.TItemRec) then begin
      offset := 0;
      GetMem(creature^.itemsAddr, SizeOf(Types.TItemRec));
      item := creature^.itemsAddr;
      repeat
        Move(data^[offset], item^, SizeOf(Types.TItemRec));
        item^.next := nil;
        Inc(offset, SizeOf(Types.TItemRec));
        if size - offset >= SizeOf(Types.TItemRec) then begin
          GetMem(item^.next, SizeOf(Types.TItemRec));
          item := item^.next;
        end;
      until size - offset < SizeOf(Types.TItemRec);
    end;
    FreeMem(data, size);
  end;
  GDVars.dsSuppressingInsertDiskFlag := False;
end;

procedure AddCreatureToParty(id: Byte);

var
  creature: Types.PCharRecord;
  cnt: Byte;
  i: ShortInt;
  classes: array[1..4] of Byte;
begin
  if GDVars.zone1^[C_Gbvm.PARTY_SIZE] >= Types.MAX_PARTY then Exit;
  GetMem(creature, SizeOf(Types.TCharRecord));
  EclMenu.LoadCreatureData(id, creature);
  with creature^ do begin
    randByte := Random(256);
    cnt := 0;
    { classes holds 4; shipped monsters have at most 4 class levels set, and none a monk's }
    for i := C_Level.CLERIC to C_Level.THIEF do
      if (classLevels[i] > 0) and (cnt < 4) then begin
        Inc(cnt);
        classes[cnt] := i;
      end;
    if cnt = 0 then begin
      cnt := 1;
      classes[cnt] := C_Level.FIGHTER;
    end;
    cnt := FxEngine.RollDice(1, cnt);
    case classes[cnt] of
      C_Level.CLERIC: portraitBody := GDConsts.npcClericBodies[genderSp, FxEngine.RollDice(1, 5)];
      C_Level.MAGE: portraitBody := GDConsts.npcMageBodies[genderSp, FxEngine.RollDice(1, 5)];
      C_Level.THIEF: portraitBody := GDConsts.npcThiefBodies[genderSp, FxEngine.RollDice(1, 5)];
      else portraitBody := GDConsts.npcFighterBodies[genderSp, FxEngine.RollDice(1, 5)];
    end;
    portraitHead := GDConsts.npcPortraitHeads[genderSp, FxEngine.RollDice(1, 8)];
  end;
  SaveLoad.AddCharToParty(creature);
  SaveLoad.LoadCharIconAnim(True);
end;

end.

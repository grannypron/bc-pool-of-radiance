{ ECL variable decoding, game-memory access, script menus, comparisons and subroutine calls. }
{$O+,F+}
unit EclMenu;

interface

uses Types;

{ Value of loaded ECL variable idx: type 0 gives its byte; 1 and 3 read the GBVM at its address word; 2 gives its word;
  $81 (string reference) gives its GBVM address. Note: $80 (string value) also reads the GBVM, at an address made of the
  packed length as low byte and a stale upper byte. }
function GetEclVar(idx: ShortInt): Word;

{ Read count ECL variables at the ECL IP into dsGbvmType/dsGbvmLowerByte/dsGbvmUpperByte, decoding string values and
  string references into gbStrings. Only the first 64 variables and 20 strings are kept (later strings overwrite the
  20th); the IP still steps past them all. }
procedure LoadEclVars(count: Byte);

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

{ Join two bytes into a word. }
function CombineBytesToWord(lowByte, highByte: Byte): Word;

{ Write value to a GBVM address; zone 1 also runs the special handler }
procedure WriteGbvm(address, value: Word);

{ Read a GBVM address }
function ReadGbvm(address: Word): Word;

{ Write s to the GBVM as a C string ($6B00 = current character name, copied as a Pascal String into the char record
  instead), shortened so that it and its terminator stay inside the zone }
procedure WriteGbvmString(address: Word; s: String);

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

procedure SkipEclCmd;

{ Highest/lowest movement in GDVars.creatureList (haste doubles, else slow halves); hiMove/loMove start from the head's
  unadjusted movementCur, so that value always lies within the bounds }
procedure MoveExtremes(var hiMove, loMove: Byte);

{ Damage message + damage + party panel refresh; dead creatures are skipped }
procedure EclInflictDamage(dmg: Word; creature: Types.PCharRecord);

implementation

uses Crt, C_Area, C_Npc, C_Save, C_Msg, GDConsts, GDVars, MapView, SaveLoad, ViewChar, C_Effect, C_Ecl, C_Keys,
  C_Status, C_Gbvm, C_Dir, C_Money, CharHlp, DaxIo, FxEngine, GameIo, MapTiles, MenuCore, Portrait, TextRend, View3D;

var
  { Monster sprite or close-up picture shown in the view window }
  animData: Types.TAnimRec absolute GDVars.animData;

procedure ConvGbString(len, strIdx: Byte); forward;

procedure DerefGbString(strIdx: Byte; address: Word); forward;

{ Var record at IP: +1 type, +2 low byte; types 1/2/3 take a third (high) byte; $80 = string value (packed 6-bit chars,
  low byte = packed byte count, decoded by ConvGbString); $81 = string reference (extra byte -> hi; the string at that
  GBVM address is copied by DerefGbString). IP ends on the byte after the last variable }
procedure LoadEclVars(count: Byte);
var
  i: Byte;
  strIdx: Byte;
  v: Word;
  len: Word;
  t: Byte;
  lo: Byte;
  hi: Byte;
begin
  strIdx := 0;
  for i := 1 to count do begin
    t := GDVars.zone3^[GDVars.eclIp + 1];
    lo := GDVars.zone3^[GDVars.eclIp + 2];
    GDVars.eclIp := GDVars.eclIp + 2;
    case t of
      1, 2, 3: begin
        Inc(GDVars.eclIp);
        hi := GDVars.zone3^[GDVars.eclIp];
      end;
      $80: begin
        { 20 = High(gbStrings) }
        if strIdx < 20 then Inc(strIdx);
        len := lo;
        if len > 0 then
          EclMenu.ConvGbString(len, strIdx)
        else
          GDVars.gbStrings[strIdx] := '';
      end;
      $81: begin
        if strIdx < 20 then Inc(strIdx);
        Inc(GDVars.eclIp);
        hi := GDVars.zone3^[GDVars.eclIp];
        v := EclMenu.CombineBytesToWord(lo, hi);
        EclMenu.DerefGbString(strIdx, v);
      end;
    end;
    { 64 = High(dsGbvmType); the upper byte is kept only for the types that carry one }
    if i <= 64 then begin
      GDVars.dsGbvmType[i] := t;
      GDVars.dsGbvmLowerByte[i] := lo;
      if (t in [1, 2, 3]) or (t = $81) then
        GDVars.dsGbvmUpperByte[i] := hi;
    end;
  end;
  Inc(GDVars.eclIp);
end;

{ Note: the locals are named backwards: vHi holds the variable's lower byte and vLo its upper byte }
function GetEclVar(idx: ShortInt): Word;
var
  d1: Word;
  d2: Word;
  d3: Word;
  vHi: Byte;
  vLo: Byte;
begin
  vHi := GDVars.dsGbvmLowerByte[idx];
  vLo := GDVars.dsGbvmUpperByte[idx];
  case GDVars.dsGbvmType[idx] of
    0: GetEclVar := vHi;
    1, 3, $80: GetEclVar := EclMenu.ReadGbvm(vLo * 256 + vHi);
    2, $81: GetEclVar := EclMenu.CombineBytesToWord(vHi, vLo);
  end;
end;

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
  EclMenu.LoadEclVars(1);
  GDVars.scriptEntryAddrs[1] := EclMenu.CombineBytesToWord(GDVars.dsGbvmLowerByte[1], GDVars.dsGbvmUpperByte[1]);
  EclMenu.LoadEclVars(1);
  GDVars.scriptEntryAddrs[C_Ecl.ENTRY_SEARCH] := EclMenu.CombineBytesToWord(GDVars.dsGbvmLowerByte[1],
                                                                            GDVars.dsGbvmUpperByte[1]);
  EclMenu.LoadEclVars(1);
  GDVars.scriptEntryAddrs[3] := EclMenu.CombineBytesToWord(GDVars.dsGbvmLowerByte[1], GDVars.dsGbvmUpperByte[1]);
  EclMenu.LoadEclVars(1);
  GDVars.scriptEntryAddrs[4] := EclMenu.CombineBytesToWord(GDVars.dsGbvmLowerByte[1], GDVars.dsGbvmUpperByte[1]);
  EclMenu.LoadEclVars(1);
  GDVars.scriptEntryAddrs[5] := EclMenu.CombineBytesToWord(GDVars.dsGbvmLowerByte[1], GDVars.dsGbvmUpperByte[1]);
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
  d1: Word;
  d2: Word;
  s: String[3];
  sizeRead: Word;
  data: Types.PByteArr;
  disk: Byte;
  n: Word;
begin
  FillChar(GDVars.zone3^, SizeOf(Types.TZone3), 0);
  GDVars.dsSuppressingInsertDiskFlag := 0;
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
    GDVars.dsSuppressingInsertDiskFlag := 1;
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
    GDVars.dsSuppressingInsertDiskFlag := 0;
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
var
  d1: Pointer;
begin
  creature := nil;
  GetMem(creature, SizeOf(Types.TCharRecord));
  SaveLoad.LoadCreatureData(id, creature);
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
  d1: Pointer;
  d2: Pointer;
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
      Portrait.LoadAnimation('SPRIT', sprId, 1, animData);
      flags[0] := True;
      GDVars.sprShown := True;
    end;
    if GDVars.gLocType = C_Area.LOC_3D_MAP then
      Portrait.Show3DSprite(d3, animData)
    else
      Portrait.Show3DSprite(2, animData);
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
    Portrait.LoadAnimation('PIC', picId, 0, animData);
    flags[1] := True;
    Portrait.DisplayImageBuf(3, 3, True, animData.frames[1].pic);
  end else begin
    EclMenu.DisplayPortrait(Byte(GDVars.zone1^[C_Gbvm.PIC_LOADING]), picId);
    flags[1] := True;
    GDVars.picDrawn := False;
  end;
end;

function CombineBytesToWord(lowByte, highByte: Byte): Word;
begin
  CombineBytesToWord := highByte * 256 + lowByte;
end;

{ 6-bit GB char -> ASCII: 0..31 map to '@'..'_', higher codes are unchanged }
function DecodeGameCharacter(c: Byte): Char;
begin
  if c > 31 then
    DecodeGameCharacter := Chr(c)
  else
    DecodeGameCharacter := Chr(c + 64);
end;

{ GBVM zone of address: 0 = $4900..$4CFF, 1 = $6B00..$6EFF, 2 = $9700..$98FF, 3 = C_Gbvm.SCRIPT_FIRST..SCRIPT_LAST
  (script), else 4 (special registers) }
function GbvmZone(address: Word): Byte;
begin
  GbvmZone := 4;
  if (address >= $4900) and (address <= $4CFF) then GbvmZone := 0;
  if (address >= $6B00) and (address <= $6EFF) then GbvmZone := 1;
  if (address >= $9700) and (address <= $98FF) then GbvmZone := 2;
  if (address >= C_Gbvm.SCRIPT_FIRST) and (address <= C_Gbvm.SCRIPT_LAST) then GbvmZone := 3;
end;

{ Return the creature's zero-based index in GDVars.creatureList (the list length if it is absent) }
function FindCurCharIdx(creature: Types.PCharRecord): Byte;
var
  idx: Byte;
  p: Types.PCharRecord;
  found: Boolean;
begin
  p := GDVars.creatureList;
  found := False;
  idx := 0;
  while (p <> nil) and (not found) do begin
    if p = creature then
      found := True
    else begin
      Inc(idx);
      p := p^.nextCharAddr;
    end;
  end;
  FindCurCharIdx := idx;
end;

{ Special read handling for GBVM zone 1: found is True when address has a handler, even one that leaves the result
  unassigned ($10D, or $2CF with charisma outside 3..25). Most handlers read the current character }
function SpecialReadZ1(address: Word; var found: Boolean): Word;
var
  t: Byte;
begin
  found := True;
  address := address - $6B00;
  case address of
    $18: SpecialReadZ1 := GDVars.curChar^.conCur;
    $9B: SpecialReadZ1 := GDVars.curChar^.saves[C_Save.PETRIFY];
    $A0: SpecialReadZ1 := GDVars.curChar^.levelHighest;
    $A5..$AC: begin
      t := address - $A4;
      SpecialReadZ1 := GDVars.curChar^.thiefSkills[t];
    end;
    $B8: SpecialReadZ1 := GDVars.curChar^.npc;
    $BB: SpecialReadZ1 := GDVars.curChar^.coins[C_Money.COPPER];
    $BD: SpecialReadZ1 := GDVars.curChar^.coins[C_Money.SILVER];
    $BF: SpecialReadZ1 := GDVars.curChar^.coins[C_Money.ELECTRUM];
    $C1: SpecialReadZ1 := GDVars.curChar^.coins[C_Money.GOLD];
    $C3: SpecialReadZ1 := GDVars.curChar^.coins[C_Money.PLATINUM];
    $D8: SpecialReadZ1 := ShortInt(GDVars.curChar^.alignment);
    $F7: SpecialReadZ1 := GDVars.curChar^.xpAward;
    $F9: SpecialReadZ1 := GDVars.curChar^.xpBonusPerHp;
    $100:
      if GDVars.curChar^.enabled <> 0 then
        SpecialReadZ1 := 1
      else
        SpecialReadZ1 := $80;
    $10C:
      if (GDVars.curChar^.hostile = 0) and (GDVars.curChar^.quickfight <> 0) then
        SpecialReadZ1 := $80
      else if GDVars.curChar^.hostile = 1 then
        SpecialReadZ1 := $81
      else
        SpecialReadZ1 := 0;
    { handled, but no value is returned }
    $10D: ;
    $11B: SpecialReadZ1 := GDVars.curChar^.movementCur;
    $2B1: SpecialReadZ1 := EclMenu.FindCurCharIdx(GDVars.curChar);
    $2B4: SpecialReadZ1 := EclMenu.FindCurCharIdx(GDVars.curChar);
    $2CF:
      { charisma -> loyalty base; no result for charisma outside 3..25 }
      case GDVars.curChar^.chaCur of
        3: SpecialReadZ1 := 0;
        4: SpecialReadZ1 := 5;
        5: SpecialReadZ1 := 10;
        6: SpecialReadZ1 := 15;
        7: SpecialReadZ1 := 20;
        8..12: SpecialReadZ1 := 25;
        13: SpecialReadZ1 := 30;
        14: SpecialReadZ1 := 35;
        15: SpecialReadZ1 := 40;
        16: SpecialReadZ1 := 50;
        17: SpecialReadZ1 := 55;
        18..25: SpecialReadZ1 := 60;
      end;
    $312: SpecialReadZ1 := GDVars.virtualDisk;
    { party size }
    $33E: SpecialReadZ1 := GDVars.zone1^[C_Gbvm.PARTY_SIZE];
  else
    found := False;
  end;
end;

{ Special write handling for GBVM zone 1 (always in addition to the zone word write). A write to the current
  character's coins recalculates its stats, so its encumbrance and movement follow. }
procedure SpecialWriteZ1(address, value: Word);
var
  t: Byte;
begin
  address := address - $6B00;
  case address of
    0:
      if value = 0 then GDVars.dumpCr6B00 := True;
    { a raw window into the character record, starting at memorizedSpells[1] and running on past it }
    $20..$70: begin
      t := address - $1F;
      GDVars.curChar^.memorizedSpells[t] := value;
    end;
    $B8: begin
      { values above C_Npc.ANIMATED_NPC ($B2) lose $32 (= C_Npc.ANIMATED_NPC and C_Npc.MORALE_MASK) }
      if value > C_Npc.ANIMATED_NPC then Dec(value, $32);
      GDVars.curChar^.npc := value;
    end;
    $BB: GDVars.curChar^.coins[C_Money.COPPER] := value;
    $BD: GDVars.curChar^.coins[C_Money.SILVER] := value;
    $BF: GDVars.curChar^.coins[C_Money.ELECTRUM] := value;
    $C1: GDVars.curChar^.coins[C_Money.GOLD] := value;
    $C3: GDVars.curChar^.coins[C_Money.PLATINUM] := value;
    $F7: GDVars.curChar^.xpAward := value;
    $F9: GDVars.curChar^.xpBonusPerHp := value;
    $100: begin
      if value >= $80 then begin
        GDVars.curChar^.enabled := 0;
        if value = $87 then GDVars.curChar^.status := C_Status.STONED;
      end;
      if value = 0 then GDVars.dumpCr6C00 := True;
    end;
    $10C:
      case value of
        0: begin
          GDVars.curChar^.hostile := 0;
          GDVars.curChar^.quickfight := 0;
        end;
        $80: begin
          GDVars.curChar^.hostile := 0;
          GDVars.curChar^.quickfight := 1;
        end;
        $81: begin
          GDVars.curChar^.hostile := 1;
          GDVars.curChar^.quickfight := 1;
        end;
      end;
    { disks 1..8 only }
    $312:
      if (value >= 1) and (value <= 8) then DaxIo.PushState(value);
    $322:
      if value > $80 then begin
        value := value and $7F;
        View3D.LoadWallSet(value, 1);
      end;
    $324:
      if value > $80 then begin
        value := value and $7F;
        View3D.LoadWallSet(value, 2);
      end;
    $326:
      if value > $80 then begin
        value := value and $7F;
        View3D.LoadWallSet(value, 3);
      end;
  end;
  { $BB, $BD, $BF, $C1, $C3: copper to platinum }
  if (address >= $BB) and (address <= $C3) and Odd(address) then
    CharHlp.RecalcStats(GDVars.curChar);
end;

procedure WriteGbvm(address, value: Word);
var
  zone: Byte;
  ok: Boolean;
begin
  zone := EclMenu.GbvmZone(address);
  case zone of
    0: begin
      GDVars.zone0^.words[address] := value;
      if (address = $49FD) or (address = $49FE) then
        GDVars.redrawSky := True;
    end;
    1: begin
      GDVars.zone1^[address] := value;
      EclMenu.SpecialWriteZ1(address, value);
    end;
    2:
      GDVars.zone2^[address] := value;
    3:
      GDVars.zone3^[address] := value;
    4:
      if address < $BF68 then
        case address of
          $FB: ;
          $FC: ;
          $B1: ;
          $3DE: GDVars.sndEffect := value;
          $B8: GDVars.writeReg1 := value;
          $B9: GDVars.writeReg2 := value;
        end else begin
        address := address - $BF68;
        case address of
          { party X }
          $E3: begin
            GDVars.movedParty := True;
            GDVars.gMapX := value;
          end;
          { party Y }
          $E4: begin
            GDVars.gMapY := value;
            GDVars.movedParty := True;
          end;
          { facing, mod-4 loop }
          $E5: begin
            repeat
              ok := True;
              case value of
                0: GDVars.gFacing := C_Dir.NORTH;
                1: GDVars.gFacing := C_Dir.EAST;
                2: GDVars.gFacing := C_Dir.SOUTH;
                3: GDVars.gFacing := C_Dir.WEST;
              else begin
                ok := False;
                Dec(value, 4);
              end;
              end;
            until ok = True;
            GDVars.movedParty := True;
          end;
          $F1: begin
            GDVars.wallColorSel := value;
            GDVars.picRegionW := True;
          end;
          $F7: begin
            GDVars.ceilFloorColorSel := value;
            GDVars.picRegionW := True;
          end;
          { accepted, ignored }
          $10BA: ;
        end;
      end;
  end;
end;

{ The party effects table scripts read at $4900..$497F: the party's effects in order (creatureList, then each creature's
  effect list), at most 64 of them. Entry k ($4900 + k) is the effect id and $4940 + k the owner's party index, counted
  from 0 as FindCurCharIdx counts; unused entries read 0. The 'THIEVES ONLY' well (ECL4.DAX block 2) scans it for
  Feather Fall when a climber falls }
function PartyEffectsTable(address: Word): Word;
var
  k: Word;
  e: Word;
  n: Byte;
  p: Types.PCharRecord;
  effect: Types.PEffectRec;
begin
  PartyEffectsTable := 0;
  k := (address - $4900) mod $40;
  e := 0;
  n := 0;
  p := GDVars.creatureList;
  while p <> nil do begin
    effect := p^.effectsAddr;
    while effect <> nil do begin
      if e = k then
        if address < $4940 then
          PartyEffectsTable := effect^.id
        else
          PartyEffectsTable := n;
      Inc(e);
      effect := effect^.next;
    end;
    Inc(n);
    p := p^.nextCharAddr;
  end;
end;

{ Zone 0 reads of $4900..$497F come from the party's effects (PartyEffectsTable), the rest from storage. Zone 4 reads
  below $C04B are fixed registers; from $C04B they index party/view state (WriteGbvm splits at $BF68 but reaches the
  same $C04B.. addresses). Unhandled zone-4 addresses leave the result unassigned }
function ReadGbvm(address: Word): Word;
var
  zone: Byte;
  found: Boolean;
begin
  zone := EclMenu.GbvmZone(address);
  found := False;
  case zone of
    0:
      if address <= $497F then
        ReadGbvm := EclMenu.PartyEffectsTable(address)
      else
        ReadGbvm := GDVars.zone0^.words[address];
    1: begin
      ReadGbvm := EclMenu.SpecialReadZ1(address, found);
      if not found then
        ReadGbvm := GDVars.zone1^[address];
    end;
    2:
      ReadGbvm := GDVars.zone2^[address];
    3:
      ReadGbvm := GDVars.zone3^[address];
    4:
      if address < $C04B then
        case address of
          $B1: ReadGbvm := GDVars.readReg3;
          $FB: ReadGbvm := GDVars.readReg1;
          $FC: ReadGbvm := GDVars.readReg2;
          $33D: ReadGbvm := GDVars.gFacing;
          { handled, but no value is returned }
          $35F: ;
        end else begin
        address := address - $C04B;
        case address of
          { sign-extends (ShortInt) }
          0: ReadGbvm := GDVars.gMapX;
          1: ReadGbvm := GDVars.gMapY;
          2: ReadGbvm := GDVars.gFacing div 2;
          3: ReadGbvm := GDVars.wallAhead;
          4: ReadGbvm := GDVars.eventAtCell;
          { Wall color ($C059): write-only, result unassigned }
          14: ;
        end;
      end;
  end;
end;

{ Strings go to the GBVM as zero-terminated strings, one character per cell (word cells in zones 0..2, bytes in zone 3);
  GBVM $6B00 instead sets the current character's name (String[15], so capped at 15). Zone 4 writes nothing }
procedure WriteGbvmString(address: Word; s: String);
var
  zone: Byte;
  len: Byte;
  i: Byte;
  last: Word;
begin
  zone := EclMenu.GbvmZone(address);
  len := Length(s);
  { the zone's last address, which the terminator may take }
  case zone of
    0: last := $4CFF;
    1: last := $6EFF;
    2: last := $98FF;
    3: last := C_Gbvm.SCRIPT_LAST;
  end;
  if zone < 4 then
    if last - address < len then
      len := last - address;
  case zone of
    0: begin
      for i := 0 to len - 1 do
        GDVars.zone0^.words[address + i] := Ord(s[i + 1]);
      GDVars.zone0^.words[address + len] := 0;
    end;
    1:
      if address = $6B00 then
        GDVars.curChar^.name := s
      else begin
        for i := 0 to len - 1 do
          GDVars.zone1^[address + i] := Ord(s[i + 1]);
        GDVars.zone1^[address + len] := 0;
      end;
    2: begin
      for i := 0 to len - 1 do
        GDVars.zone2^[address + i] := Ord(s[i + 1]);
      GDVars.zone2^[address + len] := 0;
    end;
    3: begin
      for i := 0 to len - 1 do
        GDVars.zone3^[address + i] := Ord(s[i + 1]);
      GDVars.zone3^[address + len] := 0;
    end;
  end;
end;

{ Decode len packed bytes after IP into gbStrings[strIdx] as 6-bit GB chars (4 chars per 3 bytes; phase 4 reuses the
  already-read byte; zero chars are dropped). len counts packed bytes, not decoded characters. IP ends on the last byte
  read }
procedure ConvGbString(len, strIdx: Byte);
var
  i: Byte;
  cur: Byte;
  prev: Byte;
  c6: Byte;
  phase: Byte;
  ch: Char;
begin
  GDVars.gbStrings[strIdx] := '';
  i := 0;
  phase := 1;
  while i < len do begin
    if phase < 4 then begin
      Inc(GDVars.eclIp);
      prev := cur;
      cur := GDVars.zone3^[GDVars.eclIp];
      Inc(i);
    end;
    case phase of
      1:
        c6 := cur shr 2;
      2: begin
        c6 := prev shl 6 + cur shr 2;
        c6 := c6 shr 2;
      end;
      3: begin
        c6 := prev shl 4 + cur shr 4;
        c6 := c6 shr 2;
      end;
      4:
        c6 := cur and $3F;
    end;
    if phase < 4 then Inc(phase) else phase := 1;
    if c6 <> 0 then begin
      ch := EclMenu.DecodeGameCharacter(c6);
      GDVars.gbStrings[strIdx] := Concat(GDVars.gbStrings[strIdx], ch);
    end;
  end;
  if phase = 4 then begin
    c6 := cur and $3F;
    if c6 <> 0 then begin
      ch := EclMenu.DecodeGameCharacter(c6);
      GDVars.gbStrings[strIdx] := Concat(GDVars.gbStrings[strIdx], ch);
    end;
  end;
end;

{ Copy the zero-terminated GBVM string at address into gbStrings[strIdx], one character per cell (the low byte of word
  cells); $6B00 selects the current character's name, and zone 4 gives ''. The copy also stops at the zone's last
  address and at 255 characters, as WriteGbvmString bounds the write side; v1.3 used a Byte offset that wrapped, so an
  unterminated string hung the game. }
procedure DerefGbString(strIdx: Byte; address: Word);
var
  zone: Byte;
  last: Word;
  a: Word;
  c: Word;
begin
  zone := EclMenu.GbvmZone(address);
  GDVars.gbStrings[strIdx] := '';
  if (zone = 1) and (address = $6B00) then
    GDVars.gbStrings[strIdx] := GDVars.curChar^.name
  else if zone < 4 then begin
    case zone of
      0: last := $4CFF;
      1: last := $6EFF;
      2: last := $98FF;
      3: last := C_Gbvm.SCRIPT_LAST;
    end;
    a := address;
    repeat
      case zone of
        0: c := GDVars.zone0^.words[a];
        1: c := GDVars.zone1^[a];
        2: c := GDVars.zone2^[a];
        3: c := GDVars.zone3^[a];
      end;
      if c <> 0 then
        GDVars.gbStrings[strIdx] := Concat(GDVars.gbStrings[strIdx], Char(c));
      Inc(a);
    until (c = 0) or (a > last) or (Length(GDVars.gbStrings[strIdx]) = 255);
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
      ViewChar.SelectPrevNextChar(ch);
      CharHlp.DisplayParty(GDVars.curChar);
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
  GDVars.eclIp := EclMenu.CombineBytesToWord(GDVars.dsGbvmLowerByte[varIdx], GDVars.dsGbvmUpperByte[varIdx]);
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
  tmp: Types.PItemRec;
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
  p := GDVars.creatureList;
  while p^.nextCharAddr <> nil do
    p := p^.nextCharAddr;
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
    if p^.itemsAddr = nil then begin
      GetMem(p^.itemsAddr, SizeOf(Types.TItemRec));
      p^.itemsAddr^ := srcIt^;
      p^.itemsAddr^.next := nil;
    end else begin
      tmp := p^.itemsAddr;
      GetMem(p^.itemsAddr, SizeOf(Types.TItemRec));
      p^.itemsAddr^ := srcIt^;
      p^.itemsAddr^.next := tmp;
    end;
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

{ Heavy items are harder to steal: weight > 255 coins knocks 90 off the chance, > 24 knocks 50. Note: the penalties come
  off chance itself, so they accumulate over the walk. A readied item is unreadied before it is taken, so a ring's,
  cloak's or gauntlets' effect goes with it, as ViewChar.ToggleReadyItem does. }
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

{ Step IP past the command at IP without running it, loading the opcode's operands as its handler does (VMENU, HMENU,
  ONGOTO and ONGOSUB read a count and then that many more); unlisted opcodes skip one byte }
procedure SkipEclCmd;
var
  count: Byte;
begin
  GDVars.curOpcode := GDVars.zone3^[GDVars.eclIp];
  { v1.3 skipped 2 operands for SETUP MONSTER and 1 for ADD NPC, which take 3 and 2, and only the opcode byte of the
    four commands with a count }
  case GDVars.curOpcode of
    C_Ecl.JUMP, C_Ecl.GOSUB, C_Ecl.LOAD_CHAR, C_Ecl.PICTURE, C_Ecl.PRINT, C_Ecl.PRINTCLEAR,
        C_Ecl.PARTY_STR, C_Ecl.NEWECL, C_Ecl.CALL,
    C_Ecl.FIND_ITEM, C_Ecl.CLOCK, C_Ecl.RUN_PROGRAM, C_Ecl.WHO, C_Ecl.PROTECTION:
      EclMenu.LoadEclVars(1);
    C_Ecl.COMPARE, C_Ecl.RANDOM_NUMBER, C_Ecl.SAVE, C_Ecl.INPUT_NUM, C_Ecl.INPUT_STR,
        $1F, C_Ecl.PARTY_SURPR, C_Ecl.ADD_NPC:
      EclMenu.LoadEclVars(2);
    C_Ecl.ADD..C_Ecl.MULTIPLY, C_Ecl.LOAD_MON, C_Ecl.LOADFILES, C_Ecl.ROB, C_Ecl.GETTABLE,
        C_Ecl.BIT_AND, C_Ecl.BIT_OR, C_Ecl.SAVE_TABLE,
    C_Ecl.LOADPIECES, C_Ecl.SPELL, C_Ecl.SETUP_MON:
      EclMenu.LoadEclVars(3);
    { the count is the last operand before the list, as EclVMenu, EclHMenu and EclOnGoto read it }
    C_Ecl.VMENU: begin
      EclMenu.LoadEclVars(3);
      count := EclMenu.GetEclVar(3);
      Dec(GDVars.eclIp);
      EclMenu.LoadEclVars(count);
    end;
    C_Ecl.HMENU, C_Ecl.ONGOTO, C_Ecl.ONGOSUB: begin
      EclMenu.LoadEclVars(2);
      count := EclMenu.GetEclVar(2);
      Dec(GDVars.eclIp);
      EclMenu.LoadEclVars(count);
    end;
    C_Ecl.COMPARE_AND, C_Ecl.SURPRISE:
      EclMenu.LoadEclVars(4);
    C_Ecl.DAMAGE:
      EclMenu.LoadEclVars(5);
    C_Ecl.CHECK_PARTY, C_Ecl.PARLAY:
      EclMenu.LoadEclVars(6);
    C_Ecl.TREASURE:
      EclMenu.LoadEclVars(8);
    C_Ecl.ENCOUNTER:
      EclMenu.LoadEclVars(14);
  else
    Inc(GDVars.eclIp);
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
  frameSizer: Byte;
  msg: String;
  dmgStr: String[3];
  pause: Boolean;
begin
  { a dead, stoned or gone character takes no damage, as in CharHlp.InflictDamage }
  if creature^.status in [C_Status.DEAD, C_Status.STONED, C_Status.GONE] then Exit;
  pause := False;
  Str(dmg, dmgStr);
  if creature^.hpCur + 10 < dmg then
    msg := '  ' + creature^.name + ' dies. '
  else
    msg := '  ' + creature^.name + ' is hit FOR ' + dmgStr + ' points of Damage.';
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
  CharHlp.DisplayParty(GDVars.curChar);
end;

end.

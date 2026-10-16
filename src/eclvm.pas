{ Main game loop and ECL script interpreter. }
{$O+,F+}
unit EclVm;

interface

{ Main game loop: set the interface state from the previous script id and view3dFlag, load (a saved game's too) and
  initialize the ECL script and run its on-load entry, then repeat the map menu, camp, search and movement until the
  party is defeated or a quick load is asked for (Explore.quickLoadAsked) }
procedure GameLoop;

implementation

uses Types, C_Area, C_Npc, C_Msg, GDConsts, GDVars, Crt, Temple, PostCbt, Combat, Explore, CharGen, Ending, CharHlp,
  DaxIo, GameIo, C_Ecl, C_Class, C_Level, C_Ifc, C_Gbvm, C_Sound, C_Money, C_Status, Vault, EclTrace, Border, Camp,
  EclMenu, FxEngine, MapTiles, MapView, MenuCore, Money, Portrait, SaveLoad, Shop, SoundDrv, TextRend, View3D,
  StrUtil, EclVars, CharDisp;

const
  { LOAD MONSTER adds no monsters beyond this count }
  MAX_LOADED_MONSTERS = 63;
  { the last combat-icon slot (GDVars.dsIconAnimation is [0..25]); LOAD MONSTER adds no monsters past it }
  LAST_ICON_SLOT = 25;

  { training hall (class bitmask in C_Gbvm.TRAIN_CLASS_MASK) }
  PROG_TRAINING = 0;
  PROG_WIN_GAME = 8;
  PROG_CAMP = 9;
  { The ids of the three wilderness scripts; each selects a gLocType (C_Area's LOC_WILD_WEST, LOC_WILD_CENTRAL or
    LOC_WILD_EAST). Their values equal C_Ecl.IF_GT, C_Ecl.IF_LE and C_Ecl.IF_GE, but they are script ids, not opcodes. }
  { location type 2, Western Wilderness }
  WILD_WEST_SCRIPT = 25;
  { location type 3, Central Wilderness }
  WILD_CENTRAL_SCRIPT = 26;
  { location type 4, Eastern Wilderness }
  WILD_EAST_SCRIPT = 27;


procedure CallEclScript(address: Word); forward;

{ Free the whole GOSUB return stack. }
procedure FreeEclStack;
begin
  while GDVars.dsEclStackTopPtr <> nil do begin
    GDVars.dsEclStackSecondPtr := GDVars.dsEclStackTopPtr^.next;
    FreeMem(GDVars.dsEclStackTopPtr, SizeOf(Types.TEclRet));
    GDVars.dsEclStackTopPtr := GDVars.dsEclStackSecondPtr;
  end;
end;

{ EXIT: redraw the borders if PROTECTION text was shown, restore the backed-up current character, clear the graphic
  flags, stop the VM, step past the opcode, free the whole GOSUB return stack and park the message cursor }
procedure EclExit;
begin
  if GDVars.protTextShown <> 0 then begin
    Border.DrawWindow(1, 1, 15, 15, 0, White, '');
    if GDVars.zone0^.view3dFlag <> 0 then
      Border.DrawWindow(3, 3, 13, 13, 0, White, '');
  end;
  if GDVars.restoreChar <> 0 then begin
    GDVars.curChar := GDVars.savedChar;
    GDVars.restoreChar := 0;
  end;
  FillChar(GDVars.dsMonsterFlags, SizeOf(GDVars.dsMonsterFlags), 0);
  GDVars.eclGraphics := False;
  GDVars.protTextShown := 0;
  GDVars.eclStop := 1;
  Inc(GDVars.eclIp);
  FreeEclStack;
  GDVars.curRow := C_Msg.MESSAGE_TOP;
  GDVars.curCol := C_Msg.TEXT_LEFT;
  GDVars.dsEcl3dClearFlag := 0;
end;

{ GOTO: jump to var 1's address }
procedure EclGoto;
begin
  EclVars.LoadEclVars(1);
  GDVars.eclIp := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[1], GDVars.dsGbvmUpperByte[1]);
end;

{ GOSUB: push the return address and jump to var 1's address }
procedure EclGosubCmd;
begin
  EclVars.LoadEclVars(1);
  EclMenu.EclGosub(1);
end;

{ COMPARE: set the comparison flags from vars 1 and 2, as strings when either is a string (type bit 7 set) }
procedure EclCompare;
var
  v1: Word;
  v2: Word;
  s1: String;
  s2: String;
begin
  EclVars.LoadEclVars(2);
  if (GDVars.dsGbvmType[1] >= $80) or (GDVars.dsGbvmType[2] >= $80) then begin
    s1 := GDVars.gbStrings[1];
    s2 := GDVars.gbStrings[2];
    EclMenu.EclCompareStr(s1, s2);
  end else begin
    v1 := EclVars.GetEclVar(1);
    v2 := EclVars.GetEclVar(2);
    EclMenu.EclCompareInt(v1, v2);
  end;
end;

{ ADD, SUBTRACT, DIVIDE, MULTIPLY: combine vars 1 and 2 and store the result at var 3's address. SUBTRACT computes var 2
  - var 1. DIVIDE by zero stores 0; v1.3 divided anyway and halted with runtime error 200. }
procedure EclArith;
var
  address: Word;
  v: array[1..2] of Word;
  i: ShortInt;
  r: Word;
begin
  EclVars.LoadEclVars(3);
  for i := 1 to 2 do
    v[i] := EclVars.GetEclVar(i);
  address := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[3], GDVars.dsGbvmUpperByte[3]);
  case GDVars.curOpcode of
    C_Ecl.ADD: r := v[1] + v[2];
    C_Ecl.SUBTRACT: r := v[2] - v[1];
    C_Ecl.DIVIDE:
      if v[2] = 0 then
        r := 0
      else
        r := v[1] div v[2];
    C_Ecl.MULTIPLY: r := v[1] * v[2];
  end;
  EclVars.WriteGbvm(address, r);
end;

{ RANDOM: store a random number from 0 to var 1 (0 to 254 when var 1 is 255) at var 2's address }
procedure EclRandom;
var
  n: Byte;
  roll: Byte;
  address: Word;
begin
  EclVars.LoadEclVars(2);
  n := EclVars.GetEclVar(1);
  if n < 255 then Inc(n);
  address := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[2], GDVars.dsGbvmUpperByte[2]);
  roll := Trunc(Random(n));
  EclVars.WriteGbvm(address, roll);
end;

{ SAVE: store var 1, a number or a string (type bit 7 set), at var 2's address }
procedure EclSave;
var
  v: Word;
  address: Word;
begin
  EclVars.LoadEclVars(2);
  address := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[2], GDVars.dsGbvmUpperByte[2]);
  if GDVars.dsGbvmType[1] < $80 then begin
    v := EclVars.GetEclVar(1);
    EclVars.WriteGbvm(address, v);
  end else
    EclVars.WriteGbvmString(address, GDVars.gbStrings[1]);
end;

{ LOAD CHARACTER: make creature number var 1 (low seven bits, 0 = the first) current; EXIT and PROGRAM restore the
  previous one. With bit 7 set, and dumpCr6C00 and dumpCr6B00 both set, the creature is removed from the party. }
procedure EclLoadChar;
var
  p: Types.PCharRecord;
  idx: Byte;
  i: Byte;
  flag80: Byte;
begin
  GDVars.restoreChar := 1;
  EclVars.LoadEclVars(1);
  i := 0;
  idx := EclVars.GetEclVar(1);
  p := GDVars.creatureList;
  flag80 := idx and $80;
  idx := idx and $7F;
  if idx > 0 then
    while (i < idx) and (p <> nil) do begin
      p := p^.nextCharAddr;
      Inc(i);
    end;
  if p <> nil then
    GDVars.curChar := p;
  if (flag80 <> 0) and GDVars.dumpCr6C00 and GDVars.dumpCr6B00 then begin
    if GDVars.savedChar = GDVars.curChar then
      GDVars.restoreChar := 0;
    CharGen.RemoveCreature(False, True);
    CharDisp.DisplayParty(GDVars.curChar);
    GDVars.dumpCr6C00 := False;
    GDVars.dumpCr6B00 := False;
  end;
end;

{ SETUP MONSTER: set the monster id and picture, store the requested monster distance and the actual one (capped by
  MaxMonsterDist), then draw the monster }
procedure EclSetupMon;
begin
  EclVars.LoadEclVars(3);
  GDVars.monId := EclVars.GetEclVar(1);
  GDVars.zone1^[C_Gbvm.MONSTER_DIST_REQ] := EclVars.GetEclVar(2);
  GDVars.monPicId := EclVars.GetEclVar(3);
  GDVars.zone1^[C_Gbvm.MONSTER_DIST] := EclMenu.MaxMonsterDist(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing);
  if GDVars.zone1^[C_Gbvm.MONSTER_DIST_REQ] < GDVars.zone1^[C_Gbvm.MONSTER_DIST] then
    GDVars.zone1^[C_Gbvm.MONSTER_DIST] := GDVars.zone1^[C_Gbvm.MONSTER_DIST_REQ];
  EclMenu.DisplayMonster(GDVars.monId, GDVars.monPicId, Byte(GDVars.zone1^[C_Gbvm.MONSTER_DIST]),
                         GDVars.dsMonsterFlags);
end;

{ LOAD MONSTER: load monster var 1 with EclMenu.InitCreature and append it to the creature list, then append var 2 - 1
  copies, each with its own copy of the item and effect lists (prepended, so in reverse order). All use the combat icon
  var 3, loaded into the next icon slot. Stops at 63 monsters, and loads none when the icon slots are used up. }
procedure EclLoadMon;
var
  id: Byte;
  count: Byte;
  picId: Byte;
  i: Byte;
  p: Types.PCharRecord;
  q: Types.PCharRecord;
  creature: Types.PCharRecord;
  savedCur: Types.PCharRecord;
  tmpl: Types.TCharRecord;
  nm: String[12];
  item: Types.PItemRec;
  tmpIt: Types.PItemRec;
  invHead: Types.PItemRec;
  ef: Types.PEffectRec;
  tmpEf: Types.PEffectRec;
  effHead: Types.PEffectRec;
begin
  savedCur := GDVars.curChar;
  i := 1;
  EclVars.LoadEclVars(3);
  { at most 63 monsters, and an icon slot for them }
  if GDVars.creatureCnt >= MAX_LOADED_MONSTERS then Exit;
  if GDVars.gIconAnim > LAST_ICON_SLOT then Exit;
  p := nil;
  q := nil;
  id := EclVars.GetEclVar(1);
  EclMenu.InitCreature(id, creature, item, ef);
  tmpl := creature^;
  invHead := item;
  effHead := ef;
  count := EclVars.GetEclVar(2);
  if count <= 0 then count := 1;
  picId := EclVars.GetEclVar(3);
  p := GDVars.creatureList;
  nm := 'CPIC';
  MapTiles.LoadIconAnim(nm, picId, GDVars.gIconAnim);
  while p^.nextCharAddr <> nil do
    p := p^.nextCharAddr;
  p^.nextCharAddr := creature;
  p := p^.nextCharAddr;
  p^.orderNumber := GDVars.gIconAnim;
  p^.nextCharAddr := nil;
  Inc(GDVars.creatureCnt);
  Inc(i);
  while (i <= count) and (GDVars.creatureCnt < MAX_LOADED_MONSTERS) do begin
    GetMem(q, SizeOf(Types.TCharRecord));
    p^.nextCharAddr := q;
    p := p^.nextCharAddr;
    p^ := tmpl;
    p^.orderNumber := GDVars.gIconAnim;
    p^.nextCharAddr := nil;
    p^.effectsAddr := nil;
    p^.itemsAddr := nil;
    Inc(i);
    Inc(GDVars.creatureCnt);
    while item <> nil do begin
      if p^.itemsAddr = nil then begin
        GetMem(p^.itemsAddr, SizeOf(Types.TItemRec));
        p^.itemsAddr^ := item^;
        p^.itemsAddr^.next := nil;
      end else begin
        tmpIt := p^.itemsAddr;
        GetMem(p^.itemsAddr, SizeOf(Types.TItemRec));
        p^.itemsAddr^ := item^;
        p^.itemsAddr^.next := tmpIt;
      end;
      item := item^.next;
    end;
    item := invHead;
    while ef <> nil do begin
      if p^.effectsAddr = nil then begin
        GetMem(p^.effectsAddr, SizeOf(Types.TEffectRec));
        p^.effectsAddr^ := ef^;
        p^.effectsAddr^.next := nil;
      end else begin
        tmpEf := p^.effectsAddr;
        GetMem(p^.effectsAddr, SizeOf(Types.TEffectRec));
        p^.effectsAddr^ := ef^;
        p^.effectsAddr^.next := tmpEf;
      end;
      ef := ef^.next;
    end;
    ef := effHead;
  end;
  Inc(GDVars.gIconAnim);
  GDVars.monstersOn := 1;
  GDVars.curChar := savedCur;
end;

{ APPROACH: bring the monster one step closer and redraw it }
procedure EclApproach;
begin
  if GDVars.zone1^[C_Gbvm.MONSTER_DIST] > 0 then begin
    Dec(GDVars.zone1^[C_Gbvm.MONSTER_DIST]);
    EclMenu.DisplayMonster(GDVars.monId, GDVars.monPicId, Byte(GDVars.zone1^[C_Gbvm.MONSTER_DIST]),
                           GDVars.dsMonsterFlags);
  end;
  Inc(GDVars.eclIp);
end;

{ PICTURE: show picture var 1 in the view window, as an animation or a portrait depending on C_Gbvm.PIC_LOADING. 255
  removes the picture, redrawing the map view when ECL graphics or a sprite were showing. }
procedure EclPicture;
var
  picId: Byte;
begin
  EclVars.LoadEclVars(1);
  picId := EclVars.GetEclVar(1);
  if (GDVars.zone0^.view3dFlag = 0) and (picId <> 255) then
    Border.DrawWindow(3, 3, 13, 13, 0, White, '');
  if picId <> 255 then begin
    GDVars.dsMonsterFlags[1] := True;
    GDVars.eclGraphics := True;
    if GDVars.zone1^[C_Gbvm.PIC_LOADING] = 255 then begin
      Portrait.LoadAnimation('PIC', picId, 0, GDVars.animData);
      Portrait.DisplayImageBuf(3, 3, True, GDVars.animData.frames[1].pic);
    end else
      EclMenu.DisplayPortrait(Byte(GDVars.zone1^[C_Gbvm.PIC_LOADING]), picId);
  end else begin
    if ((GDVars.locTypePrev > C_Area.LOC_3D_MAP) or (GDVars.gLocType = C_Area.LOC_3D_MAP)) and
        (GDVars.eclGraphics or GDVars.sprShown) then begin
      MapView.DisplayMapView;
      GDVars.eclGraphics := False;
      GDVars.sprShown := False;
      GDVars.picDrawn := True;
    end;
    GDVars.dsMonsterFlags[0] := False;
    GDVars.dsMonsterFlags[1] := False;
  end;
end;

{ INPUT NUMBER: read a number from the player into var 2's address }
procedure EclInputNum;
var
  q: String[1];
  v: Word;
  address: Word;
begin
  EclVars.LoadEclVars(2);
  q := '';
  address := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[2], GDVars.dsGbvmUpperByte[2]);
  v := TextRend.InputUint16(q, LightGreen);
  EclVars.WriteGbvm(address, v);
end;

{ INPUT STRING: read up to 40 characters into var 2's address; an empty answer is stored as one space }
procedure EclInputStr;
var
  q: String[1];
  address: Word;
  s: String;
begin
  EclVars.LoadEclVars(2);
  q := '';
  address := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[2], GDVars.dsGbvmUpperByte[2]);
  s := TextRend.ReadString(q, LightGreen, 40);
  if s = '' then s := ' ';
  EclVars.WriteGbvmString(address, s);
end;

{ PRINT / PRINTCLEAR: show var 1 (a number is converted to text) in the message window. PRINTCLEAR clears the window and
  starts at its top. }
procedure EclPrint;
begin
  EclVars.LoadEclVars(1);
  GDVars.bottomMsgCleared := 0;
  GDVars.msgDelayFlag := 1;
  if GDVars.dsGbvmType[1] < $80 then
    GDVars.gbStrings[1] := StrUtil.NumStr(EclVars.GetEclVar(1));
  if GDVars.curOpcode = C_Ecl.PRINT then
    TextRend.ShowMessage(LightGreen, False, GDVars.gbStrings[1])
  else begin
    GDVars.curRow := C_Msg.MESSAGE_TOP;
    GDVars.curCol := C_Msg.TEXT_LEFT;
    TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM,
                                  LightGreen, True,
                                  GDVars.gbStrings[1]);
  end;
  GDVars.msgDelayFlag := 0;
end;

{ RETURN: pop the GOSUB return stack into the IP. With an empty stack it only steps past the opcode. }
procedure EclReturn;
begin
  Inc(GDVars.eclIp);
  if GDVars.dsEclStackTopPtr <> nil then begin
    GDVars.eclIp := GDVars.dsEclStackTopPtr^.addr;
    GDVars.dsEclStackSecondPtr := GDVars.dsEclStackTopPtr^.next;
    FreeMem(GDVars.dsEclStackTopPtr, SizeOf(Types.TEclRet));
    GDVars.dsEclStackTopPtr := GDVars.dsEclStackSecondPtr;
  end;
end;

{ COMPARE AND: set the eq flag when var 1 = var 2 and var 3 = var 4, else the ne flag }
procedure EclCompareAnd;
var
  v: array[1..4] of Word;
  i: Byte;
begin
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  EclVars.LoadEclVars(4);
  for i := 1 to 4 do
    v[i] := EclVars.GetEclVar(i);
  if (v[1] = v[2]) and (v[3] = v[4]) then
    GDVars.cmpFlags[0] := True
  else
    GDVars.cmpFlags[1] := True;
end;

{ IF: skip the next command unless the comparison flag for this opcode is set }
procedure EclIf;
begin
  Inc(GDVars.eclIp);
  case GDVars.curOpcode of
    C_Ecl.IF_EQ: if not GDVars.cmpFlags[0] then EclVars.SkipEclCmd;
    C_Ecl.IF_NE: if not GDVars.cmpFlags[1] then EclVars.SkipEclCmd;
    C_Ecl.IF_LT: if not GDVars.cmpFlags[2] then EclVars.SkipEclCmd;
    C_Ecl.IF_GT: if not GDVars.cmpFlags[3] then EclVars.SkipEclCmd;
    C_Ecl.IF_LE: if not GDVars.cmpFlags[4] then EclVars.SkipEclCmd;
    C_Ecl.IF_GE: if not GDVars.cmpFlags[5] then EclVars.SkipEclCmd;
  end;
end;

{ NEWECL: remember the current script id, check that the script archive is available (the merged ECL.DAX when it is in
  use), load and initialize script var 1, then stop the VM and set newEclFlag so the game loop runs its on-load entry
  (NewEclDone) }
procedure EclNewEcl;
var
  id: Byte;
  s: String[1];
begin
  EclVars.LoadEclVars(1);
  GDVars.zone0^.previousScriptId := GDVars.eclScriptId;
  id := EclVars.GetEclVar(1);
  GDVars.eclScriptId := id;
  Str(GDVars.virtualDisk, s);
  SaveLoad.CheckFileElseQuit(GDVars.gameDir + DaxIo.ArchiveName('ECL' + s) + '.dax');
  EclMenu.LoadEclScript(id);
  { a NEWECL inside a subroutine leaves return addresses on the stack, and EclInit only clears the pointer }
  FreeEclStack;
  EclMenu.EclInit;
  GDVars.eclStop := 1;
  GDVars.newEclFlag := 1;
  GDVars.filesLoaded := 0;
end;

{ LOADFILES: load GEO map var 1 when view3dFlag <> 0, or the BACPAC tile set when view3dFlag = 0. LOADPIECES: load the
  wall sets in vars 1..3 (127 loads set 0; with both mapGraphics flags set only vars 1 and 3 are used); otherwise a 255
  slot clears its wall-def cache entry. Once both have run on entering the main loop, draw the noncombat interface and
  the party. }
procedure EclLoadFiles;
var
  f: array[1..3] of Byte;
  i: Byte;
begin
  EclVars.LoadEclVars(3);
  GDVars.filesLoaded := 1;
  for i := 1 to 3 do
    f[i] := EclVars.GetEclVar(i);
  if GDVars.curOpcode = C_Ecl.LOADFILES then begin
    GDVars.mapLoaded := 1;
    if (f[1] <> 255) and (f[1] <> 127) and (GDVars.zone0^.view3dFlag <> 0) then begin
      GDVars.zone0^.mapId.value := f[1];
      View3D.Load3DMap(f[1]);
      GDVars.zone1^[C_Gbvm.MOVE_LOCKED] := 0;
    end;
    if (f[3] <> 255) and (GDVars.zone0^.view3dFlag = 0) then
      MapTiles.Load24x24Set('BACPAC', 0, 40);
  end else begin
    GDVars.piecesLoaded := 1;
    if f[1] = 127 then
      View3D.LoadWallSet(0, 1)
    else if (GDVars.zone0^.mapGraphics1 <> 0) and (GDVars.zone0^.mapGraphics2 <> 0) then begin
      View3D.LoadWallSet(f[1], 1);
      View3D.LoadWallSet(f[3], 3);
    end else
      for i := 1 to 3 do
        if f[i] <> 255 then
          View3D.LoadWallSet(f[i], i)
        else begin
          GDVars.dsWallSetCache[i].wallDefId := -1;
          GDVars.dsWallSetCache[i].symbolSlot := -1;
        end;
  end;
  if (GDVars.enteringLoop <> 0) and (GDVars.piecesLoaded <> 0) and (GDVars.mapLoaded <> 0) then begin
    CharDisp.DisplayNoncombatInterface;
    CharDisp.DisplayParty(GDVars.curChar);
    GDVars.enteringLoop := 0;
  end;
end;

{ AND / OR: combine vars 1 and 2, truncate the result to a byte, set the comparison flags as for COMPARE 0 with the
  result, and store it at var 3's address }
procedure EclAndOr;
var
  address: Word;
  v2: Word;
  v1: Word;
  r: Byte;
begin
  EclVars.LoadEclVars(3);
  v1 := EclVars.GetEclVar(1);
  v2 := EclVars.GetEclVar(2);
  address := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[3], GDVars.dsGbvmUpperByte[3]);
  if GDVars.curOpcode = C_Ecl.BIT_AND then
    r := v1 and v2
  else
    r := v1 or v2;
  EclMenu.EclCompareInt(0, r);
  EclVars.WriteGbvm(address, r);
end;

{ GETTABLE: read the value at var 1's address + var 2 into var 3's address }
procedure EclGetTable;
var
  addr1: Word;
  addr2: Word;
  sum: Word;
  v: Word;
  idx: Byte;
begin
  EclVars.LoadEclVars(3);
  addr1 := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[1], GDVars.dsGbvmUpperByte[1]);
  idx := EclVars.GetEclVar(2);
  addr2 := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[3], GDVars.dsGbvmUpperByte[3]);
  sum := addr1 + idx;
  v := EclVars.ReadGbvm(sum);
  EclVars.WriteGbvm(addr2, v);
end;

{ SAVETABLE: store var 1 at var 2's address + var 3 }
procedure EclSaveTable;
var
  idx: Word;
  address: Word;
  v: Word;
  sum: Word;
begin
  EclVars.LoadEclVars(3);
  v := EclVars.GetEclVar(1);
  address := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[2], GDVars.dsGbvmUpperByte[2]);
  idx := EclVars.GetEclVar(3);
  sum := address + idx;
  EclVars.WriteGbvm(sum, v);
end;

{ VMENU: show the prompt, then a vertical menu of the var 3 strings that follow (at most 20), and store the chosen
  index at var 1's address }
procedure EclVMenu;
var
  count: Byte;
  i: Byte;
  msg: String;
  list: Types.PItemRec;
  head: Types.PItemRec;
  q: String[1];
  idx: Integer;
  redraw: Boolean;
  address: Word;
begin
  GDVars.bottomMsgCleared := 0;
  redraw := True;
  q := '';
  i := 1;
  EclVars.LoadEclVars(3);
  address := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[1], GDVars.dsGbvmUpperByte[1]);
  msg := GDVars.gbStrings[1];
  count := EclVars.GetEclVar(3);
  Dec(GDVars.eclIp);
  EclVars.LoadEclVars(count);
  { 20 = High(gbStrings), the most strings LoadEclVars keeps }
  if count > 20 then
    count := 20;
  MenuCore.AllocStringList(count, list);
  head := list;
  GDVars.curCol := C_Msg.TEXT_LEFT;
  GDVars.curRow := C_Msg.MESSAGE_TOP;
  TextRend.ShowMessage(LightGreen, True, msg);
  while list <> nil do begin
    list^.name := GDVars.gbStrings[i];
    list^.inUse := 0;
    list := list^.next;
    Inc(i);
  end;
  list := head;
  idx := 0;
  EclMenu.EclVerticalMenu(q, q, LightMagenta, LightGreen, White, C_Msg.TEXT_LEFT, GDVars.curRow + 1,
                          C_Msg.TEXT_RIGHT,
                          C_Msg.TEXT_BOTTOM, list, False, redraw, idx, list);
  EclVars.WriteGbvm(address, idx);
  { the menu leaves list on the chosen line (nil on Escape), so free from the head }
  MenuCore.FreeStringList(head);
  TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
end;

{ HMENU: build a '~A ~B ~C' horizontal menu from the var 2 strings that follow (1 to 20) and store the chosen index at
  var 1's address. A single choice also accepts Enter, and the joystick wording of the continue prompt becomes the
  keyboard wording. }
procedure EclHMenu;
var
  count: Byte;
  ch: Byte;
  i: Byte;
  q: String[1];
  menu: String[50];
  address: Word;
  enterOk: Boolean;
  anim: Boolean;
  hlCol: Byte;
  mCol: Byte;
begin
  q := '';
  menu := '';
  EclVars.LoadEclVars(2);
  address := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[1], GDVars.dsGbvmUpperByte[1]);
  count := EclVars.GetEclVar(2);
  Dec(GDVars.eclIp);
  EclVars.LoadEclVars(count);
  { 20 = High(gbStrings), the most strings LoadEclVars keeps; a count of 0 shows gbStrings[1] alone }
  if count > 20 then
    count := 20
  else if count = 0 then
    count := 1;
  menu := '';
  if count = 1 then begin
    enterOk := True;
    hlCol := White;
    mCol := White;
    if GDVars.gbStrings[1] = 'PRESS <RETURN> OR BUTTON TO CONTINUE' then
      GDVars.gbStrings[1] := 'PRESS <ENTER>/<RETURN> TO CONTINUE';
  end else begin
    enterOk := False;
    hlCol := White;
    mCol := LightGreen;
  end;
  anim := GDVars.eclGraphics and GDVars.picDrawn;
  for i := 1 to count - 1 do
    menu := menu + '~' + GDVars.gbStrings[i] + ' ';
  menu := menu + '~' + GDVars.gbStrings[count];
  ch := EclMenu.MenuHorizontalCS(q, menu, LightMagenta, mCol, hlCol, enterOk, anim);
  EclVars.WriteGbvm(address, ch);
  TextRend.ClearRect(0, 24, 39, 24);
end;

{ CLEAR MONSTERS: forget the loaded monsters, reset the monster icon slot, and clear the treasure money and items }
procedure EclClearMon;
begin
  Inc(GDVars.eclIp);
  GDVars.creatureCnt := 0;
  GDVars.monstersOn := 0;
  GDVars.gIconAnim := 8;
  CharHlp.ClearTreasure;
end;

{ PARTY STRENGTH: store the party's rating at var 1's address: (4*cleric + (hp + 5*(AC below 0) + 5*(THAC0 below 21)
  + 8*mage)) div 10 per member, from the stored 60-biased AC and THAC0. The sum is capped at 255; v1.3 kept it in a
  Byte, which wrapped. }
procedure EclPartyStr;
var
  hp: Byte;
  th: Byte;
  mage: Byte;
  cleric: Byte;
  ac: Byte;
  strength: Word;
  address: Word;
  p: Types.PCharRecord;
begin
  EclVars.LoadEclVars(1);
  strength := 0;
  p := GDVars.creatureList;
  while p <> nil do begin
    hp := p^.hpCur;
    ac := p^.acCur;
    th := p^.thac0Cur;
    mage := p^.classLevels[C_Level.MAGE];
    cleric := p^.classLevels[C_Level.CLERIC];
    if ac > 60 then
      ac := ac - 60
    else
      ac := 0;
    if th > 39 then
      th := th - 39
    else
      th := 0;
    Inc(strength, (cleric * 4 + (hp + ac * 5 + th * 5 + mage * 8)) div 10);
    p := p^.nextCharAddr;
  end;
  address := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[1], GDVars.dsGbvmUpperByte[1]);
  if strength > 255 then
    strength := 255;
  EclVars.WriteGbvm(address, strength);
end;

{ CHECK PARTY: with var 1 = 0, report whether any member has effect var 2; with var 1 = $6BA7 (thiefSkills[3]) or $6C1B
  (movement), report the party's lowest, highest and average value. The results go to the addresses of vars 3..6
  (lowest, highest, average, found). }
procedure EclCheckParty;
var
  attr: Word;
  sum: Word;
  effId: Byte;
  p: Types.PCharRecord;
  found: Boolean;
  effect: Types.PEffectRec;
  outv: array[1..3] of Byte;
  addr1: Word;
  addr2: Word;
  addr3: Word;
  addr4: Word;
  count: Byte;

  { Store the three results and the found flag at the addresses of vars 3..6 }
  procedure Write4Gbvm;
  begin
    EclVars.WriteGbvm(addr1, outv[1]);
    EclVars.WriteGbvm(addr2, outv[2]);
    EclVars.WriteGbvm(addr3, outv[3]);
    EclVars.WriteGbvm(addr4, ShortInt(found));
  end;

begin
  EclVars.LoadEclVars(6);
  p := GDVars.creatureList;
  found := False;
  if GDVars.dsGbvmType[1] = 1 then
    attr := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[1], GDVars.dsGbvmUpperByte[1])
  else
    attr := EclVars.GetEclVar(1);
  effId := EclVars.GetEclVar(2);
  addr1 := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[3], GDVars.dsGbvmUpperByte[3]);
  addr2 := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[4], GDVars.dsGbvmUpperByte[4]);
  addr3 := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[5], GDVars.dsGbvmUpperByte[5]);
  addr4 := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[6], GDVars.dsGbvmUpperByte[6]);
  sum := 0;
  count := 0;
  outv[1] := 255;
  outv[2] := 0;
  case attr of
    0: begin
      while (p <> nil) and (not found) do begin
        found := CharHlp.HasEffect(p, effId, effect);
        p := p^.nextCharAddr;
      end;
      for count := 1 to 3 do
        outv[count] := 0;
      Write4Gbvm;
    end;
    $6BA7: begin
      while p <> nil do begin
        Inc(count);
        if p^.thiefSkills[3] < outv[1] then
          outv[1] := p^.thiefSkills[3];
        if p^.thiefSkills[3] > outv[2] then
          outv[2] := p^.thiefSkills[3];
        Inc(sum, p^.thiefSkills[3]);
        p := p^.nextCharAddr;
      end;
      outv[3] := sum div count;
      Write4Gbvm;
    end;
    $6C1B: begin
      while p <> nil do begin
        Inc(count);
        if p^.movementCur < outv[1] then
          outv[1] := p^.movementCur;
        if p^.movementCur > outv[2] then
          outv[2] := p^.movementCur;
        Inc(sum, p^.movementCur);
        p := p^.nextCharAddr;
      end;
      outv[3] := sum div count;
      Write4Gbvm;
    end;
  end;
end;

{ PARTY SURPRISE: store 1 at var 1's address when the party has a ranger, else 0, and 0 at var 2's address }
procedure EclPartySurprise;
var
  p: Types.PCharRecord;
  mod1: Byte;
  mod2: Byte;
  rangerDead: Byte;
  addr1: Word;
  addr2: Word;
begin
  EclVars.LoadEclVars(2);
  p := GDVars.creatureList;
  mod1 := 0;
  mod2 := 0;
  rangerDead := 0;
  while p <> nil do begin
    if (p^.charClass = C_Class.RANGER) or (p^.charClass = C_Class.CLERIC_RANGER) then begin
      mod1 := 1;
      rangerDead := 1;
    end;
    p := p^.nextCharAddr;
  end;
  addr1 := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[1], GDVars.dsGbvmUpperByte[1]);
  addr2 := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[2], GDVars.dsGbvmUpperByte[2]);
  EclVars.WriteGbvm(addr1, mod1);
  EclVars.WriteGbvm(addr2, mod2);
end;

{ SURPRISE: roll 1d6 for each side against targets built from vars 1..4 and store the result at C_Gbvm.SURPRISE: 0 =
  neither roll succeeded, 1 = only the first succeeded, 2 = the second succeeded. SSI quirk, kept: when both succeed,
  the 3 set for that case is overwritten by 2; the scripts' fights were tuned with it. }
procedure EclSurprise;
var
  r1: Byte;
  r2: Byte;
  i: Byte;
  result: Byte;
  v: array[1..4] of Byte;
  t1: ShortInt;
  t2: ShortInt;
begin
  EclVars.LoadEclVars(4);
  result := 0;
  for i := 1 to 4 do
    v[i] := EclVars.GetEclVar(i);
  t1 := v[4] + 2 - v[1];
  t2 := v[2] + 2 - v[3];
  r1 := FxEngine.RollDice(1, 6);
  r2 := FxEngine.RollDice(1, 6);
  if r1 <= t1 then
    if r2 <= t2 then
      result := 3
    else
      result := 1;
  if r2 <= t2 then
    result := 2;
  EclVars.WriteGbvm(C_Gbvm.SURPRISE, result);
end;

{ COMBAT: with no monsters and no duel, enter the shop or temple when C_Gbvm.ENTER_SHOP or C_Gbvm.ENTER_TEMPLE is 1, or
  the vault when C_Gbvm.ENTER_SHOP is 2, else run PostCbt.PostCombat. Otherwise fight, then run PostCbt.PostCombat.
  Afterwards restore the interface state. }
procedure EclCombat;
var
  dist: Word;
begin
  Inc(GDVars.eclIp);
  if (GDVars.monstersOn = 0) and (not GDVars.duelFlag) then begin
    if GDVars.zone1^[C_Gbvm.ENTER_SHOP] = 1 then begin
      GDVars.zone1^[C_Gbvm.ENTER_SHOP] := 0;
      Shop.ShopMainMenu;
    end else if GDVars.zone1^[C_Gbvm.ENTER_SHOP] = 2 then begin
      { New Phlan's vault, The Hoarder's Respite: the data patch for #606 stores 2 }
      GDVars.zone1^[C_Gbvm.ENTER_SHOP] := 0;
      Vault.VaultMenu;
    end else if GDVars.zone1^[C_Gbvm.ENTER_TEMPLE] = 1 then begin
      GDVars.zone1^[C_Gbvm.ENTER_TEMPLE] := 0;
      Temple.TempleMainMenu;
    end else
      PostCbt.PostCombat;
  end else begin
    dist := EclMenu.MaxMonsterDist(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing);
    if dist < GDVars.zone1^[C_Gbvm.MONSTER_DIST] then
      GDVars.zone1^[C_Gbvm.MONSTER_DIST] := dist;
    Combat.CombatMain;
    PostCbt.PostCombat;
    if GDVars.zone0^.view3dFlag = 0 then begin
      MapTiles.Load24x24Set('BACPAC', 0, 40);
      MapTiles.LoadIconAnim('ICON', 0, 9);
      MapTiles.LoadIconAnim('ICON', 1, 10);
      MapTiles.LoadIconAnim('ICON', 2, 11);
    end;
    if GDVars.duelFlag then
      GDVars.duelFlag := False;
  end;
  if GDVars.gLocType = C_Area.LOC_3D_MAP then
    GDVars.ifcState := C_Ifc.INDOORS
  else
    GDVars.ifcState := C_Ifc.OUTDOORS;
  GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] := GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] and 1;
  FillChar(GDVars.dsMonsterFlags, SizeOf(GDVars.dsMonsterFlags), 0);
  GDVars.eclGraphics := False;
  CharDisp.DisplayNoncombatInterface;
end;

{ ONGOTO / ONGOSUB: jump to or call address number var 1 of the var 2 addresses that follow (at most 64); a selector of
  var 2 or more, or 64 or more, falls through past the list }
procedure EclOnGoto;
var
  sel: Byte;
  count: Byte;
  i: Byte;
  done: Boolean;
begin
  done := False;
  EclVars.LoadEclVars(2);
  sel := EclVars.GetEclVar(1);
  count := EclVars.GetEclVar(2);
  Dec(GDVars.eclIp);
  EclVars.LoadEclVars(count);
  { 64 = High(dsGbvmLowerByte), the most addresses LoadEclVars keeps; a selector past them falls through }
  if count > 64 then
    count := 64;
  i := 0;
  while (i < count) and (not done) do begin
    if sel = i then begin
      if GDVars.curOpcode = C_Ecl.ONGOTO then
        GDVars.eclIp := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[i + 1], GDVars.dsGbvmUpperByte[i + 1])
      else
        EclMenu.EclGosub(i + 1);
      done := True;
    end else
      Inc(i);
  end;
end;

{ TREASURE: set the treasure money from vars 1..7 and add items by var 8: below $80 it selects an ITEM archive list,
  $80+n generates n random items and 255 none. Item nodes are prepended, and a trailing part record in the list is
  ignored. A second roll of 48 or 49 (empty entries in ITEMS, not items) is rolled again; v1.3 picked no item id for
  it, so the item reused the previous item's id, or for the first item an uninitialised one. }
procedure EclTreasure;
var
  i: ShortInt;
  tId: Byte;
  j: Byte;
  it: Types.TItemRec;
  tmp: Types.PItemRec;
  walk: Types.PItemRec;
  roll3: Byte;
  roll: Byte;
  roll2: Byte;
  itemId: Byte;
  offset: Word;
  sizeRead: Word;
  s: String[1];
  data: Types.PByteArr;
begin
  EclVars.LoadEclVars(8);
  for i := C_Money.COPPER to C_Money.JEWELRY do
    GDVars.treasureMoney[i] := EclVars.GetEclVar(Byte(i) + 1);
  tId := EclVars.GetEclVar(8);
  if tId < $80 then begin
    Str(GDVars.virtualDisk, s);
    DaxIo.LoadDax('ITEM' + s, '.dax', tId, sizeRead, data);
    if sizeRead = 0 then begin
      TextRend.DisplayAndPause(White, 'Unable to find item file');
      GameIo.ExitGame;
    end;
    offset := 0;
    while sizeRead - offset >= SizeOf(Types.TItemRec) do begin
      Move(data^[offset], it, SizeOf(Types.TItemRec));
      it.next := nil;
      Inc(offset, SizeOf(Types.TItemRec));
      if GDVars.treasureItems = nil then begin
        GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
        GDVars.treasureItems^ := it;
      end else begin
        tmp := GDVars.treasureItems;
        GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
        GDVars.treasureItems^ := it;
        GDVars.treasureItems^.next := tmp;
      end;
    end;
    FreeMem(data, sizeRead);
  end else begin
    if tId = 255 then Exit;
    i := tId - $80;
    for j := 1 to i do begin
      roll := FxEngine.RollDice(1, 100);
      case roll of
        1..60: begin
          repeat
            roll2 := FxEngine.RollDice(1, 100);
          until (roll2 <> 48) and (roll2 <> 49);
          case roll2 of
            1..47, 50..59:
              if roll2 = 45 then
                itemId := 59
              else
                itemId := roll2;
            60..90: begin
              roll2 := FxEngine.RollDice(1, 10);
              case roll2 of
                1..4: itemId := 36;
                5..7: itemId := 35;
                8: itemId := 34;
                9: itemId := 37;
                10: itemId := 38;
              end;
            end;
            91..94: itemId := 73;
            95..97: itemId := 93;
            98..100: itemId := 77;
          end;
        end;
        61..85: itemId := 61;
        86..92: itemId := 62;
        91..98: begin
          roll3 := FxEngine.RollDice(1, 16);
          case roll3 of
            1..7: itemId := 71;
            8..9: itemId := 70;
            10: itemId := 84;
            11, 12: itemId := 78;
            13, 14: itemId := 79;
            15: itemId := 92;
            16: itemId := 67;
          end;
        end;
        99, 100: itemId := 69;
      end;
      Money.GenerateRandomItem(itemId, @it);
      if GDVars.treasureItems = nil then begin
        GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
        GDVars.treasureItems^ := it;
        GDVars.treasureItems^.next := nil;
      end else begin
        tmp := GDVars.treasureItems;
        GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
        GDVars.treasureItems^ := it;
        GDVars.treasureItems^.next := tmp;
      end;
    end;
    walk := GDVars.treasureItems;
    while walk <> nil do begin
      CharHlp.PrintItemString(walk, 0, 0, False, False);
      walk := walk^.next;
    end;
  end;
end;

{ ROB: take var 2 percent of the money (at most 100) and steal each item with a var 3 percent chance, from the current
  character or, when var 1 is nonzero, from every member; each robbed character's stats are recalculated. v1.3 used
  var 2 for the item chance as well, so a toll that only took coins (var 3 = 0) also stole items; Curse reads var 3. }
procedure EclRob;
var
  whole: Byte;
  pct: Byte;
  chance: Byte;
  p: Types.PCharRecord;
  inv: Types.PItemRec;
  fraction: Real;
begin
  EclVars.LoadEclVars(3);
  whole := EclVars.GetEclVar(1);
  pct := EclVars.GetEclVar(2);
  if pct > 100 then
    pct := 100;
  fraction := (100 - pct) / 100;
  chance := EclVars.GetEclVar(3);
  if whole = 0 then begin
    EclMenu.RobMoney(fraction, GDVars.curChar);
    EclMenu.RobItems(chance, GDVars.curChar);
    CharHlp.RecalcStats(GDVars.curChar);
  end else begin
    p := GDVars.creatureList;
    while p <> nil do begin
      inv := p^.itemsAddr;
      EclMenu.RobMoney(fraction, p);
      EclMenu.RobItems(chance, p);
      CharHlp.RecalcStats(p);
      p := p^.nextCharAddr;
    end;
  end;
  { the party list shows the new armor class at once }
  CharDisp.DisplayParty(GDVars.curChar);
end;

{ Run the encounter menu until combat, flight, parley or monster retreat ends it. WAIT and ADVANCE update the encounter
  and repeat; write the outcome to var 4's address: 0 = monsters flee, 1 = combat, 2 = party flees, 3 = parley }
procedure EclEncounter;
var
  sel: Byte;
  resp: array[0..4] of Byte;
  msgs: array[1..3] of String;
  msg: String;
  fleePar: Byte;
  fleeMon: Byte;
  i: Byte;
  hiMove: Byte;
  loMove: Byte;
  waited: Boolean;
  clearW: Boolean;
  anim: Boolean;
  menu: String[40];
  q: String[1];
  choice: Byte;
  k: Byte;
  address: Word;
begin
  GDVars.inEncMenu := 1;
  GDVars.bottomMsgCleared := 0;
  GDVars.msgDelayFlag := 1;
  EclMenu.MoveExtremes(hiMove, loMove);
  q := '';
  EclVars.LoadEclVars(14);
  GDVars.monId := EclVars.GetEclVar(1);
  GDVars.zone1^[C_Gbvm.MONSTER_DIST_REQ] := EclVars.GetEclVar(2);
  GDVars.monPicId := EclVars.GetEclVar(3);
  address := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[4], GDVars.dsGbvmUpperByte[4]);
  for i := 0 to 4 do
    resp[i] := EclVars.GetEclVar(i + 5);
  for i := 1 to 3 do
    msgs[i] := GDVars.gbStrings[i];
  fleePar := EclVars.GetEclVar(13);
  fleeMon := EclVars.GetEclVar(14);
  GDVars.zone1^[C_Gbvm.MONSTER_DIST] := EclMenu.MaxMonsterDist(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing);
  if GDVars.zone1^[C_Gbvm.MONSTER_DIST_REQ] < GDVars.zone1^[C_Gbvm.MONSTER_DIST] then
    GDVars.zone1^[C_Gbvm.MONSTER_DIST] := GDVars.zone1^[C_Gbvm.MONSTER_DIST_REQ];
  EclMenu.DisplayMonster(GDVars.monId, GDVars.monPicId, Byte(GDVars.zone1^[C_Gbvm.MONSTER_DIST]),
                         GDVars.dsMonsterFlags);
  repeat
    anim := GDVars.eclGraphics and GDVars.picDrawn;
    clearW := True;
    waited := False;
    GDVars.curCol := C_Msg.TEXT_LEFT;
    GDVars.curRow := C_Msg.MESSAGE_TOP;
    case GDVars.zone1^[C_Gbvm.MONSTER_DIST] of
      0: begin
        k := 1;
        repeat
          msg := msgs[k];
          Inc(k);
        until (msg <> '') or (k > 3);
      end;
      1: begin
        k := 2;
        repeat
          msg := msgs[k];
          Inc(k);
          if k > 3 then k := 1;
        until (msg <> '') or (k = 2);
      end;
      2: begin
        k := 3;
        repeat
          msg := msgs[k];
          Inc(k);
          if k > 3 then k := 1;
        until (msg <> '') or (k = 3);
      end;
    end;
    if msg = '' then
      clearW := False;
    TextRend.ShowMessage(LightGreen, clearW, msg);
    if (GDVars.zone1^[C_Gbvm.MONSTER_DIST] = 0) or (GDVars.zone0^.view3dFlag = 0) then
      menu := '~COMBAT ~WAIT ~FLEE ~PARLAY'
    else
      menu := '~COMBAT ~WAIT ~FLEE ~ADVANCE';
    sel := EclMenu.MenuHorizontalCS(q, menu, LightMagenta, LightGreen, White, False, anim);
    if ((GDVars.zone1^[C_Gbvm.MONSTER_DIST] = 0) or (GDVars.zone0^.view3dFlag = 0)) and (sel = 3) then
      sel := 4;
    choice := resp[sel];
    case choice of
      0:
        if sel <> 2 then
          EclVars.WriteGbvm(address, 1)
        else begin
          if loMove >= fleePar then
            EclVars.WriteGbvm(address, 2)
          else
            EclVars.WriteGbvm(address, 1);
        end;
      1:
        case sel of
          0: EclVars.WriteGbvm(address, 1);
          1: begin
            waited := True;
            TextRend.ShowMessage(LightGreen, True, 'Both sides wait.');
          end;
          2: EclVars.WriteGbvm(address, 2);
          3: begin
            if GDVars.zone1^[C_Gbvm.MONSTER_DIST] <> 0 then begin
              Dec(GDVars.zone1^[C_Gbvm.MONSTER_DIST]);
              EclMenu.DisplayMonster(GDVars.monId, GDVars.monPicId, Byte(GDVars.zone1^[C_Gbvm.MONSTER_DIST]),
                                     GDVars.dsMonsterFlags);
            end else
              TextRend.ShowMessage(LightGreen, True, 'Both sides wait.');
            waited := True;
          end;
          4:
            if GDVars.zone1^[C_Gbvm.MONSTER_DIST] <= 0 then
              EclVars.WriteGbvm(address, 3)
            else begin
              Dec(GDVars.zone1^[C_Gbvm.MONSTER_DIST]);
              EclMenu.DisplayMonster(GDVars.monId, GDVars.monPicId, Byte(GDVars.zone1^[C_Gbvm.MONSTER_DIST]),
                                     GDVars.dsMonsterFlags);
              waited := True;
            end;
        end;
      2:
        case sel of
          0:
            if fleeMon > hiMove then begin
              EclVars.WriteGbvm(address, 0);
              GDVars.curCol := C_Msg.TEXT_LEFT;
              GDVars.curRow := C_Msg.MESSAGE_TOP;
              TextRend.ShowMessage(LightGreen, True, 'The monsters flee.');
            end else
              EclVars.WriteGbvm(address, 1);
          1..4: begin
            EclVars.WriteGbvm(address, 0);
            GDVars.curCol := C_Msg.TEXT_LEFT;
            GDVars.curRow := C_Msg.MESSAGE_TOP;
            TextRend.ShowMessage(LightGreen, True, 'The monsters flee.');
          end;
        end;
      3:
        case sel of
          0: EclVars.WriteGbvm(address, 1);
          1, 3: begin
            if GDVars.zone1^[C_Gbvm.MONSTER_DIST] <> 0 then begin
              Dec(GDVars.zone1^[C_Gbvm.MONSTER_DIST]);
              EclMenu.DisplayMonster(GDVars.monId, GDVars.monPicId, Byte(GDVars.zone1^[C_Gbvm.MONSTER_DIST]),
                                     GDVars.dsMonsterFlags);
            end else
              TextRend.ShowMessage(LightGreen, True, 'Both sides wait.');
            waited := True;
          end;
          2: EclVars.WriteGbvm(address, 2);
          4:
            if GDVars.zone1^[C_Gbvm.MONSTER_DIST] <= 0 then
              EclVars.WriteGbvm(address, 3)
            else begin
              Dec(GDVars.zone1^[C_Gbvm.MONSTER_DIST]);
              EclMenu.DisplayMonster(GDVars.monId, GDVars.monPicId, Byte(GDVars.zone1^[C_Gbvm.MONSTER_DIST]),
                                     GDVars.dsMonsterFlags);
              waited := True;
            end;
        end;
      4:
        case sel of
          0: EclVars.WriteGbvm(address, 1);
          1, 3, 4:
            if GDVars.zone1^[C_Gbvm.MONSTER_DIST] <= 0 then
              EclVars.WriteGbvm(address, 3)
            else begin
              Dec(GDVars.zone1^[C_Gbvm.MONSTER_DIST]);
              EclMenu.DisplayMonster(GDVars.monId, GDVars.monPicId, Byte(GDVars.zone1^[C_Gbvm.MONSTER_DIST]),
                                     GDVars.dsMonsterFlags);
              waited := True;
            end;
          2: EclVars.WriteGbvm(address, 2);
        end;
    end;
  until not waited;
  TextRend.ClearRect(0, 24, 39, 24);
  GDVars.msgDelayFlag := 0;
  GDVars.inEncMenu := 0;
end;

{ PARLAY: offer the five attitudes, with a single space as the prompt, and store var (choice + 1) at var 6's address }
procedure EclParlay;
var
  sel: Byte;
  v5: Byte;
  i: Byte;
  v: array[0..4] of Byte;
  address: Word;
  space: Char;
begin
  EclVars.LoadEclVars(6);
  space := ' ';
  for i := 0 to 4 do
    v[i] := EclVars.GetEclVar(i + 1);
  sel := EclMenu.MenuHorizontalCS(space, '~HAUGHTY ~SLY ~NICE ~MEEK ~ABUSIVE', LightMagenta, LightGreen,
                                  White, False, False);
  address := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[6], GDVars.dsGbvmUpperByte[6]);
  v5 := v[sel];
  EclVars.WriteGbvm(address, v5);
end;

{ FIND ITEM: set the eq comparison flag (else ne) if any party member carries an item of type var 1 }
procedure EclFindItem;
var
  itemType: Byte;
  p: Types.PCharRecord;
  item: Types.PItemRec;
  found: Boolean;
begin
  EclVars.LoadEclVars(1);
  found := False;
  itemType := EclVars.GetEclVar(1);
  FillChar(GDVars.cmpFlags, SizeOf(GDVars.cmpFlags), 0);
  GDVars.cmpFlags[1] := True;
  p := GDVars.creatureList;
  while (p <> nil) and (not found) do begin
    item := p^.itemsAddr;
    while (item <> nil) and (not found) do begin
      if itemType = item^.itemType then begin
        GDVars.cmpFlags[0] := True;
        GDVars.cmpFlags[1] := False;
        found := True;
      end;
      item := item^.next;
    end;
    p := p^.nextCharAddr;
  end;
end;

{ DELAY: pause for the text delay }
procedure EclDelay;
begin
  Inc(GDVars.eclIp);
  TextRend.PauseOnly;
end;

{ DAMAGE: apply scripted damage, then check for total party defeat. Without attack bit 7, attack counts attack rolls
  against random members (value is passed to FxEngine.AttackRollNoAttacker) and damage is rerolled after each roll. With
  bit 7, bit 6 selects the whole party, bit 5 skips whole-party saves, and the low five bits modify the save. value bit
  7 selects the current character instead of a random one; its low three bits select the save type. The
  current-character path subtracts one from that type, and type 0 there means no save. }
procedure EclDamage;
var
  attack: Byte;
  dice: Byte;
  sides: Byte;
  i: Byte;
  saveMod: Byte;
  value: Byte;
  bonus: Byte;
  count: Byte;
  saveType: Byte;
  k: Byte;
  dmg: Word;
  p: Types.PCharRecord;
  q: Types.PCharRecord;
  savedCur: Types.PCharRecord;
  dead19: Byte;
  allParty: Byte;
begin
  savedCur := GDVars.curChar;
  dead19 := 0;
  allParty := 0;
  p := GDVars.creatureList;
  EclVars.LoadEclVars(5);
  attack := EclVars.GetEclVar(1);
  dice := EclVars.GetEclVar(2);
  sides := EclVars.GetEclVar(3);
  bonus := EclVars.GetEclVar(4);
  value := EclVars.GetEclVar(5);
  dmg := bonus + FxEngine.RollDice(dice, sides);
  if attack and $40 <> 0 then
    allParty := 1
  else
    count := FxEngine.RollDice(1, Byte(GDVars.zone1^[C_Gbvm.PARTY_SIZE]));
  if attack and $80 <> 0 then begin
    saveMod := attack and $1F;
    saveType := value and 7;
    if allParty <> 0 then begin
      while p <> nil do begin
        if attack and $20 <> 0 then
          EclMenu.EclInflictDamage(dmg, p)
        else begin
          if not FxEngine.RollSavingThrow(p, saveType, saveMod) then
            EclMenu.EclInflictDamage(dmg, p);
        end;
        p := p^.nextCharAddr;
      end;
    end else if value and $80 <> 0 then begin
      if (saveType = 0) or (not FxEngine.RollSavingThrow(GDVars.curChar, saveType - 1, saveMod)) then
        EclMenu.EclInflictDamage(dmg, GDVars.curChar);
    end else begin
      for i := 2 to count do
        p := p^.nextCharAddr;
      if not FxEngine.RollSavingThrow(p, saveType, saveMod) then
        EclMenu.EclInflictDamage(dmg, p);
    end;
  end else begin
    for i := 1 to attack do begin
      p := GDVars.creatureList;
      count := FxEngine.RollDice(1, Byte(GDVars.zone1^[C_Gbvm.PARTY_SIZE]));
      k := 1;
      while k < count do begin
        p := p^.nextCharAddr;
        Inc(k);
      end;
      if FxEngine.AttackRollNoAttacker(p, value) then
        EclMenu.EclInflictDamage(dmg, p);
      dmg := bonus + FxEngine.RollDice(dice, sides);
    end;
  end;
  q := GDVars.creatureList;
  GDVars.partyDefeated := True;
  while q <> nil do begin
    if q^.enabled <> 0 then
      GDVars.partyDefeated := False;
    q := q^.nextCharAddr;
  end;
  if GDVars.partyDefeated then begin
    Border.DrawWindow(1, 1, 38, 22, 0, White, 'The END!');
    GDVars.curCol := 2;
    GDVars.curRow := 2;
    TextRend.DisplayMessageWindow(1, 1, 38, 22, LightGreen, True, 'The entire party is killed!');
    Delay(3000);
  end;
  GDVars.curChar := savedCur;
  TextRend.DisplayAndPause(White, 'press <enter>/<return> to continue');
end;

{ SPRITE OFF: if a sprite is showing, redraw the map view over it }
procedure EclSpriteOff;
begin
  Inc(GDVars.eclIp);
  if GDVars.sprShown then begin
    MapView.DisplayMapView;
    GDVars.sprShown := False;
    GDVars.eclGraphics := False;
  end;
end;

{ CLOCK: advance the clock by var 1, in minutes, in steps of at most 255 (AdvanceTime takes a Byte). }
procedure EclClock;
var
  n: Word;
begin
  EclVars.LoadEclVars(1);
  n := EclVars.GetEclVar(1);
  while n > 255 do begin
    FxEngine.AdvanceTime(255, 1);
    Dec(n, 255);
  end;
  FxEngine.AdvanceTime(n, 1);
end;

{ PRINTRETURN: move the message cursor to the start of the next line and clear protNewLine }
procedure EclPrintRet;
begin
  Inc(GDVars.eclIp);
  if GDVars.protNewLine <> 0 then begin
    GDVars.curCol := C_Msg.TEXT_LEFT;
    Inc(GDVars.curRow);
    GDVars.protNewLine := 0;
  end else begin
    GDVars.curCol := C_Msg.TEXT_LEFT;
    Inc(GDVars.curRow);
  end;
end;

{ CLEAR BOX: clear the 3D view box and note it for PROTECTION }
procedure EclClearBox;
begin
  Inc(GDVars.eclIp);
  TextRend.ClearRect(1, 1, 15, 15);
  GDVars.dsEcl3dClearFlag := 1;
end;

{ WHO: let the player pick a party member, prompting with var 1; the choice becomes the current character }
procedure EclWho;
var
  msg: String;
begin
  EclVars.LoadEclVars(1);
  TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
  msg := GDVars.gbStrings[1];
  CharDisp.SelectChar(msg, False, GDVars.curChar);
end;

{ ADD NPC: add creature var 1 to the party as an NPC whose npc byte is half the morale var 2 with bit 7 set. Monster id
  24 joins as hostile, every other id as friendly. A full party (8 members) takes nobody, and the current character is
  left as it was. }
procedure EclAddNpc;
var
  id: Byte;
  morale: Byte;
  partySize: Byte;
begin
  EclVars.LoadEclVars(2);
  id := EclVars.GetEclVar(1);
  partySize := GDVars.zone1^[C_Gbvm.PARTY_SIZE];
  EclMenu.AddCreatureToParty(id);
  if GDVars.zone1^[C_Gbvm.PARTY_SIZE] = partySize then Exit;
  morale := EclVars.GetEclVar(2);
  morale := morale div 2;
  morale := morale or C_Npc.FLAG;
  GDVars.curChar^.npc := morale;
  if id <> 24 then
    GDVars.curChar^.hostile := 0
  else
    GDVars.curChar^.hostile := 1;
  CharHlp.RecalcStats(GDVars.curChar);
  CharDisp.DisplayParty(GDVars.curChar);
end;

{ SPELL: find the first party member, in party order, who is okay and has spell var 1 memorized (not pending) in
  memorizedSpells[1..20]. Write the slot to var 2's address as its index - 1, which is how scripts reach it through the
  character window at $6B20 (SpecialWriteZ1 maps $6B20 to memorizedSpells[1]), and the member's party position (0 =
  the first, as LOAD CHARACTER counts) to var 3's. With nobody found, the slot is 255. memorizedSpells[0] cannot be
  reached through the window, so it is not searched. Kovel Mansion's locked chest uses it for "Cast Knock". }
procedure EclSpell;
var
  spellId: Byte;
  slot: Byte;
  idx: Byte;
  k: Byte;
  p: Types.PCharRecord;
  found: Boolean;
  addr1: Word;
  addr2: Word;
begin
  EclVars.LoadEclVars(3);
  spellId := EclVars.GetEclVar(1);
  addr1 := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[2], GDVars.dsGbvmUpperByte[2]);
  addr2 := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[3], GDVars.dsGbvmUpperByte[3]);
  slot := 255;
  idx := 0;
  found := False;
  p := GDVars.creatureList;
  while (p <> nil) and (not found) do begin
    if p^.status = C_Status.OKAY then
      for k := 1 to SizeOf(p^.memorizedSpells) - 1 do
        if (not found) and (p^.memorizedSpells[k] = spellId) then begin
          found := True;
          slot := k - 1;
        end;
    if not found then begin
      p := p^.nextCharAddr;
      Inc(idx);
    end;
  end;
  EclVars.WriteGbvm(addr1, slot);
  EclVars.WriteGbvm(addr2, idx);
end;

{ CALL: dispatch ECL service calls by address: refresh the view, start a duel or solo fight, play a sound, step forward
  or update the wall state. }
procedure EclCall;
var
  address: Word;
  key: Word;
begin
  EclVars.LoadEclVars(1);
  address := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[1], GDVars.dsGbvmUpperByte[1]);
  key := address - $7FFF;
  case key of
    { address $2C90 }
    $AC91: begin
      GDVars.eventAtCell := View3D.GetMapEvent(GDVars.gMapX, GDVars.gMapY);
      if GDVars.filesLoaded <> 0 then
        if GDVars.eclGraphics or GDVars.sprShown or GDVars.picRegionW or GDVars.movedParty or
            GDVars.redrawSky then begin
          MapView.DisplayMapView;
          CharDisp.PrintMiscInfo;
          GDVars.redrawSky := False;
          GDVars.picRegionW := False;
          GDVars.movedParty := False;
          GDVars.eclGraphics := False;
          GDVars.sprShown := False;
        end;
    end;
    { address $8000 }
    1:
      EclMenu.CharFightsAlone(1);
    { address $8001 }
    2:
      EclMenu.CharFightsAlone(0);
    { address $BA03 }
    $3A04: begin
      case GDVars.sndEffect of
        8: SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.STEP]);
        10: SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.ECL_CUE]);
      end;
    end;
    { address $C01E }
    $401F:
      EclMenu.EclMoveForward;
    { address $C018 }
    $4019:
      if GDVars.gLocType = C_Area.LOC_3D_MAP then
        GDVars.wallAhead := View3D.GetWallType(GDVars.gMapX, GDVars.gMapY, GDVars.gFacing);
  end;
end;

{ Run the pre-camp script entry (scriptEntryAddrs[3]) and the camp menu, then the camp-interruption entry
  (scriptEntryAddrs[4]) if camp was interrupted. Redraw the map view and clear recentSaved. }
procedure EnterCamp;
var
  interrupted: Boolean;
begin
  interrupted := False;
  EclVm.CallEclScript(GDVars.scriptEntryAddrs[3]);
  Camp.CampMainMenu(interrupted);
  if interrupted then begin
    CharDisp.DisplayNoncombatInterface;
    EclVm.CallEclScript(GDVars.scriptEntryAddrs[4]);
  end;
  MapView.DisplayMapView;
  GDVars.recentSaved := 0;
end;

{ PROGRAM: restore the backed-up current character, then run program var 1: PROG_TRAINING (the training hall menu),
  PROG_WIN_GAME, or PROG_CAMP (camp with the IP preserved, then EXIT). Other values do nothing. }
procedure EclProgram;
var
  v: Byte;
  savedIp: Word;
begin
  if GDVars.restoreChar <> 0 then begin
    GDVars.curChar := GDVars.savedChar;
    GDVars.restoreChar := 0;
  end;
  EclVars.LoadEclVars(1);
  v := EclVars.GetEclVar(1);
  case v of
    PROG_TRAINING: begin
      CharGen.MainMenu;
      CharDisp.DisplayNoncombatInterface;
    end;
    PROG_WIN_GAME:
      Ending.WinGame;
    PROG_CAMP: begin
      savedIp := GDVars.eclIp;
      EclVm.EnterCamp;
      GDVars.eclIp := savedIp;
      EclVm.EclExit;
    end;
  end;
end;

{ PROTECTION: draw the text at var 1's address at the message cursor; each byte is one less than its game-font glyph,
  and a $00 or $FF byte ends it, as does the right edge of the text area. After CLEAR BOX, text below row 13 moves into
  the 3D box and EXIT redraws its border. }
procedure EclProtection;
var
  address: Word;
  a: Word;
  i: Word;
  c: Byte;
  done: Boolean;
begin
  FillChar(GDVars.dsMonsterFlags, SizeOf(GDVars.dsMonsterFlags), 0);
  GDVars.eclGraphics := False;
  EclVars.LoadEclVars(1);
  address := EclVars.CombineBytesToWord(GDVars.dsGbvmLowerByte[1], GDVars.dsGbvmUpperByte[1]);
  i := 0;
  done := False;
  if (GDVars.dsEcl3dClearFlag <> 0) and (GDVars.curRow > 13) then begin
    GDVars.curRow := 5;
    GDVars.curCol := 2;
    GDVars.protTextShown := 1;
  end;
  GDVars.protNewLine := 1;
  repeat
    a := address + i;
    c := EclVars.ReadGbvm(a) + 1;
    if c > 1 then begin
      TextRend.RenderChar(GDVars.curCol, GDVars.curRow, White, 1, c, 0);
      Inc(GDVars.curCol);
      Inc(i);
    end else
      done := True;
  { v1.3 stopped only at the end byte, with a Byte offset that wrapped, so text with none looped forever }
  until done or (GDVars.curCol > C_Msg.TEXT_RIGHT);
  Inc(GDVars.curRow);
end;

{ Run the command at the IP (curOpcode). An opcode with no handler, such as $1F, is stepped over as SkipEclCmd steps over
  it (its operands where SkipEclCmd knows them, otherwise the opcode byte alone); v1.3 left the IP on it, so
  CallEclScript ran it forever. }
procedure ExecNextEclCmd;
begin
  case GDVars.curOpcode of
    C_Ecl.EXIT_SCRIPT: EclVm.EclExit;
    C_Ecl.JUMP: EclVm.EclGoto;
    C_Ecl.GOSUB: EclVm.EclGosubCmd;
    C_Ecl.COMPARE: EclVm.EclCompare;
    C_Ecl.ADD, C_Ecl.SUBTRACT, C_Ecl.DIVIDE, C_Ecl.MULTIPLY: EclVm.EclArith;
    C_Ecl.RANDOM_NUMBER: EclVm.EclRandom;
    C_Ecl.SAVE: EclVm.EclSave;
    C_Ecl.LOAD_CHAR: EclVm.EclLoadChar;
    C_Ecl.LOAD_MON: EclVm.EclLoadMon;
    C_Ecl.SETUP_MON: EclVm.EclSetupMon;
    C_Ecl.APPROACH: EclVm.EclApproach;
    C_Ecl.PICTURE: EclVm.EclPicture;
    C_Ecl.INPUT_NUM: EclVm.EclInputNum;
    C_Ecl.INPUT_STR: EclVm.EclInputStr;
    C_Ecl.PRINT, C_Ecl.PRINTCLEAR: EclVm.EclPrint;
    C_Ecl.RETURN: EclVm.EclReturn;
    C_Ecl.COMPARE_AND: EclVm.EclCompareAnd;
    C_Ecl.VMENU: EclVm.EclVMenu;
    C_Ecl.IF_EQ, C_Ecl.IF_NE, C_Ecl.IF_LT, C_Ecl.IF_GT, C_Ecl.IF_LE, C_Ecl.IF_GE: EclVm.EclIf;
    C_Ecl.CLEAR_MON: EclVm.EclClearMon;
    C_Ecl.PARTY_STR: EclVm.EclPartyStr;
    C_Ecl.CHECK_PARTY: EclVm.EclCheckParty;
    C_Ecl.NEWECL: EclVm.EclNewEcl;
    C_Ecl.LOADFILES, C_Ecl.LOADPIECES: EclVm.EclLoadFiles;
    C_Ecl.PARTY_SURPR: EclVm.EclPartySurprise;
    C_Ecl.SURPRISE: EclVm.EclSurprise;
    C_Ecl.START_COMBAT: EclVm.EclCombat;
    C_Ecl.ONGOTO, C_Ecl.ONGOSUB: EclVm.EclOnGoto;
    C_Ecl.TREASURE: EclVm.EclTreasure;
    C_Ecl.ROB: EclVm.EclRob;
    C_Ecl.ENCOUNTER: EclVm.EclEncounter;
    C_Ecl.GETTABLE: EclVm.EclGetTable;
    C_Ecl.HMENU: EclVm.EclHMenu;
    C_Ecl.PARLAY: EclVm.EclParlay;
    C_Ecl.CALL: EclVm.EclCall;
    C_Ecl.DAMAGE: EclVm.EclDamage;
    C_Ecl.BIT_AND, C_Ecl.BIT_OR: EclVm.EclAndOr;
    C_Ecl.SPRITE_OFF: EclVm.EclSpriteOff;
    C_Ecl.FIND_ITEM: EclVm.EclFindItem;
    C_Ecl.PRINT_RET: EclVm.EclPrintRet;
    C_Ecl.CLOCK: EclVm.EclClock;
    C_Ecl.SAVE_TABLE: EclVm.EclSaveTable;
    C_Ecl.ADD_NPC: EclVm.EclAddNpc;
    C_Ecl.RUN_PROGRAM: EclVm.EclProgram;
    C_Ecl.WHO: EclVm.EclWho;
    C_Ecl.PAUSE: EclVm.EclDelay;
    C_Ecl.SPELL: EclVm.EclSpell;
    C_Ecl.PROTECTION: EclVm.EclProtection;
    C_Ecl.CLEAR_BOX: EclVm.EclClearBox;
  else
    EclVars.SkipEclCmd;
  end;
end;

{ Runs commands at address until EXIT/NEWECL stops the VM or the party is defeated }
procedure CallEclScript(address: Word);
begin
  GDVars.eclIp := address;
  GDVars.eclStop := 0;
  while (GDVars.eclStop = 0) and (not GDVars.partyDefeated) do begin
    GDVars.prevOpcode := GDVars.curOpcode;
    GDVars.curOpcode := GDVars.zone3^[GDVars.eclIp];
    { STING Ctrl-L's trace log (#612), as Curse writes it }
    if GDVars.debugTraceEnabled then
      WriteLn(GDVars.debugFile, EclTrace.OpName(GDVars.curOpcode));
    EclVm.ExecNextEclCmd;
  end;
  GDVars.eclStop := 0;
end;

{ Refresh the event byte, run the new script's on-load entry (scriptEntryAddrs[5]), and when view3dFlag = 0 set the
  location type for the three wilderness scripts (on the central one, call Ending.YarashComplete once the Yarash pyramid
  is done). Redraw, then run scriptEntryAddrs[1] and the search entry. newEclFlag is cleared before scriptEntryAddrs[1]
  runs, so this repeats while that entry itself runs NEWECL. }
procedure NewEclDone;
var
  savedCur: Types.PCharRecord;
begin
  repeat
    GDVars.eventAtCell := View3D.GetMapEvent(GDVars.gMapX, GDVars.gMapY);
    GDVars.zone1^[C_Gbvm.LEAVE_MAP] := 0;
    savedCur := GDVars.curChar;
    GDVars.locTypePrev := GDVars.gLocType;
    GDVars.gLocType := C_Area.LOC_3D_MAP;
    EclVm.CallEclScript(GDVars.scriptEntryAddrs[5]);
    GDVars.ifcState := C_Ifc.INDOORS;
    if GDVars.zone0^.view3dFlag = 0 then
      case GDVars.eclScriptId of
        WILD_WEST_SCRIPT: begin
          GDVars.gLocType := C_Area.LOC_WILD_WEST;
          GDVars.ifcState := C_Ifc.OUTDOORS;
        end;
        WILD_CENTRAL_SCRIPT: begin
          GDVars.gLocType := C_Area.LOC_WILD_CENTRAL;
          GDVars.ifcState := C_Ifc.OUTDOORS;
          if (GDVars.zone0^.yarashMissionDone = 254) and (GDVars.zone0^.yarashPyramidLeft = 0) then
            Ending.YarashComplete(True);
        end;
        WILD_EAST_SCRIPT: begin
          GDVars.gLocType := C_Area.LOC_WILD_EAST;
          GDVars.ifcState := C_Ifc.OUTDOORS;
        end;
      end;
    if (GDVars.locTypePrev > C_Area.LOC_3D_MAP) and (GDVars.gLocType = C_Area.LOC_3D_MAP) then
      Border.DrawWindow(3, 3, 13, 13, 0, LightGreen, '');
    if (((GDVars.locTypePrev > C_Area.LOC_3D_MAP) or (GDVars.gLocType = C_Area.LOC_3D_MAP)) and
        (GDVars.filesLoaded <> 0)) or
        ((GDVars.locTypePrev = C_Area.LOC_3D_MAP) and (GDVars.gLocType = C_Area.LOC_3D_MAP)) then
      MapView.DisplayMapView;
    GDVars.newEclFlag := 0;
    EclVm.CallEclScript(GDVars.scriptEntryAddrs[1]);
    if GDVars.newEclFlag = 0 then begin
      EclVm.CallEclScript(GDVars.scriptEntryAddrs[C_Ecl.ENTRY_SEARCH]);
      GDVars.curChar := savedCur;
      CharDisp.DisplayParty(GDVars.curChar);
    end;
  until GDVars.newEclFlag = 0;
end;

{ Run the initial script, then process map, camp, search and movement actions until the party is defeated. }
procedure GameLoop;
var
  cmd: Char;
begin
  GDVars.piecesLoaded := 0;
  GDVars.mapLoaded := 0;
  GDVars.restoreChar := 0;
  GDVars.filesLoaded := 0;
  GDVars.enteringLoop := 1;
  GDVars.ifcState := C_Ifc.INDOORS;
  GDVars.newEclFlag := 0;
  GDVars.eclScriptId := Byte(GDVars.zone0^.previousScriptId);
  case GDVars.eclScriptId of
    WILD_WEST_SCRIPT, WILD_CENTRAL_SCRIPT, WILD_EAST_SCRIPT:
      if GDVars.zone0^.view3dFlag = 0 then
        GDVars.ifcState := C_Ifc.OUTDOORS;
  end;
  { the area's script is loaded from the data even for a saved game (#609), as Secret of the Silver Blades does: the
    copy a save holds would keep a script from before a data fix (DataPat), and is SSI's size only }
  EclMenu.LoadEclScript(GDVars.eclScriptId);
  EclMenu.EclInit;
  EclVm.CallEclScript(GDVars.scriptEntryAddrs[5]);
  if GDVars.ifcState <> C_Ifc.OUTDOORS then begin
    if GDVars.enteringLoop = 1 then begin
      CharDisp.DisplayNoncombatInterface;
      GDVars.enteringLoop := 0;
    end;
    MapView.DisplayMapView;
  end;
  GDVars.zone0^.previousScriptId := GDVars.eclScriptId;
  repeat
    cmd := Explore.MapMainMenu;
    GDVars.savedChar := GDVars.curChar;
    GDVars.zone0^.previousScriptId := GDVars.eclScriptId;
    while ((GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] > 1) or (UpCase(cmd) = 'E')) and
        (not GDVars.partyDefeated) and (not Explore.quickLoadAsked) do begin
      if UpCase(cmd) = 'E' then
        EclVm.EnterCamp
      else begin
        GDVars.dsSearchModeFlag := GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] and 1;
        GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] := 1;
        MapView.DisplayMapView;
        EclVm.CallEclScript(GDVars.scriptEntryAddrs[C_Ecl.ENTRY_SEARCH]);
        if GDVars.newEclFlag <> 0 then
          EclVm.NewEclDone;
        GDVars.zone1^[C_Gbvm.SEARCH_FLAGS] := GDVars.dsSearchModeFlag;
      end;
      if not GDVars.partyDefeated then begin
        cmd := Explore.MapMainMenu;
        GDVars.savedChar := GDVars.curChar;
      end;
    end;
    { a quick load asked for on the map menu ends the loop at once: the program loads it and runs the loop again }
    if not Explore.quickLoadAsked then begin
      if not GDVars.partyDefeated then
        EclVm.CallEclScript(GDVars.scriptEntryAddrs[1]);
      if GDVars.newEclFlag <> 0 then
        EclVm.NewEclDone
      else if not GDVars.partyDefeated then begin
        GDVars.zone0^.previousX := GDVars.gMapX;
        GDVars.zone0^.previousY := GDVars.gMapY;
        Explore.ResolveMovement;
        MapView.DisplayMapView;
        if (GDVars.gMapX <> GDVars.zone0^.previousX) or (GDVars.gMapY <> GDVars.zone0^.previousY) then
          SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.STEP]);
        GDVars.eclGraphics := False;
        GDVars.picDrawn := True;
        EclVm.CallEclScript(GDVars.scriptEntryAddrs[C_Ecl.ENTRY_SEARCH]);
        if GDVars.newEclFlag <> 0 then
          EclVm.NewEclDone;
      end;
    end;
  until GDVars.partyDefeated or Explore.quickLoadAsked;
  GDVars.partyDefeated := False;
end;

end.

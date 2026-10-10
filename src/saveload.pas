{ Character files, saved games and party assembly. CHARLIST.TXT lists available characters; .cha/.itm/.spc files hold
  their records, inventory and effects, and a .mem file their usual spells. SAVGAMx.DAT stores the world and party
  state, with party members in CHRDATxN.sav files. }
{$O+,F+,I-}
unit SaveLoad;

interface

uses Types, Crt, C_Area, GDConsts, GDVars, Blit, TextRend, GameIo, MenuCore, Ending, ClassCal,
  FxEngine, View3D, MapTiles, C_Race, C_Keys, C_Class, C_Ifc, C_Gbvm, C_Npc, C_Status;

{ Read <saveDir>charlist.txt into a fresh list of string nodes (the TItemRec prefix used by
  MenuCore.AllocStringList/FreeStringList); list is nil when the file does not exist. Names of characters currently in
  the party get '* ' prepended. }
procedure LoadCharlist(var list: Types.PItemRec);

{ Rewrite <saveDir>charlist.txt, one name per line, skipping '*'-prefixed (party) members; retries with a put-save-disk
  prompt until the file opens. }
procedure SaveCharlist(list: Types.PItemRec);

{ Load curChar's CHEAD into icon-anim slot 11 and CBODY into slot orderNumber, OR-merge head onto body; when loading,
  remap the default icon colours to the character's iconColors1 nibbles. Icons live on virtual disk 3. }
procedure LoadCharIconAnim(loading: Boolean);

{ fname='' -> single-character save: re-add the name to CHARLIST.TXT and write <saveDir><sanitized-name>.cha/.itm/.spc;
  fname<>'' -> saved-game member: write <saveDir><fname>.sav/.itm/.spc. Old .itm/.spc files are erased first and
  rewritten only for non-empty lists. Records are written raw, pointers included. The .mem file beside them is
  rewritten the same way, holding the character's usual spells when it has any. }
procedure SaveChar(creature: Types.PCharRecord; fname: Types.TStr8);

{ Load one character: askDisk -> prepend the save directory to the sanitized name and prompt for the save disk, else
  prompt with the insert-game-disk message; ext = '.sav'/'.cha' by savedGame. The list and combat pointers are cleared,
  then the item/effect lists are rebuilt from the .itm/.spc files when they exist, stopping at a read error or a
  trailing part record, and the usual spells are read from the .mem file (none when it is missing or not a
  usual-spells file for this character). False, with nothing read after the record, when the .sav/.cha file holds less
  than a whole record or cannot be read; the caller then frees the record unused. A party member leaves Quick
  (quickfight 0), so a loaded game or an added character starts under manual control; NPCs and animated creatures keep
  quickfight, as PostCbt.PostCombatCreatureCleanup leaves them. }
function LoadChar(name: String; creature: Types.PCharRecord; savedGame, askDisk: Boolean): Boolean;

{ Load creature id from MON<disk>CHA/SPC/ITM.dax (a missing or short CHA record exits the game); nil the list pointers,
  derive iconSize from race, roll random icon colours (slot 4, hair, is fixed at $C4), convert effects/items to lists,
  ignoring a trailing part record. }
procedure LoadCreatureData(id: Byte; creature: Types.PCharRecord);

{ GetMem + LoadCreatureData + random portrait head and body by gender and a randomly picked class + AddCharToParty +
  LoadCharIconAnim(True). No-op when the party already has 8 members (C_Gbvm.PARTY_SIZE > 7). }
procedure AddCreatureToParty(id: Byte);

{ Load game: offer the existing SAVGAMA..J.DAT as a letter menu (Escape aborts), read the save file, reload each listed
  character from its CHRDATxN.sav (one that is missing, short or unreadable is left out), delete their single-character
  files (.mem included), reload icon anims, the 3D map and wall sets ('ICON' in the wilderness), and run
  Ending.YarashComplete when the Yarash pyramid flag is set. }
procedure LoadGame;

{ Save game: letter menu (Escape aborts), store wall slots, game speed, picture settings and disk number in the GBVM
  zones, write SAVGAMx.DAT, SaveChar each party member as CHRDATxN.sav, delete their single-character files (.mem
  included), set the recently-saved flag. }
procedure SaveGame;

{ Append to creatureList, make it current, give it the lowest free orderNumber (its icon-anim slot, 0..7), bump the GBVM
  party size and RecalcBaseSkills. }
procedure AddCharToParty(creature: Types.PCharRecord);

{ If name does not exist, offer 'Save and exit Insert disk #N'; on 'S' step the party back one square (0..15 wrap),
  restore the previous virtual disk, SaveGame and exit to DOS (GameIo.ExitGame). }
procedure CheckFileElseQuit(name: Types.TPathStr);

{ The character's usual spells: the spell IDs in its memorized and pending slots when it last confirmed memorizing,
  pending flags stripped. Return False when none are remembered for it. }
function GetUsualSpells(creature: Types.PCharRecord; var spells: Types.TSpellSlots): Boolean;

{ Remember spells as the character's usual spells. }
procedure SetUsualSpells(creature: Types.PCharRecord; var spells: Types.TSpellSlots);

{ Forget the character's usual spells; called before its record is freed or reused. }
procedure ForgetUsualSpells(creature: Types.PCharRecord);

implementation


var

  zone1b: Types.PSaveloadZoneBytes absolute GDVars.zone1;
  iconAnims: array[0..25] of Types.TIconPair absolute GDVars.dsIconAnimation;
                                         { slot 11 = scratch head    }
  wallSlots: array[1..3] of Types.TWallSlot absolute GDVars.dsWallSetCache;
                                         { kept in zone 0 across saves }

procedure CheckSaveDir; forward;

const
  { the number of characters whose usual spells are kept at once: the party's size }
  USUAL_ENTRIES = 8;
  { MEM_SIG and MEM_VERSION open every .mem file; a file without both is not read }
  MEM_SIG = 'USPL';
  MEM_VERSION = 1;

type
  { A .mem file: the usual spells, with the name and randByte of the character they belong to. }
  TUsualSpellsFile = record
    sig: string[4];
    version: Byte;
    name: string[15];
    randByte: Byte;
    spells: Types.TSpellSlots;
  end;

var
  { Usual spells (GetUsualSpells), one entry per character, kept with the record and the name it belongs to; a nil
    owner marks a free entry. }
  usualOwner: array[1..USUAL_ENTRIES] of Types.PCharRecord;
  usualName: array[1..USUAL_ENTRIES] of string[15];
  usualSpells: array[1..USUAL_ENTRIES] of Types.TSpellSlots;

{ The usual-spells entry for creature: its record and name both match, or 0 when there is none. }
function FindUsualEntry(creature: Types.PCharRecord): Byte;
var
  i: Byte;
begin
  FindUsualEntry := 0;
  if creature <> nil then
    for i := 1 to USUAL_ENTRIES do
      if (usualOwner[i] = creature) and (usualName[i] = creature^.name) then
        FindUsualEntry := i;
end;

{ True when creature is in the party list. }
function InParty(creature: Types.PCharRecord): Boolean;
var
  p: Types.PCharRecord;
begin
  InParty := False;
  p := GDVars.creatureList;
  while p <> nil do begin
    if p = creature then
      InParty := True;
    p := p^.nextCharAddr;
  end;
end;

function GetUsualSpells(creature: Types.PCharRecord; var spells: Types.TSpellSlots): Boolean;
var
  i: Byte;
begin
  i := SaveLoad.FindUsualEntry(creature);
  if i > 0 then
    spells := usualSpells[i];
  GetUsualSpells := i > 0;
end;

procedure SetUsualSpells(creature: Types.PCharRecord; var spells: Types.TSpellSlots);
var
  i: Byte;
  j: Byte;
begin
  if creature = nil then Exit;
  { a free entry, else one whose owner has left the party, else the first }
  SaveLoad.ForgetUsualSpells(creature);
  i := 0;
  for j := USUAL_ENTRIES downto 1 do
    if usualOwner[j] = nil then
      i := j;
  if i = 0 then
    for j := USUAL_ENTRIES downto 1 do
      if not SaveLoad.InParty(usualOwner[j]) then
        i := j;
  if i = 0 then
    i := 1;
  usualOwner[i] := creature;
  usualName[i] := creature^.name;
  usualSpells[i] := spells;
end;

procedure ForgetUsualSpells(creature: Types.PCharRecord);
var
  i: Byte;
begin
  for i := 1 to USUAL_ENTRIES do
    if usualOwner[i] = creature then
      usualOwner[i] := nil;
end;

{ Write the character's usual spells to <fn>.mem, erasing any old file first; nothing is written when it has none. A
  failed write leaves a short file, which ReadUsualSpells ignores. }
procedure WriteUsualSpells(creature: Types.PCharRecord; fn: Types.TPathStr);
var
  f: file;
  rec: TUsualSpellsFile;
  ioRes: Integer;
begin
  if DaxIo.FileExists(fn + '.mem') then begin
    Assign(f, fn + '.mem');
    Erase(f);
    ioRes := IOResult;
  end;
  FillChar(rec, SizeOf(rec), 0);
  if SaveLoad.GetUsualSpells(creature, rec.spells) then begin
    rec.sig := MEM_SIG;
    rec.version := MEM_VERSION;
    rec.name := creature^.name;
    rec.randByte := creature^.randByte;
    Assign(f, fn + '.mem');
    Rewrite(f, 1);
    if IOResult = 0 then begin
      BlockWrite(f, rec, SizeOf(rec));
      ioRes := IOResult;
      Close(f);
    end;
  end;
  { leave no I/O error behind for the next IOResult check }
  ioRes := IOResult;
end;

{ Read the character's usual spells from <fn>.mem. The character is left with none unless the file is exactly one
  TUsualSpellsFile with this format's signature and version, made for a character of this name and randByte. }
procedure ReadUsualSpells(creature: Types.PCharRecord; fn: Types.TPathStr);
var
  f: file;
  rec: TUsualSpellsFile;
  res: Word;
  ok: Boolean;
  ioRes: Integer;
begin
  SaveLoad.ForgetUsualSpells(creature);
  Assign(f, fn + '.mem');
  Reset(f, 1);
  if IOResult = 0 then begin
    ok := FileSize(f) = SizeOf(rec);
    if IOResult <> 0 then
      ok := False;
    if ok then begin
      BlockRead(f, rec, SizeOf(rec), res);
      ok := (IOResult = 0) and (res = SizeOf(rec));
    end;
    Close(f);
    ioRes := IOResult;
    if ok then
      ok := (rec.sig = MEM_SIG) and (rec.version = MEM_VERSION) and (Length(rec.name) <= 15) and
            (rec.name = creature^.name) and (rec.randByte = creature^.randByte);
    if ok then
      SaveLoad.SetUsualSpells(creature, rec.spells);
  end;
end;

{ Nodes are TMenuNode-sized: the TItemRec prefix (name, inUse, next), not the full record. '* ' marks party members. }
procedure LoadCharlist(var list: Types.PItemRec);
var
  n: Types.PItemRec;
  tail: Types.PItemRec;
  p: Types.PCharRecord;
  f: Text;
begin
  list := nil;
  SaveLoad.CheckSaveDir;
  if not DaxIo.FileExists(GDVars.dsSaveDirectory + 'charlist.txt') then Exit;
  Assign(f, GDVars.dsSaveDirectory + 'charlist.txt');
  Reset(f);
  while not Eof(f) do begin
    GetMem(n, SizeOf(Types.TMenuNode));
    FillChar(n^, SizeOf(Types.TMenuNode), 0);
    if list = nil then begin
      list := n;
      tail := list;
    end else begin
      tail^.next := n;
      tail := tail^.next;
    end;
    ReadLn(f, tail^.name);
    p := GDVars.creatureList;
    while (p <> nil) and (p^.name <> tail^.name) do
      p := p^.nextCharAddr;
    if p <> nil then
      tail^.name := '* ' + tail^.name;
  end;
  Close(f);
end;

procedure SaveCharlist(list: Types.PItemRec);
var
  p: Types.PItemRec;
  f: Text;
  ioRes: Integer;
begin
  SaveLoad.CheckSaveDir;
  repeat
    Assign(f, GDVars.dsSaveDirectory + 'charlist.txt');
    Rewrite(f);
    ioRes := IOResult;
    if ioRes <> 0 then
      TextRend.DisplayAndPause(Yellow, 'Put save disk in ' + GDVars.dsSaveDirectory[1] + ':');
  until ioRes = 0;
  p := list;
  while p <> nil do begin
    if p^.name[1] <> '*' then
      WriteLn(f, p^.name);
    p := p^.next;
  end;
  Close(f);
end;

{ Create the save directory (path minus the trailing backslash), and any parent directory it needs; IOResult 5 (the
  directory already exists) counts as success. Prompt for the save disk until MkDir succeeds. A drive root such as C:\
  cannot be made and is left alone. }
procedure CheckSaveDir;
var
  ioRes: Integer;
  i: Byte;
begin
  if Length(GDVars.dsSaveDirectory) <= 3 then Exit;
  repeat
    { each parent first, from the one below the root; its errors show again in the last MkDir }
    for i := 4 to Length(GDVars.dsSaveDirectory) - 1 do
      if GDVars.dsSaveDirectory[i] = '\' then begin
        MkDir(Copy(GDVars.dsSaveDirectory, 1, i - 1));
        ioRes := IOResult;
      end;
    MkDir(Copy(GDVars.dsSaveDirectory, 1, Length(GDVars.dsSaveDirectory) - 1));
    ioRes := IOResult;
    if (ioRes <> 0) and (ioRes <> 5) then
      TextRend.DisplayAndPause(Yellow, 'Put save disk in ' + GDVars.dsSaveDirectory[1] + ':');
  until (ioRes = 0) or (ioRes = 5);
end;

{ OR src's pixels onto dst and AND the transparency masks. The CGA and Tandy masks are imgSize bytes; the EGA mask is
  one plane, a quarter of imgSize, sized from iconAnims[11].pic0 rather than src. }
procedure MergeIcon(src, dst: Types.PImgBuf);
var
  n: Word;
  i: Word;
begin
  case GDVars.videoMode of
    0, 2:
      for i := 0 to src^.imgSize - 1 do begin
        dst^.data[i] := dst^.data[i] or src^.data[i];
        dst^.transp^[i] := dst^.transp^[i] and src^.transp^[i];
      end;
    1: begin
      for i := 0 to src^.imgSize - 1 do
        dst^.data[i] := dst^.data[i] or src^.data[i];
      n := iconAnims[11].pic0^.imgSize div 4 - 1;
      for i := 0 to n do
        dst^.transp^[i] := dst^.transp^[i] and src^.transp^[i];
    end;
  end;
end;

procedure LoadCharIconAnim(loading: Boolean);

var
  pad1: Byte;
  pad2: Byte;
  pad3: Byte;
  fromMap: Types.TColorTab;
  toMap: Types.TColorTab;
  i: Byte;
  pad4: Byte;
begin
  DaxIo.PushState(3);
  with GDVars.curChar^ do begin
    MapTiles.LoadIconAnim('CHEAD' + GDConsts.iconHeightSuffix[iconSize], iconHead, 11);
    MapTiles.LoadIconAnim('CBODY' + GDConsts.iconHeightSuffix[iconSize], iconBody, orderNumber);
    SaveLoad.MergeIcon(iconAnims[11].pic0, iconAnims[orderNumber].pic0);
    SaveLoad.MergeIcon(iconAnims[11].pic1, iconAnims[orderNumber].pic1);
    if loading then begin
      for i := 0 to 15 do begin
        fromMap[i] := i;
        toMap[i] := i;
      end;
      for i := 1 to 6 do begin
        toMap[GDConsts.defIconCol[i]] := iconColors1[i] and $F;
        toMap[GDConsts.defIconCol[i] + 8] := (iconColors1[i] and $F0) shr 4;
      end;
      Blit.RemapPic(fromMap, toMap, 0, False, iconAnims[orderNumber].pic0);
      Blit.RemapPic(fromMap, toMap, 0, False, iconAnims[orderNumber].pic1);
    end;
  end;
  MapTiles.FreeIconAnim(11);
  DaxIo.PopState;
end;

procedure SaveChar(creature: Types.PCharRecord; fname: Types.TStr8);
var
  f: file;
  fn: Types.TPathStr;
  ext: String[4];
  res: Word;
  item: Types.PItemRec;
  effect: Types.PEffectRec;
  list: Types.PItemRec;
  p: Types.PItemRec;
  n: Types.PItemRec;
  ioRes: Integer;
begin
  { LoadCharlist marks party members with '* ' and SaveCharlist skips them, so this rewrite drops every current party
    member's old line and then appends this character's name unmarked. }
  if Length(fname) = 0 then begin
    SaveLoad.LoadCharlist(list);
    p := list;
    if p <> nil then
      while p^.next <> nil do
        p := p^.next;
    GetMem(n, SizeOf(Types.TMenuNode));
    FillChar(n^, SizeOf(Types.TMenuNode), 0);
    n^.name := creature^.name;
    if p <> nil then
      p^.next := n
    else
      list := n;
    SaveLoad.SaveCharlist(list);
    MenuCore.FreeStringList(list);
    ext := '.cha';
    fn := GDVars.dsSaveDirectory + DaxIo.SanitizeFileName(DaxIo.SanitizeString(creature^.name, '.'));
  end else begin
    SaveLoad.CheckSaveDir;
    ext := '.sav';
    fn := GDVars.dsSaveDirectory + fname;
  end;
  repeat
    Assign(f, fn + ext);
    Rewrite(f, 1);
    ioRes := IOResult;
    if ioRes <> 0 then
      TextRend.DisplayAndPause(Yellow, 'Put save disk in ' + GDVars.dsSaveDirectory[1] + ':');
  until ioRes = 0;
  BlockWrite(f, creature^, SizeOf(Types.TCharRecord));
  Close(f);
  if DaxIo.FileExists(fn + '.itm') then begin
    Assign(f, fn + '.itm');
    Erase(f);
  end;
  if creature^.itemsAddr <> nil then begin
    Assign(f, fn + '.itm');
    Rewrite(f, 1);
    item := creature^.itemsAddr;
    while item <> nil do begin
      BlockWrite(f, item^, SizeOf(Types.TItemRec));
      item := item^.next;
    end;
    Close(f);
  end;
  if DaxIo.FileExists(fn + '.spc') then begin
    Assign(f, fn + '.spc');
    Erase(f);
  end;
  if creature^.effectsAddr <> nil then begin
    Assign(f, fn + '.spc');
    Rewrite(f, 1);
    effect := creature^.effectsAddr;
    while effect <> nil do begin
      BlockWrite(f, effect^, SizeOf(Types.TEffectRec));
      effect := effect^.next;
    end;
    Close(f);
  end;
  SaveLoad.WriteUsualSpells(creature, fn);
end;

function LoadChar(name: String; creature: Types.PCharRecord; savedGame, askDisk: Boolean): Boolean;
var
  f: file;
  res: Word;
  ext: String[4];
  item: Types.PItemRec;
  effect: Types.PEffectRec;
  newItem: Types.PItemRec;
  newEffect: Types.PEffectRec;
  whole: Boolean;
  msg: Types.TStr40;
  found: Boolean;
begin
  if askDisk then begin
    name := GDVars.dsSaveDirectory + DaxIo.SanitizeFileName(name);
    msg := 'Put save disk in ' + GDVars.dsSaveDirectory[1] + ':';
  end else
    msg := GDConsts.insertDiskMsg[GDVars.virtualDisk] + GDVars.gameDir[1] + ':';
  if savedGame then
    ext := '.sav'
  else
    ext := '.cha';
  found := DaxIo.OpenWithRetry(name + ext, msg, #0, f);
  res := 0;
  BlockRead(f, creature^, SizeOf(Types.TCharRecord), res);
  whole := (IOResult = 0) and (res = SizeOf(Types.TCharRecord));
  Close(f);
  creature^.nextCharAddr := nil;
  creature^.itemsAddr := nil;
  creature^.effectsAddr := nil;
  creature^.combatAddr := nil;
  LoadChar := whole;
  if not whole then Exit;
  { C_Npc.FLAG clear }
  if (creature^.npc < C_Npc.FLAG) and (creature^.status <> C_Status.ANIMATED) then
    creature^.quickfight := 0;
  if DaxIo.FileExists(name + '.itm') then begin
    found := DaxIo.OpenWithRetry(name + '.itm', msg, #0, f);
    item := nil;
    whole := True;
    while whole and not Eof(f) do begin
      GetMem(newItem, SizeOf(Types.TItemRec));
      res := 0;
      BlockRead(f, newItem^, SizeOf(Types.TItemRec), res);
      whole := (IOResult = 0) and (res = SizeOf(Types.TItemRec));
      if whole then begin
        newItem^.next := nil;
        if item = nil then
          creature^.itemsAddr := newItem
        else
          item^.next := newItem;
        item := newItem;
      end else
        FreeMem(newItem, SizeOf(Types.TItemRec));
    end;
    Close(f);
  end;
  if DaxIo.FileExists(name + '.spc') then begin
    found := DaxIo.OpenWithRetry(name + '.spc', msg, #0, f);
    effect := nil;
    whole := True;
    while whole and not Eof(f) do begin
      GetMem(newEffect, SizeOf(Types.TEffectRec));
      res := 0;
      BlockRead(f, newEffect^, SizeOf(Types.TEffectRec), res);
      whole := (IOResult = 0) and (res = SizeOf(Types.TEffectRec));
      if whole then begin
        newEffect^.next := nil;
        if effect = nil then
          creature^.effectsAddr := newEffect
        else
          effect^.next := newEffect;
        effect := newEffect;
      end else
        FreeMem(newEffect, SizeOf(Types.TEffectRec));
    end;
    Close(f);
  end;
  SaveLoad.ReadUsualSpells(creature, name);
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
  GDVars.dsSuppressingInsertDiskFlag := 1;
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
  GDVars.dsSuppressingInsertDiskFlag := 0;
end;

procedure AddCreatureToParty(id: Byte);

var
  junk: Pointer;
  creature: Types.PCharRecord;
  cnt: Byte;
  i: ShortInt;
  classes: array[1..4] of Byte;
begin
  if GDVars.zone1^[C_Gbvm.PARTY_SIZE] > 7 then Exit;
  GetMem(creature, SizeOf(Types.TCharRecord));
  SaveLoad.LoadCreatureData(id, creature);
  with creature^ do begin
    randByte := Random(256);
    cnt := 0;
    for i := 0 to 6 do
      if classLevels[i] > 0 then begin
        Inc(cnt);
        classes[cnt] := i;
      end;
    if cnt = 0 then begin
      cnt := 1;
      classes[cnt] := C_Class.LEVEL_FIGHTER;
    end;
    cnt := FxEngine.RollDice(1, cnt);
    case classes[cnt] of
      C_Class.LEVEL_CLERIC: portraitBody := GDConsts.npcClericBodies[genderSp, FxEngine.RollDice(1, 5)];
      C_Class.LEVEL_MAGE: portraitBody := GDConsts.npcMageBodies[genderSp, FxEngine.RollDice(1, 5)];
      C_Class.LEVEL_THIEF: portraitBody := GDConsts.npcThiefBodies[genderSp, FxEngine.RollDice(1, 5)];
      else portraitBody := GDConsts.npcFighterBodies[genderSp, FxEngine.RollDice(1, 5)];
    end;
    portraitHead := GDConsts.npcPortraitHeads[genderSp, FxEngine.RollDice(1, 8)];
  end;
  SaveLoad.AddCharToParty(creature);
  SaveLoad.LoadCharIconAnim(True);
end;

procedure AddCharToParty(creature: Types.PCharRecord);
var
  p: Types.PCharRecord;
  used: array[0..7] of Byte;
begin
  creature^.orderNumber := 255;
  if GDVars.creatureList = nil then begin
    GDVars.creatureList := creature;
    GDVars.curChar := creature;
  end else begin
    p := GDVars.creatureList;
    while p^.nextCharAddr <> nil do
      p := p^.nextCharAddr;
    p^.nextCharAddr := creature;
  end;
  FillChar(used, SizeOf(used), 0);
  p := GDVars.creatureList;
  while p <> nil do begin
    if p^.orderNumber in [0..7] then
      used[p^.orderNumber] := 1;
    p := p^.nextCharAddr;
  end;
  GDVars.curChar := creature;
  with GDVars.curChar^ do begin
    orderNumber := 0;
    while (orderNumber < 8) and (used[orderNumber] <> 0) do
      Inc(orderNumber);
  end;
  Inc(GDVars.zone1^[C_Gbvm.PARTY_SIZE]);
  ClassCal.RecalcBaseSkills(creature);
end;

procedure LoadGame;
var
  names: array[1..8] of Types.TStr40;
  f: file;
  i: Byte;
  creature: Types.PCharRecord;
  fn: Types.TPathStr;
  res: Word;
  nChars: Byte;
  found: Boolean;
  letter: Char;
  ext: Boolean;
  menu: String[20];
begin
  SaveLoad.CheckSaveDir;
  menu := '';
  for letter := 'A' to 'J' do
    if DaxIo.FileExists(GDVars.dsSaveDirectory + 'savgam' + letter + '.dat') then
      menu := menu + letter + ' ';
  if Length(menu) = 0 then Exit;
  repeat
    letter := MenuCore.MenuHorizontal('Load Which Game: ', menu, LightMagenta, LightGreen, White,
                                      False, False, ext);
  until ((letter in ['A'..'J']) and DaxIo.FileExists(GDVars.dsSaveDirectory + 'savgam' + letter + '.dat')) or
      (letter = C_Keys.NONE);
  if letter = C_Keys.NONE then Exit;
  found := DaxIo.OpenWithRetry(GDVars.dsSaveDirectory + 'savgam' + letter + '.dat',
                               'Put save disk in ' + GDVars.dsSaveDirectory, #1, f);
  MenuCore.ClearBottomLine;
  TextRend.DisplayString(0, 24, LightGreen, 'Loading...Please Wait');
  BlockRead(f, GDVars.virtualDisk, SizeOf(GDVars.virtualDisk), res);
  { disks 1..8 only }
  if not (GDVars.virtualDisk in [1..8]) then
    GDVars.virtualDisk := 1;
  BlockRead(f, GDVars.zone0^, SizeOf(GDVars.zone0^), res);
  BlockRead(f, GDVars.zone1^, SizeOf(GDVars.zone1^), res);
  BlockRead(f, GDVars.zone2^, SizeOf(GDVars.zone2^), res);
  BlockRead(f, GDVars.zone3^, SizeOf(GDVars.zone3^), res);
  BlockRead(f, GDVars.gMapX, 5, res);
  BlockRead(f, GDVars.gLocType, SizeOf(GDVars.gLocType), res);
  BlockRead(f, GDVars.ifcState, SizeOf(GDVars.ifcState), res);
  BlockRead(f, nChars, SizeOf(nChars), res);
  BlockRead(f, names, SizeOf(names), res);
  Close(f);
  GDVars.monsterPics := GDVars.zone0^.settings div 2;
  GDVars.portraitsOn := GDVars.zone0^.settings and 1;
  GDVars.gameDelay := GDVars.zone0^.gameSpeed.lo;
  GDVars.zone1^[C_Gbvm.PARTY_SIZE] := 0;
  for i := 1 to nChars do begin
    fn := DaxIo.SanitizeFileName(DaxIo.SanitizeString(names[i], '.'));
    if DaxIo.FileExists(GDVars.dsSaveDirectory + fn + '.sav') then begin
      GetMem(creature, SizeOf(Types.TCharRecord));
      { a short or unreadable .sav is left out, as a missing one is }
      if SaveLoad.LoadChar(fn, creature, True, True) then
        SaveLoad.AddCharToParty(creature)
      else
        FreeMem(creature, SizeOf(Types.TCharRecord));
      SaveLoad.CheckSaveDir;
    end;
  end;
  creature := GDVars.creatureList;
  while creature <> nil do begin
    fn := GDVars.dsSaveDirectory + DaxIo.SanitizeFileName(DaxIo.SanitizeString(creature^.name, '.'));
    { The .itm, .spc and .mem files are erased only when the .cha file exists. }
    if DaxIo.FileExists(fn + '.cha') then begin
      Assign(f, fn + '.cha');
      Erase(f);
      if DaxIo.FileExists(fn + '.itm') then begin
        Assign(f, fn + '.itm');
        Erase(f);
      end;
      if DaxIo.FileExists(fn + '.spc') then begin
        Assign(f, fn + '.spc');
        Erase(f);
      end;
      if DaxIo.FileExists(fn + '.mem') then begin
        Assign(f, fn + '.mem');
        Erase(f);
      end;
    end;
    creature := creature^.nextCharAddr;
  end;
  GDVars.curChar := GDVars.creatureList;
  while GDVars.curChar <> nil do begin
    SaveLoad.LoadCharIconAnim(True);
    GDVars.curChar := GDVars.curChar^.nextCharAddr;
  end;
  GDVars.curChar := GDVars.creatureList;
  { the disk number SaveGame stored at C_Gbvm.DISK_NUM }
  GDVars.virtualDisk := zone1b^[$624];
  if not (GDVars.virtualDisk in [1..8]) then
    GDVars.virtualDisk := 1;
  if GDVars.gLocType < C_Area.LOC_WILD_WEST then
    View3D.Load3DMap(GDVars.zone0^.mapId.lo);
  if GDVars.gLocType > C_Area.LOC_3D_MAP then
    MapTiles.LoadIconAnim('ICON', 0, 11)
  else
    for i := 1 to 3 do begin
      wallSlots[i].wallDefId := GDVars.zone0^.words[C_Gbvm.WALLSLOT_ID + i];
      wallSlots[i].symbolSlot := GDVars.zone0^.words[C_Gbvm.WALLSLOT_SLOT + i];
      if wallSlots[i].wallDefId >= 0 then
        View3D.LoadWallSet(wallSlots[i].wallDefId, wallSlots[i].symbolSlot);
    end;
  if GDVars.zone0^.yarashPyramidLeft <> 0 then
    Ending.YarashComplete(False);
  MenuCore.ClearBottomLine;
end;

procedure SaveGame;
var
  names: array[1..8] of Types.TStr40;
  f: file;
  n: Byte;
  p: Types.PCharRecord;
  numStr: String[1];
  fn: Types.TPathStr;
  ext: Boolean;
  letter: Char;
  ioRes: Integer;
begin
  repeat
    letter := MenuCore.MenuHorizontal('Save Which Game: ', 'A B C D E F G H I J', LightMagenta,
                                      LightGreen, White, False, GDVars.ifcState = C_Ifc.CAMPING, ext);
  until letter in [C_Keys.NONE, 'A'..'J'];
  if letter = C_Keys.NONE then Exit;
  SaveLoad.CheckSaveDir;
  repeat
    Assign(f, GDVars.dsSaveDirectory + 'savgam' + letter + '.dat');
    Rewrite(f, 1);
    ioRes := IOResult;
    if ioRes <> 0 then
      TextRend.DisplayAndPause(Yellow, 'Put save disk in ' + GDVars.dsSaveDirectory[1] + ':');
  until ioRes = 0;
  MenuCore.ClearBottomLine;
  TextRend.DisplayString(0, 24, LightGreen, 'Saving...Please Wait');
  for n := 1 to 3 do begin
    GDVars.zone0^.words[C_Gbvm.WALLSLOT_ID + n] := wallSlots[n].wallDefId;
    GDVars.zone0^.words[C_Gbvm.WALLSLOT_SLOT + n] := wallSlots[n].symbolSlot;
  end;
  GDVars.zone0^.gameSpeed.value := GDVars.gameDelay;
  GDVars.zone0^.settings := GDVars.monsterPics * 2 + GDVars.portraitsOn;
  GDVars.zone1^[C_Gbvm.DISK_NUM] := GDVars.virtualDisk;
  BlockWrite(f, GDVars.virtualDisk, SizeOf(GDVars.virtualDisk));
  BlockWrite(f, GDVars.zone0^, SizeOf(GDVars.zone0^));
  BlockWrite(f, GDVars.zone1^, SizeOf(GDVars.zone1^));
  BlockWrite(f, GDVars.zone2^, SizeOf(GDVars.zone2^));
  BlockWrite(f, GDVars.zone3^, SizeOf(GDVars.zone3^));
  BlockWrite(f, GDVars.gMapX, 5);
  BlockWrite(f, GDVars.gLocType, SizeOf(GDVars.gLocType));
  BlockWrite(f, GDVars.ifcState, SizeOf(GDVars.ifcState));
  n := 0;
  p := GDVars.creatureList;
  while p <> nil do begin
    Inc(n);
    Str(n, numStr);
    names[n] := 'CHRDAT' + letter + numStr;
    p := p^.nextCharAddr;
  end;
  BlockWrite(f, n, SizeOf(n));
  BlockWrite(f, names, SizeOf(names));
  Close(f);
  p := GDVars.creatureList;
  n := 0;
  while p <> nil do begin
    Inc(n);
    Str(n, numStr);
    SaveLoad.SaveChar(p, 'CHRDAT' + letter + numStr);
    fn := GDVars.dsSaveDirectory + DaxIo.SanitizeFileName(DaxIo.SanitizeString(p^.name, '.'));
    if DaxIo.FileExists(fn + '.cha') then begin
      Assign(f, fn + '.cha');
      Erase(f);
    end;
    if DaxIo.FileExists(fn + '.itm') then begin
      Assign(f, fn + '.itm');
      Erase(f);
    end;
    if DaxIo.FileExists(fn + '.spc') then begin
      Assign(f, fn + '.spc');
      Erase(f);
    end;
    if DaxIo.FileExists(fn + '.mem') then begin
      Assign(f, fn + '.mem');
      Erase(f);
    end;
    p := p^.nextCharAddr;
  end;
  GDVars.recentSaved := 1;
  MenuCore.ClearBottomLine;
end;

procedure CheckFileElseQuit(name: Types.TPathStr);
var
  msg: Types.TStr40;
  numStr: String[1];
  ch: Char;
  ext: Boolean;
begin
  if DaxIo.FileExists(name) then Exit;
  Str(GDVars.virtualDisk, numStr);
  msg := 'Save and exit  Insert disk #' + numStr;
  ch := MenuCore.MenuHorizontal('', msg, LightMagenta, LightGreen, White, False, False, ext);
  if (not ext) and (ch = 'S') then begin
    Dec(GDVars.gMapX, GDConsts.dirDX[GDVars.gFacing]);
    if GDVars.gMapX < 0 then GDVars.gMapX := 15;
    if GDVars.gMapX > 15 then GDVars.gMapX := 0;
    Dec(GDVars.gMapY, GDConsts.dirDY[GDVars.gFacing]);
    if GDVars.gMapY < 0 then GDVars.gMapY := 15;
    if GDVars.gMapY > 15 then GDVars.gMapY := 0;
    DaxIo.PopState;
    SaveLoad.SaveGame;
    GameIo.ExitGame;
  end;
end;

begin
  FillChar(usualOwner, SizeOf(usualOwner), 0);
end.

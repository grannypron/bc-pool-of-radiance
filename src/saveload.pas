{ Character files, saved games and party assembly. CHARLIST.TXT lists available characters; .cha/.itm/.spc files hold
  their records, inventory and effects, and a .mem file their usual spells. SAVGAMx.DAT stores the world and party
  state, with party members in CHRDATxN.sav files. }
{$O+,F+,I-}
unit SaveLoad;

interface

uses Types;

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
  rewritten the same way, holding the character's usual spells when it has any. A record, item or effect that cannot
  be written (a full disk) is reported once on the bottom line, after every file has been tried and closed. }
procedure SaveChar(creature: Types.PCharRecord; fname: Types.TStr8);

{ Load one character: askDisk -> prepend the save directory to the sanitized name and prompt for the save disk, else
  prompt with the insert-game-disk message; ext = '.sav'/'.cha' by savedGame. The list and combat pointers are cleared,
  then the item/effect lists are rebuilt from the .itm/.spc files when they exist, stopping at a read error or a
  trailing part record, and the usual spells are read from the .mem file (none when it is missing or not a
  usual-spells file for this character). False, with nothing read after the record, when the .sav/.cha file holds less
  than a whole record or cannot be read; the caller then frees the record unused. While the Quick Ends With Fight
  setting is on (GDVars.quickEnds), a party member leaves Quick (quickfight 0), so a loaded game or an added character
  starts under manual control; NPCs and animated creatures keep quickfight, as PostCbt.PostCombatCreatureCleanup leaves
  them. With the setting off the saved quickfight stays. }
function LoadChar(name: String; creature: Types.PCharRecord; savedGame, askDisk: Boolean): Boolean;

{ Load creature id from MON<disk>CHA/SPC/ITM.dax (a missing or short CHA record exits the game); nil the list pointers,
  derive iconSize from race, roll random icon colours (slot 4, hair, is fixed at $C4), convert effects/items to lists,
  ignoring a trailing part record. }
procedure LoadCreatureData(id: Byte; creature: Types.PCharRecord);

{ GetMem + LoadCreatureData + random portrait head and body by gender and a randomly picked class + AddCharToParty +
  LoadCharIconAnim(True). No-op when the party already has 8 members (C_Gbvm.PARTY_SIZE > 7). }
procedure AddCreatureToParty(id: Byte);

{ Load game: offer the existing SAVGAMA..J.DAT on the full-screen SaveMenu (Escape aborts), read the save file (one too
  short to hold it all is refused, with a message, before anything is read), reload each listed character, at most 8,
  from its CHRDATxN.sav (one that is missing, short or unreadable is left out), delete their single-character files
  (.mem included), reload icon anims, the 3D map and wall sets ('ICON' in the wilderness), and run Ending.YarashComplete
  when the Yarash pyramid flag is set; the slot's vault becomes the session's (Vault.RestoreFromSlot). The save's game
  speed and settings word are left in the GBVM zone: the game's own settings stay as they are. }
procedure LoadGame;

{ Save game: choose a slot on the full-screen SaveMenu and give it a description (the slot's old one to start from;
  Escape on the menu aborts, Exit in the description popup goes back to the menu), store wall slots, game speed, picture
  and music settings (SSI's copies, which loading leaves alone) and disk number in the GBVM zones, write SAVGAMx.DAT,
  SaveChar each party member (the first 8) as CHRDATxN.sav, write the slot's description and the current area
  (AreaName.CurrentArea) to SAVGAMx.INF, copy the session vault to the slot (Vault.CommitToSlot), delete their
  single-character files (.mem included), set the recently-saved flag. The caller redraws the screen. }
procedure SaveGame;

const
  { the quick-save slot: F5 saves to it and F8 loads it, from the map menu }
  QUICK_SLOT = 'Q';

{ Quick save: save into QUICK_SLOT, described as QUICK SAVE, with no menu, and say so on the bottom line. }
procedure QuickSave;

{ True when QUICK_SLOT holds a save file big enough to load. }
function QuickLoadable: Boolean;

{ Quick load, between two runs of EclVm.GameLoop: free the party (records, items, effects, usual spells and icon
  animations), load QUICK_SLOT as LoadGame loads a slot, and set loadedSave so the next GameLoop resumes it. With no
  loadable quick save it says so and frees nothing, and the next GameLoop resumes the game in memory. }
procedure QuickLoad;

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

{ Create the save directory (path minus the trailing backslash), and any parent directory it needs; IOResult 5 (the
  directory already exists) counts as success. Prompt for the save disk until MkDir succeeds. A drive root such as C:\
  cannot be made and is left alone. }
procedure CheckSaveDir;

implementation

uses Crt, C_Area, GDConsts, GDVars, Blit, TextRend, GameIo, MenuCore, Ending, ClassCal, FxEngine, View3D, MapTiles,
  C_Race, C_Keys, C_Level, C_Ifc, C_Gbvm, C_Npc, C_Status, SaveMenu, AreaName, CharGen, Vault, Stats, DaxIo, CharHlp,
  FileUtil, Party;

type
  { the party's names in a savgam file: the CHRDATxN files they are kept in }
  TSaveNames = array[1..Types.MAX_PARTY] of Types.TStr40;

var
  zone1b: Types.PSaveloadZoneBytes absolute GDVars.zone1;
  wallSlots: array[1..3] of Types.TWallSlot absolute GDVars.dsWallSetCache;
                                         { kept in zone 0 across saves }

const
  { the number of characters whose usual spells are kept at once: the party's size }
  USUAL_ENTRIES = Types.MAX_PARTY;
  { MEM_SIG and MEM_VERSION open every .mem file; a file without both is not read }
  MEM_SIG = 'USPL';
  MEM_VERSION = 1;

type
  { A .mem file: the usual spells, with the name and randByte of the character they belong to. }
  TUsualSpellsFile = record
    sig: string[4];
    version: Byte;
    name: string[Types.NAME_LEN];
    randByte: Byte;
    spells: Types.TSpellSlots;
  end;

var
  { Usual spells (GetUsualSpells), one entry per character, kept with the record and the name it belongs to; a nil
    owner marks a free entry. }
  usualOwner: array[1..USUAL_ENTRIES] of Types.PCharRecord;
  usualName: array[1..USUAL_ENTRIES] of string[Types.NAME_LEN];
  usualSpells: array[1..USUAL_ENTRIES] of Types.TSpellSlots;

{ 'Put save disk in C:', for the save directory's drive. }
function SaveDiskMsg: Types.TStr40;
begin
  SaveDiskMsg := 'Put save disk in ' + GDVars.dsSaveDirectory[1] + ':';
end;

{ Create file name (record size 1) for writing, asking for the save disk until it can be. }
procedure RewriteSaveFile(var f: file; name: Types.TPathStr);
var
  ioRes: Integer;
begin
  repeat
    Assign(f, name);
    Rewrite(f, 1);
    ioRes := IOResult;
    if ioRes <> 0 then
      TextRend.DisplayAndPause(Yellow, SaveLoad.SaveDiskMsg);
  until ioRes = 0;
end;

{ A character's single-character files' path and base name, from its name: <saveDir><name>, sanitized for DOS. }
function CharFileBase(name: String): Types.TPathStr;
begin
  CharFileBase := GDVars.dsSaveDirectory + DaxIo.SanitizeFileName(DaxIo.SanitizeString(name, '.'));
end;

{ Erase a character's single-character files <fn>.cha, .itm, .spc, .mem and .sts, those there are. }
procedure EraseCharFiles(fn: Types.TPathStr);
begin
  FileUtil.DeleteFile(fn + '.cha');
  FileUtil.DeleteFile(fn + '.itm');
  FileUtil.DeleteFile(fn + '.spc');
  FileUtil.DeleteFile(fn + '.mem');
  FileUtil.DeleteFile(fn + '.sts');
end;

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
      if not Party.IsPartyMember(usualOwner[j]) then
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
  rec: TUsualSpellsFile;
  written: Boolean;
begin
  FileUtil.DeleteFile(fn + '.mem');
  FillChar(rec, SizeOf(rec), 0);
  if SaveLoad.GetUsualSpells(creature, rec.spells) then begin
    rec.sig := MEM_SIG;
    rec.version := MEM_VERSION;
    rec.name := creature^.name;
    rec.randByte := creature^.randByte;
    { a failed write leaves a short file, which ReadUsualSpells ignores }
    written := FileUtil.WriteRecord(fn + '.mem', rec, SizeOf(rec));
  end;
end;

{ Read the character's usual spells from <fn>.mem. The character is left with none unless the file is exactly one
  TUsualSpellsFile with this format's signature and version, made for a character of this name and randByte. }
procedure ReadUsualSpells(creature: Types.PCharRecord; fn: Types.TPathStr);
var
  rec: TUsualSpellsFile;
begin
  SaveLoad.ForgetUsualSpells(creature);
  { read-only, so a write-protected .mem is read too }
  if FileUtil.ReadRecord(fn + '.mem', rec, SizeOf(rec)) then
    if (rec.sig = MEM_SIG) and (rec.version = MEM_VERSION) and (Length(rec.name) <= Types.NAME_LEN) and
        (rec.name = creature^.name) and (rec.randByte = creature^.randByte) then
      SaveLoad.SetUsualSpells(creature, rec.spells);
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
      TextRend.DisplayAndPause(Yellow, SaveLoad.SaveDiskMsg);
  until ioRes = 0;
  p := list;
  while p <> nil do begin
    if p^.name[1] <> '*' then
      WriteLn(f, p^.name);
    p := p^.next;
  end;
  Close(f);
end;

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
      TextRend.DisplayAndPause(Yellow, SaveLoad.SaveDiskMsg);
  until (ioRes = 0) or (ioRes = 5);
end;

{ OR src's pixels onto dst and AND the transparency masks. The CGA and Tandy masks are imgSize bytes; the EGA mask is
  one plane, a quarter of imgSize, sized from GDVars.dsIconAnimation[11, 0] rather than src. Nothing is merged when
  either picture is missing (LoadPic leaves nil for a block that is not there) or src is empty. }
procedure MergeIcon(src, dst: Types.PImgBuf);
var
  n: Word;
  i: Word;
begin
  if (src = nil) or (dst = nil) then Exit;
  { an empty picture would make the loops below run 65536 times }
  if src^.imgSize = 0 then Exit;
  case GDVars.videoMode of
    Types.vmCGA, Types.vmTandy:
      for i := 0 to src^.imgSize - 1 do begin
        dst^.data[i] := dst^.data[i] or src^.data[i];
        dst^.transp^[i] := dst^.transp^[i] and src^.transp^[i];
      end;
    Types.vmEGA: begin
      for i := 0 to src^.imgSize - 1 do
        dst^.data[i] := dst^.data[i] or src^.data[i];
      if GDVars.dsIconAnimation[11, 0] <> nil then
        if GDVars.dsIconAnimation[11, 0]^.imgSize >= 4 then begin
          n := GDVars.dsIconAnimation[11, 0]^.imgSize div 4 - 1;
          for i := 0 to n do
            dst^.transp^[i] := dst^.transp^[i] and src^.transp^[i];
        end;
    end;
  end;
end;

procedure LoadCharIconAnim(loading: Boolean);

var
  fromMap: Types.TColorTab;
  toMap: Types.TColorTab;
  i: Byte;
  height: Byte;
begin
  DaxIo.PushState(3);
  with GDVars.curChar^ do begin
    { iconHeightSuffix is [1..2]; a monster's iconSize is 0 (LoadCreatureData sets it only for PC races), which v1.3
      read past the table and took as the small set }
    if iconSize = 2 then
      height := 2
    else
      height := 1;
    MapTiles.LoadIconAnim('CHEAD' + GDConsts.iconHeightSuffix[height], iconHead, 11);
    MapTiles.LoadIconAnim('CBODY' + GDConsts.iconHeightSuffix[height], iconBody, orderNumber);
    SaveLoad.MergeIcon(GDVars.dsIconAnimation[11, 0], GDVars.dsIconAnimation[orderNumber, 0]);
    SaveLoad.MergeIcon(GDVars.dsIconAnimation[11, 1], GDVars.dsIconAnimation[orderNumber, 1]);
    if loading then begin
      for i := 0 to 15 do begin
        fromMap[i] := i;
        toMap[i] := i;
      end;
      for i := 1 to 6 do begin
        toMap[GDConsts.defIconCol[i]] := iconColors1[i] and $F;
        toMap[GDConsts.defIconCol[i] + 8] := (iconColors1[i] and $F0) shr 4;
      end;
      Blit.RemapPic(fromMap, toMap, 0, False, GDVars.dsIconAnimation[orderNumber, 0]);
      Blit.RemapPic(fromMap, toMap, 0, False, GDVars.dsIconAnimation[orderNumber, 1]);
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
  ok: Boolean;
  { the record as written: a copy with its pointers cleared, as below for each item and effect }
  rec: Types.TCharRecord;
  itemRec: Types.TItemRec;
  effectRec: Types.TEffectRec;
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
    fn := SaveLoad.CharFileBase(creature^.name);
  end else begin
    SaveLoad.CheckSaveDir;
    ext := '.sav';
    fn := GDVars.dsSaveDirectory + fname;
  end;
  SaveLoad.RewriteSaveFile(f, fn + ext);
  { a write that fails (a full disk) is reported once, below, after every file has been tried and closed. The records
    go out with their pointers cleared: loading rebuilds the lists from the .itm and .spc files, and the equipment
    slots from the items, so their values meant nothing, and a heap address made two saves of the same game differ. }
  rec := creature^;
  rec.effectsAddr := nil;
  rec.itemsAddr := nil;
  rec.nextCharAddr := nil;
  rec.combatAddr := nil;
  FillChar(rec.equipped, SizeOf(rec.equipped), 0);
  BlockWrite(f, rec, SizeOf(Types.TCharRecord), res);
  ok := (IOResult = 0) and (res = SizeOf(Types.TCharRecord));
  Close(f);
  ioRes := IOResult;
  FileUtil.DeleteFile(fn + '.itm');
  if creature^.itemsAddr <> nil then begin
    Assign(f, fn + '.itm');
    Rewrite(f, 1);
    if IOResult = 0 then begin
      item := creature^.itemsAddr;
      while item <> nil do begin
        itemRec := item^;
        itemRec.next := nil;
        BlockWrite(f, itemRec, SizeOf(Types.TItemRec), res);
        if (IOResult <> 0) or (res <> SizeOf(Types.TItemRec)) then
          ok := False;
        item := item^.next;
      end;
      Close(f);
      ioRes := IOResult;
    end else
      ok := False;
  end;
  FileUtil.DeleteFile(fn + '.spc');
  if creature^.effectsAddr <> nil then begin
    Assign(f, fn + '.spc');
    Rewrite(f, 1);
    if IOResult = 0 then begin
      effect := creature^.effectsAddr;
      while effect <> nil do begin
        effectRec := effect^;
        effectRec.next := nil;
        BlockWrite(f, effectRec, SizeOf(Types.TEffectRec), res);
        if (IOResult <> 0) or (res <> SizeOf(Types.TEffectRec)) then
          ok := False;
        effect := effect^.next;
      end;
      Close(f);
      ioRes := IOResult;
    end else
      ok := False;
  end;
  if not ok then
    TextRend.DisplayAndPause(Yellow, 'Could not save ' + Copy(creature^.name, 1, Types.NAME_LEN) + ' in full.');
  SaveLoad.WriteUsualSpells(creature, fn);
  Stats.WriteChar(creature, fn);
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
    msg := SaveLoad.SaveDiskMsg;
  end else
    msg := GDConsts.insertDiskMsg[GDVars.virtualDisk] + DaxIo.DataDrive + ':';
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
  if (GDVars.quickEnds <> 0) and CharHlp.ComesUnderPlayer(creature) then
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
  { the slots pointed into the heap of the game that saved them }
  CharHlp.LinkEquipped(creature);
  SaveLoad.ReadUsualSpells(creature, name);
  Stats.ReadChar(creature, name);
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
    { classes holds 4; shipped monsters have at most 4 class levels set }
    for i := 0 to 6 do
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
    while (orderNumber < Types.MAX_PARTY) and (used[orderNumber] <> 0) do
      Inc(orderNumber);
  end;
  Inc(GDVars.zone1^[C_Gbvm.PARTY_SIZE]);
  ClassCal.RecalcBaseSkills(creature);
end;

{ The least a savgam file holds: everything LoadSlot reads from it. }
function SaveMinSize: LongInt;
begin
  SaveMinSize := LongInt(SizeOf(GDVars.virtualDisk)) + SizeOf(GDVars.zone0^) + SizeOf(GDVars.zone1^) +
                 SizeOf(GDVars.zone2^) + C_Gbvm.SAVED_SCRIPT_BYTES + 5 + SizeOf(GDVars.gLocType) +
                 SizeOf(GDVars.ifcState) + SizeOf(Byte) + SizeOf(TSaveNames);
end;

{ Load saved game letter: the save file (one too short to hold it all is refused, with a message, before anything is
  read), then each listed character, and the rest LoadGame describes. The party must be empty. }
procedure LoadSlot(letter: Char);
var
  names: TSaveNames;
  f: file;
  i: Byte;
  creature: Types.PCharRecord;
  fn: Types.TPathStr;
  res: Word;
  nChars: Byte;
  found: Boolean;
begin
  found := DaxIo.OpenWithRetry(GDVars.dsSaveDirectory + 'savgam' + letter + '.dat', SaveLoad.SaveDiskMsg, #1, f);
  TextRend.ClearBottomLine;
  { a save shorter than everything read below is refused before any of it replaces the game in memory }
  if found then begin
    found := (IOResult = 0) and (FileSize(f) >= SaveLoad.SaveMinSize) and (IOResult = 0);
    if not found then
      Close(f);
    res := IOResult;
  end;
  if not found then begin
    TextRend.DisplayAndPause(Yellow, 'Save game ' + letter + ' is damaged.');
    TextRend.ClearBottomLine;
    Exit;
  end;
  TextRend.DisplayString(0, 24, LightGreen, 'Loading...Please Wait');
  BlockRead(f, GDVars.virtualDisk, SizeOf(GDVars.virtualDisk), res);
  { disks 1..8 only }
  if not (GDVars.virtualDisk in [1..Types.LAST_DISK]) then
    GDVars.virtualDisk := 1;
  BlockRead(f, GDVars.zone0^, SizeOf(GDVars.zone0^), res);
  BlockRead(f, GDVars.zone1^, SizeOf(GDVars.zone1^), res);
  BlockRead(f, GDVars.zone2^, SizeOf(GDVars.zone2^), res);
  { the script the save holds is passed over: GameLoop loads the area's script from the data (#609) }
  Seek(f, FilePos(f) + C_Gbvm.SAVED_SCRIPT_BYTES);
  BlockRead(f, GDVars.gMapX, 5, res);
  { a cardinal facing only }
  GDVars.gFacing := GDVars.gFacing and 6;
  BlockRead(f, GDVars.gLocType, SizeOf(GDVars.gLocType), res);
  BlockRead(f, GDVars.ifcState, SizeOf(GDVars.ifcState), res);
  BlockRead(f, nChars, SizeOf(nChars), res);
  BlockRead(f, names, SizeOf(names), res);
  Close(f);
  res := IOResult;
  { the vault left with this game is the session's vault now }
  Vault.RestoreFromSlot(letter);
  { the game's statistics (#611); a save made before them starts from none }
  Stats.ReadGame(GDVars.dsSaveDirectory + 'savgam' + letter + '.sts');
  { names holds 8, the most a party has }
  if nChars > 8 then
    nChars := 8;
  { the save's speed and settings word are SSI's copies: the game keeps its own settings (POOLOPT.CFG) }
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
    fn := SaveLoad.CharFileBase(creature^.name);
    { only a character that has its own .cha file has the rest of the set }
    if DaxIo.FileExists(fn + '.cha') then
      SaveLoad.EraseCharFiles(fn);
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
  if not (GDVars.virtualDisk in [1..Types.LAST_DISK]) then
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
  TextRend.ClearBottomLine;
end;

procedure LoadGame;
var
  letter: Char;
begin
  SaveLoad.CheckSaveDir;
  letter := SaveMenu.ChooseSlot(False, C_Keys.NONE);
  if letter <> C_Keys.NONE then
    SaveLoad.LoadSlot(letter);
end;

function QuickLoadable: Boolean;
var
  f: file;
  mode: Byte;
  ioRes: Integer;
begin
  QuickLoadable := False;
  Assign(f, GDVars.dsSaveDirectory + 'savgam' + QUICK_SLOT + '.dat');
  mode := FileMode;
  FileMode := 0;
  Reset(f, 1);
  FileMode := mode;
  if IOResult = 0 then begin
    QuickLoadable := (FileSize(f) >= SaveLoad.SaveMinSize) and (IOResult = 0);
    Close(f);
  end;
  ioRes := IOResult;
end;

procedure QuickLoad;
begin
  { the party goes only when there is a game to replace it }
  if not SaveLoad.QuickLoadable then begin
    TextRend.DisplayAndPause(Yellow, 'There is no quick save.');
    TextRend.ClearBottomLine;
    { GameLoop resumes the game in memory, as after a load }
    GDVars.loadedSave := 1;
    Exit;
  end;
  { RemoveCreature frees the head of the list while it is curChar }
  while GDVars.creatureList <> nil do begin
    GDVars.curChar := GDVars.creatureList;
    CharGen.RemoveCreature(False, True);
  end;
  GDVars.curChar := nil;
  SaveLoad.LoadSlot(QUICK_SLOT);
  { as CharGen.MainMenu does after a load: GameLoop keeps the loaded script }
  GDVars.loadedSave := 1;
  GDVars.locTypePrev := C_Area.LOC_3D_MAP;
end;

{ Write saved game letter, with desc and area for its slot-info file: the rest SaveGame describes after the menu. }
procedure SaveToSlot(letter: Char; desc: SaveMenu.TSlotDesc; area: SaveMenu.TSlotArea);
var
  names: TSaveNames;
  f: file;
  n: Byte;
  p: Types.PCharRecord;
  numStr: String[1];
begin
  { the script a load reopens (#609): GameLoop records the running one only once the map menu returns, and NEWECL
    leaves the old area's there until then }
  GDVars.zone0^.previousScriptId := GDVars.eclScriptId;
  { the names' unused characters too, so a save holds nothing left over in memory }
  FillChar(names, SizeOf(names), 0);
  SaveLoad.CheckSaveDir;
  SaveLoad.RewriteSaveFile(f, GDVars.dsSaveDirectory + 'savgam' + letter + '.dat');
  TextRend.ClearBottomLine;
  TextRend.DisplayString(0, 24, LightGreen, 'Saving...Please Wait');
  for n := 1 to 3 do begin
    GDVars.zone0^.words[C_Gbvm.WALLSLOT_ID + n] := wallSlots[n].wallDefId;
    GDVars.zone0^.words[C_Gbvm.WALLSLOT_SLOT + n] := wallSlots[n].symbolSlot;
  end;
  GDVars.zone0^.gameSpeed.value := GDVars.gameDelay;
  GDVars.zone0^.settings := (1 - GDVars.musicOn) * 4 + GDVars.monsterPics * 2 + GDVars.portraitsOn;
  GDVars.zone1^[C_Gbvm.DISK_NUM] := GDVars.virtualDisk;
  BlockWrite(f, GDVars.virtualDisk, SizeOf(GDVars.virtualDisk));
  BlockWrite(f, GDVars.zone0^, SizeOf(GDVars.zone0^));
  BlockWrite(f, GDVars.zone1^, SizeOf(GDVars.zone1^));
  BlockWrite(f, GDVars.zone2^, SizeOf(GDVars.zone2^));
  { SSI's part of the script buffer, so the file stays SSI's size }
  BlockWrite(f, GDVars.zone3^, C_Gbvm.SAVED_SCRIPT_BYTES);
  BlockWrite(f, GDVars.gMapX, 5);
  BlockWrite(f, GDVars.gLocType, SizeOf(GDVars.gLocType));
  BlockWrite(f, GDVars.ifcState, SizeOf(GDVars.ifcState));
  { names holds 8, the most a party has }
  n := 0;
  p := GDVars.creatureList;
  while (p <> nil) and (n < Types.MAX_PARTY) do begin
    Inc(n);
    Str(n, numStr);
    names[n] := 'CHRDAT' + letter + numStr;
    p := p^.nextCharAddr;
  end;
  BlockWrite(f, n, SizeOf(n));
  BlockWrite(f, names, SizeOf(names));
  Close(f);
  SaveMenu.WriteSlotInfo(letter, desc, area);
  Vault.CommitToSlot(letter);
  Stats.WriteGame(GDVars.dsSaveDirectory + 'savgam' + letter + '.sts');
  p := GDVars.creatureList;
  n := 0;
  while (p <> nil) and (n < Types.MAX_PARTY) do begin
    Inc(n);
    Str(n, numStr);
    SaveLoad.SaveChar(p, 'CHRDAT' + letter + numStr);
    SaveLoad.EraseCharFiles(SaveLoad.CharFileBase(p^.name));
    p := p^.nextCharAddr;
  end;
  GDVars.recentSaved := 1;
  TextRend.ClearBottomLine;
end;

procedure SaveGame;
var
  letter: Char;
  desc: SaveMenu.TSlotDesc;
  area: SaveMenu.TSlotArea;
  oldArea: SaveMenu.TSlotArea;
  ok: Boolean;
begin
  SaveLoad.CheckSaveDir;
  area := AreaName.CurrentArea;
  letter := C_Keys.NONE;
  repeat
    { back from the popup, the menu opens on the slot it was for }
    letter := SaveMenu.ChooseSlot(True, letter);
    if letter = C_Keys.NONE then Exit;
    { an overwritten save's description is offered to edit }
    ok := SaveMenu.ReadSlotInfo(letter, desc, oldArea);
    ok := SaveMenu.AskDescription(letter, area, desc);
  until ok;
  SaveLoad.SaveToSlot(letter, desc, area);
end;

procedure QuickSave;
begin
  SaveLoad.SaveToSlot(QUICK_SLOT, 'QUICK SAVE', AreaName.CurrentArea);
  TextRend.DisplayAndPause(LightGreen, 'Quick save done.');
  TextRend.ClearBottomLine;
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
    Dec(GDVars.gMapY, GDConsts.dirDY[GDVars.gFacing]);
    View3D.WrapCoords(GDVars.gMapX, GDVars.gMapY);
    DaxIo.PopState;
    SaveLoad.SaveGame;
    GameIo.ExitGame;
  end;
end;

begin
  FillChar(usualOwner, SizeOf(usualOwner), 0);
end.

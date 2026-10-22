{ Character files, saved games and party assembly. CHARLIST.TXT lists available characters; .cha/.itm/.spc files hold
  their records, inventory and effects, and a .mem file their usual spells. SAVGAMx.DAT stores the world and party
  state, with party members in CHRDATxN.sav files. }
{$O+,F+,I-}
{$I COMPILER.INC}
unit SaveLoad;

interface

uses Types;

{ Read <saveDir>charlist.txt into a fresh list of string nodes (the TItemRec prefix used by
  MenuCore.AllocStringList/FreeStringList); list is nil when the file does not exist. Names of characters currently in
  the party get '* ' prepended. }
procedure LoadCharlist(var list: Types.PItemRec);

{ Rewrite <saveDir>charlist.txt, one name per line, a party member's without its '* ' mark: a character in the party
  keeps its own files, so it stays on the roster (SSI dropped it, as saving or loading a game erased them). A line
  naming omit, marked or not, is left out ('' leaves out none). Retries with a put-save-disk prompt until the file opens
  or Escape gives up, which leaves the roster as it was. }
procedure SaveCharlist(list: Types.PItemRec; omit: String);

{ Load curChar's CHEAD into icon-anim slot 11 and CBODY into slot orderNumber, OR-merge head onto body; when loading,
  remap the default icon colours to the character's iconColors1 nibbles. Icons live on virtual disk 3. }
procedure LoadCharIconAnim(loading: Boolean);

{ fname='' -> single-character save: write <saveDir><sanitized-name>.cha/.itm/.spc and add the name to CHARLIST.TXT when
  it is not there;
  fname<>'' -> saved-game member: write <saveDir><fname>.sav/.itm/.spc. Each is written to a temporary copy, and only
  when all are whole are they put in place of the old ones; an empty item or effect list's old file is erased. The .mem
  and .sts files beside them are rewritten then, holding the character's usual spells and statistics when it has any. A
  set that cannot be written whole (a full disk) leaves the old files and CHARLIST.TXT as they were and is reported on
  the bottom line, as is a .mem or .sts that could not be written. True when the character was saved. }
function SaveChar(creature: Types.PCharRecord; fname: Types.TStr8): Boolean;

{ Erase a character's single-character files (.cha, .itm, .spc, .mem, .sts, those there are) and take its name off
  CHARLIST.TXT: a character dropped forever, whose files loading or saving a game no longer erases (#754). }
procedure EraseChar(name: String);

{ Load one character: askDisk -> name the file as SaveChar does (CharFileBase) and prompt for the save disk, else prompt
  with the insert-game-disk message (DaxIo.DataDiskMsg, Escape quits); ext = '.sav'/'.cha' by savedGame. The list and
  combat pointers are cleared, then the item/effect lists are rebuilt from the .itm/.spc files when they exist, stopping
  at a read error or a trailing part record, and the usual spells are read from the .mem file (none when it is missing
  or not a usual-spells file for this character). False, with nothing read after the record, when the .sav/.cha file
  holds less than a whole record or cannot be read, or is not there and Escape at the save disk prompt gave up
  (askDisk); the caller then frees the record unused. While the Quick Ends With Fight setting is on (GDVars.quickEnds),
  a party member leaves Quick (quickfight 0), so a loaded game or an added character starts under manual control; NPCs
  and animated creatures keep quickfight, as PostCbt.PostCombatCreatureCleanup leaves them. With the setting off the
  saved quickfight stays. }
function LoadChar(name: String; creature: Types.PCharRecord; savedGame, askDisk: Boolean): Boolean;

{ True when the character's single-character record, <saveDir><name>.cha (as SaveChar names it), is there. }
function HasCharFile(name: String): Boolean;

{ Load game: offer the existing SAVGAMA..J.DAT on the full-screen SaveMenu (Escape aborts), read the save file (one too
  short to hold it all is refused, with a message, before anything is read), reload each listed character, at most 8,
  from its CHRDATxN.sav (one that is missing, short or unreadable is left out), reload icon anims, the 3D map and wall
  sets ('ICON' in the wilderness), and run Ending.YarashComplete when the Yarash pyramid flag is set; the slot's vault
  becomes the session's (Vault.RestoreFromSlot). The members' single-character files are left alone (SSI erased them).
  The save's game speed and settings word are left in the GBVM zone: the game's own settings stay as they are. }
procedure LoadGame;

{ Save game: choose a slot on the full-screen SaveMenu and give it a description (the slot's old one to start from;
  Escape on the menu aborts, Exit in the description popup goes back to the menu), store wall slots, game speed, picture
  and music settings (SSI's copies, which loading leaves alone) and disk number in the GBVM zones, write SAVGAMx.DAT,
  each party member (the first 8) as CHRDATxN.sav, copy the session vault to the slot (Vault.CommitToSlot), and only
  when all of them were written whole put them in place of the old save's; then write the slot's description and the
  current area (AreaName.CurrentArea) to SAVGAMx.INF and set the recently-saved flag. The members' single-character
  files are left alone (SSI erased them, here and on loading). A save not written whole leaves the old one as it was and
  says so, as does a save whose side files (.inf, .sts, .map, .nts, the members' .mem and .sts) were not all written.
  True when the game was saved; False also for Escape on the menu. The caller redraws the screen. }
function SaveGame: Boolean;

const
  { the quick-save slot: F5 saves to it and F8 loads it, from the map menu }
  QUICK_SLOT = 'Q';

{ Quick save: save into QUICK_SLOT, described as QUICK SAVE, with no menu, and say on the bottom line whether it was
  saved. }
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
  restore the previous virtual disk, SaveGame and exit to DOS (GameIo.ExitGame). A save cancelled or not written puts
  the party and the disk back and offers the choice again. }
procedure CheckFileElseQuit(name: Types.TPathStr);

procedure FreeCreature(creature: Types.PCharRecord);

procedure RemoveCreature(suppressSizeDec, freeAnim: Boolean);

{ Free every creature in the list, with its icon animation; the party size drops to 0 and curChar becomes nil. }
procedure FreeParty;

implementation

uses DiskRec, Crt, C_Area, GDConsts, GDVars, Blit, TextRend, GameIo, MenuCore, Ending, ClassCal, View3D, MapTiles,
  C_Keys, C_Ifc, C_Gbvm, C_Npc, C_Status, SaveMenu, AreaName, Vault, Stats, DaxIo, CharHlp, FileUtil, Party, StrUtil,
  UsualSpl, VidOps, Explored, MapNotes, C_Effect, C_Level, CharDisp{$IFDEF FPC}, NatFile{$ENDIF};

type
  { the party's names in a savgam file: the CHRDATxN files they are kept in }
  TSaveNames = array[1..Types.MAX_PARTY] of Types.TStr40;

{ Create file name's temporary copy (FileUtil.RewriteTemp) for writing, asking for the save disk until it can be: False
  when Escape gave up (SaveMenu.AskSaveDisk), with nothing open. }
function RewriteSaveFile(var f: file; name: Types.TPathStr): Boolean;
var
  opened: Boolean;
begin
  repeat
    opened := FileUtil.RewriteTemp(f, name);
  until opened or not SaveMenu.AskSaveDisk('Cannot write', name);
  RewriteSaveFile := opened;
end;

{ A character's single-character files' path and base name, from its name: <saveDir><name>, sanitized for DOS. }
function CharFileBase(name: String): Types.TPathStr;
begin
  CharFileBase := GDVars.dsSaveDirectory + DaxIo.SanitizeFileName(DaxIo.SanitizeString(name, '.'));
end;

function HasCharFile(name: String): Boolean;
begin
  HasCharFile := DaxIo.FileExists(SaveLoad.CharFileBase(name) + '.cha');
end;

{ Nodes are TMenuNode-sized: the TItemRec prefix (name, inUse, next), not the full record. '* ' marks party members. }
procedure LoadCharlist(var list: Types.PItemRec);
var
  tail: Types.PItemRec;
  p: Types.PCharRecord;
  f: Text;
begin
  list := nil;
  SaveMenu.CheckSaveDir;
  if not DaxIo.FileExists(GDVars.dsSaveDirectory + 'charlist.txt') then Exit;
  Assign(f, GDVars.dsSaveDirectory + 'charlist.txt');
  Reset(f);
  while not Eof(f) do begin
    MenuCore.AppendMenuLine(list, tail, '', False);
    ReadLn(f, tail^.name);
    p := GDVars.creatureList;
    while (p <> nil) and (p^.name <> tail^.name) do
      p := p^.nextCharAddr;
    if p <> nil then
      tail^.name := '* ' + tail^.name;
  end;
  Close(f);
end;

procedure SaveCharlist(list: Types.PItemRec; omit: String);
var
  p: Types.PItemRec;
  f: Text;
  ioRes: Integer;
  name: String;
begin
  SaveMenu.CheckSaveDir;
  repeat
    Assign(f, GDVars.dsSaveDirectory + 'charlist.txt');
    Rewrite(f);
    ioRes := IOResult;
  until (ioRes = 0) or not SaveMenu.AskSaveDisk('Cannot write', GDVars.dsSaveDirectory + 'charlist.txt');
  { Escape gave up: the roster stays as it was }
  if ioRes <> 0 then Exit;
  p := list;
  while p <> nil do begin
    name := p^.name;
    if Copy(name, 1, 2) = '* ' then
      Delete(name, 1, 2);
    if (Length(omit) = 0) or (name <> omit) then
      WriteLn(f, name);
    p := p^.next;
  end;
  Close(f);
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
    VidOps.MergePic(GDVars.dsIconAnimation[11, 0], GDVars.dsIconAnimation[orderNumber, 0]);
    VidOps.MergePic(GDVars.dsIconAnimation[11, 1], GDVars.dsIconAnimation[orderNumber, 1]);
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

{ Erase the temporary copies WriteCharFiles (below) writes for <fn><ext>, those there are. }
procedure DropCharFiles(fn: Types.TPathStr; ext: Types.TStr8);
begin
  FileUtil.DeleteFile(FileUtil.TempName(fn + ext));
  FileUtil.DeleteFile(FileUtil.TempName(fn + '.itm'));
  FileUtil.DeleteFile(FileUtil.TempName(fn + '.spc'));
end;

{ Write creature's record, items and effects to the temporary copies (FileUtil.TempName) of <fn><ext>, <fn>.itm and
  <fn>.spc, an empty list's file not at all: True when every one is whole, else none is left. The records go out with
  their pointers cleared: loading rebuilds the lists from the .itm and .spc files, and the equipment slots from the
  items, so their values meant nothing, and a heap address made two saves of the same game differ. }
function WriteCharFiles(creature: Types.PCharRecord; fn: Types.TPathStr; ext: Types.TStr8): Boolean;
var
  f: file;
  ok: Boolean;
  item: Types.PItemRec;
  effect: Types.PEffectRec;
  { the record as written: a copy with its pointers cleared, as below for each item and effect }
  rec: Types.TCharRecord;
  itemRec: Types.TItemRec;
  effectRec: Types.TEffectRec;
  { each as the file has it (DiskRec) }
  recDisk: DiskRec.TCharDisk;
  itemDisk: DiskRec.TItemDisk;
  effectDisk: DiskRec.TEffectDisk;
begin
  ok := SaveLoad.RewriteSaveFile(f, fn + ext);
  rec := creature^;
  rec.effectsAddr := nil;
  rec.itemsAddr := nil;
  rec.nextCharAddr := nil;
  rec.combatAddr := nil;
  FillChar(rec.equipped, SizeOf(rec.equipped), 0);
  DiskRec.CharToDisk(rec, recDisk);
  if ok then begin
    FileUtil.WriteChecked(f, recDisk, DiskRec.CHAR_DISK_BYTES, ok);
    ok := FileUtil.CloseTemp(f, fn + ext, ok);
  end;
  if ok and (creature^.itemsAddr <> nil) then begin
    ok := FileUtil.RewriteTemp(f, fn + '.itm');
    if ok then begin
      item := creature^.itemsAddr;
      while ok and (item <> nil) do begin
        itemRec := item^;
        itemRec.next := nil;
        DiskRec.ItemToDisk(itemRec, itemDisk);
        FileUtil.WriteChecked(f, itemDisk, DiskRec.ITEM_DISK_BYTES, ok);
        item := item^.next;
      end;
      ok := FileUtil.CloseTemp(f, fn + '.itm', ok);
    end;
  end;
  if ok and (creature^.effectsAddr <> nil) then begin
    ok := FileUtil.RewriteTemp(f, fn + '.spc');
    if ok then begin
      effect := creature^.effectsAddr;
      while ok and (effect <> nil) do begin
        effectRec := effect^;
        effectRec.next := nil;
        DiskRec.EffectToDisk(effectRec, effectDisk);
        FileUtil.WriteChecked(f, effectDisk, DiskRec.EFFECT_DISK_BYTES, ok);
        effect := effect^.next;
      end;
      ok := FileUtil.CloseTemp(f, fn + '.spc', ok);
    end;
  end;
  if not ok then
    SaveLoad.DropCharFiles(fn, ext);
  WriteCharFiles := ok;
end;

{ Put the copies WriteCharFiles wrote for creature in place of <fn><ext>, .itm and .spc (an empty list's old file is
  erased), then write its .mem and .sts beside them, clearing whole when either was not written: True when every copy
  was put in place. A record that is not put in place takes none of the rest with it. }
function PlaceCharFiles(creature: Types.PCharRecord; fn: Types.TPathStr; ext: Types.TStr8; var whole: Boolean): Boolean;
var
  ok: Boolean;
begin
  { a record that cannot replace the old one (a read-only file) leaves the old set as it was }
  ok := FileUtil.PutInPlace(fn + ext);
  if ok then begin
    if creature^.itemsAddr <> nil then
      ok := FileUtil.PutInPlace(fn + '.itm')
    else
      FileUtil.DeleteFile(fn + '.itm');
    if creature^.effectsAddr <> nil then
      ok := FileUtil.PutInPlace(fn + '.spc') and ok
    else
      FileUtil.DeleteFile(fn + '.spc');
    whole := UsualSpl.WriteUsualSpells(creature, fn) and whole;
    whole := Stats.WriteChar(creature, fn) and whole;
  end else
    SaveLoad.DropCharFiles(fn, ext);
  PlaceCharFiles := ok;
end;

function SaveChar(creature: Types.PCharRecord; fname: Types.TStr8): Boolean;
var
  fn: Types.TPathStr;
  ext: String[4];
  list: Types.PItemRec;
  p: Types.PItemRec;
  tail: Types.PItemRec;
  ok: Boolean;
  { the .mem and .sts were written too }
  whole: Boolean;
  found: Boolean;
begin
  SaveMenu.CheckSaveDir;
  if Length(fname) = 0 then begin
    ext := '.cha';
    fn := SaveLoad.CharFileBase(creature^.name);
  end else begin
    ext := '.sav';
    fn := GDVars.dsSaveDirectory + fname;
  end;
  { a write that fails (a full disk) leaves the old files as they were }
  whole := True;
  ok := SaveLoad.WriteCharFiles(creature, fn, ext) and SaveLoad.PlaceCharFiles(creature, fn, ext, whole);
  if not (ok and whole) then
    TextRend.DisplayAndPause(Yellow, 'Could not save ' + Copy(creature^.name, 1, Types.NAME_LEN) + ' in full.');
  if ok and (Length(fname) = 0) then begin
    { the name is added once: a party member's line, which LoadCharlist marks with '* ', is its own }
    SaveLoad.LoadCharlist(list);
    p := list;
    tail := nil;
    found := False;
    while p <> nil do begin
      if (p^.name = creature^.name) or (p^.name = '* ' + creature^.name) then
        found := True;
      tail := p;
      p := p^.next;
    end;
    if not found then begin
      MenuCore.AppendMenuLine(list, tail, creature^.name, False);
      SaveLoad.SaveCharlist(list, '');
    end;
    MenuCore.FreeStringList(list);
  end;
  SaveChar := ok;
end;

procedure EraseChar(name: String);
var
  fn: Types.TPathStr;
  list: Types.PItemRec;
begin
  fn := SaveLoad.CharFileBase(name);
  FileUtil.DeleteFile(fn + '.cha');
  FileUtil.DeleteFile(fn + '.itm');
  FileUtil.DeleteFile(fn + '.spc');
  FileUtil.DeleteFile(fn + '.mem');
  FileUtil.DeleteFile(fn + '.sts');
  SaveLoad.LoadCharlist(list);
  if list <> nil then begin
    SaveLoad.SaveCharlist(list, name);
    MenuCore.FreeStringList(list);
  end;
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
  { each as the file has it (DiskRec) }
  recDisk: DiskRec.TCharDisk;
  itemDisk: DiskRec.TItemDisk;
  effectDisk: DiskRec.TEffectDisk;
begin
  if askDisk then begin
    { as SaveChar names it: SanitizeFileName alone keeps one of two periods in a row (A..B), which DOS then took for the
      extension }
    name := SaveLoad.CharFileBase(name);
    msg := SaveMenu.SaveDiskMsg;
  end else
    msg := DaxIo.DataDiskMsg;
  if savedGame then
    ext := '.sav'
  else
    ext := '.cha';
  { Escape at the save disk prompt gives up on a character whose file is gone (#794) }
  found := DaxIo.OpenWithRetry(name + ext, msg, False, not askDisk, f);
  LoadChar := False;
  if not found then Exit;
  res := 0;
  { a short file overwrites only the record's start, as a read straight into it did }
  DiskRec.CharToDisk(creature^, recDisk);
  BlockRead(f, recDisk, DiskRec.CHAR_DISK_BYTES, res);
  whole := (IOResult = 0) and (res = DiskRec.CHAR_DISK_BYTES);
  DiskRec.CharFromDisk(recDisk, creature^);
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
    found := DaxIo.OpenWithRetry(name + '.itm', msg, False, not askDisk, f);
    item := nil;
    whole := found;
    while whole and not Eof(f) do begin
      GetMem(newItem, SizeOf(Types.TItemRec));
      res := 0;
      BlockRead(f, itemDisk, DiskRec.ITEM_DISK_BYTES, res);
      whole := (IOResult = 0) and (res = DiskRec.ITEM_DISK_BYTES);
      if whole then begin
        DiskRec.ItemFromDisk(itemDisk, newItem^);
        newItem^.next := nil;
        if item = nil then
          creature^.itemsAddr := newItem
        else
          item^.next := newItem;
        item := newItem;
      end else
        FreeMem(newItem, SizeOf(Types.TItemRec));
    end;
    if found then
      Close(f);
  end;
  if DaxIo.FileExists(name + '.spc') then begin
    found := DaxIo.OpenWithRetry(name + '.spc', msg, False, not askDisk, f);
    effect := nil;
    whole := found;
    while whole and not Eof(f) do begin
      GetMem(newEffect, SizeOf(Types.TEffectRec));
      res := 0;
      BlockRead(f, effectDisk, DiskRec.EFFECT_DISK_BYTES, res);
      whole := (IOResult = 0) and (res = DiskRec.EFFECT_DISK_BYTES);
      if whole then begin
        DiskRec.EffectFromDisk(effectDisk, newEffect^);
        newEffect^.next := nil;
        if effect = nil then
          creature^.effectsAddr := newEffect
        else
          effect^.next := newEffect;
        effect := newEffect;
      end else
        FreeMem(newEffect, SizeOf(Types.TEffectRec));
    end;
    if found then
      Close(f);
  end;
  { a paladin created by SSI's game, or before #742, has eff 8 as his own Protection from Evil (permanent, strength
    255): it becomes the 10' radius one character creation gives now }
  if creature^.classLevels[C_Level.PALADIN] > 0 then begin
    effect := creature^.effectsAddr;
    while effect <> nil do begin
      if (effect^.id = C_Effect.PROT_EVIL) and (effect^.duration = 0) and (effect^.strength = 255) then
        effect^.id := C_Effect.PROT_EVIL_10FT;
      effect := effect^.next;
    end;
  end;
  { the slots pointed into the heap of the game that saved them }
  CharHlp.LinkEquipped(creature);
  UsualSpl.ReadUsualSpells(creature, name);
  Stats.ReadChar(creature, name);
end;

procedure AddCharToParty(creature: Types.PCharRecord);
var
  p: Types.PCharRecord;
  used: array[0..Types.MAX_PARTY - 1] of Byte;
begin
  creature^.orderNumber := 255;
  if GDVars.creatureList = nil then begin
    GDVars.creatureList := creature;
    GDVars.curChar := creature;
  end else
    Party.LastCreature^.nextCharAddr := creature;
  FillChar(used, SizeOf(used), 0);
  p := GDVars.creatureList;
  while p <> nil do begin
    if p^.orderNumber in [0..Types.MAX_PARTY - 1] then
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
  found := DaxIo.OpenWithRetry(GDVars.dsSaveDirectory + 'savgam' + letter + '.dat', SaveMenu.SaveDiskMsg, True,
                         False, f);
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
  { the party's map position: SSI's five bytes }
  BlockRead(f, GDVars.gMapX, SizeOf(GDVars.gMapX), res);
  BlockRead(f, GDVars.gMapY, SizeOf(GDVars.gMapY), res);
  BlockRead(f, GDVars.gFacing, SizeOf(GDVars.gFacing), res);
  BlockRead(f, GDVars.wallAhead, SizeOf(GDVars.wallAhead), res);
  BlockRead(f, GDVars.eventAtCell, SizeOf(GDVars.eventAtCell), res);
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
  Explored.ReadSlot(GDVars.dsSaveDirectory + 'savgam' + letter + '.map');
  MapNotes.ReadSlot(GDVars.dsSaveDirectory + 'savgam' + letter + '.nts');
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
      SaveMenu.CheckSaveDir;
    end;
  end;
  GDVars.curChar := GDVars.creatureList;
  while GDVars.curChar <> nil do begin
    SaveLoad.LoadCharIconAnim(True);
    GDVars.curChar := GDVars.curChar^.nextCharAddr;
  end;
  GDVars.curChar := GDVars.creatureList;
  { the disk number SaveGame stored at C_Gbvm.DISK_NUM }
  GDVars.virtualDisk := Lo(GDVars.zone1^[C_Gbvm.DISK_NUM]);
  if not (GDVars.virtualDisk in [1..Types.LAST_DISK]) then
    GDVars.virtualDisk := 1;
  if GDVars.gLocType < C_Area.LOC_WILD_WEST then
    View3D.Load3DMap(GDVars.zone0^.mapId.lo);
  if GDVars.gLocType > C_Area.LOC_3D_MAP then
    MapTiles.LoadIconAnim('ICON', 0, 11)
  else
    for i := 1 to 3 do begin
      GDVars.dsWallSetCache[i].wallDefId := GDVars.zone0^.words[C_Gbvm.WALLSLOT_ID + i];
      GDVars.dsWallSetCache[i].symbolSlot := GDVars.zone0^.words[C_Gbvm.WALLSLOT_SLOT + i];
      if GDVars.dsWallSetCache[i].wallDefId >= 0 then
        View3D.LoadWallSet(GDVars.dsWallSetCache[i].wallDefId, GDVars.dsWallSetCache[i].symbolSlot);
    end;
  { the file's last wall slot shares the menu animation flag (#651), which no menu was showing when it was saved }
  GDVars.zone0^.savedWalls.menuAnimation := 0;
  if GDVars.zone0^.yarashPyramidLeft <> 0 then
    Ending.YarashComplete(False);
  TextRend.ClearBottomLine;
end;

procedure LoadGame;
var
  letter: Char;
begin
  SaveMenu.CheckSaveDir;
  letter := SaveMenu.ChooseSlot(False, C_Keys.NONE);
  if letter <> C_Keys.NONE then
    SaveLoad.LoadSlot(letter);
end;

function QuickLoadable: Boolean;
var
  f: file;
  ioRes: Integer;
begin
  QuickLoadable := False;
  if FileUtil.OpenReadOnly(f, GDVars.dsSaveDirectory + 'savgam' + QUICK_SLOT + '.dat') then begin
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
  SaveLoad.FreeParty;
  SaveLoad.LoadSlot(QUICK_SLOT);
  { as CharGen.MainMenu does after a load: GameLoop keeps the loaded script }
  GDVars.loadedSave := 1;
  GDVars.locTypePrev := C_Area.LOC_3D_MAP;
end;

{ CHRDAT<letter><n>: the base name of the n-th party member's files in saved game letter. }
function MemberName(letter: Char; n: Byte): Types.TStr8;
var
  numStr: String[1];
begin
  Str(n, numStr);
  MemberName := 'CHRDAT' + letter + numStr;
end;

{ Write saved game letter, with desc and area for its slot-info file: the rest SaveGame describes after the menu. The
  save file and the members' files are written to temporary copies first, and only when every one is whole, and the
  vault was copied, are they put in place of the old ones (FileUtil.PutInPlace); else the old save is left as it was and
  the bottom line says the game was not saved. True when it was. }
function SaveToSlot(letter: Char; desc: SaveMenu.TSlotDesc; area: SaveMenu.TSlotArea): Boolean;
var
  names: TSaveNames;
  f: file;
  n: Byte;
  count: Byte;
  p: Types.PCharRecord;
  walls: Types.TGbvmSavedWalls;
  fn: Types.TPathStr;
  ok: Boolean;
  { the save file's copy was created: it is closed after the writes }
  opened: Boolean;
  { the side files were written too }
  whole: Boolean;
begin
  { the script a load reopens (#609): GameLoop records the running one only once the map menu returns, and NEWECL leaves
    the old area's there until then }
  GDVars.zone0^.previousScriptId := GDVars.eclScriptId;
  { the names' unused characters too, so a save holds nothing left over in memory }
  FillChar(names, SizeOf(names), 0);
  SaveMenu.CheckSaveDir;
  fn := GDVars.dsSaveDirectory + 'savgam' + letter + '.dat';
  { a save folder that cannot be written fails the save once Escape gives up (#794): nothing is written below }
  opened := SaveLoad.RewriteSaveFile(f, fn);
  ok := opened;
  TextRend.ClearBottomLine;
  TextRend.DisplayString(0, 24, LightGreen, 'Saving...Please Wait');
  { the wall slots go in the file only (#651): in memory their words are the script's, the last of them the menu
    animation flag, which would set the next menu animating the last picture loaded over the view }
  walls := GDVars.zone0^.savedWalls;
  for n := 1 to 3 do begin
    GDVars.zone0^.words[C_Gbvm.WALLSLOT_ID + n] := GDVars.dsWallSetCache[n].wallDefId;
    GDVars.zone0^.words[C_Gbvm.WALLSLOT_SLOT + n] := GDVars.dsWallSetCache[n].symbolSlot;
  end;
  GDVars.zone0^.gameSpeed.value := GDVars.gameDelay;
  GDVars.zone0^.settings := (1 - GDVars.musicOn) * 4 + GDVars.monsterPics * 2 + GDVars.portraitsOn;
  GDVars.zone1^[C_Gbvm.DISK_NUM] := GDVars.virtualDisk;
  FileUtil.WriteChecked(f, GDVars.virtualDisk, SizeOf(GDVars.virtualDisk), ok);
  FileUtil.WriteChecked(f, GDVars.zone0^, SizeOf(GDVars.zone0^), ok);
  GDVars.zone0^.savedWalls := walls;
  FileUtil.WriteChecked(f, GDVars.zone1^, SizeOf(GDVars.zone1^), ok);
  FileUtil.WriteChecked(f, GDVars.zone2^, SizeOf(GDVars.zone2^), ok);
  { SSI's part of the script buffer, so the file stays SSI's size }
  FileUtil.WriteChecked(f, GDVars.zone3^, C_Gbvm.SAVED_SCRIPT_BYTES, ok);
  { the party's map position: SSI's five bytes }
  FileUtil.WriteChecked(f, GDVars.gMapX, SizeOf(GDVars.gMapX), ok);
  FileUtil.WriteChecked(f, GDVars.gMapY, SizeOf(GDVars.gMapY), ok);
  FileUtil.WriteChecked(f, GDVars.gFacing, SizeOf(GDVars.gFacing), ok);
  FileUtil.WriteChecked(f, GDVars.wallAhead, SizeOf(GDVars.wallAhead), ok);
  FileUtil.WriteChecked(f, GDVars.eventAtCell, SizeOf(GDVars.eventAtCell), ok);
  FileUtil.WriteChecked(f, GDVars.gLocType, SizeOf(GDVars.gLocType), ok);
  FileUtil.WriteChecked(f, GDVars.ifcState, SizeOf(GDVars.ifcState), ok);
  { names holds 8, the most a party has }
  count := 0;
  p := GDVars.creatureList;
  while (p <> nil) and (count < Types.MAX_PARTY) do begin
    Inc(count);
    names[count] := SaveLoad.MemberName(letter, count);
    p := p^.nextCharAddr;
  end;
  FileUtil.WriteChecked(f, count, SizeOf(count), ok);
  FileUtil.WriteChecked(f, names, SizeOf(names), ok);
  if opened then
    ok := FileUtil.CloseTemp(f, fn, ok);
  { every member's copies, while all are whole }
  p := GDVars.creatureList;
  n := 0;
  while ok and (n < count) do begin
    Inc(n);
    ok := SaveLoad.WriteCharFiles(p, GDVars.dsSaveDirectory + SaveLoad.MemberName(letter, n), '.sav');
    p := p^.nextCharAddr;
  end;
  { the vault's own copy is put in place, or not, by itself }
  ok := ok and Vault.CommitToSlot(letter);
  whole := True;
  if ok then begin
    ok := FileUtil.PutInPlace(fn);
    p := GDVars.creatureList;
    for n := 1 to count do begin
      if ok then
        ok := SaveLoad.PlaceCharFiles(p, GDVars.dsSaveDirectory + SaveLoad.MemberName(letter, n), '.sav', whole)
      else
        SaveLoad.DropCharFiles(GDVars.dsSaveDirectory + SaveLoad.MemberName(letter, n), '.sav');
      p := p^.nextCharAddr;
    end;
    whole := SaveMenu.WriteSlotInfo(letter, desc, area) and whole;
    whole := Stats.WriteGame(GDVars.dsSaveDirectory + 'savgam' + letter + '.sts') and whole;
    whole := Explored.WriteSlot(GDVars.dsSaveDirectory + 'savgam' + letter + '.map') and whole;
    whole := MapNotes.WriteSlot(GDVars.dsSaveDirectory + 'savgam' + letter + '.nts') and whole;
  end else begin
    FileUtil.DeleteFile(FileUtil.TempName(fn));
    for n := 1 to count do
      SaveLoad.DropCharFiles(GDVars.dsSaveDirectory + SaveLoad.MemberName(letter, n), '.sav');
  end;
  TextRend.ClearBottomLine;
  if ok then begin
    GDVars.recentSaved := 1;
    if not whole then begin
      TextRend.DisplayAndPause(Yellow, 'The game was saved, but not in full.');
      TextRend.ClearBottomLine;
    end;
  end else begin
    TextRend.DisplayAndPause(Yellow, 'The game was not saved.');
    TextRend.ClearBottomLine;
  end;
  SaveToSlot := ok;
end;

function SaveGame: Boolean;
var
  letter: Char;
  desc: SaveMenu.TSlotDesc;
  area: SaveMenu.TSlotArea;
  oldArea: SaveMenu.TSlotArea;
  ok: Boolean;
begin
  SaveGame := False;
  SaveMenu.CheckSaveDir;
  area := AreaName.CurrentArea;
  letter := C_Keys.NONE;
  repeat
    { back from the popup, the menu opens on the slot it was for }
    letter := SaveMenu.ChooseSlot(True, letter);
    if letter = C_Keys.NONE then Exit;
    { an overwritten save's description is offered to edit; ReadSlotInfo leaves it empty for a slot with none, so
      whether it found one does not matter here }
    ok := SaveMenu.ReadSlotInfo(letter, desc, oldArea);
    ok := SaveMenu.AskDescription(letter, area, desc);
  until ok;
  SaveGame := SaveLoad.SaveToSlot(letter, desc, area);
end;

procedure QuickSave;
begin
  { a save that failed has said so }
  if SaveLoad.SaveToSlot(QUICK_SLOT, 'QUICK SAVE', AreaName.CurrentArea) then begin
    TextRend.DisplayAndPause(LightGreen, 'Quick save done.');
    TextRend.ClearBottomLine;
  end;
end;

procedure CheckFileElseQuit(name: Types.TPathStr);
var
  msg: Types.TStr40;
  ch: Char;
  ext: Boolean;
  saving: Boolean;
  x: Byte;
  y: Byte;
  disk: Byte;
begin
  if DaxIo.FileExists(name) then Exit;
  msg := 'Save and exit  Insert disk #' + StrUtil.NumStr(GDVars.virtualDisk);
  repeat
    ch := MenuCore.MenuHorizontal('', msg, LightMagenta, LightGreen, White, False, False, ext);
    saving := (not ext) and (ch = 'S');
    if saving then begin
      x := GDVars.gMapX;
      y := GDVars.gMapY;
      disk := GDVars.virtualDisk;
      Dec(GDVars.gMapX, GDConsts.dirDX[GDVars.gFacing]);
      Dec(GDVars.gMapY, GDConsts.dirDY[GDVars.gFacing]);
      View3D.WrapCoords(GDVars.gMapX, GDVars.gMapY);
      DaxIo.PopState;
      if SaveLoad.SaveGame then
        GameIo.ExitGame;
      { not saved: the party stands where it was, on the new disk, and chooses again over the redrawn view }
      GDVars.gMapX := x;
      GDVars.gMapY := y;
      GDVars.virtualDisk := disk;
      CharDisp.DisplayNoncombatInterface;
    end;
  until not saving;
end;

{ Free the combat record, every item, every effect node, then the record itself, forgetting its usual spells and
  statistics; the closing creature := nil clears only the local parameter. }
procedure FreeCreature(creature: Types.PCharRecord);
var
  holdE: Types.PEffectRec;
  effect: Types.PEffectRec;
begin
  with creature^ do begin
    if (combatAddr <> nil) then
      FreeMem(combatAddr, SizeOf(Types.TCombatRec));
    CharHlp.FreeItemList(itemsAddr);
    effect := effectsAddr;
    while effect <> nil do begin
      holdE := effect;
      effect := effect^.next;
      FreeMem(holdE, SizeOf(Types.TEffectRec));
    end;
  end;
  UsualSpl.ForgetUsualSpells(creature);
  Stats.Forget(creature);
  FreeMem(creature, SizeOf(Types.TCharRecord));
  creature := nil;
end;

{ Unlink curChar from the creature list and free it (and its icon animation if freeAnim); curChar becomes the next
  creature (head case) or the previous one (mid case), and the party size drops unless suppressSizeDec. A curChar not
  found in the list is left alone. When the creature removed was savedChar, savedChar follows the new curChar. }
procedure RemoveCreature(suppressSizeDec, freeAnim: Boolean);
var
  prev: Types.PCharRecord;
  removed: Types.PCharRecord;
begin
  if GDVars.creatureList = nil then Exit;
  removed := GDVars.curChar;
  prev := GDVars.creatureList;
  if prev <> GDVars.curChar then begin
    while (prev^.nextCharAddr <> GDVars.curChar) and (prev^.nextCharAddr <> nil) do
      prev := prev^.nextCharAddr;
    if prev^.nextCharAddr <> nil then begin
      if freeAnim then
        MapTiles.FreeIconAnim(GDVars.curChar^.orderNumber);
      prev^.nextCharAddr := GDVars.curChar^.nextCharAddr;
      SaveLoad.FreeCreature(GDVars.curChar);
      GDVars.curChar := prev;
      if not suppressSizeDec then
        Dec(GDVars.zone1^[C_Gbvm.PARTY_SIZE]);
    end;
  end else begin
    if freeAnim then
      MapTiles.FreeIconAnim(GDVars.curChar^.orderNumber);
    GDVars.creatureList := GDVars.curChar^.nextCharAddr;
    prev := GDVars.curChar^.nextCharAddr;
    SaveLoad.FreeCreature(GDVars.curChar);
    GDVars.curChar := prev;
    if not suppressSizeDec then
      Dec(GDVars.zone1^[C_Gbvm.PARTY_SIZE]);
  end;
  { the script engine makes savedChar current again: never the freed record (SSI left it there, as Curse's #609) }
  if (GDVars.curChar <> removed) and (GDVars.savedChar = removed) then
    GDVars.savedChar := GDVars.curChar;
end;

procedure FreeParty;
begin
  { RemoveCreature frees the head of the list while it is curChar }
  while GDVars.creatureList <> nil do begin
    GDVars.curChar := GDVars.creatureList;
    SaveLoad.RemoveCreature(False, True);
  end;
  GDVars.curChar := nil;
end;

end.

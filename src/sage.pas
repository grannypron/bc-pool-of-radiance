{ The sage in her room behind New Phlan's east tavern (#868): the Slums' fortune teller, whom a DataPat fix to New
  Phlan's script brings in with PROGRAM PROG_SAGE (EclVm.EclProgram) once the Slums are cleared, if the party let her
  live. For a fee by the creature's hit dice (MoneyCal.SageFee), paid as the temple's services are, she fills in what
  the party has not learned of a creature it has met: the facts the monster data gives its kind (BeastFil.Tell), from
  its record, found by the name the Bestiary keeps (FindRecord). }
{$O+,F+}
{$I COMPILER.INC}
unit Sage;

interface

{ The sage's counsel until Leave: Ask chooses a creature from the Bestiary's list (BeastMnu.PickBeast), the sage names
  her fee, and a paid fee fills in its entry, which is then shown. One whose record is not in the monster data she has
  heard nothing of, and one whose entry holds all she knows costs nothing and is marked told. The script has shown
  her portrait. }
procedure SageMenu;

implementation

uses Crt, Types, C_DATA, DiskRec, GameVars, DaxIo, DataArc, EclMenu, SaveLoad, Bestiary, BeastFil, BeastMnu, Money,
  MoneyCal, MenuCore, TextRend, CharDisp, StrUtil;

const
  { SageMenu's menu: its choices, as MenuHorizontalCS numbers them }
  MENU = '~Ask ~Leave';
  CHOICE_ASK = 0;
  CHOICE_LEAVE = 1;

{ True, with its id in id, when the DAX archive archive (in the game folder, without extension) holds a block, other
  than C_DATA's reserved ones, that is a creature record named wanted; the first such, in the archive's order. False
  when it has none, or cannot be read; no disk is asked for. }
function FindNamed(archive: Types.TStr20; var wanted: Types.TStr40; var id: Byte): Boolean;
var
  f1: file;
  f2: file;
  hdrSize: Word;
  e: DataArc.TDirEntry;
  n: Word;
  data: Types.PByteArr;
  found: Boolean;
  ended: Boolean;
  suppressed: Boolean;
  s: string[Types.NAME_LEN];
begin
  found := False;
  suppressed := GameVars.suppressingInsertDiskFlag;
  GameVars.suppressingInsertDiskFlag := True;
  if DaxIo.OpenDax(GameVars.gameDir + archive, '.DAX', hdrSize, f1, f2) then begin
    ended := False;
    while not found and not ended do begin
      BlockRead(f2, e, SizeOf(e), n);
      ended := (n < SizeOf(e)) or (FilePos(f2) >= hdrSize);
      if (n = SizeOf(e)) and (e.id < C_DATA.SOURCES_BLOCK) and (e.rawSize >= DiskRec.CHAR_DISK_BYTES) then begin
        DaxIo.ReadBlock(f1, hdrSize, e.offset, e.packedSize, e.rawSize, data);
        { the record's first field is its name, a string[NAME_LEN] }
        if Byte(data^[0]) <= Types.NAME_LEN then begin
          Move(data^[0], s, SizeOf(s));
          found := s = wanted;
        end;
        FreeMem(data, e.rawSize);
        if found then
          id := e.id;
      end;
    end;
    DaxIo.CloseDax(f1, f2);
  end;
  GameVars.suppressingInsertDiskFlag := suppressed;
  FindNamed := found;
end;

{ The disk and the id there of the first monster record named name: found in the merged MONCHA.DAX when the game reads
  that, so a name a data fix gave (DataPat) is found, and traced back to the per-disk archive and id whose load reads
  it (DaxIo.RemapId); otherwise found in MON1CHA.DAX to MON8CHA.DAX in turn. False when no record has the name. }
function FindRecord(var name: Types.TStr40; var disk, id: Byte): Boolean;
var
  m: Byte;
  found: Boolean;
begin
  found := False;
  disk := 1;
  if DaxIo.FamilyUsable(C_DATA.FAMILY_MONCHA) then begin
    if Sage.FindNamed(DataArc.MergedName(C_DATA.FAMILY_MONCHA), name, m) then
      { a disk whose block id the merged archive holds as block m }
      while not found and (disk <= Types.LAST_DISK) do begin
        id := 0;
        repeat
          found := (DaxIo.RemapId(C_DATA.FAMILY_MONCHA, disk, id) = m) and
                   DataArc.HasBlock(GameVars.gameDir + DataArc.SourceName(C_DATA.FAMILY_MONCHA, disk) + '.DAX', id);
          if not found then
            Inc(id);
        until found or (id = C_DATA.SOURCES_BLOCK);
        if not found then
          Inc(disk);
      end;
  end else
    while not found and (disk <= Types.LAST_DISK) do begin
      found := Sage.FindNamed(DataArc.SourceName(C_DATA.FAMILY_MONCHA, disk), name, id);
      if not found then
        Inc(disk);
    end;
  FindRecord := found;
end;

{ A creature of the kind b names, as LOAD MONSTER would make it (EclMenu.InitCreature), from its record on whichever
  disk has it; nil when the monster data has none. The caller frees it (SaveLoad.FreeCreature). }
function LoadKind(var b: Bestiary.TBeast): Types.PCharRecord;
var
  disk: Byte;
  id: Byte;
  saved: Byte;
  creature: Types.PCharRecord;
  items: Types.PItemRec;
  effects: Types.PEffectRec;
  name: Types.TStr40;
begin
  creature := nil;
  name := b.name;
  if Sage.FindRecord(name, disk, id) then begin
    saved := GameVars.virtualDisk;
    GameVars.virtualDisk := disk;
    EclMenu.InitCreature(id, creature, items, effects);
    GameVars.virtualDisk := saved;
  end;
  LoadKind := creature;
end;

{ The sage's words in the message window, as a script's PRINTCLEAR shows them. }
procedure Say(s: string);
begin
  CharDisp.MessageText(s, LightGreen, True);
end;

{ The screen again after a page of the Bestiary: the map's windows and the party, the sage's portrait in the view. }
procedure Redraw;
begin
  TextRend.ClearRect(0, 0, 39, 24);
  CharDisp.DisplayNoncombatInterface;
  EclMenu.DisplayPortrait(CharDisp.currentPortraitHead, CharDisp.currentPortraitHead2);
end;

{ The sage tells of b's kind, for a fee: the answer the menu is then shown under. }
function Consult(b: Bestiary.PBeast): string;
var
  creature: Types.PCharRecord;
  t: Bestiary.TBeast;
  fee: Word;
begin
  creature := Sage.LoadKind(b^);
  if creature = nil then
    Consult := '''' + b^.name + '? I HAVE HEARD OF NO SUCH THING.'''
  else begin
    t := b^;
    if not BeastFil.Tell(t, creature) then begin
      { nothing to sell, but the entry is now known to be whole }
      if t.known[0] <> b^.known[0] then begin
        b^ := t;
        Bestiary.dirty := True;
      end;
      Consult := '''' + b^.name + '? YOU KNOW AS MUCH OF THAT AS I DO, AND I TAKE NO FEE FOR IT.''';
    end else begin
      fee := MoneyCal.SageFee(creature^.levelHighest);
      Sage.Say('''' + b^.name + '? FOR ' + StrUtil.Count(fee, 'GOLD PIECE', 'GOLD PIECES') +
               ' I WILL TELL YOU ALL I KNOW.''');
      if MenuCore.YesNoMenu('pay the sage ', LightMagenta, White, LightGreen) <> 'Y' then
        Consult := '''AS YOU WISH.'''
      else if not Money.PayGold(GameVars.curChar, fee) then
        Consult := '''COME BACK WHEN YOU HAVE THE GOLD.'''
      else begin
        b^ := t;
        Bestiary.dirty := True;
        Sage.Say('THE OLD WOMAN OPENS A DUSTY TOME AND READS ALOUD. YOU NOTE ALL OF IT IN YOUR BESTIARY.');
        CharDisp.MessageWait;
        BeastMnu.ShowEntry(b^);
        Sage.Redraw;
        Consult := '''IS THERE ANOTHER BEAST YOU WOULD KNOW OF?''';
      end;
    end;
    SaveLoad.FreeCreature(creature);
  end;
end;

procedure SageMenu;
var
  answer: string;
  b: Bestiary.PBeast;
  choice: Byte;
begin
  answer := 'THE OLD FORTUNE TELLER FROM THE SLUMS LOOKS UP FROM HER BOOKS. ' +
            '''FOR A FEE I WILL TELL YOU ALL I KNOW OF ANY BEAST YOU HAVE MET.''';
  repeat
    Sage.Say(answer);
    choice := EclMenu.MenuHorizontalCS('', MENU, LightMagenta, LightGreen, White, True, False);
    if choice = CHOICE_ASK then begin
      b := BeastMnu.PickBeast('Ask about: ');
      Sage.Redraw;
      if b = nil then
        answer := '''IS THERE A BEAST YOU WOULD KNOW OF?'''
      else
        answer := Sage.Consult(b);
    end;
  until choice = CHOICE_LEAVE;
  CharDisp.ClearMessageWindow;
end;

end.

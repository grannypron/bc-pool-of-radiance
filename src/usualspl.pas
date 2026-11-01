{ The usual spells: the spells each character memorized when it last confirmed memorizing, kept for the party and
  saved in a .mem sidecar beside the character's files, and the memorize slots they are queued into. Overlaid; Camp
  and SaveLoad use it. }
{$O+,F+}
{$I COMPILER.INC}
unit UsualSpl;

interface

uses Types, FileUtil;

{ The character's usual spells: the spell IDs in its memorized and pending slots when it last confirmed memorizing,
  pending flags stripped. Return False when none are remembered for it. }
function GetUsualSpells(creature: Types.PCharRecord; var spells: Types.TMemorized): Boolean;

{ Remember spells as the character's usual spells. }
procedure SetUsualSpells(creature: Types.PCharRecord; var spells: Types.TMemorized);

{ Forget the character's usual spells; called before its record is freed or reused. }
procedure ForgetUsualSpells(creature: Types.PCharRecord);

{ Write the character's usual spells as file <base>.mem of save s (FileUtil.WriteToSet); for a character with none the
  save erases the old file instead. False when the write failed. }
function WriteUsualSpells(var s: FileUtil.TFileSet; creature: Types.PCharRecord; base: FileUtil.TSetName): Boolean;

{ Read the character's usual spells from <fn>.mem. The character is left with none unless the file is exactly one
  usual-spells record with this format's signature and version, made for a character of this name and randByte. }
procedure ReadUsualSpells(creature: Types.PCharRecord; fn: Types.TPathStr);

{ True when spells of class typ (C_SPELL.CLASS_CLERIC..SLOT_KIND_LAST) and level lvl have memorize slots
  (CharHlp.SpellSlots): levels 1..Types.CASTER_LEVEL_LAST of the cleric's, magic-user's and druid's. }
function HasSlotKind(lvl, typ: ShortInt): Boolean;

{ The creature's spell allowance for a class and level minus its memorized and pending spells of that class and level,
  or 0 when as many or more are memorized than allowed (e.g. after level drain), or for a class and level with no
  slots (HasSlotKind). An id outside the spell table counts for none. }
function SpellSlotsRemaining(creature: Types.PCharRecord; lvl, typ: ShortInt): Byte;

{ Put spell id, pending, in the creature's first empty memorized-spell slot; placed is False when every slot is
  taken. }
procedure PutPending(creature: Types.PCharRecord; id: Byte; var placed: Boolean);

{ Sort the creature's memorized spells by their masked IDs, keeping the pending flag attached to each spell. }
procedure SortMemorizedSpells(creature: Types.PCharRecord);

{ True when any of the creature's memorized-spell slots is pending (C_SPELL.PENDING_FLAG set). }
function HasPending(creature: Types.PCharRecord): Boolean;

{ Mark as pending each of the creature's usual spells that it lacks, still knows and has a free slot for, in turn, so
  later ones see the slots the earlier ones took; then sort its slots. A creature with no usual spells is left as it
  is. }
procedure QueueUsualSpells(creature: Types.PCharRecord);

implementation

uses GameVars, GameDefs, Party, CharHlp, C_SPELL;

const
  { the number of characters whose usual spells are kept at once: the party's size }
  USUAL_ENTRIES = Types.MAX_PARTY;
  { MEM_SIG and MEM_VERSION open every .mem file; a file without both is not read }
  MEM_SIG = 'USPL';
  MEM_VERSION = 2;
  { version 1's files hold the record's 21 slots alone, from before the slots past them (#1121) }
  MEM_VERSION_1 = 1;

type
  { A .mem file: the usual spells, with the name and randByte of the character they belong to. }
  TUsualSpellsFile = record
    sig: string[4];
    version: Byte;
    name: string[Types.NAME_LEN];
    randByte: Byte;
    spells: Types.TMemorized;
  end;

  { A version 1 .mem file. }
  TUsualSpellsFile1 = record
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
  usualSpells: array[1..USUAL_ENTRIES] of Types.TMemorized;

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

function GetUsualSpells(creature: Types.PCharRecord; var spells: Types.TMemorized): Boolean;
var
  i: Byte;
begin
  i := UsualSpl.FindUsualEntry(creature);
  if i > 0 then
    spells := usualSpells[i];
  GetUsualSpells := i > 0;
end;

procedure SetUsualSpells(creature: Types.PCharRecord; var spells: Types.TMemorized);
var
  i: Byte;
  j: Byte;
begin
  if creature = nil then Exit;
  UsualSpl.ForgetUsualSpells(creature);
  { a free entry, else one whose owner has left the party, else the first }
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

function WriteUsualSpells(var s: FileUtil.TFileSet; creature: Types.PCharRecord; base: FileUtil.TSetName): Boolean;
var
  rec: TUsualSpellsFile;
begin
  WriteUsualSpells := True;
  FillChar(rec, SizeOf(rec), 0);
  if UsualSpl.GetUsualSpells(creature, rec.spells) then begin
    rec.sig := MEM_SIG;
    rec.version := MEM_VERSION;
    rec.name := creature^.name;
    rec.randByte := creature^.randByte;
    WriteUsualSpells := FileUtil.WriteToSet(s, base + '.mem', rec, SizeOf(rec));
  end else
    FileUtil.AddToSet(s, base + '.mem', False);
end;

procedure ReadUsualSpells(creature: Types.PCharRecord; fn: Types.TPathStr);
var
  rec: TUsualSpellsFile;
  rec1: TUsualSpellsFile1;
begin
  UsualSpl.ForgetUsualSpells(creature);
  { read-only, so a write-protected .mem is read too }
  if FileUtil.ReadRecord(fn + '.mem', rec, SizeOf(rec)) then begin
    if (rec.sig = MEM_SIG) and (rec.version = MEM_VERSION) and (Length(rec.name) <= Types.NAME_LEN) and
        (rec.name = creature^.name) and (rec.randByte = creature^.randByte) then
      UsualSpl.SetUsualSpells(creature, rec.spells);
  end else if FileUtil.ReadRecord(fn + '.mem', rec1, SizeOf(rec1)) then
    if (rec1.sig = MEM_SIG) and (rec1.version = MEM_VERSION_1) and (Length(rec1.name) <= Types.NAME_LEN) and
        (rec1.name = creature^.name) and (rec1.randByte = creature^.randByte) then begin
      FillChar(rec.spells, SizeOf(rec.spells), 0);
      Move(rec1.spells, rec.spells, SizeOf(rec1.spells));
      UsualSpl.SetUsualSpells(creature, rec.spells);
    end;
end;

{ How many of the creature's memorized and pending spells are of this class and level; an id outside the spell table
  counts for none. }
function SlotsUsed(creature: Types.PCharRecord; lvl, typ: ShortInt): Byte;
var
  count: Byte;
  i: Byte;
  id: Byte;
begin
  count := 0;
  for i := 0 to Types.MEMORIZED_LAST do begin
    id := CharHlp.MemorizedAt(creature, i) and C_SPELL.ID_MASK;
    if CharHlp.IsSpell(id) then
      if (GameDefs.spellTable[id].levelSp = lvl) and (GameDefs.spellTable[id].castClassSp = typ) then
        Inc(count);
  end;
  SlotsUsed := count;
end;

function HasSlotKind(lvl, typ: ShortInt): Boolean;
begin
  HasSlotKind := (lvl >= 1) and (lvl <= Types.CASTER_LEVEL_LAST) and (typ >= C_SPELL.CLASS_CLERIC) and
                 (typ <= C_SPELL.SLOT_KIND_LAST);
end;

function SpellSlotsRemaining(creature: Types.PCharRecord; lvl, typ: ShortInt): Byte;
var
  count: Byte;
begin
  SpellSlotsRemaining := 0;
  if UsualSpl.HasSlotKind(lvl, typ) then begin
    count := UsualSpl.SlotsUsed(creature, lvl, typ);
    if count < CharHlp.SpellSlots(creature, typ, lvl) then
      SpellSlotsRemaining := CharHlp.SpellSlots(creature, typ, lvl) - count;
  end;
end;

procedure PutPending(creature: Types.PCharRecord; id: Byte; var placed: Boolean);
var
  i: Byte;
begin
  i := 0;
  while (i <= Types.MEMORIZED_LAST) and (CharHlp.MemorizedAt(creature, i) <> 0) do
    Inc(i);
  placed := i <= Types.MEMORIZED_LAST;
  if placed then
    CharHlp.SetMemorizedAt(creature, i, id + C_SPELL.PENDING_FLAG);
end;

procedure SortMemorizedSpells(creature: Types.PCharRecord);
var
  all: Types.TMemorized;
  i: Byte;
  j: Byte;
  tmp: Byte;
begin
  CharHlp.GetMemorized(creature, all);
  for i := 0 to Types.MEMORIZED_LAST - 1 do
    for j := i to Types.MEMORIZED_LAST do
      if (all[i] and C_SPELL.ID_MASK) > (all[j] and C_SPELL.ID_MASK) then begin
        tmp := all[i];
        all[i] := all[j];
        all[j] := tmp;
      end;
  CharHlp.PutMemorized(creature, all);
end;

function HasPending(creature: Types.PCharRecord): Boolean;
var
  i: Byte;
  pending: Boolean;
begin
  pending := False;
  for i := 0 to Types.MEMORIZED_LAST do
    if CharHlp.MemorizedAt(creature, i) > C_SPELL.ID_MASK then
      pending := True;
  HasPending := pending;
end;

procedure QueueUsualSpells(creature: Types.PCharRecord);
var
  usual: Types.TMemorized;
  have: Types.TMemorized;
  i: Byte;
  j: Byte;
  id: Byte;
  found: Boolean;
  placed: Boolean;
begin
  if UsualSpl.GetUsualSpells(creature, usual) then begin
    for i := 0 to Types.MEMORIZED_LAST do
      have[i] := CharHlp.MemorizedAt(creature, i) and C_SPELL.ID_MASK;
    for i := 0 to Types.MEMORIZED_LAST do begin
      id := usual[i];
      if CharHlp.IsSpell(id) then begin
        { a copy already memorized or pending covers this one }
        found := False;
        for j := 0 to Types.MEMORIZED_LAST do
          if (not found) and (have[j] = id) then begin
            have[j] := 0;
            found := True;
          end;
        if (not found) and CharHlp.KnowsSpell(creature, id) then
          if UsualSpl.SpellSlotsRemaining(creature, GameDefs.spellTable[id].levelSp,
                                          GameDefs.spellTable[id].castClassSp) > 0 then
            UsualSpl.PutPending(creature, id, placed);
      end;
    end;
    UsualSpl.SortMemorizedSpells(creature);
  end;
end;

begin
  FillChar(usualOwner, SizeOf(usualOwner), 0);
end.

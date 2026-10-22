{ The usual spells: the spells each character memorized when it last confirmed memorizing, kept for the party and
  saved in a .mem sidecar beside the character's files. Overlaid; Camp and SaveLoad use it. }
{$O+,F+}
{$I COMPILER.INC}
unit UsualSpl;

interface

uses Types, FileUtil;

{ The character's usual spells: the spell IDs in its memorized and pending slots when it last confirmed memorizing,
  pending flags stripped. Return False when none are remembered for it. }
function GetUsualSpells(creature: Types.PCharRecord; var spells: Types.TSpellSlots): Boolean;

{ Remember spells as the character's usual spells. }
procedure SetUsualSpells(creature: Types.PCharRecord; var spells: Types.TSpellSlots);

{ Forget the character's usual spells; called before its record is freed or reused. }
procedure ForgetUsualSpells(creature: Types.PCharRecord);

{ Write the character's usual spells as file <base>.mem of save s (FileUtil.WriteToSet); for a character with none the
  save erases the old file instead. False when the write failed. }
function WriteUsualSpells(var s: FileUtil.TFileSet; creature: Types.PCharRecord; base: FileUtil.TSetName): Boolean;

{ Read the character's usual spells from <fn>.mem. The character is left with none unless the file is exactly one
  usual-spells record with this format's signature and version, made for a character of this name and randByte. }
procedure ReadUsualSpells(creature: Types.PCharRecord; fn: Types.TPathStr);

implementation

uses GDVars, Party;

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
  i := UsualSpl.FindUsualEntry(creature);
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
begin
  UsualSpl.ForgetUsualSpells(creature);
  { read-only, so a write-protected .mem is read too }
  if FileUtil.ReadRecord(fn + '.mem', rec, SizeOf(rec)) then
    if (rec.sig = MEM_SIG) and (rec.version = MEM_VERSION) and (Length(rec.name) <= Types.NAME_LEN) and
        (rec.name = creature^.name) and (rec.randByte = creature^.randByte) then
      UsualSpl.SetUsualSpells(creature, rec.spells);
end;

begin
  FillChar(usualOwner, SizeOf(usualOwner), 0);
end.

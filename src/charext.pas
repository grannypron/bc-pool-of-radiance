{ Saves the fields added to Types.TCharExt: the classes left by a dual-classed
  human (#838) and the flags (EXT_*), which mark a creature that joined through
  Animate Dead (#1089). SSI's 285-byte character format has no room for these
  fields, so they are stored in a separate .chx file. They remain part of the
  in-memory record, allowing normal record copies to preserve them. }
{$O+,F+}
{$I COMPILER.INC}
unit CharExt;

interface

uses Types, FileUtil;

const
  { TCharExt.flags: a creature that joined the party when it was raised by Animate Dead on the party's side, not a
    character the party made or a script brought in; raised to life by the temple, it slips away at the next rest
    (#1089). Its record is a monster's, which SSI's format marks nowhere: the reserved bytes hold whatever the monster
    files put there, and the npc byte's bits are its morale. }
  EXT_ANIMATE_JOINED = $01;

{ True for a creature that joined through Animate Dead (EXT_ANIMATE_JOINED) and is alive again, raised by the temple:
  it slips away while the party sleeps at its next rest (#1089). }
function SlipsAway(creature: Types.PCharRecord): Boolean;

{ True when creature has a port field that is not 0, one a .chx file must hold. }
function HasExt(creature: Types.PCharRecord): Boolean;

{ Write creature's port fields as file <base>.chx of save s (FileUtil.WriteToSet); for a creature whose fields are all
  0 the save erases the old file instead. False when the write failed. }
function WriteExt(var s: FileUtil.TFileSet; creature: Types.PCharRecord; base: FileUtil.TSetName): Boolean;

{ Read creature's port fields from <fn>.chx. They are left 0 unless the file is exactly one record with this format's
  signature and version (or version 1's, from before the flags, whose class left is read), made for a character of
  this name and randByte: a character from SSI's game, from before #838, or whose .chx was lost, is an ordinary one. }
procedure ReadExt(creature: Types.PCharRecord; fn: Types.TPathStr);

implementation

uses C_STATUS;

const
  { EXT_SIG and EXT_VERSION open every .chx file; a file without both is not read }
  EXT_SIG = 'CEXT';
  EXT_VERSION = 2;
  { version 1's files hold the class left alone }
  EXT_VERSION_1 = 1;

type
  { A .chx file: the port fields, with the name and randByte of the character they belong to. }
  TCharExtFile = record
    sig: string[4];
    version: Byte;
    name: string[Types.NAME_LEN];
    randByte: Byte;
    portExt: Types.TCharExt;
  end;

  { A version 1 .chx file, from before TCharExt.flags. }
  TCharExtFile1 = record
    sig: string[4];
    version: Byte;
    name: string[Types.NAME_LEN];
    randByte: Byte;
    formerClasses: Byte;
  end;

function SlipsAway(creature: Types.PCharRecord): Boolean;
begin
  SlipsAway := (creature^.portExt.flags and EXT_ANIMATE_JOINED <> 0) and (creature^.status = C_STATUS.OKAY);
end;

function HasExt(creature: Types.PCharRecord): Boolean;
begin
  HasExt := (creature^.portExt.formerClasses <> 0) or (creature^.portExt.flags <> 0);
end;

function WriteExt(var s: FileUtil.TFileSet; creature: Types.PCharRecord; base: FileUtil.TSetName): Boolean;
var
  rec: TCharExtFile;
begin
  WriteExt := True;
  if CharExt.HasExt(creature) then begin
    FillChar(rec, SizeOf(rec), 0);
    rec.sig := EXT_SIG;
    rec.version := EXT_VERSION;
    rec.name := creature^.name;
    rec.randByte := creature^.randByte;
    rec.portExt := creature^.portExt;
    WriteExt := FileUtil.WriteToSet(s, base + '.chx', rec, SizeOf(rec));
  end else
    FileUtil.AddToSet(s, base + '.chx', False);
end;

procedure ReadExt(creature: Types.PCharRecord; fn: Types.TPathStr);
var
  rec: TCharExtFile;
  rec1: TCharExtFile1;
begin
  FillChar(creature^.portExt, SizeOf(creature^.portExt), 0);
  { read-only, so a write-protected .chx is read too }
  if FileUtil.ReadRecord(fn + '.chx', rec, SizeOf(rec)) then begin
    if (rec.sig = EXT_SIG) and (rec.version = EXT_VERSION) and (Length(rec.name) <= Types.NAME_LEN) and
        (rec.name = creature^.name) and (rec.randByte = creature^.randByte) then
      creature^.portExt := rec.portExt;
  end else if FileUtil.ReadRecord(fn + '.chx', rec1, SizeOf(rec1)) then
    if (rec1.sig = EXT_SIG) and (rec1.version = EXT_VERSION_1) and (Length(rec1.name) <= Types.NAME_LEN) and
        (rec1.name = creature^.name) and (rec1.randByte = creature^.randByte) then
      creature^.portExt.formerClasses := rec1.formerClasses;
end;

end.

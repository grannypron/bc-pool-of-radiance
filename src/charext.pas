{ Saves the fields added to Types.TCharExt, currently the classes left by a
  dual-classed human (#838). SSI's 285-byte character format has no room for
  these fields, so they are stored in a separate .chx file. They remain part of
  the in-memory record, allowing normal record copies to preserve them. }
{$O+,F+}
{$I COMPILER.INC}
unit CharExt;

interface

uses Types, FileUtil;

{ True when creature has a port field that is not 0, one a .chx file must hold. }
function HasExt(creature: Types.PCharRecord): Boolean;

{ Write creature's port fields as file <base>.chx of save s (FileUtil.WriteToSet); for a creature whose fields are all
  0 the save erases the old file instead. False when the write failed. }
function WriteExt(var s: FileUtil.TFileSet; creature: Types.PCharRecord; base: FileUtil.TSetName): Boolean;

{ Read creature's port fields from <fn>.chx. They are left 0 unless the file is exactly one record with this format's
  signature and version, made for a character of this name and randByte: a character from SSI's game, from before
  #838, or whose .chx was lost, is an ordinary one. }
procedure ReadExt(creature: Types.PCharRecord; fn: Types.TPathStr);

implementation

const
  { EXT_SIG and EXT_VERSION open every .chx file; a file without both is not read }
  EXT_SIG = 'CEXT';
  EXT_VERSION = 1;

type
  { A .chx file: the port fields, with the name and randByte of the character they belong to. }
  TCharExtFile = record
    sig: string[4];
    version: Byte;
    name: string[Types.NAME_LEN];
    randByte: Byte;
    portExt: Types.TCharExt;
  end;

function HasExt(creature: Types.PCharRecord): Boolean;
begin
  HasExt := creature^.portExt.formerClasses <> 0;
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
begin
  FillChar(creature^.portExt, SizeOf(creature^.portExt), 0);
  { read-only, so a write-protected .chx is read too }
  if FileUtil.ReadRecord(fn + '.chx', rec, SizeOf(rec)) then
    if (rec.sig = EXT_SIG) and (rec.version = EXT_VERSION) and (Length(rec.name) <= Types.NAME_LEN) and
        (rec.name = creature^.name) and (rec.randByte = creature^.randByte) then
      creature^.portExt := rec.portExt;
end;

end.

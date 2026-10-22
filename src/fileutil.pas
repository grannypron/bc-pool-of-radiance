{ Whole-file helpers for the game's own files (a saved game, a character's files, a save slot's description, the
  vault): erase one, open one read-only, read or write one record as the whole file, and write one safely, to a
  temporary copy put in its place only once it is whole, so a full disk or a failed write leaves the old file as it
  was. Resident and depending on nothing, so units with tests (Stats) can use it. I/O errors are caught, never
  raised. }
{$F+,I-}
{$I COMPILER.INC}
unit FileUtil;

interface

type
  { as long as a path gets (Types.TPathStr, which FileUtil does not use): 79 characters on DOS, a short string's most
    natively }
{$IFDEF FPC}
  TPathName = string[255];
{$ELSE}
  TPathName = string[79];
{$ENDIF}

{ True when base, a file name without its extension, in capitals, is a DOS device's (CON, AUX, NUL, PRN, COM1..COM4,
  LPT1..LPT3, CLOCK$): DOS opens the device for it, whatever the extension or directory, and makes no file. }
function IsDeviceName(base: TPathName): Boolean;

{ Erase file name; a missing file, or any other error, is ignored. }
procedure DeleteFile(name: TPathName);

{ Erase file name: True when there is no such file afterwards (a missing one included), False when it could not be
  erased (a read-only file). }
function DeleteChecked(name: TPathName): Boolean;

{ Open name for reading only, whatever FileMode is (a read-only file opens too), with record size 1. True when it
  opened; the caller closes it. }
function OpenReadOnly(var f: file; name: TPathName): Boolean;

{ Read file name into rec: True only when it is exactly size bytes and they read. The caller checks what they hold. }
function ReadRecord(name: TPathName; var rec; size: Word): Boolean;

{ Write rec's size bytes as file name, replacing it once they are all written (a temporary copy put in its place):
  True when they were. Else the old file is left as it was. }
function WriteRecord(name: TPathName; var rec; size: Word): Boolean;

{ name's temporary copy, written in its place until it is whole: name with its last character '$' (savgamA.dat's is
  savgamA.da$). Each of the game's files has a three-letter extension, so the copies of one character's files keep
  apart. }
function TempName(name: TPathName): TPathName;

{ Create name's temporary copy (TempName) for writing, record size 1: True when it opened. }
function RewriteTemp(var f: file; name: TPathName): Boolean;

{ Write size bytes of buf to f while ok holds; ok turns False when they are not all written (a full disk). }
procedure WriteChecked(var f: file; var buf; size: Word; var ok: Boolean);

{ Close f, name's temporary copy: True when ok and the close wrote the last of it. A copy that is not whole is
  erased. }
function CloseTemp(var f: file; name: TPathName; ok: Boolean): Boolean;

{ Put name's whole temporary copy in its place: erase name (a missing one is no error) and rename the copy to it. True
  when it did; else the copy is erased, and name is left as it was when it could not be erased (a read-only file). }
function PutInPlace(name: TPathName): Boolean;

implementation

{$IFDEF FPC}
uses NatFile;
{$ENDIF}

function IsDeviceName(base: TPathName): Boolean;
begin
  IsDeviceName := (base = 'CON') or (base = 'AUX') or (base = 'NUL') or (base = 'PRN') or (base = 'CLOCK$') or
                  ((Length(base) = 4) and (Copy(base, 1, 3) = 'COM') and (base[4] in ['1'..'4'])) or
                  ((Length(base) = 4) and (Copy(base, 1, 3) = 'LPT') and (base[4] in ['1'..'3']));
end;

procedure DeleteFile(name: TPathName);
var
  f: file;
  ioRes: Integer;
begin
  Assign(f, name);
  Erase(f);
  ioRes := IOResult;
end;

function DeleteChecked(name: TPathName): Boolean;
var
  f: file;
  ioRes: Integer;
begin
  DeleteChecked := True;
  if not FileUtil.OpenReadOnly(f, name) then Exit;
  Close(f);
  ioRes := IOResult;
  Erase(f);
  DeleteChecked := IOResult = 0;
end;

function OpenReadOnly(var f: file; name: TPathName): Boolean;
var
  mode: Byte;
begin
  Assign(f, name);
  mode := FileMode;
  FileMode := 0;
  Reset(f, 1);
  FileMode := mode;
  OpenReadOnly := IOResult = 0;
end;

function ReadRecord(name: TPathName; var rec; size: Word): Boolean;
var
  f: file;
  n: Word;
  ok: Boolean;
  ioRes: Integer;
begin
  ok := False;
  if FileUtil.OpenReadOnly(f, name) then begin
    ok := (FileSize(f) = size) and (IOResult = 0);
    if ok then begin
      BlockRead(f, rec, size, n);
      ok := (IOResult = 0) and (n = size);
    end;
    Close(f);
    ioRes := IOResult;
  end;
  ReadRecord := ok;
end;

function WriteRecord(name: TPathName; var rec; size: Word): Boolean;
var
  f: file;
  ok: Boolean;
begin
  ok := FileUtil.RewriteTemp(f, name);
  if ok then begin
    FileUtil.WriteChecked(f, rec, size, ok);
    ok := FileUtil.CloseTemp(f, name, ok) and FileUtil.PutInPlace(name);
  end;
  WriteRecord := ok;
end;

function TempName(name: TPathName): TPathName;
begin
  if Length(name) > 0 then
    name[Length(name)] := '$';
  TempName := name;
end;

function RewriteTemp(var f: file; name: TPathName): Boolean;
var
  ioRes: Integer;
begin
  { an error still pending would make the Rewrite do nothing }
  ioRes := IOResult;
  Assign(f, FileUtil.TempName(name));
  Rewrite(f, 1);
  RewriteTemp := IOResult = 0;
end;

procedure WriteChecked(var f: file; var buf; size: Word; var ok: Boolean);
var
  n: Word;
begin
  if not ok then Exit;
  BlockWrite(f, buf, size, n);
  ok := (IOResult = 0) and (n = size);
end;

function CloseTemp(var f: file; name: TPathName; ok: Boolean): Boolean;
begin
  Close(f);
  { the Close writes the last of the file }
  ok := (IOResult = 0) and ok;
  if not ok then
    FileUtil.DeleteFile(FileUtil.TempName(name));
  CloseTemp := ok;
end;

function PutInPlace(name: TPathName): Boolean;
var
  f: file;
  ioRes: Integer;
begin
  ioRes := IOResult;
  Assign(f, name);
  Erase(f);
  ioRes := IOResult;
  Assign(f, FileUtil.TempName(name));
  Rename(f, name);
  ioRes := IOResult;
  if ioRes <> 0 then
    FileUtil.DeleteFile(FileUtil.TempName(name));
  PutInPlace := ioRes = 0;
end;

end.

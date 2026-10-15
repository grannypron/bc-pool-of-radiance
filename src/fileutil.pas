{ Whole-file helpers for the game's own small files (a character's usual spells and statistics, a save slot's
  description, the vault): erase one, open one read-only, read or write one record as the whole file. Resident and
  depending on nothing, so units with tests (Stats) can use it. I/O errors are caught, never raised. }
{$F+,I-}
unit FileUtil;

interface

type
  { as long as a DOS path gets (Types.TPathStr) }
  TPathName = string[79];

{ Erase file name; a missing file, or any other error, is ignored. }
procedure DeleteFile(name: TPathName);

{ Open name for reading only, whatever FileMode is (a read-only file opens too), with record size 1. True when it
  opened; the caller closes it. }
function OpenReadOnly(var f: file; name: TPathName): Boolean;

{ Read file name into rec: True only when it is exactly size bytes and they read. The caller checks what they hold. }
function ReadRecord(name: TPathName; var rec; size: Word): Boolean;

{ Write rec's size bytes as file name, replacing it: True when they were written. }
function WriteRecord(name: TPathName; var rec; size: Word): Boolean;

implementation

procedure DeleteFile(name: TPathName);
var
  f: file;
  ioRes: Integer;
begin
  Assign(f, name);
  Erase(f);
  ioRes := IOResult;
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
  n: Word;
  ok: Boolean;
  ioRes: Integer;
begin
  ok := False;
  Assign(f, name);
  Rewrite(f, 1);
  if IOResult = 0 then begin
    BlockWrite(f, rec, size, n);
    ok := (IOResult = 0) and (n = size);
    Close(f);
    ok := ok and (IOResult = 0);
  end;
  ioRes := IOResult;
  WriteRecord := ok;
end;

end.

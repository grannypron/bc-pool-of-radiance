{ Whole-file helpers for the game's own files (a saved game, a character's files, a save slot's description, the
  vault): erase one, open one read-only, read one record as the whole file, and write one safely, to a temporary copy
  put in its place only once it is whole, so a full disk or a failed write leaves the old file as it was. A save's
  files go together as a set (TFileSet), put in place all or none. Resident and depending on nothing of the game's, so
  units with tests (Stats) can use it. I/O errors are caught, never raised. }
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

{ True when file name is there (it opens, read-only). }
function Exists(name: TPathName): Boolean;

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

const
  { the most files a set holds: a saved game's savgam .dat, .inf, .sts, .map and .nts, its vault copy, and five files
    for each of the 8 members }
  SET_FILES = 48;

type
  { a file of a set, without the set's folder: a DOS name, 8.3 }
  TSetName = string[12];
  { The files of one save, written together and put in place all or none (CommitSet): each either a new file, whose
    whole temporary copy (TempName) is written, or an old file the save no longer has, to be erased. }
  TFileSet = record
    { the folder the files are in, with its trailing backslash ('' for the current one) }
    dir: TPathName;
    count: Byte;
    names: array[1..SET_FILES] of TSetName;
    { the new file's copy is put in place; else the old file goes }
    put: array[1..SET_FILES] of Boolean;
    { a file was added past SET_FILES: the set is not committed }
    overflow: Boolean;
  end;

{ Start set s, empty, for the files in folder dir. }
procedure NewSet(var s: TFileSet; dir: TPathName);

{ Add file name (in s's folder) to s: put, its whole temporary copy, already written, goes in its place; else the old
  file, if there is one, is erased. Either is done only when s is committed. }
procedure AddToSet(var s: TFileSet; name: TSetName; put: Boolean);

{ Write rec's size bytes as the temporary copy of file name in s's folder, and add it to s: True when they were all
  written. Else no copy is left and s is as it was. }
function WriteToSet(var s: TFileSet; name: TSetName; var rec; size: Word): Boolean;

{ Give s up: every temporary copy it holds is erased, and the old files are left as they were. }
procedure DropSet(var s: TFileSet);

{ Put s in place, all or none: each old file of s is renamed to its backup (BackupName), the first file first, then
  each new copy renamed into place, the first file last, and only then are the backups erased. A rename that fails
  undoes it all: the new files in place are erased, the backups renamed back and the copies erased, so the old files are
  as they were. A backup left by a commit the game was ended in is erased first; one that cannot be fails the commit
  before anything is moved. With the main file first (a save's .dat), a commit ended part way leaves a slot without
  it, which no menu offers, rather than a mix of old and new files. True when the new files are in place (a backup that
  could not then be erased is erased by the next commit). }
function CommitSet(var s: TFileSet): Boolean;

{ name's backup while a set is committed: name with its last character '%' (savgamA.dat's is savgamA.da%). }
function BackupName(name: TPathName): TPathName;

implementation

uses Dos{$IFDEF FPC}, NatFile{$ENDIF};

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

function Exists(name: TPathName): Boolean;
var
  f: file;
  ioRes: Integer;
begin
  Exists := False;
  if FileUtil.OpenReadOnly(f, name) then begin
    Close(f);
    ioRes := IOResult;
    Exists := True;
  end;
end;

function DeleteChecked(name: TPathName): Boolean;
var
  f: file;
begin
  DeleteChecked := True;
  if not FileUtil.Exists(name) then Exit;
  Assign(f, name);
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

function BackupName(name: TPathName): TPathName;
begin
  if Length(name) > 0 then
    name[Length(name)] := '%';
  BackupName := name;
end;

procedure NewSet(var s: TFileSet; dir: TPathName);
begin
  s.dir := dir;
  s.count := 0;
  s.overflow := False;
end;

procedure AddToSet(var s: TFileSet; name: TSetName; put: Boolean);
begin
  if s.count >= SET_FILES then begin
    s.overflow := True;
    { a copy the set cannot hold is not left behind }
    if put then
      FileUtil.DeleteFile(FileUtil.TempName(s.dir + name));
    Exit;
  end;
  Inc(s.count);
  s.names[s.count] := name;
  s.put[s.count] := put;
end;

function WriteToSet(var s: TFileSet; name: TSetName; var rec; size: Word): Boolean;
var
  f: file;
  ok: Boolean;
begin
  ok := FileUtil.RewriteTemp(f, s.dir + name);
  if ok then begin
    FileUtil.WriteChecked(f, rec, size, ok);
    ok := FileUtil.CloseTemp(f, s.dir + name, ok);
  end;
  if ok then
    FileUtil.AddToSet(s, name, True);
  WriteToSet := ok;
end;

procedure DropSet(var s: TFileSet);
var
  i: Byte;
begin
  for i := 1 to s.count do
    if s.put[i] then
      FileUtil.DeleteFile(FileUtil.TempName(s.dir + s.names[i]));
  s.count := 0;
end;

{ Rename file from to name to: True when it was. }
function RenameChecked(from, name: TPathName): Boolean;
var
  f: file;
  ioRes: Integer;
begin
  ioRes := IOResult;
  Assign(f, from);
  Rename(f, name);
  RenameChecked := IOResult = 0;
end;

{ Erase name's backup, read-only or not (it is the game's own file): True when there is none afterwards. }
function EraseBackup(name: TPathName): Boolean;
var
  f: file;
  ioRes: Integer;
begin
  name := FileUtil.BackupName(name);
  if FileUtil.Exists(name) then begin
    Assign(f, name);
    SetFAttr(f, 0);
    ioRes := IOResult;
  end;
  EraseBackup := FileUtil.DeleteChecked(name);
end;

function CommitSet(var s: TFileSet): Boolean;
var
  i: Byte;
  ok: Boolean;
  { a backup's erase or rename back, which nothing more can be done about }
  done: Boolean;
  ioRes: Integer;
  { file i's old file was renamed to its backup; its new copy was renamed into place }
  moved: array[1..SET_FILES] of Boolean;
  placed: array[1..SET_FILES] of Boolean;
begin
  FillChar(moved, SizeOf(moved), 0);
  FillChar(placed, SizeOf(placed), 0);
  ok := not s.overflow;
  i := 0;
  while ok and (i < s.count) do begin
    Inc(i);
    ok := FileUtil.EraseBackup(s.dir + s.names[i]);
  end;
  { the old files aside, the first first }
  i := 0;
  while ok and (i < s.count) do begin
    Inc(i);
    if FileUtil.Exists(s.dir + s.names[i]) then begin
      ok := FileUtil.RenameChecked(s.dir + s.names[i], FileUtil.BackupName(s.dir + s.names[i]));
      moved[i] := ok;
    end;
  end;
  { the new files in, the first last }
  i := s.count + 1;
  while ok and (i > 1) do begin
    Dec(i);
    if s.put[i] then begin
      ok := FileUtil.RenameChecked(FileUtil.TempName(s.dir + s.names[i]), s.dir + s.names[i]);
      placed[i] := ok;
    end;
  end;
  for i := 1 to s.count do
    if ok then begin
      { in place: the old files go; a backup that cannot be erased now is erased by the next commit }
      if moved[i] then
        done := FileUtil.EraseBackup(s.dir + s.names[i]);
    end else begin
      { undone: the new files go and the old ones come back }
      if placed[i] then
        FileUtil.DeleteFile(s.dir + s.names[i]);
      if moved[i] then
        done := FileUtil.RenameChecked(FileUtil.BackupName(s.dir + s.names[i]), s.dir + s.names[i]);
    end;
  ioRes := IOResult;
  if not ok then
    FileUtil.DropSet(s);
  CommitSet := ok;
end;

end.

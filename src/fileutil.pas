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

{ Rename file from to name: True when it was. }
function RenameChecked(from, name: TPathName): Boolean;

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

{ Put s in place, all or none: each old file of s is renamed to its backup (BackupName), the first file first, and a
  new file that had no old one gets an empty backup as a mark of that (none of the game's files is empty); then each new
  copy is renamed into place, the first file last, and only then are the backups erased, the first file's first. A
  rename that fails undoes it all: the new files in place are erased, the backups renamed back and the copies erased,
  so the old files are as they were. A commit the game was ended in is settled first, as RecoverSet does: undone while
  the first file's backup is there, else finished (its backups erased); one that cannot be fails the commit before
  anything is moved. True when the new files are in place (a backup that could not then be erased goes with the next
  commit). }
function CommitSet(var s: TFileSet): Boolean;

{ Undo a commit of s's files the game was ended in (a power cut, a crash) before it was done: while the backup of s's
  first file is there, each backup is renamed back in place of its file (an empty one, the mark of a file that had none,
  erases the file) and every temporary copy of s's files is erased, so the old files are exactly as they were. A
  commit ended after the first file's backup was erased had put every new file in place; its other backups go with the
  next commit. Only s's names are used: whether each is put or erased does not matter. True when nothing is left to
  undo. }
function RecoverSet(var s: TFileSet): Boolean;

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

{ True when backup, a backup, is an empty file: the mark CommitSet leaves for a file that had no old one. }
function IsMark(backup: TPathName): Boolean;
var
  f: file;
  ioRes: Integer;
begin
  IsMark := False;
  if FileUtil.OpenReadOnly(f, backup) then begin
    IsMark := (FileSize(f) = 0) and (IOResult = 0);
    Close(f);
    ioRes := IOResult;
  end;
end;

{ Make name's backup the mark that name had no old file, an empty file: True when it was made. }
function MakeMark(name: TPathName): Boolean;
var
  f: file;
  ioRes: Integer;
begin
  ioRes := IOResult;
  Assign(f, FileUtil.BackupName(name));
  Rewrite(f, 1);
  ioRes := IOResult;
  if ioRes = 0 then begin
    Close(f);
    ioRes := IOResult;
  end;
  MakeMark := ioRes = 0;
end;

{ Settle the backups of s's files: back, each put back in place of its file (a mark erases the file), else each
  erased; with copies, every temporary copy of s's files is erased too. True when no backup is left. }
function Settle(var s: TFileSet; back, copies: Boolean): Boolean;
var
  i: Byte;
  ok: Boolean;
  name: TPathName;
begin
  ok := True;
  for i := 1 to s.count do begin
    name := s.dir + s.names[i];
    if FileUtil.Exists(FileUtil.BackupName(name)) then
      if not back then
        ok := FileUtil.EraseBackup(name) and ok
      else if FileUtil.IsMark(FileUtil.BackupName(name)) then
        ok := FileUtil.DeleteChecked(name) and FileUtil.EraseBackup(name) and ok
      else
        ok := FileUtil.DeleteChecked(name) and FileUtil.RenameChecked(FileUtil.BackupName(name), name) and ok;
    if copies then
      FileUtil.DeleteFile(FileUtil.TempName(name));
  end;
  Settle := ok;
end;

{ True when the backup of s's first file is there: a commit of s was ended before it was done. }
function Unfinished(var s: TFileSet): Boolean;
begin
  Unfinished := (s.count > 0) and FileUtil.Exists(FileUtil.BackupName(s.dir + s.names[1]));
end;

function RecoverSet(var s: TFileSet): Boolean;
begin
  RecoverSet := True;
  if FileUtil.Unfinished(s) then
    RecoverSet := FileUtil.Settle(s, True, True);
end;

function CommitSet(var s: TFileSet): Boolean;
var
  i: Byte;
  ok: Boolean;
  name: TPathName;
  { the backups' settling once the commit is done or undone, which nothing more can be done about }
  done: Boolean;
begin
  { a commit ended before: its temporary copies are this one's now }
  ok := not s.overflow and FileUtil.Settle(s, FileUtil.Unfinished(s), False);
  { the old files aside, the first first }
  i := 0;
  while ok and (i < s.count) do begin
    Inc(i);
    name := s.dir + s.names[i];
    if FileUtil.Exists(name) then
      ok := FileUtil.RenameChecked(name, FileUtil.BackupName(name))
    else if s.put[i] then
      ok := FileUtil.MakeMark(name);
  end;
  { the new files in, the first last }
  i := s.count + 1;
  while ok and (i > 1) do begin
    Dec(i);
    if s.put[i] then
      ok := FileUtil.RenameChecked(FileUtil.TempName(s.dir + s.names[i]), s.dir + s.names[i]);
  end;
  { in place: the backups go, the first file's first, so a commit ended from here on is finished, not undone; undone:
    the old files come back and the copies go }
  done := FileUtil.Settle(s, not ok, not ok);
  if not ok then
    s.count := 0;
  CommitSet := ok;
end;

end.

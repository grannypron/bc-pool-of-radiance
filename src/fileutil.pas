{ Provides whole-file operations for saves, characters, descriptions, and the
  vault. Writes go to a temporary file, in the TMP folder beside the original,
  and replace the original only after they finish successfully. TFileSet
  extends the same guarantee to a related group of files, replacing all of them
  or none. I/O errors are returned to callers rather than raised. }
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

{ True when file name is there: it opens read-only (OpenReadOnly, so a read-only file counts) and closes clean. An empty
  name is no file and is not opened: an unnamed file opens standard input (#962). A folder is no file, natively as
  under DOS (#1057). }
function Exists(name: TPathName): Boolean;

{ Erase file name; a missing file, or any other error, is ignored. }
procedure DeleteFile(name: TPathName);

{ Erase file name: True when there is no such file afterwards (a missing one included), False when it could not be
  erased (a read-only file). }
function DeleteChecked(name: TPathName): Boolean;

{ Make folder dir (with its trailing separator) and each folder above it that is not there yet, as a save's folder is
  made before the first save: True when dir is there afterwards (IOResult 5, a folder already there, counts). A drive's
  root (C:\, or / natively) is never made. Natively either separator divides it, so a per-user folder written with
  slashes is made too (#1067). }
function MakeFolder(dir: TPathName): Boolean;

{ Open name for reading only, whatever FileMode is (a read-only file opens too), with record size 1. True when it
  opened; the caller closes it. A folder does not open: DOS refuses it, and natively, where Linux would open it, it is
  refused first, by its native name, so that a backslash divides it there too (#1057). }
function OpenReadOnly(var f: file; name: TPathName): Boolean;

{ Read file name into rec: True only when it is exactly size bytes and they read. The caller checks what they hold. }
function ReadRecord(name: TPathName; var rec; size: Word): Boolean;

const
  { The folder, in a file's own folder, that its temporary copy is written in (TempName), and the one in that which
    holds its backup while a set is committed (BackupName). Each keeps the file's own name, so no two files' copies or
    backups share one (a dual-classed character's .cha and .chx did as .ch$, #1084), and a copy is renamed into place
    on its own drive. C_OPT.MAX_PATH_TEXT leaves room for the longer. }
  TEMP_FOLDER = 'TMP\';
  BACKUP_FOLDER = 'TMP\BAK\';

{ name's temporary copy, written in its place until it is whole: name in the TEMP_FOLDER of its own folder
  (SAVE\savgamA.dat's is SAVE\TMP\savgamA.dat). }
function TempName(name: TPathName): TPathName;

{ Make the folder name's temporary copy goes in (TEMP_FOLDER) when it is not there: True when it is there afterwards
  and name's backup (the longer name) fits a path. name's own folder must be there. RewriteTemp does this itself; a
  copy opened another way (a text file) comes after it. }
function MakeTempFolder(name: TPathName): Boolean;

{ Create name's temporary copy (TempName) for writing, record size 1, making its folder first (MakeTempFolder): True
  when it opened. }
function RewriteTemp(var f: file; name: TPathName): Boolean;

{ Write size bytes of buf to f while ok holds; ok turns False when they are not all written (a full disk). }
procedure WriteChecked(var f: file; var buf; size: Word; var ok: Boolean);

{ Close f, name's temporary copy: True when ok and the close wrote the last of it. A copy that is not whole is
  erased. }
function CloseTemp(var f: file; name: TPathName; ok: Boolean): Boolean;

{ Rename file from to name: True when it was. }
function RenameChecked(from, name: TPathName): Boolean;

{ Put name's whole temporary copy in its place, as a set of one file (CommitSet): the old file is renamed to its backup
  before the copy is renamed in, and put back if that fails, so a failure, or a game ended between the two
  (RecoverFile), never leaves name without its old file (#914). True when the copy is in place; else the copy is
  erased and name is as it was. A read-only name is left as it was and fails, as is a name whose file part is longer
  than a set's 8.3 names. }
function PutInPlace(name: TPathName): Boolean;

{ Undo a PutInPlace of name the game was ended in (RecoverSet on a set of one file), so a reader finds the old file:
  call it before reading a file PutInPlace writes. True when nothing is left to undo. }
function RecoverFile(name: TPathName): Boolean;

const
  { the most files a set holds: a saved game's savgam .dat, .inf, .sts, .map and .nts, its vault copy, and six files
    for each of the 8 members }
  SET_FILES = 54;

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

{ name's backup while a set is committed: name in the BACKUP_FOLDER of its own folder (SAVE\savgamA.dat's is
  SAVE\TMP\BAK\savgamA.dat). }
function BackupName(name: TPathName): TPathName;

implementation

uses Dos{$IFDEF FPC}, SysUtils, NatFile{$ENDIF};

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
  found: Boolean;
begin
  found := (name <> '') and FileUtil.OpenReadOnly(f, name);
  if found then begin
    Close(f);
    found := IOResult = 0;
  end;
  Exists := found;
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

{ True when c divides the folders of a path: a backslash, or natively also a slash. }
function IsSeparator(c: Char): Boolean;
begin
{$IFDEF FPC}
  IsSeparator := (c = '\') or (c = '/');
{$ELSE}
  IsSeparator := c = '\';
{$ENDIF}
end;

function MakeFolder(dir: TPathName): Boolean;
var
  ioRes: Integer;
  i: Byte;
  first: Byte;
begin
  ioRes := IOResult;
  if (Length(dir) > 0) and FileUtil.IsSeparator(dir[Length(dir)]) then
    Dec(dir[0]);
  { a drive's root, or the root itself, is there or cannot be made }
  first := 2;
  if (Length(dir) >= 2) and (dir[2] = ':') then
    first := 4;
  if Length(dir) < first then begin
    MakeFolder := True;
    Exit;
  end;
  { each parent first; its errors show again in the last MkDir }
  for i := first to Length(dir) - 1 do
    if FileUtil.IsSeparator(dir[i]) then begin
      MkDir(Copy(dir, 1, i - 1));
      ioRes := IOResult;
    end;
  MkDir(dir);
  ioRes := IOResult;
  MakeFolder := (ioRes = 0) or (ioRes = 5);
end;

function OpenReadOnly(var f: file; name: TPathName): Boolean;
var
  mode: Byte;
  ioRes: Integer;
begin
  { an error still pending would make the Reset do nothing, and a file that is there read as missing }
  ioRes := IOResult;
{$IFDEF FPC}
  if SysUtils.DirectoryExists(NatFile.NativeName(name)) then begin
    OpenReadOnly := False;
    Exit;
  end;
{$ENDIF}
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

{ The length of name's folder part, up to and with its last separator (0 for a name in the current folder). }
function FolderLength(name: TPathName): Byte;
var
  i: Byte;
begin
  i := Length(name);
  while (i > 0) and not (name[i] in ['\', '/', ':']) do
    Dec(i);
  FolderLength := i;
end;

{ name in folder sub of its own folder. }
function InFolder(name: TPathName; sub: TPathName): TPathName;
var
  i: Byte;
begin
  i := FileUtil.FolderLength(name);
  InFolder := Copy(name, 1, i) + sub + Copy(name, i + 1, Length(name) - i);
end;

{ True when name in BACKUP_FOLDER, the longer of its copy's and its backup's names, fits a path: a longer one would be
  cut short, and two files' names could meet (C_OPT.MAX_PATH_TEXT keeps POOL.CFG's paths within it). }
function Fits(name: TPathName): Boolean;
begin
  Fits := Length(name) + Length(BACKUP_FOLDER) < SizeOf(TPathName);
end;

{ Make folder dir (with its trailing backslash), whose parent is there, when it is not: True when it is there
  afterwards (IOResult 5, a folder already there, counts, as in MakeFolder). }
function MakeOne(dir: TPathName): Boolean;
var
  ioRes: Integer;
begin
  ioRes := IOResult;
  Dec(dir[0]);
  MkDir(dir);
  ioRes := IOResult;
  MakeOne := (ioRes = 0) or (ioRes = 5);
end;

{ The names a copy and a backup had until #1084: name with its last character '$', and '%'. A copy or backup an
  earlier version left there is still erased or put back (Settle, Unfinished); these can go a release or two on. }
function OldTempName(name: TPathName): TPathName;
begin
  if Length(name) > 0 then
    name[Length(name)] := '$';
  OldTempName := name;
end;

function OldBackupName(name: TPathName): TPathName;
begin
  if Length(name) > 0 then
    name[Length(name)] := '%';
  OldBackupName := name;
end;

function TempName(name: TPathName): TPathName;
begin
  TempName := FileUtil.InFolder(name, TEMP_FOLDER);
end;

function MakeTempFolder(name: TPathName): Boolean;
begin
  MakeTempFolder := FileUtil.Fits(name) and
                    FileUtil.MakeOne(Copy(name, 1, FileUtil.FolderLength(name)) + TEMP_FOLDER);
end;

function RewriteTemp(var f: file; name: TPathName): Boolean;
var
  ioRes: Integer;
begin
  RewriteTemp := False;
  if not FileUtil.MakeTempFolder(name) then Exit;
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

{ Make s the set of one file, name: True when name's file part fits a set's names. }
function SetOfOne(var s: TFileSet; name: TPathName): Boolean;
var
  i: Byte;
  fits: Boolean;
begin
  { the folder is name up to its last separator }
  i := FileUtil.FolderLength(name);
  FileUtil.NewSet(s, Copy(name, 1, i));
  fits := Length(name) - i < SizeOf(TSetName);
  if fits then
    FileUtil.AddToSet(s, Copy(name, i + 1, Length(name) - i), True);
  SetOfOne := fits;
end;

{ True when file name is there and read-only. }
function IsReadOnly(name: TPathName): Boolean;
var
  f: file;
  attr: Word;
  ioRes: Integer;
begin
  IsReadOnly := False;
  if not FileUtil.Exists(name) then Exit;
  Assign(f, name);
  GetFAttr(f, attr);
  ioRes := IOResult;
  IsReadOnly := (ioRes = 0) and (attr and ReadOnly <> 0);
end;

function PutInPlace(name: TPathName): Boolean;
var
  s: TFileSet;
  ok: Boolean;
begin
  ok := not FileUtil.IsReadOnly(name) and FileUtil.SetOfOne(s, name);
  if ok then
    { a failed commit erases the copy itself }
    ok := FileUtil.CommitSet(s)
  else
    FileUtil.DeleteFile(FileUtil.TempName(name));
  PutInPlace := ok;
end;

function RecoverFile(name: TPathName): Boolean;
var
  s: TFileSet;
begin
  RecoverFile := True;
  if FileUtil.SetOfOne(s, name) then
    RecoverFile := FileUtil.RecoverSet(s);
end;

function BackupName(name: TPathName): TPathName;
begin
  BackupName := FileUtil.InFolder(name, BACKUP_FOLDER);
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

{ Erase backup name, read-only or not (it is the game's own file): True when there is none afterwards. }
function EraseBackup(name: TPathName): Boolean;
var
  f: file;
  ioRes: Integer;
begin
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

{ Settle backup, file name's backup, if it is there: back, put back in place of name (a mark erases name), else
  erased. True when it is gone. }
function SettleOne(name, backup: TPathName; back: Boolean): Boolean;
begin
  if not FileUtil.Exists(backup) then
    SettleOne := True
  else if not back then
    SettleOne := FileUtil.EraseBackup(backup)
  else if FileUtil.IsMark(backup) then
    SettleOne := FileUtil.DeleteChecked(name) and FileUtil.EraseBackup(backup)
  else
    SettleOne := FileUtil.DeleteChecked(name) and FileUtil.RenameChecked(backup, name);
end;

{ Settle the backups of s's files: back, each put back in place of its file (a mark erases the file), else each
  erased; with copies, every temporary copy of s's files is erased too. A backup at the old name (OldBackupName) is
  settled the same way, and a copy at the old name, never this version's, is always erased. True when no backup is
  left. }
function Settle(var s: TFileSet; back, copies: Boolean): Boolean;
var
  i: Byte;
  ok: Boolean;
  name: TPathName;
begin
  ok := True;
  for i := 1 to s.count do begin
    name := s.dir + s.names[i];
    ok := FileUtil.SettleOne(name, FileUtil.OldBackupName(name), back) and ok;
    ok := FileUtil.SettleOne(name, FileUtil.BackupName(name), back) and ok;
    FileUtil.DeleteFile(FileUtil.OldTempName(name));
    if copies then
      FileUtil.DeleteFile(FileUtil.TempName(name));
  end;
  Settle := ok;
end;

{ True when the backup of s's first file is there, at its name or the old one: a commit of s was ended before it was
  done. }
function Unfinished(var s: TFileSet): Boolean;
begin
  Unfinished := (s.count > 0) and (FileUtil.Exists(FileUtil.BackupName(s.dir + s.names[1])) or
                                   FileUtil.Exists(FileUtil.OldBackupName(s.dir + s.names[1])));
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
  { the backups' folder, in the copies' }
  if ok and (s.count > 0) then
    ok := FileUtil.MakeOne(s.dir + TEMP_FOLDER) and FileUtil.MakeOne(s.dir + BACKUP_FOLDER);
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

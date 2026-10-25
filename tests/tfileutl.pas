{ Tests for FileUtil: a record written and read back, the size check, a read-only file, a file opened with an I/O error
  pending, erasing (DeleteChecked saying whether the file is gone), the temporary copy and backup names, the copy put in
  place only when whole, a set of files put in place all or none (CommitSet), a commit ended part way undone or
  finished (RecoverSet), one file put in place the same way (PutInPlace, RecoverFile, #914), and DOS device names. }
{$I COMPILER.INC}
program TFileUtl;

uses Dos, FileUtil, TestKit;

const
  NAME = 'TFU.TMP';
  TEMP = 'TFU.TM$';
  { a set's files }
  FA = 'TFUA.DAT';
  FB = 'TFUB.DAT';
  FC = 'TFUC.DAT';
  FD = 'TFUD.DAT';

type
  TRec = record
    a: Word;
    b: string[5];
  end;

var
  r: TRec;
  back: TRec;
  big: array[1..12] of Byte;
  f: file;
  ioRes: Integer;
  ok: Boolean;
  n: Word;
  s: FileUtil.TFileSet;

{ Write rec as file name, a set of its own: True when it is in place. }
function WriteOne(name: FileUtil.TSetName; var rec; size: Word): Boolean;
var
  one: FileUtil.TFileSet;
begin
  FileUtil.NewSet(one, '');
  WriteOne := FileUtil.WriteToSet(one, name, rec, size) and FileUtil.CommitSet(one);
end;

{ The number file name holds as a TRec, or -1 when it does not read. }
function NumberIn(name: FileUtil.TPathName): LongInt;
var
  got: TRec;
begin
  NumberIn := -1;
  if FileUtil.ReadRecord(name, got, SizeOf(got)) then
    NumberIn := got.a;
end;

{ Write r holding number a as file name, a set of its own. }
procedure WriteNumber(name: FileUtil.TSetName; a: Word);
begin
  r.a := a;
  TestKit.Check(WriteOne(name, r, SizeOf(r)), name + ' is written');
end;

{ True when no file of the set's is left over: no temporary copy and no backup. }
function NoneLeft: Boolean;
begin
  NoneLeft := not FileUtil.Exists(FileUtil.TempName(FA)) and not FileUtil.Exists(FileUtil.TempName(FB)) and
              not FileUtil.Exists(FileUtil.TempName(FC)) and not FileUtil.Exists(FileUtil.TempName(FD)) and
              not FileUtil.Exists(FileUtil.BackupName(FA)) and not FileUtil.Exists(FileUtil.BackupName(FB)) and
              not FileUtil.Exists(FileUtil.BackupName(FC)) and not FileUtil.Exists(FileUtil.BackupName(FD));
end;

{ Rename file from to name to, as a commit does. }
procedure MoveFile(from, name: FileUtil.TPathName);
var
  g: file;
  res: Integer;
begin
  Assign(g, from);
  Rename(g, name);
  res := IOResult;
end;

{ Write r holding number a as name's temporary copy: True when it is whole. }
function CopyNumber(name: FileUtil.TPathName; a: Word): Boolean;
var
  g: file;
  good: Boolean;
begin
  r.a := a;
  good := FileUtil.RewriteTemp(g, name);
  if good then begin
    FileUtil.WriteChecked(g, r, SizeOf(r), good);
    good := FileUtil.CloseTemp(g, name, good);
  end;
  CopyNumber := good;
end;

{ A, B, C and D's names, as a slot's reader knows them (each to erase: RecoverSet does not look). }
procedure NamesSet(var names: FileUtil.TFileSet);
begin
  FileUtil.NewSet(names, '');
  FileUtil.AddToSet(names, FA, False);
  FileUtil.AddToSet(names, FB, False);
  FileUtil.AddToSet(names, FC, False);
  FileUtil.AddToSet(names, FD, False);
end;

{ A set putting a new A, holding a, in place, and erasing B, C and D. }
procedure NewASet(var t: FileUtil.TFileSet; a: Word);
begin
  FileUtil.NewSet(t, '');
  r.a := a;
  TestKit.Check(FileUtil.WriteToSet(t, FA, r, SizeOf(r)), 'the new A''s copy writes');
  FileUtil.AddToSet(t, FB, False);
  FileUtil.AddToSet(t, FC, False);
  FileUtil.AddToSet(t, FD, False);
end;

{ The old files A 1, B 2 and C 3, D none, and a commit of A 11, B 12 and D 14, C erased, ended at stage: 1 A moved
  aside; 2 every old file moved aside, and D's mark made; 3 D put in place; 4 B too, all but A; 5 A too, and A's backup
  erased, the others' not yet. }
procedure Interrupt(stage: Byte);
var
  t: FileUtil.TFileSet;
  g: file;
  res: Integer;
begin
  FileUtil.DeleteFile(FD);
  WriteNumber(FA, 1);
  WriteNumber(FB, 2);
  WriteNumber(FC, 3);
  FileUtil.NewSet(t, '');
  r.a := 11;
  TestKit.Check(FileUtil.WriteToSet(t, FA, r, SizeOf(r)), 'A''s copy writes');
  r.a := 12;
  TestKit.Check(FileUtil.WriteToSet(t, FB, r, SizeOf(r)), 'B''s copy writes');
  r.a := 14;
  TestKit.Check(FileUtil.WriteToSet(t, FD, r, SizeOf(r)), 'D''s copy writes');
  MoveFile(FA, FileUtil.BackupName(FA));
  if stage >= 2 then begin
    MoveFile(FB, FileUtil.BackupName(FB));
    MoveFile(FC, FileUtil.BackupName(FC));
    Assign(g, FileUtil.BackupName(FD));
    Rewrite(g, 1);
    Close(g);
    res := IOResult;
  end;
  if stage >= 3 then
    MoveFile(FileUtil.TempName(FD), FD);
  if stage >= 4 then
    MoveFile(FileUtil.TempName(FB), FB);
  if stage >= 5 then begin
    MoveFile(FileUtil.TempName(FA), FA);
    FileUtil.DeleteFile(FileUtil.BackupName(FA));
  end;
end;

begin
  TestKit.Start('TFILEUTL');
  FileUtil.DeleteFile(NAME);
  TestKit.Check(not FileUtil.ReadRecord(NAME, back, SizeOf(back)), 'a missing file does not read');
  FileUtil.DeleteFile(NAME);
  TestKit.Check(IOResult = 0, 'erasing a missing file leaves no error behind');
  r.a := 1234;
  r.b := 'hello';
  TestKit.Check(WriteOne(NAME, r, SizeOf(r)), 'a record writes');
  FillChar(back, SizeOf(back), 0);
  TestKit.Check(FileUtil.ReadRecord(NAME, back, SizeOf(back)), 'and reads back');
  TestKit.CheckEqualsL(1234, back.a, 'the number came back');
  TestKit.CheckEqualsS('hello', back.b, 'the string came back');
  TestKit.Check(not FileUtil.ReadRecord(NAME, big, SizeOf(big)), 'a file of another size does not read');
  { read-only: OpenReadOnly and ReadRecord still open it }
  Assign(f, NAME);
  SetFAttr(f, ReadOnly);
  ioRes := IOResult;
  TestKit.Check(FileUtil.OpenReadOnly(f, NAME), 'a read-only file opens');
  Close(f);
  ioRes := IOResult;
  TestKit.Check(FileUtil.ReadRecord(NAME, back, SizeOf(back)), 'a read-only file reads');
  SetFAttr(f, 0);
  ioRes := IOResult;
  TestKit.Check(FileUtil.DeleteChecked(NAME), 'a file is erased');
  TestKit.Check(not FileUtil.OpenReadOnly(f, NAME), 'an erased file is gone');
  TestKit.Check(FileUtil.DeleteChecked(NAME), 'a missing file counts as erased');
  { the temporary copy }
  TestKit.CheckEqualsS(TEMP, FileUtil.TempName(NAME), 'the copy''s name ends in $');
  TestKit.Check(WriteOne(NAME, r, SizeOf(r)), 'a record writes again');
  TestKit.Check(not FileUtil.OpenReadOnly(f, TEMP), 'and leaves no copy behind');
  TestKit.CheckEqualsS('TFU.TM%', FileUtil.BackupName(NAME), 'the backup''s name ends in %');
  { an I/O error left pending (a missing file opened) does not make a file that is there read as missing }
{$I-}
  Assign(f, 'TFUZ.ZZZ');
  Reset(f, 1);
{$I+}
  TestKit.Check(FileUtil.Exists(NAME), 'a file is there with an error pending');
  TestKit.Check(not FileUtil.Exists(''), 'an empty name is no file, and standard input is not opened (#962)');
  { a copy not whole is dropped, and the old file stays }
  TestKit.Check(FileUtil.RewriteTemp(f, NAME), 'a copy opens');
  ok := True;
  FileUtil.WriteChecked(f, big, SizeOf(big), ok);
  TestKit.Check(ok, 'a write that is whole keeps ok');
  TestKit.Check(not FileUtil.CloseTemp(f, NAME, False), 'a copy that failed does not close whole');
  TestKit.Check(not FileUtil.OpenReadOnly(f, TEMP), 'and is erased');
  FillChar(back, SizeOf(back), 0);
  TestKit.Check(FileUtil.ReadRecord(NAME, back, SizeOf(back)), 'the old file is still there');
  TestKit.CheckEqualsL(1234, back.a, 'as it was');
  { WriteChecked writes nothing once ok is False }
  TestKit.Check(FileUtil.RewriteTemp(f, NAME), 'another copy opens');
  ok := False;
  FileUtil.WriteChecked(f, big, SizeOf(big), ok);
  TestKit.Check(not ok, 'ok stays False');
  n := FileSize(f);
  ioRes := IOResult;
  TestKit.CheckEqualsL(0, n, 'and nothing was written');
  TestKit.Check(FileUtil.CloseTemp(f, NAME, True), 'a copy closes whole');
  TestKit.Check(FileUtil.PutInPlace(NAME), 'and is put in place');
  TestKit.Check(not FileUtil.ReadRecord(NAME, back, SizeOf(back)), 'the file is the copy, empty');
  TestKit.Check(not FileUtil.OpenReadOnly(f, TEMP), 'and the copy is gone');
  FileUtil.DeleteFile(NAME);
  { a set: the old files A, B and C, D none }
  FileUtil.DeleteFile(FD);
  WriteNumber(FA, 1);
  WriteNumber(FB, 2);
  WriteNumber(FC, 3);
  TestKit.Check(NoneLeft, 'a set of one leaves no copy or backup');
  { all put in place: A and B new, C erased, D (none) erased too }
  FileUtil.NewSet(s, '');
  r.a := 11;
  TestKit.Check(FileUtil.WriteToSet(s, FA, r, SizeOf(r)), 'a set''s file writes');
  r.a := 12;
  TestKit.Check(FileUtil.WriteToSet(s, FB, r, SizeOf(r)), 'and another');
  FileUtil.AddToSet(s, FC, False);
  FileUtil.AddToSet(s, FD, False);
  TestKit.Check(FileUtil.Exists(FC), 'a file to erase is there until the set is put in place');
  TestKit.CheckEqualsL(1, NumberIn(FA), 'and so is the old file of a new one');
  TestKit.Check(FileUtil.CommitSet(s), 'the set is put in place');
  TestKit.CheckEqualsL(11, NumberIn(FA), 'the new A is in place');
  TestKit.CheckEqualsL(12, NumberIn(FB), 'the new B is in place');
  TestKit.Check(not FileUtil.Exists(FC), 'C is erased');
  TestKit.Check(not FileUtil.Exists(FD), 'and D, which was not there, is not');
  TestKit.Check(NoneLeft, 'no copy or backup is left');
  { a write that fails: the set is dropped, and the old files stay }
  WriteNumber(FC, 3);
  FileUtil.NewSet(s, '');
  r.a := 21;
  TestKit.Check(FileUtil.WriteToSet(s, FA, r, SizeOf(r)), 'a set''s first file writes');
  FileUtil.AddToSet(s, FC, False);
  TestKit.Check(FileUtil.RewriteTemp(f, FB), 'the next one''s copy opens');
  TestKit.Check(not FileUtil.CloseTemp(f, FB, False), 'and fails');
  FileUtil.DropSet(s);
  TestKit.CheckEqualsL(11, NumberIn(FA), 'A is as it was');
  TestKit.CheckEqualsL(12, NumberIn(FB), 'B is as it was');
  TestKit.CheckEqualsL(3, NumberIn(FC), 'C, to be erased, is still there');
  TestKit.Check(NoneLeft, 'the set''s copies are erased');
  FileUtil.NewSet(s, 'NODIR\');
  TestKit.Check(not FileUtil.WriteToSet(s, FA, r, SizeOf(r)), 'a write into a missing folder fails');
  TestKit.CheckEqualsL(0, s.count, 'and is not added');
  { a rename that fails part way: A's copy is missing, and A is put in place last, after B; it is all undone }
  FileUtil.NewSet(s, '');
  FileUtil.AddToSet(s, FA, True);
  r.a := 31;
  TestKit.Check(FileUtil.WriteToSet(s, FB, r, SizeOf(r)), 'B''s copy writes');
  FileUtil.AddToSet(s, FC, False);
  TestKit.Check(not FileUtil.CommitSet(s), 'a set whose rename fails is not put in place');
  TestKit.CheckEqualsL(11, NumberIn(FA), 'A is as it was');
  TestKit.CheckEqualsL(12, NumberIn(FB), 'B, put in place before A failed, is as it was again');
  TestKit.CheckEqualsL(3, NumberIn(FC), 'C, to be erased, is back');
  TestKit.Check(NoneLeft, 'no copy or backup is left');
  { a commit ended part way is undone before another starts }
  { A's backup, as a commit ended part way leaves it }
  Assign(f, FileUtil.BackupName(FA));
  Rewrite(f, 1);
  r.a := 99;
  BlockWrite(f, r, SizeOf(r));
  Close(f);
  ioRes := IOResult;
  FileUtil.NewSet(s, '');
  r.a := 41;
  ok := FileUtil.WriteToSet(s, FA, r, SizeOf(r));
  TestKit.Check(FileUtil.CommitSet(s), 'a set with an old backup about is put in place');
  TestKit.CheckEqualsL(41, NumberIn(FA), 'A is the new one');
  TestKit.Check(NoneLeft, 'and the old backup is gone');
  { a read-only file is moved aside and its backup erased all the same: it is the game's own file }
  Assign(f, FA);
  SetFAttr(f, ReadOnly);
  ioRes := IOResult;
  FileUtil.NewSet(s, '');
  r.a := 51;
  ok := FileUtil.WriteToSet(s, FA, r, SizeOf(r));
  TestKit.Check(FileUtil.CommitSet(s), 'a set replacing a read-only file is put in place');
  TestKit.CheckEqualsL(51, NumberIn(FA), 'A is the new one');
  TestKit.Check(NoneLeft, 'and the read-only backup is gone');
  Assign(f, FA);
  SetFAttr(f, 0);
  ioRes := IOResult;
  { a commit ended at each stage before A, the first file, was put in place: undone, the old files back }
  for n := 1 to 4 do begin
    Interrupt(n);
    NamesSet(s);
    TestKit.Check(FileUtil.RecoverSet(s), 'a commit ended at stage ' + Chr(Ord('0') + n) + ' is undone');
    TestKit.CheckEqualsL(1, NumberIn(FA), 'A is the old one');
    TestKit.CheckEqualsL(2, NumberIn(FB), 'B is the old one');
    TestKit.CheckEqualsL(3, NumberIn(FC), 'C, to be erased, is back');
    TestKit.Check(not FileUtil.Exists(FD), 'D, which had no old file, is gone');
    TestKit.Check(NoneLeft, 'no copy or backup is left');
  end;
  { ended once A was in place and its backup erased: the new files are whole, and stay }
  Interrupt(5);
  NamesSet(s);
  TestKit.Check(FileUtil.RecoverSet(s), 'a commit ended after A''s backup was erased needs no undoing');
  TestKit.CheckEqualsL(11, NumberIn(FA), 'A is the new one');
  TestKit.CheckEqualsL(12, NumberIn(FB), 'B is the new one');
  TestKit.Check(not FileUtil.Exists(FC), 'C is erased');
  TestKit.CheckEqualsL(14, NumberIn(FD), 'D is the new one');
  { the next commit erases its other backups }
  NewASet(s, 21);
  TestKit.Check(FileUtil.CommitSet(s), 'the next commit is put in place');
  TestKit.CheckEqualsL(21, NumberIn(FA), 'A is its');
  TestKit.Check(not FileUtil.Exists(FB) and not FileUtil.Exists(FD), 'B and D, erased by it, are gone');
  TestKit.Check(NoneLeft, 'and the old commit''s backups with them');
  { a commit ended before A was in place is undone by the next commit, which is then put in place }
  Interrupt(4);
  NewASet(s, 31);
  TestKit.Check(FileUtil.CommitSet(s), 'a commit after one ended part way is put in place');
  TestKit.CheckEqualsL(31, NumberIn(FA), 'A is its');
  TestKit.Check(not FileUtil.Exists(FB) and not FileUtil.Exists(FC) and not FileUtil.Exists(FD),
                'the files it erases are gone');
  TestKit.Check(NoneLeft, 'no backup is left');
  FileUtil.DeleteFile(FA);
  FileUtil.DeleteFile(FB);
  FileUtil.DeleteFile(FC);
  { one file put in place (#914): no old file, then an old one replaced, no backup left either way }
  TestKit.Check(CopyNumber(FA, 61) and FileUtil.PutInPlace(FA), 'a file with no old one is put in place');
  TestKit.CheckEqualsL(61, NumberIn(FA), 'A is the new one');
  TestKit.Check(NoneLeft, 'with no copy or backup left');
  TestKit.Check(CopyNumber(FA, 62) and FileUtil.PutInPlace(FA), 'an old file is replaced');
  TestKit.CheckEqualsL(62, NumberIn(FA), 'A is the new one');
  TestKit.Check(NoneLeft, 'and its backup is gone');
  { the old file cannot be moved aside: a folder holds its backup's name (DOS only: Linux opens a folder as a file, so
    FileUtil.Exists takes it for a backup left by an ended commit) }
{$IFNDEF FPC}
  MkDir(FileUtil.BackupName(FA));
  ioRes := IOResult;
  TestKit.Check(CopyNumber(FA, 63) and not FileUtil.PutInPlace(FA), 'an old file that cannot move aside fails');
  TestKit.CheckEqualsL(62, NumberIn(FA), 'and A is the old one');
  TestKit.Check(not FileUtil.Exists(FileUtil.TempName(FA)), 'the copy erased');
  RmDir(FileUtil.BackupName(FA));
  ioRes := IOResult;
{$ENDIF}
  { the copy cannot be renamed in: it is gone by then }
  TestKit.Check(CopyNumber(FA, 64), 'a copy is written');
  FileUtil.DeleteFile(FileUtil.TempName(FA));
  TestKit.Check(not FileUtil.PutInPlace(FA), 'a copy that cannot be renamed in fails');
  TestKit.CheckEqualsL(62, NumberIn(FA), 'and the old A is put back');
  TestKit.Check(NoneLeft, 'with no backup left');
  { a read-only file stays as it was (DOS only: Free Pascal's SetFAttr sets no attribute on Linux) }
{$IFNDEF FPC}
  Assign(f, FA);
  SetFAttr(f, ReadOnly);
  ioRes := IOResult;
  TestKit.Check(CopyNumber(FA, 65) and not FileUtil.PutInPlace(FA), 'a read-only file is not replaced');
  TestKit.CheckEqualsL(62, NumberIn(FA), 'A is the old one');
  TestKit.Check(NoneLeft, 'and the copy erased');
  Assign(f, FA);
  SetFAttr(f, 0);
  ioRes := IOResult;
{$ENDIF}
  { the game ended with the old file aside and the copy not yet in: RecoverFile puts the old one back }
  TestKit.Check(CopyNumber(FA, 66), 'a copy is written');
  MoveFile(FA, FileUtil.BackupName(FA));
  TestKit.Check(not FileUtil.Exists(FA), 'A is aside');
  TestKit.Check(FileUtil.RecoverFile(FA), 'an ended PutInPlace is undone');
  TestKit.CheckEqualsL(62, NumberIn(FA), 'A is the old one');
  TestKit.Check(NoneLeft, 'with no copy or backup left');
  TestKit.Check(FileUtil.RecoverFile(FA), 'and with nothing to undo, RecoverFile is no matter');
  TestKit.CheckEqualsL(62, NumberIn(FA), 'A stays');
  { the game ended after a file that had none was given its mark: RecoverFile leaves none }
  FileUtil.DeleteFile(FB);
  TestKit.Check(CopyNumber(FB, 67), 'a copy of B is written');
  Assign(f, FileUtil.BackupName(FB));
  Rewrite(f, 1);
  Close(f);
  ioRes := IOResult;
  TestKit.Check(FileUtil.RecoverFile(FB), 'an ended PutInPlace of a new file is undone');
  TestKit.Check(not FileUtil.Exists(FB), 'B is not there');
  TestKit.Check(NoneLeft, 'with no copy or mark left');
  FileUtil.DeleteFile(FA);
  { device names }
  TestKit.Check(FileUtil.IsDeviceName('CON'), 'CON is a device');
  TestKit.Check(FileUtil.IsDeviceName('NUL'), 'NUL is a device');
  TestKit.Check(FileUtil.IsDeviceName('COM4'), 'COM4 is a device');
  TestKit.Check(FileUtil.IsDeviceName('LPT1'), 'LPT1 is a device');
  TestKit.Check(not FileUtil.IsDeviceName('LPT4'), 'LPT4 is not');
  TestKit.Check(not FileUtil.IsDeviceName('CONAN'), 'CONAN is not');
  TestKit.Check(not FileUtil.IsDeviceName('CON_'), 'CON_ is not');
  TestKit.Check(not FileUtil.IsDeviceName('COM'), 'COM is not');
  TestKit.Done;
end.

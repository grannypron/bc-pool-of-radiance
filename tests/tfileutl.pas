{ Tests for FileUtil: a record written and read back, the size check, a read-only file, erasing (DeleteChecked
  saying whether the file is gone), the temporary copy put in place only when whole, a set of files put in place all or
  none (CommitSet), and DOS device names. }
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
              not FileUtil.Exists(FileUtil.TempName(FC)) and not FileUtil.Exists(FileUtil.BackupName(FA)) and
              not FileUtil.Exists(FileUtil.BackupName(FB)) and not FileUtil.Exists(FileUtil.BackupName(FC));
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
  { a backup left by a commit ended part way is erased first }
  WriteNumber(FileUtil.BackupName(FA), 99);
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
  { a backup that cannot be erased (a folder of its name) fails the set before anything is moved }
  MkDir(FileUtil.BackupName(FB));
  ioRes := IOResult;
  FileUtil.NewSet(s, '');
  r.a := 61;
  ok := FileUtil.WriteToSet(s, FA, r, SizeOf(r));
  r.a := 62;
  ok := FileUtil.WriteToSet(s, FB, r, SizeOf(r));
  TestKit.Check(not FileUtil.CommitSet(s), 'a set whose old backup cannot be erased is not put in place');
  TestKit.CheckEqualsL(51, NumberIn(FA), 'A is as it was');
  TestKit.CheckEqualsL(12, NumberIn(FB), 'B is as it was');
  RmDir(FileUtil.BackupName(FB));
  ioRes := IOResult;
  TestKit.Check(NoneLeft, 'and no copy is left');
  Assign(f, FA);
  SetFAttr(f, 0);
  ioRes := IOResult;
  FileUtil.DeleteFile(FA);
  FileUtil.DeleteFile(FB);
  FileUtil.DeleteFile(FC);
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

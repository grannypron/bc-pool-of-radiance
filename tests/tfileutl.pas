{ Tests for FileUtil: a record written and read back, the size check, a read-only file, erasing (DeleteChecked
  saying whether the file is gone), and the temporary copy put in place only when whole, and DOS device names. }
{$I COMPILER.INC}
program TFileUtl;

uses Dos, FileUtil, TestKit;

const
  NAME = 'TFU.TMP';
  TEMP = 'TFU.TM$';

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

begin
  TestKit.Start('TFILEUTL');
  FileUtil.DeleteFile(NAME);
  TestKit.Check(not FileUtil.ReadRecord(NAME, back, SizeOf(back)), 'a missing file does not read');
  FileUtil.DeleteFile(NAME);
  TestKit.Check(IOResult = 0, 'erasing a missing file leaves no error behind');
  r.a := 1234;
  r.b := 'hello';
  TestKit.Check(FileUtil.WriteRecord(NAME, r, SizeOf(r)), 'a record writes');
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
  TestKit.Check(FileUtil.WriteRecord(NAME, r, SizeOf(r)), 'a record writes again');
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

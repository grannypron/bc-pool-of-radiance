{ Tests for FileUtil: a record written and read back, the size check, a read-only file, and erasing. }
program TFileUtl;

uses Dos, FileUtil, TestKit;

const
  NAME = 'TFU.TMP';

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
  FileUtil.DeleteFile(NAME);
  TestKit.Check(not FileUtil.OpenReadOnly(f, NAME), 'an erased file is gone');
  TestKit.Done;
end.

{ Tests for DaxIo.ReadBlock's checks on a directory entry (#915): a block starting inside the file reads, one cut short
  by the file's end still reads (#122), and a negative offset or one at or past the end reads as no block. }
{$I COMPILER.INC}
program TDaxIo;

uses Types, DaxIo, TestKit;

const
  NAME = 'TDAXIO.DAX';
  { the bytes before the first block, as OpenDax counts them }
  HDR = 4;
  { the blocks' bytes after the header }
  BODY = 20;

var
  f: file;
  buf: array[1..HDR + BODY] of Byte;
  data: Types.PByteArr;
  i: Integer;
  ioRes: Integer;

{ True when ReadBlock reads the block at offset, packed size comp, into 16 bytes; what it read is freed. }
function Reads(offset: LongInt; comp: Word): Boolean;
begin
  Reads := DaxIo.ReadBlock(f, HDR, offset, comp, 16, data);
  if data <> nil then
    FreeMem(data, 16);
end;

begin
  TestKit.Start('TDAXIO');
  for i := 1 to SizeOf(buf) do
    buf[i] := 0;
  Assign(f, NAME);
  Rewrite(f, 1);
  BlockWrite(f, buf, SizeOf(buf));
  Close(f);
  Reset(f, 1);
  TestKit.Check(Reads(0, 8), 'a block inside the file reads');
  TestKit.Check(Reads(BODY - 1, 8), 'one starting at the last byte, cut short, reads too');
  TestKit.Check(not Reads(-1, 8), 'a negative offset is no block');
  TestKit.Check(data = nil, 'and leaves data nil');
  TestKit.Check(not Reads(BODY, 8), 'nor one at the file''s end');
  TestKit.Check(not Reads(BODY + 100, 8), 'nor one past it');
  TestKit.Check(not Reads($7FFFFFF0, 8), 'nor one whose offset would overflow the sum');
  Close(f);
  Erase(f);
  ioRes := IOResult;
  TestKit.Done;
end.

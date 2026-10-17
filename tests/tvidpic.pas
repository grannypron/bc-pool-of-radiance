{ Tests for the video drivers' picture routines in each mode (CGA, EGA, Tandy, VGA), without video hardware:
  installing a driver only fills GDVars.video. A one-cell-wide picture of two rows, colours 0..7 and then 7..0 with 0
  transparent, is converted from DAX's 4 bits a pixel (Blit.ExpandPicFrames) and its bytes and mask checked against
  the mode's layout; then the frame and mask sizes, a mirror (row 0 mirrored is row 1), a one-colour remap, a one-cell
  fill and the picture blitted through its mask. CGA's colour map takes colour c to CGA colour c mod 4. }
program TVidPic;

uses Types, GDConsts, GDVars, Blit, VidCga, VidEga, VidTdy, VidVga, TestKit;

const
  { the DAX frame: row 0 is colours 0..7, row 1 is 7..0, two pixels a byte, high nibble first }
  DAX: array[0..7] of Byte = ($01, $23, $45, $67, $76, $54, $32, $10);

var
  dax_: array[0..7] of Byte;

{ A copy of the test picture in the installed driver's layout: frames and mask from DAX, colour 0 transparent. }
function TestPic: Types.PImgBuf;
var
  pic: Types.PImgBuf;
  i: Byte;
begin
  Blit.AllocPic(2, 1, 1, 1, pic);
  for i := 0 to 7 do
    { colours 2i and 2i + 1 to CGA colours (2i) mod 4 and (2i + 1) mod 4 }
    pic^.map[i] := (((2 * i) mod 4) shl 4) or ((2 * i + 1) mod 4);
  Move(DAX, dax_, SizeOf(dax_));
  Blit.ExpandPicFrames(Types.PByteArr(@dax_), 0, True, 0, pic);
  TestPic := pic;
end;

{ Check pic's data and mask bytes against hex strings, two digits a byte; an empty mask string checks no mask. }
procedure CheckBytes(pic: Types.PImgBuf; data, mask: String; what: String);
const
  HEX: string[16] = '0123456789ABCDEF';
var
  i: Word;
  got: String;
begin
  got := '';
  for i := 0 to pic^.imgSize - 1 do
    got := got + HEX[pic^.data[i] shr 4 + 1] + HEX[pic^.data[i] and $F + 1];
  TestKit.CheckEqualsS(data, got, what + ': data');
  { a picture with no mask }
  if mask = '' then Exit;
  got := '';
  for i := 0 to Blit.MaskBytes(pic^.imgSize) - 1 do
    got := got + HEX[pic^.transp^[i] shr 4 + 1] + HEX[pic^.transp^[i] and $F + 1];
  TestKit.CheckEqualsS(mask, got, what + ': mask');
end;

{ The checks for the installed driver: name, then each expected layout. }
procedure CheckMode(name: String; frameBytes, maskBytes: Word; data, mask, mirrored, mirroredMask, remapped,
                    fill, tile: String);
var
  pic: Types.PImgBuf;
  mir: Types.PImgBuf;
  back: Types.PImgBuf;
  cell: Types.PImgBuf;
  fromT: Types.TColorTab;
  toT: Types.TColorTab;
  i: Byte;
  map: Types.TColorMap;
begin
  TestKit.CheckEqualsS(name, GDVars.video.name, name + ' is installed');
  TestKit.CheckEqualsL(frameBytes, Blit.FrameBytes(2, 1), name + ': a frame of 2 rows, 1 cell');
  TestKit.CheckEqualsL(maskBytes, Blit.MaskBytes(frameBytes), name + ': its mask');
  pic := TestPic;
  CheckBytes(pic, data, mask, name + ' conversion');
  { mirrored, row 0 becomes row 1's pixels and the other way round }
  Blit.AllocPic(2, 1, 1, 1, mir);
  Blit.MirrorPic(pic, mir);
  CheckBytes(mir, mirrored, mirroredMask, name + ' mirror');
  { mirrored twice is the picture again (into a second buffer: MirrorPic's source and destination must not overlap) }
  Blit.AllocPic(2, 1, 1, 1, back);
  Blit.MirrorPic(mir, back);
  CheckBytes(back, data, mask, name + ' mirrored twice');
  Blit.FreePic(back);
  Blit.FreePic(mir);
  { colour 5 becomes 12 }
  for i := 0 to 15 do begin
    fromT[i] := i;
    toT[i] := i;
  end;
  toT[5] := 12;
  Blit.RemapPic(fromT, toT, 0, False, pic);
  CheckBytes(pic, remapped, mask, name + ' remap 5 to 12');
  Blit.FreePic(pic);
  { a one-cell fill in colour 9 }
  Blit.AllocPic(1, 1, 1, 0, cell);
  for i := 0 to 7 do
    map[i] := (((2 * i) mod 4) shl 4) or ((2 * i + 1) mod 4);
  FillChar(GDVars.spanActive, SizeOf(GDVars.spanActive), 0);
  FillChar(GDVars.spanFirstOfs, SizeOf(GDVars.spanFirstOfs), $FF);
  FillChar(GDVars.spanLastOfs, SizeOf(GDVars.spanLastOfs), 0);
  Blit.FillPicRect(0, 0, 1, 1, 9, map, cell);
  CheckBytes(cell, fill, '', name + ' fill 9');
  Blit.FreePic(cell);
  { the picture blitted through its mask over colour 15: its transparent pixels keep the 15 }
  pic := TestPic;
  Blit.AllocPic(2, 1, 1, 0, cell);
  Blit.FillPicRect(0, 0, 1, 2, 15, map, cell);
  Blit.BlitTileCell(0, 0, 0, 1, pic, cell);
  CheckBytes(cell, tile, '', name + ' masked tile over 15');
  Blit.FreePic(cell);
  Blit.FreePic(pic);
end;

{ In the installed mode (VGA), a sheet of 128 frames of 24 x 24 pixels is more than one heap block holds: AllocPic keeps
  the frames that fit and puts the rest in a further block, and FrameCount, FrameBlock and BlitTileCell see one
  picture. }
procedure CheckSplitSheet;
var
  sheet: Types.PImgBuf;
  blk: Types.PImgBuf;
  dest: Types.PImgBuf;
  fit: Word;
  f: Word;
  i: Word;
  allFive: Boolean;
begin
  Blit.AllocPic(24, 3, 128, 0, sheet);
  fit := (65520 - (SizeOf(Types.TImgBuf) - SizeOf(sheet^.data))) div Blit.FrameBytes(24, 3);
  TestKit.CheckEqualsL(fit, sheet^.count, 'a 128-frame sheet keeps the frames that fit in its first block');
  TestKit.Check((sheet^.more <> nil) and (sheet^.more^.count = 128 - fit), 'and the rest in a second');
  TestKit.CheckEqualsL(128, Blit.FrameCount(sheet), 'FrameCount counts both');
  blk := sheet;
  f := 127;
  Blit.FrameBlock(blk, f);
  TestKit.Check((blk = sheet^.more) and (f = 127 - fit), 'frame 127 is in the second block');
  FillChar(blk^.data[f * blk^.imgSize], blk^.imgSize, 5);
  Blit.AllocPic(24, 3, 1, 0, dest);
  Blit.BlitTileCell(0, 0, 127, 0, sheet, dest);
  allFive := True;
  for i := 0 to dest^.imgSize - 1 do
    if dest^.data[i] <> 5 then
      allFive := False;
  TestKit.Check(allFive, 'BlitTileCell draws frame 127 from the second block');
  Blit.FreePic(dest);
  Blit.FreePic(sheet);
  TestKit.Check(sheet = nil, 'FreePic frees both blocks');
end;

begin
  TestKit.Start('TVIDPIC');
  { Tandy: the DAX bytes as they are; a mask nibble of F for each colour-0 pixel }
  VidTdy.Install;
  CheckMode('Tandy', 8, 8, '0123456776543210', 'F00000000000000F', '7654321001234567', '0000000FF0000000',
            '01234C6776C43210', '99999999', 'F12345677654321F');
  { EGA: four plane bytes a row (bit p of each pixel's colour in plane p, leftmost pixel in bit 7); one mask byte a
    row, a bit for each colour-0 pixel }
  VidEga.Install;
  CheckMode('EGA', 8, 2, '55330F00AACCF000', '8001', 'AACCF00055330F00', '0180', '51330F048ACCF020', 'FF0000FF',
            'D5B38F80ABCDF101');
  { CGA: four 2-bit pixels a byte, colour c drawn as c mod 4; a mask byte for each data byte, 2 bits a pixel }
  VidCga.Install;
  CheckMode('CGA', 4, 4, '1B1BE4E4', 'C0000003', 'E4E41B1B', '0003C000', '0B0BE0E0', '5555', 'DB1BE4E7');
  { VGA: a byte a pixel, a transparent pixel holding PIC_KEY ($FF); the mask kept a bit a pixel, a byte a cell row }
  VidVga.Install;
  CheckMode('VGA', 16, 2, 'FF0102030405060707060504030201FF', '8001', '07060504030201FFFF01020304050607', '0180',
            'FF010203040C060707060C04030201FF', '0909090909090909', '0F01020304050607070605040302010F');
  CheckSplitSheet;
  TestKit.Done;
end.

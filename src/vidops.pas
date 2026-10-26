{ Infrequent video operations used during startup, picture loading, icon
  building, and data-archive generation. These live in an overlay; the hot
  drawing primitives stay in Blit. Both use the driver in GameVars.video. }
{$O+,F+}
{$I COMPILER.INC}
unit VidOps;

interface

uses Types;

{ The video mode's name, for the settings screen. }
function ModeName: Types.TStr20;

{ Build the active video mode's per-row screen addresses (GameVars.bankRowSeg or fbRowOfs); GameInit2 calls it once
  the mode is set. }
procedure InitRowTables;

{ Merge src into dst as one sprite: dst's pixels OR src's (with a colour key, src's opaque pixels replace dst's), and
  dst's mask AND src's, so either picture's opaque pixels show. Over src's frame size, which may be fewer rows than
  dst's (a head over a body); nothing happens when either is nil, either has no mask, src is empty, or dst is not as
  wide or not as large (CanMerge). }
procedure MergePic(src, dst: Types.PImgBuf);

{ True when MergePic would merge src into dst: both there with masks, src not empty, as wide as dst and no larger. }
function CanMerge(src, dst: Types.PImgBuf): Boolean;

{ Draw src over dst through src's transparency mask: dst's pixels survive where src is transparent. Nothing happens
  when either is nil, src has no mask, the frame sizes differ, or dst is empty. }
procedure OverlayPic(src, dst: Types.PImgBuf);

{ Give every pixel of pic's first frame the colour toT gives its own. EGA, Tandy and VGA take one pass over the frame;
  CGA, whose pixels index the picture's colour map, goes through RemapPic. Nothing happens when pic is nil or empty. }
procedure RecolorPic(var toT: Types.TColorTab; pic: Types.PImgBuf);

{ Put 8 pixel colours (0..15), left to right, into scanline y of cell column 0 of frame frame of pic, in the video
  mode's layout. Pictures one cell wide only, as BldShow's cells are. }
procedure PutPixelRow(pic: Types.PImgBuf; frame, y: Byte; var px: Types.TPixelRow);

{ Builds the transparency mask for eight packed pixels. Bit 7 represents the
  first pixel and bit 0 the last. chunk stores two pixels per byte, high nibble
  first. }
function ComputeMask(transpColor: Byte; chunk: Types.TChunk): Byte;

{ Pixel k (0..7, left to right) of an 8-pixel chunk: the high nibble of chunk[k div 2] for an even k, the low for an
  odd one. }
function ChunkPixel(var chunk: Types.TChunk; k: Byte): Byte;

{ Converts packed 4-bit artwork to the active driver's pixel layout. pic must
  already be allocated. Each four-byte cell row is expanded by the driver, and
  a transparency mask is generated when the destination supports one.
  Transparent pixels are cleared (or changed to PIC_KEY for VGA) so masked
  drawing preserves the background. A nil destination is ignored. }
procedure ExpandPicFrames(imgData: Types.PByteArr; srcOff: Word; transpColor: Byte; pic: Types.PImgBuf);

{ Reverses a byte's bits to mirror eight EGA pixels or mask bits. }
function MirrorBits(value: Byte): Byte;

{ Reverses the eight packed 2-bit CGA pixels in a word. }
function MirrorPairs(value: Word): Word;

{ Swaps a byte's two 4-bit Tandy pixels. }
function MirrorNibbles(value: Byte): Byte;

{ Mirror src's first-frame mask into dst's, where a mask byte is a cell row (EGA's and VGA's): each row's bytes in
  reverse order, each byte's bits reversed. Nothing happens when src has no mask. }
procedure MirrorCellMask(src, dst: Types.PImgBuf);

implementation

uses GameDefs, GameVars, Blit;

function ModeName: Types.TStr20;
begin
  ModeName := GameVars.video.name;
end;

procedure InitRowTables;
begin
  GameVars.video.InitRowTables;
end;

procedure MergePic(src, dst: Types.PImgBuf);
var
  n: Word;
begin
  if not VidOps.CanMerge(src, dst) then Exit;
  if GameVars.video.keyed then begin
    { a colour key (VGA): src's opaque pixels replace dst's }
    for n := 0 to src^.imgSize - 1 do
      if src^.data[n] <> Types.PIC_KEY then
        dst^.data[n] := src^.data[n];
  end else
    for n := 0 to src^.imgSize - 1 do
      dst^.data[n] := dst^.data[n] or src^.data[n];
  for n := 0 to Blit.MaskBytes(src^.imgSize) - 1 do
    dst^.transp^[n] := dst^.transp^[n] and src^.transp^[n];
end;

function CanMerge(src, dst: Types.PImgBuf): Boolean;
begin
  CanMerge := False;
  if (src = nil) or (dst = nil) then Exit;
  if (src^.transp = nil) or (dst^.transp = nil) then Exit;
  { an empty picture would make MergePic's loops run 65536 times; src's rows are dst's first, so it is no wider and no
    larger }
  CanMerge := (src^.imgSize <> 0) and (src^.width = dst^.width) and (src^.imgSize <= dst^.imgSize);
end;

procedure OverlayPic(src, dst: Types.PImgBuf);
var
  n: Word;
begin
  if (src = nil) or (dst = nil) then Exit;
  if (src^.transp = nil) or (src^.imgSize <> dst^.imgSize) or (dst^.imgSize = 0) then Exit;
  if GameVars.video.keyed then begin
    { a colour key (VGA) }
    for n := 0 to dst^.imgSize - 1 do
      if src^.data[n] <> Types.PIC_KEY then
        dst^.data[n] := src^.data[n];
    Exit;
  end;
  { one mask byte covers 1 shl maskShift picture bytes (EGA's cell row of four planes) }
  for n := 0 to dst^.imgSize - 1 do
    dst^.data[n] := dst^.data[n] and src^.transp^[n shr GameVars.video.maskShift] or src^.data[n];
end;

procedure RecolorPic(var toT: Types.TColorTab; pic: Types.PImgBuf);
begin
  { an empty picture would make the drivers' loops run 65536 times }
  if (pic = nil) or (pic^.imgSize = 0) then Exit;
  GameVars.video.RecolorFrame(toT, pic);
end;

procedure PutPixelRow(pic: Types.PImgBuf; frame, y: Byte; var px: Types.TPixelRow);
begin
  if pic = nil then Exit;
  GameVars.video.PutPixelRow(pic, frame * pic^.imgSize, y, px);
end;

function ComputeMask(transpColor: Byte; chunk: Types.TChunk): Byte;
var
  mask: Byte;
  transpHigh: Byte;
  bit: Byte;
  i: Byte;
begin
  mask := 0;
  transpHigh := transpColor shl 4;
  bit := $80;
  for i := 0 to 3 do begin
    if (chunk[i] and $F0) = transpHigh then Inc(mask, bit);
    bit := bit shr 1;
    if (chunk[i] and $0F) = transpColor then Inc(mask, bit);
    bit := bit shr 1;
  end;
  ComputeMask := mask;
end;

function ChunkPixel(var chunk: Types.TChunk; k: Byte): Byte;
begin
  if Odd(k) then
    ChunkPixel := chunk[k shr 1] and $0F
  else
    ChunkPixel := chunk[k shr 1] shr 4;
end;

procedure ExpandPicFrames(imgData: Types.PByteArr; srcOff: Word; transpColor: Byte; pic: Types.PImgBuf);
var
  chunk: Types.TChunk;
  mask: Byte;
  at: Word;
  n: Word;
  chunks: Word;
begin
  { each block of the picture (pic^.more), its frames taking 4 DAX bytes a cell row and 1 shl cellShift picture bytes }
  while pic <> nil do begin
    chunks := (pic^.count * pic^.imgSize) shr GameVars.video.cellShift;
    at := 0;
    for n := 1 to chunks do begin
      Move(imgData^[srcOff], chunk, SizeOf(chunk));
      mask := 0;
      if pic^.transp <> nil then
        mask := VidOps.ComputeMask(transpColor, chunk);
      GameVars.video.ExpandChunk(chunk, mask, pic, at);
      Inc(at, 1 shl GameVars.video.cellShift);
      Inc(srcOff, SizeOf(chunk));
    end;
    pic := pic^.more;
  end;
end;

function MirrorBits(value: Byte): Byte;
var
  mirrored: Byte;
begin
  mirrored := value shl 7;
  Inc(mirrored, (value and 2) shl 5);
  Inc(mirrored, (value and 4) shl 3);
  Inc(mirrored, (value and 8) shl 1);
  Inc(mirrored, (value and $10) shr 1);
  Inc(mirrored, (value and $20) shr 3);
  Inc(mirrored, (value and $40) shr 5);
  Inc(mirrored, (value and $80) shr 7);
  MirrorBits := mirrored;
end;

function MirrorPairs(value: Word): Word;
var
  mirrored: Word;
begin
  mirrored := (value and GameDefs.cgaPixelMask[7]) shl 14;
  Inc(mirrored, (value and GameDefs.cgaPixelMask[6]) shl 10);
  Inc(mirrored, (value and GameDefs.cgaPixelMask[5]) shl 6);
  Inc(mirrored, (value and GameDefs.cgaPixelMask[4]) shl 2);
  Inc(mirrored, (value and GameDefs.cgaPixelMask[3]) shr 2);
  Inc(mirrored, (value and GameDefs.cgaPixelMask[2]) shr 6);
  Inc(mirrored, (value and GameDefs.cgaPixelMask[1]) shr 10);
  Inc(mirrored, (value and GameDefs.cgaPixelMask[0]) shr 14);
  MirrorPairs := mirrored;
end;

function MirrorNibbles(value: Byte): Byte;
var
  mirrored: Byte;
begin
  mirrored := value shl 4;
  Inc(mirrored, (value and $F0) shr 4);
  MirrorNibbles := mirrored;
end;

procedure MirrorCellMask(src, dst: Types.PImgBuf);
var
  row: Word;
  col: Word;
  maskOff: Word;
begin
  with src^ do
    if transp <> nil then begin
      maskOff := 0;
      for row := 1 to height do begin
        for col := 0 to width - 1 do
          dst^.transp^[maskOff + width - col - 1] := VidOps.MirrorBits(transp^[maskOff + col]);
        Inc(maskOff, width);
      end;
    end;
end;

end.

{ Image loading, conversion and compositing for CGA, EGA and Tandy displays. Drawing into the view buffer stages dirty
  spans; FlushView copies those spans to the screen. }

{ The renderer supports three video-memory layouts. CGA packs eight pixels into two bytes and interleaves even and odd
  scanlines between two banks. EGA stores eight pixels as four plane bytes, selected through the sequencer map mask;
  each row spans 40 bytes. Tandy packs eight pixels into four bytes across four scanline banks. Raw artwork always uses
  four bytes per eight-pixel chunk. }
{$O+,F+}
unit Blit;

interface

uses Types;

type
  { An 8-pixel chunk as stored in a picture: two pixels to a byte, the first in the high nibble. }
  TChunk = array[0..3] of Byte;

{ Returns the transparency mask of an 8-pixel chunk. A transpColor above 15 can match a high nibble but never a low one.
  @param(transpColor The colour that is transparent, 0..15.)
  @param(chunk The chunk's eight pixels, two to a byte, the first in the high nibble of chunk[0].)
  @returns(A bit set for each pixel equal to transpColor, bit 7 for the first pixel down to bit 0 for the last.) }
function ComputeMask(transpColor: Byte; chunk: TChunk): Byte;

{ Translates a logical color through a picture's color map into the device color used by the active video mode. The map
  packs two colors per byte: even colors use the high nibble, odd colors the low nibble. CGA consumers expect the result
  to fall in 0..3; neither that nor the input range is checked here.
  @param(color Logical color index, nominally 0..15.)
  @param(map Color map of the picture being drawn.)
  @returns(The mapped color, 0..15.) }
function SrcNibble(color: Byte; map: Types.TColorMap): Byte;

{ Switches the display to a BIOS video mode, remembering the mode it replaces so RestoreVideoMode can go back. The BIOS
  result is not checked, so an unsupported mode fails silently while the current-mode bookkeeping still records it.
  @param(mode BIOS INT 10h mode number to select.) }
procedure SetVideoMode(mode: Byte);

{ Returns the display to the mode saved by the last SetVideoMode call. That call also saves the mode being replaced, so
  calling this twice in a row toggles between two modes. }
procedure RestoreVideoMode;

{ Loads a picture from <name>.dax into a freshly allocated, display-ready image buffer, replacing any buffer already
  held in pic. If the file yields no data, pic is left nil. The raw data block is released once the image has been
  expanded.
  @param(name Base file name, without the .dax extension.)
  @param(fileId Identifier passed to the DAX loader to select the block within the file.)
  @param(hasMask True to build a transparency mask for the picture.)
  @param(transpColor Color index treated as transparent in that mask.)
  @param(pic Receives the new image buffer; any previous buffer is freed first.) }
procedure LoadPic(name: string; fileId: Byte; hasMask: Boolean; transpColor: Byte; var pic: Types.PImgBuf);

{ Converts raw packed 4-bit artwork into the pixel layout of the active video mode, filling an already-allocated image
  buffer and, when the buffer has one, its transparency mask. CGA produces two pixel bytes and a two-byte mask per
  eight-pixel cell; EGA produces four plane bytes and one mask byte; Tandy copies the pixels as-is and derives its mask
  in place. Transparent pixels are cleared in the pixel data so masked drawing can keep the background under them and OR
  the graphic in. Mask generation is decided by the buffer having a mask; hasMask is not read.
  @param(imgData Raw decompressed block holding the artwork.)
  @param(srcOff Offset within imgData of the first pixel byte, just past the picture header.)
  @param(hasMask Unused.)
  @param(transpColor Color index treated as transparent when building masks.)
  @param(pic Destination buffer, sized by AllocPic; nothing happens if nil.) }
procedure ExpandPicFrames(imgData: Types.PByteArr; srcOff: Word; hasMask: Boolean; transpColor: Byte;
                          pic: Types.PImgBuf);

{ Draws one frame of a graphic into a destination buffer at a character-cell position and marks the touched scanlines
  dirty so FlushView will push them to the screen. Each span records the first and inclusive last byte changed on its
  scanline. With transparency, the background is kept wherever the mask is set; otherwise rows are copied straight
  across. On EGA one mask byte covers all four plane bytes of a cell; CGA and Tandy masks match the pixel data byte for
  byte. The tile is not clipped, so the caller must keep it inside dest.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(tileIdx Frame within gfx to draw.)
  @param(flag Bit 0 requests transparent drawing; ignored when gfx has no mask.)
  @param(gfx Source graphic.)
  @param(dest Buffer drawn into, normally the view buffer.) }
procedure BlitTileCell(screenX, screenY: Integer; tileIdx, flag: Byte; gfx, dest: Types.PImgBuf);

{ Draws one frame of a graphic like BlitTileCell, but can clip it against the destination edges and can save the pixels
  it is about to cover. Clipping happens only when the clip flag is set; a tile that lies entirely outside the
  destination, or that has inconsistent geometry, is skipped. Saved pixels go to the save-under buffer at the clipped
  source position, independent of tileIdx, so the caller can restore the background later.
  @param(screenX Left edge, in character columns; may be negative when clipping is enabled.)
  @param(screenY Top edge, in character rows of eight scanlines; may be negative when clipping is enabled.)
  @param(tileIdx Frame within gfx to draw.)
  @param(flag Bit 0 requests transparent drawing (ignored when gfx has no mask); bit 2 saves the covered destination
    pixels first.)
  @param(gfx Source graphic; nothing is drawn if nil.)
  @param(dest Buffer drawn into; nothing is drawn if nil.) }
procedure BlitTileClipped(screenX, screenY: Integer; tileIdx, flag: Byte; gfx, dest: Types.PImgBuf);

{ Reverses the bit order of a byte, reflecting eight EGA pixels (one plane byte or mask byte) left to right.
  @param(value Byte to reflect.)
  @returns(The byte with bits 0..7 swapped with bits 7..0.) }
function MirrorBits(value: Byte): Byte;

{ Reverses the order of the eight 2-bit CGA pixels packed in a word, reflecting them left to right.
  @param(value Two CGA pixel bytes of one cell.)
  @returns(The word with its pixel order reversed.) }
function MirrorPairs(value: Word): Word;

{ Swaps the two 4-bit Tandy pixels of a byte, reflecting them left to right.
  @param(value Byte holding two pixels.)
  @returns(The byte with its nibbles exchanged.) }
function MirrorNibbles(value: Byte): Byte;

{ Produces a left-right reflected copy of the first frame of a graphic, including its color map and any transparency
  mask. The destination must already be large enough, must not overlap unread source data, and must have a mask if the
  source does. The source width must be nonzero.
  @param(src Graphic to reflect; nothing happens if nil.)
  @param(dst Buffer receiving the reflection; nothing happens if nil.) }
procedure MirrorPic(src, dst: Types.PImgBuf);

{ Draws the first frame of a picture straight to video memory at a character-cell position, bypassing the view buffer
  and its dirty-span staging. No clipping or transparency is applied. CGA and Tandy copy whole rows through the segment
  tables; EGA writes each of the four planes separately through the sequencer map mask.
  @param(screenX Left edge, in character columns.)
  @param(screenY Top edge, in character rows of eight scanlines.)
  @param(pic Picture to show; nothing happens if nil.) }
procedure ShowPic(screenX, screenY: Integer; pic: Types.PImgBuf);

{ Copies every dirty span of the view buffer to video memory, then resets the span tables so the next frame starts
  clean. On EGA each span is staged plane by plane in off-screen video memory and then copied to the visible page in a
  single latch-copy pass, so the visible memory is never left with only some planes updated. Spans use inclusive byte
  offsets; callers must supply valid bounds, and an EGA last offset of $FFFF would keep the plane loop from terminating.
  The graphics controller is returned to its normal write mode afterwards. }
procedure FlushView;

{ Recolors a picture by replacing pixels of each source color with the matching destination color. Every replacement is
  matched against the original pixels, not the partly remapped result, so remaps do not cascade (swapping two colors
  works). The work is done in a temporary image that is copied back at the end. Only one frame is remapped, unless frame
  is negative: then every frame of the picture is remapped, starting at frame zero.
  @param(fromColors Colors to replace, indexed by slot 0..15.)
  @param(toColors Replacement for the same slot; slots where both tables agree are skipped.)
  @param(frame Frame to remap; a negative value remaps every frame.)
  @param(isDithered True to recolor only a random subset of matching pixels, for a partial or blended effect.)
  @param(pic Picture modified in place; nothing happens if nil.) }
procedure RemapPic(fromColors, toColors: Types.TColorTab; frame: Integer; isDithered: Boolean; pic: Types.PImgBuf);

{ Allocates a zero-filled image buffer with room for a number of frames in the layout of the active video mode,
  optionally with a transparency mask. The mask is one quarter of the image size on EGA (one byte per four plane bytes)
  and the full size on CGA and Tandy.
  @param(height Frame height, in scanlines.)
  @param(width Frame width, in eight-pixel cells.)
  @param(count Number of frames.)
  @param(flag Bit 0 requests a transparency mask.)
  @param(pic Receives the new buffer.) }
procedure AllocPic(height, width: Word; count: Byte; flag: Byte; var pic: Types.PImgBuf);

{ Releases an image buffer and its transparency mask, if any, and sets the pointer to nil. The mask size is derived from
  the current video mode, so it must be freed in the mode it was allocated in. Does nothing if the pointer is already
  nil.
  @param(pic Buffer to free; nil on return.) }
procedure FreePic(var pic: Types.PImgBuf);

{ Fills a rectangle of a destination buffer with one solid color and marks the touched scanlines dirty for FlushView.
  The rectangle is clipped to the destination, so it may be partly off-screen; one wholly outside it fills nothing. CGA
  and Tandy use packed fill bytes; EGA fills four plane bytes per cell. SSI quirk, kept: with a negative y, one row
  more than the visible part is filled and the bottom edge is not checked (no caller passes a negative y).
  @param(x Left edge, in character columns; may be negative.)
  @param(y Top edge, in scanlines; may be negative.)
  @param(width Rectangle width, in eight-pixel cells.)
  @param(height Rectangle height, in scanlines.)
  @param(color Color to fill with, 0..15. CGA translates it through colorMap.)
  @param(colorMap Color map used to translate color on CGA.)
  @param(pic Buffer filled, normally the view buffer; nothing happens if nil.) }
procedure FillPicRect(x, y: Integer; width, height: Word; color: Byte; colorMap: Types.TColorMap; pic: Types.PImgBuf);

{ Gives palette register registerIndex the colour color, through the video driver: EGA's palette registers, VGA's
  DAC. Does nothing in a mode without a palette (HasPalette).
  @param(registerIndex Palette register to change.)
  @param(color Logical color to assign to that register, 0..15.) }
procedure SetPaletteRegister(registerIndex, color: Byte);

{ What the game asks of the video mode instead of naming it (phase 6, step 1). }

{ The bytes a picture frame height scanlines tall and width cells wide takes in the video mode: 2 a cell row on CGA
  (2 bits a pixel), 4 on EGA (four planes) and Tandy (4 bits a pixel). }
function FrameBytes(height, width: Word): Word;

{ The bytes of transparency mask for imageBytes bytes of picture: a quarter on EGA, where one mask byte covers a cell
  row's four plane bytes, and the same on CGA and Tandy, where the mask matches the data byte for byte. }
function MaskBytes(imageBytes: Word): Word;

{ The colours the video mode shows at once: 4 on CGA, which draws the 16 through each picture's colour map, and 16 on
  EGA and Tandy. }
function ColourCount: Byte;

{ True when the video mode has palette registers SetPaletteRegister can program (EGA). }
function HasPalette: Boolean;

{ Make pic's first frame wholly transparent: every pixel 0 (PIC_KEY in a keyed mode) and every mask bit set. }
procedure ClearPic(pic: Types.PImgBuf);

{ Step pic to the block holding frame, and frame to its index there: a picture too large for one heap block continues
  in pic^.more (AllocPic). }
procedure FrameBlock(var pic: Types.PImgBuf; var frame: Word);

{ The frames in pic, in all its blocks. }
function FrameCount(pic: Types.PImgBuf): Word;

implementation

uses GDConsts, GDVars, DaxIo, Dos, GameIo, StrUtil;
type
  PLongInt = ^LongInt;
  { The header of a DAX picture as stored; the pixel data follows it. }
  PDaxPicHeader = ^TDaxPicHeader;
  TDaxPicHeader = record
    height: Word;
    width: Word;
    originX: Word;
    originY: Word;
    count: Byte;
    map: Types.TColorMap;
  end;

function ComputeMask(transpColor: Byte; chunk: TChunk): Byte;
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

function SrcNibble(color: Byte; map: Types.TColorMap): Byte;
begin
  if Odd(color) then
    SrcNibble := map[color shr 1] and $0F
  else
    SrcNibble := (map[color shr 1] and $F0) shr 4;
end;

procedure SetVideoMode(mode: Byte);
begin
  GDVars.savedVideoMode := GDVars.curVideoMode;
  GDVars.dsInterruptRegisters.ah := 0;
  GDVars.dsInterruptRegisters.al := mode;
  Intr($10, GDVars.dsInterruptRegisters);
  GDVars.curVideoMode := mode;
end;

procedure RestoreVideoMode;
begin
  Blit.SetVideoMode(GDVars.savedVideoMode);
end;

procedure LoadPic(name: string; fileId: Byte; hasMask: Boolean; transpColor: Byte; var pic: Types.PImgBuf);
var
  picHeight: Word;
  picWidth: Word;
  picOriginX: Word;
  picOriginY: Word;
  picCount: Byte;
  colorMap: Types.TColorMap;
  dataSize: Word;
  readOfs: Word;
  data: Types.PByteArr;
begin
  if pic <> nil then Blit.FreePic(pic);
  DaxIo.LoadDax(name, '.dax', fileId, dataSize, data);
  if dataSize = 0 then Exit;
  Move(PDaxPicHeader(data)^.height, picHeight, SizeOf(picHeight));
  Move(PDaxPicHeader(data)^.width, picWidth, SizeOf(picWidth));
  Move(PDaxPicHeader(data)^.originX, picOriginX, SizeOf(picOriginX));
  Move(PDaxPicHeader(data)^.originY, picOriginY, SizeOf(picOriginY));
  Move(PDaxPicHeader(data)^.count, picCount, SizeOf(picCount));
  Move(PDaxPicHeader(data)^.map, colorMap, SizeOf(colorMap));
  Blit.AllocPic(picHeight, picWidth, picCount, Byte(hasMask), pic);
  with pic^ do begin
    originX := picOriginX;
    originY := picOriginY;
    map := colorMap;
  end;
  readOfs := SizeOf(TDaxPicHeader);
  Blit.ExpandPicFrames(data, readOfs, hasMask, transpColor, pic);
  FreeMem(data, dataSize);
end;

procedure ExpandPicFrames(imgData: Types.PByteArr; srcOff: Word; hasMask: Boolean; transpColor: Byte;
                          pic: Types.PImgBuf);
begin
  { each block of the picture (pic^.more), its frames taking 4 DAX bytes a cell row }
  while pic <> nil do begin
    GDVars.video.ExpandFrames(imgData, srcOff, hasMask, transpColor, pic);
    Inc(srcOff, pic^.count * pic^.height * pic^.width * 4);
    pic := pic^.more;
  end;
end;

{ BlitTileCell and BlitTileClipped: draw frame tileIdx of gfx into dest at (screenX, screenY), clipped against dest's
  edges when clip is set (BlitTileClipped's description), saving the covered pixels first when flag has bit 2. }
procedure BlitTile(screenX, screenY: Integer; tileIdx, flag: Byte; gfx, dest: Types.PImgBuf; clip: Boolean);
var
  { the driver's cellShift and maskShift, and what follows from them, read once a tile }
  cs: Byte;
  ms: Byte;
  planesPerMask: Byte;
  maskEach: Boolean;
  clipLeft: Word;
  clipRight: Word;
  leftSkip: Word;
  rightSkip: Word;
  maskClipLeft: Word;
  maskClipRight: Word;
  rowBytes: Word;
  srcOff: Word;
  destOff: Word;
  saveOff: Word;
  lastRow: Word;
  y: Word;
  maskOff: Word;
  planesLeft: Byte;
  scanline: Word;
  screenOff: Word;
  useMask: Boolean;
  saveRequested: Boolean;
  i: Word;
begin
  { a frame past the block's count is in a further block (AllocPic) }
  while (gfx <> nil) and (gfx^.more <> nil) and (tileIdx >= gfx^.count) do begin
    Dec(tileIdx, gfx^.count);
    gfx := gfx^.more;
  end;
  if (gfx = nil) or (dest = nil) then Exit;
  useMask := ((flag and 1) > 0) and (gfx^.transp <> nil);
  saveRequested := (flag and 4) > 0;
  if clip then begin
    if screenX < 0 then begin
      clipLeft := Abs(screenX);
      if clipLeft >= gfx^.width then Exit;
      leftSkip := 0;
    end else begin
      clipLeft := 0;
      leftSkip := screenX;
      if leftSkip >= dest^.width then Exit;
    end;
    if dest^.width < screenX + gfx^.width then begin
      clipRight := screenX + gfx^.width - dest^.width;
      if clipRight >= gfx^.width then Exit;
      rightSkip := 0;
    end else begin
      clipRight := 0;
      rightSkip := dest^.width - (screenX + gfx^.width);
      if rightSkip > dest^.width then Exit;
    end;
    if screenY < 0 then begin
      srcOff := Abs(screenY) * gfx^.width * 8;
      destOff := 0;
      scanline := 0;
      lastRow := gfx^.height - 1 - Abs(screenY) * 8;
      if (gfx^.imgSize - 1 < srcOff) or (gfx^.height - 1 < lastRow) then
        Exit;
    end else begin
      srcOff := 0;
      scanline := screenY * 8;
      destOff := scanline * dest^.width;
      lastRow := gfx^.height - 1;
      if dest^.height < screenY * 8 + gfx^.height then
        lastRow := dest^.height - 1 - screenY * 8
      else
        lastRow := gfx^.height - 1;
      if (gfx^.imgSize - 1 < srcOff) or (dest^.imgSize - 1 < destOff) or (gfx^.height - 1 < lastRow) then
        Exit;
    end;
  end else begin
    clipLeft := 0;
    clipRight := 0;
    srcOff := 0;
    scanline := screenY * 8;
    destOff := scanline * dest^.width;
    lastRow := gfx^.height - 1;
    leftSkip := screenX;
    rightSkip := dest^.width - (screenX + gfx^.width);
  end;
  { the driver's layout: 1 shl cellShift picture bytes a cell row, 1 shl screenShift screen bytes a cell column, one
    mask byte for 1 shl maskShift picture bytes }
  cs := GDVars.video.cellShift;
  ms := GDVars.video.maskShift;
  screenOff := leftSkip shl GDVars.video.screenShift;
  rowBytes := (gfx^.width - clipLeft - clipRight) shl cs;
  clipLeft := clipLeft shl cs;
  clipRight := clipRight shl cs;
  leftSkip := leftSkip shl cs;
  rightSkip := rightSkip shl cs;
  srcOff := srcOff shl cs;
  saveOff := srcOff;
  srcOff := tileIdx * gfx^.imgSize + srcOff;
  maskOff := srcOff shr ms;
  maskClipLeft := clipLeft shr ms;
  maskClipRight := clipRight shr ms;
  planesPerMask := 1 shl ms;
  planesLeft := planesPerMask;
  maskEach := useMask and (ms = 0);
  destOff := destOff shl cs;
  for y := 0 to lastRow do begin
    GDVars.spanActive[scanline] := 1;
    Inc(srcOff, clipLeft);
    Inc(saveOff, clipLeft);
    Inc(destOff, leftSkip);
    if GDVars.spanFirstOfs[scanline] > destOff then begin
      GDVars.spanScreenOfs[scanline] := screenOff;
      GDVars.spanFirstOfs[scanline] := destOff;
    end;
    if saveRequested then
      Move(dest^.data[destOff], GDVars.dsIconImageBufferPtr^.data[saveOff], rowBytes);
    Inc(saveOff, rowBytes);
    if useMask and GDVars.video.keyed then begin
      { a colour key (VGA): every pixel but PIC_KEY is drawn }
      for i := 1 to rowBytes do begin
        if gfx^.data[srcOff] <> Types.PIC_KEY then
          dest^.data[destOff] := gfx^.data[srcOff];
        Inc(srcOff);
        Inc(destOff);
      end;
    end else if maskEach then begin
      { a mask byte for each picture byte (CGA, Tandy) }
      for i := 1 to rowBytes do begin
        dest^.data[destOff] := dest^.data[destOff] and gfx^.transp^[srcOff] or gfx^.data[srcOff];
        Inc(srcOff);
        Inc(destOff);
      end;
    end else if useMask then begin
      { one mask byte for 1 shl maskShift picture bytes (EGA's planes), which keeps its own offset }
      Inc(maskOff, maskClipLeft);
      for i := 1 to rowBytes do begin
        dest^.data[destOff] := dest^.data[destOff] and gfx^.transp^[maskOff] or gfx^.data[srcOff];
        Inc(srcOff);
        Dec(planesLeft);
        if planesLeft = 0 then begin
          planesLeft := planesPerMask;
          Inc(maskOff);
        end;
        Inc(destOff);
      end;
      Inc(maskOff, maskClipRight);
    end else begin
      Move(gfx^.data[srcOff], dest^.data[destOff], rowBytes);
      Inc(srcOff, rowBytes);
      Inc(destOff, rowBytes);
    end;
    if destOff - 1 > GDVars.spanLastOfs[scanline] then
      GDVars.spanLastOfs[scanline] := destOff - 1;
    Inc(srcOff, clipRight);
    Inc(saveOff, clipRight);
    Inc(destOff, rightSkip);
    Inc(scanline);
  end;
end;

procedure BlitTileCell(screenX, screenY: Integer; tileIdx, flag: Byte; gfx, dest: Types.PImgBuf);
begin
  { no clipping and no save-under }
  Blit.BlitTile(screenX, screenY, tileIdx, flag and not 4, gfx, dest, False);
end;

procedure BlitTileClipped(screenX, screenY: Integer; tileIdx, flag: Byte; gfx, dest: Types.PImgBuf);
begin
  Blit.BlitTile(screenX, screenY, tileIdx, flag, gfx, dest, GDVars.clipFlag <> 0);
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
  mirrored := (value and GDConsts.cgaPixelMask[7]) shl 14;
  Inc(mirrored, (value and GDConsts.cgaPixelMask[6]) shl 10);
  Inc(mirrored, (value and GDConsts.cgaPixelMask[5]) shl 6);
  Inc(mirrored, (value and GDConsts.cgaPixelMask[4]) shl 2);
  Inc(mirrored, (value and GDConsts.cgaPixelMask[3]) shr 2);
  Inc(mirrored, (value and GDConsts.cgaPixelMask[2]) shr 6);
  Inc(mirrored, (value and GDConsts.cgaPixelMask[1]) shr 10);
  Inc(mirrored, (value and GDConsts.cgaPixelMask[0]) shr 14);
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

procedure MirrorPic(src, dst: Types.PImgBuf);
begin
  if (src = nil) or (dst = nil) then Exit;
  Move(src^.map, dst^.map, SizeOf(src^.map));
  GDVars.video.MirrorFrame(src, dst);
end;

procedure ShowPic(screenX, screenY: Integer; pic: Types.PImgBuf);
begin
  if pic = nil then Exit;
  GDVars.video.ShowPic(screenX, screenY, pic);
end;

procedure FlushView;
begin
  GDVars.video.FlushSpans;
  FillChar(GDVars.spanActive, SizeOf(GDVars.spanActive), 0);
  FillChar(GDVars.spanFirstOfs, SizeOf(GDVars.spanFirstOfs), $FF);
  FillChar(GDVars.spanLastOfs, SizeOf(GDVars.spanLastOfs), 0);
end;

procedure RemapPic(fromColors, toColors: Types.TColorTab; frame: Integer; isDithered: Boolean; pic: Types.PImgBuf);
var
  srcOff: Word;
  dstOff: Word;
  nFrames: Byte;
  pairIdx: Byte;
  scratchPic: Types.PImgBuf;
  allFrames: Boolean;
begin
  if pic = nil then Exit;
  allFrames := frame < 0;
  { a frame past the block's count is in a further block (AllocPic) }
  if not allFrames then
    while (pic^.more <> nil) and (frame >= pic^.count) do begin
      Dec(frame, pic^.count);
      pic := pic^.more;
    end;
  with pic^ do begin
    if frame < 0 then begin
      frame := 0;
      nFrames := count;
    end else
      nFrames := 1;
    srcOff := frame * imgSize;
  end;
  dstOff := 0;
  Blit.AllocPic(pic^.height, pic^.width, nFrames, 0, scratchPic);
  scratchPic^.map := pic^.map;
  Move(pic^.data[srcOff], scratchPic^.data[dstOff], scratchPic^.count * scratchPic^.imgSize);
  for pairIdx := 0 to 15 do begin
    srcOff := frame * pic^.imgSize;
    dstOff := 0;
    if fromColors[pairIdx] <> toColors[pairIdx] then
      GDVars.video.RemapColour(pic, scratchPic, srcOff, nFrames, fromColors[pairIdx], toColors[pairIdx], isDithered);
  end;
  with pic^ do
    Move(scratchPic^.data, data[frame * imgSize], nFrames * imgSize);
  Blit.FreePic(scratchPic);
  if allFrames and (pic^.more <> nil) then
    Blit.RemapPic(fromColors, toColors, -1, isDithered, pic^.more);
end;

procedure AllocPic(height, width: Word; count: Byte; flag: Byte; var pic: Types.PImgBuf);
var
  frameSize: Word;
  totalSize: Word;
  fit: LongInt;
  rest: Byte;
begin
  frameSize := Blit.FrameBytes(height, width);
  { A heap block holds at most 65,520 bytes: frames past what one holds go to a further block, pic^.more. A frame that
    alone is too large cannot be drawn in this mode. }
  fit := (65520 - (SizeOf(Types.TImgBuf) - SizeOf(pic^.data))) div frameSize;
  if fit = 0 then
    GameIo.FatalError('A picture of ' + StrUtil.NumStr(height) + ' rows and ' + StrUtil.NumStr(width) +
                      ' cells is too large for the ' + GDVars.video.name + ' video mode.');
  rest := 0;
  if count > fit then begin
    rest := count - fit;
    count := fit;
  end;
  totalSize := count * frameSize;
  GetMem(pic, totalSize + (SizeOf(Types.TImgBuf) - SizeOf(pic^.data)));
  FillChar(pic^, totalSize + (SizeOf(Types.TImgBuf) - SizeOf(pic^.data)), 0);
  pic^.height := height;
  pic^.width := width;
  pic^.imgSize := frameSize;
  pic^.count := count;
  if (flag and 1) > 0 then begin
    GetMem(pic^.transp, Blit.MaskBytes(totalSize));
    FillChar(pic^.transp^, Blit.MaskBytes(totalSize), 0);
  end;
  Inc(GDVars.picBytes, totalSize + (SizeOf(Types.TImgBuf) - SizeOf(pic^.data)));
  if (flag and 1) > 0 then
    Inc(GDVars.picBytes, Blit.MaskBytes(totalSize));
  if GDVars.picBytes > GDVars.picPeak then
    GDVars.picPeak := GDVars.picBytes;
  if rest > 0 then
    Blit.AllocPic(height, width, rest, flag, pic^.more);
end;

procedure FreePic(var pic: Types.PImgBuf);
var
  nBytes: Word;
begin
  if pic = nil then Exit;
  Blit.FreePic(pic^.more);
  with pic^ do begin
    nBytes := count * imgSize;
    if transp <> nil then begin
      FreeMem(transp, Blit.MaskBytes(nBytes));
      Dec(GDVars.picBytes, Blit.MaskBytes(nBytes));
    end;
  end;
  Dec(GDVars.picBytes, nBytes + (SizeOf(Types.TImgBuf) - SizeOf(pic^.data)));
  FreeMem(pic, nBytes + (SizeOf(Types.TImgBuf) - SizeOf(pic^.data)));
  pic := nil;
end;

procedure FillPicRect(x, y: Integer; width, height: Word; color: Byte; colorMap: Types.TColorMap; pic: Types.PImgBuf);
var
  clipLeft: Word;
  clipRight: Word;
  clampedX: Word;
  rightMargin: Word;
  runLen: Word;
  lastRow: Word;
  dstOff: Word;
  row: Word;
  absRow: Word;
  screenOfs: Word;
  i: Word;
  cell: Types.TCellBytes;
  cellLen: Byte;
  cells: Word;
  uniform: Boolean;
begin
  if pic = nil then Exit;
  if (x >= pic^.width) or (x + width <= 0) or (y >= pic^.height) or (y + height <= 0) then Exit;
  if x < 0 then begin
    clipLeft := Abs(x);
    clampedX := 0;
  end else begin
    clipLeft := 0;
    clampedX := x;
  end;
  if pic^.width < x + width then begin
    clipRight := x + width - pic^.width;
    rightMargin := 0;
  end else begin
    clipRight := 0;
    rightMargin := pic^.width - (x + width);
  end;
  if y < 0 then begin
    dstOff := 0;
    absRow := 0;
    lastRow := height - Abs(y);
  end else begin
    absRow := y;
    dstOff := absRow * pic^.width;
    lastRow := height - 1;
    if pic^.height < y + height then
      lastRow := pic^.height - 1 - y
    else
      lastRow := height - 1;
  end;
  { the driver's layout: 1 shl cellShift picture bytes a cell row, 1 shl screenShift screen bytes a cell column }
  with GDVars.video do begin
    screenOfs := clampedX shl screenShift;
    cells := width - clipLeft - clipRight;
    runLen := cells shl cellShift;
    clampedX := clampedX shl cellShift;
    rightMargin := rightMargin shl cellShift;
    dstOff := dstOff shl cellShift;
    CellFill(color, colorMap, cell);
    cellLen := 1 shl cellShift;
    { a cell row of one byte repeated (always on CGA and Tandy, and EGA's black and white) fills as a run }
    uniform := True;
    for i := 1 to cellLen - 1 do
      if cell[i] <> cell[0] then
        uniform := False;
  end;
  for row := 0 to lastRow do begin
    GDVars.spanActive[absRow] := 1;
    Inc(dstOff, clampedX);
    if GDVars.spanFirstOfs[absRow] > dstOff then begin
      GDVars.spanScreenOfs[absRow] := screenOfs;
      GDVars.spanFirstOfs[absRow] := dstOff;
    end;
    if uniform then begin
      FillChar(pic^.data[dstOff], runLen, cell[0]);
      Inc(dstOff, runLen);
    end else if cellLen = 4 then
      { four bytes a cell (EGA's planes): one LongInt store each }
      for i := 1 to cells do begin
        PLongInt(@pic^.data[dstOff])^ := PLongInt(@cell)^;
        Inc(dstOff, 4);
      end
    else
      for i := 1 to cells do begin
        Move(cell, pic^.data[dstOff], cellLen);
        Inc(dstOff, cellLen);
      end;
    if dstOff - 1 > GDVars.spanLastOfs[absRow] then
      GDVars.spanLastOfs[absRow] := dstOff - 1;
    Inc(dstOff, rightMargin);
    Inc(absRow);
  end;
end;

procedure SetPaletteRegister(registerIndex, color: Byte);
begin
  if Blit.HasPalette then
    GDVars.video.SetPalette(registerIndex, color);
end;

procedure FrameBlock(var pic: Types.PImgBuf; var frame: Word);
begin
  while (pic <> nil) and (pic^.more <> nil) and (frame >= pic^.count) do begin
    Dec(frame, pic^.count);
    pic := pic^.more;
  end;
end;

function FrameCount(pic: Types.PImgBuf): Word;
var
  n: Word;
begin
  n := 0;
  while pic <> nil do begin
    Inc(n, pic^.count);
    pic := pic^.more;
  end;
  FrameCount := n;
end;

procedure ClearPic(pic: Types.PImgBuf);
var
  clear: Byte;
begin
  if pic = nil then Exit;
  if GDVars.video.keyed then
    clear := Types.PIC_KEY
  else
    clear := 0;
  FillChar(pic^.data, pic^.imgSize, clear);
  if pic^.transp <> nil then
    FillChar(pic^.transp^, Blit.MaskBytes(pic^.imgSize), $FF);
end;

function FrameBytes(height, width: Word): Word;
begin
  FrameBytes := (height * width) shl GDVars.video.cellShift;
end;

function MaskBytes(imageBytes: Word): Word;
begin
  MaskBytes := imageBytes shr GDVars.video.maskShift;
end;

function ColourCount: Byte;
begin
  ColourCount := GDVars.video.colours;
end;

function HasPalette: Boolean;
begin
  HasPalette := GDVars.video.hasPalette;
end;

end.

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

{ Programs one EGA palette register through BIOS INT 10h. Bright colors (8..15) are offset by a further 8 to reach their
  palette values.
  @param(registerIndex Palette register to change.)
  @param(color Logical color to assign to that register, 0..15.) }
procedure SetPaletteRegister(registerIndex, color: Byte);

implementation


uses C_Video, C_Ega, GDConsts, GDVars, DaxIo, Dos;
const
  { write-mode 1: CPU write stores the 4 latched planes (a 4-plane block copy through the latches) }
  GC_WRITE_MODE_1 = 1;

  { off-screen planar staging area (0x200 para = 8 KB up) }
  EGA_STAGE_SEG = $A200;

type
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
var
  chunk: TChunk;
  frame: Byte;
  col: Word;
  row: Word;
  dstOff: Word;
  maskOff: Word;
  mask: Byte;
  k: Byte;
  j: Byte;
  bit: Byte;
  plane: Byte;
  color: Byte;
begin
  if pic = nil then Exit;
  with pic^ do begin
    dstOff := 0;
    maskOff := 0;
    case GDVars.videoMode of
      Types.vmCGA: begin
        for frame := 1 to count do
          for row := 0 to height - 1 do
            for col := 0 to width - 1 do begin
              Move(imgData^[srcOff], chunk, SizeOf(chunk));
              if transp <> nil then begin
                mask := Blit.ComputeMask(transpColor, chunk);
                bit := $80;
                for j := 1 to 2 do begin
                  for k := 4 to 7 do begin
                    if (bit and mask) > 0 then
                      transp^[maskOff] := transp^[maskOff] or GDConsts.cgaPixelMask[k];
                    bit := bit shr 1;
                  end;
                  Inc(maskOff);
                end;
              end;
              for k := 0 to 3 do
                if Odd(k) then
                  data[dstOff] := data[dstOff] or GDConsts.cgaPixPos[Blit.SrcNibble(chunk[k shr 1] and $0F, map)][k]
                else
                  data[dstOff] := data[dstOff] or
                    GDConsts.cgaPixPos[Blit.SrcNibble((chunk[k shr 1] and $F0) shr 4, map)][k];
              if transp <> nil then
                data[dstOff] := data[dstOff] and not transp^[maskOff - 2];
              Inc(dstOff);
              for k := 4 to 7 do
                if Odd(k) then
                  data[dstOff] := data[dstOff] or GDConsts.cgaPixPos[Blit.SrcNibble(chunk[k shr 1] and $0F, map)][k - 4]
                else
                  data[dstOff] := data[dstOff] or
                    GDConsts.cgaPixPos[Blit.SrcNibble((chunk[k shr 1] and $F0) shr 4, map)][k - 4];
              if transp <> nil then
                data[dstOff] := data[dstOff] and not transp^[maskOff - 1];
              Inc(dstOff);
              Inc(srcOff, SizeOf(chunk));
            end;
      end;
      Types.vmEGA: begin
        for frame := 1 to count do
          for row := 0 to height - 1 do
            for col := 0 to width - 1 do begin
              Move(imgData^[srcOff], chunk, SizeOf(chunk));
              if transp <> nil then begin
                transp^[maskOff] := Blit.ComputeMask(transpColor, chunk);
                Inc(maskOff);
              end;
              bit := $80;
              for k := 0 to 7 do begin
                if Odd(k) then
                  color := chunk[k shr 1] and $0F
                else
                  color := chunk[k shr 1] shr 4;
                for plane := 0 to 3 do
                  if (GDConsts.egaPlaneBit[plane] and color) > 0 then
                    data[plane + dstOff] := data[plane + dstOff] or bit;
                bit := bit shr 1;
              end;
              if transp <> nil then
                for plane := 0 to 3 do
                  data[plane + dstOff] := data[plane + dstOff] and not transp^[maskOff - 1];
              Inc(dstOff, 4);
              Inc(srcOff, SizeOf(chunk));
            end;
      end;
      Types.vmTandy: begin
        for frame := 1 to count do begin
          Move(imgData^[srcOff], data[dstOff], imgSize);
          if transp <> nil then
            for col := dstOff to dstOff + imgSize - 1 do begin
              if (data[col] shr 4) = transpColor then
                transp^[col] := $F0;
              if (data[col] and $0F) = transpColor then
                Inc(transp^[col], $0F);
              data[col] := data[col] and not transp^[col];
            end;
          Inc(dstOff, imgSize);
          Inc(srcOff, imgSize);
        end;
      end;
    end;
  end;
end;

{ BlitTileCell and BlitTileClipped: draw frame tileIdx of gfx into dest at (screenX, screenY), clipped against dest's
  edges when clip is set (BlitTileClipped's description), saving the covered pixels first when flag has bit 2. }
procedure BlitTile(screenX, screenY: Integer; tileIdx, flag: Byte; gfx, dest: Types.PImgBuf; clip: Boolean);
var
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
  case GDVars.videoMode of
    Types.vmCGA, Types.vmTandy: begin
      if GDVars.videoMode = Types.vmCGA then begin
        screenOff := leftSkip * 2;
        rowBytes := (gfx^.width - clipLeft - clipRight) * 2;
        clipLeft := clipLeft * 2;
        clipRight := clipRight * 2;
        leftSkip := leftSkip * 2;
        rightSkip := rightSkip * 2;
        srcOff := srcOff * 2;
        saveOff := srcOff;
        srcOff := tileIdx * gfx^.imgSize + srcOff;
        destOff := destOff * 2;
      end else begin
        screenOff := leftSkip * 4;
        rowBytes := (gfx^.width - clipLeft - clipRight) * 4;
        clipLeft := clipLeft * 4;
        clipRight := clipRight * 4;
        leftSkip := leftSkip * 4;
        rightSkip := rightSkip * 4;
        srcOff := srcOff * 4;
        saveOff := srcOff;
        srcOff := tileIdx * gfx^.imgSize + srcOff;
        destOff := destOff * 4;
      end;
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
        if useMask then begin
          for i := 1 to rowBytes do begin
            dest^.data[destOff] := dest^.data[destOff] and gfx^.transp^[srcOff] or gfx^.data[srcOff];
            Inc(srcOff);
            Inc(destOff);
          end;
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
    Types.vmEGA: begin
      screenOff := leftSkip;
      rowBytes := (gfx^.width - clipLeft - clipRight) * 4;
      clipLeft := clipLeft * 4;
      clipRight := clipRight * 4;
      leftSkip := leftSkip * 4;
      rightSkip := rightSkip * 4;
      srcOff := srcOff * 4;
      saveOff := srcOff;
      srcOff := tileIdx * gfx^.imgSize + srcOff;
      maskOff := srcOff div 4;
      maskClipLeft := clipLeft div 4;
      maskClipRight := clipRight div 4;
      planesLeft := 4;
      destOff := destOff * 4;
      for y := 0 to lastRow do begin
        GDVars.spanActive[scanline] := 1;
        Inc(srcOff, clipLeft);
        Inc(maskOff, maskClipLeft);
        Inc(saveOff, clipLeft);
        Inc(destOff, leftSkip);
        if GDVars.spanFirstOfs[scanline] > destOff then begin
          GDVars.spanScreenOfs[scanline] := screenOff;
          GDVars.spanFirstOfs[scanline] := destOff;
        end;
        if saveRequested then
          Move(dest^.data[destOff], GDVars.dsIconImageBufferPtr^.data[saveOff], rowBytes);
        Inc(saveOff, rowBytes);
        if useMask then begin
          for i := 1 to rowBytes do begin
            dest^.data[destOff] := dest^.data[destOff] and gfx^.transp^[maskOff] or gfx^.data[srcOff];
            Inc(srcOff);
            Dec(planesLeft);
            if planesLeft = 0 then begin
              planesLeft := 4;
              Inc(maskOff);
            end;
            Inc(destOff);
          end;
        end else begin
          Move(gfx^.data[srcOff], dest^.data[destOff], rowBytes);
          Inc(srcOff, rowBytes);
          Inc(destOff, rowBytes);
        end;
        if destOff - 1 > GDVars.spanLastOfs[scanline] then
          GDVars.spanLastOfs[scanline] := destOff - 1;
        Inc(srcOff, clipRight);
        Inc(maskOff, maskClipRight);
        Inc(saveOff, clipRight);
        Inc(destOff, rightSkip);
        Inc(scanline);
      end;
    end;
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
var
  dstOff: Word;
  srcOff: Word;
  rowStart: Word;
  rowBytes: Word;
  col: Word;
  row: Word;
  plane: Byte;
  cell: Word;
begin
  if (src = nil) or (dst = nil) then Exit;
  with src^ do begin
    Move(map, dst^.map, SizeOf(map));
    case GDVars.videoMode of
      { CGA: 2 bytes per 8-px cell, word pair-mirror }
      Types.vmCGA: begin
        rowBytes := width * SizeOf(cell);
        srcOff := rowBytes - SizeOf(cell);
        dstOff := 0;
        for row := 1 to height do begin
          rowStart := dstOff;
          for col := 0 to width - 1 do begin
            Move(data[srcOff - dstOff + rowStart], cell, SizeOf(cell));
            cell := Blit.MirrorPairs(cell);
            Move(cell, dst^.data[dstOff], SizeOf(cell));
            if transp <> nil then begin
              Move(transp^[srcOff - dstOff + rowStart], cell, SizeOf(cell));
              cell := Blit.MirrorPairs(cell);
              Move(cell, dst^.transp^[dstOff], SizeOf(cell));
            end;
            Inc(dstOff, SizeOf(cell));
          end;
          Inc(srcOff, rowBytes);
        end;
      end;
      { EGA: 4 plane bytes per cell, bit-mirror each }
      Types.vmEGA: begin
        rowBytes := width * 4;
        srcOff := rowBytes - 4;
        dstOff := 0;
        for row := 1 to height do begin
          rowStart := dstOff;
          for col := 1 to width do begin
            for plane := 0 to 3 do
              dst^.data[plane + dstOff] := Blit.MirrorBits(data[srcOff - dstOff + rowStart + plane]);
            Inc(dstOff, 4);
          end;
          Inc(srcOff, rowBytes);
        end;
        if transp <> nil then begin
          srcOff := 0;
          for row := 1 to height do begin
            for col := 0 to width - 1 do
              dst^.transp^[srcOff + width - col - 1] := Blit.MirrorBits(transp^[srcOff + col]);
            Inc(srcOff, width);
          end;
        end;
      end;
      { Tandy: 4 bytes per cell, nibble-swap each }
      Types.vmTandy: begin
        rowBytes := width * 4;
        srcOff := rowBytes - 1;
        dstOff := 0;
        for row := 1 to height do begin
          rowStart := dstOff;
          for col := 1 to rowBytes do begin
            dst^.data[dstOff] := Blit.MirrorNibbles(data[srcOff - dstOff + rowStart]);
            if transp <> nil then
              dst^.transp^[dstOff] := Blit.MirrorNibbles(transp^[srcOff - dstOff + rowStart]);
            Inc(dstOff);
          end;
          Inc(srcOff, rowBytes);
        end;
      end;
    end;
  end;
end;

procedure ShowPic(screenX, screenY: Integer; pic: Types.PImgBuf);
var
  col: Integer;
  row: Integer;
  colOff: Word;
  firstRow: Word;
  colEnd: Word;
  lastRow: Word;
  rowBytes: Word;
  srcOff: Word;
  plane: Byte;
begin
  if pic = nil then Exit;
  with pic^ do
    case GDVars.videoMode of
      { CGA: 2 bytes per 8-px cell }
      Types.vmCGA: begin
        rowBytes := width * 2;
        srcOff := 0;
        firstRow := screenY * 8;
        lastRow := firstRow + height - 1;
        colOff := screenX * 2;
        for row := firstRow to lastRow do begin
          Move(pic^.data[srcOff], Mem[GDVars.cgaRowSeg[row]:colOff], rowBytes);
          Inc(srcOff, rowBytes);
        end;
      end;
      { EGA: 4 plane bytes per cell via the Map Mask }
      Types.vmEGA: begin
        srcOff := 0;
        firstRow := screenY * 8;
        lastRow := firstRow + height - 1;
        colOff := screenX;
        colEnd := colOff + width - 1;
        Port[C_Ega.SEQ_ADDR_PORT] := C_Ega.SEQ_MAP_MASK_REG;
        for row := firstRow to lastRow do
          for col := colOff to colEnd do
            for plane := 0 to 3 do begin
              Port[C_Ega.SEQ_DATA_PORT] := GDConsts.egaPlaneBit[plane];
              Mem[C_Video.EGA_VIDEO_SEG:GDVars.fbRowOfs[row] + col] := pic^.data[srcOff];
              Inc(srcOff);
            end;
        Port[C_Ega.SEQ_DATA_PORT] := C_Ega.MAP_MASK_ALL_PLANES;
      end;
      { Tandy: 4 bytes per 8-px cell }
      Types.vmTandy: begin
        rowBytes := width * 4;
        srcOff := 0;
        firstRow := screenY * 8;
        lastRow := firstRow + height - 1;
        colOff := screenX * 4;
        for row := firstRow to lastRow do begin
          Move(pic^.data[srcOff], Mem[GDVars.tandyRowSeg[row]:colOff], rowBytes);
          Inc(srcOff, rowBytes);
        end;
      end;
    end;
end;

procedure FlushView;
var
  row: Word;
  srcOff: Word;
  dstOff: Word;
  dstBase: Word;
  plane: Byte;
begin
  case GDVars.videoMode of
    Types.vmCGA:
      for row := 0 to SizeOf(GDVars.spanActive) - 1 do
        if GDVars.spanActive[row] <> 0 then
          Move(GDVars.dsViewImageBufferPtr^.data[GDVars.spanFirstOfs[row]],
               Mem[GDVars.cgaRowSeg[row + 8]:GDVars.spanScreenOfs[row] + 2],
               GDVars.spanLastOfs[row] - GDVars.spanFirstOfs[row] + 1);
    Types.vmEGA: begin
      Port[C_Ega.SEQ_ADDR_PORT] := C_Ega.SEQ_MAP_MASK_REG;
      for row := 0 to SizeOf(GDVars.spanActive) - 1 do
        if GDVars.spanActive[row] <> 0 then begin
          dstBase := GDVars.fbRowOfs[row + 8] + GDVars.spanScreenOfs[row] + 1;
          { each plane's bytes, every fourth from its own in the view buffer }
          for plane := 0 to 3 do begin
            Port[C_Ega.SEQ_DATA_PORT] := GDConsts.egaPlaneBit[plane];
            srcOff := GDVars.spanFirstOfs[row] + plane;
            dstOff := dstBase;
            repeat
              Mem[EGA_STAGE_SEG:dstOff] := GDVars.dsViewImageBufferPtr^.data[srcOff];
              Inc(srcOff, 4);
              Inc(dstOff);
            until srcOff > GDVars.spanLastOfs[row];
          end;
        end;
      Port[C_Ega.SEQ_DATA_PORT] := C_Ega.MAP_MASK_ALL_PLANES;
      dstOff := GDVars.fbRowOfs[8] + 1;
      Port[C_Ega.GC_ADDR_PORT] := C_Ega.GC_MODE_REG;
      Port[C_Ega.GC_DATA_PORT] := GC_WRITE_MODE_1;
      for row := 0 to SizeOf(GDVars.spanActive) - 1 do begin
        if GDVars.spanActive[row] <> 0 then
          Move(Mem[EGA_STAGE_SEG:dstOff + GDVars.spanScreenOfs[row]],
               Mem[C_Video.EGA_VIDEO_SEG:dstOff + GDVars.spanScreenOfs[row]],
               (GDVars.spanLastOfs[row] - GDVars.spanFirstOfs[row]) div 4 + 1);
        Inc(dstOff, 40);
      end;
      Port[C_Ega.GC_DATA_PORT] := C_Ega.GC_WRITE_MODE_0;
    end;
    Types.vmTandy:
      for row := 0 to SizeOf(GDVars.spanActive) - 1 do
        if GDVars.spanActive[row] <> 0 then
          Move(GDVars.dsViewImageBufferPtr^.data[GDVars.spanFirstOfs[row]],
               Mem[GDVars.tandyRowSeg[row + 8]:GDVars.spanScreenOfs[row] + 4],
               GDVars.spanLastOfs[row] - GDVars.spanFirstOfs[row] + 1);
  end;
  FillChar(GDVars.spanActive, SizeOf(GDVars.spanActive), 0);
  FillChar(GDVars.spanFirstOfs, SizeOf(GDVars.spanFirstOfs), $FF);
  FillChar(GDVars.spanLastOfs, SizeOf(GDVars.spanLastOfs), 0);
end;

procedure RemapPic(fromColors, toColors: Types.TColorTab; frame: Integer; isDithered: Boolean; pic: Types.PImgBuf);
var
  srcOff: Word;
  dstOff: Word;
  nFrames: Byte;
  col: Word;
  row: Word;
  match: Byte;
  planeMask: array[0..3] of Byte;
  plane: Byte;
  pixPos: Byte;
  rowBytes: Word;
  fromHigh: Byte;
  toHigh: Byte;
  pairIdx: Byte;
  scratchPic: Types.PImgBuf;
begin
  if pic = nil then Exit;
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
      with scratchPic^ do
        case GDVars.videoMode of
          { CGA: match/rewrite each 2-bit pixel pattern }
          Types.vmCGA: begin
            rowBytes := width * 2;
            for GDVars.dsCurrentPictureNumber := frame to nFrames + frame - 1 do
              for row := 1 to height do
                for col := 1 to rowBytes do begin
                  for pixPos := 0 to 3 do
                    if pic^.data[srcOff] and GDConsts.cgaPixelMask[pixPos + 4] =
                        GDConsts.cgaPixPos[Blit.SrcNibble(fromColors[pairIdx], map)][pixPos] then
                      if not isDithered or isDithered and (Random(4) = 0) then
                        data[dstOff] := data[dstOff] and not GDConsts.cgaPixelMask[pixPos + 4] or
                          GDConsts.cgaPixPos[Blit.SrcNibble(toColors[pairIdx], map)][pixPos];
                  Inc(srcOff);
                  Inc(dstOff);
                end;
          end;
          { EGA: bitmask match across the 4 plane bytes }
          Types.vmEGA: begin
            for plane := 0 to 3 do
              if (fromColors[pairIdx] and GDConsts.egaPlaneBit[plane]) > 0 then
                planeMask[plane] := 0
              else
                planeMask[plane] := $FF;
            for GDVars.dsCurrentPictureNumber := frame to nFrames + frame - 1 do
              for row := 1 to height do
                for col := 1 to width do begin
                  if isDithered then
                    match := Random(256) and Random(256)
                  else
                    match := $FF;
                  for plane := 0 to 3 do
                    match := (pic^.data[plane + srcOff] xor planeMask[plane]) and match;
                  for plane := 0 to 3 do
                    if (toColors[pairIdx] and GDConsts.egaPlaneBit[plane]) > 0 then
                      data[plane + dstOff] := data[plane + dstOff] or match
                    else
                      data[plane + dstOff] := data[plane + dstOff] and not match;
                  Inc(srcOff, 4);
                  Inc(dstOff, 4);
                end;
          end;
          { Tandy: high and low nibble matched separately }
          Types.vmTandy: begin
            rowBytes := width * 4;
            fromHigh := fromColors[pairIdx] shl 4;
            toHigh := toColors[pairIdx] shl 4;
            for GDVars.dsCurrentPictureNumber := frame to nFrames + frame - 1 do
              for row := 1 to height do
                for col := 1 to rowBytes do begin
                  if pic^.data[srcOff] and $F0 = fromHigh then
                    if not isDithered or isDithered and (Random(4) = 0) then
                      data[dstOff] := data[dstOff] and $F or toHigh;
                  if pic^.data[srcOff] and $F = fromColors[pairIdx] then
                    if not isDithered or isDithered and (Random(4) = 0) then
                      data[dstOff] := data[dstOff] and $F0 or toColors[pairIdx];
                  Inc(srcOff);
                  Inc(dstOff);
                end;
          end;
        end;
  end;
  with pic^ do
    Move(scratchPic^.data, data[frame * imgSize], nFrames * imgSize);
  Blit.FreePic(scratchPic);
end;

procedure AllocPic(height, width: Word; count: Byte; flag: Byte; var pic: Types.PImgBuf);
var
  frameSize: Word;
  totalSize: Word;
begin
  frameSize := height * width * 2;
  if GDVars.videoMode <> Types.vmCGA then
    frameSize := frameSize * 2;
  totalSize := count * frameSize;
  GetMem(pic, totalSize + (SizeOf(Types.TImgBuf) - SizeOf(pic^.data)));
  FillChar(pic^, totalSize + (SizeOf(Types.TImgBuf) - SizeOf(pic^.data)), 0);
  pic^.height := height;
  pic^.width := width;
  pic^.imgSize := frameSize;
  pic^.count := count;
  if (flag and 1) > 0 then
    if GDVars.videoMode = Types.vmEGA then begin
      GetMem(pic^.transp, totalSize div 4);
      FillChar(pic^.transp^, totalSize div 4, 0);
    end else begin
      GetMem(pic^.transp, totalSize);
      FillChar(pic^.transp^, totalSize, 0);
    end;
end;

procedure FreePic(var pic: Types.PImgBuf);
var
  nBytes: Word;
begin
  if pic = nil then Exit;
  with pic^ do begin
    nBytes := count * imgSize;
    if transp <> nil then
      if GDVars.videoMode = Types.vmEGA then
        FreeMem(transp, nBytes div 4)
      else
        FreeMem(transp, nBytes);
  end;
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
  planeMask: array[0..3] of Byte;
  absRow: Word;
  screenOfs: Word;
  plane: Byte;
  i: Word;
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
  case GDVars.videoMode of
    Types.vmCGA, Types.vmTandy: begin
      { CGA: 2 bytes per cell }
      if GDVars.videoMode = Types.vmCGA then begin
        screenOfs := clampedX * 2;
        runLen := (width - clipLeft - clipRight) * 2;
        clampedX := clampedX * 2;
        rightMargin := rightMargin * 2;
        dstOff := dstOff * 2;
      end
      { Tandy: 4 bytes per cell }
      else begin
        runLen := (width - clipLeft - clipRight) * 4;
        clampedX := clampedX * 4;
        rightMargin := rightMargin * 4;
        dstOff := dstOff * 4;
        screenOfs := clampedX;
      end;
      for row := 0 to lastRow do begin
        GDVars.spanActive[absRow] := 1;
        Inc(dstOff, clampedX);
        if GDVars.spanFirstOfs[absRow] > dstOff then begin
          GDVars.spanScreenOfs[absRow] := screenOfs;
          GDVars.spanFirstOfs[absRow] := dstOff;
        end;
        if GDVars.videoMode = Types.vmCGA then
          FillChar(pic^.data[dstOff], runLen, GDConsts.cgaColorFill[Blit.SrcNibble(color, colorMap)])
        else
          FillChar(pic^.data[dstOff], runLen, GDConsts.tandyColorFill[color]);
        Inc(dstOff, runLen);
        if dstOff - 1 > GDVars.spanLastOfs[absRow] then
          GDVars.spanLastOfs[absRow] := dstOff - 1;
        Inc(dstOff, rightMargin);
        Inc(absRow);
      end;
    end;
    { EGA: 4 plane bytes per cell }
    Types.vmEGA: begin
      screenOfs := clampedX;
      runLen := width - clipLeft - clipRight;
      clampedX := clampedX * 4;
      rightMargin := rightMargin * 4;
      dstOff := dstOff * 4;
      FillChar(planeMask, SizeOf(planeMask), 0);
      for plane := 0 to 3 do
        if (GDConsts.egaPlaneBit[plane] and color) > 0 then
          planeMask[plane] := $FF;
      for row := 0 to lastRow do begin
        GDVars.spanActive[absRow] := 1;
        Inc(dstOff, clampedX);
        if GDVars.spanFirstOfs[absRow] > dstOff then begin
          GDVars.spanScreenOfs[absRow] := screenOfs;
          GDVars.spanFirstOfs[absRow] := dstOff;
        end;
        for i := 1 to runLen do begin
          Move(planeMask, pic^.data[dstOff], SizeOf(planeMask));
          Inc(dstOff, 4);
        end;
        if dstOff - 1 > GDVars.spanLastOfs[absRow] then
          GDVars.spanLastOfs[absRow] := dstOff - 1;
        Inc(dstOff, rightMargin);
        Inc(absRow);
      end;
    end;
  end;
end;

procedure SetPaletteRegister(registerIndex, color: Byte);
begin
  GDVars.dsInterruptRegisters.ah := $10;
  GDVars.dsInterruptRegisters.al := 0;
  if color < 8 then
    GDVars.dsInterruptRegisters.bh := color
  else
    GDVars.dsInterruptRegisters.bh := color + 8;
  GDVars.dsInterruptRegisters.bl := registerIndex;
  Intr($10, GDVars.dsInterruptRegisters);
end;

end.

{ Image loading, conversion and compositing for CGA, EGA, Tandy and VGA displays, through the installed video driver
  (GameVars.video). Drawing into the view buffer stages dirty spans; FlushView copies those spans to the screen.

  The drivers' video-memory layouts: CGA packs eight pixels into two bytes and interleaves even and odd scanlines
  between two banks. EGA stores eight pixels as four plane bytes, selected through the sequencer map mask; each row
  spans 40 bytes. Tandy packs eight pixels into four bytes across four scanline banks. VGA keeps a byte a pixel. Raw
  artwork always uses four bytes per eight-pixel chunk. }
{$O+,F+}
{$I COMPILER.INC}
unit Blit;

interface

uses Types;

const
  { the most bytes one heap block holds (GetMem's limit in real mode), and so the largest block of a picture }
  MAX_BLOCK = 65520;

var
  { heap bytes held by pictures (AllocPic less FreePic), and the most they have reached; STING Ctrl-Y shows them }
  picBytes: LongInt;
  picPeak: LongInt;

{ Translates logical color 0..15 through a picture's color map. The map packs
  two colors per byte: even colors use the high nibble and odd colors use the
  low nibble. CGA callers expect a result in 0..3. This routine does not check
  either range. }
function SrcNibble(color: Byte; map: Types.TColorMap): Byte;

{ Switches to the requested BIOS video mode and remembers the previous mode for
  RestoreVideoMode. The BIOS result is not checked, so an unsupported mode
  fails silently even though the bookkeeping records the change. }
procedure SetVideoMode(mode: Byte);

{ Returns the display to the mode saved by the last SetVideoMode call. That call also saves the mode being replaced, so
  calling this twice in a row toggles between two modes. }
procedure RestoreVideoMode;

{ Loads block fileId from <name>.dax into a display-ready image buffer. The old
  pic buffer is freed first. When hasMask is True, transpColor becomes
  transparent. If the file supplies no data, pic is left nil. }
procedure LoadPic(name: string; fileId: Byte; hasMask: Boolean; transpColor: Byte; var pic: Types.PImgBuf);

{ LoadPic, with no heap block of the picture over blockBytes (AllocPicBlocks): a large picture loaded in small blocks
  still loads when the heap is split into pieces too small for one large block (#1218). }
procedure LoadPicBlocks(name: string; fileId: Byte; hasMask: Boolean; transpColor: Byte; blockBytes: Word;
                        var pic: Types.PImgBuf);

{ Draws frame tileIdx from gfx into dest at a character-cell position. Bit 0 of
  flag enables transparency when gfx has a mask. The changed scanlines are
  marked dirty for FlushView. The tile is not clipped, so the caller must keep
  it inside dest. }
procedure BlitTileCell(screenX, screenY: Integer; tileIdx, flag: Byte; gfx, dest: Types.PImgBuf);

{ Draws frame tileIdx from gfx like BlitTileCell, but clips it to dest. Bit 0 of
  flag enables transparency; bit 2 saves the covered pixels so the caller can
  restore them later. Negative screen coordinates are allowed. Invalid or nil
  buffers and tiles wholly outside dest are ignored. }
procedure BlitTileClipped(screenX, screenY: Integer; tileIdx, flag: Byte; gfx, dest: Types.PImgBuf);

{ Copies the first frame of src into dst, reflected left to right. The color map
  and transparency mask are copied too. dst must be large enough, must not
  overlap unread source data, and must have a mask when src does. Nil buffers
  are ignored. }
procedure MirrorPic(src, dst: Types.PImgBuf);

{ Draws pic's first frame directly to video memory at a character-cell
  position, bypassing the view buffer and dirty spans. No clipping or
  transparency is applied. A nil pic is ignored. }
procedure ShowPic(screenX, screenY: Integer; pic: Types.PImgBuf);

{ Copies every dirty span of the view buffer to video memory through the driver's FlushSpans, then resets the span
  tables (ClearSpans) so the next frame starts clean. Spans use inclusive byte offsets; callers must supply valid
  bounds. CGA, Tandy and VGA copy each span in one move. On EGA each span is staged plane by plane in off-screen video
  memory and then copied to the visible page in a single latch-copy pass, so the visible memory is never left with only
  some planes updated; an EGA last offset of $FFFF would keep the plane loop from ending, and the graphics controller is
  returned to its normal write mode afterwards. }
procedure FlushView;

{ Mark no scanline of the view dirty: every row inactive, its first offset past any and its last 0. }
procedure ClearSpans;

{ Recolors pic by replacing each fromColors entry with the matching toColors
  entry. Replacements are matched against the original pixels, so remaps do not
  cascade and colors can be swapped. A negative frame remaps every frame;
  otherwise only that frame is changed. isDithered changes only a random subset
  of matching pixels. A nil pic or an out-of-range frame is ignored. }
procedure RemapPic(fromColors, toColors: Types.TColorTab; frame: Integer; isDithered: Boolean; pic: Types.PImgBuf);

{ Allocates a zero-filled image buffer for count frames. height is in scanlines
  and width is in eight-pixel cells. Bit 0 of flag requests a transparency
  mask. Frames that do not fit in one heap block continue in pic^.more. }
procedure AllocPic(height, width: Word; count: Byte; flag: Byte; var pic: Types.PImgBuf);

{ AllocPic, with each heap block holding as many frames as fit in blockBytes (header included) rather than 65,520; a
  frame larger than blockBytes still gets a block of its own. FrameBlock finds a frame in any of them. }
procedure AllocPicBlocks(height, width: Word; count: Byte; flag: Byte; blockBytes: Word; var pic: Types.PImgBuf);

{ Frees pic and its transparency mask, then sets pic to nil. The mask size
  depends on the current video mode, so a picture must be freed in the mode in
  which it was allocated. }
procedure FreePic(var pic: Types.PImgBuf);

{ Fills a clipped rectangle in pic and marks its scanlines dirty. x and width
  use eight-pixel cells; y and height use scanlines. Negative coordinates are
  allowed. color is 0..15 and is translated through colorMap on CGA. A nil pic
  or a rectangle wholly outside it is ignored. }
procedure FillPicRect(x, y: Integer; width, height: Word; color: Byte; colorMap: Types.TColorMap; pic: Types.PImgBuf);

{ Assigns logical color 0..15 to registerIndex through the video driver. This
  changes an EGA palette register or a VGA DAC entry and does nothing in modes
  without a programmable palette. }
procedure SetPaletteRegister(registerIndex, color: Byte);

{ What the game asks of the video mode instead of naming it (phase 6, step 1). }

{ The bytes a picture frame height scanlines tall and width cells wide takes in the video mode: 2 a cell row on CGA
  (2 bits a pixel), 4 on EGA (four planes) and Tandy (4 bits a pixel), 8 on VGA (a byte a pixel). }
function FrameBytes(height, width: Word): Word;

{ The bytes of transparency mask for imageBytes bytes of picture: a quarter on EGA, where one mask byte covers a cell
  row's four plane bytes, an eighth on VGA, where it covers a cell row's eight pixels, and the same on CGA and Tandy,
  where the mask matches the data byte for byte. }
function MaskBytes(imageBytes: Word): Word;

{ The colours the video mode shows at once: 4 on CGA, which draws the 16 through each picture's colour map, and 16 on
  EGA, Tandy and VGA. }
function ColourCount: Byte;

{ True when the video mode has palette registers SetPaletteRegister can program (EGA's registers, VGA's DAC). }
function HasPalette: Boolean;

{ Make pic's first frame wholly transparent: every pixel 0 (PIC_KEY in a keyed mode) and every mask bit set. }
procedure ClearPic(pic: Types.PImgBuf);

{ Step pic to the block holding frame, and frame to its index there: a picture too large for one heap block continues
  in pic^.more (AllocPic). }
procedure FrameBlock(var pic: Types.PImgBuf; var frame: Word);

{ The frames in pic, in all its blocks. }
function FrameCount(pic: Types.PImgBuf): Word;

implementation

uses GameVars, DaxIo, Dos, GameIo, StrUtil, VidOps{$IFDEF FPC}, Host{$ENDIF};

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

function SrcNibble(color: Byte; map: Types.TColorMap): Byte;
begin
  if Odd(color) then
    SrcNibble := map[color shr 1] and $0F
  else
    SrcNibble := (map[color shr 1] and $F0) shr 4;
end;

procedure SetVideoMode(mode: Byte);
begin
  GameVars.savedVideoMode := GameVars.curVideoMode;
  GameVars.interruptRegisters.ah := 0;
  GameVars.interruptRegisters.al := mode;
  Intr($10, GameVars.interruptRegisters);
  GameVars.curVideoMode := mode;
end;

procedure RestoreVideoMode;
begin
  Blit.SetVideoMode(GameVars.savedVideoMode);
end;

procedure LoadPic(name: string; fileId: Byte; hasMask: Boolean; transpColor: Byte; var pic: Types.PImgBuf);
begin
  Blit.LoadPicBlocks(name, fileId, hasMask, transpColor, MAX_BLOCK, pic);
end;

procedure LoadPicBlocks(name: string; fileId: Byte; hasMask: Boolean; transpColor: Byte; blockBytes: Word;
                        var pic: Types.PImgBuf);
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
  Blit.AllocPicBlocks(picHeight, picWidth, picCount, Byte(hasMask), blockBytes, pic);
  with pic^ do begin
    originX := picOriginX;
    originY := picOriginY;
    map := colorMap;
  end;
  readOfs := SizeOf(TDaxPicHeader);
  VidOps.ExpandPicFrames(data, readOfs, transpColor, pic);
  FreeMem(data, dataSize);
end;

{ Mark scanline row of the view dirty from byte first to byte last, first being screenOfs on the screen, widening
  what the row already has. }
procedure MarkSpan(row, first, last, screenOfs: Word);
begin
  GameVars.spanActive[row] := 1;
  if GameVars.spanFirstOfs[row] > first then begin
    GameVars.spanScreenOfs[row] := screenOfs;
    GameVars.spanFirstOfs[row] := first;
  end;
  if last > GameVars.spanLastOfs[row] then
    GameVars.spanLastOfs[row] := last;
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
  frame: Word;
  firstOfs: Word;
begin
  { a frame past the block's count is in a further block (AllocPic) }
  frame := tileIdx;
  Blit.FrameBlock(gfx, frame);
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
    end;
    if screenY < 0 then begin
      srcOff := Abs(screenY) * gfx^.width * 8;
      destOff := 0;
      scanline := 0;
      lastRow := gfx^.height - 1 - Abs(screenY) * 8;
      if (gfx^.imgSize - 1 < srcOff) or (gfx^.height - 1 < lastRow) then
        Exit;
      { no further than dest's last row (SSI did not check the bottom here) }
      if lastRow > dest^.height - 1 then
        lastRow := dest^.height - 1;
    end else begin
      srcOff := 0;
      scanline := screenY * 8;
      destOff := scanline * dest^.width;
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
  cs := GameVars.video.cellShift;
  ms := GameVars.video.maskShift;
  screenOff := leftSkip shl GameVars.video.screenShift;
  rowBytes := (gfx^.width - clipLeft - clipRight) shl cs;
  clipLeft := clipLeft shl cs;
  clipRight := clipRight shl cs;
  leftSkip := leftSkip shl cs;
  rightSkip := rightSkip shl cs;
  srcOff := srcOff shl cs;
  saveOff := srcOff;
  srcOff := frame * gfx^.imgSize + srcOff;
  maskOff := srcOff shr ms;
  maskClipLeft := clipLeft shr ms;
  maskClipRight := clipRight shr ms;
  planesPerMask := 1 shl ms;
  planesLeft := planesPerMask;
  maskEach := useMask and (ms = 0);
  destOff := destOff shl cs;
  for y := 0 to lastRow do begin
    Inc(srcOff, clipLeft);
    Inc(saveOff, clipLeft);
    Inc(destOff, leftSkip);
    firstOfs := destOff;
    if saveRequested then
      Move(dest^.data[destOff], GameVars.saveUnder^.data[saveOff], rowBytes);
    Inc(saveOff, rowBytes);
    if useMask and GameVars.video.keyed then begin
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
    Blit.MarkSpan(scanline, firstOfs, destOff - 1, screenOff);
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
  Blit.BlitTile(screenX, screenY, tileIdx, flag, gfx, dest, True);
end;

procedure MirrorPic(src, dst: Types.PImgBuf);
begin
  if (src = nil) or (dst = nil) then Exit;
  Move(src^.map, dst^.map, SizeOf(src^.map));
  GameVars.video.MirrorFrame(src, dst);
end;

procedure ShowPic(screenX, screenY: Integer; pic: Types.PImgBuf);
begin
  if pic = nil then Exit;
  GameVars.video.ShowPic(screenX, screenY, pic);
end;

procedure FlushView;
begin
  GameVars.video.FlushSpans;
  Blit.ClearSpans;
end;

procedure ClearSpans;
begin
  FillChar(GameVars.spanActive, SizeOf(GameVars.spanActive), 0);
  FillChar(GameVars.spanFirstOfs, SizeOf(GameVars.spanFirstOfs), $FF);
  FillChar(GameVars.spanLastOfs, SizeOf(GameVars.spanLastOfs), 0);
end;

procedure RemapPic(fromColors, toColors: Types.TColorTab; frame: Integer; isDithered: Boolean; pic: Types.PImgBuf);
var
  srcOff: Word;
  nFrames: Byte;
  pairIdx: Byte;
  scratchPic: Types.PImgBuf;
  allFrames: Boolean;
  inBlock: Word;
begin
  if pic = nil then Exit;
  allFrames := frame < 0;
  if not allFrames then begin
    { a frame past the block's count is in a further block (AllocPic); one past the last is not there }
    inBlock := frame;
    Blit.FrameBlock(pic, inBlock);
    if inBlock >= pic^.count then Exit;
    frame := inBlock;
  end;
  with pic^ do begin
    if frame < 0 then begin
      frame := 0;
      nFrames := count;
    end else
      nFrames := 1;
    srcOff := frame * imgSize;
  end;
  Blit.AllocPic(pic^.height, pic^.width, nFrames, 0, scratchPic);
  scratchPic^.map := pic^.map;
  Move(pic^.data[srcOff], scratchPic^.data, scratchPic^.count * scratchPic^.imgSize);
  for pairIdx := 0 to 15 do
    if fromColors[pairIdx] <> toColors[pairIdx] then
      GameVars.video.RemapColour(pic, scratchPic, srcOff, nFrames, fromColors[pairIdx], toColors[pairIdx], isDithered);
  with pic^ do
    Move(scratchPic^.data, data[frame * imgSize], nFrames * imgSize);
  Blit.FreePic(scratchPic);
  if allFrames and (pic^.more <> nil) then
    Blit.RemapPic(fromColors, toColors, -1, isDithered, pic^.more);
end;

procedure AllocPic(height, width: Word; count: Byte; flag: Byte; var pic: Types.PImgBuf);
begin
  Blit.AllocPicBlocks(height, width, count, flag, MAX_BLOCK, pic);
end;

procedure AllocPicBlocks(height, width: Word; count: Byte; flag: Byte; blockBytes: Word; var pic: Types.PImgBuf);
var
  frameSize: Word;
  totalSize: Word;
  fit: LongInt;
  rest: Byte;
begin
  frameSize := Blit.FrameBytes(height, width);
  { A heap block holds at most 65,520 bytes, and the caller may ask for less: frames past what one holds go to a
    further block, pic^.more. A frame that alone is too large for 65,520 cannot be drawn in this mode. }
  if frameSize = 0 then
    { a frame of no rows or no cells takes no bytes: they all fit (SSI divided by 0) }
    fit := count
  else begin
    fit := (LongInt(blockBytes) - (SizeOf(Types.TImgBuf) - SizeOf(pic^.data))) div frameSize;
    { a frame over the caller's cap still goes in a block of its own, when the heap can hold one }
    if (fit < 1) and (frameSize <= MAX_BLOCK - (SizeOf(Types.TImgBuf) - SizeOf(pic^.data))) then
      fit := 1;
  end;
  if (fit < 1) and (frameSize > 0) then
    GameIo.FatalError('A picture of ' + StrUtil.NumStr(height) + ' rows and ' + StrUtil.NumStr(width) +
                      ' cells is too large for the ' + GameVars.video.name + ' video mode.');
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
  Inc(picBytes, totalSize + (SizeOf(Types.TImgBuf) - SizeOf(pic^.data)));
  if (flag and 1) > 0 then
    Inc(picBytes, Blit.MaskBytes(totalSize));
  if picBytes > picPeak then
    picPeak := picBytes;
  if rest > 0 then
    Blit.AllocPicBlocks(height, width, rest, flag, blockBytes, pic^.more);
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
      Dec(picBytes, Blit.MaskBytes(nBytes));
    end;
  end;
  Dec(picBytes, nBytes + (SizeOf(Types.TImgBuf) - SizeOf(pic^.data)));
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
  firstOfs: Word;
begin
  if pic = nil then Exit;
  { an empty rectangle fills nothing (SSI ran its row loop 65536 times for a zero height at a row of 0 or more, #728) }
  if (width = 0) or (height = 0) then Exit;
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
    { the rows from 0 to the rectangle's bottom, inside the picture (SSI filled one more and did not check the bottom,
      POR-0161) }
    dstOff := 0;
    absRow := 0;
    lastRow := height - Abs(y) - 1;
    if lastRow > pic^.height - 1 then
      lastRow := pic^.height - 1;
  end else begin
    absRow := y;
    dstOff := absRow * pic^.width;
    if pic^.height < y + height then
      lastRow := pic^.height - 1 - y
    else
      lastRow := height - 1;
  end;
  { the driver's layout: 1 shl cellShift picture bytes a cell row, 1 shl screenShift screen bytes a cell column }
  with GameVars.video do begin
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
    Inc(dstOff, clampedX);
    firstOfs := dstOff;
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
    Blit.MarkSpan(absRow, firstOfs, dstOff - 1, screenOfs);
    Inc(dstOff, rightMargin);
    Inc(absRow);
  end;
end;

procedure SetPaletteRegister(registerIndex, color: Byte);
begin
  if Blit.HasPalette then
    GameVars.video.SetPalette(registerIndex, color);
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
  if GameVars.video.keyed then
    clear := Types.PIC_KEY
  else
    clear := 0;
  FillChar(pic^.data, pic^.imgSize, clear);
  if pic^.transp <> nil then
    FillChar(pic^.transp^, Blit.MaskBytes(pic^.imgSize), $FF);
end;

function FrameBytes(height, width: Word): Word;
begin
  FrameBytes := (height * width) shl GameVars.video.cellShift;
end;

function MaskBytes(imageBytes: Word): Word;
begin
  MaskBytes := imageBytes shr GameVars.video.maskShift;
end;

function ColourCount: Byte;
begin
  ColourCount := GameVars.video.colours;
end;

function HasPalette: Boolean;
begin
  HasPalette := GameVars.video.hasPalette;
end;

begin
  { Turbo Pascal clears no variable }
  picBytes := 0;
  picPeak := 0;
end.

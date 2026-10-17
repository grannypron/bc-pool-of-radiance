{ Load terrain tiles and creature icon frames, copy tiles into the view buffer and draw animated icons.

  Tile IDs use seven bits for the index and the high bit to select the second tile-set buffer. }
{$O+,F+,I-} { I/O checking is disabled for the range-error message. }
unit MapTiles;

interface

uses Types;

procedure Load24x24Set(name: string; mult: Byte; unused: ShortInt);

procedure Copy2DTile(col, row: ShortInt; tile: Byte; unused: ShortInt);

{ The second 24x24 tile set (SQRPACI block 2, tile IDs 128 and up), loaded into GDVars.ds2dMapTilePtr2 the first time
  it is needed: only the wilderness and the ending draw from it, so it is not loaded at start-up and combat frees it
  (FreeSecondSheet). Nil when it does not load. }
function SecondSheet: Types.PImgBuf;

{ Free the second tile set, for SecondSheet to load again when it is next needed. }
procedure FreeSecondSheet;

procedure FreeIconAnim(animIdx: Byte);

procedure LoadIconAnim(name: string; fileId, animIdx: Byte);

procedure DrawIconAnimSprite(col, row: ShortInt; facing, frame, animIdx: Byte);

implementation

uses Crt, C_Tile, GDConsts, GDVars, Blit, GameIo, C_Dir;

{ Load the 24x24 tile set <name> (block 1) and, when the first tile-set buffer is allocated, copy its tiles into that
  buffer starting at tile slot mult, as many as fit. A mult above 127, the last slot, restores the video mode and ends
  the game with a range error. Nothing is copied if the set does not load. }
procedure Load24x24Set(name: string; mult: Byte; unused: ShortInt);
var
  pic: Types.PImgBuf;
  dst: Types.PImgBuf;
  frame: Word;
  i: Integer;
  tiles: Integer;
begin
  if mult > 127 then begin
    GameIo.FatalError('Start range error in Load24x24Set');
  end;
  pic := nil;
  Blit.LoadPic(name, 1, False, 0, pic);
  if pic = nil then Exit;
  if GDVars.ds2dMapTilePtr <> nil then begin
    tiles := pic^.count;
    if mult + tiles > Blit.FrameCount(GDVars.ds2dMapTilePtr) then
      tiles := Blit.FrameCount(GDVars.ds2dMapTilePtr) - mult;
    { a tile at a time, as the sheet may continue in a further block (Blit.FrameBlock) }
    for i := 0 to tiles - 1 do begin
      dst := GDVars.ds2dMapTilePtr;
      frame := mult + i;
      Blit.FrameBlock(dst, frame);
      Move(pic^.data[i * pic^.imgSize], dst^.data[frame * dst^.imgSize], pic^.imgSize);
    end;
  end;
  Blit.FreePic(pic);
end;

{ Draw one 24x24 map tile into the view buffer at (col, row); tile IDs 128 and up come from the second tile set. Nothing
  is drawn from a tile set that is not loaded. }
procedure Copy2DTile(col, row: ShortInt; tile: Byte; unused: ShortInt);
begin
  if tile > C_Tile.ID_MASK then begin
    if MapTiles.SecondSheet <> nil then
      Blit.BlitTileCell(col, row, tile and C_Tile.ID_MASK, 0, GDVars.ds2dMapTilePtr2,
                        GDVars.dsViewImageBufferPtr);
  end else if GDVars.ds2dMapTilePtr <> nil then
    Blit.BlitTileCell(col, row, tile, 0, GDVars.ds2dMapTilePtr, GDVars.dsViewImageBufferPtr);
end;

function SecondSheet: Types.PImgBuf;
begin
  if GDVars.ds2dMapTilePtr2 = nil then
    Blit.LoadPic('sqrpaci', 2, False, 0, GDVars.ds2dMapTilePtr2);
  SecondSheet := GDVars.ds2dMapTilePtr2;
end;

procedure FreeSecondSheet;
begin
  Blit.FreePic(GDVars.ds2dMapTilePtr2);
end;

{ Release both frame buffers of icon-animation slot animIdx; a slot past the table is ignored. }
procedure FreeIconAnim(animIdx: Byte);
begin
  { 25 = High(GDVars.dsIconAnimation) }
  if animIdx > 25 then Exit;
  if GDVars.dsIconAnimation[animIdx, 0] <> nil then
    Blit.FreePic(GDVars.dsIconAnimation[animIdx, 0]);
  if GDVars.dsIconAnimation[animIdx, 1] <> nil then
    Blit.FreePic(GDVars.dsIconAnimation[animIdx, 1]);
end;

{ Load both frames (blocks fileId and fileId+128) of icon-animation slot animIdx, with color 0 transparent. CHEAD and
  CBODY names drop their last character, and a trailing 'T' adds 64 to fileId. Those two, COMSPR and ICON get no disk
  number; ICON frames turn LightMagenta into Black. Any other name gets the virtual disk number appended and both frames
  turn LightMagenta into DarkGray. A slot past the table loads nothing. }
procedure LoadIconAnim(name: string; fileId, animIdx: Byte);
var
  suffix: string[1];
begin
  { 25 = High(GDVars.dsIconAnimation) }
  if animIdx > 25 then Exit;
  if (Copy(name, 1, 5) = 'CHEAD') or (Copy(name, 1, 5) = 'CBODY') then begin
    if UpCase(name[Length(name)]) = 'T' then
      Inc(fileId, 64);
    name := Copy(name, 1, Length(name) - 1);
    suffix := '';
    Blit.LoadPic(name + suffix, fileId, True, 0, GDVars.dsIconAnimation[animIdx, 0]);
    Blit.LoadPic(name + suffix, fileId + 128, True, 0, GDVars.dsIconAnimation[animIdx, 1]);
  end else if (name = 'COMSPR') or (name = 'ICON') then begin
    suffix := '';
    Blit.LoadPic(name + suffix, fileId, True, 0, GDVars.dsIconAnimation[animIdx, 0]);
    Blit.LoadPic(name + suffix, fileId + 128, True, 0, GDVars.dsIconAnimation[animIdx, 1]);
    if name = 'ICON' then begin
      Blit.RemapPic(GDConsts.iconColorIdentity, GDConsts.iconColorPinkToBlack, 0, False,
                    GDVars.dsIconAnimation[animIdx, 0]);
      Blit.RemapPic(GDConsts.iconColorIdentity, GDConsts.iconColorPinkToBlack, 0, False,
                    GDVars.dsIconAnimation[animIdx, 1]);
    end;
  end else begin
    Str(GDVars.virtualDisk, suffix);
    Blit.LoadPic(name + suffix, fileId, True, 0, GDVars.dsIconAnimation[animIdx, 0]);
    Blit.RemapPic(GDConsts.iconColorIdentity, GDConsts.iconColorPinkToDarkGray, 0, False,
                  GDVars.dsIconAnimation[animIdx, 0]);
    Blit.LoadPic(name + suffix, fileId + 128, True, 0, GDVars.dsIconAnimation[animIdx, 1]);
    Blit.RemapPic(GDConsts.iconColorIdentity, GDConsts.iconColorPinkToDarkGray, 0, False,
                  GDVars.dsIconAnimation[animIdx, 1]);
  end;
end;

{ Draw one icon-animation frame at character cell (col*3, row*3): copy the frame into a scratch buffer, mirrored for
  facings past C_Dir.SOUTHEAST, then blit it transparently and clipped into the view buffer. On EGA the transparency
  mask is a quarter of the image size. Nothing is drawn if the frame is not loaded or lies outside the table. }
procedure DrawIconAnimSprite(col, row: ShortInt; facing, frame, animIdx: Byte);
var
  work: Types.PImgBuf;
begin
  { GDVars.dsIconAnimation is [0..25, 0..1] }
  if (animIdx > 25) or (frame > 1) then
    Exit;
  if GDVars.dsIconAnimation[animIdx, frame] = nil then
    Exit;
  with GDVars.dsIconAnimation[animIdx, frame]^ do begin
    Blit.AllocPic(height, width, 1, 1, work);
    if facing > C_Dir.SOUTHEAST then
      Blit.MirrorPic(GDVars.dsIconAnimation[animIdx, frame], work)
    else begin
      Move(data, work^.data, imgSize);
      Move(transp^, work^.transp^, Blit.MaskBytes(imgSize));
    end;
  end;
  Blit.BlitTileClipped(col * 3, row * 3, 0, 1, work, GDVars.dsViewImageBufferPtr);
  Blit.FreePic(work);
end;

end.

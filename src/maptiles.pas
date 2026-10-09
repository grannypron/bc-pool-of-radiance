{ Load terrain tiles and creature icon frames, copy tiles into the view buffer and draw animated icons.

  Tile IDs use seven bits for the index and the high bit to select the second tile-set buffer. }
{$O+,F+,I-} { I/O checking is disabled for the range-error message. }
unit MapTiles;

interface

uses Types, Crt, C_Tile, GDConsts, GDVars, Blit, GameIo, C_Dir;

procedure Load24x24Set(name: string; mult: Byte; unused: ShortInt);

procedure Copy2DTile(col, row: ShortInt; tile: Byte; unused: ShortInt);

procedure FreeIconAnim(animIdx: Byte);

procedure LoadIconAnim(name: string; fileId, animIdx: Byte);

procedure DrawIconAnimSprite(col, row: ShortInt; facing, frame, animIdx: Byte);

implementation

var
  iconAnims: array[0..25, 0..1] of Types.PImgBuf absolute GDVars.dsIconAnimation;
                                        { icon animation frame pairs }
  { 0=CGA 1=EGA 2=Tandy }
  displayMode: Types.TVideoMode absolute GDVars.videoMode;

{ Load the 24x24 tile set <name> (block 1) and, when the first tile-set buffer is allocated, copy all its tiles into
  that buffer starting at tile slot mult. A mult above 127, the last slot, restores the video mode and ends the game
  with a range error. }
procedure Load24x24Set(name: string; mult: Byte; unused: ShortInt);
var
  pic: Types.PImgBuf;
  total: Word;
  offset: Word;
begin
  if mult > 127 then begin
    Blit.RestoreVideoMode;
    WriteLn('Start range error in Load24x24Set');
    GameIo.ExitGame;
  end;
  pic := nil;
  Blit.LoadPic(name, 1, False, 0, pic);
  total := pic^.count * pic^.imgSize;
  offset := mult * pic^.imgSize;
  if GDVars.ds2dMapTilePtr <> nil then
    Move(pic^.data, GDVars.ds2dMapTilePtr^.data[offset], total);
  Blit.FreePic(pic);
end;

{ Draw one 24x24 map tile into the view buffer at (col, row); tile IDs 128 and up come from the second tile set. }
procedure Copy2DTile(col, row: ShortInt; tile: Byte; unused: ShortInt);
begin
  if tile > C_Tile.ID_MASK then
    Blit.BlitTileCell(col, row, tile and C_Tile.ID_MASK, 0, GDVars.ds2dMapTilePtr2,
                      GDVars.dsViewImageBufferPtr)
  else
    Blit.BlitTileCell(col, row, tile, 0, GDVars.ds2dMapTilePtr, GDVars.dsViewImageBufferPtr);
end;

{ Release both frame buffers of icon-animation slot animIdx. }
procedure FreeIconAnim(animIdx: Byte);
var
  i: Integer;
begin
  if iconAnims[animIdx, 0] <> nil then
    Blit.FreePic(iconAnims[animIdx, 0]);
  if iconAnims[animIdx, 1] <> nil then
    Blit.FreePic(iconAnims[animIdx, 1]);
end;

{ Load both frames (blocks fileId and fileId+128) of icon-animation slot animIdx, with color 0 transparent. CHEAD and
  CBODY names drop their last character, and a trailing 'T' adds 64 to fileId. Those two, COMSPR and ICON get no disk
  number; ICON frames turn LightMagenta into Black. Any other name gets the virtual disk number appended and both frames
  turn LightMagenta into DarkGray. }
procedure LoadIconAnim(name: string; fileId, animIdx: Byte);
var
  suffix: string[1];
  ch: Char;
begin
  if (Copy(name, 1, 5) = 'CHEAD') or (Copy(name, 1, 5) = 'CBODY') then begin
    if UpCase(name[Length(name)]) = 'T' then
      Inc(fileId, 64);
    name := Copy(name, 1, Length(name) - 1);
    suffix := '';
    Blit.LoadPic(name + suffix, fileId, True, 0, iconAnims[animIdx, 0]);
    Blit.LoadPic(name + suffix, fileId + 128, True, 0, iconAnims[animIdx, 1]);
  end else if (name = 'COMSPR') or (name = 'ICON') then begin
    suffix := '';
    Blit.LoadPic(name + suffix, fileId, True, 0, iconAnims[animIdx, 0]);
    Blit.LoadPic(name + suffix, fileId + 128, True, 0, iconAnims[animIdx, 1]);
    if name = 'ICON' then begin
      Blit.RemapPic(GDConsts.iconColorIdentity, GDConsts.iconColorPinkToBlack, 0, False, iconAnims[animIdx, 0]);
      Blit.RemapPic(GDConsts.iconColorIdentity, GDConsts.iconColorPinkToBlack, 0, False, iconAnims[animIdx, 1]);
    end;
  end else begin
    Str(GDVars.virtualDisk, suffix);
    Blit.LoadPic(name + suffix, fileId, True, 0, iconAnims[animIdx, 0]);
    Blit.RemapPic(GDConsts.iconColorIdentity, GDConsts.iconColorPinkToDarkGray, 0, False, iconAnims[animIdx, 0]);
    Blit.LoadPic(name + suffix, fileId + 128, True, 0, iconAnims[animIdx, 1]);
    Blit.RemapPic(GDConsts.iconColorIdentity, GDConsts.iconColorPinkToDarkGray, 0, False, iconAnims[animIdx, 1]);
  end;
end;

{ Draw one icon-animation frame at character cell (col*3, row*3): copy the frame into a scratch buffer, mirrored for
  facings past C_Dir.SOUTHEAST, then blit it transparently and clipped into the view buffer. On EGA the transparency
  mask is a quarter of the image size. Nothing is drawn if the frame is not loaded. }
procedure DrawIconAnimSprite(col, row: ShortInt; facing, frame, animIdx: Byte);
var
  work: Types.PImgBuf;
begin
  if iconAnims[animIdx, frame] = nil then
    Exit;
  with iconAnims[animIdx, frame]^ do begin
    Blit.AllocPic(height, width, 1, 1, work);
    if facing > C_Dir.SOUTHEAST then
      Blit.MirrorPic(iconAnims[animIdx, frame], work)
    else begin
      Move(data, work^.data, imgSize);
      if displayMode = Types.vmEGA then
        Move(transp^, work^.transp^, imgSize div 4)
      else
        Move(transp^, work^.transp^, imgSize);
    end;
  end;
  Blit.BlitTileClipped(col * 3, row * 3, 0, 1, work, GDVars.dsViewImageBufferPtr);
  Blit.FreePic(work);
end;

end.

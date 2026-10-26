{ Load terrain tiles and creature icon frames, copy tiles into the view buffer and draw animated icons.

  Tile IDs use seven bits for the index and the high bit to select the second tile-set buffer. }
{$O+,F+}
{$I COMPILER.INC}
unit MapTiles;

interface

uses Types;

const
  { The combat icon slots (GameVars.iconAnimation): 0..7 the party's, 8..12 the monster kinds (LOAD MONSTER takes the
    next, CLEAR MONSTERS starts them again), 13..24 the combat sprites (COMSPR) and 25 the cursor. }
  FIRST_MONSTER_ICON = 8;
  LAST_MONSTER_ICON = 12;
  { Outside combat, slots 9..11 hold the party's wilderness icon, ICON blocks 0..2 (LoadWildIcons): the animation
    MapView.DisplayWildMapView steps through. }
  FIRST_WILD_ICON = 9;

var
  { 2D map tile set image buffer 2; bit 7 of a tile id selects it }
  mapTilePtr2: Types.PImgBuf;

procedure Load24x24Set(name: string; mult: Byte);

procedure Copy2DTile(col, row: ShortInt; tile: Byte);

{ The second 24x24 tile set (SQRPACI block 2, tile IDs 128 and up), loaded into mapTilePtr2 the first time
  it is needed: only the wilderness and the ending draw from it, so it is not loaded at start-up and combat frees it
  (FreeSecondSheet). Nil when it does not load. }
function SecondSheet: Types.PImgBuf;

{ Free the second tile set, for SecondSheet to load again when it is next needed. }
procedure FreeSecondSheet;

procedure FreeIconAnim(animIdx: Byte);

procedure LoadIconAnim(name: string; fileId, animIdx: Byte);

{ Load the party's wilderness icon, ICON blocks 0..2, into slots FIRST_WILD_ICON.. (LoadIconAnim). }
procedure LoadWildIcons;

procedure DrawIconAnimSprite(col, row: ShortInt; facing, frame, animIdx: Byte);

implementation

uses Crt, C_TILE, GameDefs, GameVars, Blit, GameIo, C_DIR;

{ Load the 24x24 tile set <name> (block 1) and, when the first tile-set buffer is allocated, copy its tiles into that
  buffer starting at tile slot mult, as many as fit. A mult above 127, the last slot, restores the video mode and ends
  the game with a range error. Nothing is copied if the set does not load. }
procedure Load24x24Set(name: string; mult: Byte);
var
  pic: Types.PImgBuf;
  dst: Types.PImgBuf;
  frame: Word;
  i: Integer;
  tiles: Integer;
begin
  if mult > 127 then
    GameIo.FatalError('Start range error in Load24x24Set');
  pic := nil;
  Blit.LoadPic(name, 1, False, 0, pic);
  if pic = nil then Exit;
  if GameVars.mapTilePtr <> nil then begin
    tiles := pic^.count;
    if mult + tiles > Blit.FrameCount(GameVars.mapTilePtr) then
      tiles := Blit.FrameCount(GameVars.mapTilePtr) - mult;
    { a tile at a time, as the sheet may continue in a further block (Blit.FrameBlock) }
    for i := 0 to tiles - 1 do begin
      dst := GameVars.mapTilePtr;
      frame := mult + i;
      Blit.FrameBlock(dst, frame);
      Move(pic^.data[i * pic^.imgSize], dst^.data[frame * dst^.imgSize], pic^.imgSize);
    end;
  end;
  Blit.FreePic(pic);
end;

{ Draw one 24x24 map tile into the view buffer at (col, row); tile IDs 128 and up come from the second tile set. Nothing
  is drawn from a tile set that is not loaded. }
procedure Copy2DTile(col, row: ShortInt; tile: Byte);
begin
  if tile > C_TILE.ID_MASK then begin
    if MapTiles.SecondSheet <> nil then
      Blit.BlitTileCell(col, row, tile and C_TILE.ID_MASK, 0, mapTilePtr2, GameVars.viewBuffer);
  end else if GameVars.mapTilePtr <> nil then
    Blit.BlitTileCell(col, row, tile, 0, GameVars.mapTilePtr, GameVars.viewBuffer);
end;

function SecondSheet: Types.PImgBuf;
begin
  if mapTilePtr2 = nil then
    Blit.LoadPic('sqrpaci', 2, False, 0, mapTilePtr2);
  SecondSheet := mapTilePtr2;
end;

procedure FreeSecondSheet;
begin
  Blit.FreePic(mapTilePtr2);
end;

{ Release both frame buffers of icon-animation slot animIdx; a slot past the table is ignored. }
procedure FreeIconAnim(animIdx: Byte);
begin
  if animIdx > C_TILE.ICON_LAST then Exit;
  Blit.FreePic(GameVars.iconAnimation[animIdx, 0]);
  Blit.FreePic(GameVars.iconAnimation[animIdx, 1]);
end;

{ Load both frames (blocks fileId and fileId+128) of icon-animation slot animIdx, with color 0 transparent. CHEAD and
  CBODY names drop their last character, and a trailing 'T' adds 64 to fileId. Those two, COMSPR and ICON get no disk
  number; ICON frames turn LightMagenta into Black. Any other name gets the virtual disk number appended and both frames
  turn LightMagenta into DarkGray. A slot past the table loads nothing. }
procedure LoadIconAnim(name: string; fileId, animIdx: Byte);
const
  { The transparent color LightMagenta made DarkGray, for every icon not ICON's }
  iconColorPinkToDarkGray: Types.TColorTab = (
    { Black -> Black }
    Black,
    { Blue -> Blue }
    Blue,
    { Green -> Green }
    Green,
    { Cyan -> Cyan }
    Cyan,
    { Red -> Red }
    Red,
    { Magenta -> Magenta }
    Magenta,
    { Brown -> Brown }
    Brown,
    { LightGray -> LightGray }
    LightGray,
    { DarkGray -> DarkGray }
    DarkGray,
    { LightBlue -> LightBlue }
    LightBlue,
    { LightGreen -> LightGreen }
    LightGreen,
    { LightCyan -> LightCyan }
    LightCyan,
    { LightRed -> LightRed }
    LightRed,
    { LightMagenta -> DarkGray }
    DarkGray,
    { Yellow -> Yellow }
    Yellow,
    { White -> White }
    White);
var
  disk: string[1];
  frame: Byte;
begin
  if animIdx > C_TILE.ICON_LAST then Exit;
  disk := '';
  if (Copy(name, 1, 5) = 'CHEAD') or (Copy(name, 1, 5) = 'CBODY') then begin
    if UpCase(name[Length(name)]) = 'T' then
      Inc(fileId, 64);
    name := Copy(name, 1, Length(name) - 1);
  end else if (name <> 'COMSPR') and (name <> 'ICON') then
    Str(GameVars.diskIndex, disk);
  for frame := 0 to 1 do begin
    Blit.LoadPic(name + disk, fileId + 128 * frame, True, 0, GameVars.iconAnimation[animIdx, frame]);
    if name = 'ICON' then
      Blit.RemapPic(GameDefs.colorIdentity, GameDefs.colorPinkToBlack, 0, False, GameVars.iconAnimation[animIdx, frame])
    else if disk <> '' then
      Blit.RemapPic(GameDefs.colorIdentity, iconColorPinkToDarkGray, 0, False, GameVars.iconAnimation[animIdx, frame]);
  end;
end;

procedure LoadWildIcons;
var
  i: Byte;
begin
  for i := 0 to 2 do
    MapTiles.LoadIconAnim('ICON', i, FIRST_WILD_ICON + i);
end;

{ Draw one icon-animation frame at character cell (col*3, row*3): copy the frame into a scratch buffer, mirrored for
  facings past C_DIR.SOUTHEAST, then blit it transparently and clipped into the view buffer. On EGA the transparency
  mask is a quarter of the image size. Nothing is drawn if the frame is not loaded or lies outside the table. }
procedure DrawIconAnimSprite(col, row: ShortInt; facing, frame, animIdx: Byte);
var
  work: Types.PImgBuf;
begin
  if (animIdx > C_TILE.ICON_LAST) or (frame > 1) then
    Exit;
  if GameVars.iconAnimation[animIdx, frame] = nil then
    Exit;
  with GameVars.iconAnimation[animIdx, frame]^ do begin
    Blit.AllocPic(height, width, 1, 1, work);
    if facing > C_DIR.SOUTHEAST then
      Blit.MirrorPic(GameVars.iconAnimation[animIdx, frame], work)
    else begin
      Move(data, work^.data, imgSize);
      Move(transp^, work^.transp^, Blit.MaskBytes(imgSize));
    end;
  end;
  Blit.BlitTileClipped(col * 3, row * 3, 0, 1, work, GameVars.viewBuffer);
  Blit.FreePic(work);
end;

begin
  { Turbo Pascal clears no variable }
  mapTilePtr2 := nil;
end.

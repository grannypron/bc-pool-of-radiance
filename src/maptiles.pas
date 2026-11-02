{ Load terrain tiles and creature icon frames, copy tiles into the view buffer and draw animated icons.

  Tile IDs use seven bits for the index and the high bit to select the second tile-set buffer. }
{$O+,F+}
{$I COMPILER.INC}
unit MapTiles;

interface

uses Types;

const
  { Combat icon slots: 0..7 are party members, 8..12 are monster kinds,
    13..24 are COMSPR sprites, and 25 is the cursor. }
  FIRST_MONSTER_ICON = 8;
  LAST_MONSTER_ICON = 12;
  { Outside combat, slots 9..11 hold the three wilderness-icon frames. }
  FIRST_WILD_ICON = 9;
  { combat's first tile slot for the random-feature set, RANDCOM.DAX (CombatSt.LoadCombatTileSet): terrains 26..31 }
  FEATURE_SLOT = 34;

var
  { 2D map tile set image buffer 2; bit 7 of a tile id selects it }
  mapTilePtr2: Types.PImgBuf;
  { Cloudkill's cloud in combat (#1193): RANDCOM.DAX's stinking cloud frame alone, recoloured; nil outside combat }
  cloudkillArt: Types.PImgBuf;

procedure Load24x24Set(name: string; mult: Byte);

procedure Copy2DTile(col, row: ShortInt; tile: Byte);

{ Copy2DTile, but the tile is clipped to the view buffer: the wide wilderness view's last tile is cut off (#1186). }
procedure Copy2DTileClipped(col, row: ShortInt; tile: Byte);

{ Draw combat terrain terr at (col, row) as Copy2DTile draws its tile (GameDefs.terrainInfo), but Cloudkill's cloud
  (C_TERR.CLOUDKILL) from cloudkillArt, while it is loaded. }
procedure DrawTerrain(col, row: ShortInt; terr: Byte);

{ Load cloudkillArt for a fight: PoR's tiles have no Cloudkill cloud, so it is the stinking cloud's tile with its light
  green turned yellow, the PHB's "ghastly yellowish green" vapours. }
procedure LoadCloudkillArt;

{ Free cloudkillArt after a fight. }
procedure FreeCloudkillArt;

{ Lazily loads the second 24x24 tile sheet (SQRPACI block 2, IDs 128 and up).
  Only the wilderness and ending need it, and combat frees it. Returns nil if
  it cannot be loaded. }
function SecondSheet: Types.PImgBuf;

{ Load the second tile set now, if it is not loaded, as SecondSheet would when it is next needed. }
procedure LoadSecondSheet;

{ Free the second tile set, for SecondSheet to load again when it is next needed. }
procedure FreeSecondSheet;

procedure FreeIconAnim(animIdx: Byte);

procedure LoadIconAnim(name: string; fileId, animIdx: Byte);

{ Load the party's wilderness icon, ICON blocks 0..2, into slots FIRST_WILD_ICON.. (LoadIconAnim). }
procedure LoadWildIcons;

procedure DrawIconAnimSprite(col, row: ShortInt; facing, frame, animIdx: Byte);

implementation

uses Crt, C_TILE, C_TERR, GameDefs, GameVars, Blit, GameIo, C_DIR;

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

{ Draw one 24x24 map tile into the view buffer at (col, row), clipped to it when clip is set; tile IDs 128 and up come
  from the second tile set. Nothing is drawn from a tile set that is not loaded. }
procedure DrawTile(col, row: ShortInt; tile: Byte; clip: Boolean);
var
  sheet: Types.PImgBuf;
begin
  if tile > C_TILE.ID_MASK then
    sheet := MapTiles.SecondSheet
  else
    sheet := GameVars.mapTilePtr;
  if sheet = nil then Exit;
  if clip then
    Blit.BlitTileClipped(col, row, tile and C_TILE.ID_MASK, 0, sheet, GameVars.viewBuffer)
  else
    Blit.BlitTileCell(col, row, tile and C_TILE.ID_MASK, 0, sheet, GameVars.viewBuffer);
end;

procedure Copy2DTile(col, row: ShortInt; tile: Byte);
begin
  MapTiles.DrawTile(col, row, tile, False);
end;

procedure Copy2DTileClipped(col, row: ShortInt; tile: Byte);
begin
  MapTiles.DrawTile(col, row, tile, True);
end;

procedure DrawTerrain(col, row: ShortInt; terr: Byte);
begin
  if (terr = C_TERR.CLOUDKILL) and (cloudkillArt <> nil) then
    Blit.BlitTileCell(col, row, 0, 0, cloudkillArt, GameVars.viewBuffer)
  else
    MapTiles.Copy2DTile(col, row, GameDefs.terrainInfo[terr].tileId);
end;

procedure LoadCloudkillArt;
var
  pic: Types.PImgBuf;
  src: Types.PImgBuf;
  frame: Word;
  toT: Types.TColorTab;
begin
  Blit.FreePic(cloudkillArt);
  pic := nil;
  Blit.LoadPic('RandCom', 1, False, 0, pic);
  if pic = nil then Exit;
  { the stinking cloud's frame alone, so the fight holds one tile more and not the whole set }
  Blit.AllocPic(pic^.height, pic^.width, 1, 0, cloudkillArt);
  cloudkillArt^.map := pic^.map;
  src := pic;
  frame := GameDefs.terrainInfo[C_TERR.STINKING_CLOUD].tileId - FEATURE_SLOT;
  Blit.FrameBlock(src, frame);
  Move(src^.data[frame * src^.imgSize], cloudkillArt^.data, src^.imgSize);
  Blit.FreePic(pic);
  toT := GameDefs.colorIdentity;
  toT[LightGreen] := Yellow;
  Blit.RemapPic(GameDefs.colorIdentity, toT, 0, False, cloudkillArt);
end;

procedure FreeCloudkillArt;
begin
  Blit.FreePic(cloudkillArt);
end;

function SecondSheet: Types.PImgBuf;
begin
  MapTiles.LoadSecondSheet;
  SecondSheet := mapTilePtr2;
end;

procedure LoadSecondSheet;
begin
  if mapTilePtr2 = nil then
    Blit.LoadPic('sqrpaci', 2, False, 0, mapTilePtr2);
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
  cloudkillArt := nil;
end.

{ Picture loading, portrait composition and 3D sprite display. PIC and FINAL frames after the first are XOR deltas
  against the first frame. }
{$O+,F+}
{$I COMPILER.INC}
unit Portrait;

interface

uses Types;

const
  { a portrait's body is drawn this many rows below its head }
  BODY_ROW_OFFSET = 5;

procedure DisplayImageBuf(col, row: Integer; anim: Boolean; pic: Types.PImgBuf);

procedure LoadAnimation(name: Types.TStr8; picId: Byte; transp: Byte; var a: Types.TAnimRec);

procedure FreeAnimation(var a: Types.TAnimRec);

procedure DisplayCharPortrait;

{ True when the player portraits can be shown on the current disk: on disk 3, whose HEAD3.DAX and BODY3.DAX hold them,
  or on any disk once the merged HEAD.DAX and BODY.DAX are read in place of its own. }
function PlayerPortraitsHere: Boolean;

{ How many GameDefs.headTbl entries (bodyTbl entries when body is set) the portrait picker offers on the current disk:
  all of them once the merged HEAD.DAX and BODY.DAX are read in place of its own, otherwise the ones HEAD3.DAX and
  BODY3.DAX hold (DISK3_HEADS and DISK3_BODIES). }
function PlayerPortraitCount(body: Boolean): Byte;

procedure DisplayPortraitBufs(col, row: Byte; both: Boolean);

procedure LoadPortraitBufs(headId, bodyId: Byte);

procedure Show3DSprite(dist: Byte; var a: Types.TAnimRec);

{ Forget which archive and picture are cached, so the next picture is loaded afresh, for a new game
  (GameInit.ResetGameState). }
procedure ResetGame;

implementation

uses {$IFDEF FPC}TpCompat, {$ENDIF}Crt, GameDefs, GameVars, Blit, VidOps, GameIo, Border, DaxIo, StrUtil;

var
  { Archive of the cached picture: name and virtual-disk digit, as LoadAnimation opens it. }
  picArcName: String[9];
  { picture id loaded from picArcName; 255 invalidates the pair }
  picArcId: Byte;

{ Draw pic at (col, row). An animation frame is composited transparently through the clipped blitter into the view
  buffer at (col-1, row-1) and the view is flushed; a plain image goes straight to the screen through Blit.ShowPic. A
  nil pic draws nothing. }
procedure DisplayImageBuf(col, row: Integer; anim: Boolean; pic: Types.PImgBuf);
begin
  if pic <> nil then
    if anim then begin
      Blit.BlitTileClipped(col - 1, row - 1, 0, 1, pic, GameVars.viewImageBufferPtr);
      Blit.FlushView;
    end else
      Blit.ShowPic(col, row, pic);
end;

{ Load picture picId of <name><disk>.DAX into a, unless that archive and id are already the cached picture
  (picArcName/picArcId); a load that ends with no frames is not cached. PIC 1 is capped at 4 frames, and any
  picture at the 8 the record holds. A frame is loaded only while MaxAvail is at least 3900 and covers what loading it
  allocates (FrameNeed): loaded frames are stored in order and count becomes the number loaded, a skipped frame's data
  is stepped over, and without room for the first frame (which the others are XORed with for PIC and FINAL) nothing is
  loaded. A frame with no height or width, or one that runs past the block, ends the loading, keeping the frames before
  it; a later frame is XORed only over as many bytes as the first frame has. An odd transp remaps LightMagenta to Black
  outside CGA. }
procedure LoadAnimation(name: Types.TStr8; picId: Byte; transp: Byte; var a: Types.TAnimRec);
var
  sz: Word;
  buf: Types.PByteArr;
  offset: Word;
  f: Byte;
  h: Word;
  w: Word;
  { name and the disk's digit: the archive }
  arc: String[9];
  xorBuf: Types.PByteArr;
  j: Word;
  planeSz: Word;
  isPic: Boolean;
  gotXor: Boolean;
  xorSz: Word;
  xorLast: Word;
  loaded: Byte;
  stop: Boolean;
  fr: Types.PImgBuf;

  { Bytes loading frame f of h rows by w columns allocates at once: the picture (Blit.AllocPic), its mask when transp
    is odd and, outside CGA, RemapPic's scratch copy, and the XOR buffer for frame 1 of a PIC or FINAL; plus 8 per
    allocation for the heap's rounding. }
  function FrameNeed: LongInt;
  var
    frameSz: LongInt;
    need: LongInt;
  begin
    frameSz := Blit.FrameBytes(h, w);
    need := SizeOf(fr^) - SizeOf(fr^.data) + frameSz + 8;
    if transp and 1 > 0 then begin
      Inc(need, Blit.MaskBytes(frameSz) + 8);
      { RemapPic's scratch picture, with 16 colours }
      if Blit.ColourCount = 16 then
        Inc(need, SizeOf(fr^) - SizeOf(fr^.data) + frameSz + 8);
    end;
    if isPic and (f = 1) then
      { the XOR buffer: one DAX frame, 4 bytes a cell row }
      Inc(need, LongInt(h) * w * 4 + 8);
    FrameNeed := need;
  end;

begin
  arc := name + StrUtil.NumStr(GameVars.virtualDisk);
  { the cached picture is the one a holds, when a holds any }
  if (a.count > 0) and (arc = picArcName) and (picId = picArcId) then Exit;
  Portrait.FreeAnimation(a);
  isPic := (name = 'PIC') or (name = 'FINAL');
  DaxIo.LoadDax(arc, '.dax', picId, sz, buf);
  if sz = 0 then Exit;
  offset := 0;
  gotXor := False;
  with a do begin
    count := buf^[offset];
    if (name = 'PIC') and (picId = 1) then
      if count > 4 then count := 4;
    if count > 8 then count := 8;
    Inc(offset);
    current := 1;
    loaded := 0;
    stop := False;
    f := 1;
    while (f <= count) and not stop do begin
      { a truncated or corrupt archive: the frame's header must be in the block }
      if LongInt(offset) + SizeOf(frames[1].time) + SizeOf(h) + SizeOf(w) > sz then
        stop := True
      else begin
        Move(buf^[offset], frames[loaded + 1].time, SizeOf(frames[loaded + 1].time));
        Inc(offset, SizeOf(frames[loaded + 1].time));
        Move(buf^[offset], h, SizeOf(h));
        Inc(offset, SizeOf(h));
        Move(buf^[offset], w, SizeOf(w));
        Inc(offset, SizeOf(w));
        { and the rest of it and its h * w * 4 bytes of pixels, with neither size 0 }
        if (h = 0) or (w = 0) or (LongInt(offset) + SizeOf(fr^.originX) + SizeOf(fr^.originY) + SizeOf(fr^.count) +
            SizeOf(fr^.map) + LongInt(h) * w * 4 > sz) then
          stop := True;
      end;
      if stop then
        { the frames before it stay loaded }
      else if (MaxAvail >= 3900) and (MaxAvail >= FrameNeed) then begin
        Inc(loaded);
        Blit.AllocPic(h, w, 1, transp, frames[loaded].pic);
        with frames[loaded].pic^ do begin
          Move(buf^[offset], originX, SizeOf(originX));
          Inc(offset, SizeOf(originX));
          Move(buf^[offset], originY, SizeOf(originY));
          Inc(offset, SizeOf(originY) + SizeOf(count));
          Move(buf^[offset], map, SizeOf(map));
          Inc(offset, SizeOf(map));
        end;
        { a DAX frame is 4 bytes a cell row in every video mode }
        planeSz := frames[loaded].pic^.height * frames[loaded].pic^.width * 4 - 1;
        if isPic then
          if f = 1 then begin
            xorSz := planeSz + 1;
            GetMem(xorBuf, xorSz);
            Move(buf^[offset], xorBuf^, xorSz);
            gotXor := True;
          end else begin
            { no further than the first frame's bytes, should a later frame be larger }
            xorLast := planeSz;
            if xorLast > xorSz - 1 then
              xorLast := xorSz - 1;
            for j := offset to offset + xorLast do
              buf^[j] := buf^[j] xor xorBuf^[j - offset];
          end;
        VidOps.ExpandPicFrames(buf, offset, 0, frames[loaded].pic);
        if (transp and 1 > 0) and (Blit.ColourCount = 16) then
          Blit.RemapPic(GameDefs.colorIdentity, GameDefs.colorPinkToBlack, 0, False, frames[loaded].pic);
        Inc(offset, planeSz + 1);
      end else if f = 1 then
        { the other frames are drawn over, or XORed with, the first }
        stop := True
      else
        { step over the frame: origin, count, colour map and h * w * 4 bytes of pixels }
        Inc(offset, SizeOf(fr^.originX) + SizeOf(fr^.originY) + SizeOf(fr^.count) + SizeOf(fr^.map) + h * w * 4);
      Inc(f);
    end;
    count := loaded;
  end;
  { only a picture with frames is cached, so one that loaded none is tried again (SSI cached it and kept it blank,
    #726) }
  if loaded > 0 then begin
    picArcName := arc;
    picArcId := picId;
  end;
  if isPic and gotXor then FreeMem(xorBuf, xorSz);
  FreeMem(buf, sz);
end;

{ Free every animation frame, clear the record and invalidate the picture cache. }
procedure FreeAnimation(var a: Types.TAnimRec);
var
  k: ShortInt;
begin
  with a do
    for k := 1 to count do
      Blit.FreePic(frames[k].pic);
  FillChar(a, SizeOf(a), 0);
  picArcName[0] := #0;
  picArcId := 255;
end;

{ Draw a bordered window at the top right, then the current character's portrait in it, its head and body numbers mapped
  through GameDefs.headTbl/bodyTbl. Does nothing when either number is 0 or past its table. }
procedure DisplayCharPortrait;
begin
  with GameVars.curChar^ do
    if (portraitHead = 0) or (portraitBody = 0) or (portraitHead > SizeOf(GameDefs.headTbl)) or
        (portraitBody > SizeOf(GameDefs.bodyTbl)) then Exit;
  Border.DrawWindow(28, 1, 38, 11, 0, Black, '');
  with GameVars.curChar^ do begin
    Portrait.LoadPortraitBufs(GameDefs.headTbl[portraitHead], GameDefs.bodyTbl[portraitBody]);
    Portrait.DisplayPortraitBufs(28, 1, True);
  end;
end;

{ True when this disk's HEAD and BODY loads read the merged HEAD.DAX and BODY.DAX, which hold every head and body. }
function MergedPortraits: Boolean;
begin
  MergedPortraits := (DaxIo.ArchiveName('HEAD' + StrUtil.NumStr(GameVars.virtualDisk)) = 'HEAD') and
                     (DaxIo.ArchiveName('BODY' + StrUtil.NumStr(GameVars.virtualDisk)) = 'BODY');
end;

function PlayerPortraitsHere: Boolean;
begin
  PlayerPortraitsHere := (GameVars.virtualDisk = 3) or MergedPortraits;
end;

function PlayerPortraitCount(body: Boolean): Byte;
const
  { how many of the first headTbl and bodyTbl entries HEAD3.DAX and BODY3.DAX hold }
  DISK3_HEADS = 21;
  DISK3_BODIES = 16;
begin
  if MergedPortraits then begin
    if body then
      PlayerPortraitCount := SizeOf(GameDefs.bodyTbl)
    else
      PlayerPortraitCount := SizeOf(GameDefs.headTbl);
  end else if body then
    PlayerPortraitCount := DISK3_BODIES
  else
    PlayerPortraitCount := DISK3_HEADS;
end;

{ Load headId from HEAD<disk>.DAX and bodyId from BODY<disk>.DAX into the head and body portrait cache slots, skipping
  an id that is 255 or already loaded from this disk. A load that finds nothing leaves its slot invalid (255). }
procedure LoadPortraitBufs(headId, bodyId: Byte);

  { Load picture id of archive (HEAD or BODY) into portrait cache slot. }
  procedure LoadSlot(slot: Byte; archive: Types.TStr8; id: Byte);
  begin
    if id = 255 then Exit;
    with GameVars.portraitCache[slot] do
      if (pictureId <> id) or (disk <> GameVars.virtualDisk) then begin
        Blit.LoadPic(archive + StrUtil.NumStr(GameVars.virtualDisk), id, False, 0, pic);
        if pic <> nil then begin
          pictureId := id;
          disk := GameVars.virtualDisk;
        end else
          pictureId := 255;
      end;
  end;

begin
  LoadSlot(1, 'HEAD', headId);
  LoadSlot(2, 'BODY', bodyId);
end;

{ Draw the cached portrait at (col, row): its head, and when both is True its body five character rows below. }
procedure DisplayPortraitBufs(col, row: Byte; both: Boolean);
begin
  Portrait.DisplayImageBuf(col, row, False, GameVars.portraitCache[1].pic);
  if both then
    Portrait.DisplayImageBuf(col, row + Portrait.BODY_ROW_OFFSET, False, GameVars.portraitCache[2].pic);
end;

{ Draw frame dist (1..3, by view distance) of a into the view buffer at its origin + 2, then flush. Any other dist
  restores the video mode, prints an error and exits the game. }
procedure Show3DSprite(dist: Byte; var a: Types.TAnimRec);
begin
  if (dist < 1) or (dist > 3) then
    GameIo.FatalError('Illegal range in Show3DSprite.');
  if a.frames[dist].pic <> nil then begin
    with a.frames[dist].pic^ do
      Blit.BlitTileClipped(originX + 3 - 1, originY + 3 - 1, 0, 1, a.frames[dist].pic, GameVars.viewImageBufferPtr);
    Blit.FlushView;
  end;
end;

procedure ResetGame;
begin
  picArcName[0] := #0;
  picArcId := 255;
end;

end.

{ Picture loading, portrait composition and 3D sprite display. PIC and FINAL frames after the first are XOR deltas
  against the first frame. }
{$O+,F+,I-} { I/O checking is disabled for the sprite range-error message. }
unit Portrait;

interface

uses Types;

procedure DisplayImageBuf(col, row: Integer; anim: Boolean; pic: Types.PImgBuf);

procedure LoadAnimation(name: Types.TStr8; picId: Byte; transp: Byte; var a: Types.TAnimRec);

procedure FreeAnimation(var a: Types.TAnimRec);

procedure DisplayCharPortrait;

{ True when the player portraits can be shown on the current disk: on disk 3, whose HEAD3.DAX and BODY3.DAX hold them,
  or on any disk once the merged HEAD.DAX and BODY.DAX are read in place of its own. }
function PlayerPortraitsHere: Boolean;

{ How many GDConsts.headTbl entries (bodyTbl entries when body is set) the portrait picker offers on the current disk:
  all of them once the merged HEAD.DAX and BODY.DAX are read in place of its own, otherwise the ones HEAD3.DAX and
  BODY3.DAX hold (GDConsts.DISK3_HEADS and DISK3_BODIES). }
function PlayerPortraitCount(body: Boolean): Byte;

procedure DisplayPortraitBufs(col, row: Byte; both: Boolean);

procedure LoadPortraitBufs(headId, bodyId: Byte);

procedure Show3DSprite(dist: Byte; a: Types.TAnimRec);

implementation

uses Crt, GDConsts, GDVars, Blit, GameIo, Border, DaxIo;

{ Draw pic at (col, row). An animation frame is composited transparently through the clipped blitter into the view
  buffer at (col-1, row-1) and the view is flushed; a plain image goes straight to the screen through Blit.ShowPic. A
  nil pic draws nothing. }
procedure DisplayImageBuf(col, row: Integer; anim: Boolean; pic: Types.PImgBuf);
begin
  if pic <> nil then
    if anim then begin
      Blit.BlitTileClipped(col - 1, row - 1, 0, 1, pic, GDVars.dsViewImageBufferPtr);
      Blit.FlushView;
    end else
      Blit.ShowPic(col, row, pic);
end;

{ Draw a portrait head at (col, row). }
procedure DisplayPortraitHead(col, row: Byte; pic: Types.PImgBuf);
begin
  Portrait.DisplayImageBuf(col, row, False, pic);
end;

{ Draw a portrait body five character rows below (col, row), under the head drawn there. }
procedure DisplayPortraitBody(col, row: Byte; pic: Types.PImgBuf);
begin
  Portrait.DisplayImageBuf(col, row + 5, False, pic);
end;

{ Load picture picId of <name><disk>.DAX into a, unless that archive and id are already the cached picture
  (GDVars.picArcName/picArcId); a load that finds nothing is not cached. PIC 1 is capped at 4 frames, and any picture
  at the 8 the record holds. A frame is loaded only while MaxAvail is at least 3900 and covers what loading it
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
  diskCh: String[1];
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
    frameSz := LongInt(h) * w * 2;
    if GDVars.videoMode <> Types.vmCGA then
      frameSz := frameSz * 2;
    need := SizeOf(fr^) - SizeOf(fr^.data) + frameSz + 8;
    if transp and 1 > 0 then begin
      if GDVars.videoMode = Types.vmEGA then
        Inc(need, frameSz div 4 + 8)
      else
        Inc(need, frameSz + 8);
      if GDVars.videoMode <> Types.vmCGA then
        Inc(need, SizeOf(fr^) - SizeOf(fr^.data) + frameSz + 8);
    end;
    if isPic and (f = 1) then
      { planeSz + 1: twice the frame on CGA }
      if GDVars.videoMode = Types.vmCGA then
        Inc(need, frameSz * 2 + 8)
      else
        Inc(need, frameSz + 8);
    FrameNeed := need;
  end;

begin
  Str(LongInt(GDVars.virtualDisk), diskCh);
  if (name + diskCh = GDVars.picArcName) and (picId = GDVars.picArcId) then Exit;
  Portrait.FreeAnimation(a);
  isPic := (name = 'PIC') or (name = 'FINAL');
  DaxIo.LoadDax(name + diskCh, '.dax', picId, sz, buf);
  if sz = 0 then Exit;
  GDVars.picArcName := name + diskCh;
  GDVars.picArcId := picId;
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
        if GDVars.videoMode = Types.vmCGA then
          planeSz := frames[loaded].pic^.imgSize * 2 - 1
        else
          planeSz := frames[loaded].pic^.imgSize - 1;
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
        Blit.ExpandPicFrames(buf, offset, Boolean(transp), 0, frames[loaded].pic);
        if (transp and 1 > 0) and (GDVars.videoMode <> Types.vmCGA) then
          Blit.RemapPic(GDConsts.animRemapFrom, GDConsts.animRemapTo, 0, False, frames[loaded].pic);
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
  if isPic and gotXor then FreeMem(xorBuf, xorSz);
  FreeMem(buf, sz);
end;

{ Free every animation frame, clear the record and invalidate the picture cache. The loop counter is the shared
  GDVars.dsCurrentPictureNumber. }
procedure FreeAnimation(var a: Types.TAnimRec);
begin
  with a do
    for GDVars.dsCurrentPictureNumber := 1 to count do
      Blit.FreePic(frames[GDVars.dsCurrentPictureNumber].pic);
  FillChar(a, SizeOf(a), 0);
  GDVars.picArcName[0] := #0;
  GDVars.picArcId := 255;
end;

{ Draw a bordered window at the top right, then the current character's portrait in it, its head and body numbers mapped
  through GDConsts.headTbl/bodyTbl. Does nothing when either number is 0 or past its table. Note: s1 and s2 are built
  and never used. }
procedure DisplayCharPortrait;
var
  s1: String[3];
  s2: String[3];
begin
  with GDVars.curChar^ do
    if (portraitHead = 0) or (portraitBody = 0) or (portraitHead > SizeOf(GDConsts.headTbl)) or
        (portraitBody > SizeOf(GDConsts.bodyTbl)) then Exit;
  Border.DrawWindow(28, 1, 38, 11, 0, Black, '');
  with GDVars.curChar^ do begin
    Str(LongInt(GDConsts.headTbl[portraitHead]), s1);
    Str(LongInt(GDConsts.bodyTbl[portraitBody]), s2);
    Portrait.LoadPortraitBufs(GDConsts.headTbl[portraitHead], GDConsts.bodyTbl[portraitBody]);
    Portrait.DisplayPortraitBufs(28, 1, True);
  end;
end;

{ True when this disk's HEAD and BODY loads read the merged HEAD.DAX and BODY.DAX, which hold every head and body. }
function MergedPortraits: Boolean;
var
  diskCh: String[1];
begin
  Str(LongInt(GDVars.virtualDisk), diskCh);
  MergedPortraits := (DaxIo.ArchiveName('HEAD' + diskCh) = 'HEAD') and (DaxIo.ArchiveName('BODY' + diskCh) = 'BODY');
end;

function PlayerPortraitsHere: Boolean;
begin
  PlayerPortraitsHere := (GDVars.virtualDisk = 3) or MergedPortraits;
end;

function PlayerPortraitCount(body: Boolean): Byte;
begin
  if MergedPortraits then begin
    if body then
      PlayerPortraitCount := SizeOf(GDConsts.bodyTbl)
    else
      PlayerPortraitCount := SizeOf(GDConsts.headTbl);
  end else if body then
    PlayerPortraitCount := GDConsts.DISK3_BODIES
  else
    PlayerPortraitCount := GDConsts.DISK3_HEADS;
end;

{ Load headId from HEAD<disk>.DAX and bodyId from BODY<disk>.DAX into the head and body portrait cache slots, skipping
  an id that is 255 or already loaded from this disk. A load that finds nothing leaves its slot invalid (255). }
procedure LoadPortraitBufs(headId, bodyId: Byte);
var
  diskCh: String[1];
begin
  Str(LongInt(GDVars.virtualDisk), diskCh);
  if headId <> 255 then
    if (GDVars.dsPortraitCache[1].pictureId = 255) or (GDVars.dsPortraitCache[1].pictureId <> headId) or
        (GDVars.dsPortraitCache[1].disk <> GDVars.virtualDisk) then begin
      Blit.LoadPic('HEAD' + diskCh, headId, False, 0, GDVars.dsPortraitCache[1].pic);
      if GDVars.dsPortraitCache[1].pic <> nil then begin
        GDVars.dsPortraitCache[1].pictureId := headId;
        GDVars.dsPortraitCache[1].disk := GDVars.virtualDisk;
      end else
        GDVars.dsPortraitCache[1].pictureId := 255;
    end;
  if bodyId <> 255 then
    if (GDVars.dsPortraitCache[2].pictureId = 255) or (GDVars.dsPortraitCache[2].pictureId <> bodyId) or
        (GDVars.dsPortraitCache[2].disk <> GDVars.virtualDisk) then begin
      Blit.LoadPic('BODY' + diskCh, bodyId, False, 0, GDVars.dsPortraitCache[2].pic);
      if GDVars.dsPortraitCache[2].pic <> nil then begin
        GDVars.dsPortraitCache[2].pictureId := bodyId;
        GDVars.dsPortraitCache[2].disk := GDVars.virtualDisk;
      end else
        GDVars.dsPortraitCache[2].pictureId := 255;
    end;
end;

{ Draw the cached portrait at (col, row): head and body when both is True, the head alone otherwise. }
procedure DisplayPortraitBufs(col, row: Byte; both: Boolean);
begin
  if both then begin
    Portrait.DisplayPortraitHead(col, row, GDVars.dsPortraitCache[1].pic);
    Portrait.DisplayPortraitBody(col, row, GDVars.dsPortraitCache[2].pic);
  end else
    Portrait.DisplayImageBuf(col, row, False, GDVars.dsPortraitCache[1].pic);
end;

{ Draw frame dist (1..3, by view distance) of a into the view buffer at its origin + 2, then flush. Any other dist
  restores the video mode, prints an error and exits the game. }
procedure Show3DSprite(dist: Byte; a: Types.TAnimRec);
begin
  if (dist < 1) or (dist > 3) then begin
    Blit.RestoreVideoMode;
    WriteLn('Illegal range in Show3DSprite.');
    GameIo.ExitGame;
  end;
  if a.frames[dist].pic <> nil then
    with a.frames[dist].pic^ do
      Blit.BlitTileClipped(originX + 3 - 1, originY + 3 - 1, 0, 1, a.frames[dist].pic, GDVars.dsViewImageBufferPtr)
  else
    Exit;
  Blit.FlushView;
end;

end.

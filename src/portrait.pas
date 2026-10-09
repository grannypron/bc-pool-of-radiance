{ Picture loading, portrait composition and 3D sprite display. PIC and FINAL frames after the first are XOR deltas
  against the first frame. }
{$O+,F+,I-} { I/O checking is disabled for the sprite range-error message. }
unit Portrait;

interface

uses Types, Crt, GDConsts, GDVars, Blit, DaxIo, GameIo, Border;

procedure NoopPortrait;

procedure DisplayImageBuf(col, row: Integer; anim: Boolean; pic: Types.PImgBuf);

procedure DisplayPortraitHead(col, row: Byte; pic: Types.PImgBuf);

procedure DisplayPortraitBody(col, row: Byte; pic: Types.PImgBuf);

procedure LoadAnimation(name: Types.TStr8; picId: Byte; transp: Byte; var a: Types.TAnimRec);

procedure FreeAnimation(var a: Types.TAnimRec);

procedure DisplayCharPortrait;

procedure DisplayPortraitBufs(col, row: Byte; both: Boolean);

procedure LoadPortraitBufs(headId, bodyId: Byte);

procedure Show3DSprite(dist: Byte; a: Types.TAnimRec);

implementation

var
  { 0=CGA 1=EGA 2=Tandy }
  displayMode: Types.TVideoMode absolute GDVars.videoMode;

{ Empty entry point; does nothing. }
procedure NoopPortrait;
begin
end;

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

{ Load picture picId of <name><disk>.DAX into a, unless that name/id pair is already the cached picture
  (GDVars.picArcName/picArcId). PIC 1 is capped at 4 frames. A frame is loaded only while MaxAvail >= 3900, and count
  becomes the number loaded. PIC and FINAL frames after the first are XORed with the first; an odd transp remaps
  LightMagenta to Black outside CGA. Note: a skipped frame's data after its 8-byte header is not stepped over, so the
  frames after it are read from the wrong offset. }
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
  loaded: Byte;
begin
  if (name = GDVars.picArcName) and (picId = GDVars.picArcId) then Exit;
  Portrait.FreeAnimation(a);
  GDVars.picArcName := name;
  GDVars.picArcId := picId;
  isPic := (name = 'PIC') or (name = 'FINAL');
  Str(LongInt(GDVars.virtualDisk), diskCh);
  DaxIo.LoadDax(name + diskCh, '.dax', picId, sz, buf);
  if sz = 0 then Exit;
  offset := 0;
  gotXor := False;
  with a do begin
    count := buf^[offset];
    if (name = 'PIC') and (picId = 1) then
      if count > 4 then count := 4;
    Inc(offset);
    flag := 1;
    loaded := 0;
    for f := 1 to count do begin
      Move(buf^[offset], frames[f].hdr, SizeOf(frames[f].hdr));
      Inc(offset, SizeOf(frames[f].hdr));
      Move(buf^[offset], h, SizeOf(h));
      Inc(offset, SizeOf(h));
      Move(buf^[offset], w, SizeOf(w));
      Inc(offset, SizeOf(w));
      if MaxAvail >= 3900 then begin
        Inc(loaded);
        Blit.AllocPic(h, w, 1, transp, frames[f].pic);
        with frames[f].pic^ do begin
          Move(buf^[offset], originX, SizeOf(originX));
          Inc(offset, SizeOf(originX));
          Move(buf^[offset], originY, SizeOf(originY));
          Inc(offset, SizeOf(originY) + SizeOf(count));
          Move(buf^[offset], map, SizeOf(map));
          Inc(offset, SizeOf(map));
        end;
        if displayMode = Types.vmCGA then
          planeSz := frames[f].pic^.imgSize * 2 - 1
        else
          planeSz := frames[f].pic^.imgSize - 1;
        if isPic then
          if f = 1 then begin
            GetMem(xorBuf, planeSz + 1);
            Move(buf^[offset], xorBuf^, planeSz + 1);
            gotXor := True;
          end else
            for j := offset to offset + planeSz do
              buf^[j] := buf^[j] xor xorBuf^[j - offset];
        Blit.ExpandPicFrames(buf, offset, Boolean(transp), 0, frames[f].pic);
        if (transp and 1 > 0) and (displayMode <> Types.vmCGA) then
          Blit.RemapPic(GDConsts.animRemapFrom, GDConsts.animRemapTo, 0, False, frames[f].pic);
        Inc(offset, planeSz + 1);
      end;
    end;
    count := loaded;
  end;
  if isPic and gotXor then FreeMem(xorBuf, planeSz + 1);
  FreeMem(buf, sz);
  GameIo.PollGameKeys;
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
  through GDConsts.headTbl/bodyTbl. Does nothing when either number is 0. Note: s1 and s2 are built and never used. }
procedure DisplayCharPortrait;
var
  s1: String[3];
  s2: String[3];
begin
  if (GDVars.curChar^.portraitHead = 0) or (GDVars.curChar^.portraitBody = 0) then Exit;
  Border.DrawWindow(28, 1, 38, 11, 0, Black, '');
  with GDVars.curChar^ do begin
    Str(LongInt(GDConsts.headTbl[portraitHead]), s1);
    Str(LongInt(GDConsts.bodyTbl[portraitBody]), s2);
    Portrait.LoadPortraitBufs(GDConsts.headTbl[portraitHead], GDConsts.bodyTbl[portraitBody]);
    Portrait.DisplayPortraitBufs(28, 1, True);
  end;
end;

{ Load headId from HEAD<disk>.DAX and bodyId from BODY<disk>.DAX into the head and body portrait cache slots, skipping
  an id that is 255 or already loaded. }
procedure LoadPortraitBufs(headId, bodyId: Byte);
var
  diskCh: String[1];
begin
  Str(LongInt(GDVars.virtualDisk), diskCh);
  if headId <> 255 then
    if (GDVars.dsPortraitCache[1].pictureId = 255) or (GDVars.dsPortraitCache[1].pictureId <> headId)
    then begin
      Blit.LoadPic('HEAD' + diskCh, headId, False, 0, GDVars.dsPortraitCache[1].pic);
      GDVars.dsPortraitCache[1].pictureId := headId;
    end;
  if bodyId <> 255 then
    if (GDVars.dsPortraitCache[2].pictureId = 255) or (GDVars.dsPortraitCache[2].pictureId <> bodyId)
    then begin
      Blit.LoadPic('BODY' + diskCh, bodyId, False, 0, GDVars.dsPortraitCache[2].pic);
      GDVars.dsPortraitCache[2].pictureId := bodyId;
    end;
  GameIo.PollGameKeys;
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

begin
end.

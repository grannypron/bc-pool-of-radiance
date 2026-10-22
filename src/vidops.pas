{ The video mode's cold operations: run at start-up, when a character's icon is built or loaded, and when the data
  archives are built, so kept in an overlay. Blit holds the hot primitives and the size and capability questions. Both
  work through the installed video driver, GameVars.video (phase 6 of docs/refactor-plan.md). }
{$O+,F+}
{$I COMPILER.INC}
unit VidOps;

interface

uses Types;

{ The video mode's name, for the settings screen. }
function ModeName: Types.TStr20;

{ Build the active video mode's per-row screen addresses (GameVars.cgaRowSeg, fbRowOfs or tandyRowSeg); GameInit2 calls
  it once the mode is set. }
procedure InitRowTables;

{ Merge src into dst as one sprite: dst's pixels OR src's (with a colour key, src's opaque pixels replace dst's), and
  dst's mask AND src's, so either picture's opaque pixels show. Over src's frame size; nothing happens when either is
  nil, either has no mask, or src is empty. }
procedure MergePic(src, dst: Types.PImgBuf);

{ Draw src over dst through src's transparency mask: dst's pixels survive where src is transparent. Nothing happens
  when either is nil, src has no mask, the frame sizes differ, or dst is empty. }
procedure OverlayPic(src, dst: Types.PImgBuf);

{ Give every pixel of pic's first frame the colour toT gives its own. EGA and Tandy take one pass over the frame; CGA,
  whose pixels index the picture's colour map, goes through RemapPic. }
procedure RecolorPic(var toT: Types.TColorTab; pic: Types.PImgBuf);

{ Put 8 pixel colours (0..15), left to right, into scanline y of cell column 0 of frame frame of pic, in the video
  mode's layout. Pictures one cell wide only, as BldShow's cells are. }
procedure PutPixelRow(pic: Types.PImgBuf; frame, y: Byte; var px: Types.TPixelRow);

implementation

uses GameVars, Blit;

function ModeName: Types.TStr20;
begin
  ModeName := GameVars.video.name;
end;

procedure InitRowTables;
begin
  GameVars.video.InitRowTables;
end;

procedure MergePic(src, dst: Types.PImgBuf);
var
  n: Word;
begin
  if (src = nil) or (dst = nil) then Exit;
  if (src^.transp = nil) or (dst^.transp = nil) then Exit;
  { an empty picture would make the loops below run 65536 times }
  if src^.imgSize = 0 then Exit;
  if GameVars.video.keyed then begin
    { a colour key (VGA): src's opaque pixels replace dst's }
    for n := 0 to src^.imgSize - 1 do
      if src^.data[n] <> Types.PIC_KEY then
        dst^.data[n] := src^.data[n];
  end else
    for n := 0 to src^.imgSize - 1 do
      dst^.data[n] := dst^.data[n] or src^.data[n];
  for n := 0 to Blit.MaskBytes(src^.imgSize) - 1 do
    dst^.transp^[n] := dst^.transp^[n] and src^.transp^[n];
end;

procedure OverlayPic(src, dst: Types.PImgBuf);
var
  n: Word;
begin
  if (src = nil) or (dst = nil) then Exit;
  if (src^.transp = nil) or (src^.imgSize <> dst^.imgSize) or (dst^.imgSize = 0) then Exit;
  if GameVars.video.keyed then begin
    { a colour key (VGA) }
    for n := 0 to dst^.imgSize - 1 do
      if src^.data[n] <> Types.PIC_KEY then
        dst^.data[n] := src^.data[n];
    Exit;
  end;
  { one mask byte covers 1 shl maskShift picture bytes (EGA's cell row of four planes) }
  for n := 0 to dst^.imgSize - 1 do
    dst^.data[n] := dst^.data[n] and src^.transp^[n shr GameVars.video.maskShift] or src^.data[n];
end;

procedure RecolorPic(var toT: Types.TColorTab; pic: Types.PImgBuf);
begin
  if pic = nil then Exit;
  GameVars.video.RecolorFrame(toT, pic);
end;

procedure PutPixelRow(pic: Types.PImgBuf; frame, y: Byte; var px: Types.TPixelRow);
begin
  if pic = nil then Exit;
  GameVars.video.PutPixelRow(pic, frame * pic^.imgSize, y, px);
end;

end.

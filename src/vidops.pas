{ The video mode's cold operations: run at start-up, when a character's icon is built or loaded, and when the data
  archives are built, so kept in an overlay. Blit holds the hot primitives and the size and capability questions. Phase
  6 of docs/refactor-plan.md moves both behind the video driver. }
{$O+,F+}
unit VidOps;

interface

uses Types;

{ The video mode's name, for the settings screen. }
function ModeName: Types.TStr20;

{ Build the active video mode's per-row screen addresses (GDVars.cgaRowSeg, fbRowOfs or tandyRowSeg); GameInit2 calls
  it once the mode is set. }
procedure InitRowTables;

{ Merge src into dst as one sprite: dst's pixels OR src's, and dst's mask AND src's, so either picture's opaque pixels
  show. Over src's frame size; nothing happens when either is nil, either has no mask, or src is empty. }
procedure MergePic(src, dst: Types.PImgBuf);

{ Draw src over dst through src's transparency mask: dst's pixels survive where src is transparent. Nothing happens
  when either is nil, src has no mask, or the frame sizes differ. }
procedure OverlayPic(src, dst: Types.PImgBuf);

{ Give every pixel of pic's first frame the colour toT gives its own. EGA and Tandy take one pass over the frame; CGA,
  whose pixels index the picture's colour map, goes through RemapPic. }
procedure RecolorPic(var toT: Types.TColorTab; pic: Types.PImgBuf);

{ Put 8 pixel colours (0..15), left to right, into scanline y of cell column 0 of frame frame of pic, in the video
  mode's layout. Pictures one cell wide only, as BldShow's cells are. }
procedure PutPixelRow(pic: Types.PImgBuf; frame, y: Byte; var px: Types.TPixelRow);

implementation

uses C_Video, GDConsts, GDVars, Blit;

function ModeName: Types.TStr20;
begin
  ModeName := GDVars.video.name;
end;

procedure InitRowTables;
var
  i: Byte;
begin
  { CGA: even and odd rows in separate banks, a row pair every 5 paragraphs; EGA: 40 bytes a row; Tandy: four banks,
    four rows every 10 paragraphs }
  for i := 0 to 199 do
    case GDVars.videoMode of
      Types.vmCGA:
        if Odd(i) then
          GDVars.cgaRowSeg[i] := (i div 2) * 5 + C_Video.GFX_BANK1_SEG
        else
          GDVars.cgaRowSeg[i] := (i div 2) * 5 + C_Video.GFX_BANK0_SEG;
      Types.vmEGA:
        GDVars.fbRowOfs[i] := i * 40;
      Types.vmTandy:
        case i mod 4 of
          0: GDVars.tandyRowSeg[i] := (i div 4) * 10 + C_Video.GFX_BANK0_SEG;
          1: GDVars.tandyRowSeg[i] := (i div 4) * 10 + C_Video.GFX_BANK1_SEG;
          2: GDVars.tandyRowSeg[i] := (i div 4) * 10 + C_Video.GFX_BANK2_SEG;
          3: GDVars.tandyRowSeg[i] := (i div 4) * 10 + C_Video.GFX_BANK3_SEG;
        end;
    end;
end;

procedure MergePic(src, dst: Types.PImgBuf);
var
  n: Word;
begin
  if (src = nil) or (dst = nil) then Exit;
  if (src^.transp = nil) or (dst^.transp = nil) then Exit;
  { an empty picture would make the loops below run 65536 times }
  if src^.imgSize = 0 then Exit;
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
  { one mask byte covers 1 shl maskShift picture bytes (EGA's cell row of four planes) }
  for n := 0 to dst^.imgSize - 1 do
    dst^.data[n] := dst^.data[n] and src^.transp^[n shr GDVars.video.maskShift] or src^.data[n];
end;

procedure RecolorPic(var toT: Types.TColorTab; pic: Types.PImgBuf);
var
  n: Word;
  k: Byte;
  bit: Byte;
  c: Byte;
  fromT: Types.TColorTab;
  q: array[0..3] of Byte;
begin
  if pic = nil then Exit;
  case GDVars.videoMode of
    { four plane bytes per eight pixels; plane k holds bit k of each pixel's colour }
    Types.vmEGA: begin
        n := 0;
        while n + 3 < pic^.imgSize do begin
          for k := 0 to 3 do
            q[k] := 0;
          for bit := 0 to 7 do begin
            c := ((pic^.data[n] shr bit) and 1) or (((pic^.data[n + 1] shr bit) and 1) shl 1) or
                 (((pic^.data[n + 2] shr bit) and 1) shl 2) or (((pic^.data[n + 3] shr bit) and 1) shl 3);
            c := toT[c];
            for k := 0 to 3 do
              if (c and (1 shl k)) <> 0 then
                q[k] := q[k] or (1 shl bit);
          end;
          for k := 0 to 3 do
            pic^.data[n + k] := q[k];
          Inc(n, 4);
        end;
      end;
    { two pixels per byte }
    Types.vmTandy: for n := 0 to pic^.imgSize - 1 do
        pic^.data[n] := (toT[pic^.data[n] shr 4] shl 4) or toT[pic^.data[n] and $F];
  else
    for k := 0 to 15 do
      fromT[k] := k;
    Blit.RemapPic(fromT, toT, 0, False, pic);
  end;
end;

procedure PutPixelRow(pic: Types.PImgBuf; frame, y: Byte; var px: Types.TPixelRow);
var
  at: Word;
  plane: Byte;
  i: Byte;
  k: Byte;
  b: Byte;
begin
  if pic = nil then Exit;
  at := frame * pic^.imgSize;
  case GDVars.videoMode of
    Types.vmEGA:
      for plane := 0 to 3 do begin
        b := 0;
        for k := 0 to 7 do
          if (px[k] and GDConsts.egaPlaneBit[plane]) <> 0 then
            b := b or ($80 shr k);
        pic^.data[at + y * 4 + plane] := b;
      end;
    Types.vmCGA:
      for i := 0 to 1 do begin
        b := 0;
        for k := 0 to 3 do
          b := b or ((GDConsts.attrTable[px[i * 4 + k] and $0F] and 3) shl (6 - 2 * k));
        pic^.data[at + y * 2 + i] := b;
      end;
    Types.vmTandy:
      for i := 0 to 3 do
        pic^.data[at + y * 4 + i] := ((px[i * 2] and $0F) shl 4) or (px[i * 2 + 1] and $0F);
  end;
end;

end.

{ The VGA video driver's cold routines, which convert and recolour pictures at a byte a pixel: run when pictures load,
  icons are built, the data archives are built, and at start-up, so kept in an overlay. VidVga installs them into
  GDVars.video (phase 6 of docs/refactor-plan.md). }
{$O+,F+}
{$I COMPILER.INC}
unit PicVga;

interface

uses Types;

procedure ExpandFrames(imgData: Types.PByteArr; srcOff: Word; hasMask: Boolean; transpColor: Byte; pic: Types.PImgBuf);

procedure MirrorFrame(src, dst: Types.PImgBuf);

procedure RemapColour(pic, scratch: Types.PImgBuf; srcOff: Word; nFrames: Byte; fromC, toC: Byte; isDithered: Boolean);

procedure RecolorFrame(var toT: Types.TColorTab; pic: Types.PImgBuf);

procedure PutPixelRow(pic: Types.PImgBuf; at: Word; y: Byte; var px: Types.TPixelRow);

procedure InitRowTables;

implementation

uses C_Video, GDVars, Blit;

{ each DAX cell row (4 bytes, two pixels a byte, high nibble first) becomes 8 bytes; with a mask, a pixel of
  transpColor becomes PIC_KEY and sets its mask bit (bit 7 the leftmost) }
procedure ExpandFrames(imgData: Types.PByteArr; srcOff: Word; hasMask: Boolean; transpColor: Byte; pic: Types.PImgBuf);
var
  chunk: TChunk;
  frame: Byte;
  col: Word;
  row: Word;
  dstOff: Word;
  maskOff: Word;
  mask: Byte;
  k: Byte;
  color: Byte;
begin
  with pic^ do begin
    dstOff := 0;
    maskOff := 0;
    for frame := 1 to count do
      for row := 0 to height - 1 do
        for col := 0 to width - 1 do begin
          Move(imgData^[srcOff], chunk, SizeOf(chunk));
          mask := 0;
          if transp <> nil then begin
            mask := Blit.ComputeMask(transpColor, chunk);
            transp^[maskOff] := mask;
            Inc(maskOff);
          end;
          for k := 0 to 7 do begin
            if Odd(k) then
              color := chunk[k shr 1] and $0F
            else
              color := chunk[k shr 1] shr 4;
            if (mask and ($80 shr k)) <> 0 then
              color := Types.PIC_KEY;
            data[dstOff + k] := color;
          end;
          Inc(dstOff, 8);
          Inc(srcOff, SizeOf(chunk));
        end;
  end;
end;

{ each row's bytes in reverse order; each mask byte (a cell row) to the mirrored cell, its bits reversed }
procedure MirrorFrame(src, dst: Types.PImgBuf);
var
  rowBytes: Word;
  row: Word;
  col: Word;
  rowOff: Word;
  maskOff: Word;
begin
  with src^ do begin
    rowBytes := width * 8;
    rowOff := 0;
    for row := 1 to height do begin
      for col := 0 to rowBytes - 1 do
        dst^.data[rowOff + col] := data[rowOff + rowBytes - 1 - col];
      Inc(rowOff, rowBytes);
    end;
    if transp <> nil then begin
      maskOff := 0;
      for row := 1 to height do begin
        for col := 0 to width - 1 do
          dst^.transp^[maskOff + width - col - 1] := Blit.MirrorBits(transp^[maskOff + col]);
        Inc(maskOff, width);
      end;
    end;
  end;
end;

{ Replace fromC with toC in nFrames frames of pic from srcOff, matching the original pixels and writing scratch, which
  holds a copy of the frames (Blit.RemapPic copies it back); with isDithered, a quarter of the matches, at random. }
procedure RemapColour(pic, scratch: Types.PImgBuf; srcOff: Word; nFrames: Byte; fromC, toC: Byte; isDithered: Boolean);
var
  n: Word;
  total: Word;
  dstOff: Word;
begin
  dstOff := 0;
  total := nFrames * scratch^.imgSize;
  for n := 1 to total do begin
    if pic^.data[srcOff] = fromC then
      if not isDithered or isDithered and (Random(4) = 0) then
        scratch^.data[dstOff] := toC;
    Inc(srcOff);
    Inc(dstOff);
  end;
end;

{ every pixel but PIC_KEY to the colour toT gives it }
procedure RecolorFrame(var toT: Types.TColorTab; pic: Types.PImgBuf);
var
  n: Word;
begin
  for n := 0 to pic^.imgSize - 1 do
    if pic^.data[n] < 16 then
      pic^.data[n] := toT[pic^.data[n]];
end;

procedure PutPixelRow(pic: Types.PImgBuf; at: Word; y: Byte; var px: Types.TPixelRow);
var
  k: Byte;
begin
  for k := 0 to 7 do
    pic^.data[at + y * 8 + k] := px[k] and $0F;
end;

procedure InitRowTables;
var
  i: Byte;
begin
  for i := 0 to 199 do
    GDVars.fbRowOfs[i] := i * C_Video.VGA_ROW_BYTES;
end;

end.

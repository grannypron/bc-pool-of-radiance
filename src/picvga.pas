{ Less frequently used VGA picture-conversion routines. VGA stores one byte per
  pixel. Keeping these routines overlaid saves resident memory; VidVga installs
  them in GameVars.video. }
{$O+,F+}
{$I COMPILER.INC}
unit PicVga;

interface

uses Types;

procedure ExpandChunk(var chunk: Types.TChunk; mask: Byte; pic: Types.PImgBuf; at: Word);

procedure MirrorFrame(src, dst: Types.PImgBuf);

procedure RemapColour(pic, scratch: Types.PImgBuf; srcOff: Word; nFrames: Byte; fromC, toC: Byte; isDithered: Boolean);

procedure RecolorFrame(var toT: Types.TColorTab; pic: Types.PImgBuf);

procedure PutPixelRow(pic: Types.PImgBuf; at: Word; y: Byte; var px: Types.TPixelRow);

procedure InitRowTables;

implementation

uses C_VIDEO, GameVars, Blit, VidOps{$IFDEF FPC}, TpRand{$ENDIF};

{ eight bytes, a pixel each; with a mask, a transparent pixel becomes PIC_KEY, and the mask byte is the chunk's (bit 7
  the leftmost) }
procedure ExpandChunk(var chunk: Types.TChunk; mask: Byte; pic: Types.PImgBuf; at: Word);
var
  k: Byte;
begin
  with pic^ do begin
    if transp <> nil then
      transp^[at shr 3] := mask;
    for k := 0 to 7 do
      if (mask and ($80 shr k)) <> 0 then
        data[at + k] := Types.PIC_KEY
      else
        data[at + k] := VidOps.ChunkPixel(chunk, k);
  end;
end;

{ each row's bytes in reverse order; each mask byte (a cell row) to the mirrored cell, its bits reversed }
procedure MirrorFrame(src, dst: Types.PImgBuf);
var
  rowBytes: Word;
  row: Word;
  col: Word;
  rowOff: Word;
begin
  with src^ do begin
    rowBytes := width * 8;
    rowOff := 0;
    for row := 1 to height do begin
      for col := 0 to rowBytes - 1 do
        dst^.data[rowOff + col] := data[rowOff + rowBytes - 1 - col];
      Inc(rowOff, rowBytes);
    end;
  end;
  VidOps.MirrorCellMask(src, dst);
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
      if not isDithered or (Random(4) = 0) then
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
    GameVars.fbRowOfs[i] := i * C_VIDEO.VGA_ROW_BYTES;
end;

end.

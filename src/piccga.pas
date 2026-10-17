{ The CGA video driver's cold routines, which convert and recolour pictures: run when pictures load, icons are built,
  the data archives are built, and at start-up, so kept in an overlay. VidCga installs them into GDVars.video (phase 6 of
  docs/refactor-plan.md). }
{$O+,F+}
unit PicCga;

interface

uses Types;

procedure ExpandFrames(imgData: Types.PByteArr; srcOff: Word; hasMask: Boolean; transpColor: Byte; pic: Types.PImgBuf);

procedure MirrorFrame(src, dst: Types.PImgBuf);

procedure RemapColour(pic, scratch: Types.PImgBuf; srcOff: Word; nFrames: Byte; fromC, toC: Byte; isDithered: Boolean);

procedure RecolorFrame(var toT: Types.TColorTab; pic: Types.PImgBuf);

procedure PutPixelRow(pic: Types.PImgBuf; at: Word; y: Byte; var px: Types.TPixelRow);

procedure InitRowTables;

implementation

uses C_Video, GDConsts, GDVars, Blit;

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
  j: Byte;
  bit: Byte;
begin
  with pic^ do begin
    dstOff := 0;
    maskOff := 0;
    for frame := 1 to count do
      for row := 0 to height - 1 do
        for col := 0 to width - 1 do begin
          Move(imgData^[srcOff], chunk, SizeOf(chunk));
          if transp <> nil then begin
            mask := Blit.ComputeMask(transpColor, chunk);
            bit := $80;
            for j := 1 to 2 do begin
              for k := 4 to 7 do begin
                if (bit and mask) > 0 then
                  transp^[maskOff] := transp^[maskOff] or GDConsts.cgaPixelMask[k];
                bit := bit shr 1;
              end;
              Inc(maskOff);
            end;
          end;
          for k := 0 to 3 do
            if Odd(k) then
              data[dstOff] := data[dstOff] or GDConsts.cgaPixPos[Blit.SrcNibble(chunk[k shr 1] and $0F, map)][k]
            else
              data[dstOff] := data[dstOff] or
                GDConsts.cgaPixPos[Blit.SrcNibble((chunk[k shr 1] and $F0) shr 4, map)][k];
          if transp <> nil then
            data[dstOff] := data[dstOff] and not transp^[maskOff - 2];
          Inc(dstOff);
          for k := 4 to 7 do
            if Odd(k) then
              data[dstOff] := data[dstOff] or GDConsts.cgaPixPos[Blit.SrcNibble(chunk[k shr 1] and $0F, map)][k - 4]
            else
              data[dstOff] := data[dstOff] or
                GDConsts.cgaPixPos[Blit.SrcNibble((chunk[k shr 1] and $F0) shr 4, map)][k - 4];
          if transp <> nil then
            data[dstOff] := data[dstOff] and not transp^[maskOff - 1];
          Inc(dstOff);
          Inc(srcOff, SizeOf(chunk));
        end;
  end;
end;

procedure MirrorFrame(src, dst: Types.PImgBuf);
var
  dstOff: Word;
  srcOff: Word;
  rowStart: Word;
  rowBytes: Word;
  col: Word;
  row: Word;
  cell: Word;
begin
  with src^ do begin
    rowBytes := width * SizeOf(cell);
    srcOff := rowBytes - SizeOf(cell);
    dstOff := 0;
    for row := 1 to height do begin
      rowStart := dstOff;
      for col := 0 to width - 1 do begin
        Move(data[srcOff - dstOff + rowStart], cell, SizeOf(cell));
        cell := Blit.MirrorPairs(cell);
        Move(cell, dst^.data[dstOff], SizeOf(cell));
        if transp <> nil then begin
          Move(transp^[srcOff - dstOff + rowStart], cell, SizeOf(cell));
          cell := Blit.MirrorPairs(cell);
          Move(cell, dst^.transp^[dstOff], SizeOf(cell));
        end;
        Inc(dstOff, SizeOf(cell));
      end;
      Inc(srcOff, rowBytes);
    end;
  end;
end;

{ Replace fromC with toC in nFrames frames of pic from srcOff, matching the original pixels and writing scratch, which
  holds a copy of the frames (Blit.RemapPic copies it back); with isDithered, a random part of the matches. }
procedure RemapColour(pic, scratch: Types.PImgBuf; srcOff: Word; nFrames: Byte; fromC, toC: Byte; isDithered: Boolean);
var
  frameNo: ShortInt;
  col: Word;
  row: Word;
  pixPos: Byte;
  rowBytes: Word;
  dstOff: Word;
begin
  dstOff := 0;
  with scratch^ do begin
    rowBytes := width * 2;
    for frameNo := 1 to nFrames do
      for row := 1 to height do
        for col := 1 to rowBytes do begin
          for pixPos := 0 to 3 do
            if pic^.data[srcOff] and GDConsts.cgaPixelMask[pixPos + 4] =
                GDConsts.cgaPixPos[Blit.SrcNibble(fromC, map)][pixPos] then
              if not isDithered or isDithered and (Random(4) = 0) then
                data[dstOff] := data[dstOff] and not GDConsts.cgaPixelMask[pixPos + 4] or
                  GDConsts.cgaPixPos[Blit.SrcNibble(toC, map)][pixPos];
          Inc(srcOff);
          Inc(dstOff);
        end;
  end;
end;

procedure RecolorFrame(var toT: Types.TColorTab; pic: Types.PImgBuf);
var
  k: Byte;
  fromT: Types.TColorTab;
begin
  for k := 0 to 15 do
    fromT[k] := k;
  Blit.RemapPic(fromT, toT, 0, False, pic);
end;

procedure PutPixelRow(pic: Types.PImgBuf; at: Word; y: Byte; var px: Types.TPixelRow);
var
  i: Byte;
  k: Byte;
  b: Byte;
begin
  for i := 0 to 1 do begin
    b := 0;
    for k := 0 to 3 do
      b := b or ((GDConsts.attrTable[px[i * 4 + k] and $0F] and 3) shl (6 - 2 * k));
    pic^.data[at + y * 2 + i] := b;
  end;
end;

procedure InitRowTables;
var
  i: Byte;
begin
  for i := 0 to 199 do
    if Odd(i) then
      GDVars.cgaRowSeg[i] := (i div 2) * 5 + C_Video.GFX_BANK1_SEG
    else
      GDVars.cgaRowSeg[i] := (i div 2) * 5 + C_Video.GFX_BANK0_SEG;
end;

end.

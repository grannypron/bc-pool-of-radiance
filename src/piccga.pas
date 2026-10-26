{ Less frequently used CGA picture-conversion routines. Keeping them overlaid
  saves resident memory; VidCga installs them in GameVars.video. }
{$O+,F+}
{$I COMPILER.INC}
unit PicCga;

interface

uses Types;

procedure ExpandChunk(var chunk: Types.TChunk; mask: Byte; pic: Types.PImgBuf; at: Word);

procedure MirrorFrame(src, dst: Types.PImgBuf);

procedure RemapColour(pic, scratch: Types.PImgBuf; srcOff: Word; nFrames: Byte; fromC, toC: Byte; isDithered: Boolean);

procedure RecolorFrame(var toT: Types.TColorTab; pic: Types.PImgBuf);

procedure PutPixelRow(pic: Types.PImgBuf; at: Word; y: Byte; var px: Types.TPixelRow);

procedure InitRowTables;

implementation

uses C_VIDEO, GameDefs, GameVars, Blit, VidOps{$IFDEF FPC}, TpRand{$ENDIF};

const
  { CGA color by pixel position within a packed byte. }
  cgaPixPos: array[0..3, 0..3] of Byte = (
    ($00, $00, $00, $00),
    ($40, $10, $04, $01),
    ($80, $20, $08, $02),
    ($C0, $30, $0C, $03));

{ two bytes of four 2-bit pixels, each colour through the picture's colour map; a mask byte for each, 2 bits a pixel }
procedure ExpandChunk(var chunk: Types.TChunk; mask: Byte; pic: Types.PImgBuf; at: Word);
var
  k: Byte;
  m: Byte;
  half: Byte;
  color: Byte;
begin
  with pic^ do begin
    for k := 0 to 7 do begin
      color := Blit.SrcNibble(VidOps.ChunkPixel(chunk, k), map);
      data[at + k shr 2] := data[at + k shr 2] or cgaPixPos[color][k and 3];
    end;
    if transp <> nil then
      for half := 0 to 1 do begin
        m := 0;
        for k := 0 to 3 do
          if (mask and ($80 shr (half * 4 + k))) <> 0 then
            m := m or GameDefs.cgaPixelMask[k + 4];
        transp^[at + half] := transp^[at + half] or m;
        data[at + half] := data[at + half] and not transp^[at + half];
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
        cell := VidOps.MirrorPairs(cell);
        Move(cell, dst^.data[dstOff], SizeOf(cell));
        if transp <> nil then begin
          Move(transp^[srcOff - dstOff + rowStart], cell, SizeOf(cell));
          cell := VidOps.MirrorPairs(cell);
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
            if pic^.data[srcOff] and GameDefs.cgaPixelMask[pixPos + 4] =
                cgaPixPos[Blit.SrcNibble(fromC, map)][pixPos] then
              if not isDithered or (Random(4) = 0) then
                data[dstOff] := data[dstOff] and not GameDefs.cgaPixelMask[pixPos + 4] or
                  cgaPixPos[Blit.SrcNibble(toC, map)][pixPos];
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
      b := b or ((GameDefs.attrTable[px[i * 4 + k] and $0F] and 3) shl (6 - 2 * k));
    pic^.data[at + y * 2 + i] := b;
  end;
end;

procedure InitRowTables;
var
  i: Byte;
begin
  { 80 bytes (5 paragraphs) a scanline, even scanlines in the bank at B800 and odd ones in the bank at BA00 }
  for i := 0 to 199 do
    if Odd(i) then
      GameVars.bankRowSeg[i] := (i div 2) * 5 + C_VIDEO.GFX_BANK1_SEG
    else
      GameVars.bankRowSeg[i] := (i div 2) * 5 + C_VIDEO.GFX_BANK0_SEG;
end;

end.

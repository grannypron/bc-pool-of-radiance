{ The Tandy video driver's cold routines, which convert and recolour pictures: run when pictures load, icons are built,
  the data archives are built, and at start-up, so kept in an overlay. VidTdy installs them into GDVars.video (phase 6
  of docs/refactor-plan.md). }
{$O+,F+}
{$I COMPILER.INC}
unit PicTdy;

interface

uses Types;

procedure ExpandFrames(imgData: Types.PByteArr; srcOff: Word; transpColor: Byte; pic: Types.PImgBuf);

procedure MirrorFrame(src, dst: Types.PImgBuf);

procedure RemapColour(pic, scratch: Types.PImgBuf; srcOff: Word; nFrames: Byte; fromC, toC: Byte; isDithered: Boolean);

procedure RecolorFrame(var toT: Types.TColorTab; pic: Types.PImgBuf);

procedure PutPixelRow(pic: Types.PImgBuf; at: Word; y: Byte; var px: Types.TPixelRow);

procedure InitRowTables;

implementation

uses C_Video, GDVars, Blit{$IFDEF FPC}, TpRand{$ENDIF};

procedure ExpandFrames(imgData: Types.PByteArr; srcOff: Word; transpColor: Byte; pic: Types.PImgBuf);
var
  frame: Byte;
  col: Word;
  dstOff: Word;
begin
  with pic^ do begin
    dstOff := 0;
    for frame := 1 to count do begin
      Move(imgData^[srcOff], data[dstOff], imgSize);
      if transp <> nil then
        for col := dstOff to dstOff + imgSize - 1 do begin
          if (data[col] shr 4) = transpColor then
            transp^[col] := $F0;
          if (data[col] and $0F) = transpColor then
            Inc(transp^[col], $0F);
          data[col] := data[col] and not transp^[col];
        end;
      Inc(dstOff, imgSize);
      Inc(srcOff, imgSize);
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
begin
  with src^ do begin
    rowBytes := width * 4;
    srcOff := rowBytes - 1;
    dstOff := 0;
    for row := 1 to height do begin
      rowStart := dstOff;
      for col := 1 to rowBytes do begin
        dst^.data[dstOff] := Blit.MirrorNibbles(data[srcOff - dstOff + rowStart]);
        if transp <> nil then
          dst^.transp^[dstOff] := Blit.MirrorNibbles(transp^[srcOff - dstOff + rowStart]);
        Inc(dstOff);
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
  rowBytes: Word;
  fromHigh: Byte;
  toHigh: Byte;
  dstOff: Word;
begin
  dstOff := 0;
  with scratch^ do begin
    rowBytes := width * 4;
    fromHigh := fromC shl 4;
    toHigh := toC shl 4;
    for frameNo := 1 to nFrames do
      for row := 1 to height do
        for col := 1 to rowBytes do begin
          if pic^.data[srcOff] and $F0 = fromHigh then
            if not isDithered or isDithered and (Random(4) = 0) then
              data[dstOff] := data[dstOff] and $F or toHigh;
          if pic^.data[srcOff] and $F = fromC then
            if not isDithered or isDithered and (Random(4) = 0) then
              data[dstOff] := data[dstOff] and $F0 or toC;
          Inc(srcOff);
          Inc(dstOff);
        end;
  end;
end;

procedure RecolorFrame(var toT: Types.TColorTab; pic: Types.PImgBuf);
var
  n: Word;
begin
  for n := 0 to pic^.imgSize - 1 do
    pic^.data[n] := (toT[pic^.data[n] shr 4] shl 4) or toT[pic^.data[n] and $F];
end;

procedure PutPixelRow(pic: Types.PImgBuf; at: Word; y: Byte; var px: Types.TPixelRow);
var
  i: Byte;
begin
  for i := 0 to 3 do
    pic^.data[at + y * 4 + i] := ((px[i * 2] and $0F) shl 4) or (px[i * 2 + 1] and $0F);
end;

procedure InitRowTables;
var
  i: Byte;
begin
  for i := 0 to 199 do
    case i mod 4 of
      0: GDVars.tandyRowSeg[i] := (i div 4) * 10 + C_Video.GFX_BANK0_SEG;
      1: GDVars.tandyRowSeg[i] := (i div 4) * 10 + C_Video.GFX_BANK1_SEG;
      2: GDVars.tandyRowSeg[i] := (i div 4) * 10 + C_Video.GFX_BANK2_SEG;
      3: GDVars.tandyRowSeg[i] := (i div 4) * 10 + C_Video.GFX_BANK3_SEG;
    end;
end;

end.

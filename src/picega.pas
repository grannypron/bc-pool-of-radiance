{ The EGA video driver's cold routines, which convert and recolour pictures: run when pictures load, icons are built,
  the data archives are built, and at start-up, so kept in an overlay. VidEga installs them into GDVars.video (phase 6
  of docs/refactor-plan.md). }
{$O+,F+}
{$I COMPILER.INC}
unit PicEga;

interface

uses Types;

procedure ExpandFrames(imgData: Types.PByteArr; srcOff: Word; hasMask: Boolean; transpColor: Byte; pic: Types.PImgBuf);

procedure MirrorFrame(src, dst: Types.PImgBuf);

procedure RemapColour(pic, scratch: Types.PImgBuf; srcOff: Word; nFrames: Byte; fromC, toC: Byte; isDithered: Boolean);

procedure RecolorFrame(var toT: Types.TColorTab; pic: Types.PImgBuf);

procedure PutPixelRow(pic: Types.PImgBuf; at: Word; y: Byte; var px: Types.TPixelRow);

procedure InitRowTables;

implementation

uses GDConsts, GDVars, Blit{$IFDEF FPC}, TpRand{$ENDIF};

procedure ExpandFrames(imgData: Types.PByteArr; srcOff: Word; hasMask: Boolean; transpColor: Byte; pic: Types.PImgBuf);
var
  chunk: TChunk;
  frame: Byte;
  col: Word;
  row: Word;
  dstOff: Word;
  maskOff: Word;
  k: Byte;
  bit: Byte;
  plane: Byte;
  color: Byte;
begin
  with pic^ do begin
    dstOff := 0;
    maskOff := 0;
    for frame := 1 to count do
      for row := 0 to height - 1 do
        for col := 0 to width - 1 do begin
          Move(imgData^[srcOff], chunk, SizeOf(chunk));
          if transp <> nil then begin
            transp^[maskOff] := Blit.ComputeMask(transpColor, chunk);
            Inc(maskOff);
          end;
          bit := $80;
          for k := 0 to 7 do begin
            if Odd(k) then
              color := chunk[k shr 1] and $0F
            else
              color := chunk[k shr 1] shr 4;
            for plane := 0 to 3 do
              if (GDConsts.egaPlaneBit[plane] and color) > 0 then
                data[plane + dstOff] := data[plane + dstOff] or bit;
            bit := bit shr 1;
          end;
          if transp <> nil then
            for plane := 0 to 3 do
              data[plane + dstOff] := data[plane + dstOff] and not transp^[maskOff - 1];
          Inc(dstOff, 4);
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
  plane: Byte;
begin
  with src^ do begin
    rowBytes := width * 4;
    srcOff := rowBytes - 4;
    dstOff := 0;
    for row := 1 to height do begin
      rowStart := dstOff;
      for col := 1 to width do begin
        for plane := 0 to 3 do
          dst^.data[plane + dstOff] := Blit.MirrorBits(data[srcOff - dstOff + rowStart + plane]);
        Inc(dstOff, 4);
      end;
      Inc(srcOff, rowBytes);
    end;
    if transp <> nil then begin
      srcOff := 0;
      for row := 1 to height do begin
        for col := 0 to width - 1 do
          dst^.transp^[srcOff + width - col - 1] := Blit.MirrorBits(transp^[srcOff + col]);
        Inc(srcOff, width);
      end;
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
  match: Byte;
  planeMask: array[0..3] of Byte;
  plane: Byte;
  dstOff: Word;
begin
  dstOff := 0;
  with scratch^ do begin
    for plane := 0 to 3 do
      if (fromC and GDConsts.egaPlaneBit[plane]) > 0 then
        planeMask[plane] := 0
      else
        planeMask[plane] := $FF;
    for frameNo := 1 to nFrames do
      for row := 1 to height do
        for col := 1 to width do begin
          if isDithered then
            match := Random(256) and Random(256)
          else
            match := $FF;
          for plane := 0 to 3 do
            match := (pic^.data[plane + srcOff] xor planeMask[plane]) and match;
          for plane := 0 to 3 do
            if (toC and GDConsts.egaPlaneBit[plane]) > 0 then
              data[plane + dstOff] := data[plane + dstOff] or match
            else
              data[plane + dstOff] := data[plane + dstOff] and not match;
          Inc(srcOff, 4);
          Inc(dstOff, 4);
        end;
  end;
end;

procedure RecolorFrame(var toT: Types.TColorTab; pic: Types.PImgBuf);
var
  n: Word;
  k: Byte;
  bit: Byte;
  c: Byte;
  q: array[0..3] of Byte;
begin
  { four plane bytes per eight pixels; plane k holds bit k of each pixel's colour }
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

procedure PutPixelRow(pic: Types.PImgBuf; at: Word; y: Byte; var px: Types.TPixelRow);
var
  plane: Byte;
  k: Byte;
  b: Byte;
begin
  for plane := 0 to 3 do begin
    b := 0;
    for k := 0 to 7 do
      if (px[k] and GDConsts.egaPlaneBit[plane]) <> 0 then
        b := b or ($80 shr k);
    pic^.data[at + y * 4 + plane] := b;
  end;
end;

procedure InitRowTables;
var
  i: Byte;
begin
  for i := 0 to 199 do
    GDVars.fbRowOfs[i] := i * 40;
end;

end.

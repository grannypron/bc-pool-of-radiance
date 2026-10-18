{ The Tandy video driver: BIOS mode 9, 320x200 in 16 colours at 4 bits a pixel, four banks from $B800. Resident,
  since its routines are the hot ones; GameBoot installs it when POOL.CFG names Tandy (phase 6 of
  docs/refactor-plan.md). }
{$F+}
{$I COMPILER.INC}
unit VidTdy;

interface

{ Make this the video driver: fill GDVars.video. }
procedure Install;

implementation

uses Types, C_Video, GDConsts, GDVars, DaxIo, PicTdy;

var
  { the four banks from $B800: scanline n in bank n mod 4, 160 bytes a scanline }
  tdyB800: array[0..255] of Types.TTdyRow absolute C_Video.GFX_BANK0_SEG:$0000;
  tdyBA00: array[0..255] of Types.TTdyRow absolute C_Video.GFX_BANK1_SEG:$0000;
  tdyBC00: array[0..255] of Types.TTdyRow absolute C_Video.GFX_BANK2_SEG:$0000;
  tdyBE00: array[0..255] of Types.TTdyRow absolute C_Video.GFX_BANK3_SEG:$0000;

procedure Start;
begin
end;

procedure FlushSpans;
var
  row: Word;
begin
  for row := 0 to SizeOf(GDVars.spanActive) - 1 do
    if GDVars.spanActive[row] <> 0 then
      Move(GDVars.dsViewImageBufferPtr^.data[GDVars.spanFirstOfs[row]],
           Mem[GDVars.tandyRowSeg[row + 8]:GDVars.spanScreenOfs[row] + 4],
           GDVars.spanLastOfs[row] - GDVars.spanFirstOfs[row] + 1);
end;

{ 4 bytes per 8-pixel cell, a row at a time through the row segments }
procedure ShowPic(screenX, screenY: Integer; pic: Types.PImgBuf);
var
  row: Integer;
  colOff: Word;
  firstRow: Word;
  lastRow: Word;
  rowBytes: Word;
  srcOff: Word;
begin
  with pic^ do begin
    rowBytes := width * 4;
    srcOff := 0;
    firstRow := screenY * 8;
    lastRow := firstRow + height - 1;
    colOff := screenX * 4;
    for row := firstRow to lastRow do begin
      Move(pic^.data[srcOff], Mem[GDVars.tandyRowSeg[row]:colOff], rowBytes);
      Inc(srcOff, rowBytes);
    end;
  end;
end;

{ two pixels a byte across the four banks }
procedure DrawGlyph(col, row, color, glyph: Byte);
var
  dstOff: Word;
  cnt: Word;
  colBase: Word;
  tandyPx: Byte;
  k: Byte;
  mask: Byte;
  bank: Byte;
  outerRow: Byte;
begin
  dstOff := 0;
  cnt := row * 2;
  colBase := col * 4;
  for outerRow := 0 to 1 do begin
    for bank := 0 to 3 do begin
      mask := $80;
      for k := 0 to 3 do begin
        if (GDVars.gameFont^[glyph][dstOff] and mask) > 0 then
          tandyPx := color shl 4
        else
          tandyPx := 0;
        mask := mask shr 1;
        if (GDVars.gameFont^[glyph][dstOff] and mask) > 0 then
          tandyPx := tandyPx or color;
        mask := mask shr 1;
        case bank of
          0: tdyB800[cnt][k + colBase] := tandyPx;
          1: tdyBA00[cnt][k + colBase] := tandyPx;
          2: tdyBC00[cnt][k + colBase] := tandyPx;
          3: tdyBE00[cnt][k + colBase] := tandyPx;
        end;
      end;
      Inc(dstOff);
    end;
    Inc(cnt);
  end;
end;

procedure ClearRect(ulCol, ulRow, lrCol, lrRow: Byte);
var
  row: Word;
  firstByteColumn: Word;
  byteCount: Word;
begin
  firstByteColumn := ulCol * 4;
  byteCount := (lrCol - ulCol + 1) * 4;
  for row := ulRow * 2 to lrRow * 2 + 1 do begin
    FillChar(tdyB800[row][firstByteColumn], byteCount, 0);
    FillChar(tdyBA00[row][firstByteColumn], byteCount, 0);
    FillChar(tdyBC00[row][firstByteColumn], byteCount, 0);
    FillChar(tdyBE00[row][firstByteColumn], byteCount, 0);
  end;
end;

procedure ClearScreen;
begin
  FillChar(tdyB800, SizeOf(Types.TTandyBank), 0);
  FillChar(tdyBA00, SizeOf(Types.TTandyBank), 0);
  FillChar(tdyBC00, SizeOf(Types.TTandyBank), 0);
  FillChar(tdyBE00, SizeOf(Types.TTandyBank), 0);
end;

procedure WriteChar(col, row, attr, count, ch: Byte);
begin
  DaxIo.BiosWriteChar(GDVars.pageMain, col, row, attr, count, ch);
end;

procedure CellFill(color: Byte; var colorMap: Types.TColorMap; var cell: Types.TCellBytes);
begin
  FillChar(cell, SizeOf(cell), GDConsts.tandyColorFill[color]);
end;

{ no palette registers }
procedure SetPalette(registerIndex, color: Byte);
begin
end;

procedure Install;
begin
  with GDVars.video do begin
    name := 'Tandy';
    colours := 16;
    hasPalette := False;
    keyed := False;
    cellShift := 2;
    screenShift := 2;
    maskShift := 0;
    CellFill := VidTdy.CellFill;
    biosMode := 9;
    ramVideoParas := 1024;
    Start := VidTdy.Start;
    FlushSpans := VidTdy.FlushSpans;
    ShowPic := VidTdy.ShowPic;
    DrawGlyph := VidTdy.DrawGlyph;
    ClearRect := VidTdy.ClearRect;
    ClearScreen := VidTdy.ClearScreen;
    WriteChar := VidTdy.WriteChar;
    ExpandFrames := PicTdy.ExpandFrames;
    MirrorFrame := PicTdy.MirrorFrame;
    RemapColour := PicTdy.RemapColour;
    RecolorFrame := PicTdy.RecolorFrame;
    PutPixelRow := PicTdy.PutPixelRow;
    InitRowTables := PicTdy.InitRowTables;
    SetPalette := VidTdy.SetPalette;
  end;
end;

end.

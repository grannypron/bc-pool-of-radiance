{ The CGA video driver: BIOS mode 4, 320x200 in 4 colours at 2 bits a pixel, even and odd rows in separate banks at
  $B800 and $BA00. Resident, since its routines are the hot ones; GameBoot installs it when POOL.CFG names CGA (phase 6
  of docs/refactor-plan.md). }
{$F+}
{$I COMPILER.INC}
unit VidCga;

interface

{ Make this the video driver: fill GDVars.video. }
procedure Install;

implementation

uses Types, C_Video, GDConsts, GDVars, DaxIo, Blit, PicCga;

var
  { the two banks: even scanlines at $B800, odd at $BA00, 80 bytes a scanline and 4 scanlines of each to a text row }
  cgaB800: array[0..255] of Types.TCgaRow {$IFNDEF FPC}absolute C_Video.GFX_BANK0_SEG:$0000{$ENDIF};
  cgaBA00: array[0..255] of Types.TCgaRow {$IFNDEF FPC}absolute C_Video.GFX_BANK1_SEG:$0000{$ENDIF};

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
           Mem[GDVars.cgaRowSeg[row + 8]:GDVars.spanScreenOfs[row] + 2],
           GDVars.spanLastOfs[row] - GDVars.spanFirstOfs[row] + 1);
end;

{ 2 bytes per 8-pixel cell, a row at a time through the row segments }
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
    rowBytes := width * 2;
    srcOff := 0;
    firstRow := screenY * 8;
    lastRow := firstRow + height - 1;
    colOff := screenX * 2;
    for row := firstRow to lastRow do begin
      Move(pic^.data[srcOff], Mem[GDVars.cgaRowSeg[row]:colOff], rowBytes);
      Inc(srcOff, rowBytes);
    end;
  end;
end;

{ color is mapped to CGA's through attrTable; each pixel's 2 bits come from cgaColorPat }
procedure DrawGlyph(col, row, color, glyph: Byte);
var
  dstOff: Word;
  cnt: Word;
  cgaWord: Word;
  k: Byte;
  mask: Byte;
  outerRow: Byte;
begin
  color := GDConsts.attrTable[color];
  dstOff := row * 4;
  cnt := 0;
  for outerRow := 0 to 3 do begin
    cgaWord := 0;
    mask := $80;
    for k := 0 to 7 do begin
      if (GDVars.gameFont^[glyph][cnt] and mask) > 0 then
        cgaWord := cgaWord or (GDConsts.cgaPixelMask[k] and GDConsts.cgaColorPat[color]);
      mask := mask shr 1;
    end;
    cgaB800[dstOff][col] := Swap(cgaWord);
    Inc(cnt);
    cgaWord := 0;
    mask := $80;
    for k := 0 to 7 do begin
      if (GDVars.gameFont^[glyph][cnt] and mask) > 0 then
        cgaWord := cgaWord or (GDConsts.cgaPixelMask[k] and GDConsts.cgaColorPat[color]);
      mask := mask shr 1;
    end;
    cgaBA00[dstOff][col] := Swap(cgaWord);
    Inc(cnt);
    Inc(dstOff);
  end;
end;

procedure ClearRect(ulCol, ulRow, lrCol, lrRow: Byte);
var
  row: Word;
  byteCount: Word;
begin
  byteCount := (lrCol - ulCol + 1) * 2;
  for row := ulRow * 4 to lrRow * 4 + 3 do begin
    FillChar(cgaB800[row][ulCol], byteCount, 0);
    FillChar(cgaBA00[row][ulCol], byteCount, 0);
  end;
end;

procedure ClearScreen;
begin
  FillChar(cgaBA00, SizeOf(Types.TCgaBank), 0);
  FillChar(cgaB800, SizeOf(Types.TCgaBank), 0);
end;

{ the attribute's colour (its low four bits) mapped through attrTable, on the one page }
procedure WriteChar(col, row, attr, count, ch: Byte);
begin
  DaxIo.BiosWriteChar(GDVars.pageMain, col, row, GDConsts.attrTable[attr and $0F], count, ch);
end;

procedure CellFill(color: Byte; var colorMap: Types.TColorMap; var cell: Types.TCellBytes);
begin
  { the colour map picks which of the 4 colours shows color }
  FillChar(cell, SizeOf(cell), GDConsts.cgaColorFill[Blit.SrcNibble(color, colorMap)]);
end;

{ no palette registers }
procedure SetPalette(registerIndex, color: Byte);
begin
end;

procedure Install;
begin
  with GDVars.video do begin
    name := 'CGA';
    colours := 4;
    hasPalette := False;
    keyed := False;
    cellShift := 1;
    screenShift := 1;
    maskShift := 0;
    CellFill := VidCga.CellFill;
    biosMode := 4;
    ramVideoParas := 0;
    Start := VidCga.Start;
    FlushSpans := VidCga.FlushSpans;
    ShowPic := VidCga.ShowPic;
    DrawGlyph := VidCga.DrawGlyph;
    ClearRect := VidCga.ClearRect;
    ClearScreen := VidCga.ClearScreen;
    WriteChar := VidCga.WriteChar;
    ExpandFrames := PicCga.ExpandFrames;
    MirrorFrame := PicCga.MirrorFrame;
    RemapColour := PicCga.RemapColour;
    RecolorFrame := PicCga.RecolorFrame;
    PutPixelRow := PicCga.PutPixelRow;
    InitRowTables := PicCga.InitRowTables;
    SetPalette := VidCga.SetPalette;
  end;
end;

end.

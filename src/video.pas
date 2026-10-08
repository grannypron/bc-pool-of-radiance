{ EGA graphics-controller setup, page selection and palette register control. }
{$F+}
unit Video;

interface

uses Types, C_Video, C_Ega, GDConsts, GDVars, Dos;

procedure InitVideoPages;

procedure SetupEgaCurrentPage(page: Byte);

procedure SetupEgaOtherPage(page: Byte);

procedure SetVideoMode(mode: Byte);

procedure RestoreVideoMode;

procedure FillRectEga(ulCol, ulRow, lrCol, lrRow: ShortInt; page, color: Byte);

procedure SetPaletteRegister(reg, color: Byte);

procedure ResetEgaGC;

implementation

  { Video-mode and EGA page state shared through GameDat1 (the page segments are also used by TextRend) }

var
  displayMode: Types.TVideoMode absolute GDVars.videoMode;

{ Make page 0 the main (displayed) page and page 1 the other page, then, on EGA only, set up both page segments through
  SetupEgaCurrentPage and SetupEgaOtherPage. }
procedure InitVideoPages;
begin
  GDVars.pageMain := 0;
  GDVars.pageNum := 1;
  case displayMode of
    Types.vmCGA: ;
    Types.vmEGA: begin
      Video.SetupEgaCurrentPage(GDVars.pageMain);
      Video.SetupEgaOtherPage(GDVars.pageNum);
    end;
    Types.vmTandy: ;
  end;
end;

{ Make page the active display page through the BIOS and store its segment, EGA_VIDEO_SEG plus 512 paragraphs per page,
  in egaCurPage. }
procedure SetupEgaCurrentPage(page: Byte);
begin
  GDVars.dsInterruptRegisters.ah := 5;
  GDVars.dsInterruptRegisters.al := page;
  Intr($10, GDVars.dsInterruptRegisters);
  GDVars.egaCurPage := C_Video.EGA_VIDEO_SEG + (Word(page) shl 9);
end;

{ Store the segment of page in egaOtherPage, with the same 512-paragraph stride and no BIOS call. }
procedure SetupEgaOtherPage(page: Byte);
begin
  GDVars.egaOtherPage := C_Video.EGA_VIDEO_SEG + (Word(page) shl 9);
end;

{ Remember the current video mode in savedVideoMode, switch the BIOS to mode and record it as curVideoMode. Success is
  not checked. }
procedure SetVideoMode(mode: Byte);
var
  { unused }
  pad: Word;
begin
  GDVars.savedVideoMode := GDVars.curVideoMode;
  GDVars.dsInterruptRegisters.ah := 0;
  GDVars.dsInterruptRegisters.al := mode;
  Intr($10, GDVars.dsInterruptRegisters);
  GDVars.curVideoMode := mode;
end;

{ Return to the video mode that was in effect before the last SetVideoMode. }
procedure RestoreVideoMode;
begin
  Video.SetVideoMode(GDVars.savedVideoMode);
end;

{ Fill the character-cell rectangle ulCol,ulRow..lrCol,lrRow (columns are bytes, rows are 8 scanlines of 40 bytes) of
  EGA page with color, using write mode 2. The fill goes through egaOtherPage, temporarily pointed at page; afterwards
  write mode 0 is restored and egaOtherPage is pointed back at pageNum. }
procedure FillRectEga(ulCol, ulRow, lrCol, lrRow: ShortInt; page, color: Byte);
var
  savedPage: Byte;
  dstOff: Word;
  rowCount: Word;
  i: Word;
begin
  savedPage := GDVars.pageNum;
  dstOff := Word(ulRow) * 40 * 8 + ulCol;
  rowCount := (lrRow - ulRow + 1) * 8 - 1;
  Video.SetupEgaOtherPage(page);
  Video.ResetEgaGC;
  Port[C_Ega.GC_ADDR_PORT] := C_Ega.GC_MODE_REG;
  Port[C_Ega.GC_DATA_PORT] := 2;
  for i := 0 to rowCount do begin
    FillChar(Mem[GDVars.egaOtherPage: dstOff], lrCol - ulCol + 1, color);
    Inc(dstOff, 40);
  end;
  Port[C_Ega.GC_ADDR_PORT] := C_Ega.GC_MODE_REG;
  Port[C_Ega.GC_DATA_PORT] := C_Ega.GC_WRITE_MODE_0;
  GDVars.pageNum := savedPage;
  Video.SetupEgaOtherPage(GDVars.pageNum);
end;

{ Set EGA palette register reg to color through the BIOS; colors 8..15 are converted to the palette's intensity
  encoding. }
procedure SetPaletteRegister(reg, color: Byte);
begin
  GDVars.dsInterruptRegisters.ah := $10;
  GDVars.dsInterruptRegisters.al := 0;
  if color < 8 then
    GDVars.dsInterruptRegisters.bh := color
  else
    GDVars.dsInterruptRegisters.bh := color + 8;
  GDVars.dsInterruptRegisters.bl := reg;
  Intr($10, GDVars.dsInterruptRegisters);
end;

{ Reset the EGA graphics controller registers to their defaults, then enable all planes in the sequencer map mask. }
procedure ResetEgaGC;
begin
  Port[C_Ega.GC_ADDR_PORT] := 0;
  Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 1;
  Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 2;
  Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 3;
  Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 4;
  Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 5;
  Port[C_Ega.GC_DATA_PORT] := 0;
  Port[C_Ega.GC_ADDR_PORT] := 7;
  Port[C_Ega.GC_DATA_PORT] := $0F;
  Port[C_Ega.GC_ADDR_PORT] := 8;
  Port[C_Ega.GC_DATA_PORT] := $FF;
  Port[C_Ega.SEQ_ADDR_PORT] := C_Ega.SEQ_MAP_MASK_REG;
  Port[C_Ega.SEQ_DATA_PORT] := C_Ega.MAP_MASK_ALL_PLANES;
end;

begin
end.

{ Text-window borders, rectangle clearing and centered titles. Borders use the 8x8 symbol set. }
{$O-,F+}
unit Border;

interface

uses Types, Crt, C_Video, GDConsts, GDVars, TextRend, Sym8x8;

procedure DrawBorder(ulCol, ulRow, lrCol, lrRow: ShortInt; corner: Byte);

procedure ClearBox(ulCol, ulRow, lrCol, lrRow: ShortInt);

procedure DrawWindow(ulCol, ulRow, lrCol, lrRow: ShortInt; corner, color: Byte; title: Types.TStr40);

implementation

const
  BORDER_SYM_BASE = 276;

  { CGA and Tandy interleave scanlines across video-memory banks. Advancing a row changes the segment: CGA uses two
    banks and Tandy uses four. }

var
  { 0=CGA 1=EGA 2=Tandy }
  displayMode: Types.TVideoMode absolute GDVars.videoMode;
  cgaBank0: Types.TCgaBank absolute C_Video.GFX_BANK0_SEG:0;
  cgaBank1: Types.TCgaBank absolute C_Video.GFX_BANK1_SEG:0;
  tandyBank0: Types.TTandyBank absolute C_Video.GFX_BANK0_SEG:0;
  tandyBank1: Types.TTandyBank absolute C_Video.GFX_BANK1_SEG:0;
  tandyBank2: Types.TTandyBank absolute C_Video.GFX_BANK2_SEG:0;
  tandyBank3: Types.TTandyBank absolute C_Video.GFX_BANK3_SEG:0;

{ Draw a border one cell outside the requested text rectangle. Expand the coordinates to the border ring, then draw
  symbol BORDER_SYM_BASE + corner*3 at the four corners, +2 along the top and bottom edges and +1 down both sides. }
procedure DrawBorder(ulCol, ulRow, lrCol, lrRow: ShortInt; corner: Byte);
var
  i: ShortInt;
  symBase: Word;
begin
  Dec(ulCol);
  Dec(ulRow);
  Inc(lrCol);
  Inc(lrRow);
  symBase := corner * 3 + BORDER_SYM_BASE;
  Sym8x8.Put8x8Sym(ulCol, ulRow, symBase + 0, False, False);
  Sym8x8.Put8x8Sym(lrCol, ulRow, symBase + 0, False, False);
  Sym8x8.Put8x8Sym(ulCol, lrRow, symBase + 0, False, False);
  Sym8x8.Put8x8Sym(lrCol, lrRow, symBase + 0, False, False);
  for i := ulCol + 1 to lrCol - 1 do begin
    Sym8x8.Put8x8Sym(i, ulRow, symBase + 2, False, False);
    Sym8x8.Put8x8Sym(i, lrRow, symBase + 2, False, False);
  end;
  for i := ulRow + 1 to lrRow - 1 do begin
    Sym8x8.Put8x8Sym(ulCol, i, symBase + 1, False, False);
    Sym8x8.Put8x8Sym(lrCol, i, symBase + 1, False, False);
  end;
end;

{ Clear a character-cell rectangle to black. EGA clears it on both pages through TextRend.FillRectEga. CGA clears 4
  scanlines per character row in each of its 2 banks, 2 bytes per character; Tandy clears 2 scanlines per character row
  in each of its 4 banks, 4 bytes per character. }
procedure ClearBox(ulCol, ulRow, lrCol, lrRow: ShortInt);
var
  top: Word;
  bot: Word;
  colOff: Word;
  rowBytes: Word;
  r: Word;
begin
  case displayMode of
    Types.vmCGA: begin
      top := ulRow * 4;
      bot := lrRow * 4 + 3;
      rowBytes := (lrCol - ulCol + 1) * 2;
      for r := top to bot do begin
        FillChar(cgaBank0[r][Word(ulCol) * 2], rowBytes, 0);
        FillChar(cgaBank1[r][Word(ulCol) * 2], rowBytes, 0);
      end;
    end;
    Types.vmEGA: begin
      TextRend.FillRectEga(ulCol, ulRow, lrCol, lrRow, 0, Black);
      TextRend.FillRectEga(ulCol, ulRow, lrCol, lrRow, 1, Black);
    end;
    Types.vmTandy: begin
      top := ulRow * 2;
      bot := lrRow * 2 + 1;
      colOff := ulCol * 4;
      rowBytes := (lrCol - ulCol + 1) * 4;
      for r := top to bot do begin
        FillChar(tandyBank0[r][colOff], rowBytes, 0);
        FillChar(tandyBank1[r][colOff], rowBytes, 0);
        FillChar(tandyBank2[r][colOff], rowBytes, 0);
        FillChar(tandyBank3[r][colOff], rowBytes, 0);
      end;
    end;
  end;
end;

{ Clear the window, draw its border and center a nonempty title on the window's first text row (ulRow). }
procedure DrawWindow(ulCol, ulRow, lrCol, lrRow: ShortInt; corner, color: Byte; title: Types.TStr40);
begin
  Border.ClearBox(ulCol, ulRow, lrCol, lrRow);
  Border.DrawBorder(ulCol, ulRow, lrCol, lrRow, corner);
  if Length(title) <> 0 then
    TextRend.DisplayString((ulCol + lrCol - Length(title)) div 2, ulRow, color, title);
end;

begin
end.

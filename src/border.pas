{ Text-window borders, rectangle clearing and centered titles. Borders use the 8x8 symbol set. }
{$O+,F+}
{$I COMPILER.INC}
unit Border;

interface

uses Types;

procedure DrawBorder(ulCol, ulRow, lrCol, lrRow: ShortInt; corner: Byte);

procedure ClearBox(ulCol, ulRow, lrCol, lrRow: ShortInt);

procedure DrawWindow(ulCol, ulRow, lrCol, lrRow: ShortInt; corner, color: Byte; title: Types.TStr40);

implementation

uses TextRend, Sym8x8;
const
  BORDER_SYM_BASE = 276;
  { the 40x25 text grid }
  LAST_COL = 39;
  LAST_ROW = 24;

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

{ Clear a character-cell rectangle to black: cut to the 40x25 grid first, so a rectangle partly off the screen clears
  what is on it, then TextRend.ClearRect (an empty one clears nothing). }
procedure ClearBox(ulCol, ulRow, lrCol, lrRow: ShortInt);
begin
  if ulCol < 0 then ulCol := 0;
  if ulRow < 0 then ulRow := 0;
  if lrCol > LAST_COL then lrCol := LAST_COL;
  if lrRow > LAST_ROW then lrRow := LAST_ROW;
  TextRend.ClearRect(ulCol, ulRow, lrCol, lrRow);
end;

{ Clear the window, draw its border and center a nonempty title on the window's first text row (ulRow). The title is
  centred between ulCol and lrCol - 1, not lrCol: that is SSI's (ulCol + lrCol - Length(title)) div 2, so the titles
  sit where SSI put them (#977). }
procedure DrawWindow(ulCol, ulRow, lrCol, lrRow: ShortInt; corner, color: Byte; title: Types.TStr40);
begin
  Border.ClearBox(ulCol, ulRow, lrCol, lrRow);
  Border.DrawBorder(ulCol, ulRow, lrCol, lrRow, corner);
  if Length(title) <> 0 then
    TextRend.DisplayCentered(ulCol, lrCol - 1, ulRow, color, title);
end;

end.

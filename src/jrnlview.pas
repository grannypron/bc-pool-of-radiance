{ The Journal screen: the list of the Adventurer's Journal's proclamations, entries and tavern tales in a column on the
  left, and the highlighted item's title and text a page at a time in the pane beside it.

  The pane follows the highlight, but only once the highlight has rested for PREVIEW_DELAY: reading an item can load an
  overlay, so the preview is drawn from MenuCore's idle hook while the bottom line waits for a key, and a held arrow key
  scrolls the list without stopping to draw each item on the way. }
{$O+,F+}
{$I COMPILER.INC}
unit JrnlView;

interface

{ Show the Journal until Exit or Escape, then redraw the exploration screen. Up and Down (also Home and End) move the
  highlight through the list, scrolling it at either end of the column and wrapping at either end of the list; Page Up
  and Page Down scroll it a column at a time. The highlighted item's title and first page show in the pane once the
  highlight rests. Select shows the highlighted item at once and turns to its text: Next and Prev, offered while the
  selected item has a later or an earlier page, turn its pages until the highlight moves again. }
procedure JournalMenu;

implementation

uses Crt, Types, C_Jrnl, C_Keys, GDVars, TextRend, Border, MenuCore, CharHlp, JrnlList, CharDisp, C_MSG;

const
  { The pane holds the item: its title on TITLE_ROW and its text from TEXT_TOP down, each as wide as the text is
    wrapped. The list column fills the rest of the frame on its left, one label a row, with the border column between
    them. }
  PANE_RIGHT = 38;
  PANE_LEFT = PANE_RIGHT - C_Jrnl.JOURNAL_WIDTH + 1;
  LIST_LEFT = 1;
  LIST_RIGHT = PANE_LEFT - 2;
  TOP_ROW = 1;
  BOTTOM_ROW = 22;
  TITLE_ROW = 1;
  TEXT_TOP = 3;
  { the pane's text rows; an item longer than that gives up a row to "(more)" above a page with one before it and below
    a page with one after it }
  TEXT_ROWS = BOTTOM_ROW - TEXT_TOP + 1;
  { how long the highlight rests before the pane shows its item, in TextRend.GetTicks centiseconds }
  PREVIEW_DELAY = 25;

var
  { the highlighted item, and the item on the list's first row }
  sel: Integer;
  top: Integer;
  { the item in the pane (0 while the pane is empty), its line count, and its page out of pages }
  shown: Integer;
  lines: Integer;
  page: Integer;
  pages: Integer;
  { set when the highlight has moved and the pane has yet to follow it, with the time it moved }
  previewDue: Boolean;
  movedAt: LongInt;

{ Draw item n's label on its row of the list in color.
  @param(n The item's place in the list, on the column's visible rows.)
  @param(color The label's color.) }
procedure DrawLabel(n: Integer; color: Byte);
begin
  TextRend.DisplayString(LIST_LEFT, TOP_ROW + n - top, color,
                         Copy(JrnlList.EntryLabel(n), 1, LIST_RIGHT - LIST_LEFT + 1));
end;

{ Clear the list column and draw the labels from item top, the highlighted one in White. }
procedure DrawList;
var
  n: Integer;
begin
  Border.ClearBox(LIST_LEFT, TOP_ROW, LIST_RIGHT, BOTTOM_ROW);
  n := top;
  while (n <= C_Jrnl.JOURNAL_COUNT) and (n - top <= BOTTOM_ROW - TOP_ROW) do begin
    if n = sel then
      JrnlView.DrawLabel(n, White)
    else
      JrnlView.DrawLabel(n, LightGreen);
    Inc(n);
  end;
end;

{ Draw "(more)" centered on a row of the pane.
  @param(row The pane's row.) }
procedure DrawMore(row: Integer);
begin
  TextRend.DisplayCentered(PANE_LEFT, PANE_RIGHT, row, White, '(more)');
end;

{ The shown item's first line on page p: past the first page, which holds TEXT_ROWS - 1 lines under a "(more)", each
  page between holds TEXT_ROWS - 2 between two.
  @param(p The page, from 1.) }
function PageStart(p: Integer): Integer;
begin
  if p <= 1 then
    PageStart := 1
  else
    PageStart := TEXT_ROWS + (p - 2) * (TEXT_ROWS - 2);
end;

{ Clear the pane and draw the shown item's title, centered, and the lines of its current page, with "(more)" on the
  pane's top row when there is a page before it and on its bottom row when there is one after it. }
procedure DrawPage;
var
  title: string;
  line: Integer;
  row: Integer;
  lastRow: Integer;
begin
  Border.ClearBox(PANE_LEFT, TITLE_ROW, PANE_RIGHT, TITLE_ROW);
  Border.ClearBox(PANE_LEFT, TEXT_TOP, PANE_RIGHT, BOTTOM_ROW);
  title := Copy(JrnlList.EntryTitle(shown), 1, PANE_RIGHT - PANE_LEFT + 1);
  TextRend.DisplayCentered(PANE_LEFT, PANE_RIGHT, TITLE_ROW, White, title);
  row := TEXT_TOP;
  lastRow := BOTTOM_ROW;
  if page > 1 then begin
    JrnlView.DrawMore(TEXT_TOP);
    Inc(row);
  end;
  if page < pages then begin
    JrnlView.DrawMore(BOTTOM_ROW);
    Dec(lastRow);
  end;
  line := JrnlView.PageStart(page);
  while (row <= lastRow) and (line <= lines) do begin
    TextRend.DisplayString(PANE_LEFT, row, LightGreen,
                           Copy(JrnlList.TextLine(shown, line), 1, PANE_RIGHT - PANE_LEFT + 1));
    Inc(line);
    Inc(row);
  end;
end;

{ Show the highlighted item's first page in the pane, unless the pane shows it already. }
procedure ShowSelected;
begin
  previewDue := False;
  if shown <> sel then begin
    shown := sel;
    lines := JrnlList.LineCount(shown);
    { a page holds TEXT_ROWS lines alone, TEXT_ROWS - 1 first or last, and TEXT_ROWS - 2 between }
    if lines <= TEXT_ROWS then
      pages := 1
    else begin
      pages := 2;
      while lines > JrnlView.PageStart(pages) + TEXT_ROWS - 2 do
        Inc(pages);
    end;
    page := 1;
    JrnlView.DrawPage;
  end else if page <> 1 then begin
    page := 1;
    JrnlView.DrawPage;
  end;
end;

{ Start the wait before the pane follows the highlight, when it has moved from item old.
  @param(old The item highlighted before the move.) }
procedure Moved(old: Integer);
begin
  if sel <> old then begin
    previewDue := True;
    movedAt := TextRend.GetTicks;
  end;
end;

{ MenuCore's idle hook while the Journal waits for a key: once the highlight has rested for PREVIEW_DELAY with no key
  waiting, show its item. }
procedure TickPreview;
var
  now: LongInt;
begin
  if previewDue and not KeyPressed then begin
    now := TextRend.GetTicks;
    { the tick count restarts at midnight }
    if (now < movedAt) or (now - movedAt >= PREVIEW_DELAY) then
      JrnlView.ShowSelected;
  end;
end;

{ Move the highlight to item n, kept within the list, scrolling the list when n is off the column, and start the wait
  before the pane follows it.
  @param(n The item's place in the list.) }
procedure MoveTo(n: Integer);
var
  old: Integer;
begin
  old := sel;
  if n > C_Jrnl.JOURNAL_COUNT then
    n := C_Jrnl.JOURNAL_COUNT;
  if n < 1 then
    n := 1;
  if (n < top) or (n > top + BOTTOM_ROW - TOP_ROW) then begin
    if n < top then
      top := n
    else
      top := n - (BOTTOM_ROW - TOP_ROW);
    sel := n;
    JrnlView.DrawList;
  end else begin
    JrnlView.DrawLabel(sel, LightGreen);
    sel := n;
    JrnlView.DrawLabel(sel, White);
  end;
  JrnlView.Moved(old);
end;

{ Scroll the list a column down or up, kept within the list, with the highlight staying on its row.
  @param(down True for down, False for up.) }
procedure ScrollColumn(down: Boolean);
var
  row: Integer;
  old: Integer;
begin
  old := sel;
  row := sel - top;
  if down then
    top := top + BOTTOM_ROW - TOP_ROW + 1
  else
    top := top - (BOTTOM_ROW - TOP_ROW + 1);
  if top > C_Jrnl.JOURNAL_COUNT - (BOTTOM_ROW - TOP_ROW) then
    top := C_Jrnl.JOURNAL_COUNT - (BOTTOM_ROW - TOP_ROW);
  if top < 1 then
    top := 1;
  sel := top + row;
  if sel > C_Jrnl.JOURNAL_COUNT then
    sel := C_Jrnl.JOURNAL_COUNT;
  JrnlView.DrawList;
  JrnlView.Moved(old);
end;

procedure JournalMenu;
var
  menu: Types.TStr40;
  ch: Char;
  { the bottom-line option chosen last, kept current while it is offered }
  lastKey: Char;
  ext: Boolean;
  { set by Select: Next and Prev page the item until the highlight moves }
  reading: Boolean;
  savedChoice: Byte;

  { The option number of hotkey key on the bottom line, or 1 (Select) when it is not offered. }
  function OptionOf(key: Char): Byte;
  var
    i: Byte;
    n: Byte;
  begin
    OptionOf := 1;
    n := 0;
    for i := 1 to Length(menu) do
      if menu[i] in ['A'..'Z'] then begin
        Inc(n);
        if menu[i] = key then
          OptionOf := n;
      end;
  end;

begin
  savedChoice := GDVars.horizChoice;
  sel := 1;
  top := 1;
  shown := 0;
  lines := 0;
  page := 1;
  pages := 1;
  reading := False;
  lastKey := 'S';
  { the list's box goes first, then the text box and the title box, so the gold corners stay where the borders meet }
  Border.ClearBox(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
  Border.DrawBorder(LIST_LEFT, TOP_ROW, LIST_RIGHT, BOTTOM_ROW, 0);
  Border.DrawBorder(PANE_LEFT, TEXT_TOP, PANE_RIGHT, BOTTOM_ROW, 0);
  Border.DrawBorder(PANE_LEFT, TITLE_ROW, PANE_RIGHT, TITLE_ROW, 0);
  JrnlView.DrawList;
  previewDue := True;
  movedAt := TextRend.GetTicks;
  MenuCore.idleHook := JrnlView.TickPreview;
  repeat
    menu := 'Select';
    if reading and (page < pages) then
      menu := menu + ' Next';
    if reading and (page > 1) then
      menu := menu + ' Prev';
    menu := menu + ' Exit';
    GDVars.horizChoice := OptionOf(lastKey);
    ch := MenuCore.MenuHorizontal('', menu, LightMagenta, LightGreen, White, True, False, ext);
    if ext then begin
      case ch of
        C_Keys.UP, C_Keys.HOME: if sel > 1 then
                                  JrnlView.MoveTo(sel - 1)
                                else
                                  JrnlView.MoveTo(C_Jrnl.JOURNAL_COUNT);
        C_Keys.DOWN, C_Keys.END_KEY: if sel < C_Jrnl.JOURNAL_COUNT then
                                       JrnlView.MoveTo(sel + 1)
                                     else
                                       JrnlView.MoveTo(1);
        C_Keys.PGUP: JrnlView.ScrollColumn(False);
        C_Keys.PGDN: JrnlView.ScrollColumn(True);
      end;
      if previewDue then begin
        reading := False;
        { after a move, Enter takes the highlighted item }
        lastKey := 'S';
      end;
    end else begin
      lastKey := ch;
      case ch of
        'S': begin
               JrnlView.ShowSelected;
               reading := True;
             end;
        'N': if page < pages then begin
               Inc(page);
               JrnlView.DrawPage;
             end;
        'P': if page > 1 then begin
               Dec(page);
               JrnlView.DrawPage;
             end;
      end;
    end;
  until not ext and (ch in [C_Keys.NONE, 'E']);
  @MenuCore.idleHook := nil;
  GDVars.horizChoice := savedChoice;
  CharDisp.DisplayNoncombatInterface;
end;

end.

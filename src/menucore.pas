{ Menu input, animated menu pictures and linked lists of display strings. }
{$O+,F+}
unit MenuCore;

interface

uses Types, GDConsts, GDVars, Crt, GameIo, TextRend, Border, Portrait, C_Keys;

{ Return member n (0-based) of list, or nil when the list is shorter. }
function FindListMember(n: Integer; list: Types.PItemRec): Types.PItemRec;

{ Return the number of members in list. }
function ListCount(list: Types.PItemRec): Integer;

{ Bottom-line menu: query in qCol, then menu with its digits and capital letters (the hotkeys) in hlCol and the rest in
  mCol. Waits for a key matching a menu character and returns it upper-cased; Escape returns #0. With reinterpret, Enter
  also ends the menu (returning #13), an extended key returns its scan code with ext set, and digits 1-9 map through
  GDConsts.keypadScan to keypad scan codes with ext set. animate cycles the animData pictures while waiting. }
function MenuHorizontal(query, menu: Types.TStr40; qCol, mCol, hlCol: Byte; reinterpret, animate: Boolean;
                        var ext: Boolean): Char;

{ Blank the bottom text line. }
procedure ClearBottomLine;

{ Vertical list menu in the box ulCol,ulRow..lrCol,lrRow with menu (plus Next/Prev/Exit as they apply) on the bottom
  line. idx is zero-based; redraw requests repainting. Label rows have inUse set; they are drawn in qCol and skipped by
  the cursor. An empty list returns #0 with idx=0 and sel=nil; Exit returns #0 with sel=nil; Escape arrives from
  MenuHorizontal as #0 and falls to the selection branch, returning #0 with sel set to the highlighted entry. Any other
  menu key returns that key with sel set to the highlighted entry. }
function MenuVertical(query, menu: Types.TStr40; qCol, mCol, hlCol: Byte; ulCol, ulRow, lrCol, lrRow: ShortInt;
                      list: Types.PItemRec; addExit: Boolean; var redraw: Boolean; var idx: Integer;
                      var sel: Types.PItemRec): Char;

{ Ask a Yes/No question on the bottom line until Y or N is chosen; returns 'Y' or 'N'. }
function YesNoMenu(query: Types.TStr40; qCol, mCol, hlCol: Byte): Char;

{ Build a list of n empty members; the head is allocated even when n < 1. }
procedure AllocStringList(n: Integer; var list: Types.PItemRec);

{ Free every member. The caller's list pointer is left dangling, not set to nil. }
procedure FreeStringList(var list: Types.PItemRec);

implementation

var
  anim: Types.TMenuAnim absolute GDVars.animData;

function FindListMember(n: Integer; list: Types.PItemRec): Types.PItemRec;
var
  p: Types.PItemRec;
  i: Integer;
begin
  i := 0;
  p := list;
  while (p <> nil) and (i <> n) do begin
    p := p^.next;
    Inc(i);
  end;
  if i = n then
    FindListMember := p
  else
    FindListMember := nil;
end;

function ListCount(list: Types.PItemRec): Integer;
var
  p: Types.PItemRec;
  n: Integer;
begin
  n := 0;
  p := list;
  while p <> nil do begin
    Inc(n);
    p := p^.next;
  end;
  ListCount := n;
end;

function MenuHorizontal(query, menu: Types.TStr40; qCol, mCol, hlCol: Byte; reinterpret, animate: Boolean;
                        var ext: Boolean): Char;
var
  now: LongInt;
  frameTick: LongInt;
  ch: Char;
  pad5d: Byte;
  i: Byte;
  done: Boolean;
  mLen: Byte;
  qLen: Byte;
begin
  mLen := Length(menu);
  ch := #0;
  ext := False;
  done := False;
  frameTick := TextRend.GetTicks;
  if Length(query) <> 0 then
    TextRend.DisplayString(0, 24, qCol, query);
  qLen := Length(query) + 0;
  if mLen > 0 then begin
    for i := 1 to mLen do
      if menu[i] in ['0'..'9', 'A'..'Z'] then
        TextRend.RenderChar(qLen + i - 1, 24, hlCol, 1, Ord(menu[i]), 1)
      else
        TextRend.RenderChar(qLen + i - 1, 24, mCol, 1, Ord(menu[i]), 1);
    if qLen + mLen < 39 then
      TextRend.RenderChar(qLen + mLen, 24, Black, 39 - mLen - qLen + 1, 32, 1);
  end;
  repeat
    now := TextRend.GetTicks;
    if animate and (anim.current > 0) then begin
      Portrait.DisplayImageBuf(3, 3, animate, anim.frames[anim.current].pic);
      if now - frameTick > anim.frames[anim.current].time * 7 then begin
        Inc(anim.current);
        if anim.current > anim.count then
          anim.current := 1;
        frameTick := now;
      end;
    end;
    if KeyPressed then begin
      ch := GameIo.ReadGameKey;
      if ch = #0 then
      { #0 prefixes an extended key: the second ReadGameKey reads its scan code. It ends the menu (with ext set) only
        with reinterpret; otherwise it is ignored. }
      begin
        ch := GameIo.ReadGameKey;
        if reinterpret then begin
          ext := True;
          done := True;
        end;
      end else
        case ch of
          { Escape returns #0. }
          C_Keys.ESC: begin
                 done := True;
                 ch := C_Keys.NONE;
               end;
          C_Keys.ENTER: if reinterpret then
                 done := True;
        else begin
            ch := UpCase(ch);
            for i := 1 to mLen do
              if menu[i] = ch then
                done := True;
            if reinterpret then
              { Digits 1-9 map through GDConsts.keypadScan to keypad scan codes. }
              if ch in ['1'..'9'] then
              begin
                ch := Char(GDConsts.keypadScan[Ord(ch) - Ord('1')]);
                ext := True;
                done := True;
              end;
          end;
        end;
    end;
  until done;
  MenuHorizontal := ch;
end;

procedure ClearBottomLine;
begin
  TextRend.PrintSpaces(0, 24, Black, 40);
end;

function MenuVertical(query, menu: Types.TStr40; qCol, mCol, hlCol: Byte; ulCol, ulRow, lrCol, lrRow: ShortInt;
                      list: Types.PItemRec; addExit: Boolean; var redraw: Boolean; var idx: Integer;
                      var sel: Types.PItemRec): Char;
var
  width: Byte;
  count: Integer;
  ext: Boolean;
  rows: Integer;
  ch: Char;
  hMenu: Types.TStr40;
  hasNext: Boolean;
  hasPrev: Boolean;
  p: Types.PItemRec;
  headerCnt: Integer;
  total: Integer;

  { Last label (inUse) member among the first n, or the head when n = 0 and it is a label. The result is discarded by
    DrawPage. }
  function LastLabelBefore(n: Integer; l: Types.PItemRec): Types.PItemRec;
  var
    pp: Types.PItemRec;
    found: Types.PItemRec;
    i: Integer;
  begin
    i := 0;
    pp := l;
    found := nil;
    while (pp <> nil) and (i < n) do begin
      if pp^.inUse <> 0 then
        found := pp;
      pp := pp^.next;
      Inc(i);
    end;
    if (found = nil) and (l^.inUse <> 0) then
      LastLabelBefore := l
    else
      LastLabelBefore := found;
  end;

  { Clear the box and draw the list from member top, labels in qCol and entries in mCol. }
  procedure DrawPage(top: Integer);
  var
    pp: Types.PItemRec;
    q: Types.PItemRec;
    row: ShortInt;
  begin
    Border.ClearBox(ulCol, ulRow, lrCol, lrRow);
    pp := MenuCore.FindListMember(top, list);
    q := LastLabelBefore(top, list);
    row := ulRow;
    while (pp <> nil) and (row <= lrRow) do begin
      if pp^.inUse <> 0 then
        TextRend.DisplayString(ulCol, row, qCol, pp^.name)
      else
        TextRend.DisplayString(ulCol, row, mCol, pp^.name);
      pp := pp^.next;
      Inc(row);
    end;
  end;

  { Redraw member n in hlCol. }
  procedure HighlightLine(n: Integer);
  var
    pp: Types.PItemRec;
  begin
    pp := MenuCore.FindListMember(n, list);
    TextRend.DisplayString(ulCol, ulRow + (n - GDVars.vertTop), hlCol, pp^.name);
  end;

  { Redraw member n in its normal color. }
  procedure UnhighlightLine(n: Integer);
  var
    pp: Types.PItemRec;
  begin
    pp := MenuCore.FindListMember(n, list);
    if pp^.inUse <> 0 then
      TextRend.DisplayString(ulCol, ulRow + (n - GDVars.vertTop), qCol, pp^.name)
    else
      TextRend.DisplayString(ulCol, ulRow + (n - GDVars.vertTop), mCol, pp^.name);
  end;

  { Move idx off label rows in the given direction, wrapping within the visible page; gives up after a page of rows. }
  procedure SkipLabels(down: Boolean);
  var
    k: Integer;
  begin
    k := 0;
    if down then
      while (k < rows) and (MenuCore.FindListMember(idx, list)^.inUse <> 0) do begin
        Inc(k);
        Inc(idx);
        if GDVars.vertTop + rows - 1 < idx then
          idx := GDVars.vertTop;
      end else
      while (k < rows) and (MenuCore.FindListMember(idx, list)^.inUse <> 0) do begin
        Inc(k);
        Dec(idx);
        if idx < GDVars.vertTop then
          idx := GDVars.vertTop + rows - 1;
      end;
  end;

  { Scroll a page down or up, clamped to the list, keep the cursor's row on the page and redraw it. }
  procedure MovePage(down: Boolean);
  var
    rel: Integer;
  begin
    rel := idx - GDVars.vertTop;
    if down then begin
      Inc(GDVars.vertTop, rows);
      if count - rows < GDVars.vertTop then
        GDVars.vertTop := count - rows;
    end else begin
      Dec(GDVars.vertTop, rows);
      if GDVars.vertTop < 0 then
        GDVars.vertTop := 0;
    end;
    idx := GDVars.vertTop + rel;
    SkipLabels(down);
    DrawPage(GDVars.vertTop);
  end;

  { Move the cursor one line, wrapping within the visible page, then skip label rows. Note: idx is not clamped to the
    list length, so on a page with fewer entries than rows it can pass the last member. }
  procedure MoveLine(down: Boolean);
  var
    pp: Types.PItemRec;
    k: Integer;
    n: Integer;
  begin
    if down then begin
      Inc(idx);
      if GDVars.vertTop + rows - 1 < idx then
        idx := GDVars.vertTop;
    end else begin
      Dec(idx);
      if idx < GDVars.vertTop then
        idx := GDVars.vertTop + rows - 1;
    end;
    SkipLabels(down);
  end;

begin
  if list = nil then begin
    idx := 0;
    sel := nil;
    MenuVertical := C_Keys.NONE;
  end else begin
    width := lrCol - ulCol + 1;
    count := MenuCore.ListCount(list);
    rows := lrRow - ulRow + 1;
    p := list;
    headerCnt := 0;
    while (p <> nil) and (p^.inUse <> 0) do begin
      p := p^.next;
      Inc(headerCnt);
    end;
    p := list;
    total := 0;
    while p <> nil do begin
      p := p^.next;
      Inc(total);
    end;
    if GDVars.vertTop > idx then begin
      GDVars.vertTop := idx;
      redraw := True;
    end;
    if GDVars.vertTop > total then begin
      GDVars.vertTop := 0;
      redraw := True;
    end;
    Inc(idx);
    MoveLine(False);
    if redraw then
      DrawPage(GDVars.vertTop);
    redraw := False;
    repeat
      HighlightLine(idx);
      hMenu := menu;
      hasNext := False;
      hasPrev := False;
      if count - rows > GDVars.vertTop then begin
        hMenu := hMenu + ' Next';
        hasNext := True;
      end;
      if GDVars.vertTop > headerCnt then begin
        hMenu := hMenu + ' Prev';
        hasPrev := True;
      end;
      if addExit then
        hMenu := hMenu + ' Exit';
      ch := MenuCore.MenuHorizontal(query, hMenu, qCol, mCol, hlCol, True, False, ext);
      UnhighlightLine(idx);
      if ext then
        case ch of
          { Home = line up }
          C_Keys.HOME: MoveLine(False);
          { End = line down }
          C_Keys.END_KEY: MoveLine(True);
          { Page Up = previous page, when Prev is offered }
          C_Keys.PGUP: if hasPrev then MovePage(False);
          { Page Down = next page, when Next is offered }
          C_Keys.PGDN: if hasNext then MovePage(True);
        end else
        case ch of
          'P': MovePage(False);
          'N': MovePage(True);
          { Note: only #27 and 'E' are tested. MenuHorizontal returns Escape as #0, which falls to the else branch: sel
            is set to the highlighted entry and #0 is returned. }
          C_Keys.ESC, 'E':
            begin
              sel := nil;
              MenuVertical := C_Keys.NONE;
              Exit;
            end;
        else begin
            sel := MenuCore.FindListMember(idx, list);
            MenuVertical := ch;
            Exit;
          end;
        end;
    until False;
  end;
end;

function YesNoMenu(query: Types.TStr40; qCol, mCol, hlCol: Byte): Char;
var
  ext: Boolean;
  ch: Char;
begin
  repeat
    ch := MenuCore.MenuHorizontal(query, 'Yes No', qCol, mCol, hlCol, False, False, ext);
  until ch in ['Y', 'N'];
  YesNoMenu := ch;
end;

{ Members are allocated with only the TItemRec prefix (name, inUse, next); the fields past next do not exist. }
procedure AllocStringList(n: Integer; var list: Types.PItemRec);
var
  p: Types.PItemRec;
  i: Integer;
begin
  GetMem(list, SizeOf(Types.TMenuNode));
  list^.next := nil;
  list^.inUse := 0;
  list^.name := '';
  p := list;
  for i := 2 to n do begin
    GetMem(p^.next, SizeOf(Types.TMenuNode));
    p := p^.next;
    p^.next := nil;
    p^.inUse := 0;
    p^.name := '';
  end;
end;

procedure FreeStringList(var list: Types.PItemRec);
var
  p: Types.PItemRec;
  q: Types.PItemRec;
begin
  p := list;
  while p <> nil do begin
    q := p;
    p := p^.next;
    FreeMem(q, SizeOf(Types.TMenuNode));
  end;
end;

begin
end.

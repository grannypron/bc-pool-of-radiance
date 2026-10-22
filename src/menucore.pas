{ Menu input, animated menu pictures and linked lists of display strings. }
{$O+,F+}
{$I COMPILER.INC}
unit MenuCore;

interface

uses Types;

var
  { Set just before a MenuVertical call that only shows its list: when the list fits on one page it is drawn and #0
    returned without waiting for a key; a longer list runs the menu as usual so it can be paged. Every return clears
    it. }
  listOnly: Boolean;
  { Set just before a MenuHorizontal call whose caller reads the Left and Right arrows itself (turning, moving, aiming,
    adjusting a value); every return clears it. }
  arrowsToCaller: Boolean;
  { Set just before a MenuHorizontal call whose caller takes Enter itself (to change the highlighted line of a list):
    Enter then returns C_Keys.ENTER in place of the current option's hotkey. Every return clears it. }
  enterToCaller: Boolean;
  { Set just before a MenuHorizontal call whose caller takes keys the menu line does not show (a letter drawn on the
    screen above it, say): a letter or digit in it ends the menu and is returned upper-cased, as a hotkey is, without
    changing the current option. Every return clears it. }
  extraKeys: string[16];
  { Set just before a MenuHorizontal call whose menu shows an option without a hotkey: its capital letter in here is
    drawn in the menu colour and does not choose the option, which is reached with the arrows (Enter on it returns the
    letter, or C_Keys.ENTER under enterToCaller). The key goes to the caller only when extraKeys holds it. Every return
    clears it. }
  unmarked: string[4];
  { Set just before a MenuHorizontal call whose caller takes F5 and F8 (quick save and load) itself, as the map menu
    does; every return clears it. Without it those keys end no menu: outside combat they say quick save and load are
    unavailable here, and in combat they are ignored. }
  quickKeysToCaller: Boolean;
  { Set just before a MenuVertical call whose caller shows something for the highlighted entry: a key that moves the
    highlight then returns that key at once, with sel set to the entry now highlighted, so the caller can redraw and
    call again. The call clears it. }
  movesToCaller: Boolean;
  { Called on every pass of MenuHorizontal's key wait while set; combat sets it to animate the spell-aim preview. }
  idleHook: Types.TIdleProc;

{ Return member n (0-based) of list, or nil when the list is shorter. }
function FindListMember(n: Integer; list: Types.PItemRec): Types.PItemRec;

{ Bottom-line menu: query in qCol, then menu with its digits and capital letters (the hotkeys) in hlCol, the current
  option (GDVars.horizChoice, reset to 1 when out of range) wholly in hlCol and the rest in mCol. ',' and '.' move the
  current option, and so do the Left and Right arrows unless arrowsToCaller is set. A hotkey (returned upper-cased, and
  made the current option), a key in extraKeys (returned upper-cased) or space ends the menu; Enter, when mCol or hlCol
  is nonzero, returns the current option's hotkey (#13 for a menu without options, or while enterToCaller is set);
  Escape returns #0. With reinterpret, any other extended key returns its scan code and digits 1-9 and backslash map to
  keypad scan codes, all with ext set. The picture animates when animate is set or the GBVM menuAnimation
  flag is nonzero (that flag also advances a frame every pass and is cleared on exit). }
function MenuHorizontal(query, menu: Types.TStr40; qCol, mCol, hlCol: Byte; reinterpret, animate: Boolean;
                        var ext: Boolean): Char;

{ Vertical list menu in the box ulCol,ulRow..lrCol,lrRow with menu (plus Next/Prev/Exit as they apply) on the bottom
  line. The Up arrow or Home moves the highlight up a line and the Down arrow or End moves it down, wrapping within the
  page; Page Up and Page Down turn the page. idx is zero-based; redraw requests repainting. Label rows have inUse set;
  they are drawn in qCol and skipped by the cursor. An empty list, Exit or Escape returns #0 with sel=nil (an empty list
  also sets idx=0). Any other menu key returns that key with sel set to the highlighted entry. With listOnly set, a list
  that fits on one page is drawn and #0 returned with sel=nil at once. With movesToCaller set, a key that moves the
  highlight returns too. A key in extraKeys returns as any other menu key does, on every key the list waits for. }
function MenuVertical(query, menu: Types.TStr40; qCol, mCol, hlCol: Byte; ulCol, ulRow, lrCol, lrRow: ShortInt;
                      list: Types.PItemRec; addExit: Boolean; var redraw: Boolean; var idx: Integer;
                      var sel: Types.PItemRec): Char;

{ Ask a Yes/No question on the bottom line until Y or N is chosen; returns 'Y' or 'N'. }
function YesNoMenu(query: Types.TStr40; qCol, mCol, hlCol: Byte): Char;

{ Add a menu line (a TMenuNode: name, inUse = title, next) after tail, or as head when the list is empty, and make it
  the new tail. }
procedure AppendMenuLine(var head, tail: Types.PItemRec; name: Types.TStr40; title: Boolean);

{ Build a list of n empty members; the head is allocated even when n < 1. }
procedure AllocStringList(n: Integer; var list: Types.PItemRec);

{ Free every member. The caller's list pointer is left dangling, not set to nil. }
procedure FreeStringList(var list: Types.PItemRec);

implementation

uses GDConsts, GDVars, Crt, GameIo, Blit, Border, Portrait, C_Keys, C_Ifc, TextRend;

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

{ Return the number of members in list. }
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

{ Highlight the menu's choice characters and select an item by keypress. With takeOption, Enter returns the current
  option's hotkey, as Curse does; without it, or when the menu has no options, Enter returns #13. }
function HorizontalMenu(query, menu: Types.TStr40; qCol, mCol, hlCol: Byte; reinterpret, animate, takeOption: Boolean;
                        var ext: Boolean): Char;
var
  frameTick: LongInt;
  tick30: LongInt;
  tick80: LongInt;
  ch: Char;
  j: Byte;
  i: Byte;
  done: Boolean;
  mLen: Byte;
  qLen: Byte;
  opt: array[1..20] of Types.TOptRange;
  optCnt: Byte;
  enterOk: Boolean;

  { Split the menu into options: each starts at a digit or capital letter and ends two characters before the next one,
    the last at the end of the menu. There are at most 20 options (opt's size); the 20th runs to the end of the menu. }
  procedure ParseMenu(m: Types.TStr40);
  var
    idx: Byte;
    i: Byte;
    len: Byte;
  begin
    FillChar(opt, SizeOf(opt), 0);
    idx := 1;
    len := Length(m);
    for i := 1 to len do
      if m[i] in ['0'..'9', 'A'..'Z'] then
        if opt[idx].first = 0 then
          opt[idx].first := i
        else if idx < 20 then begin
          opt[idx].last := i - 2;
          Inc(idx);
          opt[idx].first := i;
        end;
    opt[idx].last := len;
    optCnt := idx;
  end;

  { Draw the menu after the query with option cur wholly in hlCol, the other hotkeys in hlCol and the rest in mCol, then
    blank the rest of the line. }
  procedure DisplayOption(cur: Byte);
  var
    i: Byte;
  begin
    if mLen > 0 then begin
      for i := 1 to mLen do
        if (opt[cur].first <= i) and (opt[cur].last >= i)
           and (hlCol <> 0) then
          TextRend.RenderChar(qLen + i - 1, 24, hlCol, 1, Ord(menu[i]), 1)
        else if (menu[i] in ['0'..'9', 'A'..'Z']) and (Pos(menu[i], unmarked) = 0) then
          TextRend.RenderChar(qLen + i - 1, 24, hlCol, 1, Ord(menu[i]), 1)
        else
          TextRend.RenderChar(qLen + i - 1, 24, mCol, 1, Ord(menu[i]), 1);
      { columns qLen + mLen..39 are blanked, so a 39-column line still clears column 39 }
      if qLen + mLen <= 39 then
        TextRend.RenderChar(qLen + mLen, 24, Black, 39 - mLen - qLen + 1, 32, 1);
    end;
  end;

  { Make the next option current, or the previous one when toNext is clear, wrapping at the ends, and redraw. }
  procedure StepOption(toNext: Boolean);
  begin
    if toNext then begin
      if GDVars.horizChoice = optCnt then
        GDVars.horizChoice := 1
      else
        Inc(GDVars.horizChoice);
    end else if GDVars.horizChoice = 1 then
      GDVars.horizChoice := optCnt
    else
      Dec(GDVars.horizChoice);
    DisplayOption(GDVars.horizChoice);
  end;

begin
  enterOk := (mCol <> 0) or (hlCol <> 0);
  ParseMenu(menu);
  if (GDVars.horizChoice < 1) or (GDVars.horizChoice > optCnt) then
    GDVars.horizChoice := 1;
  mLen := Length(menu);
  ch := #0;
  ext := False;
  done := False;
  frameTick := TextRend.GetTicks;
  tick30 := TextRend.GetTicks + 30;
  tick80 := tick30 + 50;
  if Length(query) <> 0 then
    TextRend.DisplayString(0, 24, qCol, query);
  qLen := Length(query);
  DisplayOption(GDVars.horizChoice);
  repeat
    if @idleHook <> nil then
      idleHook;
    { the tick count restarts at midnight: restart the frame timer with it }
    if TextRend.GetTicks < frameTick then
      frameTick := TextRend.GetTicks;
    if ((GDVars.zone0^.savedWalls.menuAnimation <> 0) or animate) and (GDVars.animData.current > 0) then begin
      Portrait.DisplayImageBuf(3, 3, animate, GDVars.animData.frames[GDVars.animData.current].pic);
      if (TextRend.GetTicks - frameTick >= GDVars.animData.frames[GDVars.animData.current].time * 10)
         or (GDVars.zone0^.savedWalls.menuAnimation <> 0) then begin
        Inc(GDVars.animData.current);
        if GDVars.animData.current > GDVars.animData.count then
          GDVars.animData.current := 1;
        frameTick := TextRend.GetTicks;
      end;
    end;
    if KeyPressed then begin
      ch := GameIo.ReadGameKey;
      { a STING pop-up (Ctrl-Y) wrote over the menu line }
      if GDVars.bottomLineTaken then begin
        GDVars.bottomLineTaken := False;
        if Length(query) <> 0 then
          TextRend.DisplayString(0, 24, qCol, query);
        DisplayOption(GDVars.horizChoice);
      end;
      if ch = #0 then
      { #0 prefixes an extended key: the second ReadGameKey reads its scan code. Left and Right move the current option
        unless the caller takes them; any other extended key ends the menu (with ext set) only with reinterpret, and is
        otherwise ignored. }
      begin
        ch := GameIo.ReadGameKey;
        if ((ch = C_Keys.LEFT) or (ch = C_Keys.RIGHT)) and not arrowsToCaller then
          StepOption(ch = C_Keys.RIGHT)
        else if ((ch = C_Keys.F5) or (ch = C_Keys.F8)) and not quickKeysToCaller then begin
          if GDVars.ifcState <> C_Ifc.COMBAT then begin
            TextRend.DisplayAndPause(Yellow, 'Quick save and load unavailable.');
            TextRend.ClearBottomLine;
            if Length(query) <> 0 then
              TextRend.DisplayString(0, 24, qCol, query);
            DisplayOption(GDVars.horizChoice);
          end;
        end else if reinterpret then begin
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
          C_Keys.ENTER: if enterOk then begin
                 if takeOption and not enterToCaller and (opt[GDVars.horizChoice].first <> 0) then
                   ch := menu[opt[GDVars.horizChoice].first]
                 else
                   ch := C_Keys.ENTER;
                 done := True;
               end;
          ',': StepOption(False);
          '.': StepOption(True);
        else begin
            ch := UpCase(ch);
            if ch in [' ', '0'..'9', 'A'..'Z'] then
              if ch = ' ' then
                done := True
              else
                for i := 1 to mLen do
                  if (menu[i] = ch) and (Pos(ch, unmarked) = 0) then begin
                    done := True;
                    { a hotkey past the 20th belongs to the 20th option }
                    j := 1;
                    while (j < optCnt) and (opt[j].first <> i) do
                      Inc(j);
                    GDVars.horizChoice := j;
                    DisplayOption(GDVars.horizChoice);
                  end;
            if (ch <> ' ') and (Pos(ch, extraKeys) > 0) then
              done := True;
            if reinterpret then
              if ch in ['1'..'9', '\'] then
              begin
                if ch = '\' then
                  { keypad-'*' scan code, not ASCII '7' }
                  ch := #55
                else
                  ch := Char(GDConsts.keypadScan[Ord(ch) - Ord('1')]);
                ext := True;
                done := True;
              end;
          end;
        end;
    end;
  until done;
  arrowsToCaller := False;
  enterToCaller := False;
  extraKeys := '';
  unmarked := '';
  quickKeysToCaller := False;
  GDVars.zone0^.savedWalls.menuAnimation := 0;
  HorizontalMenu := ch;
end;

function MenuHorizontal(query, menu: Types.TStr40; qCol, mCol, hlCol: Byte; reinterpret, animate: Boolean;
                        var ext: Boolean): Char;
begin
  MenuHorizontal := MenuCore.HorizontalMenu(query, menu, qCol, mCol, hlCol, reinterpret, animate, True, ext);
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
  toCaller: Boolean;
  oldIdx: Integer;
  oldTop: Integer;
  { the caller's extraKeys, given to every HorizontalMenu call }
  keep: string[16];

  { Clear the box and draw the list from member top, labels in qCol and entries in mCol, each padded to the box width. }
  procedure DrawPage(top: Integer);
  var
    pp: Types.PItemRec;
    row: ShortInt;
  begin
    Border.ClearBox(ulCol, ulRow, lrCol, lrRow);
    pp := MenuCore.FindListMember(top, list);
    row := ulRow;
    while (pp <> nil) and (row <= lrRow) do begin
      if pp^.inUse <> 0 then
        TextRend.DisplayString(ulCol, row, qCol, pp^.name)
      else
        TextRend.DisplayString(ulCol, row, mCol, pp^.name);
      if Length(pp^.name) < width then
        TextRend.RenderChar(ulCol + Length(pp^.name), row, Black, width - Length(pp^.name), 32, 1);
      pp := pp^.next;
      Inc(row);
    end;
  end;

  { Position of the first non-blank character of s (the last position when s is all blanks). }
  function FirstNonBlank(s: Types.TStr40): Byte;
  var
    i: Byte;
    len: Byte;
  begin
    i := 1;
    len := Length(s);
    while (i < len) and (s[i] = ' ') do
      Inc(i);
    FirstNonBlank := i;
  end;

  { Position of the last non-blank character of s (1 when s is all blanks). }
  function LastNonBlank(s: Types.TStr40): Byte;
  var
    n: Byte;
  begin
    n := Length(s);
    while (n > 1) and (s[n] = ' ') do
      Dec(n);
    LastNonBlank := n;
  end;

  { Redraw the text of member n, without its surrounding blanks, in hlCol. }
  procedure HighlightLine(n: Integer);
  var
    pp: Types.PItemRec;
    a: Byte;
    b: Byte;
  begin
    pp := MenuCore.FindListMember(n, list);
    a := FirstNonBlank(pp^.name);
    b := LastNonBlank(pp^.name) - a + 1;
    TextRend.DisplayString(ulCol + a - 1, ulRow + (n - GDVars.vertTop), hlCol, Copy(pp^.name, a, b));
  end;

  { Redraw the text of member n, without its surrounding blanks, in its normal color. }
  procedure UnhighlightLine(n: Integer);
  var
    pp: Types.PItemRec;
    a: Byte;
    b: Byte;
  begin
    pp := MenuCore.FindListMember(n, list);
    a := FirstNonBlank(pp^.name);
    b := LastNonBlank(pp^.name) - a + 1;
    if pp^.inUse <> 0 then
      TextRend.DisplayString(ulCol + a - 1, ulRow + (n - GDVars.vertTop), qCol, Copy(pp^.name, a, b))
    else
      TextRend.DisplayString(ulCol + a - 1, ulRow + (n - GDVars.vertTop), mCol, Copy(pp^.name, a, b));
  end;

  { Move idx off label rows in the given direction, wrapping within the visible page; gives up after a page of rows. }
  procedure SkipLabels(down: Boolean);
  var
    k: Integer;
  begin
    k := 0;
    if down then begin
      while (k < rows)
            and (MenuCore.FindListMember(idx, list)^.inUse <> 0) do begin
        Inc(k);
        Inc(idx);
        if GDVars.vertTop + rows - 1 < idx then
          idx := GDVars.vertTop;
        if count - 1 < idx then
          idx := GDVars.vertTop;
      end;
    end else
      while (k < rows)
            and (MenuCore.FindListMember(idx, list)^.inUse <> 0) do begin
        Inc(k);
        Dec(idx);
        if idx < GDVars.vertTop then
          idx := GDVars.vertTop + rows - 1;
        if count - 1 < idx then
          idx := count - 1;
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

  { Move the cursor one line, wrapping within the visible page and clamped to the list, then skip label rows. }
  procedure MoveLine(down: Boolean);
  begin
    if down then begin
      Inc(idx);
      if GDVars.vertTop + rows - 1 < idx then
        idx := GDVars.vertTop;
      if count - 1 < idx then
        idx := GDVars.vertTop;
    end else begin
      Dec(idx);
      if idx < GDVars.vertTop then
        idx := GDVars.vertTop + rows - 1;
      if count - 1 < idx then
        idx := count - 1;
    end;
    SkipLabels(down);
  end;

begin
  keep := extraKeys;
  extraKeys := '';
  toCaller := movesToCaller;
  movesToCaller := False;
  if list = nil then begin
    listOnly := False;
    idx := 0;
    sel := nil;
    MenuVertical := C_Keys.NONE;
  end else begin
    GDVars.horizChoice := 1;
    width := lrCol - ulCol + 1;
    count := MenuCore.ListCount(list);
    rows := lrRow - ulRow + 1;
    p := list;
    headerCnt := 0;
    while (p <> nil) and (p^.inUse <> 0) do begin
      p := p^.next;
      Inc(headerCnt);
    end;
    if GDVars.vertTop > idx then begin
      GDVars.vertTop := idx;
      redraw := True;
    end;
    if GDVars.vertTop > count then begin
      GDVars.vertTop := 0;
      redraw := True;
    end;
    Inc(idx);
    MoveLine(False);
    if redraw then
      DrawPage(GDVars.vertTop);
    redraw := False;
    if listOnly then begin
      listOnly := False;
      if count <= rows then begin
        sel := nil;
        MenuVertical := C_Keys.NONE;
        Exit;
      end;
    end;
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
      { Enter stays #13 here: it takes the highlighted list entry, not a bottom-line option. }
      extraKeys := keep;
      ch := MenuCore.HorizontalMenu(query, hMenu, qCol, mCol, hlCol, True, False, False, ext);
      UnhighlightLine(idx);
      oldIdx := idx;
      oldTop := GDVars.vertTop;
      if ext then
        case ch of
          { line up }
          C_Keys.HOME, C_Keys.UP: MoveLine(False);
          { line down }
          C_Keys.END_KEY, C_Keys.DOWN: MoveLine(True);
          { Page Up = previous page, when Prev is offered }
          C_Keys.PGUP: if hasPrev then MovePage(False);
          { Page Down = next page, when Next is offered }
          C_Keys.PGDN: if hasNext then MovePage(True);
        end else
        case ch of
          { as for Page Up and Page Down, only when the bottom line offers Prev or Next }
          'P': if hasPrev then MovePage(False);
          'N': if hasNext then MovePage(True);
          C_Keys.ESC, 'E', C_Keys.NONE:
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
      if toCaller and ((idx <> oldIdx) or (GDVars.vertTop <> oldTop)) then begin
        sel := MenuCore.FindListMember(idx, list);
        MenuVertical := ch;
        Exit;
      end;
    until False;
  end;
end;

function YesNoMenu(query: Types.TStr40; qCol, mCol, hlCol: Byte): Char;
var
  ext: Boolean;
  ch: Char;
begin
  { default the highlight to "No" }
  GDVars.horizChoice := 2;
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

procedure AppendMenuLine(var head, tail: Types.PItemRec; name: Types.TStr40; title: Boolean);
var
  n: Types.PItemRec;
begin
  GetMem(n, SizeOf(Types.TMenuNode));
  n^.next := nil;
  n^.name := name;
  n^.inUse := Ord(title);
  if head = nil then
    head := n
  else
    tail^.next := n;
  tail := n;
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
  listOnly := False;
  arrowsToCaller := False;
  enterToCaller := False;
  movesToCaller := False;
  extraKeys := '';
  unmarked := '';
  quickKeysToCaller := False;
  @idleHook := nil;
end.

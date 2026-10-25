{ An 80x25 colour text screen for the set-up program POOLCFG (#876), in the classic DOS set-up style: text written
  straight into the text screen's memory (so the bottom right cell can be written without the screen scrolling), double
  framed boxes, the title bar and key line, a line editor, and the pop-ups: a message, a Yes/No/Cancel question and a
  pick list. The game's own screen units (TextRend, Border, MenuCore) draw in graphics modes, so none of them fit; this
  is the program's only screen unit. Columns and rows count from 1, as Crt's do. DOS only: the native tool is #894. }
{$F+,I-}
{$I COMPILER.INC}
unit TuiKit;

interface

const
  COLS = 80;
  ROWS = 25;
  { the colours, as text attributes (background * 16 + foreground): the blue page and its text }
  A_TEXT = $17;
  A_FRAME = $1F;
  A_VALUE = $1E;
  A_HELP = $1B;
  A_GOOD = $1A;
  A_WARN = $1E;
  A_BAD = $1C;
  A_CHANGED = $1F;
  A_HOT = $1E;
  { the highlight, a stepping line's choice not picked, the title bar }
  A_HIGHLIGHT = $30;
  A_HIGHLIGHT_OTHER = $31;
  A_TITLE = $30;
  { the key line and its keys' names }
  A_KEYS = $70;
  A_KEY_NAME = $74;
  { the light grey pop-ups (a notice, a question, a pick list): text, frame, values, hot letters and the highlight }
  A_POP = $70;
  A_POP_FRAME = $7F;
  A_POP_VALUE = $71;
  A_POP_HOT = $74;
  A_POP_HIGHLIGHT = $0F;
  { the error box: text, frame and the value it names }
  A_ERROR = $4F;
  A_ERROR_FRAME = $4E;
  A_ERROR_VALUE = $47;
  { the line editor's field }
  A_FIELD = $0F;
  { Message's styles: a notice (light grey) or an error (red) }
  STYLE_NOTICE = 0;
  STYLE_ERROR = 1;
  { the most lines a message or pick list holds }
  MAX_LINES = 14;

type
  TLine = string[76];
  { a message's or pick list's lines, each with its colour (0: the box's own) }
  TLines = record
    count: Byte;
    text: array[1..MAX_LINES] of TLine;
    color: array[1..MAX_LINES] of Byte;
  end;
  { the whole screen's characters and colours, to put back after a pop-up }
  TScreen = array[1..ROWS * COLS] of Word;

{ Take the screen: 80x25 colour text (switched to when the screen is in another mode), the cursor hidden, Ctrl-Break
  off. The screen as it was is kept for Done. }
procedure Init;

{ Give the screen back as Init found it: its mode, characters, cursor and cursor shape. }
procedure Done;

{ Write s at column x of row y in colour attr, cut at the screen's right edge. }
procedure PutText(x, y, attr: Byte; s: string);

{ Write count of character ch from column x of row y in colour attr. }
procedure PutRun(x, y, attr: Byte; ch: Char; count: Byte);

{ Fill the rectangle from (x1, y1) to (x2, y2) with spaces in colour attr. }
procedure Fill(x1, y1, x2, y2, attr: Byte);

{ Recolour count cells from column x of row y to attr, their characters kept: a highlight bar. }
procedure Recolor(x, y, count, attr: Byte);

{ A double-line frame from (x1, y1) to (x2, y2) in colour attr, its inside cleared, and title (when not empty) in the
  middle of its top line with a space either side. }
procedure Box(x1, y1, x2, y2, attr: Byte; title: string);

{ A single-line divider across the box whose sides are columns x1 and x2, on row y: the sides joined to it. }
procedure Divider(x1, x2, y, attr: Byte);

{ The title bar, row 1: left at its left, right at its right. }
procedure TitleBar(left, right: string);

{ The key line, row 25: s, each key's name between a pair of '~' in red. }
procedure KeyLine(s: string);

procedure SaveScreen(var s: TScreen);
procedure RestoreScreen(var s: TScreen);

procedure HideCursor;

{ Show the cursor at column x of row y: a block, or an underline when block is clear. }
procedure ShowCursor(x, y: Byte; block: Boolean);

{ Wait for a key: ch its character, or for a key with none (an arrow, a function key) ext set and ch its scan code. }
procedure GetKey(var ch: Char; var ext: Boolean);

{ Empty lines, then add s to them in colour color (0 for the box's own). }
procedure ClearLines(var lines: TLines);
procedure AddLine(var lines: TLines; s: string; color: Byte);

{ Show lines in a box at least width wide in the middle of the screen, titled title, in style (STYLE_NOTICE or
  STYLE_ERROR), with "Press any key" under them, until a key; then the screen as it was. }
procedure Message(title: string; var lines: TLines; style, width: Byte);

{ Ask question in a box titled title, with the choices Yes, No and Cancel: Left, Right and Tab move between them and
  Enter takes one; Y, N and C take theirs, and Escape is Cancel. Returns 'Y', 'N' or 'C'; the screen is as it was. }
function Ask(title, question: string): Char;

{ A pick list of items with its top left corner at (x, y), titled title, the item index highlighted and marked as the
  current one: Up and Down (wrapping), Home and End move, Enter takes the highlighted item into index (True), Escape
  leaves index as it was (False). The screen is as it was afterwards. }
function PickList(x, y: Byte; title: string; var items: TLines; var index: Byte): Boolean;

{ Edit text in a field width wide from column x of row y, between brackets, at most maxLen characters, the cursor at
  its end (LineEdit.EditKey's keys; text longer than the field scrolls). first, when not #0, starts the edit with that
  character in place of the text. Returns the key that ended it: Enter (text edited) or Escape (text as it was). }
function EditLine(x, y, width: Byte; var text: string; maxLen: Byte; first: Char): Char;

implementation

uses Crt, Dos, C_KEYS, LineEdit;

var
  { the text screen's segment }
  videoSeg: Word;
  { the screen Init found: its mode, characters, cursor and cursor shape }
  oldMode: Word;
  oldScreen: TScreen;
  oldX: Byte;
  oldY: Byte;
  oldShape: Word;
  { Init switched the mode }
  switched: Boolean;

{ The offset in the text screen of column x, row y. }
function CellOfs(x, y: Byte): Word;
begin
  CellOfs := ((y - 1) * COLS + (x - 1)) * 2;
end;

{ Set the cursor's shape: its first and last scan lines, through the BIOS (INT 10h, AH=1). }
procedure SetShape(shape: Word);
var
  regs: Registers;
begin
  regs.ah := 1;
  regs.cx := shape;
  Intr($10, regs);
end;

procedure Init;
var
  regs: Registers;
begin
  oldMode := LastMode;
  switched := (LastMode <> CO80) and (LastMode <> Mono);
  if switched then
    TextMode(CO80);
  if LastMode = Mono then
    videoSeg := $B000
  else
    videoSeg := $B800;
  TuiKit.SaveScreen(oldScreen);
  oldX := WhereX;
  oldY := WhereY;
  { INT 10h AH=3: the cursor's shape in CX }
  regs.ah := 3;
  regs.bh := 0;
  Intr($10, regs);
  oldShape := regs.cx;
  CheckBreak := False;
  TuiKit.HideCursor;
end;

procedure Done;
begin
  if switched then
    TextMode(oldMode)
  else
    TuiKit.RestoreScreen(oldScreen);
  TuiKit.SetShape(oldShape);
  GotoXY(oldX, oldY);
end;

procedure PutText(x, y, attr: Byte; s: string);
var
  i: Byte;
  ofs: Word;
begin
  if (y < 1) or (y > ROWS) or (x < 1) then Exit;
  ofs := TuiKit.CellOfs(x, y);
  i := 0;
  while (i < Length(s)) and (x + i <= COLS) do begin
    Inc(i);
    MemW[videoSeg:ofs] := attr shl 8 + Ord(s[i]);
    Inc(ofs, 2);
  end;
end;

procedure PutRun(x, y, attr: Byte; ch: Char; count: Byte);
var
  i: Byte;
  ofs: Word;
begin
  if (y < 1) or (y > ROWS) or (x < 1) then Exit;
  ofs := TuiKit.CellOfs(x, y);
  i := 0;
  while (i < count) and (x + i <= COLS) do begin
    Inc(i);
    MemW[videoSeg:ofs] := attr shl 8 + Ord(ch);
    Inc(ofs, 2);
  end;
end;

procedure Fill(x1, y1, x2, y2, attr: Byte);
var
  y: Byte;
begin
  for y := y1 to y2 do
    TuiKit.PutRun(x1, y, attr, ' ', x2 - x1 + 1);
end;

procedure Recolor(x, y, count, attr: Byte);
var
  i: Byte;
  ofs: Word;
begin
  if (y < 1) or (y > ROWS) or (x < 1) then Exit;
  ofs := TuiKit.CellOfs(x, y) + 1;
  i := 0;
  while (i < count) and (x + i <= COLS) do begin
    Inc(i);
    Mem[videoSeg:ofs] := attr;
    Inc(ofs, 2);
  end;
end;

procedure Box(x1, y1, x2, y2, attr: Byte; title: string);
var
  y: Byte;
begin
  TuiKit.Fill(x1 + 1, y1 + 1, x2 - 1, y2 - 1, attr);
  TuiKit.PutRun(x1, y1, attr, #201, 1);
  TuiKit.PutRun(x1 + 1, y1, attr, #205, x2 - x1 - 1);
  TuiKit.PutRun(x2, y1, attr, #187, 1);
  for y := y1 + 1 to y2 - 1 do begin
    TuiKit.PutRun(x1, y, attr, #186, 1);
    TuiKit.PutRun(x2, y, attr, #186, 1);
  end;
  TuiKit.PutRun(x1, y2, attr, #200, 1);
  TuiKit.PutRun(x1 + 1, y2, attr, #205, x2 - x1 - 1);
  TuiKit.PutRun(x2, y2, attr, #188, 1);
  if title <> '' then begin
    title := ' ' + title + ' ';
    TuiKit.PutText(x1 + 1 + (x2 - x1 - 1 - Length(title)) div 2, y1, attr, title);
  end;
end;

procedure Divider(x1, x2, y, attr: Byte);
begin
  TuiKit.PutRun(x1, y, attr, #199, 1);
  TuiKit.PutRun(x1 + 1, y, attr, #196, x2 - x1 - 1);
  TuiKit.PutRun(x2, y, attr, #182, 1);
end;

procedure TitleBar(left, right: string);
begin
  TuiKit.PutRun(1, 1, A_TITLE, ' ', COLS);
  TuiKit.PutText(2, 1, A_TITLE, left);
  TuiKit.PutText(COLS - Length(right), 1, A_TITLE, right);
end;

procedure KeyLine(s: string);
var
  i: Byte;
  x: Byte;
  attr: Byte;
begin
  TuiKit.PutRun(1, ROWS, A_KEYS, ' ', COLS);
  x := 2;
  attr := A_KEYS;
  for i := 1 to Length(s) do
    if s[i] = '~' then begin
      if attr = A_KEYS then
        attr := A_KEY_NAME
      else
        attr := A_KEYS;
    end else begin
      TuiKit.PutRun(x, ROWS, attr, s[i], 1);
      Inc(x);
    end;
end;

procedure SaveScreen(var s: TScreen);
begin
  Move(Mem[videoSeg:0], s, SizeOf(s));
end;

procedure RestoreScreen(var s: TScreen);
begin
  Move(s, Mem[videoSeg:0], SizeOf(s));
end;

procedure HideCursor;
begin
  TuiKit.SetShape($2000);
end;

procedure ShowCursor(x, y: Byte; block: Boolean);
begin
  GotoXY(x, y);
  if LastMode = Mono then begin
    if block then
      TuiKit.SetShape($000D)
    else
      TuiKit.SetShape($0C0D);
  end else if block then
    TuiKit.SetShape($0007)
  else
    TuiKit.SetShape($0607);
end;

procedure GetKey(var ch: Char; var ext: Boolean);
begin
  ch := ReadKey;
  ext := ch = #0;
  if ext then
    ch := ReadKey;
end;

procedure ClearLines(var lines: TLines);
begin
  lines.count := 0;
end;

procedure AddLine(var lines: TLines; s: string; color: Byte);
begin
  if lines.count >= MAX_LINES then Exit;
  Inc(lines.count);
  lines.text[lines.count] := s;
  lines.color[lines.count] := color;
end;

procedure Message(title: string; var lines: TLines; style, width: Byte);
var
  under: TScreen;
  i: Byte;
  w: Byte;
  h: Byte;
  x1: Byte;
  y1: Byte;
  attr: Byte;
  frame: Byte;
  ch: Char;
  ext: Boolean;
begin
  if style = STYLE_ERROR then begin
    attr := A_ERROR;
    frame := A_ERROR_FRAME;
  end else begin
    attr := A_POP;
    frame := A_POP_FRAME;
  end;
  w := width;
  for i := 1 to lines.count do
    if Length(lines.text[i]) + 6 > w then
      w := Length(lines.text[i]) + 6;
  if w > COLS then
    w := COLS;
  h := lines.count + 5;
  x1 := (COLS - w) div 2 + 1;
  y1 := (ROWS - h) div 2 + 1;
  TuiKit.SaveScreen(under);
  TuiKit.Box(x1, y1, x1 + w - 1, y1 + h - 1, frame, title);
  TuiKit.Fill(x1 + 1, y1 + 1, x1 + w - 2, y1 + h - 2, attr);
  for i := 1 to lines.count do
    if lines.color[i] <> 0 then
      TuiKit.PutText(x1 + 3, y1 + 1 + i, lines.color[i], lines.text[i])
    else
      TuiKit.PutText(x1 + 3, y1 + 1 + i, attr, lines.text[i]);
  TuiKit.PutText(x1 + (w - 13) div 2, y1 + h - 2, attr, 'Press any key');
  TuiKit.GetKey(ch, ext);
  TuiKit.RestoreScreen(under);
end;

function Ask(title, question: string): Char;
const
  NAMES: array[0..2] of string[6] = ('Yes', 'No', 'Cancel');
  KEYS: array[0..2] of Char = ('Y', 'N', 'C');
  { each choice's column from the box's left }
  AT: array[0..2] of Byte = (7, 18, 28);
  WIDTH = 44;
  HEIGHT = 7;
var
  under: TScreen;
  x1: Byte;
  y1: Byte;
  sel: Byte;
  i: Byte;
  ch: Char;
  ext: Boolean;
  answer: Char;
begin
  x1 := (COLS - WIDTH) div 2 + 1;
  y1 := (ROWS - HEIGHT) div 2 + 1;
  TuiKit.SaveScreen(under);
  TuiKit.Box(x1, y1, x1 + WIDTH - 1, y1 + HEIGHT - 1, A_POP_FRAME, title);
  TuiKit.Fill(x1 + 1, y1 + 1, x1 + WIDTH - 2, y1 + HEIGHT - 2, A_POP);
  TuiKit.PutText(x1 + 3, y1 + 2, A_POP, question);
  sel := 0;
  answer := #0;
  repeat
    TuiKit.PutRun(x1 + 1, y1 + 4, A_POP, ' ', WIDTH - 2);
    for i := 0 to 2 do begin
      TuiKit.PutText(x1 + AT[i], y1 + 4, A_POP, NAMES[i]);
      TuiKit.PutRun(x1 + AT[i], y1 + 4, A_POP_HOT, NAMES[i][1], 1);
    end;
    TuiKit.Recolor(x1 + AT[sel] - 1, y1 + 4, Length(NAMES[sel]) + 2, A_POP_HIGHLIGHT);
    TuiKit.GetKey(ch, ext);
    if ext then
      case ch of
        C_KEYS.LEFT: sel := (sel + 2) mod 3;
        C_KEYS.RIGHT: sel := (sel + 1) mod 3;
      end
    else
      case UpCase(ch) of
        #9: sel := (sel + 1) mod 3;
        C_KEYS.ENTER: answer := KEYS[sel];
        C_KEYS.ESC: answer := 'C';
        'Y', 'N', 'C': answer := UpCase(ch);
      end;
  until answer <> #0;
  TuiKit.RestoreScreen(under);
  Ask := answer;
end;

function PickList(x, y: Byte; title: string; var items: TLines; var index: Byte): Boolean;
var
  under: TScreen;
  w: Byte;
  i: Byte;
  sel: Byte;
  ch: Char;
  ext: Boolean;
  done: Boolean;
begin
  PickList := False;
  if items.count = 0 then Exit;
  w := Length(title) + 8;
  for i := 1 to items.count do
    if Length(items.text[i]) + 8 > w then
      w := Length(items.text[i]) + 8;
  TuiKit.SaveScreen(under);
  TuiKit.Box(x, y, x + w - 1, y + items.count + 1, A_POP_FRAME, title);
  sel := index;
  if (sel < 1) or (sel > items.count) then
    sel := 1;
  done := False;
  repeat
    for i := 1 to items.count do begin
      TuiKit.PutRun(x + 1, y + i, A_POP, ' ', w - 2);
      if i = index then
        TuiKit.PutRun(x + 1, y + i, A_POP, #16, 1);
      TuiKit.PutText(x + 3, y + i, A_POP, items.text[i]);
    end;
    TuiKit.Recolor(x + 1, y + sel, w - 2, A_POP_HIGHLIGHT);
    TuiKit.GetKey(ch, ext);
    if ext then
      case ch of
        C_KEYS.UP: if sel > 1 then Dec(sel) else sel := items.count;
        C_KEYS.DOWN: if sel < items.count then Inc(sel) else sel := 1;
        C_KEYS.HOME: sel := 1;
        C_KEYS.END_KEY: sel := items.count;
      end
    else
      case ch of
        C_KEYS.ENTER: begin
                        index := sel;
                        PickList := True;
                        done := True;
                      end;
        C_KEYS.ESC: done := True;
      end;
  until done;
  TuiKit.RestoreScreen(under);
end;

function EditLine(x, y, width: Byte; var text: string; maxLen: Byte; first: Char): Char;
var
  work: string;
  pos: Byte;
  insertMode: Boolean;
  start: Byte;
  ch: Char;
  ext: Boolean;
  key: Char;
begin
  work := text;
  if first <> #0 then
    work := first;
  pos := Length(work);
  insertMode := True;
  start := 0;
  key := #0;
  TuiKit.PutRun(x - 1, y, A_TEXT, '[', 1);
  TuiKit.PutRun(x + width, y, A_TEXT, ']', 1);
  repeat
    { the field shows work from character start + 1, the cursor always in it }
    if pos < start then
      start := pos;
    if pos >= start + width then
      start := pos - width + 1;
    TuiKit.PutRun(x, y, A_FIELD, ' ', width);
    TuiKit.PutText(x, y, A_FIELD, Copy(work, start + 1, width));
    TuiKit.ShowCursor(x + pos - start, y, not insertMode);
    TuiKit.GetKey(ch, ext);
    if not LineEdit.EditKey(work, pos, insertMode, maxLen, ch, ext) and not ext then
      if ch in [C_KEYS.ENTER, C_KEYS.ESC] then
        key := ch;
  until key <> #0;
  TuiKit.HideCursor;
  if key = C_KEYS.ENTER then
    text := work;
  EditLine := key;
end;

end.

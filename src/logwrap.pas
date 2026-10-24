{ Wrapping the combat log's entries (#841, CbtLog) again for a page wider than the combat window, keeping their colour
  changes. Overlaid, apart from CbtLog: only the log's page (LogView) wraps, so the resident unit stays small. }
{$O+,F+}
{$I COMPILER.INC}
unit LogWrap;

interface

const
  { WrapEntry's lines: at most WRAP_LINES of them, each with room for WRAP_LEN characters with their colour changes }
  WRAP_LINES = 12;
  WRAP_LEN = 80;

type
  TWrapLine = string[WRAP_LEN];
  TWrapLines = array[1..WRAP_LINES] of TWrapLine;

{ Word-wrap entry into lines of at most width characters (not counting colour changes), and return how many. Spaces
  between words are one space, and none starts a line; a word longer than width is split. Each line starts with the
  colour in effect where it begins, so it can be drawn alone. Lines past WRAP_LINES are dropped. }
function WrapEntry(entry: string; width: Byte; var lines: TWrapLines): Byte;

implementation

uses CbtLog;

const
  { CbtLog's colour change, by its short name }
  COLOR_MARK = CbtLog.COLOR_MARK;

function WrapEntry(entry: string; width: Byte; var lines: TWrapLines): Byte;
var
  n: Byte;
  { the line being built and its characters shown; the word being gathered, its characters shown, and the colour in
    effect where it starts; the colour in effect after what has been read }
  lineShown: Byte;
  word: string;
  wordShown: Byte;
  wordColor: Byte;
  color: Byte;
  i: Integer;
  ch: Char;

  { Start line n + 1 in color c (none for 0); past WRAP_LINES the lines are dropped. }
  procedure StartLine(c: Byte);
  begin
    Inc(n);
    if n <= WRAP_LINES then
      if c <> 0 then
        lines[n] := COLOR_MARK + Chr(c)
      else
        lines[n] := '';
    lineShown := 0;
  end;

  { Add s to line n, when it is kept and has room. }
  procedure Put(s: string);
  begin
    if (n >= 1) and (n <= WRAP_LINES) and (Length(lines[n]) + Length(s) <= WRAP_LEN) then
      lines[n] := lines[n] + s;
  end;

  { Put the word gathered on the line, after a space when the line has something on it, or on a new line when it does
    not fit there. A word wider than a line is split, a line's width at a time. }
  procedure EndWord;
  var
    { an Integer, so it can step past a 255-character word }
    j: Integer;
    c: Char;
    shown: Byte;
  begin
    if wordShown = 0 then Exit;
    if (lineShown > 0) and (lineShown + 1 + wordShown <= width) then begin
      Put(' ');
      Inc(lineShown);
    end else if lineShown > 0 then
      StartLine(wordColor);
    if wordShown <= width - lineShown then begin
      Put(word);
      Inc(lineShown, wordShown);
    end else begin
      j := 1;
      shown := 0;
      while j <= Length(word) do begin
        c := word[j];
        if c = COLOR_MARK then begin
          if j < Length(word) then begin
            Put(COLOR_MARK + word[j + 1]);
            wordColor := Ord(word[j + 1]);
          end;
          Inc(j, 2);
        end else begin
          if lineShown >= width then
            StartLine(wordColor);
          Put(c);
          Inc(lineShown);
          Inc(j);
        end;
      end;
    end;
    word := '';
    wordShown := 0;
  end;

begin
  n := 0;
  if width = 0 then begin
    WrapEntry := 0;
    Exit;
  end;
  color := 0;
  word := '';
  wordShown := 0;
  wordColor := 0;
  StartLine(0);
  i := 1;
  while i <= Length(entry) do begin
    ch := entry[i];
    if ch = COLOR_MARK then begin
      if i < Length(entry) then begin
        color := Ord(entry[i + 1]);
        { a colour before any of a word's characters replaces the one before it }
        if wordShown = 0 then begin
          word := COLOR_MARK + Chr(color);
          wordColor := color;
        end else
          word := word + COLOR_MARK + Chr(color);
      end;
      Inc(i, 2);
    end else begin
      if ch = ' ' then
        EndWord
      else begin
        if wordShown = 0 then
          wordColor := color;
        word := word + ch;
        Inc(wordShown);
      end;
      Inc(i);
    end;
  end;
  EndWord;
  { an empty entry, or one of nothing but spaces, still has its one, empty line }
  if n > WRAP_LINES then
    n := WRAP_LINES;
  WrapEntry := n;
end;

end.

{ Number, padding and menu-text helpers for text the game shows. Resident and depending on nothing, so any unit can use
  it, even the ones that start before the overlay manager (GameIo, TextRend). }
{$F+}
{$I COMPILER.INC}
unit StrUtil;

interface

type
  { long enough for any LongInt, sign included }
  TNumStr = string[11];
  { long enough for any LongInt with its commas }
  TGroupedStr = string[15];
  { a noun for Pluralize and Count }
  TNounStr = string[20];
  { a count and its noun: any LongInt, a blank and a TNounStr }
  TCountStr = string[32];

{ n in decimal. }
function NumStr(n: LongInt): TNumStr;

{ n in two digits, a 0 in front of one below 10 (only the last two digits of a larger one). }
function ZeroPad2(n: Word): TNumStr;

{ halves, a count of half attacks (TCharRecord.attacks), as attacks a round: a whole number, or an odd count over 2,
  so 2 is '1' and 3 is '3/2'. }
function HalvesStr(halves: Byte): TNumStr;

{ n, not negative, in decimal with a comma between each group of three digits: 2500 is '2,500'. }
function Grouped(n: LongInt): TGroupedStr;

{ singular when n is 1, plural otherwise: the noun alone, for a caller that puts something between the number and it,
  as CharHlp.CatchText's '3 OF 2 ENEMIES'. }
function Pluralize(n: LongInt; singular, plural: TNounStr): TNounStr;

{ n and a blank, then its noun (Pluralize): '1 SQUARE', '3 SQUARES', '0 points'. }
function Count(n: LongInt; singular, plural: TNounStr): TCountStr;

{ s cut, or padded with spaces on the right, to width. }
function PadRight(s: String; width: Byte): String;

{ s cut, or padded with spaces on the left, to width. }
function PadLeft(s: String; width: Byte): String;

{ A '~'-hotkey menu as it is shown: letters lowercased, each '~' deleted and the character after it uppercased, the
  hotkeys collected in opts. Digits are left alone (SSI shifted them by 32 as well, so a '1' showed as a 'Q', #810). }
procedure MenuToOptions(var menu, opts: String);

implementation

function NumStr(n: LongInt): TNumStr;
var
  s: TNumStr;
begin
  Str(n, s);
  NumStr := s;
end;

function HalvesStr(halves: Byte): TNumStr;
begin
  if Odd(halves) then
    HalvesStr := StrUtil.NumStr(halves) + '/2'
  else
    HalvesStr := StrUtil.NumStr(halves div 2);
end;

function ZeroPad2(n: Word): TNumStr;
var
  s: TNumStr;
begin
  Str(n mod 100, s);
  if Length(s) < 2 then
    s := '0' + s;
  ZeroPad2 := s;
end;

function Grouped(n: LongInt): TGroupedStr;
var
  s: TGroupedStr;
  i: Integer;
begin
  Str(n, s);
  i := Length(s) - 3;
  while i > 0 do begin
    Insert(',', s, i + 1);
    Dec(i, 3);
  end;
  Grouped := s;
end;

function Pluralize(n: LongInt; singular, plural: TNounStr): TNounStr;
begin
  if n = 1 then
    Pluralize := singular
  else
    Pluralize := plural;
end;

function Count(n: LongInt; singular, plural: TNounStr): TCountStr;
begin
  Count := StrUtil.NumStr(n) + ' ' + StrUtil.Pluralize(n, singular, plural);
end;

function PadRight(s: String; width: Byte): String;
begin
  s := Copy(s, 1, width);
  while Length(s) < width do
    s := s + ' ';
  PadRight := s;
end;

function PadLeft(s: String; width: Byte): String;
begin
  s := Copy(s, 1, width);
  while Length(s) < width do
    s := ' ' + s;
  PadLeft := s;
end;

procedure MenuToOptions(var menu, opts: String);
var
  i: Byte;
begin
  opts := '';
  i := 1;
  while i <= Length(menu) do begin
    if menu[i] in ['A'..'Z'] then
      menu[i] := Chr(Ord(menu[i]) + 32);
    if menu[i] = '~' then begin
      Delete(menu, i, 1);
      if i <= Length(menu) then begin
        menu[i] := UpCase(menu[i]);
        opts := opts + menu[i];
      end;
    end;
    Inc(i);
  end;
end;

end.

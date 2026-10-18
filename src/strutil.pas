{ Number and padding helpers for text the game shows. Resident and depending on nothing, so any unit can use it, even
  the ones that start before the overlay manager (GameIo, TextRend). }
{$F+}
{$I COMPILER.INC}
unit StrUtil;

interface

type
  { long enough for any LongInt, sign included }
  TNumStr = string[11];

{ n in decimal. }
function NumStr(n: LongInt): TNumStr;

{ n in two digits, a 0 in front of one below 10 (only the last two digits of a larger one). }
function ZeroPad2(n: Word): TNumStr;

{ s cut, or padded with spaces on the right, to width. }
function PadRight(s: String; width: Byte): String;

{ s cut, or padded with spaces on the left, to width. }
function PadLeft(s: String; width: Byte): String;

implementation

function NumStr(n: LongInt): TNumStr;
var
  s: TNumStr;
begin
  Str(n, s);
  NumStr := s;
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

end.

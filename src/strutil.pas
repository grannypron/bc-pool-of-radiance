{ Small formatting helpers used throughout the UI. This unit has no dependencies
  and stays resident, so startup code can use it before overlays are available. }
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

{ Validates the length byte of a short string read directly from disk. Truncate
  corrupt values to the field size so later string operations cannot read into
  the following field (#917). Returns True when no repair was needed. }
function FitLength(var s; max: Byte): Boolean;

{ s cut, or padded with spaces on the right, to width. }
function PadRight(s: String; width: Byte): String;

{ s cut, or padded with spaces on the left, to width. }
function PadLeft(s: String; width: Byte): String;

{ A '~'-hotkey menu as it is shown: letters lowercased, each '~' deleted and the character after it uppercased, the
  hotkeys collected in opts. Digits are left alone (SSI shifted them by 32 as well, so a '1' showed as a 'Q', #810). }
procedure MenuToOptions(var menu, opts: String);

{ A script menu option marked with '~' before its hotkey, for MenuToOptions: its first character, unless an earlier
  option of the menu took that key and the option has a later letter or digit no earlier option took, which is then
  marked instead, so every option can be chosen (the Nomad Camp's ATTACK after ADVANCE CAUTIOUSLY is aTtack). taken
  holds the keys the menu's earlier options took, upper case, and gets this one's. An empty option is '~' alone and
  takes no key. }
function MarkHotkey(option: String; var taken: String): String;

{ The columns a horizontal menu lights for the option whose hotkey is at menu position first: from the start of the
  word holding the hotkey to the end of the option's last word, the word before the one holding the next option's
  hotkey at nextFirst (0 for the last option, which runs to the end of the menu, trailing spaces left out). So coMbat
  lights alone in 'coMbat sYstem' and 'Advance cautiously' whole in 'Advance cautiously aTtack' (#1216). When no space
  parts the two hotkeys, the option runs to the character before the next one. first must be 1 or more. }
procedure OptionSpan(menu: String; first, nextFirst: Byte; var hlFirst, hlLast: Byte);

{ s with every occurrence of del removed, adjacent ones and ones the removals bring together included: 'A....B' less '.'
  is 'AB' (SSI's pass moved on after each removal and kept one of two in a row, POR-0224, #960). An empty del removes
  nothing. }
function RemoveAll(s, del: String): String;

implementation

function FitLength(var s; max: Byte): Boolean;
begin
  FitLength := Byte(s) <= max;
  if Byte(s) > max then
    Byte(s) := max;
end;

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

function MarkHotkey(option: String; var taken: String): String;
var
  at: Byte;
  i: Byte;
begin
  at := 1;
  if (option <> '') and (Pos(UpCase(option[1]), taken) > 0) then begin
    i := 2;
    while (i <= Length(option)) and (at = 1) do begin
      if (UpCase(option[i]) in ['A'..'Z', '0'..'9']) and (Pos(UpCase(option[i]), taken) = 0) then
        at := i;
      Inc(i);
    end;
  end;
  if option <> '' then
    taken := taken + UpCase(option[at]);
  Insert('~', option, at);
  MarkHotkey := option;
end;

procedure OptionSpan(menu: String; first, nextFirst: Byte; var hlFirst, hlLast: Byte);
begin
  hlFirst := first;
  while (hlFirst > 1) and (menu[hlFirst - 1] <> ' ') do
    Dec(hlFirst);
  if nextFirst > first then begin
    { back over the next option's word to the space before it }
    hlLast := nextFirst - 1;
    while (hlLast > first) and (menu[hlLast] <> ' ') do
      Dec(hlLast);
    if menu[hlLast] <> ' ' then
      hlLast := nextFirst - 1;
  end else
    hlLast := Length(menu);
  while (hlLast > first) and (menu[hlLast] = ' ') do
    Dec(hlLast);
end;

function RemoveAll(s, del: String): String;
var
  i: Byte;
begin
  i := 1;
  if del <> '' then
    while i + Length(del) - 1 <= Length(s) do
      if Copy(s, i, Length(del)) = del then begin
        Delete(s, i, Length(del));
        { a match the removal brought together starts at most Length(del) - 1 places back }
        if i > Length(del) then
          Dec(i, Length(del) - 1)
        else
          i := 1;
      end else
        Inc(i);
  RemoveAll := s;
end;

end.

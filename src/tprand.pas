{ Turbo Pascal's random-number generator for native builds. Free Pascal uses a
  different algorithm, which would change dice rolls and make DOS input replays
  diverge. Units import this after System so these compatible RandSeed, Random,
  and Randomize definitions win. tests/ttprand.pas compares them with TP6. }
{$I COMPILER.INC}
{$IFDEF FPC}
{$Q-,R-}
{$ENDIF}
unit TpRand;

interface

var
  RandSeed: LongInt;

{ The next number in 0..range - 1 (0 when range is 0), as Turbo Pascal 6's System.Random(range: Word) gives it: the seed
  steps to seed * 134775813 + 1, and the number is the seed's high word modulo range. }
function Random(range: Word): Word;

{ A seed from the clock, as Randomize sets one from DOS's time. }
procedure Randomize;

implementation

uses Dos;

{ seed * 134775813 + 1, modulo 2^32, in 16-bit halves: Turbo Pascal's own way, with no 64-bit type. The products can
  pass MaxLongInt (lo * $8405 reaches $84047BFB); they wrap, with overflow and range checks off (Turbo Pascal 6 has
  none; the unit turns Free Pascal's off), and only their low halves are kept, so the seed is exact. }
procedure NextSeed;
var
  lo, hi: Word;
  p0, p1: LongInt;
begin
  lo := RandSeed and $FFFF;
  hi := (RandSeed shr 16) and $FFFF;
  { 134775813 = $08088405: the low half $8405, the high $0808 }
  p0 := LongInt(lo) * $8405;
  p1 := ((p0 shr 16) and $FFFF) + LongInt(lo) * $0808 + LongInt(hi) * $8405;
  RandSeed := (((p1 and $FFFF) shl 16) or (p0 and $FFFF)) + 1;
end;

function Random(range: Word): Word;
var
  hi: Word;
begin
  NextSeed;
  hi := (RandSeed shr 16) and $FFFF;
  if range = 0 then
    Random := 0
  else
    Random := hi mod range;
end;

procedure Randomize;
var
  h, m, s, s100: Word;
begin
  GetTime(h, m, s, s100);
  RandSeed := ((LongInt(s) shl 8 or s100) shl 16) or (LongInt(h) shl 8 or m);
end;

end.

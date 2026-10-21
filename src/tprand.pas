{ Turbo Pascal's random numbers, for the native build: Free Pascal's Random is a Mersenne twister, so the same RandSeed
  (STING NORAND's 1) would roll other dice, and a replay of the DOS game's keys would play out otherwise. Each unit that
  rolls uses this one under Free Pascal, after System, so its RandSeed, Random and Randomize are the ones it calls; the
  DOS build keeps System's, which these match (tests/ttprand.pas checks them against each other under Turbo Pascal). }
{$I COMPILER.INC}
unit TpRand;

interface

var
  RandSeed: LongInt;

{ The next number in 0..range - 1 (0 when range is 0), as Turbo Pascal 6's System.Random(range: Word) gives it: the
  seed steps to seed * 134775813 + 1, and the number is the seed's high word modulo range. }
function Random(range: Word): Word;

{ A seed from the clock, as Randomize sets one from DOS's time. }
procedure Randomize;

implementation

uses Dos;

{ seed * 134775813 + 1, modulo 2^32, in 16-bit halves: Turbo Pascal's own way, which neither overflows a LongInt nor
  needs a 64-bit type }
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

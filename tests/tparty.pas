{ Tests for Party: stepping the current character with SelectPrevNextChar, from a character and from none (#806). }
{$I COMPILER.INC}
program TParty;

uses Types, GDVars, C_GBVM, C_KEYS, Party, TestKit;

var
  a: Types.PCharRecord;
  b: Types.PCharRecord;
  c: Types.PCharRecord;

function NewCreature(next: Types.PCharRecord): Types.PCharRecord;
var
  p: Types.PCharRecord;
begin
  GetMem(p, SizeOf(Types.TCharRecord));
  FillChar(p^, SizeOf(Types.TCharRecord), 0);
  p^.nextCharAddr := next;
  NewCreature := p;
end;

begin
  TestKit.Start('TPARTY');
  GetMem(GDVars.zone1, SizeOf(Types.TGbvmZone1));
  FillChar(GDVars.zone1^, SizeOf(Types.TGbvmZone1), 0);
  c := NewCreature(nil);
  b := NewCreature(c);
  a := NewCreature(b);
  GDVars.creatureList := a;
  GDVars.zone1^[C_GBVM.PARTY_SIZE] := 3;

  GDVars.curChar := a;
  Party.SelectPrevNextChar(C_KEYS.DOWN);
  TestKit.Check(GDVars.curChar = b, 'Down steps to the next character');
  Party.SelectPrevNextChar(C_KEYS.UP);
  TestKit.Check(GDVars.curChar = a, 'Up steps back');
  Party.SelectPrevNextChar(C_KEYS.HOME);
  TestKit.Check(GDVars.curChar = c, 'the previous from the head wraps to the tail');
  Party.SelectPrevNextChar(C_KEYS.END_KEY);
  TestKit.Check(GDVars.curChar = a, 'the next from the tail wraps to the head');
  Party.SelectPrevNextChar('1');
  TestKit.Check(GDVars.curChar = a, 'another key keeps the current character');

  { no current character: the step starts from the head }
  GDVars.curChar := nil;
  Party.SelectPrevNextChar(C_KEYS.DOWN);
  TestKit.Check(GDVars.curChar = b, 'Down with no one selected steps from the head');
  GDVars.curChar := nil;
  Party.SelectPrevNextChar(C_KEYS.UP);
  TestKit.Check(GDVars.curChar = c, 'Up with no one selected steps back from the head to the tail');
  GDVars.curChar := nil;
  Party.SelectPrevNextChar('1');
  TestKit.Check(GDVars.curChar = a, 'another key with no one selected takes the head');

  { an empty list leaves no one selected }
  GDVars.creatureList := nil;
  GDVars.curChar := nil;
  Party.SelectPrevNextChar(C_KEYS.DOWN);
  TestKit.Check(GDVars.curChar = nil, 'an empty party selects no one');
  TestKit.Done;
end.

{ Tests for Party: stepping the current character with SelectPrevNextChar, from a character and from none (#806),
  and the creature before and after nil (#949). }
{$I COMPILER.INC}
program TParty;

uses Types, GameVars, C_GBVM, C_KEYS, Party, TestKit;

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
  GetMem(GameVars.zone1, SizeOf(Types.TGbvmZone1));
  FillChar(GameVars.zone1^, SizeOf(Types.TGbvmZone1), 0);
  c := NewCreature(nil);
  b := NewCreature(c);
  a := NewCreature(b);
  GameVars.creatureList := a;
  GameVars.zone1^[C_GBVM.PARTY_SIZE] := 3;

  GameVars.curChar := a;
  Party.SelectPrevNextChar(C_KEYS.DOWN);
  TestKit.Check(GameVars.curChar = b, 'Down steps to the next character');
  Party.SelectPrevNextChar(C_KEYS.UP);
  TestKit.Check(GameVars.curChar = a, 'Up steps back');
  Party.SelectPrevNextChar(C_KEYS.HOME);
  TestKit.Check(GameVars.curChar = c, 'the previous from the head wraps to the tail');
  Party.SelectPrevNextChar(C_KEYS.END_KEY);
  TestKit.Check(GameVars.curChar = a, 'the next from the tail wraps to the head');
  Party.SelectPrevNextChar('1');
  TestKit.Check(GameVars.curChar = a, 'another key keeps the current character');

  { no current character: the step starts from the head }
  GameVars.curChar := nil;
  Party.SelectPrevNextChar(C_KEYS.DOWN);
  TestKit.Check(GameVars.curChar = b, 'Down with no one selected steps from the head');
  GameVars.curChar := nil;
  Party.SelectPrevNextChar(C_KEYS.UP);
  TestKit.Check(GameVars.curChar = c, 'Up with no one selected steps back from the head to the tail');
  GameVars.curChar := nil;
  Party.SelectPrevNextChar('1');
  TestKit.Check(GameVars.curChar = a, 'another key with no one selected takes the head');

  { PrevCreature and NextCreature of nil: nil is the place after the last }
  TestKit.Check(Party.PrevCreature(nil) = c, 'the creature before nil is the last');
  TestKit.Check(Party.NextCreature(nil) = a, 'the creature after nil is the head');

  { an empty list leaves no one selected }
  GameVars.creatureList := nil;
  GameVars.curChar := nil;
  Party.SelectPrevNextChar(C_KEYS.DOWN);
  TestKit.Check(GameVars.curChar = nil, 'an empty party selects no one');
  TestKit.Done;
end.

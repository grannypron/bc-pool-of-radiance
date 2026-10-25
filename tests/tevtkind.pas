{ Tests for EvtKind (phase 8): a script laid out by hand in zone 3, dispatching on the event byte each way the area
  scripts do, and each event named by what its code does. }
{$I COMPILER.INC}
program TEvtKind;

uses Types, GameVars, C_GBVM, EvtKind, TestKit;

{ Lay bytes at GBVM address a. }
procedure Put(a: Word; bytes: String);
var
  i: Byte;
begin
  for i := 1 to Length(bytes) do
    GameVars.zone3^[a + i - 1] := Ord(bytes[i]);
end;

begin
  TestKit.Start('TEVTKIND');
  GetMem(GameVars.zone3, SizeOf(GameVars.zone3^));
  FillChar(GameVars.zone3^, SizeOf(GameVars.zone3^), 0);
  GetMem(GameVars.gbStrings, SizeOf(GameVars.gbStrings^));
  { 1: AND #7F [C04F] [6E82]; ON GOTO [6E82] #3 [A000] [A010] [A020] }
  Put($9900, #$2F#$00#$7F#$01#$4F#$C0#$01#$82#$6E);
  Put($9909, #$25#$01#$82#$6E#$00#$03#$01#$00#$A0#$01#$10#$A0#$01#$20#$A0);
  { 2: COMPARE [C04F] #9; IF =; GOTO [A030]; EXIT }
  Put($9920, #$03#$01#$4F#$C0#$00#$09#$16#$01#$01#$30#$A0#$00);
  { 3, as the training hall: AND #7F [C04F] [6E82]; SAVE #A [9800]; COMPARE [9800] [6E82]; IF =; GOTO [9960]; EXIT; at
    9960 SUBTRACT #A [9800] [9800]; ON GOTO [9800] #1 [A040] }
  Put($9940, #$2F#$00#$7F#$01#$4F#$C0#$01#$82#$6E#$09#$00#$0A#$01#$00#$98#$03#$01#$00#$98#$01#$82#$6E#$16#$01#$01#$60
             + #$99#$00);
  Put($9960, #$05#$00#$0A#$01#$00#$98#$01#$00#$98#$25#$01#$00#$98#$00#$01#$01#$40#$A0);
  { 4, as Podal Plaza: AND #7F [C04F] [6E79]; SAVE #0 [6E79], a menu's answer after; COMPARE [6E79] #11; IF =; GOTO
    [A050]; EXIT }
  Put($9980, #$2F#$00#$7F#$01#$4F#$C0#$01#$79#$6E#$09#$00#$00#$01#$79#$6E#$03#$01#$79#$6E#$00#$0B#$16#$01#$01#$50#$A0
             + #$00);
  { the events: A000 EXIT; A010 PRINT ""; EXIT; A020 a shop, SAVE #1 [6E6C]; COMBAT; EXIT; A030 COMBAT; EXIT; A040
    TREASURE of nothing; EXIT; A050 NEWECL #3 }
  Put($A010, #$11#$80#$00#$00);
  Put($A020, #$09#$00#$01#$01#$6C#$6E#$24#$00);
  Put($A030, #$24#$00);
  Put($A040, #$27#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00);
  Put($A050, #$20#$00#$03);
  { 5, an IF as the one instruction (#953): COMPARE [C04F] #12; IF =; IF =; COMBAT; PRINT ""; EXIT. Event 12 runs the
    second IF, whose instruction is the COMBAT; the PRINT past it is not the event's }
  Put($99A0, #$03#$01#$4F#$C0#$00#$0C#$16#$16#$24#$11#$80#$00#$00);
  GameVars.scriptEntryAddrs[1] := $9900;
  GameVars.scriptEntryAddrs[2] := $9920;
  GameVars.scriptEntryAddrs[3] := $9940;
  GameVars.scriptEntryAddrs[4] := $9980;
  GameVars.scriptEntryAddrs[5] := $99A0;
  EvtKind.Prepare;
  TestKit.CheckEqualsL(EvtKind.KIND_NONE, EvtKind.Kind(0), 'no event');
  TestKit.CheckEqualsL(EvtKind.KIND_MESSAGE, EvtKind.Kind(1), 'ON GOTO: a message');
  TestKit.CheckEqualsL(EvtKind.KIND_SERVICE, EvtKind.Kind(2), 'a shop, though it opens with COMBAT');
  TestKit.CheckEqualsL(EvtKind.KIND_SERVICE, EvtKind.Kind($82), 'the mask drops the high bit');
  TestKit.CheckEqualsL(EvtKind.KIND_FIGHT, EvtKind.Kind(9), 'COMPARE and IF =: a fight');
  TestKit.CheckEqualsL(EvtKind.KIND_TREASURE, EvtKind.Kind(10), 'a counted copy, less 10: treasure');
  TestKit.CheckEqualsL(EvtKind.KIND_EVENT, EvtKind.Kind(5), 'no dispatch found: an event');
  TestKit.CheckEqualsL(EvtKind.KIND_EVENT, EvtKind.Kind(11), 'a variable written over no longer holds the event');
  TestKit.CheckEqualsL(EvtKind.KIND_FIGHT, EvtKind.Kind(12), 'an IF as the one instruction: the one it guards');
  { the answers are kept until the next Prepare (#692): 9's code made a message, PRINT ""; EXIT }
  Put($A030, #$11#$80#$00#$00);
  TestKit.CheckEqualsL(EvtKind.KIND_FIGHT, EvtKind.Kind(9), 'an answer kept until Prepare');
  EvtKind.Prepare;
  TestKit.CheckEqualsL(EvtKind.KIND_MESSAGE, EvtKind.Kind(9), 'Prepare forgets the answers');
  TestKit.Done;
end.

{ Tests for EclTrace.OpName: the trace log's opcode names, Curse's spelling kept. }
{$I COMPILER.INC}
program TEclTrc;

uses C_ECL, EclTrace, TestKit;

begin
  TestKit.Start('TECLTRC');
  TestKit.CheckEqualsS('EXIT', EclTrace.OpName(C_ECL.EXIT_SCRIPT), 'EXIT');
  TestKit.CheckEqualsS('GOSUB', EclTrace.OpName(C_ECL.GOSUB), 'GOSUB');
  TestKit.CheckEqualsS('SUBTRAT', EclTrace.OpName(C_ECL.SUBTRACT), 'SUBTRACT keeps Curse''s spelling');
  TestKit.CheckEqualsS('IF = ', EclTrace.OpName(C_ECL.IF_EQ), 'IF =, with its trailing space');
  TestKit.CheckEqualsS('NEWECL', EclTrace.OpName(C_ECL.NEWECL), 'NEWECL');
  TestKit.CheckEqualsS('?', EclTrace.OpName($FF), 'an unknown opcode');
  TestKit.Done;
end.

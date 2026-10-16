{ Tests for EclTrace.OpName: the trace log's opcode names, Curse's spelling kept. }
program TEclTrc;

uses C_Ecl, EclTrace, TestKit;

begin
  TestKit.Start('TECLTRC');
  TestKit.CheckEqualsS('EXIT', EclTrace.OpName(C_Ecl.EXIT_SCRIPT), 'EXIT');
  TestKit.CheckEqualsS('GOSUB', EclTrace.OpName(C_Ecl.GOSUB), 'GOSUB');
  TestKit.CheckEqualsS('SUBTRAT', EclTrace.OpName(C_Ecl.SUBTRACT), 'SUBTRACT keeps Curse''s spelling');
  TestKit.CheckEqualsS('IF = ', EclTrace.OpName(C_Ecl.IF_EQ), 'IF =, with its trailing space');
  TestKit.CheckEqualsS('NEWECL', EclTrace.OpName(C_Ecl.NEWECL), 'NEWECL');
  TestKit.CheckEqualsS('?', EclTrace.OpName($FF), 'an unknown opcode');
  TestKit.Done;
end.

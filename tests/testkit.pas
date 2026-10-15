{ The unit tests' checks: each test program uses this unit and the units it tests, calls Check and the CheckEquals
  routines, and ends with Done. Results go to the log TEST.LOG in the current directory, which build.sh reads: a line
  per failure and a summary line per program. }
unit TestKit;

interface

{ Start the program's checks under name, for its summary line. }
procedure Start(name: String);

{ Record a check: ok, or a failure named what. }
procedure Check(ok: Boolean; what: String);

{ Check that actual is expected. }
procedure CheckEqualsL(expected, actual: LongInt; what: String);
procedure CheckEqualsS(expected, actual: String; what: String);

{ Write the program's summary line, close the log, and end the program with exit code 1 when a check failed. }
procedure Done;

implementation

var
  log: Text;
  program_: String;
  passed: Word;
  failed: Word;

function NumStr(n: LongInt): String;
var
  s: String;
begin
  Str(n, s);
  NumStr := s;
end;

procedure Start(name: String);
begin
  program_ := name;
  passed := 0;
  failed := 0;
  Assign(log, 'TEST.LOG');
  {$I-}
  Append(log);
  if IOResult <> 0 then
    Rewrite(log);
  {$I+}
end;

procedure Check(ok: Boolean; what: String);
begin
  if ok then
    Inc(passed)
  else begin
    Inc(failed);
    WriteLn(log, 'FAIL ', program_, ': ', what);
  end;
end;

procedure CheckEqualsL(expected, actual: LongInt; what: String);
begin
  if expected = actual then
    TestKit.Check(True, what)
  else
    TestKit.Check(False, what + ': expected ' + TestKit.NumStr(expected) + ', got ' + TestKit.NumStr(actual));
end;

procedure CheckEqualsS(expected, actual: String; what: String);
begin
  if expected = actual then
    TestKit.Check(True, what)
  else
    TestKit.Check(False, what + ': expected ''' + expected + ''', got ''' + actual + '''');
end;

procedure Done;
begin
  WriteLn(log, 'DONE ', program_, ': ', passed, ' passed, ', failed, ' failed');
  Close(log);
  if failed > 0 then
    Halt(1);
end;

end.

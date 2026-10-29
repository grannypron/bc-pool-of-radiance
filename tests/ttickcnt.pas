{ Tests for TextRend.TickCount natively: each read runs Host.Service (through Crt.Delay), so a loop that waits by
  watching the clock, as the ending's animations do, presents its frames and keeps the window answering (#1095); and
  the count still moves with the clock. DOS has no Host, and nothing to test. }
{$I COMPILER.INC}
program TTickCnt;

uses {$IFDEF FPC}Host, TextRend, {$ENDIF}TestKit;

{$IFDEF FPC}
var
  services: LongInt;
  first: LongInt;
  last: LongInt;
  reads: Word;

procedure CountService;
begin
  Inc(services);
end;
{$ENDIF}

begin
  TestKit.Start('TTICKCNT');
{$IFDEF FPC}
  services := 0;
  Host.serviceHook := CountService;
  TextRend.TickCount;
  TestKit.Check(services >= 1, 'a read services the host');
  services := 0;
  first := TextRend.TickCount;
  reads := 1;
  repeat
    last := TextRend.TickCount;
    Inc(reads);
  until (last <> first) or (reads = 1000);
  TestKit.Check(last <> first, 'the count moves while a loop watches it');
  TestKit.Check(services >= reads, 'every read of the loop serviced the host');
  Host.serviceHook := nil;
{$ENDIF}
  TestKit.Done;
end.

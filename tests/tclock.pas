{ Tests for Clock.ValidateClock: each part carries into the next at its GDConsts.unitScale limit (10 segments, 10
  minutes, 6 turns, 24 hours, 30 days, 12 months), once a call, upward through the parts in one call, and the party ages
  at a new year when asked; and Clock.SetFromMinutes, which turns a duration into days, hours, turns and minutes. }
program TClock;

uses Types, GDVars, Clock, TestKit;

var
  t: Types.TClock;
  c: Types.PCharRecord;

procedure SetClock(seg, min, turn, hour, day, month, year: Word);
begin
  t[0] := seg;
  t[1] := min;
  t[2] := turn;
  t[3] := hour;
  t[4] := day;
  t[5] := month;
  t[6] := year;
end;

function Shows(seg, min, turn, hour, day, month, year: Word): Boolean;
begin
  Shows := (t[0] = seg) and (t[1] = min) and (t[2] = turn) and (t[3] = hour) and (t[4] = day) and (t[5] = month) and
           (t[6] = year);
end;

begin
  TestKit.Start('TCLOCK');
  GetMem(c, SizeOf(Types.TCharRecord));
  FillChar(c^, SizeOf(Types.TCharRecord), 0);
  c^.age := 20;
  GDVars.creatureList := c;

  SetClock(9, 0, 0, 0, 0, 0, 0);
  Clock.ValidateClock(t, True);
  TestKit.Check(Shows(9, 0, 0, 0, 0, 0, 0), 'nothing carries below a limit');
  SetClock(10, 0, 0, 0, 0, 0, 0);
  Clock.ValidateClock(t, True);
  TestKit.Check(Shows(0, 1, 0, 0, 0, 0, 0), '10 segments are a minute');
  SetClock(0, 10, 5, 0, 0, 0, 0);
  Clock.ValidateClock(t, True);
  TestKit.Check(Shows(0, 0, 0, 1, 0, 0, 0), '10 minutes a turn, and 6 turns an hour, in one call');
  SetClock(0, 0, 0, 24, 29, 11, 3);
  Clock.ValidateClock(t, False);
  TestKit.Check(Shows(0, 0, 0, 0, 0, 0, 4), '24 hours a day, 30 days a month, 12 months a year');
  TestKit.CheckEqualsL(20, c^.age, 'no ageing unless asked');
  SetClock(10, 9, 5, 23, 29, 11, 3);
  Clock.ValidateClock(t, True);
  TestKit.Check(Shows(0, 0, 0, 0, 0, 0, 4), 'a carry runs up through every part');
  TestKit.CheckEqualsL(21, c^.age, 'and the new year ages the party');
  SetClock(25, 0, 0, 0, 0, 0, 0);
  Clock.ValidateClock(t, True);
  TestKit.Check(Shows(15, 1, 0, 0, 0, 0, 0), 'one carry a call');
  SetClock(0, 0, 0, 0, 0, 0, 300);
  Clock.ValidateClock(t, True);
  TestKit.Check(Shows(0, 0, 0, 0, 0, 0, 300), 'the year has no limit');

  { a duration in minutes: days, hours, turns and minutes (#644) }
  SetClock(7, 7, 7, 7, 7, 7, 7);
  Clock.SetFromMinutes(t, 0);
  TestKit.Check(Shows(0, 0, 0, 0, 0, 0, 0), 'no minutes clears every part');
  Clock.SetFromMinutes(t, 375);
  TestKit.Check(Shows(0, 5, 1, 6, 0, 0, 0), '375 minutes: 6 hours, a turn and 5 minutes');
  Clock.SetFromMinutes(t, 1800);
  TestKit.Check(Shows(0, 0, 0, 6, 1, 0, 0), '30 hours: a day and 6 hours, not 30 hours');
  Clock.SetFromMinutes(t, 65535);
  TestKit.Check(Shows(0, 5, 1, 12, 45, 0, 0), 'the longest: 45 days, 12 hours, a turn and 5 minutes');

  FreeMem(c, SizeOf(Types.TCharRecord));
  TestKit.Done;
end.

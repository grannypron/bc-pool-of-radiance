{ The game clock's carries. Resident, as every combat round and every step advance the clock, and using only data
  units, so tests can use it. }
{$F+}
{$I COMPILER.INC}
unit Clock;

interface

uses Types;

procedure ValidateClock(var clock: Types.TClock; ageOnYear: Boolean);

{ Set clock to a duration of minutes: days, hours, turns (ten minutes) and minutes, each within its limit, and the
  segments, months and years 0. Camp's rests start the rest clock with it (#644). }
procedure SetFromMinutes(var clock: Types.TClock; minutes: Word);

implementation

uses GDConsts, GDVars, C_Time;

{ Carry each clock component that has reached its GDConsts.unitScale limit into the next one (one carry per component
  per call); the year has no limit. When ageOnYear is set, every creature in GDVars.creatureList ages by one as the
  months carry into a new year. }
procedure ValidateClock(var clock: Types.TClock; ageOnYear: Boolean);
var
  i: ShortInt;
  cur: Types.PCharRecord;
begin
  for i := 0 to C_Time.MONTHS do
    if clock[i] >= GDConsts.unitScale[i] then begin
      Inc(clock[Succ(i)]);
      clock[i] := clock[i] - GDConsts.unitScale[i];
      if (i = C_Time.MONTHS) and ageOnYear then begin
        cur := GDVars.creatureList;
        while cur <> nil do begin
          Inc(cur^.age);
          cur := cur^.nextCharAddr;
        end;
      end;
    end;
end;

procedure SetFromMinutes(var clock: Types.TClock; minutes: Word);
begin
  FillChar(clock, SizeOf(clock), 0);
  clock[C_Time.DAYS] := minutes div 1440;
  clock[C_Time.HOURS] := (minutes mod 1440) div 60;
  clock[C_Time.TURNS] := (minutes mod 60) div 10;
  clock[C_Time.MINUTES] := minutes mod 10;
end;

end.

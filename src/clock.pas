{ The game clock's carries. Resident, as every combat round and every step advance the clock, and using only data
  units, so tests can use it. }
{$F+}
unit Clock;

interface

uses Types;

procedure ValidateClock(var clock: Types.TClock; ageOnYear: Boolean);

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

end.

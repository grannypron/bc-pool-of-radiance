{ The startup advisory's decisions (#1173), apart from its screen so the tests can check it: whether the support part is
  due, from the version POOLOPT.CFG says it was last shown for, and whether the speed part is, from how long the speed
  check's loop took. Advisory measures the speed and shows the screen. }
{$O+,F+}
{$I COMPILER.INC}
unit AdvPlan;

interface

const
  { The PIT clocks (1.193 MHz, 0.838 microseconds each) the speed check's loop (Advisory.Measure) may take before the
    game calls this computer slower than it needs. Measured in goldbox-player's DOSBox-X, under its harness (#1173),
    the loop takes 300,000 / cycles milliseconds at fixed cycles: 100.5 ms at 3000 (DOSBox's default for a DOS
    game, cycles=auto), 15.0 at 20000, 10.0 at 30000 (GOG's setting, and the harness's), 2.4 at max. The game, from
    start to the main menu: 52.2 s at 3000, 29.1 at 6000, 21.8 at 9000, 17.7 at 12000, 15.7 at 15000, 14.4 at 17500,
    13.5 at 20000, 12.8 at 25000, 11.7 at 30000, 10.5 at max; a Quick fight (save I's orcs in Podal Plaza): 148.8 s at
    3000, 105.2 at 6000, 83.8 at 12000, 74.7 at 15000, 62.4 at 20000, 50.7 at 30000, 28.6 at max. From 20000 up the
    start is within a third of max's and a fight near GOG's; below it each step down costs more. So the limit is
    16.7 ms, about 18,000 cycles: 20000 passes (17,900 clocks), 17500 does not (20,500). }
  SLOW_CLOCKS = 19900;
  { The PIT clocks the loop takes at one DOSBox-X cycle, from the same measurements: 300,000 ms at 1,193.182 clocks a
    millisecond. A measurement's cycles are this over its clocks (#1178). }
  CYCLE_CLOCKS = 357954600;

{ True when the support part is due: the version it was last shown for (advised, as POOLOPT.CFG keeps it: tidied, ''
  when it never was) is not this build's (version, in any case). }
function SupportDue(advised, version: string): Boolean;

{ True when the speed part is due: the speed check's loop took more than SLOW_CLOCKS. clocks is 0 when the check did
  not run (natively, which measures only the host), and that is never slow. }
function SpeedSlow(clocks: LongInt): Boolean;

{ The DOSBox-X fixed cycles the speed check's clocks match (CYCLE_CLOCKS over them), to the nearest 100, as the System
  page shows them (#1178): 30,000 for 11,932 clocks. 0 for 0, a check that did not run; a computer far slower than
  DOSBox's 3,000 cycles may give 0 too. Under another DOSBox, or on a real PC, it is a comparison, not its setting. }
function CyclesOf(clocks: LongInt): LongInt;

implementation

uses CfgFile;

function SupportDue(advised, version: string): Boolean;
begin
  SupportDue := CfgFile.Tidy(advised) <> CfgFile.Tidy(version);
end;

function SpeedSlow(clocks: LongInt): Boolean;
begin
  SpeedSlow := clocks > SLOW_CLOCKS;
end;

function CyclesOf(clocks: LongInt): LongInt;
var
  cycles: LongInt;
begin
  if clocks <= 0 then
    CyclesOf := 0
  else begin
    cycles := (CYCLE_CLOCKS + clocks div 2) div clocks;
    CyclesOf := (cycles + 50) div 100 * 100;
  end;
end;

end.

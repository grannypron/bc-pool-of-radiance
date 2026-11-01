{ Tests for AdvPlan (#1173): the startup advisory's support part is due on the first start and after each new version,
  its speed part whenever the speed check measures slower than the limit. }
{$I COMPILER.INC}
program TAdvPlan;

uses AdvPlan, TestKit;

begin
  TestKit.Start('TADVPLAN');
  TestKit.Check(AdvPlan.SupportDue('', 'v1.3-1600'), 'the support part on the first start, with none advised');
  TestKit.Check(not AdvPlan.SupportDue('V1.3-1600', 'v1.3-1600'), 'not again for the version advised, in any case');
  TestKit.Check(not AdvPlan.SupportDue(' V1.3-1600 ', 'v1.3-1600'), 'spaces around it aside');
  TestKit.Check(AdvPlan.SupportDue('V1.3-1600', 'v1.3-1601'), 'but again for a new version');
  TestKit.Check(AdvPlan.SupportDue('V1.3-1601', 'v1.3-1600'), 'or an older one');
  TestKit.Check(AdvPlan.SupportDue('V1.3-1600', 'UNKNOWN'), 'or a build without git''s version');
  TestKit.Check(not AdvPlan.SpeedSlow(0), 'a speed check that did not run is not slow');
  TestKit.Check(not AdvPlan.SpeedSlow(1), 'a fast one is not');
  TestKit.Check(not AdvPlan.SpeedSlow(AdvPlan.SLOW_CLOCKS), 'nor one right at the limit');
  TestKit.Check(AdvPlan.SpeedSlow(AdvPlan.SLOW_CLOCKS + 1), 'past it is slow');
  TestKit.Check(AdvPlan.SpeedSlow(2000000), 'and far past it');
  { the cycles the measurement matches (#1178) }
  TestKit.CheckEqualsL(0, AdvPlan.CyclesOf(0), 'no cycles for a check that did not run');
  TestKit.CheckEqualsL(30000, AdvPlan.CyclesOf(11932), '10.0 ms is 30,000 cycles, GOG''s setting');
  TestKit.CheckEqualsL(20000, AdvPlan.CyclesOf(17900), '15.0 ms is 20,000');
  TestKit.CheckEqualsL(3000, AdvPlan.CyclesOf(119900), '100.5 ms is 3,000, DOSBox''s default');
  TestKit.CheckEqualsL(18000, AdvPlan.CyclesOf(AdvPlan.SLOW_CLOCKS), 'the slow limit is about 18,000');
  TestKit.CheckEqualsL(0, AdvPlan.CyclesOf(10000000), 'far slower than DOSBox''s default rounds to 0');
  TestKit.CheckEqualsL(357954600, AdvPlan.CyclesOf(1), 'one clock does not overflow');
  TestKit.Done;
end.

{ Tests for AreaName (#604): the Clue Book names by script, and the two-map scripts by map. }
program TAreas;

uses Types, AreaName, TestKit;

begin
  TestKit.Start('TAREAS');
  TestKit.CheckEqualsS('NEW PHLAN', AreaName.AreaFor(0, 0), 'script 0');
  TestKit.CheckEqualsS('SLUMS', AreaName.AreaFor(20, 0), 'script 20');
  TestKit.CheckEqualsS('KUTO''S WELL', AreaName.AreaFor(29, 29), 'script 29 on its first map');
  TestKit.CheckEqualsS('KUTO''S CATACOMBS', AreaName.AreaFor(29, 32), 'script 29 on map 32');
  TestKit.CheckEqualsS('VALJEVO CASTLE NW', AreaName.AreaFor(3, 3), 'script 3 on map 3');
  TestKit.CheckEqualsS('VALJEVO CASTLE SE', AreaName.AreaFor(3, 5), 'script 3 on map 5');
  TestKit.CheckEqualsS('VALJEVO CASTLE', AreaName.AreaFor(3, 4), 'script 3 on another map');
  TestKit.CheckEqualsS('LIZARD CATACOMBS', AreaName.AreaFor(16, 30), 'script 16 on map 30');
  TestKit.CheckEqualsS('TEMPLE OF BANE', AreaName.AreaFor(24, 24), 'script 24 on map 24');
  TestKit.CheckEqualsS('WEALTHY AREA', AreaName.AreaFor(24, 31), 'script 24 on map 31');
  TestKit.CheckEqualsS('UNKNOWN AREA', AreaName.AreaFor(12, 0), 'script 12, which the game does not have');
  TestKit.CheckEqualsS('UNKNOWN AREA', AreaName.AreaFor(30, 0), 'a script past the last');
  TestKit.CheckEqualsS('UNKNOWN AREA', AreaName.AreaFor(255, 0), 'script 255');
  TestKit.Done;
end.

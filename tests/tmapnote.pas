{ Tests for MapNotes (phase 8): notes set, changed and removed per square and area, the notes full, and the round trip
  through savgam<x>.nts. }
program TMapNote;

uses MapNotes, TestKit;

var
  i: Byte;
  ok: Boolean;

begin
  TestKit.Start('TMAPNOTE');
  MapNotes.Clear;
  TestKit.Check(MapNotes.SetNote(18, 1, 5, 8, 'the tavern'), 'a note is set');
  TestKit.CheckEqualsS('the tavern', MapNotes.Note(18, 1, 5, 8), 'and read back');
  TestKit.CheckEqualsS('', MapNotes.Note(18, 2, 5, 8), 'not on another map');
  TestKit.CheckEqualsS('', MapNotes.Note(19, 1, 5, 8), 'nor another script');
  ok := MapNotes.SetNote(18, 1, 6, 8, 'next door');
  ok := MapNotes.SetNote(18, 1, 5, 8, 'the tavern: a fight');
  TestKit.CheckEqualsS('the tavern: a fight', MapNotes.Note(18, 1, 5, 8), 'a note is changed in place');
  ok := MapNotes.SetNote(18, 1, 5, 8, '');
  TestKit.CheckEqualsS('', MapNotes.Note(18, 1, 5, 8), 'an empty note removes it');
  TestKit.CheckEqualsS('next door', MapNotes.Note(18, 1, 6, 8), 'leaving the others');
  MapNotes.WriteSlot('TMAPNOTE.NTS');
  MapNotes.Clear;
  TestKit.CheckEqualsS('', MapNotes.Note(18, 1, 6, 8), 'cleared, there are none');
  MapNotes.ReadSlot('TMAPNOTE.NTS');
  TestKit.CheckEqualsS('next door', MapNotes.Note(18, 1, 6, 8), 'read back from its file');
  MapNotes.ReadSlot('NOSUCH.NTS');
  TestKit.CheckEqualsS('', MapNotes.Note(18, 1, 6, 8), 'a missing file leaves none');
  ok := True;
  for i := 1 to MapNotes.MAX_NOTES do
    ok := ok and MapNotes.SetNote(0, 0, i mod 16, i div 16, 'x');
  TestKit.Check(ok, 'MAX_NOTES notes fit');
  TestKit.Check(not MapNotes.SetNote(1, 0, 0, 0, 'one more'), 'one more does not');
  TestKit.Done;
end.

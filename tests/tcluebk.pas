{ Tests for ClueBook (#856): the Clue Book's keys on New Phlan's squares, a key printed at several places on each of
  them, and the whole table well formed: every entry's squares on the 16x16 map, its text short enough to show whole,
  and no square with two keys. }
{$I COMPILER.INC}
program TClueBk;

uses ClueBook, TestKit;

var
  map: Integer;
  i: Byte;
  k: Byte;
  e: string;
  x: ShortInt;
  y: ShortInt;
  ok: Boolean;
  fits: Boolean;
  single: Boolean;
  keys: Integer;
  squares: Integer;
  used: array[0..15] of Word;

begin
  TestKit.Start('TCLUEBK');
  TestKit.CheckEqualsS('1. Boat', ClueBook.Note(0, 15, 1), 'New Phlan''s boat');
  TestKit.CheckEqualsS('2. Passenger Dock', ClueBook.Note(0, 11, 1), 'the passenger dock');
  TestKit.CheckEqualsS('3. Temple of Tyr', ClueBook.Note(0, 10, 4), 'the Temple of Tyr');
  TestKit.CheckEqualsS('3. Temple of Tyr', ClueBook.Note(0, 9, 6), 'printed twice, on both squares');
  TestKit.CheckEqualsS('24. Jeweler', ClueBook.Note(0, 8, 10), 'the jeweler');
  TestKit.CheckEqualsS('', ClueBook.Note(0, 0, 15), 'a square with no key');
  TestKit.Check(ClueBook.Marked(0, 15, 1), 'a keyed square is marked');
  TestKit.Check(not ClueBook.Marked(0, 0, 15), 'one without is not');
  TestKit.Check(not ClueBook.Marked(0, -1, 3), 'nor one off the map');
  TestKit.Check(ClueBook.Marked(0, 8, 10) and not ClueBook.Marked(255, 8, 10), 'marks follow the map asked for');
  TestKit.Check(ClueBook.EntrySquare('3,4 12,15:x', 2, x, y) and (x = 12) and (y = 15), 'an entry''s second square');
  TestKit.Check(not ClueBook.EntrySquare('3,4 12,15:x', 3, x, y), 'and no third');
  TestKit.Check(not ClueBook.EntrySquare('3,16:x', 1, x, y), 'a square off the map is malformed');
  TestKit.CheckEqualsS('x', ClueBook.EntryText('3,4 12,15:x'), 'an entry''s text');
  ok := True;
  fits := True;
  single := True;
  keys := 0;
  squares := 0;
  for map := 0 to 255 do begin
    FillChar(used, SizeOf(used), 0);
    i := 1;
    e := ClueBook.Entry(map, i);
    while e <> '' do begin
      Inc(keys);
      if (Pos(':', e) < 4) or (Length(e) - Pos(':', e) > ClueBook.CLUE_LEN) or
         (Length(e) - Pos(':', e) < 1) then
        fits := False;
      if not ClueBook.EntrySquare(e, 1, x, y) then
        ok := False;
      k := 1;
      while ClueBook.EntrySquare(e, k, x, y) do begin
        Inc(squares);
        if used[y] and (1 shl x) <> 0 then
          single := False;
        used[y] := used[y] or (1 shl x);
        Inc(k);
      end;
      { the squares run up to the ':' }
      if Copy(e, 1, Pos(':', e) - 1) = '' then
        ok := False;
      Inc(i);
      e := ClueBook.Entry(map, i);
    end;
  end;
  TestKit.Check(ok, 'every key has a square');
  TestKit.Check(fits, 'every key''s text shows whole');
  TestKit.Check(single, 'no square has two keys');
  TestKit.Check(keys >= 24, 'the table has the keys');
  TestKit.Check(squares >= keys, 'on their squares');
  TestKit.Done;
end.

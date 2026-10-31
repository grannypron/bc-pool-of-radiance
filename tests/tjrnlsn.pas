{ Tests for JrnlSeen (#1090): the Journal items the party has found, read from the lines the scripts print, the list
  the Journal setting makes of them, the Area view a found map allows, and the marks through savgam<x>.jnl. }
{$I COMPILER.INC}
program TJrnlSn;

uses GameVars, FileUtil, C_GBVM, C_JRNL, JrnlSeen, TestKit;

{ The Journal item of journal entry n. }
function Entry(n: Integer): Integer;
begin
  Entry := C_JRNL.LAST_PROCLAMATION + n;
end;

{ The Journal item of tavern tale n. }
function Tale(n: Integer): Integer;
begin
  Tale := C_JRNL.LAST_ENTRY + n;
end;

{ How many items are found. }
function FoundCount: Integer;
var
  i: Integer;
  c: Integer;
begin
  c := 0;
  for i := 1 to C_JRNL.JOURNAL_COUNT do
    if JrnlSeen.Found(i) then
      Inc(c);
  FoundCount := c;
end;

{ How many items the Journal lists. }
function ListedCount: Integer;
var
  i: Integer;
  c: Integer;
begin
  c := 0;
  for i := 1 to C_JRNL.JOURNAL_COUNT do
    if JrnlSeen.Listed(i) then
      Inc(c);
  ListedCount := c;
end;

{ Write the marks as file name in folder dir, a save of their own: True when they are in place. }
function WriteJnl(dir: FileUtil.TPathName; name: FileUtil.TSetName): Boolean;
var
  s: FileUtil.TFileSet;
begin
  FileUtil.NewSet(s, dir);
  WriteJnl := JrnlSeen.WriteSlot(s, name) and FileUtil.CommitSet(s);
end;

{ Put the party in the area of script and map, whose script turns the Area view off when off is set. }
procedure InArea(script, map: Byte; off: Boolean);
begin
  GameVars.eclScriptId := script;
  GameVars.zone0^.mapId.lo := map;
  GameVars.zone0^.noAutomap := Ord(off);
end;

begin
  TestKit.Start('TJRNLSN');
  GetMem(GameVars.zone0, SizeOf(GameVars.zone0^));
  FillChar(GameVars.zone0^, SizeOf(GameVars.zone0^), 0);
  GameVars.journalFoundOn := 1;
  JrnlSeen.Clear;
  TestKit.CheckEqualsL(0, FoundCount, 'a new game has found nothing');
  TestKit.CheckEqualsL(0, ListedCount, 'and its Journal lists nothing');

  { the scripts' lines }
  JrnlSeen.Scan('YOU FIND A PAGE FROM A DIARY AND PLACE IT IN YOUR JOURNAL UNDER ENTRY 11.');
  TestKit.Check(JrnlSeen.Found(Entry(11)), 'UNDER ENTRY 11. marks entry 11');
  TestKit.CheckEqualsL(1, FoundCount, 'and nothing else');
  JrnlSeen.Scan('INSIDE THE CABINET YOU FIND SOME FILES.  YOU STUFF THE PAPERS INTO YOUR JOURNAL UNDER ' +
                'ENTRIES 23 AND 14.');
  TestKit.Check(JrnlSeen.Found(Entry(23)) and JrnlSeen.Found(Entry(14)), 'ENTRIES 23 AND 14. marks both');
  JrnlSeen.Scan('A LETTER FROM THE BOSS, TELLING YARASH TO JOIN OR DIE. (ENTRY 33)');
  TestKit.Check(JrnlSeen.Found(Entry(33)), '(ENTRY 33) marks entry 33');
  JrnlSeen.Scan('YOU COPY THE PAPERS INTO YOUR JOURNAL UNDER JOURNAL ENTRY 48.');
  TestKit.Check(JrnlSeen.Found(Entry(48)), 'JOURNAL ENTRY 48. marks entry 48');
  JrnlSeen.Scan('YOU FIND A PIECE OF PAPER ON THE FLOOR IN THE ROOM.  YOU PLACE IT IN YOUR JOURNAL UNDER ENTRY 53');
  TestKit.Check(JrnlSeen.Found(Entry(53)), 'a number at the end of the line');
  TestKit.CheckEqualsL(6, FoundCount, 'six entries so far');

  { a number left to the next line: New Phlan's tavern and the Kobold Caves' note }
  JrnlSeen.Scan('YOU OVERHEAR TAVERN TALE ');
  TestKit.CheckEqualsL(6, FoundCount, 'TAVERN TALE alone marks nothing yet');
  JrnlSeen.Scan('7');
  TestKit.Check(JrnlSeen.Found(Tale(7)), 'the next line''s 7 marks tale 7');
  TestKit.Check(not JrnlSeen.Found(Entry(7)), 'not entry 7');
  JrnlSeen.Scan(' YOU RECORD IT IN YOUR JOURNAL UNDER ENTRY ');
  JrnlSeen.Scan('42.');
  TestKit.Check(JrnlSeen.Found(Entry(42)), 'ENTRY then 42. marks entry 42');
  JrnlSeen.Scan('YOU OVERHEAR TAVERN TALE ');
  JrnlSeen.Scan('THE BARKEEP LAUGHS.');
  JrnlSeen.Scan('5');
  TestKit.Check(not JrnlSeen.Found(Tale(5)), 'a pending number is for the very next line only');
  JrnlSeen.Scan('YOU OVERHEAR TAVERN TALE ');
  JrnlSeen.Scan('23');
  TestKit.Check(JrnlSeen.Found(Tale(23)), 'tale 23, the last');
  TestKit.CheckEqualsL(9, FoundCount, 'nine items so far');

  { lines that name no entry }
  JrnlSeen.Scan('AT YOUR ENTRY, THE COUNCIL CLERK BEGINS LOOKING THROUGH A STACK OF PAPERS.');
  JrnlSeen.Scan('YOU ARE JUST NORTH OF THE ENTRY TO THE OLD ROPE GUILD.');
  JrnlSeen.Scan('YOU FIND A NOTEBOOK. A TYPICAL ENTRY READS, ''SUBJECT 213: PROGRESSING WELL''');
  JrnlSeen.Scan('WHEN YOU GIVE IT WATER, IT CRAWLS OUT AND TELLS YOU ITS TALE.');
  JrnlSeen.Scan('17');
  JrnlSeen.Scan('THE SINGLE ENTRANCE IS LOCKED AND STRONGLY BUILT. REENTRY 3');
  JrnlSeen.Scan('UNDER ENTRY 59. TAVERN TALE 24. ENTRY 0.');
  TestKit.CheckEqualsL(9, FoundCount, 'ENTRY, ENTRY TO, ENTRANCE, ITS TALE and numbers past the lists mark nothing');

  { City Hall's proclamations line: every one posted by now, here with two major rewards paid }
  GameVars.zone0^.words[C_GBVM.COUNCIL_REWARDS] := 2;
  JrnlSeen.Scan('PROCLAMATIONS ARE POSTED ON THE WALLS, IN YOUR JOURNAL YOU NOTE ');
  TestKit.Check(JrnlSeen.Found(1) and JrnlSeen.Found(2) and JrnlSeen.Found(3) and JrnlSeen.Found(4) and
                JrnlSeen.Found(5) and JrnlSeen.Found(6) and JrnlSeen.Found(9),
                'LIX, LXIV, LXXVIII, CI, CIX, CX and CXXVI are noted');
  TestKit.Check(not JrnlSeen.Found(7) and not JrnlSeen.Found(11) and not JrnlSeen.Found(8),
                'CXIV, CXXXIV and CXX are not');
  TestKit.CheckEqualsL(16, FoundCount, 'seven proclamations');

  { the list the Journal setting makes }
  TestKit.CheckEqualsL(16, ListedCount, 'Found: the Journal lists what was found');
  GameVars.journalFoundOn := 0;
  TestKit.CheckEqualsL(C_JRNL.JOURNAL_COUNT, ListedCount, 'All: every item');
  TestKit.Check(not JrnlSeen.Listed(0) and not JrnlSeen.Listed(C_JRNL.JOURNAL_COUNT + 1), 'nothing outside the list');
  GameVars.journalFoundOn := 1;

  { the Area view: where the script turns it off, the area's map opens it }
  InArea(18, 18, False);
  TestKit.Check(JrnlSeen.AreaMapAllowed, 'an area the script leaves the view on in');
  InArea(4, 4, True);
  TestKit.Check(not JrnlSeen.AreaMapAllowed, 'Valjevo Castle NE without its map');
  JrnlSeen.Scan('IT IS A MAP OF A COMPLEX MAZE WITH THE WORDS ''NE CASTLE'' UNDER IT.  YOU TAKE THE MAP AND PUT IT ' +
                'IN YOUR JOURNAL UNDER JOURNAL ENTRY 29.');
  TestKit.Check(JrnlSeen.AreaMapAllowed, 'with entry 29');
  InArea(3, 5, True);
  JrnlSeen.Mark(Entry(41));
  TestKit.Check(not JrnlSeen.AreaMapAllowed, 'the NW castle''s map is not the SE block''s');
  InArea(3, 3, True);
  TestKit.Check(JrnlSeen.AreaMapAllowed, 'but is the NW block''s');
  InArea(13, 13, True);
  TestKit.Check(JrnlSeen.AreaMapAllowed, 'the Kobold Caves with the sketch, entry 42');
  InArea(2, 2, True);
  TestKit.Check(not JrnlSeen.AreaMapAllowed, 'the Textile House without the kobolds'' map');
  JrnlSeen.Scan('THEY DESCRIBE THE SURROUNDING AREA TO YOU. YOU LISTEN CAREFULLY, QUESTION THEM AND FROM THIS, ' +
                'SKETCH A MAP INTO YOUR JOURNAL CALLING IT ENTRY 10.');
  TestKit.Check(JrnlSeen.AreaMapAllowed, 'and with entry 10');
  InArea(20, 20, True);
  TestKit.Check(not JrnlSeen.AreaMapAllowed, 'the Slums: no map opens them');

  { savgam<x>.jnl }
  TestKit.Check(WriteJnl('', 'TJRNLSN.JNL'), 'the marks are written');
  TestKit.Check(not WriteJnl('NODIR\', 'TJRNLSN.JNL'), 'a write into a missing folder says it failed');
  JrnlSeen.Clear;
  TestKit.CheckEqualsL(0, FoundCount, 'cleared, nothing is found');
  JrnlSeen.ReadSlot('TJRNLSN.JNL');
  TestKit.CheckEqualsL(19, FoundCount, 'read back from its file');
  TestKit.Check(JrnlSeen.Found(Tale(7)) and JrnlSeen.Found(Entry(41)) and not JrnlSeen.Found(Entry(1)),
                'the same items');
  JrnlSeen.ReadSlot('NOSUCH.JNL');
  TestKit.CheckEqualsL(C_JRNL.JOURNAL_COUNT, FoundCount, 'a save without a .jnl file has found everything');
  InArea(4, 4, True);
  TestKit.Check(JrnlSeen.AreaMapAllowed, 'its maps too');
  TestKit.Done;
end.

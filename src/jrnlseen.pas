{ What the party has found of the Adventurer's Journal (#1090): a mark for each of the Journal's items (JrnlList's
  list: the proclamations, the journal entries and the tavern tales), kept beside each save as savgam<x>.jnl.

  SSI's journal was a printed book, so the game kept nothing; its scripts only tell the player which entry to read.
  Scan reads that from each line the scripts print (EclVm.EclPrint): "UNDER ENTRY 11.", "ENTRIES 23 AND 14.",
  "(ENTRY 33)"; a line ending in "ENTRY " or "TAVERN TALE " (Kobold Caves' note, New Phlan's tavern) leaves the number
  to the next line; City Hall's line on the proclamations posted on its walls notes every proclamation posted by then
  (JrnlQst.IsPosted). Reading the text, not the scripts' addresses, follows the scripts DataPat has changed too.

  Twenty-two entries are named by no script: a scan of every string in the eight ECL archives, DataPat's changes
  applied, finds 36 entries named and these never: 1, 2, 4, 5, 6, 9, 12, 13, 15, 17, 18, 22, 24, 32, 34, 36, 39, 44,
  45, 52, 54 and 58, which the game never hands out (by their text, the book's decoys). The setting Journal: All
  (GameVars.journalFoundOn clear) lists them with the rest.

  A map the party has found opens the Area view (and the coordinates) in the area it maps, where the script turns it
  off (C_GBVM.NO_AUTOMAP): AreaMapAllowed. }
{$I COMPILER.INC}
unit JrnlSeen;

interface

uses FileUtil;

{ Forget every item: a new game. }
procedure Clear;

{ Mark every item found: a save from before the marks were kept, which has no .jnl file. }
procedure FindAll;

{ Mark Journal item index (1 to C_JRNL.JOURNAL_COUNT) found; one outside the list is ignored. }
procedure Mark(index: Integer);

{ True when Journal item index has been found. }
function Found(index: Integer): Boolean;

{ True when the Journal lists item index: found, or every item while the Journal setting is All. }
function Listed(index: Integer): Boolean;

{ Mark what the printed line text names (see above). A number the line before left pending is taken from the start of
  this one. }
procedure Scan(text: string);

{ True when the Area view and the coordinates are allowed in the current area (GameVars.eclScriptId and the GBVM
  mapId): the script has not turned them off, or the party has found the Journal's map of the area. }
function AreaMapAllowed: Boolean;

{ Write the marks as file name of save s (FileUtil.WriteToSet): True when they were written. }
function WriteSlot(var s: FileUtil.TFileSet; name: FileUtil.TSetName): Boolean;

{ Read the marks from file fn; a missing, short or foreign file marks every item found (FindAll), so a game saved
  before them keeps its whole Journal. }
procedure ReadSlot(fn: String);

implementation

uses C_JRNL, GameVars, JrnlList, JrnlQst;

type
  { a map the Journal holds: its entry, and the script and GBVM map of the area it maps }
  TAreaMap = record
    entry: Byte;
    script: Byte;
    map: Byte;
  end;
  { the file: a bit an item, bit index mod 8 of found[index div 8], in bytes rather than a set so the DOS and native
    games write the same file }
  TJrnlFile = record
    sig: string[4];
    version: Byte;
    found: array[0..C_JRNL.JOURNAL_COUNT div 8] of Byte;
  end;

const
  SIG = 'JRNL';
  VERSION = 1;
  { what the line before left for this one's number }
  PENDING_NONE = 0;
  PENDING_ENTRY = 1;
  PENDING_TALE = 2;
  { The Journal's maps of the areas whose script turns the Area view off. The book's other maps are of the wilderness
    (28), of Phlan and the lands around it (37), or false (4, 15, 22, 58). }
  MAP_COUNT = 5;
  MAPS: array[1..MAP_COUNT] of TAreaMap = (
    { the Mendor's Library kobolds' map of the Textile House, where the script turns the view off once the party has
      fled the hobgoblins }
    (entry: 10; script: 2; map: 2),
    { Tyrmor's journal: the maze of Sorcerer's Island's pyramid }
    (entry: 26; script: 22; map: 22),
    { the maps found in Kovel Mansion: Valjevo Castle's north-east and north-west blocks }
    (entry: 29; script: 4; map: 4),
    (entry: 41; script: 3; map: 3),
    { the kobold's sketch of the Kobold Caves and the beast's lair }
    (entry: 42; script: 13; map: 13));

var
  rec: TJrnlFile;
  { what the line printed last left for the next one's number }
  pending: Byte;

procedure Clear;
begin
  FillChar(rec, SizeOf(rec), 0);
  rec.sig := SIG;
  rec.version := VERSION;
  pending := PENDING_NONE;
end;

procedure FindAll;
begin
  JrnlSeen.Clear;
  FillChar(rec.found, SizeOf(rec.found), $FF);
end;

procedure Mark(index: Integer);
begin
  if (index >= 1) and (index <= C_JRNL.JOURNAL_COUNT) then
    rec.found[index div 8] := rec.found[index div 8] or (1 shl (index mod 8));
end;

function Found(index: Integer): Boolean;
begin
  Found := (index >= 1) and (index <= C_JRNL.JOURNAL_COUNT) and
           (rec.found[index div 8] and (1 shl (index mod 8)) <> 0);
end;

function Listed(index: Integer): Boolean;
begin
  Listed := (index >= 1) and (index <= C_JRNL.JOURNAL_COUNT) and
            ((GameVars.journalFoundOn = 0) or JrnlSeen.Found(index));
end;

{ Mark journal entry n, or with tale tavern tale n; a number past either list is ignored. }
procedure MarkNumber(n: Integer; tale: Boolean);
begin
  if tale then begin
    if (n >= 1) and (n <= C_JRNL.JOURNAL_COUNT - C_JRNL.LAST_ENTRY) then
      JrnlSeen.Mark(C_JRNL.LAST_ENTRY + n);
  end else if (n >= 1) and (n <= C_JRNL.LAST_ENTRY - C_JRNL.LAST_PROCLAMATION) then
    JrnlSeen.Mark(C_JRNL.LAST_PROCLAMATION + n);
end;

{ Every proclamation posted outside City Hall by now (JrnlQst.IsPosted). }
procedure MarkPosted;
var
  i: Integer;
begin
  for i := 1 to C_JRNL.LAST_PROCLAMATION do
    if JrnlQst.IsPosted(JrnlList.EntryNumber(i)) then
      JrnlSeen.Mark(i);
end;

{ True when text at p starts with word, not inside a longer word: the character before it is not a letter. }
function WordAt(var text: string; p: Integer; word: string): Boolean;
begin
  WordAt := (Copy(text, p, Length(word)) = word) and ((p = 1) or not (UpCase(text[p - 1]) in ['A'..'Z']));
end;

{ The number of digits at p (p moved past them) into n; False, with p as it was, when no digit is there. }
function ReadNumber(var text: string; var p: Integer; var n: Integer): Boolean;
begin
  n := 0;
  ReadNumber := (p <= Length(text)) and (text[p] in ['0'..'9']);
  while (p <= Length(text)) and (text[p] in ['0'..'9']) do begin
    if n < 1000 then
      n := n * 10 + Ord(text[p]) - Ord('0');
    Inc(p);
  end;
end;

{ After a word at p of length len and its space: mark the number there (and for ENTRIES the ones joined to it by AND or
  a comma) as a tale or an entry, or leave the kind pending when the line ends there. }
procedure TakeNumbers(var text: string; p, len: Integer; tale, many: Boolean);
var
  n: Integer;
  more: Boolean;
begin
  Inc(p, len);
  if (p > Length(text)) or (text[p] <> ' ') then Exit;
  Inc(p);
  if p > Length(text) then begin
    if tale then
      pending := PENDING_TALE
    else
      pending := PENDING_ENTRY;
    Exit;
  end;
  repeat
    more := False;
    if JrnlSeen.ReadNumber(text, p, n) then begin
      JrnlSeen.MarkNumber(n, tale);
      if many then begin
        if Copy(text, p, 5) = ' AND ' then begin
          Inc(p, 5);
          more := True;
        end else if Copy(text, p, 2) = ', ' then begin
          Inc(p, 2);
          if Copy(text, p, 4) = 'AND ' then
            Inc(p, 4);
          more := True;
        end;
      end;
    end;
  until not more;
end;

procedure Scan(text: string);
var
  p: Integer;
  n: Integer;
begin
  for p := 1 to Length(text) do
    text[p] := UpCase(text[p]);
  { the number the line before asked for }
  if pending <> PENDING_NONE then begin
    p := 1;
    while (p <= Length(text)) and (text[p] = ' ') do
      Inc(p);
    if JrnlSeen.ReadNumber(text, p, n) then
      JrnlSeen.MarkNumber(n, pending = PENDING_TALE);
    pending := PENDING_NONE;
  end;
  for p := 1 to Length(text) do
    if JrnlSeen.WordAt(text, p, 'ENTRIES') then
      JrnlSeen.TakeNumbers(text, p, 7, False, True)
    else if JrnlSeen.WordAt(text, p, 'ENTRY') then
      JrnlSeen.TakeNumbers(text, p, 5, False, False)
    else if JrnlSeen.WordAt(text, p, 'TAVERN TALE') then
      JrnlSeen.TakeNumbers(text, p, 11, True, False);
  if Pos('PROCLAMATIONS ARE POSTED', text) > 0 then
    JrnlSeen.MarkPosted;
end;

function AreaMapAllowed: Boolean;
var
  i: Byte;
  allowed: Boolean;
begin
  allowed := GameVars.zone0^.noAutomap = 0;
  for i := 1 to MAP_COUNT do
    if (MAPS[i].script = GameVars.eclScriptId) and (MAPS[i].map = GameVars.zone0^.mapId.lo) and
       JrnlSeen.Found(C_JRNL.LAST_PROCLAMATION + MAPS[i].entry) then
      allowed := True;
  AreaMapAllowed := allowed;
end;

function WriteSlot(var s: FileUtil.TFileSet; name: FileUtil.TSetName): Boolean;
begin
  WriteSlot := FileUtil.WriteToSet(s, name, rec, SizeOf(rec));
end;

procedure ReadSlot(fn: String);
begin
  pending := PENDING_NONE;
  if not FileUtil.ReadRecord(fn, rec, SizeOf(rec)) or (rec.sig <> SIG) or (rec.version <> VERSION) then
    JrnlSeen.FindAll;
end;

begin
  JrnlSeen.Clear;
end.

{ Stores notes attached to map squares for the Companion Tools. An area is
  identified by the same script/map pair used by Explored. Notes are saved
  beside each game as savgam<x>.nts. This unit remains resident so a new game
  can clear all notes before loading a save. }
{$I COMPILER.INC}
unit MapNotes;

interface

uses Types, FileUtil;

const
  MAX_NOTES = 128;
  NOTE_LEN = 30;

type
  TNoteText = string[NOTE_LEN];

{ Clears every note for a new game or a save without a .nts file. }
procedure Clear;

{ Returns the note at a square, or an empty string if none exists or the square
  is outside the map. }
function Note(script, map: Byte; x, y: ShortInt): TNoteText;

{ Sets a square's note; an empty string removes it. Returns False without
  changing anything when the square is invalid or the note table is full
  (#918). }
function SetNote(script, map: Byte; x, y: ShortInt; text: TNoteText): Boolean;

{ Remove the note on square (x, y) of the area of script and map, if it has one. }
procedure ClearNote(script, map: Byte; x, y: ShortInt);

{ Writes the notes to a save's file set and reports whether it succeeded. }
function WriteSlot(var s: FileUtil.TFileSet; name: FileUtil.TSetName): Boolean;

{ Reads notes from fn. Missing, truncated, or foreign files leave the list
  empty. Invalid individual records are discarded while valid ones are kept
  (#917, #918). }
procedure ReadSlot(fn: String);

implementation

const
  SIG = 'NOTE';
  VERSION = 1;

type
  TNoteRec = record
    script: Byte;
    map: Byte;
    x: Byte;
    y: Byte;
    text: TNoteText;
  end;
  TNotesFile = record
    sig: string[4];
    version: Byte;
    count: Byte;
    notes: array[1..MAX_NOTES] of TNoteRec;
  end;

var
  rec: TNotesFile;

procedure Clear;
begin
  FillChar(rec, SizeOf(rec), 0);
  rec.sig := SIG;
  rec.version := VERSION;
end;

{ The index of the note on square (nx, ny) of the area of script s and map m, or 0 when it has none. }
function Find(s, m: Byte; nx, ny: ShortInt): Byte;
var
  i: Byte;
begin
  Find := 0;
  for i := 1 to rec.count do
    with rec.notes[i] do
      if (script = s) and (map = m) and (x = nx) and (y = ny) then begin
        Find := i;
        Exit;
      end;
end;

function Note(script, map: Byte; x, y: ShortInt): TNoteText;
var
  i: Byte;
begin
  Note := '';
  if not Types.OnMap(x, y) then Exit;
  i := MapNotes.Find(script, map, x, y);
  if i <> 0 then
    Note := rec.notes[i].text;
end;

function SetNote(script, map: Byte; x, y: ShortInt; text: TNoteText): Boolean;
var
  i: Byte;
begin
  SetNote := Types.OnMap(x, y);
  if not Types.OnMap(x, y) then Exit;
  if text = '' then begin
    MapNotes.ClearNote(script, map, x, y);
    Exit;
  end;
  i := MapNotes.Find(script, map, x, y);
  if i = 0 then begin
    if rec.count >= MAX_NOTES then begin
      SetNote := False;
      Exit;
    end;
    Inc(rec.count);
    i := rec.count;
    rec.notes[i].script := script;
    rec.notes[i].map := map;
    rec.notes[i].x := x;
    rec.notes[i].y := y;
  end;
  rec.notes[i].text := text;
end;

procedure ClearNote(script, map: Byte; x, y: ShortInt);
var
  i: Byte;
begin
  if not Types.OnMap(x, y) then Exit;
  { the last note takes the removed one's place }
  i := MapNotes.Find(script, map, x, y);
  if i <> 0 then begin
    rec.notes[i] := rec.notes[rec.count];
    Dec(rec.count);
  end;
end;

function WriteSlot(var s: FileUtil.TFileSet; name: FileUtil.TSetName): Boolean;
begin
  WriteSlot := FileUtil.WriteToSet(s, name, rec, SizeOf(rec));
end;

procedure ReadSlot(fn: String);
var
  i: Byte;
  kept: Byte;
begin
  if not FileUtil.ReadRecord(fn, rec, SizeOf(rec)) or (rec.sig <> SIG) or (rec.version <> VERSION) or
     (rec.count > MAX_NOTES) then
    MapNotes.Clear
  else begin
    { keep the notes on the map with a whole text, in their order }
    kept := 0;
    for i := 1 to rec.count do
      if Types.OnMap(rec.notes[i].x, rec.notes[i].y) and (Length(rec.notes[i].text) <= NOTE_LEN) then begin
        Inc(kept);
        rec.notes[kept] := rec.notes[i];
      end;
    rec.count := kept;
  end;
end;

begin
  MapNotes.Clear;
end.

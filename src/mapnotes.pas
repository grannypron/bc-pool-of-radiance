{ The player's notes on the map's squares (phase 8 of docs/refactor-plan.md, the Companion Tools): up to MAX_NOTES
  notes of up to NOTE_LEN characters, each on a square of a 3D area keyed as Explored keys areas (the script, and the
  map). Written and read from the Companion Tools' Notes; saved beside each save as savgam<x>.nts. Resident, as
  Explored is, so its initialization clears the notes before any save is read. }
{$I COMPILER.INC}
unit MapNotes;

interface

uses FileUtil;

const
  MAX_NOTES = 128;
  NOTE_LEN = 30;

type
  TNoteText = string[NOTE_LEN];

{ Forget every note: a new game, or a save without a .nts file. }
procedure Clear;

{ The note on square (x, y) of the area of script and map; '' for none. }
function Note(script, map: Byte; x, y: ShortInt): TNoteText;

{ Set the note on square (x, y) of the area of script and map; '' removes it (ClearNote). False when the notes are
  full. }
function SetNote(script, map: Byte; x, y: ShortInt; text: TNoteText): Boolean;

{ Remove the note on square (x, y) of the area of script and map, if it has one. }
procedure ClearNote(script, map: Byte; x, y: ShortInt);

{ Write the notes as file name of save s (FileUtil.WriteToSet): True when they were written. }
function WriteSlot(var s: FileUtil.TFileSet; name: FileUtil.TSetName): Boolean;

{ Read the notes from file fn; a missing, short or foreign file leaves none. }
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
  i := MapNotes.Find(script, map, x, y);
  if i <> 0 then
    Note := rec.notes[i].text;
end;

function SetNote(script, map: Byte; x, y: ShortInt; text: TNoteText): Boolean;
var
  i: Byte;
begin
  SetNote := True;
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
begin
  if not FileUtil.ReadRecord(fn, rec, SizeOf(rec)) or (rec.sig <> SIG) or (rec.version <> VERSION) or
     (rec.count > MAX_NOTES) then
    MapNotes.Clear;
end;

begin
  MapNotes.Clear;
end.

{ Where the party has been (phase 8 of docs/refactor-plan.md, the Companion Tools' map): a 16x16 bit map of the squares
  visited in each 3D area, keyed as AreaName keys areas (the script, and the map for the scripts that run two). The 3D
  view marks the party's square whenever it is drawn there, so moves, turns, arrivals and the scripts' teleports all
  count, whether or not the Companion Tools are on. Saved beside each save as savgam<x>.map. Resident, since every step
  marks a square. }
{$I COMPILER.INC}
unit Explored;

interface

uses FileUtil;

const
  { areas kept; PoR has about thirty 3D maps }
  MAX_AREAS = 64;

{ Forget every square: a new game, or a save without a .map file. }
procedure Clear;

{ Mark square (x, y) of the current area (GameVars.eclScriptId, the GBVM mapId) visited. Squares off the 16x16 map, and
  areas past MAX_AREAS, are not kept. }
procedure Mark(x, y: ShortInt);

{ True when square (x, y) of the area of script and map has been visited. }
function Visited(script, map: Byte; x, y: ShortInt): Boolean;

{ Write the visited squares as file name of save s (FileUtil.WriteToSet): True when they were written. }
function WriteSlot(var s: FileUtil.TFileSet; name: FileUtil.TSetName): Boolean;

{ Read the visited squares from file fn; a missing, short or foreign file leaves none. }
procedure ReadSlot(fn: String);

implementation

uses GameVars;

const
  SIG = 'EXPL';
  VERSION = 1;

type
  TArea = record
    script: Byte;
    map: Byte;
    { a bit a square: bit x of cells[y] }
    cells: array[0..15] of Word;
  end;
  TExploredFile = record
    sig: string[4];
    version: Byte;
    count: Byte;
    areas: array[1..MAX_AREAS] of TArea;
  end;

var
  rec: TExploredFile;

procedure Clear;
begin
  FillChar(rec, SizeOf(rec), 0);
  rec.sig := SIG;
  rec.version := VERSION;
end;

{ The index of the area of script and map, or 0 when it has none. }
function Find(script, map: Byte): Byte;
var
  i: Byte;
begin
  Find := 0;
  for i := 1 to rec.count do
    if (rec.areas[i].script = script) and (rec.areas[i].map = map) then begin
      Find := i;
      Exit;
    end;
end;

procedure Mark(x, y: ShortInt);
var
  i: Byte;
  script: Byte;
  map: Byte;
begin
  if (x < 0) or (x > 15) or (y < 0) or (y > 15) then Exit;
  script := GameVars.eclScriptId;
  map := GameVars.zone0^.mapId.lo;
  i := Explored.Find(script, map);
  if i = 0 then begin
    if rec.count >= MAX_AREAS then Exit;
    Inc(rec.count);
    i := rec.count;
    rec.areas[i].script := script;
    rec.areas[i].map := map;
  end;
  rec.areas[i].cells[y] := rec.areas[i].cells[y] or (1 shl x);
end;

function Visited(script, map: Byte; x, y: ShortInt): Boolean;
var
  i: Byte;
begin
  Visited := False;
  if (x < 0) or (x > 15) or (y < 0) or (y > 15) then Exit;
  i := Explored.Find(script, map);
  if i <> 0 then
    Visited := rec.areas[i].cells[y] and (1 shl x) <> 0;
end;

function WriteSlot(var s: FileUtil.TFileSet; name: FileUtil.TSetName): Boolean;
begin
  WriteSlot := FileUtil.WriteToSet(s, name, rec, SizeOf(rec));
end;

procedure ReadSlot(fn: String);
begin
  if not FileUtil.ReadRecord(fn, rec, SizeOf(rec)) or (rec.sig <> SIG) or (rec.version <> VERSION) or
     (rec.count > MAX_AREAS) then
    Explored.Clear;
end;

begin
  Explored.Clear;
end.

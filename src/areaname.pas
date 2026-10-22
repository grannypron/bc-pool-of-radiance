{ The name of the area the party is in, as the Load/Save Game menu shows it beside a saved game: the Clue Book's name,
  shortened to fit 18 columns. }
{$O+,F+}
{$I COMPILER.INC}
unit AreaName;

interface

uses Types;

{ The name of the area of script scriptId on map mapId: the script a saved game reopens (GBVM previousScriptId's low
  byte, which GameLoop sets after every turn on the map) names it, and the map tells apart the two halves of the four
  scripts that run two. UNKNOWN AREA for a script the game does not have. }
function AreaFor(scriptId, mapId: Byte): Types.TStr40;

{ The current area's name: AreaFor the GBVM previousScriptId and mapId. }
function CurrentArea: Types.TStr40;

implementation

uses GameVars;

const
  { the last script id: ECL1..ECL8 hold scripts 0..29, all but 12 }
  LAST_SCRIPT = 29;
  { by script id; a script that runs two maps is named here by the map it starts on, and AreaFor names the other }
  names: array[0..LAST_SCRIPT] of string[18] = (
    'NEW PHLAN', 'BUCCANEER''S BASE', 'TEXTILE HOUSE', 'VALJEVO CASTLE', 'VALJEVO CASTLE NE', 'VALJEVO HEDGE MAZE',
    'VALJEVO CASTLE SW', 'VALJEVO TOWER', 'PHLAN CITY HALL', 'STOJANOW GATE', 'VALHINGEN GRAVES', 'TRAINING HALL',
    'UNKNOWN AREA', 'KOBOLD CAVES', 'KOVEL MANSION', 'MENDOR''S LIBRARY', 'LIZARD MAN KEEP', 'NOMAD CAMP',
    'PODAL PLAZA', 'SILVER DRAGON DEN', 'SLUMS', 'SOKAL KEEP', 'SORCERER''S ISLAND', 'YARASH''S PYRAMID',
    'WEALTHY AREA', 'WESTERN WILDERNESS', 'CENTRAL WILDERNESS', 'EASTERN WILDERNESS', 'ZHENTIL OUTPOST',
    'KUTO''S WELL');

function AreaFor(scriptId, mapId: Byte): Types.TStr40;
begin
  if scriptId > LAST_SCRIPT then
    AreaFor := 'UNKNOWN AREA'
  else begin
    AreaFor := names[scriptId];
    { Valjevo's outer blocks: script 3 runs the north-west (map 3) and south-east (map 5) }
    if (scriptId = 3) and (mapId = 3) then
      AreaFor := 'VALJEVO CASTLE NW';
    if (scriptId = 3) and (mapId = 5) then
      AreaFor := 'VALJEVO CASTLE SE';
    { the catacombs under the keep and the well }
    if (scriptId = 16) and (mapId = 30) then
      AreaFor := 'LIZARD CATACOMBS';
    if (scriptId = 29) and (mapId = 32) then
      AreaFor := 'KUTO''S CATACOMBS';
    { script 24 runs the wealthy area (map 31) and the Temple of Bane (map 24) }
    if (scriptId = 24) and (mapId = 24) then
      AreaFor := 'TEMPLE OF BANE';
  end;
end;

function CurrentArea: Types.TStr40;
begin
  CurrentArea := AreaName.AreaFor(Lo(GameVars.zone0^.previousScriptId), GameVars.zone0^.mapId.lo);
end;

end.

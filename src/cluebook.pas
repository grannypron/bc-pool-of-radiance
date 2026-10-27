{ Supplies the numbered Clue Book locations shown on the Companion Tools map
  (#856). Labels use the book's wording, shortened to fit. Repeated labels are
  attached to every matching square, and a number printed across a grid line is
  attached to both squares. These built-in labels are separate from the
  player's saved MapNotes.

  Coordinates come from the 1988 Clue Book maps and were checked against the
  game's GEO walls, events, and scripts. They use the game's 0-based grid, with
  x increasing right and y increasing down. Entries are keyed by GEO map rather
  than script because some printed maps span several game maps. }
{$O+,F+}
{$I COMPILER.INC}
unit ClueBook;

interface

uses Types;

const
  { as long as a player's note (MapNotes.NOTE_LEN), so the Map tool shows either on the same line }
  CLUE_LEN = 30;

type
  TClueText = string[CLUE_LEN];

{ The Clue Book's key on square (x, y) of GEO map map: its name, as 'Temple of Tyr'; '' for none. }
function Note(map: Byte; x, y: ShortInt): TClueText;

{ True when square (x, y) of GEO map map has a Clue Book key. The first call for a map reads its keys once. }
function Marked(map: Byte; x, y: ShortInt): Boolean;

{ Key i of GEO map map, from 1: its squares, each as x,y and a space between them, then ':' and its text. '' past the
  map's last key, and for a map the book has no keys for. For the tests. }
function Entry(map, i: Byte): string;

{ Square k of entry e, from 1, in x and y: False past its last square or for a malformed one. For the tests. }
function EntrySquare(e: string; k: Byte; var x, y: ShortInt): Boolean;

{ The text of entry e, after its ':'. }
function EntryText(e: string): TClueText;

implementation

const
  { no map's keys read yet }
  NO_MAP = $FF;
  { the map whose keys marks holds: a typed constant, so it starts as none }
  marksMap: Byte = NO_MAP;

var
  { marksMap's keyed squares: bit x of marks[y] }
  marks: array[0..Types.MAP_LAST] of Word;

function Entry(map, i: Byte): string;
begin
  Entry := '';
  case map of
    { New Phlan, the civilized area }
    0: case i of
         1: Entry := '15,1:Boat';
         2: Entry := '11,1:Passenger Dock';
         3: Entry := '10,4 9,6:Temple of Tyr';
         4: Entry := '10,5:Bishop Braccio''s Office';
         5: Entry := '8,1 8,2:Dueling & Hiring Hall';
         6: Entry := '5,0:Clerical Training';
         7: Entry := '7,0:Magic User Training';
         8: Entry := '8,0:Fighter Training';
         9: Entry := '9,0:Thieves Training';
         10: Entry := '1,1:Temple of Sune';
         11: Entry := '1,7:City Park';
         12: Entry := '4,3:Entrance To The City Hall';
         13: Entry := '5,5:Clerk of the City Council';
         14: Entry := '6,5:Junior Councilman''s Office';
         15: Entry := '6,6:Senior Councilman''s Office';
         16: Entry := '5,7 6,7 5,8 6,8:Head Councilman''s Office';
         17: Entry := '5,9 6,9 5,10 6,10:City Council Chambers';
         18: Entry := '1,13:Temple of Tempus';
         19: Entry := '1,14 4,12 4,13 6,12 6,13:Inns';
         20: Entry := '10,8 8,8 8,9 14,10 15,10 15,13:Taverns';
         21: Entry := '13,8 8,11 11,12 8,13 9,13:Arms & Armor Shop';
         22: Entry := '15,8 9,10 12,10 9,11 11,11:General Items Shop';
         23: Entry := '11,10 10,13:Silver Shop';
         24: Entry := '8,10:Jeweler';
       end;
    { The Buccaneers' Base; the book draws the west and east towers a row north of the game's, at 2,3 and 13,3 }
    1: case i of
         1: Entry := '7,0:Front Gate';
         2: Entry := '8,10 9,10 8,11 9,11:Merchant''s Camp Area';
         3: Entry := '7,11 7,12:Captain''s Guards';
         4: Entry := '7,13 8,13:Captains Quarters';
         5: Entry := '5,3 6,3 9,3 10,3 1,7 2,7 9,7 10,7 4,10 4,11 11,10 11,11:Buccaneer Barracks';
         6: Entry := '6,0 9,0 2,3 13,3 0,10 15,10 4,14 11,14:Guard Towers';
         7: Entry := '13,7:Animal Pen';
         8: Entry := '6,7 7,7 6,8 7,8:Slave Pen';
         9: Entry := '7,6:Slave Pen Guards';
         10: Entry := '2,11:Huckster';
       end;
    { Cadorna Textile House; the book prints 1a a square west, by a pillar it draws a column off }
    2: case i of
         1: Entry := '0,3:Dry Well';
         2: Entry := '6,11:Way in from the Dry Well';
         3: Entry := '6,8 6,9:Hobgoblin Barracks';
         4: Entry := '2,11 3,11 2,12 3,12:High Priestess Grishnak';
         5: Entry := '2,15:Skullcrusher chained up';
         6: Entry := '6,14:''Skullcrusher Was Here''';
         7: Entry := '5,15:Baby hobgoblins hiding';
         8: Entry := '10,9:A hobgoblin body';
         9: Entry := '11,14:Secret door to the east';
         10: Entry := '12,15:Ogre leader and his troops';
       end;
    { Valjevo Castle's north-west block, with the book's castle maze keys for its part of the maze }
    3: case i of
         1: Entry := '1,13 1,14:Barracks';
         2: Entry := '0,7 1,7:Barracks';
         3: Entry := '3,7 3,8:Main Gate';
         4: Entry := '0,5 1,5:Latrine';
         5: Entry := '0,2 1,2 0,3 1,3:Officers Quarters';
         6: Entry := '5,0 6,0 5,1 6,1:Guard Post';
         7: Entry := '8,0 9,0 8,1 9,1:Mess Hall';
         8: Entry := '12,11:Maze: Teleporters';
         9: Entry := '4,7 4,8:Maze: Main Gate';
         10: Entry := '4,5 5,5:Maze: Tower';
       end;
    { Valjevo Castle's north-east block, with its part of the maze }
    4: case i of
         1: Entry := '5,0 6,0 5,1 6,1:Guard Post';
         2: Entry := '8,0 9,0 8,1 9,1:Barracks';
         3: Entry := '14,2 15,2 14,3 15,3:Armory';
         4: Entry := '14,6 15,6:Kitchen';
         5: Entry := '14,9 15,9 14,10 15,10:Records Office';
         6: Entry := '14,13 15,13 14,14 15,14:Scribe''s Office';
         7: Entry := '6,10:Maze: Teleporters';
         8: Entry := '10,4 11,4 10,5 11,5:Maze: Tower';
       end;
    { Valjevo Castle's south-east block, with its part of the maze and of the inner tower's lower level }
    5: case i of
         1: Entry := '14,1:Snake House';
         2: Entry := '14,8 15,8:Barracks';
         3: Entry := '12,7 12,8:Main Gate';
         4: Entry := '14,10:Cell';
         5: Entry := '15,10:Well';
         6: Entry := '14,12 15,12 14,13 15,13:Giant''s Guard Post';
         7: Entry := '9,14 10,14 9,15 10,15:Old Building';
         8: Entry := '7,14 7,15:Barracks';
         9: Entry := '3,4:Maze: Teleporters';
         10: Entry := '11,7 11,8:Maze: Main Gate';
         11: Entry := '10,10 11,10:Maze: Giant Hideout';
         12: Entry := '1,1 2,1 1,2 2,2:Tower: False Tyranthraxus';
       end;
    { Valjevo Castle's south-west block, with its part of the maze }
    6: case i of
         1: Entry := '13,14 14,14:Laundry Room';
         2: Entry := '1,14 2,14 1,15 2,15:Smithy';
         3: Entry := '0,5 1,5 0,6 1,6:A Smokehouse';
         4: Entry := '0,1 1,1 0,2 1,2:A Bane Chapel';
         5: Entry := '9,5:Maze: Teleporters';
         6: Entry := '4,10 5,10 4,11 5,11:Maze: Giant Hideout';
       end;
    { Valjevo Castle's inner tower, its upper level (the book's drawing is this map's x 1-8, y 4-11) }
    7: case i of
         1: Entry := '5,4:Stairs to lower level';
         2: Entry := '8,5:Trap Door Room';
         3: Entry := '1,6 2,6 1,7 2,7:Waiting Room';
         4: Entry := '2,4 2,5:Genheeris'' Office';
         5: Entry := '3,9:Tyranthraxus'' Lair';
         6: Entry := '2,10:The Pool of Radiance';
       end;
    { Stojanow Gate }
    9: case i of
         1: Entry := '4,14 11,14:Merchant in Wagon';
         2: Entry := '7,10 8,10 7,11 8,11:Bugbear Patrol Area';
         3: Entry := '7,9 8,9:Southern Gate';
         4: Entry := '7,7 8,7 7,8 8,8:Northern Gate';
         5: Entry := '7,6 8,6:Ettin guards fight here';
         6: Entry := '4,8:West Tower';
         7: Entry := '11,8:East Tower';
       end;
    { Valhingen Graveyard; the keys are sentences, shortened }
    10: case i of
         1: Entry := '6,4:Skeletal Hands';
         2: Entry := '5,6:Skeletons guard mausoleum';
         3: Entry := '7,6:Giant skeleton helps guard';
         4: Entry := '5,9:Zombies guard this tower';
         5: Entry := '4,10:Spectre creating zombies';
         6: Entry := '1,12:Skeletons guard this tower';
         7: Entry := '1,13:Room filled with poison gas';
         8: Entry := '0,15:Spectre creating skeletons';
         9: Entry := '10,15:Zombies outside mausoleum';
         10: Entry := '9,15:Ju-ju zombie helps guard';
         11: Entry := '9,11:Mummies inhabit this crypt';
         12: Entry := '9,5:Wights guard this tower';
         13: Entry := '9,7:Spectre creating wights';
         14: Entry := '15,6:Wights guard mausoleum';
         15: Entry := '15,8:A wraith helps guard';
         16: Entry := '9,1:Spectres guard this crypt';
         17: Entry := '8,2:A gallant knight''s grave';
         18: Entry := '12,4:The vampire''s coffin';
         19: Entry := '14,0:The vampire is here';
         20: Entry := '8,7:An evil magic user';
       end;
    { The Kobold Caves; the keys are sentences, shortened }
    13: case i of
         1: Entry := '6,13:A hidden water trap';
         2: Entry := '6,11:A discarded map';
         3: Entry := '9,12:You meet a kobold here';
         4: Entry := '10,9:A net trap';
         5: Entry := '11,9:A Spike Trap';
         6: Entry := '12,9:A drunken kobold';
         7: Entry := '14,8 14,9:You may meet the wyvern';
         8: Entry := '14,6:The wyverns nest';
         9: Entry := '15,3:A crippled kobold';
         10: Entry := '1,2:Prison: Princess Fatima';
         11: Entry := '5,3:The throne room';
         12: Entry := '7,1 8,1:The king''s guard';
         13: Entry := '10,1:Fate of the kobold king';
         14: Entry := '14,0:An efreeti bottle';
         15: Entry := '13,1:Huge kobold treasure trove';
         16: Entry := '3,3:A clue';
       end;
    { Kovel Mansion; keys 3 on are sentences, shortened }
    14: case i of
         1: Entry := '3,4:First Ambush';
         2: Entry := '6,5:A Pair of Thieves';
         3: Entry := '9,8:The thieves split up';
         4: Entry := '13,5:Corner a single thief';
         5: Entry := '8,13:Thieves waiting in ambush';
         6: Entry := '14,9:Information collected';
         7: Entry := '11,14:Boss'' men beat old thief';
         8: Entry := '14,14:Some of the thieves'' loot';
         9: Entry := '5,14:Information collected';
         10: Entry := '7,6:A room with four caskets';
         11: Entry := '4,13:A room with a cabinet';
         12: Entry := '10,9:Pile of thieves'' treasure';
         13: Entry := '14,10:A clue';
       end;
    { Mendor's Library }
    15: case i of
         1: Entry := '11,4:History Section';
         2: Entry := '5,4:Rhetoric Section';
         3: Entry := '13,6:Philosophy Section';
         4: Entry := '3,6:Mathematics Section';
         5: Entry := '13,10:Storeroom';
         6: Entry := '11,12:Madman in Corner';
         7: Entry := '13,13:Master Scribe''s Chamber';
         8: Entry := '8,11:Librarian''s Chamber';
         9: Entry := '4,11:Garden';
       end;
    { Lizard Man Keep }
    16: case i of
         1: Entry := '10,4:Holes';
         2: Entry := '3,7:Holes';
         3: Entry := '5,12:Holes';
         4: Entry := '6,6:Holes';
         5: Entry := '7,9:Holes';
         6: Entry := '9,6:Holes';
         7: Entry := '9,8:Stairs';
         8: Entry := '4,3:Lizard Men & Giant Lizards';
         9: Entry := '4,6 4,7 2,9 2,10:Giant Lizards';
       end;
    { The Nomad Camp }
    17: case i of
         1: Entry := '10,1 3,8 9,14:Trip wire';
         2: Entry := '9,12:Your Hut';
         3: Entry := '0,9:The Forest';
       end;
    { Podal Plaza (the book spells it Podol) }
    18: case i of
         1: Entry := '14,8:Minor Temple of Bane';
         2: Entry := '3,9 4,9:The Pit';
         3: Entry := '0,14 1,14:Secret Temple of Il-Mater';
         4: Entry := '7,6 7,7 7,8:The Auction';
       end;
    { The Slums }
    20: case i of
         1: Entry := '12,0 12,1:Orcs';
         2: Entry := '9,0 10,0 9,1 10,1:Goblin Armsmaster';
         3: Entry := '12,9 12,10:Magic User';
         4: Entry := '5,2 6,2:Stable';
         5: Entry := '7,0 8,0 7,1 8,1:Kobolds';
         6: Entry := '0,0:Secret Treasure Room';
         7: Entry := '0,2 0,3:Hobgoblins';
         8: Entry := '3,5:Gypsy';
         9: Entry := '2,3 3,3:Orcs';
         10: Entry := '0,6 0,7:Monster Guards';
         11: Entry := '1,5:Monster Leaders';
         12: Entry := '3,10 3,11:Goblin Guards';
         13: Entry := '4,10 5,10:Hidden Loot';
         14: Entry := '6,11:Entrance to Old Rope Guild';
         15: Entry := '15,12:Ohlo''s Potion';
         16: Entry := '0,13 0,14:Trolls and Ogres';
       end;
    { Sokal Keep }
    21: case i of
         1: Entry := '6,13:Dead Elf';
         2: Entry := '7,11 8,11:Undead Patrol Area';
         3: Entry := '1,10:Scorpions';
         4: Entry := '2,8 3,8 2,9 3,9:Fungus';
         5: Entry := '14,7:Poisonous Frogs';
         6: Entry := '7,4 8,4:Hobgoblin and Orc Assault';
         7: Entry := '5,3:Haunts';
         8: Entry := '7,10 8,10:Ferran Martinez';
         9: Entry := '13,3 14,3:The Armory';
         10: Entry := '12,0 13,0 12,1 13,1:Secret Treasure Room';
       end;
    { Sorcerer's Island, the book's level 1: its two halves are this map's top (as printed) and bottom (8 rows down),
      with the corridor between them at x 15 }
    22: case i of
         1: Entry := '13,4:Dead body and partial map';
         2: Entry := '13,15:A crazy priest';
         3: Entry := '14,7:A0. Forward A1+, reverse B1';
         4: Entry := '15,7:A3-. From A2 in reverse';
         5: Entry := '14,8:B0. Teleporter to B1';
         6: Entry := '5,11:B1. From B0';
         7: Entry := '14,9:B2. Teleporter to B3';
         8: Entry := '0,0:B3. From B2';
         9: Entry := '6,1:B4. Teleporter to B5';
       end;
    { Yarash's Pyramid, the book's levels 2 and 3 of Sorcerer's Island (level 3 is this map's top left); the book's
      treasure rooms C2 and C3 are swapped against the dial's, so only C1 is here }
    23: case i of
         1: Entry := '14,10:Angered mutant lizards';
         2: Entry := '2,14:Lizard men in a cell';
         3: Entry := '4,15:A1+. From A0';
         4: Entry := '15,12:A2. Forward A3+, reverse A3-';
         5: Entry := '11,3:A3+. From A2';
         6: Entry := '12,3:A4. Forward A5+, reverse A5-';
         7: Entry := '14,12:A5-. From A4 in reverse';
         8: Entry := '0,12:B5. From B4';
         9: Entry := '15,8:B6. Teleporter to B7';
         10: Entry := '3,13:B7. From B6';
         11: Entry := '1,1:Password over the door';
         12: Entry := '2,1 3,1:The machinery';
         13: Entry := '5,5:Captured lizard men';
         14: Entry := '5,1:Yarash''s Office';
         15: Entry := '0,4:A5+. From A4';
         16: Entry := '0,2:A6. Forward A7+, reverse A7-';
         17: Entry := '0,0:A7+. From A6';
         18: Entry := '13,3:A7-. From A6 in reverse';
         19: Entry := '6,0:C0. Teleporter dial';
         20: Entry := '5,9:C1. Treasure room (Copper)';
       end;
    { The Temple of Bane, keyed on with the Wealthy Area's }
    24: case i of
         1: Entry := '2,7 2,8:Temple Entrance';
         2: Entry := '5,5 12,9 9,12:Hidden Treasures';
         3: Entry := '14,7 14,8:Altar';
       end;
    { The Outpost of Zhentil Keep }
    28: case i of
         1: Entry := '7,0 8,0:The Front Gate';
         2: Entry := '0,0 1,0 0,1 1,1 14,0 15,0 14,1 15,1 0,14 1,14 0,15 1,15 14,14 15,14 14,15 15,15 6,6 9,6:' +
           'Guard Towers';
         3: Entry := '6,9 7,9:Commandant''s Quarters';
         4: Entry := '5,0 6,0 5,1 6,1 9,0 10,0 9,1 10,1:The Party''s Quarters';
         5: Entry := '5,3 10,3 3,5 12,4 12,5 3,11 12,11 12,12 5,13 10,13:Barracks';
         6: Entry := '12,8:Stables';
       end;
    { The area near Kuto's Well; the book's keys here are sentences, named by their subject }
    29: case i of
         1: Entry := '2,2 3,2 2,3 3,3 5,1 6,1 9,0 10,0 8,2 9,2:Sickly kobolds';
         2: Entry := '7,4 11,5 11,7 2,8 9,10:Kobolds guard the well';
         3: Entry := '7,7:Kuto''s Well';
         4: Entry := '7,13:Lizard man patrol';
         5: Entry := '7,14:A hag on a rug';
       end;
    { The catacombs under Lizard Man Keep, keyed with the keep's }
    30: case i of
         1: Entry := '13,1:Holes';
         2: Entry := '1,7:Holes';
         3: Entry := '4,15:Holes';
         4: Entry := '4,5:Holes';
         5: Entry := '7,10:Holes';
         6: Entry := '10,4:Holes';
         7: Entry := '10,8:Stairs';
         8: Entry := '2,1 3,1 10,0 10,1 10,3 11,3 9,5 6,8 2,9 3,9 6,14 12,13 12,14 12,15 14,13:Pools';
       end;
    { The Wealthy Area }
    31: case i of
         1: Entry := '11,6 14,5 10,9:Mansion Entrances';
         2: Entry := '5,6 6,6 8,5 8,6 11,5 14,6:Hidden Treasures';
         3: Entry := '14,8:Goblin Slaves';
         4: Entry := '6,8:Mansion Guards';
         5: Entry := '8,12:Manor Guards';
         6: Entry := '9,14 10,14 9,15 10,15:Orc Bedroom';
         7: Entry := '5,14 6,14 5,15 6,15:Orc Jail';
       end;
    { The catacombs under Kuto's Well, keyed on with the well's }
    32: case i of
         1: Entry := '7,7:Lower part of Kuto''s Well';
         2: Entry := '7,8 2,10 4,13 4,14:Kobold archers';
         3: Entry := '10,3 1,5 5,5:Norris The Gray & his horde';
         4: Entry := '13,1:Norris The Gray''s loot';
       end;
  end;
end;

function EntrySquare(e: string; k: Byte; var x, y: ShortInt): Boolean;
var
  p: Byte;
  n: Byte;
  v: Integer;
  coord: Byte;
begin
  EntrySquare := False;
  p := 1;
  n := 0;
  while (p <= Length(e)) and (e[p] <> ':') do begin
    { one square: digits, a comma, digits }
    for coord := 1 to 2 do begin
      v := 0;
      if (p > Length(e)) or not (e[p] in ['0'..'9']) then Exit;
      while (p <= Length(e)) and (e[p] in ['0'..'9']) do begin
        v := v * 10 + Ord(e[p]) - Ord('0');
        Inc(p);
      end;
      if v > Types.MAP_LAST then Exit;
      if coord = 1 then begin
        x := v;
        if (p > Length(e)) or (e[p] <> ',') then Exit;
        Inc(p);
      end else
        y := v;
    end;
    Inc(n);
    if n = k then begin
      EntrySquare := True;
      Exit;
    end;
    if (p <= Length(e)) and (e[p] = ' ') then
      Inc(p);
  end;
end;

function EntryText(e: string): TClueText;
begin
  EntryText := Copy(e, Pos(':', e) + 1, CLUE_LEN);
end;

function Note(map: Byte; x, y: ShortInt): TClueText;
var
  i: Byte;
  k: Byte;
  e: string;
  ex: ShortInt;
  ey: ShortInt;
begin
  Note := '';
  i := 1;
  e := ClueBook.Entry(map, i);
  while e <> '' do begin
    k := 1;
    while ClueBook.EntrySquare(e, k, ex, ey) do begin
      if (ex = x) and (ey = y) then begin
        Note := ClueBook.EntryText(e);
        Exit;
      end;
      Inc(k);
    end;
    Inc(i);
    e := ClueBook.Entry(map, i);
  end;
end;

function Marked(map: Byte; x, y: ShortInt): Boolean;
var
  i: Byte;
  k: Byte;
  e: string;
  ex: ShortInt;
  ey: ShortInt;
begin
  if map <> marksMap then begin
    FillChar(marks, SizeOf(marks), 0);
    marksMap := map;
    i := 1;
    e := ClueBook.Entry(map, i);
    while e <> '' do begin
      k := 1;
      while ClueBook.EntrySquare(e, k, ex, ey) do begin
        marks[ey] := marks[ey] or (1 shl ex);
        Inc(k);
      end;
      Inc(i);
      e := ClueBook.Entry(map, i);
    end;
  end;
  Marked := Types.OnMap(x, y) and (marks[y] and (1 shl x) <> 0);
end;

end.

{ The Clue Book's map keys on the Companion Tools' map (#856): each 3D area's numbered keys, on the squares where the
  Clue Book's map of the area prints their numbers, in the book's own words shortened to fit. A key printed at several
  places is on each of them; a number printed across a grid line is on each square it straddles. The keys are the
  book's, not the player's: MapNotes keeps the player's notes apart, and nothing here is saved. The table is string
  literals in code, as the Journal's text is, so it lives in the overlay and costs no data segment.

  The coordinates were read off the book's maps (the 1988 Clue Book's grid is the game's own: x across from 0 at the
  left, y down from 0 at the top) and checked against each area's GEO walls and event squares, and the scripts where a
  label sat between two rooms. Where the book draws a room a square off the game's, the key is on the game's square,
  and the area's comment says so. Keys go by GEO map, not script: the maps the book draws as one (Valjevo's maze, the
  inner tower's lower level) are split over the maps that hold them. The wilderness, which has its own map, and the
  scripts with no GEO map (City Hall, the Training Hall, the silver dragon's den) have none. }
{$O+,F+}
{$I COMPILER.INC}
unit ClueBook;

interface

const
  { as long as a player's note (MapNotes.NOTE_LEN), so the Map tool shows either on the same line }
  CLUE_LEN = 30;

type
  TClueText = string[CLUE_LEN];

{ The Clue Book's key on square (x, y) of GEO map map: its number and name, as '3. Temple of Tyr'; '' for none. }
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
  marks: array[0..15] of Word;

function Entry(map, i: Byte): string;
begin
  Entry := '';
  case map of
    { New Phlan, the civilized area }
    0: case i of
         1: Entry := '15,1:1. Boat';
         2: Entry := '11,1:2. Passenger Dock';
         3: Entry := '10,4 9,6:3. Temple of Tyr';
         4: Entry := '10,5:4. Bishop Braccio''s Office';
         5: Entry := '8,1 8,2:5. Dueling & Hiring Hall';
         6: Entry := '5,0:6. Clerical Training';
         7: Entry := '7,0:7. Magic User Training';
         8: Entry := '8,0:8. Fighter Training';
         9: Entry := '9,0:9. Thieves Training';
         10: Entry := '1,1:10. Temple of Sune';
         11: Entry := '1,7:11. City Park';
         12: Entry := '4,3:12. Entrance To The City Hall';
         13: Entry := '5,5:13. Clerk of the City Council';
         14: Entry := '6,5:14. Junior Councilman''s Office';
         15: Entry := '6,6:15. Senior Councilman''s Office';
         16: Entry := '5,7 6,7 5,8 6,8:16. Head Councilman''s Office';
         17: Entry := '5,9 6,9 5,10 6,10:17. City Council Chambers';
         18: Entry := '1,13:18. Temple of Tempus';
         19: Entry := '1,14 4,12 4,13 6,12 6,13:19. Inns';
         20: Entry := '10,8 8,8 8,9 14,10 15,10 15,13:20. Taverns';
         21: Entry := '13,8 8,11 11,12 8,13 9,13:21. Arms & Armor Shop';
         22: Entry := '15,8 9,10 12,10 9,11 11,11:22. General Items Shop';
         23: Entry := '11,10 10,13:23. Silver Shop';
         24: Entry := '8,10:24. Jeweler';
       end;
    { The Buccaneers' Base; the book draws the west and east towers a row north of the game's, at 2,3 and 13,3 }
    1: case i of
         1: Entry := '7,0:1. Front Gate';
         2: Entry := '8,10 9,10 8,11 9,11:2. Merchant''s Camp Area';
         3: Entry := '7,11 7,12:3. Captain''s Guards';
         4: Entry := '7,13 8,13:4. Captains Quarters';
         5: Entry := '5,3 6,3 9,3 10,3 1,7 2,7 9,7 10,7 4,10 4,11 11,10 11,11:5. Buccaneer Barracks';
         6: Entry := '6,0 9,0 2,3 13,3 0,10 15,10 4,14 11,14:6. Guard Towers';
         7: Entry := '13,7:7. Animal Pen';
         8: Entry := '6,7 7,7 6,8 7,8:8. Slave Pen';
         9: Entry := '7,6:9. Slave Pen Guards';
         10: Entry := '2,11:10. Huckster';
       end;
    { Cadorna Textile House; the book prints 1a a square west, by a pillar it draws a column off }
    2: case i of
         1: Entry := '0,3:1. Dry Well';
         2: Entry := '6,11:1a. Way in from the Dry Well';
         3: Entry := '6,8 6,9:2. Hobgoblin Barracks';
         4: Entry := '2,11 3,11 2,12 3,12:3. High Priestess Grishnak';
         5: Entry := '2,15:4. Skullcrusher chained up';
         6: Entry := '6,14:5. ''Skullcrusher Was Here''';
         7: Entry := '5,15:6. Baby hobgoblins hiding';
         8: Entry := '10,9:7. A hobgoblin body';
         9: Entry := '11,14:8. Secret door to the east';
         10: Entry := '12,15:9. Ogre leader and his troops';
       end;
    { Valjevo Castle's north-west block, with the book's castle maze keys for its part of the maze }
    3: case i of
         1: Entry := '1,13 1,14:1. Barracks';
         2: Entry := '0,7 1,7:2. Barracks';
         3: Entry := '3,7 3,8:3. Main Gate';
         4: Entry := '0,5 1,5:4. Latrine';
         5: Entry := '0,2 1,2 0,3 1,3:5. Officers Quarters';
         6: Entry := '5,0 6,0 5,1 6,1:6. Guard Post';
         7: Entry := '8,0 9,0 8,1 9,1:7. Mess Hall';
         8: Entry := '12,11:Maze 1. Teleporters';
         9: Entry := '4,7 4,8:Maze 2. Main Gate';
         10: Entry := '4,5 5,5:Maze 4. Tower';
       end;
    { Valjevo Castle's north-east block, with its part of the maze }
    4: case i of
         1: Entry := '5,0 6,0 5,1 6,1:1. Guard Post';
         2: Entry := '8,0 9,0 8,1 9,1:2. Barracks';
         3: Entry := '14,2 15,2 14,3 15,3:3. Armory';
         4: Entry := '14,6 15,6:4. Kitchen';
         5: Entry := '14,9 15,9 14,10 15,10:5. Records Office';
         6: Entry := '14,13 15,13 14,14 15,14:6. Scribe''s Office';
         7: Entry := '6,10:Maze 1. Teleporters';
         8: Entry := '10,4 11,4 10,5 11,5:Maze 5. Tower';
       end;
    { Valjevo Castle's south-east block, with its part of the maze and of the inner tower's lower level }
    5: case i of
         1: Entry := '14,1:1. Snake House';
         2: Entry := '14,8 15,8:2. Barracks';
         3: Entry := '12,7 12,8:3. Main Gate';
         4: Entry := '14,10:4. Cell';
         5: Entry := '15,10:5. Well';
         6: Entry := '14,12 15,12 14,13 15,13:6. Giant''s Guard Post';
         7: Entry := '9,14 10,14 9,15 10,15:7. Old Building';
         8: Entry := '7,14 7,15:8. Barracks';
         9: Entry := '3,4:Maze 1. Teleporters';
         10: Entry := '11,7 11,8:Maze 2. Main Gate';
         11: Entry := '10,10 11,10:Maze 3. Giant Hideout';
         12: Entry := '1,1 2,1 1,2 2,2:Tower 1. False Tyranthraxus';
       end;
    { Valjevo Castle's south-west block, with its part of the maze }
    6: case i of
         1: Entry := '13,14 14,14:1. Laundry Room';
         2: Entry := '1,14 2,14 1,15 2,15:2. Smithy';
         3: Entry := '0,5 1,5 0,6 1,6:3. A Smokehouse';
         4: Entry := '0,1 1,1 0,2 1,2:4. A Bane Chapel';
         5: Entry := '9,5:Maze 1. Teleporters';
         6: Entry := '4,10 5,10 4,11 5,11:Maze 6. Giant Hideout';
       end;
    { Valjevo Castle's inner tower, its upper level (the book's drawing is this map's x 1-8, y 4-11) }
    7: case i of
         1: Entry := '5,4:1. Stairs to lower level';
         2: Entry := '8,5:2. Trap Door Room';
         3: Entry := '1,6 2,6 1,7 2,7:3. Waiting Room';
         4: Entry := '2,4 2,5:4. Genheeris'' Office';
         5: Entry := '3,9:5. Tyranthraxus'' Lair';
         6: Entry := '2,10:The Pool of Radiance';
       end;
    { Stojanow Gate }
    9: case i of
         1: Entry := '4,14 11,14:1. Merchant in Wagon';
         2: Entry := '7,10 8,10 7,11 8,11:2. Bugbear Patrol Area';
         3: Entry := '7,9 8,9:3. Southern Gate';
         4: Entry := '7,7 8,7 7,8 8,8:4. Northern Gate';
         5: Entry := '7,6 8,6:5. Ettin guards fight here';
         6: Entry := '4,8:6. West Tower';
         7: Entry := '11,8:7. East Tower';
       end;
    { Valhingen Graveyard; the keys are sentences, shortened }
    10: case i of
         1: Entry := '6,4:1. Skeletal Hands';
         2: Entry := '5,6:2. Skeletons guard mausoleum';
         3: Entry := '7,6:3. Giant skeleton helps guard';
         4: Entry := '5,9:4. Zombies guard this tower';
         5: Entry := '4,10:5. Spectre creating zombies';
         6: Entry := '1,12:6. Skeletons guard this tower';
         7: Entry := '1,13:7. Room filled with poison gas';
         8: Entry := '0,15:8. Spectre creating skeletons';
         9: Entry := '10,15:9. Zombies outside mausoleum';
         10: Entry := '9,15:10. Ju-ju zombie helps guard';
         11: Entry := '9,11:11. Mummies inhabit this crypt';
         12: Entry := '9,5:12. Wights guard this tower';
         13: Entry := '9,7:13. Spectre creating wights';
         14: Entry := '15,6:14. Wights guard mausoleum';
         15: Entry := '15,8:15. A wraith helps guard';
         16: Entry := '9,1:16. Spectres guard this crypt';
         17: Entry := '8,2:17. A gallant knight''s grave';
         18: Entry := '12,4:18. The vampire''s coffin';
         19: Entry := '14,0:19. The vampire is here';
         20: Entry := '8,7:20. An evil magic user';
       end;
    { The Kobold Caves; the keys are sentences, shortened }
    13: case i of
         1: Entry := '6,13:1. A hidden water trap';
         2: Entry := '6,11:2. A discarded map';
         3: Entry := '9,12:3. You meet a kobold here';
         4: Entry := '10,9:4. A net trap';
         5: Entry := '11,9:5. A Spike Trap';
         6: Entry := '12,9:6. A drunken kobold';
         7: Entry := '14,8 14,9:7. You may meet the wyvern';
         8: Entry := '14,6:8. The wyverns nest';
         9: Entry := '15,3:9. A crippled kobold';
         10: Entry := '1,2:10. Prison: Princess Fatima';
         11: Entry := '5,3:11. The throne room';
         12: Entry := '7,1 8,1:12. The king''s guard';
         13: Entry := '10,1:13. Fate of the kobold king';
         14: Entry := '14,0:14. An efreeti bottle';
         15: Entry := '13,1:15. Huge kobold treasure trove';
         16: Entry := '3,3:16. A clue';
       end;
    { Kovel Mansion; keys 3 on are sentences, shortened }
    14: case i of
         1: Entry := '3,4:1. First Ambush';
         2: Entry := '6,5:2. A Pair of Thieves';
         3: Entry := '9,8:3. The thieves split up';
         4: Entry := '13,5:4. Corner a single thief';
         5: Entry := '8,13:5. Thieves waiting in ambush';
         6: Entry := '14,9:6. Information collected';
         7: Entry := '11,14:7. Boss'' men beat old thief';
         8: Entry := '14,14:8. Some of the thieves'' loot';
         9: Entry := '5,14:9. Information collected';
         10: Entry := '7,6:10. A room with four caskets';
         11: Entry := '4,13:11. A room with a cabinet';
         12: Entry := '10,9:12. Pile of thieves'' treasure';
         13: Entry := '14,10:13. A clue';
       end;
    { Mendor's Library }
    15: case i of
         1: Entry := '11,4:1. History Section';
         2: Entry := '5,4:2. Rhetoric Section';
         3: Entry := '13,6:3. Philosophy Section';
         4: Entry := '3,6:4. Mathematics Section';
         5: Entry := '13,10:5. Storeroom';
         6: Entry := '11,12:6. Madman in Corner';
         7: Entry := '13,13:7. Master Scribe''s Chamber';
         8: Entry := '8,11:8. Librarian''s Chamber';
         9: Entry := '4,11:9. Garden';
       end;
    { Lizard Man Keep }
    16: case i of
         1: Entry := '10,4:1. Holes';
         2: Entry := '3,7:2. Holes';
         3: Entry := '5,12:3. Holes';
         4: Entry := '6,6:4. Holes';
         5: Entry := '7,9:5. Holes';
         6: Entry := '9,6:6. Holes';
         7: Entry := '9,8:7. Stairs';
         8: Entry := '4,3:8. Lizard Men & Giant Lizards';
         9: Entry := '4,6 4,7 2,9 2,10:9. Giant Lizards';
       end;
    { The Nomad Camp }
    17: case i of
         1: Entry := '10,1 3,8 9,14:1. Trip wire';
         2: Entry := '9,12:2. Your Hut';
         3: Entry := '0,9:3. The Forest';
       end;
    { Podal Plaza (the book spells it Podol) }
    18: case i of
         1: Entry := '14,8:1. Minor Temple of Bane';
         2: Entry := '3,9 4,9:2. The Pit';
         3: Entry := '0,14 1,14:3. Secret Temple of Il-Mater';
         4: Entry := '7,6 7,7 7,8:4. The Auction';
       end;
    { The Slums }
    20: case i of
         1: Entry := '12,0 12,1:1. Orcs';
         2: Entry := '9,0 10,0 9,1 10,1:2. Goblin Armsmaster';
         3: Entry := '12,9 12,10:3. Magic User';
         4: Entry := '5,2 6,2:4. Stable';
         5: Entry := '7,0 8,0 7,1 8,1:5. Kobolds';
         6: Entry := '0,0:6. Secret Treasure Room';
         7: Entry := '0,2 0,3:7. Hobgoblins';
         8: Entry := '3,5:8. Gypsy';
         9: Entry := '2,3 3,3:9. Orcs';
         10: Entry := '0,6 0,7:10. Monster Guards';
         11: Entry := '1,5:11. Monster Leaders';
         12: Entry := '3,10 3,11:12. Goblin Guards';
         13: Entry := '4,10 5,10:13. Hidden Loot';
         14: Entry := '6,11:14. Entrance to Old Rope Guild';
         15: Entry := '15,12:15. Ohlo''s Potion';
         16: Entry := '0,13 0,14:16. Trolls and Ogres';
       end;
    { Sokal Keep }
    21: case i of
         1: Entry := '6,13:1. Dead Elf';
         2: Entry := '7,11 8,11:2. Undead Patrol Area';
         3: Entry := '1,10:3. Scorpions';
         4: Entry := '2,8 3,8 2,9 3,9:4. Fungus';
         5: Entry := '14,7:5. Poisonous Frogs';
         6: Entry := '7,4 8,4:6. Hobgoblin and Orc Assault';
         7: Entry := '5,3:7. Haunts';
         8: Entry := '7,10 8,10:8. Ferran Martinez';
         9: Entry := '13,3 14,3:9. The Armory';
         10: Entry := '12,0 13,0 12,1 13,1:10. Secret Treasure Room';
       end;
    { Sorcerer's Island, the book's level 1: its two halves are this map's top (as printed) and bottom (8 rows down),
      with the corridor between them at x 15 }
    22: case i of
         1: Entry := '13,4:1. Dead body and partial map';
         2: Entry := '13,15:2. A crazy priest';
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
         1: Entry := '14,10:1. Angered mutant lizards';
         2: Entry := '2,14:2. Lizard men in a cell';
         3: Entry := '4,15:A1+. From A0';
         4: Entry := '15,12:A2. Forward A3+, reverse A3-';
         5: Entry := '11,3:A3+. From A2';
         6: Entry := '12,3:A4. Forward A5+, reverse A5-';
         7: Entry := '14,12:A5-. From A4 in reverse';
         8: Entry := '0,12:B5. From B4';
         9: Entry := '15,8:B6. Teleporter to B7';
         10: Entry := '3,13:B7. From B6';
         11: Entry := '1,1:1. Password over the door';
         12: Entry := '2,1 3,1:2. The machinery';
         13: Entry := '5,5:3. Captured lizard men';
         14: Entry := '5,1:4. Yarash''s Office';
         15: Entry := '0,4:A5+. From A4';
         16: Entry := '0,2:A6. Forward A7+, reverse A7-';
         17: Entry := '0,0:A7+. From A6';
         18: Entry := '13,3:A7-. From A6 in reverse';
         19: Entry := '6,0:C0. Teleporter dial';
         20: Entry := '5,9:C1. Treasure room (Copper)';
       end;
    { The Temple of Bane, keyed on with the Wealthy Area's }
    24: case i of
         1: Entry := '2,7 2,8:8. Temple Entrance';
         2: Entry := '5,5 12,9 9,12:9. Hidden Treasures';
         3: Entry := '14,7 14,8:10. Altar';
       end;
    { The Outpost of Zhentil Keep }
    28: case i of
         1: Entry := '7,0 8,0:1. The Front Gate';
         2: Entry := '0,0 1,0 0,1 1,1 14,0 15,0 14,1 15,1 0,14 1,14 0,15 1,15 14,14 15,14 14,15 15,15 6,6 9,6:2. ' +
           'Guard Towers';
         3: Entry := '6,9 7,9:3. Commandant''s Quarters';
         4: Entry := '5,0 6,0 5,1 6,1 9,0 10,0 9,1 10,1:4. The Party''s Quarters';
         5: Entry := '5,3 10,3 3,5 12,4 12,5 3,11 12,11 12,12 5,13 10,13:5. Barracks';
         6: Entry := '12,8:6. Stables';
       end;
    { The area near Kuto's Well; the book's keys here are sentences, named by their subject }
    29: case i of
         1: Entry := '2,2 3,2 2,3 3,3 5,1 6,1 9,0 10,0 8,2 9,2:1. Sickly kobolds';
         2: Entry := '7,4 11,5 11,7 2,8 9,10:2. Kobolds guard the well';
         3: Entry := '7,7:3. Kuto''s Well';
         4: Entry := '7,13:4. Lizard man patrol';
         5: Entry := '7,14:5. A hag on a rug';
       end;
    { The catacombs under Lizard Man Keep, keyed with the keep's }
    30: case i of
         1: Entry := '13,1:1. Holes';
         2: Entry := '1,7:2. Holes';
         3: Entry := '4,15:3. Holes';
         4: Entry := '4,5:4. Holes';
         5: Entry := '7,10:5. Holes';
         6: Entry := '10,4:6. Holes';
         7: Entry := '10,8:7. Stairs';
         8: Entry := '2,1 3,1 10,0 10,1 10,3 11,3 9,5 6,8 2,9 3,9 6,14 12,13 12,14 12,15 14,13:Pools';
       end;
    { The Wealthy Area }
    31: case i of
         1: Entry := '11,6 14,5 10,9:1. Mansion Entrances';
         2: Entry := '5,6 6,6 8,5 8,6 11,5 14,6:2. Hidden Treasures';
         3: Entry := '14,8:3. Goblin Slaves';
         4: Entry := '6,8:4. Mansion Guards';
         5: Entry := '8,12:5. Manor Guards';
         6: Entry := '9,14 10,14 9,15 10,15:6. Orc Bedroom';
         7: Entry := '5,14 6,14 5,15 6,15:7. Orc Jail';
       end;
    { The catacombs under Kuto's Well, keyed on with the well's }
    32: case i of
         1: Entry := '7,7:6. Lower part of Kuto''s Well';
         2: Entry := '7,8 2,10 4,13 4,14:7. Kobold archers';
         3: Entry := '10,3 1,5 5,5:8. Norris The Gray & his horde';
         4: Entry := '13,1:9. Norris The Gray''s loot';
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
      if v > 15 then Exit;
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
  Marked := (x >= 0) and (x <= 15) and (y >= 0) and (y <= 15) and (marks[y] and (1 shl x) <> 0);
end;

end.

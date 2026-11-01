{ Defines the data fixes applied while DataBld creates merged archives. Each fix
  is identified by its repository issue number and contains one or more atomic
  replacements for a single decoded block. A replacement is applied only when
  the block size and original bytes match exactly. Later offsets refer to the
  results of earlier fixes in this table. Changing the table requires raising
  C_DATA.VERSION.

  LoadTable builds the patch table on the heap so its large byte strings remain
  in this overlay instead of occupying the game's data segment (#964). DataBld
  frees the table after building the archives. }
{$O+,F+}
{$I COMPILER.INC}
unit DataPat;

interface

uses C_DATA;

const
  { the parts of all the fixes, and their bytes together }
  PART_COUNT = 109;
  BYTE_COUNT = 3778;

type
  { One part of a fix: the family's per-disk archive of disk, block id, which is size bytes long before this part;
    origLen bytes at offset there are replaced with newLen bytes. issue is the fix's issue number. }
  TPatchPart = record
    issue: Word;
    family: Byte;
    disk: Byte;
    id: Byte;
    size: Word;
    offset: Word;
    origLen: Byte;
    newLen: Byte;
  end;

  TPartList = array[1..PART_COUNT] of TPatchPart;
  PPartList = ^TPartList;
  TPatchBytes = array[0..BYTE_COUNT - 1] of Byte;
  PPatchBytes = ^TPatchBytes;

const
  { the heap LoadTable takes }
  TABLE_BYTES = SizeOf(TPartList) + SizeOf(TPatchBytes);

var
  { the table, on the heap between LoadTable and FreeTable }
  parts: PPartList;
  patchBytes: PPatchBytes;

{ Put the table on the heap (TABLE_BYTES; the caller sees that they are free): True when its parts and bytes came to
  PART_COUNT and BYTE_COUNT exactly. }
function LoadTable: Boolean;

{ Give back the heap LoadTable took. }
procedure FreeTable;

implementation

var
  { the parts and bytes the table has given so far, counting any past the end }
  partFill: Word;
  byteFill: Word;

{ The next part: issue's fix to the family's per-disk archive of disk, block id, size bytes long before it, whose
  origLen bytes at offset become newLen. }
procedure Part(issue: Word; family, disk, id: Byte; size, offset: Word; origLen, newLen: Byte);
begin
  Inc(partFill);
  if partFill <= PART_COUNT then begin
    parts^[partFill].issue := issue;
    parts^[partFill].family := family;
    parts^[partFill].disk := disk;
    parts^[partFill].id := id;
    parts^[partFill].size := size;
    parts^[partFill].offset := offset;
    parts^[partFill].origLen := origLen;
    parts^[partFill].newLen := newLen;
  end;
end;

{ The next bytes of patchBytes, s's characters. }
procedure Put(s: String);
var
  i: Byte;
begin
  for i := 1 to Length(s) do begin
    if byteFill < BYTE_COUNT then
      patchBytes^[byteFill] := Ord(s[i]);
    Inc(byteFill);
  end;
end;

{ The parts of all the fixes, in table order. }
procedure FillParts;
begin
  { #20: the Flame Tongue +2 Long Sword placed in Valjevo Castle's well (ITEM5 block 36, record 0) carries effect
    22 and special 0, so readying it never adds the Flame Tongue effect and Use casts Find Traps; it gets effect 6
    (Flame Tongue) and special 130, a ready-item handler }
  DataPat.Part(20, C_DATA.FAMILY_ITEM, 5, 36, 63, 61, 2, 2);
  { #27: the arms shop's south door in New Phlan, north wall of (9,14) and south wall of (9,13), is wall type 3, so
    the night lock (a type-9 shop door seen from the street) never stops the party; both become type 9 like every
    other shop door }
  DataPat.Part(27, C_DATA.FAMILY_GEO, 3, 0, 1026, 235, 1, 1);
  DataPat.Part(27, C_DATA.FAMILY_GEO, 3, 0, 1026, 475, 1, 1);
  { #28: the Slums' random-encounter result (script $B118-$B156): a win counts the encounter and gives a clear
    point only while the 15 random encounters are not all fought, so fights that interrupt a rest stop earning
    clear points }
  DataPat.Part(28, C_DATA.FAMILY_ECL, 2, 20, 7679, 6170, 63, 63);
  { #29: the Slums' clear-point routine (script $B69C) gives no point and returns from the script when the party
    fled, and the four set encounters that marked themselves done before calling it call it first, so running from
    a set encounter or from Ohlo neither counts nor removes the encounter }
  DataPat.Part(29, C_DATA.FAMILY_ECL, 2, 20, 7679, 7582, 32, 32);
  DataPat.Part(29, C_DATA.FAMILY_ECL, 2, 20, 7679, 1391, 10, 10);
  DataPat.Part(29, C_DATA.FAMILY_ECL, 2, 20, 7679, 1978, 10, 10);
  DataPat.Part(29, C_DATA.FAMILY_ECL, 2, 20, 7679, 4483, 10, 10);
  DataPat.Part(29, C_DATA.FAMILY_ECL, 2, 20, 7679, 4858, 10, 10);
  { #31: Podal Plaza's pre-camp entry (script $9914-$992A) set the on-mission rest (an interruption every 5
    minutes, 99%) and then overwrote it with the default (every 10 minutes, 16%); the default now comes first }
  DataPat.Part(31, C_DATA.FAMILY_ECL, 1, 18, 6550, 22, 23, 23);
  { #32: Podal Plaza's random encounters (script $9DEE-$9E1D) added to the clearing count before looking at the
    result, so fleeing counted as a win; the count now goes up only after a win ([$6DC7] = 0) while it is below the
    mission's $40 }
  DataPat.Part(32, C_DATA.FAMILY_ECL, 1, 18, 6550, 1264, 48, 48);
  { #33: the Pitt's tavern brawl (script $AAA6) always brought back the buccaneer beaten in the duel, with his Long
    Sword +1 and Chain Mail +1; the brawl now loads him only while [$4A37] = 0, from new code at the end of the
    script }
  DataPat.Part(33, C_DATA.FAMILY_ECL, 1, 18, 6550, 4520, 7, 7);
  DataPat.Part(33, C_DATA.FAMILY_ECL, 1, 18, 6550, 6550, 0, 26);
  { #34: the Cadorna Textile House counted a random encounter as it began (script $9A65), so fleeing it counted
    toward clearing the block; the count now goes up after a won encounter, from new code at the end of the script,
    and [$6E7C] tells the counted encounters from the uncounted hobgoblin patrol }
  DataPat.Part(34, C_DATA.FAMILY_ECL, 4, 2, 6170, 318, 4, 4);
  DataPat.Part(34, C_DATA.FAMILY_ECL, 4, 2, 6170, 359, 32, 32);
  DataPat.Part(34, C_DATA.FAMILY_ECL, 4, 2, 6170, 493, 12, 12);
  DataPat.Part(34, C_DATA.FAMILY_ECL, 4, 2, 6170, 562, 12, 12);
  DataPat.Part(34, C_DATA.FAMILY_ECL, 4, 2, 6170, 647, 12, 12);
  DataPat.Part(34, C_DATA.FAMILY_ECL, 4, 2, 6170, 728, 12, 12);
  DataPat.Part(34, C_DATA.FAMILY_ECL, 4, 2, 6170, 797, 12, 12);
  DataPat.Part(34, C_DATA.FAMILY_ECL, 4, 2, 6170, 6170, 0, 43);
  { #35: the Cadorna Textile House's pre-camp entry (script $9949) made rest safe only once the block was cleared,
    so with nine encounters won a rest could be broken off with no fight; it is now also safe then unless the ogre
    lives and the party is on a patrol square, and with the ogre dead the block is cleared }
  DataPat.Part(35, C_DATA.FAMILY_ECL, 4, 2, 6213, 75, 14, 14);
  DataPat.Part(35, C_DATA.FAMILY_ECL, 4, 2, 6213, 6213, 0, 65);
  { #36: the Ring of Feather Falling under the Wealthy Area's trap door (ITEM1 block 6, record 0) carries effect 0
    and special 0, so readying it gives no Feather Fall; it gets effect 27 and special 128, as a random one has }
  DataPat.Part(36, C_DATA.FAMILY_ITEM, 1, 6, 189, 61, 2, 2);
  { #37: Restal at the bottom of the Textile House well (script $AE71-$AF0A) kept his 'already resealed' flag in
    [$4A17], which entering the area clears, so he resealed and paid again on every visit; he now deals only while
    the party holds the sealed chest ([$4AC8] = 1) and once a game, flagged in the unused [$4A76] }
  DataPat.Part(37, C_DATA.FAMILY_ECL, 4, 2, 6278, 5491, 7, 7);
  DataPat.Part(37, C_DATA.FAMILY_ECL, 4, 2, 6278, 5504, 1, 1);
  DataPat.Part(37, C_DATA.FAMILY_ECL, 4, 2, 6278, 5644, 1, 1);
  { #38: Kovel Mansion's weapons-pile ambush (script $AAB9-$AB0F): 0..7 thieves killed give 5 1st-level thieves,
    8..12 give c-7 6th-level and 12-c 1st-level as before, 13..16 give 5 6th-level and 17 gives 4, where the
    shipped script took the 1st-level count below zero or left it stale }
  DataPat.Part(38, C_DATA.FAMILY_ECL, 3, 14, 7332, 4539, 87, 87);
  { #40: leaving the cleared Sorcerer's Pyramid (script $AE11, $AF2B, $AF3B) used the Valjevo commission state
    [$4A9A] as its scratch flag and left it at $FF, so the council's Valjevo summons never came; the flag is now
    the entry word [$4A1F], which this script uses nowhere else }
  DataPat.Part(40, C_DATA.FAMILY_ECL, 7, 26, 6569, 5397, 1, 1);
  DataPat.Part(40, C_DATA.FAMILY_ECL, 7, 26, 6569, 5681, 1, 1);
  DataPat.Part(40, C_DATA.FAMILY_ECL, 7, 26, 6569, 5697, 1, 1);
  { #41: the Nomad Camp shaman's Bracers AC 2 (MON7ITM block 43, record 1) are priced and named for AC 2 but carry
    plus 6, which gives AC 4; the plus becomes 8 }
  DataPat.Part(41, C_DATA.FAMILY_MONITM, 7, 43, 189, 113, 1, 1);
  { #42: Lizardman Keep's 'press Return' prompt (script $9A64) wrote its answer into [$6E81], the old lizardman's
    record of which location the party is at, so a wrong friend-word at location 3 or 10 started location 1's
    fight; the prompt now writes [$6E7A], which nothing reads before setting it }
  DataPat.Part(42, C_DATA.FAMILY_ECL, 8, 16, 5394, 360, 1, 1);
  { #43: Lizardman Keep's count of giant lizards still to come (script $99AD) subtracted the pool-treasure flags
    [$4A5E] instead of the giant lizards killed [$4A5F], so the catacomb ambush was always ten; it subtracts the
    kills }
  DataPat.Part(43, C_DATA.FAMILY_ECL, 8, 16, 5394, 177, 1, 1);
  { #44: the Buccaneer Base slave pen (script $B4C7) tested a scratch word, not the heir's state, so it offered the
    boy again after he was bought, rescued or lost; it tests [$4AA9] }
  DataPat.Part(44, C_DATA.FAMILY_ECL, 6, 1, 7673, 7115, 1, 1);
  { #45: the Zhentil Keep Outpost offered dinner after the party had fought the garrison or killed the commandant:
    the quarters (script $A400) offer it only while neither has happened, and a rest after fighting the guards
    brings four guards, not the dinner escort (entry 4). Entries 3 and 4 are rewritten in less room to fit, entry 3
    the same as before }
  DataPat.Part(45, C_DATA.FAMILY_ECL, 6, 28, 7669, 16, 2, 2);
  DataPat.Part(45, C_DATA.FAMILY_ECL, 6, 28, 7669, 2827, 2, 2);
  DataPat.Part(45, C_DATA.FAMILY_ECL, 6, 28, 7669, 7463, 110, 110);
  { #46: at the Zhentil Keep Outpost a party that beat the guards outside its quarters could walk west and through
    the one-way wall at (2,0), never stepping on (4,1) where the dwarf and the commandant attack; (3,0) gets the
    same event, 5, keeping its outdoor bit }
  DataPat.Part(46, C_DATA.FAMILY_GEO, 6, 28, 1026, 517, 1, 1);
  { #47: the Zhentil Keep Outpost's commandant fight (MON6CHA block 86) uses a copy of Al-Hyam Dazid, whom the
    party meets alive later in Valjevo Castle; disk 6's copy is renamed Zhentarim Mage, disk 5's Al-Hyam is
    unchanged }
  DataPat.Part(47, C_DATA.FAMILY_MONCHA, 6, 86, 285, 0, 16, 16);
  { #48: the graveyard's two tombs (script $A3D2 and $AD17) gave each other's treasure: the paladin's crypt had no
    armour and a magic-user scroll, the knight's tomb the paladin's plate, shield and lawful-good sword; the two
    item blocks trade places }
  DataPat.Part(48, C_DATA.FAMILY_ECL, 4, 10, 7672, 2788, 1, 1);
  DataPat.Part(48, C_DATA.FAMILY_ECL, 4, 10, 7672, 5161, 1, 1);
  { #49: at Stojanow Gate, refusing the bugbears' 15 gold (or not having it) and being told to 'come back when
    you've learned the rules' (script $AC32) made them hostile for good; they now become more suspicious, attitude
    2, so the party may come back }
  DataPat.Part(49, C_DATA.FAMILY_ECL, 2, 9, 6367, 4918, 1, 1);
  { #50: at Stojanow Gate, bugbears who unmasked the party as impostors (script $ACF8) never turned hostile, so the
    wagon bluff could be tried again until it worked; they now set the hostile attitude, 3, in new code at the end
    of the script }
  DataPat.Part(50, C_DATA.FAMILY_ECL, 2, 9, 6367, 5114, 4, 4);
  DataPat.Part(50, C_DATA.FAMILY_ECL, 2, 9, 6367, 6367, 0, 10);
  { #51: Stojanow Gate's alarm (script $9C0C) set its end hour from the stray word [$9800] instead of the hour it
    was raised, [$4A62], so it ended at once or never; it uses [$4A62] as Valjevo Castle's alarm does }
  DataPat.Part(51, C_DATA.FAMILY_ECL, 2, 9, 6377, 786, 2, 2);
  { #52: Stojanow Gate's location 13 (script $B10F) always fought both tower garrisons, even one already killed;
    new code at the end of the script loads only the surviving garrison, as the alarm fight does, then fights as
    before }
  DataPat.Part(52, C_DATA.FAMILY_ECL, 2, 9, 6377, 6161, 6, 6);
  DataPat.Part(52, C_DATA.FAMILY_ECL, 2, 9, 6377, 6377, 0, 99);
  { #54: the false Tyranthraxus in the hedge maze (script $A9EE) confessed to an abusive weak party and fought a
    strong one; the test is turned round, so a party strength and Charisma bonus of 85 or more gets the confession }
  DataPat.Part(54, C_DATA.FAMILY_ECL, 5, 5, 4943, 4336, 1, 1);
  { #55: beating Tyranthraxus in the Inner Tower (script $A81B) wrote its 'defeated' bit into the unused [$4A72],
    so he, the messenger and Genheeris could be fought again; the bit goes into [$4A6D] as the tower's other bits
    do }
  DataPat.Part(55, C_DATA.FAMILY_ECL, 5, 7, 4105, 3876, 1, 1);
  { #70: the Wealthy Area's south walls at (4,15) and (11,15) could be walked through off the map, where no exit is
    set, and the game hung loading script area 255; both become solid }
  DataPat.Part(70, C_DATA.FAMILY_GEO, 1, 31, 1026, 1014, 1, 1);
  DataPat.Part(70, C_DATA.FAMILY_GEO, 1, 31, 1026, 1021, 1, 1);
  { #203: every Cloak of Displacement gives +2 AC and +2 saves, as a random one (template 13: type 92, plus 2, save
    bonus 2) does; the one with the basilisk's treasure (ITEM2 block 3, record 1) has save bonus 0, so it gets 2 }
  DataPat.Part(203, C_DATA.FAMILY_ITEM, 2, 3, 252, 109, 6, 6);
  { #203: the Level 6 MU's Cloak of Displacement (MON2ITM block 82, record 3) is on the Cloak of Elvenkind's type,
    67, whose AC descriptor leaves it out of AC and saves, with plus 8 and save bonus 0, so it gives nothing; it
    gets type 92, plus 2 and save bonus 2 }
  DataPat.Part(203, C_DATA.FAMILY_MONITM, 2, 82, 315, 235, 6, 6);
  { #355: the New Phlan training hall's notice (script $9A74) directs magic users and clerics north and fighters
    and rogues east, but says nothing of paladins and rangers, who train with the fighters; new code at the end of
    the script adds a sentence for them }
  DataPat.Part(355, C_DATA.FAMILY_ECL, 3, 11, 2171, 488, 10, 10);
  DataPat.Part(355, C_DATA.FAMILY_ECL, 3, 11, 2171, 2171, 0, 49);
  { #606: New Phlan's tavern at (8,9) becomes a vault, The Hoarder's Respite: event 20's address in the event table
    (script $9B4C) goes to new code at the end of the script, which sends every other event-20 square on to the
    tavern ($A2C6) as before, and at (8,9) does what the arms shop does (once a visit, the shopkeeper, the refusal
    after an attack on the city watch) and enters the vault: [$6E6C] = 2, then COMBAT with no monsters }
  DataPat.Part(606, C_DATA.FAMILY_ECL, 3, 0, 7473, 657, 2, 2);
  DataPat.Part(606, C_DATA.FAMILY_ECL, 3, 0, 7473, 7473, 0, 52);
  { #670: the Pitt's buccaneer (script $A90D, PRINTCLEAR) runs his question into the next: WHO WILL IT BE?'WHAT DO
    YOU DO? gets a space after the quote. The packed string's last six-bit slot was empty, so it stays 66 bytes }
  DataPat.Part(670, C_DATA.FAMILY_ECL, 1, 18, 6576, 4168, 12, 12);
  { #682: the Temple of Bane (script 24, map 24) freed with Dirten in the party. At the end of the fight (script
    $AC59, $AC68) new code at the end of the script keeps the day in [$4A79] (C_GBVM.DIRTEN_TEMPLE_DAY), $FFFF when
    Dirten was not there; standing, he bids farewell as before, fallen, the temple guards come in and a cleric
    tends him. At the altar squares, (14,7) and (14,8) (script $A8B0), a freed temple's day is kept, or started for a
    game from before this whose party had Dirten ([$4A9C] = $FF); before 14 days the rebuilding is underway, after
    them Dirten welcomes the party and opens his temple a tenth off ([$6DE2] = 2) }
  DataPat.Part(682, C_DATA.FAMILY_ECL, 1, 24, 7656, 4018, 11, 11);
  DataPat.Part(682, C_DATA.FAMILY_ECL, 1, 24, 7656, 4957, 2, 2);
  DataPat.Part(682, C_DATA.FAMILY_ECL, 1, 24, 7656, 4970, 11, 11);
  DataPat.Part(682, C_DATA.FAMILY_ECL, 1, 24, 7656, 7656, 0, 145);
  DataPat.Part(682, C_DATA.FAMILY_ECL, 1, 24, 7801, 7801, 0, 111);
  DataPat.Part(682, C_DATA.FAMILY_ECL, 1, 24, 7912, 7912, 0, 178);
  { #683: Stojanow Gate once the party has taken it ([$4A77] holds both barracks and the bugbears, $1C): new code at
    the end of the script, reached through events 1, 2, 7 and 13 of the event table (script $9D84). The guard rooms
    at (4,7) and (11,7) are makeshift barracks for New Phlan's troops, and at (7,9) and (8,9), before the gatehouse,
    and (7,6) and (8,6), behind it, the guards on the wall cheer, with no portrait (#1068). Each barracks' text, and
    the cheer at whichever pair the party comes to first, comes once a visit (#1068), kept in [$4A01]
    (C_GBVM.STOJANOW_SHOWN) as the guard rooms' text was, which entering the area clears. None waits for Return }
  DataPat.Part(683, C_DATA.FAMILY_ECL, 2, 9, 6476, 1168, 2, 2);
  DataPat.Part(683, C_DATA.FAMILY_ECL, 2, 9, 6476, 1171, 2, 2);
  DataPat.Part(683, C_DATA.FAMILY_ECL, 2, 9, 6476, 1186, 2, 2);
  DataPat.Part(683, C_DATA.FAMILY_ECL, 2, 9, 6476, 1204, 2, 2);
  DataPat.Part(683, C_DATA.FAMILY_ECL, 2, 9, 6476, 2083, 2, 2);
  DataPat.Part(683, C_DATA.FAMILY_ECL, 2, 9, 6476, 6476, 0, 130);
  DataPat.Part(683, C_DATA.FAMILY_ECL, 2, 9, 6606, 6606, 0, 166);
  { #748: weapons do their damage against large targets to a Large creature (Types.ICON_LARGE), no longer to every
    two-tile one; the gnolls (MON2CHA and MON8CHA block 73) and the phase spider (MON8CHA block 116), two-tile and
    size L, get the Large bit, so they take it as before. The huge scorpion, two-tile, is size M (#792) }
  DataPat.Part(748, C_DATA.FAMILY_MONCHA, 2, 73, 285, 108, 1, 1);
  DataPat.Part(748, C_DATA.FAMILY_MONCHA, 8, 73, 285, 108, 1, 1);
  DataPat.Part(748, C_DATA.FAMILY_MONCHA, 8, 116, 285, 108, 1, 1);
  { #792: the ogre leader (MON1CHA block 9), size L, gets the Large bit its one-tile icon lacked, as the bugbear has:
    weapons do their large damage to it, and it is no person for Charm Person and Hold Person }
  DataPat.Part(792, C_DATA.FAMILY_MONCHA, 1, 9, 285, 108, 1, 1);
  { #864 (POR-0209): outside City Hall the posted proclamations (script $AC58) follow the major rewards paid
    ([$4AC1], C_GBVM.COUNCIL_REWARDS); the ninth arm ($AD21) named CXIV again, the fifth's, where CCXIV, the one
    left, is meant. The packed "CCXIV." is a byte longer than the arm's room, so its ON GOSUB entry goes to new code
    at the end of the script, after #606's }
  DataPat.Part(864, C_DATA.FAMILY_ECL, 3, 0, 7525, 5005, 2, 2);
  DataPat.Part(864, C_DATA.FAMILY_ECL, 3, 0, 7525, 7525, 0, 12);
  { #868: a sage in New Phlan, in a room of her own at (15,12), the dead end of the east tavern, which is walled off
    from it and gets a door from the lane to the west, open at every hour (wall type 10, the tavern's own door);
    (15,13)'s north wall matches the room's south and (14,12)'s east wall its door }
  DataPat.Part(868, C_DATA.FAMILY_GEO, 3, 0, 1026, 208, 1, 1);
  DataPat.Part(868, C_DATA.FAMILY_GEO, 3, 0, 1026, 225, 1, 1);
  DataPat.Part(868, C_DATA.FAMILY_GEO, 3, 0, 1026, 465, 1, 1);
  DataPat.Part(868, C_DATA.FAMILY_GEO, 3, 0, 1026, 976, 2, 2);
  { #868: the sage is the Slums' fortune teller, there only if she lived. Her murder ($A6E7) left a mark only in
    [$4A0B], one of the cells the next area's script clears; its GOSUB ($A755) to the Slums' continue prompt ($B6BC)
    goes to new code at the end of the script that sets C_GBVM.GYPSY_KILLED for good and goes on to the prompt }
  DataPat.Part(868, C_DATA.FAMILY_ECL, 2, 20, 7679, 3673, 2, 2);
  DataPat.Part(868, C_DATA.FAMILY_ECL, 2, 20, 7679, 7679, 0, 10);
  { #868: event 20's address in New Phlan's event table (script $9B4C), which #606 sent to its code at $B62F, goes to
    new code at the end of the script, which sends every other event-20 square on to #606's ($B62F) as before. At
    (15,12) it greets the party once a visit as the shops do (C_GBVM.PHLAN_GREETED). Until the Slums are cleared
    (C_GBVM.REWARD_SLUMS at C_GBVM.QUEST_DONE or past it) with the fortune teller alive (C_GBVM.GYPSY_KILLED 0) it
    shows her empty shop, with the shattered crystal ball when she was murdered; then it refuses the party after a
    fight with the city watch (C_GBVM.WATCH_FOUGHT), shows her as the Slums do (head $19 on body $0D) and runs
    PROGRAM 10 (EclVm.PROG_SAGE). The new code's two jumps to the empty shop are to itself, so a fix before this one
    that lengthens the script moves them as well as its address in the event table. }
  DataPat.Part(868, C_DATA.FAMILY_ECL, 3, 0, 7537, 657, 2, 2);
  DataPat.Part(868, C_DATA.FAMILY_ECL, 3, 0, 7537, 7537, 0, 173);
  { #1092: the Inner Tower's event at $A3E1 (Genheeris slipping away as the party nears the lair) never
    asked whether Tyranthraxus was beaten: SSI wrote that bit into the unused [$4A72] (#55), so he was never beaten and
    the fight came round again. With the bit where #55 puts it, a party that came back with Genheeris lost him at the
    door (POR-0232). The event's first test goes to new code at the end of the script, which leaves when Tyranthraxus
    is beaten ([$4A6D] bit $10), then makes SSI's test and goes back. A save made after the defeat is mended too. }
  DataPat.Part(1092, C_DATA.FAMILY_ECL, 5, 7, 4105, 2787, 9, 9);
  DataPat.Part(1092, C_DATA.FAMILY_ECL, 5, 7, 4105, 4105, 0, 24);
  { #1093: Valjevo Castle's records office (script $AFB6), once both its findings were read, said that finding more
    would take so long the party would need to clear the area first; nothing in the script asks whether the area is
    clear, so it said so however much was cleared. It now says there is nothing more, packed in the same bytes }
  DataPat.Part(1093, C_DATA.FAMILY_ECL, 5, 4, 6627, 6159, 76, 76);
  { #1096: Valhingen Graveyard's vampire coffin (script $B04E) was sanctified with no holy item. SANCTIFY goes to new
    code at the end of the script, which uses up a vial of holy water (USE UP ITEM, C_ECL.USE_UP_ITEM), or failing one
    a holy symbol (C_ITEM.FIND_HOLY_SYMBOL), before the coffin is sanctified as before; with neither it is not }
  DataPat.Part(1096, C_DATA.FAMILY_ECL, 4, 10, 7672, 5978, 2, 2);
  DataPat.Part(1096, C_DATA.FAMILY_ECL, 4, 10, 7672, 7672, 0, 54);
  { #1113: the mage who joins the party in Valhingen Graveyard (script $AE81, MON4CHA block 24) was named LEVEL 6 MU;
    once he has joined, new code at the end of the script, after #1096's, names him ODRAN. The record keeps its name,
    as the mage the party fights when it sends him away }
  DataPat.Part(1113, C_DATA.FAMILY_ECL, 4, 10, 7726, 5512, 7, 7);
  DataPat.Part(1113, C_DATA.FAMILY_ECL, 4, 10, 7726, 7726, 0, 17);
  { #1116: at the Zhentil Keep Outpost before the mission (script $A04E), LEAVE went to a bare EXIT and left the
    riders' picture up until the next step; it goes where the script's other LEAVEs go ($ADC0), which takes it down }
  DataPat.Part(1116, C_DATA.FAMILY_ECL, 6, 25, 5652, 1882, 2, 2);
  { #1117: the Valhingen mage who joined (script $AE81) stayed in the view until the next step; #1113's new code takes
    his picture down before it exits }
  DataPat.Part(1117, C_DATA.FAMILY_ECL, 4, 10, 7743, 7742, 1, 4);
  { #1138: at the Temple of Tyr (script $A064) with the Mad Man in the party, the aged priest told the party to drop
    him and waited for Return ($B06C), but never offered to take him. He now asks the party to leave him with the
    temple, and new code at the end of the script asks WILL YOU LEAVE HIM IN OUR CARE?: on yes he leaves the party
    as Skullcrusher does ($AD56, by the index the party search at $AF56 left in [$9802]), his items with him; either
    way the offer of healing follows as before }
  DataPat.Part(1138, C_DATA.FAMILY_ECL, 3, 0, 7710, 5861, 137, 137);
  DataPat.Part(1138, C_DATA.FAMILY_ECL, 3, 0, 7710, 5998, 4, 4);
  DataPat.Part(1138, C_DATA.FAMILY_ECL, 3, 0, 7710, 7710, 0, 143);
  { #1139: the Temple of Bane freed before Dirten joined left him in the party for good: City Hall still summoned
    the party to the bishop until the reward was paid, the bishop's study (event 5, script $9E07) never asked whether
    the temple was freed, and only the main fight's end ($AC68) bids him farewell. City Hall's summons ($AABE) now
    stops once the temple is freed ([$4ABD] at $FE); the study, by new code at the end of the script, has the bishop
    thank the party and send Dirten to restore the temple, the state #682's altar takes as a freed temple with
    Dirten; and at the altar (script $A8B0, #682's jump), new code finds a Dirten who joined after the temple was
    freed without him and goes to #682's farewell. The altar destroyed is kept for good in
    C_GBVM.BANE_ALTAR_DESTROYED, not the area cell [$4A02] each visit clears, so it can no longer be destroyed again;
    the altar code clears it while the temple is not freed, so an altar destroyed in a fight the party fled stands
    again, as before }
  DataPat.Part(1139, C_DATA.FAMILY_ECL, 1, 24, 8090, 4018, 4, 4);
  DataPat.Part(1139, C_DATA.FAMILY_ECL, 1, 24, 8090, 4300, 2, 2);
  DataPat.Part(1139, C_DATA.FAMILY_ECL, 1, 24, 8090, 4359, 2, 2);
  DataPat.Part(1139, C_DATA.FAMILY_ECL, 1, 24, 8090, 7914, 2, 2);
  DataPat.Part(1139, C_DATA.FAMILY_ECL, 1, 24, 8090, 8090, 0, 112);
  DataPat.Part(1139, C_DATA.FAMILY_ECL, 3, 0, 7853, 612, 2, 2);
  DataPat.Part(1139, C_DATA.FAMILY_ECL, 3, 0, 7853, 7853, 0, 185);
  DataPat.Part(1139, C_DATA.FAMILY_ECL, 3, 8, 7500, 4544, 7, 7);
  { #1091, #1158: New Phlan's arms and armor shop at (11,12), one of five squares that share event 22, becomes a magic
    shop. Event 22's address in the event table (script $9B4C) goes to new code at the end of the script, after
    #1139's, which sends every other event-22 square on to the arms shops ($A8BE) as before. At (11,12) it does what
    the arms shop does (once a visit, the shopkeeper, the refusal after an attack on the city watch) with the magic
    shop's greeting, and on Yes runs PROGRAM 11 (EclVm.PROG_MAGIC_SHOP), which fills the stock, then enters the shop:
    [$6E6C] = 1, then COMBAT with no monsters }
  DataPat.Part(1091, C_DATA.FAMILY_ECL, 3, 0, 8038, 663, 2, 2);
  DataPat.Part(1091, C_DATA.FAMILY_ECL, 3, 0, 8038, 8038, 0, 117);
  { #1121: the Manual of Bodily Health placed in Phlan (ITEM2 block 1, record 0) casts spell 67 by effect 90, which is
    Curse's Neutralize Poison; the Manual's spell moves to 128, effect 151 (C_SPELL.ITEM_BODILY_HEALTH) }
  DataPat.Part(1121, C_DATA.FAMILY_ITEM, 2, 1, 63, 61, 1, 1);
end;

{ Every part's bytes, original then fixed, in table order. }
procedure FillBytes;
begin
  { #20, original }
  DataPat.Put(#$16#$00);
  { fixed: effect 6, special 130 }
  DataPat.Put(#$06#$82);
  { #27 part 1, original }
  DataPat.Put(#$30);
  { fixed: (9,14) north: wall type 9 }
  DataPat.Put(#$90);
  { #27 part 2, original }
  DataPat.Put(#$30);
  { fixed: (9,13) south: wall type 9 }
  DataPat.Put(#$90);
  { #28, original }
  DataPat.Put(#$03#$01#$C7#$6D#$00#$80);                     { $B118 COMPARE [$6DC7], $80 }
  DataPat.Put(#$19);                                         { $B11E IF > }
  DataPat.Put(#$01#$01#$25#$B2);                             { $B11F GOTO LB225 }
  DataPat.Put(#$03#$01#$C7#$6D#$00#$01);                     { $B123 COMPARE [$6DC7], $01 }
  DataPat.Put(#$18);                                         { $B129 IF < }
  DataPat.Put(#$04#$00#$01#$01#$80#$4A#$01#$80#$4A);         { $B12A ADD $01, [$4A80], [$4A80] }
  DataPat.Put(#$18);                                         { $B133 IF < }
  DataPat.Put(#$02#$01#$9C#$B6);                             { $B134 GOSUB LB69C }
  DataPat.Put(#$19);                                         { $B138 IF > }
  DataPat.Put(#$01#$01#$50#$B2);                             { $B139 GOTO LB250 }
  DataPat.Put(#$16);                                         { $B13D IF = }
  DataPat.Put(#$03#$01#$C8#$6D#$00#$00);                     { $B13E COMPARE [$6DC8], $00 }
  DataPat.Put(#$19);                                         { $B144 IF > }
  DataPat.Put(#$04#$00#$01#$01#$80#$4A#$01#$80#$4A);         { $B145 ADD $01, [$4A80], [$4A80] }
  DataPat.Put(#$19);                                         { $B14E IF > }
  DataPat.Put(#$02#$01#$9C#$B6);                             { $B14F GOSUB LB69C }
  DataPat.Put(#$01#$01#$50#$B2);                             { $B153 GOTO LB250 }
  { fixed }
  DataPat.Put(#$03#$01#$C7#$6D#$00#$80);                     { $B118 COMPARE [$6DC7], $80 }
  DataPat.Put(#$19);                                         { $B11E IF > }
  DataPat.Put(#$01#$01#$25#$B2);                             { $B11F GOTO LB225 }
  DataPat.Put(#$03#$01#$C7#$6D#$00#$00);                     { $B123 COMPARE [$6DC7], $00 }
  DataPat.Put(#$17);                                         { $B129 IF <> }
  DataPat.Put(#$01#$01#$50#$B2);                             { $B12A GOTO LB250 }
  DataPat.Put(#$04#$00#$01#$01#$80#$4A#$01#$80#$4A);         { $B12E ADD $01, [$4A80], [$4A80] }
  DataPat.Put(#$03#$01#$80#$4A#$00#$0F);                     { $B137 COMPARE [$4A80], $0F }
  DataPat.Put(#$1A);                                         { $B13D IF <= }
  DataPat.Put(#$02#$01#$9C#$B6);                             { $B13E GOSUB LB69C }
  DataPat.Put(#$01#$01#$50#$B2);                             { $B142 GOTO LB250 }
  DataPat.Put(#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00);
  DataPat.Put(#$00);
  { #29 part 1, original }
  DataPat.Put(#$03#$01#$BB#$4A#$00#$FE);                     { $B69C COMPARE [$4ABB], $FE }
  DataPat.Put(#$1B);                                         { $B6A2 IF >= }
  DataPat.Put(#$13);                                         { $B6A3 RETURN }
  DataPat.Put(#$04#$00#$01#$01#$BB#$4A#$01#$BB#$4A);         { $B6A4 ADD $01, [$4ABB], [$4ABB] }
  DataPat.Put(#$03#$01#$BB#$4A#$00#$19);                     { $B6AD COMPARE [$4ABB], $19 }
  DataPat.Put(#$18);                                         { $B6B3 IF < }
  DataPat.Put(#$13);                                         { $B6B4 RETURN }
  DataPat.Put(#$09#$00#$FE#$01#$BB#$4A);                     { $B6B5 SAVE $FE, [$4ABB] }
  DataPat.Put(#$13);                                         { $B6BB RETURN }
  { fixed }
  DataPat.Put(#$03#$01#$C7#$6D#$00#$00);                     { $B69C COMPARE [$6DC7], $00 }
  DataPat.Put(#$17);                                         { $B6A2 IF <> }
  DataPat.Put(#$00);                                         { $B6A3 EXIT }
  DataPat.Put(#$03#$01#$BB#$4A#$00#$18);                     { $B6A4 COMPARE [$4ABB], $18 }
  DataPat.Put(#$18);                                         { $B6AA IF < }
  DataPat.Put(#$04#$00#$01#$01#$BB#$4A#$01#$BB#$4A);         { $B6AB ADD $01, [$4ABB], [$4ABB] }
  DataPat.Put(#$16);                                         { $B6B4 IF = }
  DataPat.Put(#$09#$00#$FE#$01#$BB#$4A);                     { $B6B5 SAVE $FE, [$4ABB] }
  DataPat.Put(#$13);                                         { $B6BB RETURN }
  { #29 part 2, original }
  DataPat.Put(#$09#$00#$FF#$01#$CA#$4A);                     { $9E6D SAVE $FF, [$4ACA] }
  DataPat.Put(#$02#$01#$9C#$B6);                             { $9E73 GOSUB LB69C }
  { fixed: event 1 marks itself done after the clear point }
  DataPat.Put(#$02#$01#$9C#$B6);                             { $9E6D GOSUB LB69C }
  DataPat.Put(#$09#$00#$FF#$01#$CA#$4A);                     { $9E71 SAVE $FF, [$4ACA] }
  { #29 part 3, original }
  DataPat.Put(#$09#$00#$FF#$01#$81#$4A);                     { $A0B8 SAVE $FF, [$4A81] }
  DataPat.Put(#$02#$01#$9C#$B6);                             { $A0BE GOSUB LB69C }
  { fixed: Ohlo, likewise }
  DataPat.Put(#$02#$01#$9C#$B6);                             { $A0B8 GOSUB LB69C }
  DataPat.Put(#$09#$00#$FF#$01#$81#$4A);                     { $A0BC SAVE $FF, [$4A81] }
  { #29 part 4, original }
  DataPat.Put(#$09#$00#$FA#$01#$CE#$4A);                     { $AA81 SAVE $FA, [$4ACE] }
  DataPat.Put(#$02#$01#$9C#$B6);                             { $AA87 GOSUB LB69C }
  { fixed: event 10, likewise }
  DataPat.Put(#$02#$01#$9C#$B6);                             { $AA81 GOSUB LB69C }
  DataPat.Put(#$09#$00#$FA#$01#$CE#$4A);                     { $AA85 SAVE $FA, [$4ACE] }
  { #29 part 5, original }
  DataPat.Put(#$09#$00#$FF#$01#$D0#$4A);                     { $ABF8 SAVE $FF, [$4AD0] }
  DataPat.Put(#$02#$01#$9C#$B6);                             { $ABFE GOSUB LB69C }
  { fixed: event 14, likewise }
  DataPat.Put(#$02#$01#$9C#$B6);                             { $ABF8 GOSUB LB69C }
  DataPat.Put(#$09#$00#$FF#$01#$D0#$4A);                     { $ABFC SAVE $FF, [$4AD0] }
  { #31, original }
  DataPat.Put(#$03#$01#$34#$4A#$00#$40);                     { $9914 COMPARE [$4A34], $40 }
  DataPat.Put(#$1B);                                         { $991A IF >= }
  DataPat.Put(#$02#$01#$53#$99);                             { $991B GOSUB L9953 }
  DataPat.Put(#$09#$00#$02#$01#$D2#$6D);                     { $991F SAVE $02, [$6DD2] }
  DataPat.Put(#$09#$00#$10#$01#$D3#$6D);                     { $9925 SAVE $10, [$6DD3] }
  { fixed }
  DataPat.Put(#$09#$00#$02#$01#$D2#$6D);                     { $9914 SAVE $02, [$6DD2] }
  DataPat.Put(#$09#$00#$10#$01#$D3#$6D);                     { $991A SAVE $10, [$6DD3] }
  DataPat.Put(#$03#$01#$34#$4A#$00#$40);                     { $9920 COMPARE [$4A34], $40 }
  DataPat.Put(#$1B);                                         { $9926 IF >= }
  DataPat.Put(#$02#$01#$53#$99);                             { $9927 GOSUB L9953 }
  { #32, original }
  DataPat.Put(#$02#$01#$0C#$9E);                             { $9DEE GOSUB L9E0C }
  DataPat.Put(#$03#$01#$4F#$C0#$00#$7F);                     { $9DF2 COMPARE [$C04F], $7F }
  DataPat.Put(#$18);                                         { $9DF8 IF < }
  DataPat.Put(#$01#$01#$68#$9E);                             { $9DF9 GOTO L9E68 }
  DataPat.Put(#$03#$01#$C7#$6D#$00#$80);                     { $9DFD COMPARE [$6DC7], $80 }
  DataPat.Put(#$19);                                         { $9E03 IF > }
  DataPat.Put(#$01#$01#$23#$9E);                             { $9E04 GOTO L9E23 }
  DataPat.Put(#$01#$01#$1E#$9E);                             { $9E08 GOTO L9E1E }
  DataPat.Put(#$03#$01#$34#$4A#$00#$40);                     { $9E0C COMPARE [$4A34], $40 }
  DataPat.Put(#$1B);                                         { $9E12 IF >= }
  DataPat.Put(#$13);                                         { $9E13 RETURN }
  DataPat.Put(#$04#$00#$01#$01#$34#$4A#$01#$34#$4A);         { $9E14 ADD $01, [$4A34], [$4A34] }
  DataPat.Put(#$13);                                         { $9E1D RETURN }
  { fixed }
  DataPat.Put(#$04#$01#$C7#$6D#$01#$34#$4A#$01#$79#$6E);     { $9DEE ADD [$6DC7], [$4A34], [$6E79] }
  DataPat.Put(#$03#$01#$79#$6E#$00#$40);                     { $9DF8 COMPARE [$6E79], $40 }
  DataPat.Put(#$18);                                         { $9DFE IF < }
  DataPat.Put(#$04#$00#$01#$01#$34#$4A#$01#$34#$4A);         { $9DFF ADD $01, [$4A34], [$4A34] }
  DataPat.Put(#$03#$01#$4F#$C0#$00#$7F);                     { $9E08 COMPARE [$C04F], $7F }
  DataPat.Put(#$18);                                         { $9E0E IF < }
  DataPat.Put(#$01#$01#$68#$9E);                             { $9E0F GOTO L9E68 }
  DataPat.Put(#$03#$01#$C7#$6D#$00#$80);                     { $9E13 COMPARE [$6DC7], $80 }
  DataPat.Put(#$19);                                         { $9E19 IF > }
  DataPat.Put(#$01#$01#$23#$9E);                             { $9E1A GOTO L9E23 }
  { #33 part 1, original }
  DataPat.Put(#$0B#$00#$29#$00#$01#$00#$10);                 { $AAA6 LOAD MONSTER $29, $01, $10 }
  { fixed }
  DataPat.Put(#$01#$01#$94#$B2);                             { $AAA6 GOTO LB294 }
  DataPat.Put(#$00#$00#$00);
  { #33 part 2, added at $B294: the buccaneer only before the duel, then the rest as before }
  DataPat.Put(#$03#$01#$37#$4A#$00#$00);                     { $B294 COMPARE [$4A37], $00 }
  DataPat.Put(#$16);                                         { $B29A IF = }
  DataPat.Put(#$0B#$00#$29#$00#$01#$00#$10);                 { $B29B LOAD MONSTER $29, $01, $10 }
  DataPat.Put(#$0B#$00#$04#$00#$08#$00#$04);                 { $B2A2 LOAD MONSTER $04, $08, $04 }
  DataPat.Put(#$24);                                         { $B2A9 COMBAT }
  DataPat.Put(#$01#$01#$B5#$AA);                             { $B2AA GOTO LAAB5 }
  { #34 part 1, original }
  DataPat.Put(#$01#$01#$85#$9A);                             { $9A3C GOTO L9A85 }
  { fixed: the patrol goes by new code that marks it uncounted }
  DataPat.Put(#$01#$01#$18#$B1);                             { $9A3C GOTO LB118 }
  { #34 part 2, original }
  DataPat.Put(#$04#$00#$01#$01#$E4#$4A#$01#$E4#$4A);         { $9A65 ADD $01, [$4AE4], [$4AE4] }
  DataPat.Put(#$14#$01#$E4#$4A#$00#$0A#$01#$75#$4A#$00#$FF); { $9A6E COMPARE AND [$4AE4], $0A, [$4A75], $FF }
  DataPat.Put(#$17);                                         { $9A79 IF <> }
  DataPat.Put(#$01#$01#$85#$9A);                             { $9A7A GOTO L9A85 }
  DataPat.Put(#$09#$00#$FE#$01#$E6#$4A);                     { $9A7E SAVE $FE, [$4AE6] }
  DataPat.Put(#$00);                                         { $9A84 EXIT }
  { fixed: a counted encounter, unless nine are won and the ogre is dead, which clears the block }
  DataPat.Put(#$09#$00#$01#$01#$7C#$6E);                     { $9A65 SAVE $01, [$6E7C] }
  DataPat.Put(#$14#$01#$E4#$4A#$00#$09#$01#$75#$4A#$00#$FF); { $9A6B COMPARE AND [$4AE4], $09, [$4A75], $FF }
  DataPat.Put(#$17);                                         { $9A76 IF <> }
  DataPat.Put(#$01#$01#$85#$9A);                             { $9A77 GOTO L9A85 }
  DataPat.Put(#$09#$00#$FE#$01#$E6#$4A);                     { $9A7B SAVE $FE, [$4AE6] }
  DataPat.Put(#$00);                                         { $9A81 EXIT }
  DataPat.Put(#$00#$00#$00);
  { #34 part 3, original }
  DataPat.Put(#$03#$01#$C7#$6D#$00#$80);                     { $9AEB COMPARE [$6DC7], $80 }
  DataPat.Put(#$19);                                         { $9AF1 IF > }
  DataPat.Put(#$01#$01#$FB#$9C);                             { $9AF2 GOTO L9CFB }
  DataPat.Put(#$00);                                         { $9AF6 EXIT }
  { fixed: after the frogs, the new result code }
  DataPat.Put(#$01#$01#$22#$B1);                             { $9AEB GOTO LB122 }
  DataPat.Put(#$00#$00#$00#$00#$00#$00#$00#$00);
  { #34 part 4, original }
  DataPat.Put(#$03#$01#$C7#$6D#$00#$80);                     { $9B30 COMPARE [$6DC7], $80 }
  DataPat.Put(#$19);                                         { $9B36 IF > }
  DataPat.Put(#$01#$01#$FB#$9C);                             { $9B37 GOTO L9CFB }
  DataPat.Put(#$00);                                         { $9B3B EXIT }
  { fixed: after the hobgoblins, likewise }
  DataPat.Put(#$01#$01#$22#$B1);                             { $9B30 GOTO LB122 }
  DataPat.Put(#$00#$00#$00#$00#$00#$00#$00#$00);
  { #34 part 5, original }
  DataPat.Put(#$03#$01#$C7#$6D#$00#$80);                     { $9B85 COMPARE [$6DC7], $80 }
  DataPat.Put(#$19);                                         { $9B8B IF > }
  DataPat.Put(#$01#$01#$FB#$9C);                             { $9B8C GOTO L9CFB }
  DataPat.Put(#$00);                                         { $9B90 EXIT }
  { fixed: after the skeletons, likewise }
  DataPat.Put(#$01#$01#$22#$B1);                             { $9B85 GOTO LB122 }
  DataPat.Put(#$00#$00#$00#$00#$00#$00#$00#$00);
  { #34 part 6, original }
  DataPat.Put(#$03#$01#$C7#$6D#$00#$80);                     { $9BD6 COMPARE [$6DC7], $80 }
  DataPat.Put(#$19);                                         { $9BDC IF > }
  DataPat.Put(#$01#$01#$FB#$9C);                             { $9BDD GOTO L9CFB }
  DataPat.Put(#$00);                                         { $9BE1 EXIT }
  { fixed: after the ghouls, likewise }
  DataPat.Put(#$01#$01#$22#$B1);                             { $9BD6 GOTO LB122 }
  DataPat.Put(#$00#$00#$00#$00#$00#$00#$00#$00);
  { #34 part 7, original }
  DataPat.Put(#$03#$01#$C7#$6D#$00#$80);                     { $9C1B COMPARE [$6DC7], $80 }
  DataPat.Put(#$19);                                         { $9C21 IF > }
  DataPat.Put(#$01#$01#$FB#$9C);                             { $9C22 GOTO L9CFB }
  DataPat.Put(#$00);                                         { $9C26 EXIT }
  { fixed: after the scorpions, likewise }
  DataPat.Put(#$01#$01#$22#$B1);                             { $9C1B GOTO LB122 }
  DataPat.Put(#$00#$00#$00#$00#$00#$00#$00#$00);
  { #34 part 8, added at $B118: the patrol mark, then the result code: fled, run as before; won a counted
    encounter, count it }
  DataPat.Put(#$09#$00#$00#$01#$7C#$6E);                     { $B118 SAVE $00, [$6E7C] }
  DataPat.Put(#$01#$01#$85#$9A);                             { $B11E GOTO L9A85 }
  DataPat.Put(#$03#$01#$C7#$6D#$00#$80);                     { $B122 COMPARE [$6DC7], $80 }
  DataPat.Put(#$19);                                         { $B128 IF > }
  DataPat.Put(#$01#$01#$FB#$9C);                             { $B129 GOTO L9CFB }
  DataPat.Put(#$14#$01#$C7#$6D#$00#$00#$01#$7C#$6E#$00#$01); { $B12D COMPARE AND [$6DC7], $00, [$6E7C], $01 }
  DataPat.Put(#$16);                                         { $B138 IF = }
  DataPat.Put(#$04#$00#$01#$01#$E4#$4A#$01#$E4#$4A);         { $B139 ADD $01, [$4AE4], [$4AE4] }
  DataPat.Put(#$00);                                         { $B142 EXIT }
  { #35 part 1, original }
  DataPat.Put(#$03#$01#$E6#$4A#$00#$FD);                     { $9949 COMPARE [$4AE6], $FD }
  DataPat.Put(#$19);                                         { $994F IF > }
  DataPat.Put(#$09#$00#$00#$01#$D2#$6D);                     { $9950 SAVE $00, [$6DD2] }
  DataPat.Put(#$00);                                         { $9956 EXIT }
  { fixed: on to new code at the end of the script }
  DataPat.Put(#$01#$01#$43#$B1);                             { $9949 GOTO LB143 }
  DataPat.Put(#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00);
  { #35 part 2, added at $B143: with nine encounters won, clear the block if the ogre is dead and rest safely
    unless a patrol can come; then the cleared-block check as before }
  DataPat.Put(#$03#$01#$E4#$4A#$00#$09);                     { $B143 COMPARE [$4AE4], $09 }
  DataPat.Put(#$18);                                         { $B149 IF < }
  DataPat.Put(#$01#$01#$76#$B1);                             { $B14A GOTO LB176 }
  DataPat.Put(#$03#$01#$75#$4A#$00#$FF);                     { $B14E COMPARE [$4A75], $FF }
  DataPat.Put(#$16);                                         { $B154 IF = }
  DataPat.Put(#$09#$00#$FE#$01#$E6#$4A);                     { $B155 SAVE $FE, [$4AE6] }
  DataPat.Put(#$2F#$00#$7F#$01#$4F#$C0#$01#$82#$6E);         { $B15B AND $7F, [$C04F], [$6E82] }
  DataPat.Put(#$14#$01#$82#$6E#$00#$16#$01#$75#$4A#$00#$00); { $B164 COMPARE AND [$6E82], $16, [$4A75], $00 }
  DataPat.Put(#$17);                                         { $B16F IF <> }
  DataPat.Put(#$09#$00#$00#$01#$D2#$6D);                     { $B170 SAVE $00, [$6DD2] }
  DataPat.Put(#$03#$01#$E6#$4A#$00#$FD);                     { $B176 COMPARE [$4AE6], $FD }
  DataPat.Put(#$19);                                         { $B17C IF > }
  DataPat.Put(#$09#$00#$00#$01#$D2#$6D);                     { $B17D SAVE $00, [$6DD2] }
  DataPat.Put(#$00);                                         { $B183 EXIT }
  { #36, original }
  DataPat.Put(#$00#$00);
  { fixed: effect 27 (Feather Fall), special 128 }
  DataPat.Put(#$1B#$80);
  { #37 part 1, original }
  DataPat.Put(#$03#$01#$B8#$4A#$00#$FF);                     { $AE71 COMPARE [$4AB8], $FF }
  DataPat.Put(#$16);                                         { $AE77 IF = }
  { fixed: the chest must be held unopened }
  DataPat.Put(#$03#$01#$C8#$4A#$00#$01);                     { $AE71 COMPARE [$4AC8], $01 }
  DataPat.Put(#$17);                                         { $AE77 IF <> }
  { #37 part 2, original }
  DataPat.Put(#$17);
  { fixed: COMPARE [$4A76], $01 }
  DataPat.Put(#$76);
  { #37 part 3, original }
  DataPat.Put(#$17);
  { fixed: SAVE $01, [$4A76] }
  DataPat.Put(#$76);
  { #38, original }
  DataPat.Put(#$04#$00#$05#$01#$45#$4A#$01#$79#$6E);         { $AAB9 ADD $05, [$4A45], [$6E79] }
  DataPat.Put(#$03#$01#$79#$6E#$00#$15);                     { $AAC2 COMPARE [$6E79], $15 }
  DataPat.Put(#$1B);                                         { $AAC8 IF >= }
  DataPat.Put(#$01#$01#$EE#$AA);                             { $AAC9 GOTO LAAEE }
  DataPat.Put(#$03#$01#$79#$6E#$00#$0C);                     { $AACD COMPARE [$6E79], $0C }
  DataPat.Put(#$1A);                                         { $AAD3 IF <= }
  DataPat.Put(#$01#$01#$04#$AB);                             { $AAD4 GOTO LAB04 }
  DataPat.Put(#$05#$00#$0C#$01#$79#$6E#$01#$7A#$6E);         { $AAD8 SUBTRACT $0C, [$6E79], [$6E7A] }
  DataPat.Put(#$05#$01#$7A#$6E#$00#$05#$01#$7B#$6E);         { $AAE1 SUBTRACT [$6E7A], $05, [$6E7B] }
  DataPat.Put(#$01#$01#$10#$AB);                             { $AAEA GOTO LAB10 }
  DataPat.Put(#$05#$00#$15#$01#$79#$6E#$01#$7A#$6E);         { $AAEE SUBTRACT $15, [$6E79], [$6E7A] }
  DataPat.Put(#$05#$01#$7A#$6E#$00#$05#$01#$7A#$6E);         { $AAF7 SUBTRACT [$6E7A], $05, [$6E7A] }
  DataPat.Put(#$01#$01#$10#$AB);                             { $AB00 GOTO LAB10 }
  DataPat.Put(#$09#$00#$05#$01#$7B#$6E);                     { $AB04 SAVE $05, [$6E7B] }
  DataPat.Put(#$09#$00#$00#$01#$7A#$6E);                     { $AB0A SAVE $00, [$6E7A] }
  { fixed }
  DataPat.Put(#$09#$02#$05#$00#$01#$7B#$6E);                 { $AAB9 SAVE $0005, [$6E7B] }
  DataPat.Put(#$09#$02#$00#$00#$01#$7A#$6E);                 { $AAC0 SAVE $0000, [$6E7A] }
  DataPat.Put(#$03#$01#$45#$4A#$00#$07);                     { $AAC7 COMPARE [$4A45], $07 }
  DataPat.Put(#$1A);                                         { $AACD IF <= }
  DataPat.Put(#$01#$01#$10#$AB);                             { $AACE GOTO LAB10 }
  DataPat.Put(#$05#$00#$07#$01#$45#$4A#$01#$7A#$6E);         { $AAD2 SUBTRACT $07, [$4A45], [$6E7A] }
  DataPat.Put(#$05#$01#$7A#$6E#$00#$05#$01#$7B#$6E);         { $AADB SUBTRACT [$6E7A], $05, [$6E7B] }
  DataPat.Put(#$03#$01#$45#$4A#$00#$0C);                     { $AAE4 COMPARE [$4A45], $0C }
  DataPat.Put(#$1A);                                         { $AAEA IF <= }
  DataPat.Put(#$01#$01#$10#$AB);                             { $AAEB GOTO LAB10 }
  DataPat.Put(#$09#$02#$00#$00#$01#$7B#$6E);                 { $AAEF SAVE $0000, [$6E7B] }
  DataPat.Put(#$05#$01#$45#$4A#$00#$15#$01#$7A#$6E);         { $AAF6 SUBTRACT [$4A45], $15, [$6E7A] }
  DataPat.Put(#$03#$01#$7A#$6E#$00#$05);                     { $AAFF COMPARE [$6E7A], $05 }
  DataPat.Put(#$1A);                                         { $AB05 IF <= }
  DataPat.Put(#$01#$01#$10#$AB);                             { $AB06 GOTO LAB10 }
  DataPat.Put(#$09#$00#$05#$01#$7A#$6E);                     { $AB0A SAVE $05, [$6E7A] }
  { #40 part 1, original }
  DataPat.Put(#$9A);
  { fixed: COMPARE [$4A1F], $01 }
  DataPat.Put(#$1F);
  { #40 part 2, original }
  DataPat.Put(#$9A);
  { fixed: SAVE $01, [$4A1F] }
  DataPat.Put(#$1F);
  { #40 part 3, original }
  DataPat.Put(#$9A);
  { fixed: SAVE $FF, [$4A1F] }
  DataPat.Put(#$1F);
  { #41, original }
  DataPat.Put(#$06);
  { fixed: plus 8 }
  DataPat.Put(#$08);
  { #42, original }
  DataPat.Put(#$81);
  { fixed: HORIZONTAL MENU [$6E7A] }
  DataPat.Put(#$7A);
  { #43, original }
  DataPat.Put(#$5E);
  { fixed: SUBTRACT [$4A5F], $0A, [$6E80] }
  DataPat.Put(#$5F);
  { #44, original }
  DataPat.Put(#$0A);
  { fixed: COMPARE [$4AA9], $00 }
  DataPat.Put(#$A9);
  { #45 part 1, original }
  DataPat.Put(#$78#$B6);
  { fixed: entry 4 moves to $B651 }
  DataPat.Put(#$51#$B6);
  { #45 part 2, original }
  DataPat.Put(#$64#$A6);
  { fixed: the quarters before dinner go by the new check at $B67D }
  DataPat.Put(#$7D#$B6);
  { #45 part 3, original }
  DataPat.Put(#$03#$01#$B4#$4A#$00#$00);                     { $B625 COMPARE [$4AB4], $00 }
  DataPat.Put(#$17);                                         { $B62B IF <> }
  DataPat.Put(#$01#$01#$48#$B6);                             { $B62C GOTO LB648 }
  DataPat.Put(#$03#$01#$0E#$4A#$00#$00);                     { $B630 COMPARE [$4A0E], $00 }
  DataPat.Put(#$16);                                         { $B636 IF = }
  DataPat.Put(#$01#$01#$48#$B6);                             { $B637 GOTO LB648 }
  DataPat.Put(#$09#$00#$64#$01#$D3#$6D);                     { $B63B SAVE $64, [$6DD3] }
  DataPat.Put(#$09#$00#$01#$01#$D2#$6D);                     { $B641 SAVE $01, [$6DD2] }
  DataPat.Put(#$00);                                         { $B647 EXIT }
  DataPat.Put(#$03#$01#$B4#$4A#$00#$00);                     { $B648 COMPARE [$4AB4], $00 }
  DataPat.Put(#$17);                                         { $B64E IF <> }
  DataPat.Put(#$01#$01#$6B#$B6);                             { $B64F GOTO LB66B }
  DataPat.Put(#$03#$01#$10#$4A#$00#$00);                     { $B653 COMPARE [$4A10], $00 }
  DataPat.Put(#$17);                                         { $B659 IF <> }
  DataPat.Put(#$01#$01#$3B#$B6);                             { $B65A GOTO LB63B }
  DataPat.Put(#$09#$00#$A8#$01#$D2#$6D);                     { $B65E SAVE $A8, [$6DD2] }
  DataPat.Put(#$09#$00#$64#$01#$D3#$6D);                     { $B664 SAVE $64, [$6DD3] }
  DataPat.Put(#$00);                                         { $B66A EXIT }
  DataPat.Put(#$09#$00#$00#$01#$D2#$6D);                     { $B66B SAVE $00, [$6DD2] }
  DataPat.Put(#$09#$00#$01#$01#$D3#$6D);                     { $B671 SAVE $01, [$6DD3] }
  DataPat.Put(#$00);                                         { $B677 EXIT }
  DataPat.Put(#$09#$00#$00#$01#$D3#$6D);                     { $B678 SAVE $00, [$6DD3] }
  DataPat.Put(#$03#$01#$10#$4A#$00#$00);                     { $B67E COMPARE [$4A10], $00 }
  DataPat.Put(#$16);                                         { $B684 IF = }
  DataPat.Put(#$01#$01#$DF#$A6);                             { $B685 GOTO LA6DF }
  DataPat.Put(#$09#$00#$39#$01#$E1#$6D);                     { $B689 SAVE $39, [$6DE1] }
  DataPat.Put(#$01#$01#$3E#$9A);                             { $B68F GOTO L9A3E }
  { fixed: entry 3, entry 4 and the quarters check, in the room entries 3 and 4 had }
  DataPat.Put(#$09#$00#$64#$01#$D3#$6D);                     { $B625 SAVE $64, [$6DD3] }
  DataPat.Put(#$09#$00#$A8#$01#$D2#$6D);                     { $B62B SAVE $A8, [$6DD2] }
  DataPat.Put(#$14#$01#$0E#$4A#$00#$00#$01#$10#$4A#$00#$00); { $B631 COMPARE AND [$4A0E], $00, [$4A10], $00 }
  DataPat.Put(#$17);                                         { $B63C IF <> }
  DataPat.Put(#$09#$00#$01#$01#$D2#$6D);                     { $B63D SAVE $01, [$6DD2] }
  DataPat.Put(#$03#$01#$B4#$4A#$00#$00);                     { $B643 COMPARE [$4AB4], $00 }
  DataPat.Put(#$17);                                         { $B649 IF <> }
  DataPat.Put(#$09#$00#$00#$01#$D2#$6D);                     { $B64A SAVE $00, [$6DD2] }
  DataPat.Put(#$00);                                         { $B650 EXIT }
  DataPat.Put(#$09#$00#$00#$01#$D3#$6D);                     { $B651 SAVE $00, [$6DD3] }
  DataPat.Put(#$03#$01#$10#$4A#$00#$00);                     { $B657 COMPARE [$4A10], $00 }
  DataPat.Put(#$17);                                         { $B65D IF <> }
  DataPat.Put(#$01#$01#$73#$B6);                             { $B65E GOTO LB673 }
  DataPat.Put(#$03#$01#$0E#$4A#$00#$00);                     { $B662 COMPARE [$4A0E], $00 }
  DataPat.Put(#$16);                                         { $B668 IF = }
  DataPat.Put(#$01#$01#$DF#$A6);                             { $B669 GOTO LA6DF }
  DataPat.Put(#$09#$00#$04#$01#$79#$6E);                     { $B66D SAVE $04, [$6E79] }
  DataPat.Put(#$09#$00#$39#$01#$E1#$6D);                     { $B673 SAVE $39, [$6DE1] }
  DataPat.Put(#$01#$01#$3E#$9A);                             { $B679 GOTO L9A3E }
  DataPat.Put(#$14#$01#$0E#$4A#$00#$00#$01#$B4#$4A#$00#$00); { $B67D COMPARE AND [$4A0E], $00, [$4AB4], $00 }
  DataPat.Put(#$16);                                         { $B688 IF = }
  DataPat.Put(#$01#$01#$64#$A6);                             { $B689 GOTO LA664 }
  DataPat.Put(#$01#$01#$E7#$B5);                             { $B68D GOTO LB5E7 }
  DataPat.Put(#$00#$00);
  { #46, original }
  DataPat.Put(#$80);
  { fixed: event 5 }
  DataPat.Put(#$85);
  { #47, original }
  DataPat.Put(#$0D#$41#$4C#$2D#$48#$59#$41#$4D#$20#$44#$41#$5A#$49#$44#$00#$00);
  { fixed: ZHENTARIM MAGE }
  DataPat.Put(#$0E#$5A#$48#$45#$4E#$54#$41#$52#$49#$4D#$20#$4D#$41#$47#$45#$00);
  { #48 part 1, original }
  DataPat.Put(#$1A);
  { fixed: the paladin's crypt gives item block 29 }
  DataPat.Put(#$1D);
  { #48 part 2, original }
  DataPat.Put(#$1D);
  { fixed: the knight's tomb gives item block 26 }
  DataPat.Put(#$1A);
  { #49, original }
  DataPat.Put(#$03);
  { fixed: SAVE $02, [$4A78] }
  DataPat.Put(#$02);
  { #50 part 1, original }
  DataPat.Put(#$01#$01#$5D#$A7);                             { $ACF8 GOTO LA75D }
  { fixed: on to new code at the end of the script }
  DataPat.Put(#$01#$01#$DD#$B1);                             { $ACF8 GOTO LB1DD }
  { #50 part 2, added at $B1DD: hostile from now on, then the weapons menu as before }
  DataPat.Put(#$09#$00#$03#$01#$78#$4A);                     { $B1DD SAVE $03, [$4A78] }
  DataPat.Put(#$01#$01#$5D#$A7);                             { $B1E3 GOTO LA75D }
  { #51, original }
  DataPat.Put(#$00#$98);
  { fixed: ADD $01, [$4A62], [$4A64] }
  DataPat.Put(#$62#$4A);
  { #52 part 1, original }
  DataPat.Put(#$09#$00#$00#$01#$CB#$6D);                     { $B10F SAVE $00, [$6DCB] }
  { fixed: the fight goes to $B1E7 }
  DataPat.Put(#$01#$01#$E7#$B1);                             { $B10F GOTO LB1E7 }
  DataPat.Put(#$00#$00);
  { #52 part 2, added at $B1E7: one garrison per tower still standing }
  DataPat.Put(#$09#$00#$00#$01#$CB#$6D);                     { $B1E7 SAVE $00, [$6DCB] }
  DataPat.Put(#$09#$00#$50#$01#$C6#$6D);                     { $B1ED SAVE $50, [$6DC6] }
  DataPat.Put(#$09#$00#$01#$01#$7B#$6E);                     { $B1F3 SAVE $01, [$6E7B] }
  DataPat.Put(#$2F#$01#$77#$4A#$00#$0C#$01#$82#$6E);         { $B1F9 AND [$4A77], $0C, [$6E82] }
  DataPat.Put(#$16);                                         { $B202 IF = }
  DataPat.Put(#$09#$00#$02#$01#$7B#$6E);                     { $B203 SAVE $02, [$6E7B] }
  DataPat.Put(#$09#$00#$18#$01#$7C#$6E);                     { $B209 SAVE $18, [$6E7C] }
  DataPat.Put(#$2F#$01#$77#$4A#$00#$08#$01#$82#$6E);         { $B20F AND [$4A77], $08, [$6E82] }
  DataPat.Put(#$17);                                         { $B218 IF <> }
  DataPat.Put(#$09#$00#$59#$01#$7C#$6E);                     { $B219 SAVE $59, [$6E7C] }
  DataPat.Put(#$02#$01#$E2#$9B);                             { $B21F GOSUB L9BE2 }
  DataPat.Put(#$1C);                                         { $B223 CLEARMONSTERS }
  DataPat.Put(#$0B#$01#$7C#$6E#$01#$7B#$6E#$00#$0E);         { $B224 LOAD MONSTER [$6E7C], [$6E7B], $0E }
  DataPat.Put(#$0B#$00#$35#$01#$7B#$6E#$00#$0B);             { $B22D LOAD MONSTER $35, [$6E7B], $0B }
  DataPat.Put(#$07#$01#$7B#$6E#$00#$03#$01#$7B#$6E);         { $B235 MULTIPLY [$6E7B], $03, [$6E7B] }
  DataPat.Put(#$0B#$00#$47#$01#$7B#$6E#$00#$47);             { $B23E LOAD MONSTER $47, [$6E7B], $47 }
  DataPat.Put(#$01#$01#$35#$B1);                             { $B246 GOTO LB135 }
  { #54, original }
  DataPat.Put(#$1B);                                         { $A9EE IF >= }
  { fixed: IF < }
  DataPat.Put(#$18);                                         { $A9EE IF < }
  { #55, original }
  DataPat.Put(#$72);
  { fixed: OR [$4A6D], $10, [$4A6D] }
  DataPat.Put(#$6D);
  { #70 part 1, original }
  DataPat.Put(#$10);
  { fixed: (4,15) south: solid }
  DataPat.Put(#$00);
  { #70 part 2, original }
  DataPat.Put(#$10);
  { fixed: (11,15) south: solid }
  DataPat.Put(#$00);
  { #203, original }
  DataPat.Put(#$5C#$AA#$A7#$58#$02#$00);
  { fixed: type 92, Cloak of Displacement, plus 2, save bonus 2 }
  DataPat.Put(#$5C#$AA#$A7#$58#$02#$02);
  { #203, original }
  DataPat.Put(#$43#$AA#$A7#$58#$08#$00);
  { fixed: type 92, Cloak of Displacement, plus 2, save bonus 2 }
  DataPat.Put(#$5C#$AA#$A7#$58#$02#$02);
  { #355 part 1, original }
  DataPat.Put(#$04#$00#$01#$01#$00#$4A#$01#$00#$4A);         { $9AE6 ADD $01, [$4A00], [$4A00] }
  DataPat.Put(#$00);                                         { $9AEF EXIT }
  { fixed: after the notice, on to new code at the end of the script }
  DataPat.Put(#$01#$01#$79#$A1);                             { $9AE6 GOTO LA179 }
  DataPat.Put(#$00#$00#$00#$00#$00#$00);
  { #355 part 2, added at $A179: the paladin and ranger sentence, then the notice is marked read as before }
  { $A179 PRINT "  PALADINS AND RANGERS TRAIN WITH THE FIGHTERS." }
  DataPat.Put(#$11#$80#$24#$82#$04#$01#$30#$11#$09#$39#$38#$01#$38#$48#$12#$04);
  DataPat.Put(#$E1#$C5#$49#$38#$14#$48#$12#$4E#$81#$72#$54#$22#$05#$08#$16#$01);
  DataPat.Put(#$89#$1C#$85#$05#$49#$3B#$80);
  DataPat.Put(#$04#$00#$01#$01#$00#$4A#$01#$00#$4A);         { $A1A0 ADD $01, [$4A00], [$4A00] }
  DataPat.Put(#$00);                                         { $A1A9 EXIT }
  { #606 part 1, original }
  DataPat.Put(#$C6#$A2);                                     { $9B8F ON GOTO [$9800] entry 20: LA2C6 }
  { fixed: event 20 goes to new code at the end of the script }
  DataPat.Put(#$2F#$B6);                                     { $9B8F ON GOTO [$9800] entry 20: LB62F }
  { #606 part 2, added at $B62F: the tavern but at (8,9); there, as the arms shop, the shopkeeper, then the vault }
  DataPat.Put(#$14#$01#$4B#$C0#$00#$08#$01#$4C#$C0#$00#$09); { $B62F COMPARE AND [$C04B], $08, [$C04C], $09 }
  DataPat.Put(#$17);                                         { $B63A IF <> }
  DataPat.Put(#$01#$01#$C6#$A2);                             { $B63B GOTO LA2C6 }
  DataPat.Put(#$02#$01#$89#$AE);                             { $B63F GOSUB LAE89 }
  DataPat.Put(#$09#$00#$2A#$01#$E1#$6D);                     { $B643 SAVE $2A, [$6DE1] }
  DataPat.Put(#$0E#$00#$09);                                 { $B649 PICTURE $09 }
  DataPat.Put(#$03#$01#$C0#$4A#$00#$00);                     { $B64C COMPARE [$4AC0], $00 }
  DataPat.Put(#$19);                                         { $B652 IF > }
  DataPat.Put(#$01#$01#$1D#$AE);                             { $B653 GOTO LAE1D }
  DataPat.Put(#$1C);                                         { $B657 CLEARMONSTERS }
  DataPat.Put(#$09#$00#$02#$01#$6C#$6E);                     { $B658 SAVE $02, [$6E6C] }
  DataPat.Put(#$24);                                         { $B65E COMBAT }
  DataPat.Put(#$0E#$00#$FF);                                 { $B65F PICTURE $FF }
  DataPat.Put(#$00);                                         { $B662 EXIT }
  { #670, original: ...BE?'WHAT DO YOU DO? }
  DataPat.Put(#$5C#$80#$54#$80#$43#$E0#$64#$F5#$60#$10#$FF#$C0);
  { fixed: ...BE?' WHAT DO YOU DO? }
  DataPat.Put(#$81#$72#$01#$52#$01#$0F#$81#$93#$D5#$80#$43#$FF);
  { #682 part 1, original }
  DataPat.Put(#$03#$01#$02#$4A#$00#$01);                     { $A8B0 COMPARE [$4A02], $01 }
  DataPat.Put(#$16);                                         { $A8B6 IF = }
  DataPat.Put(#$01#$01#$0B#$AA);                             { $A8B7 GOTO LAA0B }
  { fixed: the altar goes by new code at the end of the script }
  DataPat.Put(#$01#$01#$E6#$B6);                             { $A8B0 GOTO LB6E6 }
  DataPat.Put(#$00#$00#$00#$00#$00#$00#$00);
  { #682 part 2, original }
  DataPat.Put(#$A3#$B0);                                     { $AC59 GOTO LB0A3 }
  { fixed: no Dirten in the party, by new code }
  DataPat.Put(#$50#$B8);                                     { $AC59 GOTO LB850 }
  { #682 part 3, original }
  DataPat.Put(#$03#$01#$00#$6C#$00#$7F);                     { $AC68 COMPARE [$6C00], $7F }
  DataPat.Put(#$19);                                         { $AC6E IF > }
  DataPat.Put(#$01#$01#$C3#$AC);                             { $AC6F GOTO LACC3 }
  { fixed: Dirten in the party, by new code }
  DataPat.Put(#$01#$01#$F5#$B7);                             { $AC68 GOTO LB7F5 }
  DataPat.Put(#$00#$00#$00#$00#$00#$00#$00);
  { #682 part 4, added at $B6E6: the altar once the temple is freed: no day kept (a game from before this whose
    party had Dirten) starts the days now; freed without him, as before; before 14 days, the rebuilding }
  DataPat.Put(#$03#$01#$BD#$4A#$00#$FE);                     { $B6E6 COMPARE [$4ABD], $FE }
  DataPat.Put(#$18);                                         { $B6EC IF < }
  DataPat.Put(#$01#$01#$E6#$B7);                             { $B6ED GOTO LB7E6 }
  DataPat.Put(#$03#$01#$79#$4A#$00#$00);                     { $B6F1 COMPARE [$4A79], $00 }
  DataPat.Put(#$17);                                         { $B6F7 IF <> }
  DataPat.Put(#$01#$01#$0B#$B7);                             { $B6F8 GOTO LB70B }
  DataPat.Put(#$03#$01#$9C#$4A#$00#$FF);                     { $B6FC COMPARE [$4A9C], $FF }
  DataPat.Put(#$17);                                         { $B702 IF <> }
  DataPat.Put(#$01#$01#$E6#$B7);                             { $B703 GOTO LB7E6 }
  DataPat.Put(#$02#$01#$5B#$B8);                             { $B707 GOSUB LB85B }
  DataPat.Put(#$03#$01#$79#$4A#$02#$FF#$FF);                 { $B70B COMPARE [$4A79], $FFFF }
  DataPat.Put(#$16);                                         { $B712 IF = }
  DataPat.Put(#$01#$01#$E6#$B7);                             { $B713 GOTO LB7E6 }
  DataPat.Put(#$02#$01#$67#$B8);                             { $B717 GOSUB LB867 }
  DataPat.Put(#$05#$01#$79#$4A#$01#$7B#$6E#$01#$7B#$6E);     { $B71B SUBTRACT [$4A79], [$6E7B], [$6E7B] }
  DataPat.Put(#$03#$01#$7B#$6E#$00#$0E);                     { $B725 COMPARE [$6E7B], $0E }
  DataPat.Put(#$1B);                                         { $B72B IF >= }
  DataPat.Put(#$01#$01#$77#$B7);                             { $B72C GOTO LB777 }
  { $B730 PRINTCLEAR "THE EFFORT TO REBUILD IS ALREADY UNDERWAY. SOON THE TEMPLE WILL BE SERVICEABLE AGAIN." }
  DataPat.Put(#$12#$80#$40#$50#$81#$60#$14#$61#$8F#$49#$48#$14#$3E#$04#$85#$09);
  DataPat.Put(#$52#$4C#$12#$02#$53#$80#$13#$12#$14#$11#$19#$81#$53#$84#$15#$25);
  DataPat.Put(#$C1#$66#$E8#$13#$3C#$F3#$A0#$50#$81#$60#$50#$53#$50#$30#$58#$17);
  DataPat.Put(#$24#$C3#$20#$08#$58#$13#$15#$25#$89#$0C#$50#$42#$30#$58#$01#$1C);
  DataPat.Put(#$12#$4E#$B8);
  DataPat.Put(#$01#$01#$A3#$B0);                             { $B773 GOTO LB0A3 }
  { #682 part 5, added at $B777: Dirten's welcome and his temple, a tenth off }
  DataPat.Put(#$09#$00#$00#$01#$E1#$6D);                     { $B777 SAVE $00, [$6DE1] }
  DataPat.Put(#$0E#$00#$04);                                 { $B77D PICTURE $04 }
  { $B780 PRINTCLEAR "WELCOME BACK! WE'RE STILL REBUILDING, BUT LET ME OFFER WHAT AID I CAN." }
  DataPat.Put(#$12#$80#$35#$5C#$53#$03#$3C#$D1#$60#$08#$10#$CB#$86#$05#$C5#$9D);
  DataPat.Put(#$21#$60#$4D#$42#$4C#$32#$04#$85#$09#$52#$4C#$10#$93#$87#$B2#$00);
  DataPat.Put(#$95#$52#$03#$05#$52#$03#$45#$80#$F1#$86#$15#$28#$17#$20#$15#$20);
  DataPat.Put(#$04#$91#$20#$26#$00#$C1#$3A#$E0);
  { $B7B8 HORIZONTAL MENU [$6E79], $01, "PRESS <RETURN> TO CONTINUE" }
  DataPat.Put(#$2B#$01#$79#$6E#$00#$01#$80#$14#$41#$21#$53#$4E#$0F#$12#$15#$45);
  DataPat.Put(#$52#$3B#$E8#$14#$3E#$00#$CF#$39#$42#$4E#$54#$50);
  DataPat.Put(#$1C);                                         { $B7D4 CLEARMONSTERS }
  DataPat.Put(#$09#$00#$02#$01#$E2#$6D);                     { $B7D5 SAVE $02, [$6DE2] }
  DataPat.Put(#$24);                                         { $B7DB COMBAT }
  DataPat.Put(#$09#$00#$FF#$01#$E1#$6D);                     { $B7DC SAVE $FF, [$6DE1] }
  DataPat.Put(#$01#$01#$A3#$B0);                             { $B7E2 GOTO LB0A3 }
  { #682 part 6, added at $B7E6: the altar as before; the end of the fight with Dirten, and without him; the day }
  DataPat.Put(#$03#$01#$02#$4A#$00#$01);                     { $B7E6 COMPARE [$4A02], $01 }
  DataPat.Put(#$16);                                         { $B7EC IF = }
  DataPat.Put(#$01#$01#$0B#$AA);                             { $B7ED GOTO LAA0B }
  DataPat.Put(#$01#$01#$BB#$A8);                             { $B7F1 GOTO LA8BB }
  DataPat.Put(#$02#$01#$5B#$B8);                             { $B7F5 GOSUB LB85B }
  DataPat.Put(#$03#$01#$00#$6C#$00#$7F);                     { $B7F9 COMPARE [$6C00], $7F }
  DataPat.Put(#$19);                                         { $B7FF IF > }
  DataPat.Put(#$01#$01#$08#$B8);                             { $B800 GOTO LB808 }
  DataPat.Put(#$01#$01#$73#$AC);                             { $B804 GOTO LAC73 }
  { $B808 PRINTCLEAR "THE TEMPLE GUARDS ENTER AND SECURE THE AREA. A CLERIC RUSHES TO AID THE FALLEN DIRTEN." }
  DataPat.Put(#$12#$80#$41#$50#$81#$60#$50#$53#$50#$30#$58#$07#$54#$14#$84#$4E);
  DataPat.Put(#$01#$4E#$50#$54#$A0#$04#$E1#$20#$4C#$50#$D5#$48#$58#$14#$20#$58);
  DataPat.Put(#$01#$48#$50#$6E#$80#$18#$03#$30#$54#$89#$0E#$04#$95#$4C#$81#$53);
  DataPat.Put(#$81#$43#$E0#$04#$91#$20#$50#$81#$60#$18#$13#$0C#$14#$E8#$04#$25);
  DataPat.Put(#$25#$05#$3A#$E0);
  DataPat.Put(#$01#$01#$C3#$AC);                             { $B84C GOTO LACC3 }
  DataPat.Put(#$09#$02#$FF#$FF#$01#$79#$4A);                 { $B850 SAVE $FFFF, [$4A79] }
  DataPat.Put(#$01#$01#$A3#$B0);                             { $B857 GOTO LB0A3 }
  DataPat.Put(#$02#$01#$67#$B8);                             { $B85B GOSUB LB867 }
  DataPat.Put(#$09#$01#$7B#$6E#$01#$79#$4A);                 { $B85F SAVE [$6E7B], [$4A79] }
  DataPat.Put(#$13);                                         { $B866 RETURN }
  DataPat.Put(#$07#$01#$CC#$49#$02#$68#$01#$01#$7B#$6E);     { $B867 MULTIPLY [$49CC], $0168, [$6E7B] }
  DataPat.Put(#$07#$01#$CB#$49#$00#$1E#$01#$7C#$6E);         { $B871 MULTIPLY [$49CB], $1E, [$6E7C] }
  DataPat.Put(#$04#$01#$7C#$6E#$01#$7B#$6E#$01#$7B#$6E);     { $B87A ADD [$6E7C], [$6E7B], [$6E7B] }
  DataPat.Put(#$04#$01#$CA#$49#$01#$7B#$6E#$01#$7B#$6E);     { $B884 ADD [$49CA], [$6E7B], [$6E7B] }
  DataPat.Put(#$04#$00#$01#$01#$7B#$6E#$01#$7B#$6E);         { $B88E ADD $01, [$6E7B], [$6E7B] }
  DataPat.Put(#$13);                                         { $B897 RETURN }
  { #683 part 1, original }
  DataPat.Put(#$A8#$A1);                                     { $9D8E ON GOTO [$6E79] entry 1: LA1A8 }
  { fixed: event 1, the west barracks, goes to new code at the end of the script }
  DataPat.Put(#$5A#$B2);                                     { $9D8E ON GOTO [$6E79] entry 1: LB25A }
  { #683 part 2, original }
  DataPat.Put(#$C9#$A2);                                     { $9D91 ON GOTO [$6E79] entry 2: LA2C9 }
  { fixed: event 2, the east barracks, likewise }
  DataPat.Put(#$6D#$B2);                                     { $9D91 ON GOTO [$6E79] entry 2: LB26D }
  { #683 part 3, original }
  DataPat.Put(#$A1#$A0);                                     { $9DA0 ON GOTO [$6E79] entry 7: LA0A1 }
  { fixed: event 7, (7,9) and (8,9), likewise }
  DataPat.Put(#$CC#$B2);                                     { $9DA0 ON GOTO [$6E79] entry 7: LB2CC }
  { #683 part 4, original }
  DataPat.Put(#$81#$B0);                                     { $9DB2 ON GOTO [$6E79] entry 13: LB081 }
  { fixed: event 13, (7,6) and (8,6), likewise }
  DataPat.Put(#$DF#$B2);                                     { $9DB2 ON GOTO [$6E79] entry 13: LB2DF }
  { #683 part 5, original }
  DataPat.Put(#$6A#$A1);                                     { $A11F GOTO LA16A }
  { fixed: through the gatehouse by new code once the gate is taken }
  DataPat.Put(#$40#$B3);                                     { $A11F GOTO LB340 }
  { #683 part 6, added at $B24A: the gate taken, as the script counts it (both barracks and the bugbears); the
    barracks' new text, once a visit }
  DataPat.Put(#$2F#$01#$77#$4A#$00#$1C#$01#$82#$6E);         { $B24A AND [$4A77], $1C, [$6E82] }
  DataPat.Put(#$03#$01#$82#$6E#$00#$1C);                     { $B253 COMPARE [$6E82], $1C }
  DataPat.Put(#$13);                                         { $B259 RETURN }
  DataPat.Put(#$02#$01#$4A#$B2);                             { $B25A GOSUB LB24A }
  DataPat.Put(#$17);                                         { $B25E IF <> }
  DataPat.Put(#$01#$01#$A8#$A1);                             { $B25F GOTO LA1A8 }
  DataPat.Put(#$09#$00#$01#$01#$7A#$6E);                     { $B263 SAVE $01, [$6E7A] }
  DataPat.Put(#$01#$01#$7C#$B2);                             { $B269 GOTO LB27C }
  DataPat.Put(#$02#$01#$4A#$B2);                             { $B26D GOSUB LB24A }
  DataPat.Put(#$17);                                         { $B271 IF <> }
  DataPat.Put(#$01#$01#$C9#$A2);                             { $B272 GOTO LA2C9 }
  DataPat.Put(#$09#$00#$02#$01#$7A#$6E);                     { $B276 SAVE $02, [$6E7A] }
  DataPat.Put(#$2F#$01#$01#$4A#$01#$7A#$6E#$01#$82#$6E);     { $B27C AND [$4A01], [$6E7A], [$6E82] }
  DataPat.Put(#$17);                                         { $B286 IF <> }
  DataPat.Put(#$00);                                         { $B287 EXIT }
  DataPat.Put(#$30#$01#$01#$4A#$01#$7A#$6E#$01#$01#$4A);     { $B288 OR [$4A01], [$6E7A], [$4A01] }
  { $B292 PRINTCLEAR "MAKESHIFT BARRACKS HAVE BEEN ERECTED HERE FOR HOUSING NEW PHLAN TROOPS." }
  DataPat.Put(#$12#$80#$36#$34#$12#$C5#$4C#$82#$46#$52#$00#$81#$49#$20#$43#$2D);
  DataPat.Put(#$38#$08#$05#$61#$60#$08#$51#$4E#$80#$54#$85#$0D#$41#$44#$80#$81);
  DataPat.Put(#$52#$16#$01#$8F#$4A#$02#$0F#$55#$32#$4E#$1E#$03#$85#$5E#$04#$08);
  DataPat.Put(#$30#$13#$A0#$51#$23#$CF#$41#$3B#$80);
  DataPat.Put(#$00);                                         { $B2CB EXIT }
  { #683 part 7, added at $B2CC: the cheer at (7,9) and (8,9), or at (7,6) and (8,6), once a visit between them
    (C_GBVM.STOJANOW_CHEERED, #1068), without a portrait; then the way through the gatehouse }
  DataPat.Put(#$02#$01#$4A#$B2);                             { $B2CC GOSUB LB24A }
  DataPat.Put(#$17);                                         { $B2D0 IF <> }
  DataPat.Put(#$01#$01#$A1#$A0);                             { $B2D1 GOTO LA0A1 }
  DataPat.Put(#$09#$00#$04#$01#$7A#$6E);                     { $B2D5 SAVE $04, [$6E7A] }
  DataPat.Put(#$01#$01#$EE#$B2);                             { $B2DB GOTO LB2EE }
  DataPat.Put(#$02#$01#$4A#$B2);                             { $B2DF GOSUB LB24A }
  DataPat.Put(#$17);                                         { $B2E3 IF <> }
  DataPat.Put(#$01#$01#$81#$B0);                             { $B2E4 GOTO LB081 }
  DataPat.Put(#$09#$00#$04#$01#$7A#$6E);                     { $B2E8 SAVE $04, [$6E7A] }
  DataPat.Put(#$2F#$01#$01#$4A#$01#$7A#$6E#$01#$82#$6E);     { $B2EE AND [$4A01], [$6E7A], [$6E82] }
  DataPat.Put(#$17);                                         { $B2F8 IF <> }
  DataPat.Put(#$00);                                         { $B2F9 EXIT }
  DataPat.Put(#$30#$01#$01#$4A#$01#$7A#$6E#$01#$01#$4A);     { $B2FA OR [$4A01], [$6E7A], [$4A01] }
  { $B304 PRINTCLEAR "THE GUARDS ON THE WALL RAISE A CHEER AS YOU PASS. 'HAIL, HEROES OF PHLAN!'" }
  DataPat.Put(#$12#$80#$38#$50#$81#$60#$1D#$50#$52#$11#$38#$0F#$3A#$05#$08#$16);
  DataPat.Put(#$05#$C1#$30#$C8#$12#$04#$94#$C5#$80#$18#$03#$20#$51#$52#$80#$14);
  DataPat.Put(#$E0#$64#$F5#$60#$40#$14#$D3#$BA#$09#$C8#$04#$93#$2C#$80#$81#$52);
  DataPat.Put(#$3C#$54#$E0#$3C#$68#$10#$20#$C0#$4E#$86#$70);
  DataPat.Put(#$00);                                         { $B33F EXIT }
  DataPat.Put(#$02#$01#$4A#$B2);                             { $B340 GOSUB LB24A }
  DataPat.Put(#$17);                                         { $B344 IF <> }
  DataPat.Put(#$01#$01#$6A#$A1);                             { $B345 GOTO LA16A }
  DataPat.Put(#$2A#$01#$96#$A1#$01#$7D#$6E#$01#$4B#$C0);     { $B349 GETTABLE [$A196], [$6E7D], [$C04B] }
  DataPat.Put(#$2A#$01#$9C#$A1#$01#$7D#$6E#$01#$4C#$C0);     { $B353 GETTABLE [$A19C], [$6E7D], [$C04C] }
  DataPat.Put(#$2A#$01#$A2#$A1#$01#$7D#$6E#$01#$4F#$C0);     { $B35D GETTABLE [$A1A2], [$6E7D], [$C04F] }
  DataPat.Put(#$09#$00#$FF#$01#$C9#$6D);                     { $B367 SAVE $FF, [$6DC9] }
  DataPat.Put(#$2D#$01#$90#$2C);                             { $B36D CALL [$2C90] }
  DataPat.Put(#$00);                                         { $B371 EXIT }
  { #748, MON2CHA gnoll, original }
  DataPat.Put(#$02);
  { fixed: two tiles and Large }
  DataPat.Put(#$82);
  { #748, MON8CHA gnoll, original }
  DataPat.Put(#$02);
  { fixed }
  DataPat.Put(#$82);
  { #748, MON8CHA phase spider, original }
  DataPat.Put(#$03);
  { fixed }
  DataPat.Put(#$83);
  { #792, MON1CHA ogre leader, original }
  DataPat.Put(#$01);
  { fixed: one tile and Large }
  DataPat.Put(#$81);
  { #864 part 1, original }
  DataPat.Put(#$21#$AD);                                     { $AC8B ON GOSUB [$4A18] entry 9: LAD21 }
  { fixed: the ninth proclamation goes to new code at the end of the script }
  DataPat.Put(#$63#$B6);                                     { $AC8B ON GOSUB [$4A18] entry 9: LB663 }
  { #864 part 2, added at $B663: the ninth proclamation, CCXIV }
  DataPat.Put(#$09#$80#$05#$0C#$36#$09#$5A#$E0#$81#$5E#$98); { $B663 SAVE "CCXIV.", str[$985E] }
  DataPat.Put(#$13);                                         { $B66E RETURN }
  { #868 GEO3 part 1, original }
  DataPat.Put(#$06);
  { fixed: (14,12) east: the room's door, open }
  DataPat.Put(#$0A);
  { #868 GEO3 part 2, original }
  DataPat.Put(#$06);
  { fixed: (15,13) north: a wall }
  DataPat.Put(#$66);
  { #868 GEO3 part 3, original }
  DataPat.Put(#$06);
  { fixed: (15,12) south: a wall; west: the door }
  DataPat.Put(#$6A);
  { #868 GEO3 part 4, original: (14,12) and (15,12) pass no way }
  DataPat.Put(#$00#$00);
  { fixed: (14,12) east and (15,12) west pass }
  DataPat.Put(#$04#$40);
  { #868 Slums part 1, original }
  DataPat.Put(#$BC#$B6);                                     { $A755 GOSUB LB6BC, after the fortune teller is murdered }
  { fixed: the GOSUB goes to new code at the end of the script }
  DataPat.Put(#$FD#$B6);                                     { $A755 GOSUB LB6FD }
  { #868 Slums part 2, added at $B6FD: her murder remembered, then the continue prompt }
  DataPat.Put(#$09#$00#$01#$01#$53#$4A);                     { $B6FD SAVE $01, [$4A53] }
  DataPat.Put(#$01#$01#$BC#$B6);                             { $B703 GOTO LB6BC }
  { #868 New Phlan part 1, original }
  DataPat.Put(#$2F#$B6);                                     { $9B8F ON GOTO [$9800] entry 20: LB62F }
  { fixed: event 20 goes to new code at the end of the script }
  DataPat.Put(#$6F#$B6);                                     { $9B8F ON GOTO [$9800] entry 20: LB66F }
  { #868 New Phlan part 2, added at $B66F: #606's code but at (15,12); there the greeting once a visit, then, once the
    Slums are cleared with the fortune teller alive, as the shops, the sage; otherwise her empty shop, and her
    shattered crystal ball if she was murdered }
  DataPat.Put(#$14#$01#$4B#$C0#$00#$0F#$01#$4C#$C0#$00#$0C); { $B66F COMPARE AND [$C04B], $0F, [$C04C], $0C }
  DataPat.Put(#$17);                                         { $B67A IF <> }
  DataPat.Put(#$01#$01#$2F#$B6);                             { $B67B GOTO LB62F }
  DataPat.Put(#$02#$01#$89#$AE);                             { $B67F GOSUB LAE89 }
  DataPat.Put(#$03#$01#$BB#$4A#$00#$FE);                     { $B683 COMPARE [$4ABB], $FE }
  DataPat.Put(#$18);                                         { $B689 IF < }
  DataPat.Put(#$01#$01#$BA#$B6);                             { $B68A GOTO LB6BA }
  DataPat.Put(#$03#$01#$53#$4A#$00#$00);                     { $B68E COMPARE [$4A53], $00 }
  DataPat.Put(#$17);                                         { $B694 IF <> }
  DataPat.Put(#$01#$01#$BA#$B6);                             { $B695 GOTO LB6BA }
  DataPat.Put(#$09#$00#$19#$01#$E1#$6D);                     { $B699 SAVE $19, [$6DE1] }
  DataPat.Put(#$0E#$00#$0D);                                 { $B69F PICTURE $0D }
  DataPat.Put(#$03#$01#$C0#$4A#$00#$00);                     { $B6A2 COMPARE [$4AC0], $00 }
  DataPat.Put(#$19);                                         { $B6A8 IF > }
  DataPat.Put(#$01#$01#$1D#$AE);                             { $B6A9 GOTO LAE1D }
  DataPat.Put(#$38#$00#$0A);                                 { $B6AD PROGRAM $0A }
  DataPat.Put(#$09#$00#$FF#$01#$E1#$6D);                     { $B6B0 SAVE $FF, [$6DE1] }
  DataPat.Put(#$0E#$00#$FF);                                 { $B6B6 PICTURE $FF }
  DataPat.Put(#$00);                                         { $B6B9 EXIT }
  DataPat.Put(#$12#$80#$10);                                 { $B6BA PRINTCLEAR "A BARE, RICKETY SHOP." }
  DataPat.Put(#$06#$00#$81#$48#$5B#$20#$48#$90#$CB#$15#$46#$60);
  DataPat.Put(#$4C#$83#$D0#$B8);
  DataPat.Put(#$03#$01#$53#$4A#$00#$00);                     { $B6CD COMPARE [$4A53], $00 }
  DataPat.Put(#$17);                                         { $B6D3 IF <> }
  DataPat.Put(#$11#$80#$44);                                 { $B6D4 PRINT, after the PRINTCLEAR: }
  { " THE ONLY CONTENT OF NOTE IS A SHATTERED CRYSTAL BALL, ITS PIECES STREWN ACROSS THE FLOOR." }
  DataPat.Put(#$81#$42#$05#$80#$F3#$8C#$66#$00#$CF#$39#$41#$4E);
  DataPat.Put(#$52#$03#$C6#$80#$E3#$D4#$16#$02#$53#$80#$18#$13);
  DataPat.Put(#$20#$15#$14#$15#$21#$44#$80#$34#$99#$4D#$40#$4C);
  DataPat.Put(#$80#$20#$4C#$32#$C8#$09#$51#$38#$10#$24#$50#$C5);
  DataPat.Put(#$4E#$04#$D4#$48#$55#$CE#$80#$10#$D2#$3D#$34#$E0);
  DataPat.Put(#$50#$81#$60#$18#$C3#$CF#$4A#$E0);
  DataPat.Put(#$00);                                         { $B71B EXIT }
  { #1092 part 1, original }
  DataPat.Put(#$2F#$01#$6D#$4A#$00#$01#$01#$82#$6E);         { $A3E1 AND [$4A6D], $01, [$6E82] }
  { fixed: to the new test }
  DataPat.Put(#$01#$01#$07#$A9);                             { $A3E1 GOTO LA907 }
  DataPat.Put(#$00#$00#$00#$00#$00);
  { #1092 part 2, added at $A907: Tyranthraxus beaten, Genheeris stays }
  DataPat.Put(#$2F#$01#$6D#$4A#$00#$10#$01#$82#$6E);         { $A907 AND [$4A6D], $10, [$6E82] }
  DataPat.Put(#$17);                                         { $A910 IF <> }
  DataPat.Put(#$00);                                         { $A911 EXIT }
  DataPat.Put(#$2F#$01#$6D#$4A#$00#$01#$01#$82#$6E);         { $A912 AND [$4A6D], $01, [$6E82] }
  DataPat.Put(#$01#$01#$EA#$A3);                             { $A91B GOTO LA3EA }
  { #1093, original: the packed text of the PRINTCLEAR at $B10A }
  { "TO FIND ANYTHING MORE YOU WILL HAVE TO SPEND SO MUCH TIME THAT YOU WILL NEED TO CLEAR THE AREA FIRST." }
  DataPat.Put(#$50#$F8#$06#$24#$E1#$20#$04#$E6#$54#$20#$93#$87#$80#$D3#$D2#$16);
  DataPat.Put(#$06#$4F#$56#$05#$C9#$30#$C8#$08#$05#$61#$60#$50#$F8#$13#$40#$53);
  DataPat.Put(#$84#$81#$33#$E0#$35#$50#$C8#$81#$42#$4D#$16#$05#$08#$05#$48#$19);
  DataPat.Put(#$3D#$58#$17#$24#$C3#$20#$38#$51#$44#$81#$43#$E0#$0C#$C1#$41#$4A);
  DataPat.Put(#$05#$08#$16#$00#$52#$14#$18#$06#$25#$24#$D4#$B8);
  { fixed: "YOU FIND NOTHING MORE OF INTEREST IN THE RECORDS.", its unused six-bit slots empty }
  DataPat.Put(#$64#$F5#$60#$18#$93#$84#$80#$E3#$D4#$20#$93#$87#$80#$D3#$D2#$16);
  DataPat.Put(#$03#$C6#$80#$93#$94#$15#$21#$53#$52#$02#$4E#$81#$42#$05#$81#$21);
  DataPat.Put(#$43#$3D#$21#$13#$B8#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00);
  DataPat.Put(#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00);
  DataPat.Put(#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00);
  { #1096 part 1, original }
  DataPat.Put(#$6E#$B0);                                     { $B04E ON GOTO [$6E79] entry 2, SANCTIFY: LB06E }
  { fixed: SANCTIFY goes to new code at the end of the script }
  DataPat.Put(#$F6#$B6);                                     { $B04E ON GOTO [$6E79] entry 2, SANCTIFY: LB6F6 }
  { #1096 part 2, added at $B6F6: a vial of holy water is used up, or failing one a holy symbol
    (C_ITEM.FIND_HOLY_SYMBOL), and the coffin is sanctified as before ($B06E); with neither nothing is done }
  DataPat.Put(#$80#$00#$55);                                 { $B6F6 USE UP ITEM $55 }
  DataPat.Put(#$16);                                         { $B6F9 IF = }
  DataPat.Put(#$01#$01#$6E#$B0);                             { $B6FA GOTO LB06E }
  DataPat.Put(#$80#$00#$FF);                                 { $B6FE USE UP ITEM $FF }
  DataPat.Put(#$16);                                         { $B701 IF = }
  DataPat.Put(#$01#$01#$6E#$B0);                             { $B702 GOTO LB06E }
  { $B706 PRINTCLEAR "YOU HAVE NOTHING HOLY TO LEAVE IN THE COFFIN." }
  DataPat.Put(#$12#$80#$22#$64#$F5#$60#$20#$15#$85#$80#$E3#$D4#$20#$93#$87#$80);
  DataPat.Put(#$83#$CC#$66#$05#$0F#$80#$C1#$41#$58#$58#$09#$3A#$05#$08#$16#$00);
  DataPat.Put(#$CF#$18#$62#$4E#$B8);
  DataPat.Put(#$00);                                         { $B72B EXIT }
  { #1113 part 1, original }
  DataPat.Put(#$09#$00#$FF#$01#$E1#$6D);                     { $AE86 SAVE $FF, [$6DE1] }
  DataPat.Put(#$00);                                         { $AE8C EXIT }
  { fixed: on to new code; the three bytes left over are never reached }
  DataPat.Put(#$01#$01#$2C#$B7);                             { $AE86 GOTO LB72C }
  DataPat.Put(#$00#$00#$00);                                 { $AE8A EXIT EXIT EXIT }
  { #1113 part 2, added at $B72C, after #1096's: the mage who has just joined, the current character after ADD
    NPC, is Odran (MON4CHA block 24, which he fights as when he is sent away, keeps its name); then as before }
  { $B72C SAVE "ODRAN", [$6B00] }
  DataPat.Put(#$09#$80#$04#$3C#$44#$81#$38#$01#$00#$6B);
  DataPat.Put(#$09#$00#$FF#$01#$E1#$6D);                     { $B736 SAVE $FF, [$6DE1] }
  DataPat.Put(#$00);                                         { $B73C EXIT }
  { #1116, original }
  DataPat.Put(#$3E#$AB);                                     { $A04E ON GOTO [$6E79] entry 2, LEAVE: LAB3E }
  { fixed: LEAVE goes where the script's other LEAVEs go: SPRITE OFF, PICTURE $FF, EXIT }
  DataPat.Put(#$C0#$AD);                                     { $A04E ON GOTO [$6E79] entry 2, LEAVE: LADC0 }
  { #1117, original: the end of #1113's new code }
  DataPat.Put(#$00);                                         { $B73C EXIT }
  { fixed: the mage's picture is taken down }
  DataPat.Put(#$0E#$00#$FF);                                 { $B73C PICTURE $FF }
  DataPat.Put(#$00);                                         { $B73F EXIT }
  { #1138 part 1, original }
  { $AFE3 PRINTCLEAR "AN AGED PRIEST APPROACHES, POINTING AT THE MAD MAN, HE SPEAKS, 'THAT MAN URGENTLY NEEDS OUR
    CARE.  DROP HIM FROM YOUR PARTY OR HE WILL BRING YOU TO GRIEF.  WE WILL CARE FOR HIM.'" }
  DataPat.Put(#$12#$80#$86#$04#$E8#$01#$1C#$51#$20#$41#$22#$45#$4D#$48#$01#$41);
  DataPat.Put(#$04#$8F#$04#$32#$05#$4E#$C8#$10#$3C#$93#$94#$24#$E1#$E0#$05#$48);
  DataPat.Put(#$14#$20#$58#$0D#$04#$48#$0D#$04#$EB#$20#$20#$58#$13#$40#$50#$4B);
  DataPat.Put(#$4E#$C8#$27#$50#$80#$54#$80#$D0#$4E#$81#$54#$87#$14#$E5#$0C#$66);
  DataPat.Put(#$03#$85#$14#$44#$E0#$3D#$54#$A0#$0C#$14#$85#$BA#$08#$04#$48#$F4);
  DataPat.Put(#$20#$20#$93#$60#$19#$23#$CD#$81#$93#$D5#$4A#$04#$01#$49#$46#$60);
  DataPat.Put(#$3D#$28#$08#$16#$05#$C9#$30#$C8#$02#$48#$93#$87#$81#$93#$D5#$81);
  DataPat.Put(#$43#$E0#$1D#$22#$45#$1A#$E8#$20#$5C#$58#$17#$24#$C3#$20#$0C#$14);
  DataPat.Put(#$85#$80#$63#$D2#$80#$82#$4D#$BA#$70);
  { fixed: the priest asks the party to leave him with them }
  { $AFE3 PRINTCLEAR "AN AGED PRIEST APPROACHES, POINTING AT THE MAD MAN, HE SPEAKS, 'THAT MAN URGENTLY NEEDS OUR
    CARE.  LEAVE HIM WITH US AND WE WILL CARE FOR HIM.'" }
  DataPat.Put(#$12#$80#$86#$04#$E8#$01#$1C#$51#$20#$41#$22#$45#$4D#$48#$01#$41);
  DataPat.Put(#$04#$8F#$04#$32#$05#$4E#$C8#$10#$3C#$93#$94#$24#$E1#$E0#$05#$48);
  DataPat.Put(#$14#$20#$58#$0D#$04#$48#$0D#$04#$EB#$20#$20#$58#$13#$40#$50#$4B);
  DataPat.Put(#$4E#$C8#$27#$50#$80#$54#$80#$D0#$4E#$81#$54#$87#$14#$E5#$0C#$66);
  DataPat.Put(#$03#$85#$14#$44#$E0#$3D#$54#$A0#$0C#$14#$85#$BA#$08#$0C#$14#$15);
  DataPat.Put(#$85#$80#$82#$4D#$81#$72#$54#$22#$05#$53#$80#$13#$84#$81#$71#$60);
  DataPat.Put(#$5C#$93#$0C#$80#$30#$52#$16#$01#$8F#$4A#$02#$09#$36#$E9#$C0#$00);
  DataPat.Put(#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00#$00);
  DataPat.Put(#$00#$00#$00#$00#$00#$00#$00#$00#$00);
  { #1138 part 2, original }
  DataPat.Put(#$02#$01#$1F#$AF);                             { $B06C GOSUB LAF1F }
  { fixed: to the question, by new code }
  DataPat.Put(#$01#$01#$1C#$B7);                             { $B06C GOTO LB71C }
  { #1138 part 3, added at $B71C: will the party leave him; yes, he leaves the party as Skullcrusher does ($AD56) }
  { $B71C PRINT " 'WILL YOU LEAVE HIM IN OUR CARE?'" }
  DataPat.Put(#$11#$80#$1A#$82#$75#$C9#$30#$C8#$19#$3D#$58#$0C#$14#$15#$85#$80);
  DataPat.Put(#$82#$4D#$80#$93#$A0#$3D#$54#$A0#$0C#$14#$85#$FE#$70);
  DataPat.Put(#$02#$01#$5D#$AE);                             { $B739 GOSUB LAE5D }
  DataPat.Put(#$25#$01#$79#$6E#$00#$02#$01#$49#$B7#$01#$85#$B7); { $B73D ON GOTO [$6E79], $02, LB749, LB785 }
  DataPat.Put(#$09#$00#$00#$01#$00#$6C);                     { $B749 SAVE $00, [$6C00] }
  DataPat.Put(#$09#$00#$00#$01#$00#$6B);                     { $B74F SAVE $00, [$6B00] }
  DataPat.Put(#$04#$00#$80#$01#$02#$98#$01#$02#$98);         { $B755 ADD $80, [$9802], [$9802] }
  DataPat.Put(#$0A#$01#$02#$98);                             { $B75E LOAD CHARACTER [$9802] }
  { $B762 PRINTCLEAR "THE PRIESTS GENTLY LEAD THE MAD MAN AWAY." }
  DataPat.Put(#$12#$80#$1F#$50#$81#$60#$41#$22#$45#$4D#$44#$E0#$1C#$53#$94#$31);
  DataPat.Put(#$98#$0C#$14#$11#$20#$50#$81#$60#$34#$11#$20#$34#$13#$A0#$05#$70);
  DataPat.Put(#$59#$B8);
  DataPat.Put(#$13);                                         { $B784 RETURN }
  { $B785 PRINTCLEAR "THE PRIESTS OF TYR WELCOME YOU TO THE TEMPLE." }
  DataPat.Put(#$12#$80#$22#$50#$81#$60#$41#$22#$45#$4D#$44#$E0#$3C#$68#$14#$65);
  DataPat.Put(#$28#$17#$14#$C0#$CF#$34#$58#$19#$3D#$58#$14#$3E#$05#$08#$16#$05);
  DataPat.Put(#$05#$35#$03#$05#$B8);
  DataPat.Put(#$13);                                         { $B7AA RETURN }
  { #1139 part 1, original }
  DataPat.Put(#$01#$01#$E6#$B6);                             { $A8B0 GOTO LB6E6 }
  { fixed: the altar first goes by new code }
  DataPat.Put(#$01#$01#$98#$B8);                             { $A8B0 GOTO LB898 }
  { #1139 part 2, original }
  DataPat.Put(#$02#$4A);                                     { $A9C6 SAVE $01, [$4A02]: the address }
  { fixed: the altar destroyed, for good (C_GBVM.BANE_ALTAR_DESTROYED) }
  DataPat.Put(#$7A#$4A);                                     { $A9C6 SAVE $01, [$4A7A]: the address }
  { #1139 part 3, original }
  DataPat.Put(#$02#$4A);                                     { $AA01 SAVE $01, [$4A02]: the address }
  { fixed: the altar destroyed, for good (C_GBVM.BANE_ALTAR_DESTROYED) }
  DataPat.Put(#$7A#$4A);                                     { $AA01 SAVE $01, [$4A7A]: the address }
  { #1139 part 4, original }
  DataPat.Put(#$02#$4A);                                     { $B7E6 COMPARE [$4A02], $01: the address (#682 part 6) }
  { fixed: the altar destroyed, for good }
  DataPat.Put(#$7A#$4A);                                     { $B7E6 COMPARE [$4A7A], $01: the address }
  { #1139 part 5, added at $B898: an altar destroyed in a fight the party fled stands again; a temple freed without
    Dirten ([$4A79] = $FFFF) that he joined after ([$4A9C] = $FF, a game from before this) finds him in the party and
    goes to #682's farewell ($B7F5). Only then is the party searched: LOAD CHARACTER would change who the temple
    serves }
  DataPat.Put(#$03#$01#$BD#$4A#$00#$FE);                     { $B898 COMPARE [$4ABD], $FE }
  DataPat.Put(#$18);                                         { $B89E IF < }
  DataPat.Put(#$09#$00#$00#$01#$7A#$4A);                     { $B89F SAVE $00, [$4A7A] }
  DataPat.Put(#$03#$01#$BD#$4A#$00#$FE);                     { $B8A5 COMPARE [$4ABD], $FE }
  DataPat.Put(#$18);                                         { $B8AB IF < }
  DataPat.Put(#$01#$01#$E6#$B6);                             { $B8AC GOTO LB6E6 }
  DataPat.Put(#$03#$01#$79#$4A#$02#$FF#$FF);                 { $B8B0 COMPARE [$4A79], $FFFF }
  DataPat.Put(#$17);                                         { $B8B7 IF <> }
  DataPat.Put(#$01#$01#$E6#$B6);                             { $B8B8 GOTO LB6E6 }
  DataPat.Put(#$03#$01#$9C#$4A#$00#$FF);                     { $B8BC COMPARE [$4A9C], $FF }
  DataPat.Put(#$17);                                         { $B8C2 IF <> }
  DataPat.Put(#$01#$01#$E6#$B6);                             { $B8C3 GOTO LB6E6 }
  DataPat.Put(#$09#$00#$00#$01#$7A#$6E);                     { $B8C7 SAVE $00, [$6E7A] }
  DataPat.Put(#$0A#$01#$7A#$6E);                             { $B8CD LOAD CHARACTER [$6E7A] }
  { $B8D1 COMPARE str[$6B00], "DIRTEN" }
  DataPat.Put(#$03#$81#$00#$6B#$80#$05#$10#$94#$94#$14#$E0);
  DataPat.Put(#$16);                                         { $B8DC IF = }
  DataPat.Put(#$01#$01#$F9#$B8);                             { $B8DD GOTO LB8F9 }
  DataPat.Put(#$04#$00#$01#$01#$7A#$6E#$01#$7A#$6E);         { $B8E1 ADD $01, [$6E7A], [$6E7A] }
  DataPat.Put(#$03#$01#$7A#$6E#$00#$08);                     { $B8EA COMPARE [$6E7A], $08 }
  DataPat.Put(#$18);                                         { $B8F0 IF < }
  DataPat.Put(#$01#$01#$CD#$B8);                             { $B8F1 GOTO LB8CD }
  DataPat.Put(#$01#$01#$E6#$B6);                             { $B8F5 GOTO LB6E6 }
  DataPat.Put(#$03#$01#$B8#$6B#$00#$80);                     { $B8F9 COMPARE [$6BB8], $80 }
  DataPat.Put(#$18);                                         { $B8FF IF < }
  DataPat.Put(#$01#$01#$E1#$B8);                             { $B900 GOTO LB8E1 }
  DataPat.Put(#$01#$01#$F5#$B7);                             { $B904 GOTO LB7F5 }
  { #1139 part 6, original }
  DataPat.Put(#$07#$9E);                                     { $9B4C ON GOTO [$9800] entry 5: L9E07 }
  { fixed: event 5, the bishop's study, goes to new code at the end of the script }
  DataPat.Put(#$AB#$B7);                                     { $9B4C ON GOTO [$9800] entry 5: LB7AB }
  { #1139 part 7, added at $B7AB, after #1138's: the temple already freed, the bishop thanks the party and Dirten
    goes to restore it: [$4A9C] = $FF and no day kept, so #682's altar starts the 14 days on the first visit }
  DataPat.Put(#$03#$01#$BD#$4A#$00#$FE);                     { $B7AB COMPARE [$4ABD], $FE }
  DataPat.Put(#$18);                                         { $B7B1 IF < }
  DataPat.Put(#$01#$01#$07#$9E);                             { $B7B2 GOTO L9E07 }
  DataPat.Put(#$03#$01#$9C#$4A#$00#$FF);                     { $B7B6 COMPARE [$4A9C], $FF }
  DataPat.Put(#$16);                                         { $B7BC IF = }
  DataPat.Put(#$00);                                         { $B7BD EXIT }
  DataPat.Put(#$03#$01#$9B#$4A#$00#$FE);                     { $B7BE COMPARE [$4A9B], $FE }
  DataPat.Put(#$16);                                         { $B7C4 IF = }
  DataPat.Put(#$01#$01#$D4#$B7);                             { $B7C5 GOTO LB7D4 }
  DataPat.Put(#$03#$01#$9C#$4A#$00#$80);                     { $B7C9 COMPARE [$4A9C], $80 }
  DataPat.Put(#$17);                                         { $B7CF IF <> }
  DataPat.Put(#$01#$01#$07#$9E);                             { $B7D0 GOTO L9E07 }
  DataPat.Put(#$09#$00#$0D#$01#$E1#$6D);                     { $B7D4 SAVE $0D, [$6DE1] }
  DataPat.Put(#$0E#$00#$01);                                 { $B7DA PICTURE $01 }
  { $B7DD PRINTCLEAR "YOU ARE USHERED INTO THE BISHOP'S STUDY. BISHOP BRACCIO SPEAKS, 'YOU HAVE ALREADY CLEANSED THE
    TEMPLE OF BANE! DIRTEN WILL GO AT ONCE TO RESTORE IT.'" }
  DataPat.Put(#$12#$80#$70#$64#$F5#$60#$05#$21#$60#$55#$32#$05#$48#$51#$20#$24);
  DataPat.Put(#$E5#$0F#$81#$42#$05#$80#$22#$53#$20#$F4#$27#$4E#$04#$D4#$54#$46);
  DataPat.Put(#$6E#$80#$22#$53#$20#$F4#$20#$09#$20#$43#$0C#$93#$E0#$4D#$01#$41);
  DataPat.Put(#$2D#$3B#$20#$9D#$93#$D5#$80#$80#$56#$16#$00#$4C#$48#$50#$44#$66);
  DataPat.Put(#$00#$CC#$14#$13#$93#$14#$48#$14#$20#$58#$14#$14#$D4#$0C#$16#$03);
  DataPat.Put(#$C6#$80#$20#$4E#$16#$18#$04#$25#$25#$05#$3A#$05#$C9#$30#$C8#$07);
  DataPat.Put(#$3E#$00#$54#$80#$F3#$83#$16#$05#$0F#$81#$21#$53#$50#$F4#$85#$80);
  DataPat.Put(#$95#$2E#$9C);
  DataPat.Put(#$02#$01#$1F#$AF);                             { $B850 GOSUB LAF1F }
  DataPat.Put(#$09#$00#$FF#$01#$9C#$4A);                     { $B854 SAVE $FF, [$4A9C] }
  DataPat.Put(#$09#$00#$00#$01#$79#$4A);                     { $B85A SAVE $00, [$4A79] }
  DataPat.Put(#$0E#$00#$FF);                                 { $B860 PICTURE $FF }
  DataPat.Put(#$00);                                         { $B863 EXIT }
  { #1139 part 8, original }
  DataPat.Put(#$03#$01#$BD#$4A#$00#$FF#$16);                 { $AABE COMPARE [$4ABD], $FF; IF = }
  { fixed: no summons once the temple is freed }
  DataPat.Put(#$03#$01#$BD#$4A#$00#$FE#$1B);                 { $AABE COMPARE [$4ABD], $FE; IF >= }
  { #1091 part 1, original }
  DataPat.Put(#$BE#$A8);                                     { $9B95 ON GOTO [$9800] entry 22: LA8BE }
  { fixed: event 22 goes to new code at the end of the script }
  DataPat.Put(#$64#$B8);                                     { $9B95 ON GOTO [$9800] entry 22: LB864 }
  { #1091 part 2, added at $B864, after #1139's: the arms shops but at (11,12); there, as they do, the greeting once a
    visit, the shopkeeper and the refusal after a fight with the watch, then the magic shop's offer, its stock
    (PROGRAM 11) and the shop }
  DataPat.Put(#$14#$01#$4B#$C0#$00#$0B#$01#$4C#$C0#$00#$0C); { $B864 COMPARE AND [$C04B], $0B, [$C04C], $0C }
  DataPat.Put(#$17);                                         { $B86F IF <> }
  DataPat.Put(#$01#$01#$BE#$A8);                             { $B870 GOTO LA8BE }
  DataPat.Put(#$02#$01#$89#$AE);                             { $B874 GOSUB LAE89 }
  DataPat.Put(#$09#$00#$2A#$01#$E1#$6D);                     { $B878 SAVE $2A, [$6DE1] }
  DataPat.Put(#$0E#$00#$09);                                 { $B87E PICTURE $09 }
  DataPat.Put(#$03#$01#$C0#$4A#$00#$00);                     { $B881 COMPARE [$4AC0], $00 }
  DataPat.Put(#$19);                                         { $B887 IF > }
  DataPat.Put(#$01#$01#$1D#$AE);                             { $B888 GOTO LAE1D }
  { $B88C PRINTCLEAR "THE SHOP SELLS MAGICAL ITEMS. 'CAN I SHOW YOU OUR WARES?'" }
  DataPat.Put(#$12#$80#$2B#$50#$81#$60#$4C#$83#$D0#$81#$31#$4C#$31#$38#$0D#$04);
  DataPat.Put(#$72#$43#$04#$C8#$09#$50#$53#$53#$BA#$09#$C3#$04#$E8#$09#$81#$32);
  DataPat.Put(#$0F#$5E#$06#$4F#$56#$03#$D5#$4A#$05#$C1#$48#$54#$FF#$9C);
  DataPat.Put(#$02#$01#$5D#$AE);                             { $B8BA GOSUB LAE5D }
  DataPat.Put(#$25#$01#$79#$6E#$00#$02#$01#$CA#$B8#$01#$6D#$AE); { $B8BE ON GOTO [$6E79], $02, LB8CA, LAE6D }
  DataPat.Put(#$1C);                                         { $B8CA CLEARMONSTERS }
  DataPat.Put(#$38#$00#$0B);                                 { $B8CB PROGRAM $0B }
  DataPat.Put(#$09#$00#$01#$01#$6C#$6E);                     { $B8CE SAVE $01, [$6E6C] }
  DataPat.Put(#$24);                                         { $B8D4 COMBAT }
  DataPat.Put(#$0E#$00#$FF);                                 { $B8D5 PICTURE $FF }
  DataPat.Put(#$00);                                         { $B8D8 EXIT }
  { #1121, original: effect 90 }
  DataPat.Put(#$5A);
  { fixed: effect 151 }
  DataPat.Put(#$97);
end;

function LoadTable: Boolean;
begin
  GetMem(parts, SizeOf(TPartList));
  GetMem(patchBytes, SizeOf(TPatchBytes));
  partFill := 0;
  byteFill := 0;
  DataPat.FillParts;
  DataPat.FillBytes;
  LoadTable := (partFill = PART_COUNT) and (byteFill = BYTE_COUNT);
end;

procedure FreeTable;
begin
  FreeMem(patchBytes, SizeOf(TPatchBytes));
  FreeMem(parts, SizeOf(TPartList));
end;

end.

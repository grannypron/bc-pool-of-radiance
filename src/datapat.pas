{ The fixes DataBld makes to the shipped data as it builds the merged archives, each to a known fault in one block of
  a per-disk archive and named, here and in DATABLD.LOG, by the number of its issue in the pool-of-radiance
  repository. A fix is one part, or a run of parts with the same issue and block, made together or not at all. A part
  replaces origLen bytes at offset in the decoded block with newLen bytes, so a fix may lengthen a block (a script
  that gains code at its end). It is made only when the block is size bytes long and holds the original bytes there;
  offsets and sizes are those of the block as the fixes before it in this table leave it. A part's bytes are the next
  origLen + newLen bytes of patchBytes, the original first. Changing the fixes means raising C_DATA.VERSION. }
{$I COMPILER.INC}
unit DataPat;

interface

uses C_DATA;

const
  { the parts of all the fixes, and their bytes together }
  PART_COUNT = 78;
  BYTE_COUNT = 2417;

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

const
  parts: array[1..PART_COUNT] of TPatchPart = (
    { #20: the Flame Tongue +2 Long Sword placed in Valjevo Castle's well (ITEM5 block 36, record 0) carries effect
      22 and special 0, so readying it never adds the Flame Tongue effect and Use casts Find Traps; it gets effect 6
      (Flame Tongue) and special 130, a ready-item handler }
    (issue: 20; family: C_DATA.FAMILY_ITEM; disk: 5; id: 36; size: 63; offset: 61; origLen: 2; newLen: 2),
    { #27: the arms shop's south door in New Phlan, north wall of (9,14) and south wall of (9,13), is wall type 3, so
      the night lock (a type-9 shop door seen from the street) never stops the party; both become type 9 like every
      other shop door }
    (issue: 27; family: C_DATA.FAMILY_GEO; disk: 3; id: 0; size: 1026; offset: 235; origLen: 1; newLen: 1),
    (issue: 27; family: C_DATA.FAMILY_GEO; disk: 3; id: 0; size: 1026; offset: 475; origLen: 1; newLen: 1),
    { #28: the Slums' random-encounter result (script $B118-$B156): a win counts the encounter and gives a clear
      point only while the 15 random encounters are not all fought, so fights that interrupt a rest stop earning
      clear points }
    (issue: 28; family: C_DATA.FAMILY_ECL; disk: 2; id: 20; size: 7679; offset: 6170; origLen: 63; newLen: 63),
    { #29: the Slums' clear-point routine (script $B69C) gives no point and returns from the script when the party
      fled, and the four set encounters that marked themselves done before calling it call it first, so running from
      a set encounter or from Ohlo neither counts nor removes the encounter }
    (issue: 29; family: C_DATA.FAMILY_ECL; disk: 2; id: 20; size: 7679; offset: 7582; origLen: 32; newLen: 32),
    (issue: 29; family: C_DATA.FAMILY_ECL; disk: 2; id: 20; size: 7679; offset: 1391; origLen: 10; newLen: 10),
    (issue: 29; family: C_DATA.FAMILY_ECL; disk: 2; id: 20; size: 7679; offset: 1978; origLen: 10; newLen: 10),
    (issue: 29; family: C_DATA.FAMILY_ECL; disk: 2; id: 20; size: 7679; offset: 4483; origLen: 10; newLen: 10),
    (issue: 29; family: C_DATA.FAMILY_ECL; disk: 2; id: 20; size: 7679; offset: 4858; origLen: 10; newLen: 10),
    { #31: Podal Plaza's pre-camp entry (script $9914-$992A) set the on-mission rest (an interruption every 5
      minutes, 99%) and then overwrote it with the default (every 10 minutes, 16%); the default now comes first }
    (issue: 31; family: C_DATA.FAMILY_ECL; disk: 1; id: 18; size: 6550; offset: 22; origLen: 23; newLen: 23),
    { #32: Podal Plaza's random encounters (script $9DEE-$9E1D) added to the clearing count before looking at the
      result, so fleeing counted as a win; the count now goes up only after a win ([$6DC7] = 0) while it is below the
      mission's $40 }
    (issue: 32; family: C_DATA.FAMILY_ECL; disk: 1; id: 18; size: 6550; offset: 1264; origLen: 48; newLen: 48),
    { #33: the Pitt's tavern brawl (script $AAA6) always brought back the buccaneer beaten in the duel, with his Long
      Sword +1 and Chain Mail +1; the brawl now loads him only while [$4A37] = 0, from new code at the end of the
      script }
    (issue: 33; family: C_DATA.FAMILY_ECL; disk: 1; id: 18; size: 6550; offset: 4520; origLen: 7; newLen: 7),
    (issue: 33; family: C_DATA.FAMILY_ECL; disk: 1; id: 18; size: 6550; offset: 6550; origLen: 0; newLen: 26),
    { #34: the Cadorna Textile House counted a random encounter as it began (script $9A65), so fleeing it counted
      toward clearing the block; the count now goes up after a won encounter, from new code at the end of the script,
      and [$6E7C] tells the counted encounters from the uncounted hobgoblin patrol }
    (issue: 34; family: C_DATA.FAMILY_ECL; disk: 4; id: 2; size: 6170; offset: 318; origLen: 4; newLen: 4),
    (issue: 34; family: C_DATA.FAMILY_ECL; disk: 4; id: 2; size: 6170; offset: 359; origLen: 32; newLen: 32),
    (issue: 34; family: C_DATA.FAMILY_ECL; disk: 4; id: 2; size: 6170; offset: 493; origLen: 12; newLen: 12),
    (issue: 34; family: C_DATA.FAMILY_ECL; disk: 4; id: 2; size: 6170; offset: 562; origLen: 12; newLen: 12),
    (issue: 34; family: C_DATA.FAMILY_ECL; disk: 4; id: 2; size: 6170; offset: 647; origLen: 12; newLen: 12),
    (issue: 34; family: C_DATA.FAMILY_ECL; disk: 4; id: 2; size: 6170; offset: 728; origLen: 12; newLen: 12),
    (issue: 34; family: C_DATA.FAMILY_ECL; disk: 4; id: 2; size: 6170; offset: 797; origLen: 12; newLen: 12),
    (issue: 34; family: C_DATA.FAMILY_ECL; disk: 4; id: 2; size: 6170; offset: 6170; origLen: 0; newLen: 43),
    { #35: the Cadorna Textile House's pre-camp entry (script $9949) made rest safe only once the block was cleared,
      so with nine encounters won a rest could be broken off with no fight; it is now also safe then unless the ogre
      lives and the party is on a patrol square, and with the ogre dead the block is cleared }
    (issue: 35; family: C_DATA.FAMILY_ECL; disk: 4; id: 2; size: 6213; offset: 75; origLen: 14; newLen: 14),
    (issue: 35; family: C_DATA.FAMILY_ECL; disk: 4; id: 2; size: 6213; offset: 6213; origLen: 0; newLen: 65),
    { #36: the Ring of Feather Falling under the Wealthy Area's trap door (ITEM1 block 6, record 0) carries effect 0
      and special 0, so readying it gives no Feather Fall; it gets effect 27 and special 128, as a random one has }
    (issue: 36; family: C_DATA.FAMILY_ITEM; disk: 1; id: 6; size: 189; offset: 61; origLen: 2; newLen: 2),
    { #37: Restal at the bottom of the Textile House well (script $AE71-$AF0A) kept his 'already resealed' flag in
      [$4A17], which entering the area clears, so he resealed and paid again on every visit; he now deals only while
      the party holds the sealed chest ([$4AC8] = 1) and once a game, flagged in the unused [$4A76] }
    (issue: 37; family: C_DATA.FAMILY_ECL; disk: 4; id: 2; size: 6278; offset: 5491; origLen: 7; newLen: 7),
    (issue: 37; family: C_DATA.FAMILY_ECL; disk: 4; id: 2; size: 6278; offset: 5504; origLen: 1; newLen: 1),
    (issue: 37; family: C_DATA.FAMILY_ECL; disk: 4; id: 2; size: 6278; offset: 5644; origLen: 1; newLen: 1),
    { #38: Kovel Mansion's weapons-pile ambush (script $AAB9-$AB0F): 0..7 thieves killed give 5 1st-level thieves,
      8..12 give c-7 6th-level and 12-c 1st-level as before, 13..16 give 5 6th-level and 17 gives 4, where the
      shipped script took the 1st-level count below zero or left it stale }
    (issue: 38; family: C_DATA.FAMILY_ECL; disk: 3; id: 14; size: 7332; offset: 4539; origLen: 87; newLen: 87),
    { #40: leaving the cleared Sorcerer's Pyramid (script $AE11, $AF2B, $AF3B) used the Valjevo commission state
      [$4A9A] as its scratch flag and left it at $FF, so the council's Valjevo summons never came; the flag is now
      the entry word [$4A1F], which this script uses nowhere else }
    (issue: 40; family: C_DATA.FAMILY_ECL; disk: 7; id: 26; size: 6569; offset: 5397; origLen: 1; newLen: 1),
    (issue: 40; family: C_DATA.FAMILY_ECL; disk: 7; id: 26; size: 6569; offset: 5681; origLen: 1; newLen: 1),
    (issue: 40; family: C_DATA.FAMILY_ECL; disk: 7; id: 26; size: 6569; offset: 5697; origLen: 1; newLen: 1),
    { #41: the Nomad Camp shaman's Bracers AC 2 (MON7ITM block 43, record 1) are priced and named for AC 2 but carry
      plus 6, which gives AC 4; the plus becomes 8 }
    (issue: 41; family: C_DATA.FAMILY_MONITM; disk: 7; id: 43; size: 189; offset: 113; origLen: 1; newLen: 1),
    { #42: Lizardman Keep's 'press Return' prompt (script $9A64) wrote its answer into [$6E81], the old lizardman's
      record of which location the party is at, so a wrong friend-word at location 3 or 10 started location 1's
      fight; the prompt now writes [$6E7A], which nothing reads before setting it }
    (issue: 42; family: C_DATA.FAMILY_ECL; disk: 8; id: 16; size: 5394; offset: 360; origLen: 1; newLen: 1),
    { #43: Lizardman Keep's count of giant lizards still to come (script $99AD) subtracted the pool-treasure flags
      [$4A5E] instead of the giant lizards killed [$4A5F], so the catacomb ambush was always ten; it subtracts the
      kills }
    (issue: 43; family: C_DATA.FAMILY_ECL; disk: 8; id: 16; size: 5394; offset: 177; origLen: 1; newLen: 1),
    { #44: the Buccaneer Base slave pen (script $B4C7) tested a scratch word, not the heir's state, so it offered the
      boy again after he was bought, rescued or lost; it tests [$4AA9] }
    (issue: 44; family: C_DATA.FAMILY_ECL; disk: 6; id: 1; size: 7673; offset: 7115; origLen: 1; newLen: 1),
    { #45: the Zhentil Keep Outpost offered dinner after the party had fought the garrison or killed the commandant:
      the quarters (script $A400) offer it only while neither has happened, and a rest after fighting the guards
      brings four guards, not the dinner escort (entry 4). Entries 3 and 4 are rewritten in less room to fit, entry 3
      the same as before }
    (issue: 45; family: C_DATA.FAMILY_ECL; disk: 6; id: 28; size: 7669; offset: 16; origLen: 2; newLen: 2),
    (issue: 45; family: C_DATA.FAMILY_ECL; disk: 6; id: 28; size: 7669; offset: 2827; origLen: 2; newLen: 2),
    (issue: 45; family: C_DATA.FAMILY_ECL; disk: 6; id: 28; size: 7669; offset: 7463; origLen: 110; newLen: 110),
    { #46: at the Zhentil Keep Outpost a party that beat the guards outside its quarters could walk west and through
      the one-way wall at (2,0), never stepping on (4,1) where the dwarf and the commandant attack; (3,0) gets the
      same event, 5, keeping its outdoor bit }
    (issue: 46; family: C_DATA.FAMILY_GEO; disk: 6; id: 28; size: 1026; offset: 517; origLen: 1; newLen: 1),
    { #47: the Zhentil Keep Outpost's commandant fight (MON6CHA block 86) uses a copy of Al-Hyam Dazid, whom the
      party meets alive later in Valjevo Castle; disk 6's copy is renamed Zhentarim Mage, disk 5's Al-Hyam is
      unchanged }
    (issue: 47; family: C_DATA.FAMILY_MONCHA; disk: 6; id: 86; size: 285; offset: 0; origLen: 16; newLen: 16),
    { #48: the graveyard's two tombs (script $A3D2 and $AD17) gave each other's treasure: the paladin's crypt had no
      armour and a magic-user scroll, the knight's tomb the paladin's plate, shield and lawful-good sword; the two
      item blocks trade places }
    (issue: 48; family: C_DATA.FAMILY_ECL; disk: 4; id: 10; size: 7672; offset: 2788; origLen: 1; newLen: 1),
    (issue: 48; family: C_DATA.FAMILY_ECL; disk: 4; id: 10; size: 7672; offset: 5161; origLen: 1; newLen: 1),
    { #49: at Stojanow Gate, refusing the bugbears' 15 gold (or not having it) and being told to 'come back when
      you've learned the rules' (script $AC32) made them hostile for good; they now become more suspicious, attitude
      2, so the party may come back }
    (issue: 49; family: C_DATA.FAMILY_ECL; disk: 2; id: 9; size: 6367; offset: 4918; origLen: 1; newLen: 1),
    { #50: at Stojanow Gate, bugbears who unmasked the party as impostors (script $ACF8) never turned hostile, so the
      wagon bluff could be tried again until it worked; they now set the hostile attitude, 3, in new code at the end
      of the script }
    (issue: 50; family: C_DATA.FAMILY_ECL; disk: 2; id: 9; size: 6367; offset: 5114; origLen: 4; newLen: 4),
    (issue: 50; family: C_DATA.FAMILY_ECL; disk: 2; id: 9; size: 6367; offset: 6367; origLen: 0; newLen: 10),
    { #51: Stojanow Gate's alarm (script $9C0C) set its end hour from the stray word [$9800] instead of the hour it
      was raised, [$4A62], so it ended at once or never; it uses [$4A62] as Valjevo Castle's alarm does }
    (issue: 51; family: C_DATA.FAMILY_ECL; disk: 2; id: 9; size: 6377; offset: 786; origLen: 2; newLen: 2),
    { #52: Stojanow Gate's location 13 (script $B10F) always fought both tower garrisons, even one already killed;
      new code at the end of the script loads only the surviving garrison, as the alarm fight does, then fights as
      before }
    (issue: 52; family: C_DATA.FAMILY_ECL; disk: 2; id: 9; size: 6377; offset: 6161; origLen: 6; newLen: 6),
    (issue: 52; family: C_DATA.FAMILY_ECL; disk: 2; id: 9; size: 6377; offset: 6377; origLen: 0; newLen: 99),
    { #54: the false Tyranthraxus in the hedge maze (script $A9EE) confessed to an abusive weak party and fought a
      strong one; the test is turned round, so a party strength and Charisma bonus of 85 or more gets the confession }
    (issue: 54; family: C_DATA.FAMILY_ECL; disk: 5; id: 5; size: 4943; offset: 4336; origLen: 1; newLen: 1),
    { #55: beating Tyranthraxus in the Inner Tower (script $A81B) wrote its 'defeated' bit into the unused [$4A72],
      so he, the messenger and Genheeris could be fought again; the bit goes into [$4A6D] as the tower's other bits
      do }
    (issue: 55; family: C_DATA.FAMILY_ECL; disk: 5; id: 7; size: 4105; offset: 3876; origLen: 1; newLen: 1),
    { #70: the Wealthy Area's south walls at (4,15) and (11,15) could be walked through off the map, where no exit is
      set, and the game hung loading script area 255; both become solid }
    (issue: 70; family: C_DATA.FAMILY_GEO; disk: 1; id: 31; size: 1026; offset: 1014; origLen: 1; newLen: 1),
    (issue: 70; family: C_DATA.FAMILY_GEO; disk: 1; id: 31; size: 1026; offset: 1021; origLen: 1; newLen: 1),
    { #203: every Cloak of Displacement gives +2 AC and +2 saves, as a random one (template 13: type 92, plus 2, save
      bonus 2) does; the one with the basilisk's treasure (ITEM2 block 3, record 1) has save bonus 0, so it gets 2 }
    (issue: 203; family: C_DATA.FAMILY_ITEM; disk: 2; id: 3; size: 252; offset: 109; origLen: 6; newLen: 6),
    { #203: the Level 6 MU's Cloak of Displacement (MON2ITM block 82, record 3) is on the Cloak of Elvenkind's type,
      67, whose AC descriptor leaves it out of AC and saves, with plus 8 and save bonus 0, so it gives nothing; it
      gets type 92, plus 2 and save bonus 2 }
    (issue: 203; family: C_DATA.FAMILY_MONITM; disk: 2; id: 82; size: 315; offset: 235; origLen: 6; newLen: 6),
    { #355: the New Phlan training hall's notice (script $9A74) directs magic users and clerics north and fighters
      and rogues east, but says nothing of paladins and rangers, who train with the fighters; new code at the end of
      the script adds a sentence for them }
    (issue: 355; family: C_DATA.FAMILY_ECL; disk: 3; id: 11; size: 2171; offset: 488; origLen: 10; newLen: 10),
    (issue: 355; family: C_DATA.FAMILY_ECL; disk: 3; id: 11; size: 2171; offset: 2171; origLen: 0; newLen: 49),
    { #606: New Phlan's tavern at (8,9) becomes a vault, The Hoarder's Respite: event 20's address in the event table
      (script $9B4C) goes to new code at the end of the script, which sends every other event-20 square on to the
      tavern ($A2C6) as before, and at (8,9) does what the arms shop does (once a visit, the shopkeeper, the refusal
      after an attack on the city watch) and enters the vault: [$6E6C] = 2, then COMBAT with no monsters }
    (issue: 606; family: C_DATA.FAMILY_ECL; disk: 3; id: 0; size: 7473; offset: 657; origLen: 2; newLen: 2),
    (issue: 606; family: C_DATA.FAMILY_ECL; disk: 3; id: 0; size: 7473; offset: 7473; origLen: 0; newLen: 52),
    { #670: the Pitt's buccaneer (script $A90D, PRINTCLEAR) runs his question into the next: WHO WILL IT BE?'WHAT DO
      YOU DO? gets a space after the quote. The packed string's last six-bit slot was empty, so it stays 66 bytes }
    (issue: 670; family: C_DATA.FAMILY_ECL; disk: 1; id: 18; size: 6576; offset: 4168; origLen: 12; newLen: 12),
    { #682: the Temple of Bane (script 24, map 24) freed with Dirten in the party. At the end of the fight (script
      $AC59, $AC68) new code at the end of the script keeps the day in [$4A79] (C_GBVM.DIRTEN_TEMPLE_DAY), $FFFF when
      Dirten was not there; standing, he bids farewell as before, fallen, the temple guards come in and a cleric
      tends him. At the altar squares, (14,7) and (14,8) (script $A8B0), a freed temple's day is kept, or started for a
      game from before this whose party had Dirten ([$4A9C] = $FF); before 14 days the rebuilding is underway, after
      them Dirten welcomes the party and opens his temple a tenth off ([$6DE2] = 2) }
    (issue: 682; family: C_DATA.FAMILY_ECL; disk: 1; id: 24; size: 7656; offset: 4018; origLen: 11; newLen: 11),
    (issue: 682; family: C_DATA.FAMILY_ECL; disk: 1; id: 24; size: 7656; offset: 4957; origLen: 2; newLen: 2),
    (issue: 682; family: C_DATA.FAMILY_ECL; disk: 1; id: 24; size: 7656; offset: 4970; origLen: 11; newLen: 11),
    (issue: 682; family: C_DATA.FAMILY_ECL; disk: 1; id: 24; size: 7656; offset: 7656; origLen: 0; newLen: 145),
    (issue: 682; family: C_DATA.FAMILY_ECL; disk: 1; id: 24; size: 7801; offset: 7801; origLen: 0; newLen: 111),
    (issue: 682; family: C_DATA.FAMILY_ECL; disk: 1; id: 24; size: 7912; offset: 7912; origLen: 0; newLen: 178),
    { #683: Stojanow Gate once the party has taken it ([$4A77] holds both barracks and the bugbears, $1C): new code at
      the end of the script, reached through events 1, 2, 7 and 13 of the event table (script $9D84). The guard rooms
      at (4,7) and (11,7) are makeshift barracks for New Phlan's troops, and at (7,9) and (8,9), before the gatehouse,
      and (7,6) and (8,6), behind it, the guards on the wall cheer, with a guard's portrait (head $39, body 5); each
      once a visit, kept in [$4A01] as the guard rooms' text was, which entering the area clears. None waits for
      Return. Going through the gatehouse (script $A11F) makes the move without running the new square's event before
      the view is redrawn, so the cheer at (7,6) keeps its portrait }
    (issue: 683; family: C_DATA.FAMILY_ECL; disk: 2; id: 9; size: 6476; offset: 1168; origLen: 2; newLen: 2),
    (issue: 683; family: C_DATA.FAMILY_ECL; disk: 2; id: 9; size: 6476; offset: 1171; origLen: 2; newLen: 2),
    (issue: 683; family: C_DATA.FAMILY_ECL; disk: 2; id: 9; size: 6476; offset: 1186; origLen: 2; newLen: 2),
    (issue: 683; family: C_DATA.FAMILY_ECL; disk: 2; id: 9; size: 6476; offset: 1204; origLen: 2; newLen: 2),
    (issue: 683; family: C_DATA.FAMILY_ECL; disk: 2; id: 9; size: 6476; offset: 2083; origLen: 2; newLen: 2),
    (issue: 683; family: C_DATA.FAMILY_ECL; disk: 2; id: 9; size: 6476; offset: 6476; origLen: 0; newLen: 130),
    (issue: 683; family: C_DATA.FAMILY_ECL; disk: 2; id: 9; size: 6606; offset: 6606; origLen: 0; newLen: 181),
    { #748: weapons do their damage against large targets to a Large creature (Types.ICON_LARGE), no longer to every
      two-tile one; the gnolls (MON2CHA and MON8CHA block 73) and the phase spider (MON8CHA block 116), two-tile and
      size L, get the Large bit, so they take it as before. The huge scorpion, two-tile, is size M (#792) }
    (issue: 748; family: C_DATA.FAMILY_MONCHA; disk: 2; id: 73; size: 285; offset: 108; origLen: 1; newLen: 1),
    (issue: 748; family: C_DATA.FAMILY_MONCHA; disk: 8; id: 73; size: 285; offset: 108; origLen: 1; newLen: 1),
    (issue: 748; family: C_DATA.FAMILY_MONCHA; disk: 8; id: 116; size: 285; offset: 108; origLen: 1; newLen: 1),
    { #792: the ogre leader (MON1CHA block 9), size L, gets the Large bit its one-tile icon lacked, as the bugbear has:
      weapons do their large damage to it, and it is no person for Charm Person and Hold Person }
    (issue: 792; family: C_DATA.FAMILY_MONCHA; disk: 1; id: 9; size: 285; offset: 108; origLen: 1; newLen: 1),
    { #864 (POR-0209): outside City Hall the posted proclamations (script $AC58) follow the major rewards paid
      ([$4AC1], C_GBVM.COUNCIL_REWARDS); the ninth arm ($AD21) named CXIV again, the fifth's, where CCXIV, the one
      left, is meant. The packed "CCXIV." is a byte longer than the arm's room, so its ON GOSUB entry goes to new code
      at the end of the script, after #606's }
    (issue: 864; family: C_DATA.FAMILY_ECL; disk: 3; id: 0; size: 7525; offset: 5005; origLen: 2; newLen: 2),
    (issue: 864; family: C_DATA.FAMILY_ECL; disk: 3; id: 0; size: 7525; offset: 7525; origLen: 0; newLen: 12));
  patchBytes: array[0..BYTE_COUNT - 1] of Byte = (
    { #20, original }
    $16, $00,
    { fixed: effect 6, special 130 }
    $06, $82,
    { #27 part 1, original }
    $30,
    { fixed: (9,14) north: wall type 9 }
    $90,
    { #27 part 2, original }
    $30,
    { fixed: (9,13) south: wall type 9 }
    $90,
    { #28, original }
    $03, $01, $C7, $6D, $00, $80,                     { $B118 COMPARE [$6DC7], $80 }
    $19,                                              { $B11E IF > }
    $01, $01, $25, $B2,                               { $B11F GOTO LB225 }
    $03, $01, $C7, $6D, $00, $01,                     { $B123 COMPARE [$6DC7], $01 }
    $18,                                              { $B129 IF < }
    $04, $00, $01, $01, $80, $4A, $01, $80, $4A,      { $B12A ADD $01, [$4A80], [$4A80] }
    $18,                                              { $B133 IF < }
    $02, $01, $9C, $B6,                               { $B134 GOSUB LB69C }
    $19,                                              { $B138 IF > }
    $01, $01, $50, $B2,                               { $B139 GOTO LB250 }
    $16,                                              { $B13D IF = }
    $03, $01, $C8, $6D, $00, $00,                     { $B13E COMPARE [$6DC8], $00 }
    $19,                                              { $B144 IF > }
    $04, $00, $01, $01, $80, $4A, $01, $80, $4A,      { $B145 ADD $01, [$4A80], [$4A80] }
    $19,                                              { $B14E IF > }
    $02, $01, $9C, $B6,                               { $B14F GOSUB LB69C }
    $01, $01, $50, $B2,                               { $B153 GOTO LB250 }
    { fixed }
    $03, $01, $C7, $6D, $00, $80,                     { $B118 COMPARE [$6DC7], $80 }
    $19,                                              { $B11E IF > }
    $01, $01, $25, $B2,                               { $B11F GOTO LB225 }
    $03, $01, $C7, $6D, $00, $00,                     { $B123 COMPARE [$6DC7], $00 }
    $17,                                              { $B129 IF <> }
    $01, $01, $50, $B2,                               { $B12A GOTO LB250 }
    $04, $00, $01, $01, $80, $4A, $01, $80, $4A,      { $B12E ADD $01, [$4A80], [$4A80] }
    $03, $01, $80, $4A, $00, $0F,                     { $B137 COMPARE [$4A80], $0F }
    $1A,                                              { $B13D IF <= }
    $02, $01, $9C, $B6,                               { $B13E GOSUB LB69C }
    $01, $01, $50, $B2,                               { $B142 GOTO LB250 }
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
    $00,
    { #29 part 1, original }
    $03, $01, $BB, $4A, $00, $FE,                     { $B69C COMPARE [$4ABB], $FE }
    $1B,                                              { $B6A2 IF >= }
    $13,                                              { $B6A3 RETURN }
    $04, $00, $01, $01, $BB, $4A, $01, $BB, $4A,      { $B6A4 ADD $01, [$4ABB], [$4ABB] }
    $03, $01, $BB, $4A, $00, $19,                     { $B6AD COMPARE [$4ABB], $19 }
    $18,                                              { $B6B3 IF < }
    $13,                                              { $B6B4 RETURN }
    $09, $00, $FE, $01, $BB, $4A,                     { $B6B5 SAVE $FE, [$4ABB] }
    $13,                                              { $B6BB RETURN }
    { fixed }
    $03, $01, $C7, $6D, $00, $00,                     { $B69C COMPARE [$6DC7], $00 }
    $17,                                              { $B6A2 IF <> }
    $00,                                              { $B6A3 EXIT }
    $03, $01, $BB, $4A, $00, $18,                     { $B6A4 COMPARE [$4ABB], $18 }
    $18,                                              { $B6AA IF < }
    $04, $00, $01, $01, $BB, $4A, $01, $BB, $4A,      { $B6AB ADD $01, [$4ABB], [$4ABB] }
    $16,                                              { $B6B4 IF = }
    $09, $00, $FE, $01, $BB, $4A,                     { $B6B5 SAVE $FE, [$4ABB] }
    $13,                                              { $B6BB RETURN }
    { #29 part 2, original }
    $09, $00, $FF, $01, $CA, $4A,                     { $9E6D SAVE $FF, [$4ACA] }
    $02, $01, $9C, $B6,                               { $9E73 GOSUB LB69C }
    { fixed: event 1 marks itself done after the clear point }
    $02, $01, $9C, $B6,                               { $9E6D GOSUB LB69C }
    $09, $00, $FF, $01, $CA, $4A,                     { $9E71 SAVE $FF, [$4ACA] }
    { #29 part 3, original }
    $09, $00, $FF, $01, $81, $4A,                     { $A0B8 SAVE $FF, [$4A81] }
    $02, $01, $9C, $B6,                               { $A0BE GOSUB LB69C }
    { fixed: Ohlo, likewise }
    $02, $01, $9C, $B6,                               { $A0B8 GOSUB LB69C }
    $09, $00, $FF, $01, $81, $4A,                     { $A0BC SAVE $FF, [$4A81] }
    { #29 part 4, original }
    $09, $00, $FA, $01, $CE, $4A,                     { $AA81 SAVE $FA, [$4ACE] }
    $02, $01, $9C, $B6,                               { $AA87 GOSUB LB69C }
    { fixed: event 10, likewise }
    $02, $01, $9C, $B6,                               { $AA81 GOSUB LB69C }
    $09, $00, $FA, $01, $CE, $4A,                     { $AA85 SAVE $FA, [$4ACE] }
    { #29 part 5, original }
    $09, $00, $FF, $01, $D0, $4A,                     { $ABF8 SAVE $FF, [$4AD0] }
    $02, $01, $9C, $B6,                               { $ABFE GOSUB LB69C }
    { fixed: event 14, likewise }
    $02, $01, $9C, $B6,                               { $ABF8 GOSUB LB69C }
    $09, $00, $FF, $01, $D0, $4A,                     { $ABFC SAVE $FF, [$4AD0] }
    { #31, original }
    $03, $01, $34, $4A, $00, $40,                     { $9914 COMPARE [$4A34], $40 }
    $1B,                                              { $991A IF >= }
    $02, $01, $53, $99,                               { $991B GOSUB L9953 }
    $09, $00, $02, $01, $D2, $6D,                     { $991F SAVE $02, [$6DD2] }
    $09, $00, $10, $01, $D3, $6D,                     { $9925 SAVE $10, [$6DD3] }
    { fixed }
    $09, $00, $02, $01, $D2, $6D,                     { $9914 SAVE $02, [$6DD2] }
    $09, $00, $10, $01, $D3, $6D,                     { $991A SAVE $10, [$6DD3] }
    $03, $01, $34, $4A, $00, $40,                     { $9920 COMPARE [$4A34], $40 }
    $1B,                                              { $9926 IF >= }
    $02, $01, $53, $99,                               { $9927 GOSUB L9953 }
    { #32, original }
    $02, $01, $0C, $9E,                               { $9DEE GOSUB L9E0C }
    $03, $01, $4F, $C0, $00, $7F,                     { $9DF2 COMPARE [$C04F], $7F }
    $18,                                              { $9DF8 IF < }
    $01, $01, $68, $9E,                               { $9DF9 GOTO L9E68 }
    $03, $01, $C7, $6D, $00, $80,                     { $9DFD COMPARE [$6DC7], $80 }
    $19,                                              { $9E03 IF > }
    $01, $01, $23, $9E,                               { $9E04 GOTO L9E23 }
    $01, $01, $1E, $9E,                               { $9E08 GOTO L9E1E }
    $03, $01, $34, $4A, $00, $40,                     { $9E0C COMPARE [$4A34], $40 }
    $1B,                                              { $9E12 IF >= }
    $13,                                              { $9E13 RETURN }
    $04, $00, $01, $01, $34, $4A, $01, $34, $4A,      { $9E14 ADD $01, [$4A34], [$4A34] }
    $13,                                              { $9E1D RETURN }
    { fixed }
    $04, $01, $C7, $6D, $01, $34, $4A, $01, $79, $6E, { $9DEE ADD [$6DC7], [$4A34], [$6E79] }
    $03, $01, $79, $6E, $00, $40,                     { $9DF8 COMPARE [$6E79], $40 }
    $18,                                              { $9DFE IF < }
    $04, $00, $01, $01, $34, $4A, $01, $34, $4A,      { $9DFF ADD $01, [$4A34], [$4A34] }
    $03, $01, $4F, $C0, $00, $7F,                     { $9E08 COMPARE [$C04F], $7F }
    $18,                                              { $9E0E IF < }
    $01, $01, $68, $9E,                               { $9E0F GOTO L9E68 }
    $03, $01, $C7, $6D, $00, $80,                     { $9E13 COMPARE [$6DC7], $80 }
    $19,                                              { $9E19 IF > }
    $01, $01, $23, $9E,                               { $9E1A GOTO L9E23 }
    { #33 part 1, original }
    $0B, $00, $29, $00, $01, $00, $10,                { $AAA6 LOAD MONSTER $29, $01, $10 }
    { fixed }
    $01, $01, $94, $B2,                               { $AAA6 GOTO LB294 }
    $00, $00, $00,
    { #33 part 2, added at $B294: the buccaneer only before the duel, then the rest as before }
    $03, $01, $37, $4A, $00, $00,                     { $B294 COMPARE [$4A37], $00 }
    $16,                                              { $B29A IF = }
    $0B, $00, $29, $00, $01, $00, $10,                { $B29B LOAD MONSTER $29, $01, $10 }
    $0B, $00, $04, $00, $08, $00, $04,                { $B2A2 LOAD MONSTER $04, $08, $04 }
    $24,                                              { $B2A9 COMBAT }
    $01, $01, $B5, $AA,                               { $B2AA GOTO LAAB5 }
    { #34 part 1, original }
    $01, $01, $85, $9A,                               { $9A3C GOTO L9A85 }
    { fixed: the patrol goes by new code that marks it uncounted }
    $01, $01, $18, $B1,                               { $9A3C GOTO LB118 }
    { #34 part 2, original }
    $04, $00, $01, $01, $E4, $4A, $01, $E4, $4A,      { $9A65 ADD $01, [$4AE4], [$4AE4] }
    $14, $01, $E4, $4A, $00, $0A, $01, $75, $4A, $00, $FF, { $9A6E COMPARE AND [$4AE4], $0A, [$4A75], $FF }
    $17,                                              { $9A79 IF <> }
    $01, $01, $85, $9A,                               { $9A7A GOTO L9A85 }
    $09, $00, $FE, $01, $E6, $4A,                     { $9A7E SAVE $FE, [$4AE6] }
    $00,                                              { $9A84 EXIT }
    { fixed: a counted encounter, unless nine are won and the ogre is dead, which clears the block }
    $09, $00, $01, $01, $7C, $6E,                     { $9A65 SAVE $01, [$6E7C] }
    $14, $01, $E4, $4A, $00, $09, $01, $75, $4A, $00, $FF, { $9A6B COMPARE AND [$4AE4], $09, [$4A75], $FF }
    $17,                                              { $9A76 IF <> }
    $01, $01, $85, $9A,                               { $9A77 GOTO L9A85 }
    $09, $00, $FE, $01, $E6, $4A,                     { $9A7B SAVE $FE, [$4AE6] }
    $00,                                              { $9A81 EXIT }
    $00, $00, $00,
    { #34 part 3, original }
    $03, $01, $C7, $6D, $00, $80,                     { $9AEB COMPARE [$6DC7], $80 }
    $19,                                              { $9AF1 IF > }
    $01, $01, $FB, $9C,                               { $9AF2 GOTO L9CFB }
    $00,                                              { $9AF6 EXIT }
    { fixed: after the frogs, the new result code }
    $01, $01, $22, $B1,                               { $9AEB GOTO LB122 }
    $00, $00, $00, $00, $00, $00, $00, $00,
    { #34 part 4, original }
    $03, $01, $C7, $6D, $00, $80,                     { $9B30 COMPARE [$6DC7], $80 }
    $19,                                              { $9B36 IF > }
    $01, $01, $FB, $9C,                               { $9B37 GOTO L9CFB }
    $00,                                              { $9B3B EXIT }
    { fixed: after the hobgoblins, likewise }
    $01, $01, $22, $B1,                               { $9B30 GOTO LB122 }
    $00, $00, $00, $00, $00, $00, $00, $00,
    { #34 part 5, original }
    $03, $01, $C7, $6D, $00, $80,                     { $9B85 COMPARE [$6DC7], $80 }
    $19,                                              { $9B8B IF > }
    $01, $01, $FB, $9C,                               { $9B8C GOTO L9CFB }
    $00,                                              { $9B90 EXIT }
    { fixed: after the skeletons, likewise }
    $01, $01, $22, $B1,                               { $9B85 GOTO LB122 }
    $00, $00, $00, $00, $00, $00, $00, $00,
    { #34 part 6, original }
    $03, $01, $C7, $6D, $00, $80,                     { $9BD6 COMPARE [$6DC7], $80 }
    $19,                                              { $9BDC IF > }
    $01, $01, $FB, $9C,                               { $9BDD GOTO L9CFB }
    $00,                                              { $9BE1 EXIT }
    { fixed: after the ghouls, likewise }
    $01, $01, $22, $B1,                               { $9BD6 GOTO LB122 }
    $00, $00, $00, $00, $00, $00, $00, $00,
    { #34 part 7, original }
    $03, $01, $C7, $6D, $00, $80,                     { $9C1B COMPARE [$6DC7], $80 }
    $19,                                              { $9C21 IF > }
    $01, $01, $FB, $9C,                               { $9C22 GOTO L9CFB }
    $00,                                              { $9C26 EXIT }
    { fixed: after the scorpions, likewise }
    $01, $01, $22, $B1,                               { $9C1B GOTO LB122 }
    $00, $00, $00, $00, $00, $00, $00, $00,
    { #34 part 8, added at $B118: the patrol mark, then the result code: fled, run as before; won a counted
      encounter, count it }
    $09, $00, $00, $01, $7C, $6E,                     { $B118 SAVE $00, [$6E7C] }
    $01, $01, $85, $9A,                               { $B11E GOTO L9A85 }
    $03, $01, $C7, $6D, $00, $80,                     { $B122 COMPARE [$6DC7], $80 }
    $19,                                              { $B128 IF > }
    $01, $01, $FB, $9C,                               { $B129 GOTO L9CFB }
    $14, $01, $C7, $6D, $00, $00, $01, $7C, $6E, $00, $01, { $B12D COMPARE AND [$6DC7], $00, [$6E7C], $01 }
    $16,                                              { $B138 IF = }
    $04, $00, $01, $01, $E4, $4A, $01, $E4, $4A,      { $B139 ADD $01, [$4AE4], [$4AE4] }
    $00,                                              { $B142 EXIT }
    { #35 part 1, original }
    $03, $01, $E6, $4A, $00, $FD,                     { $9949 COMPARE [$4AE6], $FD }
    $19,                                              { $994F IF > }
    $09, $00, $00, $01, $D2, $6D,                     { $9950 SAVE $00, [$6DD2] }
    $00,                                              { $9956 EXIT }
    { fixed: on to new code at the end of the script }
    $01, $01, $43, $B1,                               { $9949 GOTO LB143 }
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
    { #35 part 2, added at $B143: with nine encounters won, clear the block if the ogre is dead and rest safely
      unless a patrol can come; then the cleared-block check as before }
    $03, $01, $E4, $4A, $00, $09,                     { $B143 COMPARE [$4AE4], $09 }
    $18,                                              { $B149 IF < }
    $01, $01, $76, $B1,                               { $B14A GOTO LB176 }
    $03, $01, $75, $4A, $00, $FF,                     { $B14E COMPARE [$4A75], $FF }
    $16,                                              { $B154 IF = }
    $09, $00, $FE, $01, $E6, $4A,                     { $B155 SAVE $FE, [$4AE6] }
    $2F, $00, $7F, $01, $4F, $C0, $01, $82, $6E,      { $B15B AND $7F, [$C04F], [$6E82] }
    $14, $01, $82, $6E, $00, $16, $01, $75, $4A, $00, $00, { $B164 COMPARE AND [$6E82], $16, [$4A75], $00 }
    $17,                                              { $B16F IF <> }
    $09, $00, $00, $01, $D2, $6D,                     { $B170 SAVE $00, [$6DD2] }
    $03, $01, $E6, $4A, $00, $FD,                     { $B176 COMPARE [$4AE6], $FD }
    $19,                                              { $B17C IF > }
    $09, $00, $00, $01, $D2, $6D,                     { $B17D SAVE $00, [$6DD2] }
    $00,                                              { $B183 EXIT }
    { #36, original }
    $00, $00,
    { fixed: effect 27 (Feather Fall), special 128 }
    $1B, $80,
    { #37 part 1, original }
    $03, $01, $B8, $4A, $00, $FF,                     { $AE71 COMPARE [$4AB8], $FF }
    $16,                                              { $AE77 IF = }
    { fixed: the chest must be held unopened }
    $03, $01, $C8, $4A, $00, $01,                     { $AE71 COMPARE [$4AC8], $01 }
    $17,                                              { $AE77 IF <> }
    { #37 part 2, original }
    $17,
    { fixed: COMPARE [$4A76], $01 }
    $76,
    { #37 part 3, original }
    $17,
    { fixed: SAVE $01, [$4A76] }
    $76,
    { #38, original }
    $04, $00, $05, $01, $45, $4A, $01, $79, $6E,      { $AAB9 ADD $05, [$4A45], [$6E79] }
    $03, $01, $79, $6E, $00, $15,                     { $AAC2 COMPARE [$6E79], $15 }
    $1B,                                              { $AAC8 IF >= }
    $01, $01, $EE, $AA,                               { $AAC9 GOTO LAAEE }
    $03, $01, $79, $6E, $00, $0C,                     { $AACD COMPARE [$6E79], $0C }
    $1A,                                              { $AAD3 IF <= }
    $01, $01, $04, $AB,                               { $AAD4 GOTO LAB04 }
    $05, $00, $0C, $01, $79, $6E, $01, $7A, $6E,      { $AAD8 SUBTRACT $0C, [$6E79], [$6E7A] }
    $05, $01, $7A, $6E, $00, $05, $01, $7B, $6E,      { $AAE1 SUBTRACT [$6E7A], $05, [$6E7B] }
    $01, $01, $10, $AB,                               { $AAEA GOTO LAB10 }
    $05, $00, $15, $01, $79, $6E, $01, $7A, $6E,      { $AAEE SUBTRACT $15, [$6E79], [$6E7A] }
    $05, $01, $7A, $6E, $00, $05, $01, $7A, $6E,      { $AAF7 SUBTRACT [$6E7A], $05, [$6E7A] }
    $01, $01, $10, $AB,                               { $AB00 GOTO LAB10 }
    $09, $00, $05, $01, $7B, $6E,                     { $AB04 SAVE $05, [$6E7B] }
    $09, $00, $00, $01, $7A, $6E,                     { $AB0A SAVE $00, [$6E7A] }
    { fixed }
    $09, $02, $05, $00, $01, $7B, $6E,                { $AAB9 SAVE $0005, [$6E7B] }
    $09, $02, $00, $00, $01, $7A, $6E,                { $AAC0 SAVE $0000, [$6E7A] }
    $03, $01, $45, $4A, $00, $07,                     { $AAC7 COMPARE [$4A45], $07 }
    $1A,                                              { $AACD IF <= }
    $01, $01, $10, $AB,                               { $AACE GOTO LAB10 }
    $05, $00, $07, $01, $45, $4A, $01, $7A, $6E,      { $AAD2 SUBTRACT $07, [$4A45], [$6E7A] }
    $05, $01, $7A, $6E, $00, $05, $01, $7B, $6E,      { $AADB SUBTRACT [$6E7A], $05, [$6E7B] }
    $03, $01, $45, $4A, $00, $0C,                     { $AAE4 COMPARE [$4A45], $0C }
    $1A,                                              { $AAEA IF <= }
    $01, $01, $10, $AB,                               { $AAEB GOTO LAB10 }
    $09, $02, $00, $00, $01, $7B, $6E,                { $AAEF SAVE $0000, [$6E7B] }
    $05, $01, $45, $4A, $00, $15, $01, $7A, $6E,      { $AAF6 SUBTRACT [$4A45], $15, [$6E7A] }
    $03, $01, $7A, $6E, $00, $05,                     { $AAFF COMPARE [$6E7A], $05 }
    $1A,                                              { $AB05 IF <= }
    $01, $01, $10, $AB,                               { $AB06 GOTO LAB10 }
    $09, $00, $05, $01, $7A, $6E,                     { $AB0A SAVE $05, [$6E7A] }
    { #40 part 1, original }
    $9A,
    { fixed: COMPARE [$4A1F], $01 }
    $1F,
    { #40 part 2, original }
    $9A,
    { fixed: SAVE $01, [$4A1F] }
    $1F,
    { #40 part 3, original }
    $9A,
    { fixed: SAVE $FF, [$4A1F] }
    $1F,
    { #41, original }
    $06,
    { fixed: plus 8 }
    $08,
    { #42, original }
    $81,
    { fixed: HORIZONTAL MENU [$6E7A] }
    $7A,
    { #43, original }
    $5E,
    { fixed: SUBTRACT [$4A5F], $0A, [$6E80] }
    $5F,
    { #44, original }
    $0A,
    { fixed: COMPARE [$4AA9], $00 }
    $A9,
    { #45 part 1, original }
    $78, $B6,
    { fixed: entry 4 moves to $B651 }
    $51, $B6,
    { #45 part 2, original }
    $64, $A6,
    { fixed: the quarters before dinner go by the new check at $B67D }
    $7D, $B6,
    { #45 part 3, original }
    $03, $01, $B4, $4A, $00, $00,                     { $B625 COMPARE [$4AB4], $00 }
    $17,                                              { $B62B IF <> }
    $01, $01, $48, $B6,                               { $B62C GOTO LB648 }
    $03, $01, $0E, $4A, $00, $00,                     { $B630 COMPARE [$4A0E], $00 }
    $16,                                              { $B636 IF = }
    $01, $01, $48, $B6,                               { $B637 GOTO LB648 }
    $09, $00, $64, $01, $D3, $6D,                     { $B63B SAVE $64, [$6DD3] }
    $09, $00, $01, $01, $D2, $6D,                     { $B641 SAVE $01, [$6DD2] }
    $00,                                              { $B647 EXIT }
    $03, $01, $B4, $4A, $00, $00,                     { $B648 COMPARE [$4AB4], $00 }
    $17,                                              { $B64E IF <> }
    $01, $01, $6B, $B6,                               { $B64F GOTO LB66B }
    $03, $01, $10, $4A, $00, $00,                     { $B653 COMPARE [$4A10], $00 }
    $17,                                              { $B659 IF <> }
    $01, $01, $3B, $B6,                               { $B65A GOTO LB63B }
    $09, $00, $A8, $01, $D2, $6D,                     { $B65E SAVE $A8, [$6DD2] }
    $09, $00, $64, $01, $D3, $6D,                     { $B664 SAVE $64, [$6DD3] }
    $00,                                              { $B66A EXIT }
    $09, $00, $00, $01, $D2, $6D,                     { $B66B SAVE $00, [$6DD2] }
    $09, $00, $01, $01, $D3, $6D,                     { $B671 SAVE $01, [$6DD3] }
    $00,                                              { $B677 EXIT }
    $09, $00, $00, $01, $D3, $6D,                     { $B678 SAVE $00, [$6DD3] }
    $03, $01, $10, $4A, $00, $00,                     { $B67E COMPARE [$4A10], $00 }
    $16,                                              { $B684 IF = }
    $01, $01, $DF, $A6,                               { $B685 GOTO LA6DF }
    $09, $00, $39, $01, $E1, $6D,                     { $B689 SAVE $39, [$6DE1] }
    $01, $01, $3E, $9A,                               { $B68F GOTO L9A3E }
    { fixed: entry 3, entry 4 and the quarters check, in the room entries 3 and 4 had }
    $09, $00, $64, $01, $D3, $6D,                     { $B625 SAVE $64, [$6DD3] }
    $09, $00, $A8, $01, $D2, $6D,                     { $B62B SAVE $A8, [$6DD2] }
    $14, $01, $0E, $4A, $00, $00, $01, $10, $4A, $00, $00, { $B631 COMPARE AND [$4A0E], $00, [$4A10], $00 }
    $17,                                              { $B63C IF <> }
    $09, $00, $01, $01, $D2, $6D,                     { $B63D SAVE $01, [$6DD2] }
    $03, $01, $B4, $4A, $00, $00,                     { $B643 COMPARE [$4AB4], $00 }
    $17,                                              { $B649 IF <> }
    $09, $00, $00, $01, $D2, $6D,                     { $B64A SAVE $00, [$6DD2] }
    $00,                                              { $B650 EXIT }
    $09, $00, $00, $01, $D3, $6D,                     { $B651 SAVE $00, [$6DD3] }
    $03, $01, $10, $4A, $00, $00,                     { $B657 COMPARE [$4A10], $00 }
    $17,                                              { $B65D IF <> }
    $01, $01, $73, $B6,                               { $B65E GOTO LB673 }
    $03, $01, $0E, $4A, $00, $00,                     { $B662 COMPARE [$4A0E], $00 }
    $16,                                              { $B668 IF = }
    $01, $01, $DF, $A6,                               { $B669 GOTO LA6DF }
    $09, $00, $04, $01, $79, $6E,                     { $B66D SAVE $04, [$6E79] }
    $09, $00, $39, $01, $E1, $6D,                     { $B673 SAVE $39, [$6DE1] }
    $01, $01, $3E, $9A,                               { $B679 GOTO L9A3E }
    $14, $01, $0E, $4A, $00, $00, $01, $B4, $4A, $00, $00, { $B67D COMPARE AND [$4A0E], $00, [$4AB4], $00 }
    $16,                                              { $B688 IF = }
    $01, $01, $64, $A6,                               { $B689 GOTO LA664 }
    $01, $01, $E7, $B5,                               { $B68D GOTO LB5E7 }
    $00, $00,
    { #46, original }
    $80,
    { fixed: event 5 }
    $85,
    { #47, original }
    $0D, $41, $4C, $2D, $48, $59, $41, $4D, $20, $44, $41, $5A, $49, $44, $00, $00,
    { fixed: ZHENTARIM MAGE }
    $0E, $5A, $48, $45, $4E, $54, $41, $52, $49, $4D, $20, $4D, $41, $47, $45, $00,
    { #48 part 1, original }
    $1A,
    { fixed: the paladin's crypt gives item block 29 }
    $1D,
    { #48 part 2, original }
    $1D,
    { fixed: the knight's tomb gives item block 26 }
    $1A,
    { #49, original }
    $03,
    { fixed: SAVE $02, [$4A78] }
    $02,
    { #50 part 1, original }
    $01, $01, $5D, $A7,                               { $ACF8 GOTO LA75D }
    { fixed: on to new code at the end of the script }
    $01, $01, $DD, $B1,                               { $ACF8 GOTO LB1DD }
    { #50 part 2, added at $B1DD: hostile from now on, then the weapons menu as before }
    $09, $00, $03, $01, $78, $4A,                     { $B1DD SAVE $03, [$4A78] }
    $01, $01, $5D, $A7,                               { $B1E3 GOTO LA75D }
    { #51, original }
    $00, $98,
    { fixed: ADD $01, [$4A62], [$4A64] }
    $62, $4A,
    { #52 part 1, original }
    $09, $00, $00, $01, $CB, $6D,                     { $B10F SAVE $00, [$6DCB] }
    { fixed: the fight goes to $B1E7 }
    $01, $01, $E7, $B1,                               { $B10F GOTO LB1E7 }
    $00, $00,
    { #52 part 2, added at $B1E7: one garrison per tower still standing }
    $09, $00, $00, $01, $CB, $6D,                     { $B1E7 SAVE $00, [$6DCB] }
    $09, $00, $50, $01, $C6, $6D,                     { $B1ED SAVE $50, [$6DC6] }
    $09, $00, $01, $01, $7B, $6E,                     { $B1F3 SAVE $01, [$6E7B] }
    $2F, $01, $77, $4A, $00, $0C, $01, $82, $6E,      { $B1F9 AND [$4A77], $0C, [$6E82] }
    $16,                                              { $B202 IF = }
    $09, $00, $02, $01, $7B, $6E,                     { $B203 SAVE $02, [$6E7B] }
    $09, $00, $18, $01, $7C, $6E,                     { $B209 SAVE $18, [$6E7C] }
    $2F, $01, $77, $4A, $00, $08, $01, $82, $6E,      { $B20F AND [$4A77], $08, [$6E82] }
    $17,                                              { $B218 IF <> }
    $09, $00, $59, $01, $7C, $6E,                     { $B219 SAVE $59, [$6E7C] }
    $02, $01, $E2, $9B,                               { $B21F GOSUB L9BE2 }
    $1C,                                              { $B223 CLEARMONSTERS }
    $0B, $01, $7C, $6E, $01, $7B, $6E, $00, $0E,      { $B224 LOAD MONSTER [$6E7C], [$6E7B], $0E }
    $0B, $00, $35, $01, $7B, $6E, $00, $0B,           { $B22D LOAD MONSTER $35, [$6E7B], $0B }
    $07, $01, $7B, $6E, $00, $03, $01, $7B, $6E,      { $B235 MULTIPLY [$6E7B], $03, [$6E7B] }
    $0B, $00, $47, $01, $7B, $6E, $00, $47,           { $B23E LOAD MONSTER $47, [$6E7B], $47 }
    $01, $01, $35, $B1,                               { $B246 GOTO LB135 }
    { #54, original }
    $1B,                                              { $A9EE IF >= }
    { fixed: IF < }
    $18,                                              { $A9EE IF < }
    { #55, original }
    $72,
    { fixed: OR [$4A6D], $10, [$4A6D] }
    $6D,
    { #70 part 1, original }
    $10,
    { fixed: (4,15) south: solid }
    $00,
    { #70 part 2, original }
    $10,
    { fixed: (11,15) south: solid }
    $00,
    { #203, original }
    $5C, $AA, $A7, $58, $02, $00,
    { fixed: type 92, Cloak of Displacement, plus 2, save bonus 2 }
    $5C, $AA, $A7, $58, $02, $02,
    { #203, original }
    $43, $AA, $A7, $58, $08, $00,
    { fixed: type 92, Cloak of Displacement, plus 2, save bonus 2 }
    $5C, $AA, $A7, $58, $02, $02,
    { #355 part 1, original }
    $04, $00, $01, $01, $00, $4A, $01, $00, $4A,      { $9AE6 ADD $01, [$4A00], [$4A00] }
    $00,                                              { $9AEF EXIT }
    { fixed: after the notice, on to new code at the end of the script }
    $01, $01, $79, $A1,                               { $9AE6 GOTO LA179 }
    $00, $00, $00, $00, $00, $00,
    { #355 part 2, added at $A179: the paladin and ranger sentence, then the notice is marked read as before }
    { $A179 PRINT "  PALADINS AND RANGERS TRAIN WITH THE FIGHTERS." }
    $11, $80, $24, $82, $04, $01, $30, $11, $09, $39, $38, $01, $38, $48, $12, $04,
    $E1, $C5, $49, $38, $14, $48, $12, $4E, $81, $72, $54, $22, $05, $08, $16, $01,
    $89, $1C, $85, $05, $49, $3B, $80,
    $04, $00, $01, $01, $00, $4A, $01, $00, $4A,      { $A1A0 ADD $01, [$4A00], [$4A00] }
    $00,                                              { $A1A9 EXIT }
    { #606 part 1, original }
    $C6, $A2,                                         { $9B8F ON GOTO [$9800] entry 20: LA2C6 }
    { fixed: event 20 goes to new code at the end of the script }
    $2F, $B6,                                         { $9B8F ON GOTO [$9800] entry 20: LB62F }
    { #606 part 2, added at $B62F: the tavern but at (8,9); there, as the arms shop, the shopkeeper, then the vault }
    $14, $01, $4B, $C0, $00, $08, $01, $4C, $C0, $00, $09, { $B62F COMPARE AND [$C04B], $08, [$C04C], $09 }
    $17,                                              { $B63A IF <> }
    $01, $01, $C6, $A2,                               { $B63B GOTO LA2C6 }
    $02, $01, $89, $AE,                               { $B63F GOSUB LAE89 }
    $09, $00, $2A, $01, $E1, $6D,                     { $B643 SAVE $2A, [$6DE1] }
    $0E, $00, $09,                                    { $B649 PICTURE $09 }
    $03, $01, $C0, $4A, $00, $00,                     { $B64C COMPARE [$4AC0], $00 }
    $19,                                              { $B652 IF > }
    $01, $01, $1D, $AE,                               { $B653 GOTO LAE1D }
    $1C,                                              { $B657 CLEARMONSTERS }
    $09, $00, $02, $01, $6C, $6E,                     { $B658 SAVE $02, [$6E6C] }
    $24,                                              { $B65E COMBAT }
    $0E, $00, $FF,                                    { $B65F PICTURE $FF }
    $00,                                              { $B662 EXIT }
    { #670, original: ...BE?'WHAT DO YOU DO? }
    $5C, $80, $54, $80, $43, $E0, $64, $F5, $60, $10, $FF, $C0,
    { fixed: ...BE?' WHAT DO YOU DO? }
    $81, $72, $01, $52, $01, $0F, $81, $93, $D5, $80, $43, $FF,
    { #682 part 1, original }
    $03, $01, $02, $4A, $00, $01,                     { $A8B0 COMPARE [$4A02], $01 }
    $16,                                              { $A8B6 IF = }
    $01, $01, $0B, $AA,                               { $A8B7 GOTO LAA0B }
    { fixed: the altar goes by new code at the end of the script }
    $01, $01, $E6, $B6,                               { $A8B0 GOTO LB6E6 }
    $00, $00, $00, $00, $00, $00, $00,
    { #682 part 2, original }
    $A3, $B0,                                         { $AC59 GOTO LB0A3 }
    { fixed: no Dirten in the party, by new code }
    $50, $B8,                                         { $AC59 GOTO LB850 }
    { #682 part 3, original }
    $03, $01, $00, $6C, $00, $7F,                     { $AC68 COMPARE [$6C00], $7F }
    $19,                                              { $AC6E IF > }
    $01, $01, $C3, $AC,                               { $AC6F GOTO LACC3 }
    { fixed: Dirten in the party, by new code }
    $01, $01, $F5, $B7,                               { $AC68 GOTO LB7F5 }
    $00, $00, $00, $00, $00, $00, $00,
    { #682 part 4, added at $B6E6: the altar once the temple is freed: no day kept (a game from before this whose
      party had Dirten) starts the days now; freed without him, as before; before 14 days, the rebuilding }
    $03, $01, $BD, $4A, $00, $FE,                     { $B6E6 COMPARE [$4ABD], $FE }
    $18,                                              { $B6EC IF < }
    $01, $01, $E6, $B7,                               { $B6ED GOTO LB7E6 }
    $03, $01, $79, $4A, $00, $00,                     { $B6F1 COMPARE [$4A79], $00 }
    $17,                                              { $B6F7 IF <> }
    $01, $01, $0B, $B7,                               { $B6F8 GOTO LB70B }
    $03, $01, $9C, $4A, $00, $FF,                     { $B6FC COMPARE [$4A9C], $FF }
    $17,                                              { $B702 IF <> }
    $01, $01, $E6, $B7,                               { $B703 GOTO LB7E6 }
    $02, $01, $5B, $B8,                               { $B707 GOSUB LB85B }
    $03, $01, $79, $4A, $02, $FF, $FF,                { $B70B COMPARE [$4A79], $FFFF }
    $16,                                              { $B712 IF = }
    $01, $01, $E6, $B7,                               { $B713 GOTO LB7E6 }
    $02, $01, $67, $B8,                               { $B717 GOSUB LB867 }
    $05, $01, $79, $4A, $01, $7B, $6E, $01, $7B, $6E, { $B71B SUBTRACT [$4A79], [$6E7B], [$6E7B] }
    $03, $01, $7B, $6E, $00, $0E,                     { $B725 COMPARE [$6E7B], $0E }
    $1B,                                              { $B72B IF >= }
    $01, $01, $77, $B7,                               { $B72C GOTO LB777 }
    { $B730 PRINTCLEAR "THE EFFORT TO REBUILD IS ALREADY UNDERWAY. SOON THE TEMPLE WILL BE SERVICEABLE AGAIN." }
    $12, $80, $40, $50, $81, $60, $14, $61, $8F, $49, $48, $14, $3E, $04, $85, $09,
    $52, $4C, $12, $02, $53, $80, $13, $12, $14, $11, $19, $81, $53, $84, $15, $25,
    $C1, $66, $E8, $13, $3C, $F3, $A0, $50, $81, $60, $50, $53, $50, $30, $58, $17,
    $24, $C3, $20, $08, $58, $13, $15, $25, $89, $0C, $50, $42, $30, $58, $01, $1C,
    $12, $4E, $B8,
    $01, $01, $A3, $B0,                               { $B773 GOTO LB0A3 }
    { #682 part 5, added at $B777: Dirten's welcome and his temple, a tenth off }
    $09, $00, $00, $01, $E1, $6D,                     { $B777 SAVE $00, [$6DE1] }
    $0E, $00, $04,                                    { $B77D PICTURE $04 }
    { $B780 PRINTCLEAR "WELCOME BACK! WE'RE STILL REBUILDING, BUT LET ME OFFER WHAT AID I CAN." }
    $12, $80, $35, $5C, $53, $03, $3C, $D1, $60, $08, $10, $CB, $86, $05, $C5, $9D,
    $21, $60, $4D, $42, $4C, $32, $04, $85, $09, $52, $4C, $10, $93, $87, $B2, $00,
    $95, $52, $03, $05, $52, $03, $45, $80, $F1, $86, $15, $28, $17, $20, $15, $20,
    $04, $91, $20, $26, $00, $C1, $3A, $E0,
    { $B7B8 HORIZONTAL MENU [$6E79], $01, "PRESS <RETURN> TO CONTINUE" }
    $2B, $01, $79, $6E, $00, $01, $80, $14, $41, $21, $53, $4E, $0F, $12, $15, $45,
    $52, $3B, $E8, $14, $3E, $00, $CF, $39, $42, $4E, $54, $50,
    $1C,                                              { $B7D4 CLEARMONSTERS }
    $09, $00, $02, $01, $E2, $6D,                     { $B7D5 SAVE $02, [$6DE2] }
    $24,                                              { $B7DB COMBAT }
    $09, $00, $FF, $01, $E1, $6D,                     { $B7DC SAVE $FF, [$6DE1] }
    $01, $01, $A3, $B0,                               { $B7E2 GOTO LB0A3 }
    { #682 part 6, added at $B7E6: the altar as before; the end of the fight with Dirten, and without him; the day }
    $03, $01, $02, $4A, $00, $01,                     { $B7E6 COMPARE [$4A02], $01 }
    $16,                                              { $B7EC IF = }
    $01, $01, $0B, $AA,                               { $B7ED GOTO LAA0B }
    $01, $01, $BB, $A8,                               { $B7F1 GOTO LA8BB }
    $02, $01, $5B, $B8,                               { $B7F5 GOSUB LB85B }
    $03, $01, $00, $6C, $00, $7F,                     { $B7F9 COMPARE [$6C00], $7F }
    $19,                                              { $B7FF IF > }
    $01, $01, $08, $B8,                               { $B800 GOTO LB808 }
    $01, $01, $73, $AC,                               { $B804 GOTO LAC73 }
    { $B808 PRINTCLEAR "THE TEMPLE GUARDS ENTER AND SECURE THE AREA. A CLERIC RUSHES TO AID THE FALLEN DIRTEN." }
    $12, $80, $41, $50, $81, $60, $50, $53, $50, $30, $58, $07, $54, $14, $84, $4E,
    $01, $4E, $50, $54, $A0, $04, $E1, $20, $4C, $50, $D5, $48, $58, $14, $20, $58,
    $01, $48, $50, $6E, $80, $18, $03, $30, $54, $89, $0E, $04, $95, $4C, $81, $53,
    $81, $43, $E0, $04, $91, $20, $50, $81, $60, $18, $13, $0C, $14, $E8, $04, $25,
    $25, $05, $3A, $E0,
    $01, $01, $C3, $AC,                               { $B84C GOTO LACC3 }
    $09, $02, $FF, $FF, $01, $79, $4A,                { $B850 SAVE $FFFF, [$4A79] }
    $01, $01, $A3, $B0,                               { $B857 GOTO LB0A3 }
    $02, $01, $67, $B8,                               { $B85B GOSUB LB867 }
    $09, $01, $7B, $6E, $01, $79, $4A,                { $B85F SAVE [$6E7B], [$4A79] }
    $13,                                              { $B866 RETURN }
    $07, $01, $CC, $49, $02, $68, $01, $01, $7B, $6E, { $B867 MULTIPLY [$49CC], $0168, [$6E7B] }
    $07, $01, $CB, $49, $00, $1E, $01, $7C, $6E,      { $B871 MULTIPLY [$49CB], $1E, [$6E7C] }
    $04, $01, $7C, $6E, $01, $7B, $6E, $01, $7B, $6E, { $B87A ADD [$6E7C], [$6E7B], [$6E7B] }
    $04, $01, $CA, $49, $01, $7B, $6E, $01, $7B, $6E, { $B884 ADD [$49CA], [$6E7B], [$6E7B] }
    $04, $00, $01, $01, $7B, $6E, $01, $7B, $6E,      { $B88E ADD $01, [$6E7B], [$6E7B] }
    $13,                                              { $B897 RETURN }
    { #683 part 1, original }
    $A8, $A1,                                         { $9D8E ON GOTO [$6E79] entry 1: LA1A8 }
    { fixed: event 1, the west barracks, goes to new code at the end of the script }
    $5A, $B2,                                         { $9D8E ON GOTO [$6E79] entry 1: LB25A }
    { #683 part 2, original }
    $C9, $A2,                                         { $9D91 ON GOTO [$6E79] entry 2: LA2C9 }
    { fixed: event 2, the east barracks, likewise }
    $6D, $B2,                                         { $9D91 ON GOTO [$6E79] entry 2: LB26D }
    { #683 part 3, original }
    $A1, $A0,                                         { $9DA0 ON GOTO [$6E79] entry 7: LA0A1 }
    { fixed: event 7, (7,9) and (8,9), likewise }
    $CC, $B2,                                         { $9DA0 ON GOTO [$6E79] entry 7: LB2CC }
    { #683 part 4, original }
    $81, $B0,                                         { $9DB2 ON GOTO [$6E79] entry 13: LB081 }
    { fixed: event 13, (7,6) and (8,6), likewise }
    $DF, $B2,                                         { $9DB2 ON GOTO [$6E79] entry 13: LB2DF }
    { #683 part 5, original }
    $6A, $A1,                                         { $A11F GOTO LA16A }
    { fixed: through the gatehouse by new code once the gate is taken }
    $4F, $B3,                                         { $A11F GOTO LB34F }
    { #683 part 6, added at $B24A: the gate taken, as the script counts it (both barracks and the bugbears); the
      barracks' new text, once a visit }
    $2F, $01, $77, $4A, $00, $1C, $01, $82, $6E,      { $B24A AND [$4A77], $1C, [$6E82] }
    $03, $01, $82, $6E, $00, $1C,                     { $B253 COMPARE [$6E82], $1C }
    $13,                                              { $B259 RETURN }
    $02, $01, $4A, $B2,                               { $B25A GOSUB LB24A }
    $17,                                              { $B25E IF <> }
    $01, $01, $A8, $A1,                               { $B25F GOTO LA1A8 }
    $09, $00, $01, $01, $7A, $6E,                     { $B263 SAVE $01, [$6E7A] }
    $01, $01, $7C, $B2,                               { $B269 GOTO LB27C }
    $02, $01, $4A, $B2,                               { $B26D GOSUB LB24A }
    $17,                                              { $B271 IF <> }
    $01, $01, $C9, $A2,                               { $B272 GOTO LA2C9 }
    $09, $00, $02, $01, $7A, $6E,                     { $B276 SAVE $02, [$6E7A] }
    $2F, $01, $01, $4A, $01, $7A, $6E, $01, $82, $6E, { $B27C AND [$4A01], [$6E7A], [$6E82] }
    $17,                                              { $B286 IF <> }
    $00,                                              { $B287 EXIT }
    $30, $01, $01, $4A, $01, $7A, $6E, $01, $01, $4A, { $B288 OR [$4A01], [$6E7A], [$4A01] }
    { $B292 PRINTCLEAR "MAKESHIFT BARRACKS HAVE BEEN ERECTED HERE FOR HOUSING NEW PHLAN TROOPS." }
    $12, $80, $36, $34, $12, $C5, $4C, $82, $46, $52, $00, $81, $49, $20, $43, $2D,
    $38, $08, $05, $61, $60, $08, $51, $4E, $80, $54, $85, $0D, $41, $44, $80, $81,
    $52, $16, $01, $8F, $4A, $02, $0F, $55, $32, $4E, $1E, $03, $85, $5E, $04, $08,
    $30, $13, $A0, $51, $23, $CF, $41, $3B, $80,
    $00,                                              { $B2CB EXIT }
    { #683 part 7, added at $B2CC: the cheer at (7,9) and (8,9), and at (7,6) and (8,6), once a visit; then the way
      through the gatehouse }
    $02, $01, $4A, $B2,                               { $B2CC GOSUB LB24A }
    $17,                                              { $B2D0 IF <> }
    $01, $01, $A1, $A0,                               { $B2D1 GOTO LA0A1 }
    $09, $00, $04, $01, $7A, $6E,                     { $B2D5 SAVE $04, [$6E7A] }
    $01, $01, $EE, $B2,                               { $B2DB GOTO LB2EE }
    $02, $01, $4A, $B2,                               { $B2DF GOSUB LB24A }
    $17,                                              { $B2E3 IF <> }
    $01, $01, $81, $B0,                               { $B2E4 GOTO LB081 }
    $09, $00, $08, $01, $7A, $6E,                     { $B2E8 SAVE $08, [$6E7A] }
    $2F, $01, $01, $4A, $01, $7A, $6E, $01, $82, $6E, { $B2EE AND [$4A01], [$6E7A], [$6E82] }
    $17,                                              { $B2F8 IF <> }
    $00,                                              { $B2F9 EXIT }
    $30, $01, $01, $4A, $01, $7A, $6E, $01, $01, $4A, { $B2FA OR [$4A01], [$6E7A], [$4A01] }
    $09, $00, $39, $01, $E1, $6D,                     { $B304 SAVE $39, [$6DE1] }
    $0E, $00, $05,                                    { $B30A PICTURE $05 }
    $09, $00, $FF, $01, $E1, $6D,                     { $B30D SAVE $FF, [$6DE1] }
    { $B313 PRINTCLEAR "THE GUARDS ON THE WALL RAISE A CHEER AS YOU PASS. 'HAIL, HEROES OF PHLAN!'" }
    $12, $80, $38, $50, $81, $60, $1D, $50, $52, $11, $38, $0F, $3A, $05, $08, $16,
    $05, $C1, $30, $C8, $12, $04, $94, $C5, $80, $18, $03, $20, $51, $52, $80, $14,
    $E0, $64, $F5, $60, $40, $14, $D3, $BA, $09, $C8, $04, $93, $2C, $80, $81, $52,
    $3C, $54, $E0, $3C, $68, $10, $20, $C0, $4E, $86, $70,
    $00,                                              { $B34E EXIT }
    $02, $01, $4A, $B2,                               { $B34F GOSUB LB24A }
    $17,                                              { $B353 IF <> }
    $01, $01, $6A, $A1,                               { $B354 GOTO LA16A }
    $2A, $01, $96, $A1, $01, $7D, $6E, $01, $4B, $C0, { $B358 GETTABLE [$A196], [$6E7D], [$C04B] }
    $2A, $01, $9C, $A1, $01, $7D, $6E, $01, $4C, $C0, { $B362 GETTABLE [$A19C], [$6E7D], [$C04C] }
    $2A, $01, $A2, $A1, $01, $7D, $6E, $01, $4F, $C0, { $B36C GETTABLE [$A1A2], [$6E7D], [$C04F] }
    $09, $00, $FF, $01, $C9, $6D,                     { $B376 SAVE $FF, [$6DC9] }
    $2D, $01, $90, $2C,                               { $B37C CALL [$2C90] }
    $00,                                              { $B380 EXIT }
    { #748, MON2CHA gnoll, original }
    $02,
    { fixed: two tiles and Large }
    $82,
    { #748, MON8CHA gnoll, original }
    $02,
    { fixed }
    $82,
    { #748, MON8CHA phase spider, original }
    $03,
    { fixed }
    $83,
    { #792, MON1CHA ogre leader, original }
    $01,
    { fixed: one tile and Large }
    $81,
    { #864 part 1, original }
    $21, $AD,                                         { $AC8B ON GOSUB [$4A18] entry 9: LAD21 }
    { fixed: the ninth proclamation goes to new code at the end of the script }
    $63, $B6,                                         { $AC8B ON GOSUB [$4A18] entry 9: LB663 }
    { #864 part 2, added at $B663: the ninth proclamation, CCXIV }
    $09, $80, $05, $0C, $36, $09, $5A, $E0, $81, $5E, $98, { $B663 SAVE "CCXIV.", str[$985E] }
    $13);                                             { $B66E RETURN }

implementation

end.

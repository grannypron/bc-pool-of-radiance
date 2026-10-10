{ The fixes DataBld makes to the shipped data as it builds the merged archives, each to a known fault in one block of a
  per-disk archive and named by its POR id in the bug catalogue. A fix is one part, or a run of parts with the same POR
  id and block, made together or not at all. A part replaces origLen bytes at offset in the decoded block with newLen
  bytes, so a fix may lengthen a block (a script that gains code at its end). It is made only when the block is size
  bytes long and holds the original bytes there; offsets and sizes are those of the block as the fixes before it in
  this table leave it. A part's bytes are the next origLen + newLen bytes of patchBytes, the original first. Changing
  the fixes means raising C_Data.VERSION. }
unit DataPat;

interface

uses C_Data;

const
  { the parts of all the fixes, and their bytes together }
  PART_COUNT = 48;
  BYTE_COUNT = 1399;

type
  { One part of a fix: the family's per-disk archive of disk, block id, which is size bytes long before this part;
    origLen bytes at offset there are replaced with newLen bytes. por is the fix's POR id. }
  TPatchPart = record
    por: Word;
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
    { POR-0020: the Flame Tongue +2 Long Sword placed in Valjevo Castle's well (ITEM5 block 36, record 0) carries
      effect 22 and special 0, so readying it never adds the Flame Tongue effect and Use casts Find Traps; it gets
      effect 6 (Flame Tongue) and special 130, a ready-item handler }
    (por: 20; family: C_Data.FAMILY_ITEM; disk: 5; id: 36; size: 63; offset: 61; origLen: 2; newLen: 2),
    { POR-0027: the arms shop's south door in New Phlan, north wall of (9,14) and south wall of (9,13), is wall type
      3, so the night lock (a type-9 shop door seen from the street) never stops the party; both become type 9 like
      every other shop door }
    (por: 27; family: C_Data.FAMILY_GEO; disk: 3; id: 0; size: 1026; offset: 235; origLen: 1; newLen: 1),
    (por: 27; family: C_Data.FAMILY_GEO; disk: 3; id: 0; size: 1026; offset: 475; origLen: 1; newLen: 1),
    { POR-0028: the Slums' random-encounter result (script $B118-$B156): a win counts the encounter and gives a clear
      point only while the 15 random encounters are not all fought, so fights that interrupt a rest stop earning
      clear points }
    (por: 28; family: C_Data.FAMILY_ECL; disk: 2; id: 20; size: 7679; offset: 6170; origLen: 63; newLen: 63),
    { POR-0029: the Slums' clear-point routine (script $B69C) gives no point and returns from the script when the
      party fled, and the four set encounters that marked themselves done before calling it call it first, so running
      from a set encounter or from Ohlo neither counts nor removes the encounter }
    (por: 29; family: C_Data.FAMILY_ECL; disk: 2; id: 20; size: 7679; offset: 7582; origLen: 32; newLen: 32),
    (por: 29; family: C_Data.FAMILY_ECL; disk: 2; id: 20; size: 7679; offset: 1391; origLen: 10; newLen: 10),
    (por: 29; family: C_Data.FAMILY_ECL; disk: 2; id: 20; size: 7679; offset: 1978; origLen: 10; newLen: 10),
    (por: 29; family: C_Data.FAMILY_ECL; disk: 2; id: 20; size: 7679; offset: 4483; origLen: 10; newLen: 10),
    (por: 29; family: C_Data.FAMILY_ECL; disk: 2; id: 20; size: 7679; offset: 4858; origLen: 10; newLen: 10),
    { POR-0031: Podal Plaza's pre-camp entry (script $9914-$992A) set the on-mission rest (an interruption every 5
      minutes, 99%) and then overwrote it with the default (every 10 minutes, 16%); the default now comes first }
    (por: 31; family: C_Data.FAMILY_ECL; disk: 1; id: 18; size: 6550; offset: 22; origLen: 23; newLen: 23),
    { POR-0032: Podal Plaza's random encounters (script $9DEE-$9E1D) added to the clearing count before looking at
      the result, so fleeing counted as a win; the count now goes up only after a win ([$6DC7] = 0) while it is below
      the mission's $40 }
    (por: 32; family: C_Data.FAMILY_ECL; disk: 1; id: 18; size: 6550; offset: 1264; origLen: 48; newLen: 48),
    { POR-0033: the Pitt's tavern brawl (script $AAA6) always brought back the buccaneer beaten in the duel, with his
      Long Sword +1 and Chain Mail +1; the brawl now loads him only while [$4A37] = 0, from new code at the end of
      the script }
    (por: 33; family: C_Data.FAMILY_ECL; disk: 1; id: 18; size: 6550; offset: 4520; origLen: 7; newLen: 7),
    (por: 33; family: C_Data.FAMILY_ECL; disk: 1; id: 18; size: 6550; offset: 6550; origLen: 0; newLen: 26),
    { POR-0034: the Cadorna Textile House counted a random encounter as it began (script $9A65), so fleeing it
      counted toward clearing the block; the count now goes up after a won encounter, from new code at the end of the
      script, and [$6E7C] tells the counted encounters from the uncounted hobgoblin patrol }
    (por: 34; family: C_Data.FAMILY_ECL; disk: 4; id: 2; size: 6170; offset: 318; origLen: 4; newLen: 4),
    (por: 34; family: C_Data.FAMILY_ECL; disk: 4; id: 2; size: 6170; offset: 359; origLen: 32; newLen: 32),
    (por: 34; family: C_Data.FAMILY_ECL; disk: 4; id: 2; size: 6170; offset: 493; origLen: 12; newLen: 12),
    (por: 34; family: C_Data.FAMILY_ECL; disk: 4; id: 2; size: 6170; offset: 562; origLen: 12; newLen: 12),
    (por: 34; family: C_Data.FAMILY_ECL; disk: 4; id: 2; size: 6170; offset: 647; origLen: 12; newLen: 12),
    (por: 34; family: C_Data.FAMILY_ECL; disk: 4; id: 2; size: 6170; offset: 728; origLen: 12; newLen: 12),
    (por: 34; family: C_Data.FAMILY_ECL; disk: 4; id: 2; size: 6170; offset: 797; origLen: 12; newLen: 12),
    (por: 34; family: C_Data.FAMILY_ECL; disk: 4; id: 2; size: 6170; offset: 6170; origLen: 0; newLen: 43),
    { POR-0035: the Cadorna Textile House's pre-camp entry (script $9949) made rest safe only once the block was
      cleared, so with nine encounters won a rest could be broken off with no fight; it is now also safe then unless
      the ogre lives and the party is on a patrol square, and with the ogre dead the block is cleared }
    (por: 35; family: C_Data.FAMILY_ECL; disk: 4; id: 2; size: 6213; offset: 75; origLen: 14; newLen: 14),
    (por: 35; family: C_Data.FAMILY_ECL; disk: 4; id: 2; size: 6213; offset: 6213; origLen: 0; newLen: 65),
    { POR-0036: the Ring of Feather Falling under the Wealthy Area's trap door (ITEM1 block 6, record 0) carries
      effect 0 and special 0, so readying it gives no Feather Fall; it gets effect 27 and special 128, as a random
      one has }
    (por: 36; family: C_Data.FAMILY_ITEM; disk: 1; id: 6; size: 189; offset: 61; origLen: 2; newLen: 2),
    { POR-0037: Restal at the bottom of the Textile House well (script $AE71-$AF0A) kept his 'already resealed' flag
      in [$4A17], which entering the area clears, so he resealed and paid again on every visit; he now deals only
      while the party holds the sealed chest ([$4AC8] = 1) and once a game, flagged in the unused [$4A76] }
    (por: 37; family: C_Data.FAMILY_ECL; disk: 4; id: 2; size: 6278; offset: 5491; origLen: 7; newLen: 7),
    (por: 37; family: C_Data.FAMILY_ECL; disk: 4; id: 2; size: 6278; offset: 5504; origLen: 1; newLen: 1),
    (por: 37; family: C_Data.FAMILY_ECL; disk: 4; id: 2; size: 6278; offset: 5644; origLen: 1; newLen: 1),
    { POR-0038: Kovel Mansion's weapons-pile ambush (script $AAB9-$AB0F): 0..7 thieves killed give 5 1st-level
      thieves, 8..12 give c-7 6th-level and 12-c 1st-level as before, 13..16 give 5 6th-level and 17 gives 4, where
      the shipped script took the 1st-level count below zero or left it stale }
    (por: 38; family: C_Data.FAMILY_ECL; disk: 3; id: 14; size: 7332; offset: 4539; origLen: 87; newLen: 87),
    { POR-0040: leaving the cleared Sorcerer's Pyramid (script $AE11, $AF2B, $AF3B) used the Valjevo commission state
      [$4A9A] as its scratch flag and left it at $FF, so the council's Valjevo summons never came; the flag is now
      the entry word [$4A1F], which this script uses nowhere else }
    (por: 40; family: C_Data.FAMILY_ECL; disk: 7; id: 26; size: 6569; offset: 5397; origLen: 1; newLen: 1),
    (por: 40; family: C_Data.FAMILY_ECL; disk: 7; id: 26; size: 6569; offset: 5681; origLen: 1; newLen: 1),
    (por: 40; family: C_Data.FAMILY_ECL; disk: 7; id: 26; size: 6569; offset: 5697; origLen: 1; newLen: 1),
    { POR-0041: the Nomad Camp shaman's Bracers AC 2 (MON7ITM block 43, record 1) are priced and named for AC 2 but
      carry plus 6, which gives AC 4; the plus becomes 8 }
    (por: 41; family: C_Data.FAMILY_MONITM; disk: 7; id: 43; size: 189; offset: 113; origLen: 1; newLen: 1),
    { POR-0042: Lizardman Keep's 'press Return' prompt (script $9A64) wrote its answer into [$6E81], the old
      lizardman's record of which location the party is at, so a wrong friend-word at location 3 or 10 started
      location 1's fight; the prompt now writes [$6E7A], which nothing reads before setting it }
    (por: 42; family: C_Data.FAMILY_ECL; disk: 8; id: 16; size: 5394; offset: 360; origLen: 1; newLen: 1),
    { POR-0043: Lizardman Keep's count of giant lizards still to come (script $99AD) subtracted the pool-treasure
      flags [$4A5E] instead of the giant lizards killed [$4A5F], so the catacomb ambush was always ten; it subtracts
      the kills }
    (por: 43; family: C_Data.FAMILY_ECL; disk: 8; id: 16; size: 5394; offset: 177; origLen: 1; newLen: 1),
    { POR-0044: the Buccaneer Base slave pen (script $B4C7) tested a scratch word, not the heir's state, so it
      offered the boy again after he was bought, rescued or lost; it tests [$4AA9] }
    (por: 44; family: C_Data.FAMILY_ECL; disk: 6; id: 1; size: 7673; offset: 7115; origLen: 1; newLen: 1),
    { POR-0045: the Zhentil Keep Outpost offered dinner after the party had fought the garrison or killed the
      commandant: the quarters (script $A400) offer it only while neither has happened, and a rest after fighting the
      guards brings four guards, not the dinner escort (entry 4). Entries 3 and 4 are rewritten in less room to fit,
      entry 3 the same as before }
    (por: 45; family: C_Data.FAMILY_ECL; disk: 6; id: 28; size: 7669; offset: 16; origLen: 2; newLen: 2),
    (por: 45; family: C_Data.FAMILY_ECL; disk: 6; id: 28; size: 7669; offset: 2827; origLen: 2; newLen: 2),
    (por: 45; family: C_Data.FAMILY_ECL; disk: 6; id: 28; size: 7669; offset: 7463; origLen: 110; newLen: 110),
    { POR-0046: at the Zhentil Keep Outpost a party that beat the guards outside its quarters could walk west and
      through the one-way wall at (2,0), never stepping on (4,1) where the dwarf and the commandant attack; (3,0)
      gets the same event, 5, keeping its outdoor bit }
    (por: 46; family: C_Data.FAMILY_GEO; disk: 6; id: 28; size: 1026; offset: 517; origLen: 1; newLen: 1),
    { POR-0047: the Zhentil Keep Outpost's commandant fight (MON6CHA block 86) uses a copy of Al-Hyam Dazid, whom the
      party meets alive later in Valjevo Castle; disk 6's copy is renamed Zhentarim Mage, disk 5's Al-Hyam is
      unchanged }
    (por: 47; family: C_Data.FAMILY_MONCHA; disk: 6; id: 86; size: 285; offset: 0; origLen: 16; newLen: 16),
    { POR-0048: the graveyard's two tombs (script $A3D2 and $AD17) gave each other's treasure: the paladin's crypt
      had no armour and a magic-user scroll, the knight's tomb the paladin's plate, shield and lawful-good sword; the
      two item blocks trade places }
    (por: 48; family: C_Data.FAMILY_ECL; disk: 4; id: 10; size: 7672; offset: 2788; origLen: 1; newLen: 1),
    (por: 48; family: C_Data.FAMILY_ECL; disk: 4; id: 10; size: 7672; offset: 5161; origLen: 1; newLen: 1),
    { POR-0049: at Stojanow Gate, refusing the bugbears' 15 gold (or not having it) and being told to 'come back when
      you've learned the rules' (script $AC32) made them hostile for good; they now become more suspicious, attitude
      2, so the party may come back }
    (por: 49; family: C_Data.FAMILY_ECL; disk: 2; id: 9; size: 6367; offset: 4918; origLen: 1; newLen: 1),
    { POR-0050: at Stojanow Gate, bugbears who unmasked the party as impostors (script $ACF8) never turned hostile,
      so the wagon bluff could be tried again until it worked; they now set the hostile attitude, 3, in new code at
      the end of the script }
    (por: 50; family: C_Data.FAMILY_ECL; disk: 2; id: 9; size: 6367; offset: 5114; origLen: 4; newLen: 4),
    (por: 50; family: C_Data.FAMILY_ECL; disk: 2; id: 9; size: 6367; offset: 6367; origLen: 0; newLen: 10),
    { POR-0051: Stojanow Gate's alarm (script $9C0C) set its end hour from the stray word [$9800] instead of the hour
      it was raised, [$4A62], so it ended at once or never; it uses [$4A62] as Valjevo Castle's alarm does }
    (por: 51; family: C_Data.FAMILY_ECL; disk: 2; id: 9; size: 6377; offset: 786; origLen: 2; newLen: 2),
    { POR-0052: Stojanow Gate's location 13 (script $B10F) always fought both tower garrisons, even one already
      killed; new code at the end of the script loads only the surviving garrison, as the alarm fight does, then
      fights as before }
    (por: 52; family: C_Data.FAMILY_ECL; disk: 2; id: 9; size: 6377; offset: 6161; origLen: 6; newLen: 6),
    (por: 52; family: C_Data.FAMILY_ECL; disk: 2; id: 9; size: 6377; offset: 6377; origLen: 0; newLen: 99));
  patchBytes: array[0..BYTE_COUNT - 1] of Byte = (
    { POR-0020, original }
    $16, $00,
    { fixed: effect 6, special 130 }
    $06, $82,
    { POR-0027 part 1, original }
    $30,
    { fixed: (9,14) north: wall type 9 }
    $90,
    { POR-0027 part 2, original }
    $30,
    { fixed: (9,13) south: wall type 9 }
    $90,
    { POR-0028, original }
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
    { POR-0029 part 1, original }
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
    { POR-0029 part 2, original }
    $09, $00, $FF, $01, $CA, $4A,                     { $9E6D SAVE $FF, [$4ACA] }
    $02, $01, $9C, $B6,                               { $9E73 GOSUB LB69C }
    { fixed: event 1 marks itself done after the clear point }
    $02, $01, $9C, $B6,                               { $9E6D GOSUB LB69C }
    $09, $00, $FF, $01, $CA, $4A,                     { $9E71 SAVE $FF, [$4ACA] }
    { POR-0029 part 3, original }
    $09, $00, $FF, $01, $81, $4A,                     { $A0B8 SAVE $FF, [$4A81] }
    $02, $01, $9C, $B6,                               { $A0BE GOSUB LB69C }
    { fixed: Ohlo, likewise }
    $02, $01, $9C, $B6,                               { $A0B8 GOSUB LB69C }
    $09, $00, $FF, $01, $81, $4A,                     { $A0BC SAVE $FF, [$4A81] }
    { POR-0029 part 4, original }
    $09, $00, $FA, $01, $CE, $4A,                     { $AA81 SAVE $FA, [$4ACE] }
    $02, $01, $9C, $B6,                               { $AA87 GOSUB LB69C }
    { fixed: event 10, likewise }
    $02, $01, $9C, $B6,                               { $AA81 GOSUB LB69C }
    $09, $00, $FA, $01, $CE, $4A,                     { $AA85 SAVE $FA, [$4ACE] }
    { POR-0029 part 5, original }
    $09, $00, $FF, $01, $D0, $4A,                     { $ABF8 SAVE $FF, [$4AD0] }
    $02, $01, $9C, $B6,                               { $ABFE GOSUB LB69C }
    { fixed: event 14, likewise }
    $02, $01, $9C, $B6,                               { $ABF8 GOSUB LB69C }
    $09, $00, $FF, $01, $D0, $4A,                     { $ABFC SAVE $FF, [$4AD0] }
    { POR-0031, original }
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
    { POR-0032, original }
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
    { POR-0033 part 1, original }
    $0B, $00, $29, $00, $01, $00, $10,                { $AAA6 LOAD MONSTER $29, $01, $10 }
    { fixed }
    $01, $01, $94, $B2,                               { $AAA6 GOTO LB294 }
    $00, $00, $00,
    { POR-0033 part 2, added at $B294: the buccaneer only before the duel, then the rest as before }
    $03, $01, $37, $4A, $00, $00,                     { $B294 COMPARE [$4A37], $00 }
    $16,                                              { $B29A IF = }
    $0B, $00, $29, $00, $01, $00, $10,                { $B29B LOAD MONSTER $29, $01, $10 }
    $0B, $00, $04, $00, $08, $00, $04,                { $B2A2 LOAD MONSTER $04, $08, $04 }
    $24,                                              { $B2A9 COMBAT }
    $01, $01, $B5, $AA,                               { $B2AA GOTO LAAB5 }
    { POR-0034 part 1, original }
    $01, $01, $85, $9A,                               { $9A3C GOTO L9A85 }
    { fixed: the patrol goes by new code that marks it uncounted }
    $01, $01, $18, $B1,                               { $9A3C GOTO LB118 }
    { POR-0034 part 2, original }
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
    { POR-0034 part 3, original }
    $03, $01, $C7, $6D, $00, $80,                     { $9AEB COMPARE [$6DC7], $80 }
    $19,                                              { $9AF1 IF > }
    $01, $01, $FB, $9C,                               { $9AF2 GOTO L9CFB }
    $00,                                              { $9AF6 EXIT }
    { fixed: after the frogs, the new result code }
    $01, $01, $22, $B1,                               { $9AEB GOTO LB122 }
    $00, $00, $00, $00, $00, $00, $00, $00,
    { POR-0034 part 4, original }
    $03, $01, $C7, $6D, $00, $80,                     { $9B30 COMPARE [$6DC7], $80 }
    $19,                                              { $9B36 IF > }
    $01, $01, $FB, $9C,                               { $9B37 GOTO L9CFB }
    $00,                                              { $9B3B EXIT }
    { fixed: after the hobgoblins, likewise }
    $01, $01, $22, $B1,                               { $9B30 GOTO LB122 }
    $00, $00, $00, $00, $00, $00, $00, $00,
    { POR-0034 part 5, original }
    $03, $01, $C7, $6D, $00, $80,                     { $9B85 COMPARE [$6DC7], $80 }
    $19,                                              { $9B8B IF > }
    $01, $01, $FB, $9C,                               { $9B8C GOTO L9CFB }
    $00,                                              { $9B90 EXIT }
    { fixed: after the skeletons, likewise }
    $01, $01, $22, $B1,                               { $9B85 GOTO LB122 }
    $00, $00, $00, $00, $00, $00, $00, $00,
    { POR-0034 part 6, original }
    $03, $01, $C7, $6D, $00, $80,                     { $9BD6 COMPARE [$6DC7], $80 }
    $19,                                              { $9BDC IF > }
    $01, $01, $FB, $9C,                               { $9BDD GOTO L9CFB }
    $00,                                              { $9BE1 EXIT }
    { fixed: after the ghouls, likewise }
    $01, $01, $22, $B1,                               { $9BD6 GOTO LB122 }
    $00, $00, $00, $00, $00, $00, $00, $00,
    { POR-0034 part 7, original }
    $03, $01, $C7, $6D, $00, $80,                     { $9C1B COMPARE [$6DC7], $80 }
    $19,                                              { $9C21 IF > }
    $01, $01, $FB, $9C,                               { $9C22 GOTO L9CFB }
    $00,                                              { $9C26 EXIT }
    { fixed: after the scorpions, likewise }
    $01, $01, $22, $B1,                               { $9C1B GOTO LB122 }
    $00, $00, $00, $00, $00, $00, $00, $00,
    { POR-0034 part 8, added at $B118: the patrol mark, then the result code: fled, run as before; won a counted
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
    { POR-0035 part 1, original }
    $03, $01, $E6, $4A, $00, $FD,                     { $9949 COMPARE [$4AE6], $FD }
    $19,                                              { $994F IF > }
    $09, $00, $00, $01, $D2, $6D,                     { $9950 SAVE $00, [$6DD2] }
    $00,                                              { $9956 EXIT }
    { fixed: on to new code at the end of the script }
    $01, $01, $43, $B1,                               { $9949 GOTO LB143 }
    $00, $00, $00, $00, $00, $00, $00, $00, $00, $00,
    { POR-0035 part 2, added at $B143: with nine encounters won, clear the block if the ogre is dead and rest safely
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
    { POR-0036, original }
    $00, $00,
    { fixed: effect 27 (Feather Fall), special 128 }
    $1B, $80,
    { POR-0037 part 1, original }
    $03, $01, $B8, $4A, $00, $FF,                     { $AE71 COMPARE [$4AB8], $FF }
    $16,                                              { $AE77 IF = }
    { fixed: the chest must be held unopened }
    $03, $01, $C8, $4A, $00, $01,                     { $AE71 COMPARE [$4AC8], $01 }
    $17,                                              { $AE77 IF <> }
    { POR-0037 part 2, original }
    $17,
    { fixed: COMPARE [$4A76], $01 }
    $76,
    { POR-0037 part 3, original }
    $17,
    { fixed: SAVE $01, [$4A76] }
    $76,
    { POR-0038, original }
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
    { POR-0040 part 1, original }
    $9A,
    { fixed: COMPARE [$4A1F], $01 }
    $1F,
    { POR-0040 part 2, original }
    $9A,
    { fixed: SAVE $01, [$4A1F] }
    $1F,
    { POR-0040 part 3, original }
    $9A,
    { fixed: SAVE $FF, [$4A1F] }
    $1F,
    { POR-0041, original }
    $06,
    { fixed: plus 8 }
    $08,
    { POR-0042, original }
    $81,
    { fixed: HORIZONTAL MENU [$6E7A] }
    $7A,
    { POR-0043, original }
    $5E,
    { fixed: SUBTRACT [$4A5F], $0A, [$6E80] }
    $5F,
    { POR-0044, original }
    $0A,
    { fixed: COMPARE [$4AA9], $00 }
    $A9,
    { POR-0045 part 1, original }
    $78, $B6,
    { fixed: entry 4 moves to $B651 }
    $51, $B6,
    { POR-0045 part 2, original }
    $64, $A6,
    { fixed: the quarters before dinner go by the new check at $B67D }
    $7D, $B6,
    { POR-0045 part 3, original }
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
    { POR-0046, original }
    $80,
    { fixed: event 5 }
    $85,
    { POR-0047, original }
    $0D, $41, $4C, $2D, $48, $59, $41, $4D, $20, $44, $41, $5A, $49, $44, $00, $00,
    { fixed: ZHENTARIM MAGE }
    $0E, $5A, $48, $45, $4E, $54, $41, $52, $49, $4D, $20, $4D, $41, $47, $45, $00,
    { POR-0048 part 1, original }
    $1A,
    { fixed: the paladin's crypt gives item block 29 }
    $1D,
    { POR-0048 part 2, original }
    $1D,
    { fixed: the knight's tomb gives item block 26 }
    $1A,
    { POR-0049, original }
    $03,
    { fixed: SAVE $02, [$4A78] }
    $02,
    { POR-0050 part 1, original }
    $01, $01, $5D, $A7,                               { $ACF8 GOTO LA75D }
    { fixed: on to new code at the end of the script }
    $01, $01, $DD, $B1,                               { $ACF8 GOTO LB1DD }
    { POR-0050 part 2, added at $B1DD: hostile from now on, then the weapons menu as before }
    $09, $00, $03, $01, $78, $4A,                     { $B1DD SAVE $03, [$4A78] }
    $01, $01, $5D, $A7,                               { $B1E3 GOTO LA75D }
    { POR-0051, original }
    $00, $98,
    { fixed: ADD $01, [$4A62], [$4A64] }
    $62, $4A,
    { POR-0052 part 1, original }
    $09, $00, $00, $01, $CB, $6D,                     { $B10F SAVE $00, [$6DCB] }
    { fixed: the fight goes to $B1E7 }
    $01, $01, $E7, $B1,                               { $B10F GOTO LB1E7 }
    $00, $00,
    { POR-0052 part 2, added at $B1E7: one garrison per tower still standing }
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
    $01, $01, $35, $B1);                              { $B246 GOTO LB135 }

implementation

end.

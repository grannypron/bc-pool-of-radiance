{ The Bestiary's facts (#842): the bits of Bestiary.TBeast.known, numbered as BESTIARY.DAT keeps them. The file's format
  is meant for all four games (Pool, Curse, Secret, Pools), so a bit keeps its meaning once given: a game that learns
  something new takes a free bit. Bits 0..31 (known[0]) are what the creature is and resists, bits 32..63 (known[1]) the
  harm its attacks do. }
{$I COMPILER.INC}
unit C_BEAST;

interface

const
  { what it is }
  SIZE_KNOWN = 0;
  LARGE = 1;
  HD_KNOWN = 2;
  { its defenses, in the order the entry page lists them: halved damage, immunities, then the rest }
  FIRST_DEFENSE = 3;
  HALF_BLUNT = 3;
  HALF_PIERCE = 4;
  HALF_SLASH = 5;
  HALF_MAGICAL = 6;
  HALF_FIRE = 7;
  HALF_COLD = 8;
  HALF_ELEC = 9;
  IMMUNE_POISON = 10;
  IMMUNE_PARALYSIS = 11;
  IMMUNE_SLEEP_CHARM = 12;
  IMMUNE_MM = 13;
  IMMUNE_COLD = 14;
  IMMUNE_FIRE = 15;
  IMMUNE_ELEC = 16;
  { hurt only by a magical weapon (or by a monster of 4 hit dice or more) }
  NEEDS_MAGIC = 17;
  MAGIC_RES = 18;
  REGENERATES = 19;
  LAST_DEFENSE = 19;
  { its attacks }
  FIRST_ATTACK = 32;
  ATK_POISON = 32;
  ATK_PARALYZE = 33;
  ATK_DRAIN = 34;
  ATK_ROT = 35;
  ATK_PETRIFY = 36;
  ATK_CHARM = 37;
  LAST_ATTACK = 37;
  { the last bit the format has room for }
  LAST_FACT = 63;
  { TBeast.acLo and acHi with no bound learned on that side }
  AC_NO_LOW = -128;
  AC_NO_HIGH = 127;

implementation

end.

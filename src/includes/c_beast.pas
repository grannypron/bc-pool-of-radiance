{ Bestiary fact bits stored in Bestiary.TBeast.known (#842). Bit assignments are
  shared by all four games and must never change once published. Bits 0..31
  describe the creature and its defenses; bits 32..63 describe its attacks. }
{$I COMPILER.INC}
unit C_BEAST;

interface

uses C_EFFECT;

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
  { the sage has told all she knows of it (#868, BeastFil.Tell): the entry page shows no ?? after its defenses and
    attacks }
  TOLD = 20;
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

type
  { an effect a creature's record carries, and a fact it stands for }
  TEffectFact = record
    eff: Byte;
    fact: Byte;
  end;

const
  { What a creature's own effects say of it, as BeastFil.Tell reads them for the sage (#868): the facts EffHndlr's
    handlers for those effects teach in play. An effect has a row for each of its facts. The ids are Pool's: each game
    keeps its own table. }
  EFFECT_FACTS_COUNT = 38;
  EFFECT_FACTS: array[1..EFFECT_FACTS_COUNT] of TEffectFact = (
    { troll regeneration, regenerate 3, the troll's heal and return }
    (eff: C_EFFECT.TROLL_REGEN; fact: REGENERATES),
    (eff: C_EFFECT.REGEN3; fact: REGENERATES),
    (eff: C_EFFECT.TROLL_HEAL; fact: REGENERATES),
    (eff: C_EFFECT.TROLL_RETURN; fact: REGENERATES),
    { the poisonous bites and stings }
    (eff: C_EFFECT.POISON_HIT0; fact: ATK_POISON),
    (eff: C_EFFECT.POISON_HIT4; fact: ATK_POISON),
    (eff: C_EFFECT.POISON_HIT2; fact: ATK_POISON),
    (eff: C_EFFECT.POISON_HIT_M2; fact: ATK_POISON),
    { the thri-kreen's, the ghoul's and the drider's paralysis }
    (eff: C_EFFECT.KREEN_PARA; fact: ATK_PARALYZE),
    (eff: C_EFFECT.GHOUL_PARA; fact: ATK_PARALYZE),
    (eff: C_EFFECT.DRIDER_PARA; fact: ATK_PARALYZE),
    (eff: C_EFFECT.PETRIFY_GAZE; fact: ATK_PETRIFY),
    (eff: C_EFFECT.CHARM_GAZE; fact: ATK_CHARM),
    (eff: C_EFFECT.DRAIN_ONE; fact: ATK_DRAIN),
    (eff: C_EFFECT.DRAIN_TWO; fact: ATK_DRAIN),
    (eff: C_EFFECT.ROT_TOUCH; fact: ATK_ROT),
    { magic missile and electricity }
    (eff: C_EFFECT.IMMUNE_MM; fact: IMMUNE_MM),
    (eff: C_EFFECT.IMMUNE_MM; fact: IMMUNE_ELEC),
    (eff: C_EFFECT.HALF_FIRE; fact: HALF_FIRE),
    { blunt and piercing }
    (eff: C_EFFECT.HALF_BASH; fact: HALF_BLUNT),
    (eff: C_EFFECT.HALF_BASH; fact: HALF_PIERCE),
    (eff: C_EFFECT.MAGIC_RES50; fact: MAGIC_RES),
    (eff: C_EFFECT.MAGIC_RES85; fact: MAGIC_RES),
    (eff: C_EFFECT.NO_SLEEP_CHARM; fact: IMMUNE_SLEEP_CHARM),
    (eff: C_EFFECT.NO_PARALYSIS; fact: IMMUNE_PARALYSIS),
    (eff: C_EFFECT.NO_COLD; fact: IMMUNE_COLD),
    { paralysis and poison }
    (eff: C_EFFECT.NO_PARA_POISON; fact: IMMUNE_PARALYSIS),
    (eff: C_EFFECT.NO_PARA_POISON; fact: IMMUNE_POISON),
    (eff: C_EFFECT.NO_FIRE; fact: IMMUNE_FIRE),
    (eff: C_EFFECT.HALF_ELEC; fact: HALF_ELEC),
    { piercing and slashing }
    (eff: C_EFFECT.HALF_PIERCE; fact: HALF_PIERCE),
    (eff: C_EFFECT.HALF_PIERCE; fact: HALF_SLASH),
    (eff: C_EFFECT.HALF_MAGICAL; fact: HALF_MAGICAL),
    (eff: C_EFFECT.HALF_COLD; fact: HALF_COLD),
    (eff: C_EFFECT.NEED_MAGIC; fact: NEEDS_MAGIC),
    { sleep and charm, paralysis and poison }
    (eff: C_EFFECT.NO_CHARM_POISON; fact: IMMUNE_SLEEP_CHARM),
    (eff: C_EFFECT.NO_CHARM_POISON; fact: IMMUNE_PARALYSIS),
    (eff: C_EFFECT.NO_CHARM_POISON; fact: IMMUNE_POISON));

implementation

end.

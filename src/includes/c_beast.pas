{ Bestiary fact bits stored in Bestiary.TBeast.known (#842). Bit assignments are
  shared by all four games and must never change once published: a game that
  learns something new takes a free bit, and every bit another game has taken is
  listed here, used or not, so none is given twice. The entry page lists the
  defenses and attacks in the order BeastFil.FactAt gives, not by bit. }
{$I COMPILER.INC}
unit C_BEAST;

interface

uses C_EFFECT;

const
  { what it is }
  SIZE_KNOWN = 0;
  LARGE = 1;
  HD_KNOWN = 2;
  { its defenses }
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
  { the sage has told all she knows of it (#868, BeastFil.Tell): the entry page shows no ?? after its defenses and
    attacks }
  TOLD = 20;
  { Pools of Darkness's own, which this game does not use: hurt only by a +2 weapon or better, or +3 or better; half
    damage from weapons of +3 or worse; no harm from dragon breath; no disease (goldbox-tp7's games/pod) }
  POOLS_NEEDS_PLUS_2 = 21;
  POOLS_NEEDS_PLUS_3 = 22;
  POOLS_HALF_UNDER_PLUS_4 = 23;
  POOLS_IMMUNE_BREATH = 24;
  POOLS_IMMUNE_DISEASE = 25;
  { Met in this game, Pool of Radiance. Bits 28..31 are the four games' marks, one each in the order the games came out
    (Pool, Curse, Secret, Pools), this game's the first: in a BESTIARY.DAT several games share, an entry without this
    bit was met only in another game, and one with it and another game's bit was met in both. Curse of the Azure Bonds
    sets bit 29. A game that sets no mark of its own leaves its entries with none. }
  FIRST_GAME_MARK = 28;
  MET_HERE = 28;
  LAST_GAME_MARK = 31;
  { its attacks }
  ATK_POISON = 32;
  ATK_PARALYZE = 33;
  ATK_DRAIN = 34;
  ATK_ROT = 35;
  ATK_PETRIFY = 36;
  ATK_CHARM = 37;
  { a burning touch: Pools of Darkness's bit, which Tyranthraxus's fire touch shares, the creature being the same in
    both games (#1142) }
  ATK_FIRE = 38;
  { Pools of Darkness's own, which this game does not use: a confusing gaze }
  POOLS_ATK_CONFUSE = 39;
  { The facts #1110, #1122 and #1142 added, in the bits Pool of Radiance took for them, which every game keeps for
    them. In bit order: hurt only by a silver or a magical weapon; half damage from a silver one; blinks out of an
    attack's way; displaced, the first attack on it each combat missing; fights on below 0 hit points; escapes as gas;
    a fear aura (an attack); drains blood (an attack); acid (an attack); turns aside a missile; turns aside a thrown
    boulder; takes less harm from fire; sees the invisible; turns invisible; a breath weapon (an attack); rakes with
    its rear claws (an attack); holds its victim fast in its bite (an attack). Bits 57..63 are free. }
  SILVER_OR_MAGIC = 40;
  HALF_SILVER = 41;
  BLINKS = 42;
  DISPLACED = 43;
  FIGHTS_ON = 44;
  GAS_ESCAPE = 45;
  ATK_FEAR = 46;
  ATK_BLOOD = 47;
  ATK_ACID = 48;
  DODGES_MISSILES = 49;
  DODGES_BOULDERS = 50;
  RESISTS_FIRE = 51;
  SEES_INVISIBLE = 52;
  TURNS_INVISIBLE = 53;
  ATK_BREATH = 54;
  ATK_RAKE = 55;
  ATK_HOLD = 56;
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
  EFFECT_FACTS_COUNT = 63;
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
    (eff: C_EFFECT.NO_CHARM_POISON; fact: IMMUNE_POISON),
    { the weapons that hurt the wight and the wraith, the wraith's half from silver (#1110) }
    (eff: C_EFFECT.NEED_SILVER; fact: SILVER_OR_MAGIC),
    (eff: C_EFFECT.SILVER_MAGIC; fact: SILVER_OR_MAGIC),
    (eff: C_EFFECT.SILVER_MAGIC; fact: HALF_SILVER),
    { the phase spider's blink, the displacer beast's displacement (or a Cloak of Displacement's), the wild boar's
      fighting on and the vampire's escape (#1122) }
    (eff: C_EFFECT.BLINKING; fact: BLINKS),
    (eff: C_EFFECT.DISPLACED; fact: DISPLACED),
    (eff: C_EFFECT.CAN_FIGHT_ON; fact: FIGHTS_ON),
    (eff: C_EFFECT.FIGHT_ON; fact: FIGHTS_ON),
    (eff: C_EFFECT.GASEOUS; fact: GAS_ESCAPE),
    { the mummy's and the dragon's fear, the stirge's blood drain, the anhkheg's acid (#1122) }
    (eff: C_EFFECT.MUMMY_FEAR; fact: ATK_FEAR),
    (eff: C_EFFECT.DRAGON_FEAR; fact: ATK_FEAR),
    (eff: C_EFFECT.BLOOD_ATTACH; fact: ATK_BLOOD),
    (eff: C_EFFECT.BLOOD_DRAIN; fact: ATK_BLOOD),
    (eff: C_EFFECT.ACID_SQUIRT; fact: ATK_ACID),
    (eff: C_EFFECT.ANHKHEG_ACID; fact: ATK_ACID),
    { the rest of the game's creatures (#1142): the thri-kreen's and the giants' dodging; a Ring of Fire Resistance's
      and the efreeti's lessened fire; Tyranthraxus's sight, breath and burning touch; a Cloak of Elvenkind's hiding;
      the tiger's rake and the giant mantis's hold }
    (eff: C_EFFECT.KREEN_DODGE; fact: DODGES_MISSILES),
    (eff: C_EFFECT.BOULDER_DODGE; fact: DODGES_BOULDERS),
    (eff: C_EFFECT.RING_FIRE_RES; fact: RESISTS_FIRE),
    (eff: C_EFFECT.EFREETI_FIRE; fact: RESISTS_FIRE),
    (eff: C_EFFECT.SEE_INVISIBLE; fact: SEES_INVISIBLE),
    (eff: C_EFFECT.DRAGON_BREATH; fact: ATK_BREATH),
    (eff: C_EFFECT.FIRE_TOUCH; fact: ATK_FIRE),
    (eff: C_EFFECT.CAMOUFLAGE; fact: TURNS_INVISIBLE),
    (eff: C_EFFECT.REAR_CLAW_RAKE; fact: ATK_RAKE),
    (eff: C_EFFECT.BITE_ATTACH; fact: ATK_HOLD),
    (eff: C_EFFECT.BITE_HOLD; fact: ATK_HOLD));

implementation

end.

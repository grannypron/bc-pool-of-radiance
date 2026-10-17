{ Spell values: the pending flag and id mask of a spell slot, and named spell ids. }
unit C_Spell;

interface

const
  KNOCK = 31;
  { a spell's casting class (GDConsts.spellTable's castClass): a cleric's, a magic-user's, or one cast at a fixed
    level }
  CLASS_CLERIC = 0;
  CLASS_MAGE = 1;
  CLASS_SPECIAL = 2;
  { the caster level of a CLASS_SPECIAL spell, and of any other spell cast from an item }
  SPECIAL_CASTER_LEVEL = 12;
  ITEM_CASTER_LEVEL = 6;
  { a range of 255 marks a spell that needs an attack roll }
  ATTACK_ROLL_RANGE = 255;
  PENDING_FLAG = $80;
  ID_MASK = $7F;
  { Spell IDs: 1..56 are spells and 57..67 are item effects. GDVars.castTargetMenu is the cast-target menu. }
  { no spell selected (SpellMenu exit/cancel) }
  NONE = 0;
  { the last spell; 57..67 are item effects }
  LAST = 56;
  { the last line of a spell menu (spellIds, spellScrolls): Cast lists up to 21 memorized spells and 48 scroll spells,
    three on each of 16 items }
  LINE_LAST = 68;
  { spellFns[3] = CureLightWoundsHandler; the cure-targeting special case in the AI + manual cast paths }
  CURE_LIGHT_WOUNDS = 3;
  { spellFns[1] = BlessHandler; Bless spares a creature already in melee in combat }
  BLESS = 1;
  { spellFns[15] = MagicMissileHandler; the Magic Missile immunities test for it }
  MAGIC_MISSILE = 15;
  { spellFns[23] = HoldPersonHandler; one target saves at -2 }
  HOLD_PERSON = 23;
  { the magic-user's Charm Person, which a charming gaze applies }
  CHARM_PERSON = 10;
  { spellFns[34] = StinkingCloudHandler }
  STINKING_CLOUD = 34;
  { spellFns[37] = CureBlindnessHandler }
  CURE_BLINDNESS = 37;
  { spellFns[39] = CureDiseaseHandler }
  CURE_DISEASE = 39;
  { spellFns[43] = RemoveCurseSpell }
  REMOVE_CURSE = 43;
  { spellFns[47] and spellFns[64] (the item fireball) = FireballHandler }
  FIREBALL = 47;
  ITEM_FIREBALL = 64;
  { spellFns[51] = LightningBoltHandler }
  LIGHTNING_BOLT = 51;

implementation

end.

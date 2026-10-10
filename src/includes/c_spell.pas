{ Spell values: the pending flag and id mask of a spell slot, and named spell ids. }
unit C_Spell;

interface

const
  KNOCK = 31;
  PENDING_FLAG = $80;
  ID_MASK = $7F;
  { Spell IDs: 1..56 are spells and 57..67 are item effects. spellFps[0] holds the cast-target menu. }
  { no spell selected (SpellMenu exit/cancel) }
  NONE = 0;
  { the last spell; 57..67 are item effects }
  LAST = 56;
  { the last line of a spell menu (spellIds, spellScrolls): Cast lists up to 21 memorized spells and 48 scroll spells,
    three on each of 16 items }
  LINE_LAST = 68;
  { spellFps[3] = CureLightWoundsHandler; the cure-targeting special case in the AI + manual cast paths }
  CURE_LIGHT_WOUNDS = 3;
  { the magic-user's Charm Person, which a charming gaze applies }
  CHARM_PERSON = 10;
  { spellFps[34] = StinkingCloudHandler }
  STINKING_CLOUD = 34;
  { spellFps[37] = CureBlindnessHandler }
  CURE_BLINDNESS = 37;
  { spellFps[39] = CureDiseaseHandler }
  CURE_DISEASE = 39;
  { spellFps[43] = RemoveCurseSpell }
  REMOVE_CURSE = 43;
  { spellFps[47] and spellFps[64] (the item fireball) = FireballHandler }
  FIREBALL = 47;
  ITEM_FIREBALL = 64;
  { spellFps[51] = LightningBoltHandler }
  LIGHTNING_BOLT = 51;

implementation

end.

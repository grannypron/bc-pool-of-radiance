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
  { spellFps[3] = CureLightWoundsHandler; the cure-targeting special case in the AI + manual cast paths }
  CURE_LIGHT_WOUNDS = 3;
  { the magic-user's Charm Person, which a charming gaze applies }
  CHARM_PERSON = 10;
  { spellFps[34] = StinkingCloudHandler }
  STINKING_CLOUD = 34;
  { spellFps[47] and spellFps[64] (the item fireball) = FireballHandler }
  FIREBALL = 47;
  ITEM_FIREBALL = 64;
  { spellFps[51] = LightningBoltHandler }
  LIGHTNING_BOLT = 51;

implementation

end.

{ Spell values: the pending flag and id mask of a spell slot, and named spell ids. }
{$I COMPILER.INC}
unit C_SPELL;

interface

const
  KNOCK = 31;
  { a spell's casting class (GameDefs.spellTable's castClass): a cleric's, a magic-user's, or one cast at a fixed
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
  { Spell IDs: 1..56 are spells and 57..67 are item effects. }
  { no spell selected (SpellMenu exit/cancel) }
  NONE = 0;
  { the last spell; 57..67 are item effects }
  LAST = 56;
  { GameDefs.spellTable's last entry }
  TABLE_LAST = 67;
  { an item effect above LAST is the spell id effect - ITEM_EFFECT_SHIFT (item effects 80..90 are 57..67) }
  ITEM_EFFECT_SHIFT = 23;
  { the Javelin of Lightning's spell (item effect 83), and the cells its bolt runs past the aim cell }
  ITEM_JAVELIN_LIGHTNING = 60;
  JAVELIN_BOLT_CELLS = 3;
  { the last line of a spell menu (spellIds, spellScrolls): Cast lists up to 21 memorized spells and 48 scroll spells,
    three on each of 16 items }
  LINE_LAST = 68;
  { the spell lists' rows (#900): the list window's first row, the last row of the list above the summary line, which
    is the windows' last text row, and memorize's list window's last row, with the spell slots' window under it from
    SLOTS_TOP: its heading there and a row for each spellcasting class under it }
  LIST_TOP = 3;
  LIST_BOTTOM = 20;
  SUMMARY_ROW = 22;
  MEMORIZE_LIST_BOTTOM = 16;
  SLOTS_TOP = 18;
  { Detect Magic, the cleric's and the magic-user's: the loot menu's Detect }
  DETECT_MAGIC_CLERIC = 5;
  DETECT_MAGIC_MU = 11;
  DETECT_MAGIC = [DETECT_MAGIC_CLERIC, DETECT_MAGIC_MU];
  { spellFns[3] = SpellCureLightWounds; the cure-targeting special case in the AI + manual cast paths }
  CURE_LIGHT_WOUNDS = 3;
  { spellFns[1] = SpellBless; Bless spares a creature already in melee in combat }
  BLESS = 1;
  { spellFns[15] = SpellMagicMissile }
  MAGIC_MISSILE = 15;
  { spellFns[65] = SpellWandOfMagicMissiles, the Wand of Magic Missiles }
  WAND_MAGIC_MISSILES = 65;
  { the spells that fire magic missiles: Shield and the Magic Missile immunity stop them all (POR-0210, #890) }
  MAGIC_MISSILES = [MAGIC_MISSILE, WAND_MAGIC_MISSILES];
  { spellFns[21] = SpellSleep; its pool of hit dice is SLEEP_DICE d SLEEP_DIE, rolled at casting }
  SLEEP = 21;
  SLEEP_DICE = 4;
  SLEEP_DIE = 4;
  { spellFns[23] = SpellHold; one target saves at -2 }
  HOLD_PERSON = 23;
  { the magic-user's Charm Person, which a charming gaze applies }
  CHARM_PERSON = 10;
  { a first-level magic-user's spells besides Sleep (ClassCal.StartCasterClass), with DETECT_MAGIC_MU }
  READ_MAGIC = 18;
  SHIELD = 19;
  { the spells whose durations CharHlp.SpellDuration rolls: Cause Disease, and the item spells Potion of Speed, Giant
    Strength, Wand of Paralyzation, Dust of Disappearance and Manual of Bodily Health }
  CAUSE_DISEASE = 40;
  ITEM_SPEED = 57;
  ITEM_GIANT_STRENGTH = 59;
  ITEM_PARALYZATION = 61;
  ITEM_DISAPPEARANCE = 63;
  ITEM_BODILY_HEALTH = 67;
  { spellFns[34] = SpellStinkingCloud }
  STINKING_CLOUD = 34;
  { spellFns[37] = SpellCureBlindness }
  CURE_BLINDNESS = 37;
  { spellFns[39] = SpellCureDisease }
  CURE_DISEASE = 39;
  { spellFns[43] = SpellRemoveCurse }
  REMOVE_CURSE = 43;
  { spellFns[47] and spellFns[64] (the item fireball) = SpellFireball }
  FIREBALL = 47;
  ITEM_FIREBALL = 64;
  { the item fireball's caster level: 1d ITEM_FIREBALL_DIE * 2 + 1, so 3, 5 or 7 }
  ITEM_FIREBALL_DIE = 3;
  { spellFns[51] = SpellLightningBolt }
  LIGHTNING_BOLT = 51;
  { Lightning Bolt's length, in cells past the aim cell }
  LIGHTNING_BOLT_CELLS = 8;
  { the bronze dragon's breath bolt's length past its aim cell (Magic.DragonBreathHandler) }
  DRAGON_BOLT_CELLS = 10;
  { the shape of the cells a spell reaches, as CharHlp.SpellArea gives it from spellTable's area mode and the handlers'
    own shapes: the caster alone (area mode 0); some creatures picked one at a time (modes 1..7); one creature, or a
    bare square (mode 15); everything within a radius of the aim (modes 8..14); Stinking Cloud's 2x2 block; or
    Lightning Bolt's path }
  AREA_SELF = 0;
  AREA_TARGETS = 1;
  AREA_SPOT = 2;
  AREA_RADIUS = 3;
  AREA_CLOUD = 4;
  AREA_BOLT = 5;
  { spellTable's area modes, its low nibble: the caster, the first and last of the radius modes, and the picked spot }
  AREA_MODE_SELF = 0;
  AREA_MODE_RADIUS_FIRST = 8;
  AREA_MODE_RADIUS_LAST = 14;
  AREA_MODE_SPOT = 15;
  { what a saving throw does against a spell (spellTable's saveResult, and SpellInf's save table): nothing is rolled;
    a save negates the spell; it halves the damage; or the handler decides (Stinking Cloud's, and Silence's, which
    Magic.ResolveSpell takes for a save that negates) }
  SAVE_NONE = 0;
  SAVE_NEGATES = 1;
  SAVE_HALF = 2;
  SAVE_SPECIAL = 3;
  { SpellInf's save table only: a save lessens the spell but does not end it (Stinking Cloud's cough) }
  SAVE_PARTIAL = 4;
  { a spell list line's spell cast from an item (a scroll) rather than from memory, for SpellInf: the spell id with this
    bit set }
  FROM_ITEM = $80;

implementation

end.

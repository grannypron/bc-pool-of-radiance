{ Spell values: the pending flag and id mask of a spell slot, and named spell ids. }
{$I COMPILER.INC}
unit C_SPELL;

interface

const
  KNOCK = 31;
  { a spell's casting class (GameDefs.spellTable's castClass): a cleric's (a paladin's too), a magic-user's (a
    ranger's too), a druid's (cast here only by a ranger, #1121), or one cast at a fixed level; the first three are also
    the kinds of a character's spell slots (CharHlp.SpellSlots), CLASS_CLERIC..CLASS_DRUID }
  CLASS_CLERIC = 0;
  CLASS_MAGE = 1;
  CLASS_DRUID = 2;
  CLASS_SPECIAL = 3;
  { the last kind of spell slot }
  SLOT_KIND_LAST = CLASS_DRUID;
  { the caster level of a CLASS_SPECIAL spell, and of any other spell cast from an item }
  SPECIAL_CASTER_LEVEL = 12;
  ITEM_CASTER_LEVEL = 6;
  { a range of 255 marks a spell that needs an attack roll }
  ATTACK_ROLL_RANGE = 255;
  PENDING_FLAG = $80;
  ID_MASK = $7F;
  { Spell IDs, Curse's numbers (#1121): 1..56 are SSI's spells; 57 and 59..65 and 127..128 are item spells; 58 and
    66..94 are the cleric's spells of levels 4 and 5, the druid's first level (a ranger's) and the magic-user's of
    levels 4 and 5, and 100 the magic-user's Bestow Curse; 95..99 are Curse's monster powers, not cast here, and 91 is
    Curse's Cloudkill, which this arena has no cloud for. }
  { no spell selected (SpellMenu exit/cancel) }
  NONE = 0;
  { the last spell: GameDefs.spellNames runs 1..LAST, and the spell lists and spell books read 1..LAST through
    CharHlp.IsSpell, which passes over the item spells inside it by their class }
  LAST = 100;
  { the ids below TABLE_LAST whose spellTable rows hold no spell: no handler but Magic.UnusedSpellHandler, no name, no
    description }
  EMPTY_IDS = [91, 95..99, 101..126];
  { GameDefs.spellTable's last entry: the last item spell, past every game's spell table (Pools' runs to 126) }
  TABLE_LAST = 128;
  { an item effect 1..ITEM_EFFECT_DIRECT_LAST is that spell; one above it is the spell effect - ITEM_EFFECT_SHIFT (SSI's
    item effects 80..88 are 57..65, and 150 and 151 are 127 and 128) }
  ITEM_EFFECT_DIRECT_LAST = 56;
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
  { Detect Magic, the cleric's, the magic-user's and the druid's: the loot menu's Detect }
  DETECT_MAGIC_CLERIC = 5;
  DETECT_MAGIC_MU = 11;
  DETECT_MAGIC_DRUID = 77;
  DETECT_MAGIC = [DETECT_MAGIC_CLERIC, DETECT_MAGIC_MU, DETECT_MAGIC_DRUID];
  { spellFns[3] = SpellCureLightWounds; the cure-targeting special case in the AI + manual cast paths }
  CURE_LIGHT_WOUNDS = 3;
  { the cures of wounds, Cure Light, Serious (58) and Critical (71) Wounds: the AI casts them on a wounded ally it finds
    (CbtActs.FindCureTarget, #1121) }
  CURE_WOUNDS = [CURE_LIGHT_WOUNDS, 58, 71];
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
  { the magic-user's Hold Person, also SpellHold; one target saves at -3 }
  HOLD_PERSON_MU = 49;
  { Silence, 15' Radius: the combat AI casts it only where it has seen a creature cast (#1087) }
  SILENCE = 25;
  { the buffs the combat AI casts only against a threat it has seen this fight (#1087): Resist Cold and Resist Fire once
    an enemy has done that element's damage, Protection From Normal Missiles while an enemy has a missile weapon
    readied }
  RESIST_COLD = 8;
  RESIST_FIRE = 24;
  PROT_NORMAL_MISSILES = 54;
  { Snake Charm, and the game's one snake, the creature it affects (#802): its charType, 14, the scorpions share }
  SNAKE_CHARM = 27;
  SNAKE_NAME = 'GIANT SNAKE';
  { the magic-user's Charm Person, which a charming gaze applies }
  CHARM_PERSON = 10;
  { a first-level magic-user's spells besides Sleep (ClassCal.StartCasterClass), with DETECT_MAGIC_MU }
  READ_MAGIC = 18;
  SHIELD = 19;
  { the spells whose durations CharHlp.SpellDuration rolls: Cause Disease, and the item spells Potion of Speed, Giant
    Strength, Wand of Paralyzation, Dust of Disappearance and Manual of Bodily Health, which was spell 67 until Curse's
    Neutralize Poison took the number (#1121) }
  CAUSE_DISEASE = 40;
  ITEM_SPEED = 57;
  ITEM_GIANT_STRENGTH = 59;
  ITEM_PARALYZATION = 61;
  ITEM_DISAPPEARANCE = 63;
  ITEM_BODILY_HEALTH = 128;
  { spellFns[34] = SpellStinkingCloud }
  STINKING_CLOUD = 34;
  { spellFns[37] = SpellCureBlindness }
  CURE_BLINDNESS = 37;
  { spellFns[39] = SpellCureDisease }
  CURE_DISEASE = 39;
  { spellFns[43] = SpellRemoveCurse }
  REMOVE_CURSE = 43;
  { spellFns[56] = SpellRestoration, a level-7 cleric spell: here only from a scroll }
  RESTORATION = 56;
  { the item spells Fix may use (#1129): Keoghtom's Ointment (spellFns[127], 58 until Curse's Cure Serious Wounds took
    the number, #1121) and the Potion of Healing (spellFns[62]) }
  ITEM_OINTMENT = 127;
  { the item effects SSI's data gave the Ointment and the Manual, spell 58's and 67's: DiskRec.ItemFromDisk moves an
    item with one of them and the item's name to ITEM_OINTMENT's or ITEM_BODILY_HEALTH's }
  OLD_OINTMENT_EFFECT = 81;
  OLD_BODILY_HEALTH_EFFECT = 90;
  ITEM_HEALING = 62;
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
  { the spells of levels 4 and 5 (#1121), Curse's ids: the cleric's Cure and Cause Serious Wounds, Neutralize Poison,
    Poison, Sticks to Snakes, Cure and Cause Critical Wounds, Dispel Evil, Flame Strike, Raise Dead and Slay Living;
    the druid's Entangle, Faerie Fire and Invisibility to Animals; the magic-user's Charm Monsters, Confusion,
    Dimension Door, Fear, Fire Shield, Fumble, Ice Storm, Minor Globe of Invulnerability, Animate Dead, Cone of Cold,
    Feeblemind, Hold Monsters and Bestow Curse }
  CURE_SERIOUS_WOUNDS = 58;
  CAUSE_SERIOUS_WOUNDS = 66;
  NEUTRALIZE_POISON = 67;
  POISON = 68;
  STICKS_TO_SNAKES = 70;
  CURE_CRITICAL_WOUNDS = 71;
  CAUSE_CRITICAL_WOUNDS = 72;
  DISPEL_EVIL = 73;
  FLAME_STRIKE = 74;
  RAISE_DEAD = 75;
  SLAY_LIVING = 76;
  ENTANGLE = 78;
  FAERIE_FIRE = 79;
  INVISIBILITY_TO_ANIMALS = 80;
  CHARM_MONSTERS = 81;
  CONFUSION = 82;
  DIMENSION_DOOR = 83;
  FEAR = 84;
  FIRE_SHIELD = 85;
  FUMBLE = 86;
  ICE_STORM = 87;
  MINOR_GLOBE = 88;
  ANIMATE_DEAD_MU = 90;
  CONE_OF_COLD = 92;
  FEEBLEMIND = 93;
  HOLD_MONSTERS = 94;
  BESTOW_CURSE_MU = 100;
  { the highest spell level a Minor Globe of Invulnerability stops }
  MINOR_GLOBE_LEVEL = 3;
  { the targets Confusion may take: 2d8 }
  CONFUSION_DICE = 2;
  CONFUSION_DIE = 8;
  { Charm Monsters' pool of levels: 2d4 }
  CHARM_MONSTERS_DICE = 2;
  CHARM_MONSTERS_DIE = 4;
  { the cones' rays and reach (Magic.WalkCone, CharHlp.SpellArea): Fear's three rays 6 cells long, and Cone of Cold's
    two, which reach half its caster level, rounded up }
  FEAR_CONE_RAYS = 3;
  FEAR_CONE_CELLS = 6;
  COLD_CONE_RAYS = 2;
  { the shape of the cells a spell reaches, as CharHlp.SpellArea gives it from spellTable's area mode and the handlers'
    own shapes: the caster alone (area mode 0); some creatures picked one at a time (modes 1..4, 6, 7); creatures
    picked against a pool (mode 5: Faerie Fire's caster level by size, Charm Monsters' 2d4 by level); one creature, or
    a bare square (mode 15); everything within a radius of the aim (modes 8..14); Stinking Cloud's 2x2 block;
    Lightning Bolt's path; or a cone from the caster (Fear, Cone of Cold) }
  AREA_SELF = 0;
  AREA_TARGETS = 1;
  AREA_SPOT = 2;
  AREA_RADIUS = 3;
  AREA_CLOUD = 4;
  AREA_BOLT = 5;
  AREA_CONE = 6;
  AREA_POOL = 7;
  { spellTable's area modes, its low nibble: the caster, the pool, the first and last of the radius modes, and the
    picked spot }
  AREA_MODE_SELF = 0;
  AREA_MODE_POOL = 5;
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
  { a spell list line's spell cast from an item rather than from memory, for SpellInf: the spell id with this bit set,
    above a byte, as the item spells run past ID_MASK (#1121); LINE_ID_MASK takes the spell id back out }
  FROM_ITEM = $100;
  LINE_ID_MASK = $FF;

implementation

end.

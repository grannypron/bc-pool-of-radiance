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
  { Spell IDs: 1..56 are spells; 57..65 and 127..128 are item spells, Curse's numbers (#1121). }
  { no spell selected (SpellMenu exit/cancel) }
  NONE = 0;
  { the last spell }
  LAST = 56;
  { the ids below TABLE_LAST whose spellTable rows hold no spell: no handler but Magic.UnusedSpellHandler, no name, no
    description }
  EMPTY_IDS = [58, 66..126];
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
  { a spell list line's spell cast from an item rather than from memory, for SpellInf: the spell id with this bit set,
    above a byte, as the item spells run past ID_MASK (#1121); LINE_ID_MASK takes the spell id back out }
  FROM_ITEM = $100;
  LINE_ID_MASK = $FF;

implementation

end.

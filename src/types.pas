{$F+}
unit Types;

interface

uses C_Gender, C_Save, C_Equip, C_Level, C_Abil, C_Money, C_Gbvm;


const
  { the longest name a character or creature has }
  NAME_LEN = 15;
  { the most creatures in the party: a saved game's party names, the usual spells, the statistics, the icon slots }
  MAX_PARTY = 8;
  { the data disks the game shipped on, 1..LAST_DISK }
  LAST_DISK = 8;
  { a 3D map's last row and column: maps are 16 by 16 }
  MAP_LAST = 15;
  { the last memorized-spell slot (TSpellSlots); Turbo Pascal 6 has no High() }
  SPELL_SLOT_LAST = 20;

type

  { Shared types. }
  TStr40 = String[40];
  { A DOS path with its file name, as Dos.PathStr: DOS allows 64 characters of directory after the drive, 79 in all. }
  TPathStr = String[79];
  TBaseItemRec = record
    { equip slot }
    slot: Byte;
    { hands required }
    hands: Byte;
    { damage vs large: dice number }
    dmgLgRolls: Byte;
    { damage vs large: dice sides }
    dmgLgDice: Byte;
    { damage vs large: bonus }
    dmgLgMod: ShortInt;
    { ranged rate of fire x2 }
    rateOfFire: Byte;
    { AC adjustment descriptor }
    acDescr: Byte;
    { melee damage type; WPN_* constants }
    wpnClass: Byte;
    { reserved }
    unk8: Byte;
    { damage vs small/medium: dice number }
    dmgSmRolls: Byte;
    { damage vs small/medium: dice sides }
    dmgSmDice: Byte;
    { damage vs small/medium: bonus }
    dmgSmMod: ShortInt;
    { ranged range (exclusive) }
    range: Byte;
    { class usability bitmask }
    classMask: Byte;
    { weapon-property bitmask; see the PROP_ bits of C_Item and CharHlp }
    props: Byte;
    { reserved }
    unkF: Byte;
  end;
  PBaseItemRec = ^TBaseItemRec;
  PCharRecord = ^TCharRecord;
  PCombatRec = ^TCombatRec;
  PEffectRec = ^TEffectRec;
  PItemRec = ^TItemRec;
  TIconCols = array[1..6] of Byte;
  { A character's spell slots: spell IDs, 0 = empty, C_Spell.PENDING_FLAG set while still being memorized. }
  TSpellSlots = array[0..SPELL_SLOT_LAST] of Byte;
  TCharRecord = record
    { character name }
    name: string[NAME_LEN];
    case Integer of
      0: (
    { strength }
    strCur: Byte;
    { intelligence }
    intCur: Byte;
    { wisdom }
    wisCur: Byte;
    { dexterity }
    dexCur: Byte;
    { constitution }
    conCur: Byte;
    { charisma }
    chaCur: Byte;
    { exceptional strength (18/xx pct) }
    strExc: Byte;
    { currently memorized }
    memorizedSpells: TSpellSlots;
    { camp writes the hours code 0/4/6, rest counts it down }
    spellPrepTime: Byte;
    { base THAC0 }
    thac0Base: Byte;
    { Race. }
    race: ShortInt;
    charClass: ShortInt;
    age: Word;
    { hit points maximum }
    hpMax: Byte;
    { Known spells, indexed by spell ID. }
    spellsKnown: array[1..56] of Byte;
    attackLevel: Byte;
    iconDimensions: Byte;
    { Saving throws: paralysis, petrification, wand, breath and spell. }
    saves: array[C_Save.PARALYZE..C_Save.SPELL] of Byte;
    movementBase: Byte;
    { Highest level across the character's classes. }
    levelHighest: ShortInt;
    drainedLevels: Byte;
    drainedHps: Byte;
    { Undead level for turning. }
    levelUndead: ShortInt;
    { Thief skill values. }
    thiefSkills: array[1..8] of Byte;
    { far ptr to effects list }
    effectsAddr: PEffectRec;
    { reserved }
    unknown083: Byte;
    { packed -- see C_Npc.NPC_* }
    npc: Byte;
    { Low three bits hold the NPC's treasure-share weight. }
    npcTreasureShare: Byte;
    { reserved }
    unknown086: Byte;
    { reserved }
    unknown087: Byte;
    { Coins: copper, silver, electrum, gold, platinum, gems and jewelry. }
    coins: array[C_Money.COPPER..C_Money.JEWELRY] of Word;
    { Class levels; indexed by C_Level. }
    classLevels: array[C_Level.CLERIC..C_Level.MONK] of ShortInt;
    { Gender; see GENDER_*. }
    gender: Byte;
    charType: Byte;
    alignment: Byte;
    { attacks per round }
    attacks: Byte;
    attacks2: Byte;
    { unarmed dice rolls }
    unarmedRollsA: array[1..2] of Byte;
    { unarmed dice sides }
    unarmedDiceA: array[1..2] of Byte;
    { unarmed dmg mods }
    unarmedModA: array[1..2] of ShortInt;
    acBase: Byte;
    { strength to-hit/damage applies }
    useStrength: Byte;
    { Random duplicate-detection key assigned at creation. The roster loader rejects characters whose name and key both
      match a party member. }
    randByte: Byte;
    experience: LongInt;
    itemLimits: Byte;
    hpRolled: Byte;
    { Cleric spell slots by level, including wisdom bonuses. }
    clericSpells: array[1..3] of Byte;
    mageSpells: array[1..3] of Byte;
    xpAward: Word;
    xpBonusPerHp: Byte;
    portraitHead: Byte;
    portraitBody: Byte;
    iconHead: Byte;
    iconBody: Byte;
    orderNumber: Byte;
    iconSize: Byte;
    { Color pairs: body, arm, leg, hair, shield and weapon. }
    iconColors: array[0..5] of Byte;
    numberOfItems: Byte;
    { far ptr to item list }
    itemsAddr: PItemRec;
    { Readied items, indexed by EQUIP_*. }
    equipped: array[C_Equip.WEAPON..C_Equip.BOLT] of PItemRec;
    handsEquipped: Byte;
    { accumulated save bonus (signed) }
    saveBonus: ShortInt;
    encumbrance: Word;
    { far ptr to next character }
    nextCharAddr: PCharRecord;
    { far ptr to combatant }
    combatAddr: PCombatRec;
    status: 0..127;
    enabled: Byte;
    hostile: ShortInt;
    quickfight: Byte;
    { current THAC0 }
    thac0Cur: Byte;
    { current AC }
    acCur: Byte;
    acBehind: Byte;
    curAttacks: Byte;
    curAttacks2: Byte;
    { current dice rolls }
    curRollsA: array[1..2] of Byte;
    { current dice sides }
    curDiceA: array[1..2] of Byte;
    { current dmg mods }
    curModA: array[1..2] of ShortInt;
    { current hit points }
    hpCur: Byte;
    { current movement }
    movementCur: Byte);
      1: (
    { Current attributes as an array for character creation and display. }
    stats: array[C_Abil.STRENGTH..C_Abil.CHARISMA] of Byte);
      2: (
    { skips to gender }
    genderPad: array[0..141] of Byte;
    { Signed gender value used to index racial strength limits. }
    genderSp: ShortInt);
      3: (
    { skips to iconColors }
    iconColorsPad: array[0..176] of Byte;
    { One-based icon-color array for character customization and saving. }
    iconColors1: TIconCols);
      4: (
    { skips to clericSpells }
    slotsPad: array[0..161] of Byte;
    { Spell slots indexed by casting class and level. }
    slots: array[0..1, 1..3] of Byte);
      5: (
    { skips to gender }
    viewPad0: array[0..141] of Byte;
    { gender as a 0..127 subrange -- ViewChar indexes genderNames with it }
    genderIdx: 0..127;
    { charType }
    viewPad1: Byte;
    { alignment as a 0..127 subrange -- ViewChar indexes alignNames with it }
    alignmentIdx: 0..127);
  end;
  TCombatRec = record
    { spell being cast }
    spellCast: Byte;
    { may cast this round }
    castAllowed: Byte;
    { may use an item this round }
    itemUseAllowed: Byte;
    { signed (Combat.NextCreature and CreatureAction compare signed); cleared on death and by EndActions }
    initiative: ShortInt;
    attackPhase: Byte;
    { sweep allowance (attackLevel) }
    sweepBudget: Byte;
    { movement left this round }
    movement: Byte;
    { guarding flag }
    guarding: Byte;
    madeAttack: Byte;
    { facing 0..7 }
    direction: Byte;
    { opponent/target }
    other: PCharRecord;
    { damage past 0 hp (dying) }
    overkill: Byte;
    { attackers this round }
    flankCount: Byte;
    { undead-turned flag }
    turned: Byte;
    usedTurnUndead: Byte;
    { summed offset from facing, mod 8 }
    flankSpread: Byte;
    notPcNpc: Byte;
    fleeing: Byte;
    { AI approach-pattern index 1..6 }
    aiStance: Byte;
  end;
  TDownedRec = record
    { the downed creature }
    cr: PCharRecord;
    { Corpse cell coordinates. }
    x: ShortInt;
    y: ShortInt;
    { cell terrain saved from under it }
    terrain: Byte;
  end;
  TEffectRec = record
    { effect id }
    id: Byte;
    { minutes; 0 = permanent -- blood drain packs a damage budget in the upper bits }
    duration: Word;
    { strength; handlers pack flags in the nibbles, and the hold family stores a creature index here }
    strength: Byte;
    { removal calls the handler }
    onRemove: Boolean;
    { next effect }
    next: PEffectRec;
  end;
  { One line of a list MenuCore.MenuVertical shows. Its fields are the leading fields of TItemRec, so an item list is
    shown in place and a line that is never an item is allocated at this size. }
  TMenuNode = record
    { the line's text }
    name: string[40];
    { Nonzero marks a menu-list title. }
    inUse: Byte;
    { the next line, nil after the last }
    next: PItemRec;
  end;
  TItemRec = record
    { item name }
    name: string[40];
    { Nonzero marks a menu-list title; zero for inventory items. }
    inUse: Byte;
    { next item in inventory list }
    next: PItemRec;
    { base-item index (into baseItems) }
    itemType: Byte;
    { identified name components [1]=component 3, [2]=2, [3]=1 }
    nameIds: array[1..3] of Byte;
    { magical bonus }
    plus: ShortInt;
    { saving throw bonus }
    saveBonus: ShortInt;
    { 0 = unequipped, 1 = equipped }
    equipped: Byte;
    { Unidentified name-component mask. }
    unidMask: Byte;
    cursed: Byte;
    { weight in coins }
    weight: Word;
    { 0 = single, non-stacking }
    quantity: Byte;
    { value in gold pieces }
    value: Word;
    case Integer of
      0: (
        { properties (scroll spells / charges) }
        charges: Byte;
        { effect id }
        effect: Byte;
        { special-item id }
        special: Byte);
      1: (
        { scroll spell slots }
        spells: array[1..3] of Byte);
  end;
  PBytes = ^TBytes;
  PImgBuf = ^TImgBuf;
  TArenaLoc = record
    { Arena coordinates. }
    x: ShortInt;
    y: ShortInt;
    { Registration slot stored by CombatSt. }
    slotIndex: Byte;
    { icon footprint, zero marks out of play }
    size: Byte;
  end;
  { constant rowBand entries }
  TBandRec = record
    { valid row range }
    lo: ShortInt;
    hi: ShortInt;
  end;
  TBrkSet = set of ' '..'?';
  TBytes = array[0..65000] of Byte;
  TColorMap = array[0..7] of Byte;
  TColorTab = array[0..15] of Byte;
  TCombatTarget = record
    { arena registration index }
    idx: Byte;
    { doubled walk distance from the acting creature }
    dist: Byte;
    { best facing direction }
    dir: Byte;
  end;
  TIconCoordinateDelta = record
    { cell X offset; negative marks an absent footprint cell }
    dx: ShortInt;
    { cell Y offset }
    dy: ShortInt;
  end;
  TImgBuf = record
    { image height in pixels }
    height: Word;
    { image width in CHARS (x8 for pixels) }
    width: Word;
    { image placement X from DAX header }
    originX: Word;
    { image placement Y from DAX header }
    originY: Word;
    { images in buffer }
    count: Byte;
    { EGA->CGA colour map }
    map: TColorMap;
    { bytes in one image }
    imgSize: Word;
    { extra transparency space (default nil) }
    transp: PBytes;
    { image data (open-ended) }
    data: array[0..32000] of Byte;
  end;
  TInterruptRegisters = record
    ax: Word;
    bx: Word;
    cx: Word;
    dx: Word;
    bp: Word;
    si: Word;
    di: Word;
    ds: Word;
    es: Word;
    flags: Word;
  end;
  TKrynnClassRules = record
    { class/item-usability masks }
    createClassBits: array[0..7] of Byte;
    unidentifiedByte: Byte;
    { class selection masks }
    classBits: array[0..7] of Byte;
    unidentifiedTail: array[0..8] of Byte;
    { hit-dice cap plus one }
    maxClassLevels: array[0..7] of Byte;
  end;
  { main-menu entry }
  TMenuItem = record
    { first character is the hotkey }
    name: string[40];
    { MainMenu updates availability }
    enabled: Byte;
  end;
  TName15 = string[NAME_LEN];
  TPortraitCacheSlot = record
    { HEAD/BODY DAX entry ID; 255 invalidates }
    pictureId: Byte;
    { image buffer }
    pic: Pointer;
  end;
  TRandomItemTemplate = record
    { low bytes copied to TItemRec nameIds (components 3, 2, 1) }
    nameIds: array[1..3] of Word;
    { copied to TItemRec weight (coins) and value (gold pieces) }
    weight: Word;
    value: Word;
    { low bytes copied to TItemRec charges/effect/special }
    properties: array[1..3] of Word;
  end;
  TRuleAge = record
    { years before the dice roll }
    base: Word;
    num: Byte;
    sides: Byte;
  end;
  TRuleGold = record
    { CharGen awards ten gold per point, averaged over the classes }
    num: Byte;
    sides: Byte;
  end;
  { racial ability limits (GDConsts.dsMinimumMaximumStatistics) }
  TRuleRace = record
    { by gender }
    strMin: array[C_Gender.MALE..C_Gender.FEMALE] of Byte;
    strMax: array[C_Gender.MALE..C_Gender.FEMALE] of Byte;
    excMax: array[C_Gender.MALE..C_Gender.FEMALE] of Byte;
    intMin: Byte;
    intMax: Byte;
    wisMin: Byte;
    wisMax: Byte;
    dexMin: Byte;
    dexMax: Byte;
    conMin: Byte;
    conMax: Byte;
    chaMin: Byte;
    chaMax: Byte;
  end;
  { thief abilities (GDConsts.thiefBase and raceAdj), by skill number or by name }
  TRuleThief = packed record
    case Byte of
      0: (values: array[1..8] of ShortInt);
      1: (pickPockets: ShortInt; openLocks: ShortInt; findTraps: ShortInt; moveSilently: ShortInt;
          hideShadows: ShortInt; hearNoise: ShortInt; climbWalls: ShortInt; readLanguages: ShortInt);
  end;
  { Dexterity adjustments to the first five thief abilities (GDConsts.dexAdj), by skill number or by name }
  TRuleThiefDex = packed record
    case Byte of
      0: (values: array[1..5] of ShortInt);
      1: (pickPockets: ShortInt; openLocks: ShortInt; findTraps: ShortInt; moveSilently: ShortInt;
          hideShadows: ShortInt);
  end;
  { classes a race can take (GDConsts.classesByRace), in class-menu order }
  TRuleRaceClasses = record
    count: ShortInt;
    { class IDs; 0 fills past count }
    classes: array[1..13] of ShortInt;
  end;
  { classLevels indexes a class trains (GDConsts.classParts), by position or by name; -1 fills a shorter list }
  TRuleClassParts = packed record
    case Byte of
      0: (values: array[1..3] of ShortInt);
      1: (first: ShortInt; second: ShortInt; third: ShortInt);
  end;
  { one value per ability (GDConsts.raceAbilityAdj and classMin), by C_Abil index or by name }
  TRuleAbilities = packed record
    case Byte of
      0: (values: array[C_Abil.STRENGTH..C_Abil.CHARISMA] of ShortInt);
      1: (strength: ShortInt; intelligence: ShortInt; wisdom: ShortInt; dexterity: ShortInt; constitution: ShortInt;
          charisma: ShortInt);
  end;
  { one value per classLevels index (GDConsts.raceMaxLevel), by index or by class name }
  TRuleClassLevels = packed record
    case Byte of
      0: (values: array[C_Level.CLERIC..C_Level.MONK] of ShortInt);
      1: (cleric: ShortInt; druid: ShortInt; fighter: ShortInt; paladin: ShortInt; ranger: ShortInt; mage: ShortInt;
          thief: ShortInt; monk: ShortInt);
  end;
  { the oldest age in each age category (GDConsts.ageCat), by category number or by name }
  TRuleAgeCategories = packed record
    case Byte of
      0: (values: array[1..5] of Word);
      1: (youngAdult: Word; mature: Word; middleAged: Word; old: Word; venerable: Word);
  end;
  { alignments a class can take (GDConsts.alignByClass), in alignment-menu order }
  TRuleClassAlignments = record
    count: ShortInt;
    { alignment IDs; 0 fills past count }
    alignments: array[1..9] of ShortInt;
  end;
  { saving throws (GDConsts.saveTbl), by C_Save index or by name }
  TRuleSaves = packed record
    case Byte of
      0: (values: array[C_Save.PARALYZE..C_Save.SPELL] of Byte);
      1: (paralyze: Byte; petrify: Byte; wand: Byte; breath: Byte; spell: Byte);
  end;
  TRuleXp = record
    { XP to reach level; -1 = unavailable }
    xp: array[2..9] of LongInt;
    { class level, spell level }
    slots: array[2..9, 1..3] of Byte;
  end;
  TSpecLoc = record
    x: Word;
    y: Word;
    icon: Word;
  end;
  TTerrainRec = record
    { movement cost multiplier and passability threshold }
    cost: Byte;
    { initial line-walk clearance }
    clearance: Byte;
    { compared against line-walk clearance }
    blocking: Byte;
    { combat tile graphic index }
    tileId: Byte;
  end;
  TTurnUndeadTable = array[1..10, 1..10] of ShortInt;
  TViewSlotGeom = record
    start: array[0..9] of Byte;
    cols: array[0..9] of Byte;
    rows: array[0..9] of Byte;
    xCol: array[0..9] of Integer;
    yRow: array[0..9] of Integer;
  end;
  TWallSetCacheSlot = record
    { cached WALLDEF reload ID; -1 invalidates the slot }
    wallDefId: Integer;
    { destination 8x8 slot, also invalidated with -1 }
    symbolSlot: Integer;
  end;

  { Session types. }
  PGbvmZone0State = ^TGbvmZone0State;
  TGbvmClock = packed record
    case Byte of
      0: (values: array[0..6] of Word);
      1: (segment: Word; minute: Word; turn: Word; hour: Word; day: Word; month: Word; year: Word);
  end;
  TGbvmSavedWalls = packed record
    case Byte of
      0: (wallSetIds: array[1..3] of Word;
          symbolSlots: array[1..3] of Word);
      1: (menuPrefix: array[1..5] of Word;
          { Shares symbolSlots[3]. }
          menuAnimation: Word);
  end;
  TGbvmWord = packed record
    case Byte of
      0: (value: Word);
      1: (lo: Byte; hi: Byte);
  end;
  TGbvmZone0 = array[$4900..$4CFF] of Word;
  TGbvmZone0State = packed record
    case Byte of
      0: (words: TGbvmZone0);
      1: (bytes: array[0..2047] of Byte);
      2: (
        scriptWords4900: array[$4900..$49C2] of Word;
        partyX: TGbvmWord;
        partyY: TGbvmWord;
        mapId: TGbvmWord;
        clock: TGbvmClock;
        scriptWords49CD: array[$49CD..$49E4] of Word;
        antimagic: Word;
        view3dFlag: Word;
        mapGraphics1: Word;
        mapGraphics2: Word;
        scriptWords49E9: array[$49E9..$49EF] of Word;
        previousX: Word;
        previousY: Word;
        previousScriptId: Word;
        scriptWords49F3: array[$49F3..$49FA] of Word;
        noAutomap: Word;
        gameSpeed: TGbvmWord;
        skyCeilingColor: Word;
        alternateSkyColor: Word;
        { Bit 0 the portrait flag, bit 1 the monster-picture flag, bit 2 set for music off (clear in older saves). }
        settings: Word;
        { Cleared on a fresh script entry. }
        entryWords: array[$4A00..$4A1F] of Word;
        scriptWords4A20: array[$4A20..$4A7B] of Word;
        { Bit 3 enables the camp icon. }
        nomadCampFlags: Word;
        scriptWords4A7D: array[$4A7D..$4A8B] of Word;
        buccaneersBaseGate: Word;
        scriptWords4A8D: array[$4A8D..$4A9E] of Word;
        { Zero enables the camp icon. }
        nomadCampGate: Word;
        { Bits 0 and 1 hide the keep and caves. }
        easternSitesGate: Word;
        scriptWord4AA1: Word;
        yarashPyramidLeft: Word;
        scriptWords4AA3: array[$4AA3..$4AB2] of Word;
        yarashMissionDone: Word;
        scriptWords4AB4: array[$4AB4..$4AD1] of Word;
        { Nonzero enables the camp icon. }
        nomadCampPresent: Word;
        scriptWords4AD3: array[$4AD3..$4AF9] of Word;
        savedWalls: TGbvmSavedWalls;
        scriptWords4B00: array[$4B00..$4CFF] of Word);
  end;
  TGbvmZone1 = array[$6B00..$6EFF] of Word;

  { Blit types. }
  TVideoMode = (vmCGA, vmEGA, vmTandy);

  { A routine MenuCore.MenuHorizontal calls on every pass of its key wait. }
  TIdleProc = procedure;
  { The cells a spell reaches, for the spell-aim preview: a blast around the aim cell, Lightning Bolt's path from it, or
    Stinking Cloud's 2x2 block with the aim cell at its upper left. }
  TAimShape = (AimBlast, AimBolt, AimCloud);

  { Border types. }
  TCgaBank = array[0..99] of array[0..79] of Byte;
  TTandyBank = array[0..49] of array[0..159] of Byte;

  { Camp types. }
  PZone0State = ^TGbvmZone0State;
  TClock = array[0..6] of Word;

  { CbtActs types. }
  PAttackPhaseView = ^TAttackPhaseView;
  PCbtactsZoneWords = ^TGbvmZone1;
  { Target-selection result. }
  TAimTarget = record
    { the creature (nil = bare cell) }
    cr: Pointer;
    { Arena cell. }
    x: ShortInt;
    y: ShortInt;
    { reserved }
    pad: Byte;
  end;
  { Arena cells in the order something visits them, such as the cells a lightning bolt crosses. }
  TCellList = record
    count: Byte;
    x: array[1..64] of ShortInt;
    y: array[1..64] of ShortInt;
  end;
  { TCharRecord view: armor class and attacks as arrays }
  TAttackPhaseView = record
    { skips to acCur }
    fill: array[0..272] of Byte;
    { Current and rear armor class. }
    acCurArr: array[0..1] of Byte;
    curAtt: array[1..2] of Byte;
  end;

  { CbtMap types. }
  PArena = ^TArena;
  TArena = record
    { reserved }
    pad0: Byte;
    pad1: Byte;
    { Upper-left cell of the view. }
    ox: ShortInt;
    oy: ShortInt;
    { draw the cursor sprite }
    cursorOn: Boolean;
    { cursor icon size }
    cursorSize: Byte;
    { line-walk distance mode (Pathing.WalkLine) }
    distMode: Byte;
    { terrain-info indices }
    cells: array[0..24, 0..49] of Byte;
  end;

  { CharGen types. }
  { dsStartingAge entries }
  TAgeRec = record
    base: Word;
    { dice count }
    num: Byte;
    { dice sides }
    sides: Byte;
  end;
  { dsStartingGoldClass }
  TGoldDice = record
    num: Byte;
    sides: Byte;
  end;
  { dsMinimumMaximumStatistics entry }
  TRaceLim = record
    { by gender }
    strMin: array[C_Gender.MALE..C_Gender.FEMALE] of Byte;
    strMax: array[C_Gender.MALE..C_Gender.FEMALE] of Byte;
    { exceptional-Str cap }
    excMax: array[C_Gender.MALE..C_Gender.FEMALE] of Byte;
    intMin: Byte;
    intMax: Byte;
    wisMin: Byte;
    wisMax: Byte;
    dexMin: Byte;
    dexMax: Byte;
    conMin: Byte;
    conMax: Byte;
    chaMin: Byte;
    chaMax: Byte;
  end;

  { CharHlp types. }
  PAcAdjust = ^TAcAdjust;
  PBoolean = ^Boolean;
  TAcAdjust = array[0..4] of ShortInt;
  TZone1 = record
    { skips to searchFlags }
    pad0: array[0..1427] of Byte;
    { C_Gbvm.SEARCH_FLAGS, bit 0 }
    searchFlags: Word;
  end;

  { Spell and downed-record types. }
  PDownedRec = ^TDownedRec;
  TSpellRec = record
    case Integer of
      0: (
        { 0 cleric / 1 mage / 2 item/special }
        castClass: Byte;
        { spell level }
        level: Byte;
        { base range, 255 = attack roll }
        rangeFixed: Byte;
        { range per caster level }
        rangeVar: Byte;
        { base duration }
        durFixed: Byte;
        { duration per caster level }
        durVar: Byte;
        { PACKED: lo nibble area mode, hi nibble radius }
        area: Byte;
        { targeting mode }
        target: Byte;
        { saving-throw result; Magic reads it as Boolean saveEffect }
        saveResult: Byte;
        { saving-throw column 0..4 }
        saveType: Byte;
        { effect id added on a hit }
        effect: Byte;
        { 0 noncombat / 1 combat / 2 either }
        whenCast: Byte;
        { casting time }
        castTime: Byte;
        { 0..7, 0 = AI never casts }
        aiPriority: Byte;
        { 1 = offensive }
        offensive: Byte;
        { friendly-fire scan radius }
        aiRadius: Byte);
      1: (
        { Signed class and level view. }
        castClassSp: ShortInt;
        levelSp: ShortInt);
      2: (
        { castClass..target }
        savePrefix: array[0..7] of Byte;
        { Boolean view of saveResult }
        saveEffect: Boolean);
  end;

  { Combat types. }
  PZone1 = ^TGbvmZone1;

  { CombatSt types. }
  TPortSlot = record
    pictureId: Byte;
    pic: PImgBuf;
    { virtual disk pictureId was loaded from }
    disk: Byte;
  end;

  { DaxIo types. }
  PByteArr = ^TByteArr;
  TStr20 = string[20];
  TByteArr = array[0..65534] of ShortInt;

  { EclMenu types. }
  PEclRet = ^TEclRet;
  PZone2 = ^TZone2;
  PZone3 = ^TZone3;
  TEclRet = record
    { return GBVM address }
    addr: Word;
    { node below }
    next: PEclRet;
  end;
  TMonFlags = array[0..1] of Boolean;
  TZone2 = array[$9700..$98FF] of Word;
  { the script buffer (C_Gbvm.SCRIPT_FIRST..SCRIPT_LAST) }
  TZone3 = array[C_Gbvm.SCRIPT_FIRST..C_Gbvm.SCRIPT_LAST] of Byte;

  { EclVm types. }
  TEclvmWallDef = record
    wallDefId: Word;
    symbolSlot: Word;
  end;

  { EffHndlr types. }
  TEffectHandler = procedure(creature: PCharRecord; effectData: Pointer;
                             removed: Boolean);

  { FxEngine types. }
  PFxengineZoneBytes = ^TFxengineZoneBytes;
  TFxengineZoneBytes = array[0..2047] of Byte;

  { GameBoot types. }
  THeapEndW = record
    o: Word;
    s: Word;
  end;

  { GameInit types. }
  PGameini2ZoneWords = ^TZoneWords;
  { one loaded-wallset cache slot (dsWallSetCache) }
  TWallSlot = record
    { wallDefId = -1 marks an empty slot }
    wallDefId: Integer;
    symbolSlot: Integer;
  end;
  TZoneWords = array[0..1023] of Word;

  { MenuCore types. }
  TMFrame = record
    { frame delay, 1/10 s }
    time: LongInt;
    { frame image }
    pic: PImgBuf;
  end;
  TMenuAnim = record
    { frames loaded }
    count: Byte;
    { current frame, 1-based }
    current: Byte;
    frames: array[1..8] of TMFrame;
  end;
  TMenuAuto = record
    { centiseconds before auto-answer, 0=off }
    timeout: LongInt;
    { the auto-answer key }
    key: Char;
  end;
  TOptRange = record
    first: Byte;
    last: Byte;
  end;

  { Money types. }
  TLoW = record
    lo: Word;
    hi: Word;
  end;
  TMoney = array[C_Money.COPPER..C_Money.JEWELRY] of LongInt;
  TWB = record
    lo: Byte;
    hi: Byte;
  end;

  { Pathing types. }
  TPathReq = record
    { start / end points }
    sx: Integer;
    sy: Integer;
    ex: Integer;
    ey: Integer;
    { Bresenham error term }
    err: Integer;
    { Abs(ex - sx) }
    adx: Integer;
    { Abs(ey - sy) }
    ady: Integer;
    { error bump on a diagonal step }
    incD: Integer;
    { error bump on a straight step }
    incS: Integer;
    { x step sign (-1/0/1) }
    stepX: ShortInt;
    { y step sign (-1/0/1) }
    stepY: ShortInt;
    { Current line position. }
    cx: Integer;
    cy: Integer;
    { doubled distance walked }
    dist: Byte;
    { direction of last step (0..8) }
    step: Byte;
  end;

  { Portrait types. }
  TAnimFrame = record
    { copied verbatim from the file }
    hdr: array[0..3] of Byte;
    pic: PImgBuf;
  end;
  TAnimRec = record
    { frames actually loaded }
    count: Byte;
    { always set to 1 }
    flag: Byte;
    frames: array[1..8] of TAnimFrame;
  end;
  TStr8 = String[8];

  { SaveLoad types. }
  PZone1Words = ^TGbvmZone1;
  PSaveloadZoneBytes = ^TSaveloadZoneBytes;
  TSaveloadZoneBytes = array[0..SizeOf(TGbvmZone0State) - 1] of Byte;

  { Magic types. }
  PStinkRec = ^TStinkRec;
  TCastUI = procedure(spell: Byte; b: Boolean; var sel: Boolean);
  TSpellProc = procedure;
  TStinkRec = record
    caster: PCharRecord;
    next: PStinkRec;
    under: array[1..4] of Byte;
    exists: array[1..4] of Byte;
    { target X }
    ulX: ShortInt;
    { target Y }
    ulY: ShortInt;
    { caster cloud # }
    idx: Byte;
  end;

  { TextRend types. }
  PFontArr = ^TFontArr;
  TCgaRow = array[0..39] of Word;
  TFontArr = array[0..176] of array[0..7] of Byte;
  TTdyRow = array[0..159] of Byte;

  { View3D types. }
  PGeoMap = ^TGeoMap;
  PWallDefs = ^TWallDefs;
  PWallSlices = ^TWallSlices;
  TGeoPlane = array[0..15, 0..15] of Byte;
  TGeoMap = record
    { N = high nibble, E = low }
    wallsNE: TGeoPlane;
    { S = high nibble, W = low }
    wallsSW: TGeoPlane;
    events: TGeoPlane;
    { 2 bits per facing }
    barriers: TGeoPlane;
  end;
  TView3dWallDef = array[1..5, 0..155] of Byte;
  TWallDefs = array[1..3] of TView3dWallDef;
  TWallSetCache = record
    { Cached WALLDEF reload ID }
    wallDefId: Integer;
    { Destination slot passed to Load8x8Set }
    symbolSlot: Integer;
  end;
  TWallSlices = array[1..15, 0..155] of Byte;

  { ViewChar types. }
  TStr10 = String[10];
  TStr12 = String[12];
  TStr16 = String[16];
  TStr26 = String[26];
  TStr6 = String[6];
  TStr9 = String[9];

  { Pointers for character helpers. }
  PZone1Rec = ^TZone1;

implementation

end.

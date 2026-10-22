{ Shared creature operations: statistics, equipment, inventory, damage, targeting and party display. }
{$O+,F+}
{$I COMPILER.INC}
unit CharHlp;

interface

uses Types;

procedure WeaponAdjust(creature: Types.PCharRecord);

procedure ArmorMoveAdjust(creature: Types.PCharRecord; item: Types.PItemRec);

procedure ArmorAdjustHelper(creature: Types.PCharRecord; item: Types.PItemRec; adj: Types.PAcAdjust;
                            isMagicBody: Types.PBoolean; var ringSave: ShortInt);

procedure EncumbranceAdjust(creature: Types.PCharRecord);

procedure ItemLabel(item: Types.PItemRec; isInv: Boolean);

function IsHelpless(creature: Types.PCharRecord): Boolean;

{ Point creature's equipment slots at its readied items (RecalcStats does this first; a character just loaded needs it
  alone). }
procedure LinkEquipped(creature: Types.PCharRecord);

procedure RecalcStats(creature: Types.PCharRecord);

procedure RemoveSpell(creature: Types.PCharRecord; spell: Byte);

procedure RemoveItem(creature: Types.PCharRecord; item: Types.PItemRec);

{ Free every item in list and leave it nil. }
procedure FreeItemList(var list: Types.PItemRec);

{ Put a heap copy of item at the front of list: list then points at the copy, which links to the old front. Copying a
  list item by item this way reverses its order, as SSI's copies did. }
procedure PrependItemCopy(var list: Types.PItemRec; item: Types.PItemRec);

{ The same for an effect. }
procedure PrependEffectCopy(var list: Types.PEffectRec; effect: Types.PEffectRec);

{ Empty the treasure on the table: free its items and zero its money. }
procedure ClearTreasure;

{ Put a heap copy of item at the end of list. The caller checks there is room (a creature's 16 items). }
procedure AppendItemCopy(var list: Types.PItemRec; item: Types.PItemRec);

function HasEffect(creature: Types.PCharRecord; id: Byte; var effect: Types.PEffectRec): Boolean;

{ A movement or attack rate n as Haste and Slow make it: doubled (at most 255) while the creature is Hasted (eff 39),
  halved while it is Slowed (eff 42), and unchanged with both, which cancel, as in the 1st edition (#778). Combat (the
  two effects' handlers), the encounter menu's flee test (EclMenu.MoveExtremes) and the View screen all use it. }
function HasteSlowRate(creature: Types.PCharRecord; n: Byte): Byte;

procedure InflictDamage(creature: Types.PCharRecord; dmg: Byte);

function EnemyTeam(creature: Types.PCharRecord): ShortInt;

{ The creature's team, 0 or 1: hostile and 1, as CombatSt places it. teamCount has only those entries, and an effect
  that stores a side keeps one bit for it, while a damaged save can hold a larger hostile byte (#710, #827). }
function Team(creature: Types.PCharRecord): Byte;

procedure CountTeams;

function EndActions(creature: Types.PCharRecord): Boolean;

function CanUseItems(creature: Types.PCharRecord): Boolean;

function Guard(creature: Types.PCharRecord): Boolean;

function GetCasterLevel(spell: Byte): Byte;

function HasRangedWeapon(creature: Types.PCharRecord): Boolean;

function HasThrowableWeapon(creature: Types.PCharRecord): Boolean;

{ FindAmmo for the readied weapon (equipped[C_EQUIP.WEAPON]). }
function FindDamagingRangedWeapon(creature: Types.PCharRecord; var sel: Types.PItemRec): Boolean;

{ Find the item that does the damage when the creature shoots or throws weapon w: w itself if C_ITEM.PROP_THROWN, else
  the arrows (equipped[C_EQUIP.ARROW]) with a bow (C_ITEM.PROP_ARROWS) or the quarrels (equipped[C_EQUIP.BOLT]) with a
  crossbow (C_ITEM.PROP_QUARRELS). A launcher with neither ammunition bit (props exactly C_ITEM.PROP_DEX_MISSILE +
  C_ITEM.PROP_FIRES_AMMO) returns True with sel nil; no weapon (nil), a pure melee weapon or a launcher with no
  ammunition readied returns False. }
function FindAmmo(creature: Types.PCharRecord; w: Types.PItemRec; var sel: Types.PItemRec): Boolean;

{ Check the racial level limit for a class: a fighter's, and a half-elf ranger's, from FIGHTER_CAP by the character's
  PermanentStrength, and a half-elf cleric's (HALFELF_CLERIC_CAP); a level at or past the cap counts. }
function AtLevelCap(creature: Types.PCharRecord; cls: ShortInt): Boolean;

{ The Strength points the creature's disease (eff 43) has taken so far, which a cure gives back: the upper nibble of the
  effect's strength byte, the lower holding the caster level (at most 15) as Dispel Magic reads it. 0 when it has no
  disease. The Strength the Enlarge and Strength effects (eff 12, 38) store and set is the creature's own, without this
  loss: they take it off when they set the creature's Strength, and give it back when they store it (#705). }
function DiseaseStrLoss(creature: Types.PCharRecord): Byte;

{ The character's own Strength score, without Enlarge, Strength or Gauntlets of Ogre Power but with what a disease has
  taken: the Strength to restore held by the one Enlarge or Strength effect not superseded (strength < $80;
  FxEngine.AdjustForNewStrength) less DiseaseStrLoss, not below 3, else strCur. }
function PermanentStrength(creature: Types.PCharRecord): Byte;

{ True when the creature has enough experience to train a level in some class: the training hall's own test (not at the
  racial cap, a next level in the experience table, and the experience for it), ignoring the fee and the hall. }
function CanTrain(creature: Types.PCharRecord): Boolean;

function HasBagOfHolding(creature: Types.PCharRecord): Boolean;

function RawWeight(creature: Types.PCharRecord): LongInt;

{ The weight of an item in coins: its weight is per piece, so a stack weighs weight * quantity (quantity 0 is a single
  unstacked item). }
function ItemWeight(item: Types.PItemRec): LongInt;

{ The highest of the creature's fighter, paladin and ranger levels, or 0 when it has none: the level at which it fights
  as a warrior. }
function WarriorLevel(creature: Types.PCharRecord): ShortInt;

{ The base item record for an item type: its baseItems entry, or the zeroed overflow entry for a type past the
  table, which only damaged save or monster data can carry.
  @param(itemType TItemRec.itemType.)
  @returns(A pointer to the record; the caller does not change it.) }
function BaseItem(itemType: Byte): Types.PBaseItemRec;

{ Correct the damage types (wpnClass) the shipped ITEMS file gets wrong, by the 1st edition weapons (#746): the battle
  axe cuts (slash, not pierce), and the bec de corbin, military fork, partisan, ranseur, spetum, short sword, trident
  and arrow pierce (not slash). }
procedure FixWeaponClasses(items: Types.PBaseItems);

{ Clear the ammunition bits (C_ITEM.PROP_ARROWS, PROP_QUARRELS) of a weapon that is not a launcher (no
  C_ITEM.PROP_FIRES_AMMO): the shipped ITEMS file gives the bill-guisarme and the unused item type 0 the arrows bit
  (#793). The quarrel's own row keeps its bits; it is ammunition, never readied as a weapon. The javelin, shipped as a
  launcher without the Strength bonus, becomes a throwable weapon (C_ITEM.PROPS_THROWABLE) like the spear, so it can
  be thrown or used in melee (#798); holy water, oil and boulders stay thrown only. }
procedure FixAmmoBits(items: Types.PBaseItems);

{ True for an NPC or a monster: a creature whose npc has bit 7 (C_NPC.FLAG) set, not one of the player's own
  characters. }
function IsNpc(creature: Types.PCharRecord): Boolean;

{ True when creature may trade and sell: one of the player's own characters, or an NPC that is disabled or animated. }
function MayTrade(creature: Types.PCharRecord): Boolean;

{ True for a person, whom Charm Person and Hold Person affect (#792): not undead (charType 4), and either a monster the
  1st-edition list names (GameDefs.rangerFoes' first RANGER_PERSONS, personFoes), or a creature of one tile, not Large,
  of a player race or charType 0 (the humans, some with race byte 0). SSI tested charType 0..1 and a one-tile icon,
  which kept the gnoll out and let the ogre leader in. }
function IsPerson(creature: Types.PCharRecord): Boolean;

{ True for one of the player's own characters that is not animated: the creatures Space in combat, and Quick Ends With
  Fight after it, return to the player's control. }
function ComesUnderPlayer(creature: Types.PCharRecord): Boolean;

{ True when it is non-nil and its base item's slot is a scroll's, C_ITEM.SLOT_MAGE_SCROLL..SLOT_LAST_READABLE. }
function ItemReadable(it: Pointer): Boolean;

{ True when creature can read item's spells, that is when the scroll is identified. Read Magic (effect 16), or any
  cleric level with a cleric's scroll (base slot C_ITEM.SLOT_CLERIC_SCROLL), identifies it first. }
function ScrollLegible(creature: Types.PCharRecord; item: Types.PItemRec): Boolean;

function ScrollSpellAt(item: Types.PItemRec; slot: Byte): Byte;

{ True when item is a scroll creature can read (ScrollLegible) and could use: readied, or of a class Ready accepts. The
  two hands a readied scroll takes are not asked for. The Cast list offers these scrolls' spells, and Items > Use takes
  them unreadied. }
function CastableScroll(creature: Types.PCharRecord; item: Types.PItemRec): Boolean;

{ True when the creature may use items now (CharHlp.CanUseItems) and holds a scroll it can read and use with a spell on
  it: the scroll spells the Cast list offers. }
function HasScrollSpells(creature: Types.PCharRecord): Boolean;

{ Spell range: rangeFixed + rangeVar * caster level, using C_SPELL.ITEM_CASTER_LEVEL when GameVars.usingItem. A zero
  range with a nonzero area (touch) and the attack-roll encoding (C_SPELL.ATTACK_ROLL_RANGE) both become 1. }
function CalcSpellRange(spell: Byte): Byte;

type
  { a message for a fault that should not happen }
  TFaultHook = procedure(msg: Types.TStr40);

var
  { RemoveItem's messages for a nil item or one not in the list; GameInit sets it to CharDisp.ShowFault (nil in a test
    program, which shows nothing) }
  faultHook: TFaultHook;
  { Base item types, indexed by TItemRec.itemType, on the heap; GameInit2 allocates and clears them before reading
    ITEMS. The last entry, Types.BASE_ITEM_OVERFLOW, stays zero: it keeps the ITEMS read's request for 129 records in
    bounds (the shipped ITEMS holds 128), and CharHlp.BaseItem gives it for an item type past the table. }
  baseItems: Types.PBaseItems;

{ The chance (in 100) a robbery of chance takes an item of weight coins: 90 less for over 255 coins, 50 less for over
  24, never below 0 (EclMenu.RobItems). }
function TheftChance(chance: Byte; weight: Word): Byte;

implementation

uses C_ITEM, GameDefs, GameVars, C_EFFECT, C_EQUIP, C_RACE, C_LEVEL, C_STATUS, C_IFC,
  C_MONEY, Stats, C_NPC, StrUtil, AbilAdj, C_SPELL, ClassCal;

const
  { movement in body armour, by its weight in coins: up to LIGHT_ARMOR the creature's own, up to MEDIUM_ARMOR
    MOVE_LOADED, heavier MOVE_HEAVY; magical armour gives MAGIC_ARMOR_MOVE back }
  LIGHT_ARMOR = 150;
  MEDIUM_ARMOR = 399;
  MAGIC_ARMOR_MOVE = 3;
  { the movement rates armour and loads slow a creature to }
  MOVE_LOADED = 9;
  MOVE_HEAVY = 6;
  MOVE_OVERLOADED = 3;
  { TCharRecord.charType of the undead }
  UNDEAD_TYPE = 4;
  { coins carried over the weight allowance: up to OVER_LIGHT, no change; up to OVER_LOADED, MOVE_LOADED; up to
    OVER_HEAVY, MOVE_HEAVY; more, MOVE_OVERLOADED }
  OVER_LIGHT = 512;
  OVER_LOADED = 768;
  OVER_HEAVY = 1024;
  { the coins' weight a readied Bag of Holding carries }
  BAG_OF_HOLDING_COINS = 5000;
  { the most encumbrance a creature records }
  MAX_ENCUMBRANCE = 65535;
  { a robbery's chance of taking an item over HEAVY_LOOT coins falls by HEAVY_LOOT_PENALTY, over MEDIUM_LOOT by
    MEDIUM_LOOT_PENALTY }
  HEAVY_LOOT = 255;
  HEAVY_LOOT_PENALTY = 90;
  MEDIUM_LOOT = 24;
  MEDIUM_LOOT_PENALTY = 50;
  { a fighter's (and a half-elf ranger's) racial level cap by Strength: below 17, 17, and 18 or more; 0 for none. Humans
    and half-orcs have none. }
  STR_BAND_LOW = 0;
  STR_BAND_17 = 1;
  STR_BAND_18 = 2;
  FIGHTER_CAP: array[C_RACE.DWARF..C_RACE.HALFLING, STR_BAND_LOW..STR_BAND_18] of ShortInt = (
    (7, 8, 0),
    (5, 6, 7),
    (5, 5, 6),
    (6, 7, 8),
    (4, 5, 6));
  { a half-elf cleric's cap }
  HALFELF_CLERIC_CAP = 5;

var
  { equipped-items weight }
  gEquipWeight: Word;

{ With a readied weapon, recompute to-hit and the primary attack's damage. thac0Cur restarts from thac0Base plus the
  Dexterity missile adjustment (C_ITEM.PROP_DEX_MISSILE) and Strength to-hit (C_ITEM.PROP_STR_BONUS); the damage dice
  and modifier come from the base item's small/medium entry plus Strength damage (C_ITEM.PROP_STR_BONUS). The weapon's
  plus is added to both, except that a launcher's (CharHlp.FindDamagingRangedWeapon: a bow or crossbow) is to-hit only,
  and the plus of the arrows or quarrels it fires is added to both. An elf gets a further +1 to-hit with a bow, a long
  sword or a short sword. The Fine Composite Long Bow is built on the Heavy Crossbow's row; it counts as a bow when its
  second name component is a bow's name, which a Heavy Crossbow never carries. }
procedure WeaponAdjust(creature: Types.PCharRecord);
var
  w: Types.PItemRec;
  ammo: Types.PItemRec;
  wtype: Byte;
  plus: ShortInt;
begin
  w := creature^.equipped[C_EQUIP.WEAPON];
  if w = nil then Exit;
  wtype := w^.itemType;
  creature^.thac0Cur := creature^.thac0Base;
  if (CharHlp.BaseItem(wtype)^.props and C_ITEM.PROP_DEX_MISSILE) <> 0 then
    creature^.thac0Cur := AbilAdj.DexMissileAdjust(creature) + creature^.thac0Cur;
  creature^.curModA[1] := CharHlp.BaseItem(wtype)^.dmgSmMod;
  if (CharHlp.BaseItem(wtype)^.props and C_ITEM.PROP_STR_BONUS) <> 0 then begin
    creature^.thac0Cur := AbilAdj.StrToHitAdjust(creature) + creature^.thac0Cur;
    creature^.curModA[1] := AbilAdj.StrDamageAdjust(creature) + creature^.curModA[1];
  end;
  plus := w^.plus;
  { a bow or crossbow's own plus is to hit only, its arrows' or quarrels' to hit and damage (#744) }
  if CharHlp.FindDamagingRangedWeapon(creature, ammo) and (ammo <> nil) and (ammo <> w) then begin
    plus := plus + ammo^.plus;
    creature^.curModA[1] := creature^.curModA[1] + ammo^.plus;
  end else
    creature^.curModA[1] := creature^.curModA[1] + plus;
  if (creature^.race = C_RACE.ELF) and
      ((w^.itemType in [C_ITEM.COMPOSITE_LONG_BOW..C_ITEM.SHORT_BOW, C_ITEM.LONG_SWORD, C_ITEM.SHORT_SWORD]) or
       ((w^.itemType = C_ITEM.HEAVY_CROSSBOW) and
        (w^.nameIds[2] in [C_ITEM.NAME_COMPOSITE_LONG_BOW..C_ITEM.NAME_SHORT_BOW]))) then
    Inc(plus);
  creature^.thac0Cur := creature^.thac0Cur + plus;
  creature^.curRollsA[1] := CharHlp.BaseItem(wtype)^.dmgSmRolls;
  creature^.curDiceA[1] := CharHlp.BaseItem(wtype)^.dmgSmDice;
end;

{ Body armor only (base slot C_EQUIP.ARMOR): set current movement from the armor's weight (up to LIGHT_ARMOR, the base
  movement; up to MEDIUM_ARMOR, MOVE_LOADED; heavier, MOVE_HEAVY), then MAGIC_ARMOR_MOVE more if the armor has a nonzero
  plus and the movement is still at most MOVE_LOADED. }
procedure ArmorMoveAdjust(creature: Types.PCharRecord; item: Types.PItemRec);
begin
  if CharHlp.BaseItem(item^.itemType)^.slot = C_EQUIP.ARMOR then begin
    case item^.weight of
      0..LIGHT_ARMOR: creature^.movementCur := creature^.movementBase;
      LIGHT_ARMOR + 1..MEDIUM_ARMOR: creature^.movementCur := MOVE_LOADED;
    else
      creature^.movementCur := MOVE_HEAVY;
    end;
    if (item^.plus <> 0) and (creature^.movementCur <= MOVE_LOADED) then
      creature^.movementCur := creature^.movementCur + MAGIC_ARMOR_MOVE;
  end;
end;

{ Fold one equipped item into the AC adjustment slots. Only items whose base acDescr >= 128 participate; descr's low 7
  bits are the item's own AC value. A shield sets adj[AC_SHIELD] to AC + plus. An item with AC 0 adds its saveBonus to
  the creature's and its plus to adj[AC_PLUSES], except a ring, whose plus instead raises adj[AC_RING] to the best ring
  plus, and whose plus or saveBonus, whichever is larger, raises ringSave to the best ring's save bonus (RecalcStats
  adds it once). Any other item keeps the best AC + plus in adj[AC_ARMOR], setting isMagicBody when that new best is
  body armor with a positive plus. (The AC_ indexes are Types'.) }
procedure ArmorAdjustHelper(creature: Types.PCharRecord; item: Types.PItemRec; adj: Types.PAcAdjust;
                            isMagicBody: Types.PBoolean; var ringSave: ShortInt);
var
  descr: Byte;
  slot: Byte;
begin
  descr := CharHlp.BaseItem(item^.itemType)^.acDescr;
  if descr > $7F then begin
    descr := descr and $7F;
    slot := CharHlp.BaseItem(item^.itemType)^.slot;
    if slot = C_EQUIP.SHIELD then
      adj^[Types.AC_SHIELD] := descr + item^.plus
    else if descr = 0 then begin
      if slot = C_EQUIP.RING1 then begin
        if item^.plus > adj^[Types.AC_RING] then
          adj^[Types.AC_RING] := item^.plus;
        if item^.plus > ringSave then
          ringSave := item^.plus;
        if item^.saveBonus > ringSave then
          ringSave := item^.saveBonus;
      end else begin
        adj^[Types.AC_PLUSES] := adj^[Types.AC_PLUSES] + item^.plus;
        creature^.saveBonus := creature^.saveBonus + item^.saveBonus;
      end;
    end else begin
      if descr + item^.plus > adj^[Types.AC_ARMOR] then begin
        adj^[Types.AC_ARMOR] := descr + item^.plus;
        if item^.plus > 0 then
          if slot = C_EQUIP.ARMOR then
            isMagicBody^ := True;
      end;
    end;
  end;
end;

{ Clamp movement by how many coins the creature carries over its weight allowance: within OVER_LIGHT keeps the current
  movement, then each band (OVER_LOADED, OVER_HEAVY, more) steps down (MOVE_LOADED, MOVE_HEAVY, MOVE_OVERLOADED), and
  the result only ever lowers movementCur. }
procedure EncumbranceAdjust(creature: Types.PCharRecord);
var
  over: LongInt;
  movement: Byte;
begin
  over := LongInt(creature^.encumbrance) - AbilAdj.WeightAllowance(creature);
  if over < 0 then
    over := 0;
  case over of
    0..OVER_LIGHT: movement := creature^.movementCur;
    OVER_LIGHT + 1..OVER_LOADED: movement := MOVE_LOADED;
    OVER_LOADED + 1..OVER_HEAVY: movement := MOVE_HEAVY;
  else
    movement := MOVE_OVERLOADED;
  end;
  if movement < creature^.movementCur then
    creature^.movementCur := movement;
end;

{ Build the item label in item^.name: the ' Yes  '/' No   ' equipped marker (inventory listings only), a '*' when
  any creature in the list has Detect Magic and the item has a plus, a save bonus or a curse, the quantity when nonzero,
  then the identified name components from 3 down to 1, one of them pluralized with 's' when the quantity is 2 or more.
  CharDisp.PrintItemLabel also prints it. }
procedure ItemLabel(item: Types.PItemRec; isInv: Boolean);
const
  { Item name components, indexed 1..255 by TItemRec.nameIds; a zero name ID adds no component. }
  nameParts: array[1..255] of string[20] = (
    'Battle Axe',
    'Hand Axe',
    'Bardiche',
    'Bec De Corbin',
    'Bill-Guisarme',
    'Bo Stick',
    'Club',
    'Dagger',
    'Dart',
    'Fauchard',
    'Fauchard-Fork',
    'Flail',
    'Military Fork',
    'Glaive',
    'Glaive-Guisarme',
    'Guisarme',
    'Guisarme-Voulge',
    'Halberd',
    'Lucern Hammer',
    'Hammer',
    'Javelin',
    'Jo Stick',
    'Mace',
    'Morning Star',
    'Partisan',
    'Military Pick',
    'Awl Pike',
    'Quarrel',
    'Ranseur',
    'Scimitar',
    'Spear',
    'Spetum',
    'Quarter Staff',
    'Bastard Sword',
    'Broad Sword',
    'Long Sword',
    'Short Sword',
    'Two-Handed Sword',
    'Trident',
    'Voulge',
    'Composite Long Bow',
    'Composite Short Bow',
    'Long Bow',
    'Short Bow',
    'Heavy Crossbow',
    'Light Crossbow',
    'Sling',
    'Mail',
    'Armor',
    'Leather',
    'Padded',
    'Studded',
    'Ring',
    'Scale',
    'Chain',
    'Splint',
    'Banded',
    'Plate',
    'Shield',
    'Woods',
    'Arrow',
    '',
    '',
    'Potion',
    'Scroll',
    'Ring',
    'Rod',
    'Stave',
    'Wand',
    'Jug',
    'Amulet',
    'Apparatus',
    'Bag',
    'Beaker',
    'Boat',
    'Book',
    'Boots',
    'Bowl',
    'Bracers',
    'Brazier',
    'Brooch',
    'Broom',
    'Purse',
    'Candle',
    'Carpet',
    'Censer',
    'Chime',
    'Cloak',
    'Crystal',
    'Cube',
    'Cubic',
    'Fortress',
    'Decanter',
    'Deck',
    'Drums',
    'Dust',
    'Eyes',
    'Figurine',
    'Flask',
    'Gauntlets',
    'Gem',
    'Girdle',
    'Helm',
    'Horn',
    'Horseshoes',
    'Incense',
    'Stone',
    'Instrument',
    'Javelin',
    'Jewel',
    'Ointment',
    'Libram',
    'Lyre',
    'Manual',
    'Mattock',
    'Maul',
    'Medallion',
    'Mirror',
    'Necklace',
    'Net',
    'Pigment',
    'Pearl',
    'Periapt',
    'Phylactery',
    'Pipes',
    'Hole',
    'Token',
    'Robe',
    'Rope',
    'Rug',
    'Saw',
    'Scarab',
    'Spade',
    'Sphere',
    '',
    'Talisman',
    'Tome',
    'Trident',
    'Grimoire',
    'Well',
    'Wings',
    'Vial',
    'Lantern',
    '',
    'Oil',
    '10 ft. Pole',
    '50 ft. Rope',
    'Iron',
    'Thf Prickly Tools',
    'Iron Rations',
    'Standard Rations',
    'Holy Symbol',
    'Holy Water vial',
    'Unholy Water vial',
    'Barding',
    'Dragon',
    'Lightning',
    'Saddle',
    'Small Raft',
    'Cart',
    'Wagon',
    '+1',
    '+2',
    '+3',
    '+4',
    '+5',
    'of',
    '',
    'Cloak',
    'Displacement',
    'Torches',
    'Oil',
    'Speed',
    'Tapestry',
    'Bodily Health',
    'Copper',
    'Silver',
    'Electrum',
    'Gold',
    'Platinum',
    'Ointment',
    'Keoghtum''s',
    'Sheet',
    'Strength',
    'Healing',
    'Holding',
    'Extra',
    'Gaseous Form',
    'Slipperiness',
    'Jewelled',
    'Flying',
    'Treasure Finding',
    'Fear',
    'Disappearance',
    'Statuette',
    'Fungus',
    'Chain',
    'Pendant',
    'Broach',
    'Of Seeking',
    '-1',
    '-2',
    '-3',
    'Lightning Bolt',
    'Fire Resistance',
    'Magic Missiles',
    'Save',
    'Clerical Scroll',
    'Magic User Scroll',
    'With 1 Spell',
    'With 2 Spells',
    'With 3 Spells',
    'Protection Scroll',
    'Jewelry',
    'Fine',
    'Huge',
    'Bone',
    'Brass',
    'Key',
    'AC 2',
    'AC 6',
    'AC 4',
    'AC 3',
    'Of Protection',
    'Paralyzation',
    'Ogre Power',
    'Invisibility',
    'Missiles',
    'Elvenkind',
    'Rotting',
    'Covered',
    'Efreeti',
    'Bottle',
    'Missile Attractor',
    'Of Maglubiyet',
    'Secr Door & Trap Det',
    'Gd Dragon Control',
    'Feather Falling',
    'Giant Strength',
    'Restoring Level(s)',
    'Flame Tongue',
    'Fireballs',
    'Spiritual',
    'Boulder',
    'Diamond',
    'Emerald',
    'Opal',
    'Saphire',
    'Of Tyr',
    'Of Tempus',
    'Of Sune',
    'Wooden',
    '+3 vs Undead',
    'Pass',
    'Cursed');
var
  i: Byte;
  mask: Byte;
  effect: Types.PEffectRec;
  found: Boolean;
  appended: Boolean;
  p: Types.PCharRecord;
begin
  item^.name := '';
  if isInv then begin
    if item^.equipped <> 0 then
      item^.name := ' Yes  '
    else
      item^.name := ' No   ';
  end;
  found := False;
  p := GameVars.creatureList;
  while (p <> nil) and not found do begin
    if CharHlp.HasEffect(p, C_EFFECT.DETECT_MAGIC, effect) then
      found := True;
    p := p^.nextCharAddr;
  end;
  if found then
    if (item^.plus > 0) or (item^.saveBonus > 0) or (item^.cursed <> 0) then
      item^.name := item^.name + '*' + ' ';
  if item^.quantity > 0 then
    item^.name := item^.name + StrUtil.NumStr(item^.quantity) + ' ';
  mask := 0;
  for i := 1 to 3 do
    if item^.nameIds[i] <> 0 then
      if (item^.unidMask shr (3 - i)) and 1 = 0 then
        Inc(mask, 1 shl (i - 1));
  appended := False;
  for i := 3 downto 1 do
    if (mask shr (i - 1)) and 1 > 0 then begin
      item^.name := item^.name + nameParts[item^.nameIds[i]];
      if (item^.quantity < 2) or appended then
        item^.name := item^.name + ' '
      else if ((1 shl (i - 1)) = mask) or ((i = 1) and (mask > 4) and (item^.itemType <> C_ITEM.FLASK_OF_OIL)) or
        ((i = 2) and not Odd(mask)) or ((i = 3) and (item^.itemType = C_ITEM.FLASK_OF_OIL)) or
        (((item^.itemType = C_ITEM.ARROW) or (item^.itemType = C_ITEM.QUARREL)) and
         (item^.nameIds[3] <> C_ITEM.NAME_SILVER)) then begin
        item^.name := item^.name + 's ';
        appended := True;
      end else
        item^.name := item^.name + ' ';
    end;
end;

{ Return True if any of the four helplessness effects in GameDefs.helplessFx is active on the creature. }
function IsHelpless(creature: Types.PCharRecord): Boolean;
var
  i: Byte;
  effect: Types.PEffectRec;
begin
  IsHelpless := False;
  for i := 1 to GameDefs.HELPLESS_FX_COUNT do
    if CharHlp.HasEffect(creature, GameDefs.helplessFx[i], effect) then
      IsHelpless := True;
end;

{ Point creature's equipment slots at its readied items, every other slot nil: a second ring goes in RING2, arrows and
  quarrels in their own slots (C_EQUIP.ARROW and BOLT) as well as their base item's. }
procedure LinkEquipped(creature: Types.PCharRecord);
var
  i: ShortInt;
  item: Types.PItemRec;
  slot: 0..127;
begin
  for i := C_EQUIP.WEAPON to C_EQUIP.BOLT do
    creature^.equipped[i] := nil;
  item := creature^.itemsAddr;
  while item <> nil do begin
    if item^.equipped <> 0 then begin
      slot := CharHlp.BaseItem(item^.itemType)^.slot;
      case Byte(slot) of
        C_EQUIP.WEAPON..C_EQUIP.BOOTS: creature^.equipped[slot] := item;
        C_EQUIP.RING1:
          if creature^.equipped[C_EQUIP.RING1] <> nil then begin
            if creature^.equipped[C_EQUIP.RING2] = nil then
              creature^.equipped[C_EQUIP.RING2] := item;
          end else
            creature^.equipped[C_EQUIP.RING1] := item;
      end;
      if item^.itemType = C_ITEM.ARROW then
        creature^.equipped[C_EQUIP.ARROW] := item;
      if item^.itemType = C_ITEM.QUARREL then
        creature^.equipped[C_EQUIP.BOLT] := item;
    end;
    item := item^.next;
  end;
end;

{ Rebuild equipment slots (LinkEquipped) and encumbrance, apply strength, dexterity and item adjustments, then calculate
  armor class, rear armor class (no shield or Dexterity bonus, but any Dexterity penalty), attack level
  (CharHlp.WarriorLevel for a non-monster warrior, else 1), movement and, for a thief, the thief skills
  (ClassCal.RecalcThiefSkills). An equipped Bag of Holding (name component 'Holding') removes up to BAG_OF_HOLDING_COINS
  of encumbrance, never leaving less than the equipped items' weight. The weight is summed in 32 bits and stored as at
  most MAX_ENCUMBRANCE. }
procedure RecalcStats(creature: Types.PCharRecord);
var
  j: Byte;
  k: ShortInt;
  item: Types.PItemRec;
  magicBody: Boolean;
  bag: Boolean;
  adj: Types.TAcAdjust;
  c: ShortInt;
  w: LongInt;
  raw: LongInt;
  ringSave: ShortInt;
begin
  CharHlp.LinkEquipped(creature);
  bag := False;
  creature^.numberOfItems := 0;
  item := creature^.itemsAddr;
  creature^.handsEquipped := 0;
  raw := 0;
  gEquipWeight := 0;
  while item <> nil do begin
    Inc(creature^.numberOfItems);
    w := CharHlp.ItemWeight(item);
    Inc(raw, w);
    if item^.equipped <> 0 then begin
      Inc(gEquipWeight, w);
      if item^.nameIds[1] = C_ITEM.NAME_HOLDING then
        bag := True;
      creature^.handsEquipped := creature^.handsEquipped + CharHlp.BaseItem(item^.itemType)^.hands;
    end;
    item := item^.next;
  end;
  for c := C_MONEY.COPPER to C_MONEY.JEWELRY do
    Inc(raw, creature^.coins[c]);
  for j := 1 to 2 do begin
    creature^.curRollsA[j] := creature^.unarmedRollsA[j];
    creature^.curDiceA[j] := creature^.unarmedDiceA[j];
    creature^.curModA[j] := creature^.unarmedModA[j];
  end;
  for k := Types.AC_DEX to Types.AC_ARMOR do
    adj[k] := 0;
  magicBody := False;
  creature^.saveBonus := 0;
  ringSave := 0;
  creature^.acCur := creature^.acBase;
  creature^.movementCur := creature^.movementBase;
  creature^.thac0Cur := creature^.thac0Base;
  adj[Types.AC_DEX] := AbilAdj.DexterityArmorAdjustment(creature);
  if creature^.equipped[C_EQUIP.WEAPON] = nil then begin
    creature^.thac0Cur := AbilAdj.StrToHitAdjust(creature) + creature^.thac0Cur;
    creature^.curModA[1] := AbilAdj.StrDamageAdjust(creature) + creature^.curModA[1];
  end;
  CharHlp.WeaponAdjust(creature);
  item := creature^.itemsAddr;
  while item <> nil do begin
    if item^.equipped <> 0 then begin
      CharHlp.ArmorMoveAdjust(creature, item);
      CharHlp.ArmorAdjustHelper(creature, item, @adj, @magicBody, ringSave);
    end;
    item := item^.next;
  end;
  { a Ring of Protection guards saves as well as AC: the best ring counts once, and magical body armor cancels only its
    AC }
  creature^.saveBonus := creature^.saveBonus + ringSave;
  { rings do not add to magical body armor }
  if magicBody then
    adj[Types.AC_RING] := 0;
  if bag then begin
    if raw < BAG_OF_HOLDING_COINS then
      raw := 0
    else
      Dec(raw, BAG_OF_HOLDING_COINS);
    if raw < gEquipWeight then
      raw := gEquipWeight;
  end;
  if raw > MAX_ENCUMBRANCE then
    raw := MAX_ENCUMBRANCE;
  creature^.encumbrance := raw;
  CharHlp.EncumbranceAdjust(creature);
  if adj[Types.AC_ARMOR] < creature^.acCur then
    adj[Types.AC_ARMOR] := creature^.acCur;
  creature^.acCur := 0;
  for k := Types.AC_DEX to Types.AC_ARMOR do
    creature^.acCur := creature^.acCur + adj[k];
  creature^.acBehind := adj[Types.AC_ARMOR] + adj[Types.AC_PLUSES] + adj[Types.AC_RING] - 1 - 1;
  { an attack from behind takes away a Dexterity bonus, not a penalty (#741) }
  if adj[Types.AC_DEX] < 0 then
    creature^.acBehind := creature^.acBehind + adj[Types.AC_DEX];
  if (CharHlp.WarriorLevel(creature) > 0) and (creature^.race > C_RACE.MONSTER) then
    creature^.attackLevel := CharHlp.WarriorLevel(creature)
  else
    creature^.attackLevel := 1;
  { readying or removing armor or a shield, or a change of Dexterity, changes the thief skills }
  if creature^.classLevels[C_LEVEL.THIEF] > 0 then
    ClassCal.RecalcThiefSkills(creature);
end;

procedure FixWeaponClasses(items: Types.PBaseItems);
begin
  items^[C_ITEM.BATTLE_AXE].wpnClass := C_ITEM.WPN_SLASH;
  items^[C_ITEM.BEC_DE_CORBIN].wpnClass := C_ITEM.WPN_PIERCE;
  items^[C_ITEM.MILITARY_FORK].wpnClass := C_ITEM.WPN_PIERCE;
  items^[C_ITEM.PARTISAN].wpnClass := C_ITEM.WPN_PIERCE;
  items^[C_ITEM.RANSEUR].wpnClass := C_ITEM.WPN_PIERCE;
  items^[C_ITEM.SPETUM].wpnClass := C_ITEM.WPN_PIERCE;
  items^[C_ITEM.SHORT_SWORD].wpnClass := C_ITEM.WPN_PIERCE;
  items^[C_ITEM.TRIDENT].wpnClass := C_ITEM.WPN_PIERCE;
  items^[C_ITEM.ARROW].wpnClass := C_ITEM.WPN_PIERCE;
end;

procedure FixAmmoBits(items: Types.PBaseItems);
var
  i: Byte;
begin
  with items^[C_ITEM.JAVELIN] do
    props := (props and not C_ITEM.PROP_FIRES_AMMO) or C_ITEM.PROPS_THROWABLE;
  for i := 0 to Types.BASE_ITEM_LAST do
    if (items^[i].props and C_ITEM.PROP_FIRES_AMMO) = 0 then
      items^[i].props := items^[i].props and not (C_ITEM.PROP_ARROWS or C_ITEM.PROP_QUARRELS);
end;

{ True when the creature has a Bag of Holding readied (name component C_ITEM.NAME_HOLDING). }
function HasBagOfHolding(creature: Types.PCharRecord): Boolean;
var
  item: Types.PItemRec;
begin
  HasBagOfHolding := False;
  item := creature^.itemsAddr;
  while item <> nil do begin
    if (item^.equipped <> 0) and (item^.nameIds[1] = C_ITEM.NAME_HOLDING) then
      HasBagOfHolding := True;
    item := item^.next;
  end;
end;

{ The creature's weight in coins before a Bag of Holding takes its share: every item (weight times quantity) and every
  coin, gem and piece of jewelry, as RecalcStats adds them up. }
function RawWeight(creature: Types.PCharRecord): LongInt;
var
  item: Types.PItemRec;
  w: LongInt;
  c: ShortInt;
begin
  w := 0;
  item := creature^.itemsAddr;
  while item <> nil do begin
    Inc(w, CharHlp.ItemWeight(item));
    item := item^.next;
  end;
  for c := C_MONEY.COPPER to C_MONEY.JEWELRY do
    Inc(w, creature^.coins[c]);
  RawWeight := w;
end;

function ItemWeight(item: Types.PItemRec): LongInt;
begin
  if item^.quantity > 0 then
    ItemWeight := LongInt(item^.quantity) * item^.weight
  else
    ItemWeight := item^.weight;
end;

{ Clear the first memorized-spell slot holding spell on the creature. }
procedure RemoveSpell(creature: Types.PCharRecord; spell: Byte);
var
  i: Byte;
begin
  i := 0;
  { scan the memorized-spell slots, stopping after the first match }
  while i <= Types.SPELL_SLOT_LAST do begin
    if creature^.memorizedSpells[i] = spell then begin
      creature^.memorizedSpells[i] := 0;
      i := Types.SPELL_SLOT_LAST + 1;
    end;
    Inc(i);
  end;
end;

procedure FreeItemList(var list: Types.PItemRec);
var
  next: Types.PItemRec;
begin
  while list <> nil do begin
    next := list^.next;
    FreeMem(list, SizeOf(Types.TItemRec));
    list := next;
  end;
end;

procedure PrependItemCopy(var list: Types.PItemRec; item: Types.PItemRec);
var
  n: Types.PItemRec;
begin
  GetMem(n, SizeOf(Types.TItemRec));
  n^ := item^;
  n^.next := list;
  list := n;
end;

procedure PrependEffectCopy(var list: Types.PEffectRec; effect: Types.PEffectRec);
var
  n: Types.PEffectRec;
begin
  GetMem(n, SizeOf(Types.TEffectRec));
  n^ := effect^;
  n^.next := list;
  list := n;
end;

procedure ClearTreasure;
begin
  CharHlp.FreeItemList(GameVars.treasureItems);
  FillChar(GameVars.treasureMoney, SizeOf(GameVars.treasureMoney), 0);
end;

{ Report a fault through faultHook, when one is set. }
procedure Fault(msg: Types.TStr40);
begin
  if @faultHook <> nil then
    faultHook(msg);
end;

{ Unlink an item from the creature's inventory list and free it; a nil item or one not in the list only gets an error
  message. }
procedure RemoveItem(creature: Types.PCharRecord; item: Types.PItemRec);
var
  p: Types.PItemRec;
begin
  if item = nil then
    CharHlp.Fault('Nil Item pointer...')
  else begin
    p := creature^.itemsAddr;
    if p = item then
      creature^.itemsAddr := item^.next
    else
      while (p <> nil) and (p^.next <> item) do
        p := p^.next;
    if p = nil then
      CharHlp.Fault('Tried to Lose item & couldn''t find it!')
    else begin
      p^.next := item^.next;
      item^.next := nil;
      FreeMem(item, SizeOf(Types.TItemRec));
    end;
  end;
end;

procedure AppendItemCopy(var list: Types.PItemRec; item: Types.PItemRec);
var
  p: Types.PItemRec;
  n: Types.PItemRec;
begin
  GetMem(n, SizeOf(Types.TItemRec));
  Move(item^, n^, SizeOf(Types.TItemRec));
  n^.next := nil;
  p := list;
  if p = nil then
    list := n
  else begin
    while p^.next <> nil do
      p := p^.next;
    p^.next := n;
  end;
end;

{ True when the creature carries effect id; effect is left on the matching node, or nil. }
function HasEffect(creature: Types.PCharRecord; id: Byte; var effect: Types.PEffectRec): Boolean;
var
  found: Boolean;
begin
  found := False;
  effect := creature^.effectsAddr;
  while (effect <> nil) and not found do begin
    if effect^.id = id then
      found := True
    else
      effect := effect^.next;
  end;
  HasEffect := found;
end;

function HasteSlowRate(creature: Types.PCharRecord; n: Byte): Byte;
var
  effect: Types.PEffectRec;
  hasted: Boolean;
  slowed: Boolean;
begin
  hasted := CharHlp.HasEffect(creature, C_EFFECT.HASTED, effect);
  slowed := CharHlp.HasEffect(creature, C_EFFECT.SLOWED, effect);
  if hasted and not slowed then begin
    if n > 127 then
      n := 255
    else
      n := n * 2;
  end else if slowed and not hasted then
    n := n div 2;
  HasteSlowRate := n;
end;

{ Apply damage and update status. More than nine points of overkill kills; lesser overkill leaves the creature dying.
  Exactly zero hit points leaves it unconscious, except an animated creature dies. A creature that is no longer okay or
  animated is taken out of action, and in combat also out of its team count and the initiative order. A dead, stoned or
  gone creature takes no damage, so a small hit on a corpse cannot turn it back into a dying one. }
procedure InflictDamage(creature: Types.PCharRecord; dmg: Byte);
var
  over: Byte;
  remain: Byte;
  wasUp: Boolean;
  hpBefore: Byte;
begin
  if creature^.status in [C_STATUS.DEAD, C_STATUS.STONED, C_STATUS.GONE] then Exit;
  wasUp := creature^.status in [C_STATUS.OKAY, C_STATUS.ANIMATED];
  hpBefore := creature^.hpCur;
  over := 0;
  remain := 0;
  if creature^.hpCur >= dmg then
    remain := creature^.hpCur - dmg
  else
    over := dmg - creature^.hpCur;
  if (over > 9) or ((remain = 0) and (creature^.status = C_STATUS.ANIMATED)) then
    creature^.status := C_STATUS.DEAD
  else if over > 0 then begin
    creature^.status := C_STATUS.DYING;
    if GameVars.ifcState = C_IFC.COMBAT then
      creature^.combatAddr^.overkill := over;
  end else if remain = 0 then
    creature^.status := C_STATUS.UNCONSCIOUS;
  if not (creature^.status in [C_STATUS.OKAY, C_STATUS.ANIMATED]) then begin
    creature^.enabled := 0;
    creature^.hpCur := 0;
    if GameVars.ifcState = C_IFC.COMBAT then begin
      { a creature already down (dying or unconscious) left its team count when it fell }
      if wasUp then
        Dec(GameVars.teamCount[CharHlp.Team(creature)]);
      creature^.combatAddr^.initiative := 0;
    end;
  end else
    creature^.hpCur := remain;
  { the statistics (#611), credited to the creature acting }
  Stats.Damaged(GameVars.curChar, creature, hpBefore - creature^.hpCur, wasUp);
end;

{ Return the opposing team index: 1 for a friendly creature (hostile = 0), else 0. }
function EnemyTeam(creature: Types.PCharRecord): ShortInt;
begin
  if creature^.hostile = 0 then
    EnemyTeam := 1
  else
    EnemyTeam := 0;
end;

function Team(creature: Types.PCharRecord): Byte;
begin
  Team := Byte(creature^.hostile) and 1;
end;

{ Recount the creatures still in action on each team (CharHlp.Team). }
procedure CountTeams;
var
  p: Types.PCharRecord;
begin
  GameVars.teamCount[0] := 0;
  GameVars.teamCount[1] := 0;
  p := GameVars.creatureList;
  while p <> nil do begin
    if p^.enabled <> 0 then
      Inc(GameVars.teamCount[CharHlp.Team(p)]);
    p := p^.nextCharAddr;
  end;
end;

{ Zero the creature's per-round combat state (initiative, spell being cast, guarding, movement). Always returns True. }
function EndActions(creature: Types.PCharRecord): Boolean;
begin
  creature^.combatAddr^.initiative := 0;
  creature^.combatAddr^.spellCast := 0;
  creature^.combatAddr^.guarding := 0;
  creature^.combatAddr^.movement := 0;
  EndActions := True;
end;

{ True when the creature may use an item now: an able character outside an anti-magic area, in camp, outdoors or
  indoors, or in combat while still allowed an item this round. }
function CanUseItems(creature: Types.PCharRecord): Boolean;
begin
  CanUseItems := (creature^.enabled <> 0) and (GameVars.zone0^.antimagic = 0) and
                 ((GameVars.ifcState = C_IFC.CAMPING) or (GameVars.ifcState = C_IFC.OUTDOORS) or
                  (GameVars.ifcState = C_IFC.INDOORS) or
                  ((GameVars.ifcState = C_IFC.COMBAT) and (creature^.combatAddr^.itemUseAllowed <> 0)));
end;

{ End the creature's round and raise its guarding flag; the caller announces it ('Guarding'). Always returns True. }
function Guard(creature: Types.PCharRecord): Boolean;
begin
  Guard := CharHlp.EndActions(creature);
  creature^.combatAddr^.guarding := 1;
end;

{ Caster level for a spell id: the current character's cleric or magic-user level by casting class
  (C_SPELL.SPECIAL_CASTER_LEVEL for the special class), C_SPELL.ITEM_CASTER_LEVEL when cast from an item
  (GameVars.usingItem) unless the class is the special one. }
function GetCasterLevel(spell: Byte): Byte;
begin
  case GameDefs.spellTable[spell].castClass of
    C_SPELL.CLASS_CLERIC: GetCasterLevel := GameVars.curChar^.classLevels[C_LEVEL.CLERIC];
    C_SPELL.CLASS_MAGE: GetCasterLevel := GameVars.curChar^.classLevels[C_LEVEL.MAGE];
    C_SPELL.CLASS_SPECIAL: GetCasterLevel := C_SPELL.SPECIAL_CASTER_LEVEL;
  end;
  if GameVars.usingItem and (GameDefs.spellTable[spell].castClass <> C_SPELL.CLASS_SPECIAL) then
    GetCasterLevel := C_SPELL.ITEM_CASTER_LEVEL;
end;

{ True when the readied weapon has a range past 1 (thrown weapons count). }
function HasRangedWeapon(creature: Types.PCharRecord): Boolean;
begin
  if (creature^.equipped[C_EQUIP.WEAPON] <> nil) and
      (CharHlp.BaseItem(creature^.equipped[C_EQUIP.WEAPON]^.itemType)^.range > 1) then
    HasRangedWeapon := True
  else
    HasRangedWeapon := False;
end;

{ True when the readied weapon is ranged and carries both C_ITEM.PROPS_THROWABLE bits (thrown, Strength bonus). }
function HasThrowableWeapon(creature: Types.PCharRecord): Boolean;
begin
  if CharHlp.HasRangedWeapon(creature) and
      ((CharHlp.BaseItem(creature^.equipped[C_EQUIP.WEAPON]^.itemType)^.props and
        C_ITEM.PROPS_THROWABLE) = C_ITEM.PROPS_THROWABLE) then
    HasThrowableWeapon := True
  else
    HasThrowableWeapon := False;
end;

function FindDamagingRangedWeapon(creature: Types.PCharRecord; var sel: Types.PItemRec): Boolean;
begin
  FindDamagingRangedWeapon := CharHlp.FindAmmo(creature, creature^.equipped[C_EQUIP.WEAPON], sel);
end;

function FindAmmo(creature: Types.PCharRecord; w: Types.PItemRec; var sel: Types.PItemRec): Boolean;
var
  props: Byte;
begin
  FindAmmo := False;
  sel := nil;
  props := 0;
  if w <> nil then begin
    props := CharHlp.BaseItem(w^.itemType)^.props;
    if (props and C_ITEM.PROP_THROWN) <> 0 then
      sel := w;
    if (props and C_ITEM.PROP_FIRES_AMMO) <> 0 then begin
      if (props and C_ITEM.PROP_ARROWS) <> 0 then
        sel := creature^.equipped[C_EQUIP.ARROW];
      if (props and C_ITEM.PROP_QUARRELS) <> 0 then
        sel := creature^.equipped[C_EQUIP.BOLT];
    end;
  end;
  if (sel <> nil) or (props = C_ITEM.PROP_DEX_MISSILE + C_ITEM.PROP_FIRES_AMMO) then
    FindAmmo := True;
end;

function CanTrain(creature: Types.PCharRecord): Boolean;
var
  cls: ShortInt;
  lvl: ShortInt;
begin
  CanTrain := False;
  for cls := C_LEVEL.CLERIC to C_LEVEL.MONK do begin
    lvl := creature^.classLevels[cls];
    { xp[] runs to C_LEVEL.LEVEL_LAST }
    if (lvl > 0) and (lvl < C_LEVEL.LEVEL_LAST) then
      if not CharHlp.AtLevelCap(creature, cls) then
        if GameDefs.experienceSpellsClass[cls].xp[lvl + 1] > 0 then
          if GameDefs.experienceSpellsClass[cls].xp[lvl + 1] <= creature^.experience then
            CanTrain := True;
  end;
end;

{ SSI's tests matched some levels past the cap and not others, and read the Strength magic had raised or disease lowered
  (#702). Monsters, half-orcs and humans have no limit here. }
function AtLevelCap(creature: Types.PCharRecord; cls: ShortInt): Boolean;
var
  lvl: ShortInt;
  band: Byte;
  str: Byte;
begin
  AtLevelCap := False;
  with creature^ do begin
    lvl := classLevels[cls];
    if lvl <= 0 then
      Exit;
    str := CharHlp.PermanentStrength(creature);
    if str < 17 then
      band := STR_BAND_LOW
    else if str = 17 then
      band := STR_BAND_17
    else
      band := STR_BAND_18;
    if (race = C_RACE.HALFELF) and (cls = C_LEVEL.CLERIC) then
      AtLevelCap := lvl >= HALFELF_CLERIC_CAP
    else if (race in [C_RACE.DWARF..C_RACE.HALFLING]) and
            ((cls = C_LEVEL.FIGHTER) or ((cls = C_LEVEL.RANGER) and (race = C_RACE.HALFELF))) then
      AtLevelCap := (FIGHTER_CAP[race, band] <> 0) and (lvl >= FIGHTER_CAP[race, band]);
  end;
end;

function DiseaseStrLoss(creature: Types.PCharRecord): Byte;
var
  effect: Types.PEffectRec;
begin
  if CharHlp.HasEffect(creature, C_EFFECT.DISEASE_STR, effect) then
    DiseaseStrLoss := effect^.strength shr 4
  else
    DiseaseStrLoss := 0;
end;

function PermanentStrength(creature: Types.PCharRecord): Byte;
var
  p: Types.PEffectRec;
  base: Byte;
  exc: Byte;
begin
  PermanentStrength := creature^.strCur;
  p := creature^.effectsAddr;
  while p <> nil do begin
    if ((p^.id = C_EFFECT.ENLARGE) or (p^.id = C_EFFECT.STRENGTH)) and (p^.strength < $80) then begin
      AbilAdj.StrengthEffectToStrength(p, base, exc);
      { the stored Strength is whole; the disease's loss counts, as it does in strCur }
      PermanentStrength := AbilAdj.ClampScore(Integer(base) - CharHlp.DiseaseStrLoss(creature));
      Exit;
    end;
    p := p^.next;
  end;
end;

function WarriorLevel(creature: Types.PCharRecord): ShortInt;
var
  best: ShortInt;
begin
  best := creature^.classLevels[C_LEVEL.FIGHTER];
  if creature^.classLevels[C_LEVEL.PALADIN] > best then
    best := creature^.classLevels[C_LEVEL.PALADIN];
  if creature^.classLevels[C_LEVEL.RANGER] > best then
    best := creature^.classLevels[C_LEVEL.RANGER];
  if best < 0 then
    best := 0;
  WarriorLevel := best;
end;

function BaseItem(itemType: Byte): Types.PBaseItemRec;
begin
  if itemType > Types.BASE_ITEM_LAST then
    BaseItem := @baseItems^[Types.BASE_ITEM_OVERFLOW]
  else
    BaseItem := @baseItems^[itemType];
end;

function IsNpc(creature: Types.PCharRecord): Boolean;
begin
  IsNpc := creature^.npc >= C_NPC.FLAG;
end;

function MayTrade(creature: Types.PCharRecord): Boolean;
begin
  MayTrade := not CharHlp.IsNpc(creature) or (creature^.enabled = 0) or (creature^.status = C_STATUS.ANIMATED);
end;

function IsPerson(creature: Types.PCharRecord): Boolean;
const
  personFoes: array[1..2] of Types.TName15 = ('GRISHNAK', 'LIZARDMAN');
var
  i: Byte;
  named: Boolean;
begin
  named := False;
  for i := 1 to GameDefs.RANGER_PERSONS do
    if creature^.name = GameDefs.rangerFoes[i] then
      named := True;
  for i := 1 to SizeOf(personFoes) div SizeOf(personFoes[1]) do
    if creature^.name = personFoes[i] then
      named := True;
  IsPerson := (creature^.charType <> UNDEAD_TYPE) and
              (named or ((creature^.iconDimensions = 1) and
                         ((creature^.race <> C_RACE.MONSTER) or (creature^.charType = 0))));
end;

function ComesUnderPlayer(creature: Types.PCharRecord): Boolean;
begin
  ComesUnderPlayer := not CharHlp.IsNpc(creature) and (creature^.status <> C_STATUS.ANIMATED);
end;

function ItemReadable(it: Pointer): Boolean;
begin
  if (it <> nil) and
     (CharHlp.BaseItem(Types.PItemRec(it)^.itemType)^.slot in [C_ITEM.SLOT_MAGE_SCROLL..C_ITEM.SLOT_LAST_READABLE]) then
    ItemReadable := True
  else
    ItemReadable := False;
end;

function ScrollLegible(creature: Types.PCharRecord; item: Types.PItemRec): Boolean;
var
  effect: Types.PEffectRec;
begin
  if CharHlp.HasEffect(creature, C_EFFECT.READ_MAGIC, effect) or
      ((creature^.classLevels[C_LEVEL.CLERIC] > 0) and
       (CharHlp.BaseItem(item^.itemType)^.slot = C_ITEM.SLOT_CLERIC_SCROLL)) then
    item^.unidMask := 0;
  ScrollLegible := item^.unidMask = 0;
end;

{ The spell in item's spell slot (1..3), bit 7 ignored, or C_SPELL.NONE when the slot is out of range or holds no
  spell. }
function ScrollSpellAt(item: Types.PItemRec; slot: Byte): Byte;
var
  id: Byte;
begin
  ScrollSpellAt := C_SPELL.NONE;
  if (slot >= 1) and (slot <= SizeOf(item^.spells)) then begin
    id := item^.spells[slot] and C_SPELL.ID_MASK;
    if (id >= 1) and (id <= C_SPELL.LAST) then
      ScrollSpellAt := id;
  end;
end;

function CastableScroll(creature: Types.PCharRecord; item: Types.PItemRec): Boolean;
begin
  CastableScroll := False;
  if CharHlp.ItemReadable(item) then
    if (item^.equipped <> 0) or (CharHlp.BaseItem(item^.itemType)^.classMask and creature^.itemLimits <> 0) then
      CastableScroll := CharHlp.ScrollLegible(creature, item);
end;

function HasScrollSpells(creature: Types.PCharRecord): Boolean;
var
  item: Types.PItemRec;
  i: Byte;
  found: Boolean;
begin
  found := False;
  if CharHlp.CanUseItems(creature) then begin
    item := creature^.itemsAddr;
    while (item <> nil) and not found do begin
      if CharHlp.CastableScroll(creature, item) then
        for i := 1 to SizeOf(item^.spells) do
          if CharHlp.ScrollSpellAt(item, i) <> C_SPELL.NONE then
            found := True;
      item := item^.next;
    end;
  end;
  HasScrollSpells := found;
end;

function CalcSpellRange(spell: Byte): Byte;
var
  r: Byte;
begin
  if GameVars.usingItem = False then
    r := GameDefs.spellTable[spell].rangeFixed + GameDefs.spellTable[spell].rangeVar * CharHlp.GetCasterLevel(spell)
  else
    r := GameDefs.spellTable[spell].rangeVar * C_SPELL.ITEM_CASTER_LEVEL + GameDefs.spellTable[spell].rangeFixed;
  { Touch: zero range with an area }
  if (r = 0) and (GameDefs.spellTable[spell].area <> 0) then
    r := 1;
  if r = C_SPELL.ATTACK_ROLL_RANGE then
    r := 1;
  CalcSpellRange := r;
end;

function TheftChance(chance: Byte; weight: Word): Byte;
var
  penalty: Byte;
begin
  if weight > HEAVY_LOOT then
    penalty := HEAVY_LOOT_PENALTY
  else if weight > MEDIUM_LOOT then
    penalty := MEDIUM_LOOT_PENALTY
  else
    penalty := 0;
  if chance > penalty then
    TheftChance := chance - penalty
  else
    TheftChance := 0;
end;

begin
  { unset until GameInit sets it: global variables are not cleared at startup }
  @faultHook := nil;
  baseItems := nil;
end.

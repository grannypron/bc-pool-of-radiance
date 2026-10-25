{ Item values: TBaseItemRec's weapon-property bits and the base item IDs the code names. }
{$I COMPILER.INC}
unit C_ITEM;

interface

const
  { the most items a character carries: Halve, a found item and the Spiritual Hammer's need fewer }
  CARRY_MAX = 16;
  { TBaseItemRec.props weapon-property bit flags }
  { relates to arrow ammo (bow shoots / is arrows) }
  PROP_ARROWS = $01;
  { the Dexterity missile-attack bonus applies }
  PROP_DEX_MISSILE = $02;
  { Strength damage bonus applies }
  PROP_STR_BONUS = $04;
  { a launcher: fires separate ammo (bow/crossbow) }
  PROP_FIRES_AMMO = $08;
  { thrown weapon: is its own ammo }
  PROP_THROWN = $10;
  { relates to quarrel ammo (crossbow shoots / is quarrels) }
  PROP_QUARRELS = $80;
  { TBaseItemRec.wpnClass melee damage type. Pierce and bash are distinct bits, so wpnClass and (WPN_PIERCE or WPN_BASH)
    tests pierce-or-bash; slash is zero. }
  WPN_SLASH = 0;
  WPN_PIERCE = $01;
  WPN_BASH = $80;
  { A Strength-bonus weapon that can also be thrown (hand axe, spear, and the javelin from CharHlp.FixAmmoBits); it
    strikes in melee too. Consumers require both bits }
  PROPS_THROWABLE = PROP_THROWN or PROP_STR_BONUS;
  { Base item IDs. }
  { Base item for Spiritual Hammer. EffHndlr also sets nameIds[2] to name component 20; item IDs and name-component IDs
    are separate namespaces. }
  HAMMER = 20;
  { more base item types, from what the code does with them: weapons the thief may backstab with, missiles that fly
    straight, the ammunition slots' types }
  HAND_AXE = 2;
  CLUB = 7;
  DAGGER = 8;
  DART = 9;
  JAVELIN = 21;
  QUARREL = 28;
  SPEAR = 31;
  { the weapons whose damage type CharHlp.FixWeaponClasses corrects, with SHORT_SWORD and ARROW below }
  BATTLE_AXE = 1;
  BEC_DE_CORBIN = 4;
  MILITARY_FORK = 13;
  PARTISAN = 25;
  RANSEUR = 29;
  SPETUM = 32;
  TRIDENT = 39;
  { carries the arrows bit in ITEMS, which CharHlp.FixAmmoBits clears }
  BILL_GUISARME = 5;
  { the swords a thief may backstab with run BROAD_SWORD..SHORT_SWORD }
  BROAD_SWORD = 35;
  LONG_SWORD = 36;
  SHORT_SWORD = 37;
  { the bows, and the Heavy Crossbow, whose row the Fine Composite Long Bow is also built on }
  COMPOSITE_LONG_BOW = 41;
  COMPOSITE_SHORT_BOW = 42;
  LONG_BOW = 43;
  SHORT_BOW = 44;
  HEAVY_CROSSBOW = 45;
  SLING = 47;
  LEATHER_ARMOR = 50;
  ARROW = 73;
  { named by the armor class they give, not by their plus }
  BRACERS = 77;
  { scrolls: a magic-user's and a cleric's }
  MAGE_SCROLL = 61;
  CLERIC_SCROLL = 62;
  { eff 117 "vulnerability to holy water" }
  HOLY_WATER_VIAL = 85;
  { eff 122 "mummy vulnerability to fire" }
  FLASK_OF_OIL = 86;
  { eff 120 "boulder evasion" }
  BOULDER = 87;
  LARGE_BOULDER = 88;
  { the kinds RandItem.GenerateRandomItem makes as weapons and armor with a plus: 1..59, ARROW, BRACERS and
    RANDOM_ARMS_LAST }
  RANDOM_ARMS_LAST = 93;
  RANDOM_ARMS_KINDS = [1..59, ARROW, BRACERS, RANDOM_ARMS_LAST];
  { Item name parts the code tests or builds (TItemRec.nameIds, CharHlp.ItemLabel's nameParts) }
  NAME_HAMMER = 20;
  { the bows' names, the same numbers as their item types }
  NAME_COMPOSITE_LONG_BOW = 41;
  NAME_SHORT_BOW = 44;
  NAME_MIRROR = 118;
  NAME_HOLY_SYMBOL = 152;
  { NAME_PLUS_BASE + plus is "+1".."+5" }
  NAME_PLUS_BASE = 161;
  NAME_OF = 167;
  NAME_SILVER = 177;
  NAME_HOLDING = 186;
  { the bracers' "AC 2", "AC 6" and "AC 4" }
  NAME_AC_2 = 220;
  NAME_AC_6 = 221;
  NAME_AC_4 = 222;
  { scrolls: NAME_WITH_1_SPELL and up name their spell count }
  NAME_WITH_1_SPELL = 210;
  NAME_SPIRITUAL = 243;
  NAME_WOODEN = 252;
  { TBaseItemRec.slot past the equipment slots (C_EQUIP): a magic-user's scroll, a cleric's, and the last slot a
    readable item has }
  SLOT_MAGE_SCROLL = 11;
  SLOT_CLERIC_SCROLL = 12;
  SLOT_LAST_READABLE = 13;

implementation

end.

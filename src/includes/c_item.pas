{ Item values: TBaseItemRec's weapon-property bits and the base item IDs the code names. }
unit C_Item;

interface

const
  { TBaseItemRec.props weapon-property bit flags }
  { relates to arrow ammo (bow shoots / is arrows) }
  PROP_ARROWS = $01;
  { TBaseItemRec.props weapon-property bit: the Dexterity missile-attack bonus applies }
  PROP_DEX_MISSILE = $02;
  { Strength damage bonus applies }
  PROP_STR_BONUS = $04;
  { a launcher: fires separate ammo (bow/crossbow) }
  PROP_FIRES_AMMO = $08;
  { thrown weapon: is its own ammo }
  PROP_THROWN = $10;
  { eff 120 "boulder evasion" }
  BOULDER = 87;
  { eff 120 "boulder evasion" }
  LARGE_BOULDER = 88;
  { relates to quarrel ammo (crossbow shoots / is quarrels) }
  PROP_QUARRELS = $80;
  { A Strength-bonus weapon that can also be thrown (dagger, hand axe, spear, javelin); consumers require both bits }
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
  { eff 117 "vulnerability to holy water" }
  HOLY_WATER_VIAL = 85;
  { eff 122 "mummy vulnerability to fire" }
  FLASK_OF_OIL = 86;
  { Item name parts the code tests or builds (TItemRec.nameIds, GDConsts.nameParts) }
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
  { scrolls: NAME_WITH_1_SPELL and up name their spell count }
  NAME_WITH_1_SPELL = 210;
  NAME_SPIRITUAL = 243;
  NAME_WOODEN = 252;
  { TBaseItemRec.slot past the equipment slots (C_Equip): a magic-user's scroll, a cleric's, and the last slot a
    readable item has }
  SLOT_MAGE_SCROLL = 11;
  SLOT_CLERIC_SCROLL = 12;
  SLOT_LAST_READABLE = 13;

implementation

end.

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
  { eff 117 "vulnerability to holy water" }
  HOLY_WATER_VIAL = 85;
  { eff 122 "mummy vulnerability to fire" }
  FLASK_OF_OIL = 86;

implementation

end.

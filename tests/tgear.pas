{ Tests for Allow Gear Changes (#1127): with the setting off a party member keeps the weapon it readied, whatever it
  carries (CombatAi.KeepsGear, EquipWeaponAndShield), while NPCs, animated dead and monsters re-equip as before; with
  it on, nobody keeps it. }
{$I COMPILER.INC}
program TGear;

uses Types, C_EQUIP, C_ITEM, C_NPC, C_STATUS, GameVars, CharHlp, CombatAi, TestKit;

var
  c: Types.PCharRecord;
  sword: Types.TItemRec;
  bow: Types.TItemRec;

begin
  TestKit.Start('TGEAR');
  GetMem(c, SizeOf(Types.TCharRecord));
  FillChar(c^, SizeOf(Types.TCharRecord), 0);
  GetMem(CharHlp.baseItems, SizeOf(CharHlp.baseItems^));
  FillChar(CharHlp.baseItems^, SizeOf(CharHlp.baseItems^), 0);
  CharHlp.baseItems^[C_ITEM.LONG_SWORD].slot := C_EQUIP.WEAPON;
  { a two-handed sword, as the ranger of #1127 held }
  CharHlp.baseItems^[C_ITEM.LONG_SWORD].hands := 2;
  CharHlp.baseItems^[C_ITEM.LONG_BOW].slot := C_EQUIP.WEAPON;
  CharHlp.baseItems^[C_ITEM.LONG_BOW].hands := 2;
  CharHlp.baseItems^[C_ITEM.LONG_BOW].props := C_ITEM.PROP_FIRES_AMMO;
  FillChar(sword, SizeOf(sword), 0);
  sword.itemType := C_ITEM.LONG_SWORD;
  sword.equipped := 1;
  sword.next := @bow;
  FillChar(bow, SizeOf(bow), 0);
  bow.itemType := C_ITEM.LONG_BOW;
  bow.plus := 3;
  c^.itemsAddr := @sword;
  CharHlp.RecalcStats(c);

  GameVars.gearChangesOn := 0;
  TestKit.Check(CombatAi.KeepsGear(c), 'off: a party member keeps its gear');
  CombatAi.EquipWeaponAndShield(c);
  TestKit.Check((sword.equipped <> 0) and (bow.equipped = 0), 'its sword stays readied, the bow +3 packed');
  TestKit.Check(c^.equipped[C_EQUIP.WEAPON] = @sword, 'and in its hand');
  TestKit.CheckEqualsL(2, c^.handsEquipped, 'both hands still on the sword');
  c^.npc := C_NPC.FLAG;
  TestKit.Check(not CombatAi.KeepsGear(c), 'an NPC re-equips, as before');
  c^.npc := 0;
  c^.status := C_STATUS.ANIMATED;
  TestKit.Check(not CombatAi.KeepsGear(c), 'so do animated dead');
  c^.status := C_STATUS.OKAY;
  GameVars.gearChangesOn := 1;
  TestKit.Check(not CombatAi.KeepsGear(c), 'on: a party member re-equips, as SSI''s did');
  TestKit.Done;
end.

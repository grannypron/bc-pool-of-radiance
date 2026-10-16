{ Tests for CharHlp's rules: item labels, weights, warrior level, the NPC tests, effects and spells, item lists, and the
  racial level caps. }
program TCharHlp;

uses Types, GDVars, C_Item, C_Level, C_Race, C_Effect, C_Status, C_Money, C_Npc, CharHlp, TestKit;

var
  c: Types.PCharRecord;
  it: Types.TItemRec;
  list: Types.PItemRec;
  p: Types.PItemRec;
  e: Types.TEffectRec;
  found: Types.PEffectRec;

procedure NewItem(itemType, n1, n2, n3: Byte; quantity: Byte; weight: Word);
begin
  FillChar(it, SizeOf(it), 0);
  it.itemType := itemType;
  it.nameIds[1] := n1;
  it.nameIds[2] := n2;
  it.nameIds[3] := n3;
  it.quantity := quantity;
  it.weight := weight;
end;

procedure ClearCreature;
begin
  FillChar(c^, SizeOf(Types.TCharRecord), 0);
  c^.race := C_Race.HUMAN;
end;

begin
  TestKit.Start('TCHARHLP');
  GetMem(c, SizeOf(Types.TCharRecord));
  ClearCreature;
  GDVars.creatureList := nil;

  { labels }
  NewItem(21, 0, C_Item.NAME_PLUS_BASE + 1, 21, 0, 20);
  CharHlp.ItemLabel(@it, False);
  TestKit.CheckEqualsS('Javelin +1 ', it.name, 'an identified javelin +1');
  CharHlp.ItemLabel(@it, True);
  TestKit.CheckEqualsS(' No   Javelin +1 ', it.name, 'an inventory line, not readied');
  it.equipped := 1;
  CharHlp.ItemLabel(@it, True);
  TestKit.CheckEqualsS(' Yes  Javelin +1 ', it.name, 'an inventory line, readied');
  NewItem(73, 0, C_Item.NAME_PLUS_BASE + 1, 61, 3, 1);
  CharHlp.ItemLabel(@it, False);
  TestKit.CheckEqualsS('3 Arrows +1 ', it.name, 'three arrows +1: the count, and the arrow pluralized');
  NewItem(21, 0, C_Item.NAME_PLUS_BASE + 1, 21, 0, 20);
  it.unidMask := 6;
  CharHlp.ItemLabel(@it, False);
  TestKit.CheckEqualsS('Javelin ', it.name, 'unidentified parts are left out');
  { Detect Magic on a party member marks a magic item }
  ClearCreature;
  FillChar(e, SizeOf(e), 0);
  e.id := C_Effect.DETECT_MAGIC;
  c^.effectsAddr := @e;
  GDVars.creatureList := c;
  NewItem(21, 0, C_Item.NAME_PLUS_BASE + 1, 21, 0, 20);
  it.plus := 1;
  CharHlp.ItemLabel(@it, False);
  TestKit.CheckEqualsS('* Javelin +1 ', it.name, 'Detect Magic marks a magic item');
  TestKit.Check(CharHlp.HasEffect(c, C_Effect.DETECT_MAGIC, found) and (found = @e), 'HasEffect finds the effect');
  TestKit.Check(not CharHlp.HasEffect(c, C_Effect.BLESS, found) and (found = nil), 'and not one it lacks');
  c^.effectsAddr := nil;
  GDVars.creatureList := nil;

  { weights }
  NewItem(61, 0, 0, 61, 0, 2);
  TestKit.CheckEqualsL(2, CharHlp.ItemWeight(@it), 'a single item weighs its weight');
  it.quantity := 20;
  TestKit.CheckEqualsL(40, CharHlp.ItemWeight(@it), 'a stack weighs weight times quantity');
  ClearCreature;
  list := nil;
  CharHlp.AppendItemCopy(list, @it);
  NewItem(5, 0, 0, 5, 0, 150);
  CharHlp.AppendItemCopy(list, @it);
  c^.itemsAddr := list;
  c^.coins[C_Money.GOLD] := 100;
  c^.coins[C_Money.GEMS] := 3;
  TestKit.CheckEqualsL(40 + 150 + 103, CharHlp.RawWeight(c), 'raw weight: the items and every coin, gem and jewel');

  { item lists: appends go to the end, prepends to the front }
  TestKit.CheckEqualsL(61, list^.itemType, 'the first appended item is first');
  TestKit.CheckEqualsL(5, list^.next^.itemType, 'the second follows it');
  NewItem(28, 0, 0, 28, 0, 1);
  CharHlp.PrependItemCopy(list, @it);
  TestKit.CheckEqualsL(28, list^.itemType, 'a prepended item is first');
  c^.itemsAddr := list;
  p := list^.next^.next;
  CharHlp.RemoveItem(c, p);
  TestKit.Check(c^.itemsAddr^.next^.next = nil, 'RemoveItem unlinks the last item');
  CharHlp.RemoveItem(c, @it);
  TestKit.Check((c^.itemsAddr = list) and (list^.next^.next = nil),
                'RemoveItem of an item not in the list leaves it (no fault hook in a test)');
  CharHlp.FreeItemList(c^.itemsAddr);
  TestKit.Check(c^.itemsAddr = nil, 'FreeItemList leaves the list nil');

  { warrior level }
  ClearCreature;
  TestKit.CheckEqualsL(0, CharHlp.WarriorLevel(c), 'no warrior class: 0');
  c^.classLevels[C_Level.MAGE] := 5;
  c^.classLevels[C_Level.FIGHTER] := 3;
  c^.classLevels[C_Level.RANGER] := 4;
  TestKit.CheckEqualsL(4, CharHlp.WarriorLevel(c), 'the highest of fighter, paladin and ranger');
  c^.classLevels[C_Level.FIGHTER] := -1;
  c^.classLevels[C_Level.RANGER] := -1;
  TestKit.CheckEqualsL(0, CharHlp.WarriorLevel(c), 'a level below 0 counts as none');

  { the NPC tests }
  ClearCreature;
  TestKit.Check(not CharHlp.IsNpc(c), 'a player character is not an NPC');
  TestKit.Check(CharHlp.MayTrade(c) and CharHlp.ComesUnderPlayer(c), 'it trades and comes under the player');
  c^.npc := C_Npc.FLAG;
  c^.enabled := 1;
  TestKit.Check(CharHlp.IsNpc(c), 'the NPC flag makes an NPC');
  TestKit.Check(not CharHlp.MayTrade(c) and not CharHlp.ComesUnderPlayer(c), 'which neither trades nor comes under');
  c^.enabled := 0;
  TestKit.Check(CharHlp.MayTrade(c), 'a disabled NPC can be traded with');
  ClearCreature;
  c^.status := C_Status.ANIMATED;
  TestKit.Check(not CharHlp.ComesUnderPlayer(c), 'an animated party member stays under the AI');

  { spells }
  ClearCreature;
  c^.memorizedSpells[0] := 1;
  c^.memorizedSpells[1] := 3;
  c^.memorizedSpells[2] := 3;
  CharHlp.RemoveSpell(c, 3);
  TestKit.Check((c^.memorizedSpells[1] = 0) and (c^.memorizedSpells[2] = 3), 'RemoveSpell clears only the first copy');
  NewItem(0, 0, 0, 0, 0, 0);
  it.spells[2] := $85;
  TestKit.CheckEqualsL(5, CharHlp.ScrollSpellAt(@it, 2), 'a scroll''s spell, without its bit 7');
  TestKit.CheckEqualsL(0, CharHlp.ScrollSpellAt(@it, 4), 'no slot 4');

  { racial level caps }
  ClearCreature;
  c^.race := C_Race.ELF;
  c^.classLevels[C_Level.FIGHTER] := 7;
  TestKit.Check(CharHlp.AtLevelCap(c, C_Level.FIGHTER), 'an elf fighter stops at 7');
  c^.classLevels[C_Level.FIGHTER] := 5;
  c^.strCur := 17;
  TestKit.Check(not CharHlp.AtLevelCap(c, C_Level.FIGHTER), 'at 6 with Strength 17');
  c^.strCur := 16;
  TestKit.Check(CharHlp.AtLevelCap(c, C_Level.FIGHTER), 'at 5 with Strength below 17');
  c^.race := C_Race.HUMAN;
  c^.classLevels[C_Level.FIGHTER] := 8;
  TestKit.Check(not CharHlp.AtLevelCap(c, C_Level.FIGHTER), 'a human has no cap here');
  c^.race := C_Race.HALFELF;
  c^.classLevels[C_Level.CLERIC] := 5;
  TestKit.Check(CharHlp.AtLevelCap(c, C_Level.CLERIC), 'a half-elf cleric stops at 5');

  FreeMem(c, SizeOf(Types.TCharRecord));
  TestKit.Done;
end.

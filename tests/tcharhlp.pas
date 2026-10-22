{ Tests for CharHlp's rules: item labels, weights, warrior level, the NPC tests, effects and spells, item lists, and the
  racial level caps. }
{$I COMPILER.INC}
program TCharHlp;

uses Types, GDVars, C_Item, C_Level, C_Race, C_Effect, C_Status, C_Money, C_Npc, CharHlp, TestKit;

var
  c: Types.PCharRecord;
  it: Types.TItemRec;
  list: Types.PItemRec;
  p: Types.PItemRec;
  e: Types.TEffectRec;
  found: Types.PEffectRec;
  crs: array[1..4] of Types.TCharRecord;
  i: Byte;

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

{ SSI's racial level cap tests, as CharHlp.AtLevelCap had them: true only at the levels named }
function SsiCap(race, cls, lvl, str: Integer): Boolean;
begin
  SsiCap := False;
  case race of
    C_Race.DWARF:
      SsiCap := (cls = C_Level.FIGHTER) and (((lvl = 8) and (str = 17)) or ((lvl = 7) and (str < 17)));
    C_Race.ELF:
      SsiCap := (cls = C_Level.FIGHTER) and ((lvl = 7) or ((lvl = 6) and (str = 17)) or ((lvl = 5) and (str < 17)));
    C_Race.GNOME:
      SsiCap := (cls = C_Level.FIGHTER) and ((lvl = 6) or ((lvl = 5) and (str < 18)));
    C_Race.HALFELF:
      if (cls = C_Level.CLERIC) and (lvl = 5) then
        SsiCap := True
      else
        SsiCap := ((cls = C_Level.FIGHTER) or (cls = C_Level.RANGER)) and
                  ((lvl = 8) or ((lvl = 7) and (str = 17)) or ((lvl = 6) and (str < 17)));
    C_Race.HALFLING:
      SsiCap := (cls = C_Level.FIGHTER) and ((lvl = 6) or ((lvl = 5) and (str = 17)) or ((lvl = 4) and (str < 17)));
  end;
end;

{ AtLevelCap against SSI's tests for every race, the capped classes, Strength 3..18 and levels 1..9: capped from the
  first level SSI caps at, and at every level past it }
procedure CheckCapsMatchSsi;
var
  race: Integer;
  k: Integer;
  cls: Integer;
  str: Integer;
  lvl: Integer;
  l: Integer;
  want: Boolean;
  bad: Integer;
const
  CLASSES: array[1..3] of Integer = (C_Level.FIGHTER, C_Level.RANGER, C_Level.CLERIC);
begin
  bad := 0;
  for race := C_Race.DWARF to C_Race.HUMAN do
    for k := 1 to 3 do
      for str := 3 to 18 do
        for lvl := 1 to 9 do begin
          cls := CLASSES[k];
          ClearCreature;
          c^.race := race;
          c^.strCur := str;
          c^.classLevels[cls] := lvl;
          want := False;
          for l := 1 to lvl do
            if SsiCap(race, cls, l, str) then
              want := True;
          if CharHlp.AtLevelCap(c, cls) <> want then
            Inc(bad);
        end;
  TestKit.CheckEqualsL(0, bad, 'the racial caps match SSI''s, from the cap up');
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

  CheckCapsMatchSsi;

  FreeMem(c, SizeOf(Types.TCharRecord));
  { a robbery's chance per item (POR-0163): each item's weight penalty comes off the robbery's chance, not the last }
  TestKit.CheckEqualsL(70, CharHlp.TheftChance(70, 24), 'a light item keeps the chance');
  TestKit.CheckEqualsL(20, CharHlp.TheftChance(70, 25), 'over 24 coins, 50 less');
  TestKit.CheckEqualsL(0, CharHlp.TheftChance(70, 256), 'over 255 coins, 90 less, not below 0');
  TestKit.CheckEqualsL(5, CharHlp.TheftChance(95, 300), '95 less 90');
  TestKit.CheckEqualsL(70, CharHlp.TheftChance(70, 10), 'and the next light item has the whole chance again');

  { CountTeams counts each creature in action on team hostile and 1, as CombatSt places it: teamCount has only
    entries 0 and 1, and a damaged byte of 2 or 3 once counted past them (#710) }
  FillChar(crs, SizeOf(crs), 0);
  for i := 1 to 4 do begin
    crs[i].enabled := 1;
    if i < 4 then
      crs[i].nextCharAddr := @crs[i + 1];
  end;
  crs[1].hostile := 0;
  crs[2].hostile := 1;
  crs[3].hostile := 3;
  crs[4].hostile := 2;
  GDVars.creatureList := @crs[1];
  CharHlp.CountTeams;
  TestKit.CheckEqualsL(2, GDVars.teamCount[0], 'hostile 0 and 2 count on team 0');
  TestKit.CheckEqualsL(2, GDVars.teamCount[1], 'hostile 1 and 3 count on team 1');
  TestKit.Done;
end.

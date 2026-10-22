{ Tests for CharHlp's rules: item labels, weights, item lists, warrior level, persons, the NPC tests, effects and
  spells, the racial level caps and the Strength they follow, Haste and Slow, theft chances, team counts, the weapon
  fixes, rear AC and weapon pluses. }
{$I COMPILER.INC}
program TCharHlp;

uses Types, GDVars, C_ITEM, C_EQUIP, C_LEVEL, C_Race, C_EFFECT, C_STATUS, C_MONEY, C_NPC, CharHlp, AbilAdj, TestKit;

var
  c: Types.PCharRecord;
  it: Types.TItemRec;
  weapon: Types.TItemRec;
  arrows: Types.TItemRec;
  list: Types.PItemRec;
  p: Types.PItemRec;
  e: Types.TEffectRec;
  d: Types.TEffectRec;
  found: Types.PEffectRec;
  crs: array[1..4] of Types.TCharRecord;
  i: Byte;
  items: Types.PBaseItems;

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

{ CharHlp.IsPerson for a creature with the name, race byte, charType and iconDimensions of a record in the monster data
  (#792). }
function Person(name: Types.TName15; race, charType, icon: Byte): Boolean;
begin
  ClearCreature;
  c^.name := name;
  c^.race := race;
  c^.charType := charType;
  c^.iconDimensions := icon;
  Person := CharHlp.IsPerson(c);
end;

{ Charm Person and Hold Person affect the persons of the 1st-edition list, as the monster data describes them. }
procedure CheckPersons;
begin
  TestKit.Check(Person('GNOLL', C_Race.MONSTER, 1, $82), 'a gnoll is a person, two tiles and Large as it is');
  TestKit.Check(Person('KOBOLD', C_Race.MONSTER, 1, $01), 'and a kobold');
  TestKit.Check(Person('HOBGOBLIN LDR', C_Race.MONSTER, 0, $01), 'and a hobgoblin leader');
  TestKit.Check(Person('GRISHNAK', C_Race.MONSTER, 0, $01), 'and Grishnak');
  TestKit.Check(Person('LIZARDMAN', C_Race.MONSTER, 0, $01), 'and a lizard man');
  TestKit.Check(Person('ACOLYTE', C_Race.MONSTER, 0, $01), 'and a human whose race byte is 0');
  TestKit.Check(Person('MACE', C_Race.HALFORC, 0, $01), 'and a half-orc');
  TestKit.Check(Person('TYRANITHRAXUS', C_Race.HUMAN, 0, $01), 'and the False Tyranthraxus, a hired human');
  TestKit.Check(not Person('TYRANITHRAXUS', C_Race.MONSTER, 3, $84), 'but not Tyranthraxus the dragon');
  TestKit.Check(not Person('OGRE LEADER', C_Race.MONSTER, 0, $81), 'nor the ogre leader, Large');
  TestKit.Check(not Person('BUGBEAR', C_Race.MONSTER, 1, $81), 'nor a bugbear');
  TestKit.Check(not Person('OGRE', C_Race.MONSTER, 1, $82), 'nor an ogre');
  TestKit.Check(not Person('DRIDER', C_Race.ELF, 16, $83), 'nor a drider, though its race byte is elf');
  TestKit.Check(not Person('HIPPOGRIFF', C_Race.MONSTER, 0, $83), 'nor a hippogriff');
  TestKit.Check(not Person('MUTANT LIZ-MAN ', C_Race.MONSTER, 11, $01), 'nor the mutant lizard man');
  TestKit.Check(not Person('DRYTHH', C_Race.MONSTER, 11, $01), 'nor Drythh');
  TestKit.Check(not Person('MEDUSA', C_Race.MONSTER, 17, $01), 'nor a medusa');
  TestKit.Check(not Person('SPECTRE', C_Race.HUMAN, 4, $01), 'nor an undead human');
  TestKit.Check(not Person('GNOLL', C_Race.MONSTER, 4, $82), 'nor an undead gnoll');
end;

{ SSI's racial level cap tests, as CharHlp.AtLevelCap had them: true only at the levels named }
function SsiCap(race, cls, lvl, str: Integer): Boolean;
begin
  SsiCap := False;
  case race of
    C_Race.DWARF:
      SsiCap := (cls = C_LEVEL.FIGHTER) and (((lvl = 8) and (str = 17)) or ((lvl = 7) and (str < 17)));
    C_Race.ELF:
      SsiCap := (cls = C_LEVEL.FIGHTER) and ((lvl = 7) or ((lvl = 6) and (str = 17)) or ((lvl = 5) and (str < 17)));
    C_Race.GNOME:
      SsiCap := (cls = C_LEVEL.FIGHTER) and ((lvl = 6) or ((lvl = 5) and (str < 18)));
    C_Race.HALFELF:
      if (cls = C_LEVEL.CLERIC) and (lvl = 5) then
        SsiCap := True
      else
        SsiCap := ((cls = C_LEVEL.FIGHTER) or (cls = C_LEVEL.RANGER)) and
                  ((lvl = 8) or ((lvl = 7) and (str = 17)) or ((lvl = 6) and (str < 17)));
    C_Race.HALFLING:
      SsiCap := (cls = C_LEVEL.FIGHTER) and ((lvl = 6) or ((lvl = 5) and (str = 17)) or ((lvl = 4) and (str < 17)));
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
  CLASSES: array[1..3] of Integer = (C_LEVEL.FIGHTER, C_LEVEL.RANGER, C_LEVEL.CLERIC);
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
  NewItem(21, 0, C_ITEM.NAME_PLUS_BASE + 1, 21, 0, 20);
  CharHlp.ItemLabel(@it, False);
  TestKit.CheckEqualsS('Javelin +1 ', it.name, 'an identified javelin +1');
  CharHlp.ItemLabel(@it, True);
  TestKit.CheckEqualsS(' No   Javelin +1 ', it.name, 'an inventory line, not readied');
  it.equipped := 1;
  CharHlp.ItemLabel(@it, True);
  TestKit.CheckEqualsS(' Yes  Javelin +1 ', it.name, 'an inventory line, readied');
  NewItem(73, 0, C_ITEM.NAME_PLUS_BASE + 1, 61, 3, 1);
  CharHlp.ItemLabel(@it, False);
  TestKit.CheckEqualsS('3 Arrows +1 ', it.name, 'three arrows +1: the count, and the arrow pluralized');
  NewItem(21, 0, C_ITEM.NAME_PLUS_BASE + 1, 21, 0, 20);
  it.unidMask := 6;
  CharHlp.ItemLabel(@it, False);
  TestKit.CheckEqualsS('Javelin ', it.name, 'unidentified parts are left out');
  { Detect Magic on a party member marks a magic item }
  ClearCreature;
  FillChar(e, SizeOf(e), 0);
  e.id := C_EFFECT.DETECT_MAGIC;
  c^.effectsAddr := @e;
  GDVars.creatureList := c;
  NewItem(21, 0, C_ITEM.NAME_PLUS_BASE + 1, 21, 0, 20);
  it.plus := 1;
  CharHlp.ItemLabel(@it, False);
  TestKit.CheckEqualsS('* Javelin +1 ', it.name, 'Detect Magic marks a magic item');
  TestKit.Check(CharHlp.HasEffect(c, C_EFFECT.DETECT_MAGIC, found) and (found = @e), 'HasEffect finds the effect');
  TestKit.Check(not CharHlp.HasEffect(c, C_EFFECT.BLESS, found) and (found = nil), 'and not one it lacks');
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
  c^.coins[C_MONEY.GOLD] := 100;
  c^.coins[C_MONEY.GEMS] := 3;
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
  c^.classLevels[C_LEVEL.MAGE] := 5;
  c^.classLevels[C_LEVEL.FIGHTER] := 3;
  c^.classLevels[C_LEVEL.RANGER] := 4;
  TestKit.CheckEqualsL(4, CharHlp.WarriorLevel(c), 'the highest of fighter, paladin and ranger');
  c^.classLevels[C_LEVEL.FIGHTER] := -1;
  c^.classLevels[C_LEVEL.RANGER] := -1;
  TestKit.CheckEqualsL(0, CharHlp.WarriorLevel(c), 'a level below 0 counts as none');

  CheckPersons;

  { the NPC tests }
  ClearCreature;
  TestKit.Check(not CharHlp.IsNpc(c), 'a player character is not an NPC');
  TestKit.Check(CharHlp.MayTrade(c) and CharHlp.ComesUnderPlayer(c), 'it trades and comes under the player');
  c^.npc := C_NPC.FLAG;
  c^.enabled := 1;
  TestKit.Check(CharHlp.IsNpc(c), 'the NPC flag makes an NPC');
  TestKit.Check(not CharHlp.MayTrade(c) and not CharHlp.ComesUnderPlayer(c), 'which neither trades nor comes under');
  c^.enabled := 0;
  TestKit.Check(CharHlp.MayTrade(c), 'a disabled NPC can be traded with');
  ClearCreature;
  c^.status := C_STATUS.ANIMATED;
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
  c^.classLevels[C_LEVEL.FIGHTER] := 7;
  TestKit.Check(CharHlp.AtLevelCap(c, C_LEVEL.FIGHTER), 'an elf fighter stops at 7');
  c^.classLevels[C_LEVEL.FIGHTER] := 5;
  c^.strCur := 17;
  TestKit.Check(not CharHlp.AtLevelCap(c, C_LEVEL.FIGHTER), 'at 6 with Strength 17');
  c^.strCur := 16;
  TestKit.Check(CharHlp.AtLevelCap(c, C_LEVEL.FIGHTER), 'at 5 with Strength below 17');
  c^.race := C_Race.HUMAN;
  c^.classLevels[C_LEVEL.FIGHTER] := 8;
  TestKit.Check(not CharHlp.AtLevelCap(c, C_LEVEL.FIGHTER), 'a human has no cap here');
  c^.race := C_Race.HALFELF;
  c^.classLevels[C_LEVEL.CLERIC] := 5;
  TestKit.Check(CharHlp.AtLevelCap(c, C_LEVEL.CLERIC), 'a half-elf cleric stops at 5');

  CheckCapsMatchSsi;

  { the caps follow the character's own Strength, not magic's (#702): Gauntlets or Strength leave the restore value in
    the one Strength or Enlarge node not superseded }
  ClearCreature;
  c^.race := C_Race.GNOME;
  c^.classLevels[C_LEVEL.FIGHTER] := 5;
  c^.strCur := 18;
  c^.strExc := 100;
  FillChar(e, SizeOf(e), 0);
  e.id := C_EFFECT.STRENGTH;
  e.strength := AbilAdj.StrengthModifier(17, 0) + $80;
  c^.effectsAddr := @e;
  TestKit.CheckEqualsL(18, CharHlp.PermanentStrength(c), 'a superseded node holds no restore value');
  e.strength := AbilAdj.StrengthModifier(17, 0);
  TestKit.CheckEqualsL(17, CharHlp.PermanentStrength(c), 'the active node holds the own Strength');
  TestKit.Check(CharHlp.AtLevelCap(c, C_LEVEL.FIGHTER), 'a gnome fighter with Strength 17 in gauntlets stops at 5');
  e.id := C_EFFECT.ENLARGE;
  e.strength := AbilAdj.StrengthModifier(18, 50);
  TestKit.CheckEqualsL(18, CharHlp.PermanentStrength(c), 'Enlarge''s restore value, 18/50');
  TestKit.Check(not CharHlp.AtLevelCap(c, C_LEVEL.FIGHTER), 'and with 18 of its own the gnome trains past 5');
  c^.effectsAddr := nil;
  c^.race := C_Race.DWARF;
  c^.classLevels[C_LEVEL.FIGHTER] := 8;
  c^.strCur := 15;
  TestKit.Check(CharHlp.AtLevelCap(c, C_LEVEL.FIGHTER), 'a dwarf fighter 8 whose Strength fell below 17 stays capped');
  { under Enlarge the stored Strength is whole, and a disease's loss (#705) still counts against the cap }
  FillChar(d, SizeOf(d), 0);
  d.id := C_EFFECT.DISEASE_STR;
  d.strength := 2 * 16 + 5;
  e.id := C_EFFECT.ENLARGE;
  e.strength := AbilAdj.StrengthModifier(18, 50);
  e.next := @d;
  c^.effectsAddr := @e;
  c^.strCur := 17;
  TestKit.CheckEqualsL(2, CharHlp.DiseaseStrLoss(c), 'the disease has taken 2');
  TestKit.CheckEqualsL(16, CharHlp.PermanentStrength(c), 'Enlarge''s 18/50 less the 2 the disease took');
  TestKit.Check(CharHlp.AtLevelCap(c, C_LEVEL.FIGHTER), 'so the diseased dwarf fighter 8 stays capped');
  c^.effectsAddr := nil;
  { Haste doubles, Slow halves, and the two cancel (#778) }
  FillChar(e, SizeOf(e), 0);
  FillChar(d, SizeOf(d), 0);
  TestKit.CheckEqualsL(12, CharHlp.HasteSlowRate(c, 12), 'neither leaves the rate');
  e.id := C_EFFECT.HASTED;
  c^.effectsAddr := @e;
  TestKit.CheckEqualsL(24, CharHlp.HasteSlowRate(c, 12), 'Haste doubles it');
  TestKit.CheckEqualsL(255, CharHlp.HasteSlowRate(c, 192), 'to at most 255');
  d.id := C_EFFECT.SLOWED;
  e.next := @d;
  TestKit.CheckEqualsL(13, CharHlp.HasteSlowRate(c, 13), 'Haste and Slow cancel');
  c^.effectsAddr := @d;
  TestKit.CheckEqualsL(6, CharHlp.HasteSlowRate(c, 13), 'Slow halves it');
  c^.effectsAddr := nil;

  FreeMem(c, SizeOf(Types.TCharRecord));
  { a robbery's chance per item (POR-0163): each item's weight penalty comes off the robbery's chance, not the last }
  TestKit.CheckEqualsL(70, CharHlp.TheftChance(70, 24), 'a light item keeps the chance');
  TestKit.CheckEqualsL(20, CharHlp.TheftChance(70, 25), 'over 24 coins, 50 less');
  TestKit.CheckEqualsL(0, CharHlp.TheftChance(70, 256), 'over 255 coins, 90 less, not below 0');
  TestKit.CheckEqualsL(5, CharHlp.TheftChance(95, 300), '95 less 90');
  TestKit.CheckEqualsL(70, CharHlp.TheftChance(70, 10), 'and the next light item has the whole chance again');

  { CountTeams counts each creature in action on team hostile and 1, as CombatSt places it: teamCount has only entries 0
    and 1, and a damaged byte of 2 or 3 once counted past them (#710) }
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

  { FixWeaponClasses (#746) over the shipped ITEMS file's damage types for the weapons it changes and a few it keeps }
  New(items);
  FillChar(items^, SizeOf(items^), 0);
  items^[C_ITEM.BATTLE_AXE].wpnClass := C_ITEM.WPN_PIERCE;
  items^[C_ITEM.CLUB].wpnClass := C_ITEM.WPN_BASH;
  items^[C_ITEM.DAGGER].wpnClass := C_ITEM.WPN_PIERCE;
  CharHlp.FixWeaponClasses(items);
  TestKit.CheckEqualsL(C_ITEM.WPN_SLASH, items^[C_ITEM.BATTLE_AXE].wpnClass, 'a battle axe slashes');
  TestKit.CheckEqualsL(C_ITEM.WPN_PIERCE, items^[C_ITEM.BEC_DE_CORBIN].wpnClass, 'a bec de corbin pierces');
  TestKit.CheckEqualsL(C_ITEM.WPN_PIERCE, items^[C_ITEM.TRIDENT].wpnClass, 'a trident pierces');
  TestKit.CheckEqualsL(C_ITEM.WPN_PIERCE, items^[C_ITEM.SHORT_SWORD].wpnClass, 'a short sword pierces');
  TestKit.CheckEqualsL(C_ITEM.WPN_PIERCE, items^[C_ITEM.ARROW].wpnClass, 'an arrow pierces');
  TestKit.CheckEqualsL(C_ITEM.WPN_SLASH, items^[C_ITEM.LONG_SWORD].wpnClass, 'a long sword still slashes');
  TestKit.CheckEqualsL(C_ITEM.WPN_BASH, items^[C_ITEM.CLUB].wpnClass, 'a club still bashes');
  TestKit.CheckEqualsL(C_ITEM.WPN_PIERCE, items^[C_ITEM.DAGGER].wpnClass, 'a dagger still pierces');
  { FixAmmoBits (#793) over the shipped rows: the bill-guisarme loses its arrows bit, launchers keep theirs }
  items^[C_ITEM.BILL_GUISARME].props := C_ITEM.PROP_ARROWS;
  items^[C_ITEM.LONG_BOW].props := C_ITEM.PROP_ARROWS or C_ITEM.PROP_DEX_MISSILE or C_ITEM.PROP_FIRES_AMMO;
  items^[C_ITEM.QUARREL].props := C_ITEM.PROP_QUARRELS or C_ITEM.PROP_DEX_MISSILE or C_ITEM.PROP_FIRES_AMMO;
  items^[C_ITEM.DAGGER].props := C_ITEM.PROP_THROWN or C_ITEM.PROP_STR_BONUS;
  CharHlp.FixAmmoBits(items);
  TestKit.CheckEqualsL(0, items^[C_ITEM.BILL_GUISARME].props, 'a bill-guisarme takes no arrows');
  TestKit.CheckEqualsL($0B, items^[C_ITEM.LONG_BOW].props, 'a long bow still shoots arrows');
  TestKit.CheckEqualsL($8A, items^[C_ITEM.QUARREL].props, 'a quarrel keeps its bits');
  TestKit.CheckEqualsL($14, items^[C_ITEM.DAGGER].props, 'a dagger is still thrown');
  { the javelin (#798) is thrown or melee; holy water stays thrown only }
  items^[C_ITEM.JAVELIN].props := C_ITEM.PROP_THROWN or C_ITEM.PROP_FIRES_AMMO or C_ITEM.PROP_DEX_MISSILE;
  items^[C_ITEM.HOLY_WATER_VIAL].props := C_ITEM.PROP_THROWN or C_ITEM.PROP_FIRES_AMMO or C_ITEM.PROP_DEX_MISSILE;
  CharHlp.FixAmmoBits(items);
  TestKit.CheckEqualsL($16, items^[C_ITEM.JAVELIN].props, 'a javelin is throwable, not a launcher');
  TestKit.CheckEqualsL($1A, items^[C_ITEM.HOLY_WATER_VIAL].props, 'holy water is still thrown only');
  Dispose(items);
  { the rear AC loses a Dexterity bonus but keeps a penalty (#741); unarmored, AC 10 (50) and 2 worse from behind }
  FillChar(crs[1], SizeOf(crs[1]), 0);
  crs[1].race := C_Race.HUMAN;
  crs[1].strCur := 10;
  crs[1].acBase := 50;
  crs[1].dexCur := 3;
  CharHlp.RecalcStats(@crs[1]);
  TestKit.CheckEqualsL(46, crs[1].acCur, 'Dexterity 3 makes AC 10 into AC 14');
  TestKit.CheckEqualsL(44, crs[1].acBehind, 'and AC 16 from behind');
  crs[1].dexCur := 18;
  CharHlp.RecalcStats(@crs[1]);
  TestKit.CheckEqualsL(54, crs[1].acCur, 'Dexterity 18 makes AC 10 into AC 6');
  TestKit.CheckEqualsL(48, crs[1].acBehind, 'and AC 12 from behind, without the bonus');

  { a bow's plus is to hit only, its arrows' to hit and damage (#744); a sword's is to both }
  GetMem(GDVars.baseItems, SizeOf(GDVars.baseItems^));
  FillChar(GDVars.baseItems^, SizeOf(GDVars.baseItems^), 0);
  GDVars.baseItems^[C_ITEM.LONG_BOW].props := C_ITEM.PROP_ARROWS or C_ITEM.PROP_DEX_MISSILE or C_ITEM.PROP_FIRES_AMMO;
  GDVars.baseItems^[C_ITEM.ARROW].slot := C_EQUIP.RING2;
  GDVars.baseItems^[C_ITEM.LONG_SWORD].props := C_ITEM.PROP_STR_BONUS;
  FillChar(weapon, SizeOf(weapon), 0);
  FillChar(arrows, SizeOf(arrows), 0);
  weapon.itemType := C_ITEM.LONG_BOW;
  weapon.plus := 2;
  weapon.equipped := 1;
  weapon.next := @arrows;
  arrows.itemType := C_ITEM.ARROW;
  arrows.plus := 1;
  arrows.quantity := 10;
  arrows.equipped := 1;
  crs[1].dexCur := 10;
  crs[1].thac0Base := 40;
  crs[1].itemsAddr := @weapon;
  CharHlp.RecalcStats(@crs[1]);
  TestKit.CheckEqualsL(43, crs[1].thac0Cur, 'a bow +2 with arrows +1 is +3 to hit');
  TestKit.CheckEqualsL(1, crs[1].curModA[1], 'and +1 to damage');
  weapon.itemType := C_ITEM.LONG_SWORD;
  CharHlp.RecalcStats(@crs[1]);
  TestKit.CheckEqualsL(42, crs[1].thac0Cur, 'a sword +2 is +2 to hit');
  TestKit.CheckEqualsL(2, crs[1].curModA[1], 'and +2 to damage');
  crs[1].itemsAddr := nil;
  FreeMem(GDVars.baseItems, SizeOf(GDVars.baseItems^));
  TestKit.Done;
end.

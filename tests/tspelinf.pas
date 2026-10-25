{ Tests for the spell information on the spell lists (#839): SpellInf's summary line at set caster levels (Bless at
  level 1, Hold Person at level 5, Fireball from a scroll, touch, camp-only and aura spells, Cause Disease's rolled
  duration), the page's figures, CharHlp.SpellArea's shapes and SpellDuration's dice, every summary within the list's
  38 columns and every page value within its 24, and every description within the page's 9 lines of 36 columns; the
  item spells Use casts (#861): CharHlp.ItemSpell, which items have a page, and their figures and caster levels. }
{$I COMPILER.INC}
program TSpelInf;

uses Types, GameVars, C_LEVEL, C_SPELL, C_IFC, C_ITEM, GameDefs, CharHlp, SpellInf, SpellTxt, TestKit;

const
  { the test's base item types: a magic-user's scroll, and a wand }
  SCROLL_TYPE = 1;
  WAND_TYPE = 2;

var
  c: Types.PCharRecord;
  spell: Byte;
  lvl: Byte;
  n: Byte;
  item: Byte;
  view: Byte;
  size: Byte;
  d: Types.TDurDice;
  fits: Boolean;
  texts: Boolean;
  rolled: Boolean;
  line: Types.TStr40;
  it: Types.PItemRec;

{ Make the test item a wand (or a scroll) with effect and special, identified or not. }
procedure SetItem(itemType, effect, special, unidMask: Byte);
begin
  FillChar(it^, SizeOf(Types.TItemRec), 0);
  it^.itemType := itemType;
  it^.effect := effect;
  it^.special := special;
  it^.unidMask := unidMask;
end;

{ Make the test character a cleric and magic-user of level l. }
procedure SetLevel(l: Byte);
begin
  c^.classLevels[C_LEVEL.CLERIC] := l;
  c^.classLevels[C_LEVEL.MAGE] := l;
end;

begin
  TestKit.Start('TSPELINF');
  GetMem(c, SizeOf(Types.TCharRecord));
  FillChar(c^, SizeOf(Types.TCharRecord), 0);
  c^.name := 'GIN';
  GameVars.curChar := c;
  GetMem(GameVars.zone0, SizeOf(GameVars.zone0^));
  FillChar(GameVars.zone0^, SizeOf(GameVars.zone0^), 0);
  GameVars.zone0^.view3dFlag := 1;
  GameVars.usingItem := False;
  GameVars.ifcState := C_IFC.CAMPING;

  { the summary line }
  SetLevel(1);
  TestKit.CheckEqualsS('RNG 6  AREA R2  DUR 6 RD', SpellInf.Summary(C_SPELL.BLESS), 'Bless at level 1');
  SetLevel(5);
  TestKit.CheckEqualsS('RNG 6 TGT 1-3 DUR 9 RD SAVE NEG CBT', SpellInf.Summary(C_SPELL.HOLD_PERSON),
                       'Hold Person at level 5, one blank apart');
  TestKit.CheckEqualsS('RNG 16 AREA R3 DUR INST SAVE 1/2 CBT', SpellInf.Summary(C_SPELL.FIREBALL or C_SPELL.FROM_ITEM),
                       'Fireball from a scroll, at caster level 6');
  TestKit.Check(not GameVars.usingItem, 'usingItem is put back');
  TestKit.CheckEqualsS('RNG 15 AREA R3 DUR INST SAVE 1/2 CBT', SpellInf.Summary(C_SPELL.FIREBALL),
                       'Fireball at level 5');
  GameVars.zone0^.view3dFlag := 0;
  TestKit.CheckEqualsS('AREA R2', SpellInf.AreaText(C_SPELL.FIREBALL, False), 'Fireball outdoors: radius 2');
  GameVars.zone0^.view3dFlag := 1;
  TestKit.CheckEqualsS('RNG TOUCH  DUR INST', SpellInf.Summary(C_SPELL.CURE_LIGHT_WOUNDS), 'a touch spell');
  TestKit.CheckEqualsS('RNG TOUCH  DUR INST  CBT', SpellInf.Summary(20), 'Shocking Grasp: touch, needing a hit');
  SetLevel(3);
  TestKit.CheckEqualsS('DUR 3 HR  CAMP', SpellInf.Summary(35), 'Strength: a camp-only spell at level 3');
  TestKit.CheckEqualsS('RNG SELF  DUR 6 RD  CAMP', SpellInf.Summary(18), 'Read Magic: camp only, on the caster');
  TestKit.CheckEqualsS('RNG TOUCH  DUR 1D6 TU  SAVE NEG  CBT', SpellInf.Summary(40), 'Cause Disease''s rolled onset');
  TestKit.CheckEqualsS('RNG SELF  DUR 1 TU', SpellInf.Summary(5), 'the cleric''s Detect Magic: one turn');
  SetLevel(4);
  TestKit.CheckEqualsS('RNG 3 AREA 2x2 DUR 4 RD SAVE PART CBT', SpellInf.Summary(C_SPELL.STINKING_CLOUD),
                       'Stinking Cloud');
  SetLevel(5);
  TestKit.CheckEqualsS('RNG 9 AREA BOLT DUR INST SAVE 1/2 CBT', SpellInf.Summary(C_SPELL.LIGHTNING_BOLT),
                       'Lightning Bolt');
  TestKit.CheckEqualsS('RNG SELF  AREA R6  DUR 5 RD', SpellInf.Summary(42), 'Prayer: an aura of 6');
  TestKit.CheckEqualsS('RNG 12 AREA R1 DUR 10 RD SAVE NEG CBT', SpellInf.Summary(25), 'Silence: an aura of 1');
  TestKit.CheckEqualsS('AREA ALL  DUR PERM  CBT', SpellInf.Summary(27), 'Snake Charm: not aimed, lasts the fight');
  TestKit.CheckEqualsS('RNG 12  DUR PERM  SAVE NEG  CBT', SpellInf.Summary(C_SPELL.CHARM_PERSON), 'Charm Person');
  TestKit.CheckEqualsS('DUR INST  DOORS', SpellInf.Summary(C_SPELL.KNOCK), 'Knock');

  { the page's figures }
  TestKit.CheckEqualsS('TOUCH', SpellInf.RangeText(C_SPELL.CURE_LIGHT_WOUNDS, True), 'touch range');
  TestKit.CheckEqualsS('6 SQUARES', SpellInf.RangeText(C_SPELL.BLESS, True), 'Bless''s range');
  TestKit.CheckEqualsS('BOLT, 8 SQUARES PAST AIM', SpellInf.AreaText(C_SPELL.LIGHTNING_BOLT, True), 'the bolt');
  TestKit.CheckEqualsS('UP TO 3 CREATURES', SpellInf.AreaText(C_SPELL.HOLD_PERSON, True), 'Hold Person''s targets');
  TestKit.CheckEqualsS('RADIUS 1 AROUND TARGET', SpellInf.AreaText(25, True), 'Silence''s aura');
  TestKit.CheckEqualsS('RADIUS 2 SQUARES', SpellInf.AreaText(48, True), 'Haste''s area');
  TestKit.CheckEqualsS('1 CHARACTER', SpellInf.AreaText(35, True), 'Strength, cast in camp on one character');
  TestKit.CheckEqualsS('9 ROUNDS', SpellInf.DurationText(C_SPELL.HOLD_PERSON, True), 'Hold Person''s duration');
  SetLevel(6);
  TestKit.CheckEqualsS('DUR 10 RD', SpellInf.DurationText(C_SPELL.HOLD_PERSON, False), 'still rounds at 10 rounds');
  TestKit.CheckEqualsS('6 TURNS', SpellInf.DurationText(12, True), 'Enlarge: a turn a level');
  TestKit.CheckEqualsS('DUR 6 HR', SpellInf.DurationText(26, False), 'Slow Poison: an hour a level');
  SetLevel(5);
  TestKit.CheckEqualsS('1D6 TURNS', SpellInf.DurationText(40, True), 'Cause Disease''s duration');
  TestKit.CheckEqualsS('LESSENS (VS PARALYSIS)', SpellInf.SaveText(C_SPELL.STINKING_CLOUD, True),
                       'Stinking Cloud''s save');
  TestKit.CheckEqualsS('HALVES DAMAGE (VS SPELL)', SpellInf.SaveText(C_SPELL.FIREBALL, True), 'Fireball''s save');
  TestKit.CheckEqualsS('NONE', SpellInf.SaveText(C_SPELL.BLESS, True), 'Bless has no save');
  TestKit.CheckEqualsS('IN CAMP OR COMBAT', SpellInf.WhenText(C_SPELL.BLESS, True), 'Bless, either');
  TestKit.CheckEqualsS('LATER: -3 INITIATIVE', SpellInf.CastTimeText(C_SPELL.BLESS), 'Bless''s casting time');
  TestKit.CheckEqualsS('AT ONCE', SpellInf.CastTimeText(C_SPELL.MAGIC_MISSILE), 'Magic Missile''s casting time');
  TestKit.CheckEqualsS('AT ONCE', SpellInf.CastTimeText(C_SPELL.BLESS or C_SPELL.FROM_ITEM),
                       'Bless from a scroll: Use casts it on the spot');
  TestKit.CheckEqualsS('', SpellInf.CastTimeText(35), 'a camp-only spell has none');

  { the shapes and durations shared with combat }
  TestKit.CheckEqualsL(C_SPELL.AREA_BOLT, CharHlp.SpellArea(C_SPELL.LIGHTNING_BOLT, size), 'Lightning Bolt: a bolt');
  TestKit.CheckEqualsL(C_SPELL.LIGHTNING_BOLT_CELLS, size, 'the bolt''s length');
  TestKit.CheckEqualsL(C_SPELL.AREA_CLOUD, CharHlp.SpellArea(C_SPELL.STINKING_CLOUD, size), 'Stinking Cloud: a cloud');
  TestKit.CheckEqualsL(C_SPELL.AREA_TARGETS, CharHlp.SpellArea(49, size), 'Hold Person (magic-user): targets');
  TestKit.CheckEqualsL(4, size, 'up to 4');
  TestKit.CheckEqualsL(C_SPELL.AREA_SPOT, CharHlp.SpellArea(25, size), 'Silence: one creature or square');
  TestKit.CheckEqualsL(C_SPELL.AREA_RADIUS, CharHlp.SpellArea(21, size), 'Sleep: a radius');
  TestKit.CheckEqualsL(1, size, 'of 1');
  TestKit.CheckEqualsL(C_SPELL.AREA_SELF, CharHlp.SpellArea(36, size), 'Animate Dead: not aimed');
  CharHlp.SpellDuration(59, d);
  TestKit.Check((d.count = 1) and (d.sides = 4) and (d.add = 4) and (d.mult = 10), 'Giant Strength: 1d4 + 4 turns');
  CharHlp.SpellDuration(C_SPELL.BLESS, d);
  TestKit.Check((d.count = 0) and (d.add = 6) and (d.mult = 1), 'Bless: 6 rounds, rolled by none');

  { the item spells (#861) }
  GetMem(CharHlp.baseItems, SizeOf(CharHlp.baseItems^));
  FillChar(CharHlp.baseItems^, SizeOf(CharHlp.baseItems^), 0);
  CharHlp.baseItems^[SCROLL_TYPE].slot := C_ITEM.SLOT_MAGE_SCROLL;
  GetMem(it, SizeOf(Types.TItemRec));
  SetItem(WAND_TYPE, 84, 0, 0);
  TestKit.CheckEqualsL(61, CharHlp.ItemSpell(it), 'item effect 84: the Wand of Paralyzation''s spell 61');
  TestKit.Check(SpellInf.HasItemPage(it), 'an identified Wand of Paralyzation has a page');
  SetItem(WAND_TYPE, 84, 0, 4);
  TestKit.Check(not SpellInf.HasItemPage(it), 'an unidentified one has none: it would tell what Id does');
  SetItem(WAND_TYPE, C_SPELL.FIREBALL, 0, 0);
  TestKit.CheckEqualsL(C_SPELL.FIREBALL, CharHlp.ItemSpell(it), 'the Wand of Fireballs casts Fireball');
  TestKit.Check(SpellInf.HasItemPage(it), 'and has its page');
  SetItem(WAND_TYPE, 89, 0, 0);
  TestKit.CheckEqualsL(66, CharHlp.ItemSpell(it), 'effect 89: the unused spell 66');
  TestKit.Check(not SpellInf.HasItemPage(it), 'which has no page');
  SetItem(WAND_TYPE, 89, 133, 0);
  TestKit.CheckEqualsL(C_SPELL.NONE, CharHlp.ItemSpell(it), 'readying applies a special of $80 and up: no spell');
  SetItem(WAND_TYPE, 91, 0, 0);
  TestKit.CheckEqualsL(C_SPELL.NONE, CharHlp.ItemSpell(it), 'an effect past the spell table: no spell');
  SetItem(WAND_TYPE, 0, 0, 0);
  TestKit.CheckEqualsL(C_SPELL.NONE, CharHlp.ItemSpell(it), 'no effect: no spell');
  SetItem(SCROLL_TYPE, 84, 0, 0);
  TestKit.CheckEqualsL(C_SPELL.NONE, CharHlp.ItemSpell(it), 'a scroll''s spells come from its list');
  TestKit.Check(not SpellInf.HasItemPage(it), 'and it has no item page');
  FreeMem(it, SizeOf(Types.TItemRec));
  FreeMem(CharHlp.baseItems, SizeOf(CharHlp.baseItems^));
  TestKit.CheckEqualsS('RNG 6  DUR 5D4 RD  SAVE NEG  CBT', SpellInf.Summary(61 or C_SPELL.FROM_ITEM),
                       'the Wand of Paralyzation');
  TestKit.CheckEqualsS('RNG 28 AREA BOLT DUR INST SAVE 1/2 CBT',
                       SpellInf.Summary(C_SPELL.ITEM_JAVELIN_LIGHTNING or C_SPELL.FROM_ITEM),
                       'the Javelin of Lightning: range at the item caster level 6');
  TestKit.CheckEqualsS('BOLT, 3 SQUARES PAST AIM',
                       SpellInf.AreaText(C_SPELL.ITEM_JAVELIN_LIGHTNING or C_SPELL.FROM_ITEM, True),
                       'the javelin''s bolt');
  TestKit.CheckEqualsS('BOLT, 3 SQUARES PAST AIM',
                       SpellInf.ItemAreaText(C_SPELL.ITEM_JAVELIN_LIGHTNING or C_SPELL.FROM_ITEM),
                       'the javelin''s bolt on its item page');
  TestKit.CheckEqualsS('THE CASTER', SpellInf.AreaText(59 or C_SPELL.FROM_ITEM, True), 'a potion''s area');
  TestKit.CheckEqualsS('USER', SpellInf.ItemAreaText(59 or C_SPELL.FROM_ITEM), 'reads USER on its item page');
  TestKit.CheckEqualsS('NEGATES (VS PARALYSIS)', SpellInf.SaveText(61, True), 'the Wand of Paralyzation''s save');
  TestKit.CheckEqualsS('RNG TOUCH  TGT 1-4  DUR 1D10+10 TU', SpellInf.Summary(63 or C_SPELL.FROM_ITEM),
                       'Dust of Disappearance in camp');
  GameVars.ifcState := C_IFC.COMBAT;
  TestKit.CheckEqualsS('2D10 TURNS', SpellInf.DurationText(63 or C_SPELL.FROM_ITEM, True), 'and in combat');
  GameVars.ifcState := C_IFC.CAMPING;
  TestKit.CheckEqualsS('RNG SELF  DUR 24 HR  CAMP', SpellInf.Summary(67 or C_SPELL.FROM_ITEM),
                       'the Manual of Bodily Health: a day''s study');
  TestKit.CheckEqualsS('HALVES DAMAGE (VS SPELL)', SpellInf.SaveText(C_SPELL.ITEM_FIREBALL, True),
                       'the item fireball''s save');
  TestKit.CheckEqualsS('3, 5 OR 7', SpellInf.CasterLevelText(C_SPELL.ITEM_FIREBALL or C_SPELL.FROM_ITEM),
                       'the item fireball''s rolled caster level');
  TestKit.CheckEqualsS('12', SpellInf.CasterLevelText(57 or C_SPELL.FROM_ITEM), 'an item spell''s caster level');
  TestKit.CheckEqualsS('6', SpellInf.CasterLevelText(C_SPELL.FIREBALL or C_SPELL.FROM_ITEM),
                       'a spell cast from an item: level 6');
  TestKit.CheckEqualsS('5', SpellInf.CasterLevelText(C_SPELL.FIREBALL), 'and from memory, the caster''s');

  { every list line fits, at every level, from memory and from a scroll or item, indoors and out; the save table rolls
    where the spell table does (Reduce's handler rolls its own) }
  fits := True;
  rolled := True;
  for spell := 1 to C_SPELL.TABLE_LAST do begin
    if (spell <> 13) and
       ((SpellInf.SaveResult(spell) <> C_SPELL.SAVE_NONE) <> (GameDefs.spellTable[spell].saveResult <> 0)) then
      rolled := False;
    for lvl := 1 to 12 do
      for item := 0 to 1 do
        for view := 0 to 1 do begin
          SetLevel(lvl);
          GameVars.zone0^.view3dFlag := view;
          n := spell or (item * C_SPELL.FROM_ITEM);
          if Length(SpellInf.Summary(n)) > SpellInf.SUMMARY_WIDTH then
            fits := False;
          if (Length(SpellInf.RangeText(n, True)) > SpellInf.VALUE_WIDTH) or
             (Length(SpellInf.AreaText(n, True)) > SpellInf.VALUE_WIDTH) or
             (Length(SpellInf.DurationText(n, True)) > SpellInf.VALUE_WIDTH) or
             (Length(SpellInf.SaveText(n, True)) > SpellInf.VALUE_WIDTH) or
             (Length(SpellInf.WhenText(n, True)) > SpellInf.VALUE_WIDTH) or
             (Length(SpellInf.CastTimeText(n)) > SpellInf.VALUE_WIDTH) or
             (Length('MAGIC ITEM, CASTER LEVEL ' + SpellInf.CasterLevelText(n)) > 38) then
            fits := False;
          if Length(SpellInf.Summary(n)) > SpellInf.SUMMARY_WIDTH then
            TestKit.Check(False, 'too long: ' + SpellInf.Summary(n));
        end;
  end;
  TestKit.Check(fits, 'every summary within 38 columns and every page value within 24');
  TestKit.Check(rolled, 'the save table rolls a save where the spell table does');

  { every description fits the page; the unused item spell 66 has none }
  texts := True;
  for spell := 1 to C_SPELL.TABLE_LAST do begin
    if ((SpellTxt.LineCount(spell) < 1) and (spell <> 66)) or (SpellTxt.LineCount(spell) > SpellInf.TEXT_LINES) then
      texts := False;
    for n := 1 to SpellTxt.LineCount(spell) do begin
      line := SpellInf.TextLine(spell, n);
      if (line = '') or (Length(line) > SpellInf.TEXT_COLS) then
        texts := False;
    end;
    if SpellInf.TextLine(spell, SpellTxt.LineCount(spell) + 1) <> '' then
      texts := False;
  end;
  TestKit.Check(texts, 'every description within 9 lines of 36 columns');
  TestKit.CheckEqualsS('A CLOUD FILLS FOUR SQUARES. A', SpellInf.TextLine(C_SPELL.STINKING_CLOUD, 1),
                       'Stinking Cloud''s first line');
  TestKit.CheckEqualsL(0, SpellTxt.LineCount(66), 'no text for the unused item spell');
  TestKit.CheckEqualsS('THE DRINKER MOVES AND ATTACKS AT', SpellInf.TextLine(57, 1),
                       'the Potion of Speed''s first line');
  TestKit.Done;
end.

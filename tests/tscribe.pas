{ Tests for Magic.RemoveSpellFromScroll, which clears the slot holding the spell exactly, its pending flag included,
  before another copy: a scribed spell takes its own slot and a used one a copy not queued (POR-0228); and for the
  spell lists' lines the magic shop's scroll shares (#1196): Magic.SpellLine's indent and marker, and
  Magic.LevelHeading; and the spell lists' level order (#1199): each level's heading once, its spells under it, though
  the magic-user's Bestow Curse (100) has an id past the 5th level's. }
{$I COMPILER.INC}
program TScribe;

uses Types, C_LEVEL, C_SPELL, GameDefs, CharHlp, Magic, TestKit;

const
  SP_A = 9;
  SP_B = 10;

var
  item: Types.TItemRec;
  c: Types.TCharRecord;
  name: Types.TStr40;
  id: Byte;

{ A scroll of three spells holding a, b and c. }
procedure Scroll(a, b, c: Byte);
begin
  FillChar(item, SizeOf(item), 0);
  item.nameIds[2] := 213;
  item.spells[1] := a;
  item.spells[2] := b;
  item.spells[3] := c;
end;

begin
  TestKit.Start('TSCRIBE');
  Scroll(SP_A + C_SPELL.PENDING_FLAG, SP_A, SP_B);
  Magic.RemoveSpellFromScroll(nil, @item, SP_A + C_SPELL.PENDING_FLAG);
  TestKit.CheckEqualsL(0, item.spells[1], 'a scribed spell clears its own slot (POR-0228)');
  TestKit.CheckEqualsL(SP_A, item.spells[2], 'not the other copy');
  TestKit.CheckEqualsL(212, item.nameIds[2], 'and the scroll counts one spell fewer');
  Scroll(SP_A, SP_A + C_SPELL.PENDING_FLAG, SP_B);
  Magic.RemoveSpellFromScroll(nil, @item, SP_A);
  TestKit.CheckEqualsL(0, item.spells[1], 'a used spell clears a copy not queued');
  TestKit.CheckEqualsL(SP_A + C_SPELL.PENDING_FLAG, item.spells[2], 'leaving the queued one');
  Scroll(SP_B, SP_A + C_SPELL.PENDING_FLAG, 0);
  Magic.RemoveSpellFromScroll(nil, @item, SP_A);
  TestKit.CheckEqualsL(0, item.spells[2], 'with no other copy, the queued one goes');
  Scroll(SP_A, SP_B, SP_A);
  Magic.RemoveSpellFromScroll(nil, @item, SP_A);
  TestKit.Check((item.spells[1] = SP_A) and (item.spells[3] = 0), 'of two plain copies, the last goes, as before');

  { a 3rd-level magic-user, who could learn Magic Missile }
  FillChar(c, SizeOf(c), 0);
  c.classLevels[C_LEVEL.MAGE] := 3;
  name := GameDefs.spellNames[C_SPELL.MAGIC_MISSILE];
  TestKit.CheckEqualsS('  +' + name, Magic.SpellLine(@c, C_SPELL.MAGIC_MISSILE, Magic.MARK_NOT_KNOWN),
                       'a spell the buyer could learn and lacks is marked + (#1196)');
  CharHlp.SetSpellKnown(@c, C_SPELL.MAGIC_MISSILE, True);
  TestKit.CheckEqualsS('   ' + name, Magic.SpellLine(@c, C_SPELL.MAGIC_MISSILE, Magic.MARK_NOT_KNOWN),
                       'a known one is not');
  TestKit.CheckEqualsS('  -' + name, Magic.SpellLine(@c, C_SPELL.MAGIC_MISSILE, Magic.MARK_KNOWN),
                       'the scribe list marks a known one -');
  FillChar(c, SizeOf(c), 0);
  c.classLevels[C_LEVEL.FIGHTER] := 3;
  TestKit.CheckEqualsS('   ' + name, Magic.SpellLine(@c, C_SPELL.MAGIC_MISSILE, Magic.MARK_NOT_KNOWN),
                       'a fighter, who can''t learn it, sees no mark');
  TestKit.CheckEqualsS('  *' + name,
                       Magic.SpellLine(@c, C_SPELL.MAGIC_MISSILE + C_SPELL.PENDING_FLAG, Magic.MARK_NOT_KNOWN),
                       'a pending spell is marked *');
  TestKit.CheckEqualsS('2nd Level', Magic.LevelHeading(2), 'the 2nd level''s heading');
  TestKit.CheckEqualsS('', Magic.LevelHeading(0), 'no heading for level 0');

  { a 9th-level magic-user who knows Magic Missile, Fireball, the 5th level's five and Bestow Curse }
  FillChar(c, SizeOf(c), 0);
  c.classLevels[C_LEVEL.MAGE] := 9;
  CharHlp.SetSpellKnown(@c, C_SPELL.MAGIC_MISSILE, True);
  CharHlp.SetSpellKnown(@c, C_SPELL.FIREBALL, True);
  for id := C_SPELL.ANIMATE_DEAD_MU to C_SPELL.HOLD_MONSTERS do
    CharHlp.SetSpellKnown(@c, id, True);
  CharHlp.SetSpellKnown(@c, C_SPELL.BESTOW_CURSE_MU, True);
  TestKit.Check(Magic.GenerateSpellList(@c, 1), 'the spell book lists them');
  TestKit.CheckEqualsS('1st Level', Magic.SpellListLine(0), 'the 1st level first');
  TestKit.CheckEqualsS('   ' + name, Magic.SpellListLine(1), 'with Magic Missile');
  TestKit.CheckEqualsS('3rd Level', Magic.SpellListLine(2), 'then the 3rd');
  TestKit.CheckEqualsS('4th Level', Magic.SpellListLine(4), 'then the 4th, before the 5th (#1199)');
  TestKit.CheckEqualsS('   ' + GameDefs.spellNames[C_SPELL.BESTOW_CURSE_MU], Magic.SpellListLine(5),
                       'with Bestow Curse under it');
  TestKit.CheckEqualsS('5th Level', Magic.SpellListLine(6), 'then the 5th');
  TestKit.CheckEqualsS('   ' + GameDefs.spellNames[C_SPELL.HOLD_MONSTERS], Magic.SpellListLine(11),
                       'its five spells in id order');
  TestKit.CheckEqualsS('', Magic.SpellListLine(12), 'and no second 4th-level heading after them');
  { the memorized spells, kept in id order (UsualSpl.SortMemorizedSpells), list by level too }
  CharHlp.SetMemorizedAt(@c, 0, C_SPELL.ANIMATE_DEAD_MU);
  CharHlp.SetMemorizedAt(@c, 1, C_SPELL.BESTOW_CURSE_MU);
  TestKit.Check(Magic.GenerateSpellList(@c, 0), 'the memorized spells list');
  TestKit.CheckEqualsS('4th Level', Magic.SpellListLine(0), 'Bestow Curse''s level first');
  TestKit.CheckEqualsS('5th Level', Magic.SpellListLine(2), 'Animate Dead''s after it');
  TestKit.CheckEqualsS('', Magic.SpellListLine(4), 'and nothing more');
  TestKit.Done;
end.

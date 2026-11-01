{ Tests for Magic.RemoveSpellFromScroll, which clears the slot holding the spell exactly, its pending flag included,
  before another copy: a scribed spell takes its own slot and a used one a copy not queued (POR-0228); and for the
  spell lists' lines the magic shop's scroll shares (#1196): Magic.SpellLine's indent and marker, and
  Magic.LevelHeading. }
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
  TestKit.Done;
end.

{ Tests for CbtActs.SpellCanAffect (#1086, #1087): the combat AI casts a spell only where it obviously does something.
  Hold Person and Charm Person take persons, not undead or monsters; Sleep passes over the undead, the animated dead,
  the sleeping and those with too many hit dice for any roll; a spell passes over a creature already under its effect,
  and one already helpless for a spell that leaves it so; Silence takes only a creature seen casting this fight; Snake
  Charm only the snake; Cause Disease no undead. }
{$I COMPILER.INC}
program TSpcAff;

uses Types, C_EFFECT, C_RACE, C_SPELL, C_STATUS, GameDefs, GameVars, CharHlp, FxEngine, CbtActs, TestKit;

var
  fighter: Types.TCharRecord;
  skeleton: Types.TCharRecord;
  scorpion: Types.TCharRecord;
  snake: Types.TCharRecord;

{ c as a creature of race and charType on one tile, enabled. }
procedure Make(var c: Types.TCharRecord; race, charType, icon: Byte; name: Types.TName15);
begin
  FillChar(c, SizeOf(c), 0);
  c.race := race;
  c.charType := charType;
  c.iconDimensions := icon;
  c.name := name;
  c.enabled := 1;
  c.levelHighest := 1;
end;

begin
  TestKit.Start('TSPCAFF');
  Make(fighter, C_RACE.HUMAN, 0, 1, 'FIGHTER');
  Make(skeleton, C_RACE.MONSTER, CharHlp.UNDEAD_TYPE, 1, 'SKELETON');
  Make(scorpion, C_RACE.MONSTER, 14, 2, 'LARGE SCORPION');
  Make(snake, C_RACE.MONSTER, 14, 2, C_SPELL.SNAKE_NAME);

  { the persons spells }
  TestKit.Check(CbtActs.SpellCanAffect(C_SPELL.HOLD_PERSON, @fighter, nil), 'Hold Person holds a fighter');
  TestKit.Check(not CbtActs.SpellCanAffect(C_SPELL.HOLD_PERSON, @skeleton, nil), 'not a skeleton');
  TestKit.Check(not CbtActs.SpellCanAffect(C_SPELL.HOLD_PERSON_MU, @scorpion, nil), 'nor a scorpion, either Hold');
  TestKit.Check(not CbtActs.SpellCanAffect(C_SPELL.CHARM_PERSON, @scorpion, nil), 'Charm Person no scorpion');

  { Sleep }
  TestKit.Check(CbtActs.SpellCanAffect(C_SPELL.SLEEP, @fighter, nil), 'Sleep takes a 1-HD fighter');
  TestKit.Check(not CbtActs.SpellCanAffect(C_SPELL.SLEEP, @skeleton, nil), 'not the undead');
  fighter.levelHighest := 9;
  TestKit.Check(not CbtActs.SpellCanAffect(C_SPELL.SLEEP, @fighter, nil), 'nor one too high for any roll to pay for');
  fighter.levelHighest := 1;

  { under the effect already, or helpless }
  FxEngine.AddEffect(@fighter, GameDefs.spellTable[C_SPELL.HOLD_PERSON].effect, 0, 0, False);
  TestKit.Check(not CbtActs.SpellCanAffect(C_SPELL.HOLD_PERSON, @fighter, nil), 'no Hold on one held already');
  TestKit.Check(not CbtActs.SpellCanAffect(C_SPELL.SLEEP, @fighter, nil), 'nor Sleep on one helpless');
  TestKit.Check(CbtActs.SpellCanAffect(C_SPELL.MAGIC_MISSILE, @fighter, nil), 'a Magic Missile still hits him');
  FxEngine.RemoveEffect(@fighter, GameDefs.spellTable[C_SPELL.HOLD_PERSON].effect, nil);

  { Silence: only a creature seen casting }
  GameVars.arenaCount := 2;
  GameVars.creatureArr[1] := @fighter;
  GameVars.creatureArr[2] := @skeleton;
  CbtActs.seenCasting := [];
  TestKit.Check(not CbtActs.SpellCanAffect(C_SPELL.SILENCE, @fighter, nil), 'no Silence on one never seen casting');
  CbtActs.seenCasting := [1];
  TestKit.Check(CbtActs.SpellCanAffect(C_SPELL.SILENCE, @fighter, nil), 'Silence on one seen casting');
  TestKit.Check(not CbtActs.SpellCanAffect(C_SPELL.SILENCE, @skeleton, nil), 'but not his neighbour');

  { Snake Charm and Cause Disease }
  TestKit.Check(CbtActs.SpellCanAffect(C_SPELL.SNAKE_CHARM, @snake, nil), 'Snake Charm the snake');
  TestKit.Check(not CbtActs.SpellCanAffect(C_SPELL.SNAKE_CHARM, @scorpion, nil),
                'not the scorpion it shares a type with');
  TestKit.Check(not CbtActs.SpellCanAffect(C_SPELL.CAUSE_DISEASE, @skeleton, nil), 'no disease for the undead');

  { the disabled }
  scorpion.enabled := 0;
  TestKit.Check(not CbtActs.SpellCanAffect(C_SPELL.MAGIC_MISSILE, @scorpion, nil), 'nothing for one out of the fight');
  TestKit.Done;
end.

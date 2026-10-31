{ Tests for CbtActs.SpellCanAffect (#1086, #1087): the combat AI casts a spell only where it obviously does something.
  Hold Person and Charm Person take persons, not undead or monsters; Sleep passes over the undead, the animated dead,
  the sleeping and those with too many hit dice for any roll; a spell passes over a creature already under its effect,
  and one already helpless for a spell that leaves it so; Silence takes only a creature seen casting this fight; Snake
  Charm only the snake; Cause Disease no undead. Stinking Cloud passes over one nauseated already or standing in a
  cloud, and counts only who its own 2x2 block catches (CloudCatch, #1087). }
{$I COMPILER.INC}
program TSpcAff;

uses Types, C_EFFECT, C_RACE, C_SPELL, C_STATUS, C_TERR, GameDefs, GameVars, CharHlp, FxEngine, CbtMap, CbtActs,
  TestKit;

const
  { open ground: terrain 5, cost 1 }
  GROUND = 5;

var
  fighter: Types.TCharRecord;
  skeleton: Types.TCharRecord;
  scorpion: Types.TCharRecord;
  snake: Types.TCharRecord;
  { the party's caster and three enemies round the aim cell (10, 10) }
  caster: Types.TCharRecord;
  atAim: Types.TCharRecord;
  southEast: Types.TCharRecord;
  northWest: Types.TCharRecord;

{ Put slot's one-tile body at (x, y) and rebuild the arena's creature cells. }
procedure Place(slot: Byte; x, y: ShortInt);
begin
  GameVars.arenaLoc[slot].x := x;
  GameVars.arenaLoc[slot].y := y;
  GameVars.arenaLoc[slot].size := 1;
  CbtMap.BuildArenaArrays;
end;

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

  { Stinking Cloud: not on one nauseated already, nor one standing in a cloud (#1087) }
  GetMem(GameVars.arenaPtr, SizeOf(Types.TArena));
  FillChar(GameVars.arenaPtr^, SizeOf(Types.TArena), 0);
  FillChar(GameVars.arenaPtr^.cells, SizeOf(GameVars.arenaPtr^.cells), GROUND);
  FillChar(GameVars.arenaLoc, SizeOf(GameVars.arenaLoc), 0);
  Make(caster, C_RACE.HUMAN, 0, 1, 'CASTER');
  Make(atAim, C_RACE.HUMAN, 0, 1, 'KOBOLD A');
  Make(southEast, C_RACE.HUMAN, 0, 1, 'KOBOLD B');
  Make(northWest, C_RACE.HUMAN, 0, 1, 'KOBOLD C');
  atAim.hostile := 1;
  southEast.hostile := 1;
  northWest.hostile := 1;
  GameVars.arenaCount := 6;
  GameVars.creatureArr[3] := @caster;
  GameVars.creatureArr[4] := @atAim;
  GameVars.creatureArr[5] := @southEast;
  GameVars.creatureArr[6] := @northWest;
  GameVars.curChar := @caster;
  Place(1, 20, 20);
  Place(3, 2, 2);
  Place(4, 10, 10);
  Place(5, 11, 11);
  Place(6, 9, 9);
  TestKit.Check(CbtActs.SpellCanAffect(C_SPELL.STINKING_CLOUD, @fighter, nil), 'a Stinking Cloud on a fresh fighter');
  FxEngine.AddEffect(@fighter, C_EFFECT.HELPLESS, 0, 0, False);
  TestKit.Check(not CbtActs.SpellCanAffect(C_SPELL.STINKING_CLOUD, @fighter, nil), 'not on one nauseated already');
  FxEngine.RemoveEffect(@fighter, C_EFFECT.HELPLESS, nil);
  GameVars.arenaPtr^.cells[20, 20] := C_TERR.STINKING_CLOUD;
  TestKit.Check(not CbtActs.SpellCanAffect(C_SPELL.STINKING_CLOUD, @fighter, nil), 'nor on one standing in a cloud');
  TestKit.Check(CbtActs.SpellCanAffect(C_SPELL.STINKING_CLOUD, @atAim, nil), 'but on one beside it');
  GameVars.arenaPtr^.cells[20, 20] := GROUND;

  { the cloud's own block: the aim cell, E, SE and S, not the cells round the aim }
  TestKit.CheckEqualsL(2, CbtActs.CloudCatch(10, 10), 'the cloud catches the enemies at the aim and SE, not NW');
  TestKit.CheckEqualsL(2, CbtActs.CloudCatch(9, 9), 'aimed at the NW one: him and the one SE of him');
  Place(5, 10, 9);
  TestKit.CheckEqualsL(3, CbtActs.CloudCatch(9, 9), 'and a third on the block''s east cell');
  Place(5, 11, 11);
  FxEngine.AddEffect(@southEast, C_EFFECT.HELPLESS, 0, 0, False);
  TestKit.CheckEqualsL(1, CbtActs.CloudCatch(10, 10), 'a nauseated one is not counted');
  FxEngine.RemoveEffect(@southEast, C_EFFECT.HELPLESS, nil);
  Place(3, 10, 11);
  TestKit.CheckEqualsL(0, CbtActs.CloudCatch(10, 10), 'none where the block holds the caster''s own side');
  Place(3, 2, 2);
  GameVars.arenaPtr^.cells[11, 11] := 1;
  TestKit.CheckEqualsL(1, CbtActs.CloudCatch(10, 10), 'nor one on a cell the cloud cannot fill');
  GameVars.arenaPtr^.cells[11, 11] := GROUND;
  GameVars.curChar := nil;
  GameVars.arenaCount := 2;
  FreeMem(GameVars.arenaPtr, SizeOf(Types.TArena));
  GameVars.arenaPtr := nil;

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

{ Tests for Shield (EffHndlr.EffShield, eff 17): it sets armor class 3 at worst and stops the missiles of Magic Missile
  and of the Wand of Magic Missiles, not only the spell's (POR-0210, #890), and no other spell's damage. }
{$I COMPILER.INC}
program TShield;

uses Types, C_SPELL, GameVars, FxEngine, EffHndlr, TestKit;

var
  c: Types.PCharRecord;

{ The damage left after Shield sees spell's hit of 7. }
function DamageLeft(spell: Byte): Integer;
begin
  GameVars.spellId := spell;
  GameVars.pendingDamage := 7;
  EffHndlr.EffShield(c, nil, False);
  DamageLeft := GameVars.pendingDamage;
end;

begin
  TestKit.Start('TSHIELD');
  GetMem(c, SizeOf(Types.TCharRecord));
  FillChar(c^, SizeOf(Types.TCharRecord), 0);
  c^.acCur := 50;
  TestKit.CheckEqualsL(0, DamageLeft(C_SPELL.MAGIC_MISSILE), 'Shield stops Magic Missile');
  TestKit.CheckEqualsL(0, DamageLeft(C_SPELL.WAND_MAGIC_MISSILES), 'and the Wand of Magic Missiles (#890)');
  TestKit.CheckEqualsL(7, DamageLeft(C_SPELL.FIREBALL), 'but not a fireball');
  TestKit.CheckEqualsL(7, DamageLeft(C_SPELL.ITEM_FIREBALL), 'nor the necklace''s');
  TestKit.CheckEqualsL(57, c^.acCur, 'armor class 3 at worst (60-biased 57)');
  FreeMem(c, SizeOf(Types.TCharRecord));
  TestKit.Done;
end.

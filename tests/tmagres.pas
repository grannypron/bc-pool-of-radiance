{ Tests for magic resistance (EffHndlr.EffMagicRes50, eff 105): the listed figure is against an 11th-level caster and
  moves 5% for each level below or above, and an effect that is no spell (a gaze, a touch) meets the listed figure, not
  that against the level of spell 0, read from outside the spell table (#786). }
{$I COMPILER.INC}
program TMagRes;

uses Types, C_Effect, C_Spell, C_Level, GDVars, EffHndlr, TestKit;

const
  TRIES = 1000;

var
  caster: Types.PCharRecord;
  target: Types.PCharRecord;

{ How many of TRIES effects (eff 31, under the immunity check) the target's 50% resistance stops }
function Resisted: Integer;
var
  i: Integer;
  n: Integer;
begin
  n := 0;
  for i := 1 to TRIES do begin
    GDVars.pendingEffectId := C_Effect.HELPLESS;
    EffHndlr.EffMagicRes50(target, nil, False);
    if GDVars.pendingEffectId = 0 then
      Inc(n);
  end;
  Resisted := n;
end;

begin
  TestKit.Start('TMAGRES');
  GetMem(caster, SizeOf(Types.TCharRecord));
  FillChar(caster^, SizeOf(Types.TCharRecord), 0);
  GetMem(target, SizeOf(Types.TCharRecord));
  FillChar(target^, SizeOf(Types.TCharRecord), 0);
  GDVars.curChar := caster;
  GDVars.usingItem := False;
  GDVars.elementMask := 0;

  GDVars.dsCurrentSpellBeing := C_Spell.MAGIC_MISSILE;
  caster^.classLevels[C_Level.MAGE] := 1;
  TestKit.CheckEqualsL(TRIES, Resisted, '50% against level 11 is 100% against level 1');
  caster^.classLevels[C_Level.MAGE] := 21;
  TestKit.CheckEqualsL(0, Resisted, 'and 0% against level 21');

  { no spell (#786) }
  GDVars.dsCurrentSpellBeing := C_Spell.NONE;
  TestKit.Check(Abs(Resisted - TRIES div 2) < TRIES div 10, 'an effect that is no spell meets the listed 50%');
  caster^.classLevels[C_Level.MAGE] := 1;
  TestKit.Check(Abs(Resisted - TRIES div 2) < TRIES div 10, 'whatever the creature''s own level');
  TestKit.Done;
end.

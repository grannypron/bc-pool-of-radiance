{ The conditions FxEngine.TriggerEffectsWithCondition checks effects under. }
{$I COMPILER.INC}
unit C_Cond;

interface

const
  { Check the target first, then the attacker unless the target vetoes. Handlers veto by setting the
    targeting-suppression flag. }
  { the attacker's own effects }
  ATTACKER_VETO = 0;
  { the target's effects }
  TARGET_VETO = 1;
  { a hit landed in attack phase 1 }
  HIT_PHASE_1 = 2;
  { a hit landed in attack phase 2 }
  HIT_PHASE_2 = 3;
  WEAPON_DAMAGE_ATT = 4;
  WEAPON_DAMAGE_DEF = 5;
  { before the saving-throw reduction }
  NONWEAPON_DAMAGE = 6;
  { CreatureAction, before the initiative test }
  TURN_START = 7;
  COMBAT_START = 8;
  { Clear pendingEffectId to suppress the effect. }
  EFFECT_IMMUNITY = 9;
  ATTACK_ROLL_ATT = 10;
  { after RecalcStats, before the roll }
  DEFENDER_AC = 11;
  SAVING_THROW = 12;
  { Already disabled on entry; effect 99 may revive it. }
  HP_ZERO = 13;
  { Gazes, dragon breath and acid attacks. }
  MONSTER_SPECIAL = 14;
  { CreatureAction, and each menu draw }
  ACTION_START = 15;
  ATTACK_ROLL_DEF = 16;
  MORALE_CHECK = 17;
  { haste / slow / immobile effects }
  MOVE_ATTACK_RATE = 18;
  ROUND_END = 19;

implementation

end.

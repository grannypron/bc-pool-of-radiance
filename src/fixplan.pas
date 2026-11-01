{ Fix's planning (#1129), apart from its screens so the tests can check it: what the party's clerics cast while the
  party rests, which drained clerics lack a cure they would cast undrained, and the scrolls, potions and paladin's
  powers the Fix settings let it use. Camp's Fix carries the plan out. }
{$O+,F+}
{$I COMPILER.INC}
unit FixPlan;

interface

uses Types;

const
  { The conditions Fix treats, in the order its cures are planned: a drained level, a disease (mummy rot with it),
    blindness and Bestow Curse. }
  FIX_DRAIN = 1;
  FIX_DISEASE = 2;
  FIX_BLIND = 3;
  FIX_CURSE = 4;
  FIX_FIRST = FIX_DRAIN;
  FIX_LAST = FIX_CURSE;
  { what a TFixUse does: casts its item's spell, or is a paladin's laying on of hands or weekly cure }
  USE_ITEM = 1;
  USE_LAY_ON_HANDS = 2;
  USE_PALADIN_CURE = 3;
  { the fewest hit points a member must lack before Fix spends a scroll of Cure Light Wounds, a Potion of Healing or
    Keoghtom's Ointment on its wounds: each one's average roll (1d8, 2d4 + 2, 1d4 + 8), so little of it is wasted }
  WOUND_CLW = 4;
  WOUND_HEALING = 7;
  WOUND_OINTMENT = 10;

type
  { The clerics' spells for a Fix: the members, in party order (a longer creature list is not looked at past
    Types.MAX_PARTY); each member's free cleric slots by spell level and the casts given it; the cures planned for each
    member by condition (a drained level takes a cast each), and those left with no slot for them; how many Cure Light
    Wounds are cast; the wounds those may heal; whether a treatable member has a condition at all; and the members with
    cleric levels, and those of them conscious enough to cast. }
  TFixPlan = record
    n: Byte;
    members: array[1..Types.MAX_PARTY] of Types.PCharRecord;
    free: array[1..Types.MAX_PARTY, 1..Types.CASTER_LEVEL_LAST] of Byte;
    casts: array[1..Types.MAX_PARTY, 1..Types.CASTER_LEVEL_LAST] of Byte;
    cures: array[1..Types.MAX_PARTY, FIX_FIRST..FIX_LAST] of Byte;
    left: array[1..Types.MAX_PARTY, FIX_FIRST..FIX_LAST] of Byte;
    healCasts: Word;
    need: Word;
    anyCondition: Boolean;
    clerics: Byte;
    ableClerics: Byte;
  end;
  { One use of an item or a paladin's power: what it is (USE_ITEM, USE_LAY_ON_HANDS or USE_PALADIN_CURE), who uses it,
    the item (nil for a paladin's power) and the spell it casts, and the member it is used on. }
  TFixUse = record
    kind: Byte;
    user: Types.PCharRecord;
    item: Types.PItemRec;
    spell: Byte;
    target: Types.PCharRecord;
  end;

{ The spell that cures condition cond: Restoration, Cure Disease, Cure Blindness or Remove Curse. Fix plans a cure
  from the clerics' slots only for a spell of a level they have slots for (Types.CASTER_LEVEL_LAST); a game whose
  clerics reach Restoration's level plans it as it plans the others. }
function CureSpell(cond: Byte): Byte;

{ How many casts of its cure condition cond needs on creature: its drained levels for a drain, else 1 when it has the
  condition (a disease includes mummy rot) and 0 when not. }
function CondCount(creature: Types.PCharRecord; cond: Byte): Byte;

{ True for the statuses FxEngine.RestoreHitPoints accepts, the members Fix treats: okay, animated, unconscious or
  dying. }
function Treatable(creature: Types.PCharRecord): Boolean;

{ True when creature has mummy rot, which stops all healing until a cure of disease takes it away. }
function Rotted(creature: Types.PCharRecord): Boolean;

{ Plan the clerics' spells for the party (GameVars.creatureList) into plan. Each okay cleric's slots of each level
  (clericSpells) are free for the spells of that level it knows. The cures are planned first, in condition order and
  then party order, each to the least busy cleric with a slot for it. Then as many Cure Light Wounds as the wounds need
  at 4.5 hit points each, counting the wounds of a member with mummy rot only when its cure of disease was planned:
  no healing reaches it otherwise. }
procedure Plan(var plan: TFixPlan);

{ The minutes member j needs to memorize its casts again, by the memorize rule: 4 hours, 6 with a level-3 spell or
  higher, and 15 minutes per spell level; 0 with no casts. }
function CasterTime(var plan: TFixPlan; j: Byte): Word;

{ The rest the plan takes: the busiest member's CasterTime. }
function RestMinutes(var plan: TFixPlan): Word;

{ True when the plan has the clerics cast anything. }
function HasCasts(var plan: TFixPlan): Boolean;

{ True when cleric is level drained and lacks every slot of the level of spell that it would have undrained: its cleric
  level raised by its drained levels has slots of that level in the cleric's table, where it has none now. Only levels
  the clerics have slots for count. A drained level may have been another class's; it is read as the cleric's. }
function DrainedOutOf(cleric: Types.PCharRecord; spell: Byte): Boolean;

{ The next scroll, potion or paladin's power the Fix settings (GameVars.fixScrollsOn, fixPotionsOn, fixCureOn,
  fixHealOn) have Fix use, into use; False when there is none. With drainOnly, only a scroll of Restoration for a
  drained level. Otherwise, for each treatable member in party order: a disease, by a paladin's cure, a scroll of Cure
  Disease or Keoghtom's Ointment (not on a poisoned member, whom the ointment would cure of the poison instead); then
  blindness, by a scroll of Cure Blindness; Bestow Curse, by a scroll of Remove Curse; a drained level, by a scroll of
  Restoration. Then the wounds: a paladin lays on hands on the most wounded member; and for each member in party order
  a scroll of Cure Light Wounds, a Potion of Healing, or Keoghtom's Ointment, each only for a member lacking at least
  its average (WOUND_CLW, WOUND_HEALING, WOUND_OINTMENT), none for a member with mummy rot, nor the ointment for a
  diseased or poisoned one. A paladin's power comes before an item, a scroll before a potion. A scroll is read by the
  first okay member in party order who can read and use it (CharHlp.CastableScroll); a potion or ointment is given by
  the first okay member who carries one. Each use spends what it uses, so calling this until it is False ends. }
function NextUse(drainOnly: Boolean; var use: TFixUse): Boolean;

implementation

uses GameDefs, GameVars, CharHlp, FxEngine, C_EFFECT, C_LEVEL, C_SPELL, C_STATUS;

const
  { CureSpell's table, by condition }
  CURES: array[FIX_FIRST..FIX_LAST] of Byte = (C_SPELL.RESTORATION, C_SPELL.CURE_DISEASE, C_SPELL.CURE_BLINDNESS,
    C_SPELL.REMOVE_CURSE);
  { the cleric's slot table (TRuleXp.slots) by class level, from level 2 to the table's last (#1121) }
  SLOT_ROW_FIRST = 2;
  SLOT_ROW_LAST = C_LEVEL.LEVEL_LAST;

function CureSpell(cond: Byte): Byte;
begin
  if (cond >= FIX_FIRST) and (cond <= FIX_LAST) then
    CureSpell := CURES[cond]
  else
    CureSpell := C_SPELL.NONE;
end;

function CondCount(creature: Types.PCharRecord; cond: Byte): Byte;
var
  effect: Types.PEffectRec;
begin
  case cond of
    FIX_DRAIN: CondCount := creature^.drainedLevels;
    FIX_DISEASE: CondCount := Ord(FxEngine.HasDisease(creature));
    FIX_BLIND: CondCount := Ord(CharHlp.HasEffect(creature, C_EFFECT.BLIND, effect));
    FIX_CURSE: CondCount := Ord(CharHlp.HasEffect(creature, C_EFFECT.BESTOW_CURSE, effect));
  else
    CondCount := 0;
  end;
end;

function Treatable(creature: Types.PCharRecord): Boolean;
begin
  Treatable := creature^.status in [C_STATUS.OKAY, C_STATUS.ANIMATED, C_STATUS.UNCONSCIOUS, C_STATUS.DYING];
end;

function Rotted(creature: Types.PCharRecord): Boolean;
var
  effect: Types.PEffectRec;
begin
  Rotted := CharHlp.HasEffect(creature, C_EFFECT.ROT_NO_HEAL, effect);
end;

{ The level of spell, 0 for none. }
function SpellLevel(spell: Byte): Byte;
begin
  if CharHlp.IsSpell(spell) then
    SpellLevel := GameDefs.spellTable[spell].level
  else
    SpellLevel := 0;
end;

function CasterTime(var plan: TFixPlan; j: Byte): Word;
var
  t: Word;
  lvl: Byte;
  top: Byte;
begin
  t := 0;
  top := 0;
  for lvl := 1 to Types.CASTER_LEVEL_LAST do
    if plan.casts[j, lvl] > 0 then begin
      Inc(t, 15 * lvl * plan.casts[j, lvl]);
      top := lvl;
    end;
  if top >= 3 then
    Inc(t, 360)
  else if top > 0 then
    Inc(t, 240);
  CasterTime := t;
end;

function RestMinutes(var plan: TFixPlan): Word;
var
  i: Byte;
  total: Word;
begin
  total := 0;
  for i := 1 to plan.n do
    if total < FixPlan.CasterTime(plan, i) then
      total := FixPlan.CasterTime(plan, i);
  RestMinutes := total;
end;

function HasCasts(var plan: TFixPlan): Boolean;
var
  i: Byte;
  lvl: Byte;
  any: Boolean;
begin
  any := False;
  for i := 1 to plan.n do
    for lvl := 1 to Types.CASTER_LEVEL_LAST do
      if plan.casts[i, lvl] > 0 then
        any := True;
  HasCasts := any;
end;

{ Give one cast of spell to the least busy member with a free slot of its level who knows it. False when nobody can
  cast it, or it is of a level with no slots. }
function Assign(var plan: TFixPlan; spell: Byte): Boolean;
var
  j: Byte;
  best: Byte;
  lvl: Byte;
begin
  best := 0;
  lvl := FixPlan.SpellLevel(spell);
  if (lvl >= 1) and (lvl <= Types.CASTER_LEVEL_LAST) then
    for j := 1 to plan.n do
      if (plan.free[j, lvl] > 0) and CharHlp.KnowsSpell(plan.members[j], spell) then
        if (best = 0) or (FixPlan.CasterTime(plan, j) < FixPlan.CasterTime(plan, best)) then
          best := j;
  if best <> 0 then begin
    Dec(plan.free[best, lvl]);
    Inc(plan.casts[best, lvl]);
  end;
  Assign := best <> 0;
end;

procedure Plan(var plan: TFixPlan);
var
  p: Types.PCharRecord;
  i: Byte;
  k: Byte;
  cond: Byte;
  lvl: Byte;
  wanted: Word;
begin
  FillChar(plan, SizeOf(plan), 0);
  p := GameVars.creatureList;
  while (p <> nil) and (plan.n < Types.MAX_PARTY) do begin
    Inc(plan.n);
    plan.members[plan.n] := p;
    if CharHlp.GetClassLevel(p, C_LEVEL.CLERIC_BIT) > 0 then begin
      Inc(plan.clerics);
      if p^.status = C_STATUS.OKAY then
        Inc(plan.ableClerics);
    end;
    if p^.status = C_STATUS.OKAY then
      for lvl := 1 to Types.CASTER_LEVEL_LAST do
        plan.free[plan.n, lvl] := CharHlp.SpellSlots(p, C_SPELL.CLASS_CLERIC, lvl);
    p := p^.nextCharAddr;
  end;
  for cond := FIX_FIRST to FIX_LAST do
    for i := 1 to plan.n do
      if FixPlan.Treatable(plan.members[i]) then
        for k := 1 to FixPlan.CondCount(plan.members[i], cond) do begin
          plan.anyCondition := True;
          if FixPlan.Assign(plan, FixPlan.CureSpell(cond)) then
            Inc(plan.cures[i, cond])
          else
            Inc(plan.left[i, cond]);
        end;
  for i := 1 to plan.n do begin
    p := plan.members[i];
    if FixPlan.Treatable(p) and (p^.hpCur < p^.hpMax) then
      if not FixPlan.Rotted(p) or (plan.cures[i, FIX_DISEASE] > 0) then
        Inc(plan.need, p^.hpMax - p^.hpCur);
  end;
  wanted := (2 * plan.need + 8) div 9;
  while plan.healCasts < wanted do
    if FixPlan.Assign(plan, C_SPELL.CURE_LIGHT_WOUNDS) then
      Inc(plan.healCasts)
    else
      wanted := plan.healCasts;
end;

function DrainedOutOf(cleric: Types.PCharRecord; spell: Byte): Boolean;
var
  lvl: Byte;
  cl: Integer;
begin
  DrainedOutOf := False;
  lvl := FixPlan.SpellLevel(spell);
  cl := CharHlp.GetClassLevel(cleric, C_LEVEL.CLERIC_BIT);
  if (cleric^.drainedLevels = 0) or (cl <= 0) or (lvl < 1) or (lvl > Types.CASTER_LEVEL_LAST) then Exit;
  if CharHlp.SpellSlots(cleric, C_SPELL.CLASS_CLERIC, lvl) > 0 then Exit;
  Inc(cl, cleric^.drainedLevels);
  if cl > SLOT_ROW_LAST then
    cl := SLOT_ROW_LAST;
  if cl >= SLOT_ROW_FIRST then
    DrainedOutOf := GameDefs.classExperience[C_LEVEL.CLERIC].slots[cl, lvl] > 0;
end;

{ True when creature can act to use an item or a power: okay and not out of action. }
function Able(creature: Types.PCharRecord): Boolean;
begin
  Able := (creature^.status = C_STATUS.OKAY) and (creature^.enabled <> 0);
end;

{ The first able member in party order who can read and use a scroll holding spell, and that scroll, into use's user
  and item. }
function FindScroll(spell: Byte; var use: TFixUse): Boolean;
var
  p: Types.PCharRecord;
  item: Types.PItemRec;
  slot: Byte;
begin
  FindScroll := False;
  p := GameVars.creatureList;
  while p <> nil do begin
    if FixPlan.Able(p) then begin
      item := p^.itemsAddr;
      while item <> nil do begin
        if CharHlp.ItemReadable(item) and CharHlp.CastableScroll(p, item) then
          for slot := 1 to SizeOf(item^.spells) do
            if CharHlp.ScrollSpellAt(item, slot) = spell then begin
              use.user := p;
              use.item := item;
              use.spell := spell;
              FindScroll := True;
              Exit;
            end;
        item := item^.next;
      end;
    end;
    p := p^.nextCharAddr;
  end;
end;

{ The first able member in party order who carries an item casting spell (CharHlp.ItemSpell) with a charge, and the
  item, into use's user and item. }
function FindPotion(spell: Byte; var use: TFixUse): Boolean;
var
  p: Types.PCharRecord;
  item: Types.PItemRec;
begin
  FindPotion := False;
  p := GameVars.creatureList;
  while p <> nil do begin
    if FixPlan.Able(p) then begin
      item := p^.itemsAddr;
      while item <> nil do begin
        if (CharHlp.ItemSpell(item) = spell) and (item^.charges > 0) then begin
          use.user := p;
          use.item := item;
          use.spell := spell;
          FindPotion := True;
          Exit;
        end;
        item := item^.next;
      end;
    end;
    p := p^.nextCharAddr;
  end;
end;

{ The first paladin in party order who can lay on hands (heal) or cure a disease now, into use's user. }
function FindPaladin(heal: Boolean; var use: TFixUse): Boolean;
var
  p: Types.PCharRecord;
  ready: Boolean;
begin
  FindPaladin := False;
  p := GameVars.creatureList;
  while p <> nil do begin
    if heal then
      ready := CharHlp.PaladinCanHeal(p)
    else
      ready := CharHlp.PaladinCanCure(p);
    if ready then begin
      use.user := p;
      use.item := nil;
      use.spell := C_SPELL.NONE;
      FindPaladin := True;
      Exit;
    end;
    p := p^.nextCharAddr;
  end;
end;

{ True when creature is poisoned, which Keoghtom's Ointment would cure before anything else. }
function Poisoned(creature: Types.PCharRecord): Boolean;
var
  effect: Types.PEffectRec;
begin
  Poisoned := CharHlp.HasEffect(creature, C_EFFECT.POISONED, effect);
end;

{ The hit points a member can still be healed of: its wounds, or 0 for one Fix does not treat or with mummy rot. }
function Healable(creature: Types.PCharRecord): Byte;
begin
  if FixPlan.Treatable(creature) and not FixPlan.Rotted(creature) and (creature^.hpCur < creature^.hpMax) then
    Healable := creature^.hpMax - creature^.hpCur
  else
    Healable := 0;
end;

function NextUse(drainOnly: Boolean; var use: TFixUse): Boolean;
var
  p: Types.PCharRecord;
  most: Types.PCharRecord;
  found: Boolean;
begin
  found := False;
  use.kind := USE_ITEM;
  p := GameVars.creatureList;
  while (p <> nil) and not found do begin
    if FixPlan.Treatable(p) then begin
      if not drainOnly and (FixPlan.CondCount(p, FIX_DISEASE) > 0) then begin
        if GameVars.fixCureOn <> 0 then begin
          found := FixPlan.FindPaladin(False, use);
          if found then
            use.kind := USE_PALADIN_CURE;
        end;
        if not found and (GameVars.fixScrollsOn <> 0) then
          found := FixPlan.FindScroll(C_SPELL.CURE_DISEASE, use);
        if not found and (GameVars.fixPotionsOn <> 0) and not FixPlan.Poisoned(p) then
          found := FixPlan.FindPotion(C_SPELL.ITEM_OINTMENT, use);
      end;
      if not found and not drainOnly and (GameVars.fixScrollsOn <> 0) then begin
        if FixPlan.CondCount(p, FIX_BLIND) > 0 then
          found := FixPlan.FindScroll(C_SPELL.CURE_BLINDNESS, use);
        if not found and (FixPlan.CondCount(p, FIX_CURSE) > 0) then
          found := FixPlan.FindScroll(C_SPELL.REMOVE_CURSE, use);
      end;
      if not found and (GameVars.fixScrollsOn <> 0) and (FixPlan.CondCount(p, FIX_DRAIN) > 0) then
        found := FixPlan.FindScroll(C_SPELL.RESTORATION, use);
    end;
    if found then
      use.target := p
    else
      p := p^.nextCharAddr;
  end;
  if not found and not drainOnly and (GameVars.fixHealOn <> 0) then begin
    most := nil;
    p := GameVars.creatureList;
    while p <> nil do begin
      if FixPlan.Healable(p) > 0 then
        if (most = nil) or (FixPlan.Healable(p) > FixPlan.Healable(most)) then
          most := p;
      p := p^.nextCharAddr;
    end;
    if most <> nil then begin
      found := FixPlan.FindPaladin(True, use);
      if found then begin
        use.kind := USE_LAY_ON_HANDS;
        use.target := most;
      end;
    end;
  end;
  if not drainOnly then begin
    p := GameVars.creatureList;
    while (p <> nil) and not found do begin
      if (GameVars.fixScrollsOn <> 0) and (FixPlan.Healable(p) >= WOUND_CLW) then
        found := FixPlan.FindScroll(C_SPELL.CURE_LIGHT_WOUNDS, use);
      if not found and (GameVars.fixPotionsOn <> 0) then begin
        if FixPlan.Healable(p) >= WOUND_HEALING then
          found := FixPlan.FindPotion(C_SPELL.ITEM_HEALING, use);
        if not found and (FixPlan.Healable(p) >= WOUND_OINTMENT) and not FixPlan.Poisoned(p) and
            (FixPlan.CondCount(p, FIX_DISEASE) = 0) then
          found := FixPlan.FindPotion(C_SPELL.ITEM_OINTMENT, use);
      end;
      if found then begin
        use.kind := USE_ITEM;
        use.target := p;
      end else
        p := p^.nextCharAddr;
    end;
  end;
  NextUse := found;
end;

end.

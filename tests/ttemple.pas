{ Tests for TownCore's temple: every service's refusals, needs, dice and deeds under the fleet's rule sets (gold at the
  1st-edition prices with a failed raise gone for good, as Pool of Radiance has it; Krynn's steel at half with its elves
  beyond both revivals; a free temple), and TempleService's course through a stand-in game: what it asks, what it
  charges, what it does and what it says. Carried over from goldbox-tp7's tests/shared/ttemple.pas, with this game's
  rules (Temple.TempleRules, the tenth off) and Repair (#1125): what it plans for a character, what that costs, and
  its course. }
{$I COMPILER.INC}
program TTemple;

uses TownCore, Temple, C_RACE, MoneyCal, TestKit;

var
  gold, steel, gratis, por, tenth: TTempleRules;
  plan: TRepairPlan;
  undone: LongInt;
  ch: TTempleChar;
  d: TTempleDeed;
  io: TTempleIO;
  { the stand-in game's state }
  answer: Boolean;
  payOk: Boolean;
  asked, paid, acted: Integer;
  said, quoted: String;
  dice: Integer;
  lastRolled: String;
  n, sides: Byte;
  plus: Integer;
  i: Byte;
  { the stand-in game's own words: TM_SEES and TM_GONE }
  ownWords: Boolean;

function NumStr(n: LongInt): String;
var
  t: String;
begin
  Str(n, t);
  NumStr := t;
end;

{$F+}
procedure FakeLook(var c: TTempleChar);
begin
  c := ch;
end;

function FakeAsk(const msg: String): Boolean;
begin
  Inc(asked);
  said := msg;
  FakeAsk := answer;
end;

function FakePay(const quote: String; cost: LongInt): Boolean;
begin
  quoted := quote;
  if payOk then
    Inc(paid, cost);
  FakePay := payOk;
end;

procedure FakeSay(const msg: String);
begin
  said := msg;
end;

{ The game's side of a deed, as each game carries it out on its record. }
procedure FakeAct(const dd: TTempleDeed);
begin
  Inc(acted);
  with ch do begin
    if dd.acts and TA_BLIND <> 0 then
      flags := flags and not TF_BLIND;
    if dd.acts and TA_DISEASE <> 0 then
      flags := flags and not (TF_DISEASED or TF_ROT);
    if dd.acts and TA_POISON <> 0 then
      flags := flags and not (TF_POISONED or TF_SLOW_POISON);
    if dd.acts and TA_FEEBLE <> 0 then
      flags := flags and not TF_FEEBLE;
    if dd.acts and TA_CURSE <> 0 then
      flags := flags and not TF_CURSED;
    if dd.acts and TA_RESTORE <> 0 then
      flags := flags and not TF_DRAINED;
    if dd.acts and TA_LOSE_CON <> 0 then begin
      Dec(conPerm, dd.conLoss);
      Dec(conCur, dd.conLoss);
      Dec(hpMax, dd.conLoss);
    end;
    if dd.acts and TA_STATUS <> 0 then
      status := dd.status;
    if dd.acts and TA_SET_HP <> 0 then
      hp := dd.hp;
    if dd.acts and TA_FULL_HP <> 0 then
      hp := hpMax;
    if dd.acts and TA_HEAL_HP <> 0 then
      if status in [TC_OKAY, TC_ANIMATED, TC_UNCONSCIOUS, TC_DYING] then begin
        Inc(hp, dd.hp);
        if hp > hpMax then
          hp := hpMax;
      end;
  end;
end;

function FakeRoll(n, sides: Byte): Integer;
begin
  lastRolled := NumStr(n) + 'd' + NumStr(sides);
  FakeRoll := dice;
end;

function FakeWords(msg: Byte): String;
begin
  FakeWords := '';
  if ownWords then
    case msg of
      TM_SEES: FakeWords := 'can see!';
      TM_GONE: FakeWords := 'is not here';
    end;
end;
{$F-}

procedure Fresh(status: Byte; flags: Word);
begin
  ch.status := status;
  ch.hp := 20;
  ch.hpMax := 30;
  ch.conPerm := 15;
  ch.conCur := 15;
  ch.race := RACE_HUMAN;
  ch.level := 5;
  ch.flags := flags;
  ch.drained := 0;
  answer := True;
  payOk := True;
  asked := 0;
  paid := 0;
  acted := 0;
  said := '';
  quoted := '';
  dice := 1;
  lastRolled := '';
end;

begin
  TestKit.Start('TTEMPLE');
  io.Look := FakeLook;
  io.Ask := FakeAsk;
  io.Pay := FakePay;
  io.Say := FakeSay;
  io.Act := FakeAct;
  io.Roll := FakeRoll;
  io.Words := FakeWords;
  ownWords := False;

  DefaultRules(gold);
  StandardPrices(gold, 1);
  gold.failGone := True;
  DefaultRules(steel);
  StandardPrices(steel, 2);
  steel.coin := 'steel';
  steel.raiseRaces := [RACE_HALFELF, RACE_MOUNTAINDWARF, RACE_HILLDWARF, RACE_KENDER, RACE_HUMAN];
  steel.resurrectRaces := steel.raiseRaces;
  DefaultRules(gratis);
  for i := 0 to TS_LAST do
    gratis.price[i] := 0;

  { the lists }
  for i := 0 to TS_LAST do begin
    Check(ServiceName(i) <> '', 'service ' + NumStr(i) + ' has a name');
    Check(Offers(gold, i) and Offers(steel, i) and Offers(gratis, i), 'service ' + NumStr(i) + ' sold everywhere');
  end;
  CheckEqualsS('', ServiceName(TS_LAST + 1), 'no service past the last');
  CheckEqualsL(5500, gold.price[TS_RAISE], 'Raise Dead 5500 gold');
  CheckEqualsL(2750, steel.price[TS_RAISE], 'Raise Dead 2750 steel');
  CheckEqualsL(50, steel.price[TS_CURE_LIGHT], 'Cure Light Wounds 50 steel');
  CheckEqualsL(11000, gold.price[TS_RESURRECT], 'Resurrection 11000 gold');
  CheckEqualsS('Raise Dead will only cost 2750 steel pieces.', TempleQuote(steel, TS_RAISE, 2750), 'the quote');
  Check(not Offers(gratis, TS_LAST + 1), 'nothing past the last is sold');

  { needs }
  Fresh(TC_OKAY, 0);
  CheckEqualsL(TM_NOT_BLIND, TempleNeed(TS_CURE_BLIND, ch), 'not blind');
  CheckEqualsL(TM_NOT_DISEASED, TempleNeed(TS_CURE_DISEASE, ch), 'not diseased');
  CheckEqualsL(TM_NONE, TempleNeed(TS_CURE_LIGHT, ch), 'wounded');
  CheckEqualsL(TM_NOT_POISONED, TempleNeed(TS_NEUTRALIZE, ch), 'not poisoned');
  CheckEqualsL(TM_NOT_DEAD, TempleNeed(TS_RAISE, ch), 'not dead');
  CheckEqualsL(TM_NOT_DEAD, TempleNeed(TS_RESURRECT, ch), 'not dead to resurrect');
  CheckEqualsL(TM_NOT_CURSED, TempleNeed(TS_REMOVE_CURSE, ch), 'not cursed');
  CheckEqualsL(TM_NOT_STONED, TempleNeed(TS_STONE, ch), 'not stoned');
  CheckEqualsL(TM_NOT_DRAINED, TempleNeed(TS_RESTORE, ch), 'no level lost');
  CheckEqualsL(TM_NONE, TempleNeed(TS_HEAL, ch), 'Heal works on the living');
  ch.hp := ch.hpMax;
  CheckEqualsL(TM_NOT_WOUNDED, TempleNeed(TS_CURE_SERIOUS, ch), 'not wounded');
  CheckEqualsL(TM_NONE, TempleNeed(TS_HEAL, ch), 'Heal needs no wound');
  ch.flags := TF_ROT;
  ch.hp := 1;
  CheckEqualsL(TM_ROT, TempleNeed(TS_CURE_CRITICAL, ch), 'mummy rot stops a cure');
  CheckEqualsL(TM_NONE, TempleNeed(TS_HEAL, ch), 'Heal cures the rot');
  Fresh(TC_DEAD, 0);
  CheckEqualsL(TM_IS_DEAD, TempleNeed(TS_CURE_LIGHT, ch), 'dead');
  CheckEqualsL(TM_IS_DEAD, TempleNeed(TS_HEAL, ch), 'Heal cannot help the dead');
  CheckEqualsL(TM_NONE, TempleNeed(TS_RAISE, ch), 'dead to raise');
  Fresh(TC_ANIMATED, 0);
  CheckEqualsL(TM_NONE, TempleNeed(TS_RAISE, ch), 'animated dead to raise');
  Fresh(TC_STONED, 0);
  CheckEqualsL(TM_IS_STONED, TempleNeed(TS_CURE_LIGHT, ch), 'stoned');
  CheckEqualsL(TM_NONE, TempleNeed(TS_STONE, ch), 'stoned to unstone');
  Fresh(TC_GONE, 0);
  CheckEqualsL(TM_CANNOT_HEAL, TempleNeed(TS_CURE_LIGHT, ch), 'gone');
  Fresh(TC_OKAY, TF_BLIND or TF_DISEASED or TF_POISONED or TF_CURSED or TF_DRAINED);
  CheckEqualsL(TM_NONE, TempleNeed(TS_CURE_BLIND, ch), 'blind');
  CheckEqualsL(TM_NONE, TempleNeed(TS_CURE_DISEASE, ch), 'diseased');
  CheckEqualsL(TM_NONE, TempleNeed(TS_NEUTRALIZE, ch), 'poisoned');
  CheckEqualsL(TM_NONE, TempleNeed(TS_REMOVE_CURSE, ch), 'cursed');
  CheckEqualsL(TM_NONE, TempleNeed(TS_RESTORE, ch), 'drained');

  { refusals }
  Fresh(TC_OKAY, 0);
  for i := 0 to TS_LAST do
    CheckEqualsL(TM_NONE, TempleRefusal(gold, i, ch), 'no refusal of the living ' + NumStr(i));
  Fresh(TC_GONE, 0);
  CheckEqualsL(TM_GONE, TempleRefusal(gold, TS_RAISE, ch), 'gone is beyond Raise Dead');
  CheckEqualsL(TM_GONE, TempleRefusal(gold, TS_RESURRECT, ch), 'gone is beyond Resurrection');
  CheckEqualsL(TM_NONE, TempleRefusal(gold, TS_CURE_LIGHT, ch), 'a cure does not refuse the gone');
  Fresh(TC_DEAD, TF_POISONED);
  CheckEqualsL(TM_STILL_POISONED, TempleRefusal(gold, TS_RAISE, ch), 'a poisoned corpse');
  CheckEqualsL(TM_NONE, TempleRefusal(gold, TS_RESURRECT, ch), 'Resurrection cures the poison');
  Fresh(TC_ANIMATED, TF_POISONED);
  CheckEqualsL(TM_NONE, TempleRefusal(gold, TS_RAISE, ch), 'the animated dead are raised poisoned or not');
  Fresh(TC_DEAD, 0);
  ch.conPerm := 0;
  CheckEqualsL(TM_NO_CON, TempleRefusal(gold, TS_RAISE, ch), 'no Constitution left');
  CheckEqualsL(TM_NO_CON, TempleRefusal(gold, TS_RESURRECT, ch), 'no Constitution left to resurrect');
  Fresh(TC_DEAD, 0);
  ch.race := RACE_ELF;
  CheckEqualsL(TM_ELF, TempleRefusal(gold, TS_RAISE, ch), 'an elf cannot be raised');
  CheckEqualsL(TM_ELF, TempleRefusal(gold, TS_RESURRECT, ch), 'nor resurrected');
  ch.race := RACE_SILVANESTI;
  CheckEqualsL(TM_ELF, TempleRefusal(steel, TS_RAISE, ch), 'a Silvanesti cannot be raised');
  CheckEqualsL(TM_ELF, TempleRefusal(steel, TS_RESURRECT, ch), 'nor resurrected on Krynn');
  ch.race := RACE_QUALINESTI;
  CheckEqualsL(TM_ELF, TempleRefusal(steel, TS_RESURRECT, ch), 'nor a Qualinesti');
  ch.race := RACE_HALFELF;
  CheckEqualsL(TM_NONE, TempleRefusal(steel, TS_RAISE, ch), 'a half-elf can be raised on Krynn');
  ch.race := RACE_MONSTER;
  CheckEqualsL(TM_RACE, TempleRefusal(gold, TS_RAISE, ch), 'a monster cannot be raised');
  CheckEqualsL(TM_RACE, TempleRefusal(gold, TS_RESURRECT, ch), 'nor resurrected');
  ch.race := RACE_HUMAN;
  gold.raiseMinLevel := 6;
  CheckEqualsL(TM_LEVEL, TempleRefusal(gold, TS_RAISE, ch), 'below the least level');
  CheckEqualsL(TM_NONE, TempleRefusal(gold, TS_RESURRECT, ch), 'Resurrection''s least level is its own');
  gold.raiseMinLevel := 0;

  { dice }
  Fresh(TC_OKAY, 0);
  TempleDice(gold, TS_CURE_LIGHT, ch, n, sides, plus);
  Check((n = 1) and (sides = 8) and (plus = 0), 'Cure Light Wounds 1d8');
  TempleDice(gold, TS_CURE_SERIOUS, ch, n, sides, plus);
  Check((n = 2) and (sides = 8) and (plus = 1), 'Cure Serious Wounds 2d8+1');
  TempleDice(gold, TS_CURE_CRITICAL, ch, n, sides, plus);
  Check((n = 3) and (sides = 8) and (plus = 3), 'Cure Critical Wounds 3d8+3');
  TempleDice(gold, TS_HEAL, ch, n, sides, plus);
  Check((n = 1) and (sides = 4), 'Heal 1d4');
  TempleDice(gold, TS_RAISE, ch, n, sides, plus);
  CheckEqualsL(0, n, 'no survival roll for the living');
  TempleDice(gold, TS_CURE_BLIND, ch, n, sides, plus);
  CheckEqualsL(0, n, 'Cure Blindness rolls nothing');
  Fresh(TC_DEAD, 0);
  TempleDice(gold, TS_RESURRECT, ch, n, sides, plus);
  Check((n = 1) and (sides = 100), 'resurrection survival d100');
  gold.survivalRoll := False;
  TempleDice(gold, TS_RAISE, ch, n, sides, plus);
  CheckEqualsL(0, n, 'no survival roll when the rules make none');
  gold.survivalRoll := True;
  Fresh(TC_STONED, 0);
  TempleDice(gold, TS_STONE, ch, n, sides, plus);
  Check((n = 1) and (sides = 100), 'system shock d100');

  { deeds }
  Fresh(TC_OKAY, TF_BLIND);
  TempleDeed(gold, TS_CURE_BLIND, ch, 0, d);
  Check((d.acts = TA_BLIND) and (d.msg = TM_SEES), 'Cure Blindness');
  Fresh(TC_OKAY, 0);
  TempleDeed(gold, TS_CURE_BLIND, ch, 0, d);
  Check((d.acts = TA_BLIND) and (d.msg = TM_NOT_HELPED), 'Cure Blindness bought anyway does not help');
  Fresh(TC_OKAY, TF_DISEASED);
  TempleDeed(gold, TS_CURE_DISEASE, ch, 0, d);
  Check((d.acts = TA_DISEASE) and (d.msg = TM_CURED), 'Cure Disease (with the Strength it took)');
  Fresh(TC_OKAY, 0);
  TempleDeed(gold, TS_CURE_CRITICAL, ch, 17, d);
  Check((d.acts = TA_HEAL_HP) and (d.hp = 17) and (d.msg = TM_BY_HP), 'Cure Critical Wounds heals the roll');
  Fresh(TC_OKAY, TF_BLIND or TF_FEEBLE);
  TempleDeed(gold, TS_HEAL, ch, 3, d);
  Check(d.acts = TA_BLIND or TA_DISEASE or TA_FEEBLE or TA_HEAL_HP, 'Heal cures blindness, disease and Feeblemind');
  CheckEqualsL(7, d.hp, 'Heal leaves 1d4 of the missing hit points');
  CheckEqualsL(TM_FULLY_HEALED, d.msg, 'wounds and an ailment: fully healed');
  ch.hp := 29;
  TempleDeed(gold, TS_HEAL, ch, 3, d);
  CheckEqualsL(0, d.hp, 'Heal gives nothing when fewer than the roll are missing');
  CheckEqualsL(TM_FULLY_HEALED, d.msg, 'Heal still cures');
  Fresh(TC_OKAY, 0);
  TempleDeed(gold, TS_HEAL, ch, 3, d);
  CheckEqualsL(TM_HEALED, d.msg, 'wounds alone: healed');
  ch.hp := ch.hpMax;
  ch.flags := TF_BLIND;
  TempleDeed(gold, TS_HEAL, ch, 3, d);
  CheckEqualsL(TM_HEALED, d.msg, 'an ailment alone: healed');
  Fresh(TC_DEAD, TF_POISONED);
  TempleDeed(gold, TS_NEUTRALIZE, ch, 0, d);
  Check((d.acts = TA_POISON or TA_STATUS) and (d.status = TC_OKAY) and (d.msg = TM_UNPOISONED),
        'the poison''s corpse lives');
  ch.hp := 0;
  TempleDeed(gold, TS_NEUTRALIZE, ch, 0, d);
  Check((d.acts and TA_SET_HP <> 0) and (d.hp = 1), 'at 1 hit point at least');
  Fresh(TC_DEAD, TF_POISONED or TF_SLOW_POISON);
  TempleDeed(gold, TS_NEUTRALIZE, ch, 0, d);
  CheckEqualsL(TA_POISON, d.acts, 'a death under Slow Poison was a wound''s');
  Fresh(TC_STONED, TF_POISONED);
  TempleDeed(gold, TS_NEUTRALIZE, ch, 0, d);
  CheckEqualsL(TA_POISON, d.acts, 'the stoned stay stone');
  Fresh(TC_ANIMATED, TF_POISONED);
  TempleDeed(gold, TS_NEUTRALIZE, ch, 0, d);
  CheckEqualsL(TA_POISON, d.acts, 'the animated stay animated');
  Fresh(TC_OKAY, TF_SLOW_POISON);
  TempleDeed(gold, TS_NEUTRALIZE, ch, 0, d);
  Check((d.acts = TA_POISON) and (d.msg = TM_NOT_HELPED), 'Slow Poison alone ends, unhelped');

  Fresh(TC_DEAD, 0);
  TempleDeed(gold, TS_RAISE, ch, 95, d);
  Check((d.status = TC_GONE) and (d.acts and TA_STATUS <> 0) and (d.msg = TM_NO_SURVIVE),
        'Con 15 survives on 94: 95 is gone for good');
  TempleDeed(steel, TS_RAISE, ch, 95, d);
  Check((d.acts = 0) and (d.msg = TM_NO_SURVIVE), 'or stays dead');
  TempleDeed(gold, TS_RAISE, ch, 94, d);
  Check((d.status = TC_OKAY) and (d.hp = 1) and (d.conLoss = 1) and (d.msg = TM_RAISED), '94 is raised at 1 hp');
  Check(d.acts = TA_ANIMATE or TA_POISON or TA_STATUS or TA_RAISED or TA_LOSE_CON or TA_SET_HP, 'Raise Dead''s acts');
  TempleDeed(gold, TS_RESURRECT, ch, 94, d);
  Check((d.acts and TA_FULL_HP <> 0) and (d.acts and TA_SET_HP = 0) and (d.conLoss = 1) and (d.msg = TM_RESURRECTED),
        'resurrected at full hit points');
  ch.conPerm := 3;
  TempleDeed(gold, TS_RAISE, ch, 1, d);
  Check((d.conLoss = 0) and (d.acts and TA_LOSE_CON = 0), 'Constitution 3 loses nothing');
  ch.conPerm := 4;
  gold.raiseConLoss := 2;
  TempleDeed(gold, TS_RAISE, ch, 1, d);
  CheckEqualsL(1, d.conLoss, 'never below 3');
  gold.raiseConLoss := 1;
  ch.conPerm := 15;
  gold.survivalRoll := False;
  TempleDeed(gold, TS_RAISE, ch, 0, d);
  CheckEqualsL(TC_OKAY, d.status, 'raised without a roll');
  gold.survivalRoll := True;
  Fresh(TC_OKAY, 0);
  TempleDeed(gold, TS_RAISE, ch, 0, d);
  Check((d.acts = 0) and (d.msg = TM_NOT_HELPED), 'raising the living changes nothing');
  Fresh(TC_DEAD, 0);
  ch.race := RACE_ELF;
  TempleDeed(gold, TS_RAISE, ch, 1, d);
  CheckEqualsL(0, d.acts, 'a refused raise does nothing');

  Fresh(TC_STONED, 0);
  ch.conCur := 15;
  TempleDeed(gold, TS_STONE, ch, 92, d);
  Check((d.status = TC_DEAD) and (d.hp = 0) and (d.acts and TA_DIED <> 0) and (d.msg = TM_SHOCK),
        'Con 15 shocks on 92');
  TempleDeed(gold, TS_STONE, ch, 91, d);
  Check((d.status = TC_OKAY) and (d.hp = 1) and (d.msg = TM_FLESH), 'and survives 91');
  gold.stoneShock := False;
  TempleDeed(gold, TS_STONE, ch, 100, d);
  CheckEqualsL(TC_OKAY, d.status, 'no shock when the rules roll none');
  gold.stoneShock := True;
  Fresh(TC_OKAY, TF_CURSED);
  TempleDeed(gold, TS_REMOVE_CURSE, ch, 0, d);
  Check((d.acts = TA_CURSE) and (d.msg = TM_UNCURSED), 'Remove Curse');
  Fresh(TC_OKAY, TF_DRAINED);
  TempleDeed(gold, TS_RESTORE, ch, 0, d);
  Check((d.acts = TA_RESTORE) and (d.msg = TM_CURED), 'Restoration');

  { the course of a sale }
  Fresh(TC_OKAY, TF_BLIND);
  TempleService(gold, TS_CURE_BLIND, io);
  Check((asked = 0) and (paid = 1000) and (acted = 1), 'a needed cure is paid for and done');
  CheckEqualsS('Cure Blindness will only cost 1000 gold pieces.', quoted, 'its quote');
  CheckEqualsS('is cured.', said, 'and its report');
  Check(ch.flags and TF_BLIND = 0, 'the blindness is gone');

  Fresh(TC_OKAY, 0);
  answer := False;
  TempleService(gold, TS_CURE_BLIND, io);
  Check((asked = 1) and (paid = 0) and (acted = 0), 'an unneeded cure asks, and No ends it');
  CheckEqualsS('is not blind.', said, 'saying why');
  Fresh(TC_OKAY, 0);
  TempleService(gold, TS_CURE_BLIND, io);
  Check((asked = 1) and (paid = 1000), 'Yes buys it anyway');
  CheckEqualsS('is not helped.', said, 'and it does not help');

  Fresh(TC_OKAY, TF_BLIND);
  payOk := False;
  TempleService(gold, TS_CURE_BLIND, io);
  Check((acted = 0) and (ch.flags and TF_BLIND <> 0), 'an unpaid cure does nothing');

  Fresh(TC_OKAY, 0);
  TempleService(gratis, TS_CURE_BLIND, io);
  Check((asked = 0) and (acted = 0) and (quoted = ''), 'a free temple tells, asks nothing and quotes nothing');
  CheckEqualsS('is not blind.', said, 'what it tells');
  Fresh(TC_OKAY, TF_POISONED);
  TempleService(gratis, TS_NEUTRALIZE, io);
  Check((paid = 0) and (quoted = '') and (acted = 1) and (said = 'is cured.'), 'and cures for nothing');

  Fresh(TC_OKAY, 0);
  dice := 5;
  TempleService(gold, TS_CURE_SERIOUS, io);
  CheckEqualsS('2d8', lastRolled, 'Cure Serious Wounds rolls 2d8');
  CheckEqualsL(26, ch.hp, '5 + 1 hit points');
  CheckEqualsS('is cured.', said, 'the hit points rose');
  CheckEqualsL(350, paid, 'for 350');
  ch.hp := ch.hpMax;
  TempleService(gold, TS_CURE_LIGHT, io);
  Check((asked = 1) and (said = 'is not helped.'), 'a full character asked first, then not helped');
  Fresh(TC_DEAD, 0);
  TempleService(gold, TS_CURE_LIGHT, io);
  Check((paid = 100) and (said = 'is not helped.'), 'the dead are not helped');

  Fresh(TC_DEAD, TF_POISONED);
  TempleService(gold, TS_RAISE, io);
  Check((asked = 0) and (paid = 0) and (acted = 0), 'a refusal is unpaid');
  CheckEqualsS('is still poisoned.', said, 'and says why');
  Fresh(TC_DEAD, 0);
  ch.race := RACE_ELF;
  TempleService(gold, TS_RAISE, io);
  Check((paid = 0) and (said = 'is an elf and cannot be raised.'), 'nor is an elf charged');
  TempleService(gold, TS_RESURRECT, io);
  Check((paid = 0) and (acted = 0) and (ch.status = TC_DEAD) and (said = 'is an elf and cannot be raised.'),
        'nor resurrected, unpaid');
  ch.race := RACE_HALFELF;
  TempleService(gold, TS_RESURRECT, io);
  Check((paid = 11000) and (ch.status = TC_OKAY) and (ch.hp = ch.hpMax), 'a half-elf is resurrected');
  CheckEqualsL(14, ch.conPerm, 'for a point of Constitution');
  CheckEqualsS('is resurrected.', said, 'resurrected');
  Fresh(TC_DEAD, 0);
  ch.hp := 0;
  dice := 50;
  TempleService(steel, TS_RAISE, io);
  Check((paid = 2750) and (ch.status = TC_OKAY) and (ch.hp = 1) and (ch.conPerm = 14), 'raised on Krynn');
  CheckEqualsS('1d100', lastRolled, 'after a survival roll');
  Fresh(TC_DEAD, 0);
  dice := 100;
  TempleService(gold, TS_RAISE, io);
  Check((paid = 5500) and (ch.status = TC_GONE) and (said = 'does not survive.'), 'a failure is gone, paid for');
  Fresh(TC_GONE, 0);
  TempleService(gold, TS_RESURRECT, io);
  Check((paid = 0) and (said = 'is beyond help.'), 'the gone are beyond help');

  Fresh(TC_STONED, 0);
  dice := 99;
  TempleService(gold, TS_STONE, io);
  Check((ch.status = TC_DEAD) and (paid = 2000) and (said = 'DOESN''T SURVIVE THE TRANSFORMATION.'),
        'system shock kills');
  Fresh(TC_OKAY, TF_DRAINED);
  TempleService(steel, TS_RESTORE, io);
  Check((paid = 3500) and (ch.flags = 0) and (said = 'is cured.'), 'Restoration for 3500 steel');

  { a game's own words, and the shared ones for the rest }
  for i := TM_CURED to TM_LAST do
    Check(TempleText(i) <> '', 'shared words for ' + NumStr(i));
  for i := TM_SEES to TM_FLESH do
    CheckEqualsS('is cured.', TempleText(i), 'a cure''s own words default to the shared ' + NumStr(i));
  CheckEqualsS('', NoWords(TM_SEES), 'NoWords has none');
  ownWords := True;
  Fresh(TC_OKAY, TF_BLIND);
  TempleService(gratis, TS_CURE_BLIND, io);
  CheckEqualsS('can see!', said, 'the game''s Cure Blindness');
  Fresh(TC_GONE, 0);
  TempleService(gratis, TS_RAISE, io);
  CheckEqualsS('is not here', said, 'the game''s refusal');
  Fresh(TC_OKAY, 0);
  TempleService(gratis, TS_CURE_BLIND, io);
  CheckEqualsS('is not blind.', said, 'the shared words where the game has none');
  ownWords := False;

  { Pool of Radiance's temple (Temple.TempleRules): the twelve services at the 1st-edition prices, a tenth off at the
    temple Dirten rebuilds }
  Temple.TempleRules(por);
  CheckEqualsL(5000, por.price[TS_HEAL], 'PoR: Heal 5000 gold');
  CheckEqualsL(11000, por.price[TS_RESURRECT], 'PoR: Resurrection 11000');
  CheckEqualsL(7000, por.price[TS_RESTORE], 'PoR: Restoration 7000');
  CheckEqualsL(5500, por.price[TS_RAISE], 'PoR: Raise Dead 5500, as SSI charged');
  for i := 0 to TS_LAST do
    Check(Offers(por, i), 'PoR sells service ' + NumStr(i));
  Check(por.failGone, 'PoR: a failed survival roll is gone for good (#752)');
  tenth := por;
  for i := 0 to TS_LAST do
    tenth.price[i] := MoneyCal.TemplePrice(por.price[i], MoneyCal.TEMPLE_TENTH_OFF);
  CheckEqualsL(6300, tenth.price[TS_RESTORE], 'a tenth off: Restoration 6300');
  CheckEqualsL(RACE_HUMAN, Temple.CanonRace(C_RACE.HUMAN), 'PoR''s human is the canonical human');
  CheckEqualsL(RACE_ELF, Temple.CanonRace(C_RACE.ELF), 'its elf');
  CheckEqualsL(RACE_HALFORC, Temple.CanonRace(C_RACE.HALF_ORC), 'its half-orc');
  CheckEqualsL(RACE_MONSTER, Temple.CanonRace(C_RACE.MONSTER), 'race 0 is the monster');
  CheckEqualsL(RACE_MONSTER, Temple.CanonRace(99), 'and so is any other value');
  Fresh(TC_DEAD, 0);
  ch.race := RACE_MONSTER;
  CheckEqualsL(TM_NONE, TempleRefusal(por, TS_RAISE, ch), 'PoR raises a race-0 corpse, as SSI did (#1089)');
  ch.race := RACE_ELF;
  CheckEqualsL(TM_ELF, TempleRefusal(por, TS_RAISE, ch), 'but never an elf (#61)');

  { Repair's plan }
  Fresh(TC_OKAY, TF_DISEASED or TF_DRAINED);
  ch.drained := 2;
  RepairPlan(por, ch, plan);
  Check((plan.count[TS_RESTORE] = 2) and (plan.count[TS_HEAL] = 1) and (plan.count[TS_CURE_DISEASE] = 0),
        'drained twice, diseased and wounded: two Restorations and a Heal, which cures the disease');
  CheckEqualsL(19000, RepairCost(por, plan), 'for 7000 + 7000 + 5000');
  CheckEqualsL(17100, RepairCost(tenth, plan), 'a tenth less at Dirten''s temple');
  CheckEqualsL(TM_NONE, plan.refusal, 'nothing refused');
  ch.hp := ch.hpMax;
  RepairPlan(por, ch, plan);
  Check((plan.count[TS_HEAL] = 0) and (plan.count[TS_CURE_DISEASE] = 1), 'unwounded: Cure Disease alone');
  Fresh(TC_OKAY, TF_BLIND);
  ch.hp := ch.hpMax;
  RepairPlan(por, ch, plan);
  CheckEqualsL(1000, RepairCost(por, plan), 'blind alone: Cure Blindness');
  Fresh(TC_OKAY, TF_ROT);
  ch.hp := ch.hpMax;
  RepairPlan(por, ch, plan);
  CheckEqualsL(1, plan.count[TS_HEAL], 'mummy rot: Heal, unwounded or not');
  Fresh(TC_OKAY, 0);
  ch.hp := ch.hpMax;
  RepairPlan(por, ch, plan);
  CheckEqualsL(0, RepairCost(por, plan), 'a whole character needs nothing');
  Fresh(TC_OKAY, TF_CURSED);
  ch.hp := ch.hpMax;
  RepairPlan(por, ch, plan);
  CheckEqualsL(0, RepairCost(por, plan), 'nor is a curse Repair''s, as it is not Pools''');
  Fresh(TC_DEAD, TF_POISONED);
  RepairPlan(por, ch, plan);
  Check((plan.count[TS_NEUTRALIZE] = 1) and (plan.count[TS_RAISE] = 0) and (plan.count[TS_HEAL] = 1),
        'the poison''s corpse: Neutralize Poison brings it back, then Heal');
  Fresh(TC_DEAD, TF_POISONED or TF_SLOW_POISON);
  RepairPlan(por, ch, plan);
  Check((plan.count[TS_NEUTRALIZE] = 1) and (plan.count[TS_RAISE] = 1) and (plan.count[TS_HEAL] = 1),
        'a wound''s corpse under Slow Poison: the poison goes first, so Raise Dead takes it');
  CheckEqualsL(11500, RepairCost(por, plan), '1000 + 5500 + 5000');
  Fresh(TC_DEAD, 0);
  ch.race := RACE_ELF;
  ch.flags := TF_BLIND;
  RepairPlan(por, ch, plan);
  Check((plan.refusal = TM_ELF) and (RepairCost(por, plan) = 0), 'a dead elf is refused, and nothing else is bought');
  Fresh(TC_GONE, 0);
  RepairPlan(por, ch, plan);
  Check((plan.refusal = TM_GONE) and (RepairCost(por, plan) = 0), 'the gone are beyond help');
  Fresh(TC_ANIMATED, TF_BLIND);
  RepairPlan(por, ch, plan);
  Check((plan.refusal = TM_NONE) and (RepairCost(por, plan) = 0),
        'the animated dead are left as they are: Raise Dead is bought for one on its own');
  Fresh(TC_STONED, 0);
  RepairPlan(por, ch, plan);
  Check((plan.count[TS_STONE] = 1) and (plan.count[TS_HEAL] = 1), 'the stoned: Stone to Flesh, then Heal');
  CheckEqualsS('Repairing the party will cost 7000 gold pieces.', RepairQuote(por, 7000), 'Repair''s quote');

  { Repair's course }
  Fresh(TC_OKAY, TF_DISEASED);
  ch.hp := 3;
  RepairPlan(por, ch, plan);
  undone := TempleRepair(por, plan, io);
  Check((asked = 0) and (paid = 0), 'Repair asks nothing and takes no fee of its own');
  Check((ch.hp = ch.hpMax) and (ch.flags = 0), 'Heal gives back every missing hit point and the disease goes');
  CheckEqualsS('is cured.', said, 'and says so');
  CheckEqualsL(0, undone, 'all of it done');
  Fresh(TC_DEAD, 0);
  dice := 50;
  RepairPlan(por, ch, plan);
  undone := TempleRepair(por, plan, io);
  Check((ch.status = TC_OKAY) and (ch.hp = ch.hpMax) and (ch.conPerm = 14),
        'raised, a Constitution point gone, healed');
  CheckEqualsS('1d100', lastRolled, 'the survival roll is made');
  Fresh(TC_DEAD, 0);
  dice := 100;
  RepairPlan(por, ch, plan);
  undone := TempleRepair(por, plan, io);
  Check(ch.status = TC_GONE, 'a failed survival roll is gone for good');
  CheckEqualsS('does not survive.', said, 'and is said');
  CheckEqualsL(5000, undone, 'the Heal not given is the priests'' to give back');
  Fresh(TC_STONED, 0);
  dice := 99;
  RepairPlan(por, ch, plan);
  undone := TempleRepair(por, plan, io);
  Check((ch.status = TC_DEAD) and (said = 'DOESN''T SURVIVE THE TRANSFORMATION.'), 'system shock is rolled (#1004)');
  CheckEqualsL(5000, undone, 'and the Heal is given back');
  Fresh(TC_OKAY, 0);
  ch.hp := ch.hpMax;
  RepairPlan(por, ch, plan);
  undone := TempleRepair(por, plan, io);
  Check((acted = 0) and (said = ''), 'an empty plan does and says nothing');

  steel.price[TS_HEAL] := TP_NONE;
  Fresh(TC_OKAY, 0);
  TempleService(steel, TS_HEAL, io);
  Check((asked = 0) and (paid = 0) and (acted = 0) and (said = ''), 'a service not sold does nothing');
  TestKit.Done;
end.

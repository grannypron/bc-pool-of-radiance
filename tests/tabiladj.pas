{ Tests for AbilAdj: the Strength scale and its to-hit, damage and carrying tables, and the Dexterity adjustments. }
program TAbilAdj;

uses Types, AbilAdj, StrUtil, TestKit;

var
  c: Types.PCharRecord;

{ Set the creature's Strength: str, with exc as its exceptional strength (100 is 18/00). }
procedure SetStr(str, exc: Byte);
begin
  c^.strCur := str;
  c^.strExc := exc;
end;

function StrName: String;
begin
  if c^.strExc = 0 then
    StrName := 'Strength ' + StrUtil.NumStr(c^.strCur)
  else
    StrName := 'Strength ' + StrUtil.NumStr(c^.strCur) + '/' + StrUtil.ZeroPad2(c^.strExc);
end;

{ Check the translated scale, to-hit, damage and weight allowance at the creature's Strength. }
procedure CheckStr(ts: Byte; hit, dmg: ShortInt; weight: Integer);
begin
  TestKit.CheckEqualsL(ts, AbilAdj.TranslatedStrength(c), StrName + ': the translated scale');
  TestKit.CheckEqualsL(hit, AbilAdj.StrToHitAdjust(c), StrName + ': to-hit');
  TestKit.CheckEqualsL(dmg, AbilAdj.StrDamageAdjust(c), StrName + ': damage');
  TestKit.CheckEqualsL(weight, AbilAdj.WeightAllowance(c), StrName + ': weight allowance');
end;

procedure CheckDex(dex: Byte; missile, armor: ShortInt);
begin
  c^.dexCur := dex;
  TestKit.CheckEqualsL(missile, AbilAdj.DexMissileAdjust(c), 'Dexterity ' + StrUtil.NumStr(dex) + ': missiles');
  TestKit.CheckEqualsL(armor, AbilAdj.DexterityArmorAdjustment(c), 'Dexterity ' + StrUtil.NumStr(dex) + ': armor');
end;

begin
  TestKit.Start('TABILADJ');
  GetMem(c, SizeOf(Types.TCharRecord));
  FillChar(c^, SizeOf(Types.TCharRecord), 0);
  c^.useStrength := 1;

  SetStr(3, 0); CheckStr(3, -3, -1, -350);
  SetStr(5, 0); CheckStr(5, -2, -1, -250);
  SetStr(7, 0); CheckStr(7, -1, 0, -150);
  SetStr(8, 0); CheckStr(8, 0, 0, 0);
  SetStr(12, 0); CheckStr(12, 0, 0, 100);
  SetStr(14, 0); CheckStr(14, 0, 0, 200);
  SetStr(16, 0); CheckStr(16, 0, 1, 350);
  SetStr(17, 0); CheckStr(17, 1, 1, 500);
  SetStr(18, 0); CheckStr(18, 1, 2, 750);
  SetStr(18, 1); CheckStr(19, 1, 3, 1000);
  SetStr(18, 50); CheckStr(19, 1, 3, 1000);
  SetStr(18, 51); CheckStr(20, 2, 3, 1250);
  SetStr(18, 75); CheckStr(20, 2, 3, 1250);
  SetStr(18, 76); CheckStr(21, 2, 4, 1500);
  SetStr(18, 90); CheckStr(21, 2, 4, 1500);
  SetStr(18, 91); CheckStr(22, 2, 5, 2000);
  SetStr(18, 99); CheckStr(22, 2, 5, 2000);
  SetStr(18, 100); CheckStr(23, 3, 6, 3000);
  SetStr(18, 255); CheckStr(23, 3, 6, 3000);
  SetStr(19, 0); CheckStr(24, 3, 7, 4500);
  SetStr(20, 0); CheckStr(25, 3, 8, 5000);
  SetStr(21, 0); CheckStr(26, 4, 9, 6000);
  SetStr(22, 0); CheckStr(27, 4, 10, 7500);
  SetStr(23, 0); CheckStr(28, 5, 11, 9000);
  SetStr(25, 0); CheckStr(30, 7, 14, 15000);
  SetStr(30, 0); CheckStr(30, 7, 14, 15000);
  SetStr(0, 0); CheckStr(0, 0, 0, 0);

  { without the Strength bonus, no to-hit or damage adjustment; carrying is unchanged }
  c^.useStrength := 0;
  SetStr(18, 100);
  TestKit.CheckEqualsL(0, AbilAdj.StrToHitAdjust(c), 'no Strength bonus: no to-hit adjustment');
  TestKit.CheckEqualsL(0, AbilAdj.StrDamageAdjust(c), 'no Strength bonus: no damage adjustment');
  TestKit.CheckEqualsL(3000, AbilAdj.WeightAllowance(c), 'no Strength bonus: the same weight allowance');
  SetStr(3, 0);
  TestKit.CheckEqualsL(0, AbilAdj.StrToHitAdjust(c), 'no Strength bonus: no to-hit penalty either');

  CheckDex(0, -4, 0);
  CheckDex(1, -4, -4);
  CheckDex(3, -3, -4);
  CheckDex(4, -2, -3);
  CheckDex(5, -1, -2);
  CheckDex(6, 0, -1);
  CheckDex(7, 0, 0);
  CheckDex(14, 0, 0);
  CheckDex(15, 0, 1);
  CheckDex(16, 1, 2);
  CheckDex(18, 3, 4);
  CheckDex(19, 3, 4);
  CheckDex(21, 4, 5);
  CheckDex(24, 5, 6);
  CheckDex(25, 5, 6);

  { the Constitution save bonus, +1 per 3 1/2 points }
  TestKit.CheckEqualsL(0, AbilAdj.ConSaveBonus(3), 'Constitution 3: no save bonus');
  TestKit.CheckEqualsL(1, AbilAdj.ConSaveBonus(4), 'Constitution 4: +1');
  TestKit.CheckEqualsL(1, AbilAdj.ConSaveBonus(6), 'Constitution 6: +1');
  TestKit.CheckEqualsL(2, AbilAdj.ConSaveBonus(7), 'Constitution 7: +2');
  TestKit.CheckEqualsL(2, AbilAdj.ConSaveBonus(10), 'Constitution 10: +2');
  TestKit.CheckEqualsL(3, AbilAdj.ConSaveBonus(11), 'Constitution 11: +3');
  TestKit.CheckEqualsL(3, AbilAdj.ConSaveBonus(13), 'Constitution 13: +3');
  TestKit.CheckEqualsL(4, AbilAdj.ConSaveBonus(14), 'Constitution 14: +4');
  TestKit.CheckEqualsL(4, AbilAdj.ConSaveBonus(17), 'Constitution 17: +4');
  TestKit.CheckEqualsL(5, AbilAdj.ConSaveBonus(18), 'Constitution 18: +5');
  TestKit.CheckEqualsL(5, AbilAdj.ConSaveBonus(20), 'Constitution 20: +5');
  TestKit.CheckEqualsL(6, AbilAdj.ConSaveBonus(21), 'Constitution 21: +6');
  TestKit.CheckEqualsL(6, AbilAdj.ConSaveBonus(24), 'Constitution 24: +6');

  FreeMem(c, SizeOf(Types.TCharRecord));
  TestKit.Done;
end.

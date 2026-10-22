{ Tests DiskRec's copies between the records and their disk form: every byte that is not a pointer arrives where SSI's
  layout has it (tests/treclay.pas pins the offsets), a pointer goes to disk as 4 zero bytes once the game has cleared
  it, and a record read back has its fields and nil pointers. }
{$I COMPILER.INC}
program TDiskRec;

uses Types, C_MONEY, C_EQUIP, DiskRec, TestKit;

var
  ch: Types.TCharRecord;
  back: Types.TCharRecord;
  chDisk: DiskRec.TCharDisk;
  it: Types.TItemRec;
  itBack: Types.TItemRec;
  itDisk: DiskRec.TItemDisk;
  ef: Types.TEffectRec;
  efBack: Types.TEffectRec;
  efDisk: DiskRec.TEffectDisk;
  i: Byte;
  zeros: Boolean;

begin
  TestKit.Start('TDISKREC');
  FillChar(ch, SizeOf(ch), $5A);
  ch.name := 'Tarl';
  ch.effectsAddr := nil;
  ch.itemsAddr := nil;
  FillChar(ch.equipped, SizeOf(ch.equipped), 0);
  ch.nextCharAddr := nil;
  ch.combatAddr := nil;
  ch.gender := 1;
  ch.coins[C_MONEY.PLATINUM] := 1234;
  ch.experience := 987654;
  ch.iconColors[5] := $C4;
  ch.portraitBody := 7;
  ch.movementCur := 12;
  FillChar(chDisk, SizeOf(chDisk), $FF);
  DiskRec.CharToDisk(ch, chDisk);
  TestKit.Check(chDisk[0] = 4, 'the name''s length is at 0');
  TestKit.Check(chDisk[158] = 1, 'gender is at 158');
  TestKit.Check(chDisk[187 + 1] = 7, 'portraitBody is at 188');
  zeros := True;
  for i := 127 to 130 do
    zeros := zeros and (chDisk[i] = 0);
  TestKit.Check(zeros, 'effectsAddr is 4 zero bytes at 127');
  TestKit.CheckEqualsL(1234, chDisk[136 + 2 * C_MONEY.PLATINUM] + 256 * chDisk[137 + 2 * C_MONEY.PLATINUM],
                       'platinum is where coins has it');
  FillChar(back, SizeOf(back), $A5);
  DiskRec.CharFromDisk(chDisk, back);
  TestKit.CheckEqualsS('Tarl', back.name, 'the name comes back');
  TestKit.CheckEqualsL(987654, back.experience, 'experience comes back');
  TestKit.CheckEqualsL($C4, back.iconColors[5], 'iconColors comes back');
  TestKit.CheckEqualsL(12, back.movementCur, 'movementCur, the last field, comes back');
  TestKit.CheckEqualsL(1, back.genderSp, 'genderSp is gender');
  TestKit.CheckEqualsL($C4, back.iconColors1[6], 'iconColors1 is iconColors');
  TestKit.Check((back.effectsAddr = nil) and (back.itemsAddr = nil) and (back.equipped[C_EQUIP.BOLT] = nil) and
                (back.nextCharAddr = nil) and (back.combatAddr = nil), 'the pointers come back nil');

  FillChar(it, SizeOf(it), $33);
  it.name := 'Long Sword';
  it.next := nil;
  it.value := 15;
  it.special := 9;
  DiskRec.ItemToDisk(it, itDisk);
  TestKit.Check((itDisk[42] = 0) and (itDisk[45] = 0), 'next is 4 zero bytes at 42');
  TestKit.Check((itDisk[58] = 15) and (itDisk[62] = 9), 'value at 58 and special at 62');
  DiskRec.ItemFromDisk(itDisk, itBack);
  TestKit.CheckEqualsS('Long Sword', itBack.name, 'the item''s name comes back');
  TestKit.CheckEqualsL(9, itBack.special, 'special, the last field, comes back');
  TestKit.Check(itBack.next = nil, 'next comes back nil');

  FillChar(ef, SizeOf(ef), $11);
  ef.id := 42;
  ef.duration := 300;
  ef.next := nil;
  DiskRec.EffectToDisk(ef, efDisk);
  TestKit.Check((efDisk[0] = 42) and (efDisk[1] = 44) and (efDisk[2] = 1), 'id at 0, duration at 1');
  TestKit.Check((efDisk[5] = 0) and (efDisk[8] = 0), 'next is 4 zero bytes at 5');
  DiskRec.EffectFromDisk(efDisk, efBack);
  TestKit.CheckEqualsL(300, efBack.duration, 'duration comes back');
  TestKit.Check(efBack.next = nil, 'next comes back nil');
  TestKit.Done;
end.

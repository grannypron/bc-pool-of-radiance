{ Tests for RandItem: the template items exactly, and the random weapons, armor and javelins by their properties over
  many rolls with RandSeed fixed. }
program TRandItm;

uses Types, GDConsts, C_Item, RandItem, StrUtil, TestKit;

var
  it: Types.TItemRec;
  i: Integer;
  j: Byte;
  plain: Integer;
  lightning: Integer;
  ok: Boolean;

{ Check it is template t of GDConsts.randomItemTemplates, with plus and saveBonus. }
procedure CheckTemplate(kind, t: Byte; plus: ShortInt; what: String);
var
  k: Byte;
  same: Boolean;
begin
  RandItem.GenerateRandomItem(kind, @it);
  with GDConsts.randomItemTemplates[t] do begin
    same := (it.weight = weight) and (it.value = value) and (it.quantity = 0);
    for k := 1 to 3 do
      same := same and (it.nameIds[k] = Lo(nameIds[k])) and (it.spells[k] = Lo(properties[k]));
  end;
  TestKit.Check(same, what + ': template ' + StrUtil.NumStr(t) + '''s name, weight, value and properties');
  TestKit.CheckEqualsL(plus, it.plus, what + ': plus');
  TestKit.CheckEqualsL(plus, it.saveBonus, what + ': save bonus');
  TestKit.CheckEqualsL(kind, it.itemType, what + ': item type');
end;

begin
  TestKit.Start('TRANDITM');
  RandSeed := 1;
  CheckTemplate(63, 10, 1, 'kind 63, Gauntlets of Ogre Power');
  CheckTemplate(67, 19, 1, 'kind 67, Cloak of Elvenkind');
  CheckTemplate(79, 8, 1, 'kind 79, Wand of Magic Missiles');
  CheckTemplate(84, 2, 1, 'kind 84, Potion of Giant Strength');
  CheckTemplate(92, 13, 2, 'kind 92, Cloak of Displacement');

  { a long sword (kind 1..59): a plus of 1..3 named "+plus", no save bonus }
  ok := True;
  for i := 1 to 200 do begin
    RandItem.GenerateRandomItem(5, @it);
    if (it.plus < 1) or (it.plus > 3) or (it.nameIds[3] <> 5) or (it.nameIds[2] <> it.plus + C_Item.NAME_PLUS_BASE) or
        (it.saveBonus <> 0) then
      ok := False;
  end;
  TestKit.Check(ok, 'a random weapon is +1..+3, named with its plus');

  { bracers (77): plus 4, 6 or 8, named AC 6, 4 or 2 }
  ok := True;
  for i := 1 to 200 do begin
    RandItem.GenerateRandomItem(77, @it);
    case it.plus of
      4: ok := ok and (it.nameIds[1] = 221);
      6: ok := ok and (it.nameIds[1] = 222);
      8: ok := ok and (it.nameIds[1] = 220);
    else
      ok := False;
    end;
  end;
  TestKit.Check(ok, 'bracers are AC 6, 4 or 2 (plus 4, 6, 8)');

  { a javelin (21): a plain one named "+plus", or one time in five a Javelin of Lightning (template 14); never the item
    named from templates 18 and 19 (POR-0165) }
  plain := 0;
  lightning := 0;
  ok := True;
  for i := 1 to 200 do begin
    RandItem.GenerateRandomItem(21, @it);
    if (it.nameIds[1] = Lo(GDConsts.randomItemTemplates[14].nameIds[1])) and
        (it.value = GDConsts.randomItemTemplates[14].value) then
      Inc(lightning)
    else if (it.nameIds[3] = 21) and (it.nameIds[2] = it.plus + C_Item.NAME_PLUS_BASE) then
      Inc(plain)
    else
      ok := False;
  end;
  TestKit.Check(ok, 'every javelin is a plain one or a Javelin of Lightning');
  TestKit.Check(lightning > 0, 'some javelins are Javelins of Lightning');
  TestKit.Check(plain > lightning, 'most javelins are plain');

  { a kind with no rule gets only its item type }
  RandItem.GenerateRandomItem(200, @it);
  ok := (it.itemType = 200) and (it.plus = 0) and (it.value = 0);
  for j := 1 to 3 do
    ok := ok and (it.nameIds[j] = 0);
  TestKit.Check(ok, 'an unknown kind gets only its item type');
  TestKit.Done;
end.

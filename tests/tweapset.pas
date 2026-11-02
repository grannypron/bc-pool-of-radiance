{ Tests for weapon sets (#1209): an item tagged 1 or 2 on the Items screen (ViewChar.TagSet, CharHlp.SetTaggable,
  the label's digit and the line's ' 1 2'), the set readied in one go (FxEngine.ReadySet), the tag kept in the .chx
  file and never in SSI's 63-byte item record (CharExt, DiskRec). }
{$I COMPILER.INC}
program TWeapSet;

uses Types, C_EQUIP, C_IFC, C_ITEM, GameVars, CharHlp, CharExt, DiskRec, FileUtil, FxEngine, ViewChar, VidVga,
  TestKit;

const
  FN = 'TWS';
  { the test's base item types besides C_ITEM's: a shield, a ring, a suit of armour }
  SHIELD_TYPE = 59;
  RING_TYPE = 69;
  ARMOR_TYPE = 52;
  { name parts: Long Sword, Long Bow, Shield, Arrow, Dagger }
  NAME_LONG_SWORD = 36;
  NAME_LONG_BOW = 43;
  NAME_SHIELD = 59;
  NAME_ARROW = 61;
  NAME_DAGGER = 8;

type
  { a version 4 .chx file, from before the weapon sets }
  TExt4 = record
    sig: string[4];
    version: Byte;
    name: string[Types.NAME_LEN];
    randByte: Byte;
    portExt: Types.TCharExt;
  end;

var
  c: Types.PCharRecord;
  d: Types.PCharRecord;
  sword: Types.TItemRec;
  shield: Types.TItemRec;
  bow: Types.TItemRec;
  arrows: Types.TItemRec;
  dagger: Types.TItemRec;
  ring: Types.TItemRec;
  armor: Types.TItemRec;
  back: Types.TItemRec;
  items: array[1..7] of Types.TItemRec;
  disk: array[0..DiskRec.ITEM_DISK_BYTES] of Byte;
  s: FileUtil.TFileSet;
  old: TExt4;
  i: Byte;
  line: String;

procedure Base(itemType, slot, hands: Byte);
begin
  CharHlp.baseItems^[itemType].slot := slot;
  CharHlp.baseItems^[itemType].hands := hands;
  CharHlp.baseItems^[itemType].classMask := $FF;
end;

procedure NewItem(var it: Types.TItemRec; itemType, namePart, weaponSet, equipped: Byte; next: Types.PItemRec);
begin
  FillChar(it, SizeOf(it), 0);
  it.itemType := itemType;
  it.nameIds[3] := namePart;
  it.weaponSet := weaponSet;
  it.equipped := equipped;
  it.next := next;
end;

{ The fighter's items: a long sword and shield in set 1, readied, a long bow and arrows in set 2, an untagged dagger and
  a readied ring. }
procedure Kit;
begin
  NewItem(sword, C_ITEM.LONG_SWORD, NAME_LONG_SWORD, 1, 1, @shield);
  NewItem(shield, SHIELD_TYPE, NAME_SHIELD, 1, 1, @bow);
  NewItem(bow, C_ITEM.LONG_BOW, NAME_LONG_BOW, 2, 0, @arrows);
  NewItem(arrows, C_ITEM.ARROW, NAME_ARROW, 2, 0, @dagger);
  arrows.quantity := 20;
  NewItem(dagger, C_ITEM.DAGGER, NAME_DAGGER, 0, 0, @ring);
  NewItem(ring, RING_TYPE, 0, 0, 1, nil);
  c^.itemsAddr := @sword;
  c^.numberOfItems := 6;
  CharHlp.RecalcStats(c);
end;

begin
  TestKit.Start('TWEAPSET');
  GameVars.gameDelay := 0;
  { a refusal says so on the screen: VGA's, with a blank font }
  VidVga.Install;
  GetMem(GameVars.gameFont, SizeOf(Types.TFontArr));
  FillChar(GameVars.gameFont^, SizeOf(Types.TFontArr), 0);
  GameVars.creatureList := nil;
  GetMem(GameVars.zone0, SizeOf(GameVars.zone0^));
  FillChar(GameVars.zone0^, SizeOf(GameVars.zone0^), 0);
  GetMem(CharHlp.baseItems, SizeOf(CharHlp.baseItems^));
  FillChar(CharHlp.baseItems^, SizeOf(CharHlp.baseItems^), 0);
  { the slots and hands of SSI's ITEMS }
  Base(C_ITEM.LONG_SWORD, C_EQUIP.WEAPON, 1);
  Base(C_ITEM.LONG_BOW, C_EQUIP.WEAPON, 2);
  Base(C_ITEM.DAGGER, C_EQUIP.WEAPON, 1);
  Base(C_ITEM.ARROW, 10, 0);
  Base(SHIELD_TYPE, C_EQUIP.SHIELD, 1);
  Base(RING_TYPE, C_EQUIP.RING1, 0);
  Base(ARMOR_TYPE, C_EQUIP.ARMOR, 0);
  GetMem(c, SizeOf(Types.TCharRecord));
  FillChar(c^, SizeOf(Types.TCharRecord), 0);
  c^.name := 'BRIAN';
  c^.randByte := 7;
  c^.enabled := 1;
  c^.itemLimits := $FF;
  GameVars.curChar := c;
  GameVars.ifcState := C_IFC.CAMPING;

  { what takes a tag }
  Kit;
  NewItem(armor, ARMOR_TYPE, 0, 0, 0, nil);
  TestKit.Check(CharHlp.SetTaggable(@sword) and CharHlp.SetTaggable(@bow), 'a sword and a bow take a set');
  TestKit.Check(CharHlp.SetTaggable(@shield) and CharHlp.SetTaggable(@arrows), 'so do a shield and arrows');
  TestKit.Check(not CharHlp.SetTaggable(@armor) and not CharHlp.SetTaggable(@ring), 'armour and a ring do not');
  ViewChar.TagSet(@dagger, 2);
  TestKit.CheckEqualsL(2, dagger.weaponSet, '2 tags the dagger for set 2');
  ViewChar.TagSet(@dagger, 1);
  TestKit.CheckEqualsL(1, dagger.weaponSet, '1 moves it to set 1');
  ViewChar.TagSet(@dagger, 1);
  TestKit.CheckEqualsL(0, dagger.weaponSet, 'and 1 again clears it');
  ViewChar.TagSet(@armor, 1);
  TestKit.CheckEqualsL(0, armor.weaponSet, 'armour is refused');

  { the label and the line }
  CharHlp.ItemLabel(@sword, True);
  TestKit.CheckEqualsL(CharHlp.SET_LABEL_COL, Length(sword.name), 'a tagged item''s label runs to the set column');
  TestKit.CheckEqualsS(' Yes  Long Sword ', Copy(sword.name, 1, 17), 'with its name first');
  TestKit.Check(sword.name[CharHlp.SET_LABEL_COL] = '1', 'and its set''s digit last: ' + sword.name);
  CharHlp.ItemLabel(@dagger, True);
  TestKit.CheckEqualsS(' No   Dagger ', dagger.name, 'an untagged item''s label is as ever');
  CharHlp.ItemLabel(@sword, False);
  TestKit.CheckEqualsS('Long Sword ', sword.name, 'and no digit outside the inventory');
  line := ViewChar.ItemMenuLine(c, @sword);
  TestKit.Check(Copy(line, Length(line) - 3, 4) = ' 1 2', 'the line ends in 1 2 on a weapon: ' + line);
  TestKit.Check(Pos(' 1 2', ViewChar.ItemMenuLine(c, @ring)) = 0, 'not on a ring');
  GameVars.ifcState := C_IFC.SHOP_TEMPLE;
  TestKit.Check(Pos(' 1 2', ViewChar.ItemMenuLine(c, @sword)) = 0, 'nor at a shop''s counter');
  TestKit.Check(not ViewChar.TagsSets, 'where nothing is tagged');
  GameVars.ifcState := C_IFC.CAMPING;

  { readying a set }
  Kit;
  TestKit.Check(FxEngine.ReadySet(c, 2), '2 readies set 2');
  TestKit.Check((bow.equipped <> 0) and (arrows.equipped <> 0), 'the bow and arrows');
  TestKit.Check((sword.equipped = 0) and (shield.equipped = 0), 'set 1 put away');
  TestKit.Check(ring.equipped <> 0, 'the ring, in no set and in nothing''s way, stays on');
  TestKit.Check(c^.equipped[C_EQUIP.WEAPON] = @bow, 'the bow in hand');
  TestKit.CheckEqualsL(2, c^.handsEquipped, 'in both hands');
  TestKit.Check(not FxEngine.ReadySet(c, 2), 'set 2 again changes nothing');
  TestKit.Check(FxEngine.ReadySet(c, 1), '1 readies set 1');
  TestKit.Check((sword.equipped <> 0) and (shield.equipped <> 0) and (bow.equipped = 0) and (arrows.equipped = 0),
                'the sword and shield again, the bow and arrows away');
  TestKit.Check(c^.equipped[C_EQUIP.WEAPON] = @sword, 'the sword in hand');

  { an untagged weapon in the way goes }
  Kit;
  sword.equipped := 0;
  shield.equipped := 0;
  dagger.equipped := 1;
  CharHlp.RecalcStats(c);
  TestKit.Check(FxEngine.ReadySet(c, 2), 'set 2 with an untagged dagger in hand');
  TestKit.Check((dagger.equipped = 0) and (bow.equipped <> 0), 'the dagger is put away for the bow');
  { a shield, untagged, holds the hand the bow needs }
  Kit;
  sword.equipped := 0;
  shield.weaponSet := 0;
  CharHlp.RecalcStats(c);
  TestKit.Check(FxEngine.ReadySet(c, 2), 'set 2 with an untagged shield on the arm');
  TestKit.Check((shield.equipped = 0) and (bow.equipped <> 0), 'the shield is put away for the two-handed bow');

  { a cursed sword stays }
  Kit;
  sword.cursed := 1;
  TestKit.Check(FxEngine.ReadySet(c, 2), 'set 2 with a cursed sword in set 1');
  TestKit.Check(sword.equipped <> 0, 'the cursed sword stays in hand');
  TestKit.Check(bow.equipped = 0, 'so the bow is not readied');
  TestKit.Check((shield.equipped = 0) and (arrows.equipped <> 0), 'the shield goes and the arrows are readied');

  { no set }
  Kit;
  sword.weaponSet := 0;
  shield.weaponSet := 0;
  TestKit.Check(not FxEngine.ReadySet(c, 1), 'a set with nothing in it changes nothing');
  TestKit.Check(sword.equipped <> 0, 'the sword stays in hand');

  { joined stacks: an untagged stack takes the set of the one that joins it }
  Kit;
  arrows.weaponSet := 0;
  NewItem(items[1], C_ITEM.ARROW, NAME_ARROW, 2, 0, nil);
  items[1].quantity := 10;
  { JoinStacks frees the stack that joins, so it is a heap copy }
  CharHlp.AppendItemCopy(c^.itemsAddr, @items[1]);
  CharHlp.JoinStacks(c, @arrows);
  TestKit.CheckEqualsL(30, arrows.quantity, 'two stacks of arrows join');
  TestKit.CheckEqualsL(2, arrows.weaponSet, 'and the untagged one takes the set of the one that joins it');

  { DiskRec: the tag is never written, and reads as none }
  Kit;
  sword.weaponSet := 2;
  sword.next := nil;
  FillChar(disk, SizeOf(disk), $AA);
  DiskRec.ItemToDisk(sword, disk);
  TestKit.CheckEqualsL($AA, disk[DiskRec.ITEM_DISK_BYTES], 'an item''s disk form is still 63 bytes');
  FillChar(back, SizeOf(back), $FF);
  DiskRec.ItemFromDisk(disk, back);
  TestKit.CheckEqualsL(C_ITEM.SET_NONE, back.weaponSet, 'and an item read from it is in no set');
  TestKit.CheckEqualsL(C_ITEM.LONG_SWORD, back.itemType, 'the rest as written');

  { the .chx file keeps the sets by the items' places }
  Kit;
  TestKit.Check(CharExt.HasExt(c), 'a character with tagged items needs a .chx');
  FileUtil.NewSet(s, '');
  TestKit.Check(CharExt.WriteExt(s, c, FN) and FileUtil.CommitSet(s), 'which is written');
  GetMem(d, SizeOf(Types.TCharRecord));
  d^ := c^;
  for i := 1 to 6 do
    NewItem(items[i], C_ITEM.DAGGER, NAME_DAGGER, C_ITEM.SET_LAST, 0, @items[i + 1]);
  items[6].next := nil;
  d^.itemsAddr := @items[1];
  CharExt.ReadExt(d, FN);
  TestKit.Check((items[1].weaponSet = 1) and (items[2].weaponSet = 1), 'the first two items read back in set 1');
  TestKit.Check((items[3].weaponSet = 2) and (items[4].weaponSet = 2), 'the next two in set 2');
  TestKit.Check((items[5].weaponSet = 0) and (items[6].weaponSet = 0), 'and the last two in none');
  { a version 4 file, from before the sets }
  FillChar(old, SizeOf(old), 0);
  old.sig := 'CEXT';
  old.version := 4;
  old.name := c^.name;
  old.randByte := c^.randByte;
  old.portExt.formerClasses := 4;
  { written as the game writes a .chx (FileUtil), so that the save below erases this one }
  FileUtil.NewSet(s, '');
  TestKit.Check(FileUtil.WriteToSet(s, FN + '.chx', old, SizeOf(old)) and FileUtil.CommitSet(s), 'written');
  CharExt.ReadExt(d, FN);
  TestKit.CheckEqualsL(4, d^.portExt.formerClasses, 'a version 4 file is still read');
  TestKit.Check((items[1].weaponSet = 0) and (items[3].weaponSet = 0), 'with every item in no set');
  { untagged, the character needs none }
  sword.weaponSet := 0;
  shield.weaponSet := 0;
  bow.weaponSet := 0;
  arrows.weaponSet := 0;
  TestKit.Check(not CharExt.HasExt(c), 'an untagged character needs no .chx');
  FileUtil.NewSet(s, '');
  TestKit.Check(CharExt.WriteExt(s, c, FN) and FileUtil.CommitSet(s), 'and its save erases it');
  TestKit.Check(not FileUtil.Exists(FN + '.chx'), 'it is gone');

  FreeMem(d, SizeOf(Types.TCharRecord));
  FreeMem(c, SizeOf(Types.TCharRecord));
  FreeMem(GameVars.gameFont, SizeOf(Types.TFontArr));
  TestKit.Done;
end.

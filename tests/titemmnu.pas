{ Tests the inventory's action line (ViewChar.ItemMenuLine) for the I key: at a shop's or temple's counter every item
  offers Id and none Info, so that the line does not tell which items are magic (#1115); elsewhere an item with a
  spell page offers Info. }
{$I COMPILER.INC}
program TItemMnu;

uses Types, GameVars, C_IFC, CharHlp, ViewChar, TestKit;

const
  { the test's base item types: a dagger and a wand }
  DAGGER_TYPE = 1;
  WAND_TYPE = 2;
  { item effect 84: the Wand of Paralyzation's spell }
  WAND_EFFECT = 84;

var
  c: Types.PCharRecord;
  it: Types.PItemRec;

{ Make the test item one of itemType with effect, identified or not (unidMask). }
procedure SetItem(itemType, effect, unidMask: Byte);
begin
  FillChar(it^, SizeOf(Types.TItemRec), 0);
  it^.itemType := itemType;
  it^.effect := effect;
  it^.unidMask := unidMask;
end;

{ True when the action line for the test item ends with the word w. }
function EndsWith(w: String): Boolean;
var
  s: String;
begin
  s := ViewChar.ItemMenuLine(c, it);
  EndsWith := Copy(s, Length(s) - Length(w) + 1, Length(w)) = w;
end;

begin
  TestKit.Start('TITEMMNU');
  GetMem(GameVars.zone0, SizeOf(GameVars.zone0^));
  FillChar(GameVars.zone0^, SizeOf(GameVars.zone0^), 0);
  GetMem(CharHlp.baseItems, SizeOf(CharHlp.baseItems^));
  FillChar(CharHlp.baseItems^, SizeOf(CharHlp.baseItems^), 0);
  GetMem(c, SizeOf(Types.TCharRecord));
  FillChar(c^, SizeOf(Types.TCharRecord), 0);
  c^.enabled := 1;
  GameVars.curChar := c;
  GetMem(it, SizeOf(Types.TItemRec));

  GameVars.ifcState := C_IFC.SHOP_TEMPLE;
  SetItem(DAGGER_TYPE, 0, 0);
  TestKit.Check(EndsWith(' Sell Id'), 'at the counter an identified mundane dagger offers Id: ' +
                ViewChar.ItemMenuLine(c, it));
  SetItem(DAGGER_TYPE, 0, 4);
  TestKit.Check(EndsWith(' Id'), 'and so does an unidentified magic one');
  SetItem(WAND_TYPE, WAND_EFFECT, 0);
  TestKit.Check(EndsWith(' Id'), 'an identified wand offers Id at the counter');
  TestKit.Check(Pos('Info', ViewChar.ItemMenuLine(c, it)) = 0, 'and no Info there: I is Id at the counter');

  GameVars.ifcState := C_IFC.CAMPING;
  TestKit.Check(EndsWith(' Info'), 'away from the counter the wand offers Info');
  TestKit.Check(Pos(' Id', ViewChar.ItemMenuLine(c, it)) = 0, 'and no Id');
  SetItem(DAGGER_TYPE, 0, 0);
  TestKit.Check((Pos(' Id', ViewChar.ItemMenuLine(c, it)) = 0) and (Pos('Info', ViewChar.ItemMenuLine(c, it)) = 0),
                'and a dagger neither');

  FreeMem(it, SizeOf(Types.TItemRec));
  FreeMem(c, SizeOf(Types.TCharRecord));
  FreeMem(CharHlp.baseItems, SizeOf(CharHlp.baseItems^));
  FreeMem(GameVars.zone0, SizeOf(GameVars.zone0^));
  TestKit.Done;
end.

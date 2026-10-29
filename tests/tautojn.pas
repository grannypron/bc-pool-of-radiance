{ Tests for Auto Join (#1088): CharHlp.AddToInventory joins a stack it is given into the first of the creature's stacks
  it matches while GameVars.autoJoinOn is set, and only then; a stack fills to 255 and the rest stays a stack of its
  own; the stack it joins keeps its readied mark; an item that matches nothing, or is no stack, is added as it is.
  CharHlp.JoinsWhole says when the whole of an item fits in one stack, which is when it needs no item slot. }
{$I COMPILER.INC}
program TAutoJn;

uses Types, GameVars, C_ITEM, CharHlp, TestKit;

var
  c: Types.PCharRecord;
  arrows: Types.TItemRec;
  other: Types.TItemRec;

{ How many items c carries. }
function ItemCount: Byte;
var
  p: Types.PItemRec;
  n: Byte;
begin
  n := 0;
  p := c^.itemsAddr;
  while p <> nil do begin
    Inc(n);
    p := p^.next;
  end;
  ItemCount := n;
end;

{ Take every item from c. }
procedure Empty;
begin
  while c^.itemsAddr <> nil do
    CharHlp.RemoveItem(c, c^.itemsAddr);
end;

begin
  TestKit.Start('TAUTOJN');
  GetMem(c, SizeOf(Types.TCharRecord));
  FillChar(c^, SizeOf(Types.TCharRecord), 0);
  FillChar(arrows, SizeOf(arrows), 0);
  arrows.itemType := C_ITEM.ARROW;
  arrows.nameIds[3] := 1;
  arrows.quantity := 20;
  arrows.weight := 1;
  other := arrows;
  other.plus := 1;

  { off: SSI's way, every bundle an item of its own }
  GameVars.autoJoinOn := 0;
  CharHlp.AddToInventory(c, @arrows);
  CharHlp.AddToInventory(c, @arrows);
  TestKit.CheckEqualsL(2, ItemCount, 'off: two bundles are two items');
  Empty;

  { on }
  GameVars.autoJoinOn := 1;
  CharHlp.AddToInventory(c, @arrows);
  c^.itemsAddr^.equipped := 1;
  CharHlp.AddToInventory(c, @arrows);
  TestKit.CheckEqualsL(1, ItemCount, 'on: the second bundle joins the first');
  TestKit.CheckEqualsL(40, c^.itemsAddr^.quantity, 'into one stack of 40');
  TestKit.CheckEqualsL(1, c^.itemsAddr^.equipped, 'which stays readied');
  CharHlp.AddToInventory(c, @other);
  TestKit.CheckEqualsL(2, ItemCount, 'arrows +1 do not join plain arrows');
  Empty;

  { the cap }
  arrows.quantity := 250;
  CharHlp.AddToInventory(c, @arrows);
  arrows.quantity := 20;
  TestKit.Check(not CharHlp.JoinsWhole(c, @arrows), '20 do not fit whole in a stack of 250');
  CharHlp.AddToInventory(c, @arrows);
  TestKit.CheckEqualsL(2, ItemCount, 'past 255 the rest is a stack of its own');
  TestKit.CheckEqualsL(255, c^.itemsAddr^.quantity, 'the first filled to 255');
  TestKit.CheckEqualsL(15, c^.itemsAddr^.next^.quantity, 'and 15 over');
  arrows.quantity := 5;
  TestKit.Check(CharHlp.JoinsWhole(c, @arrows), '5 fit whole in the stack of 15');
  Empty;

  { no stack }
  arrows.quantity := 0;
  CharHlp.AddToInventory(c, @arrows);
  CharHlp.AddToInventory(c, @arrows);
  TestKit.CheckEqualsL(2, ItemCount, 'items of quantity 0 never join');
  TestKit.Check(not CharHlp.JoinsWhole(c, @arrows), 'nor fit whole');
  Empty;
  TestKit.Done;
end.

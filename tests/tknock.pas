{ Tests for Explore.FindKnockCaster, which decides whether a door's 'Locked.' menu offers Knock (POR-0229, #1015): a
  member with Knock memorized, or one carrying a scroll of it that it can read and use, and only an Okay one. }
{$I COMPILER.INC}
program TKnock;

uses Types, C_ITEM, C_IFC, C_SPELL, C_STATUS, GameVars, CharHlp, Explore, TestKit;

const
  SCROLL_TYPE = C_ITEM.MAGE_SCROLL;

var
  mage: Types.PCharRecord;
  thief: Types.PCharRecord;
  scroll: Types.PItemRec;
  caster: Types.PCharRecord;
  found: Types.PItemRec;

function NewChar: Types.PCharRecord;
var
  c: Types.PCharRecord;
begin
  GetMem(c, SizeOf(Types.TCharRecord));
  FillChar(c^, SizeOf(Types.TCharRecord), 0);
  c^.status := C_STATUS.OKAY;
  c^.enabled := 1;
  NewChar := c;
end;

begin
  TestKit.Start('TKNOCK');
  GetMem(GameVars.zone0, SizeOf(Types.TGbvmZone0State));
  FillChar(GameVars.zone0^, SizeOf(Types.TGbvmZone0State), 0);
  GameVars.ifcState := C_IFC.INDOORS;
  GetMem(CharHlp.baseItems, SizeOf(CharHlp.baseItems^));
  FillChar(CharHlp.baseItems^, SizeOf(CharHlp.baseItems^), 0);
  CharHlp.baseItems^[SCROLL_TYPE].slot := C_ITEM.SLOT_MAGE_SCROLL;
  thief := NewChar;
  mage := NewChar;
  thief^.nextCharAddr := mage;
  GameVars.creatureList := thief;
  TestKit.Check(not Explore.FindKnockCaster(caster, found), 'a magic-user without Knock cannot knock (POR-0229)');
  TestKit.Check(caster = nil, 'and no caster is named');
  mage^.memorizedSpells[3] := C_SPELL.KNOCK;
  TestKit.Check(Explore.FindKnockCaster(caster, found) and (caster = mage) and (found = nil),
                'Knock memorized: the magic-user casts it');
  mage^.memorizedSpells[3] := C_SPELL.KNOCK + C_SPELL.PENDING_FLAG;
  TestKit.Check(not Explore.FindKnockCaster(caster, found), 'not while it is still being memorized');
  GetMem(scroll, SizeOf(Types.TItemRec));
  FillChar(scroll^, SizeOf(Types.TItemRec), 0);
  scroll^.itemType := SCROLL_TYPE;
  scroll^.equipped := 1;
  scroll^.spells[2] := C_SPELL.KNOCK;
  mage^.itemsAddr := scroll;
  TestKit.Check(Explore.FindKnockCaster(caster, found) and (caster = mage) and (found = scroll),
                'Knock on a scroll the magic-user can read');
  scroll^.unidMask := 1;
  TestKit.Check(not Explore.FindKnockCaster(caster, found), 'not one it cannot read');
  scroll^.unidMask := 0;
  mage^.status := C_STATUS.UNCONSCIOUS;
  mage^.enabled := 0;
  TestKit.Check(not Explore.FindKnockCaster(caster, found), 'nor by a member who is not Okay');
  mage^.status := C_STATUS.OKAY;
  mage^.enabled := 1;
  GameVars.zone0^.antimagic := 1;
  TestKit.Check(not Explore.FindKnockCaster(caster, found), 'nor read where magic does not work');
  TestKit.Done;
end.

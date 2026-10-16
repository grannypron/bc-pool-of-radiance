{ Tests for UsualSpl: usual spells remembered, found by record and name, forgotten, saved to a .mem file and read back
  only for the character it was made for, and a full table giving up the entry of a character outside the party. }
program TUsualSp;

uses Types, C_Gbvm, GDVars, FileUtil, UsualSpl, TestKit;

const
  FN = 'TUS';
  COUNT = 9;

var
  c: array[1..COUNT] of Types.PCharRecord;
  spells: Types.TSpellSlots;
  back: Types.TSpellSlots;
  i: Integer;

{ Spells marked by n, so one character's can be told from another's. }
procedure MarkSpells(n: Byte);
var
  k: Integer;
begin
  for k := 0 to Types.SPELL_SLOT_LAST do
    spells[k] := n + k;
end;

{ True when creature's usual spells are the ones MarkSpells(n) makes. }
function HasMarked(creature: Types.PCharRecord; n: Byte): Boolean;
var
  k: Integer;
  same: Boolean;
begin
  FillChar(back, SizeOf(back), 0);
  same := UsualSpl.GetUsualSpells(creature, back);
  for k := 0 to Types.SPELL_SLOT_LAST do
    if back[k] <> Byte(n + k) then
      same := False;
  HasMarked := same;
end;

begin
  TestKit.Start('TUSUALSP');
  GetMem(GDVars.zone1, SizeOf(GDVars.zone1^));
  FillChar(GDVars.zone1^, SizeOf(GDVars.zone1^), 0);
  for i := 1 to COUNT do begin
    GetMem(c[i], SizeOf(Types.TCharRecord));
    FillChar(c[i]^, SizeOf(Types.TCharRecord), 0);
    c[i]^.name := 'HERO' + Chr(Ord('0') + i);
    c[i]^.randByte := i * 7;
    if i > 1 then
      c[i - 1]^.nextCharAddr := c[i];
  end;
  GDVars.creatureList := c[1];
  GDVars.zone1^[C_Gbvm.PARTY_SIZE] := COUNT - 2;

  TestKit.Check(not UsualSpl.GetUsualSpells(c[1], back), 'none remembered at first');
  TestKit.Check(not UsualSpl.GetUsualSpells(nil, back), 'nor for nil');
  MarkSpells(10);
  UsualSpl.SetUsualSpells(c[1], spells);
  TestKit.Check(HasMarked(c[1], 10), 'remembered spells come back');
  TestKit.Check(not UsualSpl.GetUsualSpells(c[2], back), 'only for their character');
  MarkSpells(20);
  UsualSpl.SetUsualSpells(c[1], spells);
  TestKit.Check(HasMarked(c[1], 20), 'remembering again replaces them');
  c[1]^.name := 'OTHER';
  TestKit.Check(not UsualSpl.GetUsualSpells(c[1], back), 'a record reused under another name has none');
  c[1]^.name := 'HERO1';
  UsualSpl.ForgetUsualSpells(c[1]);
  TestKit.Check(not UsualSpl.GetUsualSpells(c[1], back), 'forgotten spells are gone');

  { the .mem sidecar }
  FileUtil.DeleteFile(FN + '.mem');
  UsualSpl.WriteUsualSpells(c[1], FN);
  TestKit.Check(not FileUtil.ReadRecord(FN + '.mem', back, 1), 'no file for a character with none');
  MarkSpells(30);
  UsualSpl.SetUsualSpells(c[1], spells);
  UsualSpl.WriteUsualSpells(c[1], FN);
  UsualSpl.ForgetUsualSpells(c[1]);
  UsualSpl.ReadUsualSpells(c[1], FN);
  TestKit.Check(HasMarked(c[1], 30), 'spells written and read back');
  c[1]^.randByte := 99;
  UsualSpl.ReadUsualSpells(c[1], FN);
  TestKit.Check(not UsualSpl.GetUsualSpells(c[1], back), 'a file for another randByte is not read');
  c[1]^.randByte := 7;
  c[1]^.name := 'HERO2';
  UsualSpl.ReadUsualSpells(c[1], FN);
  TestKit.Check(not UsualSpl.GetUsualSpells(c[1], back), 'nor one for another name');
  c[1]^.name := 'HERO1';
  UsualSpl.ReadUsualSpells(c[1], FN);
  TestKit.Check(HasMarked(c[1], 30), 'the right character reads it');
  FileUtil.DeleteFile(FN + '.mem');
  UsualSpl.ReadUsualSpells(c[1], FN);
  TestKit.Check(not UsualSpl.GetUsualSpells(c[1], back), 'a missing file leaves none');

  { a full table: characters 1..7 are the party, 8 is not }
  for i := 1 to Types.MAX_PARTY do begin
    MarkSpells(i);
    UsualSpl.SetUsualSpells(c[i], spells);
  end;
  MarkSpells(COUNT);
  UsualSpl.SetUsualSpells(c[COUNT], spells);
  TestKit.Check(HasMarked(c[COUNT], COUNT), 'a full table still takes a new character');
  TestKit.Check(not UsualSpl.GetUsualSpells(c[Types.MAX_PARTY], back), 'by giving up a non-member''s entry');
  TestKit.Check(HasMarked(c[1], 1) and HasMarked(c[Types.MAX_PARTY - 1], Types.MAX_PARTY - 1),
                'and keeping the party''s');

  for i := 1 to COUNT do
    FreeMem(c[i], SizeOf(Types.TCharRecord));
  FreeMem(GDVars.zone1, SizeOf(GDVars.zone1^));
  TestKit.Done;
end.

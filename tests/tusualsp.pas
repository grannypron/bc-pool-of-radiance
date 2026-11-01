{ Tests for UsualSpl: usual spells remembered, found by record and name, forgotten, saved to a .mem file and read back
  only for the character it was made for, a full table giving up the entry of a character outside the party, and the
  usual spells queued into the slots a caster has free (#1119). }
{$I COMPILER.INC}
program TUsualSp;

uses Types, C_GBVM, C_SPELL, GameVars, FileUtil, UsualSpl, CharHlp, TestKit;

const
  FN = 'TUS';
  COUNT = 9;

const
  { two first-level magic-user spells }
  MISSILE = C_SPELL.MAGIC_MISSILE;
  SLEEP = C_SPELL.SLEEP;

var
  c: array[1..COUNT] of Types.PCharRecord;
  spells: Types.TMemorized;
  back: Types.TMemorized;
  i: Integer;

{ Write c[1]'s usual spells into folder dir as a save of their own: True when they are in place. }
function WriteMem(dir: FileUtil.TPathName): Boolean;
var
  s: FileUtil.TFileSet;
begin
  FileUtil.NewSet(s, dir);
  WriteMem := UsualSpl.WriteUsualSpells(s, c[1], FN) and FileUtil.CommitSet(s);
end;

{ Spells marked by n, so one character's can be told from another's. }
procedure MarkSpells(n: Byte);
var
  k: Integer;
begin
  for k := 0 to Types.MEMORIZED_LAST do
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
  for k := 0 to Types.MEMORIZED_LAST do
    if back[k] <> Byte(n + k) then
      same := False;
  HasMarked := same;
end;

begin
  TestKit.Start('TUSUALSP');
  GetMem(GameVars.zone1, SizeOf(GameVars.zone1^));
  FillChar(GameVars.zone1^, SizeOf(GameVars.zone1^), 0);
  for i := 1 to COUNT do begin
    GetMem(c[i], SizeOf(Types.TCharRecord));
    FillChar(c[i]^, SizeOf(Types.TCharRecord), 0);
    c[i]^.name := 'HERO' + Chr(Ord('0') + i);
    c[i]^.randByte := i * 7;
    if i > 1 then
      c[i - 1]^.nextCharAddr := c[i];
  end;
  GameVars.creatureList := c[1];
  GameVars.zone1^[C_GBVM.PARTY_SIZE] := COUNT - 2;

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
  TestKit.Check(WriteMem(''), 'a character with none needs no file');
  TestKit.Check(not FileUtil.ReadRecord(FN + '.mem', back, 1), 'and has none');
  MarkSpells(30);
  UsualSpl.SetUsualSpells(c[1], spells);
  TestKit.Check(not WriteMem('NODIR\'), 'a write into a missing folder says it failed');
  TestKit.Check(WriteMem(''), 'the spells are written');
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
  UsualSpl.ForgetUsualSpells(c[1]);
  TestKit.Check(WriteMem(''), 'saving a character that has none now');
  UsualSpl.ReadUsualSpells(c[1], FN);
  TestKit.Check(not UsualSpl.GetUsualSpells(c[1], back), 'erases its old file, and a missing file leaves none');

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

  { the usual spells queued: c[1], a magic-user with two first-level slots, knows Magic Missile and Sleep }
  FillChar(spells, SizeOf(spells), 0);
  spells[0] := MISSILE;
  spells[1] := SLEEP;
  spells[2] := MISSILE;
  UsualSpl.SetUsualSpells(c[1], spells);
  CharHlp.SetSpellKnown(c[1], MISSILE, True);
  CharHlp.SetSpellKnown(c[1], SLEEP, True);
  CharHlp.SetSpellSlots(c[1], C_SPELL.CLASS_MAGE, 1, 2);
  CharHlp.ClearMemorized(c[1]);
  TestKit.Check(not UsualSpl.HasPending(c[1]), 'nothing pending at first');
  UsualSpl.QueueUsualSpells(c[1]);
  TestKit.Check(UsualSpl.HasPending(c[1]), 'queued spells are pending');
  TestKit.CheckEqualsL(0, UsualSpl.SpellSlotsRemaining(c[1], 1, C_SPELL.CLASS_MAGE), 'they fill both slots');
  TestKit.CheckEqualsL(MISSILE + C_SPELL.PENDING_FLAG, CharHlp.MemorizedAt(c[1], Types.MEMORIZED_LAST - 1),
                       'Magic Missile, sorted to the end');
  TestKit.CheckEqualsL(SLEEP + C_SPELL.PENDING_FLAG, CharHlp.MemorizedAt(c[1], Types.MEMORIZED_LAST), 'then Sleep');
  TestKit.CheckEqualsL(0, CharHlp.MemorizedAt(c[1], Types.MEMORIZED_LAST - 2), 'the second Magic Missile has no slot');
  { a cast spell is memorized again; the one still held stays }
  CharHlp.ClearMemorized(c[1]);
  CharHlp.SetMemorizedAt(c[1], 0, SLEEP);
  UsualSpl.QueueUsualSpells(c[1]);
  TestKit.CheckEqualsL(MISSILE + C_SPELL.PENDING_FLAG, CharHlp.MemorizedAt(c[1], Types.MEMORIZED_LAST - 1),
                       'the Magic Missile cast comes back');
  TestKit.CheckEqualsL(SLEEP, CharHlp.MemorizedAt(c[1], Types.MEMORIZED_LAST), 'beside the Sleep still memorized');
  { a drained caster gets only what its slots allow }
  CharHlp.ClearMemorized(c[1]);
  CharHlp.SetSpellSlots(c[1], C_SPELL.CLASS_MAGE, 1, 1);
  UsualSpl.QueueUsualSpells(c[1]);
  TestKit.CheckEqualsL(MISSILE + C_SPELL.PENDING_FLAG, CharHlp.MemorizedAt(c[1], Types.MEMORIZED_LAST),
                       'a drained caster queues the first');
  TestKit.CheckEqualsL(0, CharHlp.MemorizedAt(c[1], Types.MEMORIZED_LAST - 1), 'and no more');
  { a spell no longer known is not queued }
  CharHlp.ClearMemorized(c[1]);
  CharHlp.SetSpellSlots(c[1], C_SPELL.CLASS_MAGE, 1, 2);
  CharHlp.SetSpellKnown(c[1], MISSILE, False);
  UsualSpl.QueueUsualSpells(c[1]);
  TestKit.CheckEqualsL(SLEEP + C_SPELL.PENDING_FLAG, CharHlp.MemorizedAt(c[1], Types.MEMORIZED_LAST),
                       'only the spell still known');
  TestKit.CheckEqualsL(0, CharHlp.MemorizedAt(c[1], Types.MEMORIZED_LAST - 1), 'is queued');
  { a character with no usual spells is left alone }
  CharHlp.ClearMemorized(c[2]);
  UsualSpl.ForgetUsualSpells(c[2]);
  UsualSpl.QueueUsualSpells(c[2]);
  TestKit.Check(not UsualSpl.HasPending(c[2]), 'none remembered, none queued');

  for i := 1 to COUNT do
    FreeMem(c[i], SizeOf(Types.TCharRecord));
  FreeMem(GameVars.zone1, SizeOf(GameVars.zone1^));
  TestKit.Done;
end.

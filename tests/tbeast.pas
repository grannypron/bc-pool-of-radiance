{ Tests for Bestiary (#842): meeting creatures once an encounter, facts learned only from the party's side, the armor
  class narrowed from attack rolls, the most damage in a blow, kills and hit dice, the full table, and BESTIARY.DAT
  written and read back, missing, damaged (set aside when next written) and of a newer format (read, never written);
  and an entry filled in from a creature's record (BeastFil.Tell, the sage's, #868). }
{$I COMPILER.INC}
program TBeast;

uses Types, GameVars, C_GBVM, C_STATUS, C_IFC, C_BEAST, C_EFFECT, FileUtil, Bestiary, BeastFil, TestKit;

type
  THeader = record
    sig: string[4];
    version: Byte;
    entrySize: Byte;
    count: Word;
  end;

var
  a: Types.PCharRecord;
  troll: Types.PCharRecord;
  kobold: Types.PCharRecord;
  b: Bestiary.PBeast;
  t: Bestiary.TBeast;
  i: Word;
  f: file;
  h: THeader;
  pad: array[1..8] of Byte;
  s: String;
  e: Types.PEffectRec;
  ok: Boolean;

{ Put an effect id on the creature's effects list. }
procedure AddEffect(p: Types.PCharRecord; id: Byte);
var
  n: Types.PEffectRec;
begin
  GetMem(n, SizeOf(Types.TEffectRec));
  FillChar(n^, SizeOf(Types.TEffectRec), 0);
  n^.id := id;
  n^.next := p^.effectsAddr;
  p^.effectsAddr := n;
end;

function NewCreature(name: String; next: Types.PCharRecord): Types.PCharRecord;
var
  p: Types.PCharRecord;
begin
  GetMem(p, SizeOf(Types.TCharRecord));
  FillChar(p^, SizeOf(Types.TCharRecord), 0);
  p^.name := name;
  p^.status := C_STATUS.OKAY;
  p^.nextCharAddr := next;
  NewCreature := p;
end;

function Troll_: Bestiary.PBeast;
begin
  Troll_ := Bestiary.Entry(Bestiary.Find('TROLL'));
end;

{ Write a file of n bytes of junk as fn. }
procedure WriteJunk(fn: String; n: Word);
var
  junk: array[1..64] of Byte;
  w: Word;
begin
  FillChar(junk, SizeOf(junk), $5A);
  Assign(f, fn);
  Rewrite(f, 1);
  BlockWrite(f, junk, n, w);
  Close(f);
end;

function FileBytes(fn: String): LongInt;
begin
  FileBytes := -1;
  if FileUtil.OpenReadOnly(f, fn) then begin
    FileBytes := FileSize(f);
    Close(f);
  end;
end;

begin
  TestKit.Start('TBEAST');
  GetMem(GameVars.zone1, SizeOf(Types.TGbvmZone1));
  FillChar(GameVars.zone1^, SizeOf(Types.TGbvmZone1), 0);
  { a party of one, then two monsters, as combat appends them }
  kobold := NewCreature('KOBOLD', nil);
  troll := NewCreature('TROLL', kobold);
  a := NewCreature('TALONIA', troll);
  GameVars.creatureList := a;
  GameVars.zone1^[C_GBVM.PARTY_SIZE] := 1;
  GameVars.saveDirectory := '';
  FileUtil.DeleteFile(BeastFil.FILE_NAME);
  FileUtil.DeleteFile('BESTIARY.BAD');

  { a missing file is an empty bestiary }
  BeastFil.Load;
  TestKit.CheckEqualsL(0, Bestiary.Count, 'no file, no creatures');
  TestKit.Check(Bestiary.Entry(1) = nil, 'no entry 1');

  { meetings: once an encounter, outside combat too; never a party member }
  GameVars.ifcState := C_IFC.INDOORS;
  Bestiary.Met(troll);
  Bestiary.Met(troll);
  Bestiary.Met(a);
  TestKit.CheckEqualsL(1, Bestiary.Count, 'a met kind, and no party member');
  TestKit.CheckEqualsS('TROLL', Bestiary.Entry(1)^.name, 'keyed by its name');
  TestKit.CheckEqualsL(1, Troll_^.seen, 'met twice in an encounter counts once');
  Bestiary.NewEncounter;
  Bestiary.Met(troll);
  TestKit.CheckEqualsL(2, Troll_^.seen, 'a new encounter counts again');
  TestKit.CheckEqualsL(0, Bestiary.Find('ORC'), 'an unmet kind is not found');
  TestKit.Check(not Bestiary.Knows(Troll_^, C_BEAST.SIZE_KNOWN), 'a new entry knows nothing');
  TestKit.CheckEqualsL(C_BEAST.AC_NO_LOW, Troll_^.acLo, 'nor its armor class, low');
  TestKit.CheckEqualsL(C_BEAST.AC_NO_HIGH, Troll_^.acHi, 'nor high');

  { facts: only in combat, only on the party's side }
  Bestiary.Learn(troll, a, C_BEAST.REGENERATES);
  TestKit.Check(not Bestiary.Knows(Troll_^, C_BEAST.REGENERATES), 'nothing is learned outside combat');
  GameVars.ifcState := C_IFC.IN_COMBAT;
  Bestiary.Learn(troll, kobold, C_BEAST.REGENERATES);
  TestKit.Check(not Bestiary.Knows(Troll_^, C_BEAST.REGENERATES), 'nor from a monster''s side');
  Bestiary.Learn(a, nil, C_BEAST.REGENERATES);
  TestKit.CheckEqualsL(0, Bestiary.Find('TALONIA'), 'nor of a party member');
  Bestiary.Learn(troll, a, C_BEAST.REGENERATES);
  Bestiary.Learn(troll, nil, C_BEAST.ATK_PARALYZE);
  TestKit.Check(Bestiary.Knows(Troll_^, C_BEAST.REGENERATES), 'a fact the party saw');
  TestKit.Check(Bestiary.Knows(Troll_^, C_BEAST.ATK_PARALYZE), 'a fact anyone saw, in the second word');
  TestKit.Check(not Bestiary.Knows(Troll_^, C_BEAST.ATK_POISON), 'and no other');
  Bestiary.Learn(troll, a, 200);
  TestKit.Check(not Bestiary.Knows(Troll_^, 200), 'a fact past the format''s is ignored');
  Bestiary.LearnSize(troll, a, True);
  TestKit.Check(Bestiary.Knows(Troll_^, C_BEAST.SIZE_KNOWN) and Bestiary.Knows(Troll_^, C_BEAST.LARGE), 'Large');
  Bestiary.LearnSize(kobold, a, False);
  b := Bestiary.Entry(Bestiary.Find('KOBOLD'));
  TestKit.Check(Bestiary.Knows(b^, C_BEAST.SIZE_KNOWN) and not Bestiary.Knows(b^, C_BEAST.LARGE), 'not Large');

  { armor class: AC = 60 - acCur; a hit with reach r shows AC >= 60 - r, a miss AC <= 59 - r }
  GameVars.forcedMiss := False;
  GameVars.gAttackRoll := 12;
  Bestiary.LearnArmor(troll, a, 55, True);
  TestKit.CheckEqualsL(5, Troll_^.acLo, 'a hit bounds the armor class below');
  TestKit.CheckEqualsL(C_BEAST.AC_NO_HIGH, Troll_^.acHi, 'and not above');
  Bestiary.LearnArmor(troll, a, 52, False);
  TestKit.CheckEqualsL(7, Troll_^.acHi, 'a miss bounds it above');
  Bestiary.LearnArmor(troll, a, 58, True);
  TestKit.CheckEqualsL(5, Troll_^.acLo, 'a looser bound changes nothing');
  Bestiary.LearnArmor(troll, a, 54, True);
  Bestiary.LearnArmor(troll, a, 53, False);
  TestKit.CheckEqualsL(6, Troll_^.acLo, 'narrowed to one value, low');
  TestKit.CheckEqualsL(6, Troll_^.acHi, 'and high');
  GameVars.gAttackRoll := 1;
  Bestiary.LearnArmor(troll, a, 40, False);
  GameVars.gAttackRoll := 100;
  Bestiary.LearnArmor(troll, a, 80, True);
  GameVars.gAttackRoll := 12;
  GameVars.forcedMiss := True;
  Bestiary.LearnArmor(troll, a, 40, False);
  GameVars.forcedMiss := False;
  Bestiary.LearnArmor(kobold, troll, 40, False);
  TestKit.Check((Troll_^.acLo = 6) and (Troll_^.acHi = 6), 'natural 1 and 20, a displaced miss show nothing');
  b := Bestiary.Entry(Bestiary.Find('KOBOLD'));
  TestKit.CheckEqualsL(C_BEAST.AC_NO_HIGH, b^.acHi, 'nor a monster''s roll');
  { a contradiction starts the other side over }
  Bestiary.LearnArmor(troll, a, 56, False);
  TestKit.CheckEqualsL(3, Troll_^.acHi, 'a bound past the other');
  TestKit.CheckEqualsL(C_BEAST.AC_NO_LOW, Troll_^.acLo, 'forgets that side');
  FillChar(t, SizeOf(t), 0);
  t.acLo := C_BEAST.AC_NO_LOW;
  t.acHi := C_BEAST.AC_NO_HIGH;
  Bestiary.NarrowArmor(t, -500, True);
  TestKit.CheckEqualsL(C_BEAST.AC_NO_LOW + 1, t.acLo, 'a bound is held inside the sentinels, low');
  Bestiary.NarrowArmor(t, 500, False);
  TestKit.CheckEqualsL(C_BEAST.AC_NO_HIGH - 1, t.acHi, 'and high');
  { Mark sets and clears a fact, and says when that changed the entry }
  TestKit.Check(Bestiary.Mark(t, C_BEAST.ATK_DRAIN, True), 'a fact marked is a change');
  TestKit.Check(Bestiary.Knows(t, C_BEAST.ATK_DRAIN), 'and known');
  TestKit.Check(not Bestiary.Mark(t, C_BEAST.ATK_DRAIN, True), 'marked again, no change');
  TestKit.Check(not Bestiary.Mark(t, C_BEAST.LARGE, False), 'clearing an unknown fact, no change');
  TestKit.Check(Bestiary.Mark(t, C_BEAST.ATK_DRAIN, False) and not Bestiary.Knows(t, C_BEAST.ATK_DRAIN),
                'cleared, a change');
  TestKit.Check(not Bestiary.Mark(t, 200, True) and not Bestiary.Knows(t, 200), 'a fact past the format''s is not');
  { a size already known: nothing to write }
  Bestiary.dirty := False;
  Bestiary.LearnSize(troll, a, True);
  TestKit.Check(not Bestiary.dirty, 'a size learned again leaves the Bestiary clean');
  Bestiary.LearnSize(troll, a, False);
  TestKit.Check(Bestiary.dirty and not Bestiary.Knows(Troll_^, C_BEAST.LARGE), 'a changed size dirties it');
  Bestiary.LearnSize(troll, a, True);

  { the most damage in a blow, and kills }
  Bestiary.LearnBlow(troll, a, 9);
  Bestiary.LearnBlow(troll, a, 4);
  Bestiary.LearnBlow(a, troll, 20);
  Bestiary.LearnBlow(troll, kobold, 30);
  TestKit.CheckEqualsL(9, Troll_^.maxHit, 'the most a blow on the party did');
  troll^.levelHighest := 6;
  Bestiary.Killed(troll);
  Bestiary.Killed(a);
  TestKit.CheckEqualsL(1, Troll_^.killed, 'a kill');
  TestKit.Check(Bestiary.Knows(Troll_^, C_BEAST.HD_KNOWN), 'shows the hit dice');
  TestKit.CheckEqualsL(6, Troll_^.hd, 'its hit dice');

  { written and read back }
  TestKit.Check(BeastFil.WriteTo('TBEAST.DAT'), 'written');
  TestKit.Check(not BeastFil.WriteTo('NODIR\TBEAST.DAT'), 'a write into a missing folder fails');
  t := Troll_^;
  Bestiary.Clear;
  TestKit.CheckEqualsL(0, Bestiary.Count, 'cleared');
  BeastFil.LoadFrom('TBEAST.DAT');
  TestKit.CheckEqualsL(2, Bestiary.Count, 'both read back');
  b := Troll_;
  TestKit.Check((b <> nil) and (b^.seen = t.seen) and (b^.killed = t.killed) and (b^.known[0] = t.known[0]) and
                (b^.known[1] = t.known[1]) and (b^.acLo = t.acLo) and (b^.acHi = t.acHi) and (b^.hd = t.hd) and
                (b^.maxHit = t.maxHit), 'the troll as it was');

  { a damaged file reads as empty, and is set aside before the next write }
  WriteJunk(BeastFil.FILE_NAME, 40);
  BeastFil.Load;
  TestKit.CheckEqualsL(0, Bestiary.Count, 'a damaged file reads as none');
  Bestiary.Met(kobold);
  BeastFil.Flush;
  TestKit.CheckEqualsL(40, FileBytes('BESTIARY.BAD'), 'the damaged file set aside');
  BeastFil.Load;
  TestKit.CheckEqualsL(1, Bestiary.Count, 'and a sound one written in its place');
  { a file cut short is damaged too }
  BeastFil.LoadFrom('TBEAST.DAT');
  TestKit.Check(BeastFil.WriteTo('TBEAST.DAT'), 'rewritten');
  if FileUtil.OpenReadOnly(f, 'TBEAST.DAT') then begin
    Close(f);
    Reset(f, 1);
    Seek(f, FileSize(f) - 5);
    Truncate(f);
    Close(f);
  end;
  BeastFil.LoadFrom('TBEAST.DAT');
  TestKit.CheckEqualsL(0, Bestiary.Count, 'a short file reads as none');

  { a newer format: longer entries, read; never written }
  FillChar(h, SizeOf(h), 0);
  h.sig := 'BEST';
  h.version := 2;
  h.entrySize := SizeOf(Bestiary.TBeast) + SizeOf(pad);
  h.count := 1;
  FillChar(pad, SizeOf(pad), $77);
  Assign(f, BeastFil.FILE_NAME);
  Rewrite(f, 1);
  BlockWrite(f, h, SizeOf(h));
  BlockWrite(f, t, SizeOf(t));
  BlockWrite(f, pad, SizeOf(pad));
  Close(f);
  BeastFil.Load;
  TestKit.CheckEqualsL(1, Bestiary.Count, 'a newer format''s entry is read');
  TestKit.CheckEqualsL(t.maxHit, Troll_^.maxHit, 'as it was');
  Bestiary.Met(kobold);
  BeastFil.Flush;
  TestKit.CheckEqualsL(SizeOf(h) + h.entrySize, FileBytes(BeastFil.FILE_NAME), 'and never written over');
  { an older version than any made is damaged }
  h.version := 0;
  h.entrySize := SizeOf(Bestiary.TBeast);
  Assign(f, 'TBEAST.DAT');
  Rewrite(f, 1);
  BlockWrite(f, h, SizeOf(h));
  BlockWrite(f, t, SizeOf(t));
  Close(f);
  BeastFil.LoadFrom('TBEAST.DAT');
  TestKit.CheckEqualsL(0, Bestiary.Count, 'version 0 reads as none');
  { the same name twice: the second is dropped, and that is no reason to keep from writing the file }
  h.version := 1;
  h.count := 2;
  Assign(f, 'TBEAST.DAT');
  Rewrite(f, 1);
  BlockWrite(f, h, SizeOf(h));
  BlockWrite(f, t, SizeOf(t));
  BlockWrite(f, t, SizeOf(t));
  Close(f);
  BeastFil.LoadFrom('TBEAST.DAT');
  TestKit.CheckEqualsL(1, Bestiary.Count, 'a name twice is read once');
  TestKit.Check(not Bestiary.readOnly, 'and the file stays writable');

  { the full table }
  Bestiary.Clear;
  for i := 1 to Bestiary.MAX_ENTRIES + 1 do begin
    Str(i, s);
    kobold^.name := 'K' + s;
    Bestiary.Met(kobold);
  end;
  TestKit.CheckEqualsL(Bestiary.MAX_ENTRIES, Bestiary.Count, 'the table stops full');
  TestKit.CheckEqualsL(0, Bestiary.Find('K' + s), 'the kind past it is not kept');
  TestKit.Check(BeastFil.WriteTo('TBEAST.DAT'), 'a full table is written');
  BeastFil.LoadFrom('TBEAST.DAT');
  TestKit.CheckEqualsL(Bestiary.MAX_ENTRIES, Bestiary.Count, 'and read back whole');
  Bestiary.Clear;

  { the sage's word (#868): a troll's record fills in an entry, the party's counts and what it learned kept }
  troll^.iconDimensions := 2 or Types.ICON_LARGE;
  troll^.levelHighest := 6;
  { acCur holds 60 - AC: AC 4 }
  troll^.acCur := 56;
  troll^.effectsAddr := nil;
  AddEffect(troll, C_EFFECT.BLESS);
  AddEffect(troll, C_EFFECT.REGEN3);
  AddEffect(troll, C_EFFECT.NO_PARA_POISON);
  FillChar(t, SizeOf(t), 0);
  t.name := 'TROLL';
  t.acLo := 3;
  t.acHi := 6;
  t.seen := 3;
  t.killed := 1;
  t.maxHit := 9;
  t.known[1] := LongInt(1) shl (C_BEAST.ATK_POISON - 32);
  Bestiary.dirty := False;
  TestKit.Check(BeastFil.Tell(t, troll), 'the sage tells something new');
  TestKit.Check(not Bestiary.dirty, 'Tell leaves marking the Bestiary to its caller');
  TestKit.Check(Bestiary.Knows(t, C_BEAST.SIZE_KNOWN) and Bestiary.Knows(t, C_BEAST.LARGE), 'Large, from the icon');
  TestKit.Check(Bestiary.Knows(t, C_BEAST.HD_KNOWN), 'hit dice known');
  TestKit.CheckEqualsL(6, t.hd, 'six of them');
  TestKit.CheckEqualsL(4, t.acLo, 'the exact armor class (low)');
  TestKit.CheckEqualsL(4, t.acHi, 'the exact armor class (high)');
  TestKit.Check(Bestiary.Knows(t, C_BEAST.REGENERATES), 'eff 98 regenerates');
  TestKit.Check(Bestiary.Knows(t, C_BEAST.IMMUNE_PARALYSIS) and Bestiary.Knows(t, C_BEAST.IMMUNE_POISON),
                'eff 111: both of its immunities');
  TestKit.Check(not Bestiary.Knows(t, C_BEAST.IMMUNE_FIRE) and not Bestiary.Knows(t, C_BEAST.MAGIC_RES),
                'nothing its effects do not say');
  TestKit.Check(Bestiary.Knows(t, C_BEAST.ATK_POISON), 'what the party learned stays');
  TestKit.Check((t.seen = 3) and (t.killed = 1) and (t.maxHit = 9), 'seen, killed and the worst blow are the party''s');
  TestKit.Check(Bestiary.Knows(t, C_BEAST.TOLD), 'marked told: no ?? on the entry page');
  TestKit.Check(not BeastFil.Tell(t, troll), 'told twice, nothing new');
  { an entry the party learned whole in play: telling it only marks it told, which is nothing to pay for }
  t.known[0] := t.known[0] and not (LongInt(1) shl C_BEAST.TOLD);
  TestKit.Check(not BeastFil.Tell(t, troll), 'all known already: nothing new');
  TestKit.Check(Bestiary.Knows(t, C_BEAST.TOLD), 'but marked told');
  { a man-sized record clears a Large the entry held; the hit dice of less than one stay 0 }
  troll^.iconDimensions := 1;
  troll^.levelHighest := 0;
  TestKit.Check(BeastFil.Tell(t, troll), 'a different record tells something');
  TestKit.Check(Bestiary.Knows(t, C_BEAST.SIZE_KNOWN) and not Bestiary.Knows(t, C_BEAST.LARGE), 'man-sized now');
  TestKit.CheckEqualsL(0, t.hd, 'less than a hit die');
  { every row of the table stands for a fact the entry page lists }
  ok := True;
  for i := 1 to C_BEAST.EFFECT_FACTS_COUNT do
    with C_BEAST.EFFECT_FACTS[i] do
      if not ((fact in [C_BEAST.FIRST_DEFENSE..C_BEAST.LAST_DEFENSE]) or
              (fact in [C_BEAST.FIRST_ATTACK..C_BEAST.LAST_ATTACK])) then
        ok := False;
  TestKit.Check(ok, 'every effect''s fact is a defense or an attack');
  while troll^.effectsAddr <> nil do begin
    e := troll^.effectsAddr;
    troll^.effectsAddr := e^.next;
    FreeMem(e, SizeOf(Types.TEffectRec));
  end;

  FileUtil.DeleteFile('TBEAST.DAT');
  FileUtil.DeleteFile(BeastFil.FILE_NAME);
  FileUtil.DeleteFile('BESTIARY.BAD');
  TestKit.Done;
end.

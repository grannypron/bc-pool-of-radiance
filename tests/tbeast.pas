{ Tests Bestiary discovery, learned combat facts, capacity limits, and
  BESTIARY.DAT persistence (#842). Also covers damaged and newer-format files,
  plus the sage filling an entry from a creature record (#868), the entry page's
  lists and their layout (#1114), and the facts #1110, #1122 and #1142 added,
  from the sage and from what the party sees in a fight. }
{$I COMPILER.INC}
program TBeast;

uses Types, GameVars, C_GBVM, C_STATUS, C_IFC, C_BEAST, C_EFFECT, C_EQUIP, C_ITEM, FileUtil, Bestiary, BeastFil,
  EffHndlr, CharHlp, TestKit;

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
  { a kind another game met, met here too }
  beholder: Types.PCharRecord;
  b: Bestiary.PBeast;
  t: Bestiary.TBeast;
  i: Word;
  f: file;
  h: THeader;
  pad: array[1..8] of Byte;
  s: String;
  e: Types.PEffectRec;
  ok: Boolean;
  { a fact's place in the entry page's lists, 0 for none }
  listed: array[0..C_BEAST.LAST_FACT] of Byte;
  fact: Byte;
  defenses: Boolean;
  sword: Types.TItemRec;
  node: Types.TEffectRec;

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

{ Free the creature's effects list. }
procedure FreeEffects(p: Types.PCharRecord);
var
  n: Types.PEffectRec;
begin
  while p^.effectsAddr <> nil do begin
    n := p^.effectsAddr;
    p^.effectsAddr := n^.next;
    FreeMem(n, SizeOf(Types.TEffectRec));
  end;
end;

{ What the sage tells of a creature whose record carries the effects e1..e4 (0 for none): the entry she fills, from
  nothing. }
procedure TellOf(var t: Bestiary.TBeast; e1, e2, e3, e4: Byte);
begin
  FreeEffects(troll);
  if e1 <> 0 then AddEffect(troll, e1);
  if e2 <> 0 then AddEffect(troll, e2);
  if e3 <> 0 then AddEffect(troll, e3);
  if e4 <> 0 then AddEffect(troll, e4);
  FillChar(t, SizeOf(t), 0);
  t.acLo := C_BEAST.AC_NO_LOW;
  t.acHi := C_BEAST.AC_NO_HIGH;
  if BeastFil.Tell(t, troll) then ;
end;

{ The entry the party has for name, nil for none. }
function EntryOf(name: String): Bestiary.PBeast;
begin
  EntryOf := Bestiary.Entry(Bestiary.Find(name));
end;

{ Whether the party has learned fact of the kind named name. }
function Learned(name: String; fact: Byte): Boolean;
begin
  Learned := (EntryOf(name) <> nil) and Bestiary.Knows(EntryOf(name)^, fact);
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
  TestKit.Check(Bestiary.Knows(Troll_^, C_BEAST.MET_HERE), 'but that it was met in this game');
  TestKit.CheckEqualsL(28, C_BEAST.MET_HERE, 'Pool''s mark is bit 28, the first game''s');
  TestKit.Check((C_BEAST.MET_HERE >= C_BEAST.FIRST_GAME_MARK) and (C_BEAST.MET_HERE <= C_BEAST.LAST_GAME_MARK) and
                (C_BEAST.TOLD < C_BEAST.FIRST_GAME_MARK) and (C_BEAST.LAST_GAME_MARK < C_BEAST.ATK_POISON),
                'the game marks are bits of their own');
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
  { the entry page's two lists: each fact in one place of one list, with a name that fits a column }
  FillChar(listed, SizeOf(listed), 0);
  ok := True;
  for defenses := False to True do begin
    i := 1;
    fact := BeastFil.FactAt(defenses, i);
    while fact <> 0 do begin
      if (fact > C_BEAST.LAST_FACT) or (listed[fact] <> 0) or (BeastFil.FactName(fact) = '') or
         (Length(BeastFil.FactName(fact)) > 16) then
        ok := False
      else
        listed[fact] := i;
      Inc(i);
      fact := BeastFil.FactAt(defenses, i);
    end;
  end;
  TestKit.Check(ok, 'each listed fact is listed once, by a name of 16 characters at most');
  TestKit.CheckEqualsL(28, i - 1, 'the defenses, listed last, are 28');
  TestKit.CheckEqualsL(13, listed[C_BEAST.ATK_HOLD], 'and the attacks 13, the hold last');
  TestKit.Check((listed[C_BEAST.SIZE_KNOWN] = 0) and (listed[C_BEAST.LARGE] = 0) and (listed[C_BEAST.HD_KNOWN] = 0) and
                (listed[C_BEAST.TOLD] = 0) and (listed[C_BEAST.MET_HERE] = 0) and
                (listed[C_BEAST.POOLS_NEEDS_PLUS_2] = 0) and (listed[C_BEAST.POOLS_ATK_CONFUSE] = 0),
                'what it is, the sage''s mark, the game marks and Pools'' own facts are in neither list');
  TestKit.CheckEqualsL(1, listed[C_BEAST.HALF_BLUNT], 'the defenses start with the halved damage');
  TestKit.CheckEqualsL(8, listed[C_BEAST.HALF_SILVER], 'silver''s half among them');
  TestKit.CheckEqualsL(18, listed[C_BEAST.SILVER_OR_MAGIC], 'silver or magic after magic weapons only');
  TestKit.CheckEqualsL(7, listed[C_BEAST.ATK_FIRE], 'the attacks: the burning touch after the first six');
  ok := True;
  for i := 1 to C_BEAST.EFFECT_FACTS_COUNT do
    if listed[C_BEAST.EFFECT_FACTS[i].fact] = 0 then
      ok := False;
  TestKit.Check(ok, 'every effect''s fact is a defense or an attack');

  { the facts #1110, #1122 and #1142 added, as the sage tells them from the creatures' records }
  TellOf(t, C_EFFECT.NEED_SILVER, 0, 0, 0);
  TestKit.Check(Bestiary.Knows(t, C_BEAST.SILVER_OR_MAGIC) and not Bestiary.Knows(t, C_BEAST.HALF_SILVER),
                'the wight: silver or magic');
  TellOf(t, C_EFFECT.SILVER_MAGIC, 0, 0, 0);
  TestKit.Check(Bestiary.Knows(t, C_BEAST.SILVER_OR_MAGIC) and Bestiary.Knows(t, C_BEAST.HALF_SILVER),
                'the wraith: silver or magic, and half from silver');
  TellOf(t, C_EFFECT.BLINKING, C_EFFECT.POISON_HIT_M2, 0, 0);
  TestKit.Check(Bestiary.Knows(t, C_BEAST.BLINKS) and Bestiary.Knows(t, C_BEAST.ATK_POISON), 'the phase spider blinks');
  TellOf(t, C_EFFECT.DISPLACED, 0, 0, 0);
  TestKit.Check(Bestiary.Knows(t, C_BEAST.DISPLACED), 'the displacer beast is displaced');
  TellOf(t, C_EFFECT.CAN_FIGHT_ON, 0, 0, 0);
  TestKit.Check(Bestiary.Knows(t, C_BEAST.FIGHTS_ON), 'the wild boar fights on');
  TellOf(t, C_EFFECT.GASEOUS, 0, 0, 0);
  TestKit.Check(Bestiary.Knows(t, C_BEAST.GAS_ESCAPE), 'the vampire escapes as gas');
  TellOf(t, C_EFFECT.MUMMY_FEAR, 0, 0, 0);
  TestKit.Check(Bestiary.Knows(t, C_BEAST.ATK_FEAR), 'the mummy''s fear');
  TellOf(t, C_EFFECT.BLOOD_ATTACH, 0, 0, 0);
  TestKit.Check(Bestiary.Knows(t, C_BEAST.ATK_BLOOD), 'the stirge drains blood');
  TellOf(t, C_EFFECT.ACID_SQUIRT, C_EFFECT.ANHKHEG_ACID, 0, 0);
  TestKit.Check(Bestiary.Knows(t, C_BEAST.ATK_ACID), 'the anhkheg''s acid');
  TellOf(t, C_EFFECT.KREEN_PARA, C_EFFECT.KREEN_DODGE, 0, 0);
  TestKit.Check(Bestiary.Knows(t, C_BEAST.DODGES_MISSILES), 'the thri-kreen dodges missiles');
  TellOf(t, C_EFFECT.BOULDER_DODGE, 0, 0, 0);
  TestKit.Check(Bestiary.Knows(t, C_BEAST.DODGES_BOULDERS), 'a giant dodges boulders');
  TellOf(t, C_EFFECT.EFREETI_FIRE, 0, 0, 0);
  TestKit.Check(Bestiary.Knows(t, C_BEAST.RESISTS_FIRE), 'the efreeti resists fire');
  TellOf(t, C_EFFECT.RING_FIRE_RES, 0, 0, 0);
  TestKit.Check(Bestiary.Knows(t, C_BEAST.RESISTS_FIRE), 'so does one wearing a Ring of Fire Resistance');
  TellOf(t, C_EFFECT.SEE_INVISIBLE, C_EFFECT.FIRE_TOUCH, C_EFFECT.DRAGON_FEAR, C_EFFECT.DRAGON_BREATH);
  TestKit.Check(Bestiary.Knows(t, C_BEAST.SEES_INVISIBLE) and Bestiary.Knows(t, C_BEAST.ATK_FIRE) and
                Bestiary.Knows(t, C_BEAST.ATK_FEAR) and Bestiary.Knows(t, C_BEAST.ATK_BREATH),
                'Tyranthraxus sees the invisible, burns, frightens and breathes');
  TellOf(t, C_EFFECT.CAMOUFLAGE, 0, 0, 0);
  TestKit.Check(Bestiary.Knows(t, C_BEAST.TURNS_INVISIBLE), 'the thief in an elven cloak turns invisible');
  TellOf(t, C_EFFECT.REAR_CLAW_RAKE, 0, 0, 0);
  TestKit.Check(Bestiary.Knows(t, C_BEAST.ATK_RAKE), 'the tiger rakes');
  TellOf(t, C_EFFECT.BITE_ATTACH, 0, 0, 0);
  TestKit.Check(Bestiary.Knows(t, C_BEAST.ATK_HOLD), 'the giant mantis holds fast');
  FreeEffects(troll);

  { the entry page's layout: a told entry with an empty list has None under it, a row the layout counts (#1114) }
  FillChar(t, SizeOf(t), 0);
  for i := 1 to 10 do
    ok := Bestiary.Mark(t, BeastFil.FactAt(True, i), True);
  TestKit.CheckEqualsL(10, BeastFil.KnownCount(t, True), 'ten defenses known');
  TestKit.CheckEqualsL(0, BeastFil.KnownCount(t, False), 'and no attack');
  TestKit.CheckEqualsL(15, BeastFil.ListRows(t), 'untold: two headings, ten, a blank line and two ??');
  ok := Bestiary.Mark(t, C_BEAST.TOLD, True);
  TestKit.CheckEqualsL(14, BeastFil.ListRows(t), 'told, the juju zombie''s: None under the attacks');
  TestKit.Check(BeastFil.ListRows(t) > 13, 'more than the 13 rows one a line: two columns');
  ok := Bestiary.Mark(t, BeastFil.FactAt(False, 1), True);
  TestKit.CheckEqualsL(14, BeastFil.ListRows(t), 'an attack in place of None');
  for i := 1 to 10 do
    ok := Bestiary.Mark(t, BeastFil.FactAt(True, i), False);
  TestKit.CheckEqualsL(5, BeastFil.ListRows(t), 'no defense: None under the defenses');

  { what the party sees in a fight, a long sword's blows (no base item has properties) }
  Bestiary.Clear;
  GameVars.ifcState := C_IFC.IN_COMBAT;
  GetMem(CharHlp.baseItems, SizeOf(CharHlp.baseItems^));
  FillChar(CharHlp.baseItems^, SizeOf(CharHlp.baseItems^), 0);
  FillChar(sword, SizeOf(sword), 0);
  sword.itemType := C_ITEM.LONG_SWORD;
  a^.equipped[C_EQUIP.WEAPON] := @sword;
  kobold^.equipped[C_EQUIP.WEAPON] := @sword;
  GetMem(troll^.combatAddr, SizeOf(Types.TCombatRec));
  FillChar(troll^.combatAddr^, SizeOf(Types.TCombatRec), 0);
  troll^.name := 'WIGHT';
  GameVars.curChar := kobold;
  GameVars.pendingDamage := 6;
  EffHndlr.EffNeedSilver(troll, nil, False);
  TestKit.CheckEqualsL(0, GameVars.pendingDamage, 'a plain blow does nothing to the wight');
  TestKit.Check(not Learned('WIGHT', C_BEAST.SILVER_OR_MAGIC), 'a monster''s blow shows the party nothing');
  GameVars.curChar := a;
  GameVars.pendingDamage := 0;
  EffHndlr.EffNeedSilver(troll, nil, False);
  TestKit.Check(not Learned('WIGHT', C_BEAST.SILVER_OR_MAGIC), 'nor a blow that would have done no harm');
  GameVars.pendingDamage := 6;
  EffHndlr.EffNeedSilver(troll, nil, False);
  TestKit.Check(Learned('WIGHT', C_BEAST.SILVER_OR_MAGIC), 'a party member''s plain blow shows it (#1110)');
  troll^.name := 'WRAITH';
  sword.nameIds[3] := C_ITEM.NAME_SILVER;
  GameVars.pendingDamage := 6;
  EffHndlr.EffSilverMagic(troll, nil, False);
  TestKit.CheckEqualsL(3, GameVars.pendingDamage, 'silver does half to the wraith');
  TestKit.Check(Learned('WRAITH', C_BEAST.HALF_SILVER) and not Learned('WRAITH', C_BEAST.SILVER_OR_MAGIC),
                'and shows it');
  sword.nameIds[3] := 0;
  GameVars.pendingDamage := 6;
  EffHndlr.EffSilverMagic(troll, nil, False);
  TestKit.Check((GameVars.pendingDamage = 0) and Learned('WRAITH', C_BEAST.SILVER_OR_MAGIC),
                'a plain blow nothing, which shows it needs silver or magic');
  troll^.name := 'PHASE SPIDER';
  troll^.combatAddr^.initiative := 0;
  EffHndlr.EffBlinking(troll, nil, False);
  TestKit.Check(not Learned('PHASE SPIDER', C_BEAST.BLINKS), 'a spider that has acted does not blink');
  troll^.combatAddr^.initiative := 3;
  GameVars.forcedMiss := False;
  EffHndlr.EffBlinking(troll, nil, False);
  TestKit.Check(GameVars.forcedMiss and Learned('PHASE SPIDER', C_BEAST.BLINKS), 'one yet to act blinks (#1122)');
  { a creature in a Cloak of Displacement: the displacer beast is not displaced (#1183) }
  troll^.name := 'HOBGOBLIN';
  FillChar(node, SizeOf(node), 0);
  GameVars.curChar := kobold;
  EffHndlr.EffDisplaced(troll, @node, False);
  TestKit.Check(not Learned('HOBGOBLIN', C_BEAST.DISPLACED), 'a monster''s miss on it shows nothing');
  node.strength := 0;
  GameVars.curChar := a;
  GameVars.forcedMiss := False;
  EffHndlr.EffDisplaced(troll, @node, False);
  TestKit.Check(GameVars.forcedMiss and Learned('HOBGOBLIN', C_BEAST.DISPLACED),
                'a party member''s first attack misses, and shows it (#1122)');
  troll^.name := 'EFREETI';
  GameVars.elementMask := C_EFFECT.ELEM_COLD;
  GameVars.pendingDamage := 9;
  EffHndlr.EffEfreetiFire(troll, nil, False);
  TestKit.Check(not Learned('EFREETI', C_BEAST.RESISTS_FIRE), 'cold shows no fire resistance');
  GameVars.elementMask := C_EFFECT.ELEM_FIRE;
  EffHndlr.EffEfreetiFire(troll, nil, False);
  TestKit.Check(Learned('EFREETI', C_BEAST.RESISTS_FIRE), 'fire does (#1142)');
  troll^.name := 'WIGHT';
  GameVars.ifcState := C_IFC.INDOORS;
  Bestiary.Clear;
  GameVars.pendingDamage := 6;
  EffHndlr.EffNeedSilver(troll, nil, False);
  TestKit.CheckEqualsL(0, Bestiary.Count, 'outside a fight nothing is learned');
  GameVars.elementMask := 0;
  a^.equipped[C_EQUIP.WEAPON] := nil;
  kobold^.equipped[C_EQUIP.WEAPON] := nil;
  FreeMem(troll^.combatAddr, SizeOf(Types.TCombatRec));
  troll^.combatAddr := nil;
  troll^.name := 'TROLL';
  FreeMem(CharHlp.baseItems, SizeOf(CharHlp.baseItems^));
  Bestiary.Clear;

  { another game's entry, read from a shared file: its mark stays, and this game's is added once it is met here }
  FillChar(t, SizeOf(t), 0);
  t.name := 'BEHOLDER';
  t.acLo := C_BEAST.AC_NO_LOW;
  t.acHi := C_BEAST.AC_NO_HIGH;
  { bit 29, Curse of the Azure Bonds' mark }
  ok := Bestiary.Mark(t, 29, True);
  TestKit.Check(Bestiary.Append(t), 'an entry Curse met');
  b := Bestiary.Entry(Bestiary.Find('BEHOLDER'));
  TestKit.Check(not Bestiary.Knows(b^, C_BEAST.MET_HERE), 'is not marked met here when read');
  beholder := NewCreature('BEHOLDER', nil);
  Bestiary.Met(beholder);
  b := Bestiary.Entry(Bestiary.Find('BEHOLDER'));
  TestKit.Check(Bestiary.Knows(b^, C_BEAST.MET_HERE) and Bestiary.Knows(b^, 29),
                'met here too, it carries both games'' marks');
  FreeMem(beholder, SizeOf(Types.TCharRecord));

  FileUtil.DeleteFile('TBEAST.DAT');
  FileUtil.DeleteFile(BeastFil.FILE_NAME);
  FileUtil.DeleteFile('BESTIARY.BAD');
  TestKit.Done;
end.

{ Statistics kept per character and per game (#611): kills (in all and by kind), damage done and taken, hit points
  healed, raises, poisonings, loot and spells. Resident, not overlaid, so counting a blow in combat loads no overlay.
  Counters are LongInts that stop at MaxLongInt rather than wrap. A party member's block is on the heap, found by its
  record and name as the usual spells are (SaveLoad); the game's block is here. Both are kept in small files beside the
  saves: <character>.sts beside a character's file, savgam<x>.sts beside a saved game. }
{$F+,I-}
{$I COMPILER.INC}
unit Stats;

interface

uses Types, FileUtil;

const
  { the counters, by index into TStatBlock.counts }
  KILLS = 1;
  DAMAGE_DONE = 2;
  DAMAGE_TAKEN = 3;
  HEALED_GIVEN = 4;
  HEALED_TAKEN = 5;
  RAISED = 6;
  POISONED = 7;
  ITEMS_LOOTED = 8;
  { net, in copper (the Stats page shows gold): coin a member came away with from the loot after a fight, less what it
    put back into it, so pooling and taking back again come to nothing; may be below zero }
  COIN_LOOTED = 9;
  SPELLS_CAST = 10;
  KNOCKED_DOWN = 11;
  DIED = 12;
  STAT_COUNT = 12;
  { the kill slots in a block: KINDS - 1 kinds of creature by name, then OTHER for every kind past them }
  KINDS = 48;
  { the counters' names, for the Stats page }
  NAMES: array[1..STAT_COUNT] of string[17] = ('Kills', 'Damage done', 'Damage taken', 'Healing given',
    'Healing taken', 'Raised', 'Poisoned', 'Items looted', 'Coin looted (net)', 'Spells cast', 'Knocked down', 'Died');

type
  TKill = record
    name: string[Types.NAME_LEN];
    count: LongInt;
  end;
  TStatBlock = record
    counts: array[1..STAT_COUNT] of LongInt;
    kindCount: Byte;
    kills: array[1..KINDS] of TKill;
  end;
  PStatBlock = ^TStatBlock;

var
  { the game's totals: every count a party member makes }
  game: TStatBlock;

{ The block of party member creature, made empty the first time; nil for anyone else. }
function BlockOf(creature: Types.PCharRecord): PStatBlock;

{ Add n to counter stat of creature, when it is a party member, and of the game. }
procedure Count(creature: Types.PCharRecord; stat: Byte; n: LongInt);

{ CharHlp.InflictDamage's report: victim lost hp hit points to actor (curChar, the creature acting; may be nil), and was
  up (okay or animated) before it. In combat a party member's blow on a creature outside the party counts as damage
  done, and its fall as a kill of the victim's kind, in the Bestiary too (#842); a party member's loss counts as damage
  taken, its fall as knocked down, and its death as died. }
procedure Damaged(actor, victim: Types.PCharRecord; hp: Byte; wasUp: Boolean);

{ A party member that died other than by InflictDamage's blow (which Damaged counts): bled to death in combat, or
  killed outright by poison, a level drain, rot or the like (EffHndlr.InflictStatusMsg). }
procedure Death(creature: Types.PCharRecord);

{ FxEngine.RestoreHitPoints's report: target gained hp; healing given is credited to actor while a spell, or an item's
  spell, is being resolved, or when byPower (a paladin's laying on of hands). }
procedure Healed(actor, target: Types.PCharRecord; hp: Byte; byPower: Boolean);

{ Around one action in the loot menu after a fight: MarkCoins notes each party member's coin (copper to platinum, at its
  worth in copper), and SettleCoins adds what each has gained since, or takes off what it put back, to its Coin looted
  (net) and the game's. }
procedure MarkCoins;
procedure SettleCoins;

{ Forget creature's block; called before its record is freed. }
procedure Forget(creature: Types.PCharRecord);

{ Clear the game's totals, for a game that has none (a new one, or a save made before them). }
procedure ResetGame;

{ Write creature's block as file <base>.sts of save s (FileUtil.WriteToSet); for a creature with no block the save
  erases the old file instead. False when the write failed. }
function WriteChar(var s: FileUtil.TFileSet; creature: Types.PCharRecord; base: FileUtil.TSetName): Boolean;

{ Read creature's block from <fn>.sts: one of this format, made for a character of this name and randByte. Without one
  the creature starts with an empty block when it next counts. }
procedure ReadChar(creature: Types.PCharRecord; fn: Types.TPathStr);

{ Write the game's totals as file name of save s (True when they were written) / read them back from file fn (the
  totals are cleared when the file is not one of this format). }
function WriteGame(var s: FileUtil.TFileSet; name: FileUtil.TSetName): Boolean;
procedure ReadGame(fn: Types.TPathStr);

implementation

uses GameVars, C_GBVM, C_STATUS, C_IFC, Party, MoneyCal, Bestiary, StrUtil;

const
  ENTRIES = Types.MAX_PARTY;
  SIG = 'STAT';
  VERSION = 1;

type
  TStatFile = record
    sig: string[4];
    version: Byte;
    name: string[Types.NAME_LEN];
    randByte: Byte;
    block: TStatBlock;
  end;

var
  owner: array[1..ENTRIES] of Types.PCharRecord;
  ownerName: array[1..ENTRIES] of string[Types.NAME_LEN];
  blocks: array[1..ENTRIES] of PStatBlock;
  { MarkCoins's party, and each member's coin worth then }
  marked: array[1..ENTRIES] of Types.PCharRecord;
  markedWorth: array[1..ENTRIES] of LongInt;
  { the file record being read or written: here rather than on the stack, being a kilobyte }
  rec: TStatFile;

procedure AddTo(var counter: LongInt; n: LongInt);
begin
  if n <= 0 then Exit;
  if counter > MaxLongInt - n then
    counter := MaxLongInt
  else
    Inc(counter, n);
end;

{ Count a kill of a creature called name in b: under its own name while b has room for another kind, else OTHER. }
procedure AddKill(var b: TStatBlock; name: Types.TStr40);
var
  i: Byte;
begin
  if Length(name) > Types.NAME_LEN then
    name[0] := Chr(Types.NAME_LEN);
  i := 1;
  while (i <= b.kindCount) and (b.kills[i].name <> name) do
    Inc(i);
  if i > b.kindCount then begin
    if b.kindCount < KINDS - 1 then begin
      Inc(b.kindCount);
      i := b.kindCount;
    end else begin
      { the last slot gathers every kind past the others }
      i := KINDS;
      b.kindCount := KINDS;
      name := 'OTHER';
    end;
    b.kills[i].name := name;
    if i < KINDS then
      b.kills[i].count := 0;
  end;
  Stats.AddTo(b.kills[i].count, 1);
end;

function FindEntry(creature: Types.PCharRecord): Byte;
var
  i: Byte;
begin
  FindEntry := 0;
  for i := 1 to ENTRIES do
    if (owner[i] = creature) and (owner[i] <> nil) and (ownerName[i] = creature^.name) then
      FindEntry := i;
end;

{ An entry for creature, with an empty block on the heap; 0 when every entry is taken. }
function NewEntry(creature: Types.PCharRecord): Byte;
var
  i: Byte;
begin
  NewEntry := 0;
  for i := 1 to ENTRIES do
    if (owner[i] = nil) or (ownerName[i] <> owner[i]^.name) then begin
      if blocks[i] = nil then
        GetMem(blocks[i], SizeOf(TStatBlock));
      FillChar(blocks[i]^, SizeOf(TStatBlock), 0);
      owner[i] := creature;
      ownerName[i] := creature^.name;
      NewEntry := i;
      Exit;
    end;
end;

function BlockOf(creature: Types.PCharRecord): PStatBlock;
var
  i: Byte;
begin
  BlockOf := nil;
  if not Party.IsPartyMember(creature) then Exit;
  i := Stats.FindEntry(creature);
  if i = 0 then
    i := Stats.NewEntry(creature);
  if i <> 0 then
    BlockOf := blocks[i];
end;

procedure Count(creature: Types.PCharRecord; stat: Byte; n: LongInt);
var
  b: PStatBlock;
begin
  if not Party.IsPartyMember(creature) then Exit;
  b := Stats.BlockOf(creature);
  if b <> nil then
    Stats.AddTo(b^.counts[stat], n);
  Stats.AddTo(game.counts[stat], n);
end;

procedure Damaged(actor, victim: Types.PCharRecord; hp: Byte; wasUp: Boolean);
var
  b: PStatBlock;
  down: Boolean;
begin
  down := wasUp and not (victim^.status in [C_STATUS.OKAY, C_STATUS.ANIMATED]);
  if Party.IsPartyMember(victim) then begin
    Stats.Count(victim, DAMAGE_TAKEN, hp);
    if down then
      Stats.Count(victim, KNOCKED_DOWN, 1);
    if victim^.status = C_STATUS.DEAD_STATUS then
      Stats.Count(victim, DIED, 1);
  end else if (GameVars.ifcState = C_IFC.IN_COMBAT) and (actor <> victim) and Party.IsPartyMember(actor) then begin
    Stats.Count(actor, DAMAGE_DONE, hp);
    if down then begin
      Stats.Count(actor, KILLS, 1);
      b := Stats.BlockOf(actor);
      if b <> nil then
        Stats.AddKill(b^, victim^.name);
      Stats.AddKill(game, victim^.name);
      Bestiary.Killed(victim);
    end;
  end;
end;

procedure Death(creature: Types.PCharRecord);
begin
  Stats.Count(creature, DIED, 1);
end;

procedure Healed(actor, target: Types.PCharRecord; hp: Byte; byPower: Boolean);
begin
  Stats.Count(target, HEALED_TAKEN, hp);
  if byPower or (GameVars.spellId <> 0) then
    Stats.Count(actor, HEALED_GIVEN, hp);
end;

{ counter plus n, n of either sign, held within -MaxLongInt..MaxLongInt }
procedure AddSigned(var counter: LongInt; n: LongInt);
begin
  if (n > 0) and (counter > MaxLongInt - n) then
    counter := MaxLongInt
  else if (n < 0) and (counter < -MaxLongInt - n) then
    counter := -MaxLongInt
  else
    Inc(counter, n);
end;

procedure MarkCoins;
var
  p: Types.PCharRecord;
  n: Byte;
begin
  FillChar(marked, SizeOf(marked), 0);
  p := GameVars.creatureList;
  n := 0;
  while (p <> nil) and (n < GameVars.zone1^[C_GBVM.PARTY_SIZE]) and (n < ENTRIES) do begin
    Inc(n);
    marked[n] := p;
    markedWorth[n] := MoneyCal.CreatureCopper(p);
    p := p^.nextCharAddr;
  end;
end;

procedure SettleCoins;
var
  n: Byte;
  delta: LongInt;
  b: PStatBlock;
begin
  for n := 1 to ENTRIES do
    if (marked[n] <> nil) and Party.IsPartyMember(marked[n]) then begin
      delta := MoneyCal.CreatureCopper(marked[n]) - markedWorth[n];
      if delta <> 0 then begin
        b := Stats.BlockOf(marked[n]);
        if b <> nil then
          Stats.AddSigned(b^.counts[COIN_LOOTED], delta);
        Stats.AddSigned(game.counts[COIN_LOOTED], delta);
      end;
    end;
  FillChar(marked, SizeOf(marked), 0);
end;

procedure Forget(creature: Types.PCharRecord);
var
  i: Byte;
begin
  i := Stats.FindEntry(creature);
  if i <> 0 then
    owner[i] := nil;
end;

procedure ResetGame;
begin
  FillChar(game, SizeOf(game), 0);
end;

function WriteChar(var s: FileUtil.TFileSet; creature: Types.PCharRecord; base: FileUtil.TSetName): Boolean;
var
  i: Byte;
begin
  WriteChar := True;
  i := Stats.FindEntry(creature);
  if i = 0 then begin
    FileUtil.AddToSet(s, base + '.sts', False);
    Exit;
  end;
  FillChar(rec, SizeOf(rec), 0);
  rec.sig := SIG;
  rec.version := VERSION;
  rec.name := creature^.name;
  rec.randByte := creature^.randByte;
  rec.block := blocks[i]^;
  WriteChar := FileUtil.WriteToSet(s, base + '.sts', rec, SizeOf(rec));
end;

{ Read a TStatFile from name into rec: True when it is whole and of this format. }
function ReadFile(name: Types.TPathStr): Boolean;
var
  ok: Boolean;
  i: Byte;
begin
  ok := FileUtil.ReadRecord(name, rec, SizeOf(rec)) and StrUtil.FitLength(rec.sig, SizeOf(rec.sig) - 1) and
        (rec.sig = SIG) and (rec.version = VERSION) and (rec.block.kindCount <= KINDS) and
        StrUtil.FitLength(rec.name, SizeOf(rec.name) - 1);
  { a name whose length byte is past its field refuses the file, as a foreign one is (#917) }
  if ok then
    for i := 1 to rec.block.kindCount do
      ok := ok and StrUtil.FitLength(rec.block.kills[i].name, SizeOf(rec.block.kills[i].name) - 1);
  ReadFile := ok;
end;

procedure ReadChar(creature: Types.PCharRecord; fn: Types.TPathStr);
var
  i: Byte;
begin
  Stats.Forget(creature);
  if not Stats.ReadFile(fn + '.sts') then Exit;
  if (rec.name <> creature^.name) or (rec.randByte <> creature^.randByte) then Exit;
  i := Stats.NewEntry(creature);
  if i <> 0 then
    blocks[i]^ := rec.block;
end;

function WriteGame(var s: FileUtil.TFileSet; name: FileUtil.TSetName): Boolean;
begin
  FillChar(rec, SizeOf(rec), 0);
  rec.sig := SIG;
  rec.version := VERSION;
  rec.block := game;
  WriteGame := FileUtil.WriteToSet(s, name, rec, SizeOf(rec));
end;

procedure ReadGame(fn: Types.TPathStr);
begin
  if Stats.ReadFile(fn) then
    game := rec.block
  else
    Stats.ResetGame;
end;

begin
  FillChar(owner, SizeOf(owner), 0);
  FillChar(blocks, SizeOf(blocks), 0);
  FillChar(game, SizeOf(game), 0);
  FillChar(marked, SizeOf(marked), 0);
end.

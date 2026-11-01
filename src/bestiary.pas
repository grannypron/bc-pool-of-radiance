{ Tracks what the party has learned about each kind of creature (#842). Entries
  are keyed by the name shown to the player. Facts are learned when the
  corresponding rule is observed in play; armor class is narrowed from attack
  rolls, while encounters, kills, hit dice, and maximum damage are counted.

  This knowledge belongs to the player rather than a saved game. BeastFil keeps
  it in BESTIARY.DAT so it carries between games. The resident table grows on
  the heap as new creatures are encountered. }
{$F+,I-}
{$I COMPILER.INC}
unit Bestiary;

interface

uses Types;

const
  { the most kinds the table holds: a port with more creatures raises it (64000 bytes of entries at most) }
  MAX_ENTRIES = 2000;

type
  { one kind of creature: 32 bytes, as BESTIARY.DAT keeps it }
  TBeast = record
    name: string[Types.NAME_LEN];
    { the facts learned, bit n of the 64 at known[n div 32], bit n mod 32 (C_BEAST) }
    known: array[0..1] of LongInt;
    { the armor class the party's attack rolls allow: acLo <= AC <= acHi, C_BEAST.AC_NO_LOW and AC_NO_HIGH while a side
      is unbounded }
    acLo: ShortInt;
    acHi: ShortInt;
    { its hit dice, once C_BEAST.HD_KNOWN (0 for less than one) }
    hd: ShortInt;
    { the most damage one has done to a party member in one blow }
    maxHit: Byte;
    { the encounters the party has met one in, and the ones the party has felled }
    seen: Word;
    killed: Word;
  end;
  PBeast = ^TBeast;

var
  { BeastFil's: the table has learned something since it was last written; the file read is of a newer format, read and
    never written; the file read was damaged, and goes aside before the next write }
  dirty: Boolean;
  readOnly: Boolean;
  damaged: Boolean;

{ Returns the number of creature kinds in the table. }
function Count: Word;

{ Returns entry 1..Count, or nil when i is outside the table. }
function Entry(i: Word): PBeast;

{ The index of the entry for name, or 0 when there is none. }
function Find(name: Types.TStr40): Word;

{ Returns whether b knows the given C_BEAST fact. }
function Knows(var b: TBeast; fact: Byte): Boolean;

{ Sets or clears a C_BEAST fact in b. Returns True when b changed; the caller
  must mark the table dirty if the entry is retained. }
function Mark(var b: TBeast; fact: Byte; known: Boolean): Boolean;

{ Narrow b's armor class with what one attack roll showed: AC >= bound when lower, else AC <= bound. A bound that
  contradicts the other side (another creature under the same name, or a change in the data) starts that side over. }
procedure NarrowArmor(var b: TBeast; bound: Integer; lower: Boolean);

{ Frees the table and resets it to empty. }
procedure Clear;

{ Add b, an entry read from BESTIARY.DAT, to the end of the table, its armor bounds forgotten when they cross: False,
  and nothing added, for one without a name or of a name the table has, or when there is no room. }
function Append(var b: TBeast): Boolean;

{ The party meets creature, a creature outside it: its kind's seen count goes up, once an encounter however many of the
  kind there are (EclVm's LOAD MONSTER, a fight's start; a meeting that does not fight counts too). The demo's party is
  not the player's: in the demo (#1109) neither this nor Learn, its kin or Killed teach the Bestiary anything, which
  lives outside the saved games. }
procedure Met(creature: Types.PCharRecord);

{ Starts a new encounter so previously seen kinds can increment their counts again. }
procedure NewEncounter;

{ In combat, beast, a creature outside the party, shows fact to the party; witness is the party member on the other
  side of it (the attacker, the caster or the victim), or nil when anyone can see it. Nothing happens otherwise. }
procedure Learn(beast, witness: Types.PCharRecord; fact: Byte);

{ In combat, attacker's blow on beast showed whether beast is Large (the weapon's large-creature dice). }
procedure LearnSize(beast, attacker: Types.PCharRecord; large: Boolean);

{ In combat, attacker's roll on beast, from the front: reach is the roll and attacker's bonus less the range's penalty,
  in the 60 - AC form the attack compares (FxEngine.AttackRoll), and hit what it did. A natural 1 or 20, and an attack
  avoided by displacement or the like, show nothing. }
procedure LearnArmor(beast, attacker: Types.PCharRecord; reach: Integer; hit: Boolean);

{ In combat, attacker, a creature outside the party, hit victim, a party member, for dmg. }
procedure LearnBlow(attacker, victim: Types.PCharRecord; dmg: Byte);

{ The party felled victim (Stats.Damaged's kill): one more killed, and its hit dice known. }
procedure Killed(victim: Types.PCharRecord);

implementation

uses GameVars, C_IFC, C_BEAST, Party{$IFDEF FPC}, TpCompat{$ENDIF};

const
  { the table grows by this many entries }
  GROW = 16;
  { the kinds met in one encounter that are remembered so as to count once; past them a kind counts again }
  MET_MAX = 16;

type
  TBeastArr = array[1..MAX_ENTRIES] of TBeast;
  PBeastArr = ^TBeastArr;

var
  table: PBeastArr;
  { entries in use, and room for }
  used: Word;
  room: Word;
  metIdx: array[1..MET_MAX] of Word;
  metCount: Byte;

function Count: Word;
begin
  Count := used;
end;

function Entry(i: Word): PBeast;
begin
  if (i >= 1) and (i <= used) then
    Entry := @table^[i]
  else
    Entry := nil;
end;

function Find(name: Types.TStr40): Word;
var
  i: Word;
begin
  Find := 0;
  if Length(name) > Types.NAME_LEN then
    name[0] := Chr(Types.NAME_LEN);
  for i := 1 to used do
    if table^[i].name = name then begin
      Find := i;
      Exit;
    end;
end;

function Knows(var b: TBeast; fact: Byte): Boolean;
begin
  Knows := (fact <= C_BEAST.LAST_FACT) and (b.known[fact div 32] and (LongInt(1) shl (fact mod 32)) <> 0);
end;

function Mark(var b: TBeast; fact: Byte; known: Boolean): Boolean;
begin
  Mark := False;
  if (fact > C_BEAST.LAST_FACT) or (Bestiary.Knows(b, fact) = known) then Exit;
  b.known[fact div 32] := b.known[fact div 32] xor (LongInt(1) shl (fact mod 32));
  Mark := True;
end;

{ Set fact in b, the bestiary then to be written when it was not set already. }
procedure SetFact(var b: TBeast; fact: Byte);
begin
  if Bestiary.Mark(b, fact, True) then
    dirty := True;
end;

procedure NarrowArmor(var b: TBeast; bound: Integer; lower: Boolean);
begin
  if bound < C_BEAST.AC_NO_LOW + 1 then
    bound := C_BEAST.AC_NO_LOW + 1;
  if bound > C_BEAST.AC_NO_HIGH - 1 then
    bound := C_BEAST.AC_NO_HIGH - 1;
  if lower then begin
    if bound > b.acLo then begin
      if bound > b.acHi then
        b.acHi := C_BEAST.AC_NO_HIGH;
      b.acLo := bound;
      dirty := True;
    end;
  end else if bound < b.acHi then begin
    if bound < b.acLo then
      b.acLo := C_BEAST.AC_NO_LOW;
    b.acHi := bound;
    dirty := True;
  end;
end;

{ Make room for n entries, keeping those there: False when the format or the heap has none. }
function Reserve(n: Word): Boolean;
var
  p: PBeastArr;
  size: Word;
  more: Word;
begin
  Reserve := True;
  if n <= room then Exit;
  Reserve := False;
  if n > MAX_ENTRIES then Exit;
  more := ((n + GROW - 1) div GROW) * GROW;
  if more > MAX_ENTRIES then
    more := MAX_ENTRIES;
  size := more * SizeOf(TBeast);
  if MaxAvail < size then Exit;
  GetMem(p, size);
  if used > 0 then
    Move(table^, p^, used * SizeOf(TBeast));
  if table <> nil then
    FreeMem(table, room * SizeOf(TBeast));
  table := p;
  room := more;
  Reserve := True;
end;

{ The index of the entry for name, a new empty one at the end when there is none, marked met in this game
  (C_BEAST.MET_HERE); 0 for no name, or no room. }
function Add(name: Types.TStr40): Word;
var
  i: Word;
begin
  Add := 0;
  if Length(name) > Types.NAME_LEN then
    name[0] := Chr(Types.NAME_LEN);
  if name = '' then Exit;
  i := Bestiary.Find(name);
  if i = 0 then begin
    if not Bestiary.Reserve(used + 1) then Exit;
    Inc(used);
    i := used;
    FillChar(table^[i], SizeOf(TBeast), 0);
    table^[i].name := name;
    table^[i].acLo := C_BEAST.AC_NO_LOW;
    table^[i].acHi := C_BEAST.AC_NO_HIGH;
    dirty := True;
  end;
  Bestiary.SetFact(table^[i], C_BEAST.MET_HERE);
  Add := i;
end;

procedure Clear;
begin
  if table <> nil then
    FreeMem(table, room * SizeOf(TBeast));
  table := nil;
  used := 0;
  room := 0;
  dirty := False;
  readOnly := False;
  damaged := False;
  metCount := 0;
end;

function Append(var b: TBeast): Boolean;
begin
  Append := False;
  if (Length(b.name) < 1) or (Length(b.name) > Types.NAME_LEN) or (Bestiary.Find(b.name) <> 0) or
     not Bestiary.Reserve(used + 1) then Exit;
  if b.acLo > b.acHi then begin
    b.acLo := C_BEAST.AC_NO_LOW;
    b.acHi := C_BEAST.AC_NO_HIGH;
  end;
  Inc(used);
  table^[used] := b;
  Append := True;
end;

procedure Met(creature: Types.PCharRecord);
var
  i: Word;
  k: Byte;
begin
  if (creature = nil) or Party.IsPartyMember(creature) or GameVars.demoMode then Exit;
  i := Bestiary.Add(creature^.name);
  if i = 0 then Exit;
  for k := 1 to metCount do
    if metIdx[k] = i then Exit;
  if metCount < MET_MAX then begin
    Inc(metCount);
    metIdx[metCount] := i;
  end;
  if table^[i].seen < $FFFF then
    Inc(table^[i].seen);
  dirty := True;
end;

procedure NewEncounter;
begin
  metCount := 0;
end;

{ The entry of beast when, in combat, beast is outside the party and witness is in it (or nil); else 0, and always 0
  in the demo. }
function Watched(beast, witness: Types.PCharRecord): Word;
begin
  Watched := 0;
  if (beast = nil) or (GameVars.ifcState <> C_IFC.IN_COMBAT) or Party.IsPartyMember(beast) or GameVars.demoMode then
    Exit;
  if (witness <> nil) and not Party.IsPartyMember(witness) then Exit;
  Watched := Bestiary.Add(beast^.name);
end;

procedure Learn(beast, witness: Types.PCharRecord; fact: Byte);
var
  i: Word;
begin
  i := Bestiary.Watched(beast, witness);
  if i <> 0 then
    Bestiary.SetFact(table^[i], fact);
end;

procedure LearnSize(beast, attacker: Types.PCharRecord; large: Boolean);
var
  i: Word;
begin
  if attacker = nil then Exit;
  i := Bestiary.Watched(beast, attacker);
  if i = 0 then Exit;
  { two statements, as the boolean evaluation is short-circuit }
  if Bestiary.Mark(table^[i], C_BEAST.SIZE_KNOWN, True) then
    dirty := True;
  if Bestiary.Mark(table^[i], C_BEAST.LARGE, large) then
    dirty := True;
end;

procedure LearnArmor(beast, attacker: Types.PCharRecord; reach: Integer; hit: Boolean);
var
  i: Word;
begin
  if (attacker = nil) or GameVars.forcedMiss then Exit;
  { 1 misses whatever the armor; a natural 20 is FxEngine.RollToHit's 100, which no attack-roll modifier brings near
    50, and no other roll reaches 50 }
  if (GameVars.gAttackRoll <= 1) or (GameVars.gAttackRoll >= 50) then Exit;
  i := Bestiary.Watched(beast, attacker);
  if i = 0 then Exit;
  { a hit: reach >= 60 - AC; a miss: reach < 60 - AC }
  if hit then
    Bestiary.NarrowArmor(table^[i], 60 - reach, True)
  else
    Bestiary.NarrowArmor(table^[i], 59 - reach, False);
end;

procedure LearnBlow(attacker, victim: Types.PCharRecord; dmg: Byte);
var
  i: Word;
begin
  if victim = nil then Exit;
  i := Bestiary.Watched(attacker, victim);
  if (i <> 0) and (dmg > table^[i].maxHit) then begin
    table^[i].maxHit := dmg;
    dirty := True;
  end;
end;

procedure Killed(victim: Types.PCharRecord);
var
  i: Word;
begin
  if (victim = nil) or Party.IsPartyMember(victim) or GameVars.demoMode then Exit;
  i := Bestiary.Add(victim^.name);
  if i = 0 then Exit;
  if table^[i].killed < $FFFF then
    Inc(table^[i].killed);
  Bestiary.SetFact(table^[i], C_BEAST.HD_KNOWN);
  table^[i].hd := victim^.levelHighest;
  dirty := True;
end;

begin
  table := nil;
  used := 0;
  room := 0;
  dirty := False;
  readOnly := False;
  damaged := False;
  metCount := 0;
end.

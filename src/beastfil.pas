{ Reads and writes BESTIARY.DAT (#842). The Bestiary belongs to the player rather
  than one saved game, so the file lives in the save directory and carries
  between games. Each entry this game has met carries C_BEAST.MET_HERE; another
  game's entries keep their own mark.

  The file contains a header followed by Bestiary.TBeast records. A missing or
  invalid file loads as an empty Bestiary. An invalid file is preserved as
  BESTIARY.BAD on the next successful write. Files from newer compatible
  versions may be read but are never overwritten, and a partial load caused by
  low memory is likewise left untouched.

  Tell adds facts taken directly from a monster record. The sage uses it to
  reveal information the party has not learned during play (#868). FactAt,
  FactName and ListRows give the entry page (BeastMnu) its two lists, the
  defenses and the attacks, in the order it shows them. }
{$O+,F+,I-}
{$I COMPILER.INC}
unit BeastFil;

interface

uses FileUtil, Types, Bestiary;

const
  FILE_NAME = 'BESTIARY.DAT';
  { Name used to preserve an invalid Bestiary instead of overwriting it. }
  BAD_NAME = 'BESTIARY.BAD';

{ Loads BESTIARY.DAT from the configured save directory. }
procedure Load;

{ Writes a changed Bestiary to the save directory. An invalid input file is
  moved aside first. A failed write leaves the Bestiary dirty for a later retry. }
procedure Flush;

{ Replaces the current Bestiary with the contents of fn. }
procedure LoadFrom(fn: FileUtil.TPathName);

{ Safely writes the Bestiary to fn through FileUtil's temporary-file mechanism. }
function WriteTo(fn: FileUtil.TPathName): Boolean;

{ Adds every fact available from creature's monster-data record to b. Existing
  knowledge and observed counters are preserved. The entry is marked
  C_BEAST.TOLD even when there was nothing new to add. Returns True when another
  fact changed; the caller must then mark the Bestiary dirty. }
function Tell(var b: Bestiary.TBeast; creature: Types.PCharRecord): Boolean;

{ The C_BEAST fact at place i (from 1) of the entry page's defenses, or of its attacks; 0 past the last. }
function FactAt(defenses: Boolean; i: Byte): Byte;

{ The entry page's line for a defense or an attack fact, 16 characters at most (a column's width); '' for any other. }
function FactName(fact: Byte): Types.TStr40;

{ How many of b's defenses, or attacks, it knows. }
function KnownCount(var b: Bestiary.TBeast; defenses: Boolean): Byte;

{ The rows b's two lists take one a line: a heading and the known facts for each, a blank line between them, and under
  each list ?? while the sage has not told all (C_BEAST.TOLD), or None under an empty one once she has (#1114). }
function ListRows(var b: Bestiary.TBeast): Byte;

implementation

uses GameVars, C_BEAST;

const
  SIG = 'BEST';
  VERSION = 1;

type
  THeader = record
    sig: string[4];
    version: Byte;
    entrySize: Byte;
    count: Word;
  end;

procedure LoadFrom(fn: FileUtil.TPathName);
var
  f: file;
  h: THeader;
  n: Word;
  i: Word;
  ok: Boolean;
  ioRes: Integer;
  b: Bestiary.TBeast;
  { the entry was kept }
  kept: Boolean;
  { an entry was dropped for want of heap: the table is short of the file }
  short: Boolean;
begin
  Bestiary.Clear;
  { a write the game was ended in is undone first }
  ok := FileUtil.RecoverFile(fn);
  if not FileUtil.OpenReadOnly(f, fn) then Exit;
  BlockRead(f, h, SizeOf(h), n);
  ok := (IOResult = 0) and (n = SizeOf(h)) and (h.sig = SIG) and (h.version >= 1) and
        (h.entrySize >= SizeOf(Bestiary.TBeast)) and (h.count <= Bestiary.MAX_ENTRIES) and
        (FileSize(f) = SizeOf(h) + LongInt(h.count) * h.entrySize);
  { this format's entries are exactly a TBeast; a newer one's may be longer }
  if ok and (h.version = VERSION) then
    ok := h.entrySize = SizeOf(Bestiary.TBeast);
  i := 0;
  short := False;
  while ok and (i < h.count) do begin
    Inc(i);
    Seek(f, SizeOf(h) + LongInt(i - 1) * h.entrySize);
    BlockRead(f, b, SizeOf(b), n);
    ok := (IOResult = 0) and (n = SizeOf(b));
    { an entry without a name or under a name already read is dropped; past the heap's room the rest are, and the
      file is not written short of them }
    if ok then begin
      kept := Bestiary.Append(b);
      if not kept and (Length(b.name) >= 1) and (Length(b.name) <= Types.NAME_LEN) and (Bestiary.Find(b.name) = 0) then
        short := True;
    end;
  end;
  Close(f);
  ioRes := IOResult;
  if ok then
    Bestiary.readOnly := (h.version > VERSION) or short
  else begin
    { what was read of a damaged file is let go; the next write sets it aside and puts a sound one in its place }
    Bestiary.Clear;
    Bestiary.damaged := True;
  end;
end;

function WriteTo(fn: FileUtil.TPathName): Boolean;
var
  f: file;
  h: THeader;
  ok: Boolean;
begin
  FillChar(h, SizeOf(h), 0);
  h.sig := SIG;
  h.version := VERSION;
  h.entrySize := SizeOf(Bestiary.TBeast);
  h.count := Bestiary.Count;
  ok := FileUtil.RewriteTemp(f, fn);
  if ok then begin
    FileUtil.WriteChecked(f, h, SizeOf(h), ok);
    { the table is one block on the heap }
    if h.count > 0 then
      FileUtil.WriteChecked(f, Bestiary.Entry(1)^, h.count * SizeOf(Bestiary.TBeast), ok);
    ok := FileUtil.CloseTemp(f, fn, ok) and FileUtil.PutInPlace(fn);
  end;
  WriteTo := ok;
end;

function Tell(var b: Bestiary.TBeast; creature: Types.PCharRecord): Boolean;
var
  was: Bestiary.TBeast;
  effect: Types.PEffectRec;
  i: Byte;
  ac: Integer;
  { a fact other than TOLD has changed }
  learned: Boolean;

  procedure Know(fact: Byte; known: Boolean);
  begin
    if Bestiary.Mark(b, fact, known) and (fact <> C_BEAST.TOLD) then
      learned := True;
  end;

begin
  was := b;
  learned := False;
  Know(C_BEAST.SIZE_KNOWN, True);
  Know(C_BEAST.LARGE, creature^.iconDimensions and Types.ICON_LARGE <> 0);
  Know(C_BEAST.HD_KNOWN, True);
  b.hd := creature^.levelHighest;
  { acCur holds 60 - AC }
  ac := 60 - Integer(creature^.acCur);
  b.acLo := ac;
  b.acHi := ac;
  effect := creature^.effectsAddr;
  while effect <> nil do begin
    for i := 1 to C_BEAST.EFFECT_FACTS_COUNT do
      if C_BEAST.EFFECT_FACTS[i].eff = effect^.id then
        Know(C_BEAST.EFFECT_FACTS[i].fact, True);
    effect := effect^.next;
  end;
  Know(C_BEAST.TOLD, True);
  Tell := learned or (b.hd <> was.hd) or (b.acLo <> was.acLo) or (b.acHi <> was.acHi);
end;

{ Literals, in the overlay, rather than tables in the data segment. }
function FactAt(defenses: Boolean; i: Byte): Byte;
begin
  FactAt := 0;
  if defenses then
    { halved and lessened damage, immunities, the weapons needed, then the rest }
    case i of
      1..7: FactAt := C_BEAST.HALF_BLUNT + i - 1;
      8: FactAt := C_BEAST.HALF_SILVER;
      9: FactAt := C_BEAST.RESISTS_FIRE;
      10..16: FactAt := C_BEAST.IMMUNE_POISON + i - 10;
      17: FactAt := C_BEAST.NEEDS_MAGIC;
      18: FactAt := C_BEAST.SILVER_OR_MAGIC;
      19: FactAt := C_BEAST.MAGIC_RES;
      20: FactAt := C_BEAST.REGENERATES;
      21: FactAt := C_BEAST.FIGHTS_ON;
      22: FactAt := C_BEAST.BLINKS;
      23: FactAt := C_BEAST.DISPLACED;
      24: FactAt := C_BEAST.DODGES_MISSILES;
      25: FactAt := C_BEAST.DODGES_BOULDERS;
      26: FactAt := C_BEAST.TURNS_INVISIBLE;
      27: FactAt := C_BEAST.SEES_INVISIBLE;
      28: FactAt := C_BEAST.GAS_ESCAPE;
    end
  else
    case i of
      1..7: FactAt := C_BEAST.ATK_POISON + i - 1;
      8: FactAt := C_BEAST.ATK_FEAR;
      9: FactAt := C_BEAST.ATK_BLOOD;
      10: FactAt := C_BEAST.ATK_ACID;
      11: FactAt := C_BEAST.ATK_BREATH;
      12: FactAt := C_BEAST.ATK_RAKE;
      13: FactAt := C_BEAST.ATK_HOLD;
    end;
end;

function FactName(fact: Byte): Types.TStr40;
begin
  case fact of
    C_BEAST.HALF_BLUNT: FactName := 'Half: blunt';
    C_BEAST.HALF_PIERCE: FactName := 'Half: piercing';
    C_BEAST.HALF_SLASH: FactName := 'Half: slashing';
    C_BEAST.HALF_MAGICAL: FactName := 'Half: magic wpns';
    C_BEAST.HALF_FIRE: FactName := 'Half: fire';
    C_BEAST.HALF_COLD: FactName := 'Half: cold';
    C_BEAST.HALF_ELEC: FactName := 'Half: lightning';
    C_BEAST.HALF_SILVER: FactName := 'Half: silver';
    C_BEAST.RESISTS_FIRE: FactName := 'Resists fire';
    C_BEAST.IMMUNE_POISON: FactName := 'No poison';
    C_BEAST.IMMUNE_PARALYSIS: FactName := 'No paralysis';
    C_BEAST.IMMUNE_SLEEP_CHARM: FactName := 'No sleep, charm';
    C_BEAST.IMMUNE_MM: FactName := 'No magic missile';
    C_BEAST.IMMUNE_COLD: FactName := 'No cold';
    C_BEAST.IMMUNE_FIRE: FactName := 'No fire';
    C_BEAST.IMMUNE_ELEC: FactName := 'No lightning';
    C_BEAST.NEEDS_MAGIC: FactName := 'Magic wpns only';
    C_BEAST.SILVER_OR_MAGIC: FactName := 'Silver or magic';
    C_BEAST.MAGIC_RES: FactName := 'Resists magic';
    C_BEAST.REGENERATES: FactName := 'Regenerates';
    C_BEAST.FIGHTS_ON: FactName := 'Fights past 0 hp';
    C_BEAST.BLINKS: FactName := 'Blinks';
    C_BEAST.DISPLACED: FactName := 'Displaced';
    C_BEAST.DODGES_MISSILES: FactName := 'Dodges missiles';
    C_BEAST.DODGES_BOULDERS: FactName := 'Dodges boulders';
    C_BEAST.TURNS_INVISIBLE: FactName := 'Turns invisible';
    C_BEAST.SEES_INVISIBLE: FactName := 'Sees invisible';
    C_BEAST.GAS_ESCAPE: FactName := 'Escapes as gas';
    C_BEAST.ATK_POISON: FactName := 'Poison';
    C_BEAST.ATK_PARALYZE: FactName := 'Paralysis';
    C_BEAST.ATK_DRAIN: FactName := 'Level drain';
    C_BEAST.ATK_ROT: FactName := 'Rotting disease';
    C_BEAST.ATK_PETRIFY: FactName := 'Petrifying gaze';
    C_BEAST.ATK_CHARM: FactName := 'Charming gaze';
    C_BEAST.ATK_FIRE: FactName := 'Burning touch';
    C_BEAST.ATK_FEAR: FactName := 'Fear aura';
    C_BEAST.ATK_BLOOD: FactName := 'Drains blood';
    C_BEAST.ATK_ACID: FactName := 'Acid';
    C_BEAST.ATK_BREATH: FactName := 'Breath weapon';
    C_BEAST.ATK_RAKE: FactName := 'Rakes';
    C_BEAST.ATK_HOLD: FactName := 'Holds fast';
  else
    FactName := '';
  end;
end;

function KnownCount(var b: Bestiary.TBeast; defenses: Boolean): Byte;
var
  i: Byte;
  n: Byte;
begin
  n := 0;
  i := 1;
  while BeastFil.FactAt(defenses, i) <> 0 do begin
    if Bestiary.Knows(b, BeastFil.FactAt(defenses, i)) then
      Inc(n);
    Inc(i);
  end;
  KnownCount := n;
end;

function ListRows(var b: Bestiary.TBeast): Byte;
var
  defenses: Byte;
  attacks: Byte;
  n: Byte;
begin
  defenses := BeastFil.KnownCount(b, True);
  attacks := BeastFil.KnownCount(b, False);
  { the two headings and the blank line between the lists }
  n := defenses + attacks + 3;
  if not Bestiary.Knows(b, C_BEAST.TOLD) then
    Inc(n, 2)
  else begin
    if defenses = 0 then
      Inc(n);
    if attacks = 0 then
      Inc(n);
  end;
  ListRows := n;
end;

procedure Load;
begin
  BeastFil.LoadFrom(GameVars.saveDirectory + FILE_NAME);
end;

procedure Flush;
begin
  if not Bestiary.dirty or Bestiary.readOnly or (Bestiary.Count = 0) then Exit;
  if Bestiary.damaged then begin
    FileUtil.DeleteFile(GameVars.saveDirectory + BAD_NAME);
    if not FileUtil.RenameChecked(GameVars.saveDirectory + FILE_NAME, GameVars.saveDirectory + BAD_NAME) then Exit;
    Bestiary.damaged := False;
  end;
  if BeastFil.WriteTo(GameVars.saveDirectory + FILE_NAME) then
    Bestiary.dirty := False;
end;

end.

{ BESTIARY.DAT (#842): the Bestiary's knowledge, kept in the save folder and not in a save, so it carries from game to
  game; the format is meant for Curse, Secret and Pools as well. The file is a header (the signature BEST, the format's
  version, the bytes of an entry and their count) and then the entries, each a Bestiary.TBeast. A missing file is an
  empty bestiary. A damaged one (a foreign signature, a version before the first, a size that does not add up) reads as
  empty and is renamed BESTIARY.BAD when the next is written. One of a newer format is read, since a newer format only
  adds to the end of an entry, and never written, so an older game does not throw away what a newer one learned.
  Overlaid: it is read at start-up and written after a fight, after a save and on the way out to DOS. Tell fills in an
  entry from a creature's own record, the monster data's word on its kind, which the party did not learn in play: the
  sage's service (#868), and a later import's. }
{$O+,F+,I-}
{$I COMPILER.INC}
unit BeastFil;

interface

uses FileUtil, Types, Bestiary;

const
  FILE_NAME = 'BESTIARY.DAT';
  { a damaged BESTIARY.DAT, kept aside rather than written over }
  BAD_NAME = 'BESTIARY.BAD';

{ Read the Bestiary from BESTIARY.DAT in the save folder (LoadFrom), at start-up, once the paths are known. }
procedure Load;

{ Write the Bestiary to BESTIARY.DAT in the save folder when it has learned something since it was last written, the
  damaged file it read set aside first. A failed write is tried again the next time. }
procedure Flush;

{ Read the Bestiary from file fn in place of what it holds. }
procedure LoadFrom(fn: FileUtil.TPathName);

{ Write the Bestiary as file fn, safely (FileUtil's temporary copy, put in place once whole): True when it is there. }
function WriteTo(fn: FileUtil.TPathName): Boolean;

{ Fill in b from creature, a record of its kind as the monster data has it (EclMenu.InitCreature): its size, hit dice
  and exact armor class, and the defenses and attacks its effects stand for (C_BEAST.EFFECT_FACTS). What b knew stays
  known, and seen, killed and maxHit, the party's own, are left alone. b is marked C_BEAST.TOLD, all there is to know.
  True when b has learned something other than that; the caller that keeps b marks the Bestiary dirty. }
function Tell(var b: Bestiary.TBeast; creature: Types.PCharRecord): Boolean;

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
begin
  Bestiary.Clear;
  if not FileUtil.OpenReadOnly(f, fn) then Exit;
  BlockRead(f, h, SizeOf(h), n);
  ok := (IOResult = 0) and (n = SizeOf(h)) and (h.sig = SIG) and (h.version >= 1) and
        (h.entrySize >= SizeOf(Bestiary.TBeast)) and (h.count <= Bestiary.MAX_ENTRIES) and
        (FileSize(f) = SizeOf(h) + LongInt(h.count) * h.entrySize);
  { this format's entries are exactly a TBeast; a newer one's may be longer }
  if ok and (h.version = VERSION) then
    ok := h.entrySize = SizeOf(Bestiary.TBeast);
  i := 0;
  while ok and (i < h.count) do begin
    Inc(i);
    Seek(f, SizeOf(h) + LongInt(i - 1) * h.entrySize);
    BlockRead(f, b, SizeOf(b), n);
    ok := (IOResult = 0) and (n = SizeOf(b));
    { an entry without a name or under a name already read is dropped; past the heap's room the rest are }
    if ok then
      kept := Bestiary.Append(b);
  end;
  Close(f);
  ioRes := IOResult;
  if ok then
    Bestiary.readOnly := h.version > VERSION
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

  procedure Know(fact: Byte);
  begin
    b.known[fact div 32] := b.known[fact div 32] or (LongInt(1) shl (fact mod 32));
  end;

begin
  was := b;
  Know(C_BEAST.SIZE_KNOWN);
  if creature^.iconDimensions and Types.ICON_LARGE <> 0 then
    Know(C_BEAST.LARGE)
  else
    b.known[0] := b.known[0] and not (LongInt(1) shl C_BEAST.LARGE);
  Know(C_BEAST.HD_KNOWN);
  b.hd := creature^.levelHighest;
  { acCur holds 60 - AC }
  ac := 60 - Integer(creature^.acCur);
  b.acLo := ac;
  b.acHi := ac;
  effect := creature^.effectsAddr;
  while effect <> nil do begin
    for i := 1 to C_BEAST.EFFECT_FACTS_COUNT do
      if C_BEAST.EFFECT_FACTS[i].eff = effect^.id then
        Know(C_BEAST.EFFECT_FACTS[i].fact);
    effect := effect^.next;
  end;
  Know(C_BEAST.TOLD);
  was.known[0] := was.known[0] or (LongInt(1) shl C_BEAST.TOLD);
  Tell := (b.known[0] <> was.known[0]) or (b.known[1] <> was.known[1]) or (b.hd <> was.hd) or
          (b.acLo <> was.acLo) or (b.acHi <> was.acHi);
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

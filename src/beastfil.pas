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
  reveal information the party has not learned during play (#868). }
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

{ BESTIARY.DAT (#842): the Bestiary's knowledge, kept in the save folder and not in a save, so it carries from game to
  game; the format is meant for Curse, Secret and Pools as well. The file is a header (the signature BEST, the format's
  version, the bytes of an entry and their count) and then the entries, each a Bestiary.TBeast. A missing file is an
  empty bestiary. A damaged one (a foreign signature, a version before the first, a size that does not add up) reads as
  empty and is renamed BESTIARY.BAD when the next is written. One of a newer format is read, since a newer format only
  adds to the end of an entry, and never written, so an older game does not throw away what a newer one learned.
  Overlaid: it is read at start-up and written after a fight, after a save and on the way out to DOS. }
{$O+,F+,I-}
{$I COMPILER.INC}
unit BeastFil;

interface

uses FileUtil;

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

implementation

uses GameVars, Bestiary;

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

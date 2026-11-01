{ Saves the fields added to Types.TCharExt: the classes left by a dual-classed
  human (#838), the flags (EXT_*), which mark a creature that joined through
  Animate Dead (#1089), the drain log (#1174), which records the levels
  energy drains took, and the spells past SSI's record: slots of levels 4 and 5
  and a ranger's druid slots, spells known past 56, and memorized spells past
  the record's 21 (#1121). SSI's 285-byte character format has no room for these
  fields, so they are stored in a separate .chx file. They remain part of the
  in-memory record, allowing normal record copies to preserve them. }
{$O+,F+}
{$I COMPILER.INC}
unit CharExt;

interface

uses Types, FileUtil;

const
  { TCharExt.flags: a creature that joined the party when it was raised by Animate Dead on the party's side, not a
    character the party made or a script brought in; raised to life by the temple, it slips away at the next rest
    (#1089). Its record is a monster's, which SSI's format marks nowhere: the reserved bytes hold whatever the monster
    files put there, and the npc byte's bits are its morale. }
  EXT_ANIMATE_JOINED = $01;

{ True for a creature that joined through Animate Dead (EXT_ANIMATE_JOINED) and is alive again, raised by the temple:
  it slips away while the party sleeps at its next rest (#1089). }
function SlipsAway(creature: Types.PCharRecord): Boolean;

{ True when creature has a port field that is not 0, one a .chx file must hold. }
function HasExt(creature: Types.PCharRecord): Boolean;

{ Write creature's port fields as file <base>.chx of save s (FileUtil.WriteToSet); for a creature whose fields are all
  0 the save erases the old file instead. False when the write failed. }
function WriteExt(var s: FileUtil.TFileSet; creature: Types.PCharRecord; base: FileUtil.TSetName): Boolean;

{ Read creature's port fields from <fn>.chx. They are left 0 unless the file is exactly one record with this format's
  signature and version (or version 3's, from before the spells past SSI's record, whose class left, flags and drain
  log are read, or version 2's, from before the drain log, whose class left and flags are read, or version
  1's, from before the flags, whose class left is read), made for a character of this name and randByte: a character
  from SSI's game, from before #838, or whose .chx was lost, is an ordinary one. A drain log longer than the record's
  drainedLevels is cut to it, the oldest entries going. }
procedure ReadExt(creature: Types.PCharRecord; fn: Types.TPathStr);

{ Log a level an energy drain took (#1174): xp experience, hp hit points, class cls lowered. The log is full at
  Types.DRAIN_LOG_LEN entries, and then the oldest goes, its level restored as one before the log. }
procedure PushDrain(creature: Types.PCharRecord; xp: LongInt; hp: Byte; cls: ShortInt);

{ Take the most recent entry off creature's drain log into d: True when there was one. }
function PopDrain(creature: Types.PCharRecord; var d: Types.TDrainRec): Boolean;

{ Training gives back a drained level in class cls (CharGen.GainLevels), and the drain's entry goes, its experience
  forfeit: the level was earned again, not restored. That is the most recent entry for cls; with none, the most recent
  entry, unless creature has drained levels the log does not hold (an old save's), one of which training then takes.
  True, with the entry in d, when an entry went. Call before drainedLevels is lowered. }
function TrainDrain(creature: Types.PCharRecord; cls: ShortInt; var d: Types.TDrainRec): Boolean;

{ The entries in creature's drain log for class cls. }
function LoggedDrains(creature: Types.PCharRecord; cls: ShortInt): Byte;

implementation

uses C_STATUS;

const
  { EXT_SIG and EXT_VERSION open every .chx file; a file without both is not read }
  EXT_SIG = 'CEXT';
  EXT_VERSION = 4;
  { version 3's files hold the class left, the flags and the drain log, version 2's the class left and the flags,
    version 1's the class left alone }
  EXT_VERSION_3 = 3;
  EXT_VERSION_2 = 2;
  EXT_VERSION_1 = 1;

type
  { A .chx file: the port fields, with the name and randByte of the character they belong to. }
  TCharExtFile = record
    sig: string[4];
    version: Byte;
    name: string[Types.NAME_LEN];
    randByte: Byte;
    portExt: Types.TCharExt;
  end;

  { A version 3 .chx file, from before the spells past SSI's record (#1121): TCharExt's fields to the drain log. }
  TCharExtFile3 = record
    sig: string[4];
    version: Byte;
    name: string[Types.NAME_LEN];
    randByte: Byte;
    formerClasses: Byte;
    flags: Byte;
    drainCount: Byte;
    drains: array[1..Types.DRAIN_LOG_LEN] of Types.TDrainRec;
  end;

  { A version 2 .chx file, from before the drain log. }
  TCharExtFile2 = record
    sig: string[4];
    version: Byte;
    name: string[Types.NAME_LEN];
    randByte: Byte;
    formerClasses: Byte;
    flags: Byte;
  end;

  { A version 1 .chx file, from before TCharExt.flags. }
  TCharExtFile1 = record
    sig: string[4];
    version: Byte;
    name: string[Types.NAME_LEN];
    randByte: Byte;
    formerClasses: Byte;
  end;

function SlipsAway(creature: Types.PCharRecord): Boolean;
begin
  SlipsAway := (creature^.portExt.flags and EXT_ANIMATE_JOINED <> 0) and (creature^.status = C_STATUS.OKAY);
end;

function HasExt(creature: Types.PCharRecord): Boolean;
var
  p: Types.PBytes;
  i: Word;
  any: Boolean;
begin
  any := False;
  p := @creature^.portExt;
  for i := 0 to SizeOf(Types.TCharExt) - 1 do
    if p^[i] <> 0 then
      any := True;
  HasExt := any;
end;

function WriteExt(var s: FileUtil.TFileSet; creature: Types.PCharRecord; base: FileUtil.TSetName): Boolean;
var
  rec: TCharExtFile;
begin
  WriteExt := True;
  if CharExt.HasExt(creature) then begin
    FillChar(rec, SizeOf(rec), 0);
    rec.sig := EXT_SIG;
    rec.version := EXT_VERSION;
    rec.name := creature^.name;
    rec.randByte := creature^.randByte;
    rec.portExt := creature^.portExt;
    WriteExt := FileUtil.WriteToSet(s, base + '.chx', rec, SizeOf(rec));
  end else
    FileUtil.AddToSet(s, base + '.chx', False);
end;

{ True when a .chx file's name and randByte are creature's: the file is this character's. }
function SameChar(creature: Types.PCharRecord; name: Types.TStr40; randByte: Byte): Boolean;
begin
  SameChar := (Length(name) <= Types.NAME_LEN) and (name = creature^.name) and (randByte = creature^.randByte);
end;

{ Drop the drain log's entry i, the later ones moving down. }
procedure DropDrain(creature: Types.PCharRecord; i: Byte);
begin
  with creature^.portExt do begin
    while i < drainCount do begin
      drains[i] := drains[i + 1];
      Inc(i);
    end;
    Dec(drainCount);
  end;
end;

procedure ReadExt(creature: Types.PCharRecord; fn: Types.TPathStr);
var
  rec: TCharExtFile;
  rec3: TCharExtFile3;
  rec2: TCharExtFile2;
  rec1: TCharExtFile1;
begin
  FillChar(creature^.portExt, SizeOf(creature^.portExt), 0);
  { read-only, so a write-protected .chx is read too; each version's file has its own size }
  if FileUtil.ReadRecord(fn + '.chx', rec, SizeOf(rec)) then begin
    if (rec.sig = EXT_SIG) and (rec.version = EXT_VERSION) and CharExt.SameChar(creature, rec.name, rec.randByte) then
      creature^.portExt := rec.portExt;
  end else if FileUtil.ReadRecord(fn + '.chx', rec3, SizeOf(rec3)) then begin
    if (rec3.sig = EXT_SIG) and (rec3.version = EXT_VERSION_3) and
        CharExt.SameChar(creature, rec3.name, rec3.randByte) then begin
      creature^.portExt.formerClasses := rec3.formerClasses;
      creature^.portExt.flags := rec3.flags;
      creature^.portExt.drainCount := rec3.drainCount;
      Move(rec3.drains, creature^.portExt.drains, SizeOf(rec3.drains));
    end;
  end else if FileUtil.ReadRecord(fn + '.chx', rec2, SizeOf(rec2)) then begin
    if (rec2.sig = EXT_SIG) and (rec2.version = EXT_VERSION_2) and
        CharExt.SameChar(creature, rec2.name, rec2.randByte) then begin
      creature^.portExt.formerClasses := rec2.formerClasses;
      creature^.portExt.flags := rec2.flags;
    end;
  end else if FileUtil.ReadRecord(fn + '.chx', rec1, SizeOf(rec1)) then
    if (rec1.sig = EXT_SIG) and (rec1.version = EXT_VERSION_1) and
        CharExt.SameChar(creature, rec1.name, rec1.randByte) then
      creature^.portExt.formerClasses := rec1.formerClasses;
  with creature^.portExt do begin
    if drainCount > Types.DRAIN_LOG_LEN then
      drainCount := Types.DRAIN_LOG_LEN;
    while drainCount > creature^.drainedLevels do
      CharExt.DropDrain(creature, 1);
  end;
end;

procedure PushDrain(creature: Types.PCharRecord; xp: LongInt; hp: Byte; cls: ShortInt);
begin
  with creature^.portExt do begin
    if drainCount >= Types.DRAIN_LOG_LEN then
      CharExt.DropDrain(creature, 1);
    Inc(drainCount);
    drains[drainCount].xp := xp;
    drains[drainCount].hp := hp;
    drains[drainCount].cls := cls;
  end;
end;

function PopDrain(creature: Types.PCharRecord; var d: Types.TDrainRec): Boolean;
begin
  with creature^.portExt do begin
    PopDrain := drainCount > 0;
    if drainCount > 0 then begin
      d := drains[drainCount];
      Dec(drainCount);
    end;
  end;
end;

function TrainDrain(creature: Types.PCharRecord; cls: ShortInt; var d: Types.TDrainRec): Boolean;
var
  i: Byte;
begin
  TrainDrain := False;
  with creature^.portExt do begin
    i := drainCount;
    while (i > 0) and (drains[i].cls <> cls) do
      Dec(i);
    { no entry for cls: the most recent, unless an unlogged level is there to take }
    if (i = 0) and (drainCount > 0) and (drainCount >= creature^.drainedLevels) then
      i := drainCount;
    if i > 0 then begin
      d := drains[i];
      CharExt.DropDrain(creature, i);
      TrainDrain := True;
    end;
  end;
end;

function LoggedDrains(creature: Types.PCharRecord; cls: ShortInt): Byte;
var
  i: Byte;
  n: Byte;
begin
  n := 0;
  with creature^.portExt do
    for i := 1 to drainCount do
      if drains[i].cls = cls then
        Inc(n);
  LoggedDrains := n;
end;

end.

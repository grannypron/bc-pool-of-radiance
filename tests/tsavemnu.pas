{ Tests for SaveMenu.MoveOldQuickSave (#1080): a quick save from before #1080, in slot Q, moves whole to slot Z, the
  quick save's slot now, its savgam files, vault copy and members' files with it, and a file slot Z kept from a move
  ended part way goes; nothing moves while slot Z holds a save, or when slot Q holds none. }
{$I COMPILER.INC}
program TSaveMnu;

uses GameVars, FileUtil, SaveMenu, TestKit;

{ the files the tests make; each holds its own name }
const
  FILE_COUNT = 5;
  SUFFIXES: array[1..FILE_COUNT] of string[12] = ('savgam?.dat', 'savgam?.inf', 'savgam?.sts', 'vault?.dat',
                                                  'CHRDAT?1.sav');

{ Suffix i with its ? made letter. }
function Named(i: Byte; letter: Char): FileUtil.TSetName;
var
  name: FileUtil.TSetName;
begin
  name := SUFFIXES[i];
  name[Pos('?', name)] := letter;
  Named := name;
end;

{ Write file name holding text. }
procedure Make(name: FileUtil.TSetName; text: FileUtil.TSetName);
var
  s: FileUtil.TFileSet;
begin
  FileUtil.NewSet(s, '');
  TestKit.Check(FileUtil.WriteToSet(s, name, text, SizeOf(text)) and FileUtil.CommitSet(s), name + ' is written');
end;

{ What file name holds, or '' when it does not read. }
function Held(name: FileUtil.TSetName): FileUtil.TSetName;
var
  text: FileUtil.TSetName;
begin
  Held := '';
  if FileUtil.ReadRecord(name, text, SizeOf(text)) then
    Held := text;
end;

{ Erase every file the tests make, in slots Q and Z. }
procedure Clear;
var
  i: Byte;
begin
  for i := 1 to FILE_COUNT do begin
    FileUtil.DeleteFile(Named(i, 'Q'));
    FileUtil.DeleteFile(Named(i, 'Z'));
  end;
end;

var
  i: Byte;

begin
  TestKit.Start('TSAVEMNU');
  GameVars.saveDirectory := '';
  Clear;

  { a quick save in slot Q moves whole to slot Z, and Z's left-over .sts goes with no .sts in Q }
  for i := 1 to FILE_COUNT do
    if i <> 3 then
      Make(Named(i, 'Q'), Named(i, 'Q'));
  Make(Named(3, 'Z'), 'STALE');
  SaveMenu.MoveOldQuickSave;
  for i := 1 to FILE_COUNT do begin
    TestKit.Check(not FileUtil.Exists(Named(i, 'Q')), Named(i, 'Q') + ' is gone');
    if i <> 3 then
      TestKit.CheckEqualsS(Named(i, 'Q'), Held(Named(i, 'Z')), Named(i, 'Z') + ' holds what Q''s held');
  end;
  TestKit.Check(not FileUtil.Exists(Named(3, 'Z')), 'slot Z''s left-over .sts is gone');

  { nothing moves while slot Z holds a save }
  Clear;
  Make(Named(1, 'Q'), 'OLD');
  Make(Named(2, 'Q'), 'OLD INF');
  Make(Named(1, 'Z'), 'NEW');
  SaveMenu.MoveOldQuickSave;
  TestKit.CheckEqualsS('OLD', Held(Named(1, 'Q')), 'Q''s save stays');
  TestKit.CheckEqualsS('OLD INF', Held(Named(2, 'Q')), 'Q''s .inf stays');
  TestKit.CheckEqualsS('NEW', Held(Named(1, 'Z')), 'Z''s save stays');
  TestKit.Check(not FileUtil.Exists(Named(2, 'Z')), 'no .inf comes to Z');

  { with no save in slot Q, slot Z's files stay }
  Clear;
  Make(Named(2, 'Q'), 'ORPHAN');
  Make(Named(3, 'Z'), 'Z STS');
  SaveMenu.MoveOldQuickSave;
  TestKit.CheckEqualsS('ORPHAN', Held(Named(2, 'Q')), 'Q''s .inf without a save stays');
  TestKit.CheckEqualsS('Z STS', Held(Named(3, 'Z')), 'Z''s .sts stays');

  Clear;
  TestKit.Done;
end.

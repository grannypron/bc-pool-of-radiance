{ Tests for Explored (phase 8): squares marked per area (script and map), kept apart, and through savgam<x>.map. }
{$I COMPILER.INC}
program TExplore;

uses Types, GameVars, FileUtil, Explored, TestKit;

{ Write the squares as file name in folder dir, a save of their own: True when they are in place. }
function WriteMap(dir: FileUtil.TPathName; name: FileUtil.TSetName): Boolean;
var
  s: FileUtil.TFileSet;
begin
  FileUtil.NewSet(s, dir);
  WriteMap := Explored.WriteSlot(s, name) and FileUtil.CommitSet(s);
end;

begin
  TestKit.Start('TEXPLORE');
  GetMem(GameVars.zone0, SizeOf(Types.TGbvmZone0State));
  FillChar(GameVars.zone0^, SizeOf(Types.TGbvmZone0State), 0);
  Explored.Clear;
  GameVars.eclScriptId := 18;
  GameVars.zone0^.mapId.lo := 1;
  Explored.Mark(5, 8);
  Explored.Mark(15, 15);
  Explored.Mark(16, 3);
  TestKit.Check(Explored.Visited(18, 1, 5, 8), 'a marked square is visited');
  TestKit.Check(Explored.Visited(18, 1, 15, 15), 'the far corner too');
  TestKit.Check(not Explored.Visited(18, 1, 6, 8), 'its neighbour is not');
  TestKit.Check(not Explored.Visited(18, 2, 5, 8), 'nor the same square of another map');
  TestKit.Check(not Explored.Visited(19, 1, 5, 8), 'nor of another script');
  TestKit.Check(not Explored.Visited(18, 1, 16, 3), 'a square off the map is not kept');
  GameVars.eclScriptId := 0;
  GameVars.zone0^.mapId.lo := 0;
  Explored.Mark(0, 0);
  TestKit.Check(WriteMap('', 'TEXPLORE.MAP'), 'the squares are written');
  TestKit.Check(not WriteMap('NODIR\', 'TEXPLORE.MAP'), 'a write into a missing folder says it failed');
  Explored.Clear;
  TestKit.Check(not Explored.Visited(18, 1, 5, 8), 'cleared, nothing is visited');
  Explored.ReadSlot('TEXPLORE.MAP');
  TestKit.Check(Explored.Visited(18, 1, 5, 8) and Explored.Visited(0, 0, 0, 0), 'read back from its file');
  Explored.ReadSlot('NOSUCH.MAP');
  TestKit.Check(not Explored.Visited(18, 1, 5, 8), 'a missing file leaves none');
  TestKit.Done;
end.

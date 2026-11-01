{ The demo (#1109): the Commodore 64's attract mode, its own script in DEMO.DAX, which the start-up menu plays when it
  is left alone with no party, and which any key ends. }
{$O+,F+}
{$I COMPILER.INC}
unit Demo;

interface

uses Types;

{ True when the archive at path holds what the demo reads, so that it can play without a disk prompt or an error that
  ends the game: the script (more than its two header bytes) and each character's record (DiskRec.CHAR_DISK_BYTES at
  least) and items, in a directory DataArc.BlockRawSize can read whole. }
function Complete(path: Types.TPathStr): Boolean;

{ True when DEMO.DAX (C_DEMO.ARCHIVE) is there and Complete: without it the start-up menu waits on as it always did,
  and DEMO starts nothing (#1109). }
function Available: Boolean;

{ Play the demo the start-up menu asked for (CharGen.MainMenu sets GameVars.demoMode): the C64's script runs as an
  area's does (EclVm.RunDemo), on Podol Plaza's disk, at the demo's speed and from a fixed random seed, with the party
  it adds itself, until it ends or a key ends it (GameVars.demoAbort). Then the game is as the start-up menu left it:
  no party, a new game's state (GameInit.ResetGameState, as after a destroyed party), the player's text delay and the
  random numbers where they were, so a game started next rolls as it would have without the demo. The key is drained. }
procedure Run;

implementation

uses Crt, C_AREA, C_DEMO, C_IFC, GameVars, GameIo, DaxIo, DataArc, DiskRec, SaveLoad, EclVm, GameInit, TextRend,
  CharDisp, Portrait
  {$IFDEF FPC}, TpRand{$ENDIF};

function Complete(path: Types.TPathStr): Boolean;
var
  id: Byte;
  ok: Boolean;
begin
  ok := DataArc.BlockRawSize(path, C_DEMO.SCRIPT_BLOCK) > 2;
  for id := C_DEMO.FIRST_NPC to C_DEMO.LAST_NPC do
    ok := ok and (DataArc.BlockRawSize(path, id) >= DiskRec.CHAR_DISK_BYTES) and
          (DataArc.BlockRawSize(path, id + C_DEMO.ITEMS_OFFSET) >= 0);
  Complete := ok;
end;

function Available: Boolean;
begin
  Available := Demo.Complete({$IFDEF FPC}DaxIo.FolderOf(C_DEMO.ARCHIVE){$ELSE}GameVars.gameDir{$ENDIF} +
                             C_DEMO.ARCHIVE + '.DAX');
end;

procedure Run;
var
  savedDelay: Byte;
  savedSeed: LongInt;
begin
  { the archive gone since the menu looked: no demo, and back to the menu }
  if not Demo.Available then begin
    GameVars.demoMode := False;
    Exit;
  end;
  savedDelay := GameVars.gameDelay;
  savedSeed := RandSeed;
  GameVars.demoArg := False;
  GameVars.demoMode := True;
  GameVars.demoAbort := False;
  GameVars.gameDelay := C_DEMO.SPEED;
  RandSeed := C_DEMO.SEED;
  GameVars.diskIndex := C_DEMO.DATA_DISK;
  { the 3D view, where SETUP MONSTER and APPROACH show a monster's close-up (EclMenu.DisplayMonster) }
  GameVars.locTypePrev := C_AREA.LOC_3D_MAP;
  GameVars.gLocType := C_AREA.LOC_3D_MAP;
  GameVars.ifcState := C_IFC.INDOORS;
  TextRend.ClearScreen;
  CharDisp.DrawNoncombatWindows(False);
  EclVm.RunDemo;
  { the monsters a battle cut short left in the list go with the party, and the picture the demo showed with it }
  SaveLoad.FreeParty;
  Portrait.FreeAnimation(GameVars.animData);
  GameInit.ResetGameState;
  GameVars.gameDelay := savedDelay;
  RandSeed := savedSeed;
  GameVars.demoMode := False;
  GameVars.demoAbort := False;
  while KeyPressed do
    GameIo.DiscardPendingKeys;
  TextRend.ClearScreen;
end;

end.

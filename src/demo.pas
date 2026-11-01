{ The demo (#1109): the Commodore 64's attract mode, its own script in DEMO.DAX, which the start-up menu plays when it
  is left alone with no party, and which any key ends. }
{$O+,F+}
{$I COMPILER.INC}
unit Demo;

interface

{ True when DEMO.DAX (C_DEMO.ARCHIVE) is there to play. }
function Available: Boolean;

{ Play the demo the start-up menu asked for (CharGen.MainMenu sets GameVars.demoMode): the C64's script runs as an
  area's does (EclVm.RunDemo), on Podol Plaza's disk, at the demo's speed and from a fixed random seed, with the party
  it adds itself, until it ends or a key ends it (GameVars.demoAbort). Then the game is as the start-up menu left it:
  no party, a new game's state (GameInit.ResetGameState, as after a destroyed party), the player's text delay and the
  random numbers where they were, so a game started next rolls as it would have without the demo. The key is drained. }
procedure Run;

implementation

uses Crt, Types, C_AREA, C_DEMO, C_IFC, GameVars, GameIo, DaxIo, FileUtil, SaveLoad, EclVm, GameInit, TextRend,
  CharDisp, Portrait
  {$IFDEF FPC}, TpRand{$ENDIF};

function Available: Boolean;
begin
  Available := FileUtil.Exists({$IFDEF FPC}DaxIo.FolderOf(C_DEMO.ARCHIVE){$ELSE}GameVars.gameDir{$ENDIF} +
                               C_DEMO.ARCHIVE + '.DAX');
end;

procedure Run;
var
  savedDelay: Byte;
  savedSeed: LongInt;
begin
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

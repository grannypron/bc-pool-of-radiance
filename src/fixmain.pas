{ Program entry: initialize the game, bring the merged data archives up to date, show the introduction, run CharGen's
  main menu, then run the game loop and shut down. }
{$F+}
program FixMain;

uses Types,
  Overlay, Crt, Dos,
  GDConsts, GDVars,
  SoundDrv, Session, GameIo, DaxIo, TextRend, Blit, GameBoot,
  Sym8x8, Border, Debug, MapTiles, CbtMap, Pathing, View3D, Portrait, Wilds, MapView,
  MenuCore, CharHlp, FxEngine, ClassCal, Magic, Money, GameTime, ViewChar, Ending, SaveLoad, CharGen, Camp,
  Explore, CbtActs, EffHndlr, GameInit, CombatSt, CombatAi, Combat, EclMenu, Shop, PostCbt, Temple,
  EclVm, DataBld, Intro, HeapErr;

{$O HeapErr}
{$O Intro}
{$O DataBld}
{$O EclVm}
{$O Temple}
{$O PostCbt}
{$O Shop}
{$O EclMenu}
{$O Combat}
{$O CombatAi}
{$O CombatSt}
{$O GameInit}
{$O EffHndlr}
{$O CbtActs}
{$O Explore}
{$O Camp}
{$O CharGen}
{$O SaveLoad}
{$O Ending}
{$O ViewChar}
{$O GameTime}
{$O Money}
{$O Magic}
{$O ClassCal}
{$O FxEngine}
{$O MenuCore}
{$O MapView}
{$O Wilds}
{$O Portrait}
{$O View3D}
{$O Pathing}
{$O CbtMap}
{$O MapTiles}
{$O Debug}
{$O Sym8x8}

begin
  GameInit.GameInit2;
  DataBld.BuildDataFiles;
  { STING skips the introduction }
  if ParamStr(1) <> 'STING' then begin
    Intro.Introduction;
    { the key that skipped the introduction is not a main-menu choice }
    while KeyPressed do
      GameIo.DiscardPendingKeys;
  end;
  CharGen.MainMenu;
  View3D.SetView3DColors(LightCyan, Black, LightGray, Brown);
  EclVm.GameLoop;
  GameIo.ExitGame;
end.

{ Program entry: initialize the game, bring the merged data archives up to date, show the introduction, run CharGen's
  main menu, then run the game loop and shut down. }
{$F+}
program FixMain;

uses Types,
  Overlay, Crt, Dos,
  GDConsts, GDVars,
  SoundDrv, GameIo, DaxIo, TextRend, Blit, GameBoot,
  Sym8x8, Border, Debug, MapTiles, CbtMap, Pathing, View3D, Portrait, Wilds, MapView,
  MenuCore, CharHlp, FxEngine, ClassCal, Magic, Money, GameTime, ViewChar, Ending, SaveLoad, CharGen, Camp,
  Journal1, Journal2, Journal3, Journal4, JrnlList, JrnlView, Options,
  Explore, CbtActs, EffHndlr, GameInit, CombatSt, CombatAi, Combat, EclVars, EclMenu, Shop, PostCbt, Temple,
  EclVm, BldShow, DataBld, Intro, HeapErr, SaveMenu, AreaName, Vault, EclTrace;

{$O EclTrace}
{$O Vault}
{$O AreaName}
{$O SaveMenu}
{$O HeapErr}
{$O Intro}
{$O DataBld}
{$O BldShow}
{$O EclVm}
{$O Temple}
{$O PostCbt}
{$O Shop}
{$O EclVars}
{$O EclMenu}
{$O Combat}
{$O CombatAi}
{$O CombatSt}
{$O GameInit}
{$O EffHndlr}
{$O CbtActs}
{$O Explore}
{$O Options}
{$O JrnlView}
{$O Journal4}
{$O Journal3}
{$O Journal2}
{$O Journal1}
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
  if not GDVars.stingArg then begin
    Intro.Introduction;
    { the key that skipped the introduction is not a main-menu choice }
    while KeyPressed do
      GameIo.DiscardPendingKeys;
  end;
  { the vault of a game left unsaved last time is gone with it }
  Vault.ForgetSessionVault;
  CharGen.MainMenu;
  View3D.SetView3DColors(LightCyan, Black, LightGray, Brown);
  EclVm.GameLoop;
  { F8 on the map menu ends GameLoop to load the quick save; the loop then starts again on the loaded game, as it does
    after a load from the main menu }
  while Explore.quickLoadAsked do begin
    Explore.quickLoadAsked := False;
    SaveLoad.QuickLoad;
    EclVm.GameLoop;
  end;
  GameIo.ExitGame;
end.

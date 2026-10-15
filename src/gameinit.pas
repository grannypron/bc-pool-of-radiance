{ Initialize game state, allocate graphics buffers, load shared resources and install spell and effect handlers. }
{$O+,F+,I-}
unit GameInit;

interface

uses Types, Crt, C_Area, C_Video, GDConsts, GDVars, Sym8x8, MapTiles, Magic, EffHndlr,
  C_Dir;

procedure GameInit2;

implementation

uses Options, Blit, DaxIo, GameIo, MenuCore, Session, SoundDrv, TextRend;

var
  iconAnims: array[0..25, 0..1] of Types.PImgBuf absolute GDVars.dsIconAnimation;
  wallCache: array[1..3] of Types.TWallSlot absolute GDVars.dsWallSetCache;

{ Allocate the GBVM zones and graphics buffers, build the per-row video address tables and reset the game state to its
  defaults, then load the font, symbol sets, tile sets, combat icons and item table, read the settings from POOLOPT.CFG
  (Options.LoadOptions), seed the random numbers (with 1 when NORAND is the second argument) and install the spell and
  effect handlers. }
procedure GameInit2;
var
  ch: Char;
begin
  GetMem(Session.dsGbvmZones[0], SizeOf(Types.TGbvmZone0State));
  GetMem(Session.dsGbvmZones[1], SizeOf(Types.TGbvmZone1));
  GetMem(Session.dsGbvmZones[2], SizeOf(Types.TZone2));
  GetMem(Session.dsGbvmZones[3], SizeOf(Types.TZone3));
  GetMem(GDVars.gameFont, SizeOf(Types.TFontArr));
  GetMem(GDVars.wallGfx, SizeOf(Types.TWallDefs));
  GetMem(GDVars.map3d, SizeOf(Types.TGeoMap));
  Blit.AllocPic(8, 1, 1, 0, GDVars.dsCurrent8x8SymbolPtr2);
  { the 168x168 view area }
  Blit.AllocPic(168, 21, 1, 0, GDVars.dsViewImageBufferPtr);
  { 24x24 save-under block }
  Blit.AllocPic(24, 3, 1, 0, GDVars.dsIconImageBufferPtr);
  FillChar(GDVars.spanActive, SizeOf(GDVars.spanActive), 0);
  FillChar(GDVars.spanScreenOfs, SizeOf(GDVars.spanScreenOfs), 0);
  FillChar(GDVars.spanFirstOfs, SizeOf(GDVars.spanFirstOfs), $FF);
  FillChar(GDVars.spanLastOfs, SizeOf(GDVars.spanLastOfs), 0);
  { Per-row video addresses: CGA segment (even and odd rows in separate banks, a row pair every 5 paragraphs), EGA
    offset (40 bytes per row), Tandy segment (four banks, four rows every 10 paragraphs). }
  for GDVars.gi2 := 0 to 199 do begin
    if Odd(GDVars.gi2) then
      GDVars.cgaRowSeg[GDVars.gi2] := (GDVars.gi2 div 2) * 5 + C_Video.GFX_BANK1_SEG
    else
      GDVars.cgaRowSeg[GDVars.gi2] := (GDVars.gi2 div 2) * 5 + C_Video.GFX_BANK0_SEG;
    GDVars.fbRowOfs[GDVars.gi2] := GDVars.gi2 * 40;
    case GDVars.gi2 mod 4 of
      0: GDVars.tandyRowSeg[GDVars.gi2] := (GDVars.gi2 div 4) * 10 + C_Video.GFX_BANK0_SEG;
      1: GDVars.tandyRowSeg[GDVars.gi2] := (GDVars.gi2 div 4) * 10 + C_Video.GFX_BANK1_SEG;
      2: GDVars.tandyRowSeg[GDVars.gi2] := (GDVars.gi2 div 4) * 10 + C_Video.GFX_BANK2_SEG;
      3: GDVars.tandyRowSeg[GDVars.gi2] := (GDVars.gi2 div 4) * 10 + C_Video.GFX_BANK3_SEG;
    end;
  end;
  FillChar(GDVars.dsSymbolSetPtrs, SizeOf(GDVars.dsSymbolSetPtrs), 0);
  FillChar(GDVars.ds2dMapTilePtr, SizeOf(GDVars.ds2dMapTilePtr) + SizeOf(GDVars.ds2dMapTilePtr2), 0);
  FillChar(Types.PGbvmZone0State(Session.dsGbvmZones[0])^, SizeOf(Types.TGbvmZone0State), 0);
  FillChar(Types.PGameini2ZoneWords(Session.dsGbvmZones[1])^, SizeOf(Types.TGbvmZone1), 0);
  FillChar(Types.PGameini2ZoneWords(Session.dsGbvmZones[2])^, SizeOf(Types.TZone2), 0);
  FillChar(Types.PGameini2ZoneWords(Session.dsGbvmZones[3])^, SizeOf(Types.TZone3), 0);
  FillChar(iconAnims, SizeOf(iconAnims), 0);
  for GDVars.gi2 := 1 to 2 do begin
    GDVars.dsPortraitCache[GDVars.gi2].pictureId := 255;
    GDVars.dsPortraitCache[GDVars.gi2].pic := nil;
  end;
  FillChar(GDVars.animData, SizeOf(GDVars.animData), 0);
  GDVars.treasureItems := nil;
  { Clear the five bytes gMapX, gMapY, gFacing, wallAhead and eventAtCell. Position and facing are assigned below. }
  FillChar(GDVars.gMapX, 5, 0);
  GDVars.gMapX := 15;
  GDVars.gMapY := 1;
  GDVars.gFacing := C_Dir.WEST;
  FillChar(GDVars.doorOpen, SizeOf(GDVars.doorOpen), 1);
  { WALLDEF reload ID 0, symbol slot 1 }
  wallCache[1].wallDefId := 0;
  wallCache[1].symbolSlot := 1;
  for GDVars.gi2 := 2 to 3 do begin
    { slots 2-3 = empty }
    wallCache[GDVars.gi2].wallDefId := -1;
    wallCache[GDVars.gi2].symbolSlot := -1;
  end;
  GDVars.portraitsOn := 1;
  GDVars.monsterPics := 1;
  GDVars.musicOn := 1;
  GDVars.soundOn := 1;
  GDVars.quickEnds := 1;
  GDVars.quickMagicOn := 0;
  GDVars.stingHpFlag := 0;
  GDVars.debugTraceEnabled := False;
  GDVars.bottomLineTaken := False;
  GDVars.msgDelayFlag := 1;
  GDVars.loadedSave := 0;
  GDVars.restTicks := 0;
  GDVars.creatureList := nil;
  GDVars.curChar := nil;
  GDVars.eclIp := $9900;
  GDVars.gameDelay := 1;
  GDVars.suppressContinuePrompt := 0;
  GDVars.virtualDisk := 1;
  GDVars.prevVirtualDisk := 1;
  GDVars.unidentified03 := 1;
  GDVars.unidentified02 := 1;
  GDVars.automapOn := False;
  GDVars.locTypePrev := C_Area.LOC_3D_MAP;
  GDVars.gLocType := C_Area.LOC_3D_MAP;
  { party size }
  Types.PGameini2ZoneWords(Session.dsGbvmZones[1])^[$33E] := 0;
  GDVars.dsWildAnimFrame := 0;
  GDVars.vertTop := 1;
  GDVars.duelFlag := False;
  GDVars.dsSuppressDrawingBorderFlag := 0;
  GDVars.dsSearchModeFlag := 0;
  GDVars.dsEcl3dClearFlag := 0;
  GDVars.protNewLine := 0;
  GDVars.eclGraphics := False;
  GDVars.partyDefeated := False;
  GDVars.clipFlag := 1;
  GDVars.sprShown := False;
  GDVars.dsSuppressingInsertDiskFlag := 0;
  GDVars.picArcName[0] := #0;
  GDVars.picArcId := 255;
  GDVars.recentSaved := 0;
  GDVars.ceilFloorColorSel := 232;
  GDVars.wallColorSel := 219;
  GDVars.inEncMenu := 0;
  GDVars.soundAutoStop := 0;
  SoundDrv.SoundSetAutoStop(100);
  GDVars.savedDir := GDVars.gameDir;
  GDVars.gameDir[0] := #0;
  TextRend.LoadGameFont;
  TextRend.ClearBottomLine;
  TextRend.DisplayString(0, 24, LightGreen, 'Loading...Please Wait');
  Sym8x8.Load8x8Set(202, 4);
  Sym8x8.Load8x8Set(203, 0);
  Blit.LoadPic('sqrpaci', 1, False, 0, GDVars.ds2dMapTilePtr);
  Blit.LoadPic('sqrpaci', 2, False, 0, GDVars.ds2dMapTilePtr2);
  for GDVars.gi2 := 0 to 11 do
    MapTiles.LoadIconAnim('COMSPR', GDVars.gi2, GDVars.gi2 + 13);
  MapTiles.LoadIconAnim('COMSPR', 25, 25);
  GDVars.itemsOk := DaxIo.OpenWithRetry('ITEMS', GDConsts.insertDiskMsg[GDVars.virtualDisk] + DaxIo.DataDrive + ':',
                                        #0, GDVars.itemsFile);
  Reset(GDVars.itemsFile, 1);
  Seek(GDVars.itemsFile, 2);
  { This asks for 129 records into the 128-entry item table; baseItemsOverflow after it keeps a 129th in bounds. The
    file must hold the 128. }
  BlockRead(GDVars.itemsFile, GDVars.baseItems, 129 * SizeOf(Types.TBaseItemRec), GDVars.itemsRead);
  Close(GDVars.itemsFile);
  if (IOResult <> 0) or (GDVars.itemsRead < 128 * SizeOf(Types.TBaseItemRec)) then begin
    Blit.RestoreVideoMode;
    WriteLn('Unable to read ITEMS.');
    ch := GameIo.ReadGameKey;
    Blit.RestoreVideoMode;
    GameIo.ExitGame;
  end;
  GDVars.gameDir := GDVars.savedDir;
  TextRend.ClearBottomLine;
  { the settings, over the defaults above, before the title music }
  Options.LoadOptions;
  { Started with NORAND as the second argument, for testing, the game seeds the random numbers with 1, so two runs
    given the same keys roll the same dice. }
  if ParamStr(2) = 'NORAND' then
    RandSeed := 1
  else
    Randomize;
  { Install spell function pointers. }
  Magic.InitSpellFns;
  { Install effect function pointers. }
  EffHndlr.InitEffectHandlers;
end;

end.

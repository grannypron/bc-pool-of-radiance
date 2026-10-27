{ Endgame animation, victory sequence and Yarash completion handling. }
{$O+,F+}
{$I COMPILER.INC}
unit Ending;

interface

procedure WinGame;

procedure YarashComplete(animate: Boolean);

implementation

uses Types, Crt, C_TILE, C_MSG, GameDefs, GameVars, CharHlp, Wilds, Portrait, C_GBVM, C_IFC, Blit, TextRend, CharDisp,
  MapTiles;

{ Play FINAL picture picId at (col, row) for nCycles passes through its frames; nothing is played if it does not load. }
procedure PlayFinalAnim(col, row: Integer; picId, nCycles: Byte);
var
  a: Types.TAnimRec;
  tickNow: LongInt;
  tickLast: LongInt;
  cycles: Byte;
begin
  cycles := 0;
  tickLast := TextRend.GetTicks;
  FillChar(a, SizeOf(a), 0);
  Portrait.LoadAnimation('FINAL', picId, 2, a);
  if a.count = 0 then begin
    Portrait.FreeAnimation(a);
    Exit;
  end;
  Blit.BlitTileClipped(col - 1, row - 1, 0, 0, a.frames[1].pic, GameVars.viewBuffer);
  Blit.FlushView;
  repeat
    Portrait.DisplayImageBuf(col, row, True, a.frames[a.current].pic);
    tickNow := TextRend.GetTicks;
    { the tick count restarts at midnight }
    if (tickNow - tickLast > a.frames[a.current].time * (GameVars.gameDelay + 3)) or (tickNow < tickLast) then begin
      Inc(a.current);
      if a.current > a.count then begin
        a.current := 1;
        Inc(cycles);
      end;
      tickLast := tickNow;
    end;
  until cycles = nCycles;
  Portrait.FreeAnimation(a);
end;

{ Play the endgame: the dragon's death, Tyranthraxus' possession threat and Bane's recall, each with its text and a
  FINAL animation. Pictures are blocks of FINAL<n>.DAX, where n is the virtual disk number; blocks 4, 5 and 6 add a
  party figure when the party has more than 1, 2 and 3 members. The interface state is C_IFC.WON_GAME for the duration,
  then the saved state is restored and the non-combat interface redrawn. }
procedure WinGame;
var
  { the picture each block is loaded into in turn (Blit.LoadPic frees the last) }
  finalPic: Types.PImgBuf;
  savedIfc: Byte;
  { virtual disk digit appended to the FINAL picture names }
  finalSfx: String[1];
  { the passes of the first two animations: fewer the slower the game's speed }
  cycles: Byte;
begin
  cycles := Word(10 - GameVars.gameDelay) * 5 div 2;
  Str(GameVars.diskIndex, finalSfx);
  savedIfc := GameVars.ifcState;
  GameVars.ifcState := C_IFC.WON_GAME;
  finalPic := nil;
  TextRend.ClearRect(C_MSG.TEXT_LEFT, C_MSG.MESSAGE_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
  TextRend.DisplayString(1, 17, LightGreen, 'Mortally wounded, the dragon roars!');
  TextRend.DisplayString(1, 18, LightGreen, 'The spirit of Tyranthraxus flares up');
  TextRend.DisplayString(1, 19, LightGreen, 'from the dragon''s body.');
  CharDisp.DisplayNoncombatInterface;
  Blit.LoadPic('FINAL' + finalSfx, 1, False, 0, finalPic);
  Blit.BlitTileClipped(0, 0, 0, 0, finalPic, GameVars.viewBuffer);
  Ending.PlayFinalAnim(3, 5, 2, cycles);
  Blit.LoadPic('FINAL' + finalSfx, 3, False, 0, finalPic);
  Blit.BlitTileClipped(0, 0, 0, 0, finalPic, GameVars.viewBuffer);
  if GameVars.zone1^[C_GBVM.PARTY_SIZE] > 1 then begin
    Blit.LoadPic('FINAL' + finalSfx, 4, False, 0, finalPic);
    Blit.BlitTileClipped(0, 11, 0, 0, finalPic, GameVars.viewBuffer);
  end;
  if GameVars.zone1^[C_GBVM.PARTY_SIZE] > 2 then begin
    Blit.LoadPic('FINAL' + finalSfx, 5, False, 0, finalPic);
    Blit.BlitTileClipped(13, 9, 0, 0, finalPic, GameVars.viewBuffer);
  end;
  if GameVars.zone1^[C_GBVM.PARTY_SIZE] > 3 then begin
    Blit.LoadPic('FINAL' + finalSfx, 6, False, 0, finalPic);
    Blit.BlitTileClipped(0, 9, 0, 0, finalPic, GameVars.viewBuffer);
  end;
  TextRend.ClearRect(C_MSG.TEXT_LEFT, C_MSG.MESSAGE_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
  TextRend.DisplayString(1, 17, LightGreen, '"Fools, you have but slain the body');
  TextRend.DisplayString(1, 18, LightGreen, 'I possessed.  I cannot be defeated!"');
  TextRend.DisplayString(1, 19, LightGreen, 'With the power of the pool of radiance');
  TextRend.DisplayString(1, 20, LightGreen, 'which I moved here, to my lair,');
  TextRend.DisplayString(1, 21, LightGreen, 'I will still rule, by possessing one');
  TextRend.DisplayString(1, 22, LightGreen, 'of you!"');
  Ending.PlayFinalAnim(3, 1, 7, cycles);
  TextRend.ClearRect(C_MSG.TEXT_LEFT, C_MSG.MESSAGE_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
  TextRend.DisplayString(1, 17, LightGreen, '"No Lord Bane!  I can still rule here!');
  TextRend.DisplayString(1, 18, LightGreen, 'I have not failed.  Do not call me back');
  TextRend.DisplayString(1, 19, LightGreen, 'through the pool!"');
  TextRend.DisplayString(1, 20, LightGreen, 'Noooo...');
  Ending.PlayFinalAnim(3, 1, 8, 1);
  TextRend.PauseOnly;
  TextRend.PauseOnly;
  TextRend.PauseOnly;
  { the game goes on after the ending }
  Blit.FreePic(finalPic);
  GameVars.ifcState := savedIfc;
  CharDisp.DisplayNoncombatInterface;
end;

{ Recolor Yarash's pyramid in the wilderness tile sets. When animate is True, first show the view at (17,15), then run
  nine steps that each apply a dithered (random partial) remap to the pyramid tiles and redraw the view at that step's
  viewport. Always apply the full, undithered remap; when animating, then show the view at (23,25) and pause twice. }
procedure YarashComplete(animate: Boolean);
const
  { Wilderness tiles remapped Black to Blue and LightGray to Green. Bit 7 selects the second tile set (mapTilePtr2),
    the low 7 bits the frame. }
  yarBlueGreenTiles: array[0..10] of Byte = (101, 102, 103, 104, 105, 106, 107, 113, 128 + 96, 128 + 97, 128 + 98);
  { Wilderness tiles remapped LightGray to Green. Bit 7 selects the second tile set, the low 7 bits the frame. }
  yarGreenTiles: array[0..17] of Byte = (86, 87, 88, 89, 108, 109, 110, 111, 112, 114, 115, 116, 117, 118, 119,
                                         128 + 95, 128 + 115, 128 + 117);
  { Wilderness viewport left column and top row for each animation step }
  yarViewX: array[0..8] of Byte = (17, 17, 17, 19, 19, 19, 23, 23, 23);
  yarViewY: array[0..8] of Byte = (15, 15, 15, 20, 20, 20, 25, 25, 25);
var
  { GameDefs.colorIdentity, every colour to itself, is the source side of both remaps; blueGreenTo and greenTo differ
    from it only as named }
  blueGreenTo: Types.TColorTab;
  greenTo: Types.TColorTab;
  step: Byte;

  { Remap tile (bit 7 the second sheet) to toT, dithered or whole. }
  procedure RemapTile(tile: Byte; var toT: Types.TColorTab; dither: Boolean);
  begin
    if tile > C_TILE.ID_MASK then
      Blit.RemapPic(GameDefs.colorIdentity, toT, tile and C_TILE.ID_MASK, dither, MapTiles.SecondSheet)
    else
      Blit.RemapPic(GameDefs.colorIdentity, toT, tile, dither, GameVars.mapTilePtr);
  end;

  { Remap every pyramid tile, dithered or whole. }
  procedure RemapPyramid(dither: Boolean);
  var
    t: Byte;
  begin
    { 10 = High(yarBlueGreenTiles), 17 = High(yarGreenTiles) }
    for t := 0 to 10 do
      RemapTile(yarBlueGreenTiles[t], blueGreenTo, dither);
    for t := 0 to 17 do
      RemapTile(yarGreenTiles[t], greenTo, dither);
  end;

begin
  greenTo := GameDefs.colorIdentity;
  greenTo[LightGray] := Green;
  blueGreenTo := greenTo;
  blueGreenTo[Black] := Blue;
  if animate then begin
    Wilds.BuildWildernessMap(17, 15);
    Blit.FlushView;
    { 8 = High(yarViewX) = High(yarViewY) }
    for step := 0 to 8 do begin
      RemapPyramid(True);
      Wilds.BuildWildernessMap(yarViewX[step], yarViewY[step]);
      Blit.FlushView;
    end;
  end;
  RemapPyramid(False);
  if animate then begin
    Wilds.BuildWildernessMap(23, 25);
    Blit.FlushView;
    TextRend.PauseOnly;
    TextRend.PauseOnly;
  end;
end;

end.PauseOnly;
    TextRend.PauseOnly;
  end;
end;

end.

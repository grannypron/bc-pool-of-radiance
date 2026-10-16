{ Endgame animation, victory sequence and Yarash completion handling. }
{$O+,F+}
unit Ending;

interface

procedure WinGame;

procedure YarashComplete(animate: Boolean);

implementation

uses Types, Crt, C_Tile, C_Msg, GDConsts, GDVars, CharHlp, Wilds, Portrait, C_Gbvm, C_Ifc, Blit, TextRend, CharDisp;

var
  { WinGame passes it by var to Blit.LoadPic }
  finalPic: Types.PImgBuf;
  { WinGame saves and restores ifcState }
  savedIfc: Byte;
  { virtual disk digit appended to the FINAL picture names }
  finalSfx: String[1];

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
  Blit.BlitTileClipped(col - 1, row - 1, 0, 0, a.frames[1].pic, GDVars.dsViewImageBufferPtr);
  Blit.FlushView;
  repeat
    Portrait.DisplayImageBuf(col, row, True, a.frames[a.current].pic);
    tickNow := TextRend.GetTicks;
    { the tick count restarts at midnight }
    if (tickNow - tickLast > a.frames[a.current].time * (GDVars.gameDelay + 3)) or (tickNow < tickLast) then begin
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
  party figure when the party has more than 1, 2 and 3 members. The interface state is C_Ifc.WON_GAME for the duration,
  then the saved state is restored and the non-combat interface redrawn. }
procedure WinGame;
begin
  Str(GDVars.virtualDisk, finalSfx);
  savedIfc := GDVars.ifcState;
  GDVars.ifcState := C_Ifc.WON_GAME;
  finalPic := nil;
  TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
  TextRend.DisplayString(1, 17, LightGreen, 'Mortally wounded, the dragon roars!');
  TextRend.DisplayString(1, 18, LightGreen, 'The spirit of Tyranthraxus flares up');
  TextRend.DisplayString(1, 19, LightGreen, 'from the dragon''s body.');
  CharDisp.DisplayNoncombatInterface;
  Blit.LoadPic('FINAL' + finalSfx, 1, False, 0, finalPic);
  Blit.BlitTileClipped(0, 0, 0, 0, finalPic, GDVars.dsViewImageBufferPtr);
  Ending.PlayFinalAnim(3, 5, 2, Word(10 - GDVars.gameDelay) * 5 div 2);
  Blit.LoadPic('FINAL' + finalSfx, 3, False, 0, finalPic);
  Blit.BlitTileClipped(0, 0, 0, 0, finalPic, GDVars.dsViewImageBufferPtr);
  if GDVars.zone1^[C_Gbvm.PARTY_SIZE] > 1 then begin
    Blit.LoadPic('FINAL' + finalSfx, 4, False, 0, finalPic);
    Blit.BlitTileClipped(0, 11, 0, 0, finalPic, GDVars.dsViewImageBufferPtr);
  end;
  if GDVars.zone1^[C_Gbvm.PARTY_SIZE] > 2 then begin
    Blit.LoadPic('FINAL' + finalSfx, 5, False, 0, finalPic);
    Blit.BlitTileClipped(13, 9, 0, 0, finalPic, GDVars.dsViewImageBufferPtr);
  end;
  if GDVars.zone1^[C_Gbvm.PARTY_SIZE] > 3 then begin
    Blit.LoadPic('FINAL' + finalSfx, 6, False, 0, finalPic);
    Blit.BlitTileClipped(0, 9, 0, 0, finalPic, GDVars.dsViewImageBufferPtr);
  end;
  TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
  TextRend.DisplayString(1, 17, LightGreen, '"Fools, you have but slain the body');
  TextRend.DisplayString(1, 18, LightGreen, 'I possessed.  I cannot be defeated!"');
  TextRend.DisplayString(1, 19, LightGreen, 'With the power of the pool of radiance');
  TextRend.DisplayString(1, 20, LightGreen, 'which I moved here, to my lair,');
  TextRend.DisplayString(1, 21, LightGreen, 'I will still rule, by possessing one');
  TextRend.DisplayString(1, 22, LightGreen, 'of you!"');
  Ending.PlayFinalAnim(3, 1, 7, Word(10 - GDVars.gameDelay) * 5 div 2);
  TextRend.ClearRect(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
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
  GDVars.ifcState := savedIfc;
  CharDisp.DisplayNoncombatInterface;
end;

{ Recolor Yarash's pyramid in the wilderness tile sets. When animate is True, first show the view at (17,15), then run
  nine steps that each apply a dithered (random partial) remap to the pyramid tiles and redraw the view at that step's
  viewport. Always apply the full, undithered remap; when animating, then show the view at (23,25) and pause twice. }
procedure YarashComplete(animate: Boolean);
var
  t: Byte;
  step: Byte;
begin
  if animate then begin
    Wilds.BuildWildernessMap(17, 15);
    Blit.FlushView;
    { 8 = High(yarViewX) = High(yarViewY) }
    for step := 0 to 8 do begin
      { 10 = High(yarBlueGreenTiles) }
      for t := 0 to 10 do
        if GDConsts.yarBlueGreenTiles[t] > C_Tile.ID_MASK then
          Blit.RemapPic(GDConsts.yarRemapFrom, GDConsts.yarBlueGreenTo,
                        GDConsts.yarBlueGreenTiles[t] and C_Tile.ID_MASK, True,
                        GDVars.ds2dMapTilePtr2)
        else
          Blit.RemapPic(GDConsts.yarRemapFrom, GDConsts.yarBlueGreenTo, GDConsts.yarBlueGreenTiles[t], True,
                        GDVars.ds2dMapTilePtr);
      { 17 = High(yarGreenTiles) }
      for t := 0 to 17 do
        if GDConsts.yarGreenTiles[t] > C_Tile.ID_MASK then
          Blit.RemapPic(GDConsts.yarRemapFrom, GDConsts.yarGreenTo, GDConsts.yarGreenTiles[t] and C_Tile.ID_MASK, True,
                        GDVars.ds2dMapTilePtr2)
        else
          Blit.RemapPic(GDConsts.yarRemapFrom, GDConsts.yarGreenTo, GDConsts.yarGreenTiles[t], True,
                        GDVars.ds2dMapTilePtr);
      Wilds.BuildWildernessMap(GDConsts.yarViewX[step], GDConsts.yarViewY[step]);
      Blit.FlushView;
    end;
  end;
  { 10 = High(yarBlueGreenTiles) }
  for t := 0 to 10 do
    if GDConsts.yarBlueGreenTiles[t] > C_Tile.ID_MASK then
      Blit.RemapPic(GDConsts.yarRemapFrom, GDConsts.yarBlueGreenTo,
                    GDConsts.yarBlueGreenTiles[t] and C_Tile.ID_MASK, False,
                    GDVars.ds2dMapTilePtr2)
    else
      Blit.RemapPic(GDConsts.yarRemapFrom, GDConsts.yarBlueGreenTo, GDConsts.yarBlueGreenTiles[t], False,
                    GDVars.ds2dMapTilePtr);
  { 17 = High(yarGreenTiles) }
  for t := 0 to 17 do
    if GDConsts.yarGreenTiles[t] > C_Tile.ID_MASK then
      Blit.RemapPic(GDConsts.yarRemapFrom, GDConsts.yarGreenTo, GDConsts.yarGreenTiles[t] and C_Tile.ID_MASK,
                    False, GDVars.ds2dMapTilePtr2)
    else
      Blit.RemapPic(GDConsts.yarRemapFrom, GDConsts.yarGreenTo, GDConsts.yarGreenTiles[t], False,
                    GDVars.ds2dMapTilePtr);
  if animate then begin
    Wilds.BuildWildernessMap(23, 25);
    Blit.FlushView;
    TextRend.PauseOnly;
    TextRend.PauseOnly;
  end;
end;

end.

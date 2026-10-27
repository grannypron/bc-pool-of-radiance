{ Tests the layout of a saved game, SAVGAMx.DAT: the parts SaveLoad writes, in order, add up to SSI's 13,137 bytes, the
  party's map position is SSI's five bytes, and zone 0's named fields sit at their GBVM addresses. The sizes are SSI's
  v1.3 ones (por-disassembly v13/src SaveLoad: zone3 is SAVED_SCRIPT_BYTES there). }
{$I COMPILER.INC}
program TSaveLay;

uses Types, GameVars, C_GBVM, TestKit;

var
  total: LongInt;
  mapPos: LongInt;

{ Check that zone 0's field at actual is at GBVM word address addr: C_GBVM's name for it, where it has one. }
procedure Zone0At(addr: Word; actual: Word; what: String);
begin
  TestKit.CheckEqualsL(LongInt(addr - $4900) * 2, actual, 'zone 0''s ' + what + ' is at its GBVM address');
end;

begin
  TestKit.Start('TSAVELAY');
  TestKit.CheckEqualsL(1, SizeOf(GameVars.diskIndex), 'the disk number is a byte');
  TestKit.CheckEqualsL(2048, SizeOf(GameVars.zone0^), 'zone 0');
  TestKit.CheckEqualsL(2048, SizeOf(GameVars.zone1^), 'zone 1');
  TestKit.CheckEqualsL(1024, SizeOf(GameVars.zone2^), 'zone 2');
  TestKit.CheckEqualsL(7680, C_GBVM.SAVED_SCRIPT_BYTES, 'the saved part of the script buffer is SSI''s whole buffer');
  TestKit.Check(SizeOf(GameVars.zone3^) >= C_GBVM.SAVED_SCRIPT_BYTES, 'the script buffer holds the saved part');
  { the party's map position, one byte each }
  mapPos := SizeOf(GameVars.gMapX) + SizeOf(GameVars.gMapY) + SizeOf(GameVars.gFacing) + SizeOf(GameVars.wallAhead) +
            SizeOf(GameVars.eventAtCell);
  TestKit.CheckEqualsL(5, mapPos, 'the map position is five bytes');
  TestKit.CheckEqualsL(1, SizeOf(GameVars.gLocType), 'gLocType is a byte');
  TestKit.CheckEqualsL(1, SizeOf(GameVars.ifcState), 'ifcState is a byte');
  TestKit.CheckEqualsL(8, Types.MAX_PARTY, 'eight names');
  TestKit.CheckEqualsL(41, SizeOf(Types.TStr40), 'of 41 bytes each');
  total := SizeOf(GameVars.diskIndex) + SizeOf(GameVars.zone0^) + SizeOf(GameVars.zone1^) + SizeOf(GameVars.zone2^) +
           C_GBVM.SAVED_SCRIPT_BYTES + mapPos + SizeOf(GameVars.gLocType) + SizeOf(GameVars.ifcState) + 1 +
           Types.MAX_PARTY * SizeOf(Types.TStr40);
  TestKit.CheckEqualsL(13137, total, 'a saved game is SSI''s 13,137 bytes');

  with GameVars.zone0^ do begin
    Zone0At(C_GBVM.PARTY_X, Ofs(partyX) - Ofs(words), 'partyX');
    Zone0At(C_GBVM.PARTY_Y, Ofs(partyY) - Ofs(words), 'partyY');
    Zone0At(C_GBVM.MAP_ID, Ofs(mapId) - Ofs(words), 'mapId');
    Zone0At(C_GBVM.CLOCK, Ofs(clock) - Ofs(words), 'clock');
    Zone0At(C_GBVM.ANTIMAGIC, Ofs(antimagic) - Ofs(words), 'antimagic');
    Zone0At(C_GBVM.VIEW_3D, Ofs(view3dFlag) - Ofs(words), 'view3dFlag');
    Zone0At(C_GBVM.MAP_3D_GFX1, Ofs(mapGraphics1) - Ofs(words), 'mapGraphics1');
    Zone0At(C_GBVM.MAP_3D_GFX2, Ofs(mapGraphics2) - Ofs(words), 'mapGraphics2');
    Zone0At(C_GBVM.PREV_X, Ofs(previousX) - Ofs(words), 'previousX');
    Zone0At(C_GBVM.PREV_Y, Ofs(previousY) - Ofs(words), 'previousY');
    Zone0At(C_GBVM.PREV_SCRIPT_ID, Ofs(previousScriptId) - Ofs(words), 'previousScriptId');
    Zone0At(C_GBVM.NO_AUTOMAP, Ofs(noAutomap) - Ofs(words), 'noAutomap');
    Zone0At(C_GBVM.GAME_SPEED, Ofs(gameSpeed) - Ofs(words), 'gameSpeed');
    Zone0At(C_GBVM.SKY_CEILING_COLOR, Ofs(skyCeilingColor) - Ofs(words), 'skyCeilingColor');
    Zone0At(C_GBVM.ALT_SKY_COLOR, Ofs(alternateSkyColor) - Ofs(words), 'alternateSkyColor');
    Zone0At(C_GBVM.SETTINGS, Ofs(settings) - Ofs(words), 'settings');
    Zone0At($4A00, Ofs(entryWords) - Ofs(words), 'entryWords');
    Zone0At($4A7C, Ofs(nomadCampFlags) - Ofs(words), 'nomadCampFlags');
    Zone0At(C_GBVM.BUCCANEERS_BASE_VISIBLE, Ofs(buccaneersBaseVisible) - Ofs(words), 'buccaneersBaseVisible');
    Zone0At($4A9F, Ofs(nomadCampGate) - Ofs(words), 'nomadCampGate');
    Zone0At($4AA0, Ofs(easternSitesGate) - Ofs(words), 'easternSitesGate');
    Zone0At(C_GBVM.YARASH_PYRAMID_LEFT, Ofs(yarashPyramidLeft) - Ofs(words), 'yarashPyramidLeft');
    Zone0At(C_GBVM.YARASH_MISSION_DONE, Ofs(yarashMissionDone) - Ofs(words), 'yarashMissionDone');
    Zone0At(C_GBVM.WALLSLOT_ID + 1, Ofs(savedWalls) - Ofs(words), 'savedWalls');
  end;
  TestKit.Done;
end.

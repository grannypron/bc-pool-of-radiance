{ Tests the layout of a saved game, SAVGAMx.DAT: the parts SaveLoad writes, in order, add up to SSI's 13,137 bytes, the
  party's map position is SSI's five bytes, and zone 0's named fields sit at their GBVM addresses. The sizes are SSI's
  v1.3 ones (por-disassembly v13/src SaveLoad: zone3 is SAVED_SCRIPT_BYTES there). }
program TSaveLay;

uses Types, GDVars, C_Gbvm, TestKit;

var
  total: LongInt;
  mapPos: LongInt;

{ Check that zone 0's field at actual is at GBVM word address addr. }
procedure Zone0At(addr: Word; actual: Word; what: String);
begin
  TestKit.CheckEqualsL(LongInt(addr - $4900) * 2, actual, 'zone 0''s ' + what + ' is at its GBVM address');
end;

begin
  TestKit.Start('TSAVELAY');
  TestKit.CheckEqualsL(1, SizeOf(GDVars.virtualDisk), 'the disk number is a byte');
  TestKit.CheckEqualsL(2048, SizeOf(GDVars.zone0^), 'zone 0');
  TestKit.CheckEqualsL(2048, SizeOf(GDVars.zone1^), 'zone 1');
  TestKit.CheckEqualsL(1024, SizeOf(GDVars.zone2^), 'zone 2');
  TestKit.CheckEqualsL(7680, C_Gbvm.SAVED_SCRIPT_BYTES, 'the saved part of the script buffer is SSI''s whole buffer');
  TestKit.Check(SizeOf(GDVars.zone3^) >= C_Gbvm.SAVED_SCRIPT_BYTES, 'the script buffer holds the saved part');
  { the party's map position, one byte each }
  mapPos := SizeOf(GDVars.gMapX) + SizeOf(GDVars.gMapY) + SizeOf(GDVars.gFacing) + SizeOf(GDVars.wallAhead) +
            SizeOf(GDVars.eventAtCell);
  TestKit.CheckEqualsL(5, mapPos, 'the map position is five bytes');
  TestKit.CheckEqualsL(1, SizeOf(GDVars.gLocType), 'gLocType is a byte');
  TestKit.CheckEqualsL(1, SizeOf(GDVars.ifcState), 'ifcState is a byte');
  TestKit.CheckEqualsL(8, Types.MAX_PARTY, 'eight names');
  TestKit.CheckEqualsL(41, SizeOf(Types.TStr40), 'of 41 bytes each');
  total := SizeOf(GDVars.virtualDisk) + SizeOf(GDVars.zone0^) + SizeOf(GDVars.zone1^) + SizeOf(GDVars.zone2^) +
           C_Gbvm.SAVED_SCRIPT_BYTES + mapPos + SizeOf(GDVars.gLocType) + SizeOf(GDVars.ifcState) + 1 +
           Types.MAX_PARTY * SizeOf(Types.TStr40);
  TestKit.CheckEqualsL(13137, total, 'a saved game is SSI''s 13,137 bytes');

  with GDVars.zone0^ do begin
    Zone0At($49C3, Ofs(partyX) - Ofs(words), 'partyX');
    Zone0At($49C4, Ofs(partyY) - Ofs(words), 'partyY');
    Zone0At($49C5, Ofs(mapId) - Ofs(words), 'mapId');
    Zone0At($49C6, Ofs(clock) - Ofs(words), 'clock');
    Zone0At($49E5, Ofs(antimagic) - Ofs(words), 'antimagic');
    Zone0At($49F0, Ofs(previousX) - Ofs(words), 'previousX');
    Zone0At($49F2, Ofs(previousScriptId) - Ofs(words), 'previousScriptId');
    Zone0At($49FB, Ofs(noAutomap) - Ofs(words), 'noAutomap');
    Zone0At($49FC, Ofs(gameSpeed) - Ofs(words), 'gameSpeed');
    Zone0At($49FF, Ofs(settings) - Ofs(words), 'settings');
    Zone0At($4A00, Ofs(entryWords) - Ofs(words), 'entryWords');
    Zone0At($4A7C, Ofs(nomadCampFlags) - Ofs(words), 'nomadCampFlags');
    Zone0At($4A8C, Ofs(buccaneersBaseGate) - Ofs(words), 'buccaneersBaseGate');
    Zone0At($4A9F, Ofs(nomadCampGate) - Ofs(words), 'nomadCampGate');
    Zone0At($4AA0, Ofs(easternSitesGate) - Ofs(words), 'easternSitesGate');
    Zone0At($4AA2, Ofs(yarashPyramidLeft) - Ofs(words), 'yarashPyramidLeft');
  end;
  TestKit.Done;
end.

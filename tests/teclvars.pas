{ Tests for EclVars' GBVM address map: the zones, and every special address a script reads or writes in place of the
  game's variables (C_GBVM names them), so moving or renaming a variable cannot break a script unnoticed. }
{$I COMPILER.INC}
program TEclVars;

uses Types, GameVars, C_GBVM, C_MONEY, C_DIR, C_STATUS, C_EFFECT, C_SAVE, EclVars, StrUtil, TestKit;

var
  c: Types.PCharRecord;
  e1: Types.TEffectRec;
  e2: Types.TEffectRec;
  lastDisk: Byte;
  lastWallSet: Byte;
  lastSlot: Byte;
  k: Byte;
  ok: Boolean;

procedure TestDisk(disk: Byte);
begin
  lastDisk := disk;
end;

procedure TestWallSet(fileId, slot: Byte);
begin
  lastWallSet := fileId;
  lastSlot := slot;
end;

procedure Same(expected: LongInt; address: Word; what: String);
begin
  TestKit.CheckEqualsL(expected, EclVars.ReadGbvm(address), what);
end;

begin
  TestKit.Start('TECLVARS');
  GetMem(GameVars.zone0, SizeOf(GameVars.zone0^));
  GetMem(GameVars.zone1, SizeOf(GameVars.zone1^));
  GetMem(GameVars.zone2, SizeOf(GameVars.zone2^));
  GetMem(GameVars.zone3, SizeOf(GameVars.zone3^));
  FillChar(GameVars.zone0^, SizeOf(GameVars.zone0^), 0);
  FillChar(GameVars.zone1^, SizeOf(GameVars.zone1^), 0);
  FillChar(GameVars.zone2^, SizeOf(GameVars.zone2^), 0);
  FillChar(GameVars.zone3^, SizeOf(GameVars.zone3^), 0);
  GetMem(c, SizeOf(Types.TCharRecord));
  FillChar(c^, SizeOf(Types.TCharRecord), 0);
  c^.status := C_STATUS.OKAY;
  GameVars.curChar := c;
  GameVars.creatureList := c;
  GameVars.zone1^[C_GBVM.PARTY_SIZE] := 1;
  EclVars.diskHook := TestDisk;
  EclVars.wallSetHook := TestWallSet;

  { the zones }
  TestKit.CheckEqualsL(0, EclVars.GbvmZone(C_GBVM.ZONE0_FIRST), 'zone 0 starts at ZONE0_FIRST');
  TestKit.CheckEqualsL(1, EclVars.GbvmZone(C_GBVM.ZONE1_LAST), 'zone 1 ends at ZONE1_LAST');
  TestKit.CheckEqualsL(2, EclVars.GbvmZone(C_GBVM.ZONE2_FIRST), 'zone 2');
  TestKit.CheckEqualsL(3, EclVars.GbvmZone(C_GBVM.SCRIPT_FIRST), 'zone 3, the script');
  TestKit.CheckEqualsL(4, EclVars.GbvmZone(C_GBVM.ZONE0_LAST + 1), 'between the zones is zone 4');
  TestKit.CheckEqualsL(4, EclVars.GbvmZone(C_GBVM.CELL_PARTY_X), 'and the special cells');
  EclVars.WriteGbvm($4A10, 1234);
  Same(1234, $4A10, 'a zone 0 word');
  EclVars.WriteGbvm($9710, 4321);
  Same(4321, $9710, 'a zone 2 word');
  EclVars.WriteGbvm(C_GBVM.SCRIPT_FIRST + 5, $1234);
  Same($34, C_GBVM.SCRIPT_FIRST + 5, 'a script cell holds a byte');

  { the current character, read }
  c^.conCur := 15;
  Same(15, C_GBVM.CHAR_CON, 'CHAR_CON is conCur');
  c^.saves[C_SAVE.PETRIFY] := 11;
  Same(11, C_GBVM.CHAR_SAVE_PETRIFY, 'CHAR_SAVE_PETRIFY');
  c^.levelHighest := 6;
  Same(6, C_GBVM.CHAR_LEVEL, 'CHAR_LEVEL is levelHighest');
  ok := True;
  for k := 1 to 8 do begin
    c^.thiefSkills[k] := 10 + k;
    if EclVars.ReadGbvm(C_GBVM.CHAR_THIEF_SKILLS + k - 1) <> 10 + k then
      ok := False;
  end;
  TestKit.Check(ok, 'CHAR_THIEF_SKILLS..LAST are thief skills 1..8');
  c^.coins[C_MONEY.COPPER] := 1;
  c^.coins[C_MONEY.SILVER] := 2;
  c^.coins[C_MONEY.ELECTRUM] := 3;
  c^.coins[C_MONEY.GOLD] := 4;
  c^.coins[C_MONEY.PLATINUM] := 5;
  TestKit.Check((EclVars.ReadGbvm(C_GBVM.CHAR_COPPER) = 1) and (EclVars.ReadGbvm(C_GBVM.CHAR_SILVER) = 2) and
                (EclVars.ReadGbvm(C_GBVM.CHAR_ELECTRUM) = 3) and (EclVars.ReadGbvm(C_GBVM.CHAR_GOLD) = 4) and
                (EclVars.ReadGbvm(C_GBVM.CHAR_PLATINUM) = 5), 'the coins, copper to platinum');
  c^.xpAward := 300;
  Same(300, C_GBVM.CHAR_XP_AWARD, 'CHAR_XP_AWARD');
  c^.xpBonusPerHp := 7;
  Same(7, C_GBVM.CHAR_XP_PER_HP, 'CHAR_XP_PER_HP');
  c^.enabled := 1;
  Same(1, C_GBVM.CHAR_ENABLED, 'an enabled character reads 1');
  c^.enabled := 0;
  Same($80, C_GBVM.CHAR_ENABLED, 'a disabled one $80');
  c^.hostile := 0;
  c^.quickfight := 1;
  Same($80, C_GBVM.CHAR_CONTROL, 'quick-fight reads $80');
  c^.hostile := 1;
  Same($81, C_GBVM.CHAR_CONTROL, 'hostile reads $81');
  c^.hostile := 0;
  c^.quickfight := 0;
  Same(0, C_GBVM.CHAR_CONTROL, 'manual reads 0');
  c^.movementCur := 9;
  Same(9, C_GBVM.CHAR_MOVEMENT, 'CHAR_MOVEMENT is movementCur');
  Same(0, C_GBVM.CHAR_PARTY_INDEX, 'the first in the party has index 0');
  Same(0, C_GBVM.CHAR_PARTY_INDEX2, 'at either cell');
  c^.chaCur := 16;
  Same(50, C_GBVM.CHAR_LOYALTY, 'Charisma 16 gives loyalty 50');
  GameVars.diskIndex := 4;
  Same(4, C_GBVM.DISK_NUM, 'DISK_NUM is diskIndex');
  Same(1, C_GBVM.PARTY_SIZE, 'PARTY_SIZE');

  { the current character, written }
  EclVars.WriteGbvm(C_GBVM.CHAR_MEMORIZED_FIRST, 7);
  EclVars.WriteGbvm(C_GBVM.CHAR_MEMORIZED_FIRST + 2, 9);
  TestKit.Check((c^.memorizedSpells[1] = 7) and (c^.memorizedSpells[3] = 9),
                'CHAR_MEMORIZED_FIRST.. is a window from memorizedSpells[1]');
  EclVars.WriteGbvm(C_GBVM.CHAR_NPC, $B5);
  TestKit.CheckEqualsL($B5 - $32, c^.npc, 'an npc value above $B2 loses $32');
  EclVars.WriteGbvm(C_GBVM.CHAR_GOLD, 77);
  TestKit.CheckEqualsL(77, c^.coins[C_MONEY.GOLD], 'writing CHAR_GOLD sets the gold');
  EclVars.WriteGbvm(C_GBVM.CHAR_XP_AWARD, 450);
  TestKit.CheckEqualsL(450, c^.xpAward, 'writing CHAR_XP_AWARD');
  c^.enabled := 1;
  EclVars.WriteGbvm(C_GBVM.CHAR_ENABLED, $87);
  TestKit.Check((c^.enabled = 0) and (c^.status = C_STATUS.STONED), '$87 to CHAR_ENABLED disables and stones');
  GameVars.dumpCr6C00 := False;
  EclVars.WriteGbvm(C_GBVM.CHAR_ENABLED, 0);
  TestKit.Check(GameVars.dumpCr6C00, '0 to CHAR_ENABLED marks the character for removal');
  GameVars.dumpCr6B00 := False;
  EclVars.WriteGbvm(C_GBVM.CHAR_DUMP, 0);
  TestKit.Check(GameVars.dumpCr6B00, '0 to CHAR_DUMP marks it too');
  EclVars.WriteGbvm(C_GBVM.CHAR_CONTROL, $81);
  TestKit.Check((c^.hostile = 1) and (c^.quickfight = 1), '$81 to CHAR_CONTROL: hostile');
  EclVars.WriteGbvm(C_GBVM.CHAR_CONTROL, 0);
  TestKit.Check((c^.hostile = 0) and (c^.quickfight = 0), '0: manual');
  lastDisk := 0;
  EclVars.WriteGbvm(C_GBVM.DISK_NUM, 3);
  TestKit.CheckEqualsL(3, lastDisk, 'writing DISK_NUM 3 changes disk');
  lastDisk := 0;
  EclVars.WriteGbvm(C_GBVM.DISK_NUM, 9);
  TestKit.CheckEqualsL(0, lastDisk, 'but not to disk 9');
  lastWallSet := 0;
  EclVars.WriteGbvm(C_GBVM.WALLSET_LOAD2, $85);
  TestKit.Check((lastWallSet = 5) and (lastSlot = 2), '$85 to WALLSET_LOAD2 loads wall set 5 into slot 2');
  lastWallSet := 0;
  EclVars.WriteGbvm(C_GBVM.WALLSET_LOAD3, $80);
  TestKit.CheckEqualsL(0, lastWallSet, 'but $80 loads nothing');

  { zone 4: the party and the view }
  EclVars.movedParty := False;
  EclVars.WriteGbvm(C_GBVM.CELL_PARTY_X, 7);
  TestKit.Check((GameVars.gMapX = 7) and EclVars.movedParty, 'CELL_PARTY_X moves the party');
  Same(7, C_GBVM.CELL_PARTY_X, 'and reads gMapX');
  EclVars.WriteGbvm(C_GBVM.CELL_PARTY_Y, 3);
  Same(3, C_GBVM.CELL_PARTY_Y, 'CELL_PARTY_Y is gMapY');
  EclVars.WriteGbvm(C_GBVM.CELL_FACING, 5);
  TestKit.CheckEqualsL(C_DIR.EAST, GameVars.gFacing, 'CELL_FACING takes a facing mod 4 (5 is east)');
  Same(1, C_GBVM.CELL_FACING, 'and reads it back as 0..3');
  Same(C_DIR.EAST, C_GBVM.FACING_RAW, 'FACING_RAW reads the stored facing');
  GameVars.wallAhead := 4;
  GameVars.eventAtCell := 9;
  Same(4, C_GBVM.CELL_WALL_AHEAD, 'CELL_WALL_AHEAD');
  Same(9, C_GBVM.CELL_EVENT, 'CELL_EVENT');
  GameVars.picRegionW := False;
  EclVars.WriteGbvm(C_GBVM.CELL_WALL_COLOR, 6);
  TestKit.Check((GameVars.wallColorSel = 6) and GameVars.picRegionW, 'CELL_WALL_COLOR');
  EclVars.WriteGbvm(C_GBVM.CELL_CEIL_FLOOR_COLOR, 2);
  TestKit.CheckEqualsL(2, GameVars.ceilFloorColorSel, 'CELL_CEIL_FLOOR_COLOR');
  EclVars.WriteGbvm(C_GBVM.SOUND_EFFECT, 12);
  TestKit.CheckEqualsL(12, EclVars.sndEffect, 'SOUND_EFFECT');
  EclVars.WriteGbvm(C_GBVM.READ_REG1, 99);
  EclVars.WriteGbvm(C_GBVM.WRITE_REG1, 99);
  Same(0, C_GBVM.READ_REG1, 'READ_REG1 reads 0, even written');
  Same(0, C_GBVM.READ_REG2, 'READ_REG2 reads 0');
  Same(0, C_GBVM.READ_REG3, 'READ_REG3 reads 0');
  EclVars.redrawSky := False;
  EclVars.WriteGbvm(C_GBVM.SKY_CEILING_COLOR, 3);
  TestKit.Check(EclVars.redrawSky, 'a sky colour write redraws the sky');

  { the party's effects table }
  FillChar(e1, SizeOf(e1), 0);
  FillChar(e2, SizeOf(e2), 0);
  e1.id := C_EFFECT.BLESS;
  e1.next := @e2;
  e2.id := C_EFFECT.CURSE;
  c^.effectsAddr := @e1;
  Same(C_EFFECT.BLESS, C_GBVM.PARTY_EFFECTS, 'the first party effect');
  Same(C_EFFECT.CURSE, C_GBVM.PARTY_EFFECTS + 1, 'the second');
  Same(0, C_GBVM.PARTY_EFFECTS + 2, 'none after');
  Same(0, C_GBVM.PARTY_EFFECT_OWNERS + 1, 'its owner is party member 0');
  c^.effectsAddr := nil;

  { strings }
  EclVars.WriteGbvmString(C_GBVM.CHAR_NAME, 'BRANNOR');
  TestKit.CheckEqualsS('BRANNOR', c^.name, 'a string at CHAR_NAME is the character''s name');
  EclVars.WriteGbvmString($4A20, 'HI');
  TestKit.Check((EclVars.ReadGbvm($4A20) = Ord('H')) and (EclVars.ReadGbvm($4A21) = Ord('I')) and
                (EclVars.ReadGbvm($4A22) = 0), 'a string elsewhere is one character a cell, then 0');
  { a string value has no number (POR-0162): GetEclVar gives 0 rather than reading the GBVM }
  GameVars.varTypes[5] := $80;
  GameVars.varLo[5] := 7;
  GameVars.varHi[5] := $6B;
  TestKit.CheckEqualsL(0, EclVars.GetEclVar(5), 'a string value reads as 0');
  GameVars.varTypes[5] := 2;
  TestKit.CheckEqualsL($6B07, EclVars.GetEclVar(5), 'a word gives its value');

  { reads with no value give 0 (#952), where v1.3 left the result unassigned }
  GameVars.varTypes[5] := $40;
  TestKit.CheckEqualsL(0, EclVars.GetEclVar(5), 'a variable of an unknown type reads 0');
  Same(0, C_GBVM.CELL_35F, 'CELL_35F reads 0');
  Same(0, C_GBVM.CELL_WALL_COLOR, 'CELL_WALL_COLOR, write only, reads 0');
  Same(0, $0100, 'an unlisted zone-4 address reads 0');
  GameVars.zone1^[C_GBVM.CHAR_CONTROL_HI] := 77;
  Same(0, C_GBVM.CHAR_CONTROL_HI, 'CHAR_CONTROL_HI reads 0, not its cell');
  c^.chaCur := 30;
  Same(0, C_GBVM.CHAR_LOYALTY, 'Charisma past 25 gives no loyalty: 0');

  { facing mod 4, however large }
  EclVars.WriteGbvm(C_GBVM.CELL_FACING, 4099);
  TestKit.CheckEqualsL(C_DIR.WEST, GameVars.gFacing, 'CELL_FACING 4099 is west');

  { strings in the other zones }
  EclVars.WriteGbvmString($9710, 'AB');
  TestKit.Check((EclVars.ReadGbvm($9710) = Ord('A')) and (EclVars.ReadGbvm($9712) = 0), 'a string in zone 2');
  EclVars.WriteGbvmString(C_GBVM.SCRIPT_LAST - 2, 'WXYZ');
  TestKit.Check((EclVars.ReadGbvm(C_GBVM.SCRIPT_LAST - 2) = Ord('W')) and
                (EclVars.ReadGbvm(C_GBVM.SCRIPT_LAST - 1) = Ord('X')) and
                (EclVars.ReadGbvm(C_GBVM.SCRIPT_LAST) = 0), 'a script string stops with its terminator at the end');

  { operands: a count, then the list after it (LoadEclList), and a string reference }
  GetMem(GameVars.gbStrings, SizeOf(GameVars.gbStrings^));
  EclVars.WriteGbvmString($4A20, 'HI');
  GameVars.zone3^[C_GBVM.SCRIPT_FIRST] := $2B;
  GameVars.zone3^[C_GBVM.SCRIPT_FIRST + 1] := 0;
  GameVars.zone3^[C_GBVM.SCRIPT_FIRST + 2] := 2;
  GameVars.zone3^[C_GBVM.SCRIPT_FIRST + 3] := 0;
  GameVars.zone3^[C_GBVM.SCRIPT_FIRST + 4] := 7;
  GameVars.zone3^[C_GBVM.SCRIPT_FIRST + 5] := $81;
  GameVars.zone3^[C_GBVM.SCRIPT_FIRST + 6] := $20;
  GameVars.zone3^[C_GBVM.SCRIPT_FIRST + 7] := $4A;
  GameVars.eclIp := C_GBVM.SCRIPT_FIRST;
  EclVars.LoadEclVars(1);
  TestKit.CheckEqualsL(2, EclVars.GetEclVar(1), 'the count');
  EclVars.LoadEclList(2);
  TestKit.Check((EclVars.GetEclVar(1) = 7) and (GameVars.gbStrings^[1] = 'HI'),
                'LoadEclList loads the list right after it');
  TestKit.CheckEqualsL(C_GBVM.SCRIPT_FIRST + 8, GameVars.eclIp, 'and leaves the IP on the next opcode');
  TestKit.Done;
end.

{ The ECL interpreter's variables and the game memory (GBVM) they address: loading a command's operands, reading and
  writing GBVM words and strings, and stepping over a command. Split from EclMenu, which keeps the menus and the opcode
  helpers. }
{$O+,F+}
{$I COMPILER.INC}
unit EclVars;

interface

type
  { what a script's write to the disk cell does: DaxIo.PushState }
  TDiskHook = procedure(disk: Byte);
  { what a script's write to a wall-set cell does: View3D.LoadWallSet }
  TWallSetHook = procedure(fileId, slot: Byte);

var
  { set by GameInit (a test program sets its own), so EclVars uses neither DaxIo nor View3D }
  diskHook: TDiskHook;
  wallSetHook: TWallSetHook;

{ Value of loaded ECL variable idx: type 0 gives its byte; 1 and 3 read the GBVM at its address word; 2 gives its word;
  $81 (string reference) gives its GBVM address; $80 (string value) gives 0, as its text is in gbStrings. }
function GetEclVar(idx: ShortInt): Word;

{ Read count ECL variables at the ECL IP into dsGbvmType/dsGbvmLowerByte/dsGbvmUpperByte, decoding string values and
  string references into gbStrings. Only the first 64 variables and 20 strings are kept (later strings overwrite the
  20th); the IP still steps past them all. }
procedure LoadEclVars(count: Byte);

{ Join two bytes into a word. }
function CombineBytesToWord(lowByte, highByte: Byte): Word;

{ Write value to a GBVM address; zone 1 also runs the special handler }
procedure WriteGbvm(address, value: Word);

{ Read a GBVM address }
function ReadGbvm(address: Word): Word;

{ Write s to the GBVM as a C string ($6B00 = current character name, copied as a Pascal String into the char record
  instead), shortened so that it and its terminator stay inside the zone }
procedure WriteGbvmString(address: Word; s: String);

{ Step IP past the command at IP without running it, loading its operands as its handler does }
procedure SkipEclCmd;

{ The GBVM zone address is in: 0..2 the word zones, 3 the script, 4 everything else (the special cells). }
function GbvmZone(address: Word): Byte;

implementation

uses Types, Crt, C_Npc, C_Save, GDVars, C_Ecl, C_Status, C_Gbvm, C_Dir, C_Money, CharHlp, AbilAdj;

procedure ConvGbString(len, strIdx: Byte); forward;

procedure DerefGbString(strIdx: Byte; address: Word); forward;

{ Var record at IP: +1 type, +2 low byte; types 1/2/3 take a third (high) byte; $80 = string value (packed 6-bit chars,
  low byte = packed byte count, decoded by ConvGbString); $81 = string reference (extra byte -> hi; the string at that
  GBVM address is copied by DerefGbString). IP ends on the byte after the last variable }
procedure LoadEclVars(count: Byte);
var
  i: Byte;
  strIdx: Byte;
  v: Word;
  len: Word;
  t: Byte;
  lo: Byte;
  hi: Byte;
begin
  strIdx := 0;
  for i := 1 to count do begin
    t := GDVars.zone3^[GDVars.eclIp + 1];
    lo := GDVars.zone3^[GDVars.eclIp + 2];
    GDVars.eclIp := GDVars.eclIp + 2;
    case t of
      1, 2, 3: begin
        Inc(GDVars.eclIp);
        hi := GDVars.zone3^[GDVars.eclIp];
      end;
      $80: begin
        if strIdx < Types.GB_STRING_LAST then Inc(strIdx);
        len := lo;
        if len > 0 then
          EclVars.ConvGbString(len, strIdx)
        else
          GDVars.gbStrings^[strIdx] := '';
      end;
      $81: begin
        if strIdx < Types.GB_STRING_LAST then Inc(strIdx);
        Inc(GDVars.eclIp);
        hi := GDVars.zone3^[GDVars.eclIp];
        v := EclVars.CombineBytesToWord(lo, hi);
        EclVars.DerefGbString(strIdx, v);
      end;
    end;
    { 64 = High(dsGbvmType); the upper byte is kept only for the types that carry one }
    if i <= 64 then begin
      GDVars.dsGbvmType[i] := t;
      GDVars.dsGbvmLowerByte[i] := lo;
      if (t in [1, 2, 3]) or (t = $81) then
        GDVars.dsGbvmUpperByte[i] := hi;
    end;
  end;
  Inc(GDVars.eclIp);
end;

function GetEclVar(idx: ShortInt): Word;
var
  lo: Byte;
  hi: Byte;
begin
  lo := GDVars.dsGbvmLowerByte[idx];
  hi := GDVars.dsGbvmUpperByte[idx];
  case GDVars.dsGbvmType[idx] of
    0: GetEclVar := lo;
    1, 3: GetEclVar := EclVars.ReadGbvm(hi * 256 + lo);
    { a string value has no number: its text is in gbStrings (SSI read the GBVM at an address made of the packed length
      and a stale byte, POR-0162) }
    $80: GetEclVar := 0;
    2, $81: GetEclVar := EclVars.CombineBytesToWord(lo, hi);
  end;
end;

function CombineBytesToWord(lowByte, highByte: Byte): Word;
begin
  CombineBytesToWord := highByte * 256 + lowByte;
end;

{ 6-bit GB char -> ASCII: 0..31 map to '@'..'_', higher codes are unchanged }
function DecodeGameCharacter(c: Byte): Char;
begin
  if c > 31 then
    DecodeGameCharacter := Chr(c)
  else
    DecodeGameCharacter := Chr(c + 64);
end;

{ GBVM zone of address: 0 = $4900..$4CFF, 1 = $6B00..$6EFF, 2 = $9700..$98FF, 3 = C_Gbvm.SCRIPT_FIRST..SCRIPT_LAST
  (script), else 4 (special registers) }
function GbvmZone(address: Word): Byte;
begin
  GbvmZone := 4;
  if (address >= C_Gbvm.ZONE0_FIRST) and (address <= C_Gbvm.ZONE0_LAST) then GbvmZone := 0;
  if (address >= C_Gbvm.ZONE1_FIRST) and (address <= C_Gbvm.ZONE1_LAST) then GbvmZone := 1;
  if (address >= C_Gbvm.ZONE2_FIRST) and (address <= C_Gbvm.ZONE2_LAST) then GbvmZone := 2;
  if (address >= C_Gbvm.SCRIPT_FIRST) and (address <= C_Gbvm.SCRIPT_LAST) then GbvmZone := 3;
end;

{ Return the creature's zero-based index in GDVars.creatureList (the list length if it is absent) }
function FindCurCharIdx(creature: Types.PCharRecord): Byte;
var
  idx: Byte;
  p: Types.PCharRecord;
  found: Boolean;
begin
  p := GDVars.creatureList;
  found := False;
  idx := 0;
  while (p <> nil) and (not found) do begin
    if p = creature then
      found := True
    else begin
      Inc(idx);
      p := p^.nextCharAddr;
    end;
  end;
  FindCurCharIdx := idx;
end;

{ Special read handling for GBVM zone 1: found is True when address has a handler, even one that leaves the result
  unassigned (CHAR_CONTROL_HI, or CHAR_LOYALTY with charisma outside 3..25). Most handlers read the current character }
function SpecialReadZ1(address: Word; var found: Boolean): Word;
var
  t: Byte;
begin
  found := True;
  case address of
    C_Gbvm.CHAR_CON: SpecialReadZ1 := GDVars.curChar^.conCur;
    C_Gbvm.CHAR_SAVE_PETRIFY: SpecialReadZ1 := GDVars.curChar^.saves[C_Save.PETRIFY];
    C_Gbvm.CHAR_LEVEL: SpecialReadZ1 := GDVars.curChar^.levelHighest;
    C_Gbvm.CHAR_THIEF_SKILLS..C_Gbvm.CHAR_THIEF_SKILLS_LAST: begin
      t := address - C_Gbvm.CHAR_THIEF_SKILLS + 1;
      SpecialReadZ1 := GDVars.curChar^.thiefSkills[t];
    end;
    C_Gbvm.CHAR_NPC: SpecialReadZ1 := GDVars.curChar^.npc;
    C_Gbvm.CHAR_COPPER: SpecialReadZ1 := GDVars.curChar^.coins[C_Money.COPPER];
    C_Gbvm.CHAR_SILVER: SpecialReadZ1 := GDVars.curChar^.coins[C_Money.SILVER];
    C_Gbvm.CHAR_ELECTRUM: SpecialReadZ1 := GDVars.curChar^.coins[C_Money.ELECTRUM];
    C_Gbvm.CHAR_GOLD: SpecialReadZ1 := GDVars.curChar^.coins[C_Money.GOLD];
    C_Gbvm.CHAR_PLATINUM: SpecialReadZ1 := GDVars.curChar^.coins[C_Money.PLATINUM];
    C_Gbvm.CHAR_ALIGNMENT: SpecialReadZ1 := ShortInt(GDVars.curChar^.alignment);
    C_Gbvm.CHAR_XP_AWARD: SpecialReadZ1 := GDVars.curChar^.xpAward;
    C_Gbvm.CHAR_XP_PER_HP: SpecialReadZ1 := GDVars.curChar^.xpBonusPerHp;
    C_Gbvm.CHAR_ENABLED:
      if GDVars.curChar^.enabled <> 0 then
        SpecialReadZ1 := 1
      else
        SpecialReadZ1 := $80;
    C_Gbvm.CHAR_CONTROL:
      if (GDVars.curChar^.hostile = 0) and (GDVars.curChar^.quickfight <> 0) then
        SpecialReadZ1 := $80
      else if GDVars.curChar^.hostile = 1 then
        SpecialReadZ1 := $81
      else
        SpecialReadZ1 := 0;
    { handled, but no value is returned }
    C_Gbvm.CHAR_CONTROL_HI: ;
    C_Gbvm.CHAR_MOVEMENT: SpecialReadZ1 := GDVars.curChar^.movementCur;
    C_Gbvm.CHAR_PARTY_INDEX: SpecialReadZ1 := EclVars.FindCurCharIdx(GDVars.curChar);
    C_Gbvm.CHAR_PARTY_INDEX2: SpecialReadZ1 := EclVars.FindCurCharIdx(GDVars.curChar);
    C_Gbvm.CHAR_LOYALTY:
      { no result for charisma outside 3..25 }
      if GDVars.curChar^.chaCur in [AbilAdj.SCORE_MIN..AbilAdj.SCORE_MAX] then
        SpecialReadZ1 := AbilAdj.ChaLoyaltyBase(GDVars.curChar^.chaCur);
    C_Gbvm.DISK_NUM: SpecialReadZ1 := GDVars.virtualDisk;
    C_Gbvm.PARTY_SIZE: SpecialReadZ1 := GDVars.zone1^[C_Gbvm.PARTY_SIZE];
  else
    found := False;
  end;
end;

{ Special write handling for GBVM zone 1 (always in addition to the zone word write). A write to the current character's
  coins recalculates its stats, so its encumbrance and movement follow. }
procedure SpecialWriteZ1(address, value: Word);
var
  t: Byte;
begin
  case address of
    C_Gbvm.CHAR_DUMP:
      if value = 0 then GDVars.dumpCr6B00 := True;
    { a raw window into the character record, starting at memorizedSpells[1] and running on past it }
    C_Gbvm.CHAR_MEMORIZED_FIRST..C_Gbvm.CHAR_MEMORIZED_LAST: begin
      t := address - C_Gbvm.CHAR_MEMORIZED_FIRST + 1;
      GDVars.curChar^.memorizedSpells[t] := value;
    end;
    C_Gbvm.CHAR_NPC: begin
      { values above C_Npc.ANIMATED_NPC ($B2) lose $32 (= C_Npc.ANIMATED_NPC and C_Npc.MORALE_MASK) }
      if value > C_Npc.ANIMATED_NPC then Dec(value, $32);
      GDVars.curChar^.npc := value;
    end;
    C_Gbvm.CHAR_COPPER: GDVars.curChar^.coins[C_Money.COPPER] := value;
    C_Gbvm.CHAR_SILVER: GDVars.curChar^.coins[C_Money.SILVER] := value;
    C_Gbvm.CHAR_ELECTRUM: GDVars.curChar^.coins[C_Money.ELECTRUM] := value;
    C_Gbvm.CHAR_GOLD: GDVars.curChar^.coins[C_Money.GOLD] := value;
    C_Gbvm.CHAR_PLATINUM: GDVars.curChar^.coins[C_Money.PLATINUM] := value;
    C_Gbvm.CHAR_XP_AWARD: GDVars.curChar^.xpAward := value;
    C_Gbvm.CHAR_XP_PER_HP: GDVars.curChar^.xpBonusPerHp := value;
    C_Gbvm.CHAR_ENABLED: begin
      if value >= $80 then begin
        GDVars.curChar^.enabled := 0;
        if value = $87 then GDVars.curChar^.status := C_Status.STONED;
      end;
      if value = 0 then GDVars.dumpCr6C00 := True;
    end;
    C_Gbvm.CHAR_CONTROL:
      case value of
        0: begin
          GDVars.curChar^.hostile := 0;
          GDVars.curChar^.quickfight := 0;
        end;
        $80: begin
          GDVars.curChar^.hostile := 0;
          GDVars.curChar^.quickfight := 1;
        end;
        $81: begin
          GDVars.curChar^.hostile := 1;
          GDVars.curChar^.quickfight := 1;
        end;
      end;
    { disks 1..8 only }
    C_Gbvm.DISK_NUM:
      if (value >= 1) and (value <= 8) then EclVars.diskHook(value);
    { $80 + id loads wall set id into slot 1, 2 or 3, the cells a word apart }
    C_Gbvm.WALLSET_LOAD1, C_Gbvm.WALLSET_LOAD2, C_Gbvm.WALLSET_LOAD3:
      if value > $80 then
        EclVars.wallSetHook(value and $7F, (address - C_Gbvm.WALLSET_LOAD1) div 2 + 1);
  end;
  { the coins, copper to platinum, every other cell }
  if (address >= C_Gbvm.CHAR_COPPER) and (address <= C_Gbvm.CHAR_PLATINUM) and Odd(address) then
    CharHlp.RecalcStats(GDVars.curChar);
end;

procedure WriteGbvm(address, value: Word);
var
  zone: Byte;
  ok: Boolean;
begin
  zone := EclVars.GbvmZone(address);
  case zone of
    0: begin
      GDVars.zone0^.words[address] := value;
      if (address = C_Gbvm.SKY_CEILING_COLOR) or (address = C_Gbvm.ALT_SKY_COLOR) then
        GDVars.redrawSky := True;
    end;
    1: begin
      GDVars.zone1^[address] := value;
      EclVars.SpecialWriteZ1(address, value);
    end;
    2:
      GDVars.zone2^[address] := value;
    3:
      GDVars.zone3^[address] := value;
    4:
      case address of
        { the script registers keep nothing written to them }
        C_Gbvm.READ_REG1, C_Gbvm.READ_REG2, C_Gbvm.READ_REG3, C_Gbvm.WRITE_REG1, C_Gbvm.WRITE_REG2: ;
        C_Gbvm.SOUND_EFFECT: GDVars.sndEffect := value;
        C_Gbvm.CELL_PARTY_X: begin
          GDVars.movedParty := True;
          GDVars.gMapX := value;
        end;
        C_Gbvm.CELL_PARTY_Y: begin
          GDVars.gMapY := value;
          GDVars.movedParty := True;
        end;
        { facing, mod-4 loop }
        C_Gbvm.CELL_FACING: begin
          repeat
            ok := True;
            case value of
              0: GDVars.gFacing := C_Dir.NORTH;
              1: GDVars.gFacing := C_Dir.EAST;
              2: GDVars.gFacing := C_Dir.SOUTH;
              3: GDVars.gFacing := C_Dir.WEST;
            else begin
              ok := False;
              Dec(value, 4);
            end;
            end;
          until ok = True;
          GDVars.movedParty := True;
        end;
        C_Gbvm.CELL_WALL_COLOR: begin
          GDVars.wallColorSel := value;
          GDVars.picRegionW := True;
        end;
        C_Gbvm.CELL_CEIL_FLOOR_COLOR: begin
          GDVars.ceilFloorColorSel := value;
          GDVars.picRegionW := True;
        end;
        { accepted, ignored }
        C_Gbvm.CELL_IGNORED: ;
      end;
  end;
end;

{ The party effects table scripts read at $4900..$497F: the party's effects in order (creatureList, then each creature's
  effect list), at most 64 of them. Entry k ($4900 + k) is the effect id and $4940 + k the owner's party index, counted
  from 0 as FindCurCharIdx counts; unused entries read 0. The 'THIEVES ONLY' well (ECL4.DAX block 2) scans it for
  Feather Fall when a climber falls }
function PartyEffectsTable(address: Word): Word;
var
  k: Word;
  e: Word;
  n: Byte;
  p: Types.PCharRecord;
  effect: Types.PEffectRec;
begin
  PartyEffectsTable := 0;
  k := (address - C_Gbvm.PARTY_EFFECTS) mod (C_Gbvm.PARTY_EFFECT_OWNERS - C_Gbvm.PARTY_EFFECTS);
  e := 0;
  n := 0;
  p := GDVars.creatureList;
  while p <> nil do begin
    effect := p^.effectsAddr;
    while effect <> nil do begin
      if e = k then
        if address < C_Gbvm.PARTY_EFFECT_OWNERS then
          PartyEffectsTable := effect^.id
        else
          PartyEffectsTable := n;
      Inc(e);
      effect := effect^.next;
    end;
    Inc(n);
    p := p^.nextCharAddr;
  end;
end;

{ Zone 0 reads of $4900..$497F come from the party's effects (PartyEffectsTable), the rest from storage. Zone 4 reads
  are the special cells C_Gbvm names: registers, the party's position and facing, and the view. Unhandled zone-4
  addresses leave the result unassigned }
function ReadGbvm(address: Word): Word;
var
  zone: Byte;
  found: Boolean;
begin
  zone := EclVars.GbvmZone(address);
  found := False;
  case zone of
    0:
      if address <= C_Gbvm.PARTY_EFFECTS_LAST then
        ReadGbvm := EclVars.PartyEffectsTable(address)
      else
        ReadGbvm := GDVars.zone0^.words[address];
    1: begin
      ReadGbvm := EclVars.SpecialReadZ1(address, found);
      if not found then
        ReadGbvm := GDVars.zone1^[address];
    end;
    2:
      ReadGbvm := GDVars.zone2^[address];
    3:
      ReadGbvm := GDVars.zone3^[address];
    4:
      case address of
        { the read registers always read 0 }
        C_Gbvm.READ_REG1, C_Gbvm.READ_REG2, C_Gbvm.READ_REG3: ReadGbvm := 0;
        C_Gbvm.FACING_RAW: ReadGbvm := GDVars.gFacing;
        { handled, but no value is returned }
        C_Gbvm.CELL_35F: ;
        { sign-extends (ShortInt) }
        C_Gbvm.CELL_PARTY_X: ReadGbvm := GDVars.gMapX;
        C_Gbvm.CELL_PARTY_Y: ReadGbvm := GDVars.gMapY;
        C_Gbvm.CELL_FACING: ReadGbvm := GDVars.gFacing div 2;
        C_Gbvm.CELL_WALL_AHEAD: ReadGbvm := GDVars.wallAhead;
        C_Gbvm.CELL_EVENT: ReadGbvm := GDVars.eventAtCell;
        { write only: the result is unassigned }
        C_Gbvm.CELL_WALL_COLOR: ;
      end;
  end;
end;

{ The last address of GBVM zone 0..3, which a string written or read there may reach (0 for zone 4). }
function ZoneLast(zone: Byte): Word;
begin
  case zone of
    0: ZoneLast := C_Gbvm.ZONE0_LAST;
    1: ZoneLast := C_Gbvm.ZONE1_LAST;
    2: ZoneLast := C_Gbvm.ZONE2_LAST;
    3: ZoneLast := C_Gbvm.SCRIPT_LAST;
  else
    ZoneLast := 0;
  end;
end;

{ Strings go to the GBVM as zero-terminated strings, one character per cell (word cells in zones 0..2, bytes in zone 3);
  GBVM $6B00 instead sets the current character's name (String[15], so capped at 15). Zone 4 writes nothing }
procedure WriteGbvmString(address: Word; s: String);
var
  zone: Byte;
  len: Byte;
  i: Byte;
  last: Word;
begin
  zone := EclVars.GbvmZone(address);
  len := Length(s);
  { the zone's last address, which the terminator may take }
  last := EclVars.ZoneLast(zone);
  if zone < 4 then
    if last - address < len then
      len := last - address;
  case zone of
    0: begin
      for i := 0 to len - 1 do
        GDVars.zone0^.words[address + i] := Ord(s[i + 1]);
      GDVars.zone0^.words[address + len] := 0;
    end;
    1:
      if address = C_Gbvm.CHAR_NAME then
        GDVars.curChar^.name := s
      else begin
        for i := 0 to len - 1 do
          GDVars.zone1^[address + i] := Ord(s[i + 1]);
        GDVars.zone1^[address + len] := 0;
      end;
    2: begin
      for i := 0 to len - 1 do
        GDVars.zone2^[address + i] := Ord(s[i + 1]);
      GDVars.zone2^[address + len] := 0;
    end;
    3: begin
      for i := 0 to len - 1 do
        GDVars.zone3^[address + i] := Ord(s[i + 1]);
      GDVars.zone3^[address + len] := 0;
    end;
  end;
end;

{ Decode len packed bytes after IP into gbStrings[strIdx] as 6-bit GB chars (4 chars per 3 bytes; phase 4 reuses the
  already-read byte; zero chars are dropped). len counts packed bytes, not decoded characters. IP ends on the last byte
  read }
procedure ConvGbString(len, strIdx: Byte);
var
  i: Byte;
  cur: Byte;
  prev: Byte;
  c6: Byte;
  phase: Byte;
  ch: Char;
begin
  GDVars.gbStrings^[strIdx] := '';
  i := 0;
  cur := 0;
  phase := 1;
  while i < len do begin
    if phase < 4 then begin
      Inc(GDVars.eclIp);
      prev := cur;
      cur := GDVars.zone3^[GDVars.eclIp];
      Inc(i);
    end;
    case phase of
      1:
        c6 := cur shr 2;
      2: begin
        c6 := prev shl 6 + cur shr 2;
        c6 := c6 shr 2;
      end;
      3: begin
        c6 := prev shl 4 + cur shr 4;
        c6 := c6 shr 2;
      end;
      4:
        c6 := cur and $3F;
    end;
    if phase < 4 then Inc(phase) else phase := 1;
    if c6 <> 0 then begin
      ch := EclVars.DecodeGameCharacter(c6);
      GDVars.gbStrings^[strIdx] := Concat(GDVars.gbStrings^[strIdx], ch);
    end;
  end;
  if phase = 4 then begin
    c6 := cur and $3F;
    if c6 <> 0 then begin
      ch := EclVars.DecodeGameCharacter(c6);
      GDVars.gbStrings^[strIdx] := Concat(GDVars.gbStrings^[strIdx], ch);
    end;
  end;
end;

{ Copy the zero-terminated GBVM string at address into gbStrings[strIdx], one character per cell (the low byte of word
  cells); $6B00 selects the current character's name, and zone 4 gives ''. The copy also stops at the zone's last
  address and at 255 characters, as WriteGbvmString bounds the write side; v1.3 used a Byte offset that wrapped, so an
  unterminated string hung the game. }
procedure DerefGbString(strIdx: Byte; address: Word);
var
  zone: Byte;
  last: Word;
  a: Word;
  c: Word;
begin
  zone := EclVars.GbvmZone(address);
  GDVars.gbStrings^[strIdx] := '';
  if (zone = 1) and (address = C_Gbvm.CHAR_NAME) then
    GDVars.gbStrings^[strIdx] := GDVars.curChar^.name
  else if zone < 4 then begin
    last := EclVars.ZoneLast(zone);
    a := address;
    repeat
      case zone of
        0: c := GDVars.zone0^.words[a];
        1: c := GDVars.zone1^[a];
        2: c := GDVars.zone2^[a];
        3: c := GDVars.zone3^[a];
      end;
      if c <> 0 then
        GDVars.gbStrings^[strIdx] := Concat(GDVars.gbStrings^[strIdx], Char(c));
      Inc(a);
    until (c = 0) or (a > last) or (Length(GDVars.gbStrings^[strIdx]) = 255);
  end;
end;

{ Step IP past the command at IP without running it, loading the opcode's operands as its handler does (VMENU, HMENU,
  ONGOTO and ONGOSUB read a count and then that many more); unlisted opcodes skip one byte }
procedure SkipEclCmd;
var
  count: Byte;
begin
  GDVars.curOpcode := GDVars.zone3^[GDVars.eclIp];
  { v1.3 skipped 2 operands for SETUP MONSTER and 1 for ADD NPC, which take 3 and 2, and only the opcode byte of the
    four commands with a count }
  case GDVars.curOpcode of
    C_Ecl.JUMP, C_Ecl.GOSUB, C_Ecl.LOAD_CHAR, C_Ecl.PICTURE, C_Ecl.PRINT, C_Ecl.PRINTCLEAR,
        C_Ecl.PARTY_STR, C_Ecl.NEWECL, C_Ecl.CALL,
    C_Ecl.FIND_ITEM, C_Ecl.CLOCK, C_Ecl.RUN_PROGRAM, C_Ecl.WHO, C_Ecl.PROTECTION:
      EclVars.LoadEclVars(1);
    C_Ecl.COMPARE, C_Ecl.RANDOM_NUMBER, C_Ecl.SAVE, C_Ecl.INPUT_NUM, C_Ecl.INPUT_STR,
        $1F, C_Ecl.PARTY_SURPR, C_Ecl.ADD_NPC:
      EclVars.LoadEclVars(2);
    C_Ecl.ADD..C_Ecl.MULTIPLY, C_Ecl.LOAD_MON, C_Ecl.LOADFILES, C_Ecl.ROB, C_Ecl.GETTABLE,
        C_Ecl.BIT_AND, C_Ecl.BIT_OR, C_Ecl.SAVE_TABLE,
    C_Ecl.LOADPIECES, C_Ecl.SPELL, C_Ecl.SETUP_MON:
      EclVars.LoadEclVars(3);
    { the count is the last operand before the list, as EclVMenu, EclHMenu and EclOnGoto read it }
    C_Ecl.VMENU: begin
      EclVars.LoadEclVars(3);
      count := EclVars.GetEclVar(3);
      Dec(GDVars.eclIp);
      EclVars.LoadEclVars(count);
    end;
    C_Ecl.HMENU, C_Ecl.ONGOTO, C_Ecl.ONGOSUB: begin
      EclVars.LoadEclVars(2);
      count := EclVars.GetEclVar(2);
      Dec(GDVars.eclIp);
      EclVars.LoadEclVars(count);
    end;
    C_Ecl.COMPARE_AND, C_Ecl.SURPRISE:
      EclVars.LoadEclVars(4);
    C_Ecl.DAMAGE:
      EclVars.LoadEclVars(5);
    C_Ecl.CHECK_PARTY, C_Ecl.PARLAY:
      EclVars.LoadEclVars(6);
    C_Ecl.TREASURE:
      EclVars.LoadEclVars(8);
    C_Ecl.ENCOUNTER:
      EclVars.LoadEclVars(14);
  else
    Inc(GDVars.eclIp);
  end;
end;

end.

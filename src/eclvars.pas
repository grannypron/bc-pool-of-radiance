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
  { Sound effect selected by a script write (EclVars.WriteGbvm) }
  sndEffect: Word;
  { ECL write moved party flag }
  movedParty: Boolean;
  { Redraw sky/ceiling in 3D view flag }
  redrawSky: Boolean;

{ Value of loaded ECL variable idx: type 0 gives its byte; 1 and 3 read the GBVM at its address word; 2 gives its word;
  $81 (string reference) gives its GBVM address; $80 (string value) gives 0, as its text is in gbStrings, and so does
  any other type. }
function GetEclVar(idx: ShortInt): Word;

{ Read count ECL variables at the ECL IP into varTypes/varLo/varHi, decoding string values and
  string references into gbStrings. Only the first 64 variables and 20 strings are kept (later strings overwrite the
  20th); the IP still steps past them all. }
procedure LoadEclVars(count: Byte);

{ Load the count variables that follow the ones just loaded, as VMENU, HMENU, ON GOTO and ON GOSUB load the list after
  their count: LoadEclVars leaves the IP one past the last variable, on the next opcode, so this steps back one first. }
procedure LoadEclList(count: Byte);

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

uses Types, Crt, C_NPC, C_SAVE, GameVars, C_ECL, C_STATUS, C_GBVM, C_DIR, C_MONEY, CharHlp, AbilAdj, GameIo;

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
    t := GameVars.zone3^[GameVars.eclIp + 1];
    lo := GameVars.zone3^[GameVars.eclIp + 2];
    GameVars.eclIp := GameVars.eclIp + 2;
    case t of
      1, 2, 3: begin
        Inc(GameVars.eclIp);
        hi := GameVars.zone3^[GameVars.eclIp];
      end;
      $80: begin
        if strIdx < Types.GB_STRING_LAST then Inc(strIdx);
        len := lo;
        if len > 0 then
          EclVars.ConvGbString(len, strIdx)
        else
          GameVars.gbStrings^[strIdx] := '';
      end;
      $81: begin
        if strIdx < Types.GB_STRING_LAST then Inc(strIdx);
        Inc(GameVars.eclIp);
        hi := GameVars.zone3^[GameVars.eclIp];
        v := EclVars.CombineBytesToWord(lo, hi);
        EclVars.DerefGbString(strIdx, v);
      end;
    end;
    { 64 = High(varTypes); the upper byte is kept only for the types that carry one }
    if i <= 64 then begin
      GameVars.varTypes[i] := t;
      GameVars.varLo[i] := lo;
      if (t in [1, 2, 3]) or (t = $81) then
        GameVars.varHi[i] := hi;
    end;
  end;
  Inc(GameVars.eclIp);
end;

procedure LoadEclList(count: Byte);
begin
  Dec(GameVars.eclIp);
  EclVars.LoadEclVars(count);
end;

function GetEclVar(idx: ShortInt): Word;
var
  lo: Byte;
  hi: Byte;
begin
  { a type with no value reads 0; v1.3 left the result unassigned (#952) }
  GetEclVar := 0;
  lo :=GameVars.varLo[idx];
  hi := GameVars.varHi[idx];
  case GameVars.varTypes[idx] of
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

{ GBVM zone of address: 0 = $4900..$4CFF, 1 = $6B00..$6EFF, 2 = $9700..$98FF, 3 = C_GBVM.SCRIPT_FIRST..SCRIPT_LAST
  (script), else 4 (special registers) }
function GbvmZone(address: Word): Byte;
begin
  GbvmZone := 4;
  if (address >= C_GBVM.ZONE0_FIRST) and (address <= C_GBVM.ZONE0_LAST) then GbvmZone := 0;
  if (address >= C_GBVM.ZONE1_FIRST) and (address <= C_GBVM.ZONE1_LAST) then GbvmZone := 1;
  if (address >= C_GBVM.ZONE2_FIRST) and (address <= C_GBVM.ZONE2_LAST) then GbvmZone := 2;
  if (address >= C_GBVM.SCRIPT_FIRST) and (address <= C_GBVM.SCRIPT_LAST) then GbvmZone := 3;
end;

{ Return the creature's zero-based index in GameVars.creatureList (the list length if it is absent) }
function FindCurCharIdx(creature: Types.PCharRecord): Byte;
var
  idx: Byte;
  p: Types.PCharRecord;
  found: Boolean;
begin
  p := GameVars.creatureList;
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

{ Special read handling for GBVM zone 1: found is True when address has a handler, even one with no value, which reads 0
  (CHAR_CONTROL_HI, or CHAR_LOYALTY with charisma outside 3..25; v1.3 left the result unassigned, #952). Most handlers
  read the current character }
function SpecialReadZ1(address: Word; var found: Boolean): Word;
var
  t: Byte;
begin
  found := True;
  SpecialReadZ1 := 0;
  case address of
    C_GBVM.CHAR_CON: SpecialReadZ1 := GameVars.curChar^.conCur;
    C_GBVM.CHAR_SAVE_PETRIFY: SpecialReadZ1 := GameVars.curChar^.saves[C_SAVE.PETRIFY];
    { the level of the class the character follows now: a dual-classed human's current class's (#838) }
    C_GBVM.CHAR_LEVEL: SpecialReadZ1 := CharHlp.CurrentClassLevel(GameVars.curChar);
    C_GBVM.CHAR_THIEF_SKILLS..C_GBVM.CHAR_THIEF_SKILLS_LAST: begin
      t := address - C_GBVM.CHAR_THIEF_SKILLS + 1;
      SpecialReadZ1 := GameVars.curChar^.thiefSkills[t];
    end;
    C_GBVM.CHAR_NPC: SpecialReadZ1 := GameVars.curChar^.npc;
    C_GBVM.CHAR_COPPER: SpecialReadZ1 := GameVars.curChar^.coins[C_MONEY.COPPER];
    C_GBVM.CHAR_SILVER: SpecialReadZ1 := GameVars.curChar^.coins[C_MONEY.SILVER];
    C_GBVM.CHAR_ELECTRUM: SpecialReadZ1 := GameVars.curChar^.coins[C_MONEY.ELECTRUM];
    C_GBVM.CHAR_GOLD: SpecialReadZ1 := GameVars.curChar^.coins[C_MONEY.GOLD];
    C_GBVM.CHAR_PLATINUM: SpecialReadZ1 := GameVars.curChar^.coins[C_MONEY.PLATINUM];
    C_GBVM.CHAR_ALIGNMENT: SpecialReadZ1 := ShortInt(GameVars.curChar^.alignment);
    C_GBVM.CHAR_XP_AWARD: SpecialReadZ1 := GameVars.curChar^.xpAward;
    C_GBVM.CHAR_XP_PER_HP: SpecialReadZ1 := GameVars.curChar^.xpBonusPerHp;
    C_GBVM.CHAR_ENABLED:
      if GameVars.curChar^.enabled <> 0 then
        SpecialReadZ1 := 1
      else
        SpecialReadZ1 := $80;
    C_GBVM.CHAR_CONTROL:
      if (GameVars.curChar^.hostile = 0) and (GameVars.curChar^.quickfight <> 0) then
        SpecialReadZ1 := $80
      else if GameVars.curChar^.hostile = 1 then
        SpecialReadZ1 := $81
      else
        SpecialReadZ1 := 0;
    { handled, but has no value }
    C_GBVM.CHAR_CONTROL_HI: ;
    C_GBVM.CHAR_MOVEMENT: SpecialReadZ1 := GameVars.curChar^.movementCur;
    C_GBVM.CHAR_PARTY_INDEX, C_GBVM.CHAR_PARTY_INDEX2: SpecialReadZ1 := EclVars.FindCurCharIdx(GameVars.curChar);
    C_GBVM.CHAR_LOYALTY:
      { no result for charisma outside 3..25 }
      if GameVars.curChar^.chaCur in [AbilAdj.SCORE_MIN..AbilAdj.SCORE_MAX] then
        SpecialReadZ1 := AbilAdj.ChaLoyaltyBase(GameVars.curChar^.chaCur);
    C_GBVM.DISK_NUM: SpecialReadZ1 := GameVars.diskIndex;
    C_GBVM.PARTY_SIZE: SpecialReadZ1 := GameVars.zone1^[C_GBVM.PARTY_SIZE];
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
    C_GBVM.CHAR_DUMP:
      if value = 0 then GameVars.dumpCr6B00 := True;
    { a raw window into the character record, starting at memorizedSpells[1] and running on past it }
    C_GBVM.CHAR_MEMORIZED_FIRST..C_GBVM.CHAR_MEMORIZED_LAST: begin
      t := address - C_GBVM.CHAR_MEMORIZED_FIRST + 1;
      GameVars.curChar^.memorizedSpells[t] := value;
    end;
    C_GBVM.CHAR_NPC: begin
      { values above C_NPC.ANIMATED_NPC ($B2) lose its morale bits ($32) }
      if value > C_NPC.ANIMATED_NPC then Dec(value, C_NPC.ANIMATED_NPC and C_NPC.MORALE_MASK);
      GameVars.curChar^.npc := value;
    end;
    C_GBVM.CHAR_COPPER: GameVars.curChar^.coins[C_MONEY.COPPER] := value;
    C_GBVM.CHAR_SILVER: GameVars.curChar^.coins[C_MONEY.SILVER] := value;
    C_GBVM.CHAR_ELECTRUM: GameVars.curChar^.coins[C_MONEY.ELECTRUM] := value;
    C_GBVM.CHAR_GOLD: GameVars.curChar^.coins[C_MONEY.GOLD] := value;
    C_GBVM.CHAR_PLATINUM: GameVars.curChar^.coins[C_MONEY.PLATINUM] := value;
    C_GBVM.CHAR_XP_AWARD: GameVars.curChar^.xpAward := value;
    C_GBVM.CHAR_XP_PER_HP: GameVars.curChar^.xpBonusPerHp := value;
    C_GBVM.CHAR_ENABLED: begin
      if value >= $80 then begin
        GameVars.curChar^.enabled := 0;
        if value = $87 then GameVars.curChar^.status := C_STATUS.STONED;
      end;
      if value = 0 then GameVars.dumpCr6C00 := True;
    end;
    C_GBVM.CHAR_CONTROL:
      case value of
        0: begin
          GameVars.curChar^.hostile := 0;
          GameVars.curChar^.quickfight := 0;
        end;
        $80: begin
          GameVars.curChar^.hostile := 0;
          GameVars.curChar^.quickfight := 1;
        end;
        $81: begin
          GameVars.curChar^.hostile := 1;
          GameVars.curChar^.quickfight := 1;
        end;
      end;
    { the game's disks only }
    C_GBVM.DISK_NUM:
      if (value >= 1) and (value <= Types.LAST_DISK) then EclVars.diskHook(value);
    { $80 + id loads wall set id into slot 1, 2 or 3, the cells a word apart }
    C_GBVM.WALLSET_LOAD1, C_GBVM.WALLSET_LOAD2, C_GBVM.WALLSET_LOAD3:
      if value > $80 then
        EclVars.wallSetHook(value and $7F, (address - C_GBVM.WALLSET_LOAD1) div 2 + 1);
  end;
  { the coins, copper to platinum, every other cell }
  if (address >= C_GBVM.CHAR_COPPER) and (address <= C_GBVM.CHAR_PLATINUM) and Odd(address) then
    CharHlp.RecalcStats(GameVars.curChar);
end;

{ The stored cell at address in GBVM zone 0..3, as it is kept: a word, or in zone 3 (the script) a byte; 0 for zone 4,
  which stores nothing. }
function GetCell(zone: Byte; address: Word): Word;
begin
  case zone of
    0: GetCell := GameVars.zone0^.words[address];
    1: GetCell := GameVars.zone1^[address];
    2: GetCell := GameVars.zone2^[address];
    3: GetCell := GameVars.zone3^[address];
  else
    GetCell := 0;
  end;
end;

{ Store value in the cell at address in GBVM zone 0..3 (its low byte in zone 3); zone 4 stores nothing. }
procedure PutCell(zone: Byte; address, value: Word);
begin
  case zone of
    0: GameVars.zone0^.words[address] := value;
    1: GameVars.zone1^[address] := value;
    2: GameVars.zone2^[address] := value;
    3: GameVars.zone3^[address] := Lo(value);
  end;
end;

procedure WriteGbvm(address, value: Word);
var
  zone: Byte;
begin
  zone := EclVars.GbvmZone(address);
  EclVars.PutCell(zone, address, value);
  case zone of
    0:
      if (address = C_GBVM.SKY_CEILING_COLOR) or (address = C_GBVM.ALT_SKY_COLOR) then
        redrawSky := True
      { the demo's script sets the game speed, which is its text delay, as the C64's did (#1109); other scripts' writes
        are kept and change nothing }
      else if (address = C_GBVM.GAME_SPEED) and GameVars.demoMode then
        GameVars.gameDelay := Lo(value);
    1:
      EclVars.SpecialWriteZ1(address, value);
    4:
      case address of
        { the script registers keep nothing written to them }
        C_GBVM.READ_REG1, C_GBVM.READ_REG2, C_GBVM.READ_REG3, C_GBVM.WRITE_REG1, C_GBVM.WRITE_REG2: ;
        C_GBVM.SOUND_EFFECT: sndEffect := value;
        C_GBVM.CELL_PARTY_X: begin
          movedParty := True;
          GameVars.gMapX := value;
        end;
        C_GBVM.CELL_PARTY_Y: begin
          GameVars.gMapY := value;
          movedParty := True;
        end;
        { facing 0..3, taken mod 4 }
        C_GBVM.CELL_FACING: begin
          case value mod 4 of
            0: GameVars.gFacing := C_DIR.NORTH;
            1: GameVars.gFacing := C_DIR.EAST;
            2: GameVars.gFacing := C_DIR.SOUTH;
            3: GameVars.gFacing := C_DIR.WEST;
          end;
          movedParty := True;
        end;
        C_GBVM.CELL_WALL_COLOR: begin
          GameVars.wallColorSel := value;
          GameVars.picRegionW := True;
        end;
        C_GBVM.CELL_CEIL_FLOOR_COLOR: begin
          GameVars.ceilFloorColorSel := value;
          GameVars.picRegionW := True;
        end;
        { accepted, ignored }
        C_GBVM.CELL_IGNORED: ;
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
  k := (address - C_GBVM.PARTY_EFFECTS) mod (C_GBVM.PARTY_EFFECT_OWNERS - C_GBVM.PARTY_EFFECTS);
  e := 0;
  n := 0;
  p := GameVars.creatureList;
  while p <> nil do begin
    effect := p^.effectsAddr;
    while effect <> nil do begin
      if e = k then
        if address < C_GBVM.PARTY_EFFECT_OWNERS then
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
  are the special cells C_GBVM names: registers, the party's position and facing, and the view. A zone-4 address with
  no value reads 0 (v1.3 left the result unassigned, #952) }
function ReadGbvm(address: Word): Word;
var
  zone: Byte;
  found: Boolean;
begin
  ReadGbvm := 0;
  zone := EclVars.GbvmZone(address);
  found := False;
  case zone of
    0:
      if address <= C_GBVM.PARTY_EFFECTS_LAST then
        ReadGbvm := EclVars.PartyEffectsTable(address)
      else
        ReadGbvm := EclVars.GetCell(zone, address);
    1: begin
      ReadGbvm := EclVars.SpecialReadZ1(address, found);
      if not found then
        ReadGbvm := EclVars.GetCell(zone, address);
    end;
    2, 3:
      ReadGbvm := EclVars.GetCell(zone, address);
    4:
      case address of
        { the read registers always read 0 }
        C_GBVM.READ_REG1, C_GBVM.READ_REG2, C_GBVM.READ_REG3: ReadGbvm := 0;
        C_GBVM.FACING_RAW: ReadGbvm := GameVars.gFacing;
        { handled, but has no value }
        C_GBVM.CELL_35F: ;
        { sign-extends (ShortInt) }
        C_GBVM.CELL_PARTY_X: ReadGbvm := GameVars.gMapX;
        C_GBVM.CELL_PARTY_Y: ReadGbvm := GameVars.gMapY;
        C_GBVM.CELL_FACING: ReadGbvm := GameVars.gFacing div 2;
        C_GBVM.CELL_WALL_AHEAD: ReadGbvm := GameVars.wallAhead;
        C_GBVM.CELL_EVENT: ReadGbvm := GameVars.eventAtCell;
        { 1 when a key ends the demo (#1109); the key is left for Demo.Run }
        C_GBVM.KEY_COUNT: ReadGbvm := Ord(GameIo.DemoEnding);
        { write only: no value }
        C_GBVM.CELL_WALL_COLOR: ;
      end;
  end;
end;

{ The last address of GBVM zone 0..3, which a string written or read there may reach (0 for zone 4). }
function ZoneLast(zone: Byte): Word;
begin
  case zone of
    0: ZoneLast := C_GBVM.ZONE0_LAST;
    1: ZoneLast := C_GBVM.ZONE1_LAST;
    2: ZoneLast := C_GBVM.ZONE2_LAST;
    3: ZoneLast := C_GBVM.SCRIPT_LAST;
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
  if (zone = 1) and (address = C_GBVM.CHAR_NAME) then
    GameVars.curChar^.name := s
  else if zone < 4 then begin
    if last - address < len then
      len := last - address;
    for i := 0 to len - 1 do
      EclVars.PutCell(zone, address + i, Ord(s[i + 1]));
    EclVars.PutCell(zone, address + len, 0);
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
  GameVars.gbStrings^[strIdx] := '';
  i := 0;
  cur := 0;
  phase := 1;
  while i < len do begin
    if phase < 4 then begin
      Inc(GameVars.eclIp);
      prev := cur;
      cur := GameVars.zone3^[GameVars.eclIp];
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
      GameVars.gbStrings^[strIdx] := Concat(GameVars.gbStrings^[strIdx], ch);
    end;
  end;
  if phase = 4 then begin
    c6 := cur and $3F;
    if c6 <> 0 then begin
      ch := EclVars.DecodeGameCharacter(c6);
      GameVars.gbStrings^[strIdx] := Concat(GameVars.gbStrings^[strIdx], ch);
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
  GameVars.gbStrings^[strIdx] := '';
  if (zone = 1) and (address = C_GBVM.CHAR_NAME) then
    GameVars.gbStrings^[strIdx] := GameVars.curChar^.name
  else if zone < 4 then begin
    last := EclVars.ZoneLast(zone);
    a := address;
    repeat
      c := EclVars.GetCell(zone, a);
      if c <> 0 then
        GameVars.gbStrings^[strIdx] := Concat(GameVars.gbStrings^[strIdx], Char(c));
      Inc(a);
    until (c = 0) or (a > last) or (Length(GameVars.gbStrings^[strIdx]) = 255);
  end;
end;

{ Step IP past the command at IP without running it, loading the opcode's operands as its handler does (VMENU, HMENU,
  ONGOTO and ONGOSUB read a count and then that many more); unlisted opcodes skip one byte }
procedure SkipEclCmd;
var
  count: Byte;
begin
  GameVars.curOpcode := GameVars.zone3^[GameVars.eclIp];
  { v1.3 skipped 2 operands for SETUP MONSTER and 1 for ADD NPC, which take 3 and 2, and only the opcode byte of the
    four commands with a count }
  case GameVars.curOpcode of
    C_ECL.OP_GOTO, C_ECL.GOSUB, C_ECL.LOAD_CHARACTER, C_ECL.PICTURE, C_ECL.PRINT, C_ECL.PRINT_CLEAR,
        C_ECL.PARTY_STRENGTH, C_ECL.NEW_ECL, C_ECL.CALL,
    C_ECL.FIND_ITEM, C_ECL.CLOCK, C_ECL.OP_PROGRAM, C_ECL.WHO, C_ECL.PROTECTION, C_ECL.USE_UP_ITEM:
      EclVars.LoadEclVars(1);
    C_ECL.COMPARE, C_ECL.OP_RANDOM, C_ECL.SAVE, C_ECL.INPUT_NUMBER, C_ECL.INPUT_STRING,
        C_ECL.UNUSED_1F, C_ECL.PARTY_SURPRISE, C_ECL.ADD_NPC:
      EclVars.LoadEclVars(2);
    C_ECL.ADD..C_ECL.MULTIPLY, C_ECL.LOAD_MONSTER, C_ECL.LOAD_FILES, C_ECL.ROB, C_ECL.GET_TABLE,
        C_ECL.OP_AND, C_ECL.OP_OR, C_ECL.SAVE_TABLE,
    C_ECL.LOAD_PIECES, C_ECL.SPELL, C_ECL.SETUP_MONSTER:
      EclVars.LoadEclVars(3);
    { the count is the last operand before the list, as EclVMenu, EclHMenu and EclOnGoto read it }
    C_ECL.VERTICAL_MENU: begin
      EclVars.LoadEclVars(3);
      count := EclVars.GetEclVar(3);
      EclVars.LoadEclList(count);
    end;
    C_ECL.HORIZONTAL_MENU, C_ECL.ON_GOTO, C_ECL.ON_GOSUB: begin
      EclVars.LoadEclVars(2);
      count := EclVars.GetEclVar(2);
      EclVars.LoadEclList(count);
    end;
    C_ECL.COMPARE_AND, C_ECL.SURPRISE:
      EclVars.LoadEclVars(4);
    C_ECL.DAMAGE:
      EclVars.LoadEclVars(5);
    C_ECL.CHECK_PARTY, C_ECL.PARLAY:
      EclVars.LoadEclVars(6);
    C_ECL.TREASURE:
      EclVars.LoadEclVars(8);
    C_ECL.ENCOUNTER_MENU:
      EclVars.LoadEclVars(14);
  else
    Inc(GameVars.eclIp);
  end;
end;

begin
  { Turbo Pascal clears no variable }
  sndEffect := 0;
  movedParty := False;
  redrawSky := False;
end.

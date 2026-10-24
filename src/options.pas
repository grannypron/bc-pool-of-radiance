{ The Settings screen and POOLOPT.CFG. The game's settings (speed, portraits, music and sound with the kinds of each
  that can be turned off on their own, Quick ending with the fight, quick-mode magic, the Companion Tools and their Clue
  Book notes) are global: POOLOPT.CFG in the save folder keeps them as KEY=VALUE lines, with the provisional data and
  save paths of the later Gold Box games, which only the configuration program will set. GameInit reads it at start-up,
  before the title music, and every change writes it back; a saved game no longer changes them. The screen has three
  pages (#835): the settings, the games' paths, and the system's details (video, sound device, build, data archives and
  memory). The combat log and its size (#841) are settings too, which only a combat log with a store (CbtLog.Usable)
  can change. }
{$O+,F+,I-}
{$I COMPILER.INC}
unit Options;

interface

{ Read POOLOPT.CFG from the save folder over the defaults GameInit has set, then apply the Sound setting. A missing or
  unreadable file, an unknown key or a value out of range leaves the default. }
procedure LoadOptions;

{ Write the settings to POOLOPT.CFG, keeping the lines whose keys this version does not know. The new file is written
  beside it as POOLOPT.CF$ (FileUtil.TempName) and put in its place, so a failed write leaves the old file, and the
  settings then hold for this session only. }
procedure SaveOptions;

{ Show the Settings screen until Exit or Escape. Game, Paths and System on the bottom line show its pages. On the Game
  page Up and Down (also Home and End) move the highlight through the settings, wrapping at either end, past the Quick
  Mode heading; Enter, Left or Right turn the highlighted one over, at once. On the Game Speed and Log Lines lines Left
  and Right pick Slower or Faster (Less or More) instead, and Enter applies the one picked. Without a store for the
  combat log (CbtLog.Usable) its two lines are grey, Combat Log says it needs EMS, and the highlight passes them by. The
  Paths and System pages only show. Leaving writes POOLOPT.CFG when something changed. The caller redraws its own screen
  afterwards. }
procedure OptionsMenu;

implementation

uses {$IFDEF FPC}TpCompat, {$ENDIF}Crt, Types, C_KEYS, C_SOUND, C_DATA, GameVars, TextRend, Border, MenuCore, GameIo,
  SoundDrv, DaxIo, DataArc, GameDefs, VidOps, FileUtil, CbtLog{$IFDEF FPC}, NatFile{$ENDIF};

{ BUILD_VERSION and BUILD_COMMIT: build.sh writes them from git before each build. }
{$I BUILDID.INC}

const
  CFG_NAME = 'POOLOPT.CFG';
  { the most lines read from POOLOPT.CFG; anything after them is ignored, and dropped when the file is written }
  MAX_LINES = 100;
  { The settings, in the Game page's order; the sub-settings follow the setting they come under. }
  OPT_SPEED = 1;
  OPT_PORTRAITS_ALL = 2;
  OPT_MONSTERS = 3;
  OPT_PORTRAITS = 4;
  OPT_MUSIC = 5;
  OPT_TITLE_MUSIC = 6;
  OPT_BATTLE_MUSIC = 7;
  OPT_SOUND = 8;
  OPT_FOOTSTEPS = 9;
  OPT_RANGED = 10;
  OPT_MELEE = 11;
  OPT_DEATH = 12;
  OPT_WALL = 13;
  OPT_SPELLS = 14;
  { the first setting under the Quick Mode heading }
  OPT_QUICK = 15;
  OPT_MAGIC = 16;
  OPT_COMPANION = 17;
  OPT_CLUES = 18;
  { the combat log (#841), and how many messages it keeps }
  OPT_COMBAT_LOG = 19;
  OPT_LOG_LINES = 20;
  OPT_COUNT = 20;
  { POOLOPT.CFG's keys past the settings: the later games' data and save paths, by laterPaths index }
  KEY_PATHS = OPT_COUNT;
  LATER_PATHS = 6;
  KEY_COUNT = KEY_PATHS + LATER_PATHS;
  { the slowest game speed; 0 is the fastest }
  SLOWEST = 9;
  { Log Lines' step, between CbtLog.MIN_ENTRIES and MAX_ENTRIES }
  LOG_STEP = 5;
  { The two choices of a line that steps a number (speed, log lines), by stepChoice: Slower or Less on the left, Faster
    or More on the right. }
  CHOICE_LEFT = 0;
  CHOICE_RIGHT = 1;
  { The pages, in the bottom line's order. }
  PAGE_GAME = 1;
  PAGE_PATHS = 2;
  PAGE_SYSTEM = 3;
  { One framed box from TOP_ROW to BOTTOM_ROW: the page's title on TOP_ROW, then its lines from FIRST_ROW, the row
    below (the Game page's settings fill the box to BOTTOM_ROW). The Game page's settings have their labels at
    LABEL_COL and their values at SETTING_COL, with the Quick Mode heading on its own row; the other pages' values start
    at VALUE_COL. }
  LEFT_COL = 1;
  RIGHT_COL = 38;
  TOP_ROW = 1;
  BOTTOM_ROW = 22;
  FIRST_ROW = TOP_ROW + 1;
  LABEL_COL = 2;
  SETTING_COL = 24;
  VALUE_COL = 20;
  { the colours: titles and the Paths page's game names, and the lines; the Game page's highlight is TITLE_COLOR too,
    and a setting that cannot be changed here is OFF_COLOR }
  TITLE_COLOR = White;
  LINE_COLOR = LightGreen;
  OFF_COLOR = DarkGray;

var
  { a stepping line's choice, CHOICE_LEFT or CHOICE_RIGHT, while the screen is up }
  stepChoice: Byte;
  { the later games' paths POOLOPT.CFG holds: Curse's data and save paths, then Secret's, then Pools' }
  laterPaths: array[1..LATER_PATHS] of Types.TPathStr;

{ The key of setting or path key in POOLOPT.CFG. }
function KeyName(key: Byte): Types.TStr20;
begin
  case key of
    OPT_SPEED: KeyName := 'SPEED';
    OPT_PORTRAITS_ALL: KeyName := 'ALLPORTRAITS';
    OPT_MONSTERS: KeyName := 'MONSTERS';
    OPT_PORTRAITS: KeyName := 'PORTRAITS';
    OPT_MUSIC: KeyName := 'MUSIC';
    OPT_TITLE_MUSIC: KeyName := 'TITLEMUSIC';
    OPT_BATTLE_MUSIC: KeyName := 'BATTLEMUSIC';
    OPT_SOUND: KeyName := 'SOUND';
    OPT_FOOTSTEPS: KeyName := 'FOOTSTEPS';
    OPT_RANGED: KeyName := 'RANGEDSOUND';
    OPT_MELEE: KeyName := 'MELEESOUND';
    OPT_DEATH: KeyName := 'DEATHSCREAM';
    OPT_WALL: KeyName := 'WALLHIT';
    OPT_SPELLS: KeyName := 'SPELLSOUND';
    OPT_QUICK: KeyName := 'AUTOENDQUICK';
    OPT_MAGIC: KeyName := 'QUICKMAGIC';
    OPT_COMPANION: KeyName := 'COMPANION';
    OPT_CLUES: KeyName := 'CLUENOTES';
    OPT_COMBAT_LOG: KeyName := 'COMBATLOG';
    OPT_LOG_LINES: KeyName := 'LOGLINES';
    KEY_PATHS + 1: KeyName := 'CURSEDATA';
    KEY_PATHS + 2: KeyName := 'CURSESAVE';
    KEY_PATHS + 3: KeyName := 'SECRETDATA';
    KEY_PATHS + 4: KeyName := 'SECRETSAVE';
    KEY_PATHS + 5: KeyName := 'POOLSDATA';
    KEY_PATHS + 6: KeyName := 'POOLSSAVE';
  else
    KeyName := '';
  end;
end;

{ The label of setting opt on the Game page, a sub-setting's indented under its setting. }
function SettingLabel(opt: Byte): Types.TStr40;
var
  n: Types.TStr20;
begin
  case opt of
    OPT_SPEED: SettingLabel := 'Game Speed (' + Chr(Ord('0') + GameVars.gameDelay mod (SLOWEST + 1)) + ')';
    OPT_PORTRAITS_ALL: SettingLabel := 'Portraits';
    OPT_MONSTERS: SettingLabel := '  Monster Portraits';
    OPT_PORTRAITS: SettingLabel := '  Character Portraits';
    OPT_MUSIC: SettingLabel := 'Music';
    OPT_TITLE_MUSIC: SettingLabel := '  Title Music';
    OPT_BATTLE_MUSIC: SettingLabel := '  Battle Music';
    OPT_SOUND: SettingLabel := 'Sound';
    OPT_FOOTSTEPS: SettingLabel := '  Footsteps';
    OPT_RANGED: SettingLabel := '  Ranged Weapon Usage';
    OPT_MELEE: SettingLabel := '  Melee Attacks';
    OPT_DEATH: SettingLabel := '  Death Scream';
    OPT_WALL: SettingLabel := '  Wall Hit';
    OPT_SPELLS: SettingLabel := '  Spell Effects';
    OPT_QUICK: SettingLabel := '  Auto End Quick Mode';
    OPT_MAGIC: SettingLabel := '  Use Magic';
    OPT_COMPANION: SettingLabel := 'Companion Tools';
    OPT_CLUES: SettingLabel := '  Clue Book Notes';
    OPT_COMBAT_LOG: SettingLabel := 'Combat Log';
    OPT_LOG_LINES: begin
                     Str(GameVars.combatLogLines, n);
                     SettingLabel := '  Log Lines (' + n + ')';
                   end;
  else
    SettingLabel := '';
  end;
end;

{ The Game page row of setting opt: one a row from FIRST_ROW, the Quick Mode heading's row before OPT_QUICK. }
function SettingRow(opt: Byte): Byte;
begin
  SettingRow := FIRST_ROW + opt - 1 + Ord(opt >= OPT_QUICK);
end;

{ ON for a nonzero flag, OFF for zero. }
function OnOff(flag: Byte): Types.TStr20;
begin
  if flag <> 0 then
    OnOff := 'ON'
  else
    OnOff := 'OFF';
end;

{ The GameVars.soundGroups bit of a sound setting, or musicGroups bit of a music setting; 0 for any other setting. }
function GroupBit(opt: Byte): Byte;
begin
  case opt of
    OPT_TITLE_MUSIC: GroupBit := C_SOUND.GROUP_TITLE_MUSIC;
    OPT_BATTLE_MUSIC: GroupBit := C_SOUND.GROUP_BATTLE_MUSIC;
    OPT_FOOTSTEPS: GroupBit := C_SOUND.GROUP_FOOTSTEPS;
    OPT_RANGED: GroupBit := C_SOUND.GROUP_RANGED;
    OPT_MELEE: GroupBit := C_SOUND.GROUP_MELEE;
    OPT_DEATH: GroupBit := C_SOUND.GROUP_DEATH;
    OPT_WALL: GroupBit := C_SOUND.GROUP_WALL;
    OPT_SPELLS: GroupBit := C_SOUND.GROUP_SPELL;
  else
    GroupBit := 0;
  end;
end;

{ Setting opt (not the speed or log lines) as 1 for on and 0 for off. }
function Flag(opt: Byte): Byte;
begin
  case opt of
    OPT_PORTRAITS_ALL: Flag := GameVars.portraitsAll;
    OPT_MONSTERS: Flag := GameVars.monsterPics;
    OPT_PORTRAITS: Flag := GameVars.portraitsOn;
    OPT_MUSIC: Flag := GameVars.musicOn;
    OPT_TITLE_MUSIC, OPT_BATTLE_MUSIC: Flag := Ord(GameVars.musicGroups and Options.GroupBit(opt) <> 0);
    OPT_SOUND: Flag := GameVars.soundOn;
    OPT_FOOTSTEPS..OPT_SPELLS: Flag := Ord(GameVars.soundGroups and Options.GroupBit(opt) <> 0);
    OPT_QUICK: Flag := GameVars.quickEnds;
    OPT_MAGIC: Flag := GameVars.quickMagicOn;
    OPT_COMPANION: Flag := GameVars.companionOn;
    OPT_CLUES: Flag := GameVars.clueNotesOn;
    OPT_COMBAT_LOG: Flag := GameVars.combatLogOn;
  else
    Flag := 0;
  end;
end;

{ Set setting opt (not the speed or log lines) on for a nonzero value, else off. }
procedure SetFlag(opt, value: Byte);
var
  isOn: Byte;
begin
  isOn := Ord(value <> 0);
  case opt of
    OPT_PORTRAITS_ALL: GameVars.portraitsAll := isOn;
    OPT_MONSTERS: GameVars.monsterPics := isOn;
    OPT_PORTRAITS: GameVars.portraitsOn := isOn;
    OPT_MUSIC: GameVars.musicOn := isOn;
    OPT_TITLE_MUSIC, OPT_BATTLE_MUSIC:
      if isOn <> 0 then
        GameVars.musicGroups := GameVars.musicGroups or Options.GroupBit(opt)
      else
        GameVars.musicGroups := GameVars.musicGroups and not Options.GroupBit(opt);
    OPT_SOUND: GameVars.soundOn := isOn;
    OPT_FOOTSTEPS..OPT_SPELLS:
      if isOn <> 0 then
        GameVars.soundGroups := GameVars.soundGroups or Options.GroupBit(opt)
      else
        GameVars.soundGroups := GameVars.soundGroups and not Options.GroupBit(opt);
    OPT_QUICK: GameVars.quickEnds := isOn;
    OPT_MAGIC: GameVars.quickMagicOn := isOn;
    OPT_COMPANION: GameVars.companionOn := isOn;
    OPT_CLUES: GameVars.clueNotesOn := isOn;
    OPT_COMBAT_LOG: GameVars.combatLogOn := isOn;
  end;
end;

{ The value of setting or path key as POOLOPT.CFG keeps it. Sound is the setting, which stays as it was when POOL.CFG
  names no sound device. }
function StoredValue(key: Byte): Types.TPathStr;
var
  n: Types.TStr20;
begin
  if key = OPT_SPEED then
    StoredValue := Chr(Ord('0') + GameVars.gameDelay mod (SLOWEST + 1))
  else if key = OPT_LOG_LINES then begin
    Str(GameVars.combatLogLines, n);
    StoredValue := n;
  end else if key > KEY_PATHS then
    StoredValue := laterPaths[key - KEY_PATHS]
  else
    StoredValue := Options.OnOff(Options.Flag(key));
end;

{ The value of setting opt as the screen shows it: Sound shows whether sound is on now, and Combat Log that it needs
  EMS when it has no store. }
function ShownValue(opt: Byte): Types.TStr20;
begin
  if opt = OPT_SOUND then
    ShownValue := Options.OnOff(Ord(GameVars.soundMode <> C_SOUND.MODE_DISABLED))
  else if (opt = OPT_COMBAT_LOG) and not CbtLog.Usable then
    ShownValue := 'Needs EMS'
  else
    ShownValue := Options.StoredValue(opt);
end;

{ s without the spaces and tabs at either end, upper-cased. }
function Tidy(s: string): string;
var
  i: Byte;
begin
  while (Length(s) > 0) and (s[1] in [' ', #9]) do
    Delete(s, 1, 1);
  while (Length(s) > 0) and (s[Length(s)] in [' ', #9]) do
    Dec(s[0]);
  for i := 1 to Length(s) do
    s[i] := UpCase(s[i]);
  Tidy := s;
end;

{ The setting or path key whose key line names before its '=', or 0 for none. }
function KeyOf(line: string): Byte;
var
  eq: Byte;
  key: string;
  k: Byte;
begin
  KeyOf := 0;
  eq := Pos('=', line);
  if eq = 0 then Exit;
  key := Options.Tidy(Copy(line, 1, eq - 1));
  for k := 1 to KEY_COUNT do
    if key = Options.KeyName(k) then
      KeyOf := k;
end;

{ Set setting or path key from value (tidied): a digit 0..9 for the speed, a number from CbtLog.MIN_ENTRIES to
  MAX_ENTRIES for the log lines, a path as it is, ON or OFF (or 1 or 0) for the others. Any other value leaves the
  setting as it is. }
procedure ReadValue(key: Byte; value: string);
var
  n: Integer;
  code: Integer;
begin
  if key = OPT_SPEED then begin
    if (Length(value) = 1) and (value[1] in ['0'..'9']) then
      GameVars.gameDelay := Ord(value[1]) - Ord('0');
  end else if key = OPT_LOG_LINES then begin
    Val(value, n, code);
    if (code = 0) and (n >= CbtLog.MIN_ENTRIES) and (n <= CbtLog.MAX_ENTRIES) then
      GameVars.combatLogLines := n;
  end else if key > KEY_PATHS then begin
    if value <> '' then
      laterPaths[key - KEY_PATHS] := value;
  end else if (value = 'ON') or (value = '1') then
    Options.SetFlag(key, 1)
  else if (value = 'OFF') or (value = '0') then
    Options.SetFlag(key, 0);
end;

procedure LoadOptions;
var
  f: Text;
  line: string;
  opt: Byte;
  lines: Integer;
  done: Boolean;
  n: Integer;
begin
  laterPaths[1] := 'C:\CURSE\';
  laterPaths[2] := 'C:\CURSE\SAVE\';
  laterPaths[3] := 'C:\SECRET\';
  laterPaths[4] := 'C:\SECRET\SAVE\';
  laterPaths[5] := 'C:\POOLS\';
  laterPaths[6] := 'C:\POOLS\SAVE\';
  Assign(f, GameVars.saveDirectory + CFG_NAME);
  Reset(f);
  if IOResult = 0 then begin
    lines := 0;
    done := False;
    repeat
      if Eof(f) then
        done := True
      else begin
        ReadLn(f, line);
        Inc(lines);
        opt := Options.KeyOf(line);
        if opt <> 0 then
          Options.ReadValue(opt, Options.Tidy(Copy(line, Pos('=', line) + 1, 255)));
      end;
      if (IOResult <> 0) or (lines >= MAX_LINES) then
        done := True;
    until done;
    Close(f);
    n := IOResult;
  end;
  GameIo.SetSound(GameVars.soundOn <> 0);
  GameIo.saveSettings := Options.SaveOptions;
end;

procedure SaveOptions;
var
  newFile: Text;
  oldFile: Text;
  line: string;
  opt: Byte;
  lines: Integer;
  done: Boolean;
  ok: Boolean;
  n: Integer;
begin
  Assign(newFile, FileUtil.TempName(GameVars.saveDirectory + CFG_NAME));
  Rewrite(newFile);
  if IOResult <> 0 then Exit;
  for opt := 1 to KEY_COUNT do
    WriteLn(newFile, Options.KeyName(opt), '=', Options.StoredValue(opt));
  ok := IOResult = 0;
  Assign(oldFile, GameVars.saveDirectory + CFG_NAME);
  if ok then begin
    Reset(oldFile);
    if IOResult = 0 then begin
      lines := 0;
      done := False;
      repeat
        if Eof(oldFile) then
          done := True
        else begin
          ReadLn(oldFile, line);
          Inc(lines);
          if (Options.KeyOf(line) = 0) and (Options.Tidy(line) <> '') then
            WriteLn(newFile, line);
        end;
        if IOResult <> 0 then begin
          ok := False;
          done := True;
        end;
        if lines >= MAX_LINES then
          done := True;
      until done;
      Close(oldFile);
      n := IOResult;
    end;
  end;
  Close(newFile);
  if IOResult <> 0 then
    ok := False;
  if ok then
    ok := FileUtil.PutInPlace(GameVars.saveDirectory + CFG_NAME)
  else
    FileUtil.DeleteFile(FileUtil.TempName(GameVars.saveDirectory + CFG_NAME));
end;

{ value with a comma between each group of three digits. }
function Grouped(value: LongInt): Types.TStr20;
var
  s: Types.TStr20;
  i: Integer;
begin
  Str(value, s);
  i := Length(s) - 3;
  while i > 0 do begin
    Insert(',', s, i + 1);
    Dec(i, 3);
  end;
  Grouped := s;
end;

{ True for a setting the Game page can change: the combat log's two only when it has a store. }
function Changeable(opt: Byte): Boolean;
begin
  Changeable := not (opt in [OPT_COMBAT_LOG, OPT_LOG_LINES]) or CbtLog.Usable;
end;

{ The setting after opt that can be changed, or before it when down is clear, wrapping at either end. }
function NextSetting(opt: Byte; down: Boolean): Byte;
begin
  repeat
    if down then
      opt := opt mod OPT_COUNT + 1
    else if opt > 1 then
      Dec(opt)
    else
      opt := OPT_COUNT;
  until Options.Changeable(opt);
  NextSetting := opt;
end;

{ True when setting opt steps a number with two choices, the left lowering it and the right raising it, and if so
  their names. }
function StepNames(opt: Byte; var left, right: Types.TStr20): Boolean;
begin
  StepNames := True;
  case opt of
    OPT_SPEED: begin
                 left := 'Slower';
                 right := 'Faster';
               end;
    OPT_LOG_LINES: begin
                     left := 'Less';
                     right := 'More';
                   end;
  else
    StepNames := False;
  end;
end;

{ Draw setting opt on its row, its label and value in color, or in OFF_COLOR when the page cannot change it. A stepping
  line's value is its two choices; while it is highlighted (color TITLE_COLOR) the choice not picked stays LINE_COLOR. }
procedure DrawSetting(opt: Byte; color: Byte);
var
  row: Byte;
  leftColor: Byte;
  rightColor: Byte;
  left: Types.TStr20;
  right: Types.TStr20;
begin
  if (opt < 1) or (opt > OPT_COUNT) then Exit;
  if not Options.Changeable(opt) then
    color := OFF_COLOR;
  row := Options.SettingRow(opt);
  TextRend.PrintSpaces(LABEL_COL, row, Black, RIGHT_COL - LABEL_COL + 1);
  TextRend.DisplayString(LABEL_COL, row, color, Options.SettingLabel(opt));
  if Options.StepNames(opt, left, right) then begin
    leftColor := color;
    rightColor := color;
    if color = TITLE_COLOR then
      if stepChoice = CHOICE_RIGHT then
        leftColor := LINE_COLOR
      else
        rightColor := LINE_COLOR;
    TextRend.DisplayString(SETTING_COL, row, leftColor, left);
    TextRend.DisplayString(SETTING_COL + Length(left) + 1, row, rightColor, right);
  end else
    TextRend.DisplayString(SETTING_COL, row, color, Options.ShownValue(opt));
end;

{ Draw a display-only line on row: its label, and value cut to the space from VALUE_COL; a value too long keeps its
  end, after '...', as a path's last folders say the most. The game font has no backslash (that character is a solid
  block), so a path shows '/' in its place. }
procedure DrawInfo(row: Byte; lab, value: string);
const
  WIDTH = RIGHT_COL - VALUE_COL + 1;
var
  i: Byte;
begin
  for i := 1 to Length(value) do
    if value[i] = '\' then
      value[i] := '/';
  if Length(value) > WIDTH then
    value := '...' + Copy(value, Length(value) - (WIDTH - 3) + 1, WIDTH - 3);
  TextRend.DisplayString(LABEL_COL, row, LINE_COLOR, Copy(lab, 1, VALUE_COL - LABEL_COL - 1));
  TextRend.DisplayString(VALUE_COL, row, LINE_COLOR, value);
end;

{ How many data families read their merged archive, and how many have files here at all. }
procedure CountMerged(var merged, present: Byte);
var
  fam: Byte;
  disk: Byte;
  found: Boolean;
begin
  merged := 0;
  present := 0;
  for fam := 1 to C_DATA.FAMILIES do
    if DaxIo.FamilyUsable(fam) then begin
      Inc(merged);
      Inc(present);
    end else begin
      found := False;
      for disk := 1 to 8 do
        if not found then
          found := DataArc.FileLength(GameVars.gameDir + DataArc.SourceName(fam, disk) + '.DAX') >= 0;
      if found then
        Inc(present);
    end;
end;

{ The Game page: every setting, setting sel highlighted, and the Quick Mode heading. }
procedure DrawGamePage(sel: Byte);
var
  opt: Byte;
begin
  for opt := 1 to OPT_COUNT do
    if opt = sel then
      Options.DrawSetting(opt, TITLE_COLOR)
    else
      Options.DrawSetting(opt, LINE_COLOR);
  TextRend.DisplayString(LABEL_COL, Options.SettingRow(OPT_QUICK) - 1, LINE_COLOR, 'Quick Mode');
end;

{ The Paths page: each game's name, then its data and save paths. Pool of Radiance's are the ones POOL.CFG gives this
  game; the later games' are POOLOPT.CFG's, set only by the configuration program. }
procedure DrawPathsPage;
const
  GAMES = 4;
  { a game's three rows and the blank row after them }
  GAME_ROWS = 4;
var
  g: Byte;
  row: Byte;
  name: Types.TStr40;
  dataPath: Types.TPathStr;
  savePath: Types.TPathStr;
begin
  for g := 1 to GAMES do begin
    case g of
      1: name := 'Pool of Radiance';
      2: name := 'Curse of the Azure Bonds';
      3: name := 'Secret of the Silver Blades';
    else
      name := 'Pools of Darkness';
    end;
    if g = 1 then begin
      dataPath := GameVars.gameDir;
      savePath := GameVars.saveDirectory;
    end else begin
      dataPath := laterPaths[2 * g - 3];
      savePath := laterPaths[2 * g - 2];
    end;
    row := FIRST_ROW + (g - 1) * GAME_ROWS;
    TextRend.DisplayString(LABEL_COL, row, TITLE_COLOR, name);
    Options.DrawInfo(row + 1, '  Data Path', dataPath);
    Options.DrawInfo(row + 2, '  Save Path', savePath);
  end;
end;

{ The System page: the video and sound device the game runs with, the build, the data archives and memory, and the
  STING and NORAND switches when they are given. }
procedure DrawSystemPage;
var
  merged: Byte;
  present: Byte;
  switches: Types.TStr20;
begin
  Options.DrawInfo(FIRST_ROW, 'Video', VidOps.ModeName);
  Options.DrawInfo(FIRST_ROW + 1, 'Sound Device', GameVars.sound.name);
  Options.DrawInfo(FIRST_ROW + 2, 'Version', GameDefs.GAME_VERSION);
  Options.DrawInfo(FIRST_ROW + 3, 'Commit', BUILD_COMMIT);
  Options.CountMerged(merged, present);
  Options.DrawInfo(FIRST_ROW + 5, 'Data', 'V' + Options.Grouped(C_DATA.VERSION));
  Options.DrawInfo(FIRST_ROW + 6, 'Merged Files', Options.Grouped(merged) + '/' + Options.Grouped(present));
  Options.DrawInfo(FIRST_ROW + 8, 'Free Memory', Options.Grouped(MemAvail));
  Options.DrawInfo(FIRST_ROW + 9, 'Largest Block', Options.Grouped(MaxAvail));
{$IFDEF FPC}
  { the native build has no overlays to keep in EMS }
  Options.DrawInfo(FIRST_ROW + 10, 'EMS Active', 'N/A');
{$ELSE}
  if GameVars.ovrInEms then
    Options.DrawInfo(FIRST_ROW + 10, 'EMS Active', 'Yes')
  else
    Options.DrawInfo(FIRST_ROW + 10, 'EMS Active', 'No');
{$ENDIF}
  switches := '';
  if GameVars.stingArg then
    switches := 'STING ';
  if ParamStr(2) = 'NORAND' then
    switches := switches + 'NORAND';
  if switches <> '' then
    Options.DrawInfo(FIRST_ROW + 12, 'Switches', switches);
end;

{ Clear the screen and draw page with its title in the frame, setting sel highlighted on the Game page. }
procedure DrawPage(page, sel: Byte);
begin
  Border.ClearBox(0, 0, 39, 23);
  Border.DrawBorder(LEFT_COL, TOP_ROW, RIGHT_COL, BOTTOM_ROW, 0);
  case page of
    PAGE_GAME: begin
                 TextRend.DisplayCentered(LEFT_COL, RIGHT_COL, TOP_ROW, TITLE_COLOR, 'Game Settings');
                 Options.DrawGamePage(sel);
               end;
    PAGE_PATHS: begin
                  TextRend.DisplayCentered(LEFT_COL, RIGHT_COL, TOP_ROW, TITLE_COLOR, 'Game Paths');
                  Options.DrawPathsPage;
                end;
    PAGE_SYSTEM: begin
                   TextRend.DisplayCentered(LEFT_COL, RIGHT_COL, TOP_ROW, TITLE_COLOR, 'System Info');
                   Options.DrawSystemPage;
                 end;
  end;
end;

{ Change setting opt, as Enter does. The speed takes the speed line's choice, a step within 0..SLOWEST: Slower raises
  gameDelay (the game's text and animation delays grow with it) and Faster lowers it. Log Lines takes its line's choice
  too, LOG_STEP less or more within CbtLog.MIN_ENTRIES..MAX_ENTRIES; the next fight's log has the new size. Every other
  setting turns over. A music setting turned off ends the tune it covers now; Sound goes through GameIo.SetSound, as
  Ctrl-S does. }
procedure ChangeSetting(opt: Byte);
begin
  case opt of
    OPT_SPEED: if stepChoice = CHOICE_LEFT then begin
                 if GameVars.gameDelay < SLOWEST then
                   Inc(GameVars.gameDelay);
               end else if GameVars.gameDelay > 0 then
                 Dec(GameVars.gameDelay);
    OPT_LOG_LINES: if stepChoice = CHOICE_LEFT then begin
                     if GameVars.combatLogLines >= CbtLog.MIN_ENTRIES + LOG_STEP then
                       Dec(GameVars.combatLogLines, LOG_STEP)
                     else
                       GameVars.combatLogLines := CbtLog.MIN_ENTRIES;
                   end else if GameVars.combatLogLines <= CbtLog.MAX_ENTRIES - LOG_STEP then
                     Inc(GameVars.combatLogLines, LOG_STEP)
                   else
                     GameVars.combatLogLines := CbtLog.MAX_ENTRIES;
    OPT_SOUND: GameIo.SetSound(GameVars.soundMode = C_SOUND.MODE_DISABLED);
  else begin
      Options.SetFlag(opt, Ord(Options.Flag(opt) = 0));
      if opt in [OPT_MUSIC, OPT_TITLE_MUSIC, OPT_BATTLE_MUSIC] then
        SoundDrv.ApplyMusicSettings;
    end;
  end;
end;

procedure OptionsMenu;
var
  sel: Byte;
  page: Byte;
  ch: Char;
  ext: Boolean;
  { changed: a setting has changed since the screen opened; touched: on this pass }
  changed: Boolean;
  touched: Boolean;
  savedChoice: Byte;
  soundState: Byte;

  { Move the highlight to setting n. }
  procedure MoveTo(n: Byte);
  begin
    Options.DrawSetting(sel, LINE_COLOR);
    sel := n;
    Options.DrawSetting(sel, TITLE_COLOR);
  end;

  { Turn setting sel over, or on a stepping line pick choice. }
  procedure Arrow(choice: Byte);
  var
    left: Types.TStr20;
    right: Types.TStr20;
  begin
    if Options.StepNames(sel, left, right) then begin
      stepChoice := choice;
      Options.DrawSetting(sel, TITLE_COLOR);
    end else begin
      Options.ChangeSetting(sel);
      touched := True;
    end;
  end;

  { Show page p. }
  procedure ShowPage(p: Byte);
  begin
    page := p;
    Options.DrawPage(page, sel);
  end;

begin
  savedChoice := GameVars.horizChoice;
  sel := 1;
  stepChoice := CHOICE_LEFT;
  changed := False;
  ShowPage(PAGE_GAME);
  repeat
    { Ctrl-S on the bottom line turns the sound over too }
    soundState := GameVars.soundMode;
    touched := False;
    { the bottom line shows the page's option current }
    GameVars.horizChoice := page;
    MenuCore.arrowsToCaller := True;
    MenuCore.enterToCaller := True;
    ch := MenuCore.MenuHorizontal('Settings: ', 'Game Paths System Exit', LightMagenta, LightGreen, White, True, False,
                                  ext);
    if ext then begin
      if page = PAGE_GAME then
        case ch of
          C_KEYS.UP, C_KEYS.HOME: MoveTo(Options.NextSetting(sel, False));
          C_KEYS.DOWN, C_KEYS.END_KEY: MoveTo(Options.NextSetting(sel, True));
          C_KEYS.LEFT: Arrow(CHOICE_LEFT);
          C_KEYS.RIGHT: Arrow(CHOICE_RIGHT);
        end;
    end else
      case ch of
        C_KEYS.ENTER: if page = PAGE_GAME then begin
                        Options.ChangeSetting(sel);
                        touched := True;
                      end;
        'G': if page <> PAGE_GAME then
               ShowPage(PAGE_GAME);
        'P': if page <> PAGE_PATHS then
               ShowPage(PAGE_PATHS);
        'S': if page <> PAGE_SYSTEM then
                    ShowPage(PAGE_SYSTEM);
      end;
    if touched then
      changed := True;
    if (page = PAGE_GAME) and (touched or (GameVars.soundMode <> soundState)) then begin
      if sel <> OPT_SOUND then
        Options.DrawSetting(OPT_SOUND, LINE_COLOR);
      Options.DrawSetting(sel, TITLE_COLOR);
    end;
  until not ext and (ch in [C_KEYS.NONE, 'E']);
  if changed then
    Options.SaveOptions;
  GameVars.horizChoice := savedChoice;
end;

end.

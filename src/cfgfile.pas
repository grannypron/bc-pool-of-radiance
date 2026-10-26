{ The configuration files (#876): POOL.CFG, which START reads first (the video, the sound device, the data and save
  paths, the introduction), and POOLOPT.CFG in the save folder, the Settings screen's settings as KEY=VALUE lines with
  the later games' paths. The game (GameBoot, Options) and the set-up program POOLCFG read and write them only through
  this unit, so the two cannot read a file differently. Nothing here knows the game's state or screen: the settings are
  a TSettings record, which Options copies to and from GameVars. Depends on nothing of the game's but FileUtil, so the
  tests and POOLCFG link it alone; overlaid in the game. I/O errors are caught, never raised. }
{$O+,F+,I-}
{$I COMPILER.INC}
unit CfgFile;

interface

uses C_OPT, FileUtil;

type
  { a setting's label, a key's name, a step's name or ON/OFF }
  TName = string[24];
  { POOL.CFG as START reads it: the letters always one of C_OPT's (what START uses, whatever the file said), the paths
    as written (GameBoot and POOLCFG normalize them), and the lines after the fifth, which START does not read but a
    write keeps }
  TPoolCfg = record
    video: Char;
    sound: Char;
    intro: Char;
    dataDir: FileUtil.TPathName;
    saveDir: FileUtil.TPathName;
    extraCount: Byte;
    extra: array[1..C_OPT.CFG_EXTRA_LINES] of string[79];
  end;
  { a POOL.CFG line START would not take as written: its number, and what it held (cut to 12 characters), or missing
    when the file ended before it }
  TCfgNote = record
    line: Byte;
    missing: Boolean;
    raw: string[12];
  end;
  TCfgNotes = record
    count: Byte;
    items: array[1..C_OPT.CFG_LINES] of TCfgNote;
  end;
  { POOLOPT.CFG's values: the speed (0..C_OPT.SLOWEST), the log lines, each ON/OFF setting as 1 or 0 by its OPT_
    number, and the later games' paths by key - KEY_PATHS }
  TSettings = record
    speed: Byte;
    logLines: Byte;
    flags: array[C_OPT.OPT_FIRST_FLAG..C_OPT.OPT_LAST_FLAG] of Byte;
    paths: array[1..C_OPT.LATER_PATHS] of FileUtil.TPathName;
  end;
  { settings to pass by }
  TOptSet = set of 1..C_OPT.OPT_COUNT;
  { what a read found: the file as written, no file, a file read with values the reader would not take as written
    (left at the default, or read as START would), or a file there that could not be read }
  TReadResult = (CFG_READ, CFG_MISSING, CFG_FIXED, CFG_UNREADABLE);
  { a path checked (CheckPath): good, empty, holding a character no DOS path may, too long, or not an existing folder }
  TPathCheck = (PATH_OK, PATH_EMPTY, PATH_BAD_CHAR, PATH_TOO_LONG, PATH_MISSING);

{ The POOLOPT.CFG key of setting or path key: SPEED, ALLPORTRAITS ... LOGLINES, CURSEDATA ... POOLSSAVE; '' for none. }
function KeyName(key: Byte): TName;

{ The label of setting opt on the Settings screen, a sub-setting's indented two spaces under its setting. }
function SettingName(opt: Byte): TName;

{ SettingName with the number the speed and log lines lines show after it: 'Game Speed (1)', '  Log Lines (50)'. }
function SettingLabel(var s: TSettings; opt: Byte): TName;

{ True when setting opt steps a number with two choices, the left lowering it and the right raising it, and if so
  their names: Slower and Faster, Less and More. }
function StepNames(opt: Byte; var left, right: TName): Boolean;

{ The setting after opt, or before it when down is clear, wrapping at either end and passing by the settings in skip
  (all of them: opt). }
function NextSetting(opt: Byte; down: Boolean; skip: TOptSet): Byte;

{ ON for a nonzero flag, OFF for zero. }
function OnOff(flag: Byte): TName;

{ s without the spaces and tabs at either end. }
function Trim(s: string): string;

{ s trimmed (Trim) and upper-cased. }
function Tidy(s: string): string;

{ The setting or path key whose key line names before its '=' (in any case, spaces around it), or 0 for none. }
function KeyOf(line: string): Byte;

{ Every setting's default: speed 1, every portrait, music and sound setting on, Auto End Quick Mode on, Use Magic off,
  the Companion Tools off with their Clue Book notes on, the combat log on with 50 lines, and the later games' paths
  C:\CURSE\, C:\CURSE\SAVE\ and so on. }
procedure Defaults(var s: TSettings);

{ Setting opt (an ON/OFF one) as 1 for on and 0 for off; 0 for any other. }
function Flag(var s: TSettings; opt: Byte): Byte;

{ Set setting opt (an ON/OFF one) on for a nonzero value, else off. }
procedure SetFlag(var s: TSettings; opt, value: Byte);

{ Change setting opt as the Settings screen's Enter does: the speed and the log lines step to the choice on the right
  (Faster lowers the speed, More raises the lines by C_OPT.LOG_STEP), or the left, within their ranges; every other
  setting turns over. }
procedure ChangeSetting(var s: TSettings; opt: Byte; right: Boolean);

{ The value of setting or path key as POOLOPT.CFG keeps it: the speed's digit, the log lines' number, a path, ON or
  OFF. }
function StoredValue(var s: TSettings; key: Byte): FileUtil.TPathName;

{ Set setting or path key from value (tidied): a digit 0..9 for the speed, a number from C_OPT.LOG_MIN to LOG_MAX for
  the log lines, a path as it is, ON or OFF (or 1 or 0) for the others. False when the value was refused, which leaves
  the setting as it is; a blank path is passed over, not refused. }
function ReadValue(var s: TSettings; key: Byte; value: string): Boolean;

{ Read POOLOPT.CFG in folder dir (with its trailing backslash) over what s holds (the caller sets the defaults first).
  bad counts the known keys whose values were not taken. A missing file is CFG_MISSING; one that would not open,
  CFG_UNREADABLE; one with bad values, CFG_FIXED. At most C_OPT.MAX_LINES lines are read. }
function ReadOptions(dir: FileUtil.TPathName; var s: TSettings; var bad: Byte): TReadResult;

{ Write s as POOLOPT.CFG in folder dir: every key in order, then each line of the old file whose key this version does
  not know, kept for a newer one (blank lines dropped). It is written beside the old file as POOLOPT.CF$
  (FileUtil.TempName) and put in its place, so a failed write leaves the old file. A folder dir that is not there yet
  is made first, with any above it, as a save makes its folder (FileUtil.MakeFolder): a new save folder, or natively a
  new per-user one, keeps the settings from the first change (#1067). True when it was written. }
function WriteOptions(dir: FileUtil.TPathName; var s: TSettings): Boolean;

{ Read POOL.CFG file name into c as START reads it. A letter is taken in either case (#895); an unknown video letter
  is CGA, an unknown sound letter silent and an introduction other than F the short one. notes lists each letter line
  START would not take as written, and each line missing from a short file (whose paths are then empty, the current
  folder, and its introduction the short one). CFG_FIXED when there are notes. }
function ReadPoolCfg(name: FileUtil.TPathName; var c: TPoolCfg; var notes: TCfgNotes): TReadResult;

{ POOL.CFG's defaults, for a game with none: VGA, the full introduction, the data in folder home and the saves in SAVE\
  under it; no sound under DOS, where the card is not known, and natively Digital Audio (the Sound Blaster's letter),
  which every system plays (#894). }
procedure PoolDefaults(var c: TPoolCfg; home: string);

{ Write c as POOL.CFG file name: the five lines, then the extra ones, each ending CR LF whatever the system, through a
  temporary copy put in place (FileUtil.PutInPlace). True when it was written; else the old file is as it was. }
function WritePoolCfg(name: FileUtil.TPathName; var c: TPoolCfg): Boolean;

{ path made ready for file names to be appended, as START does with POOL.CFG's paths: spaces trimmed, the current
  drive (or, for a relative path, the current directory) put in front of a path without a drive letter, and a closing
  backslash. An empty path gives the current directory, and a drive alone (C:) the current directory on that drive.
  False when the result leaves no room for a file name within a DOS path (longer than C_OPT.MAX_PATH_TEXT); full is
  the result either way. Natively every '/' is a backslash too (NatFile turns them back), and on Linux and macOS, which
  have no drives, a path from '\' is whole (#894). }
function NormalizePath(path: string; var full: string): Boolean;

{ True when path (a full one, as NormalizePath makes) names a folder that exists: a drive's root when the drive
  answers. A path with a wildcard is never one. }
function DirExists(path: string): Boolean;

{ Check text as a folder for a POOL.CFG or POOLOPT.CFG path: tidied (Tidy), not empty, no * ? " < > or |, normalized
  (NormalizePath) within C_OPT.MAX_PATH_TEXT, and an existing folder; nothing is created. full is the normalized
  path. Natively its case is kept, as a system that tells cases apart shows it. }
function CheckPath(text: string; var full: string): TPathCheck;

{$IFDEF FPC}
{ The save folder the native game uses for POOL.CFG's dataDir and saveDir (GameBoot.NativeFolders; POOLCFG shows it),
  with its closing separator, where home is the writable folder (GameDirs.writeFolder, with its own): a save folder
  inside the data folder (SSI's C:\POOLRAD\SAVE\, both normalized, #894) is that part in home; else a whole path (from
  a drive or the root) to a folder that is there is that folder, normalized, which need not lie in the game's (#1064);
  else SAVE\ in home. }
function NativeSaveFolder(dataDir, saveDir, home: string): string;
{$ENDIF}

implementation

uses Dos{$IFDEF FPC}, NatFile{$ENDIF};

function KeyName(key: Byte): TName;
begin
  case key of
    C_OPT.OPT_SPEED: KeyName := 'SPEED';
    C_OPT.OPT_PORTRAITS_ALL: KeyName := 'ALLPORTRAITS';
    C_OPT.OPT_MONSTERS: KeyName := 'MONSTERS';
    C_OPT.OPT_PORTRAITS: KeyName := 'PORTRAITS';
    C_OPT.OPT_MUSIC: KeyName := 'MUSIC';
    C_OPT.OPT_TITLE_MUSIC: KeyName := 'TITLEMUSIC';
    C_OPT.OPT_BATTLE_MUSIC: KeyName := 'BATTLEMUSIC';
    C_OPT.OPT_SOUND: KeyName := 'SOUND';
    C_OPT.OPT_FOOTSTEPS: KeyName := 'FOOTSTEPS';
    C_OPT.OPT_RANGED: KeyName := 'RANGEDSOUND';
    C_OPT.OPT_MELEE: KeyName := 'MELEESOUND';
    C_OPT.OPT_DEATH: KeyName := 'DEATHSCREAM';
    C_OPT.OPT_WALL: KeyName := 'WALLHIT';
    C_OPT.OPT_SPELLS: KeyName := 'SPELLSOUND';
    C_OPT.OPT_QUICK: KeyName := 'AUTOENDQUICK';
    C_OPT.OPT_MAGIC: KeyName := 'QUICKMAGIC';
    C_OPT.OPT_COMPANION: KeyName := 'COMPANION';
    C_OPT.OPT_CLUES: KeyName := 'CLUENOTES';
    C_OPT.OPT_COMBAT_LOG: KeyName := 'COMBATLOG';
    C_OPT.OPT_LOG_LINES: KeyName := 'LOGLINES';
    C_OPT.KEY_PATHS + 1: KeyName := 'CURSEDATA';
    C_OPT.KEY_PATHS + 2: KeyName := 'CURSESAVE';
    C_OPT.KEY_PATHS + 3: KeyName := 'SECRETDATA';
    C_OPT.KEY_PATHS + 4: KeyName := 'SECRETSAVE';
    C_OPT.KEY_PATHS + 5: KeyName := 'POOLSDATA';
    C_OPT.KEY_PATHS + 6: KeyName := 'POOLSSAVE';
  else
    KeyName := '';
  end;
end;

function SettingName(opt: Byte): TName;
begin
  case opt of
    C_OPT.OPT_SPEED: SettingName := 'Game Speed';
    C_OPT.OPT_PORTRAITS_ALL: SettingName := 'Portraits';
    C_OPT.OPT_MONSTERS: SettingName := '  Monster Portraits';
    C_OPT.OPT_PORTRAITS: SettingName := '  Character Portraits';
    C_OPT.OPT_MUSIC: SettingName := 'Music';
    C_OPT.OPT_TITLE_MUSIC: SettingName := '  Title Music';
    C_OPT.OPT_BATTLE_MUSIC: SettingName := '  Battle Music';
    C_OPT.OPT_SOUND: SettingName := 'Sound';
    C_OPT.OPT_FOOTSTEPS: SettingName := '  Footsteps';
    C_OPT.OPT_RANGED: SettingName := '  Ranged Weapon Usage';
    C_OPT.OPT_MELEE: SettingName := '  Melee Attacks';
    C_OPT.OPT_DEATH: SettingName := '  Death Scream';
    C_OPT.OPT_WALL: SettingName := '  Wall Hit';
    C_OPT.OPT_SPELLS: SettingName := '  Spell Effects';
    C_OPT.OPT_QUICK: SettingName := '  Auto End Quick Mode';
    C_OPT.OPT_MAGIC: SettingName := '  Use Magic';
    C_OPT.OPT_COMPANION: SettingName := 'Companion Tools';
    C_OPT.OPT_CLUES: SettingName := '  Clue Book Notes';
    C_OPT.OPT_COMBAT_LOG: SettingName := 'Combat Log';
    C_OPT.OPT_LOG_LINES: SettingName := '  Log Lines';
  else
    SettingName := '';
  end;
end;

function SettingLabel(var s: TSettings; opt: Byte): TName;
begin
  if opt in [C_OPT.OPT_SPEED, C_OPT.OPT_LOG_LINES] then
    SettingLabel := CfgFile.SettingName(opt) + ' (' + CfgFile.StoredValue(s, opt) + ')'
  else
    SettingLabel := CfgFile.SettingName(opt);
end;

function StepNames(opt: Byte; var left, right: TName): Boolean;
begin
  StepNames := True;
  case opt of
    C_OPT.OPT_SPEED: begin
                       left := 'Slower';
                       right := 'Faster';
                     end;
    C_OPT.OPT_LOG_LINES: begin
                           left := 'Less';
                           right := 'More';
                         end;
  else
    StepNames := False;
  end;
end;

function NextSetting(opt: Byte; down: Boolean; skip: TOptSet): Byte;
var
  tries: Byte;
begin
  tries := 0;
  repeat
    if down then
      opt := opt mod C_OPT.OPT_COUNT + 1
    else if opt > 1 then
      Dec(opt)
    else
      opt := C_OPT.OPT_COUNT;
    Inc(tries);
  until not (opt in skip) or (tries >= C_OPT.OPT_COUNT);
  NextSetting := opt;
end;

function OnOff(flag: Byte): TName;
begin
  if flag <> 0 then
    OnOff := 'ON'
  else
    OnOff := 'OFF';
end;

function Trim(s: string): string;
begin
  while (Length(s) > 0) and (s[1] in [' ', #9]) do
    Delete(s, 1, 1);
  while (Length(s) > 0) and (s[Length(s)] in [' ', #9]) do
    Dec(s[0]);
  Trim := s;
end;

function Tidy(s: string): string;
var
  i: Byte;
begin
  s := CfgFile.Trim(s);
  for i := 1 to Length(s) do
    s[i] := UpCase(s[i]);
  Tidy := s;
end;

function KeyOf(line: string): Byte;
var
  eq: Byte;
  key: string;
  k: Byte;
begin
  KeyOf := 0;
  eq := Pos('=', line);
  if eq = 0 then Exit;
  key := CfgFile.Tidy(Copy(line, 1, eq - 1));
  for k := 1 to C_OPT.KEY_COUNT do
    if key = CfgFile.KeyName(k) then
      KeyOf := k;
end;

procedure Defaults(var s: TSettings);
var
  opt: Byte;
begin
  s.speed := C_OPT.SPEED_DEFAULT;
  s.logLines := C_OPT.LOG_DEFAULT;
  for opt := C_OPT.OPT_FIRST_FLAG to C_OPT.OPT_LAST_FLAG do
    s.flags[opt] := Ord(not (opt in [C_OPT.OPT_MAGIC, C_OPT.OPT_COMPANION]));
  s.paths[1] := 'C:\CURSE\';
  s.paths[2] := 'C:\CURSE\SAVE\';
  s.paths[3] := 'C:\SECRET\';
  s.paths[4] := 'C:\SECRET\SAVE\';
  s.paths[5] := 'C:\POOLS\';
  s.paths[6] := 'C:\POOLS\SAVE\';
end;

function Flag(var s: TSettings; opt: Byte): Byte;
begin
  if (opt >= C_OPT.OPT_FIRST_FLAG) and (opt <= C_OPT.OPT_LAST_FLAG) then
    Flag := s.flags[opt]
  else
    Flag := 0;
end;

procedure SetFlag(var s: TSettings; opt, value: Byte);
begin
  if (opt >= C_OPT.OPT_FIRST_FLAG) and (opt <= C_OPT.OPT_LAST_FLAG) then
    s.flags[opt] := Ord(value <> 0);
end;

procedure ChangeSetting(var s: TSettings; opt: Byte; right: Boolean);
begin
  case opt of
    C_OPT.OPT_SPEED: if not right then begin
                       if s.speed < C_OPT.SLOWEST then
                         Inc(s.speed);
                     end else if s.speed > 0 then
                       Dec(s.speed);
    C_OPT.OPT_LOG_LINES: if not right then begin
                           if s.logLines >= C_OPT.LOG_MIN + C_OPT.LOG_STEP then
                             Dec(s.logLines, C_OPT.LOG_STEP)
                           else
                             s.logLines := C_OPT.LOG_MIN;
                         end else if s.logLines <= C_OPT.LOG_MAX - C_OPT.LOG_STEP then
                           Inc(s.logLines, C_OPT.LOG_STEP)
                         else
                           s.logLines := C_OPT.LOG_MAX;
  else
    CfgFile.SetFlag(s, opt, Ord(CfgFile.Flag(s, opt) = 0));
  end;
end;

function StoredValue(var s: TSettings; key: Byte): FileUtil.TPathName;
var
  n: string[3];
begin
  if key = C_OPT.OPT_SPEED then
    StoredValue := Chr(Ord('0') + s.speed mod (C_OPT.SLOWEST + 1))
  else if key = C_OPT.OPT_LOG_LINES then begin
    Str(s.logLines, n);
    StoredValue := n;
  end else if key > C_OPT.KEY_PATHS then
    StoredValue := s.paths[key - C_OPT.KEY_PATHS]
  else
    StoredValue := CfgFile.OnOff(CfgFile.Flag(s, key));
end;

function ReadValue(var s: TSettings; key: Byte; value: string): Boolean;
var
  n: Integer;
  code: Integer;
begin
  ReadValue := True;
  if key = C_OPT.OPT_SPEED then begin
    if (Length(value) = 1) and (value[1] in ['0'..'9']) then
      s.speed := Ord(value[1]) - Ord('0')
    else
      ReadValue := False;
  end else if key = C_OPT.OPT_LOG_LINES then begin
    Val(value, n, code);
    if (code = 0) and (n >= C_OPT.LOG_MIN) and (n <= C_OPT.LOG_MAX) then
      s.logLines := n
    else
      ReadValue := False;
  end else if key > C_OPT.KEY_PATHS then begin
    if value <> '' then
      s.paths[key - C_OPT.KEY_PATHS] := value;
  end else if (value = 'ON') or (value = '1') then
    CfgFile.SetFlag(s, key, 1)
  else if (value = 'OFF') or (value = '0') then
    CfgFile.SetFlag(s, key, 0)
  else
    ReadValue := False;
end;

{ Open text file name for reading: CFG_READ when it opened, CFG_MISSING when there is no such file (or folder),
  CFG_UNREADABLE when it is there but would not open. A write of it the game was ended in is undone first
  (FileUtil.RecoverFile). }
function OpenText(var f: Text; name: FileUtil.TPathName): TReadResult;
var
  ioRes: Integer;
  recovered: Boolean;
begin
  recovered := FileUtil.RecoverFile(name);
  ioRes := IOResult;
  Assign(f, name);
  Reset(f);
  ioRes := IOResult;
  if ioRes = 0 then
    OpenText := CFG_READ
  else if (ioRes = 2) or (ioRes = 3) then
    OpenText := CFG_MISSING
  else
    OpenText := CFG_UNREADABLE;
end;

function ReadOptions(dir: FileUtil.TPathName; var s: TSettings; var bad: Byte): TReadResult;
var
  f: Text;
  line: string;
  key: Byte;
  lines: Integer;
  done: Boolean;
  found: TReadResult;
  ioRes: Integer;
begin
  bad := 0;
  found := CfgFile.OpenText(f, dir + C_OPT.OPT_NAME);
  if found = CFG_READ then begin
    lines := 0;
    done := False;
    repeat
      if Eof(f) then
        done := True
      else begin
        ReadLn(f, line);
        Inc(lines);
        key := CfgFile.KeyOf(line);
        if key <> 0 then
          if not CfgFile.ReadValue(s, key, CfgFile.Tidy(Copy(line, Pos('=', line) + 1, 255))) then
            Inc(bad);
      end;
      if (IOResult <> 0) or (lines >= C_OPT.MAX_LINES) then
        done := True;
    until done;
    Close(f);
    ioRes := IOResult;
    if bad > 0 then
      found := CFG_FIXED;
  end;
  ReadOptions := found;
end;

function WriteOptions(dir: FileUtil.TPathName; var s: TSettings): Boolean;
var
  newFile: Text;
  oldFile: Text;
  line: string;
  key: Byte;
  lines: Integer;
  done: Boolean;
  ok: Boolean;
  ioRes: Integer;
  name: FileUtil.TPathName;
begin
  WriteOptions := False;
  name := dir + C_OPT.OPT_NAME;
  ioRes := IOResult;
  if not FileUtil.MakeFolder(dir) then Exit;
  Assign(newFile, FileUtil.TempName(name));
  Rewrite(newFile);
  if IOResult <> 0 then Exit;
  for key := 1 to C_OPT.KEY_COUNT do
    WriteLn(newFile, CfgFile.KeyName(key), '=', CfgFile.StoredValue(s, key));
  ok := IOResult = 0;
  if ok then begin
    Assign(oldFile, name);
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
          if (CfgFile.KeyOf(line) = 0) and (CfgFile.Tidy(line) <> '') then
            WriteLn(newFile, line);
        end;
        if IOResult <> 0 then begin
          ok := False;
          done := True;
        end;
        if lines >= C_OPT.MAX_LINES then
          done := True;
      until done;
      Close(oldFile);
      ioRes := IOResult;
    end;
  end;
  Close(newFile);
  if IOResult <> 0 then
    ok := False;
  if ok then
    ok := FileUtil.PutInPlace(name)
  else
    FileUtil.DeleteFile(FileUtil.TempName(name));
  WriteOptions := ok;
end;

function ReadPoolCfg(name: FileUtil.TPathName; var c: TPoolCfg; var notes: TCfgNotes): TReadResult;
var
  f: Text;
  found: TReadResult;
  lineNo: Byte;
  line: string;
  missing: Boolean;
  letter: Char;
  known: Boolean;
  ioRes: Integer;
begin
  c.video := C_OPT.VIDEO_CGA;
  c.sound := C_OPT.SOUND_SILENT;
  c.intro := C_OPT.INTRO_SHORT;
  c.dataDir := '';
  c.saveDir := '';
  c.extraCount := 0;
  notes.count := 0;
  found := CfgFile.OpenText(f, name);
  if found <> CFG_READ then begin
    ReadPoolCfg := found;
    Exit;
  end;
  for lineNo := 1 to C_OPT.CFG_LINES do begin
    missing := Eof(f);
    line := '';
    if not missing then
      ReadLn(f, line);
    if Length(line) > 0 then
      letter := UpCase(line[1])
    else
      letter := ' ';
    known := not missing;
    case lineNo of
      1: if letter in [C_OPT.VIDEO_CGA, C_OPT.VIDEO_EGA, C_OPT.VIDEO_TANDY, C_OPT.VIDEO_VGA] then
           c.video := letter
         else
           known := False;
      2: if letter in [C_OPT.SOUND_SPEAKER, C_OPT.SOUND_TANDY, C_OPT.SOUND_ADLIB, C_OPT.SOUND_BLASTER] then
           c.sound := letter
         else if not (letter in [C_OPT.SOUND_SILENT, C_OPT.SOUND_NONE]) then
           known := False;
      3: c.dataDir := line;
      4: c.saveDir := line;
      5: if letter = C_OPT.INTRO_FULL then
           c.intro := letter
         else if letter <> C_OPT.INTRO_SHORT then
           known := False;
    end;
    if not known then begin
      Inc(notes.count);
      notes.items[notes.count].line := lineNo;
      notes.items[notes.count].missing := missing;
      notes.items[notes.count].raw := Copy(line, 1, 12);
    end;
  end;
  while not Eof(f) and (c.extraCount < C_OPT.CFG_EXTRA_LINES) and (IOResult = 0) do begin
    Inc(c.extraCount);
    ReadLn(f, c.extra[c.extraCount]);
  end;
  Close(f);
  ioRes := IOResult;
  if notes.count > 0 then
    ReadPoolCfg := CFG_FIXED
  else
    ReadPoolCfg := CFG_READ;
end;

procedure PoolDefaults(var c: TPoolCfg; home: string);
begin
  c.video := C_OPT.VIDEO_VGA;
{$IFDEF FPC}
  c.sound := C_OPT.SOUND_BLASTER;
{$ELSE}
  c.sound := C_OPT.SOUND_SILENT;
{$ENDIF}
  c.intro := C_OPT.INTRO_FULL;
  c.dataDir := home;
  c.saveDir := home + 'SAVE\';
  c.extraCount := 0;
end;

function WritePoolCfg(name: FileUtil.TPathName; var c: TPoolCfg): Boolean;
var
  f: file;
  ok: Boolean;
  i: Byte;

  { Write line s and CR LF. }
  procedure PutLine(s: string);
  begin
    s := s + #13#10;
    FileUtil.WriteChecked(f, s[1], Length(s), ok);
  end;

begin
  WritePoolCfg := False;
  if not FileUtil.RewriteTemp(f, name) then Exit;
  ok := True;
  PutLine(c.video);
  PutLine(c.sound);
  PutLine(c.dataDir);
  PutLine(c.saveDir);
  PutLine(c.intro);
  for i := 1 to c.extraCount do
    PutLine(c.extra[i]);
  if FileUtil.CloseTemp(f, name, ok) then
    WritePoolCfg := FileUtil.PutInPlace(name);
end;

{$IFDEF FPC}
{ s with each '/' a backslash. }
function Backslashed(s: string): string;
var
  i: Byte;
begin
  for i := 1 to Length(s) do
    if s[i] = '/' then
      s[i] := '\';
  Backslashed := s;
end;
{$ENDIF}

function NormalizePath(path: string; var full: string): Boolean;
var
  cur: string;
begin
  while (Length(path) > 0) and (path[1] = ' ') do
    Delete(path, 1, 1);
  while (Length(path) > 0) and (path[Length(path)] = ' ') do
    Dec(path[0]);
{$IFDEF FPC}
  path := CfgFile.Backslashed(path);
{$ENDIF}
  if (Length(path) = 2) and (path[2] = ':') then
    GetDir(Ord(UpCase(path[1])) - Ord('A') + 1, path)
  else begin
    GetDir(0, cur);
{$IFDEF FPC}
    cur := CfgFile.Backslashed(cur);
{$ENDIF}
    if cur[Length(cur)] <> '\' then cur := cur + '\';
    if (Length(path) < 2) or (path[2] <> ':') then
      if (Length(path) > 0) and (path[1] = '\') then begin
{$IFNDEF UNIX}
        path := Copy(cur, 1, 2) + path;
{$ENDIF}
      end else
        path := cur + path;
  end;
{$IFDEF FPC}
  path := CfgFile.Backslashed(path);
{$ENDIF}
  if path[Length(path)] <> '\' then path := path + '\';
  full := path;
  NormalizePath := Length(path) <= C_OPT.MAX_PATH_TEXT;
end;

function DirExists(path: string): Boolean;
var
  sr: SearchRec;
begin
  DirExists := False;
  if (path = '') or (Pos('*', path) > 0) or (Pos('?', path) > 0) then Exit;
{$IFNDEF FPC}
  if (Length(path) = 3) and (path[2] = ':') and (path[3] = '\') then begin
    DirExists := (UpCase(path[1]) in ['A'..'Z']) and (DiskFree(Ord(UpCase(path[1])) - Ord('A') + 1) <> -1);
    Exit;
  end;
{$ENDIF}
  if (Length(path) > 1) and (path[Length(path)] = '\') then
    Dec(path[0]);
{$IFDEF FPC}
  path := NatFile.NativeName(path);
{$ENDIF}
  FindFirst(path, Directory or Hidden or SysFile or ReadOnly or Archive, sr);
  DirExists := (DosError = 0) and (sr.Attr and Directory <> 0);
{$IFDEF FPC}
  FindClose(sr);
{$ENDIF}
end;

function CheckPath(text: string; var full: string): TPathCheck;
var
  i: Byte;
begin
{$IFDEF FPC}
  text := CfgFile.Trim(text);
{$ELSE}
  text := CfgFile.Tidy(text);
{$ENDIF}
  full := text;
  if text = '' then begin
    CheckPath := PATH_EMPTY;
    Exit;
  end;
  for i := 1 to Length(text) do
    if text[i] in ['*', '?', '"', '<', '>', '|'] then begin
      CheckPath := PATH_BAD_CHAR;
      Exit;
    end;
  if not CfgFile.NormalizePath(text, full) then
    CheckPath := PATH_TOO_LONG
  else begin
{$IFNDEF FPC}
    full := CfgFile.Tidy(full);
{$ENDIF}
    if CfgFile.DirExists(full) then
      CheckPath := PATH_OK
    else
      CheckPath := PATH_MISSING;
  end;
end;

{$IFDEF FPC}
function NativeSaveFolder(dataDir, saveDir, home: string): string;
var
  game: string;
  save: string;
  t: string;
  ok: Boolean;
begin
  { a path too long is compared as it is: this only places the saves }
  ok := CfgFile.NormalizePath(dataDir, game);
  ok := CfgFile.NormalizePath(saveDir, save);
  t := CfgFile.Trim(saveDir);
  if (Length(save) > Length(game)) and NatFile.SameName(Copy(save, 1, Length(game)), game) then
    NativeSaveFolder := home + Copy(save, Length(game) + 1, 255)
  else if (Length(t) > 0) and ((t[1] in ['\', '/']) or ((Length(t) >= 2) and (t[2] = ':'))) and
          CfgFile.DirExists(save) then
    NativeSaveFolder := save
  else
    NativeSaveFolder := home + 'SAVE\';
end;
{$ENDIF}

end.

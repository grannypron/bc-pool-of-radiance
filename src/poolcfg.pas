{ Pool of Radiance's 80x25 setup program (#876). It edits POOL.CFG hardware and
  path settings, plus the gameplay settings and later-game paths stored in
  POOLOPT.CFG. Paths must already exist. Save and Exit writes each file through
  a temporary replacement so a failed write leaves the old file intact. Exit
  status 0 means the configuration was saved or unchanged; status 1 means the
  user left with unsaved changes.

  Under DOS, START runs POOLCFG from the game directory when POOL.CFG is missing
  or damaged. The native poolcfg program runs separately beside poolrad (#894).
  It uses the same data and writable-folder discovery as the game and translates
  DOS hardware choices to the native VGA and Digital Audio implementations
  (#1064). }
{$IFNDEF FPC}
{$M 16384,0,16384}
{$ENDIF}
{$F+,I-}
{$I COMPILER.INC}
program PoolCfg;

uses Dos, C_KEYS, C_OPT, FileUtil, CfgFile, StrUtil, TuiKit{$IFDEF FPC}, SysUtils, NatFile, GameDirs{$ENDIF};

{ BUILD_VERSION and BUILD_COMMIT: build.sh writes them from git before each build. }
{$I BUILDID.INC}

const
  { the Main Menu's items: the three pages, then Save and Exit and Exit Without Saving }
  ITEM_HARDWARE = 1;
  ITEM_SETTINGS = 2;
  ITEM_PATHS = 3;
  ITEM_SAVE = 4;
  ITEM_QUIT = 5;
  ITEMS = 5;
  { the Hardware page's lines }
  HW_VIDEO = 1;
  HW_SOUND = 2;
  HW_INTRO = 3;
  HW_LINES = 3;
  { the Paths page's lines: Pool of Radiance's data and save paths, then each later game's (CfgFile's paths 1..6) }
  PATH_DATA = 1;
  PATH_SAVE = 2;
  PATH_LINES = 2 + C_OPT.LATER_PATHS;
  { the Paths page's path values: their column, and the edit field's }
  PATH_COL = 20;
  FIELD_WIDTH = 56;
  { the longest path that can be typed: a DOS path's 79 characters, natively 255 }
  PATH_TYPED = C_OPT.MAX_PATH_TEXT + C_OPT.LONGEST_NAME;
  { the program that reads POOL.CFG: START under DOS, the game itself natively }
{$IFDEF FPC}
  GAME_PROG = 'POOLRAD';
{$ELSE}
  GAME_PROG = 'START';
{$ENDIF}

var
  { POOL.CFG as Setup will write it (its paths normalized), and as it was read; what the read found, and its notes }
  cfg: CfgFile.TPoolCfg;
  cfgRead: CfgFile.TPoolCfg;
  cfgState: CfgFile.TReadResult;
  notes: CfgFile.TCfgNotes;
  { POOL.CFG's defaults (CfgFile.PoolDefaults), for a missing file and F5 }
  cfgDefaults: CfgFile.TPoolCfg;
  { a Pool path, as read, that START refuses as too long for DOS: shown in red until corrected }
  tooLong: array[PATH_DATA..PATH_SAVE] of Boolean;
  { POOLOPT.CFG as Setup will write it, as it was read, and every setting's default; what the read found, and how many
    values it would not take }
  opts: CfgFile.TSettings;
  optsRead: CfgFile.TSettings;
  defaults: CfgFile.TSettings;
  optState: CfgFile.TReadResult;
  optBad: Byte;
  { the folder Setup runs in, normalized (the Pool data path's default), POOL.CFG's full name, and the folder
    POOLOPT.CFG was read from }
  homeDir: string;
  cfgName: string;
  optDir: string;
{$IFDEF FPC}
  { the data folder the game finds (GameDirs.dataFolder), normalized as POOL.CFG holds it: the data path's default }
  dataHome: string;
{$ENDIF}
  { a stepping setting's choice on the Game Settings page: the right one (Faster, More) }
  stepRight: Boolean;
  { run by START (C_OPT.SETUP_FROM_START on the command line) }
  fromStart: Boolean;
  { leave the program, with this exit code }
  leave: Boolean;
  exitCode: Byte;

{ path as shown, cut to width characters: a path too long keeps its end, after '...', as its last folders say the most.
  On Linux and macOS its backslashes are shown as the system's '/'. }
function CutPath(path: string; width: Byte): string;
{$IFDEF UNIX}
var
  i: Byte;
{$ENDIF}
begin
{$IFDEF UNIX}
  for i := 1 to Length(path) do
    if path[i] = '\' then
      path[i] := '/';
{$ENDIF}
  if Length(path) > width then
    path := '...' + Copy(path, Length(path) - (width - 3) + 1, width - 3);
  CutPath := path;
end;

{ The title bar, and the blue page under it from row 2 to row 24. }
procedure ClearPage;
begin
  TuiKit.TitleBar('Pool of Radiance Setup', 'POOLCFG ' + CfgFile.Tidy(BUILD_VERSION));
  TuiKit.Fill(1, 2, TuiKit.COLS, TuiKit.ROWS - 1, TuiKit.A_TEXT);
end;

{ --- the Hardware page's choices ------------------------------------------------------------------------------- }

{ How many choices Hardware line has. }
function ChoiceCount(line: Byte): Byte;
begin
  case line of
    HW_VIDEO: ChoiceCount := 4;
    HW_SOUND: ChoiceCount := 5;
  else
    ChoiceCount := 2;
  end;
end;

{ The POOL.CFG letter of choice i of Hardware line. }
function ChoiceLetter(line, i: Byte): Char;
const
  VIDEO: array[1..4] of Char = (C_OPT.VIDEO_CGA, C_OPT.VIDEO_EGA, C_OPT.VIDEO_TANDY, C_OPT.VIDEO_VGA);
  SOUND: array[1..5] of Char = (C_OPT.SOUND_SILENT, C_OPT.SOUND_SPEAKER, C_OPT.SOUND_TANDY, C_OPT.SOUND_ADLIB,
    C_OPT.SOUND_BLASTER);
  INTRO: array[1..2] of Char = (C_OPT.INTRO_FULL, C_OPT.INTRO_SHORT);
begin
  case line of
    HW_VIDEO: ChoiceLetter := VIDEO[i];
    HW_SOUND: ChoiceLetter := SOUND[i];
  else
    ChoiceLetter := INTRO[i];
  end;
end;

{ The name of choice i of Hardware line. }
function ChoiceName(line, i: Byte): TuiKit.TLine;
const
  VIDEO: array[1..4] of string[5] = ('CGA', 'EGA', 'Tandy', 'VGA');
  SOUND: array[1..5] of string[13] = ('None', 'PC Speaker', 'Tandy', 'AdLib', 'Sound Blaster');
  INTRO: array[1..2] of string[5] = ('Full', 'Short');
begin
  case line of
    HW_VIDEO: ChoiceName := VIDEO[i];
    HW_SOUND: ChoiceName := SOUND[i];
  else
    ChoiceName := INTRO[i];
  end;
end;

{ Hardware line's label, on the page and over its pick list. }
function LineName(line: Byte): TuiKit.TLine;
const
  NAMES: array[1..HW_LINES] of string[12] = ('Video', 'Sound Device', 'Introduction');
begin
  LineName := NAMES[line];
end;

{ Hardware line's letter in c. }
function LineLetter(var c: CfgFile.TPoolCfg; line: Byte): Char;
begin
  case line of
    HW_VIDEO: LineLetter := c.video;
    HW_SOUND: LineLetter := c.sound;
  else
    LineLetter := c.intro;
  end;
end;

{ The choice Hardware line has in c: the index of its letter (1 for a letter that is no choice's). }
function ChoiceOf(var c: CfgFile.TPoolCfg; line: Byte): Byte;
var
  i: Byte;
begin
  ChoiceOf := 1;
  for i := 1 to ChoiceCount(line) do
    if ChoiceLetter(line, i) = LineLetter(c, line) then
      ChoiceOf := i;
end;

{ Set Hardware line to choice i. }
procedure SetChoice(line, i: Byte);
begin
  case line of
    HW_VIDEO: cfg.video := ChoiceLetter(line, i);
    HW_SOUND: cfg.sound := ChoiceLetter(line, i);
  else
    cfg.intro := ChoiceLetter(line, i);
  end;
end;

{ --- the paths ------------------------------------------------------------------------------------------------- }

{ Paths line's path: Pool's from POOL.CFG, the later games' from POOLOPT.CFG. }
function PathOf(var c: CfgFile.TPoolCfg; var s: CfgFile.TSettings; line: Byte): string;
begin
  case line of
    PATH_DATA: PathOf := c.dataDir;
    PATH_SAVE: PathOf := c.saveDir;
  else
    PathOf := s.paths[line - 2];
  end;
end;

{ Set Paths line to path (a normalized one); a Pool path is marked when it is too long for START (tooLong), as a
  default can be in a folder too deep for DOS. }
procedure SetPath(line: Byte; path: string);
begin
  case line of
    PATH_DATA: cfg.dataDir := path;
    PATH_SAVE: cfg.saveDir := path;
  else
    opts.paths[line - 2] := path;
  end;
  if line <= PATH_SAVE then
    tooLong[line] := Length(path) > C_OPT.MAX_PATH_TEXT;
end;

{ Paths line's default: Pool's data in the folder Setup runs in (natively the data folder the game finds) and its saves
  in SAVE\ under it (natively under the writable folder), the later games' as CfgFile.Defaults has them. }
function DefaultPath(line: Byte): string;
begin
  case line of
    PATH_DATA: DefaultPath := {$IFDEF FPC}dataHome{$ELSE}homeDir{$ENDIF};
    PATH_SAVE: DefaultPath := homeDir + 'SAVE\';
  else
    DefaultPath := defaults.paths[line - 2];
  end;
end;

{ True when folder dir holds Pool of Radiance's data: ITEMS or GEO1.DAX. }
function HasPoolData(dir: string): Boolean;
begin
  HasPoolData := FileUtil.Exists(dir + 'ITEMS') or FileUtil.Exists(dir + 'GEO1.DAX');
end;

{ --- what has changed ------------------------------------------------------------------------------------------ }

function HardwareChanged: Boolean;
begin
  HardwareChanged := (cfg.video <> cfgRead.video) or (cfg.sound <> cfgRead.sound) or (cfg.intro <> cfgRead.intro);
end;

{ True when setting opt differs from POOLOPT.CFG as read. }
function SettingChanged(opt: Byte): Boolean;
begin
  SettingChanged := CfgFile.StoredValue(opts, opt) <> CfgFile.StoredValue(optsRead, opt);
end;

function SettingsChanged: Boolean;
var
  opt: Byte;
  changed: Boolean;
begin
  changed := False;
  for opt := 1 to C_OPT.OPT_COUNT do
    changed := changed or SettingChanged(opt);
  SettingsChanged := changed;
end;

function PathChanged(line: Byte): Boolean;
begin
  PathChanged := PathOf(cfg, opts, line) <> PathOf(cfgRead, optsRead, line);
end;

function PathsChanged: Boolean;
var
  line: Byte;
  changed: Boolean;
begin
  changed := False;
  for line := 1 to PATH_LINES do
    changed := changed or PathChanged(line);
  PathsChanged := changed;
end;

{ True when saving writes POOL.CFG: something in it changed, or it was missing or is not as START would read it. }
function PoolCfgDue: Boolean;
begin
  PoolCfgDue := HardwareChanged or PathChanged(PATH_DATA) or PathChanged(PATH_SAVE) or
                (cfgState in [CfgFile.CFG_MISSING, CfgFile.CFG_FIXED]);
end;

{ True when saving writes POOLOPT.CFG: something in it changed, or the save folder did (the settings go with it), or it
  was missing or not as the game would read it and the save folder is there. }
function OptionsDue: Boolean;
var
  line: Byte;
  due: Boolean;
begin
  due := SettingsChanged or PathChanged(PATH_SAVE);
  for line := PATH_SAVE + 1 to PATH_LINES do
    due := due or PathChanged(line);
  if (optState in [CfgFile.CFG_MISSING, CfgFile.CFG_FIXED]) and CfgFile.DirExists(cfg.saveDir) then
    due := True;
  OptionsDue := due;
end;

{ True when leaving now would lose something: a change, or a POOL.CFG still to be written. }
function Unsaved: Boolean;
begin
  Unsaved := SettingsChanged or PathsChanged or PoolCfgDue;
end;

{ --- the Main Menu --------------------------------------------------------------------------------------------- }

{ What a file's read found (state), as the Files box says it, and its colour in attr; fixed is what CFG_FIXED says. }
function ReadState(state: CfgFile.TReadResult; fixed: string; var attr: Byte): string;
begin
  attr := TuiKit.A_WARN;
  case state of
    CfgFile.CFG_READ: begin
                        ReadState := 'read';
                        attr := TuiKit.A_GOOD;
                      end;
    CfgFile.CFG_MISSING: ReadState := 'not found: defaults';
    CfgFile.CFG_FIXED: ReadState := fixed;
  else begin
      ReadState := 'cannot read';
      attr := TuiKit.A_BAD;
    end;
  end;
end;

{ The Files box: each file's name, where it is and what the read found, and the pages with changes. }
procedure DrawFiles;
var
  state: string;
  attr: Byte;
  changes: string;

  { Add page to the pages with changes. }
  procedure Changed(page: string);
  begin
    if changes <> '' then
      changes := changes + ', ';
    changes := changes + page;
  end;

begin
  TuiKit.Box(3, 15, 78, 19, TuiKit.A_FRAME, 'Files');
  TuiKit.PutText(5, 16, TuiKit.A_TEXT, C_OPT.CFG_NAME);
  TuiKit.PutText(18, 16, TuiKit.A_TEXT, CutPath(cfgName, 30));
  state := ReadState(cfgState, 'fixed', attr);
  TuiKit.PutText(49, 16, attr, state);
  TuiKit.PutText(5, 17, TuiKit.A_TEXT, C_OPT.OPT_NAME);
  TuiKit.PutText(18, 17, TuiKit.A_TEXT, CutPath(optDir + C_OPT.OPT_NAME, 30));
  state := ReadState(optState, 'fixed: ' + StrUtil.Count(optBad, 'value', 'values') + ' out of range', attr);
  TuiKit.PutText(49, 17, attr, state);
  TuiKit.PutText(5, 18, TuiKit.A_TEXT, 'Changes');
  changes := '';
  if HardwareChanged then
    Changed('Hardware');
  if SettingsChanged then
    Changed('Game Settings');
  if PathsChanged then
    Changed('Paths');
  if (changes = '') and PoolCfgDue then
    changes := 'none; saving writes POOL.CFG';
  if changes <> '' then
    TuiKit.PutText(18, 18, TuiKit.A_WARN, changes)
  else
    TuiKit.PutText(18, 18, TuiKit.A_TEXT, 'none');
end;

{ The Main Menu's row of item i. }
function ItemRow(i: Byte): Byte;
begin
  ItemRow := 4 + i + Ord(i >= ITEM_SAVE);
end;

{ The Main Menu, item sel highlighted. }
procedure DrawMain(sel: Byte);
const
  NAMES: array[1..ITEMS] of string[19] = ('Hardware', 'Game Settings', 'Paths', 'Save and Exit',
    'Exit Without Saving');
  { each item's hot letter's place in its name }
  HOT: array[1..ITEMS] of Byte = (1, 1, 1, 1, 2);
  ABOUT: array[1..3] of string[26] = ('Video, sound, introduction', 'The Settings screen''s list',
    'Data and save folders');
var
  i: Byte;
begin
  ClearPage;
  TuiKit.Box(16, 3, 65, 12, TuiKit.A_FRAME, 'Main Menu');
  for i := 1 to ITEMS do begin
    TuiKit.PutText(20, ItemRow(i), TuiKit.A_TEXT, NAMES[i]);
    TuiKit.PutRun(19 + HOT[i], ItemRow(i), TuiKit.A_HOT, NAMES[i][HOT[i]], 1);
    if i <= 3 then
      TuiKit.PutText(36, ItemRow(i), TuiKit.A_HELP, ABOUT[i]);
  end;
  TuiKit.Recolor(17, ItemRow(sel), 48, TuiKit.A_HIGHLIGHT);
  DrawFiles;
  TuiKit.KeyLine('~Enter~ Select   ~Esc~ Exit   ~F10~ Save and Exit');
end;

{ --- saving ---------------------------------------------------------------------------------------------------- }

{ Show an error: title Error, the lines first and second (second, a file or folder, in the error box's value colour). }
procedure ShowError(first, second: string);
var
  lines: TuiKit.TLines;
begin
  TuiKit.ClearLines(lines);
  TuiKit.AddLine(lines, first, 0);
  if second <> '' then begin
    TuiKit.AddLine(lines, '', 0);
    TuiKit.AddLine(lines, second, TuiKit.A_ERROR_VALUE);
  end;
  TuiKit.Message('Error', lines, TuiKit.STYLE_ERROR, 44);
end;

{ Save: POOLOPT.CFG into the save folder being written, then POOL.CFG, each only when due. True when every file due
  was written (or none was), and the files written are said; else the error is shown and Setup stays open with the
  changes kept. A POOL.CFG that could not be read is not written over, nor one with a path START refuses. }
function Save: Boolean;
var
  lines: TuiKit.TLines;
  poolDue: Boolean;
  optDue: Boolean;
begin
  Save := False;
  if cfgState = CfgFile.CFG_UNREADABLE then begin
    ShowError('POOL.CFG could not be read, so Setup will not', 'write over it: ' + CutPath(cfgName, 22));
    Exit;
  end;
  if tooLong[PATH_DATA] or tooLong[PATH_SAVE] then begin
    ShowError('A Pool of Radiance path is too long for DOS.', 'Correct it on the Paths page first.');
    Exit;
  end;
  poolDue := PoolCfgDue;
  optDue := OptionsDue;
  if optDue and not CfgFile.WriteOptions(cfg.saveDir, opts) then begin
    ShowError('Could not write ' + C_OPT.OPT_NAME + '. The folder may be',
              'missing or read-only: ' + CutPath(cfg.saveDir, 20));
    Exit;
  end;
  if poolDue and not CfgFile.WritePoolCfg({$IFDEF FPC}cfgName{$ELSE}C_OPT.CFG_NAME{$ENDIF}, cfg) then begin
    ShowError('Could not write ' + C_OPT.CFG_NAME + '. The folder may be', 'read-only; nothing in it was changed.');
    Exit;
  end;
{$IFDEF FPC}
  { the data folder the game is to use from now on (#1064) }
  if PathChanged(PATH_DATA) and not GameDirs.Remember(GameDirs.POOL, NatFile.NativeName(cfg.dataDir)) then begin
    ShowError('Could not remember the data folder in', CutPath(GameDirs.UserFolder(GameDirs.POOL, GameDirs.THIS_OS,
              GetUserDir), 38));
    Exit;
  end;
{$ENDIF}
  TuiKit.ClearLines(lines);
  if not optDue and not poolDue then
    TuiKit.AddLine(lines, 'Nothing has changed, so no file was written.', 0)
  else begin
    TuiKit.AddLine(lines, 'Setup wrote:', 0);
    TuiKit.AddLine(lines, '', 0);
    if optDue then
      TuiKit.AddLine(lines, '  ' + CutPath(cfg.saveDir + C_OPT.OPT_NAME, 60), TuiKit.A_POP_VALUE);
    if poolDue then
      TuiKit.AddLine(lines, '  ' + CutPath(cfgName, 60), TuiKit.A_POP_VALUE);
  end;
  TuiKit.KeyLine('Press any key');
  TuiKit.Message('Saved', lines, TuiKit.STYLE_NOTICE, 64);
  Save := True;
end;

{ Save and, when it did, leave with exit code 0. }
procedure SaveAndLeave;
begin
  if Save then begin
    exitCode := 0;
    leave := True;
  end;
end;

{ --- the Hardware page ----------------------------------------------------------------------------------------- }

{ The Hardware page's help for line, under the divider. }
procedure DrawHardwareHelp(line: Byte);
var
  row: Byte;

  procedure Put(indent: Byte; s: string);
  begin
    TuiKit.PutText(6 + indent, row, TuiKit.A_HELP, s);
    Inc(row);
  end;

begin
  TuiKit.Fill(4, 10, 77, 22, TuiKit.A_TEXT);
  row := 10;
{$IFDEF FPC}
  case line of
    HW_VIDEO: begin
                Put(0, 'The graphics card the DOS game draws with. The native game always');
                Put(0, 'draws in VGA (EGA''s 16 colours), whatever this says:');
                Inc(row);
                Put(2, 'CGA, EGA, Tandy, VGA   all VGA natively');
                Inc(row);
                Put(0, 'It is kept for a copy of the game run under DOS or DOSBox.');
                Put(0, 'POOLRAD reads this as POOL.CFG''s first line.');
              end;
    HW_SOUND: begin
                Put(0, 'The card the DOS game plays music and effects on. The native game');
                Put(0, 'always plays Digital Audio, whatever this says: the Tandy''s music');
                Put(0, 'and the Sound Blaster''s recorded effects.');
                Inc(row);
                Put(0, 'For silence, turn off Music and Sound on the Settings page');
                Put(0, '(Ctrl-S in the game).');
                Inc(row);
                Put(0, 'It is kept for a copy of the game run under DOS or DOSBox.');
                Put(0, 'POOLRAD reads this as POOL.CFG''s second line.');
              end;
  else begin
      Put(0, 'Full: SSI''s whole title sequence. Short: the title and straight to');
      Put(0, 'the menu.');
      Inc(row);
      Put(0, 'POOLRAD reads this as POOL.CFG''s fifth line.');
    end;
  end;
{$ELSE}
  case line of
    HW_VIDEO: begin
                Put(0, 'The graphics card the game draws with:');
                Inc(row);
                Put(2, 'CGA     4 colours');
                Put(2, 'EGA     16 colours');
                Put(2, 'Tandy   16 colours, Tandy 1000 and PCjr');
                Put(2, 'VGA     EGA''s 16 colours in VGA''s 320x200 mode (not in SSI''s game)');
                Inc(row);
                Put(0, 'START reads this as POOL.CFG''s first line.');
              end;
    HW_SOUND: begin
                Put(0, 'The card the game plays music and effects on:');
                Inc(row);
                Put(2, 'None            silence');
                Put(2, 'PC Speaker      music and effects on the speaker');
                Put(2, 'Tandy           the Tandy 1000''s three voices');
                Put(2, 'AdLib           AdLib music, effects on the speaker');
                Put(2, 'Sound Blaster   AdLib music, SSI''s recorded effects');
                Inc(row);
                Put(0, 'START reads this as POOL.CFG''s second line.');
              end;
  else begin
      Put(0, 'Full: SSI''s whole title sequence. Short: the title and straight to');
      Put(0, 'the menu.');
      Inc(row);
      Put(0, 'START reads this as POOL.CFG''s fifth line.');
    end;
  end;
{$ENDIF}
end;

{ Hardware line on its row, highlighted when sel. }
procedure DrawHardwareLine(line: Byte; sel: Boolean);
var
  row: Byte;
  value: string;
begin
  row := 4 + line;
  TuiKit.PutRun(4, row, TuiKit.A_TEXT, ' ', 74);
  TuiKit.PutText(6, row, TuiKit.A_TEXT, LineName(line));
  value := ChoiceName(line, ChoiceOf(cfg, line));
  if LineLetter(cfg, line) <> LineLetter(cfgRead, line) then
    TuiKit.PutText(26, row, TuiKit.A_CHANGED, value + '*')
  else
    TuiKit.PutText(26, row, TuiKit.A_VALUE, value);
  if sel then
    TuiKit.Recolor(4, row, 74, TuiKit.A_HIGHLIGHT);
end;

procedure DrawHardware(sel: Byte);
var
  line: Byte;
begin
  ClearPage;
  TuiKit.Box(3, 3, 78, 23, TuiKit.A_FRAME, 'Hardware (POOL.CFG)');
  TuiKit.Divider(3, 78, 9, TuiKit.A_FRAME);
  for line := 1 to HW_LINES do
    DrawHardwareLine(line, line = sel);
  DrawHardwareHelp(sel);
  TuiKit.KeyLine('~Up Dn~ Move  ~Lt Rt~ Change  ~Enter~ List  ~F5~ Default  ~Esc~ Main Menu  ~F10~ Save+Exit');
end;

{ The Hardware page (POOL.CFG's letters) until Escape, or F10 saves and leaves. }
procedure HardwarePage;
var
  sel: Byte;
  i: Byte;
  ch: Char;
  ext: Boolean;
  done: Boolean;
  items: TuiKit.TLines;
begin
  sel := HW_VIDEO;
  DrawHardware(sel);
  done := False;
  repeat
    TuiKit.GetKey(ch, ext);
    i := ChoiceOf(cfg, sel);
    if ext then begin
      TuiKit.MoveInList(ch, sel, HW_LINES);
      case ch of
        C_KEYS.LEFT: if i > 1 then SetChoice(sel, i - 1) else SetChoice(sel, ChoiceCount(sel));
        C_KEYS.RIGHT: SetChoice(sel, i mod ChoiceCount(sel) + 1);
        C_KEYS.F5: SetChoice(sel, ChoiceOf(cfgDefaults, sel));
        C_KEYS.F10: begin
                      SaveAndLeave;
                      done := leave;
                    end;
      end;
    end else
      case ch of
        ' ': SetChoice(sel, i mod ChoiceCount(sel) + 1);
        C_KEYS.ENTER: begin
                        TuiKit.ClearLines(items);
                        for i := 1 to ChoiceCount(sel) do
                          TuiKit.AddLine(items, ChoiceName(sel, i), 0);
                        i := ChoiceOf(cfg, sel);
                        TuiKit.KeyLine('~Up Dn~ Move  ~Enter~ Choose  ~Esc~ Cancel');
                        if TuiKit.PickList(41, 4, LineName(sel), items, i) then
                          SetChoice(sel, i);
                      end;
        C_KEYS.ESCAPE: done := True;
      end;
    if not done then
      DrawHardware(sel);
  until done;
end;

{ --- the Game Settings page ------------------------------------------------------------------------------------ }

{ The Game Settings page's row of setting opt: one a row from row 3, the Quick Mode heading's row before OPT_QUICK, as
  on the game's Settings screen. }
function SettingRow(opt: Byte): Byte;
begin
  SettingRow := 3 + opt - 1 + Ord(opt >= C_OPT.OPT_QUICK);
end;

{ What setting opt does, its lines split at '|', for the About box. }
function AboutText(opt: Byte): string;
begin
  case opt of
    C_OPT.OPT_SPEED: AboutText := 'How long the game waits over|its messages and animations:|' +
                                  '0 is the fastest, 9 the|slowest. Slower raises it.';
    C_OPT.OPT_PORTRAITS_ALL: AboutText := 'Every portrait at once: off,|the game shows none.';
    C_OPT.OPT_MONSTERS: AboutText := 'The monsters'' pictures when|an encounter starts.';
    C_OPT.OPT_PORTRAITS: AboutText := 'The party''s portraits on the|character screens.';
    C_OPT.OPT_MUSIC: AboutText := 'Every tune at once.';
    C_OPT.OPT_TITLE_MUSIC: AboutText := 'The title theme.';
    C_OPT.OPT_BATTLE_MUSIC: AboutText := 'The music as a fight starts.';
{$IFDEF FPC}
    C_OPT.OPT_SOUND: AboutText := 'Every sound effect at once|(Ctrl-S in the game).';
{$ELSE}
    C_OPT.OPT_SOUND: AboutText := 'Every sound effect at once|(Ctrl-S in the game).||' +
                                  'With no sound device in|POOL.CFG the game stays|silent whatever this says.';
{$ENDIF}
    C_OPT.OPT_FOOTSTEPS: AboutText := 'The party''s steps.';
    C_OPT.OPT_RANGED: AboutText := 'Missiles in flight and their|hits and misses.';
    C_OPT.OPT_MELEE: AboutText := 'Melee attacks'' hits and|misses.';
    C_OPT.OPT_DEATH: AboutText := 'A creature going down.';
    C_OPT.OPT_WALL: AboutText := 'The party walking into a|wall.';
    C_OPT.OPT_SPELLS: AboutText := 'Spells being cast, and their|effects.';
    C_OPT.OPT_QUICK: AboutText := 'Quick mode ends with the|fight it was turned on in.';
    C_OPT.OPT_MAGIC: AboutText := 'Characters in quick mode|cast their spells.';
    C_OPT.OPT_COMPANION: AboutText := 'The Companion Tools: F6 on|the map and camp menus.';
    C_OPT.OPT_CLUES: AboutText := 'The Companion Tools'' notes|from the Clue Book.';
    C_OPT.OPT_COMBAT_LOG: AboutText := 'Keeps the fight''s messages for|F7 to page back through.||' +
                                       'Under DOS the log needs EMS:|without it the game keeps none,|' +
                                       'whatever this says.';
    C_OPT.OPT_LOG_LINES: AboutText := 'How many messages the combat|log keeps, from 10 to 60 in|steps of 5.';
  else
    AboutText := '';
  end;
end;

{ The About box for setting opt: its name, what it does, its default and its key. }
procedure DrawAbout(opt: Byte);
var
  text: string;
  row: Byte;
  bar: Byte;
begin
  TuiKit.Fill(47, 3, 78, 23, TuiKit.A_TEXT);
  text := CfgFile.SettingName(opt);
  while (text <> '') and (text[1] = ' ') do
    Delete(text, 1, 1);
  TuiKit.PutText(48, 3, TuiKit.A_FRAME, text);
  text := AboutText(opt) + '|';
  row := 5;
  while text <> '' do begin
    bar := Pos('|', text);
    TuiKit.PutText(48, row, TuiKit.A_HELP, Copy(text, 1, bar - 1));
    Delete(text, 1, bar);
    Inc(row);
  end;
  Inc(row);
  TuiKit.PutText(48, row, TuiKit.A_TEXT, 'Default  ' + CfgFile.StoredValue(defaults, opt));
  TuiKit.PutText(48, row + 1, TuiKit.A_TEXT, 'Key      ' + CfgFile.KeyName(opt));
end;

{ Setting opt on its row, highlighted when sel: its label, and its value, or a stepping line's two choices. }
procedure DrawSettingLine(opt: Byte; sel: Boolean);
var
  row: Byte;
  left: CfgFile.TName;
  right: CfgFile.TName;
  value: string;
  attr: Byte;
begin
  row := SettingRow(opt);
  TuiKit.PutRun(3, row, TuiKit.A_TEXT, ' ', 42);
  TuiKit.PutText(4, row, TuiKit.A_TEXT, CfgFile.SettingLabel(opts, opt));
  attr := TuiKit.A_VALUE;
  if SettingChanged(opt) then
    attr := TuiKit.A_CHANGED;
  if CfgFile.StepNames(opt, left, right) then
    value := left + ' ' + right
  else
    value := CfgFile.StoredValue(opts, opt);
  if SettingChanged(opt) then
    value := value + '*';
  TuiKit.PutText(28, row, attr, value);
  if sel then begin
    TuiKit.Recolor(3, row, 42, TuiKit.A_HIGHLIGHT);
    if CfgFile.StepNames(opt, left, right) then
      if stepRight then
        TuiKit.Recolor(28, row, Length(left), TuiKit.A_HIGHLIGHT_OTHER)
      else
        TuiKit.Recolor(28 + Length(left) + 1, row, Length(right), TuiKit.A_HIGHLIGHT_OTHER);
  end;
end;

procedure DrawSettings(sel: Byte);
var
  opt: Byte;
begin
  ClearPage;
  TuiKit.Box(2, 2, 45, 24, TuiKit.A_FRAME, 'Game Settings (POOLOPT.CFG)');
  TuiKit.Box(46, 2, 79, 24, TuiKit.A_FRAME, 'About');
  for opt := 1 to C_OPT.OPT_COUNT do
    DrawSettingLine(opt, opt = sel);
  TuiKit.PutText(4, SettingRow(C_OPT.OPT_QUICK) - 1, TuiKit.A_FRAME, 'Quick Mode');
  DrawAbout(sel);
  TuiKit.KeyLine('~Up Dn~ Move  ~Lt Rt~ Change  ~F5~ Default  ~Esc~ Main Menu  ~F10~ Save and Exit');
end;

{ The Game Settings page (POOLOPT.CFG's settings, as the game's Settings screen lists them) until Escape, or F10 saves
  and leaves. }
procedure SettingsPage;
var
  sel: Byte;
  ch: Char;
  ext: Boolean;
  done: Boolean;
  left: CfgFile.TName;
  right: CfgFile.TName;
  stepping: Boolean;
begin
  sel := 1;
  stepRight := False;
  DrawSettings(sel);
  done := False;
  repeat
    TuiKit.GetKey(ch, ext);
    stepping := CfgFile.StepNames(sel, left, right);
    if ext then
      case ch of
        C_KEYS.UP: sel := CfgFile.NextSetting(sel, False, []);
        C_KEYS.DOWN: sel := CfgFile.NextSetting(sel, True, []);
        C_KEYS.HOME: sel := 1;
        C_KEYS.END_KEY: sel := C_OPT.OPT_COUNT;
        C_KEYS.LEFT, C_KEYS.RIGHT: if stepping then
                                     stepRight := ch = C_KEYS.RIGHT
                                   else
                                     CfgFile.ChangeSetting(opts, sel, False);
        C_KEYS.F5: case sel of
                     C_OPT.OPT_SPEED: opts.speed := defaults.speed;
                     C_OPT.OPT_LOG_LINES: opts.logLines := defaults.logLines;
                   else
                     CfgFile.SetFlag(opts, sel, CfgFile.Flag(defaults, sel));
                   end;
        C_KEYS.F10: begin
                      SaveAndLeave;
                      done := leave;
                    end;
      end
    else
      case ch of
        ' ', C_KEYS.ENTER: CfgFile.ChangeSetting(opts, sel, stepRight);
        C_KEYS.ESCAPE: done := True;
      end;
    if not done then
      DrawSettings(sel);
  until done;
end;

{ --- the Paths page -------------------------------------------------------------------------------------------- }

{ The Paths page's row of line. }
function PathRow(line: Byte): Byte;
begin
  PathRow := 5 + ((line - 1) div 2) * 4 + (line - 1) mod 2;
end;

{ The note under the divider: for a Pool path that START refuses or whose folder is not there, what that means, else
  the page's rule. }
procedure DrawPathNote(line: Byte);
begin
  TuiKit.Fill(3, 21, 78, 23, TuiKit.A_TEXT);
{$IFDEF FPC}
  if line = PATH_DATA then begin
    TuiKit.PutText(5, 21, TuiKit.A_HELP, 'The folder the native game reads SSI''s files from, found beside it or');
    TuiKit.PutText(5, 22, TuiKit.A_HELP, 'in GOG''s or Steam''s folders. Saving a change makes the game use it.');
    TuiKit.PutText(5, 23, TuiKit.A_HELP, 'It needs GEO1.DAX; poolrad --choose-data-folder chooses it too.');
  end else
{$ENDIF}
  if (line <= PATH_SAVE) and tooLong[line] then begin
    TuiKit.PutText(5, 21, TuiKit.A_BAD, 'This path is too long for DOS (' + StrUtil.NumStr(C_OPT.MAX_PATH_TEXT) +
                   ' characters at most).');
    TuiKit.PutText(5, 22, TuiKit.A_BAD, 'START will not run until it is corrected.');
  end else if (line <= PATH_SAVE) and not CfgFile.DirExists(PathOf(cfg, opts, line)) then begin
    TuiKit.PutText(5, 21, TuiKit.A_WARN, 'This folder is not there.');
    if line = PATH_DATA then
      TuiKit.PutText(5, 22, TuiKit.A_WARN, 'START will ask for the disk when it needs a file.')
    else
      TuiKit.PutText(5, 22, TuiKit.A_WARN, 'The game will create it on the first save.');
    TuiKit.PutText(5, 23, TuiKit.A_WARN, 'Enter a folder that exists, or F5 for the default.');
  end else begin
    TuiKit.PutText(5, 21, TuiKit.A_HELP, 'A folder must already exist: Setup checks each path as it is entered');
    TuiKit.PutText(5, 22, TuiKit.A_HELP, 'and creates none. Pool of Radiance''s are POOL.CFG''s; the others are');
    TuiKit.PutText(5, 23, TuiKit.A_HELP, 'kept in POOLOPT.CFG for the later games'' ports.');
  end;
end;

{ Paths line on its row, highlighted when sel: a path START refuses red, a changed one white with a '*'. }
procedure DrawPathLine(line: Byte; sel: Boolean);
var
  row: Byte;
  attr: Byte;
  value: string;
begin
  row := PathRow(line);
  TuiKit.PutRun(3, row, TuiKit.A_TEXT, ' ', 76);
  if line mod 2 = 1 then
    TuiKit.PutText(7, row, TuiKit.A_TEXT, 'Data Path')
  else
    TuiKit.PutText(7, row, TuiKit.A_TEXT, 'Save Path');
  value := CutPath(PathOf(cfg, opts, line), FIELD_WIDTH - 1);
  attr := TuiKit.A_VALUE;
  if (line <= PATH_SAVE) and tooLong[line] then
    attr := TuiKit.A_BAD
  else if PathChanged(line) then begin
    attr := TuiKit.A_CHANGED;
    value := value + '*';
  end;
  TuiKit.PutText(PATH_COL, row, attr, value);
  if sel then
    TuiKit.Recolor(3, row, 76, TuiKit.A_HIGHLIGHT);
end;

procedure DrawPaths(sel: Byte);
const
  GAMES: array[1..4] of string[27] = ('Pool of Radiance', 'Curse of the Azure Bonds', 'Secret of the Silver Blades',
    'Pools of Darkness');
var
  g: Byte;
  line: Byte;
begin
  ClearPage;
  TuiKit.Box(2, 2, 79, 24, TuiKit.A_FRAME, 'Paths');
  TuiKit.Divider(2, 79, 20, TuiKit.A_FRAME);
  for g := 1 to 4 do
    TuiKit.PutText(5, 4 + (g - 1) * 4, TuiKit.A_FRAME, GAMES[g]);
  for line := 1 to PATH_LINES do
    DrawPathLine(line, line = sel);
  DrawPathNote(sel);
  TuiKit.KeyLine('~Up Dn~ Move  ~Enter~ Edit  ~F5~ Default  ~Esc~ Main Menu  ~F10~ Save and Exit');
end;

{ Edit Paths line in place, starting with character first (#0: the path as it is) until a path is accepted or Escape
  puts the old one back. A path is checked as it is accepted (CfgFile.CheckPath): one that is empty, holds a character
  no path may, is too long for DOS or is not an existing folder is refused with the reason, and the edit goes on with
  the text kept. A Pool data folder without the game's data is taken with a warning; a changed Pool save folder with a
  note that the saved games stay where they are. }
procedure EditPath(line: Byte; first: Char);
var
  text: string;
  full: string;
  key: Char;
  check: CfgFile.TPathCheck;
  lines: TuiKit.TLines;
  accepted: Boolean;
begin
  text := CutPath(PathOf(cfg, opts, line), 255);
  accepted := False;
  { the field in place of the highlight, its brackets on the page's own colour }
  DrawPathLine(line, False);
  repeat
    TuiKit.KeyLine('Type the folder   ~Lt Rt Home End Del Bksp~   ~Enter~ Accept   ~Esc~ Cancel');
    key := TuiKit.EditLine(PATH_COL, PathRow(line), FIELD_WIDTH, text, PATH_TYPED, first);
    first := #0;
    if key = C_KEYS.ENTER then begin
      check := CfgFile.CheckPath(text, full);
      case check of
{$IFDEF FPC}
        CfgFile.PATH_OK: if (line <> PATH_DATA) or GameDirs.HoldsData(NatFile.NativeName(full), GameDirs.POOL) then
                           accepted := True
                         else
                           ShowError('No Pool of Radiance data (GEO1.DAX) is in', CutPath(full, 38));
{$ELSE}
        CfgFile.PATH_OK: accepted := True;
{$ENDIF}
        CfgFile.PATH_EMPTY: ShowError('Please type the folder''s path.', '');
        CfgFile.PATH_BAD_CHAR: ShowError('A folder''s path cannot hold * ? " < > or |.', CutPath(full, 38));
        CfgFile.PATH_TOO_LONG: ShowError('This path is too long for DOS (' + StrUtil.NumStr(C_OPT.MAX_PATH_TEXT) +
                                         ' characters at most).', CutPath(full, 38));
      else
        ShowError('Please verify the directory exists.', CutPath(full, 38));
      end;
    end;
  until accepted or (key = C_KEYS.ESCAPE);
  if not accepted then Exit;
{$IFNDEF FPC}
  if (line = PATH_DATA) and not HasPoolData(full) then begin
    TuiKit.ClearLines(lines);
    TuiKit.AddLine(lines, 'No Pool of Radiance data (ITEMS, GEO1.DAX) is in', 0);
    TuiKit.AddLine(lines, '', 0);
    TuiKit.AddLine(lines, '  ' + CutPath(full, 54), TuiKit.A_POP_VALUE);
    TuiKit.AddLine(lines, '', 0);
    TuiKit.AddLine(lines, 'Setup takes it, but START will ask for the disk.', 0);
    TuiKit.Message('Warning', lines, TuiKit.STYLE_NOTICE, 64);
  end;
{$ENDIF}
  if (line = PATH_SAVE) and (full <> cfgRead.saveDir) and (full <> cfg.saveDir) then begin
    TuiKit.ClearLines(lines);
    TuiKit.AddLine(lines, 'Saved games stay in ' + CutPath(cfgRead.saveDir, 38), 0);
    TuiKit.AddLine(lines, 'Setup does not move them. The settings go with', 0);
    TuiKit.AddLine(lines, 'the new folder when you save.', 0);
    TuiKit.Message('Note', lines, TuiKit.STYLE_NOTICE, 64);
  end;
  SetPath(line, full);
end;

{ The Paths page (the four games' data and save folders) until Escape, or F10 saves and leaves. }
procedure PathsPage;
var
  sel: Byte;
  ch: Char;
  ext: Boolean;
  done: Boolean;
begin
  sel := PATH_DATA;
  DrawPaths(sel);
  done := False;
  repeat
    TuiKit.GetKey(ch, ext);
    if ext then begin
      TuiKit.MoveInList(ch, sel, PATH_LINES);
      case ch of
        C_KEYS.F5: SetPath(sel, DefaultPath(sel));
        C_KEYS.F10: begin
                      SaveAndLeave;
                      done := leave;
                    end;
      end;
    end
    else
      case ch of
        C_KEYS.ENTER: EditPath(sel, #0);
        C_KEYS.ESCAPE: done := True;
        '!'..'~': EditPath(sel, ch);
      end;
    if not done then
      DrawPaths(sel);
  until done;
end;

{ --- starting ---------------------------------------------------------------------------------------------------- }

{ POOL.CFG's path line, normalized as START would: too long for DOS, kept as it is and marked (SetPath). Under DOS in
  capitals, as CheckPath gives a path typed in, so the same folder typed again is no change. }
procedure NormalizeRead(line: Byte);
var
  full: string;
  ok: Boolean;
begin
  ok := CfgFile.NormalizePath(PathOf(cfg, opts, line), full);
{$IFNDEF FPC}
  full := CfgFile.Tidy(full);
{$ENDIF}
  SetPath(line, full);
end;

{ Read POOL.CFG (or start from the defaults without it) and then POOLOPT.CFG from the save folder it names. }
procedure ReadFiles;
var
  ok: Boolean;
begin
{$IFDEF FPC}
  { POOL.CFG in the writable folder, or until one is written there the data folder's (#1064) }
  ok := CfgFile.NormalizePath(GameDirs.writeFolder, homeDir);
  ok := CfgFile.NormalizePath(GameDirs.dataFolder, dataHome);
  if GameDirs.dataFolder = '' then
    dataHome := '';
  cfgName := GameDirs.writeFolder + C_OPT.CFG_NAME;
  cfgState := CfgFile.ReadPoolCfg(GameDirs.ReadName(C_OPT.CFG_NAME), cfg, notes);
{$ELSE}
  ok := CfgFile.NormalizePath('', homeDir);
  cfgName := FExpand(C_OPT.CFG_NAME);
  cfgState := CfgFile.ReadPoolCfg(C_OPT.CFG_NAME, cfg, notes);
{$ENDIF}
  CfgFile.PoolDefaults(cfgDefaults, homeDir);
  if cfgState in [CfgFile.CFG_MISSING, CfgFile.CFG_UNREADABLE] then
    cfg := cfgDefaults;
  { the defaults too, which in a folder too deep for DOS START would refuse }
  NormalizeRead(PATH_DATA);
  NormalizeRead(PATH_SAVE);
{$IFDEF FPC}
  { the folders as the native game takes them (GameBoot.NativeFolders) }
  SetPath(PATH_SAVE, CfgFile.NativeSaveFolder(cfg.dataDir, cfg.saveDir, homeDir));
  SetPath(PATH_DATA, dataHome);
{$ENDIF}
  cfgRead := cfg;
  optDir := cfg.saveDir;
  CfgFile.Defaults(defaults);
  opts := defaults;
  optState := CfgFile.ReadOptions(optDir, opts, optBad);
  optsRead := opts;
end;

{ The notice for a POOL.CFG that is missing, could not be read, or holds values START does not know. When START ran
  Setup for a damaged one, the notice starts by saying why. }
procedure ShowNotice;
const
  WHAT: array[1..C_OPT.CFG_LINES] of string[11] = ('video', 'sound', 'data path', 'save path', 'intro');
var
  lines: TuiKit.TLines;
  i: Byte;
  raw: string;
  reads: string;
begin
  TuiKit.ClearLines(lines);
  if fromStart and (cfgState in [CfgFile.CFG_UNREADABLE, CfgFile.CFG_FIXED]) then begin
    TuiKit.AddLine(lines, 'POOL.CFG was damaged, unreadable, or unparseable.', TuiKit.A_POP_VALUE);
    TuiKit.AddLine(lines, 'Please reconfigure the game.', TuiKit.A_POP_VALUE);
    TuiKit.AddLine(lines, '', 0);
  end;
  case cfgState of
    CfgFile.CFG_MISSING: begin
                           TuiKit.AddLine(lines, 'POOL.CFG was not found in ' + CutPath(homeDir, 30) + '.', 0);
                           TuiKit.AddLine(lines, '', 0);
{$IFDEF FPC}
                           TuiKit.AddLine(lines, 'Setup starts from the defaults: VGA, Digital Audio, the full',
                                          0);
{$ELSE}
                           TuiKit.AddLine(lines, 'Setup starts from the defaults: VGA, no sound, the full', 0);
{$ENDIF}
                           TuiKit.AddLine(lines, 'introduction, the data in this folder and the saves in', 0);
                           TuiKit.AddLine(lines, 'SAVE\ under it. Nothing is written until you save.', 0);
                         end;
    CfgFile.CFG_UNREADABLE: begin
                              TuiKit.AddLine(lines, 'POOL.CFG is in ' + CutPath(homeDir, 30) + ',', 0);
                              TuiKit.AddLine(lines, 'but it could not be read.', 0);
                              TuiKit.AddLine(lines, '', 0);
                              TuiKit.AddLine(lines, 'Setup shows the defaults, and will not write over a', 0);
                              TuiKit.AddLine(lines, 'file it could not read.', 0);
                            end;
    CfgFile.CFG_FIXED: begin
                         TuiKit.AddLine(lines, 'POOL.CFG holds values ' + GAME_PROG + ' does not know:', 0);
                         TuiKit.AddLine(lines, '', 0);
                         for i := 1 to notes.count do begin
                           if notes.items[i].missing then
                             raw := 'missing'
                           else
                             raw := '''' + notes.items[i].raw + '''';
                           case notes.items[i].line of
                             1: reads := GAME_PROG + ' reads it as ' + ChoiceName(HW_VIDEO, ChoiceOf(cfg, HW_VIDEO));
                             2: reads := GAME_PROG + ' reads it as none';
                             5: reads := GAME_PROG + ' reads it as short';
                           else
                             reads := GAME_PROG + ' uses this folder';
                           end;
                           TuiKit.AddLine(lines, '  ' + StrUtil.PadRight('Line ' + StrUtil.NumStr(notes.items[i].line) +
                                          ' (' + WHAT[notes.items[i].line] + ')', 21) + StrUtil.PadRight(raw, 15) +
                                          reads, TuiKit.A_POP_VALUE);
                         end;
                         TuiKit.AddLine(lines, '', 0);
                         TuiKit.AddLine(lines, 'Setup shows what ' + GAME_PROG + ' would use. Saving writes the', 0);
                         TuiKit.AddLine(lines, 'file back in the form ' + GAME_PROG + ' expects.', 0);
                       end;
  else
    Exit;
  end;
  ClearPage;
  TuiKit.KeyLine('Press any key');
  TuiKit.Message('Notice', lines, TuiKit.STYLE_NOTICE, 64);
end;

{ Leave by Escape: with changes, ask first whether to save them (Yes saves and leaves, No leaves with exit code 1,
  Cancel stays). }
procedure AskToLeave;
begin
  if not Unsaved then begin
    exitCode := 0;
    leave := True;
    Exit;
  end;
  TuiKit.KeyLine('~Lt Rt~ Move  ~Enter~ Choose  ~Y~ Yes  ~N~ No  ~Esc~ Cancel');
  case TuiKit.Ask('Exit', 'Save the changes before leaving?') of
    'Y': SaveAndLeave;
    'N': begin
           exitCode := 1;
           leave := True;
         end;
  end;
end;

{$IFDEF FPC}
{ The game's folders, as the game finds them (GameDirs.Settle) but without asking: of several copies the first, and
  with none no data folder and the player's own folder to write in. }
procedure FindFolders;
var
  hits: GameDirs.TCandidates;
  ask: Boolean;
begin
  if GameDirs.Settle(GameDirs.POOL, hits, ask) then Exit;
  if Length(hits) > 0 then
    GameDirs.Place(GameDirs.POOL, hits[0].path, False)
  else begin
    GameDirs.writeFolder := GameDirs.UserFolder(GameDirs.POOL, GameDirs.THIS_OS, GetUserDir);
    ForceDirectories(GameDirs.writeFolder);
  end;
end;
{$ENDIF}

{ The Main Menu until the program leaves. }
procedure MainMenu;
var
  sel: Byte;
  ch: Char;
  ext: Boolean;
  item: Byte;
begin
  sel := ITEM_HARDWARE;
  repeat
    DrawMain(sel);
    TuiKit.GetKey(ch, ext);
    item := 0;
    if ext then begin
      TuiKit.MoveInList(ch, sel, ITEMS);
      if ch = C_KEYS.F10 then
        item := ITEM_SAVE;
    end else
      case UpCase(ch) of
        C_KEYS.ENTER: item := sel;
        'H': item := ITEM_HARDWARE;
        'G': item := ITEM_SETTINGS;
        'P': item := ITEM_PATHS;
        'S': item := ITEM_SAVE;
        'X': item := ITEM_QUIT;
        C_KEYS.ESCAPE: AskToLeave;
      end;
    if item <> 0 then
      sel := item;
    case item of
      ITEM_HARDWARE: HardwarePage;
      ITEM_SETTINGS: SettingsPage;
      ITEM_PATHS: PathsPage;
      ITEM_SAVE: SaveAndLeave;
      ITEM_QUIT: begin
                   exitCode := Ord(Unsaved);
                   leave := True;
                 end;
    end;
  until leave;
end;

begin
{$IFDEF FPC}
  FindFolders;
{$ENDIF}
  fromStart := ParamStr(1) = C_OPT.SETUP_FROM_START;
  exitCode := 0;
  leave := False;
  TuiKit.Init;
  ReadFiles;
  ShowNotice;
  MainMenu;
  TuiKit.Done;
  Halt(exitCode);
end.

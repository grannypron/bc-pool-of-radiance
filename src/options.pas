{ The Settings screen and POOLOPT.CFG. The game's settings (speed, portraits, music and sound with the kinds of each
  that can be turned off on their own, Quick ending with the fight, quick-mode magic, the Companion Tools and their Clue
  Book notes) are global: POOLOPT.CFG in the save folder keeps them as KEY=VALUE lines, with the provisional data and
  save paths of the later Gold Box games, which only the configuration program will set. GameInit reads it at start-up,
  before the title music, and every change writes it back; a saved game no longer changes them. The screen has three
  pages (#835): the settings, the games' paths, and the system's details (video, sound device, build, data archives and
  memory). The combat log and its size (#841) are settings too, which only a combat log with a store (CbtLog.Usable)
  can change. POOLOPT.CFG is read and written through CfgFile, which the set-up program POOLCFG shares (#876): Collect
  and Apply are the one place the game's GameVars meet its TSettings. }
{$O+,F+,I-}
{$I COMPILER.INC}
unit Options;

interface

uses CfgFile;

{ Read POOLOPT.CFG from the save folder over the defaults GameInit has set, then apply the Sound setting. A missing or
  unreadable file, an unknown key or a value out of range leaves the default. }
procedure LoadOptions;

{ Write the settings to POOLOPT.CFG, keeping the lines whose keys this version does not know. The new file is written
  beside it as POOLOPT.CF$ (FileUtil.TempName) and put in its place, so a failed write leaves the old file, and the
  settings then hold for this session only. }
procedure SaveOptions;

{ Set the game's settings (GameVars) from s, and keep its later games' paths for POOLOPT.CFG. GameInit gives it
  CfgFile.Defaults at start-up. }
procedure Apply(var s: CfgFile.TSettings);

{ Show the Settings screen until Exit or Escape. Game, Paths and System on the bottom line show its pages. On the Game
  page Up and Down (also Home and End) move the highlight through the settings, wrapping at either end, past the Quick
  Mode heading; Enter, Left or Right turn the highlighted one over, at once. On the Game Speed and Log Lines lines Left
  and Right pick Slower or Faster (Less or More) instead, and Enter applies the one picked. Without a store for the
  combat log (CbtLog.Usable) its two lines are grey, Combat Log says it needs EMS, and the highlight passes them by. The
  Paths and System pages only show. Leaving writes POOLOPT.CFG when something changed. The caller redraws its own screen
  afterwards. }
procedure OptionsMenu;

implementation

uses {$IFDEF FPC}TpCompat, {$ENDIF}Crt, Types, C_KEYS, C_SOUND, C_DATA, C_OPT, GameVars, TextRend, Border, MenuCore,
  GameIo, SoundDrv, DaxIo, DataArc, GameDefs, VidOps, CbtLog, StrUtil;

{ BUILD_VERSION and BUILD_COMMIT: build.sh writes them from git before each build. }
{$I BUILDID.INC}

const
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
  { the settings as POOLOPT.CFG keeps them: the later games' paths, which only POOLCFG sets, and the rest as Collect
    last copied them from GameVars }
  cur: CfgFile.TSettings;
  { the settings the Game page passes by, while the screen is up: the combat log's two without a store for it
    (CbtLog.Usable) }
  unchangeable: CfgFile.TOptSet;

{ The GameVars.soundGroups bit of a sound setting, or musicGroups bit of a music setting; 0 for any other setting. }
function GroupBit(opt: Byte): Byte;
begin
  case opt of
    C_OPT.OPT_TITLE_MUSIC: GroupBit := C_SOUND.GROUP_TITLE_MUSIC;
    C_OPT.OPT_BATTLE_MUSIC: GroupBit := C_SOUND.GROUP_BATTLE_MUSIC;
    C_OPT.OPT_FOOTSTEPS: GroupBit := C_SOUND.GROUP_FOOTSTEPS;
    C_OPT.OPT_RANGED: GroupBit := C_SOUND.GROUP_RANGED;
    C_OPT.OPT_MELEE: GroupBit := C_SOUND.GROUP_MELEE;
    C_OPT.OPT_DEATH: GroupBit := C_SOUND.GROUP_DEATH;
    C_OPT.OPT_WALL: GroupBit := C_SOUND.GROUP_WALL;
    C_OPT.OPT_SPELLS: GroupBit := C_SOUND.GROUP_SPELL;
  else
    GroupBit := 0;
  end;
end;

{ The game's settings (GameVars) into s, its paths left as they are; each bit of the music and sound groups is a
  setting of its own. }
procedure Collect(var s: CfgFile.TSettings);
var
  opt: Byte;
begin
  s.speed := GameVars.gameDelay;
  s.logLines := GameVars.combatLogLines;
  for opt := C_OPT.OPT_FIRST_FLAG to C_OPT.OPT_LAST_FLAG do
    case opt of
      C_OPT.OPT_PORTRAITS_ALL: s.flags[opt] := GameVars.portraitsAll;
      C_OPT.OPT_MONSTERS: s.flags[opt] := GameVars.monsterPics;
      C_OPT.OPT_PORTRAITS: s.flags[opt] := GameVars.portraitsOn;
      C_OPT.OPT_MUSIC: s.flags[opt] := GameVars.musicOn;
      C_OPT.OPT_TITLE_MUSIC, C_OPT.OPT_BATTLE_MUSIC:
        s.flags[opt] := Ord(GameVars.musicGroups and Options.GroupBit(opt) <> 0);
      C_OPT.OPT_SOUND: s.flags[opt] := GameVars.soundOn;
      C_OPT.OPT_FOOTSTEPS..C_OPT.OPT_SPELLS: s.flags[opt] := Ord(GameVars.soundGroups and Options.GroupBit(opt) <> 0);
      C_OPT.OPT_QUICK: s.flags[opt] := GameVars.quickEnds;
      C_OPT.OPT_MAGIC: s.flags[opt] := GameVars.quickMagicOn;
      C_OPT.OPT_COMPANION: s.flags[opt] := GameVars.companionOn;
      C_OPT.OPT_CLUES: s.flags[opt] := GameVars.clueNotesOn;
      C_OPT.OPT_COMBAT_LOG: s.flags[opt] := GameVars.combatLogOn;
    end;
end;

procedure Apply(var s: CfgFile.TSettings);
var
  opt: Byte;
begin
  GameVars.gameDelay := s.speed;
  GameVars.combatLogLines := s.logLines;
  GameVars.musicGroups := 0;
  GameVars.soundGroups := 0;
  for opt := C_OPT.OPT_FIRST_FLAG to C_OPT.OPT_LAST_FLAG do
    case opt of
      C_OPT.OPT_PORTRAITS_ALL: GameVars.portraitsAll := s.flags[opt];
      C_OPT.OPT_MONSTERS: GameVars.monsterPics := s.flags[opt];
      C_OPT.OPT_PORTRAITS: GameVars.portraitsOn := s.flags[opt];
      C_OPT.OPT_MUSIC: GameVars.musicOn := s.flags[opt];
      C_OPT.OPT_TITLE_MUSIC, C_OPT.OPT_BATTLE_MUSIC:
        if s.flags[opt] <> 0 then
          GameVars.musicGroups := GameVars.musicGroups or Options.GroupBit(opt);
      C_OPT.OPT_SOUND: GameVars.soundOn := s.flags[opt];
      C_OPT.OPT_FOOTSTEPS..C_OPT.OPT_SPELLS:
        if s.flags[opt] <> 0 then
          GameVars.soundGroups := GameVars.soundGroups or Options.GroupBit(opt);
      C_OPT.OPT_QUICK: GameVars.quickEnds := s.flags[opt];
      C_OPT.OPT_MAGIC: GameVars.quickMagicOn := s.flags[opt];
      C_OPT.OPT_COMPANION: GameVars.companionOn := s.flags[opt];
      C_OPT.OPT_CLUES: GameVars.clueNotesOn := s.flags[opt];
      C_OPT.OPT_COMBAT_LOG: GameVars.combatLogOn := s.flags[opt];
    end;
  cur.paths := s.paths;
end;

{ The Game page row of setting opt: one a row from FIRST_ROW, the Quick Mode heading's row before OPT_QUICK. }
function SettingRow(opt: Byte): Byte;
begin
  SettingRow := FIRST_ROW + opt - 1 + Ord(opt >= C_OPT.OPT_QUICK);
end;

{ The value of setting opt as the screen shows it: Sound shows whether sound is on now, and Combat Log that it needs
  EMS when it has no store. }
function ShownValue(opt: Byte): Types.TStr20;
begin
  if opt = C_OPT.OPT_SOUND then
    ShownValue := CfgFile.OnOff(Ord(GameVars.soundMode <> C_SOUND.MODE_DISABLED))
  else if (opt = C_OPT.OPT_COMBAT_LOG) and not CbtLog.Usable then
    ShownValue := 'Needs EMS'
  else begin
    Options.Collect(cur);
    ShownValue := CfgFile.StoredValue(cur, opt);
  end;
end;

procedure LoadOptions;
var
  bad: Byte;
  found: CfgFile.TReadResult;
begin
  Options.Collect(cur);
  found := CfgFile.ReadOptions(GameVars.saveDirectory, cur, bad);
  Options.Apply(cur);
  GameIo.SetSound(GameVars.soundOn <> 0);
  GameIo.saveSettings := Options.SaveOptions;
end;

procedure SaveOptions;
var
  written: Boolean;
begin
  Options.Collect(cur);
  written := CfgFile.WriteOptions(GameVars.saveDirectory, cur);
end;

{ Draw setting opt on its row, its label and value in color, or in OFF_COLOR when the page cannot change it. A stepping
  line's value is its two choices; while it is highlighted (color TITLE_COLOR) the choice not picked stays LINE_COLOR. }
procedure DrawSetting(opt: Byte; color: Byte);
var
  row: Byte;
  leftColor: Byte;
  rightColor: Byte;
  left: CfgFile.TName;
  right: CfgFile.TName;
begin
  if (opt < 1) or (opt > C_OPT.OPT_COUNT) then Exit;
  if opt in unchangeable then
    color := OFF_COLOR;
  row := Options.SettingRow(opt);
  TextRend.PrintSpaces(LABEL_COL, row, Black, RIGHT_COL - LABEL_COL + 1);
  Options.Collect(cur);
  TextRend.DisplayString(LABEL_COL, row, color, CfgFile.SettingLabel(cur, opt));
  if CfgFile.StepNames(opt, left, right) then begin
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
      for disk := 1 to Types.LAST_DISK do
        if not found then
          found := DataArc.FileLength(GameVars.gameDir + DataArc.SourceFile(fam, disk)) >= 0;
      if found then
        Inc(present);
    end;
end;

{ The Game page: every setting, setting sel highlighted, and the Quick Mode heading. }
procedure DrawGamePage(sel: Byte);
var
  opt: Byte;
begin
  for opt := 1 to C_OPT.OPT_COUNT do
    if opt = sel then
      Options.DrawSetting(opt, TITLE_COLOR)
    else
      Options.DrawSetting(opt, LINE_COLOR);
  TextRend.DisplayString(LABEL_COL, Options.SettingRow(C_OPT.OPT_QUICK) - 1, LINE_COLOR, 'Quick Mode');
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
      dataPath := cur.paths[2 * g - 3];
      savePath := cur.paths[2 * g - 2];
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
  Options.DrawInfo(FIRST_ROW + 5, 'Data', 'V' + StrUtil.Grouped(C_DATA.VERSION));
  Options.DrawInfo(FIRST_ROW + 6, 'Merged Files', StrUtil.Grouped(merged) + '/' + StrUtil.Grouped(present));
  Options.DrawInfo(FIRST_ROW + 8, 'Free Memory', StrUtil.Grouped(MemAvail));
  Options.DrawInfo(FIRST_ROW + 9, 'Largest Block', StrUtil.Grouped(MaxAvail));
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

{ Change setting opt, as Enter does (CfgFile.ChangeSetting). The speed takes the speed line's choice: Slower raises
  gameDelay (the game's text and animation delays grow with it) and Faster lowers it. Log Lines takes its line's choice
  too; the next fight's log has the new size. Every other setting turns over. A music setting turned off ends the tune
  it covers now; Sound goes through GameIo.SetSound, as Ctrl-S does. }
procedure ChangeSetting(opt: Byte);
begin
  if opt = C_OPT.OPT_SOUND then
    GameIo.SetSound(GameVars.soundMode = C_SOUND.MODE_DISABLED)
  else begin
    Options.Collect(cur);
    CfgFile.ChangeSetting(cur, opt, stepChoice = CHOICE_RIGHT);
    Options.Apply(cur);
    if opt in [C_OPT.OPT_MUSIC, C_OPT.OPT_TITLE_MUSIC, C_OPT.OPT_BATTLE_MUSIC] then
      SoundDrv.ApplyMusicSettings;
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
    left: CfgFile.TName;
    right: CfgFile.TName;
  begin
    if CfgFile.StepNames(sel, left, right) then begin
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
  if CbtLog.Usable then
    unchangeable := []
  else
    unchangeable := [C_OPT.OPT_COMBAT_LOG, C_OPT.OPT_LOG_LINES];
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
          C_KEYS.UP, C_KEYS.HOME: MoveTo(CfgFile.NextSetting(sel, False, unchangeable));
          C_KEYS.DOWN, C_KEYS.END_KEY: MoveTo(CfgFile.NextSetting(sel, True, unchangeable));
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
      if sel <> C_OPT.OPT_SOUND then
        Options.DrawSetting(C_OPT.OPT_SOUND, LINE_COLOR);
      Options.DrawSetting(sel, TITLE_COLOR);
    end;
  until not ext and (ch in [C_KEYS.NONE, 'E']);
  if changed then
    Options.SaveOptions;
  GameVars.horizChoice := savedChoice;
end;

end.

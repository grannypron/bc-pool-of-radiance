{ The Settings screen and POOLOPT.CFG. The game's settings (speed, monster pictures, portraits, music, sound, Quick
  ending with the fight, quick-mode magic and the Companion Tools) are global: POOLOPT.CFG in the save folder keeps them
  as KEY=VALUE lines. GameInit reads it at start-up, before the title music, and every change writes it back; a saved
  game no longer changes them. The screen lists the settings above what the game runs with from POOL.CFG and a few lines
  about the build, the data archives and memory. The NORAND and STING notes, when they are given, stand at the right of
  the last settings rows. }
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

{ Show the Settings screen until Exit or Escape. Up and Down (also Home and End) move the highlight through the
  settings, wrapping at either end; Enter, Left or Right turn the highlighted one over, at once. On the speed line Left
  and Right pick Slower or Faster instead, and Enter applies the one picked. Leaving writes POOLOPT.CFG when something
  changed. The caller redraws its own screen afterwards. }
procedure OptionsMenu;

implementation

uses {$IFDEF FPC}TpCompat, {$ENDIF}Crt, Types, C_Keys, C_Sound, C_DATA, GDVars, TextRend, Border, MenuCore, GameIo,
  SoundDrv, DaxIo, DataArc, GDConsts, VidOps, FileUtil{$IFDEF FPC}, NatFile{$ENDIF};

{ BUILD_VERSION and BUILD_COMMIT: build.sh writes them from git before each build. }
{$I BUILDID.INC}

const
  CFG_NAME = 'POOLOPT.CFG';
  { the most lines read from POOLOPT.CFG; anything after them is ignored, and dropped when the file is written }
  MAX_LINES = 100;
  { The settings, in the screen's order. }
  OPT_SPEED = 1;
  OPT_MONSTERS = 2;
  OPT_PORTRAITS = 3;
  OPT_MUSIC = 4;
  OPT_SOUND = 5;
  OPT_QUICK = 6;
  OPT_MAGIC = 7;
  OPT_COMPANION = 8;
  OPT_COUNT = 8;
  { the slowest game speed; 0 is the fastest }
  SLOWEST = 9;
  { The speed line's two choices, by speedChoice. }
  CHOICE_SLOWER = 0;
  CHOICE_FASTER = 1;
  { Two framed boxes sharing border row SPLIT_ROW. The upper holds, after a blank row, the settings, the last against
    the border; the lower holds, after a blank row, POOL.CFG's values, a blank row, the build and memory lines and a
    blank last row. The notes are right-aligned to RIGHT_COL on the settings' last rows, from the bottom up. }
  LEFT_COL = 1;
  RIGHT_COL = 38;
  UPPER_TOP = 1;
  SETTINGS_TOP = UPPER_TOP + 1;
  SETTINGS_BOTTOM = SETTINGS_TOP + OPT_COUNT - 1;
  SPLIT_ROW = SETTINGS_BOTTOM + 1;
  CFG_TOP = SPLIT_ROW + 2;
  CFG_BOTTOM = CFG_TOP + 3;
  INFO_TOP = CFG_BOTTOM + 2;
  LOWER_BOTTOM = 22;
  LABEL_COL = 2;
  SETTING_COL = 24;
  { the speed line's Faster, after Slower and a space }
  FASTER_COL = SETTING_COL + 7;
  INFO_COL = 16;
  { the display-only lines' colour, apart from the settings' LightGreen and the highlight's White }
  INFO_COLOR = Cyan;
  NOTE_COLOR = Yellow;
  { the most notes: STING and NORAND }
  NOTE_COUNT = 2;

var
  { the speed line's choice, CHOICE_SLOWER or CHOICE_FASTER, while the screen is up }
  speedChoice: Byte;

{ The key of setting opt in POOLOPT.CFG. }
function KeyName(opt: Byte): Types.TStr20;
begin
  case opt of
    OPT_SPEED: KeyName := 'SPEED';
    OPT_MONSTERS: KeyName := 'MONSTERS';
    OPT_PORTRAITS: KeyName := 'PORTRAITS';
    OPT_MUSIC: KeyName := 'MUSIC';
    OPT_SOUND: KeyName := 'SOUND';
    OPT_QUICK: KeyName := 'AUTOENDQUICK';
    OPT_MAGIC: KeyName := 'QUICKMAGIC';
    OPT_COMPANION: KeyName := 'COMPANION';
  else
    KeyName := '';
  end;
end;

{ The label of setting opt on the screen. }
function SettingLabel(opt: Byte): Types.TStr40;
begin
  case opt of
    OPT_SPEED: SettingLabel := 'Game Speed (' + Chr(Ord('0') + GDVars.gameDelay mod (SLOWEST + 1)) + ')';
    OPT_MONSTERS: SettingLabel := 'Monster Pictures';
    OPT_PORTRAITS: SettingLabel := 'Character Portraits';
    OPT_MUSIC: SettingLabel := 'Music';
    OPT_SOUND: SettingLabel := 'Sound';
    OPT_QUICK: SettingLabel := 'Auto End Quick Mode';
    OPT_MAGIC: SettingLabel := 'Quick Mode Magic';
    OPT_COMPANION: SettingLabel := 'Companion Tools';
  else
    SettingLabel := '';
  end;
end;

{ ON for a nonzero flag, OFF for zero. }
function OnOff(flag: Byte): Types.TStr20;
begin
  if flag <> 0 then
    OnOff := 'ON'
  else
    OnOff := 'OFF';
end;

{ The value of setting opt as POOLOPT.CFG keeps it. Sound is the setting, which stays as it was when POOL.CFG names no
  sound device. }
function StoredValue(opt: Byte): Types.TStr20;
begin
  case opt of
    OPT_SPEED: StoredValue := Chr(Ord('0') + GDVars.gameDelay mod (SLOWEST + 1));
    OPT_MONSTERS: StoredValue := Options.OnOff(GDVars.monsterPics);
    OPT_PORTRAITS: StoredValue := Options.OnOff(GDVars.portraitsOn);
    OPT_MUSIC: StoredValue := Options.OnOff(GDVars.musicOn);
    OPT_SOUND: StoredValue := Options.OnOff(GDVars.soundOn);
    OPT_QUICK: StoredValue := Options.OnOff(GDVars.quickEnds);
    OPT_MAGIC: StoredValue := Options.OnOff(GDVars.quickMagicOn);
    OPT_COMPANION: StoredValue := Options.OnOff(GDVars.companionOn);
  else
    StoredValue := '';
  end;
end;

{ The value of setting opt as the screen shows it: Sound shows whether sound is on now. }
function ShownValue(opt: Byte): Types.TStr20;
begin
  if opt = OPT_SOUND then
    ShownValue := Options.OnOff(Ord(GDVars.soundMode <> C_Sound.MODE_DISABLED))
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

{ The setting whose key line names before its '=', or 0 for none. }
function KeyOf(line: string): Byte;
var
  eq: Byte;
  key: string;
  opt: Byte;
begin
  KeyOf := 0;
  eq := Pos('=', line);
  if eq = 0 then Exit;
  key := Options.Tidy(Copy(line, 1, eq - 1));
  for opt := 1 to OPT_COUNT do
    if key = Options.KeyName(opt) then
      KeyOf := opt;
end;

{ Set setting opt from value (tidied): a digit 0..9 for the speed, ON or OFF (or 1 or 0) for the others. Any other value
  leaves the setting as it is. }
procedure ReadValue(opt: Byte; value: string);
var
  flag: Byte;
begin
  if opt = OPT_SPEED then begin
    if (Length(value) = 1) and (value[1] in ['0'..'9']) then
      GDVars.gameDelay := Ord(value[1]) - Ord('0');
    Exit;
  end;
  if (value = 'ON') or (value = '1') then
    flag := 1
  else if (value = 'OFF') or (value = '0') then
    flag := 0
  else
    Exit;
  case opt of
    OPT_MONSTERS: GDVars.monsterPics := flag;
    OPT_PORTRAITS: GDVars.portraitsOn := flag;
    OPT_MUSIC: GDVars.musicOn := flag;
    OPT_SOUND: GDVars.soundOn := flag;
    OPT_QUICK: GDVars.quickEnds := flag;
    OPT_MAGIC: GDVars.quickMagicOn := flag;
    OPT_COMPANION: GDVars.companionOn := flag;
  end;
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
  Assign(f, GDVars.dsSaveDirectory + CFG_NAME);
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
  GameIo.SetSound(GDVars.soundOn <> 0);
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
  Assign(newFile, FileUtil.TempName(GDVars.dsSaveDirectory + CFG_NAME));
  Rewrite(newFile);
  if IOResult <> 0 then Exit;
  for opt := 1 to OPT_COUNT do
    WriteLn(newFile, Options.KeyName(opt), '=', Options.StoredValue(opt));
  ok := IOResult = 0;
  Assign(oldFile, GDVars.dsSaveDirectory + CFG_NAME);
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
    ok := FileUtil.PutInPlace(GDVars.dsSaveDirectory + CFG_NAME)
  else
    FileUtil.DeleteFile(FileUtil.TempName(GDVars.dsSaveDirectory + CFG_NAME));
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

{ The note shown at the right of settings row row, or '' for none: the active notes stacked from SETTINGS_BOTTOM up,
  STING lowest and NORAND above it. }
function NoteOnRow(row: Byte): Types.TStr20;
var
  notes: array[1..NOTE_COUNT] of Types.TStr20;
  n: Byte;
begin
  n := 0;
  if GDVars.stingArg then begin
    Inc(n);
    notes[n] := 'STING ';
  end;
  if ParamStr(2) = 'NORAND' then begin
    Inc(n);
    notes[n] := 'NORAND ';
  end;
  NoteOnRow := '';
  if (row <= SETTINGS_BOTTOM) and (SETTINGS_BOTTOM - row < n) then
    NoteOnRow := notes[SETTINGS_BOTTOM - row + 1];
end;

{ Draw setting opt on its row, its label and value in color, then the row's note, if any. The speed line's value is its
  two choices; while it is highlighted (color White) the choice not picked stays LightGreen. }
procedure DrawSetting(opt: Byte; color: Byte);
var
  row: Byte;
  slowerColor: Byte;
  fasterColor: Byte;
  note: Types.TStr20;
begin
  if (opt < 1) or (opt > OPT_COUNT) then Exit;
  row := SETTINGS_TOP + opt - 1;
  TextRend.PrintSpaces(LABEL_COL, row, Black, RIGHT_COL - LABEL_COL + 1);
  TextRend.DisplayString(LABEL_COL, row, color, Options.SettingLabel(opt));
  if opt = OPT_SPEED then begin
    slowerColor := color;
    fasterColor := color;
    if color = White then
      if speedChoice = CHOICE_FASTER then
        slowerColor := LightGreen
      else
        fasterColor := LightGreen;
    TextRend.DisplayString(SETTING_COL, row, slowerColor, 'Slower');
    TextRend.DisplayString(FASTER_COL, row, fasterColor, 'Faster');
  end else
    TextRend.DisplayString(SETTING_COL, row, color, Options.ShownValue(opt));
  note := Options.NoteOnRow(row);
  TextRend.DisplayString(RIGHT_COL + 1 - Length(note), row, NOTE_COLOR, note);
end;

{ Draw a display-only line on row: its label, and value cut to the space after INFO_COL; a value too long keeps its end,
  after '...', as a path's last folders say the most. The game font has no backslash (that character is a solid block),
  so a path shows '/' in its place. }
procedure DrawInfo(row: Byte; lab, value: string);
const
  WIDTH = RIGHT_COL - INFO_COL + 1;
var
  i: Byte;
begin
  for i := 1 to Length(value) do
    if value[i] = '\' then
      value[i] := '/';
  if Length(value) > WIDTH then
    value := '...' + Copy(value, Length(value) - (WIDTH - 3) + 1, WIDTH - 3);
  TextRend.DisplayString(LABEL_COL, row, INFO_COLOR, Copy(lab, 1, INFO_COL - LABEL_COL - 1));
  TextRend.PrintSpaces(INFO_COL, row, Black, WIDTH);
  TextRend.DisplayString(INFO_COL, row, INFO_COLOR, value);
end;

{ The data archives' line: C_DATA.VERSION, then how many of the families with files here read their merged archive. }
function DataLine: string;
var
  fam: Byte;
  disk: Byte;
  merged: Byte;
  present: Byte;
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
          found := DataArc.FileLength(GDVars.gameDir + DataArc.SourceName(fam, disk) + '.DAX') >= 0;
      if found then
        Inc(present);
    end;
  DataLine := 'V' + Options.Grouped(C_DATA.VERSION) + '  Merged ' + Options.Grouped(merged) + '/' +
              Options.Grouped(present);
end;

{ Draw the display-only lines: POOL.CFG's values as the game runs with them, the build, the data archives and memory. }
procedure DrawInfoLines;
begin
  Options.DrawInfo(CFG_TOP, 'Video', VidOps.ModeName);
  Options.DrawInfo(CFG_TOP + 1, 'Sound Device', GDVars.sound.name);
  Options.DrawInfo(CFG_TOP + 2, 'Data Path', GDVars.gameDir);
  Options.DrawInfo(CFG_TOP + 3, 'Save Path', GDVars.dsSaveDirectory);
  Options.DrawInfo(INFO_TOP, 'Version', GDConsts.GAME_VERSION);
  Options.DrawInfo(INFO_TOP + 1, 'Commit', BUILD_COMMIT);
  Options.DrawInfo(INFO_TOP + 2, 'Data', Options.DataLine);
  Options.DrawInfo(INFO_TOP + 3, 'Free Memory', Options.Grouped(MemAvail));
  Options.DrawInfo(INFO_TOP + 4, 'Largest Block', Options.Grouped(MaxAvail));
end;

{ Change setting opt, as Enter does. The speed takes the speed line's choice, a step within 0..SLOWEST: Slower raises
  gameDelay (the game's text and animation delays grow with it) and Faster lowers it. Every other setting turns over.
  Music off ends the music now; Sound goes through GameIo.SetSound, as Ctrl-S does. }
procedure ChangeSetting(opt: Byte);
begin
  case opt of
    OPT_SPEED: if speedChoice = CHOICE_SLOWER then begin
                 if GDVars.gameDelay < SLOWEST then
                   Inc(GDVars.gameDelay);
               end else if GDVars.gameDelay > 0 then
                 Dec(GDVars.gameDelay);
    OPT_MONSTERS: GDVars.monsterPics := Ord(GDVars.monsterPics = 0);
    OPT_PORTRAITS: GDVars.portraitsOn := Ord(GDVars.portraitsOn = 0);
    OPT_MUSIC: begin
                 GDVars.musicOn := Ord(GDVars.musicOn = 0);
                 if GDVars.musicOn = 0 then
                   SoundDrv.StopMusic;
               end;
    OPT_SOUND: GameIo.SetSound(GDVars.soundMode = C_Sound.MODE_DISABLED);
    OPT_QUICK: GDVars.quickEnds := Ord(GDVars.quickEnds = 0);
    OPT_MAGIC: GDVars.quickMagicOn := Ord(GDVars.quickMagicOn = 0);
    OPT_COMPANION: GDVars.companionOn := Ord(GDVars.companionOn = 0);
  end;
end;

procedure OptionsMenu;
var
  sel: Byte;
  opt: Byte;
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
    Options.DrawSetting(sel, LightGreen);
    sel := n;
    Options.DrawSetting(sel, White);
  end;

  { Turn setting sel over, or on the speed line pick choice. }
  procedure Arrow(choice: Byte);
  begin
    if sel = OPT_SPEED then begin
      speedChoice := choice;
      Options.DrawSetting(sel, White);
    end else begin
      Options.ChangeSetting(sel);
      touched := True;
    end;
  end;

begin
  savedChoice := GDVars.horizChoice;
  sel := 1;
  speedChoice := CHOICE_SLOWER;
  changed := False;
  { the upper box first, so the gold corners stay where the borders meet }
  Border.ClearBox(0, 0, 39, 23);
  Border.DrawBorder(LEFT_COL, UPPER_TOP, RIGHT_COL, SPLIT_ROW - 1, 0);
  Border.DrawBorder(LEFT_COL, SPLIT_ROW + 1, RIGHT_COL, LOWER_BOTTOM, 0);
  for opt := 1 to OPT_COUNT do
    if opt = sel then
      Options.DrawSetting(opt, White)
    else
      Options.DrawSetting(opt, LightGreen);
  Options.DrawInfoLines;
  repeat
    { Ctrl-S on the bottom line turns the sound over too }
    soundState := GDVars.soundMode;
    touched := False;
    GDVars.horizChoice := 1;
    MenuCore.arrowsToCaller := True;
    MenuCore.enterToCaller := True;
    ch := MenuCore.MenuHorizontal('Settings: ', 'Exit', LightMagenta, LightGreen, White, True, False, ext);
    if ext then
      case ch of
        C_Keys.UP, C_Keys.HOME: if sel > 1 then
                                  MoveTo(sel - 1)
                                else
                                  MoveTo(OPT_COUNT);
        C_Keys.DOWN, C_Keys.END_KEY: if sel < OPT_COUNT then
                                       MoveTo(sel + 1)
                                     else
                                       MoveTo(1);
        C_Keys.LEFT: Arrow(CHOICE_SLOWER);
        C_Keys.RIGHT: Arrow(CHOICE_FASTER);
      end
    else if ch = C_Keys.ENTER then begin
      Options.ChangeSetting(sel);
      touched := True;
    end;
    if touched then
      changed := True;
    if touched or (GDVars.soundMode <> soundState) then begin
      if sel <> OPT_SOUND then
        Options.DrawSetting(OPT_SOUND, LightGreen);
      Options.DrawSetting(sel, White);
    end;
  until not ext and (ch in [C_Keys.NONE, 'E']);
  if changed then
    Options.SaveOptions;
  GDVars.horizChoice := savedChoice;
end;

end.

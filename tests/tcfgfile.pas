{ Tests CfgFile defaults, POOLOPT.CFG parsing and safe writes, POOL.CFG
  compatibility with START, and path validation (#876). Includes unknown lines,
  short files, failed writes, directory creation, native separators, and the
  native save directory (#894, #1064, #1067). }
{$I COMPILER.INC}
program TCfgFile;

uses Dos, C_OPT, FileUtil, CfgFile, TestKit;

const
  CRLF = #13#10;
  DIR_NAME = 'TCFGDIR';
  { a save folder not there yet, and one in it (#1067), in the system's separators: natively MakeFolder splits on a
    slash as on a backslash }
{$IFDEF FPC}
  SEP = '/';
{$ELSE}
  SEP = '\';
{$ENDIF}
  NEW_DIR = 'TCFGNEW';
  NEW_SUB = 'SUB';
  NEW_PATH = NEW_DIR + SEP + NEW_SUB + SEP;
  FILE_NAME = 'TCFG.TMP';
  POOL_NAME = 'TCFGPOOL.CFG';

var
  s: CfgFile.TSettings;
  t: CfgFile.TSettings;
  c: CfgFile.TPoolCfg;
  notes: CfgFile.TCfgNotes;
  bad: Byte;
  opt: Byte;
  skip: CfgFile.TOptSet;
  i: Byte;
  cur: string;
  full: string;
  body: string;
  ioRes: Integer;
  { a file's bytes, to compare with another's }
  bytes: array[1..1024] of Char;
  byteCount: Word;

{ Write body as file name, as it is: True when it was written. }
function PutFile(name: FileUtil.TPathName; body: string): Boolean;
var
  g: file;
  ok: Boolean;
begin
  ok := FileUtil.RewriteTemp(g, name);
  if ok then begin
    FileUtil.WriteChecked(g, body[1], Length(body), ok);
    ok := FileUtil.CloseTemp(g, name, ok) and FileUtil.PutInPlace(name);
  end;
  PutFile := ok;
end;

{ File name's bytes (its first 255), or '?' when it does not read. }
function FileText(name: FileUtil.TPathName): string;
var
  g: file;
  n: Word;
  body: string;
begin
  FileText := '?';
  if not FileUtil.OpenReadOnly(g, name) then Exit;
  BlockRead(g, body[1], 255, n);
  body[0] := Chr(n);
  Close(g);
  ioRes := IOResult;
  FileText := body;
end;

{ The number of the first line of file name that is s, or 0. }
function LineNo(name: FileUtil.TPathName; s: string): Integer;
var
  g: Text;
  line: string;
  n: Integer;
  found: Boolean;
begin
  LineNo := 0;
  Assign(g, name);
  Reset(g);
  if IOResult <> 0 then Exit;
  n := 0;
  found := False;
  while not found and not Eof(g) and (IOResult = 0) do begin
    ReadLn(g, line);
    Inc(n);
    found := line = s;
  end;
  if found then
    LineNo := n;
  Close(g);
  ioRes := IOResult;
end;

{ Keep file name's bytes (KeepBytes), or say whether they are the ones kept (SameBytes). }
procedure KeepBytes(name: FileUtil.TPathName);
var
  g: file;
begin
  byteCount := 0;
  if not FileUtil.OpenReadOnly(g, name) then Exit;
  BlockRead(g, bytes, SizeOf(bytes), byteCount);
  Close(g);
  ioRes := IOResult;
end;

function SameBytes(name: FileUtil.TPathName): Boolean;
var
  g: file;
  other: array[1..1024] of Char;
  n: Word;
  i: Word;
  same: Boolean;
begin
  SameBytes := False;
  if not FileUtil.OpenReadOnly(g, name) then Exit;
  BlockRead(g, other, SizeOf(other), n);
  Close(g);
  ioRes := IOResult;
  same := (n = byteCount) and (n > 0);
  for i := 1 to n do
    if same and (other[i] <> bytes[i]) then
      same := False;
  SameBytes := same;
end;

{ Read a POOLOPT.CFG holding body over the defaults into s. }
function ReadText(body: string): CfgFile.TReadResult;
begin
  TestKit.Check(PutFile(C_OPT.OPT_NAME, body), 'POOLOPT.CFG is written for the test');
  CfgFile.Defaults(s);
  ReadText := CfgFile.ReadOptions('', s, bad);
end;

{ Read a POOL.CFG holding body into c and notes. }
function ReadPool(body: string): CfgFile.TReadResult;
begin
  TestKit.Check(PutFile(POOL_NAME, body), 'POOL.CFG is written for the test');
  ReadPool := CfgFile.ReadPoolCfg(POOL_NAME, c, notes);
end;

begin
  TestKit.Start('TCFGFILE');

  { the defaults are what GameInit set before #876 }
  CfgFile.Defaults(s);
  TestKit.CheckEqualsL(1, s.speed, 'the default speed is 1');
  TestKit.CheckEqualsL(50, s.logLines, 'the default log keeps 50 lines');
  for opt := C_OPT.OPT_FIRST_FLAG to C_OPT.OPT_LAST_FLAG do
    if opt in [C_OPT.OPT_CONSOLIDATE, C_OPT.OPT_MAGIC, C_OPT.OPT_COMPANION, C_OPT.OPT_TRAIN_ANYWHERE,
               C_OPT.OPT_FIX_SCROLLS..C_OPT.OPT_FIX_HEAL, C_OPT.OPT_MINIMAP] then
      TestKit.CheckEqualsL(0, CfgFile.Flag(s, opt), CfgFile.KeyName(opt) + ' is off by default')
    else
      TestKit.CheckEqualsL(1, CfgFile.Flag(s, opt), CfgFile.KeyName(opt) + ' is on by default');
  TestKit.CheckEqualsS('Game Speed (1)', CfgFile.SettingLabel(s, C_OPT.OPT_SPEED), 'the speed''s label');
  TestKit.CheckEqualsS('  Log Lines (50)', CfgFile.SettingLabel(s, C_OPT.OPT_LOG_LINES), 'the log lines'' label');
  TestKit.CheckEqualsS('', s.advised, 'no version advised by default (#1173)');
  TestKit.CheckEqualsS('ADVISED', CfgFile.KeyName(C_OPT.KEY_COUNT), 'the last key, the version advised');
  TestKit.CheckEqualsL(C_OPT.OPT_COUNT + 1, C_OPT.KEY_ADVISED,
                       'right after the settings: no later games'' paths (#1177)');
  TestKit.CheckEqualsL(0, CfgFile.KeyOf('CURSEDATA=C:\CURSE\'), 'CURSEDATA is no key now');

  { keys and values }
  TestKit.CheckEqualsS('a B', CfgFile.Trim(#9' a B '#9), 'Trim takes spaces and tabs off both ends, keeping case');
  TestKit.CheckEqualsS('A B', CfgFile.Tidy(#9' a B '#9), 'Tidy trims and capitalizes');
  TestKit.CheckEqualsS('', CfgFile.Trim(' '#9' '), 'a blank line trims to nothing');
  TestKit.CheckEqualsL(C_OPT.OPT_SPEED, CfgFile.KeyOf(' speed'#9'= 3'), 'a key in lower case, spaced');
  TestKit.CheckEqualsL(0, CfgFile.KeyOf('SPEED 3'), 'a line without = has no key');
  TestKit.CheckEqualsL(0, CfgFile.KeyOf('SPEEDS=3'), 'an unknown key');
  TestKit.CheckEqualsL(C_OPT.OPT_SPEED, CfgFile.NextSetting(C_OPT.OPT_LOG_LINES, True, []), 'Down wraps');
  TestKit.CheckEqualsL(C_OPT.OPT_MAGIC, CfgFile.NextSetting(C_OPT.OPT_SPEED, False,
                       [C_OPT.OPT_GEAR..C_OPT.OPT_LOG_LINES]), 'Up wraps past the settings skipped');

  { the Game, Sound (#1088) and Camp pages (#1119, #1129) }
  TestKit.Check((CfgFile.SettingPage(C_OPT.OPT_MUSIC) = C_OPT.OPT_PAGE_SOUND) and
                (CfgFile.SettingPage(C_OPT.OPT_SPELLS) = C_OPT.OPT_PAGE_SOUND),
                'the music and the sound effects are the Sound page''s');
  TestKit.Check((CfgFile.SettingPage(C_OPT.OPT_AUTO_JOIN) = C_OPT.OPT_PAGE_GAME) and
                (CfgFile.SettingPage(C_OPT.OPT_NONHUMAN_CAP) = C_OPT.OPT_PAGE_GAME) and
                (CfgFile.SettingPage(C_OPT.OPT_CLUES) = C_OPT.OPT_PAGE_GAME),
                'Auto Join, Non-Human Level Cap and the Clue Book notes are the Game page''s');
  TestKit.Check((CfgFile.SettingPage(C_OPT.OPT_QUICK) = C_OPT.OPT_PAGE_COMBAT) and
                (CfgFile.SettingPage(C_OPT.OPT_AIM) = C_OPT.OPT_PAGE_COMBAT) and
                (CfgFile.SettingPage(C_OPT.OPT_RETRIEVE) = C_OPT.OPT_PAGE_COMBAT) and
                (CfgFile.SettingPage(C_OPT.OPT_MINIMAP) = C_OPT.OPT_PAGE_COMBAT) and
                (CfgFile.SettingPage(C_OPT.OPT_LOG_LINES) = C_OPT.OPT_PAGE_COMBAT),
                'Quick Mode, Aim Cycles, Retrieve Thrown, the Minimap and the combat log are the Combat page''s');
  bad := 0;
  for opt := 2 to C_OPT.OPT_COUNT do
    if CfgFile.SettingPage(opt) < CfgFile.SettingPage(opt - 1) then
      Inc(bad);
  TestKit.CheckEqualsL(0, bad, 'each page''s settings are one run of numbers, in page order (#1180)');
  TestKit.CheckEqualsL(C_OPT.OPT_PAGE_COMBAT, CfgFile.SettingPage(C_OPT.OPT_COUNT),
                       'the Combat page''s run is the last');
  TestKit.Check((CfgFile.SettingPage(C_OPT.OPT_AUTO_MEMORIZE) = C_OPT.OPT_PAGE_CAMP) and
                (CfgFile.SettingPage(C_OPT.OPT_FIX_HEAL) = C_OPT.OPT_PAGE_CAMP),
                'Auto Memorize and the Fix settings are the Camp page''s');
  TestKit.CheckEqualsL(0, CfgFile.SettingLine(C_OPT.OPT_SPEED), 'the Game page starts with the speed');
  TestKit.CheckEqualsL(4, CfgFile.SettingLine(C_OPT.OPT_AUTO_JOIN), 'Auto Join after the portraits');
  TestKit.CheckEqualsL(5, CfgFile.SettingLine(C_OPT.OPT_CONSOLIDATE), 'Consolidate Coin after Auto Join (#1179)');
  TestKit.CheckEqualsL(6, CfgFile.SettingLine(C_OPT.OPT_JOURNAL), 'the Journal after it (#1090)');
  TestKit.CheckEqualsL(7, CfgFile.SettingLine(C_OPT.OPT_NONHUMAN_CAP), 'Non-Human Level Cap after the Journal (#1176)');
  TestKit.CheckEqualsL(8, CfgFile.SettingLine(C_OPT.OPT_LEVEL_CAP), 'Game Level Cap after it (#1121)');
  TestKit.CheckEqualsL(9, CfgFile.SettingLine(C_OPT.OPT_TRAIN_ANYWHERE), 'Train Anywhere after it (#1212)');
  TestKit.CheckEqualsL(10, CfgFile.SettingLine(C_OPT.OPT_COMPANION), 'the Companion Tools after that');
  TestKit.CheckEqualsL(11, CfgFile.SettingLine(C_OPT.OPT_CLUES), 'the Game page ends with the Clue Book notes');
  TestKit.CheckEqualsL(1, CfgFile.SettingLine(C_OPT.OPT_QUICK), 'the Combat page starts under the Quick Mode heading');
  TestKit.CheckEqualsL(3, CfgFile.SettingLine(C_OPT.OPT_GEAR), 'Allow Gear Changes under Quick Mode, after Use Magic');
  TestKit.CheckEqualsL(5, CfgFile.SettingLine(C_OPT.OPT_RETRIEVE), 'Aim Cycles and Retrieve Thrown after it');
  TestKit.CheckEqualsL(6, CfgFile.SettingLine(C_OPT.OPT_MINIMAP), 'the Minimap after Retrieve Thrown (#1210)');
  TestKit.CheckEqualsL(8, CfgFile.SettingLine(C_OPT.OPT_LOG_LINES), 'the Combat page ends with the log lines');
  TestKit.CheckEqualsS('Minimap (F3)', CfgFile.SettingName(C_OPT.OPT_MINIMAP), 'the Minimap''s label names its key');
  TestKit.CheckEqualsS('Quick Mode', CfgFile.Heading(C_OPT.OPT_QUICK), 'the Quick Mode heading');
  TestKit.CheckEqualsS('Fix', CfgFile.Heading(C_OPT.OPT_FIX_SCROLLS), 'the Fix heading (#1129)');
  TestKit.CheckEqualsS('', CfgFile.Heading(C_OPT.OPT_FIX_POTIONS), 'and none on the other lines');
  TestKit.CheckEqualsL(0, CfgFile.SettingLine(C_OPT.OPT_AUTO_MEMORIZE), 'the Camp page starts with Auto Memorize');
  TestKit.CheckEqualsL(2, CfgFile.SettingLine(C_OPT.OPT_FIX_SCROLLS), 'the Fix settings under their heading');
  TestKit.CheckEqualsL(5, CfgFile.SettingLine(C_OPT.OPT_FIX_HEAL), 'four of them');
  TestKit.CheckEqualsL(0, CfgFile.SettingLine(C_OPT.OPT_MUSIC), 'the Sound page starts with the music');
  TestKit.CheckEqualsL(9, CfgFile.SettingLine(C_OPT.OPT_SPELLS), 'and ends with the spell effects');

  { no sound device (#1156): Music and Sound show OFF, the Sound page is passed by, POOLOPT.CFG's values kept }
  TestKit.Check(CfgFile.NoSoundDevice(C_OPT.SOUND_SILENT) and CfgFile.NoSoundDevice(C_OPT.SOUND_NONE) and
                CfgFile.NoSoundDevice('q'), 'S, N and an unknown letter are no sound device');
  TestKit.Check(not CfgFile.NoSoundDevice(C_OPT.SOUND_SPEAKER) and not CfgFile.NoSoundDevice(C_OPT.SOUND_TANDY) and
                not CfgFile.NoSoundDevice('a') and not CfgFile.NoSoundDevice(C_OPT.SOUND_BLASTER),
                'the speaker, the Tandy, the AdLib (in either case) and the Sound Blaster are');
  CfgFile.Defaults(s);
  TestKit.CheckEqualsS('ON', CfgFile.ShownValue(s, C_OPT.OPT_MUSIC, False), 'Music shows ON with a device');
  TestKit.CheckEqualsS('OFF', CfgFile.ShownValue(s, C_OPT.OPT_MUSIC, True), 'and OFF without one');
  TestKit.CheckEqualsS('OFF', CfgFile.ShownValue(s, C_OPT.OPT_SOUND, True), 'Sound too');
  TestKit.CheckEqualsS('ON', CfgFile.ShownValue(s, C_OPT.OPT_FOOTSTEPS, True), 'a sub-setting shows what it keeps');
  TestKit.CheckEqualsS('FOUND', CfgFile.ShownValue(s, C_OPT.OPT_JOURNAL, True), 'other settings are as stored');
  TestKit.Check((CfgFile.Flag(s, C_OPT.OPT_MUSIC) = 1) and (CfgFile.Flag(s, C_OPT.OPT_SOUND) = 1),
                'and what POOLOPT.CFG keeps for Music and Sound is left ON');
  skip := [C_OPT.OPT_LOG_LINES];
  CfgFile.Silenced(False, skip);
  TestKit.Check(skip = [C_OPT.OPT_LOG_LINES], 'with a device nothing more is passed by');
  CfgFile.Silenced(True, skip);
  TestKit.Check(skip = [C_OPT.OPT_FIRST_SOUND..C_OPT.OPT_LAST_SOUND, C_OPT.OPT_LOG_LINES],
                'without one every Sound page setting is, Music and Sound among them');
  TestKit.CheckEqualsL(C_OPT.OPT_AUTO_MEMORIZE, CfgFile.NextSetting(C_OPT.OPT_CLUES, True, skip),
                       'Down from the Clue Book notes passes them by');
  skip := [];
  for opt := 1 to C_OPT.OPT_COUNT do
    if CfgFile.SettingPage(opt) <> C_OPT.OPT_PAGE_SOUND then
      skip := skip + [opt];
  CfgFile.Silenced(True, skip);
  TestKit.CheckEqualsL(C_OPT.OPT_MUSIC, CfgFile.NextSetting(C_OPT.OPT_MUSIC, True, skip),
                       'on the Sound page with nothing to change Down stays on Music');
  TestKit.CheckEqualsL(C_OPT.OPT_MUSIC, CfgFile.NextSetting(C_OPT.OPT_MUSIC, False, skip), 'and so does Up');

  { POOLOPT.CFG read as the game reads it }
  TestKit.Check(ReadText('speed = 0' + CRLF + ' Monsters'#9'=off' + CRLF + 'COMPANION=1' + CRLF + 'CLUENOTES=0' + CRLF +
                         'LOGLINES=10' + CRLF + 'CURSEDATA=D:\CURSE\' + CRLF + 'CURSESAVE=' + CRLF) = CfgFile.CFG_READ,
                'a good POOLOPT.CFG reads, the later games'' paths an old one has passed over (#1177)');
  TestKit.CheckEqualsL(0, bad, 'and not counted as bad values');
  TestKit.CheckEqualsL(0, s.speed, 'SPEED 0');
  TestKit.CheckEqualsL(0, CfgFile.Flag(s, C_OPT.OPT_MONSTERS), 'MONSTERS off, spaced and in lower case');
  TestKit.CheckEqualsL(1, CfgFile.Flag(s, C_OPT.OPT_COMPANION), 'COMPANION 1');
  TestKit.CheckEqualsL(0, CfgFile.Flag(s, C_OPT.OPT_CLUES), 'CLUENOTES 0');
  TestKit.CheckEqualsL(10, s.logLines, 'LOGLINES 10, the fewest');
  TestKit.Check(ReadText('AUTOMEMORIZE=OFF' + CRLF + 'FIXSCROLLS=ON' + CRLF + 'FixPotions = on' + CRLF +
                         'FIXPALADINCURE=1' + CRLF + 'FIXPALADINHEAL=ON' + CRLF) = CfgFile.CFG_READ,
                'the camp settings read (#1119, #1129)');
  TestKit.CheckEqualsL(0, CfgFile.Flag(s, C_OPT.OPT_AUTO_MEMORIZE), 'AUTOMEMORIZE off');
  TestKit.Check((CfgFile.Flag(s, C_OPT.OPT_FIX_SCROLLS) = 1) and (CfgFile.Flag(s, C_OPT.OPT_FIX_POTIONS) = 1) and
                (CfgFile.Flag(s, C_OPT.OPT_FIX_CURE) = 1) and (CfgFile.Flag(s, C_OPT.OPT_FIX_HEAL) = 1),
                'the four Fix settings on');
  TestKit.Check(ReadText('consolidatecoin = On' + CRLF) = CfgFile.CFG_READ, 'CONSOLIDATECOIN reads (#1179)');
  TestKit.CheckEqualsL(1, CfgFile.Flag(s, C_OPT.OPT_CONSOLIDATE), 'Consolidate Coin on');
  TestKit.CheckEqualsS('Consolidate Coin', CfgFile.SettingName(C_OPT.OPT_CONSOLIDATE), 'its label');
  TestKit.Check(ReadText('NONHUMANCAP=OFF' + CRLF) = CfgFile.CFG_READ, 'NONHUMANCAP reads (#1176)');
  TestKit.CheckEqualsL(0, CfgFile.Flag(s, C_OPT.OPT_NONHUMAN_CAP), 'Non-Human Level Cap off');
  TestKit.Check(ReadText('LEVELCAP=OFF' + CRLF) = CfgFile.CFG_READ, 'LEVELCAP reads (#1121)');
  TestKit.CheckEqualsL(0, CfgFile.Flag(s, C_OPT.OPT_LEVEL_CAP), 'Game Level Cap off');
  TestKit.CheckEqualsS('Game Level Cap', CfgFile.SettingName(C_OPT.OPT_LEVEL_CAP), 'its label');
  TestKit.Check(ReadText('TRAINANYWHERE=ON' + CRLF) = CfgFile.CFG_READ, 'TRAINANYWHERE reads (#1212)');
  TestKit.CheckEqualsL(1, CfgFile.Flag(s, C_OPT.OPT_TRAIN_ANYWHERE), 'Train Anywhere on');
  { a setting a key acts on names the key (#1215), and every label fits before the value's column (Options'
    SETTING_COL 24 from LABEL_COL 2, POOLCFG's 26 from 4: 21 characters and a space) }
  TestKit.CheckEqualsS('Train Anywhere (F4)', CfgFile.SettingName(C_OPT.OPT_TRAIN_ANYWHERE), 'its label names F4');
  TestKit.CheckEqualsS('Combat Log (F7)', CfgFile.SettingName(C_OPT.OPT_COMBAT_LOG), 'the Combat Log''s F7');
  TestKit.CheckEqualsS('Companion Tools (F6)', CfgFile.SettingName(C_OPT.OPT_COMPANION), 'the Companion Tools'' F6');
  TestKit.CheckEqualsS('Sound (Ctrl-S)', CfgFile.SettingName(C_OPT.OPT_SOUND), 'Sound''s Ctrl-S');
  bad := 0;
  for opt := 1 to C_OPT.OPT_COUNT do
    if Length(CfgFile.SettingLabel(s, opt)) > 21 then
      Inc(bad);
  TestKit.CheckEqualsL(0, bad, 'every label fits its line');
  TestKit.Check(ReadText('SPEED=9' + CRLF + 'SPEED=A' + CRLF + 'LOGLINES=60' + CRLF + 'LOGLINES=61' + CRLF +
                         'LOGLINES=9' + CRLF + 'LOGLINES=abc' + CRLF + 'MUSIC=maybe' + CRLF + 'SPEED=10')
                = CfgFile.CFG_FIXED, 'bad values are a fixed read');
  TestKit.CheckEqualsL(9, s.speed, 'SPEED 9; A and 10 are refused');
  TestKit.CheckEqualsL(60, s.logLines, 'LOGLINES 60; 61, 9 and abc are refused');
  TestKit.CheckEqualsL(1, CfgFile.Flag(s, C_OPT.OPT_MUSIC), 'an unknown flag value leaves the default');
  TestKit.CheckEqualsL(6, bad, 'six values refused');
  TestKit.Check(ReadText('SPEED=4' + CRLF + 'SPEED=5') = CfgFile.CFG_READ, 'a file with no newline at its end reads');
  TestKit.CheckEqualsL(5, s.speed, 'the last of a key given twice wins, the last line too');
  { the version the startup advisory's support part was last shown for (#1173) }
  TestKit.Check(ReadText('advised = v1.3-1600 ' + CRLF) = CfgFile.CFG_READ, 'ADVISED reads');
  TestKit.CheckEqualsS('V1.3-1600', s.advised, 'tidied');
  TestKit.CheckEqualsS('V1.3-1600', CfgFile.StoredValue(s, C_OPT.KEY_ADVISED), 'and is kept so');
  TestKit.Check(ReadText('ADVISED=' + CRLF) = CfgFile.CFG_READ, 'a blank ADVISED reads');
  TestKit.CheckEqualsS('', s.advised, 'as none advised');
  body := '';
  for i := 1 to C_OPT.MAX_LINES - 1 do
    body := body + CRLF;
  TestKit.Check(ReadText(body + 'SPEED=3' + CRLF + 'SPEED=7' + CRLF) = CfgFile.CFG_READ, 'a long file reads');
  TestKit.CheckEqualsL(3, s.speed, 'reading stops after the hundredth line');
  FileUtil.DeleteFile(C_OPT.OPT_NAME);
  CfgFile.Defaults(s);
  TestKit.Check(CfgFile.ReadOptions('', s, bad) = CfgFile.CFG_MISSING, 'a missing POOLOPT.CFG');
  TestKit.CheckEqualsL(1, s.speed, 'leaves the defaults');

  { POOLOPT.CFG written: every key in order, then the unknown lines, blank ones dropped }
  TestKit.Check(PutFile(C_OPT.OPT_NAME, 'NEWKEY=1' + CRLF + CRLF + 'SPEED=2' + CRLF + '; a note' + CRLF +
                        'CURSEDATA=D:\CURSE\' + CRLF), 'old file');
  CfgFile.Defaults(s);
  s.speed := 4;
  CfgFile.SetFlag(s, C_OPT.OPT_WALL, 0);
  s.advised := 'V1.3-1600';
  TestKit.Check(CfgFile.WriteOptions('', s), 'POOLOPT.CFG is written');
  TestKit.CheckEqualsL(1, LineNo(C_OPT.OPT_NAME, 'SPEED=4'), 'the keys start with SPEED');
  TestKit.CheckEqualsL(2, LineNo(C_OPT.OPT_NAME, 'ALLPORTRAITS=ON'), 'in their order');
  TestKit.CheckEqualsL(C_OPT.OPT_WALL, LineNo(C_OPT.OPT_NAME, 'WALLHIT=OFF'), 'a setting turned off');
  TestKit.CheckEqualsL(5, LineNo(C_OPT.OPT_NAME, 'AUTOJOIN=ON'), 'Auto Join on by default, after the portraits');
  TestKit.CheckEqualsL(6, LineNo(C_OPT.OPT_NAME, 'CONSOLIDATECOIN=OFF'), 'Consolidate Coin off by default, after it');
  TestKit.CheckEqualsL(C_OPT.OPT_NONHUMAN_CAP, LineNo(C_OPT.OPT_NAME, 'NONHUMANCAP=ON'),
                       'Non-Human Level Cap on by default, after the Journal (#1176)');
  TestKit.CheckEqualsL(C_OPT.OPT_LEVEL_CAP, LineNo(C_OPT.OPT_NAME, 'LEVELCAP=ON'),
                       'Game Level Cap on by default, after it (#1121)');
  TestKit.CheckEqualsL(C_OPT.OPT_TRAIN_ANYWHERE, LineNo(C_OPT.OPT_NAME, 'TRAINANYWHERE=OFF'),
                       'Train Anywhere off by default, after it (#1212)');
  TestKit.CheckEqualsL(C_OPT.OPT_JOURNAL, LineNo(C_OPT.OPT_NAME, 'JOURNAL=FOUND'),
                       'the Journal FOUND by default, after Auto Join');
  TestKit.CheckEqualsL(C_OPT.OPT_GEAR, LineNo(C_OPT.OPT_NAME, 'GEARCHANGES=ON'), 'Allow Gear Changes on by default');
  TestKit.CheckEqualsL(C_OPT.OPT_AIM, LineNo(C_OPT.OPT_NAME, 'AIMCYCLES=ENEMIES'), 'Aim Cycles at ENEMIES by default');
  TestKit.CheckEqualsL(C_OPT.OPT_RETRIEVE, LineNo(C_OPT.OPT_NAME, 'RETRIEVETHROWN=ON'),
                       'Retrieve Thrown on by default');
  TestKit.CheckEqualsL(C_OPT.OPT_MINIMAP, LineNo(C_OPT.OPT_NAME, 'MINIMAP=OFF'), 'the Minimap off by default (#1210)');
  TestKit.CheckEqualsL(C_OPT.OPT_AUTO_MEMORIZE, LineNo(C_OPT.OPT_NAME, 'AUTOMEMORIZE=ON'),
                       'Auto Memorize on by default');
  TestKit.CheckEqualsL(C_OPT.OPT_FIX_SCROLLS, LineNo(C_OPT.OPT_NAME, 'FIXSCROLLS=OFF'), 'Use Scrolls off by default');
  TestKit.CheckEqualsL(C_OPT.OPT_FIX_HEAL, LineNo(C_OPT.OPT_NAME, 'FIXPALADINHEAL=OFF'),
                       'Use Paladin''s Heal off by default');
  TestKit.CheckEqualsL(C_OPT.KEY_COUNT, LineNo(C_OPT.OPT_NAME, 'ADVISED=V1.3-1600'), 'the last key, the version');
  TestKit.CheckEqualsL(C_OPT.KEY_COUNT + 1, LineNo(C_OPT.OPT_NAME, 'NEWKEY=1'), 'then the unknown lines');
  TestKit.CheckEqualsL(C_OPT.KEY_COUNT + 2, LineNo(C_OPT.OPT_NAME, '; a note'), 'in their order, the blank dropped');
  TestKit.CheckEqualsL(C_OPT.KEY_COUNT + 3, LineNo(C_OPT.OPT_NAME, 'CURSEDATA=D:\CURSE\'),
                       'an old later-game path among them, unchanged (#1177)');
  TestKit.CheckEqualsL(0, LineNo(C_OPT.OPT_NAME, 'SPEED=2'), 'an old known line is not kept');
  KeepBytes(C_OPT.OPT_NAME);
  CfgFile.Defaults(t);
  TestKit.Check(CfgFile.ReadOptions('', t, bad) = CfgFile.CFG_READ, 'the written file reads');
  TestKit.Check(CfgFile.WriteOptions('', t), 'and is written again');
  TestKit.Check(SameBytes(C_OPT.OPT_NAME), 'a round trip gives the same bytes');
  { a save folder not there yet is made, with the folder above it, and the settings land (#1067) }
  TestKit.Check(not CfgFile.DirExists(NEW_DIR), 'no new folder yet');
  TestKit.Check(CfgFile.WriteOptions(NEW_PATH, t), 'a write into a missing folder');
  TestKit.CheckEqualsL(1, LineNo(NEW_PATH + C_OPT.OPT_NAME, 'SPEED=4'), 'lands, the folders made');
  CfgFile.Defaults(s);
  TestKit.Check(CfgFile.ReadOptions(NEW_PATH, s, bad) = CfgFile.CFG_READ, 'and reads back');
  TestKit.Check(CfgFile.WriteOptions(NEW_PATH, t), 'a folder already there is written again');
  FileUtil.DeleteFile(NEW_PATH + C_OPT.OPT_NAME);
  { the copy's folder and the backups' in it, made beside the file (#1084) }
  TestKit.Check(CfgFile.DirExists(NEW_PATH + 'TMP' + SEP + 'BAK' + SEP), 'the copy and backup folders are made');
  RmDir(NEW_PATH + 'TMP' + SEP + 'BAK');
  ioRes := IOResult;
  RmDir(NEW_PATH + 'TMP');
  ioRes := IOResult;
  RmDir(NEW_DIR + SEP + NEW_SUB);
  ioRes := IOResult;
  RmDir(NEW_DIR);
  ioRes := IOResult;
  TestKit.Check(PutFile(FILE_NAME, 'x'), 'a file for the test');
  TestKit.Check(not CfgFile.WriteOptions(FILE_NAME + '\', t), 'a write into a file, as a folder, fails');
  FileUtil.DeleteFile(FILE_NAME);
  { a folder in the way of the temporary copy fails the write (TMP\, its folder, is there from the writes above) }
  MkDir('TMP' + SEP + C_OPT.OPT_NAME);
  ioRes := IOResult;
  t.speed := 8;
  TestKit.Check(not CfgFile.WriteOptions('', t), 'a write that cannot make its copy fails');
  TestKit.Check(SameBytes(C_OPT.OPT_NAME), 'and leaves the old file');
  RmDir('TMP' + SEP + C_OPT.OPT_NAME);
  ioRes := IOResult;
  FileUtil.DeleteFile(C_OPT.OPT_NAME);

  { the steps }
  CfgFile.Defaults(s);
  CfgFile.ChangeSetting(s, C_OPT.OPT_SPEED, False);
  TestKit.CheckEqualsL(2, s.speed, 'Slower raises the speed');
  CfgFile.ChangeSetting(s, C_OPT.OPT_SPEED, True);
  CfgFile.ChangeSetting(s, C_OPT.OPT_SPEED, True);
  CfgFile.ChangeSetting(s, C_OPT.OPT_SPEED, True);
  TestKit.CheckEqualsL(0, s.speed, 'Faster stops at 0');
  s.logLines := 58;
  CfgFile.ChangeSetting(s, C_OPT.OPT_LOG_LINES, True);
  TestKit.CheckEqualsL(60, s.logLines, 'More stops at 60');
  s.logLines := 13;
  CfgFile.ChangeSetting(s, C_OPT.OPT_LOG_LINES, False);
  TestKit.CheckEqualsL(10, s.logLines, 'Less stops at 10');
  CfgFile.ChangeSetting(s, C_OPT.OPT_MUSIC, False);
  TestKit.CheckEqualsL(0, CfgFile.Flag(s, C_OPT.OPT_MUSIC), 'a flag turns over');
  { the Journal's FOUND and ALL (#1090) }
  TestKit.CheckEqualsS('FOUND', CfgFile.StoredValue(s, C_OPT.OPT_JOURNAL), 'the Journal is FOUND by default');
  CfgFile.ChangeSetting(s, C_OPT.OPT_JOURNAL, True);
  TestKit.CheckEqualsS('ALL', CfgFile.StoredValue(s, C_OPT.OPT_JOURNAL), 'and turns over to ALL');
  TestKit.Check(CfgFile.ReadValue(s, C_OPT.OPT_JOURNAL, 'FOUND') and (CfgFile.Flag(s, C_OPT.OPT_JOURNAL) = 1),
                'JOURNAL=FOUND reads');
  TestKit.Check(CfgFile.ReadValue(s, C_OPT.OPT_JOURNAL, 'OFF') and (CfgFile.Flag(s, C_OPT.OPT_JOURNAL) = 0),
                'and OFF, as ALL');
  TestKit.Check(not CfgFile.ReadValue(s, C_OPT.OPT_MUSIC, 'FOUND'), 'FOUND is the Journal''s only');

  { Allow Gear Changes (#1127), Aim Cycles (#1137) and Retrieve Thrown (#1118) }
  TestKit.Check(ReadText('GEARCHANGES=OFF' + CRLF + 'AIMCYCLES=all' + CRLF + 'RETRIEVETHROWN=0' + CRLF)
                = CfgFile.CFG_READ, 'the combat settings read');
  TestKit.CheckEqualsL(0, CfgFile.Flag(s, C_OPT.OPT_GEAR), 'GEARCHANGES off');
  TestKit.CheckEqualsL(0, CfgFile.Flag(s, C_OPT.OPT_AIM), 'AIMCYCLES ALL, in any case');
  TestKit.CheckEqualsL(0, CfgFile.Flag(s, C_OPT.OPT_RETRIEVE), 'RETRIEVETHROWN 0');
  TestKit.CheckEqualsS('ALL', CfgFile.StoredValue(s, C_OPT.OPT_AIM), 'Aim Cycles keeps ALL');
  TestKit.CheckEqualsS('OFF', CfgFile.StoredValue(s, C_OPT.OPT_GEAR), 'Allow Gear Changes keeps OFF');
  TestKit.Check(ReadText('AIMCYCLES=Enemies' + CRLF) = CfgFile.CFG_READ, 'ENEMIES reads');
  TestKit.CheckEqualsL(1, CfgFile.Flag(s, C_OPT.OPT_AIM), 'as Aim Cycles at ENEMIES');
  TestKit.Check(ReadText('GEARCHANGES=ALL' + CRLF + 'AIMCYCLES=SOME' + CRLF) = CfgFile.CFG_FIXED,
                'ALL is Aim Cycles'' value only, and SOME no one''s');
  TestKit.CheckEqualsL(2, bad, 'both refused');
  CfgFile.ChangeSetting(s, C_OPT.OPT_AIM, False);
  TestKit.CheckEqualsS('ALL', CfgFile.StoredValue(s, C_OPT.OPT_AIM), 'Aim Cycles turns over to ALL');
  TestKit.CheckEqualsS('Aim Cycles', CfgFile.SettingName(C_OPT.OPT_AIM), 'Aim Cycles'' label');
  FileUtil.DeleteFile(C_OPT.OPT_NAME);

  { POOL.CFG as START reads it }
  TestKit.Check(ReadPool('E' + CRLF + 'T' + CRLF + 'C:\POOLRAD\' + CRLF + 'C:\POOLRAD\SAVE\' + CRLF + 'F' + CRLF)
                = CfgFile.CFG_READ, 'the GOG POOL.CFG reads');
  TestKit.Check((c.video = 'E') and (c.sound = 'T') and (c.intro = 'F'), 'its letters');
  TestKit.CheckEqualsS('C:\POOLRAD\', c.dataDir, 'its data path');
  TestKit.CheckEqualsS('C:\POOLRAD\SAVE\', c.saveDir, 'its save path');
  TestKit.CheckEqualsL(0, c.extraCount, 'no extra lines');
  TestKit.Check(ReadPool('e' + CRLF + 'b' + CRLF + 'D' + CRLF + 'S' + CRLF + 'n' + CRLF) = CfgFile.CFG_READ,
                'lower-case letters are known');
  TestKit.Check((c.video = 'E') and (c.sound = 'B') and (c.intro = 'N'), 'and read in capitals');
  TestKit.Check(ReadPool('V' + CRLF + 'S' + CRLF + CRLF + CRLF + 'F' + CRLF) = CfgFile.CFG_READ, 'S is known');
  TestKit.Check(c.sound = C_OPT.SOUND_SILENT, 'S is silent (#880)');
  TestKit.Check(ReadPool('V' + CRLF + 'N' + CRLF + CRLF + CRLF + 'F' + CRLF) = CfgFile.CFG_READ, 'N is known');
  TestKit.Check(c.sound = C_OPT.SOUND_SILENT, 'N is silent too');
  TestKit.Check(ReadPool('X' + CRLF + 'q' + CRLF + 'C:\A\' + CRLF + 'C:\B\' + CRLF + CRLF + 'MORE' + CRLF + 'LAST')
                = CfgFile.CFG_FIXED, 'unknown letters are a fixed read');
  TestKit.Check((c.video = C_OPT.VIDEO_CGA) and (c.sound = C_OPT.SOUND_SILENT) and (c.intro = C_OPT.INTRO_SHORT),
                'read as START reads them: CGA, silent, short');
  TestKit.CheckEqualsL(3, notes.count, 'three notes');
  TestKit.Check((notes.items[1].line = 1) and (notes.items[1].raw = 'X'), 'the video''s');
  TestKit.Check((notes.items[2].line = 2) and (notes.items[2].raw = 'q'), 'the sound''s');
  TestKit.Check((notes.items[3].line = 5) and not notes.items[3].missing, 'a blank introduction line''s');
  TestKit.CheckEqualsL(2, c.extraCount, 'the lines after the fifth are kept');
  TestKit.CheckEqualsS('LAST', c.extra[2], 'the last without its newline');
  TestKit.Check(ReadPool('T' + CRLF + 'A' + CRLF + 'C:\GAME\') = CfgFile.CFG_FIXED, 'a three-line file');
  TestKit.CheckEqualsS('', c.saveDir, 'has no save path (START: the current folder)');
  TestKit.Check(c.intro = C_OPT.INTRO_SHORT, 'and the short introduction');
  TestKit.Check((notes.count = 2) and notes.items[1].missing and (notes.items[2].line = 5), 'its missing lines noted');
  FileUtil.DeleteFile(POOL_NAME);
  TestKit.Check(CfgFile.ReadPoolCfg(POOL_NAME, c, notes) = CfgFile.CFG_MISSING, 'a missing POOL.CFG');

  { POOL.CFG written with CR LF whatever the system }
  c.video := 'V';
  c.sound := 'B';
  c.dataDir := 'C:\POOLRAD\';
  c.saveDir := 'C:\POOLRAD\SAVE\';
  c.intro := 'F';
  c.extraCount := 1;
  c.extra[1] := 'MORE';
  TestKit.Check(CfgFile.WritePoolCfg(POOL_NAME, c), 'POOL.CFG is written');
  TestKit.CheckEqualsS('V' + CRLF + 'B' + CRLF + 'C:\POOLRAD\' + CRLF + 'C:\POOLRAD\SAVE\' + CRLF + 'F' + CRLF +
                       'MORE' + CRLF, FileText(POOL_NAME), 'its bytes');
  TestKit.Check(not CfgFile.WritePoolCfg('NODIR\' + POOL_NAME, c), 'a write into a missing folder fails');
  FileUtil.DeleteFile(POOL_NAME);

  { POOL.CFG's defaults }
  CfgFile.PoolDefaults(c, 'C:\GAME\');
  TestKit.Check((c.video = 'V') and (c.intro = 'F') and (c.extraCount = 0), 'defaults: VGA, the full introduction');
{$IFDEF FPC}
  TestKit.Check(c.sound = 'B', 'natively Digital Audio (the Sound Blaster''s letter)');
{$ELSE}
  TestKit.Check(c.sound = 'S', 'under DOS no sound');
{$ENDIF}
  TestKit.CheckEqualsS('C:\GAME\', c.dataDir, 'the data in the folder given');
  TestKit.CheckEqualsS('C:\GAME\SAVE\', c.saveDir, 'the saves in SAVE\ under it');

  { paths }
  GetDir(0, cur);
{$IFDEF FPC}
  { natively the separators are backslashes, as in POOL.CFG }
  for i := 1 to Length(cur) do
    if cur[i] = '/' then
      cur[i] := '\';
{$ENDIF}
  if cur[Length(cur)] <> '\' then
    cur := cur + '\';
  TestKit.Check(CfgFile.NormalizePath(' GAME ', full), 'a relative path');
  TestKit.CheckEqualsS(cur + 'GAME\', full, 'is put in the current folder, trimmed, with its backslash');
  TestKit.Check(CfgFile.NormalizePath('', full), 'an empty path');
  TestKit.CheckEqualsS(cur, full, 'is the current folder');
{$IFNDEF FPC}
  TestKit.Check(CfgFile.NormalizePath('\ROOTED', full), 'a rooted path');
  TestKit.CheckEqualsS(Copy(cur, 1, 2) + '\ROOTED\', full, 'takes the current drive');
  TestKit.Check(CfgFile.NormalizePath('C:\', full) and (full = 'C:\'), 'a drive''s root stays');
  TestKit.Check(CfgFile.NormalizePath(Copy(cur, 1, 2), full), 'a drive alone');
  TestKit.CheckEqualsS(cur, full, 'is its current folder');
{$ENDIF}
{$IFDEF FPC}
  TestKit.Check(CfgFile.NormalizePath('GAME/SAVE/', full), 'a path with slashes');
  TestKit.CheckEqualsS(cur + 'GAME\SAVE\', full, 'has backslashes, and one at its end');
{$IFDEF UNIX}
  TestKit.Check(CfgFile.NormalizePath('/home/pool', full), 'a path from the root');
  TestKit.CheckEqualsS('\home\pool\', full, 'is whole on a system without drives');
{$ENDIF}
  TestKit.CheckEqualsS('H/SAVE\', CfgFile.NativeSaveFolder('C:\POOLRAD\', 'C:\POOLRAD\SAVE\', 'H/'),
                       'NativeSaveFolder: SSI''s install, in the writable folder');
  TestKit.CheckEqualsS('H/games\one\', CfgFile.NativeSaveFolder('C:\POOLRAD', 'c:\poolrad\games\one', 'H/'),
                       'a folder deeper, whatever its case');
  TestKit.CheckEqualsS('H/SAVE\', CfgFile.NativeSaveFolder('C:\POOLRAD\', 'D:\NO SUCH SAVES\', 'H/'),
                       'a folder elsewhere that is not there is SAVE\');
  TestKit.CheckEqualsS('H/SAVE\', CfgFile.NativeSaveFolder('C:\POOLRAD\', 'C:\POOLRAD\', 'H/'), 'and the game''s own');
  TestKit.CheckEqualsS('H/SAVE\', CfgFile.NativeSaveFolder('', '', 'H/'), 'and an empty one');
  TestKit.CheckEqualsS('H/Saves\', CfgFile.NativeSaveFolder('', 'Saves', 'H/'),
                       'a relative one under the current folder');
  TestKit.CheckEqualsS(cur, CfgFile.NativeSaveFolder('C:\POOLRAD\', cur, 'H/'),
                       'a whole path to a folder that is there, outside the game''s, is kept (#1064)');
{$ENDIF}
  body := 'C:\';
  while Length(body) < C_OPT.MAX_PATH_TEXT - 1 do
    body := body + 'A';
  TestKit.Check(CfgFile.NormalizePath(body, full), 'a path of the most characters START takes');
  TestKit.CheckEqualsL(C_OPT.MAX_PATH_TEXT, Length(full), 'with its backslash');
  TestKit.Check(not CfgFile.NormalizePath(body + 'A', full), 'one more is too long');
{$IFNDEF FPC}
  TestKit.CheckEqualsL(59, C_OPT.MAX_PATH_TEXT, 'START takes 59 characters under DOS, room for TMP\BAK\ (#1084)');
{$ENDIF}

  { folders: nothing is created }
  MkDir(DIR_NAME);
  ioRes := IOResult;
  TestKit.Check(PutFile(FILE_NAME, 'x'), 'a file for the test');
  TestKit.Check(CfgFile.DirExists(cur + DIR_NAME + '\'), 'a folder that exists');
  TestKit.Check(CfgFile.DirExists(cur + DIR_NAME), 'without its backslash too');
  TestKit.Check(not CfgFile.DirExists(cur + 'NOSUCHD\'), 'a folder that does not');
  TestKit.Check(not CfgFile.DirExists(cur + FILE_NAME + '\'), 'a file is not a folder');
  TestKit.Check(not CfgFile.DirExists(cur + 'TCFG*\'), 'a wildcard is never a folder');
{$IFNDEF FPC}
  TestKit.Check(CfgFile.DirExists(Copy(cur, 1, 3)), 'the drive''s root');
{$ENDIF}
  TestKit.Check(CfgFile.CheckPath(' ' + DIR_NAME + ' ', full) = CfgFile.PATH_OK, 'CheckPath takes a folder');
{$IFDEF FPC}
  TestKit.CheckEqualsS(cur + DIR_NAME + '\', full, 'normalized, its case kept natively');
{$ELSE}
  TestKit.CheckEqualsS(CfgFile.Tidy(cur + DIR_NAME + '\'), full, 'normalized, in capitals');
{$ENDIF}
  TestKit.Check(CfgFile.CheckPath('NOSUCHD', full) = CfgFile.PATH_MISSING, 'refuses a missing folder');
  TestKit.Check(not CfgFile.DirExists(cur + 'NOSUCHD\'), 'and does not create it');
  TestKit.Check(CfgFile.CheckPath('  ', full) = CfgFile.PATH_EMPTY, 'refuses an empty path');
  TestKit.Check(CfgFile.CheckPath('C:\A?B', full) = CfgFile.PATH_BAD_CHAR, 'refuses a wildcard');
  TestKit.Check(CfgFile.CheckPath('C:\A|B', full) = CfgFile.PATH_BAD_CHAR, 'refuses a pipe');
  TestKit.Check(CfgFile.CheckPath(body + 'A', full) = CfgFile.PATH_TOO_LONG, 'refuses a path too long');
  FileUtil.DeleteFile(FILE_NAME);
  RmDir(DIR_NAME);
  ioRes := IOResult;

  TestKit.Done;
end.

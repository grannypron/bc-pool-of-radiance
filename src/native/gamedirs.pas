{ Locates the read-only game data and the directory used for generated files
  (#1064). When a writable data directory sits beside the executable, both are
  the same. Store installations and signed app bundles instead use a per-user
  writable directory so the original installation is never modified.

  Settle checks an explicit command-line path, locations beside the executable,
  the previously remembered choice, and known Steam, GOG, and Heroic layouts.
  DataPick handles ambiguous or unsuccessful searches. Store-specific paths are
  described by TStoreGame so the later Gold Box games can reuse this code.

  This unit deliberately has no SDL or game-unit dependencies, allowing poolcfg
  and the unit tests to link it. Free Pascal only. }
{$MODE OBJFPC}
{$H-}
{$I-}
unit GameDirs;

interface

type
  { Operating system whose standard locations should be searched. }
  TOs = (OS_LINUX, OS_MAC, OS_WINDOWS);

  { Store-specific locations and identifiers for one game. }
  TStoreGame = record
    { the game's name: GOG's and Heroic's install folder, and the per-user folder's on macOS and Windows }
    name: string[40];
    { the per-user folder's name on Linux }
    linuxName: string[40];
    { a file only a data folder holds: what HoldsData looks for }
    dataFile: string[12];
    { Steam: under a library's steamapps/common/ }
    steamFolder: ShortString;
    { GOG's game id: its Windows registry key and its marker file, goggame-<id>.info }
    gogId: string[12];
    { GOG on Windows (and Heroic's Windows install): under the install folder }
    gogFolder: string[60];
    { GOG on Linux (MojoSetup): under the install folder }
    gogLinuxFolder: string[60];
    { GOG on macOS: under the folder the .pkg installs into }
    gogMacFolder: ShortString;
  end;

  { Candidate data directory and the store name shown to the player. }
  TCandidate = record
    path: ShortString;
    store: string[24];
  end;
  TCandidates = array of TCandidate;
  TPaths = array of ShortString;

  { Root directories searched for store installations. Tests can supply their
    own roots instead of DefaultRoots. }
  TSearchRoots = record
    { Steam's own folders, each with steamapps/libraryfolders.vdf }
    steamRoots: TPaths;
    { GOG installs the Windows registry names }
    gogPaths: TPaths;
    { folders whose subfolders may be GOG Windows installs: one holding goggame-<id>.info is taken }
    gogMarkerParents: TPaths;
    { folders whose subfolders may be GOG Linux installs }
    gogParents: TPaths;
    { folders GOG's Mac .pkg may have put the app in }
    appFolders: TPaths;
    { folders whose subfolders may be Heroic's installs (of GOG's Windows, Linux or Mac version) }
    heroicParents: TPaths;
  end;

const
{$IFDEF WINDOWS}
  THIS_OS = OS_WINDOWS;
{$ELSE}
{$IFDEF DARWIN}
  THIS_OS = OS_MAC;
{$ELSE}
  THIS_OS = OS_LINUX;
{$ENDIF}
{$ENDIF}

  { Pool of Radiance, as #1064 found each store's install }
  POOL: TStoreGame = (
    name: 'Pool of Radiance';
    linuxName: 'pool-of-radiance';
    dataFile: 'GEO1.DAX';
    steamFolder: 'Forgotten Realms The Archives - Collection Two/games/POOLRAD/GAME/POOLRAD';
    gogId: '1432640961';
    gogFolder: 'POOLRAD';
    gogLinuxFolder: 'data/POOLRAD';
    gogMacFolder: 'Pool of Radiance.app/Contents/Resources/game/POOLRAD');

  { the command line's options: a data folder to use (and remember), and to choose it again }
  OPT_DATA_FOLDER = '--data-folder';
  OPT_CHOOSE = '--choose-data-folder';

var
  { Selected data and writable directories, including trailing separators.
    Both are empty until Settle or Take succeeds. }
  dataFolder: ShortString;
  writeFolder: ShortString;

{ Parses every Steam library path from libraryfolders.vdf, including its older
  numbered format, and decodes VDF escapes. }
function ParseLibraryFolders(const text: AnsiString): TPaths;

{ Builds the default search roots for an operating system and home directory. }
function DefaultRoots(const game: TStoreGame; os: TOs; const home: ShortString): TSearchRoots;

{ Expands the search roots into candidate installation directories, in search
  order. This does not check whether the directories contain game data. }
function Candidates(const roots: TSearchRoots; const game: TStoreGame): TCandidates;

{ Filters candidates to unique directories that contain the game's data. }
function Found(const list: TCandidates; const game: TStoreGame): TCandidates;

{ Returns whether dir contains the game's identifying data file. }
function HoldsData(const dir: ShortString; const game: TStoreGame): Boolean;

{ Returns whether dir looks like a Pool of Radiance directory. A configured
  game contains POOL.CFG; a fresh one contains GEO1.DAX (#894). }
function HoldsGame(const dir: ShortString): Boolean;

{ True when a and b are one folder (on Linux and macOS, one file system entry, so a link and its target are one). }
function SameFolder(const a, b: ShortString): Boolean;

{ Returns the game's per-user writable directory, with a trailing separator,
  using the platform's normal application-data location. }
function UserFolder(const game: TStoreGame; os: TOs; const home: ShortString): ShortString;

{ True when folder dir is inside a macOS app bundle (a signed bundle that writing would break). }
function InAppBundle(const dir: ShortString): Boolean;

{ True when the game must not write in folder dir: it is inside an app bundle, or a file cannot be made in it. }
function MustNotWrite(const dir: ShortString): Boolean;

{ Returns the directory beside the executable, or the directory containing its
  .app bundle on macOS. Includes a trailing separator. }
function AppFolder: ShortString;

{ Finds a release-provided file such as RAVFULL.DAX or SBSFX.DAT. Files beside
  the executable take precedence over the original data directory. }
function OwnFolder(const name: ShortString): ShortString;

{ The file name (POOL.CFG) as the game reads it: the writable folder's when it has one, else the data folder's. }
function ReadName(const name: ShortString): ShortString;

{ Returns the previously remembered data directory, or an empty string. }
function Remembered(const game: TStoreGame): ShortString;

{ Stores dir as the preferred data directory. Returns False on write failure. }
function Remember(const game: TStoreGame; const dir: ShortString): Boolean;

{ Selects dir as the data directory. It is also used for writes when it is a
  writable directory beside the program; otherwise a per-user directory is
  created and selected for writes. }
procedure Place(const game: TStoreGame; const dir: ShortString; beside: Boolean);

{ Place dir as a data folder found or chosen (not beside the program), and remember it. }
procedure Take(const game: TStoreGame; const dir: ShortString);

{ The value given the command-line option opt (opt PATH or opt=PATH); empty when it is not there. }
function OptionValue(const opt: ShortString): ShortString;

{ True when the command line holds option opt. }
function HasOption(const opt: ShortString): Boolean;

{ Searches for and places the data directory without prompting. The order is an
  explicit --data-folder, directories beside the program, the remembered path,
  then known store installations. Returns True when one directory was selected.
  Otherwise hits contains all matches and ask says whether the player explicitly
  requested a choice. }
function Settle(const game: TStoreGame; var hits: TCandidates; var ask: Boolean): Boolean;

implementation

{ Windows first, so SysUtils' routines of the same names (FindClose, DeleteFile, GetEnvironmentVariable) are the ones
  called }
uses {$IFDEF WINDOWS}Windows, {$ENDIF}SysUtils, NatFile{$IFDEF UNIX}, BaseUnix{$ENDIF};

const
  { the file in the player's own folder that remembers the data folder }
  REMEMBER_NAME = 'datafolder.txt';
  { made and removed to see whether a folder may be written }
  PROBE_NAME = 'poolrad.$$$';

{ path with its closing separator }
function Slashed(const path: ShortString): ShortString;
begin
  if path = '' then
    Result := ''
  else
    Result := IncludeTrailingPathDelimiter(path);
end;

{ folder dir and the path under it (with '/' between its folders), in this system's separators }
function Join(const dir, sub: ShortString): ShortString;
var
  i: Integer;
begin
  Result := Slashed(dir) + sub;
  for i := 1 to Length(Result) do
    if Result[i] in ['/', '\'] then
      Result[i] := PathDelim;
end;

procedure Add(var list: TPaths; const path: ShortString);
begin
  if path = '' then
    Exit;
  SetLength(list, Length(list) + 1);
  list[High(list)] := path;
end;

procedure AddCandidate(var list: TCandidates; const path, store: ShortString);
begin
  SetLength(list, Length(list) + 1);
  list[High(list)].path := path;
  list[High(list)].store := store;
end;

{ --- libraryfolders.vdf ------------------------------------------------------------------------------------------ }

function ParseLibraryFolders(const text: AnsiString): TPaths;
var
  tokens: array of AnsiString;
  quoted: array of Boolean;
  i: Integer;
  tok: AnsiString;
  key: AnsiString;
  depth: Integer;

  procedure Push(const t: AnsiString; q: Boolean);
  begin
    SetLength(tokens, Length(tokens) + 1);
    SetLength(quoted, Length(quoted) + 1);
    tokens[High(tokens)] := t;
    quoted[High(quoted)] := q;
  end;

  { True when s is digits only, as an older file's library keys are }
  function Numbered(const s: AnsiString): Boolean;
  var
    k: Integer;
  begin
    Result := s <> '';
    for k := 1 to Length(s) do
      Result := Result and (s[k] in ['0'..'9']);
  end;

begin
  Result := nil;
  tokens := nil;
  quoted := nil;
  i := 1;
  while i <= Length(text) do begin
    case text[i] of
      '"': begin
             tok := '';
             Inc(i);
             while (i <= Length(text)) and (text[i] <> '"') do begin
               if (text[i] = '\') and (i < Length(text)) then
                 Inc(i);
               tok := tok + text[i];
               Inc(i);
             end;
             Push(tok, True);
           end;
      '{', '}': Push(text[i], False);
      '/': if (i < Length(text)) and (text[i + 1] = '/') then
             while (i <= Length(text)) and not (text[i] in [#10, #13]) do
               Inc(i);
    end;
    Inc(i);
  end;
  { a key and its value are two quoted tokens in a row; a key before a brace opens a block. The older form's numbered
    libraries are in the outer block (depth 1); the current form's numbered blocks hold apps' numbered sizes deeper. }
  i := 0;
  depth := 0;
  while i <= High(tokens) do begin
    if not quoted[i] then begin
      if tokens[i] = '{' then
        Inc(depth)
      else
        Dec(depth);
      Inc(i);
    end else if (i < High(tokens)) and quoted[i + 1] then begin
      key := tokens[i];
      if (CompareText(key, 'path') = 0) or (Numbered(key) and (depth = 1)) then
        if Length(tokens[i + 1]) <= 255 then
          Add(Result, tokens[i + 1]);
      Inc(i, 2);
    end else
      Inc(i);
  end;
end;

{ the whole of file name as text; empty when it cannot be read }
function ReadText(const name: ShortString): AnsiString;
var
  f: File;
  n: LongInt;
begin
  Result := '';
  System.Assign(f, name);
  FileMode := FileMode and not 3;
  Reset(f, 1);
  if IOResult <> 0 then
    Exit;
  n := FileSize(f);
  if (IOResult = 0) and (n > 0) and (n < 1048576) then begin
    SetLength(Result, n);
    BlockRead(f, Result[1], n);
    if IOResult <> 0 then
      Result := '';
  end;
  Close(f);
  n := IOResult;
end;

{ the subfolders of parent, by name }
function SubFolders(const parent: ShortString): TPaths;
var
  sr: TSearchRec;
  i, j: Integer;
  t: ShortString;
begin
  Result := nil;
  if (parent = '') or not DirectoryExists(parent) then
    Exit;
  if FindFirst(Slashed(parent) + AllFilesMask, faDirectory, sr) = 0 then begin
    repeat
      if (sr.Attr and faDirectory <> 0) and (sr.Name <> '.') and (sr.Name <> '..') then
        Add(Result, Slashed(parent) + sr.Name);
    until FindNext(sr) <> 0;
    FindClose(sr);
  end;
  { FindFirst's order is the file system's: sorted, so the list is the same each time }
  for i := 1 to High(Result) do begin
    t := Result[i];
    j := i - 1;
    while (j >= 0) and (Result[j] > t) do begin
      Result[j + 1] := Result[j];
      Dec(j);
    end;
    Result[j + 1] := t;
  end;
end;

{ --- the roots --------------------------------------------------------------------------------------------------- }

{$IFDEF WINDOWS}
const
  { RegOpenKeyEx: the 32-bit registry view, where GOG's 32-bit installer writes (SOFTWARE\WOW6432Node to a 64-bit
    program) }
  KEY_WOW64_32KEY = $0200;

{ The string value of key under root (in the registry's 32-bit view when wow32); empty when there is none. }
function RegString(root: HKEY; const key, value: ShortString; wow32: Boolean): ShortString;
var
  h: HKEY;
  access: REGSAM;
  buf: array[0..1023] of Char;
  size: DWORD;
  kind: DWORD;
  k, v: AnsiString;
begin
  Result := '';
  access := KEY_READ;
  if wow32 then
    access := access or KEY_WOW64_32KEY;
  k := key;
  v := value;
  if RegOpenKeyExA(root, PChar(k), 0, access, h) <> ERROR_SUCCESS then
    Exit;
  size := SizeOf(buf) - 1;
  if (RegQueryValueExA(h, PChar(v), nil, @kind, @buf, @size) = ERROR_SUCCESS) and
     (kind in [REG_SZ, REG_EXPAND_SZ]) then begin
    buf[size] := #0;
    Result := StrPas(buf);
  end;
  RegCloseKey(h);
end;
{$ENDIF}

function DefaultRoots(const game: TStoreGame; os: TOs; const home: ShortString): TSearchRoots;
var
  xdg: ShortString;
{$IFDEF WINDOWS}
  s: ShortString;
  x86: ShortString;
{$ENDIF}
begin
  Result := Default(TSearchRoots);
  case os of
    OS_LINUX: begin
                xdg := GetEnvironmentVariable('XDG_DATA_HOME');
                if xdg <> '' then
                  Add(Result.steamRoots, Join(xdg, 'Steam'));
                Add(Result.steamRoots, Join(home, '.local/share/Steam'));
                Add(Result.steamRoots, Join(home, '.steam/steam'));
                Add(Result.steamRoots, Join(home, '.var/app/com.valvesoftware.Steam/.local/share/Steam'));
                Add(Result.gogParents, Join(home, 'GOG Games'));
                Add(Result.gogParents, '/opt/GOG Games');
                Add(Result.heroicParents, Join(home, 'Games/Heroic'));
              end;
    OS_MAC: begin
              Add(Result.steamRoots, Join(home, 'Library/Application Support/Steam'));
              Add(Result.appFolders, '/Applications');
              Add(Result.appFolders, Join(home, 'Applications'));
              Add(Result.heroicParents, Join(home, 'Games/Heroic'));
            end;
    OS_WINDOWS: begin
{$IFDEF WINDOWS}
                  x86 := GetEnvironmentVariable('ProgramFiles(x86)');
                  if x86 = '' then
                    x86 := GetEnvironmentVariable('ProgramFiles');
                  if x86 = '' then
                    x86 := 'C:\Program Files (x86)';
                  Add(Result.steamRoots, RegString(HKEY_CURRENT_USER, 'Software\Valve\Steam', 'SteamPath', False));
                  Add(Result.steamRoots, Join(x86, 'Steam'));
                  s := RegString(HKEY_LOCAL_MACHINE, 'SOFTWARE\GOG.com\Games\' + game.gogId, 'path', True);
                  Add(Result.gogPaths, s);
                  s := RegString(HKEY_LOCAL_MACHINE, 'SOFTWARE\GOG.com\Games\' + game.gogId, 'path', False);
                  Add(Result.gogPaths, s);
                  Add(Result.gogMarkerParents, 'C:\GOG Games');
                  Add(Result.gogMarkerParents, Join(x86, 'GOG Galaxy\Games'));
                  Add(Result.gogMarkerParents, Join(x86, 'GOG.com'));
{$ENDIF}
                  Add(Result.heroicParents, Join(home, 'Games\Heroic'));
                end;
  end;
end;

function Candidates(const roots: TSearchRoots; const game: TStoreGame): TCandidates;
var
  libs: TPaths;
  subs: TPaths;
  i, j: Integer;
begin
  Result := nil;
  for i := 0 to High(roots.steamRoots) do begin
    { the Steam folder is its first library, and libraryfolders.vdf names it again: Found keeps one }
    AddCandidate(Result, Join(roots.steamRoots[i], 'steamapps/common/' + game.steamFolder), 'Steam');
    libs := ParseLibraryFolders(ReadText(Join(roots.steamRoots[i], 'steamapps/libraryfolders.vdf')));
    for j := 0 to High(libs) do
      AddCandidate(Result, Join(libs[j], 'steamapps/common/' + game.steamFolder), 'Steam');
  end;
  for i := 0 to High(roots.gogPaths) do
    AddCandidate(Result, Join(roots.gogPaths[i], game.gogFolder), 'GOG');
  for i := 0 to High(roots.gogMarkerParents) do begin
    subs := SubFolders(roots.gogMarkerParents[i]);
    for j := 0 to High(subs) do
      if FileExists(Join(subs[j], 'goggame-' + game.gogId + '.info')) then
        AddCandidate(Result, Join(subs[j], game.gogFolder), 'GOG');
  end;
  for i := 0 to High(roots.gogParents) do begin
    subs := SubFolders(roots.gogParents[i]);
    for j := 0 to High(subs) do
      AddCandidate(Result, Join(subs[j], game.gogLinuxFolder), 'GOG');
  end;
  for i := 0 to High(roots.appFolders) do
    AddCandidate(Result, Join(roots.appFolders[i], game.gogMacFolder), 'GOG (Mac app)');
  for i := 0 to High(roots.heroicParents) do begin
    subs := SubFolders(roots.heroicParents[i]);
    for j := 0 to High(subs) do begin
      AddCandidate(Result, Join(subs[j], game.gogFolder), 'Heroic');
      AddCandidate(Result, Join(subs[j], game.gogLinuxFolder), 'Heroic');
      AddCandidate(Result, Join(subs[j], game.gogMacFolder), 'Heroic');
    end;
  end;
end;

function SameFolder(const a, b: ShortString): Boolean;
{$IFDEF UNIX}
var
  sa, sb: Stat;
{$ENDIF}
begin
{$IFDEF UNIX}
  if (FpStat(a, sa) = 0) and (FpStat(b, sb) = 0) then
    Exit((sa.st_dev = sb.st_dev) and (sa.st_ino = sb.st_ino));
  Result := ExcludeTrailingPathDelimiter(ExpandFileName(a)) = ExcludeTrailingPathDelimiter(ExpandFileName(b));
{$ELSE}
  Result := CompareText(ExcludeTrailingPathDelimiter(ExpandFileName(a)),
                        ExcludeTrailingPathDelimiter(ExpandFileName(b))) = 0;
{$ENDIF}
end;

function Found(const list: TCandidates; const game: TStoreGame): TCandidates;
var
  i, j: Integer;
  seen: Boolean;
begin
  Result := nil;
  for i := 0 to High(list) do
    if HoldsData(list[i].path, game) then begin
      seen := False;
      for j := 0 to High(Result) do
        seen := seen or SameFolder(Result[j].path, list[i].path);
      if not seen then
        AddCandidate(Result, list[i].path, list[i].store);
    end;
end;

{ True when folder dir has file name, whatever its case }
function HasFile(const dir, name: ShortString): Boolean;
begin
  Result := (dir <> '') and DirectoryExists(dir) and FileExists(NatFile.NativeName(Slashed(dir) + name));
end;

function HoldsData(const dir: ShortString; const game: TStoreGame): Boolean;
begin
  Result := HasFile(dir, game.dataFile);
end;

function HoldsGame(const dir: ShortString): Boolean;
begin
  Result := HasFile(dir, 'POOL.CFG') or HasFile(dir, 'GEO1.DAX');
end;

{ --- the folders ------------------------------------------------------------------------------------------------- }

function UserFolder(const game: TStoreGame; os: TOs; const home: ShortString): ShortString;
var
  base: ShortString;
begin
  case os of
    OS_MAC: Result := Join(home, 'Library/Application Support/' + game.name);
    OS_WINDOWS: begin
                  base := GetEnvironmentVariable('APPDATA');
                  if base = '' then
                    base := Join(home, 'AppData\Roaming');
                  Result := Join(base, game.name);
                end;
  else
    begin
      base := GetEnvironmentVariable('XDG_DATA_HOME');
      if base = '' then
        base := Join(home, '.local/share');
      Result := Join(base, game.linuxName);
    end;
  end;
  Result := Slashed(Result);
end;

{ the player's home folder }
function Home: ShortString;
begin
  Result := GetUserDir;
end;

function InAppBundle(const dir: ShortString): Boolean;
begin
  Result := Pos('.APP' + PathDelim + 'CONTENTS', UpperCase(Join(dir, ''))) > 0;
end;

function MustNotWrite(const dir: ShortString): Boolean;
var
  h: THandle;
  probe: ShortString;
begin
  Result := True;
  if InAppBundle(dir) then
    Exit;
  probe := Slashed(dir) + PROBE_NAME;
  h := FileCreate(probe);
  if h = THandle(-1) then
    Exit;
  FileClose(h);
  DeleteFile(probe);
  Result := False;
end;

function AppFolder: ShortString;
var
  exeDir: ShortString;
begin
  exeDir := ExtractFileDir(ExpandFileName(ParamStr(0)));
  { <folder>/<name>.app/Contents/MacOS: three levels up }
  if SameText(ExtractFileName(exeDir), 'MacOS') then
    exeDir := ExtractFileDir(ExtractFileDir(ExtractFileDir(exeDir)));
  Result := Slashed(exeDir);
end;

function OwnFolder(const name: ShortString): ShortString;
begin
  Result := AppFolder;
  if not HasFile(Result, name) then
    Result := dataFolder;
end;

function ReadName(const name: ShortString): ShortString;
begin
  Result := Slashed(writeFolder) + name;
  if (writeFolder = '') or not FileExists(NatFile.NativeName(Result)) then
    Result := Slashed(dataFolder) + name;
end;

function Remembered(const game: TStoreGame): ShortString;
var
  s: AnsiString;
  i: Integer;
begin
  s := ReadText(UserFolder(game, THIS_OS, Home) + REMEMBER_NAME);
  i := Pos(#10, s);
  if i > 0 then
    SetLength(s, i - 1);
  Result := Trim(s);
end;

function Remember(const game: TStoreGame; const dir: ShortString): Boolean;
var
  t: Text;
  folder: ShortString;
begin
  folder := UserFolder(game, THIS_OS, Home);
  ForceDirectories(folder);
  System.Assign(t, folder + REMEMBER_NAME);
  Rewrite(t);
  WriteLn(t, ExcludeTrailingPathDelimiter(dir));
  Close(t);
  Result := IOResult = 0;
end;

procedure Place(const game: TStoreGame; const dir: ShortString; beside: Boolean);
begin
  dataFolder := Slashed(ExpandFileName(dir));
  if beside and not MustNotWrite(dataFolder) then
    writeFolder := dataFolder
  else begin
    writeFolder := UserFolder(game, THIS_OS, Home);
    if not ForceDirectories(writeFolder) then begin
      WriteLn(StdErr, 'Pool of Radiance: cannot make ', writeFolder, ': writing in ', dataFolder);
      writeFolder := dataFolder;
    end;
  end;
end;

procedure Take(const game: TStoreGame; const dir: ShortString);
begin
  Place(game, dir, False);
  if not Remember(game, dataFolder) then
    WriteLn(StdErr, 'Pool of Radiance: cannot remember the data folder in ', UserFolder(game, THIS_OS, Home));
end;

function OptionValue(const opt: ShortString): ShortString;
var
  i: Integer;
begin
  Result := '';
  for i := 1 to ParamCount do
    if ParamStr(i) = opt then begin
      if i < ParamCount then
        Result := ParamStr(i + 1);
      Exit;
    end else if Copy(ParamStr(i), 1, Length(opt) + 1) = opt + '=' then
      Exit(Copy(ParamStr(i), Length(opt) + 2, 255));
end;

function HasOption(const opt: ShortString): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 1 to ParamCount do
    Result := Result or (ParamStr(i) = opt);
end;

function Settle(const game: TStoreGame; var hits: TCandidates; var ask: Boolean): Boolean;
var
  beside: array[1..4] of ShortString;
  given: ShortString;
  i: Integer;
begin
  Result := True;
  hits := nil;
  ask := HasOption(OPT_CHOOSE);
  given := OptionValue(OPT_DATA_FOLDER);
  if given <> '' then begin
    if HoldsData(given, game) then begin
      Take(game, given);
      Exit;
    end;
    WriteLn(StdErr, 'Pool of Radiance: no ', game.dataFile, ' in ', given);
    ask := True;
  end;
  if not ask then begin
    beside[1] := GetEnvironmentVariable('POOLRAD_DIR');
    beside[2] := GetCurrentDir;
    beside[3] := ExtractFileDir(ExpandFileName(ParamStr(0)));
    beside[4] := AppFolder;
    for i := Low(beside) to High(beside) do
      if HoldsGame(beside[i]) then begin
        Place(game, beside[i], True);
        Exit;
      end;
    given := Remembered(game);
    if HoldsData(given, game) then begin
      Place(game, given, False);
      Exit;
    end;
  end;
  hits := Found(Candidates(DefaultRoots(game, THIS_OS, Home), game), game);
  if (Length(hits) = 1) and not ask then begin
    Take(game, hits[0].path);
    Exit;
  end;
  Result := False;
end;

end.

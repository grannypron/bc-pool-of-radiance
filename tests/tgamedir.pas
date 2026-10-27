{ Tests native game-data discovery (#1064): Steam library files, GOG layouts on
  each platform, default and per-user roots, duplicate removal, case-insensitive
  data files, application bundles, and writable-directory checks. The DOS build
  intentionally has no assertions here. }
{$IFDEF FPC}
{$MODE OBJFPC}
{$H-}
{$ENDIF}
{$I COMPILER.INC}
program TGameDir;

uses {$IFDEF FPC}SysUtils, {$IFDEF UNIX}BaseUnix, {$ENDIF}GameDirs, {$ENDIF}TestKit;

{$IFDEF FPC}
const
  NL = #10;
  FIX = 'GDFIX';

var
  roots: TSearchRoots;
  list: TCandidates;
  hits: TCandidates;
  libs: TPaths;
  i: Integer;
  base: ShortString;
  steamData: ShortString;

{ path with '/' as this system's separator }
function Native(const path: ShortString): ShortString;
var
  k: Integer;
begin
  Result := path;
  for k := 1 to Length(Result) do
    if Result[k] in ['/', '\'] then
      Result[k] := PathDelim;
end;

{ path as libraryfolders.vdf writes it: each backslash doubled }
function Escaped(const path: ShortString): ShortString;
var
  k: Integer;
begin
  Result := '';
  for k := 1 to Length(path) do
    if path[k] = '\' then
      Result := Result + '\\'
    else
      Result := Result + path[k];
end;

{ Make file name (its folders too) holding text. }
procedure PutFile(const name: ShortString; const text: AnsiString);
var
  t: Text;
begin
  ForceDirectories(ExtractFileDir(Native(name)));
  Assign(t, Native(name));
  Rewrite(t);
  Write(t, text);
  Close(t);
end;

{ True when list holds a candidate at path (with its closing separator or not) from store }
function Has(const l: TCandidates; const path, store: ShortString): Boolean;
var
  k: Integer;
begin
  Result := False;
  for k := 0 to High(l) do
    Result := Result or ((ExcludeTrailingPathDelimiter(l[k].path) = ExcludeTrailingPathDelimiter(Native(path))) and
                         (l[k].store = store));
end;
{$ENDIF}

begin
  TestKit.Start('TGAMEDIR');
{$IFDEF FPC}
  { libraryfolders.vdf }
  libs := GameDirs.ParseLibraryFolders(AnsiString('"libraryfolders"') + NL + '{' + NL + #9'"0"' + NL + #9'{' + NL +
    #9#9'"path"'#9#9'"/home/p/.local/share/Steam"' + NL + #9#9'"label"'#9#9'""' + NL + #9#9'"apps"' + NL +
    #9#9'{' + NL +
    #9#9#9'"1882280"'#9#9'"0"' + NL + #9#9'}' + NL + #9'}' + NL + #9'"1"' + NL + #9'{' + NL +
    #9#9'"path"'#9#9'"/mnt/games/Steam Library"' + NL + #9'}' + NL + '}' + NL);
  TestKit.CheckEqualsL(2, Length(libs), 'libraryfolders.vdf: two libraries');
  if Length(libs) = 2 then begin
    TestKit.CheckEqualsS('/home/p/.local/share/Steam', libs[0], 'the first library''s path');
    TestKit.CheckEqualsS('/mnt/games/Steam Library', libs[1], 'the second, with a space');
  end;
  libs := GameDirs.ParseLibraryFolders('"libraryfolders" { "0" { "path" "C:\\Program Files (x86)\\Steam" }' +
    ' // a comment "path" "X"' + NL + ' "1" { "PATH" "D:\\Games\\\"Steam\"" } }');
  TestKit.CheckEqualsL(2, Length(libs), 'Windows'' paths, past a comment');
  if Length(libs) = 2 then begin
    TestKit.CheckEqualsS('C:\Program Files (x86)\Steam', libs[0], 'its backslashes unescaped');
    TestKit.CheckEqualsS('D:\Games\"Steam"', libs[1], 'a quote unescaped, the key in any case');
  end;
  libs := GameDirs.ParseLibraryFolders('"LibraryFolders"' + NL + '{' + NL + '"TimeNextStatsReport" "1612345678"' + NL +
    '"ContentStatsID" "-123"' + NL + '"1" "E:\\SteamLibrary"' + NL + '}');
  TestKit.CheckEqualsL(1, Length(libs), 'the older form: a numbered key''s value');
  if Length(libs) = 1 then
    TestKit.CheckEqualsS('E:\SteamLibrary', libs[0], 'is the library');
  TestKit.CheckEqualsL(0, Length(GameDirs.ParseLibraryFolders('')), 'an empty file names none');
  TestKit.CheckEqualsL(0, Length(GameDirs.ParseLibraryFolders('"path" {')), 'nor one cut short');

  { the stores' folders, built here }
  base := IncludeTrailingPathDelimiter(ExpandFileName(FIX));
  steamData := base + 'lib2/steamapps/common/' + GameDirs.POOL.steamFolder;
  PutFile(base + 'steam/steamapps/libraryfolders.vdf', AnsiString('"libraryfolders" { "0" { "path" "') +
          Escaped(base) + 'steam" } "1" { "path" "' + Escaped(base) + 'lib2" } }');
  PutFile(steamData + '/geo1.dax', 'x');
  PutFile(base + 'reg/POOLRAD/GEO1.DAX', 'x');
  PutFile(base + 'gogwin/PoR/goggame-1432640961.info', '{}');
  PutFile(base + 'gogwin/PoR/POOLRAD/GEO1.DAX', 'x');
  PutFile(base + 'gogwin/Unmarked/POOLRAD/GEO1.DAX', 'x');
  PutFile(base + 'gog/Pool of Radiance/data/POOLRAD/GEO1.DAX', 'x');
  PutFile(base + 'gog/Curse/data/CURSE/GEO1.DAX', 'x');
  PutFile(base + 'Applications/Pool of Radiance.app/Contents/Resources/game/POOLRAD/GEO1.DAX', 'x');
  PutFile(base + 'empty/README', 'x');
  roots := Default(TSearchRoots);
  SetLength(roots.steamRoots, 1);
  roots.steamRoots[0] := base + 'steam';
{$IFDEF UNIX}
  { a link to the Steam folder, as ~/.steam/steam is: the same library twice }
  DeleteFile(base + 'steamlink');
  if FpSymlink(PChar(AnsiString(base + 'steam')), PChar(AnsiString(base + 'steamlink'))) = 0 then begin
    SetLength(roots.steamRoots, 2);
    roots.steamRoots[1] := base + 'steamlink';
  end;
{$ENDIF}
  SetLength(roots.gogPaths, 1);
  roots.gogPaths[0] := base + 'reg';
  SetLength(roots.gogMarkerParents, 1);
  roots.gogMarkerParents[0] := base + 'gogwin';
  SetLength(roots.gogParents, 2);
  roots.gogParents[0] := base + 'gog';
  roots.gogParents[1] := base + 'no such folder';
  SetLength(roots.appFolders, 1);
  roots.appFolders[0] := base + 'Applications';
  list := GameDirs.Candidates(roots, GameDirs.POOL);
  TestKit.Check(Has(list, base + 'steam/steamapps/common/' + GameDirs.POOL.steamFolder, 'Steam'),
                'a candidate in the Steam folder''s own library');
  TestKit.Check(Has(list, steamData, 'Steam'), 'and in the library libraryfolders.vdf names');
  TestKit.Check(Has(list, base + 'reg/POOLRAD', 'GOG'), 'GOG''s registry install, its POOLRAD folder');
  TestKit.Check(Has(list, base + 'gogwin/PoR/POOLRAD', 'GOG'), 'a GOG Windows install with its marker');
  TestKit.Check(not Has(list, base + 'gogwin/Unmarked/POOLRAD', 'GOG'), 'but not one without');
  TestKit.Check(Has(list, base + 'gog/Pool of Radiance/data/POOLRAD', 'GOG'), 'a GOG Linux install');
  TestKit.Check(Has(list, base + 'gog/Curse/data/POOLRAD', 'GOG'), 'each subfolder of GOG Games is tried');
  TestKit.Check(Has(list, base + 'Applications/Pool of Radiance.app/Contents/Resources/game/POOLRAD', 'GOG (Mac app)'),
                'GOG''s Mac app');
  TestKit.Check((Length(list) > 0) and (list[0].store = 'Steam'), 'Steam''s come first');

  hits := GameDirs.Found(list, GameDirs.POOL);
  TestKit.CheckEqualsL(5, Length(hits), 'Found keeps the five that hold the data, each once');
  TestKit.Check(Has(hits, steamData, 'Steam'), 'Steam''s, its GEO1.DAX in lower case');
  TestKit.Check(Has(hits, base + 'reg/POOLRAD', 'GOG'), 'the registry''s');
  TestKit.Check(Has(hits, base + 'gogwin/PoR/POOLRAD', 'GOG'), 'the marked one');
  TestKit.Check(Has(hits, base + 'gog/Pool of Radiance/data/POOLRAD', 'GOG'), 'GOG Games''');
  TestKit.Check(Has(hits, base + 'Applications/Pool of Radiance.app/Contents/Resources/game/POOLRAD',
                'GOG (Mac app)'), 'the Mac app''s');
  TestKit.CheckEqualsL(0, Length(GameDirs.Found(GameDirs.Candidates(Default(TSearchRoots), GameDirs.POOL),
                       GameDirs.POOL)), 'no roots, nothing found');

  { the folders' tests }
  TestKit.Check(GameDirs.HoldsData(base + 'reg/POOLRAD', GameDirs.POOL), 'HoldsData: GEO1.DAX');
  TestKit.Check(not GameDirs.HoldsData(base + 'empty', GameDirs.POOL), 'not without');
  TestKit.Check(not GameDirs.HoldsData('', GameDirs.POOL), 'nor an empty path');
  TestKit.Check(GameDirs.HoldsGame(base + 'reg/POOLRAD'), 'HoldsGame: the data');
  PutFile(base + 'cfgonly/pool.cfg', 'x');
  TestKit.Check(GameDirs.HoldsGame(base + 'cfgonly'), 'or POOL.CFG, in any case');
  TestKit.Check(not GameDirs.HoldsData(base + 'cfgonly', GameDirs.POOL), 'which is not the data');
  TestKit.Check(GameDirs.SameFolder(base + 'reg', base + 'reg' + PathDelim), 'SameFolder: a closing separator');
  TestKit.Check(not GameDirs.SameFolder(base + 'reg', base + 'gog'), 'two folders');
  TestKit.Check(GameDirs.InAppBundle(Native('/Applications/Pool of Radiance.app/Contents/Resources/game/POOLRAD/')),
                'InAppBundle: inside a .app');
  TestKit.Check(not GameDirs.InAppBundle(Native('/Games/POOLRAD/')), 'not elsewhere');
  TestKit.Check(GameDirs.MustNotWrite(base + 'Applications/Pool of Radiance.app/Contents/Resources/game/POOLRAD'),
                'MustNotWrite: the Mac app''s data, though this folder may be written');
  TestKit.Check(not GameDirs.MustNotWrite(base + 'empty'), 'a folder that may be written');
  TestKit.Check(GameDirs.MustNotWrite(base + 'no such folder'), 'nor one that is not there');
  TestKit.Check(not FileExists(base + 'empty' + PathDelim + 'poolrad.$$$'), 'the test leaves no file behind');

  { the per-user folders and the default roots }
  TestKit.CheckEqualsS(Native('/h/Library/Application Support/Pool of Radiance/'),
                       GameDirs.UserFolder(GameDirs.POOL, OS_MAC, Native('/h/')), 'macOS'' own folder');
  if GetEnvironmentVariable('XDG_DATA_HOME') = '' then
    TestKit.CheckEqualsS(Native('/h/.local/share/pool-of-radiance/'),
                         GameDirs.UserFolder(GameDirs.POOL, OS_LINUX, Native('/h/')), 'Linux''s own folder');
  if GetEnvironmentVariable('APPDATA') <> '' then
    TestKit.CheckEqualsS(IncludeTrailingPathDelimiter(GetEnvironmentVariable('APPDATA')) + 'Pool of Radiance' +
                         PathDelim, GameDirs.UserFolder(GameDirs.POOL, OS_WINDOWS, Native('/h/')),
                         'Windows'' own folder, in APPDATA');
  roots := GameDirs.DefaultRoots(GameDirs.POOL, OS_LINUX, Native('/h'));
  TestKit.Check(Length(roots.steamRoots) >= 3, 'Linux: Steam''s three folders');
  TestKit.Check(Has(GameDirs.Candidates(roots, GameDirs.POOL), '/h/.var/app/com.valvesoftware.Steam/.local/share/' +
                'Steam/steamapps/common/' + GameDirs.POOL.steamFolder, 'Steam'), 'Flatpak''s Steam among them');
  TestKit.Check((Length(roots.gogParents) = 2) and (roots.gogParents[1] = '/opt/GOG Games'),
                'GOG Games, in the home folder and /opt');
  roots := GameDirs.DefaultRoots(GameDirs.POOL, OS_MAC, Native('/h'));
  TestKit.Check((Length(roots.appFolders) = 2) and (roots.appFolders[0] = '/Applications'),
                'macOS: /Applications and ~/Applications');
  TestKit.CheckEqualsS(Native('/h/Library/Application Support/Steam'), roots.steamRoots[0], 'and Steam''s folder');
{$ENDIF}
  TestKit.Done;
end.

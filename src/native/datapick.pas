{ Finding the game's data at start (#1064): GameDirs.Settle finds it without asking where it can; otherwise the player
  chooses here, in the game's window before anything of the game is shown, in the BIOS's 40-column text (the data, and
  so the game's own font, is not found yet). Several copies found: a list to pick from, with Another Folder. None: the
  system's folder picker (SDL_ShowOpenFolderDialog), or, where it cannot open (a Linux desktop without the XDG portal or
  zenity), a typed path. A folder chosen is taken only when it holds the data, and remembered (GameDirs.Take).
  Escape on the list, or cancelling the picker with nothing found, leaves the game with a message. Free Pascal only. }
{$MODE OBJFPC}
{$H-}
unit DataPick;

interface

{ Find the game's data folder (GameDirs.Settle), asking the player when that cannot, and make it the current folder. }
procedure FindGame;

implementation

uses SysUtils, Crt, Host, Sdl3Min, SdlHost, GameDirs;

const
  COLS = 40;
  ROWS = 25;
  { the DAC entries the screen is drawn in }
  C_TEXT = 7;
  C_TITLE = 14;
  C_KEY = 11;
  C_PATH = 15;
  C_BAD = 12;
  { the most copies the list shows }
  MAX_SHOWN = 6;
  { the keys read }
  KEY_ENTER = #13;
  KEY_ESC = #27;
  KEY_BS = #8;
  SCAN_UP = #72;
  SCAN_DOWN = #80;

type
  { what the folder picker gave: a folder, nothing (cancelled), or no picker }
  TPicked = (PICK_FOLDER, PICK_CANCELLED, PICK_FAILED);

var
  { the folder picker's answer, which its callback may give on another thread }
  dialogDone: Boolean;
  dialogFailed: Boolean;
  dialogPath: ShortString;

{ --- the screen -------------------------------------------------------------------------------------------------- }

procedure SetColor(index, r, g, b: Byte);
begin
  Host.dac[index, 0] := r;
  Host.dac[index, 1] := g;
  Host.dac[index, 2] := b;
end;

{ An empty screen in mode 13h, with the colours the text is drawn in. }
procedure ClearScreen;
var
  regs: Host.Registers;
begin
  regs.ah := 0;
  regs.al := Host.VGA_MODE;
  Host.Intr($10, regs);
  SetColor(C_TEXT, 42, 42, 42);
  SetColor(C_TITLE, 63, 63, 21);
  SetColor(C_KEY, 21, 63, 63);
  SetColor(C_PATH, 63, 63, 63);
  SetColor(C_BAD, 63, 21, 21);
end;

{ s at (col, row) in colour, cut at the screen's edge }
procedure Put(col, row: Byte; color: Byte; const s: ShortString);
var
  regs: Host.Registers;
  i: Integer;
begin
  for i := 1 to Length(s) do begin
    if col + i - 1 >= COLS then
      Break;
    regs.ah := 2;
    regs.bh := 0;
    regs.dh := row;
    regs.dl := col + i - 1;
    Host.Intr($10, regs);
    regs.ah := 9;
    regs.al := Ord(s[i]);
    regs.bl := color;
    regs.bh := 0;
    regs.cx := 1;
    Host.Intr($10, regs);
  end;
end;

{ path from (col, row) on, broken across at most lines rows of the screen's width from col; the rows it took }
function PutPath(col, row, lines: Byte; color: Byte; const path: ShortString): Byte;
var
  width: Byte;
  rest: ShortString;
begin
  width := COLS - col;
  rest := path;
  Result := 0;
  while (rest <> '') and (Result < lines) do begin
    if (Result = lines - 1) and (Length(rest) > width) then
      rest := '...' + Copy(rest, Length(rest) - width + 4, width);
    Put(col, row + Result, color, Copy(rest, 1, width));
    Delete(rest, 1, width);
    Inc(Result);
  end;
end;

{ Clear the screen, with the title at its top. }
procedure Page;
begin
  ClearScreen;
  Put(1, 1, C_TITLE, 'Pool of Radiance');
end;

{ Show lines of text from row 3, then wait for a key: the key. }
function Notice(const lines: array of ShortString; const path: ShortString; prompt: ShortString): Char;
var
  i: Integer;
  row: Byte;
begin
  Page;
  row := 3;
  for i := 0 to High(lines) do begin
    Put(1, row, C_TEXT, lines[i]);
    Inc(row);
  end;
  if path <> '' then
    PutPath(1, row + 1, 6, C_PATH, path);
  Put(1, ROWS - 2, C_KEY, prompt);
  Result := ReadKey;
  if Result = #0 then
    ReadKey;
end;

{ Leave the game: no data folder was chosen. }
procedure GiveUp;
begin
  WriteLn(StdErr, 'Pool of Radiance: no data folder was chosen. Run poolrad --data-folder PATH, or poolrad again',
          ' to choose one.');
  Notice(['No folder was chosen. The game needs', 'Pool of Radiance''s data (GEO1.DAX)', 'from GOG, Steam or the',
          'original disks.', '', 'Run it again to choose one, or give it', 'with --data-folder PATH.'], '',
         'Press a key to quit');
  Halt(0);
end;

{ --- choosing a folder ------------------------------------------------------------------------------------------- }

procedure DialogAnswered(userdata: Pointer; filelist: PPChar; filter: LongInt); cdecl;
begin
  if filelist = nil then
    dialogFailed := True
  else if filelist^ <> nil then
    dialogPath := StrPas(filelist^);
  dialogDone := True;
end;

{ The system's folder picker, starting in the home folder; the folder chosen in path. }
function PickFolder(var path: ShortString): TPicked;
var
  start: AnsiString;
begin
  Page;
  Put(1, 3, C_TEXT, 'Choose the folder that holds');
  Put(1, 4, C_TEXT, 'Pool of Radiance''s data (GEO1.DAX)');
  Put(1, 5, C_TEXT, 'in the window that has opened.');
  dialogDone := False;
  dialogFailed := False;
  dialogPath := '';
  start := GetUserDir;
  SDL_ShowOpenFolderDialog(@DialogAnswered, nil, SdlHost.GameWindow, PChar(start), False);
  while not dialogDone do begin
    Host.Service;
    Sleep(10);
  end;
  path := dialogPath;
  if dialogFailed then
    Result := PICK_FAILED
  else if path = '' then
    Result := PICK_CANCELLED
  else
    Result := PICK_FOLDER;
end;

{ The folder typed by the player, where no picker opens; False when Escape gave up. }
function TypeFolder(var path: ShortString): Boolean;
var
  key: Char;
  shown: ShortString;
begin
  path := '';
  repeat
    Page;
    Put(1, 3, C_TEXT, 'Type the folder that holds');
    Put(1, 4, C_TEXT, 'Pool of Radiance''s data (GEO1.DAX):');
    shown := path + '_';
    if Length(shown) > COLS - 2 then
      shown := Copy(shown, Length(shown) - (COLS - 3), COLS - 2);
    Put(1, 7, C_PATH, shown);
    Put(1, ROWS - 2, C_KEY, 'Enter Accept   Esc Cancel');
    key := ReadKey;
    case key of
      #0: ReadKey;
      KEY_BS: if path <> '' then
                SetLength(path, Length(path) - 1);
      KEY_ENTER: if path <> '' then
                   Exit(True);
      KEY_ESC: Exit(False);
      ' '..'~': if Length(path) < 255 then
                  path := path + key;
    end;
  until False;
end;

{ A folder from the picker or typed, taken when it holds the data: True when it was. With nothing found, a cancelled
  picker leaves the game. }
function OtherFolder(found: Boolean): Boolean;
var
  path: ShortString;
  picked: TPicked;
begin
  Result := False;
  picked := PickFolder(path);
  if picked = PICK_FAILED then
    if TypeFolder(path) then
      picked := PICK_FOLDER
    else
      picked := PICK_CANCELLED;
  if picked = PICK_CANCELLED then begin
    if not found then
      GiveUp;
    Exit;
  end;
  { a typed ~/ is the home folder, as a shell has it }
  if Copy(path, 1, 2) = '~/' then
    path := GetUserDir + Copy(path, 3, 255);
  path := ExpandFileName(path);
  if not GameDirs.HoldsData(path, GameDirs.POOL) then begin
    Notice(['This folder does not hold', 'Pool of Radiance''s data (GEO1.DAX):'], path, 'Press a key');
    Exit;
  end;
  GameDirs.Take(GameDirs.POOL, path);
  Result := True;
end;

{ folder path as the list shows it: without its closing separator, and in the home folder from ~ }
function Shown(const path: ShortString): ShortString;
var
  home: ShortString;
begin
  Result := ExcludeTrailingPathDelimiter(path);
  home := IncludeTrailingPathDelimiter(GetUserDir);
  if Copy(Result, 1, Length(home)) = home then
    Result := '~' + PathDelim + Copy(Result, Length(home) + 1, 255);
end;

{ The copies found, to pick from, and Another Folder; until one is taken. Escape leaves the game. }
procedure PickCopy(const hits: TCandidates);
var
  sel: Integer;
  count: Integer;
  i: Integer;
  row: Byte;
  key: Char;
begin
  count := Length(hits);
  if count > MAX_SHOWN then
    count := MAX_SHOWN;
  sel := 0;
  repeat
    Page;
    Put(1, 3, C_TEXT, 'Which copy of the game''s data?');
    row := 5;
    for i := 0 to count do begin
      if i = sel then
        Put(0, row, C_TITLE, '>');
      if i < count then begin
        Put(1, row, C_KEY, Chr(Ord('1') + i));
        Put(3, row, C_TEXT, hits[i].store);
        Inc(row);
        Inc(row, PutPath(3, row, 2, C_PATH, Shown(hits[i].path)));
      end else begin
        Put(1, row, C_KEY, Chr(Ord('1') + i));
        Put(3, row, C_TEXT, 'Another folder...');
      end;
      Inc(row);
    end;
    Put(1, ROWS - 2, C_KEY, 'Enter Choose   Esc Quit');
    key := ReadKey;
    if key = #0 then
      case ReadKey of
        SCAN_UP: sel := (sel + count) mod (count + 1);
        SCAN_DOWN: sel := (sel + 1) mod (count + 1);
      end
    else if key = KEY_ESC then
      GiveUp
    else if (key >= '1') and (key <= Chr(Ord('1') + count)) then begin
      sel := Ord(key) - Ord('1');
      key := KEY_ENTER;
    end;
    if key = KEY_ENTER then
      if sel < count then begin
        GameDirs.Take(GameDirs.POOL, hits[sel].path);
        Exit;
      end else if OtherFolder(True) then
        Exit;
  until False;
end;

procedure FindGame;
var
  hits: TCandidates;
  ask: Boolean;
begin
  if not GameDirs.Settle(GameDirs.POOL, hits, ask) then begin
    if Length(hits) > 0 then
      PickCopy(hits)
    else begin
      Notice(['No copy of Pool of Radiance was found', 'in GOG''s or Steam''s folders.', '',
              'Choose the folder that holds its data', '(GEO1.DAX) next.'], '', 'Press a key');
      while not OtherFolder(False) do;
    end;
    ClearScreen;
    FillChar(Host.dac, SizeOf(Host.dac), 0);
  end;
  ChDir(GameDirs.dataFolder);
end;

end.

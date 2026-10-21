{ The native build's file names as DOS took them: a backslash is a separator, and case does not matter. The game names
  its files in either case ('pool.cfg', 'POOL.CFG', 'savgam' + letter + '.dat') and the files of a DOS install are in
  capitals, which a case-sensitive file system (Linux; macOS's can be) tells apart. Each unit that opens a file uses
  this one last, so its Assign, Rename and MkDir, which find a name's file whatever its case, are the ones it calls;
  a file or folder that is not there yet is named in capitals, as DOS stored it. Objfpc mode: its routines must have
  System's own parameters (out, const) to be taken over System's. Free Pascal only. }
{$MODE OBJFPC}
{$H-}
{ the callers check IOResult (they are compiled {$I-}), so an error stays there rather than raising }
{$I-}
unit NatFile;

interface

{ name as this system has it: separators made '/', and each part that exists in another case given that case; a part
  that does not exist (a file about to be made) in capitals }
function NativeName(const name: ShortString): ShortString;

{ True when a and b are one name to DOS: equal but for case }
function SameName(const a, b: ShortString): Boolean;

procedure Assign(out f: File; const name: ShortString); overload;
procedure Assign(out t: Text; const name: ShortString); overload;
procedure Rename(var f: File; const name: ShortString); overload;
procedure Rename(var t: Text; const name: ShortString); overload;
procedure MkDir(const name: ShortString); overload;

{ Make the game's folder the current one: the first of POOLRAD_DIR, the current folder, the program's folder and, for a
  program in a macOS app (Pool of Radiance.app/Contents/MacOS), the folder the app is in, that holds POOL.CFG. With
  none, the current folder stays (the game then reports POOL.CFG missing, as on DOS). }
procedure EnterGameFolder;

implementation

uses SysUtils;

{ the entry of folder dir ('' for the current one) whose name is part whatever its case; '' when there is none }
function FindPart(const dir, part: ShortString): ShortString;
var
  sr: TSearchRec;
  path: ShortString;
begin
  Result := '';
  if dir = '' then
    path := '*'
  else
    path := dir + '*';
  if FindFirst(path, faAnyFile, sr) = 0 then begin
    repeat
      if CompareText(sr.Name, part) = 0 then begin
        Result := sr.Name;
        Break;
      end;
    until FindNext(sr) <> 0;
    FindClose(sr);
  end;
end;

function NativeName(const name: ShortString): ShortString;
var
  path: ShortString;
  dir: ShortString;
  part: ShortString;
  found: ShortString;
  i: Integer;
  missing: Boolean;
  trailing: Boolean;
begin
  path := name;
  for i := 1 to Length(path) do
    if path[i] = '\' then
      path[i] := '/';
  if (path = '') or FileExists(path) or DirectoryExists(path) then
    Exit(path);
  { part by part from the start: a part in another case takes the case it has; from the first part that is not there,
    capitals }
  trailing := path[Length(path)] = '/';
  dir := '';
  if path[1] = '/' then begin
    dir := '/';
    Delete(path, 1, 1);
  end;
  missing := False;
  while path <> '' do begin
    i := Pos('/', path);
    if i = 0 then
      i := Length(path) + 1;
    part := Copy(path, 1, i - 1);
    Delete(path, 1, i);
    if (part = '') or (part = '.') or (part = '..') then
      found := part
    else begin
      found := '';
      if not missing then
        found := FindPart(dir, part);
      if found = '' then begin
        missing := True;
        found := UpperCase(part);
      end;
    end;
    dir := dir + found;
    if (path <> '') or trailing then
      dir := dir + '/';
  end;
  Result := dir;
end;

function SameName(const a, b: ShortString): Boolean;
begin
  Result := CompareText(a, b) = 0;
end;

procedure Assign(out f: File; const name: ShortString);
begin
  System.Assign(f, NativeName(name));
end;

procedure Assign(out t: Text; const name: ShortString);
begin
  System.Assign(t, NativeName(name));
end;

procedure Rename(var f: File; const name: ShortString);
begin
  System.Rename(f, NativeName(name));
end;

procedure Rename(var t: Text; const name: ShortString);
begin
  System.Rename(t, NativeName(name));
end;

procedure MkDir(const name: ShortString);
begin
  System.MkDir(NativeName(name));
end;

{ True when folder dir holds POOL.CFG, whatever its case }
function HoldsGame(const dir: ShortString): Boolean;
begin
  Result := (dir <> '') and DirectoryExists(dir) and (FindPart(IncludeTrailingPathDelimiter(dir), 'POOL.CFG') <> '');
end;

procedure EnterGameFolder;
var
  candidates: array[1..4] of ShortString;
  exeDir: ShortString;
  i: Integer;
begin
  exeDir := ExtractFileDir(ParamStr(0));
  candidates[1] := GetEnvironmentVariable('POOLRAD_DIR');
  candidates[2] := GetCurrentDir;
  candidates[3] := exeDir;
  candidates[4] := '';
  { <folder>/Pool of Radiance.app/Contents/MacOS: three levels up }
  if SameText(ExtractFileName(exeDir), 'MacOS') then
    candidates[4] := ExtractFileDir(ExtractFileDir(ExtractFileDir(exeDir)));
  for i := Low(candidates) to High(candidates) do
    if HoldsGame(candidates[i]) then begin
      ChDir(candidates[i]);
      Exit;
    end;
end;

end.

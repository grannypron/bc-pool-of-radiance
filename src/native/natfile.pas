{ Gives native builds DOS-style filename behavior: backslashes are separators
  and case is ignored. Existing path components are resolved with their actual
  case; new files and directories use uppercase names. Units import NatFile
  after System so these Assign, Rename, and MkDir overloads handle their file
  operations. Free Pascal only. }
{$MODE OBJFPC}
{$H-}
{ the callers check IOResult (they are compiled $I-), so an error stays there rather than raising }
{$I-}
unit NatFile;

interface

{ Converts a DOS name to its native path. Existing components keep their actual
  case; components that do not yet exist are uppercased. }
function NativeName(const name: ShortString): ShortString;

{ Returns whether two names are equal under DOS's case-insensitive rules. }
function SameName(const a, b: ShortString): Boolean;

procedure Assign(out f: File; const name: ShortString); overload;
procedure Assign(out t: Text; const name: ShortString); overload;
procedure Rename(var f: File; const name: ShortString); overload;
procedure Rename(var t: Text; const name: ShortString); overload;
procedure MkDir(const name: ShortString); overload;

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

end.

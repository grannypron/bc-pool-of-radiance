{ Gives a terminal program a terminal of its own (#1098). On Linux, a program
  double-clicked in a file manager runs with no terminal, so poolcfg drew
  nowhere and crashed, saying nothing. Started like that, Start runs the
  program again in a terminal emulator, the first of the player's $TERMINAL and
  the common ones it finds, and does not come back. Windows gives a console
  program a console window, and macOS's Finder opens Terminal for one, so it
  does nothing there. Free Pascal only. }
{$MODE OBJFPC}
{$H+}
unit OwnTerm;

interface

{ The option a program run again in a terminal carries, so that it never tries a second time. }
const
  IN_TERMINAL = '--in-terminal';

{ Come back when this program has a terminal. Without one, run it again in a terminal emulator, with its options and
  IN_TERMINAL, when there is a desktop to open one on; and when that cannot be done, say so on the error output and
  leave (exit code 1), rather than drawing nowhere. }
procedure Start;

implementation

{$IFDEF LINUX}
uses SysUtils, BaseUnix, TermIO;

type
  { a terminal emulator: its program, and the option (if any) that puts the command after it }
  TTerminal = record
    exe: string[24];
    run: string[8];
  end;

const
  { in the order tried, after $TERMINAL: xdg-terminal-exec (the desktop's choice) and Debian's alternative first }
  TERMINALS: array[1..13] of TTerminal = (
    (exe: 'xdg-terminal-exec'; run: ''),
    (exe: 'x-terminal-emulator'; run: '-e'),
    (exe: 'konsole'; run: '-e'),
    (exe: 'gnome-terminal'; run: '--'),
    (exe: 'ptyxis'; run: '--'),
    (exe: 'kgx'; run: '--'),
    (exe: 'xfce4-terminal'; run: '-x'),
    (exe: 'mate-terminal'; run: '-x'),
    (exe: 'alacritty'; run: '-e'),
    (exe: 'kitty'; run: ''),
    (exe: 'foot'; run: ''),
    (exe: 'wezterm'; run: 'start'),
    (exe: 'xterm'; run: '-e'));

{ True when option opt is on the command line. }
function HasOption(const opt: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 1 to ParamCount do
    Result := Result or (ParamStr(i) = opt);
end;

{ Replace this program with terminal emulator exe, running this program after option run: comes back only when exe
  is not on the PATH or would not start. }
procedure TryTerminal(const exe, run: string);
var
  path: string;
  args: array of string;
  argv: array of PChar;
  i: Integer;
begin
  if Pos('/', exe) > 0 then
    path := exe
  else
    path := ExeSearch(exe, GetEnvironmentVariable('PATH'));
  if (path = '') or not FileExists(path) then
    Exit;
  args := nil;
  SetLength(args, 1);
  args[0] := exe;
  if run <> '' then begin
    SetLength(args, Length(args) + 1);
    args[High(args)] := run;
  end;
  SetLength(args, Length(args) + 1);
  args[High(args)] := ExpandFileName(ParamStr(0));
  for i := 1 to ParamCount do begin
    SetLength(args, Length(args) + 1);
    args[High(args)] := ParamStr(i);
  end;
  SetLength(args, Length(args) + 1);
  args[High(args)] := IN_TERMINAL;
  argv := nil;
  SetLength(argv, Length(args) + 1);
  for i := 0 to High(args) do
    argv[i] := PChar(args[i]);
  argv[High(argv)] := nil;
  FpExecve(PChar(path), PPChar(@argv[0]), envp);
end;

procedure Start;
var
  i: Integer;
begin
  if (IsATTY(StdInputHandle) = 1) or (IsATTY(StdOutputHandle) = 1) then
    Exit;
  if not HasOption(IN_TERMINAL) and
     ((GetEnvironmentVariable('DISPLAY') <> '') or (GetEnvironmentVariable('WAYLAND_DISPLAY') <> '')) then begin
    if GetEnvironmentVariable('TERMINAL') <> '' then
      TryTerminal(GetEnvironmentVariable('TERMINAL'), '-e');
    for i := Low(TERMINALS) to High(TERMINALS) do
      TryTerminal(TERMINALS[i].exe, TERMINALS[i].run);
  end;
  WriteLn(StdErr, ExtractFileName(ParamStr(0)), ' needs a terminal: run it from one.');
  Halt(1);
end;
{$ELSE}
procedure Start;
begin
end;
{$ENDIF}

end.

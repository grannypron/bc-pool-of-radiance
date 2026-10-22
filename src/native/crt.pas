{ The native build's Crt: the parts of Turbo Pascal's Crt the game uses (the colour constants, ReadKey, KeyPressed,
  Delay and CheckBreak) on Host's keyboard buffer and clock. build-native.sh puts src/native on the unit path, so this
  unit, not Free Pascal's own Crt (which drives a text terminal), is the Crt every unit uses. Each call that waits or
  polls runs Host.Service, which takes the window's events in and shows the screen, as DOS's hardware did meanwhile.
  Free Pascal only. }
{$I COMPILER.INC}
unit Crt;

interface

const
  Black = 0;
  Blue = 1;
  Green = 2;
  Cyan = 3;
  Red = 4;
  Magenta = 5;
  Brown = 6;
  LightGray = 7;
  DarkGray = 8;
  LightBlue = 9;
  LightGreen = 10;
  LightCyan = 11;
  LightRed = 12;
  LightMagenta = 13;
  Yellow = 14;
  White = 15;
  Blink = 128;

var
  { Ctrl-Break's check, which the game turns off; a native program has none, so it only keeps the value }
  CheckBreak: Boolean;

{ The next key's character, waiting for one; a key with none (a function or cursor key, an Alt combination) gives #0 and
  then its scan code on the next call, as Turbo Pascal's ReadKey does. }
function ReadKey: Char;

{ True when a key is waiting. }
function KeyPressed: Boolean;

{ Wait ms milliseconds. }
procedure Delay(ms: Word);

implementation

uses SysUtils, Host;

var
  { the scan code ReadKey owes after the #0 of a key with no character; 0 for none }
  pendingScan: Byte;

function ReadKey: Char;
var
  key: Word;
begin
  if pendingScan <> 0 then begin
    ReadKey := Chr(pendingScan);
    pendingScan := 0;
    Exit;
  end;
  Host.Service;
  while not Host.KeyWaiting do begin
    Sleep(1);
    Host.Service;
  end;
  key := Host.PopKey;
  if Lo(key) = 0 then
    pendingScan := Hi(key);
  ReadKey := Chr(Lo(key));
end;

function KeyPressed: Boolean;
begin
  Host.Service;
  if (pendingScan = 0) and not Host.KeyWaiting then begin
    { the game polls in a loop: give the processor back while nothing is waiting }
    Sleep(1);
    KeyPressed := False;
  end else
    KeyPressed := True;
end;

procedure Delay(ms: Word);
var
  until_: QWord;
begin
  until_ := GetTickCount64 + ms;
  Host.Service;
  while GetTickCount64 < until_ do begin
    Sleep(1);
    Host.Service;
  end;
end;

begin
  CheckBreak := True;
end.

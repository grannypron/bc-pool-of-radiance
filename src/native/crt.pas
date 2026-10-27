{ Native replacement for the subset of Turbo Pascal's Crt used by the game.
  It provides the color constants and implements keyboard and timing routines
  on top of Host. Calls that wait or poll also run Host.Service so window events
  and screen updates continue while the game is idle. Free Pascal only. }
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
  { Retained for compatibility; native builds do not handle Ctrl-Break. }
  CheckBreak: Boolean;

{ Waits for and returns the next key. Extended keys return #0 first and their
  scan code on the next call, matching Turbo Pascal's ReadKey. }
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

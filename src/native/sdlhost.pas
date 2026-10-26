{ The native build's window: shows Host's screen through its DAC and turns the window's key presses into the BIOS's scan
  codes and characters in Host's keyboard buffer, as a PC's keyboard and BIOS did (a US layout, as the BIOS's). It hooks
  Host.Service, which Crt's ReadKey, KeyPressed and Delay run, so the screen is shown and keys arrive while the game
  waits; the screen is shown at most once every 15 ms. Closing the window, or the system's Quit, asks before ending the
  program (ConfirmQuit, #1073). For testing, POOLRAD_SHOT
  names a file the screen is written to (a PPM image) twice a second, and POOLRAD_KEYS gives keys to press, as if typed:
  words separated by spaces, each a wait in milliseconds (a number of two digits or more), a character (a, A, 1, ?) or a
  key's name (enter, esc, space, tab, bs, up, down, left, right, home, end, pgup, pgdn, ins, del, f1..f12), the names
  optionally after shift-, ctrl- or alt-. Each key is followed by KEY_GAP_MS: the game drops keys typed ahead of the one
  it reads (GameIo.ReadGameKey), as a player's are not. The program uses this unit (the unit tests do not, so they need
  no SDL). Objfpc mode, for its initialization and finalization. Free Pascal only. }
{$MODE OBJFPC}
{$H-}
unit SdlHost;

interface

uses Sdl3Min;

{ The game's window, for a dialog to belong to (DataPick's folder picker, #1064). }
function GameWindow: PSDL_Window;

var
  { False while there is nothing to lose (DataPick, before the game starts): a quit then ends the program without
    asking. On a Mac the question could not be asked there anyway while the folder picker is open: both are sheets on
    the game's window, and the question would wait for the picker to close (#1073). }
  askBeforeQuit: Boolean = True;

implementation

uses SysUtils, Math, Host;

const
  { the screen is 320x200 shown at 4:3, as on a PC's monitor: each pixel 1.2 times as tall as wide }
  SHOWN_HEIGHT = 240;
  WINDOW_SCALE = 3;
  PRESENT_MS = 15;
  KEY_GAP_MS = 200;
  SHOT_MS = 500;

  { SDL_Scancode (USB HID usage) values the table starts and ends at }
  FIRST_SCANCODE = 4;
  LAST_SCANCODE = 99;

type
  { a key as the BIOS gives it: its scan code, and its character unshifted and with Shift (#0 for none) }
  TBiosKey = record
    scan: Byte;
    normal: Char;
    shifted: Char;
  end;

const
  { SDL_Scancode 4..99 to the BIOS's keys; a scan of 0 is a key the BIOS has no code for }
  BIOS_KEYS: array[FIRST_SCANCODE..LAST_SCANCODE] of TBiosKey = (
    (scan: $1E; normal: 'a'; shifted: 'A'), (scan: $30; normal: 'b'; shifted: 'B'),
    (scan: $2E; normal: 'c'; shifted: 'C'), (scan: $20; normal: 'd'; shifted: 'D'),
    (scan: $12; normal: 'e'; shifted: 'E'), (scan: $21; normal: 'f'; shifted: 'F'),
    (scan: $22; normal: 'g'; shifted: 'G'), (scan: $23; normal: 'h'; shifted: 'H'),
    (scan: $17; normal: 'i'; shifted: 'I'), (scan: $24; normal: 'j'; shifted: 'J'),
    (scan: $25; normal: 'k'; shifted: 'K'), (scan: $26; normal: 'l'; shifted: 'L'),
    (scan: $32; normal: 'm'; shifted: 'M'), (scan: $31; normal: 'n'; shifted: 'N'),
    (scan: $18; normal: 'o'; shifted: 'O'), (scan: $19; normal: 'p'; shifted: 'P'),
    (scan: $10; normal: 'q'; shifted: 'Q'), (scan: $13; normal: 'r'; shifted: 'R'),
    (scan: $1F; normal: 's'; shifted: 'S'), (scan: $14; normal: 't'; shifted: 'T'),
    (scan: $16; normal: 'u'; shifted: 'U'), (scan: $2F; normal: 'v'; shifted: 'V'),
    (scan: $11; normal: 'w'; shifted: 'W'), (scan: $2D; normal: 'x'; shifted: 'X'),
    (scan: $15; normal: 'y'; shifted: 'Y'), (scan: $2C; normal: 'z'; shifted: 'Z'),
    { 30..39: 1..9, 0 }
    (scan: $02; normal: '1'; shifted: '!'), (scan: $03; normal: '2'; shifted: '@'),
    (scan: $04; normal: '3'; shifted: '#'), (scan: $05; normal: '4'; shifted: '$'),
    (scan: $06; normal: '5'; shifted: '%'), (scan: $07; normal: '6'; shifted: '^'),
    (scan: $08; normal: '7'; shifted: '&'), (scan: $09; normal: '8'; shifted: '*'),
    (scan: $0A; normal: '9'; shifted: '('), (scan: $0B; normal: '0'; shifted: ')'),
    { 40..44: Enter, Esc, Backspace, Tab, Space }
    (scan: $1C; normal: #13; shifted: #13), (scan: $01; normal: #27; shifted: #27),
    (scan: $0E; normal: #8; shifted: #8), (scan: $0F; normal: #9; shifted: #0),
    (scan: $39; normal: ' '; shifted: ' '),
    { 45..56: - = [ ] \ (non-US #) ; ' ` , . / }
    (scan: $0C; normal: '-'; shifted: '_'), (scan: $0D; normal: '='; shifted: '+'),
    (scan: $1A; normal: '['; shifted: '{'), (scan: $1B; normal: ']'; shifted: '}'),
    (scan: $2B; normal: '\'; shifted: '|'), (scan: $2B; normal: '\'; shifted: '|'),
    (scan: $27; normal: ';'; shifted: ':'), (scan: $28; normal: ''''; shifted: '"'),
    (scan: $29; normal: '`'; shifted: '~'), (scan: $33; normal: ','; shifted: '<'),
    (scan: $34; normal: '.'; shifted: '>'), (scan: $35; normal: '/'; shifted: '?'),
    { 57: Caps Lock }
    (scan: 0; normal: #0; shifted: #0),
    { 58..69: F1..F12 }
    (scan: $3B; normal: #0; shifted: #0), (scan: $3C; normal: #0; shifted: #0),
    (scan: $3D; normal: #0; shifted: #0), (scan: $3E; normal: #0; shifted: #0),
    (scan: $3F; normal: #0; shifted: #0), (scan: $40; normal: #0; shifted: #0),
    (scan: $41; normal: #0; shifted: #0), (scan: $42; normal: #0; shifted: #0),
    (scan: $43; normal: #0; shifted: #0), (scan: $44; normal: #0; shifted: #0),
    (scan: $85; normal: #0; shifted: #0), (scan: $86; normal: #0; shifted: #0),
    { 70..72: Print Screen, Scroll Lock, Pause }
    (scan: 0; normal: #0; shifted: #0), (scan: 0; normal: #0; shifted: #0), (scan: 0; normal: #0; shifted: #0),
    { 73..82: Insert, Home, Page Up, Delete, End, Page Down, Right, Left, Down, Up }
    (scan: $52; normal: #0; shifted: #0), (scan: $47; normal: #0; shifted: #0),
    (scan: $49; normal: #0; shifted: #0), (scan: $53; normal: #0; shifted: #0),
    (scan: $4F; normal: #0; shifted: #0), (scan: $51; normal: #0; shifted: #0),
    (scan: $4D; normal: #0; shifted: #0), (scan: $4B; normal: #0; shifted: #0),
    (scan: $50; normal: #0; shifted: #0), (scan: $48; normal: #0; shifted: #0),
    { 83: Num Lock }
    (scan: 0; normal: #0; shifted: #0),
    { 84..88: keypad / * - + Enter }
    (scan: $35; normal: '/'; shifted: '/'), (scan: $37; normal: '*'; shifted: '*'),
    (scan: $4A; normal: '-'; shifted: '-'), (scan: $4E; normal: '+'; shifted: '+'),
    (scan: $1C; normal: #13; shifted: #13),
    { 89..99: keypad 1..9, 0, . (their characters with Num Lock on; without, cursor keys) }
    (scan: $4F; normal: '1'; shifted: '1'), (scan: $50; normal: '2'; shifted: '2'),
    (scan: $51; normal: '3'; shifted: '3'), (scan: $4B; normal: '4'; shifted: '4'),
    (scan: $4C; normal: '5'; shifted: '5'), (scan: $4D; normal: '6'; shifted: '6'),
    (scan: $47; normal: '7'; shifted: '7'), (scan: $48; normal: '8'; shifted: '8'),
    (scan: $49; normal: '9'; shifted: '9'), (scan: $52; normal: '0'; shifted: '0'),
    (scan: $53; normal: '.'; shifted: '.'));

  SC_A = 4;
  SC_Z = 29;
  SC_1 = 30;
  SC_0 = 39;
  SC_ENTER = 40;
  SC_BACKSPACE = 42;
  SC_F1 = 58;
  SC_F10 = 67;
  SC_F11 = 68;
  SC_F12 = 69;
  SC_INSERT = 73;
  SC_UP = 82;
  SC_KP_1 = 89;
  SC_KP_PERIOD = 99;

var
  window: PSDL_Window;
  renderer: PSDL_Renderer;
  texture: PSDL_Texture;
  pixels: array[0..SCREEN_WIDTH * SCREEN_HEIGHT - 1] of LongWord;
  lastPresent: QWord;
  shotPath: String;
  lastShot: QWord;
  { POOLRAD_KEYS: the words not yet pressed, and when the next may be }
  keyScript: AnsiString;
  keyDue: QWord;
  { POOLRAD_KEYS or POOLRAD_SHOT was given: a scripted run, which no one is there to answer a dialog for }
  scripted: Boolean;

procedure Fail(what: String);
begin
  WriteLn(StdErr, 'Pool of Radiance: ', what, ': ', SDL_GetError);
  Halt(1);
end;

{ the screen as a PPM image (binary, 8 bits a component) at shotPath }
procedure WriteShot(var rgb: array of LongWord);
var
  f: File;
  header: String;
  row: array[0..SCREEN_WIDTH * 3 - 1] of Byte;
  x, y: LongInt;
  c: LongWord;
begin
  header := 'P6' + #10 + IntToStr(SCREEN_WIDTH) + ' ' + IntToStr(SCREEN_HEIGHT) + #10 + '255' + #10;
  System.Assign(f, shotPath);
  {$I-}
  Rewrite(f, 1);
  {$I+}
  if IOResult <> 0 then
    Exit;
  BlockWrite(f, header[1], Length(header));
  for y := 0 to SCREEN_HEIGHT - 1 do begin
    for x := 0 to SCREEN_WIDTH - 1 do begin
      c := rgb[Host.screen[y * SCREEN_WIDTH + x]];
      row[x * 3] := (c shr 16) and $FF;
      row[x * 3 + 1] := (c shr 8) and $FF;
      row[x * 3 + 2] := c and $FF;
    end;
    BlockWrite(f, row, SizeOf(row));
  end;
  Close(f);
end;

{ Host's screen through its DAC into the texture, and the texture to the window }
procedure Present;
var
  rgb: array[0..255] of LongWord;
  i: LongInt;
  r, g, b: Byte;
begin
  for i := 0 to 255 do begin
    { 6-bit DAC components to 8 bits: 63 is 255 }
    r := (Host.dac[i, 0] shl 2) or (Host.dac[i, 0] shr 4);
    g := (Host.dac[i, 1] shl 2) or (Host.dac[i, 1] shr 4);
    b := (Host.dac[i, 2] shl 2) or (Host.dac[i, 2] shr 4);
    rgb[i] := (LongWord(r) shl 16) or (LongWord(g) shl 8) or b;
  end;
  for i := 0 to SCREEN_WIDTH * SCREEN_HEIGHT - 1 do
    pixels[i] := rgb[Host.screen[i]];
  SDL_UpdateTexture(texture, nil, @pixels, SCREEN_WIDTH * 4);
  SDL_RenderClear(renderer);
  SDL_RenderTexture(renderer, texture, nil, nil);
  SDL_RenderPresent(renderer);
  lastPresent := SDL_GetTicks;
  if (shotPath <> '') and (lastPresent - lastShot >= SHOT_MS) then begin
    WriteShot(rgb);
    lastShot := lastPresent;
  end;
end;

{ A key press to the BIOS's scan code and character, into Host's buffer. }
procedure KeyDown(var key: TSDL_KeyboardEvent);
var
  sc: LongInt;
  k: TBiosKey;
  shift, ctrl, alt, caps, num: Boolean;
  scan: Byte;
  ch: Char;
begin
  sc := key.scancode;
  if (sc < FIRST_SCANCODE) or (sc > LAST_SCANCODE) then
    Exit;
  { Command (a Mac's) or the Windows key: the system's shortcuts (Command-Q), not the game's; nor is it Alt (#1073) }
  if (key.keyMod and SDL_KMOD_GUI) <> 0 then
    Exit;
  k := BIOS_KEYS[sc];
  if k.scan = 0 then
    Exit;
  shift := (key.keyMod and SDL_KMOD_SHIFT) <> 0;
  ctrl := (key.keyMod and SDL_KMOD_CTRL) <> 0;
  alt := (key.keyMod and SDL_KMOD_ALT) <> 0;
  caps := (key.keyMod and SDL_KMOD_CAPS) <> 0;
  num := (key.keyMod and SDL_KMOD_NUM) <> 0;
  scan := k.scan;
  if shift then
    ch := k.shifted
  else
    ch := k.normal;

  if (sc >= SC_A) and (sc <= SC_Z) then begin
    if alt then
      ch := #0
    else if ctrl then
      ch := Chr(Ord(k.shifted) - 64)
    else if caps then begin
      if shift then
        ch := k.normal
      else
        ch := k.shifted;
    end;
  end else if (sc >= SC_1) and (sc <= SC_0) then begin
    if alt then begin
      { Alt-1..Alt-9, Alt-0: scan codes 78h..81h }
      scan := $78 + (sc - SC_1);
      ch := #0;
    end else if ctrl then
      Exit;
  end else if (sc >= SC_F1) and (sc <= SC_F12) then begin
    { F1..F10 from 3Bh, Shift 54h, Ctrl 5Eh, Alt 68h; F11 and F12 85h, 87h, 89h, 8Bh }
    if sc <= SC_F10 then begin
      if alt then scan := $68 + (sc - SC_F1)
      else if ctrl then scan := $5E + (sc - SC_F1)
      else if shift then scan := $54 + (sc - SC_F1);
    end else begin
      if alt then scan := $8B + (sc - SC_F11)
      else if ctrl then scan := $89 + (sc - SC_F11)
      else if shift then scan := $87 + (sc - SC_F11);
    end;
    ch := #0;
  end else if ((sc >= SC_INSERT) and (sc <= SC_UP)) or
              ((sc >= SC_KP_1) and (sc <= SC_KP_PERIOD) and not (num xor shift)) then begin
    { a cursor key: with Ctrl, Home 77h, End 75h, Page Up 84h, Page Down 76h, Left 73h, Right 74h, Up 8Dh, Down 91h,
      Insert 92h, Delete 93h; keypad 5 and Alt give nothing }
    ch := #0;
    if ctrl then
      case scan of
        $47: scan := $77;
        $4F: scan := $75;
        $49: scan := $84;
        $51: scan := $76;
        $4B: scan := $73;
        $4D: scan := $74;
        $48: scan := $8D;
        $50: scan := $91;
        $52: scan := $92;
        $53: scan := $93;
      else
        Exit;
      end
    else if alt or (scan = $4C) then
      Exit;
  end else if alt then
    { Alt with anything else gives nothing the game reads }
    Exit
  else if ctrl then
    case sc of
      SC_ENTER: ch := #10;
      SC_BACKSPACE: ch := #127;
    else
      case k.normal of
        '[': ch := #27;
        '\': ch := #28;
        ']': ch := #29;
        '-': ch := #31;
      else
        Exit;
      end;
    end;
  Host.PushKey(scan, Ord(ch));
end;

{ The SDL_Scancode for a key's name or character in POOLRAD_KEYS, with the modifiers it needs; -1 for none. }
function ScriptKey(word: String; var keyMod: Word): LongInt;
const
  NAMES: array[0..14] of String[5] = ('enter', 'esc', 'bs', 'tab', 'space', 'ins', 'home', 'pgup', 'del', 'end',
                                      'pgdn', 'right', 'left', 'down', 'up');
  CODES: array[0..14] of Byte = (40, 41, 42, 43, 44, 73, 74, 75, 76, 77, 78, 79, 80, 81, 82);
var
  i: LongInt;
  sc: LongInt;
begin
  keyMod := 0;
  repeat
    i := Length(word);
    if Copy(word, 1, 6) = 'shift-' then begin keyMod := keyMod or SDL_KMOD_SHIFT; Delete(word, 1, 6); end;
    if Copy(word, 1, 5) = 'ctrl-' then begin keyMod := keyMod or SDL_KMOD_CTRL; Delete(word, 1, 5); end;
    if Copy(word, 1, 4) = 'alt-' then begin keyMod := keyMod or SDL_KMOD_ALT; Delete(word, 1, 4); end;
  until Length(word) = i;
  ScriptKey := -1;
  if Length(word) = 1 then begin
    for sc := FIRST_SCANCODE to SC_KP_1 - 1 do
      if BIOS_KEYS[sc].normal = word[1] then
        Exit(sc)
      else if (BIOS_KEYS[sc].shifted = word[1]) and (BIOS_KEYS[sc].scan <> 0) then begin
        keyMod := keyMod or SDL_KMOD_SHIFT;
        Exit(sc);
      end;
    Exit;
  end;
  for i := 0 to 14 do
    if word = NAMES[i] then
      Exit(CODES[i]);
  if (Length(word) >= 2) and (word[1] = 'f') then begin
    i := StrToIntDef(Copy(word, 2, 2), 0);
    if (i >= 1) and (i <= 12) then
      Exit(SC_F1 + i - 1);
  end;
end;

{ Press POOLRAD_KEYS' next key, or start its next wait, when it is due. }
procedure RunKeyScript;
var
  word: String;
  i: LongInt;
  ms: LongInt;
  key: TSDL_KeyboardEvent;
begin
  while (keyScript <> '') and (SDL_GetTicks >= keyDue) do begin
    keyScript := TrimLeft(keyScript);
    i := Pos(' ', keyScript);
    if i = 0 then
      i := Length(keyScript) + 1;
    word := Copy(keyScript, 1, i - 1);
    Delete(keyScript, 1, i);
    if word = '' then
      Continue;
    if (Length(word) > 1) and TryStrToInt(word, ms) then
      keyDue := SDL_GetTicks + ms
    else begin
      FillChar(key, SizeOf(key), 0);
      key.scancode := ScriptKey(word, key.keyMod);
      if key.scancode < 0 then
        WriteLn(StdErr, 'POOLRAD_KEYS: no key ', word)
      else begin
        KeyDown(key);
        keyDue := SDL_GetTicks + KEY_GAP_MS;
      end;
    end;
  end;
end;

{ A quit asked for by the system (Command-Q, the app menu's Quit, the window's close button, Alt-F4): ask the player in
  the system's own message box, Cancel the default for Return and Escape, and end the program on Quit (#1073). A
  box that cannot be shown ends it, as before there was one, and so does a quit while askBeforeQuit is off (DataPick:
  nothing to lose yet). A scripted run (POOLRAD_KEYS, POOLRAD_SHOT) ends without
  asking: nothing would answer, and the run would wait for ever. On Cancel the quit leaves nothing behind: SDL has not
  closed the window, and the quit events still queued are dropped, as closing the last window sends both
  SDL_EVENT_WINDOW_CLOSE_REQUESTED and SDL_EVENT_QUIT, which would otherwise ask twice. }
procedure ConfirmQuit;
const
  BUTTON_QUIT = 1;
  BUTTON_CANCEL = 0;
var
  buttons: array[0..1] of TSDL_MessageBoxButtonData;
  box: TSDL_MessageBoxData;
  chosen: LongInt;
begin
  if scripted or not askBeforeQuit then
    Halt(0);
  buttons[0].flags := 0;
  buttons[0].buttonID := BUTTON_QUIT;
  buttons[0].text := 'Quit';
  buttons[1].flags := SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT or SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT;
  buttons[1].buttonID := BUTTON_CANCEL;
  buttons[1].text := 'Cancel';
  FillChar(box, SizeOf(box), 0);
  box.flags := SDL_MESSAGEBOX_WARNING;
  box.window := window;
  box.title := 'Pool of Radiance';
  box.message := 'Quit Pool of Radiance? Progress since your last save will be lost.';
  box.numbuttons := 2;
  box.buttons := @buttons[0];
  chosen := BUTTON_CANCEL;
  if not SDL_ShowMessageBox(box, chosen) or (chosen = BUTTON_QUIT) then
    Halt(0);
  SDL_FlushEvent(SDL_EVENT_QUIT);
  SDL_FlushEvent(SDL_EVENT_WINDOW_CLOSE_REQUESTED);
end;

procedure Service;
var
  event: TSDL_Event;
begin
  if keyScript <> '' then
    RunKeyScript;
  while SDL_PollEvent(event) do
    case event.eventType of
      SDL_EVENT_QUIT, SDL_EVENT_WINDOW_CLOSE_REQUESTED:
        ConfirmQuit;
      SDL_EVENT_KEY_DOWN:
        KeyDown(event.key);
    end;
  if SDL_GetTicks - lastPresent >= PRESENT_MS then
    Present;
end;

function GameWindow: PSDL_Window;
begin
  GameWindow := window;
end;

procedure Open;
begin
  { Free Pascal traps floating-point errors (an invalid operation, a division by zero); C code never expects that, and
    the system's own libraries make NaNs and infinities freely: macOS's Core Animation stopped the program as SDL made
    the window (CFNumberCreate, from CALayer). Masked, as a C program has them, before SDL runs any. }
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide, exOverflow, exUnderflow, exPrecision]);
  if not SDL_Init(SDL_INIT_VIDEO) then
    Fail('cannot start SDL');
  window := SDL_CreateWindow('Pool of Radiance', SCREEN_WIDTH * WINDOW_SCALE, SHOWN_HEIGHT * WINDOW_SCALE,
                             SDL_WINDOW_RESIZABLE or SDL_WINDOW_HIGH_PIXEL_DENSITY);
  if window = nil then
    Fail('cannot open a window');
  renderer := SDL_CreateRenderer(window, nil);
  if renderer = nil then
    Fail('cannot draw in the window');
  SDL_SetRenderVSync(renderer, 1);
  SDL_SetRenderLogicalPresentation(renderer, SCREEN_WIDTH, SHOWN_HEIGHT, SDL_LOGICAL_PRESENTATION_LETTERBOX);
  texture := SDL_CreateTexture(renderer, SDL_PIXELFORMAT_XRGB8888, SDL_TEXTUREACCESS_STREAMING, SCREEN_WIDTH,
                               SCREEN_HEIGHT);
  if texture = nil then
    Fail('cannot make the screen''s texture');
  SDL_SetTextureScaleMode(texture, SDL_SCALEMODE_PIXELART);
  Host.serviceHook := @Service;
  shotPath := GetEnvironmentVariable('POOLRAD_SHOT');
  keyScript := GetEnvironmentVariable('POOLRAD_KEYS');
  scripted := (shotPath <> '') or (keyScript <> '');
  keyDue := 0;
  Present;
end;

procedure Close;
begin
  Host.serviceHook := nil;
  SDL_DestroyTexture(texture);
  SDL_DestroyRenderer(renderer);
  SDL_DestroyWindow(window);
  SDL_Quit;
end;

initialization
  Open;
finalization
  Close;
end.

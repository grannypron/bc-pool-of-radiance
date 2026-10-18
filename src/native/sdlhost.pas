{ The native build's window: shows Host's screen through its DAC and turns the window's key presses into the BIOS's
  scan codes and characters in Host's keyboard buffer, as a PC's keyboard and BIOS did (a US layout, as the BIOS's).
  It hooks Host.Service, which Crt's ReadKey, KeyPressed and Delay run, so the screen is shown and keys arrive while
  the game waits; the screen is shown at most 60 times a second. Closing the window ends the program. For testing,
  POOLRAD_SHOT names a file the screen is written to (a PPM image) twice a second. The program
  uses this unit (the unit tests do not, so they need no SDL). Objfpc mode, for its initialization and finalization.
  Free Pascal only. }
{$MODE OBJFPC}
{$H-}
unit SdlHost;

interface

implementation

uses SysUtils, Sdl3Min, Host;

const
  { the screen is 320x200 shown at 4:3, as on a PC's monitor: each pixel 1.2 times as tall as wide }
  SHOWN_HEIGHT = 240;
  WINDOW_SCALE = 3;
  PRESENT_MS = 15;
  SHOT_MS = 500;
  { SDL_ScaleMode: nearest, smoothed where a pixel straddles two (SDL 3.4) }
  SDL_SCALEMODE_PIXELART = 2;

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
    { a cursor key: with Ctrl, Home 77h, End 75h, Page Up 84h, Page Down 76h, Left 73h, Right 74h }
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

procedure Service;
var
  event: TSDL_Event;
begin
  while SDL_PollEvent(event) do
    case event.eventType of
      SDL_EVENT_QUIT, SDL_EVENT_WINDOW_CLOSE_REQUESTED:
        Halt(0);
      SDL_EVENT_KEY_DOWN:
        KeyDown(event.key);
    end;
  if SDL_GetTicks - lastPresent >= PRESENT_MS then
    Present;
end;

procedure Open;
begin
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

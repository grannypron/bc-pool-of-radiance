{$I COMPILER.INC}
{ The few SDL3 calls the native build makes (a window, a texture the screen is copied to, events, the clock, an
  audio stream, the folder picker and a message box), declared from SDL 3.4's headers (SDL_init.h, SDL_video.h,
  SDL_render.h, SDL_events.h, SDL_audio.h, SDL_dialog.h, SDL_messagebox.h).
  Only these: a full binding is not needed, and these are all that must be kept right.

  On Linux and macOS SDL is linked into the program: build-native.sh copies SDL's static libSDL3.a as libSDL3static.a
  into a folder it gives the linker, and that name is linked here, so a shared libSDL3 in a system folder (which the
  linker searches first) is never taken instead. What the static library needs besides is named here too: the maths
  library, and on macOS the system frameworks SDL's sdl3.pc lists. Free Pascal only. }
unit Sdl3Min;

interface

{$IFDEF DARWIN}
{ on macOS Free Pascal passes no library to the linker for a routine's external name: named here }
{$LINKLIB SDL3static}
{ clang's runtime, which a C compiler's link adds by itself: SDL's @available checks call into it }
{$LINKLIB clang_rt.osx}
{$LINKFRAMEWORK CoreMedia}
{$LINKFRAMEWORK CoreVideo}
{$LINKFRAMEWORK Cocoa}
{$LINKFRAMEWORK UniformTypeIdentifiers}
{$LINKFRAMEWORK IOKit}
{$LINKFRAMEWORK ForceFeedback}
{$LINKFRAMEWORK Carbon}
{$LINKFRAMEWORK CoreAudio}
{$LINKFRAMEWORK AudioToolbox}
{$LINKFRAMEWORK AVFoundation}
{$LINKFRAMEWORK Foundation}
{$LINKFRAMEWORK GameController}
{$LINKFRAMEWORK Metal}
{$LINKFRAMEWORK QuartzCore}
{$LINKFRAMEWORK CoreHaptics}
{$ELSE}
{$IFDEF UNIX}
{$LINKLIB m}
{$ENDIF}
{$ENDIF}

const
{$IFDEF WINDOWS}
  SDL_LIB = 'SDL3.dll';
{$ELSE}
  SDL_LIB = 'SDL3static';
{$ENDIF}

  SDL_INIT_AUDIO = $00000010;
  SDL_INIT_VIDEO = $00000020;

  SDL_WINDOW_RESIZABLE = $0000000000000020;
  SDL_WINDOW_HIGH_PIXEL_DENSITY = $0000000000002000;

  SDL_PIXELFORMAT_XRGB8888 = $16161804;
  { SDL_TextureAccess }
  SDL_TEXTUREACCESS_STREAMING = 1;
  { SDL_ScaleMode: nearest, smoothed where a pixel straddles two (SDL 3.4) }
  SDL_SCALEMODE_PIXELART = 2;
  { SDL_RendererLogicalPresentation }
  SDL_LOGICAL_PRESENTATION_LETTERBOX = 2;

  { SDL_EventType }
  SDL_EVENT_QUIT = $100;
  SDL_EVENT_WINDOW_CLOSE_REQUESTED = $210;
  SDL_EVENT_KEY_DOWN = $300;

  { SDL_Keymod }
  SDL_KMOD_SHIFT = $0003;
  SDL_KMOD_CTRL = $00C0;
  SDL_KMOD_ALT = $0300;
  { Command on a Mac, the Windows key elsewhere }
  SDL_KMOD_GUI = $0C00;
  SDL_KMOD_NUM = $1000;
  SDL_KMOD_CAPS = $2000;

  { SDL_AudioFormat: signed 16-bit little-endian samples (the machine's byte order on every target here) }
  SDL_AUDIO_S16LE = $8010;
  SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK = $FFFFFFFF;

  { SDL_MessageBoxFlags }
  SDL_MESSAGEBOX_WARNING = $00000020;
  { SDL_MessageBoxButtonFlags: the button Return, and the one Escape, chooses }
  SDL_MESSAGEBOX_BUTTON_RETURNKEY_DEFAULT = $00000001;
  SDL_MESSAGEBOX_BUTTON_ESCAPEKEY_DEFAULT = $00000002;

type
  PSDL_Window = Pointer;
  PSDL_Renderer = Pointer;
  PSDL_Texture = Pointer;
  PSDL_AudioStream = Pointer;

  { SDL_KeyboardEvent }
  TSDL_KeyboardEvent = record
    eventType: LongWord;
    reserved: LongWord;
    timestamp: QWord;
    windowID: LongWord;
    which: LongWord;
    scancode: LongInt;
    key: LongWord;
    keyMod: Word;
    raw: Word;
    down: Boolean;
    isRepeat: Boolean;
  end;

  { SDL_Event: a 128-byte union; the type comes first in every member }
  TSDL_Event = record
    case Integer of
      0: (eventType: LongWord);
      1: (key: TSDL_KeyboardEvent);
      2: (padding: array[0..127] of Byte);
  end;

  { SDL_DialogFileCallback: filelist is nil after an error, points to nil when nothing was chosen, else to the chosen
    paths (UTF-8), ending in nil; it may be called on another thread }
  TSDL_DialogFileCallback = procedure(userdata: Pointer; filelist: PPChar; filter: LongInt); cdecl;

{ C's alignment for these, not COMPILER.INC's PACKRECORDS 1: their pointers follow 4-byte fields }
{$PUSH}
{$PACKRECORDS C}
  { SDL_MessageBoxButtonData: 16 bytes on 64-bit, 12 on 32-bit }
  TSDL_MessageBoxButtonData = record
    flags: LongWord;
    buttonID: LongInt;
    text: PChar;
  end;
  PSDL_MessageBoxButtonData = ^TSDL_MessageBoxButtonData;

  { SDL_MessageBoxData: 56 bytes on 64-bit (padding after flags and numbuttons), 28 on 32-bit; colorScheme nil is
    the system's colours }
  TSDL_MessageBoxData = record
    flags: LongWord;
    window: PSDL_Window;
    title: PChar;
    message: PChar;
    numbuttons: LongInt;
    buttons: PSDL_MessageBoxButtonData;
    colorScheme: Pointer;
  end;
{$POP}

  { SDL_AudioSpec }
  TSDL_AudioSpec = record
    format: LongInt;
    channels: LongInt;
    freq: LongInt;
  end;

function SDL_Init(flags: LongWord): Boolean; cdecl; external SDL_LIB;
procedure SDL_Quit; cdecl; external SDL_LIB;
function SDL_GetError: PChar; cdecl; external SDL_LIB;

function SDL_CreateWindow(title: PChar; w, h: LongInt; flags: QWord): PSDL_Window; cdecl; external SDL_LIB;
procedure SDL_DestroyWindow(window: PSDL_Window); cdecl; external SDL_LIB;
function SDL_CreateRenderer(window: PSDL_Window; name: PChar): PSDL_Renderer; cdecl; external SDL_LIB;
procedure SDL_DestroyRenderer(renderer: PSDL_Renderer); cdecl; external SDL_LIB;
function SDL_SetRenderVSync(renderer: PSDL_Renderer; vsync: LongInt): Boolean; cdecl; external SDL_LIB;
function SDL_SetRenderLogicalPresentation(renderer: PSDL_Renderer; w, h: LongInt; mode: LongInt): Boolean; cdecl;
  external SDL_LIB;
function SDL_CreateTexture(renderer: PSDL_Renderer; format: LongWord; access: LongInt; w, h: LongInt): PSDL_Texture;
  cdecl; external SDL_LIB;
procedure SDL_DestroyTexture(texture: PSDL_Texture); cdecl; external SDL_LIB;
function SDL_SetTextureScaleMode(texture: PSDL_Texture; scaleMode: LongInt): Boolean; cdecl; external SDL_LIB;
function SDL_UpdateTexture(texture: PSDL_Texture; rect: Pointer; pixels: Pointer; pitch: LongInt): Boolean; cdecl;
  external SDL_LIB;
function SDL_RenderClear(renderer: PSDL_Renderer): Boolean; cdecl; external SDL_LIB;
function SDL_RenderTexture(renderer: PSDL_Renderer; texture: PSDL_Texture; srcrect, dstrect: Pointer): Boolean; cdecl;
  external SDL_LIB;
function SDL_RenderPresent(renderer: PSDL_Renderer): Boolean; cdecl; external SDL_LIB;

function SDL_PollEvent(var event: TSDL_Event): Boolean; cdecl; external SDL_LIB;
procedure SDL_FlushEvent(eventType: LongWord); cdecl; external SDL_LIB;

function SDL_GetTicks: QWord; cdecl; external SDL_LIB;

function SDL_OpenAudioDeviceStream(devid: LongWord; var spec: TSDL_AudioSpec; callback: Pointer;
  userdata: Pointer): PSDL_AudioStream; cdecl; external SDL_LIB;
function SDL_ResumeAudioStreamDevice(stream: PSDL_AudioStream): Boolean; cdecl; external SDL_LIB;
function SDL_PutAudioStreamData(stream: PSDL_AudioStream; buf: Pointer; len: LongInt): Boolean; cdecl;
  external SDL_LIB;
procedure SDL_DestroyAudioStream(stream: PSDL_AudioStream); cdecl; external SDL_LIB;
function SDL_LockAudioStream(stream: PSDL_AudioStream): Boolean; cdecl; external SDL_LIB;
function SDL_UnlockAudioStream(stream: PSDL_AudioStream): Boolean; cdecl; external SDL_LIB;

{ Open the system's folder picker, which answers through callback when the player has chosen or cancelled (SDL 3.2) }
procedure SDL_ShowOpenFolderDialog(callback: TSDL_DialogFileCallback; userdata: Pointer; window: PSDL_Window;
  defaultLocation: PChar; allowMany: Boolean); cdecl; external SDL_LIB;

{ Show a message box and wait for a button: buttonid is the chosen button's ID, or -1 if the box was closed without
  one. False if it could not be shown. }
function SDL_ShowMessageBox(var messageboxdata: TSDL_MessageBoxData; var buttonid: LongInt): Boolean; cdecl;
  external SDL_LIB;

{ the records' layouts, as SDL_messagebox.h's }
{$IFDEF CPU64}
{$IF (SizeOf(TSDL_MessageBoxButtonData) <> 16) or (SizeOf(TSDL_MessageBoxData) <> 56)}
{$ERROR SDL_MessageBox records' layout}
{$ENDIF}
{$ELSE}
{$IF (SizeOf(TSDL_MessageBoxButtonData) <> 12) or (SizeOf(TSDL_MessageBoxData) <> 28)}
{$ERROR SDL_MessageBox records' layout}
{$ENDIF}
{$ENDIF}

implementation

end.

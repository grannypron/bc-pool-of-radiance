{ Connects the native sound emulation to an SDL audio stream. SDL's audio
  callback asks SndChip to render samples and advance the sequencer. The stream
  lock prevents game-thread sequencer calls from overlapping an audio tick.
  When no audio device is available, the game remains silent and SndSeq falls
  back to clock-driven timing. Free Pascal only. }
{$MODE OBJFPC}
{$H-}
unit SdlSound;

interface

implementation

uses Sdl3Min, SndSeq, SndChip;

const
  { samples rendered at once }
  CHUNK = 512;

var
  stream: PSDL_AudioStream;

procedure Feed(userdata: Pointer; s: PSDL_AudioStream; additional, total: LongInt); cdecl;
var
  buf: array[0..CHUNK - 1] of SmallInt;
  n: LongInt;
  k: LongInt;
begin
  n := additional div SizeOf(SmallInt);
  while n > 0 do begin
    k := n;
    if k > CHUNK then
      k := CHUNK;
    SndChip.Render(@buf[0], k);
    SDL_PutAudioStreamData(s, @buf[0], k * SizeOf(SmallInt));
    n := n - k;
  end;
end;

procedure LockStream;
begin
  SDL_LockAudioStream(stream);
end;

procedure UnlockStream;
begin
  SDL_UnlockAudioStream(stream);
end;

procedure Open;
var
  spec: TSDL_AudioSpec;
begin
  SndSeq.PortWrite := @SndChip.Write;
  if not SDL_Init(SDL_INIT_AUDIO) then
    Exit;
  spec.format := SDL_AUDIO_S16LE;
  spec.channels := 1;
  spec.freq := SndChip.RATE;
  stream := SDL_OpenAudioDeviceStream(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, spec, @Feed, nil);
  if stream = nil then
    Exit;
  SndSeq.Lock := @LockStream;
  SndSeq.Unlock := @UnlockStream;
  SndSeq.Rendered := True;
  SDL_ResumeAudioStreamDevice(stream);
end;

procedure Close;
begin
  if stream = nil then
    Exit;
  SDL_DestroyAudioStream(stream);
  stream := nil;
  SndSeq.Rendered := False;
  SndSeq.Lock := nil;
  SndSeq.Unlock := nil;
end;

initialization
  Open;
finalization
  Close;
end.

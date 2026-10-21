{ The native build's sound output: an SDL audio stream whose callback, on SDL's audio thread, fills it from SndChip
  (which runs the sequencer's ticks as it goes). It sends the sequencer's port writes to SndChip, and gives the
  sequencer the stream's lock, which SDL holds while the callback runs, so a game's call into the sequencer and a tick
  never overlap. With no audio device the game plays silent, and the sequencer keeps time on the clock instead
  (SndSeq.Rendered stays False). The program uses this unit after SdlHost. Objfpc mode, for its initialization and
  finalization. Free Pascal only. }
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

{$I COMPILER.INC}
{ Turbo Pascal System routines Free Pascal lacks. build-native.sh loads this unit into every unit after System (-Fa),
  as Turbo Pascal's System has them, so the game's units use them unchanged. Free Pascal only. }
unit TpCompat;

interface

{ The heap's free bytes and its largest free block. DOS had about 600 KB in all; a native heap grows as it needs to, so
  both report a fixed 16 MB, more than any of the game's checks (a frame, a sound, a data file's buffer) asks for. }
function MemAvail: LongInt;
function MaxAvail: LongInt;

implementation

const
  NATIVE_HEAP_BYTES = 16 * 1024 * 1024;

function MemAvail: LongInt;
begin
  MemAvail := NATIVE_HEAP_BYTES;
end;

function MaxAvail: LongInt;
begin
  MaxAvail := NATIVE_HEAP_BYTES;
end;

end.

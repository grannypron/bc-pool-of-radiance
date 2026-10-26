{$I COMPILER.INC}
{ Implements Turbo Pascal System routines that Free Pascal lacks. The native
  build loads this unit after System so existing game units need no changes. }
unit TpCompat;

interface

{ Native heaps grow on demand, so these return a fixed 16 MB—more than any
  allocation guard in the original game requires. }
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

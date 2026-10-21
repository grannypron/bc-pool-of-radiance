{ The native build's I/O ports: Port[p], as Turbo Pascal's System has it, for the sound units that look for their cards
  (SndOpl's OPL2 at 388h, SndSb's DSP and DMA). For now no card answers: every port reads FFh, as an empty ISA bus
  does, and writes go nowhere, so the game finds neither card and goes on without it. Emulated cards answer here
  when they come. Objfpc mode, for Port's default property. Free Pascal only. }
{$MODE OBJFPC}
unit PortIO;

interface

type
  TPortBus = object
    function Read(p: Word): Byte;
    procedure Write(p: Word; v: Byte);
    property Bytes[p: Word]: Byte read Read write Write; default;
  end;

var
  Port: TPortBus;

implementation

function TPortBus.Read(p: Word): Byte;
begin
  Result := $FF;
end;

procedure TPortBus.Write(p: Word; v: Byte);
begin
end;

end.

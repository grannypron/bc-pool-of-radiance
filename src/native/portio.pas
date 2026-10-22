{ The native build's I/O ports: Port[p], as Turbo Pascal's System has it, so the sound units that look for their cards
  (SndOpl's OPL2 at 388h, SndSb's DSP and DMA) compile natively. The native game uses neither (GameBoot installs SndDig
  for T, A and S), so nothing in it reads these ports today. No card answers: every port reads FFh, as an empty ISA bus
  does, and writes go nowhere. Emulated cards answer here when they come. Objfpc mode, for Port's default property. Free
  Pascal only. }
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

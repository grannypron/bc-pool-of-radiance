{ Provides Turbo Pascal's Port[p] interface to native sound units. No native
  driver currently uses these ports, so reads return FFh like an empty ISA bus
  and writes are ignored. Future device emulation can be connected here. }
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

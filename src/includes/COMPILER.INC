{ Compiler settings shared by every unit and program. Turbo Pascal gets the
  equivalent settings from TPC.CFG. Free Pascal uses PACKRECORDS 1 here to
  match Turbo Pascal's /$A- record layout and preserve on-disk formats. }
{$IFDEF FPC}
{$PACKRECORDS 1}
{$ENDIF}

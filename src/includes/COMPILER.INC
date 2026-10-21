{ Compiler settings shared by every unit and program, included before its header. Turbo Pascal reads its settings from
  TPC.CFG and skips this; Free Pascal (the native build) takes them from here, as it has no setting file per folder.
  PACKRECORDS 1 lays records out as TPC.CFG's /$A- does, so the save files' and data files' records keep their bytes. }
{$IFDEF FPC}
{$PACKRECORDS 1}
{$ENDIF}

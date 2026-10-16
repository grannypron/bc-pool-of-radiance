{ Tests for DataArc's archive names: a family's per-disk and merged names, matching a file name back to its family and
  disk in any case, and FileLength. }
program TDataArc;

uses C_Data, DataArc, StrUtil, TestKit;

var
  f: Byte;
  d: Byte;
  disk: Byte;
  name: String;
  ok: Boolean;
  lower: String;
  i: Byte;
  t: Text;

begin
  TestKit.Start('TDATAARC');
  TestKit.CheckEqualsS('MON5CHA', DataArc.SourceName(C_Data.FAMILY_MONCHA, 5), 'the monsters'' disk-5 archive');
  TestKit.CheckEqualsS('MONCHA', DataArc.MergedName(C_Data.FAMILY_MONCHA), 'the merged monster archive');
  TestKit.CheckEqualsS('', DataArc.SourceName(0, 1), 'no family 0');
  TestKit.CheckEqualsS('', DataArc.SourceName(C_Data.FAMILY_ECL, 9), 'no disk 9');
  TestKit.CheckEqualsS('', DataArc.MergedName(C_Data.FAMILIES + 1), 'no family past the last');

  { every family's per-disk names match back to that family and disk, in upper and lower case }
  ok := True;
  for f := 1 to C_Data.FAMILIES do
    for d := 1 to 8 do begin
      name := DataArc.SourceName(f, d);
      if name <> '' then begin
        disk := 0;
        if (DataArc.MatchFamily(name, disk) <> f) or (disk <> d) then
          ok := False;
        lower := name;
        for i := 1 to Length(lower) do
          if lower[i] in ['A'..'Z'] then
            lower[i] := Chr(Ord(lower[i]) + 32);
        disk := 0;
        if (DataArc.MatchFamily(lower, disk) <> f) or (disk <> d) then
          ok := False;
      end;
    end;
  TestKit.Check(ok, 'every per-disk name matches its family and disk, in any case');
  TestKit.CheckEqualsL(0, DataArc.MatchFamily('MONCHA', disk), 'a merged name is no per-disk archive');
  TestKit.CheckEqualsL(0, DataArc.MatchFamily('MON9CHA', disk), 'nor a disk past 8');

  { FileLength }
  Assign(t, 'TDATAARC.TMP');
  Rewrite(t);
  Write(t, 'twelve bytes');
  Close(t);
  TestKit.CheckEqualsL(12, DataArc.FileLength('TDATAARC.TMP'), 'FileLength of a file');
  Erase(t);
  TestKit.CheckEqualsL(-1, DataArc.FileLength('TDATAARC.TMP'), 'FileLength of no file');
  TestKit.Done;
end.

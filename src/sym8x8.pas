{ Load and draw 8x8 symbol sets. }
{$O+,F+}
{$I-}
unit Sym8x8;

interface

{ Load 8x8 graphics symbol set: picture fileID of "8X8D<disk>.DAX" -> dsSymbolSetPtrs[setID] (with a transparency mask
  for color 13, hot pink). No-op when setID is outside 0..4; on load failure prints the
  file name and fileID, waits for a key and quits to DOS }
procedure Load8x8Set(fileID, setID: Byte);

{ Put 8x8 symbol: map symbol 1..286 to its set (symSetFirst) + local index. inCombat=True composites it into the view
  buffer with Blit.BlitTileCell (other = transparency flag); otherwise copies the glyph to the current-8x8 buffer and
  draws it straight to the screen with Blit.ShowPic. Nothing is drawn if the set is not loaded, is not 8x1-cell glyphs,
  or does not hold the symbol. Symbol 0 or above 286 prints an error, waits for a key and quits to DOS. }
procedure Put8x8Sym(col, row: ShortInt; symbol: Word; inCombat, other: Boolean);

implementation


uses Crt, GDConsts, GDVars, Blit, GameIo, StrUtil;
procedure Load8x8Set(fileID, setID: Byte);
var
  s1: String[1];
begin
  if setID in [0..4] then begin
    Str(GDVars.virtualDisk, s1);
    Blit.LoadPic('8x8d' + s1, fileID, True, LightMagenta, GDVars.dsSymbolSetPtrs[setID]);
    if GDVars.dsSymbolSetPtrs[setID] = nil then begin
      GameIo.FatalError('Unable to load 8x8D' + s1 + '-' + StrUtil.NumStr(fileID));
    end;
  end;
end;

procedure Put8x8Sym(col, row: ShortInt; symbol: Word; inCombat, other: Boolean);
var
  setIdx: Byte;
begin
  case symbol of
    1..45: setIdx := 0;
    46..115: setIdx := 1;
    116..185: setIdx := 2;
    186..255: setIdx := 3;
    256..286: setIdx := 4;
    0, 287..65535: begin
      GameIo.FatalError('Bad symbol number in Put8x8Symbol.');
    end;
  end;
  if GDVars.dsSymbolSetPtrs[setIdx] <> nil then begin
    Dec(symbol, GDConsts.symSetFirst[setIdx]);
    with GDVars.dsSymbolSetPtrs[setIdx]^ do
      if (height <> 8) or (width <> 1) or (symbol >= count) then Exit;
    if inCombat then
      Blit.BlitTileCell(col, row, symbol, Ord(other), GDVars.dsSymbolSetPtrs[setIdx], GDVars.dsViewImageBufferPtr)
    else begin
      with GDVars.dsSymbolSetPtrs[setIdx]^ do
        Move(data[symbol * imgSize], GDVars.dsCurrent8x8SymbolPtr2^.data, imgSize);
      Blit.ShowPic(col, row, GDVars.dsCurrent8x8SymbolPtr2);
    end;
  end;
end;

end.

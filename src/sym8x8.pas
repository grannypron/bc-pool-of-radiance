{ Load and draw 8x8 symbol sets. }
{$O+,F+}
{$I COMPILER.INC}
unit Sym8x8;

interface

{ Loads one 8x8 symbol set and builds a transparency mask for hot pink. Ignore
  invalid destination slots. A missing required set reports the DAX record and
  exits the game. }
procedure Load8x8Set(fileID, setId: Byte);

{ Draws a global symbol ID from the loaded 8x8 sets. Combat composites it into
  the view buffer; other screens draw it directly. Missing or malformed sets
  draw nothing. An invalid symbol ID reports an error and exits. }
procedure Put8x8Sym(col, row: ShortInt; symbol: Word; inCombat, other: Boolean);

implementation

uses Crt, GameDefs, GameVars, Blit, GameIo, StrUtil;

procedure Load8x8Set(fileID, setId: Byte);
var
  s1: String[1];
begin
  if setId in [0..4] then begin
    Str(GameVars.diskIndex, s1);
    Blit.LoadPic('8x8d' + s1, fileID, True, LightMagenta, GameVars.symbolSetPtrs[setId]);
    if GameVars.symbolSetPtrs[setId] = nil then begin
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
  if GameVars.symbolSetPtrs[setIdx] <> nil then begin
    Dec(symbol, GameDefs.symSetFirst[setIdx]);
    with GameVars.symbolSetPtrs[setIdx]^ do
      if (height <> 8) or (width <> 1) or (symbol >= count) then Exit;
    if inCombat then
      Blit.BlitTileCell(col, row, symbol, Ord(other), GameVars.symbolSetPtrs[setIdx], GameVars.viewBuffer)
    else begin
      with GameVars.symbolSetPtrs[setIdx]^ do
        Move(data[symbol * imgSize], GameVars.sym8x8Buf^.data, imgSize);
      Blit.ShowPic(col, row, GameVars.sym8x8Buf);
    end;
  end;
end;

end.

{ The view buffer at another size: the wilderness's wide view (#1186) and the full-width combat view (#1211) swap
  GameVars.viewBuffer for a larger one while they are shown, so they cost their extra bytes only then. }
{$O+,F+}
{$I COMPILER.INC}
unit WideView;

interface

{ Free the view buffer and allocate it again rows scanlines by cells text cells. When the heap cannot spare that, the
  usual one (C_AREA.VIEW_ROWS by VIEW_CELLS) comes back, as its own freed block holds it, and the result is False. The
  buffer starts blank and no span is dirty; the caller draws. }
function Enter(rows, cells: Word): Boolean;

{ Free the view buffer and allocate the usual one again, blank, no span dirty. }
procedure Leave;

implementation

uses Types, C_AREA, GameVars, Blit{$IFDEF FPC}, TpCompat{$ENDIF};

function Enter(rows, cells: Word): Boolean;
var
  fits: Boolean;
begin
  Blit.FreePic(GameVars.viewBuffer);
  fits := MaxAvail >= LongInt(Blit.FrameBytes(rows, cells)) + SizeOf(Types.TImgBuf) -
                      SizeOf(GameVars.viewBuffer^.data);
  if fits then
    Blit.AllocPic(rows, cells, 1, 0, GameVars.viewBuffer)
  else
    Blit.AllocPic(C_AREA.VIEW_ROWS, C_AREA.VIEW_CELLS, 1, 0, GameVars.viewBuffer);
  { what was dirty was the freed buffer's }
  Blit.ClearSpans;
  Enter := fits;
end;

procedure Leave;
begin
  Blit.FreePic(GameVars.viewBuffer);
  Blit.AllocPic(C_AREA.VIEW_ROWS, C_AREA.VIEW_CELLS, 1, 0, GameVars.viewBuffer);
  Blit.ClearSpans;
end;

end.

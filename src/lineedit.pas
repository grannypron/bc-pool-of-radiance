{ Keyboard handling for the one-line editor (#876). TuiKit.EditLine handles
  drawing and passes each key here, which keeps the editing rules independently
  testable. }
{$I COMPILER.INC}
unit LineEdit;

interface

{ Applies one key to text. pos is the cursor position between characters, from
  0 through Length(text), and ext identifies an extended-key scan code. Cursor,
  deletion, insert, and overwrite keys are handled here without letting text
  exceed maxLen. Returns True for any editor key, even if it made no change;
  returns False when the caller should handle the key. }
function EditKey(var text: string; var pos: Byte; var insertMode: Boolean; maxLen: Byte; ch: Char;
  ext: Boolean): Boolean;

implementation

uses C_KEYS;

function EditKey(var text: string; var pos: Byte; var insertMode: Boolean; maxLen: Byte; ch: Char;
  ext: Boolean): Boolean;
begin
  EditKey := True;
  if pos > Length(text) then
    pos := Length(text);
  if ext then
    case ch of
      C_KEYS.LEFT: if pos > 0 then
                     Dec(pos);
      C_KEYS.RIGHT: if pos < Length(text) then
                      Inc(pos);
      C_KEYS.HOME: pos := 0;
      C_KEYS.END_KEY: pos := Length(text);
      C_KEYS.DEL: if pos < Length(text) then
                    Delete(text, pos + 1, 1);
      C_KEYS.INS: insertMode := not insertMode;
    else
      EditKey := False;
    end
  else if ch = C_KEYS.BACKSPACE then begin
    if pos > 0 then begin
      Delete(text, pos, 1);
      Dec(pos);
    end;
  end else if (ch >= ' ') and (ch <= '~') then begin
    if not insertMode and (pos < Length(text)) then begin
      text[pos + 1] := ch;
      Inc(pos);
    end else if Length(text) < maxLen then begin
      Insert(ch, text, pos + 1);
      Inc(pos);
    end;
  end else
    EditKey := False;
end;

end.

{ A one-line text editor's keys, with no screen in them (#876): TuiKit.EditLine draws the line and passes each key here,
  so the editing rules can be tested on their own, natively too. }
{$I COMPILER.INC}
unit LineEdit;

interface

{ Apply key ch (ext set for an extended key's scan code) to text, whose cursor sits before character pos + 1 (0 the
  start, Length(text) the end). Left, Right, Home and End move the cursor; Backspace deletes the character before it
  and Del the one under it; Ins turns insertMode over; a printable character is inserted at the cursor, or with
  insertMode clear replaces the one under it, while text stays within maxLen characters. True when the key was the
  editor's, whether or not it changed anything; False for any other key (Enter, Escape, a function key), for the
  caller. }
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

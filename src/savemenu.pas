{ The full-screen Load/Save Game menu: one entry per saved-game slot, its description, area and the time it was saved,
  and the popup that asks for a description when saving. A slot's description and area are kept in savgam<x>.inf beside
  its savgam<x>.dat. }
{$O+,F+,I-}
unit SaveMenu;

interface

uses Types;

const
  { the saved-game slots, in the order the menu lists them: A..J, then Q, the quick save (F5 and F8) }
  SLOT_LETTERS = 'ABCDEFGHIJQ';
  { the longest description and area name a slot keeps }
  DESC_LEN = 30;
  AREA_LEN = 18;

type
  TSlotDesc = string[DESC_LEN];
  TSlotArea = string[AREA_LEN];

{ Run the menu and return the slot chosen, or C_Keys.NONE for Escape. Saving lists every slot, an unused one as EMPTY;
  loading lists only the slots holding a saved game, and returns C_Keys.NONE at once when there are none. Up and Down
  (Home and End) move the selection a slot at a time, scrolling the list a slot at a time past its top or bottom,
  Page Up and Page Down a screenful; a slot's letter selects it; Enter, or the action's own key (L or S), takes it. The
  selection starts on slot start when it is listed, else on the newest saved game. The caller redraws the screen
  afterwards. }
function ChooseSlot(saving: Boolean; start: Char): Char;

{ The popup for saving into slot letter, in place of the menu's list: the slot, the area, and the description, which
  starts as desc and is edited on its line (up to DESC_LEN characters, upper case; Backspace deletes). Enter ends the
  editing and asks Okay or Exit on the bottom line. True, with desc set, for Okay; False for Exit or Escape. }
function AskDescription(letter: Char; area: TSlotArea; var desc: TSlotDesc): Boolean;

{ The description and area kept for slot letter: True when its savgam<x>.inf is a slot-info file of this format, else
  False with both empty. }
function ReadSlotInfo(letter: Char; var desc: TSlotDesc; var area: TSlotArea): Boolean;

{ Write slot letter's savgam<x>.inf. A failed write leaves a short file, which ReadSlotInfo ignores. }
procedure WriteSlotInfo(letter: Char; desc: TSlotDesc; area: TSlotArea);

{ 'Put save disk in X:', for the save directory's drive. }
function SaveDiskMsg: Types.TStr40;

{ Create the save directory (path minus the trailing backslash), and any parent directory it needs; IOResult 5 (the
  directory already exists) counts as success. Prompt for the save disk until MkDir succeeds. A drive root such as C:\
  cannot be made and is left alone. }
procedure CheckSaveDir;

implementation

uses Crt, Dos, GDVars, TextRend, Border, GameIo, DaxIo, MenuCore, AreaName, C_Keys, StrUtil, FileUtil;

const
  INFO_SIG = 'SINF';
  INFO_VERSION = 1;
  { the list's frame: the title box on row 1, the list box rows 3..22 }
  TITLE_ROW = 1;
  LIST_TOP = 3;
  LIST_BOTTOM = 22;
  { the slots shown at once: each takes two rows and a blank one, below the top "(more)" row }
  VISIBLE = 6;
  { a slot's second line: the area from AREA_COL, the time from STAMP_COL }
  AREA_COL = 4;
  STAMP_COL = 23;
  { the save popup's box, and its description line }
  POP_LEFT = 5;
  POP_RIGHT = 34;
  POP_DESC_ROW = 13;

type
  { A savgam<x>.inf file. }
  TSlotInfoFile = record
    sig: string[4];
    version: Byte;
    desc: TSlotDesc;
    area: TSlotArea;
  end;

var
  { the slots listed, by letter, with what is shown for each }
  listed: string[16];
  count: Byte;
  used: array[1..16] of Boolean;
  descs: array[1..16] of TSlotDesc;
  areas: array[1..16] of TSlotArea;
  stamps: array[1..16] of string[16];
  times: array[1..16] of LongInt;
  { the selected slot, and the first one shown, as indexes into listed }
  sel: Byte;
  top: Byte;

function SlotFile(letter: Char; ext: Types.TStr8): Types.TPathStr;
begin
  SlotFile := GDVars.dsSaveDirectory + 'savgam' + letter + ext;
end;

function ReadSlotInfo(letter: Char; var desc: TSlotDesc; var area: TSlotArea): Boolean;
var
  rec: TSlotInfoFile;
  ok: Boolean;
begin
  desc := '';
  area := '';
  ok := FileUtil.ReadRecord(SaveMenu.SlotFile(letter, '.inf'), rec, SizeOf(rec)) and (rec.sig = INFO_SIG) and
        (rec.version = INFO_VERSION) and (Length(rec.desc) <= DESC_LEN) and (Length(rec.area) <= AREA_LEN);
  if ok then begin
    desc := rec.desc;
    area := rec.area;
  end;
  ReadSlotInfo := ok;
end;

procedure WriteSlotInfo(letter: Char; desc: TSlotDesc; area: TSlotArea);
var
  rec: TSlotInfoFile;
  written: Boolean;
begin
  FillChar(rec, SizeOf(rec), 0);
  rec.sig := INFO_SIG;
  rec.version := INFO_VERSION;
  rec.desc := desc;
  rec.area := area;
  { a failed write leaves a short file, which ReadSlotInfo turns down }
  written := FileUtil.WriteRecord(SaveMenu.SlotFile(letter, '.inf'), rec, SizeOf(rec));
end;

{ Fill in listed entry i for slot letter: whether its savgam<x>.dat exists, the file's time (packed, and as
  YYYY/MM/DD hh:mm), and its description and area. A save with no slot-info file (one made before the menu kept them)
  has no description, and its area is read from the save itself: the GBVM previousScriptId and mapId in its zone 0,
  which follows the one-byte virtualDisk. }
procedure ReadSlot(i: Byte; letter: Char);
var
  f: file;
  t: LongInt;
  dt: DateTime;
  y: string[4];
  ioRes: Integer;
  script: Word;
  map: Types.TGbvmWord;
  n1: Word;
  n2: Word;
begin
  listed[i] := letter;
  used[i] := False;
  times[i] := 0;
  stamps[i] := '';
  descs[i] := '';
  areas[i] := '';
  if FileUtil.OpenReadOnly(f, SaveMenu.SlotFile(letter, '.dat')) then begin
    used[i] := True;
    GetFTime(f, t);
    if IOResult = 0 then begin
      times[i] := t;
      UnpackTime(t, dt);
      Str(dt.Year, y);
      stamps[i] := y + '/' + StrUtil.ZeroPad2(dt.Month) + '/' + StrUtil.ZeroPad2(dt.Day) + ' ' +
                   StrUtil.ZeroPad2(dt.Hour) + ':' + StrUtil.ZeroPad2(dt.Min);
    end;
    if not SaveMenu.ReadSlotInfo(letter, descs[i], areas[i]) then begin
      Seek(f, 1 + Ofs(GDVars.zone0^.previousScriptId) - Ofs(GDVars.zone0^));
      BlockRead(f, script, SizeOf(script), n1);
      Seek(f, 1 + Ofs(GDVars.zone0^.mapId) - Ofs(GDVars.zone0^));
      BlockRead(f, map, SizeOf(map), n2);
      if (IOResult = 0) and (n1 = SizeOf(script)) and (n2 = SizeOf(map)) then
        areas[i] := AreaName.AreaFor(Lo(script), map.lo)
      else
        areas[i] := 'UNKNOWN AREA';
    end;
    Close(f);
    ioRes := IOResult;
  end;
end;

{ Draw "(more)" centered on row. }
procedure DrawMore(row: Byte);
begin
  TextRend.DisplayCentered(1, 38, row, White, '(more)');
end;

{ Draw the slots from top, the selected one in white and the rest in light green, with "(more)" above when a slot is
  hidden above and below when one is hidden below. }
procedure DrawList;
var
  k: Byte;
  i: Byte;
  row: Byte;
  color: Byte;
begin
  Border.ClearBox(1, LIST_TOP, 38, LIST_BOTTOM);
  if top > 1 then
    SaveMenu.DrawMore(LIST_TOP);
  for k := 0 to VISIBLE - 1 do begin
    i := top + k;
    if i <= count then begin
      if i = sel then
        color := White
      else
        color := LightGreen;
      row := LIST_TOP + 1 + 3 * k;
      if used[i] then begin
        TextRend.DisplayString(1, row, color, listed[i] + ': ' + descs[i]);
        TextRend.DisplayString(AREA_COL, row + 1, color, areas[i]);
        TextRend.DisplayString(STAMP_COL, row + 1, color, stamps[i]);
      end else
        TextRend.DisplayString(1, row, color, listed[i] + ': EMPTY');
    end;
  end;
  if top + VISIBLE - 1 < count then
    SaveMenu.DrawMore(LIST_BOTTOM);
end;

{ Select listed entry i, wrapping past either end, scroll it into view and redraw the list. }
procedure MoveTo(i: Integer);
begin
  if i < 1 then
    i := count
  else if i > count then
    i := 1;
  sel := i;
  if sel < top then
    top := sel;
  if sel > top + VISIBLE - 1 then
    top := sel - VISIBLE + 1;
  SaveMenu.DrawList;
end;

function ChooseSlot(saving: Boolean; start: Char): Char;
var
  i: Byte;
  ch: Char;
  ext: Boolean;
  action: Types.TStr8;
  newest: LongInt;
  chosen: Char;
  letters: string[16];
begin
  ChooseSlot := C_Keys.NONE;
  { a string constant cannot be indexed }
  letters := SLOT_LETTERS;
  count := 0;
  for i := 1 to Length(letters) do begin
    SaveMenu.ReadSlot(count + 1, letters[i]);
    if saving or used[count + 1] then
      Inc(count);
  end;
  listed[0] := Chr(count);
  if count = 0 then
    Exit;
  sel := 1;
  newest := 0;
  for i := 1 to count do
    if used[i] and ((newest = 0) or (times[i] > newest)) then begin
      newest := times[i];
      sel := i;
    end;
  if Pos(start, listed) > 0 then
    sel := Pos(start, listed);
  top := 1;
  TextRend.ClearScreen;
  Border.DrawBorder(1, LIST_TOP, 38, LIST_BOTTOM, 0);
  Border.DrawBorder(1, TITLE_ROW, 38, TITLE_ROW, 0);
  TextRend.DisplayString(1 + (38 - 19) div 2, TITLE_ROW, White, 'Load/Save Game Menu');
  SaveMenu.MoveTo(sel);
  if saving then
    action := 'Save'
  else
    action := 'Load';
  chosen := ' ';
  repeat
    MenuCore.extraKeys := listed;
    ch := MenuCore.MenuHorizontal('Game: ', action, LightMagenta, LightGreen, White, True, False, ext);
    if ext then
      case ch of
        C_Keys.UP, C_Keys.HOME: SaveMenu.MoveTo(sel - 1);
        C_Keys.DOWN, C_Keys.END_KEY: SaveMenu.MoveTo(sel + 1);
        { a screenful, stopping at the first or last slot rather than wrapping }
        C_Keys.PGUP: if sel > VISIBLE then
                       SaveMenu.MoveTo(sel - VISIBLE)
                     else
                       SaveMenu.MoveTo(1);
        C_Keys.PGDN: if sel + VISIBLE < count then
                       SaveMenu.MoveTo(sel + VISIBLE)
                     else
                       SaveMenu.MoveTo(count);
      end
    else if ch = C_Keys.NONE then
      chosen := C_Keys.NONE
    else if ch = action[1] then begin
      if saving or used[sel] then
        chosen := listed[sel];
    end else if (ch <> ' ') and (Pos(ch, listed) > 0) then
      SaveMenu.MoveTo(Pos(ch, listed));
  until chosen <> ' ';
  TextRend.ClearBottomLine;
  ChooseSlot := chosen;
end;

{ Draw the description line: desc in white, the rest of its DESC_LEN columns as dots (the font's underscore is not a
  line). }
procedure DrawDescLine(desc: TSlotDesc);
var
  i: Byte;
begin
  TextRend.DisplayString(POP_LEFT, POP_DESC_ROW, White, desc);
  for i := Length(desc) + 1 to DESC_LEN do
    TextRend.DisplayString(POP_LEFT + i - 1, POP_DESC_ROW, LightGreen, '.');
end;

function AskDescription(letter: Char; area: TSlotArea; var desc: TSlotDesc): Boolean;
var
  s: TSlotDesc;
  key: Char;
  ch: Char;
  ext: Boolean;
begin
  AskDescription := False;
  { the list is cleared behind it; a title box on row 7, the slot and area on rows 9 and 10, the description on rows
    12 and 13 }
  Border.ClearBox(1, LIST_TOP, 38, LIST_BOTTOM);
  Border.DrawBorder(POP_LEFT, 9, POP_RIGHT, 10, 0);
  Border.DrawBorder(POP_LEFT, 12, POP_RIGHT, POP_DESC_ROW, 0);
  Border.DrawBorder(POP_LEFT, 7, POP_RIGHT, 7, 0);
  TextRend.DisplayString(POP_LEFT + (POP_RIGHT - POP_LEFT + 1 - 9) div 2, 7, White, 'Save Game');
  TextRend.DisplayString(POP_LEFT, 9, LightGreen, 'Save Game ' + letter);
  TextRend.DisplayString(POP_LEFT, 10, LightGreen, 'Location: ' + area);
  TextRend.DisplayString(POP_LEFT, 12, LightGreen, 'Description:');
  s := desc;
  SaveMenu.DrawDescLine(s);
  TextRend.ClearBottomLine;
  TextRend.DisplayString(0, 24, LightMagenta, 'Type a description, then press Enter');
  repeat
    key := GameIo.ReadGameKey;
    case key of
      { an extended key's scan code follows its #0: neither is typed }
      #0: key := GameIo.ReadGameKey;
      ' '..'z':
        if Length(s) < DESC_LEN then begin
          s := s + UpCase(key);
          SaveMenu.DrawDescLine(s);
        end;
      C_Keys.BACKSPACE:
        if Length(s) > 0 then begin
          s := Copy(s, 1, Length(s) - 1);
          SaveMenu.DrawDescLine(s);
        end;
    end;
  until (key = C_Keys.ENTER) or (key = C_Keys.ESC);
  TextRend.ClearBottomLine;
  ch := C_Keys.NONE;
  if key = C_Keys.ENTER then
    ch := MenuCore.MenuHorizontal('Save: ', 'Okay Exit', LightMagenta, LightGreen, White, False, False, ext);
  TextRend.ClearBottomLine;
  if ch = 'O' then begin
    desc := s;
    AskDescription := True;
  end;
end;

{ 'Put save disk in C:', for the save directory's drive. }
function SaveDiskMsg: Types.TStr40;
begin
  SaveDiskMsg := 'Put save disk in ' + GDVars.dsSaveDirectory[1] + ':';
end;

procedure CheckSaveDir;
var
  ioRes: Integer;
  i: Byte;
begin
  if Length(GDVars.dsSaveDirectory) <= 3 then Exit;
  repeat
    { each parent first, from the one below the root; its errors show again in the last MkDir }
    for i := 4 to Length(GDVars.dsSaveDirectory) - 1 do
      if GDVars.dsSaveDirectory[i] = '\' then begin
        MkDir(Copy(GDVars.dsSaveDirectory, 1, i - 1));
        ioRes := IOResult;
      end;
    MkDir(Copy(GDVars.dsSaveDirectory, 1, Length(GDVars.dsSaveDirectory) - 1));
    ioRes := IOResult;
    if (ioRes <> 0) and (ioRes <> 5) then
      TextRend.DisplayAndPause(Yellow, SaveMenu.SaveDiskMsg);
  until (ioRes = 0) or (ioRes = 5);
end;

end.

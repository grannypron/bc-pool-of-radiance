{ The Bestiary's pages (#842): F2 on the map, wilderness and camp menus opens them, outside combat, whatever the
  Companion Tools setting. The list page shows every creature the party has met, by name in two columns, a page at a
  time; the entry page shows what the party has learned of one (Bestiary), and ?? for what it has not. The sage (#868)
  has the party choose a creature from the same list page. }
{$O+,F+}
{$I COMPILER.INC}
unit BeastMnu;

interface

uses Types, Bestiary;

{ The Bestiary's list page until Exit or Escape, its entry pages from it. The caller redraws its screen afterwards. }
procedure BestiaryMenu;

{ The Bestiary's list page for choosing a creature, prompt on its menu (Ask Next Prev Exit): the entry chosen with Ask
  or Enter, nil on Exit or Escape. The caller redraws its screen afterwards. }
function PickBeast(prompt: Types.TStr40): Bestiary.PBeast;

{ The entry page of b until Exit or Escape. The caller redraws its screen afterwards. }
procedure ShowEntry(var b: Bestiary.TBeast);

implementation

uses {$IFDEF FPC}TpCompat, {$ENDIF}Crt, C_KEYS, C_MSG, C_BEAST, GameVars, TextRend, Border, MenuCore, StrUtil;

const
  { the list page: two columns of up to LIST_ROWS names from LIST_TOP, the count on COUNT_ROW }
  TITLE_ROW = 1;
  LIST_TOP = 3;
  LIST_ROWS = 18;
  LIST_LEFT = 3;
  LIST_COL_WIDTH = 18;
  PER_PAGE = 2 * LIST_ROWS;
  COUNT_ROW = 22;
  { the entry page: the facts' names at FACT_COL and their values at VALUE_COL from FACTS_TOP; the defenses and attacks
    below them, each under its heading, at ITEM_COL (in two columns, the second at ITEM_COL2, when one does not fit) }
  FACTS_TOP = 3;
  FACT_COL = 2;
  VALUE_COL = 20;
  ITEM_COL = 4;
  ITEM_COL2 = 21;
  LAST_ROW = 22;
  UNKNOWN = '??';

type
  TOrder = array[1..Bestiary.MAX_ENTRIES] of Word;
  POrder = ^TOrder;

{ The frame, and title centred in white on its top row. }
procedure DrawFrame(title: Types.TStr40);
begin
  TextRend.ClearScreen;
  Border.DrawBorder(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0);
  TextRend.DisplayCentered(C_MSG.TEXT_LEFT, C_MSG.TEXT_RIGHT, TITLE_ROW, White, title);
end;

{ The entry at place i of the list. }
function At(order: POrder; i: Word): PBeast;
begin
  if order <> nil then
    At := Bestiary.Entry(order^[i])
  else
    At := Bestiary.Entry(i);
end;

{ The table's entries sorted by name, in a list on the heap (n entries); nil, the table's own order, when the heap has
  no room for it. }
function SortedOrder(n: Word): POrder;
var
  order: POrder;
  gap: Word;
  i: Word;
  j: Word;
  t: Word;
begin
  SortedOrder := nil;
  if (n = 0) or (MaxAvail < LongInt(n) * SizeOf(Word)) then Exit;
  GetMem(order, n * SizeOf(Word));
  for i := 1 to n do
    order^[i] := i;
  { a Shell sort: the table may hold a few hundred kinds once Curse's and the later games' are in it }
  gap := n div 2;
  while gap > 0 do begin
    for i := gap + 1 to n do begin
      t := order^[i];
      j := i;
      while (j > gap) and (Bestiary.Entry(order^[j - gap])^.name > Bestiary.Entry(t)^.name) do begin
        order^[j] := order^[j - gap];
        Dec(j, gap);
      end;
      order^[j] := t;
    end;
    gap := gap div 2;
  end;
  SortedOrder := order;
end;

{ The names on the page from place top (of n), down the left column, then the right, the one at place sel in white and
  the rest in green; the count under them. }
procedure DrawList(order: POrder; n, top, sel: Word);
var
  shown: Word;
  rows: Word;
  k: Word;
  colour: Byte;
  s: Types.TStr40;
begin
  DrawFrame('Bestiary');
  if n = 0 then begin
    TextRend.DisplayString(LIST_LEFT, LIST_TOP, LightGreen, 'None met yet');
    Exit;
  end;
  shown := n - top + 1;
  if shown > PER_PAGE then
    shown := PER_PAGE;
  rows := (shown + 1) div 2;
  for k := 0 to shown - 1 do begin
    colour := LightGreen;
    if top + k = sel then
      colour := White;
    TextRend.DisplayString(LIST_LEFT + (k div rows) * LIST_COL_WIDTH, LIST_TOP + k mod rows, colour,
                           At(order, top + k)^.name);
  end;
  s := StrUtil.Count(n, 'Creature', 'Creatures');
  TextRend.DisplayCentered(C_MSG.TEXT_LEFT, C_MSG.TEXT_RIGHT, COUNT_ROW, LightCyan, s);
end;

{ The armor class b's rolls have shown: the one value once they have narrowed it to that, else as far as they go. }
function ArmorText(var b: Bestiary.TBeast): Types.TStr40;
begin
  if (b.acLo = C_BEAST.AC_NO_LOW) and (b.acHi = C_BEAST.AC_NO_HIGH) then
    ArmorText := UNKNOWN
  else if b.acLo = b.acHi then
    ArmorText := StrUtil.NumStr(b.acLo)
  else if b.acLo = C_BEAST.AC_NO_LOW then
    ArmorText := StrUtil.NumStr(b.acHi) + ' or better'
  else if b.acHi = C_BEAST.AC_NO_HIGH then
    ArmorText := StrUtil.NumStr(b.acLo) + ' or worse'
  else
    ArmorText := StrUtil.NumStr(b.acLo) + ' to ' + StrUtil.NumStr(b.acHi);
end;

{ The entry page's line for defense or attack fact; literals, in the overlay, rather than a table in the data segment. }
function FactName(fact: Byte): Types.TStr40;
begin
  case fact of
    C_BEAST.HALF_BLUNT: FactName := 'Half: blunt';
    C_BEAST.HALF_PIERCE: FactName := 'Half: piercing';
    C_BEAST.HALF_SLASH: FactName := 'Half: slashing';
    C_BEAST.HALF_MAGICAL: FactName := 'Half: magic wpns';
    C_BEAST.HALF_FIRE: FactName := 'Half: fire';
    C_BEAST.HALF_COLD: FactName := 'Half: cold';
    C_BEAST.HALF_ELEC: FactName := 'Half: lightning';
    C_BEAST.IMMUNE_POISON: FactName := 'No poison';
    C_BEAST.IMMUNE_PARALYSIS: FactName := 'No paralysis';
    C_BEAST.IMMUNE_SLEEP_CHARM: FactName := 'No sleep, charm';
    C_BEAST.IMMUNE_MM: FactName := 'No magic missile';
    C_BEAST.IMMUNE_COLD: FactName := 'No cold';
    C_BEAST.IMMUNE_FIRE: FactName := 'No fire';
    C_BEAST.IMMUNE_ELEC: FactName := 'No lightning';
    C_BEAST.NEEDS_MAGIC: FactName := 'Magic wpns only';
    C_BEAST.MAGIC_RES: FactName := 'Resists magic';
    C_BEAST.REGENERATES: FactName := 'Regenerates';
    C_BEAST.ATK_POISON: FactName := 'Poison';
    C_BEAST.ATK_PARALYZE: FactName := 'Paralysis';
    C_BEAST.ATK_DRAIN: FactName := 'Level drain';
    C_BEAST.ATK_ROT: FactName := 'Rotting disease';
    C_BEAST.ATK_PETRIFY: FactName := 'Petrifying gaze';
    C_BEAST.ATK_CHARM: FactName := 'Charming gaze';
  else
    FactName := '';
  end;
end;

{ How many of b's facts first..last it knows. }
function KnownCount(var b: Bestiary.TBeast; first, last: Byte): Byte;
var
  f: Byte;
  n: Byte;
begin
  n := 0;
  for f := first to last do
    if Bestiary.Knows(b, f) then
      Inc(n);
  KnownCount := n;
end;

{ heading in cyan on row, then b's known facts first..last under it, ?? after them for what may be still to learn
  unless the sage has told all (C_BEAST.TOLD, #868): one a line, or two a line when twoCols. Row comes back as the row
  after them. }
procedure DrawGroup(var b: Bestiary.TBeast; heading: Types.TStr40; first, last: Byte; twoCols: Boolean;
                    var row: Byte);
var
  f: Byte;
  k: Byte;
begin
  TextRend.DisplayString(FACT_COL, row, LightCyan, heading);
  Inc(row);
  k := 0;
  for f := first to last do
    if Bestiary.Knows(b, f) and (row <= LAST_ROW) then begin
      if twoCols and (k mod 2 = 1) then
        TextRend.DisplayString(ITEM_COL2, row, LightGreen, FactName(f))
      else
        TextRend.DisplayString(ITEM_COL, row, LightGreen, FactName(f));
      Inc(k);
      if not twoCols or (k mod 2 = 0) then
        Inc(row);
    end;
  if (row <= LAST_ROW) and not Bestiary.Knows(b, C_BEAST.TOLD) then begin
    if twoCols and (k mod 2 = 1) then
      TextRend.DisplayString(ITEM_COL2, row, Yellow, UNKNOWN)
    else
      TextRend.DisplayString(ITEM_COL, row, Yellow, UNKNOWN);
    Inc(row);
  end;
end;

{ One of the entry page's facts: name in green, value in white, or ?? in yellow when not known. }
procedure DrawFact(row: Byte; name: Types.TStr40; known: Boolean; value: Types.TStr40);
begin
  TextRend.DisplayString(FACT_COL, row, LightGreen, name);
  if known then
    TextRend.DisplayString(VALUE_COL, row, White, value)
  else
    TextRend.DisplayString(VALUE_COL, row, Yellow, UNKNOWN);
end;

{ The entry page of b: the counts and what it is, then its defenses and its attacks, each list in two columns when the
  page has no room for them one a line. }
procedure DrawEntry(var b: Bestiary.TBeast);
var
  row: Byte;
  s: Types.TStr40;
  defenses: Byte;
  attacks: Byte;
  twoCols: Boolean;
begin
  DrawFrame(b.name);
  s := StrUtil.Count(b.seen, 'time', 'times');
  DrawFact(FACTS_TOP, 'Seen', True, s);
  DrawFact(FACTS_TOP + 1, 'Killed', True, StrUtil.NumStr(b.killed));
  if Bestiary.Knows(b, C_BEAST.LARGE) then
    s := 'Large'
  else
    s := 'Man-sized or less';
  DrawFact(FACTS_TOP + 2, 'Size', Bestiary.Knows(b, C_BEAST.SIZE_KNOWN), s);
  s := ArmorText(b);
  DrawFact(FACTS_TOP + 3, 'Armor Class', s <> UNKNOWN, s);
  if b.hd < 1 then
    s := 'Less than 1'
  else
    s := StrUtil.NumStr(b.hd);
  DrawFact(FACTS_TOP + 4, 'Hit Dice', Bestiary.Knows(b, C_BEAST.HD_KNOWN), s);
  DrawFact(FACTS_TOP + 5, 'Most Damage Done', b.maxHit > 0, StrUtil.NumStr(b.maxHit) + ' in one blow');
  { each list a heading, its facts, ?? and a blank line, in the rows from the facts' blank line down }
  row := FACTS_TOP + 7;
  defenses := KnownCount(b, C_BEAST.FIRST_DEFENSE, C_BEAST.LAST_DEFENSE);
  attacks := KnownCount(b, C_BEAST.FIRST_ATTACK, C_BEAST.LAST_ATTACK);
  twoCols := defenses + attacks + 5 > LAST_ROW - row + 1;
  DrawGroup(b, 'Defenses', C_BEAST.FIRST_DEFENSE, C_BEAST.LAST_DEFENSE, twoCols, row);
  Inc(row);
  if row <= LAST_ROW then
    DrawGroup(b, 'Attacks', C_BEAST.FIRST_ATTACK, C_BEAST.LAST_ATTACK, twoCols, row);
end;

{ The entry pages from place sel of the list (n entries): Next and Prev turn to the next and previous creature on it,
  round from either end, until Exit or Escape. sel comes back as the place of the last one shown. }
procedure EntryPages(order: POrder; n: Word; var sel: Word);
var
  ch: Char;
  ext: Boolean;
  b: PBeast;
begin
  GameVars.horizChoice := 1;
  repeat
    b := At(order, sel);
    DrawEntry(b^);
    ch := MenuCore.MenuHorizontal(b^.name + ': ', 'Next Prev Exit', LightMagenta, LightGreen, White, False, False,
                                  ext);
    case ch of
      'N': if sel < n then Inc(sel) else sel := 1;
      'P': if sel > 1 then Dec(sel) else sel := n;
    end;
  until ch in [C_KEYS.NONE, 'E'];
end;

procedure ShowEntry(var b: Bestiary.TBeast);
var
  ch: Char;
  ext: Boolean;
begin
  GameVars.horizChoice := 1;
  DrawEntry(b);
  repeat
    ch := MenuCore.MenuHorizontal(b.name + ': ', 'Exit', LightMagenta, LightGreen, White, False, False, ext);
  until ch in [C_KEYS.NONE, 'E'];
end;

{ The list page under prompt until Exit or Escape. With pick, Ask (or Enter) gives the creature at the highlight back,
  nil when the page is left without one; without it, View (or Enter) opens the entry pages there, and the result is
  nil. }
function ListPages(prompt: Types.TStr40; pick: Boolean): Bestiary.PBeast;
var
  chosen: Bestiary.PBeast;
  order: POrder;
  n: Word;
  top: Word;
  sel: Word;
  rows: Word;
  shown: Word;
  ch: Char;
  cmd: Char;
  ext: Boolean;
begin
  chosen := nil;
  n := Bestiary.Count;
  order := SortedOrder(n);
  top := 1;
  sel := 1;
  GameVars.horizChoice := 1;
  repeat
    DrawList(order, n, top, sel);
    shown := n - top + 1;
    if shown > PER_PAGE then
      shown := PER_PAGE;
    rows := (shown + 1) div 2;
    MenuCore.arrowsToCaller := True;
    MenuCore.enterToCaller := True;
    if n = 0 then
      ch := MenuCore.MenuHorizontal(prompt, 'Exit', LightMagenta, LightGreen, White, True, False, ext)
    else if pick then
      ch := MenuCore.MenuHorizontal(prompt, 'Ask Next Prev Exit', LightMagenta, LightGreen, White, True, False, ext)
    else
      ch := MenuCore.MenuHorizontal(prompt, 'View Next Prev Exit', LightMagenta, LightGreen, White, True, False,
                                    ext);
    { an extended key's scan code can be a letter's (Down is 'P'): the commands are in cmd }
    cmd := ch;
    if ext then
      cmd := C_KEYS.NONE;
    if n > 0 then begin
      if ext then
        case ch of
          C_KEYS.UP: if sel > top then Dec(sel);
          C_KEYS.DOWN: if sel < top + shown - 1 then Inc(sel);
          C_KEYS.LEFT: if sel >= top + rows then Dec(sel, rows);
          C_KEYS.RIGHT: if sel + rows < top + shown then Inc(sel, rows);
          C_KEYS.PGUP: cmd := 'P';
          C_KEYS.PGDN: cmd := 'N';
        end;
      if pick and (cmd in ['A', C_KEYS.ENTER]) then
        chosen := At(order, sel)
      else case cmd of
        'V', C_KEYS.ENTER: begin
               EntryPages(order, n, sel);
               { the page of the creature last shown }
               top := ((sel - 1) div PER_PAGE) * PER_PAGE + 1;
               GameVars.horizChoice := 1;
             end;
        'N': if top + PER_PAGE <= n then begin
               Inc(top, PER_PAGE);
               sel := top;
             end;
        'P': if top > PER_PAGE then begin
               Dec(top, PER_PAGE);
               sel := top;
             end;
      end;
    end;
  until (chosen <> nil) or ((not ext) and (ch in [C_KEYS.NONE, 'E']));
  if order <> nil then
    FreeMem(order, n * SizeOf(Word));
  TextRend.ClearBottomLine;
  ListPages := chosen;
end;

procedure BestiaryMenu;
var
  none: Bestiary.PBeast;
begin
  none := ListPages('Bestiary: ', False);
end;

function PickBeast(prompt: Types.TStr40): Bestiary.PBeast;
begin
  PickBeast := ListPages(prompt, True);
end;

end.

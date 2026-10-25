{ Spell information on the spell lists (#839): the summary line under a list and the spell page its Info opens. The
  figures come from the spell table and the routines combat uses (CharHlp.CalcSpellRange, GetCasterLevel, SpellArea
  and SpellDuration, FxEngine.AuraRange), so they match what the spell does in this port; the saving throw, which each
  handler decides, comes from this unit's save table, and the description from SpellTxt. A list line's spell is its
  spell id, with C_SPELL.FROM_ITEM set for one read from a scroll, worked out at C_SPELL.ITEM_CASTER_LEVEL as casting
  from the scroll does (GameVars.usingItem); otherwise for GameVars.curChar. Overlaid: it is loaded only while a spell
  list is up. }
{$O+,F+}
{$I COMPILER.INC}
unit SpellInf;

interface

uses Types, C_SPELL;

const
  { the summary line's widest text: the list window's columns }
  SUMMARY_WIDTH = 38;
  { the page's description: its most lines and their columns }
  TEXT_LINES = 9;
  TEXT_COLS = 36;
  { the page's figures: the column their values start in, and the columns they have up to the window's edge }
  VALUE_COL = 15;
  VALUE_WIDTH = 24;

type
  { the list lines a page steps through, each as a list line's spell }
  TLineSpells = array[0..C_SPELL.LINE_LAST] of Byte;

{ What a saving throw does against spell (C_SPELL.SAVE_NONE, SAVE_NEGATES, SAVE_HALF or SAVE_PARTIAL), as its handler
  decides it: the spell table's saveResult says only whether one is rolled. }
function SaveResult(spell: Byte): Byte;

{ The figures, each for a list line's spell. Short (long False) is the summary line's term, empty when it does not
  apply; long is the page's value. }

{ Range in squares (RNG 6), or SELF or TOUCH; none for a spell that is not aimed (Snake Charm, Animate Dead) or is cast
  only in camp on a character the player picks. }
function RangeText(line: Byte; long: Boolean): Types.TStr40;

{ What the spell reaches (CharHlp.SpellArea): a radius (AREA R2), an aura around its target or caster, Stinking
  Cloud's 2x2 block, Lightning Bolt's path, up to a number of creatures picked (TGT 1-3), every creature it seeks on
  the field (AREA ALL) or the whole party in camp (AREA PARTY). A single creature, or the caster, has no short term. }
function AreaText(line: Byte; long: Boolean): Types.TStr40;

{ The duration (CharHlp.SpellDuration) in rounds (RD), turns of 10 (TU) or hours (HR), whichever both its fixed part
  and its part per caster level come in (Hold Person's 4 + 1 a level stays in rounds at level 6), or as dice for one
  that rolls it (DUR 1D6 TU); INST for a spell that adds no effect, PERM for one whose effect lasts until it is ended. }
function DurationText(line: Byte; long: Boolean): Types.TStr40;

{ The saving throw (SaveResult) and, on the page, its column (VS SPELL); none when no save is rolled. }
function SaveText(spell: Byte; long: Boolean): Types.TStr40;

{ When it can be cast: CAMP or CBT for a spell cast only there, none for either; Knock, cast only at a locked door,
  DOORS. }
function WhenText(spell: Byte; long: Boolean): Types.TStr40;

{ The page's casting time: AT ONCE when it costs no initiative in combat (castTime div 3 is 0, CbtActs.CastSpellCombat),
  else the initiative it costs, the spell going off later in the round; empty for a spell cast only in camp. }
function CastTimeText(spell: Byte): Types.TStr40;

{ The summary line: the short terms of RangeText, AreaText, DurationText, SaveText and WhenText that apply, two blanks
  apart, or one when two would run past SUMMARY_WIDTH. }
function Summary(line: Byte): Types.TStr40;

{ Line n (from 1) of spell's description (SpellTxt), or an empty string past its last. }
function TextLine(spell, n: Byte): Types.TStr40;

{ Draw line's summary on row, in light green, over the list window's columns; line 0 (a level heading) clears it. }
procedure ShowSummary(line, row: Byte);

{ The spell page for lines[cur] over the list window (rows 3 to 22): its name, class and level, the figures, and its
  description. Next and Prev (N, P, Down and Up, Page Down and Page Up) step through the count lines, wrapping round;
  Exit or Escape returns, with cur the line shown last. }
procedure ShowPage(var lines: TLineSpells; count: Integer; var cur: Integer);

implementation

uses Crt, GameDefs, GameVars, C_KEYS, CharHlp, FxEngine, StrUtil, TextRend, Border, MenuCore, CharDisp, SpellTxt;

const
  { what a save does against each spell, checked against the handlers (Magic): Silence's negates its aura, Stinking
    Cloud's leaves the creature coughing for a round (FxEngine.ConsiderStinkingCloud) }
  saveResults: array[1..C_SPELL.LAST] of Byte = (
    { 1..10: Bless .. Charm Person }
    0, 0, 0, 0, 0, 0, 0, 0, 0, 1,
    { 11..20: Detect Magic .. Shocking Grasp; Reduce's handler rolls its own }
    0, 0, 1, 0, 0, 0, 0, 0, 0, 0,
    { 21..30: Sleep .. Invisibility; Hold Person, Silence }
    0, 0, 1, 0, 1, 0, 0, 0, 0, 0,
    { 31..40: Knock .. Cause Disease; Ray of Enfeeblement, Stinking Cloud, Cause Blindness, Cause Disease }
    0, 0, 1, 4, 0, 0, 0, 1, 0, 1,
    { 41..50: Dispel Magic .. Invisibility, 10' Radius; Bestow Curse, Fireball, Hold Person }
    0, 0, 0, 1, 0, 0, 2, 0, 1, 0,
    { 51..56: Lightning Bolt .. Restoration }
    2, 0, 0, 0, 0, 0);
  { the save columns' names, by C_SAVE }
  saveNames: array[0..4] of String[7] = (
    'POISON', 'PETRIFY', 'WAND', 'BREATH', 'SPELL');

{ line's spell id, with GameVars.usingItem set as casting it would set it; old receives usingItem to restore. }
function UseLine(line: Byte; var old: Boolean): Byte;
begin
  old := GameVars.usingItem;
  GameVars.usingItem := line and C_SPELL.FROM_ITEM <> 0;
  UseLine := line and C_SPELL.ID_MASK;
end;

{ True for a spell cast only in camp: its target is a character picked from the party, or the party (spellTable's
  target), not a place on the combat map. }
function CampOnly(spell: Byte): Boolean;
begin
  CampOnly := GameDefs.spellTable[spell].whenCast = 0;
end;

function SaveResult(spell: Byte): Byte;
begin
  if (spell >= 1) and (spell <= C_SPELL.LAST) then
    SaveResult := saveResults[spell]
  else
    SaveResult := GameDefs.spellTable[spell].saveResult;
end;

function RangeText(line: Byte; long: Boolean): Types.TStr40;
var
  spell: Byte;
  old: Boolean;
  size: Byte;
  s: Types.TStr40;
begin
  spell := UseLine(line, old);
  s := '';
  with GameDefs.spellTable[spell] do
    if spell = C_SPELL.KNOCK then begin
      if long then
        s := 'TOUCH';
    end else if CampOnly(spell) then begin
      if target = 1 then
        s := 'SELF'
      else if long then
        s := 'ANY OF THE PARTY';
    end else if CharHlp.SpellArea(spell, size) = C_SPELL.AREA_SELF then begin
      if target = 1 then
        s := 'SELF'
      else if long then
        s := 'ANYWHERE';
    end else if (rangeFixed = C_SPELL.ATTACK_ROLL_RANGE) or (rangeFixed + rangeVar = 0) then
      s := 'TOUCH'
    else if long then
      s := StrUtil.Count(CharHlp.CalcSpellRange(spell), 'SQUARE', 'SQUARES')
    else
      s := StrUtil.NumStr(CharHlp.CalcSpellRange(spell));
  if (s <> '') and not long then
    s := 'RNG ' + s;
  RangeText := s;
  GameVars.usingItem := old;
end;

function AreaText(line: Byte; long: Boolean): Types.TStr40;
var
  spell: Byte;
  old: Boolean;
  kind: Byte;
  size: Byte;
  aura: Byte;
  s: Types.TStr40;
  l: Types.TStr40;
begin
  spell := UseLine(line, old);
  s := '';
  l := '';
  kind := CharHlp.SpellArea(spell, size);
  aura := 0;
  with GameDefs.spellTable[spell] do begin
    if effect > 0 then
      aura := FxEngine.AuraRange(effect);
    if spell = C_SPELL.KNOCK then
      l := 'ONE DOOR'
    else if CampOnly(spell) then
      case target of
        1: l := 'THE CASTER';
        4: begin
             s := 'AREA PARTY';
             l := 'THE WHOLE PARTY';
           end;
      else
        l := '1 CHARACTER';
      end
    else if aura > 0 then begin
      s := 'AREA R' + StrUtil.NumStr(aura);
      if kind = C_SPELL.AREA_SELF then
        l := 'RADIUS ' + StrUtil.NumStr(aura) + ' AROUND CASTER'
      else
        l := 'RADIUS ' + StrUtil.NumStr(aura) + ' AROUND TARGET';
    end else
      case kind of
        C_SPELL.AREA_SELF:
          if target = 1 then
            l := 'THE CASTER'
          else begin
            s := 'AREA ALL';
            l := 'THE WHOLE FIELD';
          end;
        C_SPELL.AREA_TARGETS:
          if size = 1 then
            l := '1 CREATURE'
          else begin
            s := 'TGT 1-' + StrUtil.NumStr(size);
            l := 'UP TO ' + StrUtil.NumStr(size) + ' CREATURES';
          end;
        C_SPELL.AREA_SPOT: l := '1 CREATURE';
        C_SPELL.AREA_RADIUS: begin
            s := 'AREA R' + StrUtil.NumStr(size);
            l := 'RADIUS ' + StrUtil.Count(size, 'SQUARE', 'SQUARES');
          end;
        C_SPELL.AREA_CLOUD: begin
            s := 'AREA 2x2';
            l := '2x2 SQUARES';
          end;
        C_SPELL.AREA_BOLT: begin
            s := 'AREA BOLT';
            l := 'BOLT, ' + StrUtil.NumStr(size) + ' SQUARES PAST AIM';
          end;
      end;
  end;
  if long then
    AreaText := l
  else
    AreaText := s;
  GameVars.usingItem := old;
end;

function DurationText(line: Byte; long: Boolean): Types.TStr40;
var
  spell: Byte;
  old: Boolean;
  d: Types.TDurDice;
  m: Word;
  { minutes to the unit shown: 1 rounds, 10 turns, 60 hours }
  u: Byte;
  s: Types.TStr40;
  n: Types.TStr20;
begin
  spell := UseLine(line, old);
  CharHlp.SpellDuration(spell, d);
  if d.count > 0 then begin
    n := StrUtil.NumStr(d.count) + 'D' + StrUtil.NumStr(d.sides);
    if d.add > 0 then
      n := n + '+' + StrUtil.NumStr(d.add);
    case d.mult of
      1: if long then s := n + ' ROUNDS' else s := n + ' RD';
      10: if long then s := n + ' TURNS' else s := n + ' TU';
    else
      if long then s := n + ' HOURS' else s := n + ' HR';
    end;
  end else begin
    m := d.add * d.mult;
    { the unit both the fixed part and the part per level come in, so a spell keeps its unit at every level }
    with GameDefs.spellTable[spell] do
      if d.mult > 1 then
        u := d.mult
      else if (durFixed mod 60 = 0) and (durVar mod 60 = 0) then
        u := 60
      else if (durFixed mod 10 = 0) and (durVar mod 10 = 0) then
        u := 10
      else
        u := 1;
    if (m = 0) or (GameDefs.spellTable[spell].effect = 0) then begin
      if (m = 0) and (GameDefs.spellTable[spell].effect > 0) then begin
        if long then s := 'PERMANENT' else s := 'PERM';
      end else if long then
        s := 'INSTANT'
      else
        s := 'INST';
    end else if u = 60 then begin
      if long then s := StrUtil.Count(m div 60, 'HOUR', 'HOURS') else s := StrUtil.NumStr(m div 60) + ' HR';
    end else if u = 10 then begin
      if long then s := StrUtil.Count(m div 10, 'TURN', 'TURNS') else s := StrUtil.NumStr(m div 10) + ' TU';
    end else if long then
      s := StrUtil.Count(m, 'ROUND', 'ROUNDS')
    else
      s := StrUtil.NumStr(m) + ' RD';
  end;
  if not long then
    s := 'DUR ' + s;
  DurationText := s;
  GameVars.usingItem := old;
end;

function SaveText(spell: Byte; long: Boolean): Types.TStr40;
var
  s: Types.TStr40;
  vs: Types.TStr20;
begin
  spell := spell and C_SPELL.ID_MASK;
  vs := ' (VS ' + saveNames[GameDefs.spellTable[spell].saveType mod 5] + ')';
  case SpellInf.SaveResult(spell) of
    C_SPELL.SAVE_NEGATES: if long then s := 'NEGATES' + vs else s := 'SAVE NEG';
    C_SPELL.SAVE_HALF: if long then s := 'HALVES DAMAGE' + vs else s := 'SAVE 1/2';
    C_SPELL.SAVE_PARTIAL: if long then s := 'LESSENS' + vs else s := 'SAVE PART';
  else
    if long then s := 'NONE' else s := '';
  end;
  SaveText := s;
end;

function WhenText(spell: Byte; long: Boolean): Types.TStr40;
var
  s: Types.TStr40;
begin
  spell := spell and C_SPELL.ID_MASK;
  if spell = C_SPELL.KNOCK then begin
    if long then s := 'AT A LOCKED DOOR' else s := 'DOORS';
  end else
    case GameDefs.spellTable[spell].whenCast of
      0: if long then s := 'IN CAMP' else s := 'CAMP';
      1: if long then s := 'IN COMBAT' else s := 'CBT';
    else
      if long then s := 'IN CAMP OR COMBAT' else s := '';
    end;
  WhenText := s;
end;

function CastTimeText(spell: Byte): Types.TStr40;
var
  n: Byte;
begin
  spell := spell and C_SPELL.ID_MASK;
  n := GameDefs.spellTable[spell].castTime div 3;
  if CampOnly(spell) then
    CastTimeText := ''
  else if n = 0 then
    CastTimeText := 'AT ONCE'
  else
    CastTimeText := 'LATER: -' + StrUtil.NumStr(n) + ' INITIATIVE';
end;

function Summary(line: Byte): Types.TStr40;
var
  terms: array[1..5] of Types.TStr40;
  s: String;
  gap: Types.TStr20;
  i: Byte;
  pass: Byte;
begin
  terms[1] := SpellInf.RangeText(line, False);
  terms[2] := SpellInf.AreaText(line, False);
  terms[3] := SpellInf.DurationText(line, False);
  terms[4] := SpellInf.SaveText(line, False);
  terms[5] := SpellInf.WhenText(line, False);
  gap := '  ';
  for pass := 1 to 2 do begin
    s := '';
    for i := 1 to 5 do
      if terms[i] <> '' then begin
        if s <> '' then
          s := s + gap;
        s := s + terms[i];
      end;
    if Length(s) > SUMMARY_WIDTH then
      gap := ' ';
  end;
  if Length(s) > SUMMARY_WIDTH then
    s[0] := Chr(SUMMARY_WIDTH);
  Summary := s;
end;

function TextLine(spell, n: Byte): Types.TStr40;
var
  chunk: String;
  i: Byte;
  p: Byte;
begin
  TextLine := '';
  if (n < 1) or (n > SpellTxt.LineCount(spell)) then
    Exit;
  { 6 lines a chunk }
  chunk := SpellTxt.TextChunk(spell, (n - 1) div 6);
  for i := 1 to (n - 1) mod 6 do begin
    p := Pos(#13, chunk);
    if p = 0 then
      chunk := ''
    else
      Delete(chunk, 1, p);
  end;
  p := Pos(#13, chunk);
  if p > 0 then
    chunk[0] := Chr(p - 1);
  TextLine := chunk;
end;

procedure ShowSummary(line, row: Byte);
begin
  TextRend.PrintSpaces(1, row, Black, SUMMARY_WIDTH);
  if line and C_SPELL.ID_MASK <> 0 then
    TextRend.DisplayString(1, row, LightGreen, SpellInf.Summary(line));
end;

{ One figure row: label in light green, value in white from VALUE_COL. }
procedure Figure(row: Byte; lbl, value: Types.TStr40);
begin
  TextRend.DisplayString(1, row, LightGreen, lbl);
  TextRend.DisplayString(VALUE_COL, row, White, value);
end;

{ Draw the page for line over the list window. }
procedure DrawPage(line: Byte);
const
  FIGURE_TOP = 6;
  TEXT_TOP = 14;
var
  spell: Byte;
  old: Boolean;
  lvl: Types.TStr20;
  s: Types.TStr40;
  i: Byte;
  row: Byte;
begin
  spell := line and C_SPELL.ID_MASK;
  Border.DrawWindow(1, 3, 38, 22, 0, Black, '');
  TextRend.DisplayCentered(1, 38, 3, White, GameDefs.spellNames[spell]);
  case GameDefs.spellTable[spell].castClass of
    C_SPELL.CLASS_CLERIC: s := 'CLERIC';
    C_SPELL.CLASS_MAGE: s := 'MAGIC-USER';
  else
    s := 'ITEM';
  end;
  TextRend.DisplayCentered(1, 38, 4, LightGreen, s + ' LEVEL ' + StrUtil.NumStr(GameDefs.spellTable[spell].levelSp));
  spell := UseLine(line, old);
  lvl := StrUtil.NumStr(CharHlp.GetCasterLevel(spell));
  GameVars.usingItem := old;
  TextRend.DisplayString(1, FIGURE_TOP, LightGreen, 'CAST BY');
  if line and C_SPELL.FROM_ITEM <> 0 then
    TextRend.DisplayString(VALUE_COL, FIGURE_TOP, White, 'A SCROLL, LEVEL ' + lvl)
  else begin
    CharDisp.DisplayCreatureName(GameVars.curChar, VALUE_COL, FIGURE_TOP, False);
    if Length(GameVars.curChar^.name) + Length(', LEVEL ' + lvl) <= VALUE_WIDTH then
      s := ', LEVEL ' + lvl
    else
      s := ', LV ' + lvl;
    TextRend.DisplayString(VALUE_COL + Length(GameVars.curChar^.name), FIGURE_TOP, White, s);
  end;
  row := FIGURE_TOP + 1;
  Figure(row, 'RANGE', SpellInf.RangeText(line, True));
  Figure(row + 1, 'AREA', SpellInf.AreaText(line, True));
  Figure(row + 2, 'DURATION', SpellInf.DurationText(line, True));
  Figure(row + 3, 'SAVING THROW', SpellInf.SaveText(line, True));
  Figure(row + 4, 'CAST', SpellInf.WhenText(line, True));
  s := SpellInf.CastTimeText(line);
  if s <> '' then
    Figure(row + 5, 'CASTING TIME', s);
  for i := 1 to TEXT_LINES do
    TextRend.DisplayString(1, TEXT_TOP + i - 1, LightGreen, SpellInf.TextLine(spell, i));
end;

procedure ShowPage(var lines: TLineSpells; count: Integer; var cur: Integer);
var
  ch: Char;
  ext: Boolean;
  menu: Types.TStr40;
  step: Integer;
  done: Boolean;
begin
  if (count < 1) or (cur < 0) or (cur >= count) then
    Exit;
  if count > 1 then
    menu := 'Next Prev Exit'
  else
    menu := 'Exit';
  done := False;
  repeat
    SpellInf.DrawPage(lines[cur]);
    step := 0;
    GameVars.horizChoice := 1;
    repeat
      ch := MenuCore.MenuHorizontal('Spell: ', menu, LightMagenta, LightGreen, White, True, False, ext);
      if ext then
        case ch of
          C_KEYS.UP, C_KEYS.PGUP: step := -1;
          C_KEYS.DOWN, C_KEYS.PGDN: step := 1;
        end
      else
        case ch of
          'P': step := -1;
          'N': step := 1;
          C_KEYS.NONE, 'E': done := True;
        end;
      if count < 2 then
        step := 0;
    until done or (step <> 0);
    if step <> 0 then
      cur := (cur + count + step) mod count;
  until done;
  TextRend.ClearBottomLine;
end;

end.

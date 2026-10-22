{ The Companion Tools' character editor (phase 8 of docs/refactor-plan.md): the party's characters changed in place, on
  their character sheets. Abilities and hit points are CharGen's Modify Character, without its no-experience check;
  levels go up as training raises them (CharGen.GainLevels) and down by a hit die's average, to the experience tables'
  last level whatever the race; gear adds any item RandItem makes and sets the coins; magic sets the spells known;
  health heals and sets the status. Edited characters are not marked. }
{$O+,F+}
{$I COMPILER.INC}
unit CharEdit;

interface

{ Edit the party's characters until Exit or Escape, starting with curChar; Up, Down, Home and End pick another. }
procedure EditMenu;

implementation

uses Crt, Types, C_ABIL, C_ITEM, C_Keys, C_Level, C_Money, C_MSG, C_SPELL, C_STATUS, GDConsts, GDVars, Border, CharDisp,
  CharGen, CharHlp, ClassCal, MenuCore, Party, RandItem, Shop, StrUtil, TextRend, ViewChar;

const
  { the Levels screen's first row and its columns }
  LEVEL_ROW = 4;
  NAME_COL = 3;
  VALUE_COL = 16;
  { the Add list: titles, weapons and armour by item type, the magic items by template (TEMPLATE_CODE + template) and
    the scrolls by item type; lines past MAX_LINES are left off }
  MAX_LINES = 100;
  TEMPLATE_CODE = 256;
  { the item type each of GDConsts.randomItemTemplates is made on, as RandItem rolls them; 0 for the Scroll of Restoring
    Levels, which RandItem never makes }
  TEMPLATE_KINDS: array[1..19] of Byte = (71, 84, 71, 71, 0, 69, 78, 79, 78, 63, 71, 70, 92, 21, 78, 69, 69, 70, 67);
  { the highest plus a weapon or armour takes here: name parts run to +5 (C_ITEM.NAME_PLUS_BASE) }
  PLUS_LAST = 5;
  { the bracers' choices, AC 6, 4 and 2: their plus, as RandItem gives it, and their name part; each is worth 3000 gp a
    point of plus }
  BRACERS_LAST = 3;
  BRACERS_PLUS: array[1..BRACERS_LAST] of Byte = (4, 6, 8);
  BRACERS_NAME: array[1..BRACERS_LAST] of Byte = (C_ITEM.NAME_AC_6, C_ITEM.NAME_AC_4, C_ITEM.NAME_AC_2);
  BRACERS_GP = 3000;

type
  THeld = array[0..7] of ShortInt;
  TCodes = array[0..MAX_LINES] of Word;

{ The class slots (C_Level) curChar has levels in, in order, and how many. }
procedure HeldClasses(var held: THeld; var count: Byte);
var
  cls: ShortInt;
begin
  count := 0;
  for cls := C_Level.CLERIC to C_Level.MONK do
    if GDVars.curChar^.classLevels[cls] > 0 then begin
      held[count] := cls;
      Inc(count);
    end;
end;

{ A level of class slot cls taken off curChar: hit points less a hit die's average and the class's Constitution bonus
  divided by the class count (at least 1, not below ClassCal.HpMinimum, damage kept), the skills recalculated, and a
  cleric or magic-user back at level 1 given level 1's one slot. }
procedure LowerLevel(cls: ShortInt; clsCount: Byte);
var
  avg: Integer;
  loss: Integer;
  dmg: Integer;
  hp: Integer;
begin
  with GDVars.curChar^ do begin
    if classLevels[cls] <= 1 then Exit;
    avg := GDConsts.hpSides[cls] div 2 + 1;
    loss := (avg + ClassCal.ConHpPerDie(cls, stats[C_ABIL.CONSTITUTION])) div clsCount;
    if loss < 1 then
      loss := 1;
    Dec(classLevels[cls]);
    dmg := hpMax - hpCur;
    hp := hpMax - loss;
    if hp < ClassCal.HpMinimum(GDVars.curChar) then
      hp := ClassCal.HpMinimum(GDVars.curChar);
    if hp < 1 then
      hp := 1;
    hpMax := hp;
    if hp - dmg < 0 then
      hpCur := 0
    else
      hpCur := hp - dmg;
    if hpRolled > avg div clsCount then
      Dec(hpRolled, avg div clsCount);
    if classLevels[cls] = 1 then
      case cls of
        C_Level.CLERIC: begin
            FillChar(clericSpells, SizeOf(clericSpells), 0);
            clericSpells[1] := 1;
            ClassCal.AwardWisdomBonus(Types.PCharRecord(GDVars.curChar));
          end;
        C_Level.MAGE: begin
            FillChar(mageSpells, SizeOf(mageSpells), 0);
            mageSpells[1] := 1;
          end;
      end;
    { the level drained or lowered to is the creature's level, as EffHndlr's drain sets it }
    levelHighest := 0;
    ClassCal.RecalcBaseSkills(Types.PCharRecord(GDVars.curChar));
  end;
end;

{ The experience a level of class slot cls starts at: 0 for level 1. }
function LevelXp(cls: ShortInt; level: Byte): LongInt;
begin
  if level < 2 then
    LevelXp := 0
  else
    LevelXp := GDConsts.experienceSpellsClass[cls].xp[level];
end;

{ The Levels screen: each class's level, the experience and hit points; row sel highlighted. }
procedure DrawLevels(sel: Byte);
var
  held: THeld;
  count: Byte;
  i: Byte;
  colour: Byte;
begin
  HeldClasses(held, count);
  Border.ClearBox(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
  CharDisp.DisplayCreatureName(Types.PCharRecord(GDVars.curChar), NAME_COL, 2, False);
  for i := 0 to count - 1 do begin
    colour := LightGreen;
    if i = sel then
      colour := LightMagenta;
    TextRend.DisplayString(NAME_COL, LEVEL_ROW + i, colour, GDConsts.classNames[held[i]]);
    TextRend.DisplayString(VALUE_COL, LEVEL_ROW + i, White,
                           'level ' + StrUtil.NumStr(GDVars.curChar^.classLevels[held[i]]) + ' ');
  end;
  TextRend.DisplayString(NAME_COL, LEVEL_ROW + count + 1, LightGreen, 'Experience');
  TextRend.DisplayString(VALUE_COL, LEVEL_ROW + count + 1, White, StrUtil.NumStr(GDVars.curChar^.experience) + '   ');
  TextRend.DisplayString(NAME_COL, LEVEL_ROW + count + 2, LightGreen, 'Hit points');
  TextRend.DisplayString(VALUE_COL, LEVEL_ROW + count + 2, White, StrUtil.NumStr(GDVars.curChar^.hpCur) + '/' +
                         StrUtil.NumStr(GDVars.curChar^.hpMax) + '   ');
end;

{ The Levels tool: Up and Down pick a class, Left and Right lower or raise its level (1 to C_Level.LEVEL_LAST, past the
  racial limits), the experience following into the level's range; Experience types a new total. }
procedure LevelsTool;
var
  held: THeld;
  count: Byte;
  sel: Byte;
  key: Char;
  ext: Boolean;
  cls: ShortInt;
  s: Types.TStr40;
  xp: LongInt;
  code: Integer;
begin
  HeldClasses(held, count);
  if count = 0 then Exit;
  sel := 0;
  repeat
    DrawLevels(sel);
    MenuCore.arrowsToCaller := True;
    key := MenuCore.MenuHorizontal('Levels: ', 'Experience Done', LightMagenta, LightGreen, White, True, False, ext);
    cls := held[sel];
    if ext then
      with GDVars.curChar^ do
        case key of
          C_Keys.DOWN: sel := (sel + 1) mod count;
          C_Keys.UP: sel := (sel + count - 1) mod count;
          C_Keys.LEFT:
            if classLevels[cls] > 1 then begin
              LowerLevel(cls, count);
              { past the level's range, the experience comes down to one short of the next level }
              if experience >= LevelXp(cls, classLevels[cls] + 1) then
                experience := LevelXp(cls, classLevels[cls] + 1) - 1;
            end;
          C_Keys.RIGHT:
            if classLevels[cls] < C_Level.LEVEL_LAST then begin
              CharGen.GainLevels(GDConsts.classBit[cls], False);
              if experience < LevelXp(cls, classLevels[cls]) then
                experience := LevelXp(cls, classLevels[cls]);
            end;
        end
    else if key = 'E' then begin
      s := TextRend.ReadString('Experience: ', LightGreen, 7);
      Val(s, xp, code);
      if (code = 0) and (xp >= 0) then
        GDVars.curChar^.experience := xp;
    end;
  until (not ext) and (key in ['D', C_Keys.NONE]);
end;

{ The Health tool, on the character sheet: Heal restores every hit point and wakes the unconscious and dying; Status
  steps through okay, unconscious, dying, dead, stoned and gone, an okay character keeping at least 1 hit point and the
  rest none. Either way the character is in action (enabled) only when okay or animated, as the temple and the healing
  spells and CharHlp's damage leave one (#694): the party list and combat go by enabled, not status. }
procedure HealthTool;
var
  key: Char;
  ext: Boolean;
begin
  repeat
    ViewChar.DisplayChar(GDVars.curChar);
    key := MenuCore.MenuHorizontal('Health: ', 'Heal Status Exit', LightMagenta, LightGreen, White, False, False, ext);
    with GDVars.curChar^ do
      case key of
        'H': begin
               hpCur := hpMax;
               if status in [C_STATUS.UNCONSCIOUS, C_STATUS.DYING] then
                 status := C_STATUS.OKAY;
               enabled := Ord(status in [C_STATUS.OKAY, C_STATUS.ANIMATED]);
             end;
        'S': begin
               case status of
                 C_STATUS.OKAY: status := C_STATUS.UNCONSCIOUS;
                 C_STATUS.UNCONSCIOUS: status := C_STATUS.DYING;
                 C_STATUS.DYING: status := C_STATUS.DEAD;
                 C_STATUS.DEAD: status := C_STATUS.STONED;
                 C_STATUS.STONED: status := C_STATUS.GONE;
               else
                 status := C_STATUS.OKAY;
               end;
               if status = C_STATUS.OKAY then begin
                 if hpCur = 0 then
                   hpCur := 1;
               end else
                 hpCur := 0;
               enabled := Ord(status in [C_STATUS.OKAY, C_STATUS.ANIMATED]);
             end;
      end;
  until key in ['E', C_Keys.NONE];
end;

{ Add a line to the Add list with its code, while there is room. }
procedure AddLine(var head, tail: Types.PItemRec; var codes: TCodes; var n: Byte; name: Types.TStr40; code: Word);
begin
  if n > MAX_LINES then Exit;
  MenuCore.AppendMenuLine(head, tail, name, code = 0);
  codes[n] := code;
  Inc(n);
end;

{ item's name as the inventory shows it, identified or not as its unidMask says, without the trailing space. }
function Named(item: Types.PItemRec): Types.TStr40;
begin
  CharHlp.ItemLabel(item, False);
  while (Length(item^.name) > 0) and (item^.name[Length(item^.name)] = ' ') do
    Dec(item^.name[0]);
  Named := item^.name;
end;

{ Make item the item of an Add list code: a weapon or armour (RandItem's, its plus then chosen), a magic item, or a
  scroll of rolled spells. }
procedure Make(code: Word; item: Types.PItemRec);
begin
  if code > TEMPLATE_CODE then begin
    RandItem.GenerateRandomItem(TEMPLATE_KINDS[code - TEMPLATE_CODE], item);
    RandItem.ApplyTemplate(item, code - TEMPLATE_CODE);
  end else
    RandItem.GenerateRandomItem(code, item);
end;

{ Choose a weapon's or armour's plus, 0 to PLUS_LAST from +1, with Left and Right, its name and value following; False
  when left with Exit. Bracers, named by their AC rather than their plus, choose AC 6, 4 or 2 the same way, from AC 6
  (#772). }
function ChoosePlus(item: Types.PItemRec): Boolean;
var
  pos: Byte;
  i: Byte;
  per: Word;
  key: Char;
  ext: Boolean;
  ac: Byte;

  procedure SetBracers;
  begin
    item^.plus := BRACERS_PLUS[ac];
    item^.nameIds[1] := BRACERS_NAME[ac];
    item^.value := Word(item^.plus) * BRACERS_GP;
  end;

begin
  ac := 1;
  if item^.itemType = C_ITEM.BRACERS then
    SetBracers;
  pos := 0;
  for i := 1 to 3 do
    if (item^.nameIds[i] > C_ITEM.NAME_PLUS_BASE) and (item^.nameIds[i] <= C_ITEM.NAME_PLUS_BASE + PLUS_LAST) then
      pos := i;
  per := 0;
  if item^.plus > 0 then
    per := item^.value div Word(item^.plus);
  { every choice starts at +1, whatever RandItem rolled }
  if pos <> 0 then begin
    item^.plus := 1;
    item^.nameIds[pos] := C_ITEM.NAME_PLUS_BASE + 1;
    item^.value := per;
  end;
  repeat
    Border.ClearBox(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
    TextRend.DisplayString(NAME_COL, LEVEL_ROW, White, Named(item));
    if pos <> 0 then
      TextRend.DisplayString(NAME_COL, LEVEL_ROW + 2, LightGreen, 'Left and Right change its plus.')
    else if item^.itemType = C_ITEM.BRACERS then
      TextRend.DisplayString(NAME_COL, LEVEL_ROW + 2, LightGreen, 'Left and Right change its AC.');
    MenuCore.arrowsToCaller := True;
    key := MenuCore.MenuHorizontal('Add: ', 'Take Exit', LightMagenta, LightGreen, White, True, False, ext);
    if ext and (pos <> 0) then begin
      if (key = C_Keys.LEFT) and (item^.plus > 0) then
        Dec(item^.plus);
      if (key = C_Keys.RIGHT) and (item^.plus < PLUS_LAST) then
        Inc(item^.plus);
      if item^.plus = 0 then
        item^.nameIds[pos] := 0
      else
        item^.nameIds[pos] := C_ITEM.NAME_PLUS_BASE + item^.plus;
      item^.value := per * Word(item^.plus);
    end else if ext and (item^.itemType = C_ITEM.BRACERS) then begin
      if (key = C_Keys.LEFT) and (ac > 1) then
        Dec(ac);
      if (key = C_Keys.RIGHT) and (ac < BRACERS_LAST) then
        Inc(ac);
      SetBracers;
    end;
  until (not ext) and (key in ['T', 'E', C_Keys.NONE]);
  ChoosePlus := key = 'T';
end;

{ The Add tool: a list of every weapon and armour RandItem makes, the magic items of its templates and the two scrolls;
  the one picked, identified, goes to curChar if it can carry it. }
procedure AddItem;
var
  head: Types.PItemRec;
  tail: Types.PItemRec;
  sel: Types.PItemRec;
  p: Types.PItemRec;
  item: Types.PItemRec;
  codes: TCodes;
  n: Byte;
  k: Byte;
  idx: Integer;
  redraw: Boolean;
  key: Char;
  code: Word;
  failed: Boolean;
begin
  GetMem(item, SizeOf(Types.TItemRec));
  head := nil;
  tail := nil;
  n := 0;
  AddLine(head, tail, codes, n, 'Weapons and armor', 0);
  for k := 1 to C_ITEM.RANDOM_ARMS_LAST do
    if k in C_ITEM.RANDOM_ARMS_KINDS then begin
      RandItem.GenerateRandomItem(k, item);
      if Named(item) <> '' then
        AddLine(head, tail, codes, n, Named(item), k);
    end;
  AddLine(head, tail, codes, n, 'Magic items', 0);
  for k := 1 to 19 do
    if TEMPLATE_KINDS[k] <> 0 then begin
      Make(TEMPLATE_CODE + k, item);
      item^.unidMask := 0;
      AddLine(head, tail, codes, n, Named(item), TEMPLATE_CODE + k);
    end;
  for k := C_ITEM.MAGE_SCROLL to C_ITEM.CLERIC_SCROLL do begin
    RandItem.GenerateRandomItem(k, item);
    AddLine(head, tail, codes, n, Named(item), k);
  end;
  idx := 0;
  redraw := True;
  sel := nil;
  Border.ClearBox(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
  key := MenuCore.MenuVertical('Add: ', 'Take', LightMagenta, LightGreen, White, 1, 1, 38, 22, head, True, redraw,
                               idx, sel);
  code := 0;
  if (key <> C_Keys.NONE) and (sel <> nil) then begin
    p := head;
    k := 0;
    while (p <> nil) and (p <> sel) do begin
      p := p^.next;
      Inc(k);
    end;
    if p <> nil then
      code := codes[k];
  end;
  MenuCore.FreeStringList(head);
  if code <> 0 then begin
    Make(code, item);
    item^.unidMask := 0;
    if (code > TEMPLATE_CODE) or (code = 61) or (code = 62) or ChoosePlus(item) then begin
      Shop.GiveItemCopyToCreature(item, failed);
      if failed then
        TextRend.PauseOnly;
    end;
  end;
  FreeMem(item, SizeOf(Types.TItemRec));
end;

{ The Money tool: a list of the seven coin types with curChar's count of each; the one picked takes a typed count. }
procedure MoneyTool;
var
  head: Types.PItemRec;
  tail: Types.PItemRec;
  sel: Types.PItemRec;
  p: Types.PItemRec;
  m: ShortInt;
  idx: Integer;
  redraw: Boolean;
  key: Char;
  s: Types.TStr40;
  count: LongInt;
  code: Integer;
begin
  idx := 0;
  repeat
    head := nil;
    tail := nil;
    for m := C_Money.COPPER to C_Money.JEWELRY do
      MenuCore.AppendMenuLine(head, tail, StrUtil.PadLeft(GDConsts.moneyNames[m], 8) + ' ' +
                              StrUtil.NumStr(GDVars.curChar^.coins[m]), False);
    redraw := True;
    sel := nil;
    key := MenuCore.MenuVertical('Money: ', 'Set', LightMagenta, LightGreen, White, 12, 7, 27, 13, head, True,
                                 redraw, idx, sel);
    m := -1;
    if (key <> C_Keys.NONE) and (sel <> nil) then begin
      m := C_Money.COPPER;
      p := head;
      while (p <> nil) and (p <> sel) do begin
        p := p^.next;
        Inc(m);
      end;
    end;
    MenuCore.FreeStringList(head);
    if m >= C_Money.COPPER then begin
      s := TextRend.ReadString(GDConsts.moneyNames[m] + ': ', LightGreen, 5);
      Val(s, count, code);
      if (code = 0) and (count >= 0) and (count <= 65535) then
        GDVars.curChar^.coins[m] := count;
      CharHlp.RecalcStats(Types.PCharRecord(GDVars.curChar));
    end;
  until m < C_Money.COPPER;
end;

{ The Gear tool, on the character sheet: Add an item, or set the Money. The Items menu drops what is not wanted. }
procedure GearTool;
var
  key: Char;
  ext: Boolean;
begin
  repeat
    ViewChar.DisplayChar(GDVars.curChar);
    key := MenuCore.MenuHorizontal('Gear: ', 'Add Money Exit', LightMagenta, LightGreen, White, False, False, ext);
    case key of
      'A': AddItem;
      'M': MoneyTool;
    end;
  until key in ['E', C_Keys.NONE];
end;

{ The spells of class cls (a spellTable castClass: 0 cleric, 1 magic-user) a character here can know, levels 1 to
  Types.CASTER_LEVEL_LAST, each marked * when curChar knows it; picking one learns or forgets it, until Exit. }
procedure SpellList(cls: Byte);
var
  head: Types.PItemRec;
  tail: Types.PItemRec;
  sel: Types.PItemRec;
  p: Types.PItemRec;
  spells: array[1..56] of Byte;
  n: Byte;
  m: Byte;
  k: Byte;
  idx: Integer;
  redraw: Boolean;
  key: Char;
  mark: string[2];
begin
  idx := 0;
  repeat
    head := nil;
    tail := nil;
    n := 0;
    for m := 1 to C_SPELL.LAST do
      with GDConsts.spellTable[m] do
        if (castClass = cls) and (levelSp >= 1) and (levelSp <= Types.CASTER_LEVEL_LAST) then begin
          mark := '  ';
          if GDVars.curChar^.spellsKnown[m] <> 0 then
            mark := '* ';
          MenuCore.AppendMenuLine(head, tail, mark + StrUtil.NumStr(levelSp) + ' ' + GDConsts.spellNames[m], False);
          Inc(n);
          spells[n] := m;
        end;
    redraw := True;
    sel := nil;
    Border.ClearBox(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
    key := MenuCore.MenuVertical('Known: ', 'Toggle', LightMagenta, LightGreen, White, 1, 1, 38, 22, head, True,
                                 redraw, idx, sel);
    k := 0;
    if (key <> C_Keys.NONE) and (sel <> nil) then begin
      p := head;
      k := 1;
      while (p <> nil) and (p <> sel) do begin
        p := p^.next;
        Inc(k);
      end;
      if p = nil then
        k := 0;
    end;
    MenuCore.FreeStringList(head);
    if k <> 0 then
      with GDVars.curChar^ do
        spellsKnown[spells[k]] := Ord(spellsKnown[spells[k]] = 0);
  until k = 0;
end;

{ The Magic tool: the magic-user's or the cleric's spells known. }
procedure MagicTool;
var
  key: Char;
  ext: Boolean;
begin
  repeat
    ViewChar.DisplayChar(GDVars.curChar);
    key := MenuCore.MenuHorizontal('Spells known: ', 'Mage Cleric Exit', LightMagenta, LightGreen, White, False,
                                   False, ext);
    case key of
      'M': SpellList(1);
      'C': SpellList(0);
    end;
  until key in ['E', C_Keys.NONE];
end;

procedure EditMenu;
var
  key: Char;
  ext: Boolean;
begin
  if GDVars.curChar = nil then Exit;
  repeat
    ViewChar.DisplayChar(GDVars.curChar);
    key := MenuCore.MenuHorizontal('', 'Abilities Levels Gear Magic Health Exit', LightMagenta, LightGreen, White,
                                   False, False, ext);
    if ext then begin
      if key in [C_Keys.HOME, C_Keys.END_KEY, C_Keys.UP, C_Keys.DOWN] then
        Party.SelectPrevNextChar(key);
    end else
      case key of
        'A': CharGen.ModifyCharacter(True);
        'L': LevelsTool;
        'G': GearTool;
        'M': MagicTool;
        'H': HealthTool;
      end;
  until (not ext) and (key in ['E', C_Keys.NONE]);
end;

end.

{ Character sheets, inventory actions, coin menus and spell-menu access. }
{$O+,F+}
{$I COMPILER.INC}
unit ViewChar;

interface

uses Types;

procedure DisplayChar(creature: Types.PCharRecord);

procedure PrintCombatStats;

procedure PrintStat(statIdx: ShortInt; modifying: Boolean);

procedure PrintMoney;

procedure ViewCharMenu(var done: Boolean);

procedure UseItemMenu(var done: Boolean);

function CannotCarryItem(creature: Types.PCharRecord; item: Types.PItemRec): Boolean;

implementation

uses Crt, C_Npc, GDConsts, GDVars, DaxIo, TextRend, Border, CharHlp, MenuCore, Portrait, CbtMap, Money, Magic, FxEngine,
  C_Effect, C_Equip, C_Keys, C_Class, C_Level, C_Status, C_Ifc, C_Abil, C_Money, C_Save, Vault, Stats, StrUtil,
  CharDisp, MoneyCal, C_Msg, ClassCal;

var
  { the last character traded to, offered first by the next trade; ViewCharMenu starts it at curChar }
  tradeTarget: Types.PCharRecord;

procedure ItemTradeMenu(item: Types.PItemRec); forward;

procedure HalveItem(item: Types.PItemRec); forward;

procedure JoinItem(item: Types.PItemRec); forward;

procedure SellItem(item: Types.PItemRec); forward;

procedure IdentifyItem(item: Types.PItemRec; var newInfo: Boolean); forward;

procedure TradeTreasureMenu; forward;

procedure DropMoneyMenu; forward;

{ What a shopkeeper or an item prompt says, in yellow on the bottom two rows (1, 21 to 38, 22). }
procedure SayBelow(clearFirst: Boolean; s: String);
begin
  TextRend.DisplayMessageWindow(1, 21, 38, 22, Yellow, clearFirst, s);
end;

{ Draw creature's character sheet; the portrait is curChar's (Portrait.DisplayCharPortrait), which every caller shows. }
procedure DisplayChar(creature: Types.PCharRecord);
var
  row: Byte;
  col: Byte;
  i: ShortInt;
  j: ShortInt;
  s: String;
  multi: Boolean;
begin
  TextRend.ClearScreen;
  Border.DrawBorder(C_Msg.TEXT_LEFT, C_Msg.TEXT_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, 0);
  CharDisp.DisplayCreatureName(creature, 1, 1, False);
  { C_Npc.FLAG set: not a party member }
  if CharHlp.IsNpc(creature) then
    TextRend.DisplayString(Length(creature^.name) + 3, 1, LightGreen, '(NPC)');
  col := 1;
  s := GDConsts.genderNames[creature^.genderIdx];
  TextRend.DisplayString(col, 3, White, s);
  col := col + Length(s) + 1;
  s := GDConsts.raceNames[creature^.race];
  TextRend.DisplayString(col, 3, White, s);
  col := col + Length(s) + 1;
  TextRend.DisplayString(col, 3, White, 'Age ' + StrUtil.NumStr(creature^.age));
  s := GDConsts.alignNames[creature^.alignmentIdx];
  TextRend.DisplayString(1, 4, White, s);
  s := GDConsts.classNames[creature^.charClass];
  TextRend.DisplayString(1, 5, White, s);
  { the six ability scores }
  for i := C_Abil.STRENGTH to C_Abil.CHARISMA do begin
    case i of
      C_Abil.STRENGTH: s := 'STR ';
      C_Abil.INTELLIGENCE: s := 'INT ';
      C_Abil.WISDOM: s := 'WIS ';
      C_Abil.DEXTERITY: s := 'DEX ';
      C_Abil.CONSTITUTION: s := 'CON ';
      C_Abil.CHARISMA: s := 'CHA ';
    end;
    TextRend.DisplayString(1, i + 7, LightGreen, s);
    ViewChar.PrintStat(i, False);
  end;
  ViewChar.PrintMoney;
  TextRend.DisplayString(1, 15, White, 'Level');
  multi := False;
  s := '';
  { one entry per class the character has levels in, joined with '/' }
  for j := C_Level.CLERIC to C_Level.MONK do
    if creature^.classLevels[j] > 0 then begin
      if multi then
        s := s + '/';
      s := s + StrUtil.NumStr(creature^.classLevels[j]);
      multi := True;
    end;
  TextRend.DisplayString(7, 15, White, s);
  TextRend.DisplayString(17, 15, White, 'Exp ' + StrUtil.NumStr(creature^.experience));
  ViewChar.PrintCombatStats;
  row := 20;
  if creature^.equipped[C_Equip.WEAPON] <> nil then begin
    TextRend.DisplayString(1, row, White, 'Weapon');
    CharDisp.PrintItemLabel(creature^.equipped[C_Equip.WEAPON], 8, row);
  end;
  Inc(row);
  if creature^.equipped[C_Equip.ARMOR] <> nil then begin
    { 'Armor' starts one column right of 'Weapon' so the two labels end in the same column }
    TextRend.DisplayString(2, row, White, 'Armor');
    CharDisp.PrintItemLabel(creature^.equipped[C_Equip.ARMOR], 8, row);
  end;
  Inc(row);
  TextRend.DisplayString(1, row, White, 'Status');
  TextRend.DisplayString(8, row, LightGreen, GDConsts.statusStrs[creature^.status]);
  if (GDVars.portraitsOn <> 0) and Portrait.PlayerPortraitsHere then
    Portrait.DisplayCharPortrait;
end;

{ Print nonzero coin holdings, highest type first: names right-aligned to end at column 19, amounts from column 21.
  Reads curChar. }
procedure PrintMoney;
var
  row: Byte;
  m: ShortInt;
  s: Types.TStr40;
begin
  Border.ClearBox(12, 7, 26, 14);
  row := 7;
  for m := C_Money.JEWELRY downto C_Money.COPPER do
    if GDVars.curChar^.coins[m] > 0 then begin
      s := GDConsts.moneyNames[m];
      TextRend.DisplayString(20 - Length(s), row, LightGreen, s);
      TextRend.DisplayString(21, row, LightGreen, StrUtil.NumStr(GDVars.curChar^.coins[m]));
      Inc(row);
    end;
end;

{ True when p is a paladin who can use a paladin's powers now: okay, and out of combat. }
function PaladinReady(p: Types.PCharRecord): Boolean;
begin
  PaladinReady := (p^.charClass = C_Class.PALADIN) and (p^.status = C_Status.OKAY) and
    (GDVars.ifcState <> C_Ifc.COMBAT);
end;

{ True when paladin p has not laid on hands in the last day. }
function CanHeal(p: Types.PCharRecord): Boolean;
var
  effect: Types.PEffectRec;
begin
  CanHeal := ViewChar.PaladinReady(p) and not CharHlp.HasEffect(p, C_Effect.RECENT_HEAL, effect);
end;

{ True when paladin p has a cure left this week: one a week, and one more for every five levels after the first. The
  week starts with the first cure (effect C_Effect.RECENT_CURE, whose strength counts the cures made). }
function CanCure(p: Types.PCharRecord): Boolean;
var
  effect: Types.PEffectRec;
  used: Byte;
  allowed: ShortInt;
begin
  used := 0;
  if CharHlp.HasEffect(p, C_Effect.RECENT_CURE, effect) then
    used := effect^.strength;
  allowed := (p^.classLevels[C_Level.PALADIN] - 1) div 5 + 1;
  CanCure := ViewChar.PaladinReady(p) and (allowed > 0) and (used < allowed);
end;

{ Lay on hands: paladin p restores 2 hit points per paladin level to the party member chosen, and cannot do so again
  for a day (C_Effect.RECENT_HEAL, 1440 minutes, at strength 255). Choosing Exit spends nothing. }
procedure LayOnHands(p: Types.PCharRecord);
var
  tgt: Types.PCharRecord;
  hpBefore: Byte;
begin
  CharDisp.DisplayNoncombatInterface;
  tgt := GDVars.creatureList;
  CharDisp.SelectChar('Heal whom? ', True, tgt);
  if tgt = nil then
    Exit;
  hpBefore := tgt^.hpCur;
  if FxEngine.RestoreHitPoints(tgt, p^.classLevels[C_Level.PALADIN] * 2, False) then begin
    Stats.Count(p, Stats.HEALED_GIVEN, tgt^.hpCur - hpBefore);
    CharDisp.PrintBottomLine(tgt^.name + ' feels better')
  end
  else
    CharDisp.PrintBottomLine(tgt^.name + ' is unaffected');
  FxEngine.AddEffect(p, C_Effect.RECENT_HEAL, 1440, 255, False);
end;

{ Cure disease: paladin p removes the disease effects (GDConsts.cureDiseaseEffects) from the party member chosen, asking
  first when there are none, and spends one of the week's cures: the first starts C_Effect.RECENT_CURE for 10080
  minutes at strength 1, later ones count up its strength. Choosing Exit, or No to the question, spends nothing. }
procedure CureDisease(p: Types.PCharRecord);
var
  tgt: Types.PCharRecord;
  effect: Types.PEffectRec;
  ch: Char;
begin
  CharDisp.DisplayNoncombatInterface;
  tgt := GDVars.creatureList;
  CharDisp.SelectChar('Cure whom? ', True, tgt);
  if tgt = nil then
    Exit;
  ch := 'Y';
  if not FxEngine.HasDisease(tgt) then begin
    CharDisp.PrintNameString(tgt, 'is not diseased', 0, False);
    ch := MenuCore.YesNoMenu('cure anyway: ', LightMagenta, LightGreen, White);
    CharDisp.ClearMessageWindow;
  end;
  if ch <> 'Y' then
    Exit;
  FxEngine.RemoveDiseases(tgt);
  if CharHlp.HasEffect(p, C_Effect.RECENT_CURE, effect) then
    Inc(effect^.strength)
  else
    FxEngine.AddEffect(p, C_Effect.RECENT_CURE, 10080, 1, False);
  CharDisp.PrintBottomLine(tgt^.name + ' is cured');
end;

type
  { the kinds a stats block holds, in the order the Kills page lists them }
  TKillOrder = array[1..Stats.KINDS] of Byte;

const
  { the Kill Count page: two columns of KILL_ROWS rows, an entry a column wide, a "(more)" row above and below }
  KILL_TOP = 6;
  KILL_ROWS = 15;
  KILL_COL_WIDTH = 18;
  KILLS_SHOWN = 2 * KILL_ROWS;
  { More Info's pages, in the order of its menu }
  PAGE_SAVES = 1;
  PAGE_STATS = 2;
  PAGE_KILLS = 3;
  PAGE_THIEF = 4;

{ Clear the screen, draw the border and centre creature's name in light cyan on row 2: the top of a More Info page. }
procedure MoreHeading(creature: Types.PCharRecord);
begin
  TextRend.ClearScreen;
  Border.DrawBorder(C_Msg.TEXT_LEFT, C_Msg.TEXT_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, 0);
  TextRend.DisplayCentered(C_Msg.TEXT_LEFT + 1, C_Msg.TEXT_RIGHT - 1, 2, LightCyan, creature^.name);
end;

{ A More Info page's top (MoreHeading) with title centred in white on row 4, under the name and a blank line. }
procedure MoreTitle(creature: Types.PCharRecord; title: Types.TStr40);
begin
  ViewChar.MoreHeading(creature);
  TextRend.DisplayCentered(C_Msg.TEXT_LEFT + 1, C_Msg.TEXT_RIGHT - 1, 4, White, title);
end;

{ The Game Stats page: the creature's twelve counters in this game, from row 6, coin in gold; b nil reads every
  counter as 0. }
procedure DrawGameStats(creature: Types.PCharRecord; b: Stats.PStatBlock);
var
  i: Byte;
  n: LongInt;
  s: Types.TStr40;
begin
  ViewChar.MoreTitle(creature, 'Game Stats');
  for i := 1 to Stats.STAT_COUNT do begin
    n := 0;
    if b <> nil then
      n := b^.counts[i];
    if i = Stats.COIN_LOOTED then
      n := n div GDConsts.dsCoinValuationCopper[C_Money.GOLD];
    Str(n, s);
    TextRend.DisplayString(3, 5 + i, White, Stats.NAMES[i]);
    TextRend.DisplayString(36 - Length(s), 5 + i, LightGreen, s);
  end;
end;

{ The Kill Count page from entry top of order (b's kinds, sorted by name): left then right along each row, each count
  right-aligned to the widest and its name after it, cut to fit the column, and "(more)" above or below when entries
  are hidden there. }
procedure DrawKills(creature: Types.PCharRecord; b: Stats.PStatBlock; var order: TKillOrder; kinds, top: Byte);
var
  i: Byte;
  k: Byte;
  width: Byte;
  s: Types.TStr40;
begin
  ViewChar.MoreTitle(creature, 'Kill Count');
  if kinds = 0 then begin
    TextRend.DisplayString(3, KILL_TOP, LightGreen, 'None');
    Exit;
  end;
  width := 1;
  for i := 1 to kinds do
    if Length(StrUtil.NumStr(b^.kills[i].count)) > width then
      width := Length(StrUtil.NumStr(b^.kills[i].count));
  if top > 1 then
    TextRend.DisplayCentered(1, 38, KILL_TOP - 1, White, '(more)');
  for k := 0 to KILLS_SHOWN - 1 do
    if top + k <= kinds then begin
      i := order[top + k];
      s := StrUtil.PadLeft(StrUtil.NumStr(b^.kills[i].count), width) + ' ' +
           Copy(b^.kills[i].name, 1, KILL_COL_WIDTH - 2 - width);
      TextRend.DisplayString(2 + (k mod 2) * KILL_COL_WIDTH, KILL_TOP + k div 2, LightGreen, s);
    end;
  if top + KILLS_SHOWN <= kinds then
    TextRend.DisplayCentered(1, 38, KILL_TOP + KILL_ROWS, White, '(more)');
end;

{ creature's statistics block (#611, #672), made the first time, and the kinds it has killed in alphabetical order. }
procedure ReadStats(creature: Types.PCharRecord; var b: Stats.PStatBlock; var order: TKillOrder; var kinds: Byte);
var
  i: Byte;
  j: Byte;
  t: Byte;
begin
  { a creature outside the party has no block: its counters read 0 }
  b := Stats.BlockOf(creature);
  kinds := 0;
  if b <> nil then
    kinds := b^.kindCount;
  for i := 1 to kinds do
    order[i] := i;
  for i := 1 to kinds do
    for j := i + 1 to kinds do
      if b^.kills[order[j]].name < b^.kills[order[i]].name then begin
        t := order[i];
        order[i] := order[j];
        order[j] := t;
      end;
end;

{ The Saves page: the five saving throws from row 6, under its title as on the other pages, each the d20 roll needed
  (saves[] less saveBonus, held to 2..20 since a 1 always fails and a 20 always succeeds). Situational bonuses, such as
  a dwarf's or halfling's against magic and poison, apply only at the roll and are not included. The names are
  literals, in the overlay, rather than a typed constant in the data segment. }
procedure DrawSaves(p: Types.PCharRecord);
var
  i: ShortInt;
  need: Integer;
  s: Types.TStr40;
begin
  ViewChar.MoreTitle(p, 'Saving Throws');
  for i := C_Save.PARALYZE to C_Save.SPELL do begin
    case i of
      C_Save.PARALYZE: s := 'Paralysis, Poison, Death';
      C_Save.PETRIFY: s := 'Petrification, Polymorph';
      C_Save.WAND: s := 'Rod, Staff, Wand';
      C_Save.BREATH: s := 'Breath Weapon';
    else
      s := 'Spell';
    end;
    TextRend.DisplayString(2, 6 + i, LightGreen, s);
    need := p^.saves[i] - p^.saveBonus;
    if need < 2 then
      need := 2;
    if need > 20 then
      need := 20;
    s := StrUtil.NumStr(need);
    TextRend.DisplayString(32 - Length(s), 6 + i, White, s);
  end;
end;

{ n signed, its digits padded to two: '+ 0', '-15', '+40', '+103'. }
function SignedNum(n: Integer): Types.TStr40;
var
  s: Types.TStr40;
begin
  s := StrUtil.NumStr(Abs(n));
  if Length(s) < 2 then
    s := ' ' + s;
  if n < 0 then
    s := '-' + s
  else
    s := '+' + s;
  SignedNum := s;
end;

{ The Thief page (#685): each thief skill's name, then its racial and Dexterity adjustments and its base for the thief
  level (ClassCal.ThiefSkillParts), and the total the game uses (thiefSkills), which is stopped at 0 and so need not be
  the sum of the three. All are percentages, shown without the sign, which the game's font does not have. The window
  has 36 columns where the design has 44: the names start at column 2 and the headings fill 18..37, one space apart,
  each figure right-aligned under its heading. }
procedure DrawThief(p: Types.PCharRecord);
var
  j: Byte;
  base: ShortInt;
  racial: ShortInt;
  dexterity: ShortInt;
  s: Types.TStr40;
begin
  ViewChar.MoreHeading(p);
  TextRend.DisplayString(18, 4, White, 'Race Dex Level Total');
  { 8 = High(thiefSkills) }
  for j := 1 to 8 do begin
    case j of
      1: s := 'Pick Pockets';
      2: s := 'Open Lock';
      3: s := 'Find Traps';
      4: s := 'Move Silently';
      5: s := 'Hide in Shadows';
      6: s := 'Hear Noise';
      7: s := 'Climb Walls';
    else
      s := 'Read Languages';
    end;
    TextRend.DisplayString(2, 4 + j, LightGreen, s);
    ClassCal.ThiefSkillParts(p, j, base, racial, dexterity);
    { the adjustments and the base are three characters wide; a total can be four }
    TextRend.DisplayString(19, 4 + j, White, ViewChar.SignedNum(racial));
    TextRend.DisplayString(23, 4 + j, White, ViewChar.SignedNum(dexterity));
    TextRend.DisplayString(29, 4 + j, White, ViewChar.SignedNum(base));
    s := ViewChar.SignedNum(p^.thiefSkills[j]);
    TextRend.DisplayString(38 - Length(s), 4 + j, White, s);
  end;
end;

{ The More Info page for the current character (#592, #685): its bottom line, More Info: Saves sTats Kills tHief Exit,
  turns its pages, Saves (where it opens), Game Stats, Kill Count and, only for a character with thief levels, Thief.
  On Kill Count, Up and Down scroll the list a row (two entries) at a time and Page Up and Page Down a page. The
  statistics block is read when Stats or Kills is first chosen, since reading it makes one for the character, which a
  save then writes. Exit or Escape returns to the character sheet, which the caller redraws. }
procedure MorePage;
var
  p: Types.PCharRecord;
  menu: Types.TStr40;
  page: Byte;
  b: Stats.PStatBlock;
  kinds: Byte;
  order: TKillOrder;
  haveStats: Boolean;
  top: Integer;
  ch: Char;
  ext: Boolean;
begin
  p := GDVars.curChar;
  CharHlp.RecalcStats(p);
  menu := 'Saves sTats Kills';
  if p^.classLevels[C_Level.THIEF] > 0 then
    menu := menu + ' tHief';
  menu := menu + ' Exit';
  page := PAGE_SAVES;
  haveStats := False;
  top := 1;
  GDVars.horizChoice := 1;
  repeat
    case page of
      PAGE_STATS: ViewChar.DrawGameStats(p, b);
      PAGE_KILLS: ViewChar.DrawKills(p, b, order, kinds, top);
      PAGE_THIEF: ViewChar.DrawThief(p);
    else
      ViewChar.DrawSaves(p);
    end;
    ch := MenuCore.MenuHorizontal('More Info: ', menu, LightMagenta, LightGreen, White, True, False, ext);
    if ext then begin
      if page = PAGE_KILLS then
        case ch of
          C_Keys.UP: if top > 1 then
                       Dec(top, 2);
          C_Keys.DOWN: if top + KILLS_SHOWN <= kinds then
                         Inc(top, 2);
          C_Keys.PGUP: begin
                         Dec(top, KILLS_SHOWN);
                         if top < 1 then
                           top := 1;
                       end;
          C_Keys.PGDN: if top + KILLS_SHOWN <= kinds then
                         Inc(top, KILLS_SHOWN);
        end;
    end else
      case ch of
        'S': page := PAGE_SAVES;
        'H': page := PAGE_THIEF;
        'T', 'K': begin
               if not haveStats then
                 ViewChar.ReadStats(p, b, order, kinds);
               haveStats := True;
               if ch = 'T' then
                 page := PAGE_STATS
               else begin
                 page := PAGE_KILLS;
                 top := 1;
               end;
             end;
      end;
  until (not ext) and (ch in [C_Keys.NONE, 'E']);
end;

{ Draw "More Info" under the character sheet's portrait frame (columns 28..38, rows 1..11), the M in white as a hotkey
  is and the rest in light green. ViewCharMenu takes M through MenuCore.extraKeys. The rows below the frame hold nothing
  else, so it is drawn whether or not a portrait is shown. }
procedure DrawMoreInfoLabel;
begin
  TextRend.DisplayString(29, 13, White, 'M');
  TextRend.DisplayString(30, 13, LightGreen, 'ore Info');
end;

{ Recalculate curChar's stats, then display armor class, hit points, THAC0 (60 - thac0Cur), damage, encumbrance and
  movement (halved when Slowed, doubled when Hasted). }
procedure PrintCombatStats;
var
  p: Types.PCharRecord;
  row: Byte;
  col: Byte;
  mv: Byte;
  s: Types.TStr40;
  effect: Types.PEffectRec;
begin
  p := GDVars.curChar;
  CharHlp.RecalcStats(p);
  row := 17;
  TextRend.DisplayString(1, row, White, 'AC    ');
  CharDisp.PrintArmorClass(p, 4, row);
  TextRend.DisplayString(1, row + 1, White, 'HP    ');
  CharDisp.PrintHitPoints(p, 4, row + 1, False);
  col := 8;
  TextRend.DisplayString(col + 1, row, White, 'THAC0   ');
  TextRend.DisplayString(col + 7, row, LightGreen, StrUtil.NumStr(60 - p^.thac0Cur));
  s := StrUtil.NumStr(p^.curRollsA[1]) + 'd' + StrUtil.NumStr(p^.curDiceA[1]);
  if p^.curModA[1] > 0 then
    s := s + '+' + StrUtil.NumStr(p^.curModA[1]);
  if p^.curModA[1] < 0 then
    s := s + '-' + StrUtil.NumStr(Abs(p^.curModA[1]));
  TextRend.DisplayString(col, row + 1, White, 'Damage        ');
  TextRend.DisplayString(col + 7, row + 1, LightGreen, s);
  col := 22;
  TextRend.DisplayString(col, row, White, 'Encumbrance      ');
  TextRend.DisplayString(col + 12, row, LightGreen, StrUtil.NumStr(p^.encumbrance));
  mv := p^.movementCur;
  if CharHlp.HasEffect(p, C_Effect.SLOWED, effect) then
    mv := mv div 2;
  if CharHlp.HasEffect(p, C_Effect.HASTED, effect) then
    mv := mv * 2;
  TextRend.DisplayString(col + 3, row + 1, White, 'Movement   ');
  TextRend.DisplayString(col + 12, row + 1, LightGreen, StrUtil.NumStr(mv));
end;

{ Print stat statIdx (0..5) of curChar in light green, or light magenta while modifying. Strength 18 with exceptional
  strength adds '(xx)', zero-padded, with 100 shown as 00. }
procedure PrintStat(statIdx: ShortInt; modifying: Boolean);
var
  s: Types.TStr40;
  col: Byte;
  hlCol: Byte;
begin
  if modifying then
    hlCol := LightMagenta
  else
    hlCol := LightGreen;
  col := 5;
  Border.ClearBox(col, statIdx + 7, 11, statIdx + 7);
  if GDVars.curChar^.stats[statIdx] < 10 then
    Inc(col);
  TextRend.DisplayString(col, statIdx + 7, hlCol, StrUtil.NumStr(GDVars.curChar^.stats[statIdx]));
  if (statIdx = C_Abil.STRENGTH) and (GDVars.curChar^.strCur = 18) and (GDVars.curChar^.strExc > 0) then begin
    { 100 shows as 00 }
    s := StrUtil.ZeroPad2(GDVars.curChar^.strExc);
    TextRend.DisplayString(7, 7, hlCol, '(' + s + ')');
  end;
end;

{ Run the character-sheet menu for items, spells, trading and dropping money, a paladin's Heal (lay on hands) and Cure
  (cure disease) while each can be used, and the More Info page (M, shown under the portrait rather than on the menu
  line, which has no room for it), until Escape, Exit or done. The menu line has no prompt, as in Curse: with one, a
  paladin holding items and money would not fit. Temporarily use the noncombat palette when opened during combat. }
procedure ViewCharMenu(var done: Boolean);
var
  ch: Char;
  s: Types.TStr40;
  hasMoney: Boolean;
  hasSpells: Boolean;
  ext: Boolean;
  i: Byte;
  j: ShortInt;
  idx: Integer;
  shown: Types.PCharRecord;
begin
  if GDVars.ifcState = C_Ifc.COMBAT then
    CbtMap.SetNoncombatPalette;
  ch := ' ';
  done := False;
  tradeTarget := GDVars.curChar;
  shown := GDVars.curChar;
  ViewChar.DisplayChar(shown);
  ViewChar.DrawMoreInfoLabel;
  while not (ch in [C_Keys.NONE, 'E']) and not done do
  begin
    s := '';
    hasSpells := False;
    hasMoney := False;
    { every memorized-spell slot }
    for i := 0 to Types.SPELL_SLOT_LAST do
      if shown^.memorizedSpells[i] > 0 then
        hasSpells := True;
    { every coin type, gems and jewelry included }
    for j := C_Money.COPPER to C_Money.JEWELRY do
      if shown^.coins[j] > 0 then
        hasMoney := True;
    if shown^.itemsAddr <> nil then
      s := s + 'Items ';
    if hasSpells then
      s := s + 'Spells ';
    if CharHlp.MayTrade(shown) and hasMoney and
        (GDVars.ifcState <> C_Ifc.COMBAT) then
      s := s + 'Trade ';
    { in the vault, dropped money is deposited there (Money.DropMoney) }
    if hasMoney and (GDVars.ifcState = C_Ifc.VAULT) then
      s := s + 'Deposit '
    else if hasMoney then
      s := s + 'Drop ';
    if ViewChar.CanHeal(shown) then
      s := s + 'Heal ';
    if ViewChar.CanCure(shown) then
      s := s + 'Cure ';
    s := s + 'Exit';
    MenuCore.extraKeys := 'M';
    ch := MenuCore.MenuHorizontal('', s, LightMagenta, LightGreen, White, False, False, ext);
    idx := -1;
    case ch of
      'I': ViewChar.UseItemMenu(done);
      'S': i := Magic.SpellMenu(0, 0, idx, hasSpells);
      'T': ViewChar.TradeTreasureMenu;
      'D': begin
             ViewChar.DropMoneyMenu;
             ViewChar.PrintMoney;
           end;
      'H': if ViewChar.CanHeal(shown) then
             ViewChar.LayOnHands(shown);
      'C': if ViewChar.CanCure(shown) then
             ViewChar.CureDisease(shown);
      'M': ViewChar.MorePage;
    end;
    if not done and (ch in ['I', 'S', 'T', 'H', 'C', 'M']) then begin
      shown := GDVars.curChar;
      ViewChar.DisplayChar(shown);
      ViewChar.DrawMoreInfoLabel;
    end;
  end;
  if GDVars.ifcState = C_Ifc.COMBAT then
    CbtMap.SetCombatPalette;
  CharDisp.DisplayNoncombatInterface;
end;

{ True when the item may leave curChar's inventory. Equipped items must be unreadied first. If a scroll has pending
  scribing (charges, effect or special above $7F), ask before discarding that work. }
function CheckItemAvail(item: Types.PItemRec): Boolean;
begin
  CheckItemAvail := False;
  if item^.equipped <> 0 then
    CharDisp.PrintBottomLine('Must be unreadied')
  else if not CharHlp.ItemReadable(item) then
    CheckItemAvail := True
  else if (item^.charges > $7F) or (item^.effect > $7F) or (item^.special > $7F) then begin
    CharDisp.DisplayCreatureName(GDVars.curChar, 1, 21, False);
    GDVars.curCol := Length(GDVars.curChar^.name) + 2;
    GDVars.curRow := 21;
    ViewChar.SayBelow(False, ' was going to scribe from that scroll');
    if MenuCore.YesNoMenu('is it Okay to lose it? ', LightMagenta, LightGreen, White) = 'Y' then
      CheckItemAvail := True;
  end else
    CheckItemAvail := True;
  Border.ClearBox(1, 21, 38, 22);
end;

{ Run curChar's inventory menu, offering actions according to the character's state and the current interface state,
  until Escape, done, or no items remain. }
{ STING's raw item viewer (V in the Items menu, #612), Curse's ViewItemDetail: the item's type, name ids, plus, save
  bonus, ready, identified mask, cursed, value, charges, effect and special, and its base type's large-creature damage
  dice, until a key. The caller redraws the screen. }
procedure ViewItemDetail(it: Types.PItemRec);
const
  labels: array[1..15] of string[13] = ('itemtype:', 'namenum(1):', 'namenum(2):', 'namenum(3):', 'plus:',
    'plussave:', 'ready:', 'identified:', 'cursed:', 'value:', 'charges:', 'effect:', 'special:', 'dice large:',
    'sides large:');
var
  v: array[1..15] of LongInt;
  i: Byte;
  s: Types.TStr40;
begin
  with it^ do begin
    v[1] := itemType;
    v[2] := nameIds[1];
    v[3] := nameIds[2];
    v[4] := nameIds[3];
    v[5] := Byte(plus);
    v[6] := Byte(saveBonus);
    v[7] := equipped;
    v[8] := unidMask;
    v[9] := cursed;
    v[10] := value;
    v[11] := charges;
    v[12] := effect;
    v[13] := special;
    v[14] := CharHlp.BaseItem(itemType)^.dmgLgRolls;
    v[15] := CharHlp.BaseItem(itemType)^.dmgLgDice;
  end;
  TextRend.ClearScreen;
  Border.DrawBorder(C_Msg.TEXT_LEFT, C_Msg.TEXT_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, 0);
  for i := 1 to 15 do begin
    Str(v[i], s);
    TextRend.DisplayString(2, i + 1, LightGreen, labels[i]);
    TextRend.DisplayString(20, i + 1, LightGreen, s);
  end;
  TextRend.DisplayAndPause(LightGreen, 'press a key');
end;

procedure UseItemMenu(var done: Boolean);
var
  ch: Char;
  s: Types.TStr40;
  needRedraw: Boolean;
  vmRedraw: Boolean;
  p: Types.PItemRec;
  sel: Types.PItemRec;
  idx: Integer;
  creature: Types.PCharRecord;
  itemCount: Byte;
begin
  creature := GDVars.curChar;
  ch := ' ';
  sel := creature^.itemsAddr;
  idx := 0;
  vmRedraw := True;
  needRedraw := True;
  { the list as well as the count: a stale count over a nil list would never leave the loop }
  while not (ch in [C_Keys.NONE, 'E']) and not done and (creature^.numberOfItems > 0) and
      (creature^.itemsAddr <> nil) do begin
    itemCount := creature^.numberOfItems;
    if creature^.itemsAddr <> nil then begin
      s := 'Ready';
      if CharHlp.CanUseItems(creature) then
        s := s + ' Use';
      if CharHlp.MayTrade(creature) and (GDVars.ifcState <> C_Ifc.COMBAT) then
        s := s + ' Trade';
      if GDVars.ifcState = C_Ifc.VAULT then
        s := s + ' Deposit'
      else
        s := s + ' Drop';
      if creature^.numberOfItems < 16 then
        s := s + ' Halve';
      s := s + ' Join';
      { the characters that may trade may sell, but only in a shop }
      if CharHlp.MayTrade(creature) and (GDVars.ifcState = C_Ifc.SHOP_TEMPLE) then
        s := s + ' Sell';
      if GDVars.ifcState = C_Ifc.SHOP_TEMPLE then
        s := s + ' Id';
      { rebuild every item name }
      p := creature^.itemsAddr;
      while p <> nil do begin
        CharHlp.ItemLabel(p, True);
        p := p^.next;
      end;
      if needRedraw or (GDVars.dsRedrawInventoryMenuFlag <> 0) then begin
        TextRend.ClearScreen;
        Border.DrawBorder(C_Msg.TEXT_LEFT, C_Msg.TEXT_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, 0);
        CharDisp.DisplayCreatureName(creature, 1, 1, True);
        TextRend.DisplayString(Length(creature^.name) + 4, 1, LightGreen, 'Items');
        Border.DrawWindow(1, 3, 38, 22, 0, Black, '');
        TextRend.DisplayString(1, 3, White, 'Ready Item');
        vmRedraw := True;
        needRedraw := False;
        GDVars.dsRedrawInventoryMenuFlag := 0;
      end;
      { STING: V, not on the menu line, shows the selected item's raw record, as Curse's debug mode does }
      if GDVars.stingArg then
        MenuCore.extraKeys := 'V';
      ch := MenuCore.MenuVertical('', s, LightMagenta, LightGreen, White, 1, 5, 38, 22,
                                  creature^.itemsAddr, True, vmRedraw, idx, sel);
      if sel <> nil then
        case ch of
          'V': if GDVars.stingArg then begin
                 ViewChar.ViewItemDetail(sel);
                 needRedraw := True;
               end;
          'R': FxEngine.ToggleReadyItem(sel);
          { a scroll the Cast list offers (CharHlp.CastableScroll) need not be readied; other items must be }
          'U': if (sel^.equipped = 0) and not CharHlp.CastableScroll(creature, sel) then
               begin
                 CharDisp.PrintBottomLine('Must be Readied');
                 ch := ' ';
               end else if CharHlp.ItemReadable(sel) or ((sel^.effect > 0) and (sel^.special < $80)) then begin
                 Magic.UseItem(sel, done);
                 if GDVars.ifcState <> C_Ifc.COMBAT then
                   { outside combat, using an item does not end the menu }
                   done := False;
                 if not done then
                   needRedraw := True;
               end;
          'T': begin
                 if ViewChar.CheckItemAvail(sel) then
                   ViewChar.ItemTradeMenu(sel)
                 else
                   ch := ' ';
                 needRedraw := True;
               end;
          'D': if (GDVars.ifcState = C_Ifc.VAULT) and ViewChar.CheckItemAvail(sel) then begin
                 { the vault keeps it, with the game it is saved with }
                 if Vault.HasRoom then begin
                   Vault.DepositItem(GDVars.curChar, sel);
                   vmRedraw := True;
                 end else
                   TextRend.DisplayAndPause(Yellow, 'The vault is full.');
               end else if ViewChar.CheckItemAvail(sel) then
               begin
                 { the item label ends in a space }
                 CharHlp.ItemLabel(sel, False);
                 ViewChar.SayBelow(True, 'Your ' + sel^.name + 'will be gone forever');
                 if MenuCore.YesNoMenu('Drop It? ', LightMagenta, LightGreen, White) = 'Y' then
                 begin
                   CharHlp.RemoveItem(GDVars.curChar, sel);
                   vmRedraw := True;
                 end;
                 Border.ClearBox(1, 21, 38, 22);
               end else
                 ch := ' ';
          'H': ViewChar.HalveItem(sel);
          'J': ViewChar.JoinItem(sel);
          'S': if ViewChar.CheckItemAvail(sel) then
                 ViewChar.SellItem(sel)
               else
                 ch := ' ';
          'I': ViewChar.IdentifyItem(sel, vmRedraw);
        end;
      CharHlp.RecalcStats(creature);
    end;
    if creature^.numberOfItems <> itemCount then
      vmRedraw := True;
  end;
end;

{ Select a trade recipient, check carrying capacity, then copy the item to the recipient and remove it from curChar. }
procedure ItemTradeMenu(item: Types.PItemRec);
var
  tgt: Types.PCharRecord;
begin
  tgt := tradeTarget;
  CharDisp.DisplayNoncombatInterface;
  CharDisp.SelectChar('Trade with Whom?', True, tgt);
  if tgt <> nil then begin
    tradeTarget := tgt;
    if ViewChar.CannotCarryItem(tgt, item) then
      CharDisp.PrintBottomLine('Overloaded')
    else begin
      CharHlp.AppendItemCopy(tgt^.itemsAddr, item);
      CharHlp.RemoveItem(GDVars.curChar, item);
      CharHlp.RecalcStats(tgt);
    end;
  end;
end;

{ Split an item stack: a copy holding half the quantity (rounded down), unreadied, is linked in right after the
  original, which keeps the rest. }
procedure HalveItem(item: Types.PItemRec);
var
  newIt: Types.PItemRec;
  half: Byte;
  remainder: Byte;
begin
  half := item^.quantity div 2;
  if half > 0 then begin
    remainder := item^.quantity - half;
    GetMem(newIt, SizeOf(Types.TItemRec));
    Move(item^, newIt^, SizeOf(Types.TItemRec));
    newIt^.quantity := half;
    newIt^.equipped := 0;
    newIt^.next := item^.next;
    item^.quantity := remainder;
    item^.next := newIt;
  end else
    CharDisp.PrintBottomLine('Can''t halve that');
end;

{ Merge into item every other stack (quantity > 0) of curChar's with the same name components, type, plus, save bonus,
  curse, weight, charges, effect and special, and fewer than 2 charges. Save the next node before merging, since
  RemoveItem frees the current node. If the total would exceed 255, fill the destination to 255, keep the excess in the
  current stack, and continue merging into that stack. A readied stack merged away leaves the stack it joins readied:
  the two are the same item type, so the slot and hands it held pass over, and no more stacks end up readied than
  before. An unstacked item (quantity 0) is left alone: merging into it would start the count at 0 and lose the item
  itself. }
procedure JoinItem(item: Types.PItemRec);
var
  cur: Types.PItemRec;
  next: Types.PItemRec;
  dst: Types.PItemRec;
  qty: Byte;
begin
  if item^.quantity = 0 then Exit;
  dst := item;
  qty := dst^.quantity;
  cur := GDVars.curChar^.itemsAddr;
  while cur <> nil do begin
    next := cur^.next;
    if (cur <> dst) and (cur^.quantity > 0) and (cur^.nameIds[1] = dst^.nameIds[1]) and
        (cur^.nameIds[2] = dst^.nameIds[2]) and (cur^.nameIds[3] = dst^.nameIds[3]) and
        (cur^.itemType = dst^.itemType) and (cur^.plus = dst^.plus) and (cur^.saveBonus = dst^.saveBonus) and
        (cur^.cursed = dst^.cursed) and (cur^.weight = dst^.weight) and (cur^.charges = dst^.charges) and
        (cur^.charges < 2) and (cur^.effect = dst^.effect) and (cur^.special = dst^.special) then begin
      if qty + cur^.quantity <= 255 then begin
        Inc(qty, cur^.quantity);
        if cur^.equipped <> 0 then
          dst^.equipped := cur^.equipped;
        CharHlp.RemoveItem(GDVars.curChar, cur);
      end else begin
        dst^.quantity := 255;
        cur^.quantity := cur^.quantity - (255 - qty);
        qty := cur^.quantity;
        dst := cur;
      end;
    end;
    cur := next;
  end;
  dst^.quantity := qty;
end;

{ Offer MoneyCal.ItemSalePrice for the item: half what it is worth, with ammunition valued per bundle of 20 at any
  quantity, so a single arrow fetches a twentieth of a bundle's price. Pay as platinum (price div 5) plus gold (price
  mod 5); when overloaded, the platinum the character cannot take goes to the treasure pool. }
procedure SellItem(item: Types.PItemRec);
var
  price: Word;
  plat: Word;
  gold: Word;
  takable: Word;
begin
  price := MoneyCal.ItemSalePrice(item);
  CharHlp.ItemLabel(item, False);
  ViewChar.SayBelow(True, 'I''ll give you ' + StrUtil.NumStr(price) + ' gold pieces for your ' + item^.name);
  if MenuCore.YesNoMenu('Is It a Deal? ', LightMagenta, LightGreen, White) = 'Y' then
  begin
    CharDisp.PrintBottomLine('Sold!');
    CharHlp.RemoveItem(GDVars.curChar, item);
    plat := price div 5;
    gold := price mod 5;
    if Money.CheckOverload(GDVars.curChar, gold + plat, takable) then begin
      CharDisp.PrintBottomLine('Overloaded.  Money will be put in pool.');
      if takable > plat then
        Inc(GDVars.curChar^.coins[C_Money.PLATINUM], plat)
      else begin
        Inc(GDVars.curChar^.coins[C_Money.PLATINUM], takable);
        Inc(GDVars.treasureMoney[C_Money.PLATINUM], plat - takable);
      end;
      { added even when overloaded }
      Inc(GDVars.curChar^.coins[C_Money.GOLD], gold);
    end else begin
      Inc(GDVars.curChar^.coins[C_Money.PLATINUM], plat);
      Inc(GDVars.curChar^.coins[C_Money.GOLD], gold);
    end;
  end;
  Border.ClearBox(1, 21, 38, 22);
end;

{ Identify an item for 200 gold, paid from the character's coins if they are worth enough (converting them to platinum
  and gold), else from the treasure pool. newInfo is set, never cleared, when identification reveals new information. }
procedure IdentifyItem(item: Types.PItemRec; var newInfo: Boolean);
var
  paid: Boolean;
begin
  paid := False;
  CharHlp.ItemLabel(item, False);
  ViewChar.SayBelow(True, 'For 200 gold pieces I''ll identify your ' + item^.name);
  if MenuCore.YesNoMenu('Is It a Deal? ', LightMagenta, LightGreen, White) = 'Y' then
  begin
    paid := Money.PayGold(GDVars.curChar, 200);
  end;
  if paid then begin
    if item^.unidMask = 0 then
      ViewChar.SayBelow(True, 'I can''t tell anything new about your ' + item^.name)
    else begin
      item^.unidMask := 0;
      CharHlp.ItemLabel(item, False);
      ViewChar.SayBelow(True, 'It looks like some sort of ' + item^.name);
      newInfo := True;
    end;
  end;
  if paid then
    TextRend.PauseOnly;
  Border.ClearBox(1, 21, 38, 22);
end;

{ Show the current character's coins as a menu (one line per type it holds: the name right-aligned in 8 columns and
  the count, jewelry first) and return the line picked, or nil on Escape. list receives the menu list, for
  MenuCore.FreeStringList (nil when there is no coin). }
function PickCoinType(var list: Types.PItemRec): Types.PItemRec;
var
  m: ShortInt;
  p: Types.PItemRec;
  prev: Types.PItemRec;
  idx: Integer;
  redraw: Boolean;
  ch: Char;
begin
  p := nil;
  for m := C_Money.COPPER to C_Money.JEWELRY do
    if GDVars.curChar^.coins[m] <> 0 then begin
      { a menu-list node: only the name, inUse and next fields of a TItemRec }
      prev := p;
      GetMem(p, SizeOf(Types.TMenuNode));
      p^.next := prev;
      p^.name := StrUtil.PadLeft(GDConsts.moneyNames[m], 8) + ' ' + StrUtil.NumStr(GDVars.curChar^.coins[m]);
      p^.inUse := 0;
    end;
  list := p;
  prev := nil;
  idx := 0;
  redraw := True;
  ch := MenuCore.MenuVertical('Select type of coin', '', LightMagenta, LightGreen, White, 12, 7, 25, 13, p, True,
                              redraw, idx, prev);
  PickCoinType := prev;
end;

{ Trade coins from curChar to another character. The outer loop picks the recipient, starting from tradeTarget; the
  inner loop lists curChar's nonzero coin types (linked backwards, so the highest type heads the list), lets the player
  pick a type and an amount up to the holding, and hands it over with Money.TradeMoney, repeating while coins remain.
  Escaping the coin menu goes back to choosing the recipient. }
procedure TradeTreasureMenu;
var
  tgt: Types.PCharRecord;
  m: ShortInt;
  mType: ShortInt;
  prev: Types.PItemRec;
  list: Types.PItemRec;
  s2: String;
  amount: Word;
  exitOuter: Boolean;
  exitInner: Boolean;
  redraw: Boolean;
begin
  repeat
    tgt := tradeTarget;
    CharDisp.DisplayNoncombatInterface;
    CharDisp.SelectChar('Trade to?', True, tgt);
    if tgt = nil then
      exitOuter := True
    else begin
      ViewChar.DisplayChar(GDVars.curChar);
      repeat
        ViewChar.PrintMoney;
        tradeTarget := tgt;
        prev := ViewChar.PickCoinType(list);
        if prev = nil then begin
          exitInner := True;
          exitOuter := False;
        end else begin
          s2 := '';
          mType := MoneyCal.ParseMoneyType(prev^.name, s2);
          s2 := 'How much ' + s2 + 'will you trade? ';
          amount := Money.InputNumberMax(GDVars.curChar^.coins[mType], s2, 10);
          Money.TradeMoney(GDVars.curChar, tgt, amount, mType);
          exitInner := True;
          exitOuter := True;
          for m := C_Money.COPPER to C_Money.JEWELRY do
            if GDVars.curChar^.coins[m] > 0 then begin
              exitOuter := False;
              exitInner := False;
            end;
        end;
        if list <> nil then
          MenuCore.FreeStringList(list);
      until exitInner;
    end;
  until exitOuter;
end;

{ Choose a coin type and amount to drop from the character's holdings, repeating until Escape or no coins remain. }
procedure DropMoneyMenu;
var
  m: ShortInt;
  mType: ShortInt;
  prev: Types.PItemRec;
  list: Types.PItemRec;
  exitFlag: Boolean;
  s2: String;
  amount: Word;
begin
  repeat
    ViewChar.PrintMoney;
    prev := ViewChar.PickCoinType(list);
    if prev = nil then
      exitFlag := True
    else begin
      s2 := '';
      mType := MoneyCal.ParseMoneyType(prev^.name, s2);
      if GDVars.ifcState = C_Ifc.VAULT then
        s2 := 'How much ' + s2 + 'will you deposit? '
      else
        s2 := 'How much ' + s2 + 'will you drop? ';
      amount := Money.InputNumberMax(GDVars.curChar^.coins[mType], s2, 10);
      Money.DropMoney(GDVars.curChar, amount, mType);
      exitFlag := True;
      for m := C_Money.COPPER to C_Money.JEWELRY do
        if GDVars.curChar^.coins[m] > 0 then
          exitFlag := False;
    end;
    if list <> nil then
      MenuCore.FreeStringList(list);
  until exitFlag;
end;

{ True when the creature already holds 16 or more items, or the item's weight (times its quantity) is more than it can
  still carry (Money.CheckOverload, which counts a readied Bag of Holding). Recalculates the creature's stats first. }
function CannotCarryItem(creature: Types.PCharRecord; item: Types.PItemRec): Boolean;
var
  f: Boolean;
  w: LongInt;
  takable: Word;
begin
  CharHlp.RecalcStats(creature);
  f := False;
  if creature^.numberOfItems > 15 then
    f := True;
  w := CharHlp.ItemWeight(item);
  if Money.CheckOverload(creature, w, takable) then
    f := True;
  CannotCarryItem := f;
end;

end.

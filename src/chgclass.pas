{ Human Change Class (#838): the training hall's screen where a human leaves its class and starts again as a level 1
  character of another, as the 1st-edition PHB ("Characters With Two Classes", p.33) and Curse of the Azure Bonds let
  it, and the powers that follow a class as it rests and wakes again. The rules are ClassCal's (CanChangeClass,
  CanTakeClass, ChangeClass) and CharHlp's (GetClassLevel, ClassResting). Overlaid; CharGen, EffHndlr and Magic use
  it. }
{$O+,F+}
{$I COMPILER.INC}
unit ChgClass;

interface

uses Types;

const
  { what a change of class costs, in gold pieces, and only at a hall that trains the new class (#838) }
  CHANGE_FEE = 2500;

{ The classes creature has left and cannot use yet, one C_LEVEL bit each (CharHlp.ClassResting): taken before a level
  is gained, drained or restored, and given to AnnounceWoken after. }
function RestingMask(creature: Types.PCharRecord): Byte;

{ Bring the powers that go with a class into line with the classes creature can use: a paladin's own Protection from
  Evil (C_EFFECT.PROT_EVIL_10FT, permanent at strength 255, as creation gives it) is there while its paladin levels
  are usable and gone while they rest, and a readied item none of its usable classes may use (itemLimits) is put
  away unless it is cursed. Then RecalcStats. Only a dual-classed human is touched. }
procedure SyncClassPowers(creature: Types.PCharRecord);

{ For each class of wasResting (RestingMask before) creature can use again, say so in the message window ('Alias can
  again use the skills of a Fighter.') and, for a level 1 cleric or magic-user, give its first-level slot
  (ClassCal.StartCasterClass), which RecalcBaseSkills leaves to creation; then SyncClassPowers. }
procedure AnnounceWoken(creature: Types.PCharRecord; wasResting: Byte);

{ The Human Change Class screen for curChar (mocks/change-class.txt): what leaving its class needs and what it has,
  then the classes a human can take with what each needs and what it has, white for one it qualifies for here, dark
  gray for one it does not; Up and Down move the yellow highlight between the qualifying ones, and the lines below
  say what choosing it does. A class qualifies when ClassCal.CanTakeClass allows it and this hall trains it
  (C_GBVM.TRAIN_CLASS_MASK, GameDefs.classBit); freeTraining (CharGen's STING switch) waives the hall and the fee.
  Choose asks Yes or No, takes CHANGE_FEE gold and changes the class (ClassCal.ChangeClass, SyncClassPowers). A
  character not okay, or without the fee, is turned away first, as training turns it away. }
procedure ChangeClassMenu(freeTraining: Boolean);

implementation

uses Crt, C_ABIL, C_CLASS, C_EFFECT, C_GBVM, C_KEYS, C_LEVEL, C_MSG, C_RACE, C_STATUS, GameDefs, GameVars, Border,
  CharDisp, CharHlp, ClassCal, FxEngine, MenuCore, Money, MoneyCal, StrUtil, TextRend;

const
  { the screen's columns: labels, the class names, what is needed and what the character has }
  LABEL_COL = 2;
  CLASS_COL = 4;
  NEEDS_COL = 15;
  HAS_COL = 30;
  { its rows: the title, the name, the class followed now and what leaving it needs, the heading of the classes and the
    first of them, the explanation's first and last }
  TITLE_ROW = 1;
  NAME_ROW = 3;
  NOW_ROW = 5;
  LEAVE_ROW = 6;
  HEAD_ROW = 8;
  FIRST_CLASS_ROW = 9;
  TEXT_TOP_ROW = 16;
  TEXT_BOTTOM_ROW = 21;
  { the most classes listed: a human's six less the one it follows }
  MAX_LISTED = 6;
  abilityNames: array[C_ABIL.STRENGTH..C_ABIL.CHARISMA] of string[3] = ('STR', 'INT', 'WIS', 'DEX', 'CON', 'CHA');

function RestingMask(creature: Types.PCharRecord): Byte;
var
  mask: Byte;
  cls: ShortInt;
begin
  mask := 0;
  for cls := C_LEVEL.CLERIC to C_LEVEL.MONK do
    if CharHlp.ClassResting(creature, cls) then
      mask := mask or (1 shl cls);
  RestingMask := mask;
end;

{ creature's own Protection from Evil, creation's: permanent, at strength 255; nil when it has none. }
function OwnWard(creature: Types.PCharRecord): Types.PEffectRec;
var
  p: Types.PEffectRec;
begin
  OwnWard := nil;
  p := creature^.effectsAddr;
  while p <> nil do begin
    if (p^.id = C_EFFECT.PROT_EVIL_10FT) and (p^.duration = 0) and (p^.strength = 255) then
      OwnWard := p;
    p := p^.next;
  end;
end;

procedure SyncClassPowers(creature: Types.PCharRecord);
var
  ward: Types.PEffectRec;
  item: Types.PItemRec;
begin
  if not CharHlp.IsDualClass(creature) then Exit;
  ward := ChgClass.OwnWard(creature);
  if CharHlp.GetClassLevel(creature, C_LEVEL.PALADIN_BIT) > 0 then begin
    if ward = nil then
      FxEngine.AddEffect(creature, C_EFFECT.PROT_EVIL_10FT, 0, 255, False);
  end else if ward <> nil then
    FxEngine.RemoveEffect(creature, C_EFFECT.PROT_EVIL_10FT, ward);
  item := creature^.itemsAddr;
  while item <> nil do begin
    if (item^.equipped <> 0) and (item^.cursed = 0) and
        (CharHlp.BaseItem(item^.itemType)^.classMask and creature^.itemLimits = 0) then begin
      item^.equipped := 0;
      { as FxEngine.ToggleReadyItem puts a special item away }
      if item^.special > $7F then
        FxEngine.CallEffectHandler(item^.special, creature, item, True);
    end;
    item := item^.next;
  end;
  CharHlp.RecalcStats(creature);
end;

procedure AnnounceWoken(creature: Types.PCharRecord; wasResting: Byte);
var
  cls: ShortInt;
begin
  for cls := C_LEVEL.CLERIC to C_LEVEL.MONK do
    if (wasResting and (1 shl cls) <> 0) and not CharHlp.ClassResting(creature, cls) then begin
      if creature^.classLevels[cls] = 1 then
        ClassCal.StartCasterClass(creature, cls);
      CharDisp.MessageText(creature^.name + ' can again use the skills of a ' + GameDefs.classNames[cls] + '.',
                           LightGreen, True);
      CharDisp.MessageWait;
    end;
  ChgClass.SyncClassPowers(creature);
end;

{ ability names joined with '/', each of class cls's prime requisites (ClassCal.primeRequisites), and the creature's
  scores in them the same way }
procedure PrimeText(creature: Types.PCharRecord; cls: ShortInt; var names, scores: Types.TStr40);
var
  ab: ShortInt;
  score: Byte;
begin
  names := '';
  scores := '';
  for ab := C_ABIL.STRENGTH to C_ABIL.CHARISMA do
    if ClassCal.primeRequisites[cls] and (1 shl ab) <> 0 then begin
      if names <> '' then begin
        names := names + '/';
        scores := scores + '/';
      end;
      names := names + abilityNames[ab];
      if ab = C_ABIL.STRENGTH then
        score := CharHlp.PermanentStrength(creature)
      else
        score := creature^.stats[ab];
      scores := scores + StrUtil.NumStr(score);
    end;
end;

{ True when creature qualifies for class cls here: the rules allow it and the hall trains it, or free training is on. }
function Qualifies(creature: Types.PCharRecord; cls: ShortInt; freeTraining: Boolean): Boolean;
begin
  Qualifies := ClassCal.CanTakeClass(creature, cls) and
               (freeTraining or (GameDefs.classBit[cls] and GameVars.zone1^[C_GBVM.TRAIN_CLASS_MASK] <> 0));
end;

{ One class line: its name, what its prime requisites need and what the creature has, in color. }
procedure DrawClassLine(creature: Types.PCharRecord; cls: ShortInt; row, color: Byte);
var
  names: Types.TStr40;
  scores: Types.TStr40;
begin
  ChgClass.PrimeText(creature, cls, names, scores);
  TextRend.PrintSpaces(CLASS_COL, row, Black, C_MSG.TEXT_RIGHT - CLASS_COL);
  TextRend.DisplayString(CLASS_COL, row, color, GameDefs.classNames[cls]);
  TextRend.DisplayString(NEEDS_COL, row, color, names + ' ' + StrUtil.NumStr(ClassCal.TAKE_CLASS_SCORE));
  TextRend.DisplayString(HAS_COL, row, color, scores);
end;

{ The explanation under the classes, word-wrapped between the frame's sides. }
procedure Explain(s: string);
var
  delayFlag: Byte;
begin
  Border.ClearBox(LABEL_COL, TEXT_TOP_ROW, C_MSG.TEXT_RIGHT - 1, TEXT_BOTTOM_ROW);
  delayFlag := GameVars.msgDelayFlag;
  GameVars.msgDelayFlag := 0;
  TextRend.DisplayMessageWindow(LABEL_COL, TEXT_TOP_ROW, C_MSG.TEXT_RIGHT - 1, TEXT_BOTTOM_ROW, LightGreen, False, s);
  GameVars.msgDelayFlag := delayFlag;
end;

{ What choosing cls does, or why no class can be chosen (cls -1). }
procedure ExplainChoice(creature: Types.PCharRecord; cls: ShortInt; freeTraining: Boolean);
var
  old: ShortInt;
  names: Types.TStr40;
  scores: Types.TStr40;
begin
  old := creature^.charClass;
  if cls >= 0 then
    ChgClass.Explain(creature^.name + ' will be a level 1 ' + GameDefs.classNames[cls] + '. The ' +
                     GameDefs.classNames[old] + '''s skills rest until ' + creature^.name + ' passes level ' +
                     StrUtil.NumStr(creature^.classLevels[old]) + ' as a ' + GameDefs.classNames[cls] + '.')
  else if ChgClass.RestingMask(creature) <> 0 then
    ChgClass.Explain(creature^.name + ' cannot change class again until the skills of every class left come back.')
  else if not ClassCal.PrimesAtLeast(creature, old, ClassCal.LEAVE_CLASS_SCORE) then begin
    ChgClass.PrimeText(creature, old, names, scores);
    ChgClass.Explain('To leave the ' + GameDefs.classNames[old] + ' class ' + creature^.name + ' needs ' + names +
                     ' of ' + StrUtil.NumStr(ClassCal.LEAVE_CLASS_SCORE) + ' or more.')
  end else
    ChgClass.Explain(creature^.name + ' qualifies for no new class this hall trains. A new class needs ' +
                     StrUtil.NumStr(ClassCal.TAKE_CLASS_SCORE) + ' in each of its prime requisites, its minimums ' +
                     'and an alignment it allows.');
end;

procedure ChangeClassMenu(freeTraining: Boolean);
var
  creature: Types.PCharRecord;
  listed: array[1..MAX_LISTED] of ShortInt;
  count: Byte;
  sel: Byte;
  i: Byte;
  cls: ShortInt;
  old: ShortInt;
  ch: Char;
  ext: Boolean;
  names: Types.TStr40;
  scores: Types.TStr40;
  done: Boolean;

  { the next qualifying line from sel in direction step (1 or -1), wrapping; sel itself when there is no other }
  function NextQualifying(step: ShortInt): Byte;
  var
    n: Byte;
    k: Byte;
  begin
    NextQualifying := sel;
    n := sel;
    for k := 1 to count do begin
      n := (n + count + step - 1) mod count + 1;
      if ChgClass.Qualifies(creature, listed[n], freeTraining) then begin
        NextQualifying := n;
        Exit;
      end;
    end;
  end;

  procedure MoveTo(n: Byte);
  begin
    if sel > 0 then
      ChgClass.DrawClassLine(creature, listed[sel], FIRST_CLASS_ROW + sel - 1, White);
    sel := n;
    ChgClass.DrawClassLine(creature, listed[sel], FIRST_CLASS_ROW + sel - 1, Yellow);
    ChgClass.ExplainChoice(creature, listed[sel], freeTraining);
  end;

begin
  creature := GameVars.curChar;
  if (creature^.status <> C_STATUS.OKAY) and not freeTraining then begin
    TextRend.PrintAndPause('we only train conscious people', Yellow);
    Exit;
  end;
  if (MoneyCal.CreatureGold(creature) < CHANGE_FEE) and not freeTraining then begin
    TextRend.PrintAndPause('Changing class costs ' + StrUtil.NumStr(CHANGE_FEE) + ' gp.', Yellow);
    Exit;
  end;
  old := creature^.charClass;
  TextRend.ClearScreen;
  Border.DrawBorder(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0);
  TextRend.DisplayCentered(C_MSG.TEXT_LEFT + 1, C_MSG.TEXT_RIGHT - 1, TITLE_ROW, LightCyan, 'Human Change Class');
  TextRend.DisplayCentered(C_MSG.TEXT_LEFT + 1, C_MSG.TEXT_RIGHT - 1, NAME_ROW, LightCyan, creature^.name);
  TextRend.DisplayString(LABEL_COL, NOW_ROW, LightGreen, 'Now');
  TextRend.DisplayString(NEEDS_COL, NOW_ROW, White,
                         GameDefs.classNames[old] + ', level ' + StrUtil.NumStr(creature^.classLevels[old]));
  ChgClass.PrimeText(creature, old, names, scores);
  TextRend.DisplayString(LABEL_COL, LEAVE_ROW, LightGreen, 'To leave');
  TextRend.DisplayString(NEEDS_COL, LEAVE_ROW, White, names + ' ' + StrUtil.NumStr(ClassCal.LEAVE_CLASS_SCORE));
  TextRend.DisplayString(HAS_COL, LEAVE_ROW, White, scores);
  TextRend.DisplayString(LABEL_COL, HEAD_ROW, LightGreen, 'New class');
  TextRend.DisplayString(NEEDS_COL, HEAD_ROW, LightGreen, 'Needs');
  TextRend.DisplayString(HAS_COL, HEAD_ROW, LightGreen, 'Has');
  { the classes a human takes, but the one it follows and those it has left }
  count := 0;
  for i := 1 to ClassCal.classesByRace[C_RACE.HUMAN].count do begin
    cls := ClassCal.classesByRace[C_RACE.HUMAN].classes[i];
    if (cls <> old) and (creature^.portExt.formerClasses and (1 shl cls) = 0) and (count < MAX_LISTED) then begin
      Inc(count);
      listed[count] := cls;
    end;
  end;
  sel := 0;
  for i := 1 to count do
    if ChgClass.Qualifies(creature, listed[i], freeTraining) then begin
      ChgClass.DrawClassLine(creature, listed[i], FIRST_CLASS_ROW + i - 1, White);
      if sel = 0 then
        sel := i;
    end else
      ChgClass.DrawClassLine(creature, listed[i], FIRST_CLASS_ROW + i - 1, DarkGray);
  if sel > 0 then begin
    i := sel;
    sel := 0;
    MoveTo(i);
  end else
    ChgClass.ExplainChoice(creature, -1, freeTraining);
  done := False;
  repeat
    MenuCore.arrowsToCaller := True;
    MenuCore.enterToCaller := sel > 0;
    if sel > 0 then
      ch := MenuCore.MenuHorizontal('Change class: ', 'Choose Exit', LightMagenta, LightGreen, White, True, False,
                                    ext)
    else
      ch := MenuCore.MenuHorizontal('Change class: ', 'Exit', LightMagenta, LightGreen, White, True, False, ext);
    if ext then begin
      if sel > 0 then
        case ch of
          C_KEYS.UP: MoveTo(NextQualifying(-1));
          C_KEYS.DOWN: MoveTo(NextQualifying(1));
        end;
    end else if (sel > 0) and ((ch = 'C') or (ch = C_KEYS.ENTER)) then begin
      cls := listed[sel];
      if MenuCore.YesNoMenu('Change ' + creature^.name + ' to a ' + GameDefs.classNames[cls] + '? ', LightMagenta,
                            LightGreen, White) = 'Y' then begin
        if not freeTraining then
          Money.PayFromCreature(creature, CHANGE_FEE);
        ClassCal.ChangeClass(creature, cls);
        ChgClass.SyncClassPowers(creature);
        CharDisp.PrintBottomLine(creature^.name + ' is now a ' + GameDefs.classNames[cls] + '.');
        done := True;
      end;
    end else if (ch = 'E') or (ch = C_KEYS.NONE) then
      done := True;
  until done;
end;

end.

{ Character creation, modification and training, plus party management and the main menu. }
{$O+,F+}
{$I COMPILER.INC}
unit CharGen;

interface

procedure MainMenu;

procedure CustomizeIcon;

{ The portrait picker for curChar; canCancel lets Escape leave it with the portrait unchanged (camp's Alter). }
procedure CustomizePortrait(canCancel: Boolean);

{ True when curChar can be modified at all: a player race (Dwarf..Human, whose limits
  dsMinimumMaximumStatistics holds; the hired Acolyte is race 0) and a class C_Class.CLERIC..MAGE_THIEF (0..16). }
function Modifiable: Boolean;

{ Arrow-key editor for curChar's six attributes and hit points (ModifyCharacterMenu's, which calls it for a character
  with no experience; the Companion Tools' character editor calls it for any Modifiable one). levelled: a Constitution
  change moves hpMax by the hit points it gives over every hit die (ClassCal.ConHpTotal), the hit-point row runs
  between ClassCal.HpMinimum and HpMaximum for the character's levels, and damage taken stays taken; Keep leaves
  npcTreasureShare as it is. }
procedure ModifyCharacter(levelled: Boolean);

procedure GainLevels(trainable: Byte; restoreDrain: Boolean);

implementation

uses Types, Crt, C_Area, C_Npc, GDConsts, GDVars, SaveLoad, ViewChar, Border, GameIo, C_Class, C_Level, C_Race, C_Keys,
  C_Effect, C_Status, C_Ifc, C_Gbvm, C_Abil, C_Money, Money, C_Align, Options, Blit, CbtMap, CharHlp, ClassCal,
  DaxIo, FxEngine, MapTiles, MenuCore, Portrait, TextRend, StrUtil, CharDisp, MoneyCal, Party, Magic, C_Msg, Dice, VidOps
  {$IFDEF FPC}, TpRand{$ENDIF};

var
  { STING training override. }
  stingMode: Byte;



const
  { The race screen's frames: the race list and the ability adjustments share rows 1..RACE_TOP_BOTTOM, on either side
    of the border column RACE_SPLIT_COL; the classes and their maximum levels fill the box below. }
  RACE_SPLIT_COL = 17;
  RACE_TOP_BOTTOM = 8;
  { the row of the first race, and of the first ability beside it }
  RACE_LIST_ROW = 2;

procedure CreateCharacterMenu; forward;

procedure DropCharacterMenu; forward;

procedure ModifyCharacterMenu; forward;

procedure TrainingMenu; forward;

procedure AddCharacterMenu; forward;





{ MainMenu: The party-roster main menu (create, drop, modify, train, view, add, remove, load, save, begin, game
  settings, exit). Returns once a loaded saved game leaves the main-menu state (setting loadedSave) or Begin
  Adventuring sets ifcState to 4 (C_Ifc.INDOORS). Exit to DOS, with a party not saved since it changed, asks to save
  first: Yes opens the save menu, and leaving it without saving stays in the menu; No quits unsaved (#660). Game
  Settings opens the Settings screen (Options.OptionsMenu). J sets stingMode when the first command-line parameter is STING. }
procedure MainMenu;
const
  MENU_CREATE = 0;
  MENU_DROP = 1;
  MENU_MODIFY = 2;
  MENU_TRAIN = 3;
  MENU_VIEW = 4;
  MENU_ADD = 5;
  MENU_REMOVE = 6;
  MENU_LOAD = 7;
  MENU_SAVE = 8;
  MENU_BEGIN = 9;
  MENU_SETTINGS = 10;
  MENU_QUIT = 11;
var
  i: Byte;
  ch: Char;
  ext: Boolean;
  ext2: Boolean;
  n: ShortInt;
  redraw: Boolean;
  stateB: Byte;
  quit: Boolean;
  { SaveGame's result: the menu goes on either way }
  saved: Boolean;
begin
  GDVars.virtualDisk := 3;
  stateB := C_Ifc.INDOORS;
  redraw := True;
  stingMode := 0;
  GDVars.ifcState := C_Ifc.MAIN_MENU;
  while True do begin
    if redraw then begin
      Border.DrawWindow(C_Msg.TEXT_LEFT, C_Msg.TEXT_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, 0, Black, '');
      if GDVars.curChar <> nil then begin
        CharDisp.DisplayParty(Types.PCharRecord(GDVars.curChar));
        GDConsts.menuItems[MENU_DROP].enabled := 1;
        GDConsts.menuItems[MENU_MODIFY].enabled := 1;
        { Train is offered only at a training hall or with free training on, recomputed on each redraw (#765) }
        GDConsts.menuItems[MENU_TRAIN].enabled :=
          Ord((GDVars.zone1^[C_Gbvm.TRAIN_CLASS_MASK] > 0) or (stingMode <> 0));
        GDConsts.menuItems[MENU_VIEW].enabled := 1;
        GDConsts.menuItems[MENU_REMOVE].enabled := 1;
        GDConsts.menuItems[MENU_LOAD].enabled := 0;
        GDConsts.menuItems[MENU_SAVE].enabled := 1;
        GDConsts.menuItems[MENU_BEGIN].enabled := 1;
      end else begin
        GDConsts.menuItems[MENU_DROP].enabled := 0;
        GDConsts.menuItems[MENU_MODIFY].enabled := 0;
        GDConsts.menuItems[MENU_TRAIN].enabled := 0;
        GDConsts.menuItems[MENU_VIEW].enabled := 0;
        GDConsts.menuItems[MENU_REMOVE].enabled := 0;
        GDConsts.menuItems[MENU_LOAD].enabled := 1;
        GDConsts.menuItems[MENU_SAVE].enabled := 0;
        GDConsts.menuItems[MENU_BEGIN].enabled := 0;
      end;
      n := 0;
      for i := MENU_CREATE to MENU_QUIT do
        if GDConsts.menuItems[i].enabled <> 0 then begin
          TextRend.DisplayString(2, n + 12, White, GDConsts.menuItems[i].name[1]);
          TextRend.DisplayString(3, n + 12, LightGreen,
                                 Copy(GDConsts.menuItems[i].name, 2, Length(GDConsts.menuItems[i].name) - 1));
          Inc(n);
        end;
      redraw := False;
    end;

    ch := MenuCore.MenuHorizontal('pool of radiance ' + GDConsts.GAME_VERSION, GDConsts.menuKeys, MAGENTA, Black, Black, 
            True, False, ext);
    TextRend.ClearBottomLine;
    if ext then begin
      { Home, End, Up and Down step through the party (Party.SelectPrevNextChar) }
      if ch in [C_Keys.HOME, C_Keys.END_KEY, C_Keys.UP, C_Keys.DOWN] then begin
        Party.SelectPrevNextChar(ch);
        CharDisp.DisplayParty(Types.PCharRecord(GDVars.curChar));
      end;
    end else begin
      if not (ch in ['E', 'S']) then
        GDVars.recentSaved := 0;
      case ch of
        'C': if GDConsts.menuItems[MENU_CREATE].enabled <> 0 then
               CharGen.CreateCharacterMenu;
        'D': if GDConsts.menuItems[MENU_DROP].enabled <> 0 then
               CharGen.DropCharacterMenu;
        'M': if GDConsts.menuItems[MENU_MODIFY].enabled <> 0 then
               CharGen.ModifyCharacterMenu;
        'T': if GDConsts.menuItems[MENU_TRAIN].enabled <> 0 then
               CharGen.TrainingMenu;
        'V': if GDConsts.menuItems[MENU_VIEW].enabled <> 0 then
               ViewChar.ViewCharMenu(ext2);
        'A': if GDConsts.menuItems[MENU_ADD].enabled <> 0 then
               CharGen.AddCharacterMenu;
        'R': if (GDConsts.menuItems[MENU_REMOVE].enabled <> 0) and (GDVars.curChar <> nil) then
             begin
               { a character whose save failed stays in the party }
               if SaveLoad.SaveChar(Types.PCharRecord(GDVars.curChar), '') then
                 SaveLoad.RemoveCreature(False, True);
             end;
        'L': if GDConsts.menuItems[MENU_LOAD].enabled <> 0 then
             begin
               SaveLoad.LoadGame;
               if GDVars.ifcState <> C_Ifc.MAIN_MENU then begin
                 GDVars.loadedSave := 1;
                 Exit;
               end;
             end;
        'S': if (GDConsts.menuItems[MENU_SAVE].enabled <> 0) and (GDVars.creatureList <> nil) then
               saved := SaveLoad.SaveGame;
        'B': if (GDConsts.menuItems[MENU_BEGIN].enabled <> 0) and (GDVars.creatureList <> nil) then
             begin
               GDVars.ifcState := stateB;
               TextRend.ClearBottomLine;
               Exit;
             end;
        'G': if GDConsts.menuItems[MENU_SETTINGS].enabled <> 0 then
               Options.OptionsMenu;
        'E': if GDConsts.menuItems[MENU_QUIT].enabled <> 0 then
             begin
               ch := MenuCore.YesNoMenu('Quit to DOS ', Yellow, LightGreen, White);
               if ch = 'Y' then
               begin
                 quit := True;
                 if (GDVars.recentSaved = 0) and (GDVars.creatureList <> nil) then
                   if MenuCore.YesNoMenu('Save first? ', Yellow, LightGreen, White) = 'Y' then begin
                     quit := SaveLoad.SaveGame;
                   end;
                 if quit then
                   GameIo.ExitGame;
               end;
             end;
        { free training, turned on and off as in Curse }
        'J': if GDVars.stingArg then
             begin
               stingMode := Ord(stingMode = 0);
               if stingMode <> 0 then
                 CharDisp.PrintBottomLine('Free training on')
               else
                 CharDisp.PrintBottomLine('Free training off');
             end;
      end;
      redraw := True;
    end;
  end;
end;

{ ShowRaceInfo: Fill the race screen's panes for race: its ability adjustments (GDConsts.raceAbilityAdj) beside the race
  list, and below, the single classes the race may take with the rule book's maximum level in each
  (GDConsts.raceMaxLevel; U for no maximum), and beside them the race's multiclasses, abbreviated. A single class is one
  GDConsts.classesByRace offers alone or as part of a multiclass. A multiclass trains each part to the same maximum,
  which the note at the foot of the box says; a race without multiclasses shows neither the note nor the multiclass
  heading. The note sits under the single classes, so the multiclasses may run on beside it to the foot of the box. A
  race outside Dwarf..Human leaves the panes blank. }
procedure ShowRaceInfo(race: ShortInt);
const
  ABIL_LABELS: array[C_Abil.STRENGTH..C_Abil.CHARISMA] of String[3] = ('STR', 'INT', 'WIS', 'DEX', 'CON', 'CHA');
  { by classLevels index }
  PART_ABBREVS: array[C_Level.CLERIC..C_Level.MONK] of String[2] = (
    'CL', 'DR', 'FI', 'PA', 'RA', 'MU', 'TH', 'MO');
  ABIL_COL = 19;
  ADJ_COL = 23;
  HEADING_ROW = 11;
  { the data starts a row below the headings; the single classes end above the note's two rows, and the
    multiclasses, right of the note, at the foot of the box }
  FIRST_ROW = 13;
  LAST_ROW = 19;
  NOTE_ROW = 20;
  LAST_MULTI_ROW = 21;
  MAX_COL = 2;
  MAX_VALUE_COL = 3;
  CLASS_COL = 7;
  MULTI_COL = 21;
  LAST_COL = 38;
var
  i: ShortInt;
  slot: Byte;
  cnt: Byte;
  cls: ShortInt;
  row: Byte;
  adj: ShortInt;
  s: String;
  p: Byte;
  part: ShortInt;
  lvl: ShortInt;
  hasMulti: Boolean;
  isSingle: array[C_Level.CLERIC..C_Level.MONK] of Boolean;
begin
  Border.ClearBox(ADJ_COL, RACE_LIST_ROW, LAST_COL, RACE_LIST_ROW + C_Abil.CHARISMA);
  Border.ClearBox(1, HEADING_ROW, LAST_COL, NOTE_ROW + 1);
  if (race < C_Race.DWARF) or (race > C_Race.HUMAN) then
    Exit;
  for i := C_Abil.STRENGTH to C_Abil.CHARISMA do begin
    TextRend.DisplayString(ABIL_COL, RACE_LIST_ROW + i, LightGreen, ABIL_LABELS[i]);
    adj := GDConsts.raceAbilityAdj[race].values[i];
    if adj > 0 then
      s := '+' + StrUtil.NumStr(adj)
    else if adj < 0 then
      s := '-' + StrUtil.NumStr(-adj)
    else
      s := ' 0';
    TextRend.DisplayString(ADJ_COL, RACE_LIST_ROW + i, LightGreen, s);
  end;
  { the multiclasses on the right, noting every part as a single class }
  FillChar(isSingle, SizeOf(isSingle), 0);
  hasMulti := False;
  cnt := GDConsts.classesByRace[race].count;
  if cnt > 13 then
    cnt := 13;
  row := FIRST_ROW;
  for slot := 1 to cnt do begin
    cls := GDConsts.classesByRace[race].classes[slot];
    if (cls >= C_Class.CLERIC) and (cls <= C_Class.MAGE_THIEF) then begin
      s := '';
      for p := 1 to 3 do begin
        part := GDConsts.classParts[cls].values[p];
        if (part >= C_Level.CLERIC) and (part <= C_Level.MONK) then begin
          isSingle[part] := True;
          if s <> '' then
            s := s + '/';
          s := s + PART_ABBREVS[part];
        end;
      end;
      if (cls > C_Class.MONK) and (row <= LAST_MULTI_ROW) then begin
        hasMulti := True;
        TextRend.DisplayString(MULTI_COL, row, LightGreen, Copy(s, 1, LAST_COL - MULTI_COL + 1));
        Inc(row);
      end;
    end;
  end;
  TextRend.DisplayString(MAX_COL, HEADING_ROW, LightMagenta, 'Max');
  TextRend.DisplayString(CLASS_COL, HEADING_ROW, LightMagenta, 'Class');
  if hasMulti then
    TextRend.DisplayString(MULTI_COL, HEADING_ROW, LightMagenta, 'Multiclasses');
  { the single classes on the left; a single class's id is its classLevels index }
  row := FIRST_ROW;
  for part := C_Level.CLERIC to C_Level.MONK do
    if isSingle[part] and (row <= LAST_ROW) then begin
      lvl := GDConsts.raceMaxLevel[race].values[part];
      if lvl = 0 then
        s := 'U'
      else if lvl > 0 then
        s := StrUtil.NumStr(lvl)
      else
        s := '-';
      TextRend.DisplayString(MAX_VALUE_COL, row, LightGreen, s);
      TextRend.DisplayString(CLASS_COL, row, LightGreen, Copy(GDConsts.classNames[part], 1, MULTI_COL - CLASS_COL - 1));
      Inc(row);
    end;
  if hasMulti then begin
    TextRend.DisplayString(MAX_COL, NOTE_ROW, LightGreen, 'Multiclass levels');
    TextRend.DisplayString(MAX_COL + 2, NOTE_ROW + 1, LightGreen, 'are as above.');
  end;
end;

{ CreateCharacterMenu: Choose race, gender, class and alignment, set the starting age, then roll attributes, hit points
  and gold until the player keeps the result; name the character, customize portrait and icon, save it with
  SaveLoad.SaveChar (a save that fails is offered again, until No) and free it. Aborting a pick menu frees the string
  list and the character before it exits; at the end SaveLoad.FreeCreature frees the record with its racial effects. }
procedure CreateCharacterMenu;
var
  creature: Types.PCharRecord;
  savedCur: Types.PCharRecord;
  list: Types.PItemRec;
  m: Types.PItemRec;
  sel: Integer;
  slot: Byte;
  j: ShortInt;
  roll: Byte;
  ch: Char;
  k: ShortInt;
  g: ShortInt;
  cls: ShortInt;
  i: ShortInt;
  cnt: Byte;
  conB: Integer;
  clsCount: Byte;
  hpTotal: Byte;
  addExit: Boolean;
  redraw: Boolean;

  { Bring the new character's rolled ability i within its race's limits (ClassCal.RaceAbilityMin and Max), then up to
    its class's minimum. }
  procedure ClampToLimits(i: ShortInt);
  begin
    with creature^ do begin
      if stats[i] < ClassCal.RaceAbilityMin(race, genderSp, i) then
        stats[i] := ClassCal.RaceAbilityMin(race, genderSp, i);
      if stats[i] > ClassCal.RaceAbilityMax(race, genderSp, i) then
        stats[i] := ClassCal.RaceAbilityMax(race, genderSp, i);
      if stats[i] < ClassCal.ClassAbilityMin(charClass, i) then
        stats[i] := ClassCal.ClassAbilityMin(charClass, i);
    end;
  end;

  { Run the gender, class or alignment list until Enter, leaving the pick in sel (1 for the first line). Exit or Escape
    frees the list and the character and returns False, for the caller to leave. }
  function PickFromList: Boolean;
  var
    picked: Types.PItemRec;
    key: Char;
    withExit: Boolean;
    repaint: Boolean;
  begin
    PickFromList := True;
    picked := list;
    sel := 1;
    withExit := True;
    repaint := True;
    repeat
      key := MenuCore.MenuVertical('', '', LightMagenta, LightGreen, White, 1, 2, 38, 22, list, withExit, repaint, sel,
                                   picked);
      if key = C_Keys.NONE then begin
        MenuCore.FreeStringList(list);
        SaveLoad.FreeCreature(creature);
        PickFromList := False;
        Exit;
      end;
    until key = C_Keys.ENTER;
  end;

begin
  GetMem(creature, SizeOf(Types.TCharRecord));
  FillChar(creature^, SizeOf(Types.TCharRecord), 0);
  with creature^ do begin
    for slot := 1 to 6 do
      iconColors1[slot] := GDConsts.defIconCol[slot] + (GDConsts.defIconCol[slot] + 8) * 16;
    acBase := 50;
    thac0Base := 40;
    status := C_Status.OKAY;
    enabled := 1;
    portraitHead := 1;
    portraitBody := 1;
    iconDimensions := 1;
    randByte := Random(256);
  end;
  { race }
  MenuCore.AllocStringList(7, list);
  list^.inUse := 1;
  list^.name := 'Pick Race';
  for k := 1 to 7 do
    case k of
      C_Race.DWARF..C_Race.HALFLING: begin
              m := MenuCore.FindListMember(k, list);
              m^.name := '  ' + GDConsts.raceNames[k];
            end;
      { half-orc (6) row skipped }
      C_Race.HUMAN: begin
              m := MenuCore.FindListMember(k - 1, list);
              m^.name := '  ' + GDConsts.raceNames[k];
            end;
    end;
  { the race screen: the bottom box goes first, so the top boxes' gold corners stay on the row they share with it }
  Border.ClearBox(C_Msg.TEXT_LEFT, C_Msg.TEXT_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
  Border.DrawBorder(1, RACE_TOP_BOTTOM + 2, 38, 22, 0);
  Border.DrawBorder(1, 1, RACE_SPLIT_COL - 1, RACE_TOP_BOTTOM, 0);
  Border.DrawBorder(RACE_SPLIT_COL + 1, 1, 38, RACE_TOP_BOTTOM, 0);
  CharGen.ShowRaceInfo(C_Race.DWARF);
  m := list;
  sel := 1;
  { the list starts at Dwarf, with the label row above the box }
  GDVars.vertTop := 1;
  redraw := True;
  addExit := True;
  repeat
    MenuCore.movesToCaller := True;
    ch := MenuCore.MenuVertical('', '', LightMagenta, LightGreen, White, 1, RACE_LIST_ROW, RACE_SPLIT_COL - 1,
                                RACE_LIST_ROW + 5, list, addExit, redraw, sel, m);
    if ch = C_Keys.NONE then begin
      MenuCore.FreeStringList(list);
      SaveLoad.FreeCreature(creature);
      Exit;
    end;
    if ch <> C_Keys.ENTER then
      { 6 -> Human (7) }
      if sel = 6 then
        CharGen.ShowRaceInfo(C_Race.HUMAN)
      else
        CharGen.ShowRaceInfo(sel);
  until ch = C_Keys.ENTER;
  { back to the one frame the following lists use }
  Border.DrawWindow(C_Msg.TEXT_LEFT, C_Msg.TEXT_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, 0, Black, '');
  if sel = 6 then
    { 6 -> Human (7) }
    Inc(sel);
  with creature^ do begin
    race := sel;
    { Racial innate effects. }
    case race of
      C_Race.HALFLING: begin
           iconSize := 1;
           FxEngine.AddEffect(Types.PCharRecord(creature), C_Effect.CON_PSN_SAVE, 0, 255, False);
           FxEngine.AddEffect(Types.PCharRecord(creature), C_Effect.CON_SPELL_SAVE, 0, 255, False);
         end;
      C_Race.DWARF: begin
           iconSize := 1;
           FxEngine.AddEffect(Types.PCharRecord(creature), C_Effect.CON_PSN_SAVE, 0, 255, False);
           FxEngine.AddEffect(Types.PCharRecord(creature), C_Effect.CON_SPELL_SAVE, 0, 255, False);
           FxEngine.AddEffect(Types.PCharRecord(creature), C_Effect.DWARF_THAC0, 0, 255, False);
           FxEngine.AddEffect(Types.PCharRecord(creature), C_Effect.DWARF_AC_GIANT, 0, 255, False);
         end;
      C_Race.GNOME: begin
           iconSize := 1;
           FxEngine.AddEffect(Types.PCharRecord(creature), C_Effect.CON_SPELL_SAVE, 0, 255, False);
           FxEngine.AddEffect(Types.PCharRecord(creature), C_Effect.GNOME_THAC0, 0, 255, False);
           FxEngine.AddEffect(Types.PCharRecord(creature), C_Effect.DWARF_AC_GIANT, 0, 255, False);
           FxEngine.AddEffect(Types.PCharRecord(creature), C_Effect.GNOME_AC_BUG, 0, 255, False);
         end;
      C_Race.ELF: begin
           iconSize := 2;
           FxEngine.AddEffect(Types.PCharRecord(creature), C_Effect.ELF_RESIST, 0, 255, False);
         end;
      C_Race.HALFELF: begin
           iconSize := 2;
           FxEngine.AddEffect(Types.PCharRecord(creature), C_Effect.HALF_ELF_RESIST, 0, 255, False);
         end;
      else
        { human }
        iconSize := 2;
    end;
  end;
  { gender }
  MenuCore.FreeStringList(list);
  MenuCore.AllocStringList(3, list);
  list^.inUse := 1;
  list^.name := 'Pick Gender';
  for g := 0 to 1 do begin
    m := MenuCore.FindListMember(g + 1, list);
    m^.name := '  ' + GDConsts.genderNames[g];
  end;
  if not PickFromList then Exit;
  creature^.genderSp := sel - 1;
  { class }
  MenuCore.FreeStringList(list);
  cnt := GDConsts.classesByRace[creature^.race].count;
  { the table's width }
  if cnt > 13 then
    cnt := 13;
  MenuCore.AllocStringList(cnt + 1, list);
  list^.inUse := 1;
  list^.name := 'Pick Class';
  for slot := 1 to cnt do begin
    m := MenuCore.FindListMember(slot, list);
    m^.name := '  ' + GDConsts.classNames[GDConsts.classesByRace[creature^.race].classes[slot]];
  end;
  if not PickFromList then Exit;
  if (sel < 1) or (sel > cnt) then
    sel := 1;
  with creature^ do begin
    charClass := GDConsts.classesByRace[race].classes[sel];
    levelHighest := 1;
    { first level in each part of the class }
    if (charClass >= C_Class.CLERIC) and (charClass <= C_Class.MAGE_THIEF) then
      for slot := 1 to 3 do
        if (GDConsts.classParts[charClass].values[slot] >= C_Level.CLERIC)
           and (GDConsts.classParts[charClass].values[slot] <= C_Level.MONK) then
          classLevels[GDConsts.classParts[charClass].values[slot]] := 1;
    { a paladin's own Protection from Evil: permanent, and at strength 255 so Dispel Magic leaves it. It is the 10'
      radius one, as the paladin's has a 1" radius: SSI gave eff 8, which covered the paladin alone (#742). }
    if charClass = C_Class.PALADIN then
      FxEngine.AddEffect(creature, C_Effect.PROT_EVIL_10FT, 0, 255, False);
    itemLimits := 0;
    thac0Base := 0;
    for cls := C_Level.CLERIC to C_Level.MONK do
      if classLevels[cls] > 0 then begin
        if GDConsts.thac0Tbl[cls, classLevels[cls]] > thac0Base then
          thac0Base := GDConsts.thac0Tbl[cls, classLevels[cls]];
        itemLimits := itemLimits or GDConsts.usabilityBit[cls];
      end;
  end;
  ClassCal.RecalcSaves(Types.PCharRecord(creature));
  { alignment }
  MenuCore.FreeStringList(list);
  cnt := GDConsts.alignByClass[creature^.charClass].count;
  MenuCore.AllocStringList(cnt + 1, list);
  list^.inUse := 1;
  list^.name := 'Pick Alignment';
  for slot := 1 to cnt do begin
    m := MenuCore.FindListMember(slot, list);
    m^.name := '  ' + GDConsts.alignNames[GDConsts.alignByClass[creature^.charClass].alignments[slot]];
  end;
  if not PickFromList then Exit;
  creature^.alignment := GDConsts.alignByClass[creature^.charClass].alignments[sel];
  MenuCore.FreeStringList(list);
  { Starting age: single classes (0..7, monk included) roll the age dice; multiclasses take base + sides * num (the dice
    maximum) of one component class. }
  if creature^.charClass <= C_Class.MONK then
    with GDConsts.dsStartingAge[creature^.race, creature^.charClass] do
      creature^.age := Dice.RollDice(num, sides) + base
  else
    with creature^ do
      case charClass of
        C_Class.CLERIC_FIGHTER: age := GDConsts.dsStartingAge[race, C_Class.CLERIC].base +
                   GDConsts.dsStartingAge[race, C_Class.CLERIC].sides * GDConsts.dsStartingAge[race,
                       C_Class.CLERIC].num;
        C_Class.CLERIC_FIGHTER_MAGE: age := GDConsts.dsStartingAge[race, C_Class.CLERIC].base +
                   GDConsts.dsStartingAge[race, C_Class.CLERIC].sides * GDConsts.dsStartingAge[race,
                       C_Class.CLERIC].num;
        C_Class.CLERIC_RANGER: age := GDConsts.dsStartingAge[race, C_Class.CLERIC].base +
                   GDConsts.dsStartingAge[race, C_Class.CLERIC].sides * GDConsts.dsStartingAge[race,
                       C_Class.CLERIC].num;
        C_Class.CLERIC_MAGE: age := GDConsts.dsStartingAge[race, C_Class.CLERIC].base +
                   GDConsts.dsStartingAge[race, C_Class.CLERIC].sides * GDConsts.dsStartingAge[race,
                       C_Class.CLERIC].num;
        C_Class.CLERIC_THIEF: age := GDConsts.dsStartingAge[race, C_Class.CLERIC].base +
                   GDConsts.dsStartingAge[race, C_Class.CLERIC].sides * GDConsts.dsStartingAge[race,
                       C_Class.CLERIC].num;
        C_Class.FIGHTER_MAGE: age := GDConsts.dsStartingAge[race, C_Class.MAGE].base +
                   GDConsts.dsStartingAge[race, C_Class.MAGE].sides * GDConsts.dsStartingAge[race,
                       C_Class.MAGE].num;
        C_Class.FIGHTER_THIEF: age := GDConsts.dsStartingAge[race, C_Class.FIGHTER].base +
                   GDConsts.dsStartingAge[race, C_Class.FIGHTER].sides * GDConsts.dsStartingAge[race,
                       C_Class.FIGHTER].num;
        C_Class.FIGHTER_MAGE_THIEF: age := GDConsts.dsStartingAge[race, C_Class.MAGE].base +
                   GDConsts.dsStartingAge[race, C_Class.MAGE].sides * GDConsts.dsStartingAge[race,
                       C_Class.MAGE].num;
        C_Class.MAGE_THIEF: age := GDConsts.dsStartingAge[race, C_Class.MAGE].base +
                   GDConsts.dsStartingAge[race, C_Class.MAGE].sides * GDConsts.dsStartingAge[race,
                       C_Class.MAGE].num;
      end;
  { stat roll / derived / keep loop }
  savedCur := GDVars.curChar;
  GDVars.curChar := creature;
  ViewChar.DisplayChar(GDVars.curChar);
  repeat
    creature^.strExc := 0;
    for i := 0 to 5 do begin
      creature^.stats[i] := 0;
      for j := 1 to 6 do begin
        roll := Dice.RollDice(3, 6);
        { racial adjustment; the racial limits below still apply }
        if (creature^.race >= C_Race.DWARF) and (creature^.race <= C_Race.HUMAN) then
          roll := roll + GDConsts.raceAbilityAdj[creature^.race].values[i];
        if creature^.stats[i] < roll then
          creature^.stats[i] := roll;
      end;
      with creature^ do
        case i of
          { Strength }
          C_Abil.STRENGTH: begin
               if (stats[i] > 0) and (GDConsts.ageCat[race].youngAdult < age) then
                 Inc(stats[i]);
               if (stats[i] > 0) and (GDConsts.ageCat[race].mature < age) then
                 Dec(stats[i]);
               if (stats[i] > 0) and (GDConsts.ageCat[race].middleAged < age) then
                 Dec(stats[i], 2);
               if (stats[i] > 0) and (GDConsts.ageCat[race].old < age) then
                 Dec(stats[i]);
               ClampToLimits(i);
               if (stats[C_Abil.STRENGTH] = 18) and (CharHlp.WarriorLevel(creature) > 0) then begin
                 strExc := Random(100) + 1;
                 if GDConsts.dsMinimumMaximumStatistics[race].excMax[genderSp] < strExc then
                   strExc := GDConsts.dsMinimumMaximumStatistics[race].excMax[genderSp];
               end;
             end;
          { Intelligence }
          C_Abil.INTELLIGENCE: begin
               if GDConsts.ageCat[race].mature < age then
                 Inc(stats[i]);
               if GDConsts.ageCat[race].old < age then
                 Inc(stats[i]);
               ClampToLimits(i);
             end;
          { Wisdom }
          C_Abil.WISDOM: begin
               if GDConsts.ageCat[race].youngAdult >= age then
                 Dec(stats[i]);
               if GDConsts.ageCat[race].mature < age then
                 Inc(stats[i]);
               if GDConsts.ageCat[race].middleAged < age then
                 Inc(stats[i]);
               if GDConsts.ageCat[race].old < age then
                 Inc(stats[i]);
               ClampToLimits(i);
               if stats[i] < 13 then
                 { cleric multiclasses need Wisdom 13 }
                 if charClass in [C_Class.CLERIC_FIGHTER..C_Class.CLERIC_THIEF] then
                   stats[i] := 13;
             end;
          { Dexterity }
          C_Abil.DEXTERITY: begin
               if GDConsts.ageCat[race].middleAged < age then
                 Dec(stats[i], 2);
               if GDConsts.ageCat[race].old < age then
                 Dec(stats[i]);
               ClampToLimits(i);
             end;
          { Constitution }
          C_Abil.CONSTITUTION: begin
               { the DMG's young adult +1, kept when mature; middle age, old and venerable each take 1 off. SSI left
                 out the +1, so every age came out one lower (#704). }
               Inc(stats[i]);
               if GDConsts.ageCat[race].mature < age then
                 Dec(stats[i]);
               if GDConsts.ageCat[race].middleAged < age then
                 Dec(stats[i]);
               if GDConsts.ageCat[race].old < age then
                 Dec(stats[i]);
               ClampToLimits(i);
             end;
          { Charisma }
          C_Abil.CHARISMA: begin
               ClampToLimits(i);
             end;
        end;
      ViewChar.PrintStat(i, False);
    end;
    { thief skills use the Dexterity just rolled }
    if creature^.classLevels[C_Level.THIEF] > 0 then
      ClassCal.RecalcThiefSkills(Types.PCharRecord(creature));
    with creature^ do begin
      hpCur := hpMax;
      attacks := 2;
      unarmedRollsA[1] := 1;
      unarmedDiceA[1] := 2;
      useStrength := 1;
      movementBase := 12;
      { hpTotal sums each class's starting-gold dice (dsStartingGoldClass); gold = sum * 10 div class count }
      hpTotal := 0;
      clsCount := 0;
      for cls := C_Level.CLERIC to C_Level.MONK do
        if classLevels[cls] > 0 then begin
          case cls of
            C_Level.CLERIC: clericSpells[1] := 1;
            C_Level.MAGE: mageSpells[1] := 1;
          end;
          Inc(hpTotal,
              Dice.RollDice(GDConsts.dsStartingGoldClass[cls].num, GDConsts.dsStartingGoldClass[cls].sides));
          Inc(clsCount);
          case cls of
            C_Level.CLERIC: begin
                 ClassCal.AwardWisdomBonus(Types.PCharRecord(creature));
                 for slot := 1 to SizeOf(spellsKnown) div SizeOf(spellsKnown[1]) do
                   with GDConsts.spellTable[slot] do
                     if (castClass = 0) and (level = 1) then
                       spellsKnown[slot] := 1;
               end;
            C_Level.MAGE: begin
                 { Detect Magic }
                 spellsKnown[11] := 1;
                 { Read Magic }
                 spellsKnown[18] := 1;
                 { Shield }
                 spellsKnown[19] := 1;
                 { Sleep }
                 spellsKnown[21] := 1;
               end;
          end;
        end;
      coins[C_Money.GOLD] := hpTotal * 10 div clsCount;
      { Hit points: roll every class, add the Con bonus and divide by the class count (1 if a negative bonus would leave
        too little) }
      hpRolled := ClassCal.RollFirstLevelHp(creature, $FF);
      hpMax := hpRolled;
      conB := ClassCal.ConHpBonus(creature, $FF);
      if conB < 0 then begin
        if hpMax > Abs(conB) + clsCount then
          hpMax := (hpMax + conB) div clsCount
        else
          hpMax := 1;
      end else
        hpMax := (hpMax + conB) div clsCount;
      hpCur := hpMax;
      hpRolled := hpRolled div clsCount;
    end;
    ViewChar.PrintCombatStats;
    ViewChar.PrintMoney;
    ch := MenuCore.YesNoMenu('Keep this character? ', LightMagenta, LightGreen, White);
  until ch = 'Y';
  ViewChar.DisplayChar(GDVars.curChar);
  GDVars.curChar := savedCur;
  repeat
    creature^.name := TextRend.ReadString('Character name: ', LightMagenta, Types.NAME_LEN);
  until creature^.name <> '';
  savedCur := GDVars.curChar;
  GDVars.curChar := creature;
  CharGen.CustomizePortrait(False);
  { the icon editor draws over the sheet the picker cleared }
  ViewChar.DisplayChar(GDVars.curChar);
  CharGen.CustomizeIcon;
  while not SaveLoad.SaveChar(Types.PCharRecord(creature), '') and
        (MenuCore.YesNoMenu('Try again? ', Yellow, LightGreen, White) = 'Y') do
    ;
  GDVars.curChar := savedCur;
  { with its racial effects }
  SaveLoad.FreeCreature(creature);
end;

{ DropCharacterMenu: Ask twice, then drop curChar from the party with RemoveCreature (freeing it and its icon); the
  farewell message depends on whether the character is enabled. Declining shows the relief line, shortened for a name
  too long for SSI's wording to fit the 40-column bottom row. }
procedure DropCharacterMenu;
begin
  if GDVars.curChar = nil then Exit;
  with GDVars.curChar^ do begin
    if (MenuCore.YesNoMenu('Drop ' + name + ' forever? ', Yellow, LightGreen, White) = 'Y') and
        (MenuCore.YesNoMenu('Are you sure? ', Yellow, LightGreen, White) = 'Y') then
    begin
      if enabled = 0 then
        CharDisp.PrintBottomLine('You dump ' + name + ' out back.')
      else
        CharDisp.PrintBottomLine(name + ' bids you farewell.');
      SaveLoad.RemoveCreature(False, True);
    end else if Length(name) + Length(' breathes a sigh of relief.') <= 40 then
      CharDisp.PrintBottomLine(name + ' breathes a sigh of relief.')
    else
      { a name of 14 or 15 letters takes the shorter line, which fits the bottom row (#766) }
      CharDisp.PrintBottomLine(name + ' sighs with relief.');
  end;
end;

function Modifiable: Boolean;
begin
  Modifiable := (GDVars.curChar^.race >= C_Race.DWARF) and (GDVars.curChar^.race <= C_Race.HUMAN) and
                (GDVars.curChar^.charClass >= 0) and (GDVars.curChar^.charClass <= 16);
end;

{ ModifyCharacterMenu: Modify Character on the main menu: ModifyCharacter for a Modifiable character with no
  experience. }
procedure ModifyCharacterMenu;
begin
  if (GDVars.curChar^.experience > 0) or not CharGen.Modifiable then
    TextRend.PrintAndPause(GDVars.curChar^.name + ' can''t be modified.', Yellow)
  else
    CharGen.ModifyCharacter(False);
end;

{ ModifyCharacter: Up and Down pick a row (6 = hit points); Left and Right lower or raise it within racial, class and
  hit-point limits. Keep recalculates a thief's skills for the new Dexterity and, unless levelled, sets
  npcTreasureShare to 1; Exit restores the saved attributes, strExc, hpMax (and, levelled, hpCur) and cleric spell
  slots. A lowered attribute stops at the higher of the racial and class minimums; one already at 0 is not lowered
  further, so it rises to that minimum. }
procedure ModifyCharacter(levelled: Boolean);
var
  savedStats: array[0..5] of Byte;
  savedExc: Byte;
  savedHp: Byte;
  savedHpCur: Byte;
  savedClericSpells: array[1..3] of Byte;
  hold: ShortInt;
  key: Char;
  ext: Boolean;
  statIdx: Byte;
  oldCon: Byte;
  hpShift: Integer;

  { RedrawStat: Repaint the selected row: an attribute via ViewChar.PrintStat, or the hit-point line (row 6) via
    CharDisp.PrintHitPoints; hotPink highlights it }
  procedure RedrawStat(hotPink: Boolean);
  begin
    if statIdx < 6 then
      ViewChar.PrintStat(statIdx, hotPink)
    else
      CharDisp.PrintHitPoints(Types.PCharRecord(GDVars.curChar), 4, 18, hotPink);
  end;

  { StatMinimum: The lowest value the selected attribute may be lowered to: racialMin, or the class minimum when that
    is higher }
  function StatMinimum(racialMin: Byte): Byte;
  begin
    if ClassCal.ClassAbilityMin(GDVars.curChar^.charClass, statIdx) > racialMin then
      StatMinimum := ClassCal.ClassAbilityMin(GDVars.curChar^.charClass, statIdx)
    else
      StatMinimum := racialMin;
  end;

  { Left on ability a: up to the larger of its racial and class minimums. }
  procedure RaiseToMinimum(a: ShortInt);
  begin
    with GDVars.curChar^ do
      if stats[a] < StatMinimum(ClassCal.RaceAbilityMin(race, genderSp, a)) then
        stats[a] := StatMinimum(ClassCal.RaceAbilityMin(race, genderSp, a));
  end;

  { Right on ability a: down to its racial maximum. }
  procedure LowerToMaximum(a: ShortInt);
  begin
    with GDVars.curChar^ do
      if stats[a] > ClassCal.RaceAbilityMax(race, genderSp, a) then
        stats[a] := ClassCal.RaceAbilityMax(race, genderSp, a);
  end;

  { Levelled, the hit points a Constitution change from oldCon gives or takes over every hit die, damage kept. }
  procedure ShiftHp;
  begin
    with GDVars.curChar^ do begin
      hpShift := ClassCal.ConHpTotal(Types.PCharRecord(GDVars.curChar), stats[C_Abil.CONSTITUTION]) -
                 ClassCal.ConHpTotal(Types.PCharRecord(GDVars.curChar), oldCon);
      if hpMax + hpShift < 1 then
        hpShift := 1 - hpMax;
      hpMax := hpMax + hpShift;
      if hpCur + hpShift < 0 then
        hpCur := 0
      else
        hpCur := hpCur + hpShift;
    end;
  end;

  { Levelled, hpMax moved by k within the levels' limits, damage kept. }
  procedure StepHp(k: Integer);
  var
    dmg: Integer;
    hp: Integer;
  begin
    with GDVars.curChar^ do begin
      dmg := hpMax - hpCur;
      hp := hpMax + k;
      if hp > ClassCal.HpMaximum(GDVars.curChar) then
        hp := ClassCal.HpMaximum(GDVars.curChar);
      if hp < ClassCal.HpMinimum(GDVars.curChar) then
        hp := ClassCal.HpMinimum(GDVars.curChar);
      if hp < 1 then
        hp := 1;
      hpMax := hp;
      if hp - dmg < 0 then
        hpCur := 0
      else
        hpCur := hp - dmg;
    end;
  end;

begin
  if not CharGen.Modifiable then begin
    TextRend.PrintAndPause(GDVars.curChar^.name + ' can''t be modified.', Yellow);
    Exit;
  end;
  ViewChar.DisplayChar(GDVars.curChar);
  Move(GDVars.curChar^.stats, savedStats, SizeOf(GDVars.curChar^.stats));
  savedExc := GDVars.curChar^.strExc;
  savedHp := GDVars.curChar^.hpMax;
  savedHpCur := GDVars.curChar^.hpCur;
  { a Wisdom change recalculates the cleric spell slots }
  Move(GDVars.curChar^.clericSpells, savedClericSpells, SizeOf(savedClericSpells));
  statIdx := 6;
  RedrawStat(False);
  statIdx := 0;
  RedrawStat(True);
  with GDVars.curChar^ do begin
    repeat
      MenuCore.arrowsToCaller := True;
      key := MenuCore.MenuHorizontal('Modify character: ', 'Keep Exit', LightMagenta, LightGreen,
                                     White, True, False, ext);
      RedrawStat(False);
      oldCon := stats[C_Abil.CONSTITUTION];
      if ext then
        case key of
          C_Keys.DOWN, C_Keys.ENTER:
            begin
              Inc(statIdx);
              if statIdx > 6 then
                statIdx := 0;
            end;
          C_Keys.UP:
            begin
              Dec(statIdx);
              if statIdx = 255 then
                statIdx := 6;
            end;
          { Left = decrease }
          C_Keys.LEFT:
            if statIdx < 6 then begin
              hold := statIdx;
              if stats[hold] > 0 then
                Dec(stats[hold]);
              case hold of
                C_Abil.STRENGTH: if strExc > 0 then begin
                     Dec(strExc);
                     Inc(stats[hold]);
                   end else
                     RaiseToMinimum(hold);
                C_Abil.WISDOM: begin
                     RaiseToMinimum(hold);
                     { Only clericSpells[1] is reset; [2] and [3] are not, so each keypress would re-award their bonus
                       with no ceiling (they are 0 for a new first-level character) }
                     if clericSpells[1] > 0 then
                       clericSpells[1] := 1;
                     ClassCal.AwardWisdomBonus(Types.PCharRecord(GDVars.curChar));
                   end;
                C_Abil.CONSTITUTION: begin
                     RaiseToMinimum(hold);
                     if levelled then
                       ShiftHp
                     else begin
                       if ClassCal.HpMaximum(GDVars.curChar) < hpMax then
                         hpMax := ClassCal.HpMaximum(GDVars.curChar);
                       hpCur := hpMax;
                     end;
                     statIdx := 6;
                     RedrawStat(False);
                     statIdx := C_Abil.CONSTITUTION;
                   end;
              else
                { Intelligence, Dexterity, Charisma }
                RaiseToMinimum(hold);
              end;
            end else
            { HP row }
            if levelled then
              StepHp(-1)
            else begin
              Dec(hpMax);
              if ClassCal.HpMinimum(GDVars.curChar) > hpMax then
                hpMax := ClassCal.HpMinimum(GDVars.curChar);
              hpCur := hpMax;
            end;
          { Right = increase }
          C_Keys.RIGHT:
            if statIdx < 6 then begin
              hold := statIdx;
              Inc(stats[hold]);
              case hold of
                C_Abil.STRENGTH: if stats[hold] > ClassCal.RaceAbilityMax(race, genderSp, hold) then begin
                     if (stats[hold] > 18) and (CharHlp.WarriorLevel(GDVars.curChar) > 0) and
                         (GDConsts.dsMinimumMaximumStatistics[race].excMax[genderSp] > strExc) then
                       Inc(strExc);
                     stats[hold] := ClassCal.RaceAbilityMax(race, genderSp, hold);
                   end;
                C_Abil.WISDOM: begin
                     LowerToMaximum(hold);
                     { clericSpells[1] only, same shape as the Left arm above }
                     if clericSpells[1] > 0 then
                       clericSpells[1] := 1;
                     ClassCal.AwardWisdomBonus(Types.PCharRecord(GDVars.curChar));
                   end;
                C_Abil.CONSTITUTION: begin
                     LowerToMaximum(hold);
                     if levelled then
                       ShiftHp
                     else begin
                       if ClassCal.HpMinimum(GDVars.curChar) > hpMax then
                         hpMax := ClassCal.HpMinimum(GDVars.curChar);
                       hpCur := hpMax;
                     end;
                     statIdx := 6;
                     RedrawStat(False);
                     statIdx := C_Abil.CONSTITUTION;
                   end;
              else
                { Intelligence, Dexterity, Charisma }
                LowerToMaximum(hold);
              end;
            end else
            { HP row }
            if levelled then
              StepHp(1)
            else begin
              Inc(hpMax);
              if ClassCal.HpMaximum(GDVars.curChar) < hpMax then
                hpMax := ClassCal.HpMaximum(GDVars.curChar);
              hpCur := hpMax;
            end;
        end else
        case key of
          'E', C_Keys.NONE:
            begin
              for hold := 0 to 5 do
                GDVars.curChar^.stats[hold] := savedStats[hold];
              GDVars.curChar^.strExc := savedExc;
              GDVars.curChar^.hpMax := savedHp;
              GDVars.curChar^.hpCur := hpMax;
              if levelled then
                GDVars.curChar^.hpCur := savedHpCur;
              Move(savedClericSpells, GDVars.curChar^.clericSpells, SizeOf(savedClericSpells));
              CharHlp.RecalcStats(Types.PCharRecord(GDVars.curChar));
              Exit;
            end;
        end;
      CharHlp.RecalcStats(Types.PCharRecord(GDVars.curChar));
      ViewChar.PrintCombatStats;
      RedrawStat(True);
    until (not ext) and (key = 'K');
    if classLevels[C_Level.THIEF] > 0 then
      ClassCal.RecalcThiefSkills(Types.PCharRecord(GDVars.curChar));
    if not levelled then
      GDVars.curChar^.npcTreasureShare := 1;
  end;
end;

{ GainLevels: curChar gains a level in each of its classes in mask (GDConsts.classBit), as training gives it: with
  restoreDrain, one drained level is restored for each; base skills are recalculated; a new magic-user level picks one
  spell; hit points grow by the rolled dice (and, for hpMax, the classes' Con bonus) divided by the class count, at
  least 1, damage kept. }
procedure GainLevels(trainable: Byte; restoreDrain: Boolean);
var
  clsCount: Byte;
  rolled: Integer;
  gain: Integer;
  dmg: Byte;
  cls: ShortInt;
  conB: Integer;
  oldMage: ShortInt;
  sel: Byte;
  idx: Integer;
  notEmpty: Boolean;
begin
  with GDVars.curChar^ do begin
    clsCount := 0;
    oldMage := classLevels[C_Level.MAGE];
    for cls := C_Level.CLERIC to C_Level.MONK do
      if classLevels[cls] > 0 then begin
        Inc(clsCount);
        if GDConsts.classBit[cls] and trainable > 0 then begin
          Inc(classLevels[cls]);
          if restoreDrain and (drainedLevels > 0) then begin
            Dec(drainedHps, drainedHps div drainedLevels);
            Dec(drainedLevels);
          end;
        end;
      end;
    ClassCal.RecalcBaseSkills(Types.PCharRecord(GDVars.curChar));
    if classLevels[C_Level.MAGE] > oldMage then begin
      idx := -1;
      repeat
        sel := Magic.SpellMenu(4, 4, idx, notEmpty);
      until (sel > 0) or (not notEmpty);
      { SpellMenu returns 0 when there is no spell left to learn; spellsKnown starts at 1 }
      if sel > 0 then
        spellsKnown[sel] := 1;
    end;
    rolled := ClassCal.RollFirstLevelHp(GDVars.curChar, trainable);
    gain := rolled div clsCount;
    if gain = 0 then
      gain := 1;
    Inc(hpRolled, gain);
    conB := ClassCal.ConHpBonus(GDVars.curChar, trainable);
    gain := (rolled + conB) div clsCount;
    if gain < 1 then
      gain := 1;
    dmg := hpMax - hpCur;
    Inc(hpMax, gain);
    hpCur := hpMax - dmg;
  end;
end;

{ TrainingMenu: Train curChar for 1000 gp. Refuses characters that are not C_Status.OKAY, have under 1000 gp, have no
  class this hall trains (C_Gbvm.TRAIN_CLASS_MASK) or lack the experience; stingMode skips these checks and the fee,
  but not the class and level limits, so a character with no class left to train is still sent away.
  Applies the racial fighter (and half-elf cleric and ranger) level caps by permanent Strength (CharHlp.AtLevelCap).
  A character who trains has experience clamped to one below the highest level + 2 threshold it has reached. Each
  trained class gains a level and restores one drained level; a new magic-user level picks one spell; hit points grow
  by the rolled dice (and, for hpMax, the trained classes' Con bonus) divided by the class count, at least 1, as
  GainLevels gives them. }
procedure TrainingMenu;
var
  xpClamp: LongInt;
  nextXp: LongInt;
  trainMask: Byte;
  classMask: Byte;
  trainable: Byte;
  cls: ShortInt;
  row: ShortInt;
  lvl: ShortInt;
begin
  if (GDVars.curChar^.status <> C_Status.OKAY) and (stingMode = 0) then begin
    TextRend.PrintAndPause('we only train conscious people', Yellow);
    Exit;
  end;
  if (MoneyCal.CreatureGold(Types.PCharRecord(GDVars.curChar)) < 1000) and (stingMode = 0) then begin
    TextRend.PrintAndPause('Training costs 1000 gp.', Yellow);
    Exit;
  end;
  trainMask := 0;
  classMask := 0;
  with GDVars.curChar^ do begin
    xpClamp := 0;
    for cls := C_Level.CLERIC to C_Level.MONK do
      if classLevels[cls] > 0 then begin
        Inc(classMask, GDConsts.classBit[cls]);
        lvl := classLevels[cls];
        { xp[] runs to level 9 }
        if (not CharHlp.AtLevelCap(Types.PCharRecord(GDVars.curChar), cls)) and (lvl < 9) then
          if (GDConsts.dsExperienceSpellsClass[cls].xp[Succ(lvl)] <= experience) or (stingMode <> 0) then
            if GDConsts.dsExperienceSpellsClass[cls].xp[Succ(lvl)] > 0 then begin
              Inc(trainMask, GDConsts.classBit[cls]);
              if lvl < 8 then
                nextXp := GDConsts.dsExperienceSpellsClass[cls].xp[Succ(Succ(lvl))]
              else
                nextXp := 0;
              if nextXp > 0 then
                if experience >= nextXp then
                  if nextXp > xpClamp then
                    xpClamp := nextXp - 1;
            end;
      end;
    if stingMode = 0 then begin
      if Byte(classMask and GDVars.zone1^[C_Gbvm.TRAIN_CLASS_MASK]) = 0 then begin
        TextRend.PrintAndPause('We don''t train that class here', Yellow);
        Exit;
      end else if Byte(trainMask and GDVars.zone1^[C_Gbvm.TRAIN_CLASS_MASK]) = 0 then begin
        TextRend.PrintAndPause('Not Enough Experience', Yellow);
        Exit;
      end;
    end;
    if stingMode = 0 then
      trainable := trainMask and GDVars.zone1^[C_Gbvm.TRAIN_CLASS_MASK]
    else
      trainable := trainMask;
    { free training passes the hall's checks with every class at its limit: GainLevels would then gain no level and
      still add a hit point (#703) }
    if trainable = 0 then begin
      TextRend.PrintAndPause('No class can train further', Yellow);
      Exit;
    end;
    Border.ClearBox(C_Msg.TEXT_LEFT, C_Msg.TEXT_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
    row := 4;
    CharDisp.DisplayCreatureName(Types.PCharRecord(GDVars.curChar), 4, row, False);
    TextRend.DisplayString(Length(name) + 4, row, LightGreen, ' will become:');
    for cls := C_Level.CLERIC to C_Level.MONK do
      if classLevels[cls] > 0 then
        if GDConsts.classBit[cls] and trainable > 0 then begin
          Inc(row);
          if row = 5 then
            TextRend.DisplayString(6, row, LightGreen,
                                   '    a level ' + StrUtil.NumStr(classLevels[cls] + 1) + ' ' +
                                     GDConsts.classNames[cls])
          else
            TextRend.DisplayString(6, row, LightGreen,
                                   'and a level ' + StrUtil.NumStr(classLevels[cls] + 1) + ' ' +
                                     GDConsts.classNames[cls]);
        end;
    if MenuCore.YesNoMenu('Do you wish to train? ', LightMagenta, LightGreen, White) <> 'Y' then
      Exit;
    CharDisp.PrintBottomLine('Congratulations...');
    if stingMode = 0 then
      Money.PayFromCreature(Types.PCharRecord(GDVars.curChar), 1000);
    { only a character who trains loses the experience past the level + 2 threshold: SSI cut it before the hall's
      checks and the question, so a refusal or a No kept the cut (#701) }
    if xpClamp > 0 then
      experience := xpClamp;
    CharGen.GainLevels(trainable, True);
  end;
end;

{ AddCharacterMenu: Pick characters from the CHARLIST.TXT roster (SaveLoad.LoadCharlist), load each with
  SaveLoad.LoadChar and add it to the party unless already there (same name and randByte) or its record is short or
  unreadable, which the bottom line reports as a damaged file until a key: at most 6 non-NPCs and 8 members in all.
  Curse's party rules also apply: a paladin does not join a party with an evil member, nor an evil character a party
  with a paladin, and a party has at most 3 rangers. A character they refuse gets Curse's message on the bottom line
  until a key, keeps its unmarked name and is freed. The first character into an empty party joins unchecked, as do
  NPCs a script adds.
  Added entries get a leading '* ' and the roster is saved back, the added ones still on it (SaveLoad.SaveCharlist). }
procedure AddCharacterMenu;
var
  list: Types.PItemRec;
  m: Types.PItemRec;
  creature: Types.PCharRecord;
  p: Types.PCharRecord;
  idx: Integer;
  key: Char;
  redraw: Boolean;
  nonNpc: Byte;
  rangers: Byte;
  hasEvil: Boolean;
  paladin: Types.PCharRecord;
  newEvil: Boolean;
  newPaladin: Boolean;
begin
  Border.ClearBox(C_Msg.TEXT_LEFT, C_Msg.TEXT_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
  SaveLoad.LoadCharlist(list);
  if list = nil then Exit;
  idx := 0;
  m := list;
  redraw := True;
  { the until clause reads nonNpc after every key, including Space and a party member's entry, which add nothing }
  nonNpc := 0;
  repeat
    { the menu string already holds Exit, so MenuVertical adds none }
    key := MenuCore.MenuVertical('Add a character: ', 'Add Exit', LightMagenta, LightGreen, White,
                                 1, 2, 38, 22, list, False, redraw, idx, m);
    if (key = C_Keys.ENTER) or (key = 'A') then
      if m^.name[1] <> '*' then
      begin
        GetMem(creature, SizeOf(Types.TCharRecord));
        nonNpc := 0;
        { a short or unreadable .cha is not added and keeps its unmarked name; the bottom line says so until a key,
          as the put-save-disk prompt does, with the name cut to fit the line }
        if not SaveLoad.LoadChar(m^.name, Types.PCharRecord(creature), False, True) then begin
          FreeMem(creature, SizeOf(Types.TCharRecord));
          TextRend.DisplayAndPause(Yellow, Copy(m^.name, 1, 21) + '''s file is damaged.');
          Border.ClearBox(0, 24, 39, 24);
        end else begin
          m^.name := '* ' + m^.name;
          if GDVars.creatureList = nil then begin
            GDVars.zone1^[C_Gbvm.PARTY_SIZE] := 0;
            SaveLoad.AddCharToParty(Types.PCharRecord(creature));
            SaveLoad.LoadCharIconAnim(True);
          end else begin
            rangers := 0;
            hasEvil := False;
            paladin := nil;
            p := GDVars.creatureList;
            while (p <> nil) and ((p^.name <> creature^.name) or (p^.randByte <> creature^.randByte)) do begin
              { C_Npc.FLAG clear }
              if not CharHlp.IsNpc(p) then
                Inc(nonNpc);
              if p^.classLevels[C_Level.RANGER] > 0 then
                Inc(rangers);
              if p^.alignment in [C_Align.LAWFUL_EVIL, C_Align.NEUTRAL_EVIL, C_Align.CHAOTIC_EVIL] then
                hasEvil := True;
              if p^.classLevels[C_Level.PALADIN] > 0 then
                paladin := p;
              p := p^.nextCharAddr;
            end;
            newPaladin := creature^.classLevels[C_Level.PALADIN] > 0;
            newEvil := creature^.alignment in [C_Align.LAWFUL_EVIL, C_Align.NEUTRAL_EVIL, C_Align.CHAOTIC_EVIL];
            if (p = nil) and
                ((newPaladin and hasEvil) or ((creature^.classLevels[C_Level.RANGER] > 0) and (rangers >= 3)) or
                 (newEvil and (paladin <> nil))) then begin
              { refused by the party rules: unmarked, so it stays on the roster; the reason stays up until a key }
              Delete(m^.name, 1, 2);
              if newPaladin and hasEvil then
                TextRend.DisplayAndPause(Yellow, 'paladins do not join with evil scum')
              else if (creature^.classLevels[C_Level.RANGER] > 0) and (rangers >= 3) then
                TextRend.DisplayAndPause(Yellow, 'too many rangers in party')
              else
                TextRend.DisplayAndPause(Yellow, paladin^.name + ' will tolerate no evil!');
              Border.ClearBox(0, 24, 39, 24);
              SaveLoad.FreeCreature(Types.PCharRecord(creature));
            end
            { Add if not already in the party and the party is under 8: a non-NPC (C_Npc.FLAG clear) while under 6
              non-NPCs, or an NPC (C_Npc.FLAG set). v1.3 took a non-NPC into a full party with 3 or more NPCs as a
              ninth member. }
            else if (p = nil) and (GDVars.zone1^[C_Gbvm.PARTY_SIZE] < Types.MAX_PARTY) and
                (CharHlp.IsNpc(creature) or (nonNpc < 6)) then begin
              SaveLoad.AddCharToParty(Types.PCharRecord(creature));
              SaveLoad.LoadCharIconAnim(True);
              { C_Npc.FLAG clear }
              if not CharHlp.IsNpc(creature) then
                Inc(nonNpc);
            end else begin
              { one the party has no room for is unmarked, to be picked again }
              if p = nil then
                m^.name := Copy(m^.name, 3, Length(m^.name) - 2);
              { with the items and effects LoadChar read }
              SaveLoad.FreeCreature(Types.PCharRecord(creature));
            end;
          end;
        end;
      end;
  until (key = 'E') or (key = C_Keys.NONE) or (nonNpc > 5) or (GDVars.zone1^[C_Gbvm.PARTY_SIZE] >= Types.MAX_PARTY);
  SaveLoad.SaveCharlist(list);
  MenuCore.FreeStringList(list);
end;

{ CustomizePortrait: The portrait picker, on its own bordered page. Three heads sit over three bodies; the middle
  column, framed, is the current pick and the others are the previous and next in GDConsts.headTbl/bodyTbl, wrapping
  at the ends of the entries offered (Portrait.PlayerPortraitCount: all of them once the merged archives are read).
  Head and Body (or Up and Down) choose the row; Next and Prev (or Left and Right) step through it. Keep (or Space, or
  Enter while Keep is the current option) shows the pick alone and asks whether it is ok: Yes keeps it, No goes back to
  choosing. With canCancel (camp's Alter), Escape leaves the picker and restores the head and body the character
  had; without it (character creation) there is no way out but choosing a portrait. A head or body number past the
  ones offered starts at 1. The caller redraws its screen afterwards. (SSI's picker cycled the head or body with H
  and B under the sheet's portrait, forward only.) }
procedure CustomizePortrait(canCancel: Boolean);
const
  PIC_COL: array[0..2] of Byte = (2, 14, 26);
  PIC_ROW = 4;
  { the hint under the counts }
  HINT_ROW = 20;
var
  key: Char;
  ext: Boolean;
  onBody: Boolean;
  done: Boolean;
  heads: array[0..2] of Types.PImgBuf;
  bodies: array[0..2] of Types.PImgBuf;
  diskCh: String[1];
  i: Byte;
  step: Integer;
  { how many heads and bodies are offered (Portrait.PlayerPortraitCount) }
  nHeads: Byte;
  nBodies: Byte;
  { the portrait on entry, which Escape restores }
  savedHead: Byte;
  savedBody: Byte;

  { Wrap: The table position k steps from cur in a table of n, wrapping at the ends }
  function Wrap(cur: Byte; k: Integer; n: Byte): Byte;
  begin
    Wrap := ((Integer(cur) - 1 + k + n) mod n) + 1;
  end;

  { ShowRow: Load and draw the heads (or bodies) around the current pick }
  procedure ShowRow(body: Boolean);
  var
    k: Integer;
  begin
    with GDVars.curChar^ do
      for k := -1 to 1 do
        if body then begin
          Blit.LoadPic('BODY' + diskCh, GDConsts.bodyTbl[Wrap(portraitBody, k, nBodies)], False, 0, bodies[k + 1]);
          Portrait.DisplayImageBuf(PIC_COL[k + 1], PIC_ROW + 5, False, bodies[k + 1]);
        end else begin
          Blit.LoadPic('HEAD' + diskCh, GDConsts.headTbl[Wrap(portraitHead, k, nHeads)], False, 0, heads[k + 1]);
          Portrait.DisplayImageBuf(PIC_COL[k + 1], PIC_ROW, False, heads[k + 1]);
        end;
  end;

  { Centered: Print s centred between the margins (columns 2..37) on row, clearing the row first }
  procedure Centered(row, color: Byte; s: Types.TStr40);
  begin
    Border.ClearBox(2, row, 37, row);
    TextRend.DisplayCentered(2, 37, row, color, s);
  end;

  { ShowCounts: The "Head  7 of 41" and "Body  3 of 21" lines, the row being changed in white and the other in green }
  procedure ShowCounts;
  var
    col: Byte;
  begin
    with GDVars.curChar^ do begin
      if onBody then col := LightGreen else col := White;
      Centered(17, col, 'Head ' + StrUtil.PadLeft(StrUtil.NumStr(portraitHead), 2) + ' of ' + StrUtil.NumStr(nHeads));
      if onBody then col := White else col := LightGreen;
      Centered(18, col, 'Body ' + StrUtil.PadLeft(StrUtil.NumStr(portraitBody), 2) + ' of ' + StrUtil.NumStr(nBodies));
    end;
  end;

begin
  Str(LongInt(GDVars.virtualDisk), diskCh);
  nHeads := Portrait.PlayerPortraitCount(False);
  nBodies := Portrait.PlayerPortraitCount(True);
  for i := 0 to 2 do begin
    heads[i] := nil;
    bodies[i] := nil;
  end;
  with GDVars.curChar^ do begin
    savedHead := portraitHead;
    savedBody := portraitBody;
    if (portraitHead = 0) or (portraitHead > nHeads) then
      portraitHead := 1;
    if (portraitBody = 0) or (portraitBody > nBodies) then
      portraitBody := 1;
    TextRend.ClearScreen;
    Border.DrawBorder(C_Msg.TEXT_LEFT, C_Msg.TEXT_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, 0);
    Centered(2, White, name);
    Border.DrawBorder(PIC_COL[1], PIC_ROW, PIC_COL[1] + 10, PIC_ROW + 10, 0);
    Centered(HINT_ROW, LightGreen, 'Arrow keys for selection');
    ShowRow(False);
    ShowRow(True);
    onBody := False;
    done := False;
    { Keep, the fifth option }
    GDVars.horizChoice := 5;
    repeat
      ShowCounts;
      MenuCore.arrowsToCaller := True;
      key := MenuCore.MenuHorizontal('Portrait: ', 'Head Body Next Prev Keep', LightMagenta, LightGreen, White,
                                     True, False, ext);
      { an extended key's scan code can equal a letter (Down is 80, 'P'), so the two are told apart by ext }
      step := 0;
      if ext then
        case key of
          C_Keys.UP, C_Keys.DOWN: onBody := not onBody;
          C_Keys.LEFT: step := -1;
          C_Keys.RIGHT: step := 1;
        end
      else
        case key of
          'N': step := 1;
          'P': step := -1;
          'H': onBody := False;
          'B': onBody := True;
          { Escape }
          C_Keys.NONE: if canCancel then begin
              portraitHead := savedHead;
              portraitBody := savedBody;
              done := True;
            end;
          'K', ' ', C_Keys.ENTER: begin
              { the pick alone: no neighbours, no counts }
              Border.ClearBox(PIC_COL[0], PIC_ROW, PIC_COL[0] + 10, PIC_ROW + 10);
              Border.ClearBox(PIC_COL[2], PIC_ROW, PIC_COL[2] + 10, PIC_ROW + 10);
              Border.ClearBox(2, 17, 37, HINT_ROW);
              if MenuCore.YesNoMenu('Is this portrait ok? ', LightMagenta, LightGreen, White) = 'Y' then
                done := True
              else begin
                ShowRow(False);
                ShowRow(True);
                Centered(HINT_ROW, LightGreen, 'Arrow keys for selection');
                GDVars.horizChoice := 5;
              end;
            end;
        end;
      if step <> 0 then begin
        if onBody then
          portraitBody := Wrap(portraitBody, step, nBodies)
        else
          portraitHead := Wrap(portraitHead, step, nHeads);
        ShowRow(onBody);
      end;
    until done;
  end;
  for i := 0 to 2 do begin
    Blit.FreePic(heads[i]);
    Blit.FreePic(bodies[i]);
  end;
  TextRend.ClearBottomLine;
end;

{ CustomizeIcon: The combat-icon editor for curChar, on its own two-pane page. The left pane shows the name, the
  icon's ready and action frames, Head and Weapon (each with its place among the shapes there are), Size, the seven
  coloured parts ("1 2" beside the five with two colours) and, on the bottom line, the menu: Keep and Exit. Up and Down
  choose an item, the menu being the last; on the menu Left and Right choose Keep or Exit and Enter takes it, as K and
  E do.
  Enter on Size toggles small and large; on any other item it fills the right pane with a 4x4 grid of the icon with
  each option of that item: every head, every weapon, or the part in each of the 16 colours. The arrows move the
  game's cursor box (COMSPR 25, the square behind the active icon in combat) through the grid, turning the page past
  its last or first row, and the ready and action frames on the left show the boxed option. Enter keeps it, Escape
  goes back to the left with the icon as it was, and Space switches a two-colour part between colour 1 and colour 2.
  The menu is not offered while the grid is up. Keep asks whether the icon is ok: Yes ends the editor with the icon as
  it is and No goes back to it. Exit, or Escape on the left, ends the editor with the icon as it was when the editor
  opened. Only the field chosen is stored (iconHead, iconBody, iconSize or iconColors1), and a party member's icon in
  its slot (orderNumber) is rebuilt at the end. A page's icons are kept, so moving the box loads
  at most one frame from CHEAD or CBODY.
  (SSI's editor stepped through each choice with Next and Prev under an old and a new copy of the icon.) }
procedure CustomizeIcon;
const
  { CHEAD and CBODY each hold 14 heads and 32 weapons per size }
  NUM_HEADS = 14;
  NUM_WEAPONS = 32;
  NUM_COLORS = 16;
  { the left pane's items, in Up and Down order }
  ITEM_HEAD = 0;
  ITEM_WEAPON = 1;
  ITEM_SIZE = 2;
  FIRST_PART = 3;
  LAST_PART = 9;
  { the bottom line's menu, which MenuHorizontal draws }
  ITEM_MENU = 10;
  ITEM_NAME: array[ITEM_HEAD..LAST_PART] of String[6] = (
    'Head', 'Weapon', 'Size', 'Weapon', 'Body', 'Hair', 'Face', 'Shield', 'Arm', 'Leg');
  ITEM_COL: array[ITEM_HEAD..LAST_PART] of Byte = (2, 2, 2, 3, 3, 3, 3, 3, 3, 3);
  ITEM_ROW: array[ITEM_HEAD..LAST_PART] of Byte = (8, 9, 10, 13, 14, 15, 16, 17, 18, 19);
  { each part's iconColors1 slot }
  PART_SLOT: array[FIRST_PART..LAST_PART] of Byte = (6, 1, 4, 4, 5, 2, 3);
  { the nibble a one-colour part uses (0 low, 1 high), or 2 for a part with two colours }
  PART_NIBBLE: array[FIRST_PART..LAST_PART] of Byte = (2, 2, 0, 1, 2, 2, 2);
  COLOR_ROW = 12;
  VALUE_COL = 10;
  DIGIT_COL = 11;
  READY_COL = 3;
  ACTION_COL = 10;
  PREVIEW_ROW = 3;
  LABEL_ROW = 6;
  GRID_COL: array[0..3] of Byte = (19, 24, 29, 34);
  GRID_ROW: array[0..3] of Byte = (2, 6, 10, 14);
  { where "(more)" starts on a grid row: centred under the four columns }
  MORE_COL = 25;
  { the message panel's text rows, under its own border }
  MSG_TOP = 18;
  MSG_BOTTOM = 22;
  { an icon frame: 24 pixel rows of 3 character cells }
  ICON_H = 24;
  ICON_W = 3;
  PART_FILE: array[0..1] of String[5] = ('CHEAD', 'CBODY');
  PART_COUNT: array[0..1] of Byte = (NUM_HEADS, NUM_WEAPONS);
  { no block loaded; real blocks go up to 223 }
  NO_BLOCK = 255;

var
  key: Char;
  ext: Boolean;
  done: Boolean;
  cur: Byte;
  i: Byte;
  j: Byte;
  savedChoice: Byte;
  { the icon as it was when the editor opened, which Exit puts back }
  savedHead: Byte;
  savedBody: Byte;
  savedSize: Byte;
  savedCols: Types.TIconCols;
  { the icon shown: the stored one, or with the highlighted option while the grid is up }
  tHead: Byte;
  tBody: Byte;
  tSize: Byte;
  tCols: Types.TIconCols;
  inGrid: Boolean;
  { colour 1 or 2 (0 or 1) of a part with two colours }
  which: Byte;
  pick: Byte;
  { the last-loaded head and body of each frame, by DAX block }
  loaded: array[0..1, 0..1] of Types.PImgBuf;
  loadedBlock: array[0..1, 0..1] of Byte;
  work: Types.PImgBuf;
  cells: array[0..15] of Types.PImgBuf;
  readyPic: Types.PImgBuf;
  actionPic: Types.PImgBuf;
  shownPic: Types.PImgBuf;
  p: Types.PCharRecord;

  { PartPic: Frame frame of head (kind 0) or weapon (kind 1) id at tSize, loaded from CHEAD or CBODY on disk 3 unless
    it is the one loaded last; nil when id is past the ones there are or the block is missing }
  function PartPic(kind, id, frame: Byte): Types.PImgBuf;
  var
    block: Byte;
  begin
    PartPic := nil;
    if (kind > 1) or (frame > 1) then Exit;
    if id >= PART_COUNT[kind] then Exit;
    block := id + frame * 128;
    if tSize = 2 then
      Inc(block, 64);
    if loadedBlock[kind, frame] <> block then begin
      DaxIo.PushState(3);
      Blit.LoadPic(PART_FILE[kind], block, True, 0, loaded[kind, frame]);
      DaxIo.PopState;
      loadedBlock[kind, frame] := block;
    end;
    PartPic := loaded[kind, frame];
  end;

  { Merge: OR src's pixels onto the top rows of work and AND their transparency masks (VidOps.MergePic; a head is the
    top 8 or 10 rows of the icon), taking src's colour map }
  procedure Merge(src: Types.PImgBuf);
  begin
    if (src = nil) or (work = nil) then Exit;
    if (src^.transp = nil) or (work^.transp = nil) then Exit;
    if (src^.width <> work^.width) or (src^.imgSize = 0) or (src^.imgSize > work^.imgSize) then Exit;
    VidOps.MergePic(src, work);
    work^.map := src^.map;
  end;

  { BuildIcon: Frame frame (0 ready, 1 action) of the icon with head h, weapon b and colours c at tSize into work,
    with its transparency mask }
  procedure BuildIcon(frame, h, b: Byte; var c: Types.TIconCols);
  var
    k: Byte;
    toT: Types.TColorTab;
  begin
    if (work = nil) or (frame > 1) then Exit;
    if work^.transp = nil then Exit;
    Blit.ClearPic(work);
    Merge(PartPic(1, b, frame));
    Merge(PartPic(0, h, frame));
    for k := 0 to 15 do
      toT[k] := k;
    for k := 1 to 6 do begin
      toT[GDConsts.defIconCol[k] and $F] := c[k] and $F;
      toT[(GDConsts.defIconCol[k] + 8) and $F] := c[k] shr 4;
    end;
    VidOps.RecolorPic(toT, work);
  end;

  { Place: Draw icon frame frame (src, with its mask) into dst, in the game's cursor box (COMSPR 25 in slot 25; plain
    cyan with 4 colours) when boxed and on the plain background otherwise }
  procedure Place(src: Types.PImgBuf; frame: Byte; boxed: Boolean; dst: Types.PImgBuf);
  begin
    if dst = nil then Exit;
    { the cursor box picture needs 16 colours }
    if boxed and (Blit.ColourCount < 16) then
      FillChar(dst^.data, dst^.imgSize, GDConsts.cgaColorFill[Blit.SrcNibble(Cyan, GDConsts.dsIconColorMap)])
    else
      FillChar(dst^.data, dst^.imgSize, 0);
    if boxed and (Blit.ColourCount = 16) then
      if frame = 0 then
        VidOps.OverlayPic(GDVars.dsIconAnimation[25, 0], dst)
      else
        VidOps.OverlayPic(GDVars.dsIconAnimation[25, 1], dst);
    VidOps.OverlayPic(src, dst);
  end;

  { Compose: Frame frame of the icon with head h, weapon b and colours c into dst, in the cursor box }
  procedure Compose(frame, h, b: Byte; var c: Types.TIconCols; dst: Types.PImgBuf);
  begin
    BuildIcon(frame, h, b, c);
    Place(work, frame, True, dst);
  end;

  { OptionCount: How many options the current item has }
  function OptionCount: Byte;
  begin
    case cur of
      ITEM_HEAD: OptionCount := NUM_HEADS;
      ITEM_WEAPON: OptionCount := NUM_WEAPONS;
    else
      OptionCount := NUM_COLORS;
    end;
  end;

  { PageSize: How many options the grid page starting at option first holds. Up to 16 options fit on one page; past
    that the first page holds 12 above a "(more)" row, a later page puts a "(more)" row above them, and one with more
    after it a second below, so it holds 12 when it is the last and 8 otherwise. Pages start on a multiple of 4, so an
    option keeps its column. }
  function PageSize(first: Byte): Byte;
  var
    n: Byte;
  begin
    n := OptionCount;
    if n <= 16 then
      PageSize := n
    else if first = 0 then
      PageSize := 12
    else if n - first <= 12 then
      PageSize := n - first
    else
      PageSize := 8;
  end;

  { PageFirst: The first option of the page holding option v }
  function PageFirst(v: Byte): Byte;
  var
    first: Byte;
  begin
    first := 0;
    while (first < OptionCount) and (v >= first + PageSize(first)) do
      Inc(first, PageSize(first));
    PageFirst := first;
  end;

  { CellOf: The grid cell (0..15) option v is drawn in, below the "(more)" row of a page after the first }
  function CellOf(v: Byte): Byte;
  var
    first: Byte;
  begin
    first := PageFirst(v);
    if first > 0 then
      CellOf := v - first + 4
    else
      CellOf := v - first;
  end;

  { PartNibble: The nibble of its slot the current part changes }
  function PartNibble: Byte;
  begin
    PartNibble := 0;
    if (cur >= FIRST_PART) and (cur <= LAST_PART) then
      if PART_NIBBLE[cur] = 2 then
        PartNibble := which
      else
        PartNibble := PART_NIBBLE[cur];
  end;

  { OptionState: Change h, b or c to option opt of the current item }
  procedure OptionState(opt: Byte; var h, b: Byte; var c: Types.TIconCols);
  var
    slot: Byte;
  begin
    case cur of
      ITEM_HEAD: h := opt;
      ITEM_WEAPON: b := opt;
      FIRST_PART..LAST_PART: begin
          slot := PART_SLOT[cur];
          if PartNibble = 0 then
            c[slot] := c[slot] and $F0 or (opt and $F)
          else
            c[slot] := c[slot] and $0F or ((opt and $F) shl 4);
        end;
    end;
  end;

  { CurrentOption: The option of the current item the icon has now, or 0 when it has none of them }
  function CurrentOption: Byte;
  var
    v: Byte;
  begin
    case cur of
      ITEM_HEAD: v := tHead;
      ITEM_WEAPON: v := tBody;
    else
      if PartNibble = 0 then
        v := tCols[PART_SLOT[cur]] and $F
      else
        v := tCols[PART_SLOT[cur]] shr 4;
    end;
    if v >= OptionCount then
      v := 0;
    CurrentOption := v;
  end;

  { Counter: "n/count", n counting from 1, padded to five characters }
  function Counter(v, count: Byte): Types.TStr40;
  var
    s: Types.TStr40;
  begin
    if v < count then
      s := StrUtil.NumStr(v + 1)
    else
      s := '?';
    s := s + '/' + StrUtil.NumStr(count);
    while Length(s) < 5 do
      s := s + ' ';
    Counter := s;
  end;

  { DrawItem: Item k of the left pane and its value, white when it is the current item and green otherwise; in the
    grid, the colour not being chosen is green. The menu (ITEM_MENU) is MenuHorizontal's to draw. }
  procedure DrawItem(k: Byte);
  var
    col: Byte;
    d1: Byte;
    d2: Byte;
  begin
    if k > LAST_PART then Exit;
    if k = cur then col := White else col := LightGreen;
    TextRend.DisplayString(ITEM_COL[k], ITEM_ROW[k], col, ITEM_NAME[k]);
    case k of
      ITEM_HEAD: TextRend.DisplayString(VALUE_COL, ITEM_ROW[k], col, Counter(tHead, NUM_HEADS));
      ITEM_WEAPON: TextRend.DisplayString(VALUE_COL, ITEM_ROW[k], col, Counter(tBody, NUM_WEAPONS));
      ITEM_SIZE: if tSize = 1 then
                   TextRend.DisplayString(VALUE_COL, ITEM_ROW[k], col, 'Small')
                 else
                   TextRend.DisplayString(VALUE_COL, ITEM_ROW[k], col, 'Large');
      FIRST_PART..LAST_PART:
        if PART_NIBBLE[k] = 2 then begin
          d1 := col;
          d2 := col;
          if inGrid and (k = cur) then
            if which = 0 then
              d2 := LightGreen
            else
              d1 := LightGreen;
          TextRend.DisplayString(DIGIT_COL, ITEM_ROW[k], d1, '1');
          TextRend.DisplayString(DIGIT_COL + 2, ITEM_ROW[k], d2, '2');
        end;
    end;
  end;

  { ShowCell: Draw grid cell k's icon, in the cursor box when it is the highlight and on the plain background
    otherwise }
  procedure ShowCell(k: Byte; boxed: Boolean);
  begin
    if (k > 15) or (cells[k] = nil) then Exit;
    Place(cells[k], 0, boxed, shownPic);
    Blit.ShowPic(GRID_COL[k mod 4], GRID_ROW[k div 4], shownPic);
  end;

  { DrawGrid: Compose and draw the page of options holding pick, one cell at a time, with "(more)" on the top row when
    there is a page before it and on the bottom row when there is one after it (the font has no arrows) }
  procedure DrawGrid;
  var
    k: Byte;
    opt: Integer;
    h: Byte;
    b: Byte;
    c: Types.TIconCols;
    first: Byte;
    top: Byte;
    moreBelow: Boolean;
  begin
    first := PageFirst(pick);
    if first > 0 then top := 4 else top := 0;
    moreBelow := first + PageSize(first) < OptionCount;
    { a page of several: "(more)" shows between the cells, so the whole grid is cleared first }
    if OptionCount > 16 then
      Border.ClearBox(18, GRID_ROW[0], 38, GRID_ROW[3] + 2);
    for k := 0 to 15 do begin
      opt := first + k - top;
      if ((k < 4) and (top > 0)) or ((k >= 12) and moreBelow) then begin
        { a "(more)" row, written at its first cell }
        if k mod 4 = 0 then
          TextRend.DisplayString(MORE_COL, GRID_ROW[k div 4] + 1, LightGreen, '(more)');
      end else if opt < first + PageSize(first) then begin
        h := tHead;
        b := tBody;
        c := tCols;
        OptionState(opt, h, b, c);
        BuildIcon(0, h, b, c);
        if (cells[k] <> nil) and (work <> nil) and (cells[k]^.imgSize = work^.imgSize)
           and (cells[k]^.transp <> nil) and (work^.transp <> nil) then begin
          Move(work^.data, cells[k]^.data, work^.imgSize);
          Move(work^.transp^, cells[k]^.transp^, Blit.MaskBytes(work^.imgSize));
        end;
        ShowCell(k, opt = pick);
      end else
        Border.ClearBox(GRID_COL[k mod 4], GRID_ROW[k div 4], GRID_COL[k mod 4] + 2, GRID_ROW[k div 4] + 2);
    end;
  end;

  { ShowPreviews: Draw the ready and action frames of the icon shown, in the cursor box; the ready frame of the
    highlight is its cell's icon }
  procedure ShowPreviews;
  begin
    if inGrid then
      Place(cells[CellOf(pick)], 0, True, readyPic)
    else
      Compose(0, tHead, tBody, tCols, readyPic);
    Blit.ShowPic(READY_COL, PREVIEW_ROW, readyPic);
    Compose(1, tHead, tBody, tCols, actionPic);
    Blit.ShowPic(ACTION_COL, PREVIEW_ROW, actionPic);
  end;

  { MsgLine: Print s centred in the message panel on row }
  procedure MsgLine(row: Byte; s: Types.TStr40);
  begin
    TextRend.DisplayCentered(18, 38, row, LightGreen, s);
  end;

  { ShowMessage: The message panel: what is being chosen and the keys, or nothing on the left }
  procedure ShowMessage;
  var
    top: Byte;
  begin
    Border.ClearBox(18, MSG_TOP, 38, MSG_BOTTOM);
    if not inGrid then Exit;
    if (cur >= FIRST_PART) and (cur <= LAST_PART) and (PART_NIBBLE[cur] = 2) then
      top := MSG_TOP
    else
      top := MSG_TOP + 1;
    if cur >= FIRST_PART then
      MsgLine(top, 'Choosing ' + ITEM_NAME[cur] + ' color')
    else
      MsgLine(top, 'Choosing ' + ITEM_NAME[cur]);
    MsgLine(top + 1, 'Arrows to select,');
    MsgLine(top + 2, 'Enter to choose');
    if top = MSG_TOP then begin
      MsgLine(top + 3, 'Space toggles');
      MsgLine(top + 4, 'color 1/2');
    end;
  end;

  { Revert: Make the icon shown the stored one; a size other than small reads as large }
  procedure Revert;
  begin
    with GDVars.curChar^ do begin
      tHead := iconHead;
      tBody := iconBody;
      if iconSize = 1 then tSize := 1 else tSize := 2;
      tCols := iconColors1;
    end;
  end;

  { MovePick: Move the highlight by an arrow key. Left and Right step through the options; Up and Down move a row,
    turning the page past its first or last row and wrapping at the ends }
  procedure MovePick(arrow: Char);
  var
    n: Integer;
    v: Integer;
  begin
    n := OptionCount;
    v := pick;
    case arrow of
      C_Keys.LEFT: if v > 0 then Dec(v) else v := n - 1;
      C_Keys.RIGHT: if v < n - 1 then Inc(v) else v := 0;
      C_Keys.DOWN: if v + 4 < n then
                     Inc(v, 4)
                   else if v div 4 < (n - 1) div 4 then
                     v := n - 1
                   else
                     v := v mod 4;
      C_Keys.UP: if v >= 4 then
                   Dec(v, 4)
                 else begin
                   v := ((n - 1) div 4) * 4 + v;
                   if v > n - 1 then
                     Dec(v, 4);
                 end;
    end;
    if (v >= 0) and (v < n) then
      pick := v;
  end;

  { ChooseInGrid: Run the right pane for the current item until Enter keeps the highlighted option or Escape leaves
    the icon as it was }
  procedure ChooseInGrid;
  var
    old: Byte;
    finished: Boolean;
  begin
    inGrid := True;
    which := 0;
    pick := CurrentOption;
    { the menu's keys do nothing here }
    TextRend.ClearBottomLine;
    DrawItem(cur);
    ShowMessage;
    DrawGrid;
    ShowPreviews;
    finished := False;
    repeat
      MenuCore.arrowsToCaller := True;
      key := MenuCore.MenuHorizontal('', '', LightMagenta, LightGreen, White, True, False, ext);
      if ext then begin
        if key in [C_Keys.UP, C_Keys.DOWN, C_Keys.LEFT, C_Keys.RIGHT] then begin
          old := pick;
          MovePick(key);
          if pick <> old then begin
            OptionState(pick, tHead, tBody, tCols);
            if PageFirst(pick) <> PageFirst(old) then
              DrawGrid
            else begin
              ShowCell(CellOf(old), False);
              ShowCell(CellOf(pick), True);
            end;
            DrawItem(cur);
            ShowPreviews;
          end;
        end;
      end else
        case key of
          C_Keys.ENTER: begin
              with GDVars.curChar^ do
                case cur of
                  ITEM_HEAD: iconHead := tHead;
                  ITEM_WEAPON: iconBody := tBody;
                else
                  iconColors1 := tCols;
                end;
              finished := True;
            end;
          C_Keys.NONE: begin
              Revert;
              finished := True;
            end;
          ' ': if (cur >= FIRST_PART) and (cur <= LAST_PART) and (PART_NIBBLE[cur] = 2) then begin
              which := 1 - which;
              pick := CurrentOption;
              DrawItem(cur);
              DrawGrid;
            end;
        end;
    until finished;
    inGrid := False;
    Border.ClearBox(18, 1, 38, 16);
    ShowMessage;
    DrawItem(cur);
    ShowPreviews;
  end;

  { Confirmed: Ask whether the icon is ok on the bottom line; on No, the menu comes back there, on Keep, for more
    editing }
  function Confirmed: Boolean;
  begin
    if MenuCore.YesNoMenu('Is this icon ok? ', LightMagenta, LightGreen, White) = 'Y' then
      Confirmed := True
    else begin
      GDVars.horizChoice := 1;
      Confirmed := False;
    end;
  end;

begin
  savedChoice := GDVars.horizChoice;
  with GDVars.curChar^ do begin
    savedHead := iconHead;
    savedBody := iconBody;
    savedSize := iconSize;
    savedCols := iconColors1;
  end;
  for i := 0 to 1 do
    for j := 0 to 1 do begin
      loaded[i, j] := nil;
      loadedBlock[i, j] := NO_BLOCK;
    end;
  Blit.AllocPic(ICON_H, ICON_W, 1, 1, work);
  for i := 0 to 15 do
    Blit.AllocPic(ICON_H, ICON_W, 1, 1, cells[i]);
  Blit.AllocPic(ICON_H, ICON_W, 1, 0, readyPic);
  Blit.AllocPic(ICON_H, ICON_W, 1, 0, actionPic);
  Blit.AllocPic(ICON_H, ICON_W, 1, 0, shownPic);
  inGrid := False;
  which := 0;
  pick := 0;
  cur := ITEM_HEAD;
  Revert;
  TextRend.ClearScreen;
  CbtMap.SetCombatPalette;
  Border.DrawBorder(1, 1, 16, 22, 0);
  Border.DrawBorder(18, 1, 38, 22, 0);
  Border.DrawBorder(18, MSG_TOP, 38, MSG_BOTTOM, 0);
  with GDVars.curChar^ do
    TextRend.DisplayCentered(1, 16, 1, Cyan, name);
  TextRend.DisplayString(READY_COL - 1, LABEL_ROW, LightGreen, 'Ready');
  TextRend.DisplayString(ACTION_COL - 1, LABEL_ROW, LightGreen, 'Action');
  TextRend.DisplayString(2, COLOR_ROW, LightGreen, 'Color');
  for i := ITEM_HEAD to LAST_PART do
    DrawItem(i);
  ShowPreviews;
  done := False;
  GDVars.horizChoice := 1;
  repeat
    { on the left pane the arrows and Enter come back here; on the menu Left and Right step through it and Enter takes
      the option there }
    MenuCore.arrowsToCaller := cur <> ITEM_MENU;
    MenuCore.enterToCaller := cur <> ITEM_MENU;
    key := MenuCore.MenuHorizontal('', 'Keep Exit', LightMagenta, LightGreen, White, True, False, ext);
    if ext then begin
      if key in [C_Keys.UP, C_Keys.DOWN] then begin
        i := cur;
        if key = C_Keys.UP then begin
          if cur = ITEM_HEAD then cur := ITEM_MENU else Dec(cur);
        end else if cur = ITEM_MENU then
          cur := ITEM_HEAD
        else
          Inc(cur);
        DrawItem(i);
        DrawItem(cur);
      end;
    end else
      case key of
        C_Keys.ENTER: case cur of
            ITEM_SIZE: begin
                tSize := 3 - tSize;
                GDVars.curChar^.iconSize := tSize;
                DrawItem(cur);
                ShowPreviews;
              end;
          else
            ChooseInGrid;
          end;
        'K': done := Confirmed;
        'E', C_Keys.NONE: begin
            with GDVars.curChar^ do begin
              iconHead := savedHead;
              iconBody := savedBody;
              iconSize := savedSize;
              iconColors1 := savedCols;
            end;
            done := True;
          end;
      end;
  until done;
  for i := 0 to 1 do
    for j := 0 to 1 do
      Blit.FreePic(loaded[i, j]);
  Blit.FreePic(work);
  for i := 0 to 15 do
    Blit.FreePic(cells[i]);
  Blit.FreePic(readyPic);
  Blit.FreePic(actionPic);
  Blit.FreePic(shownPic);
  { a party member's combat icon; a character being created has no slot of its own yet }
  p := GDVars.creatureList;
  while (p <> nil) and (p <> GDVars.curChar) do
    p := p^.nextCharAddr;
  if (p <> nil) and (GDVars.curChar^.orderNumber < Types.MAX_PARTY) then begin
    SaveLoad.LoadCharIconAnim(True);
    if GDVars.gLocType > C_Area.LOC_3D_MAP then
      { the party map icon LoadCharIconAnim freed }
      MapTiles.LoadIconAnim('ICON', 0, 11);
  end;
  TextRend.ClearBottomLine;
  CbtMap.SetNoncombatPalette;
  GDVars.horizChoice := savedChoice;
end;

end.

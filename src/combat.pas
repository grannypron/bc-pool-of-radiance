{ Combat loop, initiative selection and manual-control menus. }

{$O+,F+}
unit Combat;

interface

procedure CombatMain;

implementation

uses Types, C_Time, C_Npc, C_Cond, GDConsts, GDVars, Crt, CombatAi, CombatSt, Magic, C_Keys, C_Class,
  C_Status, C_Ifc, C_Gbvm, C_Dir, Options, Stats, Blit, Border, CbtActs, CbtMap, CharHlp, FxEngine, MenuCore, ViewChar,
  TextRend, StrUtil, CharDisp;


procedure NextCreature(var next: Types.PCharRecord); forward;

procedure CreatureAction(creature: Types.PCharRecord); forward;

procedure ManualControl(creature: Types.PCharRecord); forward;

procedure CombatMenu(creature: Types.PCharRecord; var ch: Char); forward;

procedure EndOfRound(var done: Boolean); forward;

procedure MoveMenu(creature: Types.PCharRecord; var done: Boolean); forward;

procedure MeleeAttack(att, def: Types.PCharRecord; var done: Boolean); forward;

procedure DoneMenu(creature: Types.PCharRecord; var done: Boolean); forward;

function BandageDying(bandage: Boolean): Boolean; forward;

procedure SpeedMenu; forward;

procedure TurnOnAuto(creature: Types.PCharRecord); forward;

{ Free the stinking-cloud list, the arena and the move-icon sheet, restore the noncombat palette and point the
  cast-target menu (GDVars.castTargetMenu) back at the noncombat menu. }
procedure CombatDoneCleanup;
var
  p: Types.PStinkRec;
begin
  while GDVars.stinkHead <> nil do begin
    p := GDVars.stinkHead^.next;
    FreeMem(GDVars.stinkHead, SizeOf(Types.TStinkRec));
    GDVars.stinkHead := p;
  end;
  FreeMem(GDVars.arenaPtr, SizeOf(Types.TArena));
  GDVars.arenaPtr := nil;
  Blit.FreePic(GDVars.dsMoveIconSheet);
  CbtMap.SetNoncombatPalette;
  GDVars.castTargetMenu := Magic.NoncombatCastTargetMenu;
end;

{ The combat loop. Each round: count teams, run every creature's round-start setup, clear the GBVM surprise flag, let
  the creatures act in initiative order, then EndOfRound decides whether the battle goes on. }
procedure CombatMain;
var
  done: Boolean;
  creature: Types.PCharRecord;
begin
  GDVars.ifcState := C_Ifc.COMBAT;
  GDVars.castTargetMenu := CbtActs.CombatCastTargetMenu;
  CombatSt.CombatStart;
  done := False;
  if (GDVars.teamCount[0] = 0) or (GDVars.teamCount[1] = 0) then
    done := True;
  while not done do begin
    CharHlp.CountTeams;
    creature := GDVars.creatureList;
    while creature <> nil do begin
      CbtActs.CombatRoundStartSetup(creature);
      creature := creature^.nextCharAddr;
    end;
    GDVars.zone1^[C_Gbvm.SURPRISE] := 0;
    Combat.NextCreature(creature);
    while creature <> nil do begin
      Combat.CreatureAction(creature);
      Combat.NextCreature(creature);
    end;
    Combat.EndOfRound(done);
  end;
  Combat.CombatDoneCleanup;
end;

{ Highest initiative acts next; ties go to the higher 1d100 roll, later-listed creature on a full tie }
procedure NextCreature(var next: Types.PCharRecord);
var
  best: Byte;
  bestRoll: Byte;
  roll: Byte;
  p: Types.PCharRecord;
begin
  best := 0;
  bestRoll := 0;
  p := GDVars.creatureList;
  while p <> nil do begin
    roll := FxEngine.RollDice(1, 100);
    if p^.combatAddr^.initiative > best then
      bestRoll := roll;
    if (p^.combatAddr^.initiative >= best) and (roll >= bestRoll) then begin
      bestRoll := roll;
      best := p^.combatAddr^.initiative;
      next := p;
    end;
    p := p^.nextCharAddr;
  end;
  { No positive initiative: no next turn }
  if best = 0 then
    next := nil;
end;

{ One creature's turn: reset its flanking accumulators and guard flag, fire turn-start effects and, if it still has
  initiative, let the AI (quickfight) or the player act, then redraw its cell to erase the cursor. }
procedure CreatureAction(creature: Types.PCharRecord);
begin
  creature^.combatAddr^.flankCount := 0;
  creature^.combatAddr^.flankSpread := 0;
  creature^.combatAddr^.guarding := 0;
  { turn-start effects, among them those that leave the creature helpless }
  FxEngine.TriggerEffectsWithCondition(C_Cond.TURN_START, creature);
  if creature^.combatAddr^.initiative <= 0 then
    Exit;
  { Initiative 20 marks a creature that switched between manual and AI control mid-turn (Alt-Q here, space in CombatAi)
    so that it acts again at once; clear the mark }
  if creature^.combatAddr^.initiative = 20 then
    creature^.combatAddr^.initiative := 19;
  GDVars.curChar := creature;
  CbtMap.DisplayMapViewCentered(creature, 2, True);
  CharHlp.RecalcStats(creature);
  CharDisp.CombatPrintCreatureInfo(creature);
  FxEngine.TriggerEffectsWithCondition(C_Cond.ACTION_START, creature);
  if creature^.combatAddr^.initiative > 0 then
    if creature^.quickfight <> 0 then
      CombatAi.CombatAiControl(creature)
    else
      Combat.ManualControl(creature);
  CbtMap.RedrawArenaCell(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature));
end;

{ The player command dispatcher: resolve a spell begun earlier, or run the combat menu until an action ends the turn. A
  disabled creature just ends its actions. }
procedure ManualControl(creature: Types.PCharRecord);
var
  ch: Char;
  done: Boolean;
  p: Types.PCharRecord;
  aimTgt: Pointer;
  spell: Byte;
begin
  if creature^.enabled <> 0 then begin
    if creature^.combatAddr^.spellCast > 0 then begin
      { a spell begun earlier (CbtActs.CastSpellCombat) resolves now }
      spell := creature^.combatAddr^.spellCast;
      creature^.combatAddr^.spellCast := 0;
      Magic.CastSpellNC(spell, False, True, done);
      done := CharHlp.EndActions(creature);
    end else begin
      done := False;
      while not done do begin
        Combat.CombatMenu(creature, ch);
        case ch of
          'M': Combat.MoveMenu(creature, done);
          'V': begin
                 ViewChar.ViewCharMenu(done);
                 CbtActs.SetCurAttacksX2(creature);
                 if not done then
                   CharDisp.DisplayCombatInterface;
               end;
          'A': CbtActs.CombatAimMenu(creature, 255, 1, 0, done, aimTgt);
          'U': begin
                 ViewChar.UseItemMenu(done);
                 CbtActs.SetCurAttacksX2(creature);
                 if not done then
                   CharDisp.DisplayCombatInterface;
               end;
          'C': CbtActs.CastSpellCombat(0, 0, done);
          'T': begin
                 CbtActs.CombatTurnUndead(creature);
                 done := CharHlp.EndActions(creature);
               end;
          'Q': begin
                 Combat.TurnOnAuto(creature);
                 TextRend.ClearBottomLine;
                 Delay(200);
                 done := True;
                 CombatAi.CombatAiControl(creature);
               end;
          'D': Combat.DoneMenu(creature, done);
          { Alt-M scan code: toggle quick magic }
          C_Keys.ALT_M: begin
                      GDVars.quickMagic := GDVars.quickMagic = False;
                      if GDVars.quickMagic then
                        CharDisp.PrintBottomLine('Magic On')
                      else
                        CharDisp.PrintBottomLine('Magic Off');
                    end;
          { every non-NPC creature back to manual control }
          ' ': begin
                 p := GDVars.creatureList;
                 while p <> nil do begin
                   { creatures with the NPC flag (high bit of npc) stay on quick-fight }
                   if not CharHlp.IsNpc(p) then
                     p^.quickfight := 0;
                   p := p^.nextCharAddr;
                 end;
               end;
          { Alt-Q scan code: everyone to quick-fight; this creature acts again at once under the AI }
          C_Keys.ALT_Q: begin
                      creature^.combatAddr^.initiative := 20;
                      p := GDVars.creatureList;
                      while p <> nil do begin
                        Combat.TurnOnAuto(p);
                        p := p^.nextCharAddr;
                      end;
                      TextRend.ClearBottomLine;
                      Delay(200);
                      done := True;
                    end;
          { Alt-X scan code: the STING cheat }
          C_Keys.ALT_X: if CbtActs.StingVictoryCheat then begin
                      CbtMap.DisplayMapViewCentered(creature, 3, False);
                      done := True;
                    end else
                      CharDisp.PrintBottomLine('That doesn''t work');
        end;
        if not done then begin
          CbtMap.DisplayMapViewCentered(creature, 2, True);
          CharDisp.CombatPrintCreatureInfo(creature);
        end;
      end;
    end;
  end else
    done := CharHlp.EndActions(creature);
end;

{ Build the command list and run the horizontal menu until an accepted key arrives }
procedure CombatMenu(creature: Types.PCharRecord; var ch: Char);
var
  menu: String[40];
  i: Byte;
  hasSpell: Boolean;
begin
  FxEngine.TriggerEffectsWithCondition(C_Cond.ACTION_START, creature);
  menu := '';
  if creature^.combatAddr^.movement > 0 then
    menu := menu + 'Move ';
  menu := menu + 'View Aim ';
  if creature^.numberOfItems > 0 then
    menu := menu + 'Use ';
  hasSpell := False;
  for i := 0 to SizeOf(creature^.memorizedSpells) div SizeOf(creature^.memorizedSpells[0]) - 1 do
    if creature^.memorizedSpells[i] > 0 then
      hasSpell := True;
  { Cast lists the memorized spells, while castAllowed, and the spells on readable scrolls }
  if ((hasSpell and (creature^.combatAddr^.castAllowed <> 0)) or CharHlp.HasScrollSpells(creature))
     and (GDVars.zone0^.antimagic = 0) then
    menu := menu + 'Cast ';
  if (CbtActs.TurnLevel(creature) > 0)
     and (creature^.combatAddr^.usedTurnUndead = 0) then
    menu := menu + 'Turn ';
  menu := menu + 'Quick Done';
  { hasSpell doubles as MenuHorizontal's extended-key flag: an extended key other than Alt-Q, Alt-R, Alt-X or Alt-M
    becomes C_Keys.NONE and is rejected. Alt-R is accepted here, but ManualControl has no arm for it. }
  repeat
    ch := MenuCore.MenuHorizontal('', menu, LightMagenta, LightGreen, White, True, False, hasSpell);
    if hasSpell then
      if not (ch in [C_Keys.ALT_Q, C_Keys.ALT_R, C_Keys.ALT_X, C_Keys.ALT_M]) then
        ch := C_Keys.NONE;
  until ch in [C_Keys.ALT_Q, C_Keys.ALT_R, ' ', C_Keys.ALT_X, C_Keys.ALT_M, 'A', 'C', 'D', 'M', 'Q',
               'T', 'U', 'V'];
end;

{ Advance the clock one minute, fire round-end effects and stinking-cloud checks, bleed dying creatures (dead at
  overkill 10), warn when a party member is dying, then end combat when a side is empty, unless the party won and the
  player answers yes to Continue Battle (not asked when suppressContinuePrompt is set). }
procedure EndOfRound(var done: Boolean);
var
  p: Types.PCharRecord;
  cnt: Byte;
begin
  { one minute (tUnit 1) }
  FxEngine.AdvanceTime(1, C_Time.MINUTES);
  Inc(GDVars.roundCounter);
  CbtActs.CalcHostileHpPercent;
  p := GDVars.creatureList;
  cnt := 1;
  while p <> nil do begin
    FxEngine.TriggerEffectsWithCondition(C_Cond.ROUND_END, p);
    FxEngine.ConsiderStinkingCloud(p);
    if p^.status = C_Status.DYING then begin
      Inc(p^.combatAddr^.overkill);
      if p^.combatAddr^.overkill > 9 then
        { dead at -10 }
        p^.status := C_Status.DEAD;
        Stats.BledOut(p);
    end;
    Inc(cnt);
    p := p^.nextCharAddr;
  end;
  if Combat.BandageDying(False) then
    CharDisp.PrintBottomLine('Your Teammate is Dying');
  CharHlp.CountTeams;
  CbtMap.ScrollView(GDVars.arenaPtr^.ox + 3, GDVars.arenaPtr^.oy + 3, 255, C_Dir.CENTER);
  if (GDVars.teamCount[0] = 0) or (GDVars.teamCount[1] = 0) then
    done := True;
  if (GDVars.teamCount[0] > 0) and (GDVars.teamCount[1] = 0)
     and (GDVars.suppressContinuePrompt = 0) then
    if MenuCore.YesNoMenu('Continue Battle:', LightMagenta, LightGreen, White) = 'Y' then
      done := False;
end;

{ Arrow-scan movement: H/I/M/Q/P/O/K/G extended scans = dirs 0..7; bump into a creature = melee attack; walk off the map
  edge (terrain 0) = flee prompt; Escape undoes the whole move and leaves. movement is in half-moves (shown div 2); the
  loop ends below 2 or on Enter. }
procedure MoveMenu(creature: Types.PCharRecord; var done: Boolean);
var
  savedMove: Byte;
  savedDir: Byte;
  startX: ShortInt;
  startY: ShortInt;
  dir: Byte;
  crIdx: Byte;
  terrIdx: Byte;
  ch: Char;
begin
  savedMove := creature^.combatAddr^.movement;
  savedDir := creature^.combatAddr^.direction;
  startX := CbtMap.CombatCellX(creature);
  startY := CbtMap.CombatCellY(creature);
  ch := ' ';
  done := False;
  dir := C_Dir.CENTER;
  while (creature^.combatAddr^.movement > 1) and (ch <> C_Keys.NONE)
        and (ch <> C_Keys.ENTER) do begin
    Border.ClearBox(24, 24, 39, 24);
    MenuCore.arrowsToCaller := True;
    ch :=
      MenuCore.MenuHorizontal('Move/Attack, Move Left = ' + StrUtil.NumStr(creature^.combatAddr^.movement div 2) +
      ' ', '', LightGreen, LightGreen, White, True, False, GDVars.doneRoundFlag);
    case ch of
      { Escape: undo }
      C_Keys.NONE: begin
                  creature^.combatAddr^.movement := savedMove;
                  { slot 0 (not on the map) would redraw view cell 0, 0 instead }
                  if CbtMap.CombatSlot(creature) > 0 then
                    CbtMap.UpdateCombatMapTile(0, 0, CbtMap.CombatSlot(creature));
                  { Put it back on its start cell; the turn ends if that cell is no longer free }
                  done := CbtMap.IsValidCreatureLoc(creature, startX, startY, False) = False;
                  CbtMap.ScrollView(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 0, C_Dir.CENTER);
                  creature^.combatAddr^.direction := savedDir;
                  dir := C_Dir.CENTER;
                end;
      { Up arrow }
      C_Keys.UP: dir := C_Dir.NORTH;
      { Page Up }
      C_Keys.PGUP: dir := C_Dir.NORTHEAST;
      { Right arrow }
      C_Keys.RIGHT: dir := C_Dir.EAST;
      { Page Down }
      C_Keys.PGDN: dir := C_Dir.SOUTHEAST;
      { Down arrow }
      C_Keys.DOWN: dir := C_Dir.SOUTH;
      { End }
      C_Keys.END_KEY: dir := C_Dir.SOUTHWEST;
      { Left arrow }
      C_Keys.LEFT: dir := C_Dir.WEST;
      { Home }
      C_Keys.HOME: dir := C_Dir.NORTHWEST;
    else
      dir := C_Dir.CENTER;
    end;
    if dir < C_Dir.CENTER then begin
      CbtMap.SetCreatureFacing(creature, dir, 0, 0);
      CbtMap.ProbeDirection(creature, dir, crIdx, terrIdx);
      if crIdx > 0 then
        Combat.MeleeAttack(creature, GDVars.creatureArr[crIdx], done)
      else if terrIdx = 0 then begin
        case MenuCore.YesNoMenu('Flee:', LightMagenta, LightGreen, White) of
          'Y': done := CbtActs.CombatFleeAttempt(creature);
          'N': done := False;
        end;
      end else if GDConsts.terrainInfo[terrIdx].cost > creature^.combatAddr^.movement then
        CharDisp.PrintBottomLine('Blocked')
      else begin
        { free attacks from the enemies this step leaves }
        CbtActs.MoveOpportunityAttacks(creature, dir);
        if creature^.enabled = 0 then
          done := CharHlp.EndActions(creature)
        else begin
          CbtActs.CombatMoveCreature(creature, dir);
          if creature^.enabled = 0 then
            done := CharHlp.EndActions(creature);
          FxEngine.ConsiderStinkingCloud(creature);
          if CharHlp.IsHelpless(creature) then
            done := CharHlp.EndActions(creature);
        end;
      end;
    end;
  end;
  if creature^.combatAddr^.movement < 2 then
    creature^.combatAddr^.movement := 0;
end;

{ MoveMenu's bump attack: refused with a ranged, non-throwable weapon; otherwise, once CheckAttackAlly allows it, lock
  def as the target and try a sweep before a normal attack. }
procedure MeleeAttack(att, def: Types.PCharRecord; var done: Boolean);
begin
  if CharHlp.HasRangedWeapon(att) and not CharHlp.HasThrowableWeapon(att) then
    CharDisp.PrintBottomLine('Not with that weapon')
  else if CbtActs.CheckAttackAlly(att, def) then begin
    att^.combatAddr^.other := def;
    if CbtActs.SweepAttempt(att, def) then
      done := True
    else begin
      CbtActs.NoteAttackDirection(att, def);
      CbtActs.CombatAttack(att, def, False, nil, done);
    end;
  end;
end;

{ Guard/Delay/Quit/Bandage/Speed/Exit. Guard needs a melee or throwable weapon; Bandage appears only while a party
  member is dying. }
procedure DoneMenu(creature: Types.PCharRecord; var done: Boolean);
var
  menu: String[40];
  ch: Char;
begin
  done := False;
  menu := '';
  if not CharHlp.HasRangedWeapon(creature) or CharHlp.HasThrowableWeapon(creature) then
    menu := menu + 'Guard ';
  menu := menu + 'Delay Quit ';
  if Combat.BandageDying(False) then
    menu := menu + 'Bandage ';
  menu := menu + 'Speed Exit';
  ch := ' ';
  while not (ch in [C_Keys.NONE, 'E']) and not done do
  begin
    ch := MenuCore.MenuHorizontal('', menu, LightMagenta, LightGreen, White, False, False,
                                  GDVars.doneRoundFlag);
    case ch of
      'G': begin
             done := CharHlp.Guard(creature);
             CharDisp.PrintBottomLine('Guarding');
           end;
      { Delay: act again later this round, at initiative 1 }
      'D': begin
             creature^.combatAddr^.initiative := 1;
             done := True;
           end;
      'Q': done := CharHlp.EndActions(creature);
      'B': begin
             done := Combat.BandageDying(True);
             { Bandage result is overwritten }
             done := CharHlp.EndActions(creature);
           end;
      'S': Combat.SpeedMenu;
    end;
  end;
end;

{ Return True if any party character (notPcNpc = 0, not hostile) is dying; with bandage set, the first one found is
  bandaged to unconscious with its overkill cleared. }
function BandageDying(bandage: Boolean): Boolean;
var
  p: Types.PCharRecord;
  found: Boolean;
begin
  found := False;
  p := GDVars.creatureList;
  while p <> nil do begin
    if (p^.combatAddr^.notPcNpc = 0) and (p^.hostile = 0)
       and (p^.status = C_Status.DYING) then begin
      found := True;
      if bandage then begin
        p^.status := C_Status.UNCONSCIOUS;
        p^.combatAddr^.overkill := 0;
        CharDisp.PrintNameString(p, 'is bandaged', 10, True);
        { Stop bandaging; keep scanning }
        bandage := False;
      end;
    end;
    p := p^.nextCharAddr;
  end;
  BandageDying := found;
end;

{ GameSpeed (n): Slower (offered below 9) raises gameDelay, Faster (offered above 0) lowers it, Exit or Escape leaves.
  The speed is a setting, so a change is written to POOLOPT.CFG on leaving (Options.SaveOptions). }
procedure SpeedMenu;
var
  menu: String[40];
  query: String[40];
  ch: Char;
  speed: Byte;
begin
  speed := GDVars.gameDelay;
  ch := ' ';
  while not (ch in [C_Keys.NONE, 'E']) do
  begin
    query := 'GameSpeed (' + StrUtil.NumStr(GDVars.gameDelay) + ') :';
    menu := ' ';
    if GDVars.gameDelay < 9 then
      menu := menu + 'Slower ';
    if GDVars.gameDelay > 0 then
      menu := menu + 'Faster ';
    menu := menu + 'Exit';
    ch := MenuCore.MenuHorizontal(query, menu, LightMagenta, LightGreen, White, False, False,
                                  GDVars.doneRoundFlag);
    case ch of
      'S': Inc(GDVars.gameDelay);
      'F': Dec(GDVars.gameDelay);
    end;
  end;
  if GDVars.gameDelay <> speed then
    Options.SaveOptions;
end;

{ Quick-fight on; drop a same-side locked target }
procedure TurnOnAuto(creature: Types.PCharRecord);
begin
  creature^.quickfight := 1;
  if (creature^.combatAddr^.other <> nil)
     and (creature^.combatAddr^.other^.hostile = creature^.hostile) then begin
    creature^.combatAddr^.other := nil;
  end;
end;

end.

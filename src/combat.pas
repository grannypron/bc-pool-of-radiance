{ Combat loop, initiative selection and manual-control menus. }
{$O+,F+}
{$I COMPILER.INC}
unit Combat;

interface

procedure CombatMain;

{ Return True if any party character (notPcNpc = 0, not hostile) is dying; with bandage set, the first one found is
  bandaged to unconscious with its overkill cleared. The Bandage choice on the combat menu calls it, and so does the AI
  for a party member under Quick (CombatAi.AiMoveAttack). }
function BandageDying(bandage: Boolean): Boolean;

{ Let the Continue Battle prompt show again, for a new game (GameInit.ResetGameState). }
procedure ResetGame;

implementation

uses Types, C_TIME, C_NPC, C_COND, GameDefs, GameVars, Crt, CombatAi, CombatSt, Magic, C_KEYS, C_CLASS,
  C_STATUS, C_IFC, C_GBVM, C_DIR, Options, Stats, Blit, Border, CbtActs, CbtMap, CharHlp, FxEngine, MenuCore, ViewChar,
  TextRend, StrUtil, CharDisp, Dice, CbtLog, LogView;

const
  { CombatMenu's answer for F7, the combat log (#841): F7's scan code is the character code of 'A', which is Aim }
  SHOW_LOG = #255;

var
  { nonzero suppresses Combat's Continue Battle prompt }
  suppressContinuePrompt: Byte;

procedure NextCreature(var next: Types.PCharRecord); forward;

procedure CreatureAction(creature: Types.PCharRecord); forward;

procedure ManualControl(creature: Types.PCharRecord); forward;

procedure CombatMenu(creature: Types.PCharRecord; var ch: Char); forward;

procedure EndOfRound(var done: Boolean); forward;

procedure MoveMenu(creature: Types.PCharRecord; var done: Boolean); forward;

procedure MeleeAttack(att, def: Types.PCharRecord; var done: Boolean); forward;

procedure DoneMenu(creature: Types.PCharRecord; var done: Boolean); forward;

procedure SpeedMenu; forward;

procedure TurnOnAuto(creature: Types.PCharRecord); forward;

{ Free the stinking-cloud list, the arena and the move-icon sheet, restore the noncombat palette and point the
  cast-target menu (GameVars.castTargetMenu) back at the noncombat menu. }
procedure CombatDoneCleanup;
var
  p: Types.PStinkRec;
begin
  while GameVars.stinkHead <> nil do begin
    p := GameVars.stinkHead^.next;
    FreeMem(GameVars.stinkHead, SizeOf(Types.TStinkRec));
    GameVars.stinkHead := p;
  end;
  FreeMem(GameVars.arenaPtr, SizeOf(Types.TArena));
  GameVars.arenaPtr := nil;
  Blit.FreePic(GameVars.moveIconSheet);
  CbtMap.SetNoncombatPalette;
  GameVars.castTargetMenu := Magic.NoncombatCastTargetMenu;
end;

{ The combat loop. Each round: count teams, run every creature's round-start setup, clear the GBVM surprise flag, let
  the creatures act in initiative order, then EndOfRound decides whether the battle goes on. The combat log starts
  empty, sized and turned on by the settings, and each round's messages come under the round's number (#841). }
procedure CombatMain;
var
  done: Boolean;
  creature: Types.PCharRecord;
begin
  GameVars.ifcState := C_IFC.COMBAT;
  GameVars.castTargetMenu := CbtActs.CombatCastTargetMenu;
  CbtLog.Clear(GameVars.combatLogLines, GameVars.combatLogOn <> 0);
  CombatSt.CombatStart;
  done := False;
  if (GameVars.teamCount[0] = 0) or (GameVars.teamCount[1] = 0) then
    done := True;
  while not done do begin
    CbtLog.Heading(White, 'Round ' + StrUtil.NumStr(GameVars.roundCounter + 1));
    CharHlp.CountTeams;
    creature := GameVars.creatureList;
    while creature <> nil do begin
      CbtActs.CombatRoundStartSetup(creature);
      creature := creature^.nextCharAddr;
    end;
    GameVars.zone1^[C_GBVM.SURPRISE] := 0;
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
  p := GameVars.creatureList;
  while p <> nil do begin
    roll := Dice.RollDice(1, 100);
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
  FxEngine.TriggerEffectsWithCondition(C_COND.TURN_START, creature);
  if creature^.combatAddr^.initiative <= 0 then
    Exit;
  { Initiative 20 marks a creature that switched between manual and AI control mid-turn (Alt-Q here, space in CombatAi)
    so that it acts again at once; clear the mark }
  if creature^.combatAddr^.initiative = 20 then
    creature^.combatAddr^.initiative := 19;
  GameVars.curChar := creature;
  CbtMap.DisplayMapViewCentered(creature, 2, True);
  CharHlp.RecalcStats(creature);
  CharDisp.CombatPrintCreatureInfo(creature);
  { once a turn: SSI's fired them again at every draw of the combat menu (#816) }
  FxEngine.TriggerEffectsWithCondition(C_COND.ACTION_START, creature);
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
          SHOW_LOG: begin
                      LogView.ShowLog('Combat Messages');
                      CharDisp.DisplayCombatInterface;
                    end;
          { Alt-M scan code: toggle quick magic }
          C_KEYS.ALT_M: CombatAi.ToggleQuickMagic;
          { every creature under the player's control back to manual; NPCs and animated creatures stay on quick-fight,
            as during the AI's turns (#640) }
          ' ': CombatAi.AllToManual;
          { Alt-Q scan code: everyone to quick-fight; this creature acts again at once under the AI }
          C_KEYS.ALT_Q: begin
                          creature^.combatAddr^.initiative := 20;
                          p := GameVars.creatureList;
                          while p <> nil do begin
                            Combat.TurnOnAuto(p);
                            p := p^.nextCharAddr;
                          end;
                          TextRend.ClearBottomLine;
                          Delay(200);
                          done := True;
                        end;
          { Alt-X scan code: the STING cheat }
          C_KEYS.ALT_X: if CbtActs.StingVictoryCheat then begin
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

{ Build the command list and run the horizontal menu until an accepted key arrives. F7, while the combat log is kept,
  is answered as SHOW_LOG; it is on no menu line, as Move View Aim Use Cast Turn Quick Done fills it (#841). }
procedure CombatMenu(creature: Types.PCharRecord; var ch: Char);
var
  menu: String[40];
  i: Byte;
  hasSpell: Boolean;
begin
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
     and (GameVars.zone0^.antimagic = 0) then
    menu := menu + 'Cast ';
  if (CbtActs.TurnLevel(creature) > 0)
     and (creature^.combatAddr^.usedTurnUndead = 0) then
    menu := menu + 'Turn ';
  menu := menu + 'Quick Done';
  { hasSpell doubles as MenuHorizontal's extended-key flag: an extended key other than Alt-Q, Alt-X or Alt-M becomes
    C_KEYS.NONE and is rejected. SSI's took Alt-R too, which no command answers (#818). }
  repeat
    ch := MenuCore.MenuHorizontal('', menu, LightMagenta, LightGreen, White, True, False, hasSpell);
    if hasSpell then
      if (ch = C_KEYS.F7) and CbtLog.Active then
        ch := SHOW_LOG
      else if not (ch in [C_KEYS.ALT_Q, C_KEYS.ALT_X, C_KEYS.ALT_M]) then
        ch := C_KEYS.NONE;
  until ch in [C_KEYS.ALT_Q, ' ', C_KEYS.ALT_X, C_KEYS.ALT_M, SHOW_LOG, 'A', 'C', 'D', 'M', 'Q', 'T', 'U', 'V'];
end;

{ Advance the clock one minute, fire round-end effects and stinking-cloud checks, bleed dying creatures (dead at
  overkill 10), warn when a party member is dying, then end combat when a side is empty, unless the party won and the
  player answers yes to Continue Battle (not asked when suppressContinuePrompt is set). }
procedure EndOfRound(var done: Boolean);
var
  p: Types.PCharRecord;
begin
  { one minute }
  FxEngine.AdvanceTime(1, C_TIME.MINUTES);
  Inc(GameVars.roundCounter);
  CbtActs.CalcHostileHpPercent;
  p := GameVars.creatureList;
  while p <> nil do begin
    FxEngine.TriggerEffectsWithCondition(C_COND.ROUND_END, p);
    FxEngine.ConsiderStinkingCloud(p);
    if p^.status = C_STATUS.DYING then begin
      Inc(p^.combatAddr^.overkill);
      if p^.combatAddr^.overkill > 9 then begin
        { dead at -10 }
        p^.status := C_STATUS.DEAD;
        Stats.Death(p);
      end;
    end;
    p := p^.nextCharAddr;
  end;
  if Combat.BandageDying(False) then
    CharDisp.PrintBottomLine('Your Teammate is Dying');
  CharHlp.CountTeams;
  CbtMap.ScrollView(GameVars.arenaPtr^.ox + 3, GameVars.arenaPtr^.oy + 3, 255, C_DIR.CENTER);
  if (GameVars.teamCount[0] = 0) or (GameVars.teamCount[1] = 0) then
    done := True;
  if (GameVars.teamCount[0] > 0) and (GameVars.teamCount[1] = 0)
     and (suppressContinuePrompt = 0) then
    if MenuCore.YesNoMenu('Continue Battle:', LightMagenta, LightGreen, White) = 'Y' then
      done := False;
end;

{ Arrow-scan movement: H/I/M/Q/P/O/K/G extended scans = dirs 0..7; bump into a creature = melee attack; walk off the map
  edge (terrain 0) = flee prompt; Escape undoes the move since the last attack and leaves: a bump attack that is made
  keeps the steps before it, or Escape would put the creature back with its full move after attacking (#712). movement
  is in half-moves (shown div 2); the loop ends below 2 or on Enter. }
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
  attacksLeft: Word;
begin
  savedMove := creature^.combatAddr^.movement;
  savedDir := creature^.combatAddr^.direction;
  startX := CbtMap.CombatCellX(creature);
  startY := CbtMap.CombatCellY(creature);
  ch := ' ';
  done := False;
  dir := C_DIR.CENTER;
  while (creature^.combatAddr^.movement > 1) and (ch <> C_KEYS.NONE)
        and (ch <> C_KEYS.ENTER) do begin
    Border.ClearBox(24, 24, 39, 24);
    MenuCore.arrowsToCaller := True;
    ch :=
      MenuCore.MenuHorizontal('Move/Attack, Move Left = ' + StrUtil.NumStr(creature^.combatAddr^.movement div 2) +
      ' ', '', LightGreen, LightGreen, White, True, False, CbtActs.doneRoundFlag);
    case ch of
      { Escape: undo }
      C_KEYS.NONE: begin
                     creature^.combatAddr^.movement := savedMove;
                     { slot 0 (not on the map) would redraw view cell 0, 0 instead }
                     if CbtMap.CombatSlot(creature) > 0 then
                       CbtMap.UpdateCombatMapTile(0, 0, CbtMap.CombatSlot(creature));
                     { Put it back on its start cell; the turn ends if that cell is no longer free }
                     done := CbtMap.IsValidCreatureLoc(creature, startX, startY, False) = False;
                     CbtMap.ScrollView(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 0, C_DIR.CENTER);
                     creature^.combatAddr^.direction := savedDir;
                     dir := C_DIR.CENTER;
                   end;
      { Up arrow }
      C_KEYS.UP: dir := C_DIR.NORTH;
      { Page Up }
      C_KEYS.PGUP: dir := C_DIR.NORTHEAST;
      { Right arrow }
      C_KEYS.RIGHT: dir := C_DIR.EAST;
      { Page Down }
      C_KEYS.PGDN: dir := C_DIR.SOUTHEAST;
      { Down arrow }
      C_KEYS.DOWN: dir := C_DIR.SOUTH;
      { End }
      C_KEYS.END_KEY: dir := C_DIR.SOUTHWEST;
      { Left arrow }
      C_KEYS.LEFT: dir := C_DIR.WEST;
      { Home }
      C_KEYS.HOME: dir := C_DIR.NORTHWEST;
    else
      dir := C_DIR.CENTER;
    end;
    if dir < C_DIR.CENTER then begin
      CbtMap.SetCreatureFacing(creature, dir, 0, 0);
      CbtMap.ProbeDirection(creature, dir, crIdx, terrIdx);
      if crIdx > 0 then begin
        attacksLeft := creature^.curAttacks + creature^.curAttacks2;
        Combat.MeleeAttack(creature, GameVars.creatureArr[crIdx], done);
        if creature^.curAttacks + creature^.curAttacks2 <> attacksLeft then begin
          { attacked: the move so far stands }
          savedMove := creature^.combatAddr^.movement;
          savedDir := creature^.combatAddr^.direction;
          startX := CbtMap.CombatCellX(creature);
          startY := CbtMap.CombatCellY(creature);
        end;
      end else if terrIdx = 0 then begin
        case MenuCore.YesNoMenu('Flee:', LightMagenta, LightGreen, White) of
          'Y': done := CbtActs.CombatFleeAttempt(creature);
          'N': done := False;
        end;
      end else if GameDefs.terrainInfo[terrIdx].cost > creature^.combatAddr^.movement then
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
  while not (ch in [C_KEYS.NONE, 'E']) and not done do
  begin
    ch := MenuCore.MenuHorizontal('', menu, LightMagenta, LightGreen, White, False, False,
                                  CbtActs.doneRoundFlag);
    case ch of
      'G': begin
             done := CharHlp.Guard(creature);
             CharDisp.PrintActionLine(creature, 'Guarding', 'is Guarding');
           end;
      { Delay: act again later this round, at initiative 1 }
      'D': begin
             creature^.combatAddr^.initiative := 1;
             done := True;
           end;
      'Q': done := CharHlp.EndActions(creature);
      'B': begin
             if Combat.BandageDying(True) then ;
             done := CharHlp.EndActions(creature);
           end;
      'S': Combat.SpeedMenu;
    end;
  end;
end;

function BandageDying(bandage: Boolean): Boolean;
var
  p: Types.PCharRecord;
  found: Boolean;
begin
  found := False;
  p := GameVars.creatureList;
  while p <> nil do begin
    if (p^.combatAddr^.notPcNpc = 0) and (p^.hostile = 0)
       and (p^.status = C_STATUS.DYING) then begin
      found := True;
      if bandage then begin
        p^.status := C_STATUS.UNCONSCIOUS;
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
  speed := GameVars.gameDelay;
  ch := ' ';
  while not (ch in [C_KEYS.NONE, 'E']) do
  begin
    query := 'GameSpeed (' + StrUtil.NumStr(GameVars.gameDelay) + ') :';
    menu := ' ';
    if GameVars.gameDelay < 9 then
      menu := menu + 'Slower ';
    if GameVars.gameDelay > 0 then
      menu := menu + 'Faster ';
    menu := menu + 'Exit';
    ch := MenuCore.MenuHorizontal(query, menu, LightMagenta, LightGreen, White, False, False,
                                  CbtActs.doneRoundFlag);
    case ch of
      'S': Inc(GameVars.gameDelay);
      'F': Dec(GameVars.gameDelay);
    end;
  end;
  if GameVars.gameDelay <> speed then
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

procedure ResetGame;
begin
  suppressContinuePrompt := 0;
end;

end.

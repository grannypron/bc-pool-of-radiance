{ Resolve combat results, distribute experience and treasure, show the loot menus and clean up creatures. }
{$O+,F+}
{$I COMPILER.INC}
unit PostCbt;

interface

{ Wrap up a combat: settle the outcome, award experience, run the loot menus and free the combat state. }
procedure PostCombat;

{ With both money and items left, loop on a Money/Items/Exit menu; with only one kind left, go straight to the money or
  item menu. }
procedure LootTakeMenu(var treasure, items: Boolean);

implementation

uses Types, Crt, C_NPC, C_MSG, GameDefs, GameVars, Shop, SaveLoad, Magic, C_KEYS, C_STATUS, C_IFC, C_GBVM,
  C_MONEY, Stats, Bestiary, BeastFil, Border, CharHlp, EclMenu, MenuCore, Money, TextRend, ViewChar, CharDisp, Party,
  Dice, ClassCal;

var
  { Combat outcome. }
  nonEscapedHostileFound: Boolean;
  partyFled: Boolean;
  { party members who get no experience share: the disabled and the Animated }
  nonSharerCount: Byte;
  { Experience share before individual bonuses. }
  expShare: LongInt;
  combatWon: Boolean;

{ Collect coins, experience and items from hostile creatures that did not run away. An item is taken when its value is
  above 0, or on a 3-in-10 roll while fewer than 8 items have been taken. Coins add experience (copper div 200, silver
  div 20, electrum div 2, gold x1, platinum x5, gems x250, jewelry x2200), as does each taken item's positive plus x400
  (items before GameVars.lastMissileItem). The total is divided by C_GBVM.PARTY_SIZE minus nonSharerCount, and the share
  is 0 when that leaves no one (a fight won by Animated members alone). A mirror duel instead awards 100 experience per
  level (levelHighest) of the current character. }
procedure DetermineLootExp(var share: LongInt);
var
  p: Types.PCharRecord;
  i: ShortInt;
  expTotal: LongInt;
  q: Types.PItemRec;
  item: Types.PItemRec;
  cnt: Byte;
  sharers: Integer;
begin
  if GameVars.duelFlag and (GameVars.zone1^[C_GBVM.MIRROR_DUEL] <> 0) then
    share := GameVars.curChar^.levelHighest * 100
  else begin
    expTotal := 0;
    p := GameVars.creatureList;
    cnt := 0;
    while p <> nil do begin
      item := p^.itemsAddr;
      if (p^.hostile = 1) and (p^.status <> C_STATUS.RUNNING) then begin
        nonEscapedHostileFound := True;
        for i := C_MONEY.COPPER to C_MONEY.JEWELRY do
          Inc(GameVars.treasureMoney[i], p^.coins[i]);
        expTotal := expTotal + p^.xpAward + LongInt(p^.xpBonusPerHp) * p^.hpRolled;
        if GameVars.zone1^[C_GBVM.NO_COMBAT_ITEMS] <> 1 then
          while item <> nil do begin
            if (item^.value > 0) or ((cnt < 8) and (Dice.RollDice(1, 10) <= 3)) then begin
              Inc(cnt);
              CharHlp.ItemLabel(item, False);
              CharHlp.PrependItemCopy(GameVars.treasureItems, item);
              GameVars.treasureItems^.equipped := 0;
            end;
            item := item^.next;
          end;
      end;
      p := p^.nextCharAddr;
    end;
    Inc(expTotal, GameVars.treasureMoney[C_MONEY.COPPER] div 200);
    Inc(expTotal, GameVars.treasureMoney[C_MONEY.SILVER] div 20);
    Inc(expTotal, GameVars.treasureMoney[C_MONEY.ELECTRUM] div 2);
    Inc(expTotal, GameVars.treasureMoney[C_MONEY.GOLD]);
    Inc(expTotal, GameVars.treasureMoney[C_MONEY.PLATINUM] * 5);
    Inc(expTotal, GameVars.treasureMoney[C_MONEY.GEMS] * 250);
    Inc(expTotal, GameVars.treasureMoney[C_MONEY.JEWELRY] * 2200);
    q := GameVars.treasureItems;
    while (q <> nil) and (q <> GameVars.lastMissileItem) do begin
      if q^.plus > 0 then
        Inc(expTotal, q^.plus * 400);
      q := q^.next;
    end;
    sharers := GameVars.zone1^[C_GBVM.PARTY_SIZE] - nonSharerCount;
    if sharers > 0 then
      share := expTotal div sharers
    else
      share := 0;
  end;
end;

{ Every enabled, non-Animated creature in the list gets its share of exp (ClassCal.ExperienceShare). }
procedure AwardExperience(experience: LongInt);
var
  p: Types.PCharRecord;
begin
  p := GameVars.creatureList;
  while p <> nil do begin
    if (p^.enabled <> 0) and (p^.status <> C_STATUS.ANIMATED) then
      Inc(p^.experience, ClassCal.ExperienceShare(p, experience));
    p := p^.nextCharAddr;
  end;
end;

{ True for a monster: notPcNpc = 1 in its combat record. A creature without a combat record counts as a party member; a
  COMBAT with no monsters (a treasure-only pickup) reaches the results without giving the party combat records. }
function IsMonster(p: Types.PCharRecord): Boolean;
begin
  IsMonster := (p^.combatAddr <> nil) and (p^.combatAddr^.notPcNpc = 1);
end;

{ Classify the combat outcome. Outside a duel the party (the creatures before the first notPcNpc = 1 entry) is defeated
  unless some non-hostile, non-NPC member is Running, Animated or Okay; while C_GBVM.MIRROR_DUEL is 1 any non-hostile,
  non-NPC member will do, so a lost mirror duel does not end the game. Any Animated or Okay member wins the combat and
  experience is awarded; otherwise a Running member means the party fled. Not fled: Running members return Okay, Dying
  ones become Unconscious and Unconscious ones with HP above 0 recover. Fled: C_GBVM.COMBAT_RESULT becomes $81, Running
  members return and every other member is removed. Defeated: every party member is removed and the party size is set to
  0. In a duel the party is never defeated: each enabled, Okay, non-hostile creature sets combatWon and triggers an
  experience award, Okay and Animated creatures are re-enabled and Dying ones become Unconscious. }
procedure DetermineCombatResults;
var
  p: Types.PCharRecord;
  nxt: Types.PCharRecord;
  b: Boolean;
begin
  nonSharerCount := 0;
  GameVars.partyDefeated := True;
  partyFled := False;
  p := GameVars.creatureList;
  while (p <> nil) and (not IsMonster(p)) do begin
    if p^.status = C_STATUS.RUNNING then
      partyFled := True;
    p := p^.nextCharAddr;
  end;
  if GameVars.duelFlag then
    GameVars.partyDefeated := False;
  combatWon := False;
  p := GameVars.creatureList;
  if not GameVars.duelFlag then begin
    while (p <> nil) and (not IsMonster(p)) do begin
      { C_NPC.FLAG clear }
      if ((p^.status = C_STATUS.RUNNING) or (p^.status = C_STATUS.ANIMATED) or
          (p^.status = C_STATUS.OKAY) or
          (GameVars.zone1^[C_GBVM.MIRROR_DUEL] = 1)) and (p^.hostile = 0) and not CharHlp.IsNpc(p) then
        GameVars.partyDefeated := False;
      if (p^.status = C_STATUS.ANIMATED) or (p^.status = C_STATUS.OKAY) then begin
        combatWon := True;
        partyFled := False;
      end;
      if (p^.enabled = 0) or (p^.status = C_STATUS.ANIMATED) then
        Inc(nonSharerCount);
      p := p^.nextCharAddr;
    end;
    if combatWon then begin
      PostCbt.DetermineLootExp(expShare);
      PostCbt.AwardExperience(expShare);
    end;
    p := GameVars.creatureList;
    if not GameVars.partyDefeated then begin
      while (p <> nil) and (not IsMonster(p)) do begin
        { RemoveCreature below frees p }
        nxt := p^.nextCharAddr;
        if not partyFled then begin
          case p^.status of
            C_STATUS.RUNNING: begin
                                p^.status := C_STATUS.OKAY;
                                p^.enabled := 1;
                              end;
            C_STATUS.DYING: p^.status := C_STATUS.UNCONSCIOUS;
            C_STATUS.UNCONSCIOUS: if p^.hpCur > 0 then begin
                                    p^.status := C_STATUS.OKAY;
                                    p^.enabled := 1;
                                  end;
          end;
        end else begin
          GameVars.zone1^[C_GBVM.COMBAT_RESULT] := $81;
          if p^.status = C_STATUS.RUNNING then begin
            p^.status := C_STATUS.OKAY;
            p^.enabled := 1;
          end else begin
            GameVars.curChar := p;
            SaveLoad.RemoveCreature(False, True);
          end;
        end;
        p := nxt;
      end;
    end else begin
      p := GameVars.creatureList;
      b := False;
      while (p <> nil) and not b do begin
        { RemoveCreature frees p }
        nxt := p^.nextCharAddr;
        if not IsMonster(p) then begin
          GameVars.curChar := p;
          SaveLoad.RemoveCreature(False, True);
        end else
          b := True;
        p := nxt;
      end;
      GameVars.zone1^[C_GBVM.PARTY_SIZE] := 0;
    end;
  end else begin
    p := GameVars.creatureList;
    while p <> nil do begin
      if (p^.enabled = 1) and (p^.status = C_STATUS.OKAY) and (p^.hostile <> 1) then begin
        combatWon := True;
        PostCbt.DetermineLootExp(expShare);
        PostCbt.AwardExperience(expShare);
      end;
      p := p^.nextCharAddr;
    end;
    p := GameVars.creatureList;
    while p <> nil do begin
      if (p^.status = C_STATUS.OKAY) or (p^.status = C_STATUS.ANIMATED) then
        p^.enabled := 1;
      if p^.status = C_STATUS.DYING then
        p^.status := C_STATUS.UNCONSCIOUS;
      p := p^.nextCharAddr;
    end;
  end;
end;

{ Show the combat outcome and the experience each character (or the duelist) received; the figure shown is 0 when the
  party fled or lost a duel. }
procedure PostCombatSummary(experience: LongInt);
var
  numStr: String[10];
  msg: String;
  c: Char;
  query: String[1];
  ext: Boolean;
begin
  query[0] := #0;
  Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0, White, '');
  if nonEscapedHostileFound or GameVars.duelFlag then begin
    if GameVars.duelFlag and not combatWon then begin
      TextRend.DisplayString(1, 3, LightGreen, 'You have lost the duel.');
      experience := 0;
    end else if GameVars.duelFlag then
      TextRend.DisplayString(1, 3, LightGreen, 'You have won the duel.')
    else
      TextRend.DisplayString(1, 3, LightGreen, 'The party has won.');
  end else begin
    if partyFled then begin
      TextRend.DisplayString(1, 3, LightGreen, 'The party has fled.');
      experience := 0;
    end else
      TextRend.DisplayString(1, 3, LightGreen, 'The party has found Treasure!');
  end;
  Str(experience, numStr);
  if GameVars.duelFlag then
    msg := 'The duelist receives ' + numStr
  else
    msg := 'Each character receives ' + numStr;
  TextRend.DisplayString(1, 5, LightGreen, msg);
  TextRend.DisplayString(1, 7, LightGreen, 'experience points.');
  c := MenuCore.MenuHorizontal(query, 'press <enter>/<return> to continue', White, White, White,
                               True, False, ext);
end;

{ Draw the Loot list (rebuilding each item's display name) and run the Items/Take menu; returns the menu key in c and
  the highlighted item in itemToTake. }
procedure LootTakeItemSelection(var c: Char; var itemToTake: Types.PItemRec; var cursor: Types.PItemRec;
                                var idx: Integer);
var
  head: Types.PItemRec;
  { seeded True so MenuVertical paints the list; MenuVertical clears it }
  redraw: Boolean;
begin
  redraw := True;
  Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0, White, 'Loot');
  CharHlp.LabelItems(GameVars.treasureItems);
  head := GameVars.treasureItems;
  c := MenuCore.MenuVertical('Items: ', 'Take', LightMagenta, LightGreen, White, 1, 4, 38, 22,
                             head, True, redraw, idx, cursor);
  itemToTake := cursor;
end;

{ Take loop: give a copy to the current character, then unlink and free the treasure node. Ends on any key other than
  'T' or Enter, with no item highlighted, or when no treasure items are left. }
procedure LootTakeItemMenu;
var
  itemToTake: Types.PItemRec;
  p: Types.PItemRec;
  c: Char;
  done: Boolean;
  cursor: Types.PItemRec;
  idx: Integer;
  failed: Boolean;
begin
  itemToTake := nil;
  cursor := GameVars.treasureItems;
  idx := 0;
  repeat
    PostCbt.LootTakeItemSelection(c, itemToTake, cursor, idx);
    { no item highlighted (an empty list) leaves too, before anything reads it }
    if ((c <> 'T') and (c <> C_KEYS.ENTER)) or (itemToTake = nil) then
      done := True
    else begin
      done := False;
      Shop.GiveItemCopyToCreature(itemToTake, failed);
      { loot after a fight, not the vault's own items (#611) }
      if not failed and (GameVars.ifcState = C_IFC.LOOT) then
        Stats.Count(GameVars.curChar, Stats.ITEMS_LOOTED, 1);
      if not failed then begin
        p := GameVars.treasureItems;
        if p = itemToTake then
          GameVars.treasureItems := itemToTake^.next
        else begin
          while p^.next <> itemToTake do
            p := p^.next;
          p^.next := itemToTake^.next;
        end;
        itemToTake^.next := nil;
        FreeMem(itemToTake, SizeOf(Types.TItemRec));
        if GameVars.treasureItems = nil then
          done := True;
      end;
    end;
  until done;
  CharDisp.DisplayNoncombatInterface;
end;

procedure LootTakeMenu(var treasure, items: Boolean);
var
  c: Char;
  done: Boolean;
  ext: Boolean;
begin
  done := False;
  if treasure then begin
    if items then begin
      repeat
        c := MenuCore.MenuHorizontal('Take: ', 'Money Items Exit', LightMagenta, LightGreen, White,
                                     True, True, ext);
        { an extended key only steps the character: its scan code is no command letter (keypad 6 and 9 came back as 'M'
          and 'I', #730) }
        if ext then
          Party.SelectPrevNextChar(c)
        else
          case c of
            'M': begin
                   Money.TakeMoneyMenu;
                   CharDisp.DisplayNoncombatInterface;
                 end;
            'I': PostCbt.LootTakeItemMenu;
            'E', C_KEYS.NONE: done := True;
          end;
        CharDisp.DisplayParty(GameVars.curChar);
        Money.DetermineTreasure(treasure, items);
        if not treasure or not items then
          done := True;
      until done;
    end else begin
      Money.TakeMoneyMenu;
      CharDisp.DisplayNoncombatInterface;
    end;
  end else
    PostCbt.LootTakeItemMenu;
end;

{ The loot menu is 'View Take Pool Share' with money left, 'View Take Pool' with only items left (each followed by
  ' Detect Exit' when items are left and the current character has Detect Magic, spell 5 cleric / 11 magic-user,
  memorized, else ' Exit'), or 'View Pool Exit' with nothing left. Leaving with treasure left asks for confirmation. }
procedure LootMenu;
var
  treasure: Boolean;
  items: Boolean;
  menu: String;
  c: Char;
  done: Boolean;
  ext: Boolean;
  query: String[1];
  i: Byte;
  detectSpell: Byte;
  hasDetect: Boolean;
  tail: String[13];
begin
  query[0] := #0;
  done := False;
  CharDisp.DisplayNoncombatInterface;
  treasure := False;
  repeat
    Money.DetermineTreasure(treasure, items);
    menu := 'View Pool Exit';
    i := 0;
    tail := ' Exit';
    hasDetect := False;
    if items then
      while (i <= Types.SPELL_SLOT_LAST) and not hasDetect do begin
        if (GameVars.curChar^.memorizedSpells[i] = 5) or (GameVars.curChar^.memorizedSpells[i] = 11) then begin
          hasDetect := True;
          detectSpell := GameVars.curChar^.memorizedSpells[i];
        end;
        Inc(i);
      end;
    if hasDetect then
      tail := ' Detect Exit';
    if treasure then
      menu := 'View Take Pool Share' + tail
    else if items then
      menu := 'View Take Pool' + tail;
    c := MenuCore.MenuHorizontal(query, menu, LightMagenta, LightGreen, White, True, True, ext);
    { the coin each party member gains or puts back here, Take, Share, Pool or Drop alike, is Coin looted (net) (#611) }
    Stats.MarkCoins;
    { an extended key only steps the character: its scan code is no command letter (Delete came back as 'S' and shared
      the money, F10 as 'D' and cast Detect Magic, #730) }
    if ext then begin
      Party.SelectPrevNextChar(c);
      CharDisp.DisplayParty(GameVars.curChar);
    end else
      case c of
        'V': ViewChar.ViewCharMenu(ext);
        'T': PostCbt.LootTakeMenu(treasure, items);
        'P': Money.PoolMoney;
        'S': if treasure then
               Money.ShareMoney;
        'D': if hasDetect then
               Magic.CastSpellNC(detectSpell, False, False, ext);
        'E', C_KEYS.NONE: begin
                            Money.DetermineTreasure(treasure, items);
                            done := not (treasure or items) or
                                    not Money.GoBackForIt('There is still treasure left.  ',
                                                          'Do you want to go back and claim your treasure?');
                          end;
      end;
    Stats.SettleCoins;
  until done;
end;

{ Monsters and hostile creatures are removed, counting the ones not enabled in C_GBVM.MONSTERS_DEFEATED; the others get
  their combat records freed, and while the Quick Ends With Fight setting is on (GameVars.quickEnds) party members leave
  Quick (quickfight 0) so that the treasure screen and the next combat find them under manual control. NPCs and animated
  creatures keep quickfight, as Space in combat leaves them. curChar is left at the list head. }
procedure PostCombatCreatureCleanup;
var
  p: Types.PCharRecord;
  next: Types.PCharRecord;
begin
  GameVars.zone1^[C_GBVM.MONSTERS_DEFEATED] := 0;
  p := GameVars.creatureList;
  while p <> nil do begin
    if IsMonster(p) or (p^.hostile = 1) then begin
      if p^.enabled <> 1 then
        Inc(GameVars.zone1^[C_GBVM.MONSTERS_DEFEATED]);
      next := p^.nextCharAddr;
      GameVars.curChar := p;
      SaveLoad.RemoveCreature(IsMonster(p), True);
      p := next;
    end else begin
      if p^.combatAddr <> nil then begin
        FreeMem(p^.combatAddr, SizeOf(Types.TCombatRec));
        p^.combatAddr := nil;
      end;
      if (GameVars.quickEnds <> 0) and CharHlp.ComesUnderPlayer(p) then
        p^.quickfight := 0;
      p := p^.nextCharAddr;
    end;
  end;
  GameVars.curChar := GameVars.creatureList;
end;

{ Each Okay NPC claims (npcTreasureShare and 7) shares, every other creature one share. Each coin type above 0 is cut
  into that many shares and the NPCs' shares are removed. If any coin type was cut, list the NPCs with a nonzero
  npcTreasureShare as taking their share. }
procedure NpcTreasureShare;
var
  p: Types.PCharRecord;
  npcShares: Byte;
  total: Byte;
  cut: LongInt;
  row: Byte;
  i: ShortInt;
  took: Boolean;
  ext: Boolean;
  c: Char;
begin
  took := False;
  p := GameVars.creatureList;
  npcShares := 0;
  total := 0;
  while p <> nil do begin
    { C_NPC.FLAG set }
    if CharHlp.IsNpc(p) and (p^.status = C_STATUS.OKAY) then begin
      Inc(npcShares, p^.npcTreasureShare and 7);
      Inc(total, p^.npcTreasureShare and 7);
    end else
      Inc(total);
    p := p^.nextCharAddr;
  end;
  if npcShares > 0 then
    for i := C_MONEY.COPPER to C_MONEY.JEWELRY do
      if GameVars.treasureMoney[i] > 0 then begin
        cut := GameVars.treasureMoney[i] div total;
        Dec(GameVars.treasureMoney[i], npcShares * cut);
        took := True;
      end;
  if took then begin
    Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0, White, '');
    p := GameVars.creatureList;
    row := 0;
    while p <> nil do begin
      { C_NPC.FLAG set }
      if CharHlp.IsNpc(p) and (p^.status = C_STATUS.OKAY) and (p^.npcTreasureShare > 0) then begin
        TextRend.DisplayMessageWindow(5, row + 5, 34, 22, LightGreen, True,
                                      p^.name + ' takes and hides his share.');
        Inc(row, 2);
      end;
      p := p^.nextCharAddr;
    end;
    c := MenuCore.MenuHorizontal('', 'press <enter>/<return> to continue', White, White, White,
                                 True, False, ext);
  end;
end;

{ Resolve combat results and remove combat state. On survival or in a duel, take the NPC shares, display the summary,
  offer loot and free the leftover treasure items; on defeat, set C_GBVM.COMBAT_RESULT to $80 and show the game-over
  screen. Then clear the one-combat GBVM modifiers: THAC0 adjustments, party movement, no-items and mirror duel, and
  write what the Bestiary learned in the fight, the next fight a new encounter for it (#842). }
procedure PostCombat;
begin
  GameVars.zone1^[C_GBVM.COMBAT_RESULT] := 0;
  nonEscapedHostileFound := False;
  GameVars.ifcState := C_IFC.LOOT;
  PostCbt.DetermineCombatResults;
  PostCbt.PostCombatCreatureCleanup;
  if not GameVars.partyDefeated or GameVars.duelFlag then begin
    PostCbt.NpcTreasureShare;
    PostCbt.PostCombatSummary(expShare);
    PostCbt.LootMenu;
    CharHlp.FreeItemList(GameVars.treasureItems);
  end else begin
    GameVars.zone1^[C_GBVM.COMBAT_RESULT] := $80;
    Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0, White, 'The END!');
    GameVars.curCol := 2;
    GameVars.curRow := 6;
    TextRend.DisplayMessageWindow(2, 5, 37, 22, LightGreen, True,
                                  'The monsters rejoice for the party has been destroyed');
    TextRend.DisplayAndPause(LightMagenta, 'Press any key to continue');
  end;
  GameVars.msgDelayFlag := 1;
  GameVars.zone1^[C_GBVM.MONSTER_HIT_MOD] := 0;
  GameVars.zone1^[C_GBVM.PARTY_HIT_MOD] := 0;
  GameVars.zone1^[C_GBVM.MOD_PARTY_MOVE] := 0;
  GameVars.zone1^[C_GBVM.NO_COMBAT_ITEMS] := 0;
  GameVars.zone1^[C_GBVM.MIRROR_DUEL] := 0;
  Bestiary.NewEncounter;
  BeastFil.Flush;
end;

end.

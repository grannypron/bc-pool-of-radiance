{ Resolve combat results, distribute experience and treasure, show the loot menus and clean up creatures. }
{$O+,F+}
unit PostCbt;

interface

{ Wrap up a combat: settle the outcome, award experience, run the loot menus and free the combat state. }
procedure PostCombat;

{ With both money and items left, loop on a Money/Items/Exit menu; with only one kind left, go straight to the money or
  item menu. }
procedure LootTakeMenu(var treasure, items: Boolean);

implementation

uses Types, Crt, C_Npc, C_Msg, GDConsts, GDVars, Shop, CharGen, Magic, C_Class, C_Keys, C_Status, C_Ifc, C_Gbvm,
  C_Money, Stats, Border, CharHlp, EclMenu, FxEngine, MenuCore, Money, TextRend, ViewChar, CharDisp;

const
  { AwardExperience: prime stat > 15 earns a 10% bonus }
  PRIME_STAT_THRESHOLD = 15;



{ Collect coins, experience and items from hostile creatures that did not run away. An item is taken when its value is
  above 0, or on a 3-in-10 roll while fewer than 8 items have been taken. Coins add experience (copper div 200, silver
  div 20, electrum div 2, gold x1, platinum x5, gems x250, jewelry x2200), as does each taken item's positive plus x400
  (items before GDVars.lastMissileItem). The total is divided by C_Gbvm.PARTY_SIZE minus nonAnimCount, and the share is
  0 when that leaves no one (a fight won by Animated members alone). A mirror duel instead awards 100 experience per
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
  if GDVars.duelFlag and (GDVars.zone1^[C_Gbvm.MIRROR_DUEL] <> 0) then
    share := GDVars.curChar^.levelHighest * 100
  else begin
    expTotal := 0;
    p := GDVars.creatureList;
    cnt := 0;
    while p <> nil do begin
      item := p^.itemsAddr;
      if (p^.hostile = 1) and (p^.status <> C_Status.RUNNING) then begin
        GDVars.nonEscapedHostileFound := True;
        for i := C_Money.COPPER to C_Money.JEWELRY do
          Inc(GDVars.treasureMoney[i], p^.coins[i]);
        expTotal := expTotal + p^.xpAward + LongInt(p^.xpBonusPerHp) * p^.hpRolled;
        if GDVars.zone1^[C_Gbvm.NO_COMBAT_ITEMS] <> 1 then
          while item <> nil do begin
            if (item^.value > 0) or ((cnt < 8) and (FxEngine.RollDice(1, 10) <= 3)) then begin
              Inc(cnt);
              if GDVars.treasureItems = nil then begin
                GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
                CharHlp.PrintItemString(item, 0, 0, False, False);
                GDVars.treasureItems^ := item^;
                GDVars.treasureItems^.equipped := 0;
                GDVars.treasureItems^.next := nil;
              end else begin
                q := GDVars.treasureItems;
                GetMem(GDVars.treasureItems, SizeOf(Types.TItemRec));
                CharHlp.PrintItemString(item, 0, 0, False, False);
                GDVars.treasureItems^ := item^;
                GDVars.treasureItems^.equipped := 0;
                GDVars.treasureItems^.next := q;
              end;
            end;
            item := item^.next;
          end;
      end;
      p := p^.nextCharAddr;
    end;
    Inc(expTotal, GDVars.treasureMoney[C_Money.COPPER] div 200);
    Inc(expTotal, GDVars.treasureMoney[C_Money.SILVER] div 20);
    Inc(expTotal, GDVars.treasureMoney[C_Money.ELECTRUM] div 2);
    Inc(expTotal, GDVars.treasureMoney[C_Money.GOLD]);
    Inc(expTotal, GDVars.treasureMoney[C_Money.PLATINUM] * 5);
    Inc(expTotal, GDVars.treasureMoney[C_Money.GEMS] * 250);
    Inc(expTotal, GDVars.treasureMoney[C_Money.JEWELRY] * 2200);
    q := GDVars.treasureItems;
    while (q <> nil) and (q <> GDVars.lastMissileItem) do begin
      if q^.plus > 0 then
        Inc(expTotal, q^.plus * 400);
      q := q^.next;
    end;
    sharers := GDVars.zone1^[C_Gbvm.PARTY_SIZE] - GDVars.nonAnimCount;
    if sharers > 0 then
      share := expTotal div sharers
    else
      share := 0;
  end;
end;

{ Every enabled, non-Animated creature in the list gets exp. A single-class cleric, fighter, magic-user or thief whose
  prime stat (Wis/Str/Int/Dex) is above PRIME_STAT_THRESHOLD (15) gets +10 pct, as does a paladin with Str and Wis or a
  ranger with Str, Int and Wis above it; other single classes get exp unchanged; two-class multiclasses get exp div 2,
  three-class (9 = C/F/M, 15 = F/M/T) exp div 3. }
procedure AwardExperience(experience: LongInt);
var
  p: Types.PCharRecord;
  share: LongInt;
begin
  p := GDVars.creatureList;
  while p <> nil do begin
    if (p^.enabled <> 0) and (p^.status <> C_Status.ANIMATED) then begin
      share := experience;
      case p^.charClass of
        C_Class.CLERIC: if p^.wisCur > PRIME_STAT_THRESHOLD then share := experience div 10 + experience;
        C_Class.FIGHTER: if p^.strCur > PRIME_STAT_THRESHOLD then share := experience div 10 + experience;
        C_Class.PALADIN:
          if (p^.strCur > PRIME_STAT_THRESHOLD) and (p^.wisCur > PRIME_STAT_THRESHOLD) then
            share := experience div 10 + experience;
        C_Class.RANGER:
          if (p^.strCur > PRIME_STAT_THRESHOLD) and (p^.intCur > PRIME_STAT_THRESHOLD) and
              (p^.wisCur > PRIME_STAT_THRESHOLD) then
            share := experience div 10 + experience;
        C_Class.MAGE: if p^.intCur > PRIME_STAT_THRESHOLD then share := experience div 10 + experience;
        C_Class.THIEF: if p^.dexCur > PRIME_STAT_THRESHOLD then share := experience div 10 + experience;
        C_Class.CLERIC_FIGHTER, C_Class.CLERIC_RANGER..C_Class.FIGHTER_THIEF,
          { 2-class multi }
          C_Class.MAGE_THIEF: share := experience div 2;
        C_Class.CLERIC_FIGHTER_MAGE, C_Class.FIGHTER_MAGE_THIEF:
          { 3-class multi }
          share := experience div 3;
      end;
      Inc(p^.experience, share);
    end;
    p := p^.nextCharAddr;
  end;
end;

{ True for a monster: notPcNpc = 1 in its combat record. A creature without a combat record counts as a party member;
  a COMBAT with no monsters (a treasure-only pickup) reaches the results without giving the party combat records. }
function IsMonster(p: Types.PCharRecord): Boolean;
begin
  IsMonster := (p^.combatAddr <> nil) and (p^.combatAddr^.notPcNpc = 1);
end;

{ Classify the combat outcome. Outside a duel the party (the creatures before the first notPcNpc = 1 entry) is defeated
  unless some non-hostile, non-NPC member is Running, Animated or Okay; while C_Gbvm.MIRROR_DUEL is 1 any non-hostile,
  non-NPC member will do, so a lost mirror duel does not end the game. Any Animated or Okay member wins the combat and
  experience is awarded; otherwise a Running member means the party fled. Not fled: Running members return Okay, Dying
  ones become Unconscious and Unconscious ones with HP above 0 recover. Fled: C_Gbvm.COMBAT_RESULT becomes $81, Running
  members return and every other member is removed. Defeated: every party member is removed and the party size is set to
  0. In a duel the party is never defeated: each enabled, Okay, non-hostile creature sets combatWon and triggers an
  experience award, Okay and Animated creatures are re-enabled and Dying ones become Unconscious. }
procedure DetermineCombatResults;
var
  p: Types.PCharRecord;
  nxt: Types.PCharRecord;
  b: Boolean;
begin
  GDVars.nonAnimCount := 0;
  GDVars.partyDefeated := True;
  GDVars.partyFled := False;
  p := GDVars.creatureList;
  while (p <> nil) and (not IsMonster(p)) do begin
    if p^.status = C_Status.RUNNING then
      GDVars.partyFled := True;
    p := p^.nextCharAddr;
  end;
  if GDVars.duelFlag then
    GDVars.partyDefeated := False;
  GDVars.combatWon := False;
  p := GDVars.creatureList;
  if not GDVars.duelFlag then begin
    while (p <> nil) and (not IsMonster(p)) do begin
      { C_Npc.FLAG clear }
      if ((p^.status = C_Status.RUNNING) or (p^.status = C_Status.ANIMATED) or
          (p^.status = C_Status.OKAY) or
          (GDVars.zone1^[C_Gbvm.MIRROR_DUEL] = 1)) and (p^.hostile = 0) and not CharHlp.IsNpc(p) then
        GDVars.partyDefeated := False;
      if (p^.status = C_Status.ANIMATED) or (p^.status = C_Status.OKAY) then begin
        GDVars.combatWon := True;
        GDVars.partyFled := False;
      end;
      if (p^.enabled = 0) or (p^.status = C_Status.ANIMATED) then
        Inc(GDVars.nonAnimCount);
      p := p^.nextCharAddr;
    end;
    if GDVars.combatWon then begin
      PostCbt.DetermineLootExp(GDVars.expShare);
      PostCbt.AwardExperience(GDVars.expShare);
    end;
    p := GDVars.creatureList;
    if not GDVars.partyDefeated then begin
      while (p <> nil) and (not IsMonster(p)) do begin
        { RemoveCreature below frees p }
        nxt := p^.nextCharAddr;
        if not GDVars.partyFled then begin
          case p^.status of
            C_Status.RUNNING: begin
                 p^.status := C_Status.OKAY;
                 p^.enabled := 1;
               end;
            C_Status.DYING: p^.status := C_Status.UNCONSCIOUS;
            C_Status.UNCONSCIOUS: if p^.hpCur > 0 then begin
                 p^.status := C_Status.OKAY;
                 p^.enabled := 1;
               end;
          end;
        end else begin
          GDVars.zone1^[C_Gbvm.COMBAT_RESULT] := $81;
          if p^.status = C_Status.RUNNING then begin
            p^.status := C_Status.OKAY;
            p^.enabled := 1;
          end else begin
            GDVars.curChar := p;
            CharGen.RemoveCreature(False, True);
          end;
        end;
        p := nxt;
      end;
    end else begin
      p := GDVars.creatureList;
      b := False;
      while (p <> nil) and not b do begin
        { RemoveCreature frees p }
        nxt := p^.nextCharAddr;
        if not IsMonster(p) then begin
          GDVars.curChar := p;
          CharGen.RemoveCreature(False, True);
        end else
          b := True;
        p := nxt;
      end;
      GDVars.zone1^[C_Gbvm.PARTY_SIZE] := 0;
    end;
  end else begin
    p := GDVars.creatureList;
    while p <> nil do begin
      if (p^.enabled = 1) and (p^.status = C_Status.OKAY) and (p^.hostile <> 1) then begin
        GDVars.combatWon := True;
        PostCbt.DetermineLootExp(GDVars.expShare);
        PostCbt.AwardExperience(GDVars.expShare);
      end;
      p := p^.nextCharAddr;
    end;
    p := GDVars.creatureList;
    while p <> nil do begin
      if (p^.status = C_Status.OKAY) or (p^.status = C_Status.ANIMATED) then
        p^.enabled := 1;
      if p^.status = C_Status.DYING then
        p^.status := C_Status.UNCONSCIOUS;
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
  Border.DrawWindow(1, 1, 38, 22, 0, White, '');
  if GDVars.nonEscapedHostileFound or GDVars.duelFlag then begin
    if GDVars.duelFlag and not GDVars.combatWon then begin
      TextRend.DisplayString(1, 3, LightGreen, 'You have lost the duel.');
      experience := 0;
    end else if GDVars.duelFlag then
      TextRend.DisplayString(1, 3, LightGreen, 'You have won the duel.')
    else
      TextRend.DisplayString(1, 3, LightGreen, 'The party has won.');
  end else begin
    if GDVars.partyFled then begin
      TextRend.DisplayString(1, 3, LightGreen, 'The party has fled.');
      experience := 0;
    end else
      TextRend.DisplayString(1, 3, LightGreen, 'The party has found Treasure!');
  end;
  Str(experience, numStr);
  if GDVars.duelFlag then
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
  p: Types.PItemRec;
begin
  redraw := True;
  Border.DrawWindow(1, 1, 38, 22, 0, White, 'Loot');
  p := GDVars.treasureItems;
  while p <> nil do begin
    CharHlp.PrintItemString(p, 0, 0, False, False);
    p := p^.next;
  end;
  head := GDVars.treasureItems;
  c := MenuCore.MenuVertical('Items: ', 'Take', LightMagenta, LightGreen, White, 1, 4, 38, 22,
                             head, True, redraw, idx, cursor);
  itemToTake := cursor;
end;

{ Take loop: give a copy to the current character, then unlink and free the treasure node. Ends on any key other than
  'T' or Enter, or when no treasure items are left. }
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
  cursor := GDVars.treasureItems;
  idx := 0;
  repeat
    PostCbt.LootTakeItemSelection(c, itemToTake, cursor, idx);
    if (c <> 'T') and (c <> C_Keys.ENTER) then
      done := True
    else begin
      done := False;
      Shop.GiveItemCopyToCreature(itemToTake, failed);
      { loot after a fight, not the vault's own items (#611) }
      if not failed and (GDVars.ifcState = C_Ifc.LOOT) then
        Stats.Count(GDVars.curChar, Stats.ITEMS_LOOTED, 1);
      if not failed then begin
        p := GDVars.treasureItems;
        if p = itemToTake then
          GDVars.treasureItems := itemToTake^.next
        else begin
          while p^.next <> itemToTake do
            p := p^.next;
          p^.next := itemToTake^.next;
        end;
        itemToTake^.next := nil;
        if itemToTake <> nil then
          FreeMem(itemToTake, SizeOf(Types.TItemRec));
        if GDVars.treasureItems = nil then
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
        case c of
          'M': begin
                 Money.TakeMoneyMenu;
                 CharDisp.DisplayNoncombatInterface;
               end;
          'I': PostCbt.LootTakeItemMenu;
          'E', C_Keys.NONE: done := True;
          'G': ViewChar.SelectPrevNextChar(c);
          'O': ViewChar.SelectPrevNextChar(c);
        end;
        CharDisp.DisplayParty(GDVars.curChar);
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

{ The loot menu is 'View Take Pool Share' with money left, 'View Take Pool' with only items left (each followed by '
  Detect Exit' when items are left and the current character has Detect Magic, spell 5 cleric / 11 magic-user,
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
        if (GDVars.curChar^.memorizedSpells[i] = 5) or (GDVars.curChar^.memorizedSpells[i] = 11) then begin
          hasDetect := True;
          detectSpell := GDVars.curChar^.memorizedSpells[i];
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
    case c of
      'V': ViewChar.ViewCharMenu(ext);
      'T': PostCbt.LootTakeMenu(treasure, items);
      'P': if not ext then Money.PoolMoney;
      'S': Money.ShareMoney;
      'D': Magic.CastSpellNC(detectSpell, False, False, ext);
      'E', C_Keys.NONE: begin
                 Money.DetermineTreasure(treasure, items);
                 done := not (treasure or items) or
                         not Money.GoBackForIt('There is still treasure left.  ',
                                               'Do you want to go back and claim your treasure?');
               end;
      'G': begin
             ViewChar.SelectPrevNextChar(c);
             CharDisp.DisplayParty(GDVars.curChar);
           end;
      'O': begin
             ViewChar.SelectPrevNextChar(c);
             CharDisp.DisplayParty(GDVars.curChar);
           end;
    end;
    Stats.SettleCoins;
  until done;
end;

{ Monsters and hostile creatures are removed, counting the ones not enabled in C_Gbvm.MONSTERS_DEFEATED; the others get
  their combat records freed, and while the Quick Ends With Fight setting is on (GDVars.quickEnds) party members leave
  Quick (quickfight 0) so that the treasure screen and the next combat find them under manual control. NPCs and
  animated creatures keep quickfight, as Space in combat leaves them. curChar is left at the list head. }
procedure PostCombatCreatureCleanup;
var
  p: Types.PCharRecord;
  next: Types.PCharRecord;
begin
  GDVars.zone1^[C_Gbvm.MONSTERS_DEFEATED] := 0;
  p := GDVars.creatureList;
  while p <> nil do begin
    if IsMonster(p) or (p^.hostile = 1) then begin
      if p^.enabled <> 1 then
        Inc(GDVars.zone1^[C_Gbvm.MONSTERS_DEFEATED]);
      next := p^.nextCharAddr;
      GDVars.curChar := p;
      CharGen.RemoveCreature(IsMonster(p), True);
      p := next;
    end else begin
      if p^.combatAddr <> nil then begin
        FreeMem(p^.combatAddr, SizeOf(Types.TCombatRec));
        p^.combatAddr := nil;
      end;
      if (GDVars.quickEnds <> 0) and CharHlp.ComesUnderPlayer(p) then
        p^.quickfight := 0;
      p := p^.nextCharAddr;
    end;
  end;
  GDVars.curChar := GDVars.creatureList;
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
  p := GDVars.creatureList;
  npcShares := 0;
  total := 0;
  while p <> nil do begin
    { C_Npc.FLAG set }
    if CharHlp.IsNpc(p) and (p^.status = C_Status.OKAY) then begin
      Inc(npcShares, p^.npcTreasureShare and 7);
      Inc(total, p^.npcTreasureShare and 7);
    end else
      Inc(total);
    p := p^.nextCharAddr;
  end;
  if npcShares > 0 then
    for i := C_Money.COPPER to C_Money.JEWELRY do
      if GDVars.treasureMoney[i] > 0 then begin
        cut := GDVars.treasureMoney[i] div total;
        Dec(GDVars.treasureMoney[i], npcShares * cut);
        took := True;
      end;
  if took then begin
    Border.DrawWindow(1, 1, 38, 22, 0, White, '');
    p := GDVars.creatureList;
    row := 0;
    while p <> nil do begin
      { C_Npc.FLAG set }
      if CharHlp.IsNpc(p) and (p^.status = C_Status.OKAY) and (p^.npcTreasureShare > 0) then begin
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
  offer loot and free the leftover treasure items; on defeat, set C_Gbvm.COMBAT_RESULT to $80 and show the game-over
  screen. Then clear the one-combat GBVM modifiers: THAC0 adjustments, party movement, no-items and mirror duel. }
procedure PostCombat;
begin
  GDVars.zone1^[C_Gbvm.COMBAT_RESULT] := 0;
  GDVars.nonEscapedHostileFound := False;
  GDVars.ifcState := C_Ifc.LOOT;
  PostCbt.DetermineCombatResults;
  PostCbt.PostCombatCreatureCleanup;
  if not GDVars.partyDefeated or GDVars.duelFlag then begin
    PostCbt.NpcTreasureShare;
    PostCbt.PostCombatSummary(GDVars.expShare);
    PostCbt.LootMenu;
    CharHlp.FreeItemList(GDVars.treasureItems);
  end else begin
    GDVars.zone1^[C_Gbvm.COMBAT_RESULT] := $80;
    Border.DrawWindow(1, 1, 38, 22, 0, White, 'The END!');
    GDVars.curCol := 2;
    GDVars.curRow := 6;
    TextRend.DisplayMessageWindow(2, 5, 37, 22, LightGreen, True,
                                  'The monsters rejoice for the party has been destroyed');
    TextRend.DisplayAndPause(LightMagenta, 'Press any key to continue');
  end;
  GDVars.msgDelayFlag := 1;
  GDVars.zone1^[C_Gbvm.MOD_MONSTER_THAC0] := 0;
  GDVars.zone1^[C_Gbvm.MOD_PARTY_THAC0] := 0;
  GDVars.zone1^[C_Gbvm.MOD_PARTY_MOVE] := 0;
  GDVars.zone1^[C_Gbvm.NO_COMBAT_ITEMS] := 0;
  GDVars.zone1^[C_Gbvm.MIRROR_DUEL] := 0;
end;

end.

{ Camp menus for spell preparation, resting, Fix healing, party order and the way to the Settings screen. Also provides
  the noncombat Cast menu. }

{$O+,F+}
unit Camp;

interface

{ Run the camp menu, preserving the interface state and clearing rest timers and pending spell activities. Return
  interrupted=True when a scripted random interruption ends a rest (GameTime.CampRest). }
procedure CampMainMenu(var interrupted: Boolean);

{ Run the noncombat Cast menu. Clear the remembered target on entry and redraw the noncombat interface afterwards if a
  spell was cast or the spell list was not empty. }
procedure NoncombatCastMenu;

implementation

uses Types, Crt, C_Msg, GDConsts, GDVars, CharGen, GameTime, C_Effect, C_Keys, C_Status, C_Ifc, C_Spell, C_Level,
  FxEngine, Portrait, Options, Border, C_Time, CharHlp, GameIo, Magic, MenuCore, SaveLoad, TextRend, ViewChar, StrUtil,
  CharDisp;

const
  { CanDoSpellActivity's activity selector: ACT_CAST, ACT_MEMORIZE or ACT_SCRIBE. }
  { cast a memorized spell }
  ACT_CAST = 1;
  { memorize spells from spellbook }
  ACT_MEMORIZE = 2;
  { scribe scrolls into spellbook }
  ACT_SCRIBE = 3;

{ Return preparation time in minutes: 15 minutes per pending spell level, plus four hours if any spells are pending, or
  six hours if any is level 3 or higher. Count both memorizing and scribing (readable items only), and store the base
  hours (0, 4 or 6) in spellPrepTime. }
function CampSpellPrepTime(creature: Types.PCharRecord): Word;
var
  { highest pending level per kind }
  maxMem: Byte;
  maxScr: Byte;
  { SUM of pending spell levels }
  cntMem: Byte;
  cntScr: Byte;
  p: Types.PItemRec;
  i: Byte;
  lvl: Byte;
  base: Byte;
begin
  maxMem := 0;
  maxScr := 0;
  cntMem := 0;
  cntScr := 0;
  for i := 0 to SizeOf(creature^.memorizedSpells) - 1 do
    if creature^.memorizedSpells[i] > C_Spell.ID_MASK then begin
      lvl := GDConsts.spellTable[creature^.memorizedSpells[i] and C_Spell.ID_MASK].levelSp;
      if lvl > maxMem then maxMem := lvl;
      Inc(cntMem, lvl);
    end;
  p := creature^.itemsAddr;
  while p <> nil do begin
    if Magic.ItemReadable(p) then
      for i := 1 to SizeOf(p^.spells) do
        if p^.spells[i] > C_Spell.ID_MASK then begin
          lvl := GDConsts.spellTable[p^.spells[i] and C_Spell.ID_MASK].levelSp;
          if lvl > maxScr then maxScr := lvl;
          Inc(cntScr, lvl);
        end;
    p := p^.next;
  end;
  base := 0;
  if (cntMem > 0) or (cntScr > 0) then
    base := 4;
  if (maxMem > 2) or (maxScr > 2) then
    base := 6;
  creature^.spellPrepTime := base;
  CampSpellPrepTime := base * 60 + cntMem * 15 + cntScr * 15;
end;

{ Clear every slot marked for memorizing (removing the spell entirely, unlike ResetScribe, which only strips the mark)
  and clear the base prep time. }
procedure ResetMemorize(creature: Types.PCharRecord);
var
  i: Byte;
begin
  for i := 0 to SizeOf(creature^.memorizedSpells) - 1 do
    if creature^.memorizedSpells[i] > C_Spell.ID_MASK then
      creature^.memorizedSpells[i] := 0;
  creature^.spellPrepTime := 0;
end;

{ Strip the pending flag from every scroll spell on every readable item. }
procedure ResetScribe(creature: Types.PCharRecord);
var
  i: Byte;
  p: Types.PItemRec;
begin
  p := creature^.itemsAddr;
  while p <> nil do begin
    if Magic.ItemReadable(p) then
      for i := 1 to SizeOf(p^.spells) do
        p^.spells[i] := p^.spells[i] and C_Spell.ID_MASK;
    p := p^.next;
  end;
end;

{ Run ResetMemorize and ResetScribe on every creature in the list. }
procedure ResetPartySpellActivities;
var
  p: Types.PCharRecord;
begin
  p := GDVars.creatureList;
  while p <> nil do begin
    Camp.ResetMemorize(p);
    Camp.ResetScribe(p);
    p := p^.nextCharAddr;
  end;
end;

{ Return the current character's spell allowance for a class and level minus its memorized and pending spells of that
  class and level, or 0 when as many or more are memorized than allowed (e.g. after level drain). }
function SpellSlotsRemaining(lvl, typ: ShortInt): Byte;
var
  count: Byte;
  i: Byte;
begin
  count := 0;
  for i := 0 to SizeOf(GDVars.curChar^.memorizedSpells) - 1 do
    if GDVars.curChar^.memorizedSpells[i] > 0 then
      if (GDConsts.spellTable[GDVars.curChar^.memorizedSpells[i] and C_Spell.ID_MASK].levelSp = lvl) and
          (GDConsts.spellTable[GDVars.curChar^.memorizedSpells[i] and C_Spell.ID_MASK].castClassSp = typ) then
        Inc(count);
  if count >= GDVars.curChar^.slots[typ, lvl] then
    SpellSlotsRemaining := 0
  else
    SpellSlotsRemaining := GDVars.curChar^.slots[typ, lvl] - count;
end;

{ Check whether the current character can cast, memorize or scribe. Anti-magic blocks casting; animated or disabled
  characters cannot do any of these. Held and asleep are effects, so these status checks do not detect them. On failure,
  display the character's name and the reason. }
function CanDoSpellActivity(activity: Byte): Boolean;
var
  msg: Types.TStr40;
begin
  msg := '';
  if (activity = ACT_CAST) and (GDVars.zone0^.antimagic > 0) then
    msg := 'cannot cast spells in this area'
  else if (GDVars.curChar^.status = C_Status.ANIMATED) or (GDVars.curChar^.enabled = 0) then begin
    msg := 'is in no condition to ';
    case activity of
      ACT_CAST: msg := msg + 'cast any spells';
      ACT_MEMORIZE: msg := msg + 'memorize spells';
      ACT_SCRIBE: msg := msg + 'scribe any scrolls';
    end;
  end;
  if msg = '' then
    CanDoSpellActivity := True
  else begin
    CanDoSpellActivity := False;
    CharDisp.PrintNameString(GDVars.curChar, msg, 10, True);
  end;
end;

{ Loop the Cast list (memorized spells and readable scroll spells); on a pick, frame the message window and cast a
  memorized spell through Magic.CastSpellNC, or a scroll spell from its own scroll as Use does (ViewChar.UseItemSpell,
  which asks 'Use it?' of a combat-only one and otherwise names the spell as a memorized cast does), followed by Use's
  CharHlp.RecalcStats. An empty list prints 'has no spells memorized'. }
procedure NoncombatCastMenu;
var
  idx: Integer;
  notEmpty: Boolean;
  redraw: Boolean;
  { CastSpellNC's var out, unread }
  castSel: Boolean;
  spellId: Byte;
  { the scroll the spell is cast from, nil for a memorized one }
  scroll: Types.PItemRec;
  caster: Types.PCharRecord;
begin
  redraw := False;
  idx := -1;
  GDVars.castTarget := nil;
  if Camp.CanDoSpellActivity(ACT_CAST) then begin
    repeat
      spellId := ViewChar.CastSpellMenu(idx, notEmpty, scroll);
      if spellId <> C_Spell.NONE then begin
        redraw := True;
        Border.DrawBorder(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, 0);
        Border.ClearBox(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
        if scroll = nil then
          Magic.CastSpellNC(spellId, False, True, castSel)
        else begin
          caster := GDVars.curChar;
          ViewChar.UseItemSpell(scroll, spellId, True, castSel);
          { recount the items and their weight, as Items > Use does: the scroll may be gone }
          CharHlp.RecalcStats(caster);
        end;
        idx := -1;
      end else begin
        if notEmpty then
          redraw := True
        else
          CharDisp.PrintNameString(GDVars.curChar, 'has no spells memorized', 10, True);
      end;
    until spellId = C_Spell.NONE;
  end;
  if redraw then
    CharDisp.DisplayNoncombatInterface;
end;

{ Show remaining spell slots by class and level. A level with no allowance is blank; a full level shows zero. Return
  True whenever the character has any spell allowance, even if all slots are occupied. }
function DisplaySpellSlots: Boolean;
var
  s: Types.TStr40;
  slotStr: array[1..3, 0..1] of String[2];
  canDo: array[0..1] of Byte;
  typ: ShortInt;
  lvl: ShortInt;
  col: Byte;
  row: Byte;
  any: Boolean;
begin
  any := False;
  for typ := 0 to 1 do begin
    canDo[typ] := 0;
    for lvl := 1 to 3 do begin
      slotStr[lvl, typ] := StrUtil.NumStr(Camp.SpellSlotsRemaining(lvl, typ));
      if GDVars.curChar^.slots[typ, lvl] = 0 then
        slotStr[lvl, typ] := ' '
      else begin
        canDo[typ] := 1;
        any := True;
      end;
    end;
  end;
  if any then begin
    CharDisp.PrintNameString(GDVars.curChar, 'can memorize:', 10, False);
    row := 3;
    for typ := 0 to 1 do begin
      if canDo[typ] <> 0 then begin
        case typ of
          0: s := '    Cleric Spells:';
          1: s := 'Magic-User Spells:';
        end;
        TextRend.DisplayString(1, row + 17, LightGreen, s);
        col := 19;
        for lvl := 1 to 3 do begin
          TextRend.DisplayString(col + 1, row + 17, LightGreen, slotStr[lvl, typ]);
          Inc(col, 3);
        end;
        Inc(row);
      end;
    end;
  end;
  DisplaySpellSlots := any;
end;

{ Seed the rest clock (hours, tens of minutes, minutes) from the party's longest spell-prep time, run GameTime.CampRest,
  then clear the clock and update the misc-info line. }
procedure CampRestMenu(var interrupted: Boolean);
var
  p: Types.PCharRecord;
  total: Word;
  t: Word;
begin
  total := 0;
  p := GDVars.creatureList;
  while p <> nil do begin
    t := Camp.CampSpellPrepTime(p);
    if total < t then total := t;
    p := p^.nextCharAddr;
  end;
  GDVars.dsRestingTimeGbvm[3] := total div 60;
  GDVars.dsRestingTimeGbvm[2] := (total - 60 * GDVars.dsRestingTimeGbvm[3]) div 10;
  GDVars.dsRestingTimeGbvm[1] := total mod 10;
  interrupted := GameTime.CampRest(True);
  FillChar(GDVars.dsRestingTimeGbvm, SizeOf(GDVars.dsRestingTimeGbvm), 0);
  CharDisp.PrintMiscInfo;
end;

{ Sort memorized spells by their masked IDs, keeping the pending flag attached to each spell. }
procedure SortMemorizedSpells;
var
  i: Byte;
  j: Byte;
  tmp: Byte;
begin
  for i := 0 to SizeOf(GDVars.curChar^.memorizedSpells) - 2 do
    for j := i to SizeOf(GDVars.curChar^.memorizedSpells) - 1 do
      if (GDVars.curChar^.memorizedSpells[i] and C_Spell.ID_MASK) > (GDVars.curChar^.memorizedSpells[j] and
                                                                     C_Spell.ID_MASK) then begin
        tmp := GDVars.curChar^.memorizedSpells[i];
        GDVars.curChar^.memorizedSpells[i] := GDVars.curChar^.memorizedSpells[j];
        GDVars.curChar^.memorizedSpells[j] := tmp;
      end;
end;

{ Remember the current character's memorized and pending spells as its usual spells (SaveLoad.SetUsualSpells). }
procedure RememberUsualSpells;
var
  spells: Types.TSpellSlots;
  i: Byte;
begin
  for i := 0 to SizeOf(spells) - 1 do
    spells[i] := GDVars.curChar^.memorizedSpells[i] and C_Spell.ID_MASK;
  SaveLoad.SetUsualSpells(GDVars.curChar, spells);
end;

{ True when the current character has a slot of this class and level left. Unlike SpellSlotsRemaining it bounds the
  level (levels past 3 have no slots) and skips memorized ids outside the spell table. }
function SlotFree(lvl, typ: ShortInt): Boolean;
var
  count: Integer;
  i: Byte;
  id: Byte;
begin
  SlotFree := False;
  if (lvl >= 1) and (lvl <= 3) and (typ >= 0) and (typ <= 1) then begin
    count := 0;
    for i := 0 to SizeOf(GDVars.curChar^.memorizedSpells) - 1 do begin
      id := GDVars.curChar^.memorizedSpells[i] and C_Spell.ID_MASK;
      if (id >= 1) and (id <= SizeOf(GDConsts.spellTable) div SizeOf(GDConsts.spellTable[1])) then
        if (GDConsts.spellTable[id].levelSp = lvl) and (GDConsts.spellTable[id].castClassSp = typ) then
          Inc(count);
    end;
    SlotFree := count < GDVars.curChar^.slots[typ, lvl];
  end;
end;

{ Mark as pending each of the current character's usual spells that it lacks, still knows and has a free slot for, in
  turn, so later ones see the slots the earlier ones took. }
procedure QueueUsualSpells;
var
  usual: Types.TSpellSlots;
  have: Types.TSpellSlots;
  i: Byte;
  j: Byte;
  k: Byte;
  id: Byte;
  found: Boolean;
begin
  if SaveLoad.GetUsualSpells(GDVars.curChar, usual) then begin
    for i := 0 to SizeOf(have) - 1 do
      have[i] := GDVars.curChar^.memorizedSpells[i] and C_Spell.ID_MASK;
    for i := 0 to SizeOf(usual) - 1 do begin
      id := usual[i];
      if (id > 0) and (id <= SizeOf(GDVars.curChar^.spellsKnown)) then begin
        { a copy already memorized or pending covers this one }
        found := False;
        for j := 0 to SizeOf(have) - 1 do
          if (not found) and (have[j] = id) then begin
            have[j] := 0;
            found := True;
          end;
        if (not found) and (GDVars.curChar^.spellsKnown[id] <> 0) then
          if Camp.SlotFree(GDConsts.spellTable[id].levelSp, GDConsts.spellTable[id].castClassSp) then begin
            k := 0;
            while (k < SizeOf(GDVars.curChar^.memorizedSpells)) and (GDVars.curChar^.memorizedSpells[k] <> 0) do
              Inc(k);
            if k < SizeOf(GDVars.curChar^.memorizedSpells) then
              GDVars.curChar^.memorizedSpells[k] := id + C_Spell.PENDING_FLAG;
          end;
      end;
    end;
    Camp.SortMemorizedSpells;
  end;
end;

{ With nothing pending, first queue the character's usual spells that it lacks. Then show the pending list under the
  question (Yes keeps it and skips selection, No clears it), so the usual spells are one keypress away and No leads to
  choosing. Otherwise loop the spellbook menu, marking picks as pending while slots remain, and confirm again at the end
  once the spellbook menu has run (idx <> -1). A confirmed list becomes the usual spells. }
procedure CampMemorizeMenu;
var
  done: Boolean;
  notEmpty: Boolean;
  redraw: Boolean;
  spellId: Byte;
  i: Byte;
  idx: Integer;
  pending: Boolean;
begin
  if Camp.CanDoSpellActivity(ACT_MEMORIZE) then begin
    done := False;
    pending := False;
    for i := 0 to SizeOf(GDVars.curChar^.memorizedSpells) - 1 do
      if GDVars.curChar^.memorizedSpells[i] > C_Spell.ID_MASK then
        pending := True;
    if not pending then
      Camp.QueueUsualSpells;
    idx := -1;
    spellId := ViewChar.SpellMenu(5, 5, idx, notEmpty);
    redraw := True;
    if notEmpty then begin
      if MenuCore.YesNoMenu('Memorize These Spells? ', Yellow, LightGreen, White) = 'N' then
        Camp.ResetMemorize(GDVars.curChar)
      else begin
        Camp.RememberUsualSpells;
        done := True;
      end;
    end else
      redraw := False;
    idx := -1;
    while done = False do begin
      done := Camp.DisplaySpellSlots = False;
      if done then
        CharDisp.PrintNameString(GDVars.curChar, 'cannot memorize any spells', 10, True)
      else begin
        spellId := ViewChar.SpellMenu(1, 2, idx, notEmpty);
        redraw := True;
        if spellId = C_Spell.NONE then
          done := True
        else if Camp.SpellSlotsRemaining(GDConsts.spellTable[spellId].levelSp,
                                         GDConsts.spellTable[spellId].castClassSp) > 0
        then begin
          { Sorting puts empty spell slots first; a full array takes nothing }
          i := 0;
          while (i < SizeOf(GDVars.curChar^.memorizedSpells)) and (GDVars.curChar^.memorizedSpells[i] <> 0) do
            Inc(i);
          if i < SizeOf(GDVars.curChar^.memorizedSpells) then begin
            GDVars.curChar^.memorizedSpells[i] := spellId + C_Spell.PENDING_FLAG;
            Camp.SortMemorizedSpells;
          end;
        end;
      end;
    end;
    if idx <> -1 then begin
      idx := -1;
      spellId := ViewChar.SpellMenu(5, 5, idx, notEmpty);
      if notEmpty then
        if MenuCore.YesNoMenu('Memorize these spells? ', Yellow, LightGreen, White) = 'N' then
          Camp.ResetMemorize(GDVars.curChar)
        else
          Camp.RememberUsualSpells;
    end;
    if redraw then
      CharDisp.DisplayNoncombatInterface;
  end;
end;

{ Confirm pending scribing (Yes keeps it and skips selection), then let the player mark scroll spells. Reject known,
  pending or unavailable spells. The marking walk does not check Magic.ItemReadable: the first unmarked byte equal to
  the spell ID in any item's spells view is marked. }
procedure CampScribeMenu;
var
  done: Boolean;
  notEmpty: Boolean;
  redraw: Boolean;
  spellId: Byte;
  i: Byte;
  idx: Integer;
  p: Types.PItemRec;
  found: Boolean;
begin
  if Camp.CanDoSpellActivity(ACT_SCRIBE) then begin
    done := False;
    idx := -1;
    spellId := ViewChar.SpellMenu(6, 0, idx, notEmpty);
    redraw := True;
    if notEmpty then begin
      if MenuCore.YesNoMenu('Scribe These Spells? ', Yellow, LightGreen, White) = 'N' then
        Camp.ResetScribe(GDVars.curChar)
      else
        done := True;
    end else
      redraw := False;
    idx := -1;
    while done = False do begin
      spellId := ViewChar.SpellMenu(3, 3, idx, notEmpty);
      if spellId = C_Spell.NONE then begin
        done := True;
        if notEmpty = False then
          CharDisp.PrintNameString(GDVars.curChar, 'has no copyable scrolls', 10, True)
        else
          redraw := True;
      end else if (spellId > SizeOf(GDVars.curChar^.spellsKnown)) or (GDConsts.spellTable[spellId].levelSp < 1) or
          (GDConsts.spellTable[spellId].levelSp > 3) or (GDConsts.spellTable[spellId].castClassSp < 0) or
          (GDConsts.spellTable[spellId].castClassSp > 1) then begin
        { a scroll byte past the spells a character can know, or a spell with no memorize slot, is not scribed }
        redraw := True;
        CharDisp.PrintBottomLine('You can not scribe that spell.');
      end else begin
        redraw := True;
        if GDVars.curChar^.spellsKnown[spellId] <> 0 then
          CharDisp.PrintBottomLine('You already know that spell')
        else begin
          p := GDVars.curChar^.itemsAddr;
          found := False;
          while (p <> nil) and (found = False) do begin
            if Magic.ItemReadable(p) then
              for i := 1 to SizeOf(p^.spells) do
                if (p^.spells[i] > C_Spell.ID_MASK) and
                    (p^.spells[i] and C_Spell.ID_MASK = spellId) then begin
                  CharDisp.PrintBottomLine('You are already scibing that spell');
                  found := True;
                end;
            p := p^.next;
          end;
          if found = False then begin
            if GDVars.curChar^.slots[GDConsts.spellTable[spellId].castClassSp,
                                       GDConsts.spellTable[spellId].levelSp] > 0
            then begin
              p := GDVars.curChar^.itemsAddr;
              while (p <> nil) and (found = False) do begin
                i := 1;
                repeat
                  if p^.spells[i] = spellId then begin
                    p^.spells[i] := p^.spells[i] or C_Spell.PENDING_FLAG;
                    found := True;
                  end;
                  Inc(i);
                until (i > SizeOf(p^.spells)) or found;
                p := p^.next;
              end;
            end else
              CharDisp.PrintBottomLine('You can not scribe that spell.');
          end;
        end;
      end;
    end;
    if idx <> -1 then begin
      idx := -1;
      spellId := ViewChar.SpellMenu(6, 0, idx, notEmpty);
      if notEmpty then
        if MenuCore.YesNoMenu('Scribe these spells? ', Yellow, LightGreen, White) = 'N' then
          Camp.ResetScribe(GDVars.curChar);
    end;
    if redraw then
      CharDisp.DisplayNoncombatInterface;
  end;
end;

{ Build the effect-display list with a heading for each character. Use the spell name for spell effects, fixed labels
  for other visible effects, and 'Funky--<id>' when no named spell produces a listed effect; other IDs are hidden.
  Stinking Cloud's cough is not included. }
procedure CampDisplayMenu;
var
  effect: Types.PEffectRec;
  head: Types.PItemRec;
  cur: Types.PItemRec;
  ch: Types.PCharRecord;
  id: Byte;
  k: Byte;
  { effects listed for this char }
  cnt: Byte;
  found: Boolean;
  show: Boolean;
  menuRedraw: Boolean;
  s: Types.TStr40;
  idx: Integer;
  c: Char;

  { Append a TMenuNode-sized node after cur and advance cur to it; title sets inUse }
  procedure AddToList(title: Boolean; s: Types.TStr40);
  begin
    GetMem(cur^.next, SizeOf(Types.TMenuNode));
    cur := cur^.next;
    cur^.next := nil;
    cur^.name := s;
    cur^.inUse := Ord(title);
  end;

begin
  GetMem(head, SizeOf(Types.TMenuNode));
  cur := head;
  cur^.inUse := 0;
  cur^.name := ' ';
  cur^.next := nil;
  ch := GDVars.creatureList;
  while ch <> nil do begin
    cnt := 0;
    AddToList(True, ch^.name);
    effect := ch^.effectsAddr;
    while effect <> nil do begin
      show := True;
      id := effect^.id;
      case id of
        C_Effect.BLESS, C_Effect.CURSE, C_Effect.DETECT_MAGIC, C_Effect.PROT_EVIL..C_Effect.FRIENDS,
            C_Effect.READ_MAGIC, C_Effect.SHIELD,
        C_Effect.FIND_TRAPS..C_Effect.INVISIBLE, C_Effect.MIRROR_IMAGE, C_Effect.ENFEEBLE,
            C_Effect.ANIMATE_DEAD..C_Effect.DISEASED,
        C_Effect.BESTOW_CURSE..C_Effect.HASTED, C_Effect.PROT_MISSILES, C_Effect.SLOWED,
            C_Effect.PROT_EVIL_10FT, C_Effect.PROT_GOOD_10FT,
        C_Effect.PRAYER, C_Effect.SNAKE_CHARM..C_Effect.SLEEP:
          begin
            { Find the named spell that produces this effect. Only IDs 1..56 have spell names; higher IDs are item
              effects. }
            k := 1;
            found := False;
            while (k <= 56) and (found = False) do
              if GDConsts.spellTable[k].effect = id then begin
                s := GDConsts.spellNames[k];
                found := True;
              end else
                Inc(k);
            if found = False then
              s := 'Funky--' + StrUtil.NumStr(id);
          end;
        C_Effect.TRAIN_START: s := 'Studying Manual of Bodily Health';
        C_Effect.TRAIN_MANUAL: s := 'Training with Manual of Bodily Health';
        C_Effect.FEATHER_FALL: s := 'Feather Fall';
        C_Effect.HELPLESS: s := 'Helpless';
        C_Effect.ALLIED_PRAYER: s := 'Prayer';
        C_Effect.DISEASE_HP: s := 'Cause Disease';
        C_Effect.ROT_NO_HEAL: s := 'Dreaded Mummy Disease';
        C_Effect.DRAGON_AURA: s := 'Repulsed';
        C_Effect.POISONED: s := 'Poisoned';
        C_Effect.TROLL_REGEN: s := 'Regenerating';
        C_Effect.RING_FIRE_RES: s := 'Fire Resistance';
        C_Effect.DUST_DISAPPEAR: s := 'Invisible';
        C_Effect.CAMOUFLAGE: s := 'Camouflaged';
        C_Effect.DISPLACED: s := 'Displaced';
      else
        show := False;
      end;
      if show then begin
        Inc(cnt);
        AddToList(False, ' ' + s);
      end;
      effect := effect^.next;
    end;
    if cnt = 0 then
      AddToList(False, ' <No Spell Effects>');
    AddToList(False, ' ');
    ch := ch^.nextCharAddr;
  end;
  menuRedraw := True;
  idx := 0;
  Border.DrawWindow(1, 1, 38, 22, 0, White, 'Display');
  c := MenuCore.MenuVertical('', '', LightCyan, LightGreen, White, 1, 4, 38, 22, head, True,
                             menuRedraw, idx, cur);
  MenuCore.FreeStringList(head);
  CharDisp.DisplayNoncombatInterface;
end;

{ Run the magic menu ('Cast Memorize Scribe Display Rest Exit'); extended keys switch character. Ends on Exit, Escape or
  an interrupted rest. }
procedure CampMagicMenu(var interrupted: Boolean);
var
  c: Char;
  ext: Boolean;
begin
  c := ' ';
  while (interrupted = False) and (not (c in [C_Keys.NONE, 'E'])) do begin
    c := MenuCore.MenuHorizontal('', GDConsts.magicMenu, LightMagenta, LightGreen, White, True, True, ext);
    if ext then begin
      ViewChar.SelectPrevNextChar(c);
      CharDisp.DisplayParty(GDVars.curChar);
    end else
      case c of
        'C': Camp.NoncombatCastMenu;
        'M': Camp.CampMemorizeMenu;
        'S': Camp.CampScribeMenu;
        'D': Camp.CampDisplayMenu;
        'R': Camp.CampRestMenu(interrupted);
      end;
  end;
end;

{ Move the current character one position earlier in the party list; if already first, it wraps to the end. prev trails
  two behind the current character. }
procedure OrderMoveUp;
var
  prev: Types.PCharRecord;
  p: Types.PCharRecord;
  savedNext: Types.PCharRecord;
begin
  p := GDVars.creatureList;
  prev := nil;
  if p = GDVars.curChar then begin
    while p^.nextCharAddr <> nil do
      p := p^.nextCharAddr;
  end else
    while p^.nextCharAddr <> GDVars.curChar do begin
      prev := p;
      p := p^.nextCharAddr;
    end;
  savedNext := GDVars.curChar^.nextCharAddr;
  if GDVars.creatureList = GDVars.curChar then begin
    { first -> last (p walked to the tail above) }
    if savedNext <> nil then
      GDVars.creatureList := savedNext;
    p^.nextCharAddr := GDVars.curChar;
    GDVars.curChar^.nextCharAddr := nil;
  end else begin
    { p = predecessor: unlink and reinsert one earlier }
    p^.nextCharAddr := savedNext;
    GDVars.curChar^.nextCharAddr := p;
    if (p = GDVars.creatureList) or (prev = nil) then
      GDVars.creatureList := GDVars.curChar
    else
      prev^.nextCharAddr := GDVars.curChar;
  end;
end;

{ Move the current character one position later in the party list; if already last, it wraps to the front. }
procedure OrderMoveDown;
var
  p: Types.PCharRecord;
  next: Types.PCharRecord;
begin
  p := GDVars.creatureList;
  if p <> GDVars.curChar then
    while p^.nextCharAddr <> GDVars.curChar do
      p := p^.nextCharAddr;
  next := GDVars.curChar^.nextCharAddr;
  if next = nil then begin
    GDVars.curChar^.nextCharAddr := GDVars.creatureList;
    GDVars.creatureList := GDVars.curChar;
    p^.nextCharAddr := next;
  end else begin
    GDVars.curChar^.nextCharAddr := next^.nextCharAddr;
    if GDVars.creatureList = GDVars.curChar then
      GDVars.creatureList := next;
    if p <> GDVars.curChar then
      p^.nextCharAddr := next;
    next^.nextCharAddr := GDVars.curChar;
  end;
end;

{ Reorder the party through Select and Place modes. In Select mode extended keys pick a character; in Place mode Home
  moves it up and End moves it down. P and S switch modes; Enter takes the highlighted option. }
procedure CampOrderMenu;
var
  selected: ShortInt;
  ext: Boolean;
  c: Char;
begin
  selected := 0;
  c := ' ';
  while not (c in [C_Keys.NONE, 'E']) do begin
    c := MenuCore.MenuHorizontal('Party Order: ', GDConsts.orderMenus[selected], LightMagenta, LightGreen,
                                 White, True, True, ext);
    if ext then begin
      if selected = 0 then begin
        ViewChar.SelectPrevNextChar(c);
        CharDisp.DisplayParty(GDVars.curChar);
      end else begin
        case c of
          C_Keys.HOME: Camp.OrderMoveUp;
          C_Keys.END_KEY: Camp.OrderMoveDown;
        end;
        CharDisp.DisplayParty(GDVars.curChar);
      end;
    end else
      if c in ['P', 'S'] then begin
        selected := Ord(selected = 0);
        if selected <> 0 then
          CharDisp.PrintNameString(GDVars.curChar, 'has been selected', 10, False)
        else
          CharDisp.ClearMessageWindow;
      end;
  end;
end;

{ Drop the current character from the party after confirmation, with a farewell message that depends on enabled; then
  clear the roster panel and redraw the party. For the last party member, offer to quit to DOS instead. }
procedure CampDropMenu;
begin
  if (GDVars.curChar^.nextCharAddr = nil) and (GDVars.curChar = GDVars.creatureList) then begin
    { last member: quit-to-DOS confirm }
    if MenuCore.YesNoMenu('quit TO DOS: ', Yellow, LightGreen, White) = 'Y' then begin
      CharGen.RemoveCreature(False, True);
      GameIo.ExitGame;
    end else
      Exit;
    Exit;
  end;
  CharDisp.PrintNameString(GDVars.curChar, 'will be gone', 10, False);
  if MenuCore.YesNoMenu('Drop from party? ', Yellow, LightGreen, White) = 'Y' then begin
    if GDVars.curChar^.enabled <> 0 then
      CharDisp.PrintNameString(GDVars.curChar, 'bids you farewell', 10, True)
    else
      CharDisp.PrintNameString(GDVars.curChar, 'is dumped in a ditch', 10, True);
    CharGen.RemoveCreature(False, True);
    Border.ClearBox(17, 1, 38, 11);
    CharDisp.DisplayParty(GDVars.curChar);
  end else
    CharDisp.PrintNameString(GDVars.curChar, 'Breathes A sigh of relief', 10, True);
end;

{ Run the Alter menu ('Order Drop Char Settings Exit'). Char opens a submenu for the current character's icon or
  portrait; Portrait is offered only where the player portraits can be shown (Portrait.PlayerPortraitsHere). The
  selection keys pick another character there too, as in Alter itself. Settings opens the Settings screen
  (Options.OptionsMenu), which holds the game speed with the other settings. }
procedure CampAlterMenu;
var
  c: Char;
  c2: Char;
  ext: Boolean;
  s: Types.TStr40;
begin
  c := ' ';
  while not (c in [C_Keys.NONE, 'E']) do begin
    c := MenuCore.MenuHorizontal('Alter: ', GDConsts.alterMenu, LightMagenta, LightGreen, White, True, True,
                                 ext);
    if ext then begin
      ViewChar.SelectPrevNextChar(c);
      CharDisp.DisplayParty(GDVars.curChar);
    end else
      case c of
        'O': Camp.CampOrderMenu;
        'D': Camp.CampDropMenu;
        'C': repeat
               if Portrait.PlayerPortraitsHere then
                 s := 'Icon Portrait Exit'
               else
                 s := 'Icon Exit';
               c2 := MenuCore.MenuHorizontal('Character: ', s, LightMagenta, LightGreen, White, True, True, ext);
               if ext then begin
                 ViewChar.SelectPrevNextChar(c2);
                 CharDisp.DisplayParty(GDVars.curChar);
               end else
                 case c2 of
                   'I': begin
                          CharGen.CustomizeIcon;
                          CharDisp.DisplayNoncombatInterface;
                        end;
                   'P': if Portrait.PlayerPortraitsHere then begin
                          CharGen.CustomizePortrait;
                          CharDisp.DisplayNoncombatInterface;
                        end;
                 end;
             until (not ext) and (c2 in [C_Keys.NONE, 'E']);
        'S': begin
               Options.OptionsMenu;
               CharDisp.DisplayNoncombatInterface;
             end;
      end;
  end;
end;

{ Fix, as in Curse of the Azure Bonds and Pools of Darkness: rest while the party's clerics cure and heal everyone.
  Each cleric level-3 slot of a conscious (status OKAY) caster cures one condition -- disease first (Cure Disease also
  clears mummy rot, which would block the healing), then blindness, then Bestow Curse. Each level-1 slot of such a
  caster who knows Cure Light Wounds heals 1d8, cast only as often as the party's wounds need on average. The casts go
  to the least busy caster, and the rest lasts as long as the busiest one needs by the memorize rule: 4 hours (6 with
  a level-3 spell) plus 15 minutes per spell level. Nothing happens unless the whole rest is completed; interrupted
  reports a rest broken off by a scripted random interruption. A party with no cleric, or with none conscious, is told
  so and does not rest, as is a party with nothing Fix can treat or no slot to treat it with. }
procedure CampFixMenu(var interrupted: Boolean);
const
  { the members planned for; a longer creature list is not looked at past this }
  MAX_PARTY = 8;
  { Conditions, cured in this order. }
  FIX_DISEASE = 1;
  FIX_BLIND = 2;
  FIX_CURSE = 3;
var
  members: array[1..MAX_PARTY] of Types.PCharRecord;
  { Free level-1 (Cure Light Wounds) and level-3 slots, and the casts given to each member. }
  l1Free: array[1..MAX_PARTY] of Byte;
  l3Free: array[1..MAX_PARTY] of Byte;
  l1Casts: array[1..MAX_PARTY] of Byte;
  l3Casts: array[1..MAX_PARTY] of Byte;
  cures: array[1..MAX_PARTY, FIX_DISEASE..FIX_CURSE] of Boolean;
  p: Types.PCharRecord;
  n: Byte;
  i: Byte;
  kind: Byte;
  anyCure: Boolean;
  { set when a treatable member has a condition, cured or not }
  anyCondition: Boolean;
  need: Word;
  wanted: Word;
  healCasts: Word;
  { counts the Cure Light Wounds rolls; a Word, as healCasts can pass 255 }
  cast: Word;
  healPool: Word;
  total: Word;
  hp: Word;
  done: Boolean;
  { the members with cleric levels, and those of them conscious enough to cast }
  clerics: Byte;
  ableClerics: Byte;

  { Fix treats the statuses RestoreHitPoints accepts. }
  function Treatable(creature: Types.PCharRecord): Boolean;
  begin
    Treatable := creature^.status in [C_Status.OKAY, C_Status.ANIMATED, C_Status.UNCONSCIOUS, C_Status.DYING];
  end;

  function HasCondition(creature: Types.PCharRecord; cond: Byte): Boolean;
  var
    effect: Types.PEffectRec;
  begin
    case cond of
      FIX_DISEASE: HasCondition := CharHlp.HasEffect(creature, C_Effect.DISEASED, effect) or
                                   CharHlp.HasEffect(creature, C_Effect.DISEASE_STR, effect) or
                                   CharHlp.HasEffect(creature, C_Effect.ROT_NO_HEAL, effect);
      FIX_BLIND: HasCondition := CharHlp.HasEffect(creature, C_Effect.BLIND, effect);
    else
      HasCondition := CharHlp.HasEffect(creature, C_Effect.BESTOW_CURSE, effect);
    end;
  end;

  function CureSpell(cond: Byte): Byte;
  begin
    case cond of
      FIX_DISEASE: CureSpell := C_Spell.CURE_DISEASE;
      FIX_BLIND: CureSpell := C_Spell.CURE_BLINDNESS;
    else
      CureSpell := C_Spell.REMOVE_CURSE;
    end;
  end;

  { Minutes member j needs to memorize its casts again. }
  function CasterTime(j: Byte): Word;
  var
    t: Word;
  begin
    t := 0;
    if l3Casts[j] > 0 then
      t := 360
    else if l1Casts[j] > 0 then
      t := 240;
    CasterTime := t + 15 * l1Casts[j] + 45 * l3Casts[j];
  end;

  { Give one cast to the least busy member with a free slot for it: spell 0 is Cure Light Wounds, any other spell a
    level-3 cure the member must know. False when nobody can cast it. }
  function Assign(spell: Byte): Boolean;
  var
    j: Byte;
    best: Byte;
    free: Boolean;
  begin
    best := 0;
    for j := 1 to n do begin
      if spell = 0 then
        free := l1Free[j] > 0
      else
        free := (l3Free[j] > 0) and (members[j]^.spellsKnown[spell] <> 0);
      if free then
        if (best = 0) or (CasterTime(j) < CasterTime(best)) then best := j;
    end;
    if best <> 0 then
      if spell = 0 then begin
        Dec(l1Free[best]);
        Inc(l1Casts[best]);
      end else begin
        Dec(l3Free[best]);
        Inc(l3Casts[best]);
      end;
    Assign := best <> 0;
  end;

begin
  interrupted := False;
  n := 0;
  need := 0;
  clerics := 0;
  ableClerics := 0;
  p := GDVars.creatureList;
  while (p <> nil) and (n < MAX_PARTY) do begin
    Inc(n);
    members[n] := p;
    l1Free[n] := 0;
    l3Free[n] := 0;
    l1Casts[n] := 0;
    l3Casts[n] := 0;
    if p^.classLevels[C_Level.CLERIC] > 0 then begin
      Inc(clerics);
      if p^.status = C_Status.OKAY then Inc(ableClerics);
    end;
    if p^.status = C_Status.OKAY then begin
      if p^.spellsKnown[C_Spell.CURE_LIGHT_WOUNDS] <> 0 then l1Free[n] := p^.clericSpells[1];
      l3Free[n] := p^.clericSpells[3];
    end;
    if Treatable(p) and (p^.hpCur < p^.hpMax) then Inc(need, p^.hpMax - p^.hpCur);
    p := p^.nextCharAddr;
  end;
  if clerics = 0 then begin
    CharDisp.PrintMessageWait('No clerics available to heal.');
    Exit;
  end;
  if ableClerics = 0 then begin
    CharDisp.PrintMessageWait('No cleric is in a condition to heal.');
    Exit;
  end;
  { Plan the cures, then as many Cure Light Wounds as the wounds need at 4.5 hp each. }
  anyCure := False;
  anyCondition := False;
  for kind := FIX_DISEASE to FIX_CURSE do
    for i := 1 to n do begin
      cures[i, kind] := False;
      if Treatable(members[i]) then
        if HasCondition(members[i], kind) then begin
          anyCondition := True;
          if Assign(CureSpell(kind)) then begin
            cures[i, kind] := True;
            anyCure := True;
          end;
        end;
    end;
  wanted := (2 * need + 8) div 9;
  healCasts := 0;
  while healCasts < wanted do
    if Assign(0) then
      Inc(healCasts)
    else
      wanted := healCasts;
  if (healCasts = 0) and not anyCure then begin
    { the dead and the like are not Fix's to treat, so they leave nothing to do }
    if (need = 0) and not anyCondition then
      CharDisp.PrintMessageWait('Further healing would do no good.')
    else
      CharDisp.PrintMessageWait('Further healing isn''t possible.');
    Exit;
  end;
  total := 0;
  for i := 1 to n do
    if total < CasterTime(i) then total := CasterTime(i);
  FillChar(GDVars.dsRestingTimeGbvm, SizeOf(GDVars.dsRestingTimeGbvm), 0);
  GDVars.dsRestingTimeGbvm[C_Time.DAYS] := total div 1440;
  GDVars.dsRestingTimeGbvm[C_Time.HOURS] := (total mod 1440) div 60;
  GDVars.dsRestingTimeGbvm[C_Time.TURNS] := (total mod 60) div 10;
  GDVars.dsRestingTimeGbvm[C_Time.MINUTES] := total mod 10;
  interrupted := GameTime.CampRest(False);
  done := (GDVars.dsRestingTimeGbvm[C_Time.DAYS] = 0) and (GDVars.dsRestingTimeGbvm[C_Time.HOURS] = 0) and
          (GDVars.dsRestingTimeGbvm[C_Time.TURNS] = 0) and (GDVars.dsRestingTimeGbvm[C_Time.MINUTES] = 0);
  FillChar(GDVars.dsRestingTimeGbvm, SizeOf(GDVars.dsRestingTimeGbvm), 0);
  if done and not interrupted then begin
    for i := 1 to n do
      for kind := FIX_DISEASE to FIX_CURSE do
        if cures[i, kind] then begin
          GDVars.dsTargetCreaturePtr[1] := members[i];
          case kind of
            FIX_DISEASE: Magic.CureDiseaseHandler;
            FIX_BLIND: Magic.CureBlindnessHandler;
            FIX_CURSE: Magic.RemoveCurseSpell;
          end;
        end;
    healPool := 0;
    for cast := 1 to healCasts do Inc(healPool, FxEngine.RollDice(1, 8));
    for i := 1 to n do begin
      p := members[i];
      if Treatable(p) and (p^.hpCur < p^.hpMax) and (healPool > 0) then begin
        hp := p^.hpMax - p^.hpCur;
        if hp > healPool then hp := healPool;
        if FxEngine.RestoreHitPoints(p, hp, False) then Dec(healPool, hp);
      end;
    end;
  end;
  CharDisp.DisplayParty(GDVars.curChar);
  CharDisp.PrintMiscInfo;
end;

procedure CampMainMenu(var interrupted: Boolean);
var
  savedIfc: Byte;
  c: Char;
  { ViewCharMenu's var out }
  viewDone: Boolean;
  ext: Boolean;
begin
  savedIfc := GDVars.ifcState;
  GDVars.ifcState := C_Ifc.CAMPING;
  GDVars.healTicks := 0;
  FillChar(GDVars.dsRestingTimeGbvm, SizeOf(GDVars.dsRestingTimeGbvm), 0);
  CharDisp.DisplayNoncombatInterface;
  Border.ClearBox(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
  TextRend.DisplayString(1, 18, LightGreen, 'The party makes camp...');
  Camp.ResetPartySpellActivities;
  interrupted := False;
  c := ' ';
  while (interrupted = False) and (not (c in [C_Keys.NONE, 'E'])) do begin
    { 'Camp:' plus the menu fills the 40-column bottom line exactly, as in Curse }
    c := MenuCore.MenuHorizontal('Camp: ', GDConsts.campMenu, LightMagenta, LightGreen, White, True, True,
                                 ext);
    if ext then begin
      ViewChar.SelectPrevNextChar(c);
      CharDisp.DisplayParty(GDVars.curChar);
    end else
      case c of
        'S': begin
               SaveLoad.SaveGame;
               { the save menu takes the whole screen }
               CharDisp.DisplayNoncombatInterface;
               if MenuCore.YesNoMenu('Quit TO DOS ', Yellow, LightGreen, White) = 'Y' then
                 GameIo.ExitGame;
             end;
        'V': ViewChar.ViewCharMenu(viewDone);
        'M': Camp.CampMagicMenu(interrupted);
        'R': Camp.CampRestMenu(interrupted);
        'A': Camp.CampAlterMenu;
        'F': Camp.CampFixMenu(interrupted);
      end;
  end;
  Camp.ResetPartySpellActivities;
  GDVars.castTarget := nil;
  GDVars.ifcState := savedIfc;
  CharDisp.PrintMiscInfo;
  CharDisp.ClearMessageWindow;
  TextRend.ClearBottomLine;
end;

end.

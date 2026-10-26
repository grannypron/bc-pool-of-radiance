{ Camp menus for spell preparation, resting, Fix healing, party order and the way to the Settings screen. Also provides
  the noncombat Cast menu. }
{$O+,F+}
{$I COMPILER.INC}
unit Camp;

interface

{ Run the camp menu, preserving the interface state and clearing rest timers and pending spell activities. Return
  interrupted=True when a scripted random interruption ends a rest (GameTime.CampRest). F2 opens the Bestiary (#842)
  and F6 the Companion Tools. }
procedure CampMainMenu(var interrupted: Boolean);

{ Run the noncombat Cast menu. Clear the remembered target on entry and redraw the noncombat interface afterwards if a
  spell was cast or the spell list was not empty. }
procedure NoncombatCastMenu;

implementation

uses Types, Crt, C_MSG, GameDefs, GameVars, CharGen, GameTime, C_EFFECT, C_KEYS, C_STATUS, C_IFC, C_SPELL, C_LEVEL,
  FxEngine, Portrait, Options, Border, C_TIME, CharHlp, GameIo, Magic, MenuCore, SaveLoad, TextRend, ViewChar, StrUtil,
  CharDisp, Party, Dice, UsualSpl, Clock, Explore;

const
  { CanDoSpellActivity's activity selector: ACT_CAST, ACT_MEMORIZE or ACT_SCRIBE. }
  { cast a memorized spell }
  ACT_CAST = 1;
  { memorize spells from spellbook }
  ACT_MEMORIZE = 2;
  { scribe scrolls into spellbook }
  ACT_SCRIBE = 3;

{ The level of the spell in a memorized-spell or scroll slot holding b while it is pending (C_SPELL.PENDING_FLAG set);
  0 for one not pending, or whose id is outside 1..C_SPELL.LAST. }
function PendingLevel(b: Byte): Byte;
begin
  PendingLevel := 0;
  if (b > C_SPELL.ID_MASK) and CharHlp.IsSpell(b and C_SPELL.ID_MASK) then
    PendingLevel := GameDefs.spellTable[b and C_SPELL.ID_MASK].levelSp;
end;

{ Return preparation time in minutes: 15 minutes per pending spell level, plus four hours if any spells are pending, or
  six hours if any is level 3 or higher. Count both memorizing and scribing (readable items only), and store the base
  hours (0, 4 or 6) in spellPrepTime. A slot whose id is outside the spells (PendingLevel) counts for none. }
function CampSpellPrepTime(creature: Types.PCharRecord): Word;
var
  { highest pending level per kind }
  maxMem: Byte;
  maxScr: Byte;
  { the sum of pending spell levels; a Word, as scrolls can hold more than 255 levels (#812) }
  cntMem: Word;
  cntScr: Word;
  p: Types.PItemRec;
  i: Byte;
  lvl: Byte;
  base: Byte;
begin
  maxMem := 0;
  maxScr := 0;
  cntMem := 0;
  cntScr := 0;
  for i := 0 to SizeOf(creature^.memorizedSpells) - 1 do begin
    lvl := Camp.PendingLevel(creature^.memorizedSpells[i]);
    if lvl > maxMem then maxMem := lvl;
    Inc(cntMem, lvl);
  end;
  p := creature^.itemsAddr;
  while p <> nil do begin
    if CharHlp.ItemReadable(p) then
      for i := 1 to SizeOf(p^.spells) do begin
        lvl := Camp.PendingLevel(p^.spells[i]);
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
  CampSpellPrepTime := Word(base) * 60 + (cntMem + cntScr) * 15;
end;

{ Clear every slot marked for memorizing (removing the spell entirely, unlike ResetScribe, which only strips the mark)
  and clear the base prep time. }
procedure ResetMemorize(creature: Types.PCharRecord);
var
  i: Byte;
begin
  for i := 0 to SizeOf(creature^.memorizedSpells) - 1 do
    if creature^.memorizedSpells[i] > C_SPELL.ID_MASK then
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
    if CharHlp.ItemReadable(p) then
      for i := 1 to SizeOf(p^.spells) do
        p^.spells[i] := p^.spells[i] and C_SPELL.ID_MASK;
    p := p^.next;
  end;
end;

{ Run ResetMemorize and ResetScribe on every creature in the list. }
procedure ResetPartySpellActivities;
var
  p: Types.PCharRecord;
begin
  p := GameVars.creatureList;
  while p <> nil do begin
    Camp.ResetMemorize(p);
    Camp.ResetScribe(p);
    p := p^.nextCharAddr;
  end;
end;

{ How many of the current character's memorized and pending spells are of this class and level; an id outside the spell
  table counts for none. }
function SlotsUsed(lvl, typ: ShortInt): Byte;
var
  count: Byte;
  i: Byte;
  id: Byte;
begin
  count := 0;
  for i := 0 to SizeOf(GameVars.curChar^.memorizedSpells) - 1 do begin
    id := GameVars.curChar^.memorizedSpells[i] and C_SPELL.ID_MASK;
    if CharHlp.IsSpell(id) then
      if (GameDefs.spellTable[id].levelSp = lvl) and (GameDefs.spellTable[id].castClassSp = typ) then
        Inc(count);
  end;
  SlotsUsed := count;
end;

{ Put spell id, pending, in the current character's first empty memorized-spell slot; placed is False when every slot is
  taken. }
procedure PutPending(id: Byte; var placed: Boolean);
var
  i: Byte;
begin
  i := 0;
  while (i < SizeOf(GameVars.curChar^.memorizedSpells)) and (GameVars.curChar^.memorizedSpells[i] <> 0) do
    Inc(i);
  placed := i < SizeOf(GameVars.curChar^.memorizedSpells);
  if placed then
    GameVars.curChar^.memorizedSpells[i] := id + C_SPELL.PENDING_FLAG;
end;

{ True when spells of class typ (0 cleric, 1 magic-user) and level lvl have memorize slots (TCharRecord.slots): levels
  1..3 of the two classes. }
function HasSlotKind(lvl, typ: ShortInt): Boolean;
begin
  HasSlotKind := (lvl >= 1) and (lvl <= 3) and (typ >= 0) and (typ <= 1);
end;

{ Return the current character's spell allowance for a class and level minus its memorized and pending spells of that
  class and level, or 0 when as many or more are memorized than allowed (e.g. after level drain), or for a class and
  level with no slots (HasSlotKind). }
function SpellSlotsRemaining(lvl, typ: ShortInt): Byte;
var
  count: Byte;
begin
  SpellSlotsRemaining := 0;
  if Camp.HasSlotKind(lvl, typ) then begin
    count := Camp.SlotsUsed(lvl, typ);
    if count < GameVars.curChar^.slots[typ, lvl] then
      SpellSlotsRemaining := GameVars.curChar^.slots[typ, lvl] - count;
  end;
end;

{ Check whether the current character can cast, memorize or scribe. Anti-magic blocks casting; animated or disabled
  characters cannot do any of these. Held and asleep are effects, so these status checks do not detect them. On failure,
  display the character's name and the reason, which stay in the message window without waiting for a key (#681). }
function CanDoSpellActivity(activity: Byte): Boolean;
var
  msg: Types.TStr40;
begin
  msg := '';
  if (activity = ACT_CAST) and CharHlp.AntiMagicArea then
    msg := 'cannot cast spells in this area'
  else if (GameVars.curChar^.status = C_STATUS.ANIMATED) or (GameVars.curChar^.enabled = 0) then begin
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
    CharDisp.PrintNameString(GameVars.curChar, msg, 10, False);
  end;
end;

{ Select the previous or next character for the selection key c (Party.SelectPrevNextChar) and redraw the party. When
  another character is selected the message window is cleared, so that a message about the last one, which camp's
  messages leave there (#681), does not stay under the new one. }
procedure SelectOtherChar(c: Char);
var
  was: Types.PCharRecord;
begin
  was := GameVars.curChar;
  Party.SelectPrevNextChar(c);
  if GameVars.curChar <> was then
    CharDisp.ClearMessageWindow;
  CharDisp.DisplayParty(GameVars.curChar);
end;

{ Loop the Cast list (memorized spells and readable scroll spells); on a pick, frame the message window and cast a
  memorized spell through Magic.CastSpellNC, or a scroll spell from its own scroll as Use does (Magic.UseItemSpell,
  which asks 'Use it?' of a combat-only one and otherwise names the spell as a memorized cast does), followed by Use's
  CharHlp.RecalcStats. An empty list prints 'has no spells memorized'. }
procedure NoncombatCastMenu;
var
  idx: Integer;
  notEmpty: Boolean;
  redraw: Boolean;
  { CastSpellNC's and UseItemSpell's var out, unread }
  castSel: Boolean;
  spellId: Byte;
  { the scroll the spell is cast from, nil for a memorized one }
  scroll: Types.PItemRec;
  caster: Types.PCharRecord;
begin
  redraw := False;
  idx := -1;
  GameVars.castTarget := nil;
  if Camp.CanDoSpellActivity(ACT_CAST) then begin
    repeat
      spellId := Magic.CastSpellMenu(idx, notEmpty, scroll);
      if spellId <> C_SPELL.NONE then begin
        redraw := True;
        Border.DrawBorder(C_MSG.TEXT_LEFT, C_MSG.MESSAGE_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0);
        Border.ClearBox(C_MSG.TEXT_LEFT, C_MSG.MESSAGE_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
        if scroll = nil then
          Magic.CastSpellNC(spellId, False, True, castSel)
        else begin
          caster := GameVars.curChar;
          Magic.UseItemSpell(scroll, spellId, True, castSel);
          { recount the items and their weight, as Items > Use does: the scroll may be gone }
          CharHlp.RecalcStats(caster);
        end;
        idx := -1;
      end else begin
        if notEmpty then
          redraw := True
        else
          CharDisp.PrintNameString(GameVars.curChar, 'has no spells memorized', 10, True);
      end;
    until spellId = C_SPELL.NONE;
  end;
  if redraw then
    CharDisp.DisplayNoncombatInterface;
end;

{ Show the remaining spell slots in the window under the memorize list (#900): 'Spell Slots Remaining' in light cyan
  on C_SPELL.SLOTS_TOP, then a light green row for each class with an allowance, cleric first, as
  'Magic-User  1:2  2:1  3:0'; a level with no allowance is left blank, a full one shows zero, and an unused class row
  is blank. Return True whenever the character has any spell allowance, even if all slots are occupied. }
function DisplaySpellSlots: Boolean;
var
  s: Types.TStr40;
  typ: ShortInt;
  lvl: ShortInt;
  row: Byte;
  any: Boolean;
  has: Boolean;
begin
  any := False;
  row := C_SPELL.SLOTS_TOP + 1;
  for typ := 0 to 1 do begin
    has := False;
    case typ of
      0: s := 'Cleric';
    else
      s := 'Magic-User';
    end;
    s := StrUtil.PadRight(s, 10);
    for lvl := 1 to 3 do
      if GameVars.curChar^.slots[typ, lvl] = 0 then
        s := s + '     '
      else begin
        s := s + '  ' + StrUtil.NumStr(lvl) + ':' + StrUtil.NumStr(Camp.SpellSlotsRemaining(lvl, typ));
        has := True;
      end;
    if has then begin
      any := True;
      TextRend.PrintSpaces(1, row, Black, 38);
      TextRend.DisplayString(1, row, LightGreen, s);
      Inc(row);
    end;
  end;
  if any then begin
    TextRend.DisplayString(1, C_SPELL.SLOTS_TOP, LightCyan, 'Spell Slots Remaining');
    { a single-class character's second row }
    while row <= C_SPELL.SLOTS_TOP + 2 do begin
      TextRend.PrintSpaces(1, row, Black, 38);
      Inc(row);
    end;
  end;
  DisplaySpellSlots := any;
end;

{ Seed the rest clock (Clock.SetFromMinutes) from the party's longest spell-prep time, run GameTime.CampRest, then clear
  the clock and update the misc-info line. }
procedure CampRestMenu(var interrupted: Boolean);
var
  p: Types.PCharRecord;
  total: Word;
  t: Word;
begin
  total := 0;
  p := GameVars.creatureList;
  while p <> nil do begin
    t := Camp.CampSpellPrepTime(p);
    if total < t then total := t;
    p := p^.nextCharAddr;
  end;
  Clock.SetFromMinutes(GameTime.restTime, total);
  interrupted := GameTime.CampRest(True);
  FillChar(GameTime.restTime, SizeOf(GameTime.restTime), 0);
  CharDisp.PrintMiscInfo;
end;

{ Sort memorized spells by their masked IDs, keeping the pending flag attached to each spell. }
procedure SortMemorizedSpells;
var
  i: Byte;
  j: Byte;
  tmp: Byte;
begin
  for i := 0 to SizeOf(GameVars.curChar^.memorizedSpells) - 2 do
    for j := i to SizeOf(GameVars.curChar^.memorizedSpells) - 1 do
      if (GameVars.curChar^.memorizedSpells[i] and C_SPELL.ID_MASK) > (GameVars.curChar^.memorizedSpells[j] and
                                                                       C_SPELL.ID_MASK) then begin
        tmp := GameVars.curChar^.memorizedSpells[i];
        GameVars.curChar^.memorizedSpells[i] := GameVars.curChar^.memorizedSpells[j];
        GameVars.curChar^.memorizedSpells[j] := tmp;
      end;
end;

{ Remember the current character's memorized and pending spells as its usual spells (UsualSpl.SetUsualSpells). }
procedure RememberUsualSpells;
var
  spells: Types.TSpellSlots;
  i: Byte;
begin
  for i := 0 to SizeOf(spells) - 1 do
    spells[i] := GameVars.curChar^.memorizedSpells[i] and C_SPELL.ID_MASK;
  UsualSpl.SetUsualSpells(GameVars.curChar, spells);
end;

{ Mark as pending each of the current character's usual spells that it lacks, still knows and has a free slot for, in
  turn, so later ones see the slots the earlier ones took. }
procedure QueueUsualSpells;
var
  usual: Types.TSpellSlots;
  have: Types.TSpellSlots;
  i: Byte;
  j: Byte;
  id: Byte;
  found: Boolean;
  placed: Boolean;
begin
  if UsualSpl.GetUsualSpells(GameVars.curChar, usual) then begin
    for i := 0 to SizeOf(have) - 1 do
      have[i] := GameVars.curChar^.memorizedSpells[i] and C_SPELL.ID_MASK;
    for i := 0 to SizeOf(usual) - 1 do begin
      id := usual[i];
      if (id > 0) and (id <= SizeOf(GameVars.curChar^.spellsKnown)) then begin
        { a copy already memorized or pending covers this one }
        found := False;
        for j := 0 to SizeOf(have) - 1 do
          if (not found) and (have[j] = id) then begin
            have[j] := 0;
            found := True;
          end;
        if (not found) and (GameVars.curChar^.spellsKnown[id] <> 0) then
          if Camp.SpellSlotsRemaining(GameDefs.spellTable[id].levelSp, GameDefs.spellTable[id].castClassSp) > 0 then
            Camp.PutPending(id, placed);
      end;
    end;
    Camp.SortMemorizedSpells;
  end;
end;

{ Magic.belowListHook for the memorize list: show the spell slots again under it after the spell page covers them. }
procedure RedrawSpellSlots;
var
  junk: Boolean;
begin
  junk := Camp.DisplaySpellSlots;
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
  placed: Boolean;
begin
  if Camp.CanDoSpellActivity(ACT_MEMORIZE) then begin
    done := False;
    pending := False;
    for i := 0 to SizeOf(GameVars.curChar^.memorizedSpells) - 1 do
      if GameVars.curChar^.memorizedSpells[i] > C_SPELL.ID_MASK then
        pending := True;
    if not pending then
      Camp.QueueUsualSpells;
    idx := -1;
    spellId := Magic.SpellMenu(5, 5, idx, notEmpty);
    redraw := True;
    if notEmpty then begin
      if MenuCore.YesNoMenu('Memorize These Spells? ', Yellow, LightGreen, White) = 'N' then
        Camp.ResetMemorize(GameVars.curChar)
      else begin
        Camp.RememberUsualSpells;
        done := True;
      end;
    end else
      redraw := False;
    idx := -1;
    Magic.belowListHook := Camp.RedrawSpellSlots;
    while done = False do begin
      done := Camp.DisplaySpellSlots = False;
      if done then
        CharDisp.PrintNameString(GameVars.curChar, 'cannot memorize any spells', 10, True)
      else begin
        spellId := Magic.SpellMenu(1, 2, idx, notEmpty);
        redraw := True;
        if spellId = C_SPELL.NONE then
          done := True
        else if Camp.SpellSlotsRemaining(GameDefs.spellTable[spellId].levelSp,
                                         GameDefs.spellTable[spellId].castClassSp) > 0
        then begin
          { Sorting puts empty spell slots first; a full array takes nothing }
          Camp.PutPending(spellId, placed);
          if placed then
            Camp.SortMemorizedSpells;
        end;
      end;
    end;
    @Magic.belowListHook := nil;
    if idx <> -1 then begin
      idx := -1;
      spellId := Magic.SpellMenu(5, 5, idx, notEmpty);
      if notEmpty then
        if MenuCore.YesNoMenu('Memorize these spells? ', Yellow, LightGreen, White) = 'N' then
          Camp.ResetMemorize(GameVars.curChar)
        else
          Camp.RememberUsualSpells;
    end;
    if redraw then
      CharDisp.DisplayNoncombatInterface;
  end;
end;

{ Confirm pending scribing (Yes keeps it and skips selection), then let the player mark scroll spells. A character with
  no magic-user levels is told scribing needs arcane training (#671). Reject known, pending or unavailable spells. The
  first unmarked scroll spell with the spell ID, on a CharHlp.ItemReadable item, is marked. SSI's marking walk did not
  check ItemReadable, so an earlier wand or other item whose charges, effect or special byte (sharing storage with
  spells[1..3]) equalled the ID got the pending flag, 128 more, and nothing was scribed. }
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
  if not Camp.CanDoSpellActivity(ACT_SCRIBE) then
    Exit;
  if CharHlp.GetClassLevel(GameVars.curChar, C_LEVEL.MAGE_BIT) <= 0 then begin
    CharDisp.PrintMessage('Scribing a scroll requires arcane training.')
  end else begin
    done := False;
    idx := -1;
    spellId := Magic.SpellMenu(6, 0, idx, notEmpty);
    redraw := True;
    if notEmpty then begin
      if MenuCore.YesNoMenu('Scribe These Spells? ', Yellow, LightGreen, White) = 'N' then
        Camp.ResetScribe(GameVars.curChar)
      else
        done := True;
    end else
      redraw := False;
    idx := -1;
    while done = False do begin
      spellId := Magic.SpellMenu(3, 3, idx, notEmpty);
      if spellId = C_SPELL.NONE then begin
        done := True;
        if notEmpty = False then
          CharDisp.PrintNameString(GameVars.curChar, 'has no copyable scrolls.', 10, True)
        else
          redraw := True;
      end else if (spellId > SizeOf(GameVars.curChar^.spellsKnown)) or
          not Camp.HasSlotKind(GameDefs.spellTable[spellId].levelSp, GameDefs.spellTable[spellId].castClassSp)
      then begin
        { a scroll byte past the spells a character can know, or a spell with no memorize slot, is not scribed }
        redraw := True;
        CharDisp.PrintBottomLine('You can not scribe that spell.');
      end else begin
        redraw := True;
        if GameVars.curChar^.spellsKnown[spellId] <> 0 then
          CharDisp.PrintBottomLine('You already know that spell.')
        else begin
          p := GameVars.curChar^.itemsAddr;
          found := False;
          while (p <> nil) and (found = False) do begin
            if CharHlp.ItemReadable(p) then
              for i := 1 to SizeOf(p^.spells) do
                if (p^.spells[i] > C_SPELL.ID_MASK) and
                    (p^.spells[i] and C_SPELL.ID_MASK = spellId) then begin
                  CharDisp.PrintBottomLine('You are already scribing that spell.');
                  found := True;
                end;
            p := p^.next;
          end;
          if found = False then begin
            if GameVars.curChar^.slots[GameDefs.spellTable[spellId].castClassSp,
                                       GameDefs.spellTable[spellId].levelSp] > 0
            then begin
              p := GameVars.curChar^.itemsAddr;
              while (p <> nil) and (found = False) do begin
                if CharHlp.ItemReadable(p) then begin
                  i := 1;
                  repeat
                    if p^.spells[i] = spellId then begin
                      p^.spells[i] := p^.spells[i] or C_SPELL.PENDING_FLAG;
                      found := True;
                    end;
                    Inc(i);
                  until (i > SizeOf(p^.spells)) or found;
                end;
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
      spellId := Magic.SpellMenu(6, 0, idx, notEmpty);
      if notEmpty then
        if MenuCore.YesNoMenu('Scribe these spells? ', Yellow, LightGreen, White) = 'N' then
          Camp.ResetScribe(GameVars.curChar);
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
begin
  GetMem(head, SizeOf(Types.TMenuNode));
  cur := head;
  cur^.inUse := 0;
  cur^.name := ' ';
  cur^.next := nil;
  ch := GameVars.creatureList;
  while ch <> nil do begin
    cnt := 0;
    MenuCore.AppendMenuLine(head, cur, ch^.name, True);
    effect := ch^.effectsAddr;
    while effect <> nil do begin
      show := True;
      id := effect^.id;
      case id of
        C_EFFECT.BLESS, C_EFFECT.CURSE, C_EFFECT.DETECT_MAGIC, C_EFFECT.PROTECTION_FROM_EVIL..C_EFFECT.FRIENDS,
            C_EFFECT.READ_MAGIC, C_EFFECT.SHIELD,
        C_EFFECT.FIND_TRAPS..C_EFFECT.INVISIBLE, C_EFFECT.MIRROR_IMAGE, C_EFFECT.ENFEEBLE,
            C_EFFECT.ANIMATE_DEAD..C_EFFECT.DISEASED,
        C_EFFECT.BESTOW_CURSE..C_EFFECT.HASTED, C_EFFECT.PROT_MISSILES, C_EFFECT.SLOWED,
            C_EFFECT.PROT_EVIL_10FT, C_EFFECT.PROT_GOOD_10FT,
        C_EFFECT.PRAYER, C_EFFECT.SNAKE_CHARM..C_EFFECT.SLEEP:
          begin
            { Find the named spell that produces this effect. Only IDs 1..C_SPELL.LAST have spell names; higher IDs
              are item effects. }
            k := 1;
            found := False;
            while (k <= C_SPELL.LAST) and (found = False) do
              if GameDefs.spellTable[k].effect = id then begin
                s := GameDefs.spellNames[k];
                found := True;
              end else
                Inc(k);
            if found = False then
              s := 'Funky--' + StrUtil.NumStr(id);
          end;
        C_EFFECT.TRAIN_START: s := 'Studying Manual of Bodily Health';
        C_EFFECT.TRAIN_MANUAL: s := 'Training with Manual of Bodily Health';
        C_EFFECT.FEATHER_FALL: s := 'Feather Fall';
        C_EFFECT.HELPLESS: s := 'Helpless';
        C_EFFECT.ALLIED_PRAYER: s := 'Prayer';
        C_EFFECT.DISEASE_HIT_POINTS: s := 'Cause Disease';
        C_EFFECT.ROT_NO_HEAL: s := 'Dreaded Mummy Disease';
        C_EFFECT.DRAGON_AURA: s := 'Repulsed';
        C_EFFECT.POISONED: s := 'Poisoned';
        C_EFFECT.TROLL_REGEN: s := 'Regenerating';
        C_EFFECT.RING_FIRE_RES: s := 'Fire Resistance';
        C_EFFECT.DUST_DISAPPEAR: s := 'Invisible';
        C_EFFECT.CAMOUFLAGE: s := 'Camouflaged';
        C_EFFECT.DISPLACED: s := 'Displaced';
      else
        show := False;
      end;
      if show then begin
        Inc(cnt);
        MenuCore.AppendMenuLine(head, cur, ' ' + s, False);
      end;
      effect := effect^.next;
    end;
    if cnt = 0 then
      MenuCore.AppendMenuLine(head, cur, ' <No Spell Effects>', False);
    MenuCore.AppendMenuLine(head, cur, ' ', False);
    ch := ch^.nextCharAddr;
  end;
  menuRedraw := True;
  idx := 0;
  Border.DrawWindow(C_MSG.TEXT_LEFT, C_MSG.TEXT_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM, 0, White, 'Display');
  c := MenuCore.MenuVertical('', '', LightCyan, LightGreen, White, 1, 4, 38, 22, head, True,
                             menuRedraw, idx, cur);
  MenuCore.FreeStringList(head);
  CharDisp.DisplayNoncombatInterface;
end;

{ Run the magic menu ('Cast Memorize Scribe Display Rest Exit'); extended keys switch character. Ends on Exit, Escape or
  an interrupted rest. }
procedure CampMagicMenu(var interrupted: Boolean);
const
  { magic actions }
  magicMenu: String[40] = 'Cast Memorize Scribe Display Rest Exit';
var
  c: Char;
  ext: Boolean;
begin
  c := ' ';
  while (interrupted = False) and (not (c in [C_KEYS.NONE, 'E'])) do begin
    c := MenuCore.MenuHorizontal('', magicMenu, LightMagenta, LightGreen, White, True, True, ext);
    if ext then
      Camp.SelectOtherChar(c)
    else
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
  p := GameVars.creatureList;
  prev := nil;
  if p = GameVars.curChar then
    p := Party.LastCreature
  else
    while p^.nextCharAddr <> GameVars.curChar do begin
      prev := p;
      p := p^.nextCharAddr;
    end;
  savedNext := GameVars.curChar^.nextCharAddr;
  if GameVars.creatureList = GameVars.curChar then begin
    { first -> last (p walked to the tail above) }
    if savedNext <> nil then
      GameVars.creatureList := savedNext;
    p^.nextCharAddr := GameVars.curChar;
    GameVars.curChar^.nextCharAddr := nil;
  end else begin
    { p = predecessor: unlink and reinsert one earlier }
    p^.nextCharAddr := savedNext;
    GameVars.curChar^.nextCharAddr := p;
    if (p = GameVars.creatureList) or (prev = nil) then
      GameVars.creatureList := GameVars.curChar
    else
      prev^.nextCharAddr := GameVars.curChar;
  end;
end;

{ Move the current character one position later in the party list; if already last, it wraps to the front. }
procedure OrderMoveDown;
var
  p: Types.PCharRecord;
  next: Types.PCharRecord;
begin
  p := GameVars.creatureList;
  if p <> GameVars.curChar then
    while p^.nextCharAddr <> GameVars.curChar do
      p := p^.nextCharAddr;
  next := GameVars.curChar^.nextCharAddr;
  if next = nil then begin
    GameVars.curChar^.nextCharAddr := GameVars.creatureList;
    GameVars.creatureList := GameVars.curChar;
    p^.nextCharAddr := next;
  end else begin
    GameVars.curChar^.nextCharAddr := next^.nextCharAddr;
    if GameVars.creatureList = GameVars.curChar then
      GameVars.creatureList := next;
    if p <> GameVars.curChar then
      p^.nextCharAddr := next;
    next^.nextCharAddr := GameVars.curChar;
  end;
end;

{ Reorder the party through Select and Place modes. In Select mode extended keys pick a character; in Place mode Home or
  Up moves it up and End or Down moves it down. P and S switch modes; Enter takes the highlighted option. }
procedure CampOrderMenu;
const
  orderMenus: array[0..1] of String[40] = ('Select Exit', 'Place Exit');
var
  selected: ShortInt;
  ext: Boolean;
  c: Char;
begin
  selected := 0;
  c := ' ';
  while not (c in [C_KEYS.NONE, 'E']) do begin
    c := MenuCore.MenuHorizontal('Party Order: ', orderMenus[selected], LightMagenta, LightGreen,
                                 White, True, True, ext);
    if ext then begin
      if selected = 0 then begin
        Camp.SelectOtherChar(c);
      end else begin
        case c of
          C_KEYS.HOME, C_KEYS.UP: Camp.OrderMoveUp;
          C_KEYS.END_KEY, C_KEYS.DOWN: Camp.OrderMoveDown;
        end;
        CharDisp.DisplayParty(GameVars.curChar);
      end;
    end else
      if c in ['P', 'S'] then begin
        selected := Ord(selected = 0);
        if selected <> 0 then
          CharDisp.PrintNameString(GameVars.curChar, 'has been selected', 10, False)
        else
          CharDisp.ClearMessageWindow;
      end;
  end;
end;

{ Drop the current character from the party after confirmation, with a farewell message that depends on enabled; then
  clear the roster panel and redraw the party. For the last party member, offer to quit to DOS instead. }
procedure CampDropMenu;
begin
  if (GameVars.curChar^.nextCharAddr = nil) and (GameVars.curChar = GameVars.creatureList) then begin
    { last member: quit-to-DOS confirm }
    if MenuCore.YesNoMenu('quit TO DOS: ', Yellow, LightGreen, White) = 'Y' then begin
      SaveLoad.RemoveCreature(False, True);
      GameIo.ExitGame;
    end;
    Exit;
  end;
  CharDisp.PrintNameString(GameVars.curChar, 'will be gone', 10, False);
  if MenuCore.YesNoMenu('Drop from party? ', Yellow, LightGreen, White) = 'Y' then begin
    if GameVars.curChar^.enabled <> 0 then
      CharDisp.PrintNameString(GameVars.curChar, 'bids you farewell.', 10, True)
    else
      CharDisp.PrintNameString(GameVars.curChar, 'is dumped in a ditch.', 10, True);
    SaveLoad.RemoveCreature(False, True);
    Border.ClearBox(17, 1, 38, 11);
    CharDisp.DisplayParty(GameVars.curChar);
  end else
    CharDisp.PrintNameString(GameVars.curChar, 'Breathes A sigh of relief.', 10, True);
end;

{ Run the Alter menu ('Order Drop Char Settings Exit'). Char opens a submenu for the current character's icon or
  portrait; Portrait is offered only where the player portraits can be shown (Portrait.PlayerPortraitsHere). The
  selection keys pick another character there too, as in Alter itself. Settings opens the Settings screen
  (Options.OptionsMenu), which holds the game speed with the other settings. }
procedure CampAlterMenu;
const
  { Char (the character's icon or portrait) took Icon's place: the bottom line has no room for a seventh choice.
    Settings (S, free since Speed left for it) holds the game speed with the other settings. }
  alterMenu: String[40] = 'Order Drop Char Settings Exit';
var
  c: Char;
  c2: Char;
  ext: Boolean;
  s: Types.TStr40;
begin
  c := ' ';
  while not (c in [C_KEYS.NONE, 'E']) do begin
    c := MenuCore.MenuHorizontal('Alter: ', alterMenu, LightMagenta, LightGreen, White, True, True, ext);
    if ext then
      Camp.SelectOtherChar(c)
    else
      case c of
        'O': Camp.CampOrderMenu;
        'D': Camp.CampDropMenu;
        'C': repeat
               if Portrait.PlayerPortraitsHere then
                 s := 'Icon Portrait Exit'
               else
                 s := 'Icon Exit';
               c2 := MenuCore.MenuHorizontal('Character: ', s, LightMagenta, LightGreen, White, True, True, ext);
               if ext then
                 Camp.SelectOtherChar(c2)
               else
                 case c2 of
                   'I': begin
                          CharGen.CustomizeIcon;
                          CharDisp.DisplayNoncombatInterface;
                        end;
                   'P': if Portrait.PlayerPortraitsHere then begin
                          CharGen.CustomizePortrait(True);
                          CharDisp.DisplayNoncombatInterface;
                        end;
                 end;
             until (not ext) and (c2 in [C_KEYS.NONE, 'E']);
        'S': begin
               Options.OptionsMenu;
               CharDisp.DisplayNoncombatInterface;
             end;
      end;
  end;
end;

{ Fix, as in Curse of the Azure Bonds and Pools of Darkness: rest while the party's clerics cure and heal everyone. Each
  cleric level-3 slot of a conscious (status OKAY) caster cures one condition -- disease first (Cure Disease also clears
  mummy rot, which would block the healing), then blindness, then Bestow Curse. Each level-1 slot of such a caster who
  knows Cure Light Wounds heals 1d8, cast only as often as the party's wounds need on average. The casts go to the least
  busy caster, and the rest lasts as long as the busiest one needs by the memorize rule: 4 hours (6 with a level-3
  spell) plus 15 minutes per spell level. Nothing happens unless the whole rest is completed; interrupted reports a rest
  broken off by a scripted random interruption. A party with no cleric, or with none conscious, is told so and does not
  rest, as is a party with nothing Fix can treat or no slot to treat it with; the message stays in the message window,
  without waiting for a key (#681). Fix's healing is spells, so in an anti-magic area (CharHlp.AntiMagicArea) it says
  "Spells cannot be cast in this area." and nobody rests (#877). }
procedure CampFixMenu(var interrupted: Boolean);
const
  { Conditions, cured in this order. }
  FIX_DISEASE = 1;
  FIX_BLIND = 2;
  FIX_CURSE = 3;
var
  { the members planned for; a longer creature list is not looked at past Types.MAX_PARTY }
  members: array[1..Types.MAX_PARTY] of Types.PCharRecord;
  { Free level-1 (Cure Light Wounds) and level-3 slots, and the casts given to each member. }
  l1Free: array[1..Types.MAX_PARTY] of Byte;
  l3Free: array[1..Types.MAX_PARTY] of Byte;
  l1Casts: array[1..Types.MAX_PARTY] of Byte;
  l3Casts: array[1..Types.MAX_PARTY] of Byte;
  cures: array[1..Types.MAX_PARTY, FIX_DISEASE..FIX_CURSE] of Boolean;
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
    Treatable := creature^.status in [C_STATUS.OKAY, C_STATUS.ANIMATED, C_STATUS.UNCONSCIOUS, C_STATUS.DYING];
  end;

  function HasCondition(creature: Types.PCharRecord; cond: Byte): Boolean;
  var
    effect: Types.PEffectRec;
  begin
    case cond of
      FIX_DISEASE: HasCondition := CharHlp.HasEffect(creature, C_EFFECT.DISEASED, effect) or
                                   CharHlp.HasEffect(creature, C_EFFECT.DISEASE_STRENGTH, effect) or
                                   CharHlp.HasEffect(creature, C_EFFECT.ROT_NO_HEAL, effect);
      FIX_BLIND: HasCondition := CharHlp.HasEffect(creature, C_EFFECT.BLIND, effect);
    else
      HasCondition := CharHlp.HasEffect(creature, C_EFFECT.BESTOW_CURSE, effect);
    end;
  end;

  function CureSpell(cond: Byte): Byte;
  begin
    case cond of
      FIX_DISEASE: CureSpell := C_SPELL.CURE_DISEASE;
      FIX_BLIND: CureSpell := C_SPELL.CURE_BLINDNESS;
    else
      CureSpell := C_SPELL.REMOVE_CURSE;
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
  if CharHlp.AntiMagicArea then begin
    CharDisp.PrintMessage('Spells cannot be cast in this area.');
    Exit;
  end;
  n := 0;
  need := 0;
  clerics := 0;
  ableClerics := 0;
  p := GameVars.creatureList;
  while (p <> nil) and (n < Types.MAX_PARTY) do begin
    Inc(n);
    members[n] := p;
    l1Free[n] := 0;
    l3Free[n] := 0;
    l1Casts[n] := 0;
    l3Casts[n] := 0;
    if CharHlp.GetClassLevel(p, C_LEVEL.CLERIC_BIT) > 0 then begin
      Inc(clerics);
      if p^.status = C_STATUS.OKAY then Inc(ableClerics);
    end;
    if p^.status = C_STATUS.OKAY then begin
      if p^.spellsKnown[C_SPELL.CURE_LIGHT_WOUNDS] <> 0 then l1Free[n] := p^.clericSpells[1];
      l3Free[n] := p^.clericSpells[3];
    end;
    if Treatable(p) and (p^.hpCur < p^.hpMax) then Inc(need, p^.hpMax - p^.hpCur);
    p := p^.nextCharAddr;
  end;
  if clerics = 0 then begin
    CharDisp.PrintMessage('No clerics available to heal.');
    Exit;
  end;
  if ableClerics = 0 then begin
    CharDisp.PrintMessage('No cleric is in a condition to heal.');
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
      CharDisp.PrintMessage('Further healing would do no good.')
    else
      CharDisp.PrintMessage('Further healing isn''t possible.');
    Exit;
  end;
  total := 0;
  for i := 1 to n do
    if total < CasterTime(i) then total := CasterTime(i);
  Clock.SetFromMinutes(GameTime.restTime, total);
  interrupted := GameTime.CampRest(False);
  done := (GameTime.restTime[C_TIME.DAYS] = 0) and (GameTime.restTime[C_TIME.HOURS] = 0) and
          (GameTime.restTime[C_TIME.TURNS] = 0) and (GameTime.restTime[C_TIME.MINUTES] = 0);
  FillChar(GameTime.restTime, SizeOf(GameTime.restTime), 0);
  if done and not interrupted then begin
    for i := 1 to n do
      for kind := FIX_DISEASE to FIX_CURSE do
        if cures[i, kind] then begin
          GameVars.spellTargets[1] := members[i];
          case kind of
            FIX_DISEASE: Magic.CureDiseaseHandler;
            FIX_BLIND: Magic.CureBlindnessHandler;
            FIX_CURSE: Magic.RemoveCurseSpell;
          end;
        end;
    healPool := 0;
    for cast := 1 to healCasts do Inc(healPool, Dice.RollDice(1, 8));
    for i := 1 to n do begin
      p := members[i];
      if Treatable(p) and (p^.hpCur < p^.hpMax) and (healPool > 0) then begin
        hp := p^.hpMax - p^.hpCur;
        if hp > healPool then hp := healPool;
        if FxEngine.RestoreHitPoints(p, hp, False) then Dec(healPool, hp);
      end;
    end;
  end;
  CharDisp.DisplayParty(GameVars.curChar);
  CharDisp.PrintMiscInfo;
end;

procedure CampMainMenu(var interrupted: Boolean);
const
  { camp actions }
  campMenu: String[40] = 'Save View Magic Rest Alter Fix Exit';
var
  savedIfc: Byte;
  c: Char;
  { ViewCharMenu's var out }
  viewDone: Boolean;
  ext: Boolean;
  saved: Boolean;
begin
  savedIfc := GameVars.ifcState;
  GameVars.ifcState := C_IFC.CAMPING;
  GameTime.healTicks := 0;
  FillChar(GameTime.restTime, SizeOf(GameTime.restTime), 0);
  CharDisp.DisplayNoncombatInterface;
  Border.ClearBox(C_MSG.TEXT_LEFT, C_MSG.MESSAGE_TOP, C_MSG.TEXT_RIGHT, C_MSG.TEXT_BOTTOM);
  TextRend.DisplayString(1, 18, LightGreen, 'The party makes camp...');
  Camp.ResetPartySpellActivities;
  interrupted := False;
  c := ' ';
  while (interrupted = False) and (not (c in [C_KEYS.NONE, 'E'])) do begin
    { 'Camp:' plus the menu fills the 40-column bottom line exactly, as in Curse, so the prompt has no space after it
      (#674) }
    MenuCore.helpToCaller := True;
    c := MenuCore.MenuHorizontal('Camp:', campMenu, LightMagenta, LightGreen, White, True, True, ext);
    if ext then begin
      { F1's Command Keys window leaves out F5 and F8, which camp does not take (#855) }
      if not Explore.SideScreen(c, False, False) then
        Camp.SelectOtherChar(c);
    end else
      case c of
        'S': begin
               { the save menu's Quit asks to exit to DOS, in place of SSI's question after a save (#872) }
               saved := SaveLoad.SaveGame;
               { the save menu takes the whole screen }
               CharDisp.DisplayNoncombatInterface;
             end;
        'V': ViewChar.ViewCharMenu(viewDone);
        'M': Camp.CampMagicMenu(interrupted);
        'R': Camp.CampRestMenu(interrupted);
        'A': Camp.CampAlterMenu;
        'F': Camp.CampFixMenu(interrupted);
      end;
  end;
  Camp.ResetPartySpellActivities;
  GameVars.castTarget := nil;
  GameVars.ifcState := savedIfc;
  CharDisp.PrintMiscInfo;
  CharDisp.ClearMessageWindow;
  TextRend.ClearBottomLine;
end;

end.

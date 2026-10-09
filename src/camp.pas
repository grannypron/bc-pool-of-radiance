{ Camp menus for spell preparation, resting, party order and game settings. Also provides the noncombat Cast menu. }

{$O+,F+}
unit Camp;

interface

uses Types, Crt, C_Msg, GDConsts, GDVars, CharGen, GameTime, C_Effect, C_Keys, C_Status, C_Ifc, C_Spell;

{ Run the camp menu, preserving the interface state and clearing rest timers and pending spell activities. Return
  interrupted=True when a scripted random interruption ends a rest (GameTime.CampRest). }
procedure CampMainMenu(var interrupted: Boolean);

{ Run the noncombat Cast menu. Clear the remembered target on entry and redraw the noncombat interface afterwards if a
  spell was cast or the spell list was not empty. }
procedure NoncombatCastMenu;

implementation

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
  class and level. The Byte result wraps when more are memorized than allowed (e.g. after level drain). }
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
    CharHlp.PrintNameString(GDVars.curChar, msg, 10, True);
  end;
end;

{ Loop the memorized-spell menu; on a pick, frame the message window and cast through Magic.CastSpellNC. An empty list
  prints 'has no spells memorized'. }
procedure NoncombatCastMenu;
var
  idx: Integer;
  notEmpty: Boolean;
  redraw: Boolean;
  { CastSpellNC's var out, unread }
  castSel: Boolean;
  spellId: Byte;
begin
  redraw := False;
  idx := -1;
  GDVars.castTarget := nil;
  if Camp.CanDoSpellActivity(ACT_CAST) then begin
    repeat
      spellId := ViewChar.SpellMenu(0, 1, idx, notEmpty);
      if spellId <> C_Spell.NONE then begin
        redraw := True;
        Border.DrawBorder(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, 0);
        Border.ClearBox(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
        Magic.CastSpellNC(spellId, False, True, castSel);
        idx := -1;
      end else begin
        if notEmpty then
          redraw := True
        else
          CharHlp.PrintNameString(GDVars.curChar, 'has no spells memorized', 10, True);
      end;
    until spellId = C_Spell.NONE;
  end;
  if redraw then
    CharHlp.DisplayNoncombatInterface;
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
      slotStr[lvl, typ] := CharHlp.ByteToString(Camp.SpellSlotsRemaining(lvl, typ));
      if GDVars.curChar^.slots[typ, lvl] = 0 then
        slotStr[lvl, typ] := ' '
      else begin
        canDo[typ] := 1;
        any := True;
      end;
    end;
  end;
  if any then begin
    CharHlp.PrintNameString(GDVars.curChar, 'can memorize:', 10, False);
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
  pad: Word;
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
  interrupted := GameTime.CampRest;
  FillChar(GDVars.dsRestingTimeGbvm, SizeOf(GDVars.dsRestingTimeGbvm), 0);
  CharHlp.PrintMiscInfo;
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

{ Show the pending list first (Yes keeps it and skips selection, No clears it), then loop the spellbook menu, marking
  picks as pending while slots remain. Confirm again at the end once the spellbook menu has run (idx <> -1). }
procedure CampMemorizeMenu;
var
  done: Boolean;
  notEmpty: Boolean;
  redraw: Boolean;
  spellId: Byte;
  i: Byte;
  idx: Integer;
begin
  if Camp.CanDoSpellActivity(ACT_MEMORIZE) then begin
    done := False;
    idx := -1;
    spellId := ViewChar.SpellMenu(5, 0, idx, notEmpty);
    redraw := True;
    if notEmpty then begin
      if MenuCore.YesNoMenu('Memorize These Spells? ', Yellow, LightGreen, White) = 'N' then
        Camp.ResetMemorize(GDVars.curChar)
      else
        done := True;
    end else
      redraw := False;
    idx := -1;
    while done = False do begin
      done := Camp.DisplaySpellSlots = False;
      if done then
        CharHlp.PrintNameString(GDVars.curChar, 'cannot memorize any spells', 10, True)
      else begin
        spellId := ViewChar.SpellMenu(1, 2, idx, notEmpty);
        redraw := True;
        if spellId = C_Spell.NONE then
          done := True
        else if Camp.SpellSlotsRemaining(GDConsts.spellTable[spellId].levelSp,
                                         GDConsts.spellTable[spellId].castClassSp) > 0
        then begin
          { Sorting puts empty spell slots first. Note: the remaining-slot count is a Byte and can underflow after level
            drain; if the array is full, this unbounded search can run past it. }
          i := 0;
          while GDVars.curChar^.memorizedSpells[i] <> 0 do
            Inc(i);
          GDVars.curChar^.memorizedSpells[i] := spellId + C_Spell.PENDING_FLAG;
          Camp.SortMemorizedSpells;
        end;
      end;
    end;
    if idx <> -1 then begin
      idx := -1;
      spellId := ViewChar.SpellMenu(5, 0, idx, notEmpty);
      if notEmpty then
        if MenuCore.YesNoMenu('Memorize these spells? ', Yellow, LightGreen, White) = 'N' then
          Camp.ResetMemorize(GDVars.curChar);
    end;
    if redraw then
      CharHlp.DisplayNoncombatInterface;
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
  pad: Byte;
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
          CharHlp.PrintNameString(GDVars.curChar, 'has no copyable scrolls', 10, True)
        else
          redraw := True;
      end else begin
        redraw := True;
        if GDVars.curChar^.spellsKnown[spellId] <> 0 then
          CharHlp.PrintBottomLine('You already know that spell')
        else begin
          p := GDVars.curChar^.itemsAddr;
          found := False;
          while (p <> nil) and (found = False) do begin
            if Magic.ItemReadable(p) then
              for i := 1 to SizeOf(p^.spells) do
                if (p^.spells[i] > C_Spell.ID_MASK) and
                    (p^.spells[i] and C_Spell.ID_MASK = spellId) then begin
                  CharHlp.PrintBottomLine('You are already scibing that spell');
                  found := True;
                end;
            p := p^.next;
          end;
          if found = False then begin
            { Note: spell class and level are used as slot indices without validation. High-level or item-only spell IDs
              can read beyond the slot table into xpAward or iconHead. Unlike the spell-list scan, this path accepts IDs
              directly from scroll items. }
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
              CharHlp.PrintBottomLine('You can not scribe that spell.');
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
      CharHlp.DisplayNoncombatInterface;
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
  pad: Byte;
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
              s := 'Funky--' + CharHlp.ByteToString(id);
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
  CharHlp.DisplayNoncombatInterface;
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
      CharHlp.DisplayParty(GDVars.curChar);
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
  moves it up and End moves it down. Enter, P and S switch modes. }
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
        CharHlp.DisplayParty(GDVars.curChar);
      end else begin
        case c of
          C_Keys.HOME: Camp.OrderMoveUp;
          C_Keys.END_KEY: Camp.OrderMoveDown;
        end;
        CharHlp.DisplayParty(GDVars.curChar);
      end;
    end else
      if c in [C_Keys.ENTER, 'P', 'S'] then begin
        selected := Ord(selected = 0);
        if selected <> 0 then
          CharHlp.PrintNameString(GDVars.curChar, 'has been selected', 10, False)
        else
          CharHlp.ClearMessageWindow;
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
  CharHlp.PrintNameString(GDVars.curChar, 'will be gone', 10, False);
  if MenuCore.YesNoMenu('Drop from party? ', Yellow, LightGreen, White) = 'Y' then begin
    if GDVars.curChar^.enabled <> 0 then
      CharHlp.PrintNameString(GDVars.curChar, 'bids you farewell', 10, True)
    else
      CharHlp.PrintNameString(GDVars.curChar, 'is dumped in a ditch', 10, True);
    CharGen.RemoveCreature(False, True);
    Border.ClearBox(17, 1, 38, 11);
    CharHlp.DisplayParty(GDVars.curChar);
  end else
    CharHlp.PrintNameString(GDVars.curChar, 'Breathes A sigh of relief', 10, True);
end;

{ Adjust game speed. Ordinary keys and arrows limit changes to 0..9; loaded values are not clamped. Up slows the game
  and Down speeds it up. }
procedure CampSpeedMenu;
var
  c: Char;
  ext: Boolean;
  menuStr: Types.TStr40;
begin
  repeat
    TextRend.DisplayString(1, 18, LightGreen,
                           'Game Speed = ' + CharHlp.ByteToString(GDVars.gameDelay) + ' (0=fastest 9=slowest)');
    menuStr := '';
    if GDVars.gameDelay > 0 then
      menuStr := menuStr + ' Faster';
    if GDVars.gameDelay < 9 then
      menuStr := menuStr + ' Slower';
    menuStr := menuStr + ' Exit';
    c := MenuCore.MenuHorizontal('Game Speed:', menuStr, LightMagenta, LightGreen, White, True,
                                 True, ext);
    if ext then begin
      case c of
        C_Keys.DOWN: if GDVars.gameDelay > 0 then Dec(GDVars.gameDelay);
        C_Keys.UP: if GDVars.gameDelay < 9 then Inc(GDVars.gameDelay);
      end;
    end else
      case c of
        'F': Dec(GDVars.gameDelay);
        'S': Inc(GDVars.gameDelay);
      end;
  until c in [C_Keys.NONE, 'E'];
  CharHlp.ClearMessageWindow;
end;

{ Run the Alter menu ('Order Drop Speed Icon Pics Exit'). Pics opens a submenu that toggles the monster-graphics and
  portraits flags. }
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
      CharHlp.DisplayParty(GDVars.curChar);
    end else
      case c of
        'O': Camp.CampOrderMenu;
        'D': Camp.CampDropMenu;
        'S': Camp.CampSpeedMenu;
        'I': begin
               CharGen.CustomizeIcon;
               CharHlp.DisplayNoncombatInterface;
             end;
        'P': repeat
               if GDVars.monsterPics <> 0 then
                 s := 'Monsters on  '
               else
                 s := 'Monsters off  ';
               if GDVars.portraitsOn <> 0 then
                 s := s + 'Portraits on  '
               else
                 s := s + 'Portraits off  ';
               s := s + 'Exit';
               c2 := MenuCore.MenuHorizontal('', s, LightMagenta, LightGreen, White, False, True,
                                             ext);
               case c2 of
                 'M': GDVars.monsterPics := Ord(GDVars.monsterPics = 0);
                 'P': GDVars.portraitsOn := Ord(GDVars.portraitsOn = 0);
               end;
             until c2 in [C_Keys.NONE, 'E'];
      end;
  end;
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
  CharHlp.DisplayNoncombatInterface;
  Border.ClearBox(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
  TextRend.DisplayString(1, 18, LightGreen, 'The party makes camp...');
  Camp.ResetPartySpellActivities;
  interrupted := False;
  c := ' ';
  while (interrupted = False) and (not (c in [C_Keys.NONE, 'E'])) do begin
    c := MenuCore.MenuHorizontal('Camp: ', GDConsts.campMenu, LightMagenta, LightGreen, White, True, True,
                                 ext);
    if ext then begin
      ViewChar.SelectPrevNextChar(c);
      CharHlp.DisplayParty(GDVars.curChar);
    end else
      case c of
        'S': begin
               SaveLoad.SaveGame;
               if MenuCore.YesNoMenu('Quit TO DOS ', Yellow, LightGreen, White) = 'Y' then
                 GameIo.ExitGame;
             end;
        'V': ViewChar.ViewCharMenu(viewDone);
        'M': Camp.CampMagicMenu(interrupted);
        'R': Camp.CampRestMenu(interrupted);
        'A': Camp.CampAlterMenu;
      end;
  end;
  Camp.ResetPartySpellActivities;
  GDVars.castTarget := nil;
  GDVars.ifcState := savedIfc;
  CharHlp.PrintMiscInfo;
  CharHlp.ClearMessageWindow;
  MenuCore.ClearBottomLine;
end;

begin
end.

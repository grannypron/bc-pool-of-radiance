{ Spell selection, casting, targeting and spell-specific behavior. }
{$O+,F+}
{$I COMPILER.INC}
unit Magic;

interface

{ Types supplies PCharRecord, PItemRec, PEffectRec, TStr40 and TCellList for the declarations below. }
uses Types;

{ Spell-selection menu: MenuCore.MenuVertical over spellList as built by GenerateSpellList. selType: 1 cast, 2 memorize
  (shorter window, bottom row 15), 3 scribe, 4 learn (on gaining a level; no Exit entry), 5 show only (drawn and left
  for the caller's question, unless it needs paging; MenuCore.listOnly), anything else view only (no title or prompt).
  idx is the menu cursor and persists across calls; idx < 0 clears the window and opens at the top of the list on its
  first spell (cast and learn always redraw). Returns the chosen spell id, or 0 for Exit, with scroll the chosen line's
  scroll in spellScrolls (nil for Exit or a memorized spell); scribe also sets dsCurrentScrollPtr to the chosen
  spell's scroll. Frees spellList before returning. }
function SpellSelection(selType: Byte; var idx: Integer; var scroll: Types.PItemRec): Byte;

{ Build spellList and spellIds for a menu of creature's spells. menuType: 0 memorized, 5 still being memorized (bit 7
  set), 1 spell book, 2 current scroll, 3 spells on every readable item, 6 scroll spells queued for scribing (bit 7
  set), 4 spells learnable on gaining a level (creature has slots of the spell's class and level and does not know it
  yet), 7 the spells creature can cast now (AddAvailableSpells). Returns True if the list has a spell; a list of level
  headings alone is freed and counts as empty. }
function GenerateSpellList(creature: Types.PCharRecord; menuType: Byte): Boolean;

{ The cast-target menu outside combat (GDVars.castTargetMenu). spellTable target mode 1 targets the caster, 2 asks for
  one party member (remembered in GDVars.castTarget; cancelling clears the targets and the cast) and 4 targets every
  creature in GDVars.creatureList; any other mode cancels the cast. b is unused; it matches Types.TCastUI. }
procedure NoncombatCastTargetMenu(spell: Byte; b: Boolean; var cast: Boolean);

{ Cast spell for GDVars.curChar. Outside combat a combat-only spell (target mode 0) is not cast: a memorized spell
  offers 'Lose it?' (Yes removes it) and an item offers 'Use it?' (Yes sets sel). Otherwise, when ai is set and no item
  is in use, announce the cast, then call GDVars.castTargetMenu with b until it picks targets or the cast ends. On a
  pick, a memorized spell first rolls the caster's chance of spell failure (ClassCal.SpellFailureChance: a cleric's low
  Wisdom, for a clerical spell, #60); a failure spends the spell and shows "<name> fails to cast <spell>." and nothing
  else happens. Otherwise, in combat turn to face the aim, play the cast sound and animate the projectile; then remove
  the caster's invisibility, consume the memorized spell unless GDVars.usingItem, and run GDVars.spellFns[spell] with
  dsCurrentSpellBeing set. With no pick, outside combat it just returns; in combat b, or Yes to 'Abort Spell?', aborts
  and consumes the spell, and otherwise targeting repeats. b means automatic targeting (AI or quick fight); sel returns
  whether targets were picked. }
procedure CastSpellNC(spell: Byte; b, ai: Boolean; var sel: Boolean);

{ Cast's refusal of a combat-only spell outside combat: show the spell's name and 'is a combat-only spell...' in the
  message window. }
procedure ShowCombatOnlySpell(spell: Byte);

{ Clear the last of the scroll's spell slots holding spell (bit 7 ignored) and decrement its spell-count name component,
  nameIds[2]; remove the item from cr once that drops below 210. Does nothing if no slot matches. }
procedure RemoveSpellFromScroll(cr, it: Pointer; spell: Byte);

{ Announce a cast. In combat, print 'Casts a Spell' for the creature (msg is ignored) and show the spell name on the
  bottom line. Otherwise show the creature name, msg and the spell name in the message window, pause, then clear it. }
procedure PrintCastSpellMsg(creature: Types.PCharRecord; msg: Types.TStr40; spell: Byte);

{ Remove Curse (spellFns[43], also called by Temple): remove Bestow Curse (effect 36) from dsTargetCreaturePtr[1], or
  else clear the curse on its first cursed item. }
procedure RemoveCurseSpell;

{ Spell handlers: each acts on GDVars.curChar, dsTargetCreaturePtr and dsCurrentSpellBeing; GameInit.InitSpellFns maps
  spell IDs to them }
procedure BlessHandler;

procedure CurseHandler;

procedure CureLightWoundsHandler;

procedure CauseLightWoundsHandler;

procedure DetectionHandler;

procedure ProtectionHandler;

procedure ResistColdHandler;

procedure BurningHandsHandler;

procedure CharmPersonHandler;

procedure EnlargeHandler;

procedure ReduceHandler;

procedure FriendsHandler;

procedure MagicMissileHandler;

procedure ShieldHandler;

procedure ShockingGraspHandler;

procedure SleepHandler;

procedure HoldPersonHandler;

procedure ResistFireHandler;

procedure SilenceHandler;

procedure SlowPoisonHandler;

procedure SnakeCharmHandler;

procedure SpiritualHammerHandler;

procedure InvisibilityHandler;

procedure KnockHandler;

procedure MirrorImageHandler;

procedure RayOfEnfeeblementHandler;

procedure StinkingCloudHandler;

procedure StrengthHandler;

procedure AnimateDeadHandler;

procedure CureBlindnessHandler;

procedure CauseBlindnessHandler;

procedure CureDiseaseHandler;

procedure CauseDiseaseHandler;

procedure DispelMagicHandler;

procedure PrayerHandler;

procedure BestowCurseHandler;

procedure BlinkHandler;

procedure FireballHandler;

procedure HasteHandler;

procedure LightningBoltHandler;

{ The cells a Lightning Bolt aimed at (x, y) by GDVars.curChar would cross after the aim cell itself, in order, bounces
  included, judged on the arena as it stands. Nothing is drawn or damaged. }
procedure TraceLightningBolt(x, y: ShortInt; var cells: Types.TCellList);

procedure SlowHandler;

procedure RestorationHandler;

procedure PotionOfSpeedHandler;

procedure KeoghtomsOintmentHandler;

procedure GiantStrengthHandler;

procedure JavelinOfLightningHandler;

procedure WandParalyzationHandler;

procedure PotionOfHealingHandler;

procedure DustDisappearanceHandler;

procedure WandMagicMissilesHandler;

procedure UnusedSpellHandler;

procedure ManualBodilyHealthHandler;

{ Bronze dragon breath, installed as effect 88's handler, so it has FxEngine's effect-handler signature }
procedure DragonBreathHandler(creature: Types.PCharRecord; p: Pointer; removed: Boolean);

{ Generate the spell list for menuType (0 in memory, 1 spell book, 2 scroll, 3 scrolls, 4 choosing a spell on gaining a
  level, 5 to be memorized, 6 to be scribed, 7 available to cast) and run Magic.SpellSelection on it, returning the
  chosen spell, or 0 when the list is empty. idx < 0 also draws the "<name>'s Spells ..." heading ("<name>'s Available
  Spells" for 7); notEmpty receives whether the list has entries. }
function SpellMenu(menuType, selType: Byte; var idx: Integer; var notEmpty: Boolean): Byte;

{ The Cast menu (SpellMenu 7, select 1): the spell chosen, as SpellMenu returns it, with scroll the scroll it is cast
  from (nil for a memorized spell). }
function CastSpellMenu(var idx: Integer; var notEmpty: Boolean; var scroll: Types.PItemRec): Byte;

procedure UseItemSpell(item: Types.PItemRec; spell: Byte; announce: Boolean; var done: Boolean);

procedure UseItem(item: Types.PItemRec; var done: Boolean);

implementation

uses Stats, CharDisp, C_Sound, C_Item, Dice, Crt, C_Npc, C_Terr, C_Save, C_Cond, GDConsts, GDVars, TextRend,
  Border, CharHlp, SoundDrv, MenuCore, Pathing, CbtMap, ClassCal, FxEngine, C_Effect, C_Race, C_Keys, C_Level, C_Status,
  C_Ifc, C_Dir, C_Spell, AbilAdj;

var
  { the menu string list }
  spellList: Types.PItemRec;
  { spell ID per menu line }
  spellIds: array[0..C_Spell.LINE_LAST] of Byte;
  { the scroll each Cast line reads from, nil for a memorized spell }
  spellScrolls: array[0..C_Spell.LINE_LAST] of Types.PItemRec;
  scrollPtrs: array[0..48] of Types.PItemRec;
  scrollCount: Byte;
  { Current item used for spell casting. }
  dsCurrentScrollPtr: Types.PItemRec;

const
  { Lightning Bolt's length, in cells past the aim cell }
  LIGHTNING_BOLT_CELLS = 8;
  { AddSpellToList's markers, in the indent column: none; KNOWN_MARK on a spell already in the creature's spell book; or
    NOT_KNOWN_MARK on a spell the creature's classes could learn but its spell book lacks }
  MARK_NONE = 0;
  MARK_KNOWN = 1;
  MARK_NOT_KNOWN = 2;
  KNOWN_MARK = '-';
  NOT_KNOWN_MARK = '+';
  { a Cast line's scroll marker, in the indent column just before the spell name }
  SCROLL_MARK = '-';
  { the highest spell level in spellTable (Restoration's 7) }
  SPELL_LEVEL_LAST = 7;

function SpellMark(creature: Types.PCharRecord; spell, mark: Byte): Char; forward;

procedure WalkBolt(boltLen, damage: Byte; saveType: ShortInt; bounce, trace: Boolean; var cells: Types.TCellList);
  forward;

function SpellSelection(selType: Byte; var idx: Integer; var scroll: Types.PItemRec): Byte;
var
  sel: Types.PItemRec;
  p: Types.PItemRec;
  prompt: Types.TStr40;
  title: Types.TStr40;
  count: Byte;
  bottomRow: Byte;
  ch: Char;
  addExit: Boolean;
  redraw: Boolean;
begin
  case selType of
    1: title := 'Cast';
    2: title := 'Memorize';
    3: title := 'Scribe';
    4: title := 'Learn';
  else
    title := '';
  end;
  if selType in [1..4] then
    prompt := 'Choose Spell: '
  else
    prompt := '';
  if selType = 2 then
    bottomRow := 15
  else
    bottomRow := 22;
  if selType = 4 then
    addExit := False
  else
    addExit := True;
  redraw := False;
  if idx < 0 then begin
    Border.DrawWindow(1, 3, 38, bottomRow, 0, Black, '');
    redraw := True;
    { open at the top of the list on its first spell, the line under the first level heading (MenuVertical, given the
      heading, would wrap up to the page's last line) }
    GDVars.vertTop := 0;
    idx := 0;
    p := spellList;
    while (p <> nil) and (p^.inUse <> 0) do begin
      p := p^.next;
      Inc(idx);
    end;
    if p = nil then
      idx := 0;
  end;
  if (selType = 4) or (selType = 1) then
    redraw := True;
  sel := nil;
  repeat
    MenuCore.listOnly := selType = 5;
    ch := MenuCore.MenuVertical(prompt, title, LightMagenta, LightGreen, White, 1, 5, 38,
                                bottomRow, spellList, addExit, redraw, idx, sel);
  until ch in [C_Keys.NONE, C_Keys.ENTER, 'C', 'E', 'L', 'M', 'S'];
  p := spellList;
  count := 0;
  while p <> sel do begin
    if p^.inUse = 0 then
      Inc(count);
    p := p^.next;
  end;
  scroll := nil;
  if (ch in [C_Keys.NONE, 'E']) or (count > C_Spell.LINE_LAST) then
    SpellSelection := C_Spell.NONE
  else begin
    SpellSelection := spellIds[count];
    scroll := spellScrolls[count];
  end;
  if selType = 3 then
    { 48 = High(scrollPtrs) }
    if count <= 48 then
      dsCurrentScrollPtr := scrollPtrs[count]
    else
      dsCurrentScrollPtr := nil;
  MenuCore.FreeStringList(spellList);
end;

{ Append spell to spellList, first adding a level heading entry (inUse = 1) when its spell level differs from the
  previous spell's. Bit 7 set (pending memorization or scribing) prefixes ' *'; otherwise the second column holds
  SpellMark's character for mark (MARK_NONE, MARK_KNOWN or MARK_NOT_KNOWN). Stores spell and $7F in spellIds at the
  entry's selectable index. }
procedure AddSpellToList(creature: Types.PCharRecord; spell, mark: Byte);
var
  p: Types.PItemRec;
  count: ShortInt;
  lastLevel: ShortInt;
begin
  p := spellList;
  if spellList = nil then begin
    { Allocate only a TMenuNode, the TItemRec prefix a MenuCore.MenuVertical entry uses (name, inUse and next); the rest
      of the record is never touched }
    GetMem(p, SizeOf(Types.TMenuNode));
    spellList := p;
    lastLevel := 0;
    count := 0;
  end else begin
    count := 1;
    while p^.next <> nil do begin
      if p^.inUse = 0 then
        Inc(count);
      p := p^.next;
    end;
    { a full list takes no more lines }
    if count > C_Spell.LINE_LAST then
      Exit;
    lastLevel := GDConsts.spellTable[spellIds[count - 1]].levelSp;
    GetMem(p^.next, SizeOf(Types.TMenuNode));
    p := p^.next;
  end;
  p^.next := nil;
  if GDConsts.spellTable[spell and C_Spell.ID_MASK].levelSp <> lastLevel then begin
    p^.name := GDConsts.spellLevelNames[GDConsts.spellTable[spell and C_Spell.ID_MASK].levelSp];
    p^.inUse := 1;
    GetMem(p^.next, SizeOf(Types.TMenuNode));
    p := p^.next;
    p^.next := nil;
  end;
  if spell > C_Spell.ID_MASK then
    p^.name := ' *'
  else
    p^.name := ' ' + Magic.SpellMark(creature, spell, mark);
  p^.name := p^.name + GDConsts.spellNames[spell and C_Spell.ID_MASK];
  p^.inUse := 0;
  spellIds[count] := spell and C_Spell.ID_MASK;
end;

{ The indent-column marker for spell (bit 7 ignored) on a spell list, otherwise a blank: KNOWN_MARK for MARK_KNOWN when
  creature's spell book has it; NOT_KNOWN_MARK for MARK_NOT_KNOWN when the spell book lacks a spell creature's classes
  could learn. A class could learn a spell of its own (castClass 0 needs a cleric level, castClass 1 a magic-user level)
  at spell level 1..3, the levels a character has slots for, whatever the character's current level. An ID outside the
  spell book (1..56) gets a blank. }
function SpellMark(creature: Types.PCharRecord; spell, mark: Byte): Char;
var
  id: Byte;
  learnable: Boolean;
begin
  SpellMark := ' ';
  id := spell and C_Spell.ID_MASK;
  if (id >= 1) and (id <= SizeOf(creature^.spellsKnown)) then
    case mark of
      MARK_KNOWN:
        if creature^.spellsKnown[id] <> 0 then
          SpellMark := KNOWN_MARK;
      MARK_NOT_KNOWN:
        if creature^.spellsKnown[id] = 0 then begin
          learnable := False;
          with GDConsts.spellTable[id] do
            if (levelSp >= 1) and (levelSp <= 3) then
              case castClassSp of
                0: learnable := creature^.classLevels[C_Level.CLERIC] > 0;
                1: learnable := creature^.classLevels[C_Level.MAGE] > 0;
              end;
          if learnable then
            SpellMark := NOT_KNOWN_MARK;
        end;
    end;
end;

{ Add dsCurrentScrollPtr's spells to the list (forScribe: only those queued for scribing, id > $80), each with mark,
  and record the scroll in scrollPtrs for each while scrollPtrs has room. Read Magic (effect 16), or any cleric level
  with a scroll whose base item slot is 12, identifies the scroll first; an unidentified scroll adds nothing. }
procedure AddScrollSpells(creature: Types.PCharRecord; forScribe: Boolean; mark: Byte);
var
  i: Byte;
begin
  if CharHlp.ScrollLegible(creature, dsCurrentScrollPtr) then
    { 3 = High(TItemRec.spells) }
    for i := 1 to 3 do begin
      if (forScribe and (dsCurrentScrollPtr^.spells[i] > C_Spell.PENDING_FLAG)) or
          (not forScribe and (dsCurrentScrollPtr^.spells[i] > 0)) then begin
        Magic.AddSpellToList(creature, dsCurrentScrollPtr^.spells[i], mark);
        { 48 = High(scrollPtrs) }
        if scrollCount <= 48 then begin
          scrollPtrs[scrollCount] := dsCurrentScrollPtr;
          Inc(scrollCount);
        end;
      end;
    end;
end;

{ Walk creature's inventory: each readable item becomes dsCurrentScrollPtr and feeds AddScrollSpells with forScribe and
  mark. dsCurrentScrollPtr itself is the loop variable, so it ends as nil. }
procedure AddAllScrollSpells(creature: Types.PCharRecord; forScribe: Boolean; mark: Byte);
begin
  dsCurrentScrollPtr := creature^.itemsAddr;
  while dsCurrentScrollPtr <> nil do begin
    if CharHlp.ItemReadable(dsCurrentScrollPtr) then
      Magic.AddScrollSpells(creature, forScribe, mark);
    dsCurrentScrollPtr := dsCurrentScrollPtr^.next;
  end;
end;

{ Add the spell in item's slot to the Cast list as line number lines, with item in spellScrolls, and count the line.
  SCROLL_MARK goes in the indent column before the name, in place of the '*' a spell queued for scribing gets. Nothing
  is added once the list is full. }
procedure AddScrollLine(creature: Types.PCharRecord; item: Types.PItemRec; slot: Byte; var lines: Byte);
var
  p: Types.PItemRec;
begin
  if lines <= C_Spell.LINE_LAST then begin
    Magic.AddSpellToList(creature, item^.spells[slot], MARK_NONE);
    spellScrolls[lines] := item;
    Inc(lines);
    p := spellList;
    while p^.next <> nil do
      p := p^.next;
    if Length(p^.name) >= 2 then
      p^.name[2] := SCROLL_MARK;
  end;
end;

{ The Cast list, level by level: creature's memorized spells (not those still being memorized), then a line for each
  spell on each scroll creature can read and use (CastableScroll), in inventory order, marked with SCROLL_MARK. In
  combat the memorized spells need castAllowed, as the Cast command does, and the scroll spells CharHlp.CanUseItems, as
  Use does. }
procedure AddAvailableSpells(creature: Types.PCharRecord);
var
  lvl: Byte;
  i: Byte;
  id: Byte;
  lines: Byte;
  memOk: Boolean;
  scrollOk: Boolean;
  item: Types.PItemRec;
begin
  memOk := (GDVars.ifcState <> C_Ifc.COMBAT) or (creature^.combatAddr^.castAllowed <> 0);
  scrollOk := CharHlp.CanUseItems(creature);
  lines := 0;
  for lvl := 1 to SPELL_LEVEL_LAST do begin
    if memOk then
      for i := 0 to SizeOf(creature^.memorizedSpells) - 1 do begin
        id := creature^.memorizedSpells[i];
        if (id >= 1) and (id <= C_Spell.LAST) then
          if (GDConsts.spellTable[id].levelSp = lvl) and (lines <= C_Spell.LINE_LAST) then begin
            Magic.AddSpellToList(creature, id, MARK_NONE);
            Inc(lines);
          end;
      end;
    if scrollOk then begin
      item := creature^.itemsAddr;
      while item <> nil do begin
        if CharHlp.CastableScroll(creature, item) then
          for i := 1 to SizeOf(item^.spells) do begin
            id := CharHlp.ScrollSpellAt(item, i);
            if id <> C_Spell.NONE then
              if GDConsts.spellTable[id].levelSp = lvl then
                Magic.AddScrollLine(creature, item, i, lines);
          end;
        item := item^.next;
      end;
    end;
  end;
end;

function GenerateSpellList(creature: Types.PCharRecord; menuType: Byte): Boolean;
var
  i: Byte;
  p: Types.PItemRec;
begin
  GenerateSpellList := False;
  spellList := nil;
  for i := 0 to C_Spell.LINE_LAST do begin
    spellIds[i] := 0;
    spellScrolls[i] := nil;
  end;
  { every list starts with no scrolls recorded: High(scrollPtrs), 49 slots }
  for i := 0 to 48 do
    scrollPtrs[i] := nil;
  scrollCount := 0;
  case menuType of
    7: Magic.AddAvailableSpells(creature);
    0: for i := 0 to Types.SPELL_SLOT_LAST do
         if (creature^.memorizedSpells[i] > 0) and
             (creature^.memorizedSpells[i] < C_Spell.PENDING_FLAG) then
           Magic.AddSpellToList(creature, creature^.memorizedSpells[i], MARK_NONE);
    5: for i := 0 to Types.SPELL_SLOT_LAST do
         if creature^.memorizedSpells[i] > C_Spell.ID_MASK then
           Magic.AddSpellToList(creature, creature^.memorizedSpells[i], MARK_NONE);
    { every known spell, Restoration (56) too: SSI stopped at 55 }
    1: for i := 1 to SizeOf(creature^.spellsKnown) do
         if creature^.spellsKnown[i] <> 0 then
           Magic.AddSpellToList(creature, i, MARK_NONE);
    { one scroll's list marks the spells the character could learn but does not know }
    2: Magic.AddScrollSpells(creature, False, MARK_NOT_KNOWN);
    { the scribe list marks the spells the character already knows }
    3: Magic.AddAllScrollSpells(creature, False, MARK_KNOWN);
    6: Magic.AddAllScrollSpells(creature, True, MARK_NONE);
    { only spells inside slots[0..1, 1..3]: Restoration (spell 56, level 7) would read slots[0, 7], xpAward's low byte }
    4: for i := 1 to C_Spell.LAST do
         with GDConsts.spellTable[i] do
           if (castClassSp >= 0) and (castClassSp <= 1) and (levelSp >= 1) and (levelSp <= 3) then
             if (creature^.slots[castClassSp, levelSp] > 0) and (creature^.spellsKnown[i] = 0) then
               Magic.AddSpellToList(creature, i, MARK_NONE);
  end;
  { a list of headings alone has nothing to pick: it counts as empty }
  p := spellList;
  while (p <> nil) and (p^.inUse <> 0) do
    p := p^.next;
  if p <> nil then
    GenerateSpellList := True
  else if spellList <> nil then begin
    MenuCore.FreeStringList(spellList);
    spellList := nil;
  end;
end;

{ Spell duration in minutes: durFixed + durVar * caster level, except for the item spells below with their own rolls }
function CalcSpellDuration(spell: Byte): Word;
var
  d: Word;
begin
  case spell of
    { Cause Disease }
    40: d := Dice.RollDice(1, 6) * 10;
    { Potion of Speed, Wand of Paralyzation }
    57, 61: d := Dice.RollDice(5, 4);
    { Giant Strength }
    59: d := Dice.RollDice(1, 4) * 10 + 40;
    { Dust of Disappearance }
    63: if GDVars.ifcState = C_Ifc.COMBAT then
          d := Dice.RollDice(2, 10) * 10
        else
          d := (Dice.RollDice(1, 10) + 10) * 10;
    { Manual of Bodily Health: 1440 minutes, 24 hours }
    67: d := 1440;
  else
    d := GDConsts.spellTable[spell].durFixed + GDConsts.spellTable[spell].durVar * CharHlp.GetCasterLevel(spell);
  end;
  CalcSpellDuration := d;
end;

{ Apply spell to every non-nil dsTargetCreaturePtr entry. The save is rolled only when the spell's saveEffect is set.
  When dsCurrentSpellBeing's rangeFixed is 255 an attack roll is needed too; a miss counts as saved and zeroes damage
  for this and every later target. damage > 0 is dealt with elem as GDVars.elementMask and saveEffect as the save
  reduction. The spell's effect, if any, is added for CalcSpellDuration minutes at strength eff (0 = caster level) with
  onRemove, saveEffect as save-negates, and msg. With no targets it returns at once, leaving elementMask set. }
procedure ResolveSpell(spell, eff: Byte; onRemove: Boolean; damage, elem: Byte; msg: Types.TStr40);
var
  effLevel: Byte;
  i: Byte;
  tgt: Types.PCharRecord;
  saved: Boolean;
begin
  if damage = 0 then
    GDVars.elementMask := 0
  else
    GDVars.elementMask := elem;
  if GDVars.spellTargetCount = 0 then
    Exit;
  if eff = 0 then
    effLevel := CharHlp.GetCasterLevel(spell)
  else
    effLevel := eff;
  for i := 1 to GDVars.spellTargetCount do begin
    if GDVars.dsTargetCreaturePtr[i] <> nil then begin
      tgt := GDVars.dsTargetCreaturePtr[i];
      if not GDConsts.spellTable[spell].saveEffect then
        saved := False
      else
        saved := FxEngine.RollSavingThrow(tgt, GDConsts.spellTable[spell].saveType, 0);
      if GDConsts.spellTable[GDVars.dsCurrentSpellBeing].rangeFixed = 255 then begin
        CharHlp.RecalcStats(tgt);
        FxEngine.TriggerEffectsWithCondition(C_Cond.DEFENDER_AC, tgt);
        if not FxEngine.AttackRoll(GDVars.curChar, tgt, tgt^.acCur) then begin
          damage := 0;
          saved := True;
        end;
      end;
      if damage > 0 then
        FxEngine.InflictNonWeaponDamage(tgt, damage, Byte(GDConsts.spellTable[spell].saveEffect), saved);
      if GDConsts.spellTable[spell].effect > 0 then
        FxEngine.AddEffectWithMessage(tgt, GDConsts.spellTable[spell].effect, Magic.CalcSpellDuration(spell), effLevel,
                                      onRemove, GDConsts.spellTable[spell].saveEffect, saved, msg);
    end;
  end;
  GDVars.elementMask := 0;
end;

procedure NoncombatCastTargetMenu(spell: Byte; b: Boolean; var cast: Boolean);
begin
  if GDVars.castTarget = nil then
    GDVars.castTarget := GDVars.curChar;
  GDVars.dsTargetCreaturePtr[1] := GDVars.curChar;
  GDVars.spellTargetCount := 1;
  cast := True;
  case GDConsts.spellTable[spell].target of
    1: ;
    2: begin
         CharDisp.DisplayNoncombatInterface;
         CharDisp.SelectChar('Cast Spell on whom', True, GDVars.castTarget);
         if GDVars.castTarget = nil then begin
           GDVars.dsTargetCreaturePtr[1] := nil;
           GDVars.spellTargetCount := 0;
           cast := False;
         end else
           GDVars.dsTargetCreaturePtr[1] := GDVars.castTarget;
       end;
    4: begin
         GDVars.dsTargetCreaturePtr[GDVars.spellTargetCount] := GDVars.creatureList;
         while GDVars.dsTargetCreaturePtr[GDVars.spellTargetCount]^.nextCharAddr <> nil do begin
           GDVars.dsTargetCreaturePtr[GDVars.spellTargetCount + 1] :=
             GDVars.dsTargetCreaturePtr[GDVars.spellTargetCount]^.nextCharAddr;
           Inc(GDVars.spellTargetCount);
         end;
       end;
  else
    cast := False;
  end;
end;

procedure CastSpellNC(spell: Byte; b, ai: Boolean; var sel: Boolean);
var
  ok: Boolean;
  { the caster's chance of spell failure, and whether this cast failed }
  chance: Byte;
  failed: Boolean;
  x: ShortInt;
  y: ShortInt;
  k: Byte;
  p: Types.PCharRecord;
begin
  p := GDVars.curChar;
  ok := True;
  if (GDVars.ifcState <> C_Ifc.COMBAT) and (GDConsts.spellTable[spell].target = 0) then begin
    if GDVars.usingItem = False then begin
      Magic.ShowCombatOnlySpell(spell);
      if MenuCore.YesNoMenu('Lose it? ', LightMagenta, White, LightGreen) = 'Y' then
        CharHlp.RemoveSpell(GDVars.curChar, spell);
    end else begin
      TextRend.DisplayString(1, 19, LightGreen, 'That Item');
      TextRend.DisplayString(1, 20, LightGreen, 'is a combat-only item...');
      if MenuCore.YesNoMenu('Use it? ', LightMagenta, White, LightGreen) = 'Y' then
        sel := True;
    end;
    ai := False;
    ok := False;
  end;
  if ai then
    if GDVars.usingItem = False then
      Magic.PrintCastSpellMsg(p, 'casts', spell);
  while ok do begin
    GDVars.castTargetMenu(spell, b, sel);
    if sel then begin
      ok := False;
      { a cleric's low Wisdom can make a memorized clerical spell fail (#60), rolled only when there is a chance }
      failed := False;
      if GDVars.usingItem = False then begin
        chance := ClassCal.SpellFailureChance(p, spell);
        if chance > 0 then
          failed := Dice.RollDice(1, 100) <= chance;
      end;
      if failed then begin
        CharHlp.RemoveSpell(p, spell);
        CharDisp.PrintNameString(p, 'fails to cast ' + GDConsts.spellNames[spell] + '.', 10, True);
      end else begin
        if GDVars.ifcState = C_Ifc.COMBAT then begin
          CharDisp.BuildIconFacings(18);
          x := CbtMap.CombatCellX(p);
          y := CbtMap.CombatCellY(p);
          k := 0;
          while not Pathing.IsDirToward(x, y, GDVars.gTargetX, GDVars.gTargetY, k) do
            Inc(k);
          CbtMap.SetCreatureFacing(p, k, 1, 0);
          SoundDrv.SoundSetAutoStop(0);
          case spell of
            C_Spell.FIREBALL: SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.FIREBALL]);
            C_Spell.LIGHTNING_BOLT: SoundDrv.SoundCommand(GDConsts.soundIds.combat[C_Sound.LIGHTNING]);
          else
            SoundDrv.SoundCommand(GDConsts.soundIds.commands[C_Sound.CAST]);
          end;
          CharDisp.CombatAnimateMovingIcon(x, y, GDVars.gTargetX, GDVars.gTargetY, 4, 30);
          SoundDrv.SoundSetAutoStop(10);
          if CbtMap.CombatIconVisible(p, 0) then begin
            CbtMap.SetCreatureFacing(p, p^.combatAddr^.direction, 1, 1);
            CbtMap.SetCreatureFacing(p, p^.combatAddr^.direction, 0, 0);
          end;
        end;
        FxEngine.RemoveInvisibility(p);
        if GDVars.usingItem = False then begin
          CharHlp.RemoveSpell(GDVars.curChar, spell);
          Stats.Count(p, Stats.SPELLS_CAST, 1);
        end;
        GDVars.dsCurrentSpellBeing := spell;
        GDVars.spellFns[GDVars.dsCurrentSpellBeing];
        GDVars.dsCurrentSpellBeing := C_Spell.NONE;
        GDVars.gMultiTarget := 0;
      end;
    end else begin
      if GDVars.ifcState <> C_Ifc.COMBAT then
        ok := False
      else if b or (MenuCore.YesNoMenu('Abort Spell? ', Yellow, LightGreen, White) = 'Y') then
      begin
        CharDisp.PrintBottomLine('Spell Aborted');
        if GDVars.usingItem = False then
          CharHlp.RemoveSpell(GDVars.curChar, spell);
        ok := False;
      end;
    end;
  end;
  CharDisp.ClearMessageWindow;
  if GDVars.ifcState = C_Ifc.COMBAT then
    Border.ClearBox(0, 23, 39, 23);
end;

procedure ShowCombatOnlySpell(spell: Byte);
begin
  TextRend.DisplayString(1, 19, LightGreen, GDConsts.spellNames[spell]);
  TextRend.DisplayString(1, 20, LightGreen, 'is a combat-only spell...');
end;

{ Bless and Curse: drop targets not on team hostFlag and, for Bless in combat, targets with an enemy within range 1;
  resolve the rest as a multi-target spell with msg. }
procedure CastOneSide(hostFlag: ShortInt; msg: Types.TStr40);
var
  i: Byte;
begin
  GDVars.gMultiTarget := 1;
  for i := 1 to GDVars.spellTargetCount do begin
    if (GDVars.dsTargetCreaturePtr[i]^.hostile <> hostFlag) or
        ((GDVars.dsCurrentSpellBeing = C_Spell.BLESS) and (GDVars.ifcState = C_Ifc.COMBAT) and
         (CbtMap.CountTargets(GDVars.dsTargetCreaturePtr[i], 1) > 0)) then
      GDVars.dsTargetCreaturePtr[i] := nil;
  end;
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, 0, 0, msg);
end;

{ Bless: apply the spell to the caster's own team (see CastOneSide). }
procedure BlessHandler;
begin
  Magic.CastOneSide(GDVars.curChar^.hostile, 'is Blessed');
end;

{ Curse: apply the spell to the caster's enemies (see CastOneSide). }
procedure CurseHandler;
begin
  Magic.CastOneSide(CharHlp.EnemyTeam(GDVars.curChar), 'is Cursed');
end;

{ Cure Light Wounds: restore 1d8 hit points to the first target. }
procedure CureLightWoundsHandler;
begin
  if GDVars.spellTargetCount = 0 then
    Exit;
  if FxEngine.RestoreHitPoints(GDVars.dsTargetCreaturePtr[1], Dice.RollDice(1, 8), False) then
    CharDisp.PrintHpRestoreMsg(GDVars.dsTargetCreaturePtr[1]);
end;

{ Cause Light Wounds: 1d8 damage, element mask 8. }
procedure CauseLightWoundsHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, Dice.RollDamageDice(1, 8), C_Effect.ELEM_MAGIC, '');
end;

{ Shared handler for the detection-style spells: apply the spell's effect. }
procedure DetectionHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, 0, 0, 'is affected');
end;

{ Shared handler for the protection spells: apply the spell's effect. }
procedure ProtectionHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, 0, 0, 'is protected');
end;

{ Resist Cold: apply the spell's effect. }
procedure ResistColdHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, 0, 0, 'is cold-resistant');
end;

{ Burning Hands: caster-level damage, element mask 9. }
procedure BurningHandsHandler;
begin
  { no dice are rolled: the fixed damage counts as one die for the per-die fire protections (effects 61 and 113),
    which otherwise used the die count of whatever damage roll came before }
  GDVars.gDamageDice := 1;
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, CharHlp.GetCasterLevel(GDVars.dsCurrentSpellBeing),
                     C_Effect.ELEM_FIRE or C_Effect.ELEM_MAGIC, '');
end;

{ Charm Person: only persons (CharHlp.IsPerson) can be charmed (#792). The Charm effect's strength is the caster's
  hostile * 128 + caster level; afterwards the target's first Charm effect (normally the one just added) has its handler
  called with removed = False. }
procedure CharmPersonHandler;
var
  effect: Types.PEffectRec;
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.dsTargetCreaturePtr[1];
  if not CharHlp.IsPerson(tgt) then
    CharDisp.PrintNameString(tgt, 'is unaffected', 10, True)
  else begin
    Magic.ResolveSpell(GDVars.dsCurrentSpellBeing,
                        GDVars.curChar^.hostile * 128 + CharHlp.GetCasterLevel(GDVars.dsCurrentSpellBeing), True, 0,
                        0, 'is charmed');
    if CharHlp.HasEffect(tgt, C_Effect.CHARM, effect) then
      FxEngine.CallEffectHandler(C_Effect.CHARM, GDVars.dsTargetCreaturePtr[1], effect, False);
  end;
end;

{ Enlarge: set the first target's Strength from the caster level and add the Enlarge effect, which keeps the Strength
  encoding AdjustForNewStrength returns. }
procedure EnlargeHandler;
var
  baseStr: Byte;
  excStr: Byte;
  enc: Byte;
  lvl: Byte;
begin
  { Strength 18 with exceptional Strength 0, 1, 51, 76, 91 or 100 for caster levels 1..6; 100 above 6, 0 for level 0 }
  baseStr := 18;
  lvl := CharHlp.GetCasterLevel(GDVars.dsCurrentSpellBeing);
  case lvl of
    1: excStr := 0;
    2: excStr := 1;
    3: excStr := 51;
    4: excStr := 76;
    5: excStr := 91;
    6: excStr := 100;
  else
    if lvl > 6 then
      excStr := 100
    else
      excStr := 0;
  end;
  if FxEngine.AdjustForNewStrength(GDVars.dsTargetCreaturePtr[1], baseStr, excStr, enc) then
    CharDisp.PrintNameString(GDVars.dsTargetCreaturePtr[1], 'is stronger', 10, True);
  { enc: the Strength encoding AdjustForNewStrength returned, kept as the effect's strength }
  FxEngine.AddEffect(GDVars.dsTargetCreaturePtr[1], C_Effect.ENLARGE,
                     Magic.CalcSpellDuration(GDVars.dsCurrentSpellBeing), enc, True);
end;

{ Reduce: if dsTargetCreaturePtr[1] fails a spell save, remove its Enlarge effect (12) }
procedure ReduceHandler;
begin
  if GDVars.spellTargetCount > 0 then
    if not FxEngine.RollSavingThrow(GDVars.dsTargetCreaturePtr[1], C_Save.SPELL, 0) then
      if FxEngine.RemoveEffectWithMessage(GDVars.dsTargetCreaturePtr[1], C_Effect.ENLARGE) then
        CharDisp.PrintNameString(GDVars.dsTargetCreaturePtr[1], 'has been reduced', 10, True);
end;

{ Friends: +2d4 Charisma, capped at 25; the effect's strength is the old Charisma, restored on removal }
procedure FriendsHandler;
var
  oldCha: Byte;
begin
  oldCha := GDVars.dsTargetCreaturePtr[1]^.chaCur;
  GDVars.dsTargetCreaturePtr[1]^.chaCur := AbilAdj.ClampScore(oldCha + Dice.RollDice(2, 4));
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, oldCha, True, 0, 0, 'is friendly');
end;

{ Magic Missile: (caster level div 2)d4 + caster level div 2 damage, element mask 8. }
procedure MagicMissileHandler;
var
  cl: Byte;
begin
  cl := CharHlp.GetCasterLevel(GDVars.dsCurrentSpellBeing);
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, cl div 2 + Dice.RollDamageDice(cl div 2, 4),
                     C_Effect.ELEM_MAGIC, '');
end;

{ Shield: apply the spell's effect. }
procedure ShieldHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, 0, 0, 'is shielded');
end;

{ Shocking Grasp: 1d8 + caster level damage, element mask $C. }
procedure ShockingGraspHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False,
                      Dice.RollDamageDice(1, 8) + CharHlp.GetCasterLevel(GDVars.dsCurrentSpellBeing),
                      C_Effect.ELEM_ELEC or C_Effect.ELEM_MAGIC, '');
end;

{ Sleep: a 4d4 hit-dice pool. Cost per target by levelHighest: 0..1 -> 1, 2 -> 2, 3 -> 4, 4 -> 6, 5 -> 10 for
  C_Race.MONSTER and 20 otherwise, higher -> 20. Animated dead (C_Status.ANIMATED), targets already asleep (effect 53)
  and targets the remaining pool cannot pay for are dropped; the pool is spent greedily in target order. }
procedure SleepHandler;
var
  pool: Byte;
  cost: Byte;
  i: Byte;
  effect: Types.PEffectRec;
begin
  GDVars.gMultiTarget := 1;
  pool := Dice.RollDice(4, 4);
  for i := 1 to GDVars.spellTargetCount do begin
    case GDVars.dsTargetCreaturePtr[i]^.levelHighest of
      0..1: cost := 1;
      2: cost := 2;
      3: cost := 4;
      4: cost := 6;
      5: if GDVars.dsTargetCreaturePtr[i]^.race = C_Race.MONSTER then
           cost := 10
         else
           cost := 20;
    else
      cost := 20;
    end;
    if (GDVars.dsTargetCreaturePtr[i]^.status <> C_Status.ANIMATED) and
        (not CharHlp.HasEffect(GDVars.dsTargetCreaturePtr[i], C_Effect.SLEEP, effect)) and
        (pool >= cost) then
      Dec(pool, cost)
    else
      GDVars.dsTargetCreaturePtr[i] := nil;
  end;
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, 0, 0, 'falls asleep');
end;

{ Hold Person (spells 23 and 49): save modifier -2 (cleric) or -3 (mage) for one target, -1 for two, 0 for three or
  more. Targets are processed in reverse; each one after the first processed (i < spellTargetCount) gets its own
  projectile animation. Targets that are not persons (CharHlp.IsPerson, #792) always save. }
procedure HoldPersonHandler;
var
  tgt: Types.PCharRecord;
  saved: Boolean;
  i: Byte;
  smod: ShortInt;
begin
  case GDVars.spellTargetCount of
    1: if GDVars.dsCurrentSpellBeing = C_Spell.HOLD_PERSON then
         smod := -2
       else
         smod := -3;
    2: smod := -1;
  else
    smod := 0;
  end;
  for i := GDVars.spellTargetCount downto 1 do begin
    if GDVars.dsTargetCreaturePtr[i] <> nil then begin
      tgt := GDVars.dsTargetCreaturePtr[i];
      if i < GDVars.spellTargetCount then begin
        SoundDrv.SoundSetAutoStop(0);
        SoundDrv.SoundCommand(GDConsts.soundIds.commands[C_Sound.CAST]);
        CharDisp.BuildIconFacings(18);
        CharDisp.CombatAnimateMovingIcon(CbtMap.CombatCellX(GDVars.curChar), CbtMap.CombatCellY(GDVars.curChar),
                                        CbtMap.CombatCellX(tgt), CbtMap.CombatCellY(tgt), 4, 30);
        SoundDrv.SoundSetAutoStop(10);
      end;
      saved := FxEngine.RollSavingThrow(tgt, GDConsts.spellTable[GDVars.dsCurrentSpellBeing].saveType, smod);
      if not CharHlp.IsPerson(tgt) then
        saved := True;
      FxEngine.AddEffectWithMessage(tgt, GDConsts.spellTable[GDVars.dsCurrentSpellBeing].effect,
                                    Magic.CalcSpellDuration(GDVars.dsCurrentSpellBeing),
                                    CharHlp.GetCasterLevel(GDVars.dsCurrentSpellBeing), False,
                                    GDConsts.spellTable[GDVars.dsCurrentSpellBeing].saveEffect, saved, 'is held');
    end;
  end;
end;

{ Resist Fire: apply the spell's effect. }
procedure ResistFireHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, 0, 0, 'is fire resistant');
end;

{ Silence: apply the spell's effect. }
procedure SilenceHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, 0, 0, 'is silenced');
end;

{ Stand a downed creature back up with its hit points through FxEngine.ReviveDeadCreature, or, where it cannot stand
  yet (another creature on its cell), a minute later through C_Effect.HEAL_WAKE. }
procedure StandUpOrWake(tgt: Types.PCharRecord);
begin
  if not FxEngine.ReviveDeadCreature(tgt, tgt^.hpCur) then
    FxEngine.AddEffect(tgt, C_Effect.HEAL_WAKE, 1, 0, True);
end;

{ Slow Poison: animated dead are skipped. A poisoned target (effect 55) has hpCur raised to at least 1, gets the spell's
  effect at strength 255 and gains effect 15 for 10 minutes at strength 255. One that is down (dead or out of play, and
  not fled, petrified or gone) gets back up (StandUpOrWake, as under Keoghtom's Ointment); one still standing is left
  as it is. SSI stood up every poisoned target, so a standing one "got back up" again and a stoned, disintegrated or
  fled one was set Okay. }
procedure SlowPoisonHandler;
var
  effect: Types.PEffectRec;
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.dsTargetCreaturePtr[1];
  if tgt^.status = C_Status.ANIMATED then
    GDVars.dsTargetCreaturePtr[1] := nil
  else if CharHlp.HasEffect(tgt, C_Effect.POISONED, effect) then begin
    if tgt^.hpCur = 0 then
      tgt^.hpCur := 1;
    Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 255, True, 0, 0, 'is affected');
    if ((tgt^.status = C_Status.DEAD) or (tgt^.enabled = 0)) and
        not (tgt^.status in [C_Status.TEMPGONE, C_Status.RUNNING, C_Status.STONED, C_Status.GONE]) then
      StandUpOrWake(tgt);
    FxEngine.AddEffect(tgt, C_Effect.SLOW_POISON_HIT, 10, 255, True);
  end;
end;

{ Snake Charm: rebuild the target list from GDVars.creatureList: snakes whose hpCur still fits in a pool equal to the
  caster's hpCur, paid in list order }
procedure SnakeCharmHandler;
var
  pool: Byte;
  p: Types.PCharRecord;
begin
  pool := GDVars.curChar^.hpCur;
  GDVars.spellTargetCount := 0;
  p := GDVars.creatureList;
  while p <> nil do begin
    { charType 14: snake }
    if p^.charType = 14 then
      if pool >= p^.hpCur then begin
        pool := pool - p^.hpCur;
        Inc(GDVars.spellTargetCount);
        GDVars.dsTargetCreaturePtr[GDVars.spellTargetCount] := p;
      end;
    p := p^.nextCharAddr;
  end;
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, 0, 0, 'is charmed');
end;

{ Spiritual Hammer: apply the spell's effect, then run the Spiritual Hammer effect handler for the first target. }
procedure SpiritualHammerHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, True, 0, 0, '');
  FxEngine.CallEffectHandler(C_Effect.SPIRIT_HAMMER, GDVars.dsTargetCreaturePtr[1], nil, False);
end;

{ Invisibility: apply the spell's effect. }
procedure InvisibilityHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, 0, 0, 'is invisible');
end;

{ Knock: apply the spell's effect. }
procedure KnockHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, 0, 0, 'Knock-Knock');
end;

{ Mirror Image: apply the spell's effect with 1d4 images as its strength. }
procedure MirrorImageHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, Dice.RollDice(1, 4), False, 0, 0, 'is duplicated');
end;

{ Ray of Enfeeblement: apply the spell's effect. }
procedure RayOfEnfeeblementHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, 0, 0, 'is weakened');
end;

{ Stinking Cloud: append a node to the stinkHead list and give the caster effect 40 for caster-level minutes at strength
  FxEngine.CloudStrength (caster level, at most 15, + myClouds * 16; SSI let a level above 15 carry into the number),
  where myClouds is the lowest number none of the caster's clouds has (FxEngine.FreeCloudNumber; SSI counted the
  caster's nodes on the walk to the tail and never checked the tail, so a second cloud could share the first one's
  number and its end clear the older cloud). The cloud covers the 2x2 block whose upper-left is the aim cell
  (GDConsts.cloudDir: center, E, SE, S). Each cell records the terrain underneath (a cell already under another cloud
  takes that cloud's saved terrain, a corpse cell the corpse's), and passable cells are stamped C_Terr.STINK_CLOUD;
  every creature found in the four cells then gets FxEngine.ConsiderStinkingCloud. }
procedure StinkingCloudHandler;
var
  p2: Types.PStinkRec;
  node: Types.PStinkRec;
  crIdx: array[1..4] of Byte;
  j: Byte;
  myClouds: Byte;
  terr: Byte;
  cl: Byte;
  k: Byte;
  d: Byte;
begin
  GDVars.gMultiTarget := 1;
  cl := CharHlp.GetCasterLevel(GDVars.dsCurrentSpellBeing);
  myClouds := FxEngine.FreeCloudNumber(GDVars.curChar);
  node := GDVars.stinkHead;
  if GDVars.stinkHead = nil then begin
    GetMem(GDVars.stinkHead, SizeOf(Types.TStinkRec));
    node := GDVars.stinkHead;
  end else begin
    while node^.next <> nil do
      node := node^.next;
    GetMem(node^.next, SizeOf(Types.TStinkRec));
    node := node^.next;
  end;
  FillChar(node^, SizeOf(Types.TStinkRec), 0);
  FxEngine.AddEffect(GDVars.curChar, C_Effect.CAST_STINK, cl, FxEngine.CloudStrength(cl, myClouds), True);
  node^.caster := GDVars.curChar;
  node^.idx := myClouds;
  node^.ulX := GDVars.gTargetX;
  node^.ulY := GDVars.gTargetY;
  for k := 1 to 4 do begin
    d := GDConsts.cloudDir[k];
    CbtMap.GetArenaContents(GDVars.gTargetX + GDConsts.dirDX[d], GDVars.gTargetY + GDConsts.dirDY[d], crIdx[k],
                            terr);
    if (terr > 0) and (GDConsts.terrainInfo[terr].cost < 255) then
      node^.exists[k] := 1
    else
      node^.exists[k] := 0;
    if terr = C_Terr.STINK_CLOUD then begin
      p2 := GDVars.stinkHead;
      while p2 <> nil do begin
        if p2 <> node then
          for j := 1 to 4 do
            if (p2^.exists[j] <> 0) and
                (p2^.ulX + GDConsts.dirDX[GDConsts.cloudDir[j]] = GDVars.gTargetX + GDConsts.dirDX[d]) and
                (p2^.ulY + GDConsts.dirDY[GDConsts.cloudDir[j]] = GDVars.gTargetY + GDConsts.dirDY[d]) then
              if p2^.under[j] <> C_Terr.STINK_CLOUD then
                terr := p2^.under[j];
        p2 := p2^.next;
      end;
    end else if terr = C_Terr.CORPSE then begin
      for j := 1 to GDVars.downedCount do
        if GDVars.downed[j].x = GDVars.gTargetX + GDConsts.dirDX[d] then
          if GDVars.downed[j].y = GDVars.gTargetY + GDConsts.dirDY[d] then
            terr := GDVars.downed[j].terrain;
    end;
    node^.under[k] := terr;
    if node^.exists[k] <> 0 then
      GDVars.arenaPtr^.cells[GDVars.gTargetY + GDConsts.dirDY[d],
                               GDVars.gTargetX + GDConsts.dirDX[d]] := C_Terr.STINK_CLOUD;
  end;
  CharDisp.PrintNameString(GDVars.curChar, 'Creates a noxious cloud', 10, False);
  CbtMap.ScrollView(GDVars.gTargetX, GDVars.gTargetY, 255, C_Dir.CENTER);
  TextRend.PauseOnly;
  CharDisp.ClearMessageWindow;
  for k := 1 to 4 do
    if crIdx[k] > 0 then
      FxEngine.ConsiderStinkingCloud(GDVars.creatureArr[crIdx[k]]);
end;

{ Strength: add 1d4 for a mage, 1d6 for a cleric or thief, 1d8 for a fighter, paladin or ranger; when several classes
  match, the last test wins, and with none of them nothing is added. Above 18, those warriors turn each extra point into
  10 points of exceptional Strength (capped at 100) and others are held at 18. }
procedure StrengthHandler;
var
  tgt: Types.PCharRecord;
  exStr: Byte;
  roll: Byte;
  newStr: Byte;
  enc: Byte;
begin
  exStr := 0;
  roll := 0;
  tgt := GDVars.dsTargetCreaturePtr[1];
  if tgt^.classLevels[C_Level.MAGE] > 0 then
    roll := Dice.RollDice(1, 4);
  if (tgt^.classLevels[C_Level.CLERIC] > 0) or (tgt^.classLevels[C_Level.THIEF] > 0) then
    roll := Dice.RollDice(1, 6);
  if CharHlp.WarriorLevel(tgt) > 0 then
    roll := Dice.RollDice(1, 8);
  newStr := tgt^.strCur + roll;
  if newStr > 18 then begin
    if CharHlp.WarriorLevel(tgt) > 0 then begin
      { 10 exceptional points per point above 18 }
      exStr := tgt^.strExc + (newStr - 18) * 10;
      { Percentile cap 100 }
      if exStr > 100 then
        exStr := 100;
      newStr := 18;
    end else
      newStr := 18;
  end;
  if FxEngine.AdjustForNewStrength(tgt, newStr, exStr, enc) then
    CharDisp.PrintNameString(tgt, 'is stronger', 10, True);
  FxEngine.AddEffect(tgt, C_Effect.STRENGTH, Magic.CalcSpellDuration(GDVars.dsCurrentSpellBeing), enc, True);
end;

{ Animate Dead: animate up to caster-level dead (C_Status.DEAD) human (charType 0) creatures whose cell is still a valid
  location. Effect 32's strength is the old side * 16 + caster level (at most 15). Each corpse joins the caster's team
  under computer control (quickfight 1), becomes undead (charType 4, levelUndead 2, movementBase 6, attackLevel 0),
  loses its memorized spells and gets the animated NPC or PC npc code; if ReviveDeadCreature succeeds at full hpMax it
  also gets effect 32 and C_Status.ANIMATED. }
procedure AnimateDeadHandler;
var
  i: Byte;
  strength: Byte;
  n: Byte;
  p: Types.PCharRecord;
begin
  GDVars.gMultiTarget := 1;
  n := CharHlp.GetCasterLevel(GDVars.dsCurrentSpellBeing);
  GDVars.spellTargetCount := 0;
  p := GDVars.creatureList;
  while (p <> nil) and (n > 0) do begin
    if p^.status = C_Status.DEAD then
      { Human }
      if p^.charType = 0 then
        if CbtMap.IsValidCreatureLoc(p, CbtMap.CombatCellX(p), CbtMap.CombatCellY(p), True) then begin
          { the corpse's side in bit 4, the caster level (at most 15) below it: a level of 16 or more carried into the
            side, and EffAnimateDead gave the corpse back a hostile of 2 or more (#710) }
          strength := CharHlp.GetCasterLevel(GDVars.dsCurrentSpellBeing);
          if strength > 15 then
            strength := 15;
          strength := (p^.hostile and 1) * 16 + strength;
          p^.hostile := GDVars.curChar^.hostile;
          p^.quickfight := 1;
          p^.levelUndead := 2;
          p^.attackLevel := 0;
          p^.movementBase := 6;
          for i := 0 to Types.SPELL_SLOT_LAST do
            p^.memorizedSpells[i] := 0;
          { C_Npc.FLAG set }
          if CharHlp.IsNpc(p) then
            p^.npc := C_Npc.ANIMATED_NPC
          else
            p^.npc := C_Npc.ANIMATED_PC;
          { Undead }
          p^.charType := 4;
          if GDVars.ifcState = C_Ifc.COMBAT then
            p^.combatAddr^.other := nil;
          Dec(n);
          if FxEngine.ReviveDeadCreature(p, p^.hpMax) then begin
            FxEngine.AddEffectWithMessage(p, C_Effect.ANIMATE_DEAD, 0, strength, True, False, False, 'is animated');
            p^.status := C_Status.ANIMATED;
          end;
        end;
    p := p^.nextCharAddr;
  end;
end;

{ Cure Blindness: remove the first target's blindness. }
procedure CureBlindnessHandler;
begin
  if FxEngine.RemoveEffectWithMessage(GDVars.dsTargetCreaturePtr[1], C_Effect.BLIND) then
    CharDisp.PrintNameStringAnim(GDVars.dsTargetCreaturePtr[1], True, 'can see');
end;

{ Cause Blindness: apply the spell's effect. }
procedure CauseBlindnessHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, 0, 0, 'is blind');
end;

{ Remove disease from tgt with effectLock held: Diseased, the Strength-draining disease (also dropping its hit-point and
  helpless effects) and rot (also dropping mummy rot). Returns True if any of the three was present. }
function RemoveDiseaseEffects(tgt: Types.PCharRecord): Boolean;
begin
  RemoveDiseaseEffects := False;
  GDVars.effectLock := 1;
  if FxEngine.RemoveEffectWithMessage(tgt, C_Effect.DISEASED) then
    RemoveDiseaseEffects := True;
  if FxEngine.RemoveEffectWithMessage(tgt, C_Effect.DISEASE_STR) then begin
    RemoveDiseaseEffects := True;
    FxEngine.RemoveEffect(tgt, C_Effect.DISEASE_HP, nil);
    FxEngine.RemoveEffect(tgt, C_Effect.HELPLESS, nil);
  end;
  if FxEngine.RemoveEffectWithMessage(tgt, C_Effect.ROT_NO_HEAL) then begin
    RemoveDiseaseEffects := True;
    FxEngine.RemoveEffect(tgt, C_Effect.MUMMY_ROT, nil);
  end;
  GDVars.effectLock := 0;
end;

{ Cure Disease: remove the first target's disease effects. }
procedure CureDiseaseHandler;
var
  junk: Boolean;
begin
  junk := Magic.RemoveDiseaseEffects(GDVars.dsTargetCreaturePtr[1]);
end;

{ Cause Disease: apply the spell's effect. }
procedure CauseDiseaseHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, True, 0, 0, 'is diseased');
end;

{ Dispel Magic: on each target, try every effect whose strength is below 255, with its low nibble as the effect's caster
  level: 50%, +5% per caster level above it, -2% per level below. A paladin's lay-on-hands and cure-disease timers are
  left alone, and so are the diseases (C_Effect.DISEASES), which Cure Disease removes: SSI's dispelled Strength drain
  re-armed itself and took another point (#787). A removal that frees the next effect (dispelled Animate Dead) ends that
  target's walk; SSI read on into the freed node. }
procedure DispelMagicHandler;
var
  chance: Byte;
  effLevel: Byte;
  i: Byte;
  cl: Byte;
  tgt: Types.PCharRecord;
  removed: Boolean;
  effect: Types.PEffectRec;
  nxt: Types.PEffectRec;
begin
  GDVars.gMultiTarget := 1;
  cl := CharHlp.GetCasterLevel(GDVars.dsCurrentSpellBeing);
  for i := 1 to GDVars.spellTargetCount do begin
    removed := False;
    if i <= Types.ARENA_SLOTS then
      tgt := GDVars.dsTargetCreaturePtr[i]
    else
      tgt := nil;
    if tgt <> nil then
      effect := Types.PEffectRec(tgt^.effectsAddr)
    else
      effect := nil;
    while effect <> nil do begin
      nxt := effect^.next;
      if (effect^.strength < 255)
         and not (effect^.id in C_Effect.DISEASES + [C_Effect.RECENT_HEAL, C_Effect.RECENT_CURE]) then begin
        { dispel treats the low nibble as caster level }
        effLevel := effect^.strength and $F;
        if cl > effLevel then
          chance := (cl - effLevel) * 5 + 50
        else if cl < effLevel then
          chance := 50 - (effLevel - cl) * 2
        else
          chance := 50;
        if Dice.RollDice(1, 100) <= chance then begin
          FxEngine.RemoveEffect(tgt, effect^.id, effect);
          removed := True;
          { a removal that kills the creature (Animate Dead's) strips its 0-HP effects, which may free the next node:
            the walk goes on only while that node is still in the list }
          if (nxt <> nil) and not FxEngine.HasEffectNode(tgt, nxt) then
            nxt := nil;
        end;
      end;
      effect := nxt;
    end;
    if removed then
      CharDisp.PrintNameStringAnim(tgt, True, 'is affected');
  end;
end;

{ Prayer: apply the spell's effect at strength caster team * 16 + caster level. }
procedure PrayerHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing,
                      GDVars.curChar^.hostile * 16 + CharHlp.GetCasterLevel(GDVars.dsCurrentSpellBeing), False, 0,
                      0, 'is praying');
end;

procedure RemoveCurseSpell;
var
  item: Types.PItemRec;
  found: Boolean;
begin
  if FxEngine.RemoveEffectWithMessage(GDVars.dsTargetCreaturePtr[1], C_Effect.BESTOW_CURSE) then
    CharDisp.PrintNameStringAnim(GDVars.dsTargetCreaturePtr[1], True, 'is un-cursed')
  else begin
    found := False;
    item := GDVars.dsTargetCreaturePtr[1]^.itemsAddr;
    while (item <> nil) and (found = False) do begin
      if item^.cursed <> 0 then begin
        found := True;
        item^.cursed := 0;
      end;
      item := item^.next;
    end;
    if found then
      CharDisp.PrintNameStringAnim(GDVars.dsTargetCreaturePtr[1], True, '''s item is un-cursed');
  end;
end;

{ Bestow Curse: apply the spell's effect. }
procedure BestowCurseHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, 0, 0, 'has been cursed!');
end;

{ Blink: apply the spell's effect. }
procedure BlinkHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, 0, 0, 'is blinking');
end;

{ Fireball: spell 64 (an item fireball) uses level 1d3 * 2 + 1. When zone0^.view3dFlag is 0 the target list is rebuilt
  with Pathing.TargetArea, radius 2 around the aim cell. Damage is level d6, element mask 9. }
procedure FireballHandler;
var
  cl: Byte;
begin
  GDVars.gMultiTarget := 1;
  if GDVars.dsCurrentSpellBeing = C_Spell.ITEM_FIREBALL then
    cl := Dice.RollDice(1, 3) * 2 + 1
  else
    cl := CharHlp.GetCasterLevel(GDVars.dsCurrentSpellBeing);
  if GDVars.zone0^.view3dFlag = 0 then begin
    Pathing.TargetArea(GDVars.gTargetX, GDVars.gTargetY, 2);
  end;
  CbtMap.ScrollView(GDVars.gTargetX, GDVars.gTargetY, 0, C_Dir.CENTER);
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, Dice.RollDamageDice(cl, 6),
                     C_Effect.ELEM_FIRE or C_Effect.ELEM_MAGIC, '');
end;

{ Haste and Slow: keep up to caster-level targets on team hostFlag and drop the rest. A kept target carrying removeId,
  the opposing Slowed or Hasted effect, just loses it; the others get the spell's effect and have their
  C_Cond.MOVE_ATTACK_RATE effects re-run on their own attack count, as at a round's start (#797), so a hasted one ages
  at once; its rates are worked out where they are used (CbtActs). }
procedure HasteSlowLogic(removeId: Byte; hostFlag: ShortInt; msg: Types.TStr40);
var
  cl: Byte;
  i: Byte;
begin
  GDVars.gMultiTarget := 1;
  cl := CharHlp.GetCasterLevel(GDVars.dsCurrentSpellBeing);
  for i := 1 to GDVars.spellTargetCount do begin
    if (GDVars.dsTargetCreaturePtr[i]^.hostile = hostFlag) and (cl > 0) then begin
      Dec(cl);
      if FxEngine.RemoveEffectWithMessage(GDVars.dsTargetCreaturePtr[i], removeId) then
        GDVars.dsTargetCreaturePtr[i] := nil;
    end else
      GDVars.dsTargetCreaturePtr[i] := nil;
  end;
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, 0, 0, msg);
  for i := 1 to GDVars.spellTargetCount do
    if GDVars.dsTargetCreaturePtr[i] <> nil then begin
      GDVars.dsCurrentAttackCurrent := GDVars.dsTargetCreaturePtr[i]^.attacks2;
      GDVars.dsCurrentCreatureCalculatingFlag := 0;
      FxEngine.TriggerEffectsWithCondition(C_Cond.MOVE_ATTACK_RATE, GDVars.dsTargetCreaturePtr[i]);
    end;
end;

{ Haste: the caster's team loses Slowed or is hasted (see HasteSlowLogic). }
procedure HasteHandler;
begin
  Magic.HasteSlowLogic(C_Effect.SLOWED, GDVars.curChar^.hostile, 'is Hasted');
end;

{ Lightning damage to the creature at one bolt cell (half on a save of saveType). blocked returns whether the cell's
  terrain is impassable (cost 255). }
procedure LightningAttackAt(x, y: ShortInt; damage: Byte; saveType: ShortInt; var blocked: Boolean);
var
  tgt: Types.PCharRecord;
  crIdx: Byte;
  terr: Byte;
begin
  blocked := False;
  CbtMap.GetArenaContents(x, y, crIdx, terr);
  if terr > 0 then
    if GDConsts.terrainInfo[terr].cost = 255 then
      blocked := True;
  if crIdx > 0 then begin
    tgt := GDVars.creatureArr[crIdx];
    GDVars.elementMask := C_Effect.ELEM_ELEC or C_Effect.ELEM_MAGIC;
    FxEngine.InflictNonWeaponDamage(tgt, damage, 2, FxEngine.RollSavingThrow(tgt, saveType, 0));
    CharDisp.BuildIconFacings(19);
    GDVars.elementMask := 0;
  end;
end;

{ Run a lightning bolt from the aim cell (GDVars.gTargetX/Y) directly away from the caster, attacking each creature cell
  it reaches; callers attack the aim cell itself first. The budget is boltLen * 2 in Pathing's doubled distance units.
  Impassable terrain reflects the bolt back the other way; with bounce set, a first reflection at most 8 units from the
  caster costs 8 extra units. An off-map cell ends the bolt. }
procedure LightningPath(boltLen, damage: Byte; saveType: ShortInt; bounce: Boolean);
var
  cells: Types.TCellList;
begin
  Magic.WalkBolt(boltLen, damage, saveType, bounce, False, cells);
end;

{ LightningPath's walk. With trace set it neither animates nor attacks: it lists every arena cell the bolt crosses in
  cells and leaves GDVars.gTargetX/Y and GDVars.gMultiTarget as it found them. }
procedure WalkBolt(boltLen, damage: Byte; saveType: ShortInt; bounce, trace: Boolean; var cells: Types.TCellList);
var
  req: Types.TPathReq;
  req2: Types.TPathReq;
  x0: ShortInt;
  y0: ShortInt;
  prevX: ShortInt;
  prevY: ShortInt;
  sign: ShortInt;
  blocked: Boolean;
  valid: Boolean;
  doBounce: Boolean;
  prevCr: Byte;
  crIdx: Byte;
  terr: Byte;
  budget: Byte;
  savedX: ShortInt;
  savedY: ShortInt;
  savedMulti: Byte;
begin
  cells.count := 0;
  savedX := GDVars.gTargetX;
  savedY := GDVars.gTargetY;
  savedMulti := GDVars.gMultiTarget;
  if not trace then
    CharDisp.BuildIconFacings(19);
  CbtMap.GetArenaContents(GDVars.gTargetX, GDVars.gTargetY, prevCr, terr);
  sign := 1;
  x0 := CbtMap.CombatCellX(GDVars.curChar);
  y0 := CbtMap.CombatCellY(GDVars.curChar);
  doBounce := bounce;
  if x0 = GDVars.gTargetX then
    if y0 = GDVars.gTargetY then
      Exit;
  budget := boltLen * 2;
  GDVars.gMultiTarget := 1;
  while budget > 0 do begin
    FillChar(req, SizeOf(req), 0);
    req.sx := GDVars.gTargetX;
    req.sy := GDVars.gTargetY;
    req.ex := GDVars.gTargetX + (GDVars.gTargetX - x0) * sign * budget;
    req.ey := GDVars.gTargetY + (GDVars.gTargetY - y0) * sign * budget;
    Pathing.PathFind(req);
    repeat
      prevX := req.cx;
      prevY := req.cy;
      if (req.sx <> req.ex) or (req.sy <> req.ey) then begin
        repeat
          valid := Pathing.NextPathStep(req);
          CbtMap.GetArenaContents(req.cx, req.cy, crIdx, terr);
          if trace and valid and (terr <> 0) and (cells.count < SizeOf(cells.x)) then begin
            Inc(cells.count);
            cells.x[cells.count] := req.cx;
            cells.y[cells.count] := req.cy;
          end;
        until (valid = False) or ((crIdx > 0) and (crIdx <> prevCr)) or (terr = 0) or
            (GDConsts.terrainInfo[terr].cost > 1) or (req.dist >= budget);
      end;
      prevCr := crIdx;
      if terr = 0 then
        budget := 0;
      if trace then begin
        { LightningAttackAt's test }
        blocked := False;
        if terr > 0 then
          blocked := GDConsts.terrainInfo[terr].cost = 255;
      end else begin
        CharDisp.CombatAnimateMovingIcon(prevX, prevY, req.cx, req.cy, 4, 50);
        Magic.LightningAttackAt(req.cx, req.cy, damage, saveType, blocked);
      end;
      if blocked then begin
        GDVars.gTargetX := req.cx;
        GDVars.gTargetY := req.cy;
        FillChar(req2, SizeOf(req2), 0);
        req2.sx := GDVars.gTargetX;
        req2.sy := GDVars.gTargetY;
        req2.ex := x0;
        req2.ey := y0;
        Pathing.PathFind(req2);
        while Pathing.NextPathStep(req2) do ;
        if doBounce then
          if req2.dist <= 8 then
            Inc(req.dist, 8);
        sign := 0 - sign;
        doBounce := False;
        prevCr := 0;
      end;
      if req.dist < budget then
        Dec(budget, req.dist)
      else
        budget := 0;
    until blocked or (budget = 0);
  end;
  GDVars.gMultiTarget := 0;
  if trace then begin
    GDVars.gTargetX := savedX;
    GDVars.gTargetY := savedY;
    GDVars.gMultiTarget := savedMulti;
  end;
end;

{ Lightning Bolt: caster-level d6 damage at the aim cell, then a bouncing bolt of 8 cells. }
procedure LightningBoltHandler;
var
  dmg: Byte;
  junk: Boolean;
begin
  dmg := Dice.RollDice(CharHlp.GetCasterLevel(GDVars.dsCurrentSpellBeing), 6);
  Magic.LightningAttackAt(GDVars.gTargetX, GDVars.gTargetY, dmg, C_Save.SPELL, junk);
  Magic.LightningPath(LIGHTNING_BOLT_CELLS, dmg, C_Save.SPELL, True);
end;

procedure TraceLightningBolt(x, y: ShortInt; var cells: Types.TCellList);
var
  savedX: ShortInt;
  savedY: ShortInt;
begin
  savedX := GDVars.gTargetX;
  savedY := GDVars.gTargetY;
  GDVars.gTargetX := x;
  GDVars.gTargetY := y;
  Magic.WalkBolt(LIGHTNING_BOLT_CELLS, 0, C_Save.SPELL, True, True, cells);
  GDVars.gTargetX := savedX;
  GDVars.gTargetY := savedY;
end;

{ Slow: the caster's enemies lose Hasted or are slowed (see HasteSlowLogic). }
procedure SlowHandler;
begin
  Magic.HasteSlowLogic(C_Effect.HASTED, CharHlp.EnemyTeam(GDVars.curChar), 'is Slowed');
end;

{ Restoration: give back one drained level. hpMax, hpCur and hpRolled regain drainedHps div drainedLevels. Scanning
  classes 0..7, a class becomes the pick when its level is not above the current pick's, its next-level XP is nonzero
  and smaller, and it is not at its level cap. The pick gains a level and experience is raised to its next-level XP if
  lower; with no pick the hit points alone come back. }
procedure RestorationHandler;
var
  tgt: Types.PCharRecord;
  share: Byte;
  bestLvl: ShortInt;
  lvl: ShortInt;
  bestXp: LongInt;
  bestCls: ShortInt;
  cls: ShortInt;
begin
  tgt := GDVars.dsTargetCreaturePtr[1];
  if tgt^.drainedLevels > 0 then begin
    share := tgt^.drainedHps div tgt^.drainedLevels;
    Inc(tgt^.hpMax, share);
    Inc(tgt^.hpCur, share);
    Inc(tgt^.hpRolled, share);
    Dec(tgt^.drainedHps, share);
    Dec(tgt^.drainedLevels);
    { 13: above any class level, so the first eligible class passes lvl <= bestLvl }
    bestLvl := 13;
    { sentinel above any table entry }
    bestXp := 10000000;
    { no class picked yet }
    bestCls := -1;
    for cls := C_Level.CLERIC to C_Level.MONK do begin
      lvl := tgt^.classLevels[cls];
      { xp[] runs to level 9 }
      if (lvl > 0) and (lvl < 9) and (lvl <= bestLvl) and (GDConsts.dsExperienceSpellsClass[cls].xp[Succ(lvl)] > 0) and
          (GDConsts.dsExperienceSpellsClass[cls].xp[Succ(lvl)] < bestXp) and
          (not CharHlp.AtLevelCap(tgt, cls)) then begin
        bestLvl := lvl;
        bestCls := cls;
        bestXp := GDConsts.dsExperienceSpellsClass[cls].xp[Succ(lvl)];
      end;
    end;
    if bestCls >= 0 then begin
      Inc(tgt^.classLevels[bestCls]);
      if tgt^.experience < bestXp then
        tgt^.experience := bestXp;
    end;
    ClassCal.RecalcBaseSkills(tgt);
    CharDisp.PrintNameString(tgt, 'is restored', 10, True);
  end;
end;

{ Potion of Speed: remove Slowed, or else apply the potion's effect. }
procedure PotionOfSpeedHandler;
begin
  if not FxEngine.RemoveEffectWithMessage(GDVars.dsTargetCreaturePtr[1], C_Effect.SLOWED) then
    Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, 0, 0, 'is Speedy');
end;

{ Keoghtom's Ointment: cure poison (also removing effect 22 silently), else cure disease, else heal 1d4 + 8. Poison
  kills on the spot, so a target the poison left dead gets back up with at least 1 hp, as under Slow Poison
  (StandUpOrWake). A dead target still under Slow Poison was kept up through the poison and died of something else (a
  wound, bleeding out), so it stays dead, as at the temple (Temple.NeutralizePoison). }
procedure KeoghtomsOintmentHandler;
var
  tgt: Types.PCharRecord;
  effect: Types.PEffectRec;
  slowed: Boolean;
begin
  tgt := GDVars.dsTargetCreaturePtr[1];
  slowed := CharHlp.HasEffect(tgt, C_Effect.SLOW_POISON_END, effect) or
            CharHlp.HasEffect(tgt, C_Effect.SLOW_POISON_HIT, effect);
  if FxEngine.RemoveEffectWithMessage(tgt, C_Effect.POISONED) then begin
    GDVars.effectLock := 1;
    FxEngine.RemoveEffect(tgt, C_Effect.SLOW_POISON_END, nil);
    GDVars.effectLock := 0;
    if (tgt^.status = C_Status.DEAD) and not slowed then begin
      if tgt^.hpCur = 0 then
        tgt^.hpCur := 1;
      StandUpOrWake(tgt);
    end;
  end else if not Magic.RemoveDiseaseEffects(tgt) then begin
    if FxEngine.RestoreHitPoints(GDVars.dsTargetCreaturePtr[1], Dice.RollDice(1, 4) + 8, False) then
      CharDisp.PrintNameStringAnim(GDVars.dsTargetCreaturePtr[1], True, 'is Healed');
  end;
end;

{ Giant Strength: raise Strength to 21 and add the Strength effect, which keeps the Strength encoding
  AdjustForNewStrength returns. }
procedure GiantStrengthHandler;
var
  enc: Byte;
begin
  if FxEngine.AdjustForNewStrength(GDVars.dsTargetCreaturePtr[1], 21, 0, enc) then
    CharDisp.PrintNameString(GDVars.dsTargetCreaturePtr[1], 'is stronger', 10, True);
  FxEngine.AddEffect(GDVars.dsTargetCreaturePtr[1], C_Effect.STRENGTH,
                     Magic.CalcSpellDuration(GDVars.dsCurrentSpellBeing), enc, True);
end;

{ Javelin of Lightning: 1d6 + 20 damage at the aim cell, then a 3-cell bolt of 20 damage. }
procedure JavelinOfLightningHandler;
var
  junk: Boolean;
begin
  Magic.LightningAttackAt(GDVars.gTargetX, GDVars.gTargetY, Dice.RollDice(1, 6) + 20, C_Save.SPELL, junk);
  Magic.LightningPath(3, 20, C_Save.SPELL, False);
end;

{ Wand of Paralyzation: apply the item's effect. }
procedure WandParalyzationHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, 0, 0, 'is paralyzed');
end;

{ Potion of Healing: restore 2d4 + 2 hit points. }
procedure PotionOfHealingHandler;
begin
  if FxEngine.RestoreHitPoints(GDVars.dsTargetCreaturePtr[1], Dice.RollDice(2, 4) + 2, False) then
    CharDisp.PrintNameStringAnim(GDVars.dsTargetCreaturePtr[1], True, 'is Healed');
end;

{ Dust of Disappearance: apply the item's effect. }
procedure DustDisappearanceHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, 0, 0, 'is invisible');
end;

{ Wand of Magic Missiles: 2d4 + 2 damage, element C_Effect.ELEM_MAGIC. }
procedure WandMagicMissilesHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, Dice.RollDamageDice(2, 4) + 2, C_Effect.ELEM_MAGIC, '');
end;

{ Unused item spell slot: does nothing. }
procedure UnusedSpellHandler;
begin
end;

{ Manual of Bodily Health: apply the item's effect at strength 255. }
procedure ManualBodilyHealthHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 255, True, 0, 0, 'is Reading');
end;

{ Bronze dragon breath, effect 88's handler. After the first round (roundCounter <> 0) it holds fire half the time.
  Otherwise the cast-target UI picks an aim for spell 51 (Lightning Bolt) with automatic targeting, and the aim becomes
  one step from the dragon toward it, plus one more step on each axis where that step is +1. A bolt of hpMax damage
  (save type 3) then hits that cell and runs 10 cells. Charges live in the effect's strength: 255 and 254 are
  decremented, anything lower removes the effect. removed is unused. }
procedure DragonBreathHandler(creature: Types.PCharRecord; p: Pointer; removed: Boolean);
var
  junk: Boolean;
  x: ShortInt;
  y: ShortInt;
begin
  if GDVars.roundCounter <> 0 then
    if Dice.RollDice(1, 100) <= 50 then
      Exit;
  x := CbtMap.CombatCellX(creature);
  y := CbtMap.CombatCellY(creature);
  CharDisp.PrintNameString(creature, 'Breathes!', 10, True);
  GDVars.castTargetMenu(C_Spell.LIGHTNING_BOLT, True, GDVars.breathAim);
  GDVars.gTargetX := x + Pathing.SignOf(GDVars.gTargetX - x);
  GDVars.gTargetY := y + Pathing.SignOf(GDVars.gTargetY - y);
  if GDVars.gTargetX = x + 1 then
    Inc(GDVars.gTargetX);
  if GDVars.gTargetY = y + 1 then
    Inc(GDVars.gTargetY);
  FxEngine.RemoveInvisibility(creature);
  CharDisp.BuildIconFacings(19);
  CharDisp.CombatAnimateMovingIcon(x, y, GDVars.gTargetX, GDVars.gTargetY, 4, 50);
  Magic.LightningAttackAt(GDVars.gTargetX, GDVars.gTargetY, creature^.hpMax, C_Save.BREATH, junk);
  Magic.LightningPath(10, creature^.hpMax, C_Save.BREATH, False);
  { Remaining breath charges }
  if Types.PEffectRec(p)^.strength > 253 then
    Dec(Types.PEffectRec(p)^.strength)
  else
    FxEngine.RemoveEffect(creature, C_Effect.DRAGON_BREATH, p);
  junk := CharHlp.EndActions(creature);
end;

procedure RemoveSpellFromScroll(cr, it: Pointer; spell: Byte);
var
  sp: Byte;
  i: Byte;
  found: Byte;
begin
  sp := spell and C_Spell.ID_MASK;
  found := 0;
  { 3 = High(TItemRec.spells) }
  for i := 1 to 3 do
    if Types.PItemRec(it)^.spells[i] and C_Spell.ID_MASK = sp then
      found := i;
  if found = 0 then
    Exit;
  Types.PItemRec(it)^.spells[found] := 0;
  { scroll spell-count name component }
  Dec(Types.PItemRec(it)^.nameIds[2]);
  if Types.PItemRec(it)^.nameIds[2] < C_Item.NAME_WITH_1_SPELL then
    CharHlp.RemoveItem(Types.PCharRecord(cr), Types.PItemRec(it));
end;

procedure PrintCastSpellMsg(creature: Types.PCharRecord; msg: Types.TStr40; spell: Byte);
begin
  if GDVars.ifcState = C_Ifc.COMBAT then begin
    CharDisp.PrintNameString(creature, 'Casts a Spell', 10, True);
    Border.ClearBox(0, 23, 39, 23);
    TextRend.DisplayString(0, 23, LightGreen, 'Spell:' + GDConsts.spellNames[spell]);
  end else begin
    Border.ClearBox(1, 18, 38, 22);
    CharDisp.DisplayCreatureName(creature, 1, 19, False);
    TextRend.DisplayString(Length(creature^.name) + 2, 19, LightGreen, msg);
    TextRend.DisplayString(1, 20, LightGreen, GDConsts.spellNames[spell]);
    TextRend.PauseOnly;
    CharDisp.ClearMessageWindow;
  end;
end;

{ SpellMenu's work, with the chosen line's scroll in scroll. }
function ChooseSpell(menuType, selType: Byte; var idx: Integer; var notEmpty: Boolean;
  var scroll: Types.PItemRec): Byte;
var
  s: Types.TStr40;
begin
  case menuType of
    0: s := 'in Memory';
    1: s := 'in Spell Book';
    2: s := 'on Scroll';
    3: s := 'on Scrolls';
    4: s := 'to choose from';
    5: s := 'to be memorized';
    6: s := 'to be scribed';
    7: s := '';
  else
    s := '';
  end;
  notEmpty := Magic.GenerateSpellList(GDVars.curChar, menuType);
  if notEmpty then begin
    if idx < 0 then begin
      Border.DrawWindow(1, 1, 38, 1, 0, Black, '');
      CharDisp.DisplayCreatureName(GDVars.curChar, 1, 1, True);
      if menuType = 7 then
        s := 'Available Spells'
      else
        s := 'Spells ' + s;
      TextRend.DisplayString(Length(GDVars.curChar^.name) + 4, 1, LightGreen, s);
    end;
    ChooseSpell := Magic.SpellSelection(selType, idx, scroll);
  end else begin
    scroll := nil;
    ChooseSpell := 0;
  end;
end;

function SpellMenu(menuType, selType: Byte; var idx: Integer; var notEmpty: Boolean): Byte;
var
  scroll: Types.PItemRec;
begin
  SpellMenu := Magic.ChooseSpell(menuType, selType, idx, notEmpty, scroll);
end;

function CastSpellMenu(var idx: Integer; var notEmpty: Boolean; var scroll: Types.PItemRec): Byte;
begin
  CastSpellMenu := Magic.ChooseSpell(7, 1, idx, notEmpty, scroll);
end;

{ Cast spell from item, a scroll or an effect-bearing item (an effect past C_Spell.LAST maps to spell effect -
  C_Spell.ITEM_EFFECT_SHIFT), setting usingItem during the cast. A combat-only scroll spell outside combat is not cast:
  Cast's message (Magic.ShowCombatOnlySpell) and 'Use it?', where Yes sets done and spends the scroll spell and No
  leaves done clear. In combat, a spell castable in combat (whenCast <> 0) ends the user's actions and sets done, cast
  or not. Past that prompt, only when the spell was cast, consume the scroll spell, or use quantity and then charges;
  remove the item when its charges run out (SSI spent them on done, so an aborted spell in combat still used them up).
  announce (the Cast list's scroll lines) names the spell first, as casting a memorized one does
  (Magic.PrintCastSpellMsg); Use names none. A spell id past the spell table, from corrupt or edited item data, does
  nothing and leaves done clear. }
procedure UseItemSpell(item: Types.PItemRec; spell: Byte; announce: Boolean; var done: Boolean);
var
  id: Byte;
  { set only when the spell was cast (not on an aborted aim); the item is spent on it, not on done, which in combat
    also reports the end of the turn }
  cast: Boolean;
begin
  id := spell;
  if not CharHlp.ItemReadable(item) and (spell > C_Spell.LAST) then
    id := spell - C_Spell.ITEM_EFFECT_SHIFT;
  if (id < 1) or (id > SizeOf(GDConsts.spellTable) div SizeOf(GDConsts.spellTable[1])) then begin
    done := False;
    Exit;
  end;
  if CharHlp.ItemReadable(item) and (GDVars.ifcState <> C_Ifc.COMBAT) and
      (GDConsts.spellTable[spell].target = 0) then begin
    Magic.ShowCombatOnlySpell(spell);
    done := MenuCore.YesNoMenu('Use it? ', LightMagenta, White, LightGreen) = 'Y';
    CharDisp.ClearMessageWindow;
    if done then
      Magic.RemoveSpellFromScroll(GDVars.curChar, item, spell);
    Exit;
  end;
  if (GDVars.ifcState = C_Ifc.COMBAT) and (GDVars.curChar^.quickfight = 0) then
    CharDisp.DisplayCombatInterface;
  if not CharHlp.ItemReadable(item) then begin
    if spell > C_Spell.LAST then
      { item effect -> spell id }
      Dec(spell, C_Spell.ITEM_EFFECT_SHIFT);
    CharDisp.PrintNameString(GDVars.curChar, 'uses an item', 10, False);
    if GDVars.ifcState = C_Ifc.COMBAT then begin
      TextRend.DisplayString(0, 23, LightGreen, 'Item:');
      CharDisp.PrintItemLabel(item, 5, 23);
    end else
      CharDisp.PrintItemLabel(item, 1, 22);
    TextRend.PauseOnly;
    CharDisp.ClearMessageWindow;
  end;
  GDVars.usingItem := True;
  if announce then
    Magic.PrintCastSpellMsg(GDVars.curChar, 'casts', spell);
  cast := False;
  Magic.CastSpellNC(spell, Boolean(GDVars.curChar^.quickfight), False, cast);
  GDVars.usingItem := False;
  done := cast;
  if GDVars.ifcState = C_Ifc.COMBAT then
    if GDConsts.spellTable[spell].whenCast <> 0 then
      done := CharHlp.EndActions(GDVars.curChar);
  if cast then begin
    if CharHlp.ItemReadable(item) then
      Magic.RemoveSpellFromScroll(GDVars.curChar, item, spell)
    else if item^.charges > 0 then begin
      if item^.quantity > 1 then
        Dec(item^.quantity)
      else begin
        Dec(item^.charges);
        if item^.charges = 0 then
          CharHlp.RemoveItem(GDVars.curChar, item);
      end;
    end;
  end;
end;

{ Cast from a scroll (spell chosen from its list) or an effect-bearing item through UseItemSpell. }
procedure UseItem(item: Types.PItemRec; var done: Boolean);
var
  spell: Byte;
  idx: Integer;
  notEmpty: Boolean;
begin
  idx := -1;
  GDVars.usingItem := False;
  spell := 0;
  if CharHlp.ItemReadable(item) then begin
    dsCurrentScrollPtr := item;
    spell := Magic.SpellMenu(2, 1, idx, notEmpty);
  end else if (item^.effect > 0) and (item^.special < $80) then
    spell := item^.effect;
  if spell = 0 then
    done := False
  else
    Magic.UseItemSpell(item, spell, False, done);
end;

end.

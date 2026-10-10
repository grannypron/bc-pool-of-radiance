{ Spell selection, casting, targeting and spell-specific behavior. }
{$O+,F+}
unit Magic;

interface

{ Types supplies PCharRecord, PItemRec, PEffectRec and TStr40 for the declarations below. }
uses Types, Crt, C_Npc, C_Terr, C_Save, C_Cond, GDConsts, GDVars, Session, DaxIo,
  TextRend, Border, CharHlp, SoundDrv, MenuCore, Pathing, CbtMap, ClassCal, FxEngine, C_Effect, C_Race, C_Keys, C_Class,
  C_Status, C_Ifc, C_Dir, C_Spell;

{ Spell-selection menu: MenuCore.MenuVertical over spellList as built by GenerateSpellList. selType: 1 cast, 2 memorize
  (shorter window, bottom row 15), 3 scribe, 4 learn (on gaining a level; no Exit entry), 5 show only (drawn and left
  for the caller's question, unless it needs paging; MenuCore.listOnly), anything else view only (no title or prompt).
  idx is the menu cursor and persists across calls; idx < 0 clears the window and opens at the top of the list on its
  first spell (cast and learn always redraw). Returns the chosen spell id, or 0 for Exit, and sets GDVars.castScroll
  to the chosen line's scroll in spellScrolls (nil for Exit); scribe also sets GDVars.dsCurrentScrollPtr to the chosen
  spell's scroll. Frees spellList before returning. }
function SpellSelection(selType: Byte; var idx: Integer): Byte;

{ Build spellList and spellIds for a spell menu. menuType: 0 memorized, 5 still being memorized (bit 7 set), 1 spell
  book, 2 current scroll, 3 spells on every readable item, 6 scroll spells queued for scribing (bit 7 set), 4 spells
  learnable on gaining a level (the character has slots of the spell's class and level and does not know it yet), 7
  the spells the character can cast now (AddAvailableSpells). Returns True if the list has a spell; a list of level
  headings alone is freed and counts as empty. }
function GenerateSpellList(menuType: Byte): Boolean;

{ Spell range: rangeFixed + rangeVar * caster level, using caster level 6 when GDVars.usingItem. A zero range with a
  nonzero area (touch) and the 255 attack-roll encoding both become 1. }
function CalcSpellRange(spell: Byte): Byte;

{ Noncombat cast-target UI, installed in spellFps[0] outside combat. spellTable target mode 1 targets the caster, 2 asks
  for one party member (remembered in GDVars.castTarget; cancelling clears the targets and the cast) and 4 targets every
  creature in GDVars.creatureList; any other mode cancels the cast. b is unused; it matches Types.TCastUI. }
procedure NoncombatCastTargetMenu(spell: Byte; b: Boolean; var cast: Boolean);

{ Cast spell for GDVars.curChar. Outside combat a combat-only spell (target mode 0) is not cast: a memorized spell
  offers 'Lose it?' (Yes removes it) and an item offers 'Use it?' (Yes sets sel). Otherwise, when ai is set and no item
  is in use, announce the cast, then call the cast-target UI (spellFns[0]) with b until it picks targets or the cast
  ends. On a pick: in combat turn to face the aim, play the cast sound and animate the projectile; then remove the
  caster's invisibility, consume the memorized spell unless GDVars.usingItem, and run spellFns[spell] with
  dsCurrentSpellBeing set. With no pick, outside combat it just returns; in combat b, or Yes to 'Abort Spell?', aborts
  and consumes the spell, and otherwise targeting repeats. b means automatic targeting (AI or quick fight); sel returns
  whether targets were picked. }
procedure CastSpellNC(spell: Byte; b, ai: Boolean; var sel: Boolean);

{ Cast's refusal of a combat-only spell outside combat: show the spell's name and 'is a combat-only spell...' in the
  message window. }
procedure ShowCombatOnlySpell(spell: Byte);

{ True when it is non-nil and its base item's slot is 11, 12 or 13. }
function ItemReadable(it: Pointer): Boolean;

{ True when creature can read item's spells, that is when the scroll is identified. Read Magic (effect 16), or any
  cleric level with a scroll whose base item slot is 12, identifies it first. }
function ScrollLegible(creature: Types.PCharRecord; item: Types.PItemRec): Boolean;

{ True when item is a scroll creature can read (ScrollLegible) and could use: readied, or of a class Ready accepts. The
  two hands a readied scroll takes are not asked for. The Cast list offers these scrolls' spells, and Items > Use takes
  them unreadied. }
function CastableScroll(creature: Types.PCharRecord; item: Types.PItemRec): Boolean;

{ True when the creature may use items now (CharHlp.CanUseItems) and holds a scroll it can read and use with a spell on
  it: the scroll spells the Cast list offers. }
function HasScrollSpells(creature: Types.PCharRecord): Boolean;

{ Clear the last of the scroll's spell slots holding spell (bit 7 ignored) and decrement its spell-count name component,
  nameIds[2]; remove the item from cr once that drops below 210. Does nothing if no slot matches. }
procedure RemoveSpellFromScroll(cr, it: Pointer; spell: Byte);

{ Announce a cast. In combat, print 'Casts a Spell' for the creature (msg is ignored) and show the spell name on the
  bottom line. Otherwise show the creature name, msg and the spell name in the message window, pause, then clear it. }
procedure PrintCastSpellMsg(creature: Types.PCharRecord; msg: Types.TStr40; spell: Byte);

{ Remove Curse (spellFps[43], also called by Temple): remove Bestow Curse (effect 36) from dsTargetCreaturePtr[1], or
  else clear the curse on its first cursed item. }
procedure RemoveCurseSpell;

{ Called by GameInit2: install every spell handler in spellFps (slot 0 is the noncombat cast-target UI) and
  DragonBreathHandler as effect 88's handler, clear effectLock, GDVars.usingItem and GDVars.castTarget, and set
  dsRedrawInventoryMenuFlag. }
procedure InitSpellFns;

{ Spell handlers: each acts on GDVars.curChar, dsTargetCreaturePtr and dsCurrentSpellBeing; InitSpellFns maps spell IDs
  to them }
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

implementation

const
  { Lightning Bolt's length, in cells past the aim cell }
  LIGHTNING_BOLT_CELLS = 8;
  { AddSpellToList's markers, in the indent column: none; KNOWN_MARK on a spell already in curChar's spell book; or
    NOT_KNOWN_MARK on a spell curChar's classes could learn but its spell book lacks }
  MARK_NONE = 0;
  MARK_KNOWN = 1;
  MARK_NOT_KNOWN = 2;
  KNOWN_MARK = '-';
  NOT_KNOWN_MARK = '+';
  { a Cast line's scroll marker, in the indent column just before the spell name }
  SCROLL_MARK = '-';
  { the highest spell level in spellTable (Restoration's 7) }
  SPELL_LEVEL_LAST = 7;

var
  { Word view of GDConsts.soundIds -- commands, damage and the first eight combat ids: [3] = 2 (default cast), [9] = 8
    (Lightning Bolt), [12] = 11 (Fireball) }
  soundIds: array[0..12] of Word absolute GDConsts.soundIds;

  spellFns: array[0..67] of Types.TSpellProc
                            { dispatch view }
                            absolute GDVars.spellFps;
  { slot-0 call view }
  castUI: Types.TCastUI absolute GDVars.spellFps;

procedure AddSpellToList(spell, mark: Byte); forward;

function SpellMark(spell, mark: Byte): Char; forward;

procedure AddScrollSpells(forScribe: Boolean; mark: Byte); forward;

procedure AddAllScrollSpells(forScribe: Boolean; mark: Byte); forward;

function ScrollSpellAt(item: Types.PItemRec; slot: Byte): Byte; forward;

procedure AddScrollLine(item: Types.PItemRec; slot: Byte; var lines: Byte); forward;

procedure AddAvailableSpells; forward;

function CalcSpellDuration(spell: Byte): Word; forward;

procedure ResolveSpell(spell, eff: Byte; onRemove: Boolean; damage, elem: Byte; msg: Types.TStr40); forward;

procedure CastOneSide(hostFlag: ShortInt; msg: Types.TStr40); forward;

function RemoveDiseaseEffects: Boolean; forward;

procedure HasteSlowLogic(removeId: Byte; hostFlag: ShortInt; msg: Types.TStr40); forward;

procedure LightningAttackAt(x, y: ShortInt; damage: Byte; saveType: ShortInt; var blocked: Boolean); forward;

procedure LightningPath(boltLen, damage: Byte; saveType: ShortInt; bounce: Boolean); forward;

procedure WalkBolt(boltLen, damage: Byte; saveType: ShortInt; bounce, trace: Boolean; var cells: Types.TCellList);
  forward;

function SpellSelection(selType: Byte; var idx: Integer): Byte;
var
  sel: Types.PItemRec;
  p: Types.PItemRec;
  prompt: Types.TStr40;
  title: Types.TStr40;
  pad: Byte;
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
    p := GDVars.spellList;
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
                                bottomRow, GDVars.spellList, addExit, redraw, idx, sel);
  until ch in [C_Keys.NONE, C_Keys.ENTER, 'C', 'E', 'L', 'M', 'S'];
  p := GDVars.spellList;
  count := 0;
  while p <> sel do begin
    if p^.inUse = 0 then
      Inc(count);
    p := p^.next;
  end;
  GDVars.castScroll := nil;
  if (ch in [C_Keys.NONE, 'E']) or (count > C_Spell.LINE_LAST) then
    SpellSelection := C_Spell.NONE
  else begin
    SpellSelection := GDVars.spellIds[count];
    GDVars.castScroll := GDVars.spellScrolls[count];
  end;
  if selType = 3 then
    { 48 = High(scrollPtrs) }
    if count <= 48 then
      GDVars.dsCurrentScrollPtr := GDVars.scrollPtrs[count]
    else
      GDVars.dsCurrentScrollPtr := nil;
  MenuCore.FreeStringList(GDVars.spellList);
end;

{ Append spell to spellList, first adding a level heading entry (inUse = 1) when its spell level differs from the
  previous spell's. Bit 7 set (pending memorization or scribing) prefixes ' *'; otherwise the second column holds
  SpellMark's character for mark (MARK_NONE, MARK_KNOWN or MARK_NOT_KNOWN). Stores spell and $7F in spellIds at the
  entry's selectable index. }
procedure AddSpellToList(spell, mark: Byte);
var
  p: Types.PItemRec;
  count: ShortInt;
  lastLevel: ShortInt;
begin
  p := GDVars.spellList;
  if GDVars.spellList = nil then begin
    { Allocate only a TMenuNode, the TItemRec prefix a MenuCore.MenuVertical entry uses (name, inUse and next); the rest
      of the record is never touched }
    GetMem(p, SizeOf(Types.TMenuNode));
    GDVars.spellList := p;
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
    lastLevel := GDConsts.spellTable[GDVars.spellIds[count - 1]].levelSp;
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
    p^.name := ' ' + Magic.SpellMark(spell, mark);
  p^.name := p^.name + GDConsts.spellNames[spell and C_Spell.ID_MASK];
  p^.inUse := 0;
  GDVars.spellIds[count] := spell and C_Spell.ID_MASK;
end;

{ The indent-column marker for spell (bit 7 ignored) on a spell list, otherwise a blank: KNOWN_MARK for MARK_KNOWN when
  curChar's spell book has it; NOT_KNOWN_MARK for MARK_NOT_KNOWN when the spell book lacks a spell curChar's classes
  could learn. A class could learn a spell of its own (castClass 0 needs a cleric level, castClass 1 a magic-user level)
  at spell level 1..3, the levels a character has slots for, whatever the character's current level. An ID outside the
  spell book (1..56) gets a blank. }
function SpellMark(spell, mark: Byte): Char;
var
  id: Byte;
  learnable: Boolean;
begin
  SpellMark := ' ';
  id := spell and C_Spell.ID_MASK;
  if (id >= 1) and (id <= SizeOf(GDVars.curChar^.spellsKnown)) then
    case mark of
      MARK_KNOWN:
        if GDVars.curChar^.spellsKnown[id] <> 0 then
          SpellMark := KNOWN_MARK;
      MARK_NOT_KNOWN:
        if GDVars.curChar^.spellsKnown[id] = 0 then begin
          learnable := False;
          with GDConsts.spellTable[id] do
            if (levelSp >= 1) and (levelSp <= 3) then
              case castClassSp of
                0: learnable := GDVars.curChar^.classLevels[C_Class.LEVEL_CLERIC] > 0;
                1: learnable := GDVars.curChar^.classLevels[C_Class.LEVEL_MAGE] > 0;
              end;
          if learnable then
            SpellMark := NOT_KNOWN_MARK;
        end;
    end;
end;

{ Add dsCurrentScrollPtr's spells to the list (forScribe: only those queued for scribing, id > $80), each with mark,
  and record the scroll in scrollPtrs for each while scrollPtrs has room. Read Magic (effect 16), or any cleric level
  with a scroll whose base item slot is 12, identifies the scroll first; an unidentified scroll adds nothing. }
procedure AddScrollSpells(forScribe: Boolean; mark: Byte);
var
  i: Byte;
begin
  if Magic.ScrollLegible(GDVars.curChar, GDVars.dsCurrentScrollPtr) then
    { 3 = High(TItemRec.spells) }
    for i := 1 to 3 do begin
      if (forScribe and (GDVars.dsCurrentScrollPtr^.spells[i] > C_Spell.PENDING_FLAG)) or
          (not forScribe and (GDVars.dsCurrentScrollPtr^.spells[i] > 0)) then begin
        Magic.AddSpellToList(GDVars.dsCurrentScrollPtr^.spells[i], mark);
        { 48 = High(scrollPtrs) }
        if GDVars.scrollCount <= 48 then begin
          GDVars.scrollPtrs[GDVars.scrollCount] := GDVars.dsCurrentScrollPtr;
          Inc(GDVars.scrollCount);
        end;
      end;
    end;
end;

{ Walk curChar's inventory: each readable item becomes dsCurrentScrollPtr and feeds AddScrollSpells with forScribe and
  mark. dsCurrentScrollPtr itself is the loop variable, so it ends as nil. }
procedure AddAllScrollSpells(forScribe: Boolean; mark: Byte);
begin
  GDVars.dsCurrentScrollPtr := GDVars.curChar^.itemsAddr;
  while GDVars.dsCurrentScrollPtr <> nil do begin
    if Magic.ItemReadable(GDVars.dsCurrentScrollPtr) then
      Magic.AddScrollSpells(forScribe, mark);
    GDVars.dsCurrentScrollPtr := GDVars.dsCurrentScrollPtr^.next;
  end;
end;

function CastableScroll(creature: Types.PCharRecord; item: Types.PItemRec): Boolean;
begin
  CastableScroll := False;
  if Magic.ItemReadable(item) then
    if (item^.equipped <> 0) or (CharHlp.BaseItem(item^.itemType)^.classMask and creature^.itemLimits <> 0) then
      CastableScroll := Magic.ScrollLegible(creature, item);
end;

{ The spell in item's spell slot (1..3), bit 7 ignored, or C_Spell.NONE when the slot is out of range or holds no
  spell. }
function ScrollSpellAt(item: Types.PItemRec; slot: Byte): Byte;
var
  id: Byte;
begin
  ScrollSpellAt := C_Spell.NONE;
  if (slot >= 1) and (slot <= SizeOf(item^.spells)) then begin
    id := item^.spells[slot] and C_Spell.ID_MASK;
    if (id >= 1) and (id <= C_Spell.LAST) then
      ScrollSpellAt := id;
  end;
end;

{ Add the spell in item's slot to the Cast list as line number lines, with item in spellScrolls, and count the line.
  SCROLL_MARK goes in the indent column before the name, in place of the '*' a spell queued for scribing gets. Nothing
  is added once the list is full. }
procedure AddScrollLine(item: Types.PItemRec; slot: Byte; var lines: Byte);
var
  p: Types.PItemRec;
begin
  if lines <= C_Spell.LINE_LAST then begin
    Magic.AddSpellToList(item^.spells[slot], MARK_NONE);
    GDVars.spellScrolls[lines] := item;
    Inc(lines);
    p := GDVars.spellList;
    while p^.next <> nil do
      p := p^.next;
    if Length(p^.name) >= 2 then
      p^.name[2] := SCROLL_MARK;
  end;
end;

{ The Cast list, level by level: curChar's memorized spells (not those still being memorized), then a line for each
  spell on each scroll curChar can read and use (CastableScroll), in inventory order, marked with SCROLL_MARK. In
  combat the memorized spells need castAllowed, as the Cast command does, and the scroll spells CharHlp.CanUseItems, as
  Use does. }
procedure AddAvailableSpells;
var
  lvl: Byte;
  i: Byte;
  id: Byte;
  lines: Byte;
  memOk: Boolean;
  scrollOk: Boolean;
  item: Types.PItemRec;
begin
  memOk := (GDVars.ifcState <> C_Ifc.COMBAT) or (GDVars.curChar^.combatAddr^.castAllowed <> 0);
  scrollOk := CharHlp.CanUseItems(GDVars.curChar);
  lines := 0;
  for lvl := 1 to SPELL_LEVEL_LAST do begin
    if memOk then
      for i := 0 to SizeOf(GDVars.curChar^.memorizedSpells) - 1 do begin
        id := GDVars.curChar^.memorizedSpells[i];
        if (id >= 1) and (id <= C_Spell.LAST) then
          if (GDConsts.spellTable[id].levelSp = lvl) and (lines <= C_Spell.LINE_LAST) then begin
            Magic.AddSpellToList(id, MARK_NONE);
            Inc(lines);
          end;
      end;
    if scrollOk then begin
      item := GDVars.curChar^.itemsAddr;
      while item <> nil do begin
        if Magic.CastableScroll(GDVars.curChar, item) then
          for i := 1 to SizeOf(item^.spells) do begin
            id := Magic.ScrollSpellAt(item, i);
            if id <> C_Spell.NONE then
              if GDConsts.spellTable[id].levelSp = lvl then
                Magic.AddScrollLine(item, i, lines);
          end;
        item := item^.next;
      end;
    end;
  end;
end;

function GenerateSpellList(menuType: Byte): Boolean;
var
  i: Byte;
  p: Types.PItemRec;
begin
  GenerateSpellList := False;
  GDVars.spellList := nil;
  for i := 0 to C_Spell.LINE_LAST do begin
    GDVars.spellIds[i] := 0;
    GDVars.spellScrolls[i] := nil;
  end;
  { every list starts with no scrolls recorded: High(scrollPtrs), 49 slots }
  for i := 0 to 48 do
    GDVars.scrollPtrs[i] := nil;
  GDVars.scrollCount := 0;
  case menuType of
    7: Magic.AddAvailableSpells;
    { High(memorizedSpells) }
    0: for i := 0 to 20 do
         if (GDVars.curChar^.memorizedSpells[i] > 0) and
             (GDVars.curChar^.memorizedSpells[i] < C_Spell.PENDING_FLAG) then
           Magic.AddSpellToList(GDVars.curChar^.memorizedSpells[i], MARK_NONE);
    { High(memorizedSpells) }
    5: for i := 0 to 20 do
         if GDVars.curChar^.memorizedSpells[i] > C_Spell.ID_MASK then
           Magic.AddSpellToList(GDVars.curChar^.memorizedSpells[i], MARK_NONE);
    { Note: 55 stops one short of High(spellsKnown) = 56 (Restoration), so the spell book never lists Restoration }
    1: for i := 1 to 55 do
         if GDVars.curChar^.spellsKnown[i] <> 0 then
           Magic.AddSpellToList(i, MARK_NONE);
    { one scroll's list marks the spells the character could learn but does not know }
    2: Magic.AddScrollSpells(False, MARK_NOT_KNOWN);
    { the scribe list marks the spells the character already knows }
    3: Magic.AddAllScrollSpells(False, MARK_KNOWN);
    6: Magic.AddAllScrollSpells(True, MARK_NONE);
    { only spells inside slots[0..1, 1..3]: Restoration (spell 56, level 7) would read slots[0, 7], xpAward's low byte }
    4: for i := 1 to 56 do
         with GDConsts.spellTable[i] do
           if (castClassSp >= 0) and (castClassSp <= 1) and (levelSp >= 1) and (levelSp <= 3) then
             if (GDVars.curChar^.slots[castClassSp, levelSp] > 0) and (GDVars.curChar^.spellsKnown[i] = 0) then
               Magic.AddSpellToList(i, MARK_NONE);
  end;
  { a list of headings alone has nothing to pick: it counts as empty }
  p := GDVars.spellList;
  while (p <> nil) and (p^.inUse <> 0) do
    p := p^.next;
  if p <> nil then
    GenerateSpellList := True
  else if GDVars.spellList <> nil then begin
    MenuCore.FreeStringList(GDVars.spellList);
    GDVars.spellList := nil;
  end;
end;

function CalcSpellRange(spell: Byte): Byte;
var
  r: Byte;
begin
  if GDVars.usingItem = False then
    r := GDConsts.spellTable[spell].rangeFixed + GDConsts.spellTable[spell].rangeVar * CharHlp.GetCasterLevel(spell)
  else
    r := GDConsts.spellTable[spell].rangeVar * 6 + GDConsts.spellTable[spell].rangeFixed;
  { Touch: zero range with an area }
  if (r = 0) and (GDConsts.spellTable[spell].area <> 0) then
    r := 1;
  { A range of 255 marks an attack-roll spell }
  if r = 255 then
    r := 1;
  CalcSpellRange := r;
end;

{ Spell duration in minutes: durFixed + durVar * caster level, except for the item spells below with their own rolls }
function CalcSpellDuration(spell: Byte): Word;
var
  d: Word;
begin
  case spell of
    { Cause Disease }
    40: d := FxEngine.RollDice(1, 6) * 10;
    { Potion of Speed, Wand of Paralyzation }
    57, 61: d := FxEngine.RollDice(5, 4);
    { Giant Strength }
    59: d := FxEngine.RollDice(1, 4) * 10 + 40;
    { Dust of Disappearance }
    63: if GDVars.ifcState = C_Ifc.COMBAT then
                d := FxEngine.RollDice(2, 10) * 10
              else
                d := (FxEngine.RollDice(1, 10) + 10) * 10;
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
var
  pad: Pointer;
begin
  if GDVars.castTarget = nil then
    GDVars.castTarget := GDVars.curChar;
  GDVars.dsTargetCreaturePtr[1] := GDVars.curChar;
  GDVars.spellTargetCount := 1;
  cast := True;
  case GDConsts.spellTable[spell].target of
    1: ;
    2: begin
         CharHlp.DisplayNoncombatInterface;
         CharHlp.SelectChar('Cast Spell on whom', True, GDVars.castTarget);
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
  pad: Byte;
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
    castUI(spell, b, sel);
    if sel then begin
      ok := False;
      if GDVars.ifcState = C_Ifc.COMBAT then begin
        CharHlp.BuildIconFacings(18);
        x := CbtMap.CombatCellX(p);
        y := CbtMap.CombatCellY(p);
        k := 0;
        while not Pathing.IsDirToward(x, y, GDVars.gTargetX, GDVars.gTargetY, k) do
          Inc(k);
        CbtMap.SetCreatureFacing(p, k, 1, 0);
        SoundDrv.SoundSetAutoStop(0);
        case spell of
          { Fireball: 11 }
          47: SoundDrv.SoundCommand(soundIds[12]);
          { Lightning: 8 }
          51: SoundDrv.SoundCommand(soundIds[9]);
        else
          { default: 2 }
          SoundDrv.SoundCommand(soundIds[3]);
        end;
        CharHlp.CombatAnimateMovingIcon(x, y, GDVars.gTargetX, GDVars.gTargetY, 4, 30);
        SoundDrv.SoundSetAutoStop(10);
        if CbtMap.CombatIconVisible(p, 0) then begin
          CbtMap.SetCreatureFacing(p, p^.combatAddr^.direction, 1, 1);
          CbtMap.SetCreatureFacing(p, p^.combatAddr^.direction, 0, 0);
        end;
      end;
      FxEngine.RemoveInvisibility(p);
      if GDVars.usingItem = False then
        CharHlp.RemoveSpell(GDVars.curChar, spell);
      GDVars.dsCurrentSpellBeing := spell;
      spellFns[GDVars.dsCurrentSpellBeing];
      GDVars.dsCurrentSpellBeing := C_Spell.NONE;
      GDVars.gMultiTarget := 0;
    end else begin
      if GDVars.ifcState <> C_Ifc.COMBAT then
        ok := False
      else if b or (MenuCore.YesNoMenu('Abort Spell? ', Yellow, LightGreen, White) = 'Y') then
      begin
        CharHlp.PrintBottomLine('Spell Aborted');
        if GDVars.usingItem = False then
          CharHlp.RemoveSpell(GDVars.curChar, spell);
        ok := False;
      end;
    end;
  end;
  CharHlp.ClearMessageWindow;
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
        ((GDVars.dsCurrentSpellBeing = 1) and (GDVars.ifcState = C_Ifc.COMBAT) and
         (CharHlp.CountTargets(GDVars.dsTargetCreaturePtr[i], 1) > 0)) then
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
  if FxEngine.RestoreHitPoints(GDVars.dsTargetCreaturePtr[1], FxEngine.RollDice(1, 8), False) then
    CharHlp.PrintHpRestoreMsg(GDVars.dsTargetCreaturePtr[1]);
end;

{ Cause Light Wounds: 1d8 damage, element mask 8. }
procedure CauseLightWoundsHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, FxEngine.RollDamageDice(1, 8), 8, '');
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
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, CharHlp.GetCasterLevel(GDVars.dsCurrentSpellBeing), 9,
                      '');
end;

{ Charm Person: only targets with charType 0..1 and icon size 1 can be charmed. The Charm effect's strength is the
  caster's hostile * 128 + caster level; afterwards the target's first Charm effect (normally the one just added) has
  its handler called with removed = False. }
procedure CharmPersonHandler;
var
  effect: Types.PEffectRec;
  tgt: Types.PCharRecord;
begin
  tgt := GDVars.dsTargetCreaturePtr[1];
  if (tgt^.charType > 1) or (tgt^.iconDimensions > 1) then
    CharHlp.PrintNameString(tgt, 'is unaffected', 10, True)
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
  enc: Byte;
  lvl: Byte;
begin
  { Strength 18 with exceptional Strength 0, 1, 51, 76, 91 or 100 for caster levels 1..6; 100 above 6, 0 for level 0 }
  GDVars.gSpellTemp1 := 18;
  lvl := CharHlp.GetCasterLevel(GDVars.dsCurrentSpellBeing);
  case lvl of
    1: GDVars.gSpellTemp2 := 0;
    2: GDVars.gSpellTemp2 := 1;
    3: GDVars.gSpellTemp2 := 51;
    4: GDVars.gSpellTemp2 := 76;
    5: GDVars.gSpellTemp2 := 91;
    6: GDVars.gSpellTemp2 := 100;
  else
    if lvl > 6 then
      GDVars.gSpellTemp2 := 100
    else
      GDVars.gSpellTemp2 := 0;
  end;
  if FxEngine.AdjustForNewStrength(GDVars.dsTargetCreaturePtr[1], GDVars.gSpellTemp1, GDVars.gSpellTemp2, enc) then
    CharHlp.PrintNameString(GDVars.dsTargetCreaturePtr[1], 'is stronger', 10, True);
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
        CharHlp.PrintNameString(GDVars.dsTargetCreaturePtr[1], 'has been reduced', 10, True);
end;

{ Friends: +2d4 Charisma, capped at 25; the effect's strength is the old Charisma, restored on removal }
procedure FriendsHandler;
var
  oldCha: Byte;
begin
  oldCha := GDVars.dsTargetCreaturePtr[1]^.chaCur;
  Inc(GDVars.dsTargetCreaturePtr[1]^.chaCur, FxEngine.RollDice(2, 4));
  { 25, the Cha cap }
  if GDVars.dsTargetCreaturePtr[1]^.chaCur > 25 then
    GDVars.dsTargetCreaturePtr[1]^.chaCur := 25;
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, oldCha, True, 0, 0, 'is friendly');
end;

{ Magic Missile: (caster level div 2)d4 + caster level div 2 damage, element mask 8. }
procedure MagicMissileHandler;
var
  cl: Byte;
begin
  cl := CharHlp.GetCasterLevel(GDVars.dsCurrentSpellBeing);
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, cl div 2 + FxEngine.RollDamageDice(cl div 2, 4), 8, '');
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
                      FxEngine.RollDamageDice(1, 8) + CharHlp.GetCasterLevel(GDVars.dsCurrentSpellBeing), $C, '');
end;

{ Sleep: a 4d4 hit-dice pool. Cost per target by levelHighest: 0..1 -> 1, 2 -> 2, 3 -> 4, 4 -> 6, 5 -> 10 for
  C_Race.MONSTER and 20 otherwise, higher -> 20. Animated dead (C_Status.ANIMATED), targets already asleep (effect 53)
  and targets the remaining pool cannot pay for are dropped; the pool is spent greedily in target order. }
procedure SleepHandler;
var
  i: Byte;
  effect: Types.PEffectRec;
begin
  GDVars.gMultiTarget := 1;
  GDVars.gSpellTemp1 := FxEngine.RollDice(4, 4);
  for i := 1 to GDVars.spellTargetCount do begin
    case GDVars.dsTargetCreaturePtr[i]^.levelHighest of
      0..1: GDVars.gSpellTemp2 := 1;
      2: GDVars.gSpellTemp2 := 2;
      3: GDVars.gSpellTemp2 := 4;
      4: GDVars.gSpellTemp2 := 6;
      5: if GDVars.dsTargetCreaturePtr[i]^.race = C_Race.MONSTER then
              GDVars.gSpellTemp2 := 10
            else
              GDVars.gSpellTemp2 := 20;
    else
      GDVars.gSpellTemp2 := 20;
    end;
    if (GDVars.dsTargetCreaturePtr[i]^.status <> C_Status.ANIMATED) and
        (not CharHlp.HasEffect(GDVars.dsTargetCreaturePtr[i], C_Effect.SLEEP, effect)) and
        (GDVars.gSpellTemp1 >= GDVars.gSpellTemp2) then
      Dec(GDVars.gSpellTemp1, GDVars.gSpellTemp2)
    else
      GDVars.dsTargetCreaturePtr[i] := nil;
  end;
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, 0, 0, 'falls asleep');
end;

{ Hold Person (spells 23 and 49): save modifier -2 (cleric) or -3 (mage) for one target, -1 for two, 0 for three or
  more. Targets are processed in reverse; each one after the first processed (i < spellTargetCount) gets its own
  projectile animation. Targets with charType > 1 or icon size > 1 always save. }
procedure HoldPersonHandler;
var
  tgt: Types.PCharRecord;
  saved: Boolean;
  i: Byte;
  smod: ShortInt;
begin
  case GDVars.spellTargetCount of
    1: if GDVars.dsCurrentSpellBeing = 23 then
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
        SoundDrv.SoundCommand(soundIds[3]);
        CharHlp.BuildIconFacings(18);
        CharHlp.CombatAnimateMovingIcon(CbtMap.CombatCellX(GDVars.curChar), CbtMap.CombatCellY(GDVars.curChar),
                                        CbtMap.CombatCellX(tgt), CbtMap.CombatCellY(tgt), 4, 30);
        SoundDrv.SoundSetAutoStop(10);
      end;
      saved := FxEngine.RollSavingThrow(tgt, GDConsts.spellTable[GDVars.dsCurrentSpellBeing].saveType, smod);
      if (tgt^.charType > 1) or (tgt^.iconDimensions > 1) then
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

{ Slow Poison: animated dead are skipped. A poisoned target (effect 55) has hpCur raised to at least 1, gets the spell's
  effect at strength 255, gets back up through FxEngine.ReviveDeadCreature (or, where it cannot stand yet, a minute
  later through C_Effect.HEAL_WAKE, as under Keoghtom's Ointment), and gains effect 15 for 10 minutes at strength
  255. }
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
    if not FxEngine.ReviveDeadCreature(tgt, tgt^.hpCur) then
      FxEngine.AddEffect(tgt, C_Effect.HEAL_WAKE, 1, 0, True);
    FxEngine.AddEffect(tgt, C_Effect.SLOW_POISON_HIT, 10, 255, True);
  end;
end;

{ Snake Charm: rebuild the target list from GDVars.creatureList: snakes whose hpCur still fits in a pool equal to the
  caster's hpCur, paid in list order }
procedure SnakeCharmHandler;
var
  p: Types.PCharRecord;
begin
  GDVars.gSpellTemp1 := GDVars.curChar^.hpCur;
  GDVars.spellTargetCount := 0;
  p := GDVars.creatureList;
  while p <> nil do begin
    { charType 14: snake }
    if p^.charType = 14 then
      if GDVars.gSpellTemp1 >= p^.hpCur then begin
        GDVars.gSpellTemp1 := GDVars.gSpellTemp1 - p^.hpCur;
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
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, FxEngine.RollDice(1, 4), False, 0, 0, 'is duplicated');
end;

{ Ray of Enfeeblement: apply the spell's effect. }
procedure RayOfEnfeeblementHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, 0, 0, 'is weakened');
end;

{ Stinking Cloud: append a node to the stinkHead list and give the caster effect 40 for caster-level minutes at strength
  caster level + myClouds * 16, where myClouds counts the caster's clouds among the nodes passed while walking to the
  tail (the old tail node itself is not checked). The cloud covers the 2x2 block whose upper-left is the aim cell
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
  myClouds := 0;
  node := GDVars.stinkHead;
  if GDVars.stinkHead = nil then begin
    GetMem(GDVars.stinkHead, SizeOf(Types.TStinkRec));
    node := GDVars.stinkHead;
  end else begin
    while node^.next <> nil do begin
      if node^.caster = GDVars.curChar then
        Inc(myClouds);
      node := node^.next;
    end;
    GetMem(node^.next, SizeOf(Types.TStinkRec));
    node := node^.next;
  end;
  FillChar(node^, SizeOf(Types.TStinkRec), 0);
  FxEngine.AddEffect(GDVars.curChar, C_Effect.CAST_STINK, cl, cl + myClouds * 16, True);
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
  CharHlp.PrintNameString(GDVars.curChar, 'Creates a noxious cloud', 10, False);
  CbtMap.ScrollView(GDVars.gTargetX, GDVars.gTargetY, 255, C_Dir.CENTER);
  TextRend.PauseOnly;
  CharHlp.ClearMessageWindow;
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
  if tgt^.classLevels[C_Class.LEVEL_MAGE] > 0 then
    roll := FxEngine.RollDice(1, 4);
  if (tgt^.classLevels[C_Class.LEVEL_CLERIC] > 0) or (tgt^.classLevels[C_Class.LEVEL_THIEF] > 0) then
    roll := FxEngine.RollDice(1, 6);
  if CharHlp.WarriorLevel(tgt) > 0 then
    roll := FxEngine.RollDice(1, 8);
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
    CharHlp.PrintNameString(tgt, 'is stronger', 10, True);
  FxEngine.AddEffect(tgt, C_Effect.STRENGTH, Magic.CalcSpellDuration(GDVars.dsCurrentSpellBeing), enc, True);
end;

{ Animate Dead: animate up to caster-level dead (C_Status.DEAD) human (charType 0) creatures whose cell is still a valid
  location. Effect 32's strength is the old hostile * 16 + caster level. Each corpse joins the caster's team under
  computer control (quickfight 1), becomes undead (charType 4, levelUndead 2, movementBase 6, attackLevel 0), loses its
  memorized spells and gets the animated NPC or PC npc code; if ReviveDeadCreature succeeds at full hpMax it also gets
  effect 32 and C_Status.ANIMATED. }
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
          strength := p^.hostile * 16 + CharHlp.GetCasterLevel(GDVars.dsCurrentSpellBeing);
          p^.hostile := GDVars.curChar^.hostile;
          p^.quickfight := 1;
          p^.levelUndead := 2;
          p^.attackLevel := 0;
          p^.movementBase := 6;
          { High(memorizedSpells) }
          for i := 0 to 20 do
            p^.memorizedSpells[i] := 0;
          { C_Npc.FLAG set }
          if p^.npc > $7F then
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
    CharHlp.PrintNameStringAnim(GDVars.dsTargetCreaturePtr[1], True, 'can see');
end;

{ Cause Blindness: apply the spell's effect. }
procedure CauseBlindnessHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, 0, 0, 'is blind');
end;

{ Remove disease from dsTargetCreaturePtr[1] with effectLock held: Diseased, the Strength-draining disease (also
  dropping its hit-point and helpless effects) and rot (also dropping mummy rot). Returns True if any of the three was
  present. }
function RemoveDiseaseEffects: Boolean;
begin
  RemoveDiseaseEffects := False;
  GDVars.effectLock := 1;
  if FxEngine.RemoveEffectWithMessage(GDVars.dsTargetCreaturePtr[1], C_Effect.DISEASED) then
    RemoveDiseaseEffects := True;
  if FxEngine.RemoveEffectWithMessage(GDVars.dsTargetCreaturePtr[1], C_Effect.DISEASE_STR) then begin
    RemoveDiseaseEffects := True;
    FxEngine.RemoveEffect(GDVars.dsTargetCreaturePtr[1], C_Effect.DISEASE_HP, nil);
    FxEngine.RemoveEffect(GDVars.dsTargetCreaturePtr[1], C_Effect.HELPLESS, nil);
  end;
  if FxEngine.RemoveEffectWithMessage(GDVars.dsTargetCreaturePtr[1], C_Effect.ROT_NO_HEAL) then begin
    RemoveDiseaseEffects := True;
    FxEngine.RemoveEffect(GDVars.dsTargetCreaturePtr[1], C_Effect.MUMMY_ROT, nil);
  end;
  GDVars.effectLock := 0;
end;

{ Cure Disease: remove the first target's disease effects. }
procedure CureDiseaseHandler;
var
  junk: Boolean;
begin
  junk := Magic.RemoveDiseaseEffects;
end;

{ Cause Disease: apply the spell's effect. }
procedure CauseDiseaseHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, True, 0, 0, 'is diseased');
end;

{ Dispel Magic: on each target, try every effect whose strength is below 255, with its low nibble as the effect's caster
  level: 50%, +5% per caster level above it, -2% per level below. A paladin's lay-on-hands and cure-disease timers are
  left alone. }
procedure DispelMagicHandler;
var
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
    { 72 = High(dsTargetCreaturePtr) }
    if i <= 72 then
      tgt := GDVars.dsTargetCreaturePtr[i]
    else
      tgt := nil;
    if tgt <> nil then
      effect := Types.PEffectRec(tgt^.effectsAddr)
    else
      effect := nil;
    while effect <> nil do begin
      nxt := effect^.next;
      if (effect^.strength < 255) and not (effect^.id in [C_Effect.RECENT_HEAL, C_Effect.RECENT_CURE]) then begin
        { dispel treats the low nibble as caster level }
        GDVars.gSpellTemp2 := effect^.strength and $F;
        if cl > GDVars.gSpellTemp2 then
          GDVars.gSpellTemp1 := (cl - GDVars.gSpellTemp2) * 5 + 50
        else if cl < GDVars.gSpellTemp2 then
          GDVars.gSpellTemp1 := 50 - (GDVars.gSpellTemp2 - cl) * 2
        else
          GDVars.gSpellTemp1 := 50;
        if FxEngine.RollDice(1, 100) <= GDVars.gSpellTemp1 then begin
          FxEngine.RemoveEffect(tgt, effect^.id, effect);
          removed := True;
        end;
      end;
      effect := nxt;
    end;
    if removed then
      CharHlp.PrintNameStringAnim(tgt, True, 'is affected');
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
    CharHlp.PrintNameStringAnim(GDVars.dsTargetCreaturePtr[1], True, 'is un-cursed')
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
      CharHlp.PrintNameStringAnim(GDVars.dsTargetCreaturePtr[1], True, '''s item is un-cursed');
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
  with Pathing.BuildTargetList, radius 2 around the aim cell. Damage is level d6, element mask 9. }
procedure FireballHandler;
var
  cl: Byte;
  i: Byte;
begin
  GDVars.gMultiTarget := 1;
  if GDVars.dsCurrentSpellBeing = 64 then
    cl := FxEngine.RollDice(1, 3) * 2 + 1
  else
    cl := CharHlp.GetCasterLevel(GDVars.dsCurrentSpellBeing);
  if GDVars.zone0^.view3dFlag = 0 then begin
    Pathing.BuildTargetList(GDVars.gTargetX, GDVars.gTargetY, 2, 255, 1, GDVars.arenaPtr);
    for i := 1 to GDVars.targetCount do
      GDVars.dsTargetCreaturePtr[i] := GDVars.creatureArr[GDVars.targetList[i].idx];
    GDVars.spellTargetCount := GDVars.targetCount;
  end;
  CbtMap.ScrollView(GDVars.gTargetX, GDVars.gTargetY, 0, C_Dir.CENTER);
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, FxEngine.RollDamageDice(cl, 6), 9, '');
end;

{ Haste and Slow: keep up to caster-level targets on team hostFlag and drop the rest. A kept target carrying removeId,
  the opposing Slowed or Hasted effect, just loses it; the others get the spell's effect and have their
  C_Cond.MOVE_ATTACK_RATE effects re-run. }
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
    if GDVars.dsTargetCreaturePtr[i] <> nil then
      FxEngine.TriggerEffectsWithCondition(C_Cond.MOVE_ATTACK_RATE, GDVars.dsTargetCreaturePtr[i]);
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
  pad: Word;
begin
  blocked := False;
  CbtMap.GetArenaContents(x, y, crIdx, terr);
  if terr > 0 then
    if GDConsts.terrainInfo[terr].cost = 255 then
      blocked := True;
  if crIdx > 0 then begin
    tgt := GDVars.creatureArr[crIdx];
    GDVars.elementMask := $C;
    FxEngine.InflictNonWeaponDamage(tgt, damage, 2, FxEngine.RollSavingThrow(tgt, saveType, 0));
    CharHlp.BuildIconFacings(19);
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
    CharHlp.BuildIconFacings(19);
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
        CharHlp.CombatAnimateMovingIcon(prevX, prevY, req.cx, req.cy, 4, 50);
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
  dmg := FxEngine.RollDice(CharHlp.GetCasterLevel(GDVars.dsCurrentSpellBeing), 6);
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
    { 7 = High(classLevels) }
    for cls := 0 to 7 do begin
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
    CharHlp.PrintNameString(tgt, 'is restored', 10, True);
  end;
end;

{ Potion of Speed: remove Slowed, or else apply the potion's effect. }
procedure PotionOfSpeedHandler;
begin
  if not FxEngine.RemoveEffectWithMessage(GDVars.dsTargetCreaturePtr[1], C_Effect.SLOWED) then
    Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, 0, 0, 'is Speedy');
end;

{ Keoghtom's Ointment: cure poison (also removing effect 22 silently), else cure disease, else heal 1d4 + 8. Poison
  kills on the spot, so a target the poison left dead gets back up with at least 1 hp, as under Slow Poison; where it
  cannot stand yet (another creature on its cell) it gets up a minute later through C_Effect.HEAL_WAKE. A dead target
  still under Slow Poison was kept up through the poison and died of something else (a wound, bleeding out), so it
  stays dead, as at the temple (Temple.NeutralizePoison). }
procedure KeoghtomsOintmentHandler;
var
  pad: Byte;
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
      if not FxEngine.ReviveDeadCreature(tgt, tgt^.hpCur) then
        FxEngine.AddEffect(tgt, C_Effect.HEAL_WAKE, 1, 0, True);
    end;
  end else if not Magic.RemoveDiseaseEffects then begin
    if FxEngine.RestoreHitPoints(GDVars.dsTargetCreaturePtr[1], FxEngine.RollDice(1, 4) + 8, False) then
      CharHlp.PrintNameStringAnim(GDVars.dsTargetCreaturePtr[1], True, 'is Healed');
  end;
end;

{ Giant Strength: raise Strength to 21 and add the Strength effect, which keeps the Strength encoding
  AdjustForNewStrength returns. }
procedure GiantStrengthHandler;
var
  enc: Byte;
begin
  if FxEngine.AdjustForNewStrength(GDVars.dsTargetCreaturePtr[1], 21, 0, enc) then
    CharHlp.PrintNameString(GDVars.dsTargetCreaturePtr[1], 'is stronger', 10, True);
  FxEngine.AddEffect(GDVars.dsTargetCreaturePtr[1], C_Effect.STRENGTH,
                     Magic.CalcSpellDuration(GDVars.dsCurrentSpellBeing), enc, True);
end;

{ Javelin of Lightning: 1d6 + 20 damage at the aim cell, then a 3-cell bolt of 20 damage. }
procedure JavelinOfLightningHandler;
var
  junk: Boolean;
begin
  Magic.LightningAttackAt(GDVars.gTargetX, GDVars.gTargetY, FxEngine.RollDice(1, 6) + 20, C_Save.SPELL, junk);
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
  if FxEngine.RestoreHitPoints(GDVars.dsTargetCreaturePtr[1], FxEngine.RollDice(2, 4) + 2, False) then
    CharHlp.PrintNameStringAnim(GDVars.dsTargetCreaturePtr[1], True, 'is Healed');
end;

{ Dust of Disappearance: apply the item's effect. }
procedure DustDisappearanceHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, 0, 0, 'is invisible');
end;

{ Wand of Magic Missiles: 2d4 + 2 damage, element mask 8. }
procedure WandMagicMissilesHandler;
begin
  Magic.ResolveSpell(GDVars.dsCurrentSpellBeing, 0, False, FxEngine.RollDamageDice(2, 4) + 2, 8, '');
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
    if FxEngine.RollDice(1, 100) <= 50 then
      Exit;
  x := CbtMap.CombatCellX(creature);
  y := CbtMap.CombatCellY(creature);
  CharHlp.PrintNameString(creature, 'Breathes!', 10, True);
  castUI(51, True, GDVars.breathAim);
  GDVars.gTargetX := x + Pathing.SignOf(GDVars.gTargetX - x);
  GDVars.gTargetY := y + Pathing.SignOf(GDVars.gTargetY - y);
  if GDVars.gTargetX = x + 1 then
    Inc(GDVars.gTargetX);
  if GDVars.gTargetY = y + 1 then
    Inc(GDVars.gTargetY);
  FxEngine.RemoveInvisibility(creature);
  CharHlp.BuildIconFacings(19);
  CharHlp.CombatAnimateMovingIcon(x, y, GDVars.gTargetX, GDVars.gTargetY, 4, 50);
  Magic.LightningAttackAt(GDVars.gTargetX, GDVars.gTargetY, creature^.hpMax, C_Save.BREATH, junk);
  Magic.LightningPath(10, creature^.hpMax, C_Save.BREATH, False);
  { Remaining breath charges }
  if Types.PEffectRec(p)^.strength > 253 then
    Dec(Types.PEffectRec(p)^.strength)
  else
    FxEngine.RemoveEffect(creature, C_Effect.DRAGON_BREATH, p);
  junk := CharHlp.EndActions(creature);
end;

function ItemReadable(it: Pointer): Boolean;
begin
  if (it <> nil) and (CharHlp.BaseItem(Types.PItemRec(it)^.itemType)^.slot > 10) and
      (CharHlp.BaseItem(Types.PItemRec(it)^.itemType)^.slot < 14) then
    ItemReadable := True
  else
    ItemReadable := False;
end;

function ScrollLegible(creature: Types.PCharRecord; item: Types.PItemRec): Boolean;
var
  effect: Types.PEffectRec;
begin
  if CharHlp.HasEffect(creature, C_Effect.READ_MAGIC, effect) or
      ((creature^.classLevels[C_Class.LEVEL_CLERIC] > 0) and (CharHlp.BaseItem(item^.itemType)^.slot = 12)) then
    item^.unidMask := 0;
  ScrollLegible := item^.unidMask = 0;
end;

function HasScrollSpells(creature: Types.PCharRecord): Boolean;
var
  item: Types.PItemRec;
  i: Byte;
  found: Boolean;
begin
  found := False;
  if CharHlp.CanUseItems(creature) then begin
    item := creature^.itemsAddr;
    while (item <> nil) and not found do begin
      if Magic.CastableScroll(creature, item) then
        for i := 1 to SizeOf(item^.spells) do
          if Magic.ScrollSpellAt(item, i) <> C_Spell.NONE then
            found := True;
      item := item^.next;
    end;
  end;
  HasScrollSpells := found;
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
  if Types.PItemRec(it)^.nameIds[2] < 210 then
    CharHlp.RemoveItem(Types.PCharRecord(cr), Types.PItemRec(it));
end;

procedure PrintCastSpellMsg(creature: Types.PCharRecord; msg: Types.TStr40; spell: Byte);
begin
  if GDVars.ifcState = C_Ifc.COMBAT then begin
    CharHlp.PrintNameString(creature, 'Casts a Spell', 10, True);
    Border.ClearBox(0, 23, 39, 23);
    TextRend.DisplayString(0, 23, LightGreen, 'Spell:' + GDConsts.spellNames[spell]);
  end else begin
    Border.ClearBox(1, 18, 38, 22);
    CharHlp.DisplayCreatureName(creature, 1, 19, False);
    TextRend.DisplayString(Length(creature^.name) + 2, 19, LightGreen, msg);
    TextRend.DisplayString(1, 20, LightGreen, GDConsts.spellNames[spell]);
    TextRend.PauseOnly;
    CharHlp.ClearMessageWindow;
  end;
end;

procedure InitSpellFns;
begin
  GDVars.spellFps[0] := @Magic.NoncombatCastTargetMenu;
  GDVars.effectLock := 0;
  GDVars.usingItem := False;
  GDVars.castTarget := nil;
  GDVars.dsRedrawInventoryMenuFlag := 1;
  GDVars.spellFps[1] := @Magic.BlessHandler;
  GDVars.spellFps[2] := @Magic.CurseHandler;
  GDVars.spellFps[3] := @Magic.CureLightWoundsHandler;
  GDVars.spellFps[4] := @Magic.CauseLightWoundsHandler;
  GDVars.spellFps[5] := @Magic.DetectionHandler;
  GDVars.spellFps[6] := @Magic.ProtectionHandler;
  GDVars.spellFps[7] := @Magic.ProtectionHandler;
  GDVars.spellFps[8] := @Magic.ResistColdHandler;
  GDVars.spellFps[9] := @Magic.BurningHandsHandler;
  GDVars.spellFps[10] := @Magic.CharmPersonHandler;
  GDVars.spellFps[11] := @Magic.DetectionHandler;
  GDVars.spellFps[12] := @Magic.EnlargeHandler;
  GDVars.spellFps[13] := @Magic.ReduceHandler;
  GDVars.spellFps[14] := @Magic.FriendsHandler;
  GDVars.spellFps[15] := @Magic.MagicMissileHandler;
  GDVars.spellFps[16] := @Magic.ProtectionHandler;
  GDVars.spellFps[17] := @Magic.ProtectionHandler;
  GDVars.spellFps[18] := @Magic.DetectionHandler;
  GDVars.spellFps[19] := @Magic.ShieldHandler;
  GDVars.spellFps[20] := @Magic.ShockingGraspHandler;
  GDVars.spellFps[21] := @Magic.SleepHandler;
  GDVars.spellFps[22] := @Magic.DetectionHandler;
  GDVars.spellFps[23] := @Magic.HoldPersonHandler;
  GDVars.spellFps[24] := @Magic.ResistFireHandler;
  GDVars.spellFps[25] := @Magic.SilenceHandler;
  GDVars.spellFps[26] := @Magic.SlowPoisonHandler;
  GDVars.spellFps[27] := @Magic.SnakeCharmHandler;
  GDVars.spellFps[28] := @Magic.SpiritualHammerHandler;
  GDVars.spellFps[29] := @Magic.DetectionHandler;
  GDVars.spellFps[30] := @Magic.InvisibilityHandler;
  GDVars.spellFps[31] := @Magic.KnockHandler;
  GDVars.spellFps[32] := @Magic.MirrorImageHandler;
  GDVars.spellFps[33] := @Magic.RayOfEnfeeblementHandler;
  GDVars.spellFps[34] := @Magic.StinkingCloudHandler;
  GDVars.spellFps[35] := @Magic.StrengthHandler;
  GDVars.spellFps[36] := @Magic.AnimateDeadHandler;
  GDVars.spellFps[37] := @Magic.CureBlindnessHandler;
  GDVars.spellFps[38] := @Magic.CauseBlindnessHandler;
  GDVars.spellFps[39] := @Magic.CureDiseaseHandler;
  GDVars.spellFps[40] := @Magic.CauseDiseaseHandler;
  GDVars.spellFps[41] := @Magic.DispelMagicHandler;
  GDVars.spellFps[42] := @Magic.PrayerHandler;
  GDVars.spellFps[43] := @Magic.RemoveCurseSpell;
  GDVars.spellFps[44] := @Magic.BestowCurseHandler;
  GDVars.spellFps[45] := @Magic.BlinkHandler;
  GDVars.spellFps[46] := @Magic.DispelMagicHandler;
  GDVars.spellFps[47] := @Magic.FireballHandler;
  GDVars.spellFps[48] := @Magic.HasteHandler;
  GDVars.spellFps[49] := @Magic.HoldPersonHandler;
  GDVars.spellFps[50] := @Magic.InvisibilityHandler;
  GDVars.spellFps[51] := @Magic.LightningBoltHandler;
  GDVars.spellFps[52] := @Magic.ProtectionHandler;
  GDVars.spellFps[53] := @Magic.ProtectionHandler;
  GDVars.spellFps[54] := @Magic.ProtectionHandler;
  GDVars.spellFps[55] := @Magic.SlowHandler;
  GDVars.spellFps[56] := @Magic.RestorationHandler;
  GDVars.spellFps[57] := @Magic.PotionOfSpeedHandler;
  GDVars.spellFps[58] := @Magic.KeoghtomsOintmentHandler;
  GDVars.spellFps[59] := @Magic.GiantStrengthHandler;
  GDVars.spellFps[60] := @Magic.JavelinOfLightningHandler;
  GDVars.spellFps[61] := @Magic.WandParalyzationHandler;
  GDVars.spellFps[62] := @Magic.PotionOfHealingHandler;
  GDVars.spellFps[63] := @Magic.DustDisappearanceHandler;
  GDVars.spellFps[64] := @Magic.FireballHandler;
  GDVars.spellFps[65] := @Magic.WandMagicMissilesHandler;
  GDVars.spellFps[66] := @Magic.UnusedSpellHandler;
  GDVars.spellFps[67] := @Magic.ManualBodilyHealthHandler;
  GDVars.effectFns[88] := @Magic.DragonBreathHandler;
end;

end.

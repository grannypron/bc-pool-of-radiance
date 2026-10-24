{ Spell selection, casting, targeting and spell-specific behavior. }
{$O+,F+}
{$I COMPILER.INC}
unit Magic;

interface

{ Types supplies PCharRecord, PItemRec, PEffectRec, TStr40 and TCellList for the declarations below. }
uses Types;

var
  { Set by a caller whose screen below a memorize list (Camp's spell slots) is covered by the spell page:
    SpellSelection calls it, when set, after the page closes, to draw that part again. }
  belowListHook: Types.TIdleProc;
  { combat arena column, 0..49 }
  gTargetX: ShortInt;
  { combat arena row, 0..24 }
  gTargetY: ShortInt;

{ Spell-selection menu: MenuCore.MenuVertical over spellList as built by GenerateSpellList. selType: 1 cast, 2 memorize
  (shorter window, bottom row 15), 3 scribe, 4 learn (on gaining a level; no Exit entry), 5 show only (drawn and left
  for the caller's question, unless it needs paging; MenuCore.listOnly), anything else view only (no title or prompt).
  idx is the menu cursor and persists across calls; idx < 0 clears the window and opens at the top of the list on its
  first spell (cast and learn always redraw). Every list but show only has the highlighted spell's summary line
  (SpellInf.ShowSummary) under it, on row 22 below a list that ends at row 20, or for memorize on the message window's
  top row, and Info (I) on the bottom line, which opens the spell page (SpellInf.ShowPage) and comes back to the list
  on the spell the page showed last (#839). A line read from a scroll is worked out at the scroll's caster level.
  Returns the chosen spell id, or 0 for Exit, with scroll the chosen line's scroll in spellScrolls (nil for Exit or a
  memorized spell); scribe also sets currentScrollPtr to the chosen spell's scroll. Frees spellList before returning. }
function SpellSelection(selType: Byte; var idx: Integer; var scroll: Types.PItemRec): Byte;

{ Build spellList and spellIds for a menu of creature's spells. menuType: 0 memorized, 5 still being memorized (bit 7
  set), 1 spell book, 2 current scroll, 3 spells on every readable item, 6 scroll spells queued for scribing (bit 7
  set), 4 spells learnable on gaining a level (creature has slots of the spell's class and level and does not know it
  yet), 7 the spells creature can cast now (AddAvailableSpells). Returns True if the list has a spell; a list of level
  headings alone is freed and counts as empty. }
function GenerateSpellList(creature: Types.PCharRecord; menuType: Byte): Boolean;

{ The cast-target menu outside combat (GameVars.castTargetMenu). spellTable target mode 1 targets the caster, 2 asks for
  one party member (remembered in GameVars.castTarget; cancelling clears the targets and the cast) and 4 targets every
  creature in GameVars.creatureList; any other mode cancels the cast. b is unused; it matches Types.TCastUI. }
procedure NoncombatCastTargetMenu(spell: Byte; b: Boolean; var cast: Boolean);

{ Cast spell for GameVars.curChar. Outside combat a combat-only spell (target mode 0) is not cast: a memorized spell
  offers 'Lose it?' (Yes removes it) and an item offers 'Use it?' (Yes sets sel). Otherwise, when ai is set and no item
  is in use, announce the cast, then call GameVars.castTargetMenu with b until it picks targets or the cast ends. On a
  pick, a memorized spell first rolls the caster's chance of spell failure (ClassCal.SpellFailureChance: a cleric's low
  Wisdom, for a clerical spell, #60); a failure spends the spell and shows "<name> fails to cast <spell>." and nothing
  else happens. Otherwise, in combat turn to face the aim, play the cast sound and animate the projectile; then remove
  the caster's invisibility, consume the memorized spell unless GameVars.usingItem, and run GameVars.spellFns[spell]
  with currentSpellBeing set. With no pick, outside combat it just returns; in combat b, or Yes to 'Abort Spell?',
  aborts and consumes the spell, and otherwise targeting repeats. b means automatic targeting (AI or quick fight); sel
  returns whether targets were picked. }
procedure CastSpellNC(spell: Byte; b, ai: Boolean; var sel: Boolean);

{ Cast's refusal of a combat-only spell outside combat: show the spell's name and 'is a combat-only spell...' in the
  message window. }
procedure ShowCombatOnlySpell(spell: Byte);

{ Clear the last of the scroll's spell slots holding spell (bit 7 ignored) and decrement its spell-count name component,
  nameIds[2]; remove the item from cr once that drops below 210. Does nothing if no slot matches. }
procedure RemoveSpellFromScroll(cr, it: Pointer; spell: Byte);

{ Announce a cast. In combat, print 'Casts a Spell' for the creature (msg is ignored) and show the spell name on the
  line above the bottom line, the combat log naming it after the message (#841). Otherwise show the creature name, msg
  and the spell name in the message window, pause, then clear it. }
procedure PrintCastSpellMsg(creature: Types.PCharRecord; msg: Types.TStr40; spell: Byte);

{ Remove Curse (spellFns[43], also called by Temple): remove Bestow Curse (effect 36) from targetCreaturePtr[1], or
  else clear the curse on its first cursed item. }
procedure RemoveCurseSpell;

{ Spell handlers: each acts on GameVars.curChar, targetCreaturePtr and currentSpellBeing; GameInit.InitSpellFns maps
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

{ The cells a Lightning Bolt aimed at (x, y) by GameVars.curChar would cross after the aim cell itself, in order,
  bounces included, judged on the arena as it stands. Nothing is drawn or damaged. }
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

uses Stats, CharDisp, C_SOUND, C_ITEM, Dice, Crt, C_NPC, C_TERR, C_SAVE, C_COND, GameDefs, GameVars, TextRend,
  Border, CharHlp, SoundDrv, MenuCore, Pathing, CbtMap, ClassCal, FxEngine, C_EFFECT, C_RACE, C_KEYS, C_LEVEL, C_STATUS,
  C_IFC, C_DIR, C_SPELL, AbilAdj, StrUtil, C_MSG, ChgClass, SpellInf, CbtLog;

var
  { the menu string list }
  spellList: Types.PItemRec;
  { spell ID per menu line }
  spellIds: array[0..C_SPELL.LINE_LAST] of Byte;
  { the scroll each Cast line reads from, nil for a memorized spell }
  spellScrolls: array[0..C_SPELL.LINE_LAST] of Types.PItemRec;
  scrollPtrs: array[0..48] of Types.PItemRec;
  scrollCount: Byte;
  { Current item used for spell casting. }
  currentScrollPtr: Types.PItemRec;
  { the list is one scroll's spells (GenerateSpellList's menu 2, read with Use), each cast from the scroll }
  scrollList: Boolean;

const
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
  { the columns a spell list's line has, from the list window's left edge to its right }
  LINE_WIDTH = 38;

function SpellMark(creature: Types.PCharRecord; spell, mark: Byte): Char; forward;

procedure WalkBolt(boltLen, damage: Byte; saveType: ShortInt; bounce, trace: Boolean; var cells: Types.TCellList);
  forward;

{ The number of selectable lines (spells) before member n of spellList: its index in spellIds and spellScrolls. }
function LineBefore(n: Integer): Integer;
var
  p: Types.PItemRec;
  k: Integer;
  lines: Integer;
begin
  p := spellList;
  k := 0;
  lines := 0;
  while (p <> nil) and (k < n) do begin
    if p^.inUse = 0 then
      Inc(lines);
    p := p^.next;
    Inc(k);
  end;
  LineBefore := lines;
end;

{ Member n of spellList as SpellInf takes a list line: its spell id, with C_SPELL.FROM_ITEM set when it is read from a
  scroll (the one-scroll list, or a Cast line with a scroll); 0 for a level heading or past the list. }
function LineSpell(n: Integer): Byte;
var
  p: Types.PItemRec;
  line: Integer;
begin
  LineSpell := 0;
  p := MenuCore.FindListMember(n, spellList);
  if (p <> nil) and (n >= 0) then
    if p^.inUse = 0 then begin
      line := Magic.LineBefore(n);
      if line <= C_SPELL.LINE_LAST then
        if scrollList or (spellScrolls[line] <> nil) then
          LineSpell := spellIds[line] or C_SPELL.FROM_ITEM
        else
          LineSpell := spellIds[line];
    end;
end;

{ Show the spell page for spellList's member idx, stepping through every spell on the list, then point idx at the
  spell it showed last, scrolled into the rows firstRow..lastRow, and redraw the window down to windowRow and, for
  memorize, what lies below it (belowListHook). }
procedure SpellPage(var idx: Integer; firstRow, lastRow, windowRow: Byte; memorize: Boolean);
var
  lines: SpellInf.TLineSpells;
  p: Types.PItemRec;
  n: Integer;
  count: Integer;
  cur: Integer;
  rows: Integer;
begin
  count := 0;
  cur := 0;
  p := spellList;
  n := 0;
  while p <> nil do begin
    if (p^.inUse = 0) and (count <= C_SPELL.LINE_LAST) then begin
      if n = idx then
        cur := count;
      lines[count] := Magic.LineSpell(n);
      Inc(count);
    end;
    p := p^.next;
    Inc(n);
  end;
  SpellInf.ShowPage(lines, count, cur);
  { back to the list, on the spell shown last }
  p := spellList;
  n := 0;
  while (p <> nil) and ((p^.inUse <> 0) or (Magic.LineBefore(n) < cur)) do begin
    p := p^.next;
    Inc(n);
  end;
  if p <> nil then
    idx := n;
  rows := lastRow - firstRow + 1;
  if idx < GameVars.vertTop then
    GameVars.vertTop := idx;
  if idx > GameVars.vertTop + rows - 1 then
    GameVars.vertTop := idx - rows + 1;
  Border.DrawWindow(1, 3, 38, windowRow, 0, Black, '');
  if memorize and (@belowListHook <> nil) then
    belowListHook;
end;

function SpellSelection(selType: Byte; var idx: Integer; var scroll: Types.PItemRec): Byte;
const
  LIST_TOP = 5;
var
  sel: Types.PItemRec;
  p: Types.PItemRec;
  prompt: Types.TStr40;
  title: Types.TStr40;
  count: Byte;
  { the list window's last row, the list's own, and the summary line's (0 for none) }
  windowRow: Byte;
  bottomRow: Byte;
  summaryRow: Byte;
  ch: Char;
  addExit: Boolean;
  redraw: Boolean;
  moved: Boolean;
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
  case selType of
    2: begin
         windowRow := 15;
         bottomRow := 15;
         { the message window's top row, above Camp.DisplaySpellSlots' lines }
         summaryRow := C_MSG.MESSAGE_TOP;
       end;
    5: begin
         windowRow := 22;
         bottomRow := 22;
         summaryRow := 0;
       end;
  else
    begin
      windowRow := 22;
      bottomRow := 20;
      summaryRow := 22;
    end;
  end;
  if summaryRow > 0 then
    if title = '' then
      title := 'Info'
    else
      title := title + ' Info';
  { the bottom line holds 40 columns: with Next, Prev and Exit after it, Memorize Info takes 'Spell: ' }
  if Length(prompt) + Length(title) + Length(' Next Prev Exit') > 40 then
    prompt := 'Spell: ';
  if selType = 4 then
    addExit := False
  else
    addExit := True;
  redraw := False;
  if idx < 0 then begin
    Border.DrawWindow(1, 3, 38, windowRow, 0, Black, '');
    redraw := True;
    { open at the top of the list on its first spell, the line under the first level heading (MenuVertical, given the
      heading, would wrap up to the page's last line) }
    GameVars.vertTop := 0;
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
    if summaryRow > 0 then
      SpellInf.ShowSummary(Magic.LineSpell(idx), summaryRow);
    MenuCore.listOnly := selType = 5;
    MenuCore.movesToCaller := summaryRow > 0;
    ch := MenuCore.MenuVertical(prompt, title, LightMagenta, LightGreen, White, 1, LIST_TOP, 38,
                                bottomRow, spellList, addExit, redraw, idx, sel);
    moved := MenuCore.moved;
    if not moved and (ch = 'I') and (summaryRow > 0) and (sel <> nil) then begin
      Magic.SpellPage(idx, LIST_TOP, bottomRow, windowRow, selType = 2);
      redraw := True;
    end;
  until not moved and (ch in [C_KEYS.NONE, C_KEYS.ENTER, 'C', 'E', 'L', 'M', 'S']);
  if summaryRow > 0 then
    SpellInf.ShowSummary(0, summaryRow);
  p := spellList;
  count := 0;
  while p <> sel do begin
    if p^.inUse = 0 then
      Inc(count);
    p := p^.next;
  end;
  scroll := nil;
  if (ch in [C_KEYS.NONE, 'E']) or (count > C_SPELL.LINE_LAST) then
    SpellSelection := C_SPELL.NONE
  else begin
    SpellSelection := spellIds[count];
    scroll := spellScrolls[count];
  end;
  if selType = 3 then
    { 48 = High(scrollPtrs) }
    if count <= 48 then
      currentScrollPtr := scrollPtrs[count]
    else
      currentScrollPtr := nil;
  MenuCore.FreeStringList(spellList);
end;

{ Append spell to spellList, first adding a level heading entry (inUse = 1) when its spell level differs from the
  previous spell's. Bit 7 set (pending memorization or scribing) prefixes ' *'; otherwise the second column holds
  SpellMark's character for mark (MARK_NONE, MARK_KNOWN or MARK_NOT_KNOWN). Stores spell and $7F in spellIds at the
  entry's selectable index. }
procedure AddSpellToList(creature: Types.PCharRecord; spell, mark: Byte);
const
  { Spell-list headings indexed by spell level }
  spellLevelNames: array[1..9] of String[9] = (
    '1st Level',
    '2nd Level',
    '3rd Level',
    '4th Level',
    '5th Level',
    '6th Level',
    '7th Level',
    '8th Level',
    '9th Level');
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
    if count > C_SPELL.LINE_LAST then
      Exit;
    lastLevel := GameDefs.spellTable[spellIds[count - 1]].levelSp;
    GetMem(p^.next, SizeOf(Types.TMenuNode));
    p := p^.next;
  end;
  p^.next := nil;
  if GameDefs.spellTable[spell and C_SPELL.ID_MASK].levelSp <> lastLevel then begin
    p^.name := spellLevelNames[GameDefs.spellTable[spell and C_SPELL.ID_MASK].levelSp];
    p^.inUse := 1;
    GetMem(p^.next, SizeOf(Types.TMenuNode));
    p := p^.next;
    p^.next := nil;
  end;
  if spell > C_SPELL.ID_MASK then
    p^.name := ' *'
  else
    p^.name := ' ' + Magic.SpellMark(creature, spell, mark);
  p^.name := p^.name + GameDefs.spellNames[spell and C_SPELL.ID_MASK];
  p^.inUse := 0;
  spellIds[count] := spell and C_SPELL.ID_MASK;
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
  id := spell and C_SPELL.ID_MASK;
  if (id >= 1) and (id <= SizeOf(creature^.spellsKnown)) then
    case mark of
      MARK_KNOWN:
        if creature^.spellsKnown[id] <> 0 then
          SpellMark := KNOWN_MARK;
      MARK_NOT_KNOWN:
        if creature^.spellsKnown[id] = 0 then begin
          learnable := False;
          with GameDefs.spellTable[id] do
            if (levelSp >= 1) and (levelSp <= 3) then
              case castClassSp of
                0: learnable := CharHlp.GetClassLevel(creature, C_LEVEL.CLERIC_BIT) > 0;
                1: learnable := CharHlp.GetClassLevel(creature, C_LEVEL.MAGE_BIT) > 0;
              end;
          if learnable then
            SpellMark := NOT_KNOWN_MARK;
        end;
    end;
end;

{ Add currentScrollPtr's spells to the list (forScribe: only those queued for scribing, id > $80), each with mark,
  and record the scroll in scrollPtrs for each while scrollPtrs has room. Read Magic (effect 16), or any cleric level
  with a scroll whose base item slot is 12, identifies the scroll first; an unidentified scroll adds nothing. }
procedure AddScrollSpells(creature: Types.PCharRecord; forScribe: Boolean; mark: Byte);
var
  i: Byte;
begin
  if CharHlp.ScrollLegible(creature, currentScrollPtr) then
    { 3 = High(TItemRec.spells) }
    for i := 1 to 3 do begin
      if (forScribe and (currentScrollPtr^.spells[i] > C_SPELL.PENDING_FLAG)) or
          (not forScribe and (currentScrollPtr^.spells[i] > 0)) then begin
        Magic.AddSpellToList(creature, currentScrollPtr^.spells[i], mark);
        { 48 = High(scrollPtrs) }
        if scrollCount <= 48 then begin
          scrollPtrs[scrollCount] := currentScrollPtr;
          Inc(scrollCount);
        end;
      end;
    end;
end;

{ Walk creature's inventory: each readable item becomes currentScrollPtr and feeds AddScrollSpells with forScribe and
  mark. currentScrollPtr itself is the loop variable, so it ends as nil. }
procedure AddAllScrollSpells(creature: Types.PCharRecord; forScribe: Boolean; mark: Byte);
begin
  currentScrollPtr := creature^.itemsAddr;
  while currentScrollPtr <> nil do begin
    if CharHlp.ItemReadable(currentScrollPtr) then
      Magic.AddScrollSpells(creature, forScribe, mark);
    currentScrollPtr := currentScrollPtr^.next;
  end;
end;

{ Add ' (xN)' to spellList's last line when copies is two or more, cutting the spell's name when the line would run
  past LINE_WIDTH. }
procedure AddCopies(copies: Byte);
var
  p: Types.PItemRec;
  s: Types.TStr20;
begin
  if (copies < 2) or (spellList = nil) then Exit;
  p := spellList;
  while p^.next <> nil do
    p := p^.next;
  s := ' (x' + StrUtil.NumStr(copies) + ')';
  if Length(p^.name) + Length(s) > LINE_WIDTH then
    p^.name[0] := Chr(LINE_WIDTH - Length(s));
  p^.name := p^.name + s;
end;

{ The number of spells on scroll item. }
function ScrollSpellCount(item: Types.PItemRec): Byte;
var
  i: Byte;
  n: Byte;
begin
  n := 0;
  for i := 1 to SizeOf(item^.spells) do
    if CharHlp.ScrollSpellAt(item, i) <> C_SPELL.NONE then
      Inc(n);
  ScrollSpellCount := n;
end;

{ How many times spell is on the scrolls creature can read and use (CharHlp.CastableScroll), and the one of them to
  read it from: the scroll with the fewest spells on it, the first in the inventory among equals, so a part-used scroll
  is used up before a full one is started (#833). best is nil when no such scroll holds spell. }
procedure FindScrollCopies(creature: Types.PCharRecord; spell: Byte; var copies: Byte; var best: Types.PItemRec);
var
  item: Types.PItemRec;
  i: Byte;
  held: Byte;
  fewest: Byte;
begin
  copies := 0;
  best := nil;
  fewest := 0;
  item := creature^.itemsAddr;
  while item <> nil do begin
    if CharHlp.CastableScroll(creature, item) then begin
      held := 0;
      for i := 1 to SizeOf(item^.spells) do
        if CharHlp.ScrollSpellAt(item, i) = spell then
          Inc(held);
      if held > 0 then begin
        Inc(copies, held);
        if (best = nil) or (Magic.ScrollSpellCount(item) < fewest) then begin
          best := item;
          fewest := Magic.ScrollSpellCount(item);
        end;
      end;
    end;
    item := item^.next;
  end;
end;

{ Add spell to the Cast list as line number lines, read from scroll item (spellScrolls), with its copies counted
  (AddCopies), and count the line. SCROLL_MARK goes in the indent column before the name, in place of the '*' a spell
  queued for scribing gets. Nothing is added once the list is full. }
procedure AddScrollLine(creature: Types.PCharRecord; item: Types.PItemRec; spell, copies: Byte; var lines: Byte);
var
  p: Types.PItemRec;
begin
  if lines <= C_SPELL.LINE_LAST then begin
    Magic.AddSpellToList(creature, spell, MARK_NONE);
    spellScrolls[lines] := item;
    Inc(lines);
    p := spellList;
    while p^.next <> nil do
      p := p^.next;
    if Length(p^.name) >= 2 then
      p^.name[2] := SCROLL_MARK;
    Magic.AddCopies(copies);
  end;
end;

{ How many of creature's memorized-spell slots hold what slot i holds, or 0 when an earlier slot holds it too: a list of
  memorized spells shows each once, where its first slot falls, with the number of copies (#833). }
function MemorizedCopies(creature: Types.PCharRecord; i: Byte): Byte;
var
  j: Byte;
  n: Byte;
begin
  n := 0;
  for j := 0 to Types.SPELL_SLOT_LAST do
    if creature^.memorizedSpells[j] = creature^.memorizedSpells[i] then begin
      if j < i then begin
        MemorizedCopies := 0;
        Exit;
      end;
      Inc(n);
    end;
  MemorizedCopies := n;
end;

{ Add memorized slot i's spell to spellList as line number lines, once for all its copies (MemorizedCopies, counted by
  AddCopies), and count the line. Nothing is added for a slot an earlier one repeats, or once the list is full. }
procedure AddMemorizedSpell(creature: Types.PCharRecord; i: Byte; var lines: Byte);
var
  copies: Byte;
begin
  copies := Magic.MemorizedCopies(creature, i);
  if (copies = 0) or (lines > C_SPELL.LINE_LAST) then Exit;
  Magic.AddSpellToList(creature, creature^.memorizedSpells[i], MARK_NONE);
  Inc(lines);
  Magic.AddCopies(copies);
end;

{ The Cast list, level by level: creature's memorized spells (not those still being memorized), each once with its
  copies counted (AddMemorizedSpell), then the spells on the scrolls creature can read and use (CastableScroll), each
  once in the order the inventory first holds them, marked with SCROLL_MARK and read from the scroll FindScrollCopies
  picks. In combat the memorized spells need castAllowed, as the Cast command does, and the scroll spells
  CharHlp.CanUseItems, as Use does. }
procedure AddAvailableSpells(creature: Types.PCharRecord);
var
  lvl: Byte;
  i: Byte;
  id: Byte;
  lines: Byte;
  memOk: Boolean;
  scrollOk: Boolean;
  item: Types.PItemRec;
  best: Types.PItemRec;
  copies: Byte;
  { the scroll spells already listed }
  listed: set of Byte;
begin
  listed := [];
  memOk := (GameVars.ifcState <> C_IFC.COMBAT) or (creature^.combatAddr^.castAllowed <> 0);
  scrollOk := CharHlp.CanUseItems(creature);
  lines := 0;
  for lvl := 1 to SPELL_LEVEL_LAST do begin
    if memOk then
      for i := 0 to SizeOf(creature^.memorizedSpells) - 1 do begin
        id := creature^.memorizedSpells[i];
        if (id >= 1) and (id <= C_SPELL.LAST) then
          if GameDefs.spellTable[id].levelSp = lvl then
            Magic.AddMemorizedSpell(creature, i, lines);
      end;
    if scrollOk then begin
      item := creature^.itemsAddr;
      while item <> nil do begin
        if CharHlp.CastableScroll(creature, item) then
          for i := 1 to SizeOf(item^.spells) do begin
            id := CharHlp.ScrollSpellAt(item, i);
            if (id <> C_SPELL.NONE) and not (id in listed) then
              if GameDefs.spellTable[id].levelSp = lvl then begin
                listed := listed + [id];
                Magic.FindScrollCopies(creature, id, copies, best);
                Magic.AddScrollLine(creature, best, id, copies, lines);
              end;
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
  lines: Byte;
begin
  GenerateSpellList := False;
  spellList := nil;
  lines := 0;
  for i := 0 to C_SPELL.LINE_LAST do begin
    spellIds[i] := 0;
    spellScrolls[i] := nil;
  end;
  { every list starts with no scrolls recorded: High(scrollPtrs), 49 slots }
  for i := 0 to 48 do
    scrollPtrs[i] := nil;
  scrollCount := 0;
  scrollList := menuType = 2;
  case menuType of
    7: Magic.AddAvailableSpells(creature);
    0: for i := 0 to Types.SPELL_SLOT_LAST do
         if (creature^.memorizedSpells[i] > 0) and
             (creature^.memorizedSpells[i] < C_SPELL.PENDING_FLAG) then
           Magic.AddMemorizedSpell(creature, i, lines);
    5: for i := 0 to Types.SPELL_SLOT_LAST do
         if creature^.memorizedSpells[i] > C_SPELL.ID_MASK then
           Magic.AddMemorizedSpell(creature, i, lines);
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
    4: for i := 1 to C_SPELL.LAST do
         with GameDefs.spellTable[i] do
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

{ Spell duration in minutes: CharHlp.SpellDuration's dice rolled, or its fixed figure }
function CalcSpellDuration(spell: Byte): Word;
var
  d: Types.TDurDice;
  m: Word;
begin
  CharHlp.SpellDuration(spell, d);
  m := d.add;
  if d.count > 0 then
    Inc(m, Dice.RollDice(d.count, d.sides));
  CalcSpellDuration := m * d.mult;
end;

{ Apply spell to every non-nil targetCreaturePtr entry. The save is rolled only when the spell's saveResult is not
  C_SPELL.SAVE_NONE. When currentSpellBeing's rangeFixed is 255 an attack roll is needed too; a miss counts as saved
  and zeroes damage for this and every later target. damage > 0 is dealt with elem as GameVars.elementMask and
  saveResult as the save reduction (C_SPELL.SAVE_NEGATES none, C_SPELL.SAVE_HALF half). The spell's effect, if any, is
  added for CalcSpellDuration minutes at strength eff (0 = caster level) with onRemove and msg, a save negating it for
  C_SPELL.SAVE_NEGATES and C_SPELL.SAVE_SPECIAL (Silence, whose aura then never starts). SSI's code read saveResult as a
  Boolean, so Silence's 3 negated under Free Pascal and not under Turbo Pascal (#860). With no targets it returns at
  once, leaving elementMask set. }
procedure ResolveSpell(spell, eff: Byte; onRemove: Boolean; damage, elem: Byte; msg: Types.TStr40);
var
  effLevel: Byte;
  i: Byte;
  tgt: Types.PCharRecord;
  saved: Boolean;
  saveResult: Byte;
begin
  saveResult := GameDefs.spellTable[spell].saveResult;
  if damage = 0 then
    GameVars.elementMask := 0
  else
    GameVars.elementMask := elem;
  if GameVars.spellTargetCount = 0 then
    Exit;
  if eff = 0 then
    effLevel := CharHlp.GetCasterLevel(spell)
  else
    effLevel := eff;
  for i := 1 to GameVars.spellTargetCount do begin
    if GameVars.targetCreaturePtr[i] <> nil then begin
      tgt := GameVars.targetCreaturePtr[i];
      if saveResult = C_SPELL.SAVE_NONE then
        saved := False
      else
        saved := FxEngine.RollSavingThrow(tgt, GameDefs.spellTable[spell].saveType, 0);
      if GameDefs.spellTable[GameVars.currentSpellBeing].rangeFixed = 255 then begin
        CharHlp.RecalcStats(tgt);
        FxEngine.TriggerEffectsWithCondition(C_COND.DEFENDER_AC, tgt);
        if not FxEngine.AttackRoll(GameVars.curChar, tgt, tgt^.acCur) then begin
          damage := 0;
          saved := True;
        end;
      end;
      if damage > 0 then
        FxEngine.InflictNonWeaponDamage(tgt, damage, saveResult, saved);
      if GameDefs.spellTable[spell].effect > 0 then
        FxEngine.AddEffectWithMessage(tgt, GameDefs.spellTable[spell].effect, Magic.CalcSpellDuration(spell), effLevel,
                                      onRemove, saveResult in [C_SPELL.SAVE_NEGATES, C_SPELL.SAVE_SPECIAL], saved, msg);
    end;
  end;
  GameVars.elementMask := 0;
end;

procedure NoncombatCastTargetMenu(spell: Byte; b: Boolean; var cast: Boolean);
begin
  if GameVars.castTarget = nil then
    GameVars.castTarget := GameVars.curChar;
  GameVars.targetCreaturePtr[1] := GameVars.curChar;
  GameVars.spellTargetCount := 1;
  cast := True;
  case GameDefs.spellTable[spell].target of
    1: ;
    2: begin
         CharDisp.DisplayNoncombatInterface;
         CharDisp.SelectChar('Cast Spell on whom', True, GameVars.castTarget);
         if GameVars.castTarget = nil then begin
           GameVars.targetCreaturePtr[1] := nil;
           GameVars.spellTargetCount := 0;
           cast := False;
         end else
           GameVars.targetCreaturePtr[1] := GameVars.castTarget;
       end;
    4: begin
         GameVars.targetCreaturePtr[GameVars.spellTargetCount] := GameVars.creatureList;
         while GameVars.targetCreaturePtr[GameVars.spellTargetCount]^.nextCharAddr <> nil do begin
           GameVars.targetCreaturePtr[GameVars.spellTargetCount + 1] :=
             GameVars.targetCreaturePtr[GameVars.spellTargetCount]^.nextCharAddr;
           Inc(GameVars.spellTargetCount);
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
  p := GameVars.curChar;
  ok := True;
  if (GameVars.ifcState <> C_IFC.COMBAT) and (GameDefs.spellTable[spell].target = 0) then begin
    if GameVars.usingItem = False then begin
      Magic.ShowCombatOnlySpell(spell);
      if MenuCore.YesNoMenu('Lose it? ', LightMagenta, White, LightGreen) = 'Y' then
        CharHlp.RemoveSpell(GameVars.curChar, spell);
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
    if GameVars.usingItem = False then
      Magic.PrintCastSpellMsg(p, 'casts', spell);
  while ok do begin
    GameVars.castTargetMenu(spell, b, sel);
    if sel then begin
      ok := False;
      { a cleric's low Wisdom can make a memorized clerical spell fail (#60), rolled only when there is a chance }
      failed := False;
      if GameVars.usingItem = False then begin
        chance := ClassCal.SpellFailureChance(p, spell);
        if chance > 0 then
          failed := Dice.RollDice(1, 100) <= chance;
      end;
      if failed then begin
        CharHlp.RemoveSpell(p, spell);
        CharDisp.PrintNameString(p, 'fails to cast ' + GameDefs.spellNames[spell] + '.', 10, True);
      end else begin
        if GameVars.ifcState = C_IFC.COMBAT then begin
          CharDisp.BuildIconFacings(18);
          x := CbtMap.CombatCellX(p);
          y := CbtMap.CombatCellY(p);
          k := 0;
          while not Pathing.IsDirToward(x, y, gTargetX, gTargetY, k) do
            Inc(k);
          CbtMap.SetCreatureFacing(p, k, 1, 0);
          SoundDrv.SoundSetAutoStop(0);
          case spell of
            C_SPELL.FIREBALL: SoundDrv.SoundEffect(GameDefs.soundIds.combat[C_SOUND.FIREBALL], C_SOUND.GROUP_SPELL);
            C_SPELL.LIGHTNING_BOLT:
              SoundDrv.SoundEffect(GameDefs.soundIds.combat[C_SOUND.LIGHTNING], C_SOUND.GROUP_SPELL);
          else
            SoundDrv.SoundEffect(GameDefs.soundIds.commands[C_SOUND.CAST], C_SOUND.GROUP_SPELL);
          end;
          CharDisp.CombatAnimateMovingIcon(x, y, gTargetX, gTargetY, 4, 30);
          SoundDrv.SoundSetAutoStop(10);
          if CbtMap.CombatIconVisible(p, 0) then begin
            CbtMap.SetCreatureFacing(p, p^.combatAddr^.direction, 1, 1);
            CbtMap.SetCreatureFacing(p, p^.combatAddr^.direction, 0, 0);
          end;
        end;
        FxEngine.RemoveInvisibility(p);
        if GameVars.usingItem = False then begin
          CharHlp.RemoveSpell(GameVars.curChar, spell);
          Stats.Count(p, Stats.SPELLS_CAST, 1);
        end;
        GameVars.currentSpellBeing := spell;
        GameVars.spellFns[GameVars.currentSpellBeing];
        GameVars.currentSpellBeing := C_SPELL.NONE;
        GameVars.gMultiTarget := 0;
      end;
    end else begin
      if GameVars.ifcState <> C_IFC.COMBAT then
        ok := False
      else if b or (MenuCore.YesNoMenu('Abort Spell? ', Yellow, LightGreen, White) = 'Y') then
      begin
        CharDisp.PrintBottomLine('Spell Aborted');
        if GameVars.usingItem = False then
          CharHlp.RemoveSpell(GameVars.curChar, spell);
        ok := False;
      end;
    end;
  end;
  CharDisp.ClearMessageWindow;
  if GameVars.ifcState = C_IFC.COMBAT then
    Border.ClearBox(0, 23, 39, 23);
end;

procedure ShowCombatOnlySpell(spell: Byte);
begin
  TextRend.DisplayString(1, 19, LightGreen, GameDefs.spellNames[spell]);
  TextRend.DisplayString(1, 20, LightGreen, 'is a combat-only spell...');
end;

{ Bless and Curse: drop targets not on team hostFlag and, for Bless in combat, targets with an enemy within range 1;
  resolve the rest as a multi-target spell with msg. }
procedure CastOneSide(hostFlag: ShortInt; msg: Types.TStr40);
var
  i: Byte;
begin
  GameVars.gMultiTarget := 1;
  for i := 1 to GameVars.spellTargetCount do begin
    if (GameVars.targetCreaturePtr[i]^.hostile <> hostFlag) or
        ((GameVars.currentSpellBeing = C_SPELL.BLESS) and (GameVars.ifcState = C_IFC.COMBAT) and
         (CbtMap.CountTargets(GameVars.targetCreaturePtr[i], 1) > 0)) then
      GameVars.targetCreaturePtr[i] := nil;
  end;
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, False, 0, 0, msg);
end;

{ Bless: apply the spell to the caster's own team (see CastOneSide). }
procedure BlessHandler;
begin
  Magic.CastOneSide(GameVars.curChar^.hostile, 'is Blessed');
end;

{ Curse: apply the spell to the caster's enemies (see CastOneSide). }
procedure CurseHandler;
begin
  Magic.CastOneSide(CharHlp.EnemyTeam(GameVars.curChar), 'is Cursed');
end;

{ Cure Light Wounds: restore 1d8 hit points to the first target. }
procedure CureLightWoundsHandler;
begin
  if GameVars.spellTargetCount = 0 then
    Exit;
  if FxEngine.RestoreHitPoints(GameVars.targetCreaturePtr[1], Dice.RollDice(1, 8), False) then
    CharDisp.PrintHpRestoreMsg(GameVars.targetCreaturePtr[1]);
end;

{ Cause Light Wounds: 1d8 damage, element mask 8. }
procedure CauseLightWoundsHandler;
begin
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, False, Dice.RollDamageDice(1, 8), C_EFFECT.ELEM_MAGIC, '');
end;

{ Shared handler for the detection-style spells: apply the spell's effect. }
procedure DetectionHandler;
begin
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, False, 0, 0, 'is affected');
end;

{ Shared handler for the protection spells: apply the spell's effect. }
procedure ProtectionHandler;
begin
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, False, 0, 0, 'is protected');
end;

{ Resist Cold: apply the spell's effect. }
procedure ResistColdHandler;
begin
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, False, 0, 0, 'is cold-resistant');
end;

{ Burning Hands: caster-level damage, element mask 9. }
procedure BurningHandsHandler;
begin
  { no dice are rolled: the fixed damage counts as one die for the per-die fire protections (effects 61 and 113),
    which otherwise used the die count of whatever damage roll came before }
  GameVars.gDamageDice := 1;
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, False, CharHlp.GetCasterLevel(GameVars.currentSpellBeing),
                     C_EFFECT.ELEM_FIRE or C_EFFECT.ELEM_MAGIC, '');
end;

{ Charm Person: only persons (CharHlp.IsPerson) can be charmed (#792). The Charm effect's strength is the caster's
  team (CharHlp.Team) * 128 + caster level; afterwards the target's first Charm effect (normally the one just added)
  has its handler called with removed = False. }
procedure CharmPersonHandler;
var
  effect: Types.PEffectRec;
  tgt: Types.PCharRecord;
begin
  tgt := GameVars.targetCreaturePtr[1];
  if not CharHlp.IsPerson(tgt) then
    CharDisp.PrintNameString(tgt, 'is unaffected', 10, True)
  else begin
    Magic.ResolveSpell(GameVars.currentSpellBeing,
                        CharHlp.Team(GameVars.curChar) * 128 + CharHlp.GetCasterLevel(GameVars.currentSpellBeing),
                        True, 0, 0, 'is charmed');
    if CharHlp.HasEffect(tgt, C_EFFECT.CHARM, effect) then
      FxEngine.CallEffectHandler(C_EFFECT.CHARM, GameVars.targetCreaturePtr[1], effect, False);
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
  lvl := CharHlp.GetCasterLevel(GameVars.currentSpellBeing);
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
  if FxEngine.AdjustForNewStrength(GameVars.targetCreaturePtr[1], baseStr, excStr, enc) then
    CharDisp.PrintNameString(GameVars.targetCreaturePtr[1], 'is stronger', 10, True);
  { enc: the Strength encoding AdjustForNewStrength returned, kept as the effect's strength }
  FxEngine.AddEffect(GameVars.targetCreaturePtr[1], C_EFFECT.ENLARGE,
                     Magic.CalcSpellDuration(GameVars.currentSpellBeing), enc, True);
end;

{ Reduce: if targetCreaturePtr[1] fails a spell save, remove its Enlarge effect (12) }
procedure ReduceHandler;
begin
  if GameVars.spellTargetCount > 0 then
    if not FxEngine.RollSavingThrow(GameVars.targetCreaturePtr[1], C_SAVE.SPELL, 0) then
      if FxEngine.RemoveEffectWithMessage(GameVars.targetCreaturePtr[1], C_EFFECT.ENLARGE) then
        CharDisp.PrintNameString(GameVars.targetCreaturePtr[1], 'has been reduced', 10, True);
end;

{ Friends: +2d4 Charisma, capped at 25; the effect's strength is the old Charisma, restored on removal }
procedure FriendsHandler;
var
  oldCha: Byte;
begin
  oldCha := GameVars.targetCreaturePtr[1]^.chaCur;
  GameVars.targetCreaturePtr[1]^.chaCur := AbilAdj.ClampScore(oldCha + Dice.RollDice(2, 4));
  Magic.ResolveSpell(GameVars.currentSpellBeing, oldCha, True, 0, 0, 'is friendly');
end;

{ Magic Missile: one missile of 1d4 + 1 for every two caster levels, the first at level 1 (1st edition and the rule
  book: two at levels 3 and 4, three at 5 and 6), element mask 8. SSI's counted caster level div 2, so a 1st-level
  caster's did no damage and every later pair of levels got its missile a level late (#859). }
procedure MagicMissileHandler;
var
  missiles: Byte;
begin
  missiles := (CharHlp.GetCasterLevel(GameVars.currentSpellBeing) + 1) div 2;
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, False, missiles + Dice.RollDamageDice(missiles, 4),
                     C_EFFECT.ELEM_MAGIC, '');
end;

{ Shield: apply the spell's effect. }
procedure ShieldHandler;
begin
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, False, 0, 0, 'is shielded');
end;

{ Shocking Grasp: 1d8 + caster level damage, element mask $C. }
procedure ShockingGraspHandler;
begin
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, False,
                      Dice.RollDamageDice(1, 8) + CharHlp.GetCasterLevel(GameVars.currentSpellBeing),
                      C_EFFECT.ELEM_ELEC or C_EFFECT.ELEM_MAGIC, '');
end;

{ Sleep: a 4d4 hit-dice pool (C_SPELL.SLEEP_DICE d SLEEP_DIE), spent greedily in target order through
  CharHlp.SleepTakes: animated dead, targets already asleep and targets the remaining pool cannot pay for
  (CharHlp.SleepCost) are dropped. }
procedure SleepHandler;
var
  pool: Byte;
  i: Byte;
begin
  GameVars.gMultiTarget := 1;
  pool := Dice.RollDice(C_SPELL.SLEEP_DICE, C_SPELL.SLEEP_DIE);
  for i := 1 to GameVars.spellTargetCount do
    if not CharHlp.SleepTakes(GameVars.targetCreaturePtr[i], pool) then
      GameVars.targetCreaturePtr[i] := nil;
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, False, 0, 0, 'falls asleep');
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
  case GameVars.spellTargetCount of
    1: if GameVars.currentSpellBeing = C_SPELL.HOLD_PERSON then
         smod := -2
       else
         smod := -3;
    2: smod := -1;
  else
    smod := 0;
  end;
  for i := GameVars.spellTargetCount downto 1 do begin
    if GameVars.targetCreaturePtr[i] <> nil then begin
      tgt := GameVars.targetCreaturePtr[i];
      if i < GameVars.spellTargetCount then begin
        SoundDrv.SoundSetAutoStop(0);
        SoundDrv.SoundEffect(GameDefs.soundIds.commands[C_SOUND.CAST], C_SOUND.GROUP_SPELL);
        CharDisp.BuildIconFacings(18);
        CharDisp.CombatAnimateMovingIcon(CbtMap.CombatCellX(GameVars.curChar), CbtMap.CombatCellY(GameVars.curChar),
                                        CbtMap.CombatCellX(tgt), CbtMap.CombatCellY(tgt), 4, 30);
        SoundDrv.SoundSetAutoStop(10);
      end;
      saved := FxEngine.RollSavingThrow(tgt, GameDefs.spellTable[GameVars.currentSpellBeing].saveType, smod);
      if not CharHlp.IsPerson(tgt) then
        saved := True;
      FxEngine.AddEffectWithMessage(tgt, GameDefs.spellTable[GameVars.currentSpellBeing].effect,
                                    Magic.CalcSpellDuration(GameVars.currentSpellBeing),
                                    CharHlp.GetCasterLevel(GameVars.currentSpellBeing), False,
                                    GameDefs.spellTable[GameVars.currentSpellBeing].saveResult = C_SPELL.SAVE_NEGATES,
                                    saved, 'is held');
    end;
  end;
end;

{ Resist Fire: apply the spell's effect. }
procedure ResistFireHandler;
begin
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, False, 0, 0, 'is fire resistant');
end;

{ Silence: apply the spell's effect. }
procedure SilenceHandler;
begin
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, False, 0, 0, 'is silenced');
end;

{ Stand a downed creature back up with its hit points through FxEngine.ReviveDeadCreature, or, where it cannot stand
  yet (another creature on its cell), a minute later through C_EFFECT.HEAL_WAKE. }
procedure StandUpOrWake(tgt: Types.PCharRecord);
begin
  if not FxEngine.ReviveDeadCreature(tgt, tgt^.hpCur) then
    FxEngine.AddEffect(tgt, C_EFFECT.HEAL_WAKE, 1, 0, True);
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
  tgt := GameVars.targetCreaturePtr[1];
  if tgt^.status = C_STATUS.ANIMATED then
    GameVars.targetCreaturePtr[1] := nil
  else if CharHlp.HasEffect(tgt, C_EFFECT.POISONED, effect) then begin
    if tgt^.hpCur = 0 then
      tgt^.hpCur := 1;
    Magic.ResolveSpell(GameVars.currentSpellBeing, 255, True, 0, 0, 'is affected');
    if ((tgt^.status = C_STATUS.DEAD) or (tgt^.enabled = 0)) and
        not (tgt^.status in [C_STATUS.TEMPGONE, C_STATUS.RUNNING, C_STATUS.STONED, C_STATUS.GONE]) then
      StandUpOrWake(tgt);
    FxEngine.AddEffect(tgt, C_EFFECT.SLOW_POISON_HIT, 10, 255, True);
  end;
end;

{ Snake Charm: rebuild the target list from GameVars.creatureList: snakes (SNAKE_NAME) whose hpCur still fits
  in a pool equal to the caster's hpCur, paid in list order. SSI's took charType 14, which the large and huge scorpions
  share with the giant snake (#802). }
procedure SnakeCharmHandler;
const
  { The game's one snake, the creature Snake Charm affects (#802): its charType, 14, the scorpions share }
  SNAKE_NAME = 'GIANT SNAKE';
var
  pool: Byte;
  p: Types.PCharRecord;
begin
  pool := GameVars.curChar^.hpCur;
  GameVars.spellTargetCount := 0;
  p := GameVars.creatureList;
  while p <> nil do begin
    if p^.name = SNAKE_NAME then
      if pool >= p^.hpCur then begin
        pool := pool - p^.hpCur;
        Inc(GameVars.spellTargetCount);
        GameVars.targetCreaturePtr[GameVars.spellTargetCount] := p;
      end;
    p := p^.nextCharAddr;
  end;
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, False, 0, 0, 'is charmed');
end;

{ Spiritual Hammer: apply the spell's effect, then run the Spiritual Hammer effect handler for the first target. }
procedure SpiritualHammerHandler;
begin
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, True, 0, 0, '');
  FxEngine.CallEffectHandler(C_EFFECT.SPIRIT_HAMMER, GameVars.targetCreaturePtr[1], nil, False);
end;

{ Invisibility: apply the spell's effect. }
procedure InvisibilityHandler;
begin
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, False, 0, 0, 'is invisible');
end;

{ Knock: apply the spell's effect. }
procedure KnockHandler;
begin
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, False, 0, 0, 'Knock-Knock');
end;

{ Mirror Image: apply the spell's effect with 1d4 images as its strength. }
procedure MirrorImageHandler;
begin
  Magic.ResolveSpell(GameVars.currentSpellBeing, Dice.RollDice(1, 4), False, 0, 0, 'is duplicated');
end;

{ Ray of Enfeeblement: apply the spell's effect. }
procedure RayOfEnfeeblementHandler;
begin
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, False, 0, 0, 'is weakened');
end;

{ Stinking Cloud: append a node to the stinkHead list and give the caster effect 40 for caster-level minutes at strength
  FxEngine.CloudStrength (caster level, at most 15, + myClouds * 16; SSI let a level above 15 carry into the number),
  where myClouds is the lowest number none of the caster's clouds has (FxEngine.FreeCloudNumber; SSI counted the
  caster's nodes on the walk to the tail and never checked the tail, so a second cloud could share the first one's
  number and its end clear the older cloud). The cloud covers the 2x2 block whose upper-left is the aim cell
  (GameDefs.cloudDir: center, E, SE, S). Each cell records the terrain underneath (a cell already under another cloud
  takes that cloud's saved terrain, a corpse cell the corpse's), and passable cells are stamped C_TERR.STINK_CLOUD;
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
  GameVars.gMultiTarget := 1;
  cl := CharHlp.GetCasterLevel(GameVars.currentSpellBeing);
  myClouds := FxEngine.FreeCloudNumber(GameVars.curChar);
  node := GameVars.stinkHead;
  if GameVars.stinkHead = nil then begin
    GetMem(GameVars.stinkHead, SizeOf(Types.TStinkRec));
    node := GameVars.stinkHead;
  end else begin
    while node^.next <> nil do
      node := node^.next;
    GetMem(node^.next, SizeOf(Types.TStinkRec));
    node := node^.next;
  end;
  FillChar(node^, SizeOf(Types.TStinkRec), 0);
  FxEngine.AddEffect(GameVars.curChar, C_EFFECT.CAST_STINK, cl, FxEngine.CloudStrength(cl, myClouds), True);
  node^.caster := GameVars.curChar;
  node^.idx := myClouds;
  node^.ulX := gTargetX;
  node^.ulY := gTargetY;
  for k := 1 to 4 do begin
    d := GameDefs.cloudDir[k];
    CbtMap.GetArenaContents(gTargetX + GameDefs.dirDX[d], gTargetY + GameDefs.dirDY[d], crIdx[k], terr);
    if (terr > 0) and (GameDefs.terrainInfo[terr].cost < 255) then
      node^.exists[k] := 1
    else
      node^.exists[k] := 0;
    if terr = C_TERR.STINK_CLOUD then begin
      p2 := GameVars.stinkHead;
      while p2 <> nil do begin
        if p2 <> node then
          for j := 1 to 4 do
            if (p2^.exists[j] <> 0) and
                (p2^.ulX + GameDefs.dirDX[GameDefs.cloudDir[j]] = gTargetX + GameDefs.dirDX[d]) and
                (p2^.ulY + GameDefs.dirDY[GameDefs.cloudDir[j]] = gTargetY + GameDefs.dirDY[d]) then
              if p2^.under[j] <> C_TERR.STINK_CLOUD then
                terr := p2^.under[j];
        p2 := p2^.next;
      end;
    end else if terr = C_TERR.CORPSE then begin
      for j := 1 to GameVars.downedCount do
        if GameVars.downed[j].x = gTargetX + GameDefs.dirDX[d] then
          if GameVars.downed[j].y = gTargetY + GameDefs.dirDY[d] then
            terr := GameVars.downed[j].terrain;
    end;
    node^.under[k] := terr;
    if node^.exists[k] <> 0 then
      GameVars.arenaPtr^.cells[gTargetY + GameDefs.dirDY[d], gTargetX + GameDefs.dirDX[d]] := C_TERR.STINK_CLOUD;
  end;
  CharDisp.PrintNameString(GameVars.curChar, 'Creates a noxious cloud', 10, False);
  CbtMap.ScrollView(gTargetX, gTargetY, 255, C_DIR.CENTER);
  TextRend.PauseOnly;
  CharDisp.ClearMessageWindow;
  for k := 1 to 4 do
    if crIdx[k] > 0 then
      FxEngine.ConsiderStinkingCloud(GameVars.creatureArr[crIdx[k]]);
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
  tgt := GameVars.targetCreaturePtr[1];
  if CharHlp.GetClassLevel(tgt, C_LEVEL.MAGE_BIT) > 0 then
    roll := Dice.RollDice(1, 4);
  if CharHlp.GetClassLevel(tgt, C_LEVEL.CLERIC_BIT + C_LEVEL.THIEF_BIT) > 0 then
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
  FxEngine.AddEffect(tgt, C_EFFECT.STRENGTH, Magic.CalcSpellDuration(GameVars.currentSpellBeing), enc, True);
end;

{ Animate Dead: animate up to caster-level dead (C_STATUS.DEAD) human (charType 0) creatures whose cell is still a valid
  location. Effect 32's strength is the old side * 16 + caster level (at most 15). Each corpse joins the caster's team
  under computer control (quickfight 1), becomes undead (charType 4, levelUndead 2, movementBase 6, attackLevel 0),
  loses its memorized spells and gets the animated NPC or PC npc code; if ReviveDeadCreature succeeds at full hpMax it
  also gets effect 32 and C_STATUS.ANIMATED. }
procedure AnimateDeadHandler;
var
  i: Byte;
  strength: Byte;
  n: Byte;
  p: Types.PCharRecord;
begin
  GameVars.gMultiTarget := 1;
  n := CharHlp.GetCasterLevel(GameVars.currentSpellBeing);
  GameVars.spellTargetCount := 0;
  p := GameVars.creatureList;
  while (p <> nil) and (n > 0) do begin
    if p^.status = C_STATUS.DEAD then
      { Human }
      if p^.charType = 0 then
        if CbtMap.IsValidCreatureLoc(p, CbtMap.CombatCellX(p), CbtMap.CombatCellY(p), True) then begin
          { the corpse's side in bit 4, the caster level (at most 15) below it: a level of 16 or more carried into the
            side, and EffAnimateDead gave the corpse back a hostile of 2 or more (#710) }
          strength := CharHlp.GetCasterLevel(GameVars.currentSpellBeing);
          if strength > 15 then
            strength := 15;
          strength := CharHlp.Team(p) * 16 + strength;
          p^.hostile := CharHlp.Team(GameVars.curChar);
          p^.quickfight := 1;
          p^.levelUndead := 2;
          p^.attackLevel := 0;
          p^.movementBase := 6;
          for i := 0 to Types.SPELL_SLOT_LAST do
            p^.memorizedSpells[i] := 0;
          { C_NPC.FLAG set }
          if CharHlp.IsNpc(p) then
            p^.npc := C_NPC.ANIMATED_NPC
          else
            p^.npc := C_NPC.ANIMATED_PC;
          { Undead }
          p^.charType := 4;
          if GameVars.ifcState = C_IFC.COMBAT then
            p^.combatAddr^.other := nil;
          Dec(n);
          if FxEngine.ReviveDeadCreature(p, p^.hpMax) then begin
            FxEngine.AddEffectWithMessage(p, C_EFFECT.ANIMATE_DEAD, 0, strength, True, False, False, 'is animated');
            p^.status := C_STATUS.ANIMATED;
          end;
        end;
    p := p^.nextCharAddr;
  end;
end;

{ Cure Blindness: remove the first target's blindness. }
procedure CureBlindnessHandler;
begin
  if FxEngine.RemoveEffectWithMessage(GameVars.targetCreaturePtr[1], C_EFFECT.BLIND) then
    CharDisp.PrintNameStringAnim(GameVars.targetCreaturePtr[1], True, 'can see');
end;

{ Cause Blindness: apply the spell's effect. }
procedure CauseBlindnessHandler;
begin
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, False, 0, 0, 'is blind');
end;

{ Remove disease from tgt with effectLock held: Diseased, the Strength-draining disease (also dropping its hit-point and
  helpless effects) and rot (also dropping mummy rot). Returns True if any of the three was present. }
function RemoveDiseaseEffects(tgt: Types.PCharRecord): Boolean;
begin
  RemoveDiseaseEffects := False;
  GameVars.effectLock := 1;
  if FxEngine.RemoveEffectWithMessage(tgt, C_EFFECT.DISEASED) then
    RemoveDiseaseEffects := True;
  if FxEngine.RemoveEffectWithMessage(tgt, C_EFFECT.DISEASE_STR) then begin
    RemoveDiseaseEffects := True;
    FxEngine.RemoveEffect(tgt, C_EFFECT.DISEASE_HP, nil);
    FxEngine.RemoveEffect(tgt, C_EFFECT.HELPLESS, nil);
  end;
  if FxEngine.RemoveEffectWithMessage(tgt, C_EFFECT.ROT_NO_HEAL) then begin
    RemoveDiseaseEffects := True;
    FxEngine.RemoveEffect(tgt, C_EFFECT.MUMMY_ROT, nil);
  end;
  GameVars.effectLock := 0;
end;

{ Cure Disease: remove the first target's disease effects. }
procedure CureDiseaseHandler;
var
  junk: Boolean;
begin
  junk := Magic.RemoveDiseaseEffects(GameVars.targetCreaturePtr[1]);
end;

{ Cause Disease: apply the spell's effect. }
procedure CauseDiseaseHandler;
begin
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, True, 0, 0, 'is diseased');
end;

{ Dispel Magic: on each target, try every effect whose strength is below 255, with its low nibble as the effect's caster
  level: 50%, +5% per caster level above it, -2% per level below. A paladin's lay-on-hands and cure-disease timers are
  left alone, and so are the diseases (C_EFFECT.DISEASES), which Cure Disease removes: SSI's dispelled Strength drain
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
  GameVars.gMultiTarget := 1;
  cl := CharHlp.GetCasterLevel(GameVars.currentSpellBeing);
  for i := 1 to GameVars.spellTargetCount do begin
    removed := False;
    if i <= Types.ARENA_SLOTS then
      tgt := GameVars.targetCreaturePtr[i]
    else
      tgt := nil;
    if tgt <> nil then
      effect := Types.PEffectRec(tgt^.effectsAddr)
    else
      effect := nil;
    while effect <> nil do begin
      nxt := effect^.next;
      if (effect^.strength < 255)
         and not (effect^.id in C_EFFECT.DISEASES + [C_EFFECT.RECENT_HEAL, C_EFFECT.RECENT_CURE]) then begin
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

{ Prayer: apply the spell's effect at FxEngine.PrayerStrength, the caster's team and level. }
procedure PrayerHandler;
begin
  Magic.ResolveSpell(GameVars.currentSpellBeing,
                      FxEngine.PrayerStrength(GameVars.curChar, CharHlp.GetCasterLevel(GameVars.currentSpellBeing)),
                      False, 0, 0, 'is praying');
end;

procedure RemoveCurseSpell;
var
  item: Types.PItemRec;
  found: Boolean;
begin
  if FxEngine.RemoveEffectWithMessage(GameVars.targetCreaturePtr[1], C_EFFECT.BESTOW_CURSE) then
    CharDisp.PrintNameStringAnim(GameVars.targetCreaturePtr[1], True, 'is un-cursed')
  else begin
    found := False;
    item := GameVars.targetCreaturePtr[1]^.itemsAddr;
    while (item <> nil) and (found = False) do begin
      if item^.cursed <> 0 then begin
        found := True;
        item^.cursed := 0;
      end;
      item := item^.next;
    end;
    if found then
      CharDisp.PrintNameStringAnim(GameVars.targetCreaturePtr[1], True, '''s item is un-cursed');
  end;
end;

{ Bestow Curse: apply the spell's effect. }
procedure BestowCurseHandler;
begin
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, False, 0, 0, 'has been cursed!');
end;

{ Blink: apply the spell's effect. }
procedure BlinkHandler;
begin
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, False, 0, 0, 'is blinking');
end;

{ Fireball: spell 64 (an item fireball) uses level 1d3 * 2 + 1. When zone0^.view3dFlag is 0 the target list is rebuilt
  with Pathing.TargetArea, radius 2 around the aim cell. Damage is level d6, element mask 9. }
procedure FireballHandler;
var
  cl: Byte;
begin
  GameVars.gMultiTarget := 1;
  if GameVars.currentSpellBeing = C_SPELL.ITEM_FIREBALL then
    cl := Dice.RollDice(1, 3) * 2 + 1
  else
    cl := CharHlp.GetCasterLevel(GameVars.currentSpellBeing);
  if GameVars.zone0^.view3dFlag = 0 then begin
    Pathing.TargetArea(gTargetX, gTargetY, 2);
  end;
  CbtMap.ScrollView(gTargetX, gTargetY, 0, C_DIR.CENTER);
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, False, Dice.RollDamageDice(cl, 6),
                     C_EFFECT.ELEM_FIRE or C_EFFECT.ELEM_MAGIC, '');
end;

{ Haste and Slow: keep up to caster-level targets on team hostFlag and drop the rest. A kept target carrying removeId,
  the opposing Slowed or Hasted effect, just loses it; the others get the spell's effect and have their
  C_COND.MOVE_ATTACK_RATE effects re-run on their own attack count, as at a round's start (#797), so a hasted one ages
  at once; its rates are worked out where they are used (CbtActs). }
procedure HasteSlowLogic(removeId: Byte; hostFlag: ShortInt; msg: Types.TStr40);
var
  cl: Byte;
  i: Byte;
begin
  GameVars.gMultiTarget := 1;
  cl := CharHlp.GetCasterLevel(GameVars.currentSpellBeing);
  for i := 1 to GameVars.spellTargetCount do begin
    if (GameVars.targetCreaturePtr[i]^.hostile = hostFlag) and (cl > 0) then begin
      Dec(cl);
      if FxEngine.RemoveEffectWithMessage(GameVars.targetCreaturePtr[i], removeId) then
        GameVars.targetCreaturePtr[i] := nil;
    end else
      GameVars.targetCreaturePtr[i] := nil;
  end;
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, False, 0, 0, msg);
  for i := 1 to GameVars.spellTargetCount do
    if GameVars.targetCreaturePtr[i] <> nil then begin
      GameVars.currentAttackCurrent := GameVars.targetCreaturePtr[i]^.attacks2;
      GameVars.currentCreatureCalculatingFlag := 0;
      FxEngine.TriggerEffectsWithCondition(C_COND.MOVE_ATTACK_RATE, GameVars.targetCreaturePtr[i]);
    end;
end;

{ Haste: the caster's team loses Slowed or is hasted (see HasteSlowLogic). }
procedure HasteHandler;
begin
  Magic.HasteSlowLogic(C_EFFECT.SLOWED, GameVars.curChar^.hostile, 'is Hasted');
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
    if GameDefs.terrainInfo[terr].cost = 255 then
      blocked := True;
  if crIdx > 0 then begin
    tgt := GameVars.creatureArr[crIdx];
    GameVars.elementMask := C_EFFECT.ELEM_ELEC or C_EFFECT.ELEM_MAGIC;
    FxEngine.InflictNonWeaponDamage(tgt, damage, 2, FxEngine.RollSavingThrow(tgt, saveType, 0));
    CharDisp.BuildIconFacings(19);
    GameVars.elementMask := 0;
  end;
end;

{ Run a lightning bolt from the aim cell (gTargetX/Y) directly away from the caster, attacking each creature
  cell it reaches; callers attack the aim cell itself first. The budget is boltLen * 2 in Pathing's doubled distance
  units. Impassable terrain reflects the bolt back the other way; with bounce set, a first reflection at most 8 units
  from the caster costs 8 extra units. An off-map cell ends the bolt. }
procedure LightningPath(boltLen, damage: Byte; saveType: ShortInt; bounce: Boolean);
var
  cells: Types.TCellList;
begin
  Magic.WalkBolt(boltLen, damage, saveType, bounce, False, cells);
end;

{ LightningPath's walk. With trace set it neither animates nor attacks: it lists every arena cell the bolt crosses in
  cells and leaves gTargetX/Y and GameVars.gMultiTarget as it found them. }
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
  savedX := gTargetX;
  savedY := gTargetY;
  savedMulti := GameVars.gMultiTarget;
  if not trace then
    CharDisp.BuildIconFacings(19);
  CbtMap.GetArenaContents(gTargetX, gTargetY, prevCr, terr);
  sign := 1;
  x0 := CbtMap.CombatCellX(GameVars.curChar);
  y0 := CbtMap.CombatCellY(GameVars.curChar);
  doBounce := bounce;
  if x0 = gTargetX then
    if y0 = gTargetY then
      Exit;
  budget := boltLen * 2;
  GameVars.gMultiTarget := 1;
  while budget > 0 do begin
    FillChar(req, SizeOf(req), 0);
    req.sx := gTargetX;
    req.sy := gTargetY;
    req.ex := gTargetX + (gTargetX - x0) * sign * budget;
    req.ey := gTargetY + (gTargetY - y0) * sign * budget;
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
            (GameDefs.terrainInfo[terr].cost > 1) or (req.dist >= budget);
      end;
      prevCr := crIdx;
      if terr = 0 then
        budget := 0;
      if trace then begin
        { LightningAttackAt's test }
        blocked := False;
        if terr > 0 then
          blocked := GameDefs.terrainInfo[terr].cost = 255;
      end else begin
        CharDisp.CombatAnimateMovingIcon(prevX, prevY, req.cx, req.cy, 4, 50);
        Magic.LightningAttackAt(req.cx, req.cy, damage, saveType, blocked);
      end;
      if blocked then begin
        gTargetX := req.cx;
        gTargetY := req.cy;
        FillChar(req2, SizeOf(req2), 0);
        req2.sx := gTargetX;
        req2.sy := gTargetY;
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
  GameVars.gMultiTarget := 0;
  if trace then begin
    gTargetX := savedX;
    gTargetY := savedY;
    GameVars.gMultiTarget := savedMulti;
  end;
end;

{ Lightning Bolt: caster-level d6 damage at the aim cell, then a bouncing bolt of 8 cells. }
procedure LightningBoltHandler;
var
  dmg: Byte;
  junk: Boolean;
begin
  dmg := Dice.RollDice(CharHlp.GetCasterLevel(GameVars.currentSpellBeing), 6);
  Magic.LightningAttackAt(gTargetX, gTargetY, dmg, C_SAVE.SPELL, junk);
  Magic.LightningPath(C_SPELL.LIGHTNING_BOLT_CELLS, dmg, C_SAVE.SPELL, True);
end;

procedure TraceLightningBolt(x, y: ShortInt; var cells: Types.TCellList);
var
  savedX: ShortInt;
  savedY: ShortInt;
begin
  savedX := gTargetX;
  savedY := gTargetY;
  gTargetX := x;
  gTargetY := y;
  Magic.WalkBolt(C_SPELL.LIGHTNING_BOLT_CELLS, 0, C_SAVE.SPELL, True, True, cells);
  gTargetX := savedX;
  gTargetY := savedY;
end;

{ Slow: the caster's enemies lose Hasted or are slowed (see HasteSlowLogic). }
procedure SlowHandler;
begin
  Magic.HasteSlowLogic(C_EFFECT.HASTED, CharHlp.EnemyTeam(GameVars.curChar), 'is Slowed');
end;

{ Restoration: give back one drained level. hpMax, hpCur and hpRolled regain drainedHps div drainedLevels. Scanning
  classes 0..7, a class becomes the pick when its level is not above the current pick's, its next-level XP is nonzero
  and smaller, and it is not at its level cap. The pick gains a level and experience is raised to its next-level XP if
  lower; with no pick the hit points alone come back. A class a dual-classed human has left is never the pick, as
  Curse restores classLevels alone (curse-disassembly v13 magic.pas:2016-2047), and a class the restored level passes
  wakes again (ChgClass.AnnounceWoken, #838). }
procedure RestorationHandler;
var
  tgt: Types.PCharRecord;
  share: Byte;
  bestLvl: ShortInt;
  lvl: ShortInt;
  bestXp: LongInt;
  bestCls: ShortInt;
  cls: ShortInt;
  resting: Byte;
begin
  tgt := GameVars.targetCreaturePtr[1];
  if tgt^.drainedLevels > 0 then begin
    resting := ChgClass.RestingMask(tgt);
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
    for cls := C_LEVEL.CLERIC to C_LEVEL.MONK do begin
      lvl := tgt^.classLevels[cls];
      if tgt^.portExt.formerClasses and (1 shl cls) <> 0 then
        lvl := 0;
      { xp[] runs to level 9 }
      if (lvl > 0) and (lvl < 9) and (lvl <= bestLvl) and (GameDefs.experienceSpellsClass[cls].xp[Succ(lvl)] > 0) and
          (GameDefs.experienceSpellsClass[cls].xp[Succ(lvl)] < bestXp) and
          (not CharHlp.AtLevelCap(tgt, cls)) then begin
        bestLvl := lvl;
        bestCls := cls;
        bestXp := GameDefs.experienceSpellsClass[cls].xp[Succ(lvl)];
      end;
    end;
    if bestCls >= 0 then begin
      Inc(tgt^.classLevels[bestCls]);
      if tgt^.experience < bestXp then
        tgt^.experience := bestXp;
    end;
    ClassCal.RecalcBaseSkills(tgt);
    CharDisp.PrintNameString(tgt, 'is restored', 10, True);
    if resting <> 0 then
      ChgClass.AnnounceWoken(tgt, resting);
  end;
end;

{ Potion of Speed: remove Slowed, or else apply the potion's effect. }
procedure PotionOfSpeedHandler;
begin
  if not FxEngine.RemoveEffectWithMessage(GameVars.targetCreaturePtr[1], C_EFFECT.SLOWED) then
    Magic.ResolveSpell(GameVars.currentSpellBeing, 0, False, 0, 0, 'is Speedy');
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
  tgt := GameVars.targetCreaturePtr[1];
  slowed := CharHlp.HasEffect(tgt, C_EFFECT.SLOW_POISON_END, effect) or
            CharHlp.HasEffect(tgt, C_EFFECT.SLOW_POISON_HIT, effect);
  if FxEngine.RemoveEffectWithMessage(tgt, C_EFFECT.POISONED) then begin
    GameVars.effectLock := 1;
    FxEngine.RemoveEffect(tgt, C_EFFECT.SLOW_POISON_END, nil);
    GameVars.effectLock := 0;
    if (tgt^.status = C_STATUS.DEAD) and not slowed then begin
      if tgt^.hpCur = 0 then
        tgt^.hpCur := 1;
      StandUpOrWake(tgt);
    end;
  end else if not Magic.RemoveDiseaseEffects(tgt) then begin
    if FxEngine.RestoreHitPoints(GameVars.targetCreaturePtr[1], Dice.RollDice(1, 4) + 8, False) then
      CharDisp.PrintNameStringAnim(GameVars.targetCreaturePtr[1], True, 'is Healed');
  end;
end;

{ Giant Strength: raise Strength to 21 and add the Strength effect, which keeps the Strength encoding
  AdjustForNewStrength returns. }
procedure GiantStrengthHandler;
var
  enc: Byte;
begin
  if FxEngine.AdjustForNewStrength(GameVars.targetCreaturePtr[1], 21, 0, enc) then
    CharDisp.PrintNameString(GameVars.targetCreaturePtr[1], 'is stronger', 10, True);
  FxEngine.AddEffect(GameVars.targetCreaturePtr[1], C_EFFECT.STRENGTH,
                     Magic.CalcSpellDuration(GameVars.currentSpellBeing), enc, True);
end;

{ Javelin of Lightning: 1d6 + 20 damage at the aim cell, then a 3-cell bolt of 20 damage. }
procedure JavelinOfLightningHandler;
var
  junk: Boolean;
begin
  Magic.LightningAttackAt(gTargetX, gTargetY, Dice.RollDice(1, 6) + 20, C_SAVE.SPELL, junk);
  Magic.LightningPath(3, 20, C_SAVE.SPELL, False);
end;

{ Wand of Paralyzation: apply the item's effect. }
procedure WandParalyzationHandler;
begin
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, False, 0, 0, 'is paralyzed');
end;

{ Potion of Healing: restore 2d4 + 2 hit points. }
procedure PotionOfHealingHandler;
begin
  if FxEngine.RestoreHitPoints(GameVars.targetCreaturePtr[1], Dice.RollDice(2, 4) + 2, False) then
    CharDisp.PrintNameStringAnim(GameVars.targetCreaturePtr[1], True, 'is Healed');
end;

{ Dust of Disappearance: apply the item's effect. }
procedure DustDisappearanceHandler;
begin
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, False, 0, 0, 'is invisible');
end;

{ Wand of Magic Missiles: 2d4 + 2 damage, element C_EFFECT.ELEM_MAGIC. }
procedure WandMagicMissilesHandler;
begin
  Magic.ResolveSpell(GameVars.currentSpellBeing, 0, False, Dice.RollDamageDice(2, 4) + 2, C_EFFECT.ELEM_MAGIC, '');
end;

{ Unused item spell slot: does nothing. }
procedure UnusedSpellHandler;
begin
end;

{ Manual of Bodily Health: apply the item's effect at strength 255. }
procedure ManualBodilyHealthHandler;
begin
  Magic.ResolveSpell(GameVars.currentSpellBeing, 255, True, 0, 0, 'is Reading');
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
  if GameVars.roundCounter <> 0 then
    if Dice.RollDice(1, 100) <= 50 then
      Exit;
  x := CbtMap.CombatCellX(creature);
  y := CbtMap.CombatCellY(creature);
  CharDisp.PrintNameString(creature, 'Breathes!', 10, True);
  GameVars.castTargetMenu(C_SPELL.LIGHTNING_BOLT, True, GameVars.breathAim);
  gTargetX := x + Pathing.SignOf(gTargetX - x);
  gTargetY := y + Pathing.SignOf(gTargetY - y);
  if gTargetX = x + 1 then
    Inc(gTargetX);
  if gTargetY = y + 1 then
    Inc(gTargetY);
  FxEngine.RemoveInvisibility(creature);
  CharDisp.BuildIconFacings(19);
  CharDisp.CombatAnimateMovingIcon(x, y, gTargetX, gTargetY, 4, 50);
  Magic.LightningAttackAt(gTargetX, gTargetY, creature^.hpMax, C_SAVE.BREATH, junk);
  Magic.LightningPath(10, creature^.hpMax, C_SAVE.BREATH, False);
  { Remaining breath charges }
  if Types.PEffectRec(p)^.strength > 253 then
    Dec(Types.PEffectRec(p)^.strength)
  else
    FxEngine.RemoveEffect(creature, C_EFFECT.DRAGON_BREATH, p);
  junk := CharHlp.EndActions(creature);
end;

procedure RemoveSpellFromScroll(cr, it: Pointer; spell: Byte);
var
  sp: Byte;
  i: Byte;
  found: Byte;
begin
  sp := spell and C_SPELL.ID_MASK;
  found := 0;
  { 3 = High(TItemRec.spells) }
  for i := 1 to 3 do
    if Types.PItemRec(it)^.spells[i] and C_SPELL.ID_MASK = sp then
      found := i;
  if found = 0 then
    Exit;
  Types.PItemRec(it)^.spells[found] := 0;
  { scroll spell-count name component }
  Dec(Types.PItemRec(it)^.nameIds[2]);
  if Types.PItemRec(it)^.nameIds[2] < C_ITEM.NAME_WITH_1_SPELL then
    CharHlp.RemoveItem(Types.PCharRecord(cr), Types.PItemRec(it));
end;

procedure PrintCastSpellMsg(creature: Types.PCharRecord; msg: Types.TStr40; spell: Byte);
begin
  if GameVars.ifcState = C_IFC.COMBAT then begin
    CharDisp.PrintNameString(creature, 'Casts a Spell', 10, True);
    { the combat log names the spell after the message (#841) }
    CbtLog.Add(LightGreen, ' (' + GameDefs.spellNames[spell] + ')');
    Border.ClearBox(0, 23, 39, 23);
    TextRend.DisplayString(0, 23, LightGreen, 'Spell:' + GameDefs.spellNames[spell]);
  end else begin
    Border.ClearBox(1, 18, 38, 22);
    CharDisp.DisplayCreatureName(creature, 1, 19, False);
    TextRend.DisplayString(Length(creature^.name) + 2, 19, LightGreen, msg);
    TextRend.DisplayString(1, 20, LightGreen, GameDefs.spellNames[spell]);
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
  notEmpty := Magic.GenerateSpellList(GameVars.curChar, menuType);
  if notEmpty then begin
    if idx < 0 then begin
      Border.DrawWindow(1, 1, 38, 1, 0, Black, '');
      CharDisp.DisplayCreatureName(GameVars.curChar, 1, 1, True);
      if menuType = 7 then
        s := 'Available Spells'
      else
        s := 'Spells ' + s;
      TextRend.DisplayString(Length(GameVars.curChar^.name) + 4, 1, LightGreen, s);
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

{ Cast spell from item, a scroll or an effect-bearing item (an effect past C_SPELL.LAST maps to spell effect -
  C_SPELL.ITEM_EFFECT_SHIFT), setting usingItem during the cast. A combat-only scroll spell outside combat is not cast:
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
  if not CharHlp.ItemReadable(item) and (spell > C_SPELL.LAST) then
    id := spell - C_SPELL.ITEM_EFFECT_SHIFT;
  if (id < 1) or (id > SizeOf(GameDefs.spellTable) div SizeOf(GameDefs.spellTable[1])) then begin
    done := False;
    Exit;
  end;
  if CharHlp.ItemReadable(item) and (GameVars.ifcState <> C_IFC.COMBAT) and
      (GameDefs.spellTable[spell].target = 0) then begin
    Magic.ShowCombatOnlySpell(spell);
    done := MenuCore.YesNoMenu('Use it? ', LightMagenta, White, LightGreen) = 'Y';
    CharDisp.ClearMessageWindow;
    if done then
      Magic.RemoveSpellFromScroll(GameVars.curChar, item, spell);
    Exit;
  end;
  if (GameVars.ifcState = C_IFC.COMBAT) and (GameVars.curChar^.quickfight = 0) then
    CharDisp.DisplayCombatInterface;
  if not CharHlp.ItemReadable(item) then begin
    if spell > C_SPELL.LAST then
      { item effect -> spell id }
      Dec(spell, C_SPELL.ITEM_EFFECT_SHIFT);
    CharDisp.PrintNameString(GameVars.curChar, 'uses an item', 10, False);
    if GameVars.ifcState = C_IFC.COMBAT then begin
      TextRend.DisplayString(0, 23, LightGreen, 'Item:');
      CharDisp.PrintItemLabel(item, 5, 23);
    end else
      CharDisp.PrintItemLabel(item, 1, 22);
    TextRend.PauseOnly;
    CharDisp.ClearMessageWindow;
  end;
  GameVars.usingItem := True;
  if announce then
    Magic.PrintCastSpellMsg(GameVars.curChar, 'casts', spell);
  cast := False;
  Magic.CastSpellNC(spell, Boolean(GameVars.curChar^.quickfight), False, cast);
  GameVars.usingItem := False;
  done := cast;
  if GameVars.ifcState = C_IFC.COMBAT then
    if GameDefs.spellTable[spell].whenCast <> 0 then
      done := CharHlp.EndActions(GameVars.curChar);
  if cast then begin
    if CharHlp.ItemReadable(item) then
      Magic.RemoveSpellFromScroll(GameVars.curChar, item, spell)
    else if item^.charges > 0 then begin
      if item^.quantity > 1 then
        Dec(item^.quantity)
      else begin
        Dec(item^.charges);
        if item^.charges = 0 then
          CharHlp.RemoveItem(GameVars.curChar, item);
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
  GameVars.usingItem := False;
  spell := 0;
  if CharHlp.ItemReadable(item) then begin
    currentScrollPtr := item;
    spell := Magic.SpellMenu(2, 1, idx, notEmpty);
  end else if (item^.effect > 0) and (item^.special < $80) then
    spell := item^.effect;
  if spell = 0 then
    done := False
  else
    Magic.UseItemSpell(item, spell, False, done);
end;

begin
  { Turbo Pascal clears no variable }
  gTargetX := 0;
  gTargetY := 0;
  @belowListHook := nil;
  scrollList := False;
end.

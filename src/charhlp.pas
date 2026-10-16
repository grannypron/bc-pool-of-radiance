{ Shared creature operations: statistics, equipment, inventory, damage, targeting and party display. }
{$O+,F+}
unit CharHlp;

interface

uses Types;

procedure WeaponAdjust(creature: Types.PCharRecord);

procedure ArmorMoveAdjust(creature: Types.PCharRecord; item: Types.PItemRec);

procedure ArmorAdjustHelper(creature: Types.PCharRecord; item: Types.PItemRec; adj: Types.PAcAdjust;
                            isMagicBody: Types.PBoolean; var ringSave: ShortInt);

procedure EncumbranceAdjust(creature: Types.PCharRecord);

procedure PrintItemString(item: Types.PItemRec; col, row: Byte; isInv, doPrint: Boolean);

function IsHelpless(creature: Types.PCharRecord): Boolean;

{ Point creature's equipment slots at its readied items (RecalcStats does this first; a character just loaded needs it
  alone). }
procedure LinkEquipped(creature: Types.PCharRecord);

procedure RecalcStats(creature: Types.PCharRecord);

procedure RemoveSpell(creature: Types.PCharRecord; spell: Byte);

procedure RemoveItem(creature: Types.PCharRecord; item: Types.PItemRec);

{ Free every item in list and leave it nil. }
procedure FreeItemList(var list: Types.PItemRec);

{ Put a heap copy of item at the front of list: list then points at the copy, which links to the old front. Copying a
  list item by item this way reverses its order, as SSI's copies did. }
procedure PrependItemCopy(var list: Types.PItemRec; item: Types.PItemRec);

{ The same for an effect. }
procedure PrependEffectCopy(var list: Types.PEffectRec; effect: Types.PEffectRec);

{ Empty the treasure on the table: free its items and zero its money. }
procedure ClearTreasure;

{ Put a heap copy of item at the end of list. The caller checks there is room (a creature's 16 items). }
procedure AppendItemCopy(var list: Types.PItemRec; item: Types.PItemRec);

function HasEffect(creature: Types.PCharRecord; id: Byte; var effect: Types.PEffectRec): Boolean;

procedure InflictDamage(creature: Types.PCharRecord; dmg: Byte);

function EnemyTeam(creature: Types.PCharRecord): ShortInt;

procedure CountTeams;

function CountTargets(creature: Types.PCharRecord; range: Byte): Byte;

function CalcDistance(creature, other: Types.PCharRecord): Byte;

function EndActions(creature: Types.PCharRecord): Boolean;

function CanUseItems(creature: Types.PCharRecord): Boolean;

function Guard(creature: Types.PCharRecord): Boolean;

function GetCasterLevel(spell: Byte): Byte;

function HasRangedWeapon(creature: Types.PCharRecord): Boolean;

function HasThrowableWeapon(creature: Types.PCharRecord): Boolean;

function FindDamagingRangedWeapon(creature: Types.PCharRecord; var sel: Types.PItemRec): Boolean;

function AtLevelCap(creature: Types.PCharRecord; cls: ShortInt): Boolean;

{ True when the creature has enough experience to train a level in some class: the training hall's own test (not at the
  racial cap, a next level in the experience table, and the experience for it), ignoring the fee and the hall. }
function CanTrain(creature: Types.PCharRecord): Boolean;

function HasBagOfHolding(creature: Types.PCharRecord): Boolean;

function RawWeight(creature: Types.PCharRecord): LongInt;

{ The weight of an item in coins: its weight is per piece, so a stack weighs weight * quantity (quantity 0 is a single
  unstacked item). }
function ItemWeight(item: Types.PItemRec): LongInt;

{ The highest of the creature's fighter, paladin and ranger levels, or 0 when it has none: the level at which it
  fights as a warrior. }
function WarriorLevel(creature: Types.PCharRecord): ShortInt;

{ The hit points Constitution con gives creature over all its hit dice, as creation and training bank them (CharGen's
  ConHpBonus at each level): each class's GDConsts.conBonusTbl share, plus 1 at Con 17 and 1 more at 18 for a
  single-class fighter, paladin or ranger, once per level (a ranger's level + 1), divided by the class count. A
  Constitution outside the table's 3..20 uses the nearer end. The difference between two Constitutions is the
  hit-point change a change of Constitution makes. }
function ConHpTotal(creature: Types.PCharRecord; con: Byte): Integer;

{ The base item record for an item type: its GDVars.baseItems entry, or the zeroed GDVars.baseItemsOverflow for a type
  past the table, which only damaged save or monster data can carry.
  @param(itemType TItemRec.itemType.)
  @returns(A pointer to the record; the caller does not change it.) }
function BaseItem(itemType: Byte): Types.PBaseItemRec;

{ True for an NPC or a monster: a creature whose npc has bit 7 (C_Npc.FLAG) set, not one of the player's own
  characters. }
function IsNpc(creature: Types.PCharRecord): Boolean;

{ True when creature may trade and sell: one of the player's own characters, or an NPC that is disabled or animated. }
function MayTrade(creature: Types.PCharRecord): Boolean;

{ True for one of the player's own characters that is not animated: the creatures Space in combat, and Quick Ends
  With Fight after it, return to the player's control. }
function ComesUnderPlayer(creature: Types.PCharRecord): Boolean;

{ True when it is non-nil and its base item's slot is 11, 12 or 13. }
function ItemReadable(it: Pointer): Boolean;

{ True when creature can read item's spells, that is when the scroll is identified. Read Magic (effect 16), or any
  cleric level with a scroll whose base item slot is 12, identifies it first. }
function ScrollLegible(creature: Types.PCharRecord; item: Types.PItemRec): Boolean;

function ScrollSpellAt(item: Types.PItemRec; slot: Byte): Byte;

{ True when item is a scroll creature can read (ScrollLegible) and could use: readied, or of a class Ready accepts. The
  two hands a readied scroll takes are not asked for. The Cast list offers these scrolls' spells, and Items > Use takes
  them unreadied. }
function CastableScroll(creature: Types.PCharRecord; item: Types.PItemRec): Boolean;

{ True when the creature may use items now (CharHlp.CanUseItems) and holds a scroll it can read and use with a spell on
  it: the scroll spells the Cast list offers. }
function HasScrollSpells(creature: Types.PCharRecord): Boolean;

{ Spell range: rangeFixed + rangeVar * caster level, using caster level 6 when GDVars.usingItem. A zero range with a
  nonzero area (touch) and the 255 attack-roll encoding both become 1. }
function CalcSpellRange(spell: Byte): Byte;

implementation

uses Crt, C_Item, GDConsts, GDVars, Pathing, CbtMap, C_Effect, C_Equip, C_Race, C_Class, C_Level, C_Status, C_Ifc,
  C_Money, Stats, TextRend, C_Npc, StrUtil, AbilAdj, C_Spell;

{ With a readied weapon, recompute to-hit and the primary attack's damage. thac0Cur restarts from thac0Base plus the
  Dexterity missile adjustment (C_Item.PROP_DEX_MISSILE) and Strength to-hit (C_Item.PROP_STR_BONUS); the damage dice
  and modifier come from the base item's small/medium entry plus Strength damage (C_Item.PROP_STR_BONUS). The weapon's
  plus, and that of readied quarrels or arrows when the weapon fires them, is added to both. An elf gets a further +1
  to-hit with a bow (item types 41..44), a long sword (36) or a short sword (37). Type 45 is the Heavy Crossbow's row,
  but the Fine Composite Long Bow is also built on it; it counts as a bow when its second name component is a bow's
  name (41..44), which a Heavy Crossbow never carries. }
procedure WeaponAdjust(creature: Types.PCharRecord);
var
  w: Types.PItemRec;
  wtype: Byte;
  plus: ShortInt;
begin
  w := creature^.equipped[C_Equip.WEAPON];
  if w = nil then Exit;
  wtype := w^.itemType;
  creature^.thac0Cur := creature^.thac0Base;
  if (CharHlp.BaseItem(wtype)^.props and C_Item.PROP_DEX_MISSILE) <> 0 then
    creature^.thac0Cur := AbilAdj.DexMissileAdjust(creature) + creature^.thac0Cur;
  creature^.curModA[1] := CharHlp.BaseItem(wtype)^.dmgSmMod;
  if (CharHlp.BaseItem(wtype)^.props and C_Item.PROP_STR_BONUS) <> 0 then begin
    creature^.thac0Cur := AbilAdj.StrToHitAdjust(creature) + creature^.thac0Cur;
    creature^.curModA[1] := AbilAdj.StrDamageAdjust(creature) + creature^.curModA[1];
  end;
  plus := w^.plus;
  { C_Item.PROP_QUARRELS: the weapon fires quarrels }
  if CharHlp.BaseItem(wtype)^.props > $7F then
    if creature^.equipped[C_Equip.BOLT] <> nil then
      plus := plus + creature^.equipped[C_Equip.BOLT]^.plus;
  if (CharHlp.BaseItem(wtype)^.props and C_Item.PROP_ARROWS) > 0 then
    if creature^.equipped[C_Equip.ARROW] <> nil then
      plus := plus + creature^.equipped[C_Equip.ARROW]^.plus;
  creature^.curModA[1] := creature^.curModA[1] + plus;
  if (creature^.race = C_Race.ELF) and
      (((w^.itemType > 40) and (w^.itemType < 45)) or (w^.itemType = 37) or (w^.itemType = 36) or
       ((w^.itemType = 45) and (w^.nameIds[2] in [41..44]))) then
    Inc(plus);
  creature^.thac0Cur := creature^.thac0Cur + plus;
  creature^.curRollsA[1] := CharHlp.BaseItem(wtype)^.dmgSmRolls;
  creature^.curDiceA[1] := CharHlp.BaseItem(wtype)^.dmgSmDice;
end;

{ Body armor only (base slot 2): set current movement from the armor's weight (0..150 = base movement, 151..399 = 9,
  heavier = 6), then +3 if the armor has a nonzero plus and the movement is still <= 9. }
procedure ArmorMoveAdjust(creature: Types.PCharRecord; item: Types.PItemRec);
begin
  if CharHlp.BaseItem(item^.itemType)^.slot = C_Equip.ARMOR then begin
    case item^.weight of
      0..150: creature^.movementCur := creature^.movementBase;
      151..399: creature^.movementCur := 9;
    else
      creature^.movementCur := 6;
    end;
    if (item^.plus <> 0) and (creature^.movementCur <= 9) then
      creature^.movementCur := creature^.movementCur + 3;
  end;
end;

{ Fold one equipped item into the AC adjustment slots. Only items whose base acDescr >= 128 participate; descr's low 7
  bits are the item's own AC value. A shield (slot 1) sets adj[1] to AC + plus. An item with AC 0 adds its saveBonus to
  the creature's and its plus to adj[2], except a ring (slot 9), whose plus instead raises adj[3] to the best ring
  plus, and whose plus or saveBonus, whichever is larger, raises ringSave to the best ring's save bonus (RecalcStats
  adds it once). Any other item keeps the best AC + plus in adj[4], setting isMagicBody when that new best is body
  armor (slot 2) with a positive plus. }
procedure ArmorAdjustHelper(creature: Types.PCharRecord; item: Types.PItemRec; adj: Types.PAcAdjust;
                            isMagicBody: Types.PBoolean; var ringSave: ShortInt);
var
  descr: Byte;
  slot: Byte;
begin
  descr := CharHlp.BaseItem(item^.itemType)^.acDescr;
  if descr > $7F then begin
    descr := descr and $7F;
    slot := CharHlp.BaseItem(item^.itemType)^.slot;
    if slot = C_Equip.SHIELD then
      adj^[1] := descr + item^.plus
    else if descr = 0 then begin
      if slot = C_Equip.RING1 then begin
        if item^.plus > adj^[3] then
          adj^[3] := item^.plus;
        if item^.plus > ringSave then
          ringSave := item^.plus;
        if item^.saveBonus > ringSave then
          ringSave := item^.saveBonus;
      end else begin
        adj^[2] := adj^[2] + item^.plus;
        creature^.saveBonus := creature^.saveBonus + item^.saveBonus;
      end;
    end else begin
      if descr + item^.plus > adj^[4] then begin
        adj^[4] := descr + item^.plus;
        if item^.plus > 0 then
          if slot = C_Equip.ARMOR then
            isMagicBody^ := True;
      end;
    end;
  end;
end;

{ Clamp movement by how many coins the creature carries over its weight allowance: within 512 over keeps the current
  movement, each further 256-coin band steps down (9 / 6 / 3), and the result only ever lowers movementCur. }
procedure EncumbranceAdjust(creature: Types.PCharRecord);
var
  over: LongInt;
  movement: Byte;
begin
  over := LongInt(creature^.encumbrance) - AbilAdj.WeightAllowance(creature);
  if over < 0 then
    over := 0;
  case over of
    0..512: movement := creature^.movementCur;
    513..768: movement := 9;
    769..1024: movement := 6;
  else
    movement := 3;
  end;
  if movement < creature^.movementCur then
    creature^.movementCur := movement;
end;

{ Build the item label in item^.name: the ' Yes  '/' No   ' equipped marker (inventory listings only), a '*' when
  any creature in the list has Detect Magic and the item has a plus, a save bonus or a curse, the quantity when
  nonzero, then the identified name components from 3 down to 1, one of them pluralized with 's' when the quantity
  is 2 or more. Optionally print it in light green at the requested position. }
procedure PrintItemString(item: Types.PItemRec; col, row: Byte; isInv, doPrint: Boolean);
var
  i: Byte;
  mask: Byte;
  effect: Types.PEffectRec;
  found: Boolean;
  appended: Boolean;
  p: Types.PCharRecord;
begin
  item^.name := '';
  if isInv then begin
    if item^.equipped <> 0 then
      item^.name := ' Yes  '
    else
      item^.name := ' No   ';
  end;
  found := False;
  p := GDVars.creatureList;
  while (p <> nil) and not found do begin
    if CharHlp.HasEffect(p, C_Effect.DETECT_MAGIC, effect) then
      found := True;
    p := p^.nextCharAddr;
  end;
  if found then
    if (item^.plus > 0) or (item^.saveBonus > 0) or (item^.cursed <> 0) then
      item^.name := item^.name + '*' + ' ';
  if item^.quantity > 0 then
    item^.name := item^.name + StrUtil.NumStr(item^.quantity) + ' ';
  mask := 0;
  for i := 1 to 3 do
    if item^.nameIds[i] <> 0 then
      if (item^.unidMask shr (3 - i)) and 1 = 0 then
        Inc(mask, 1 shl (i - 1));
  appended := False;
  for i := 3 downto 1 do
    if (mask shr (i - 1)) and 1 > 0 then begin
      item^.name := item^.name + GDConsts.nameParts[item^.nameIds[i]];
      if (item^.quantity < 2) or appended then
        item^.name := item^.name + ' '
      { Name component 177 is 'Silver' }
      else if ((1 shl (i - 1)) = mask) or ((i = 1) and (mask > 4) and (item^.itemType <> C_Item.FLASK_OF_OIL)) or
        ((i = 2) and not Odd(mask)) or ((i = 3) and (item^.itemType = C_Item.FLASK_OF_OIL)) or
        (((item^.itemType = 73) or (item^.itemType = 28)) and (item^.nameIds[3] <> 177)) then begin
        item^.name := item^.name + 's ';
        appended := True;
      end else
        item^.name := item^.name + ' ';
    end;
  if doPrint then
    TextRend.DisplayString(col, row, LightGreen, item^.name);
end;

{ Return True if any of the four helplessness effects in GDConsts.helplessFx is active on the creature. }
function IsHelpless(creature: Types.PCharRecord): Boolean;
var
  i: Byte;
  effect: Types.PEffectRec;
begin
  IsHelpless := False;
  for i := 1 to 4 do
    if CharHlp.HasEffect(creature, GDConsts.helplessFx[i], effect) then
      IsHelpless := True;
end;

{ Point creature's equipment slots at its readied items, every other slot nil: a second ring goes in RING2, arrows
  (item type 73) and bolts (28) in their own slots as well as their base item's. }
procedure LinkEquipped(creature: Types.PCharRecord);
var
  i: ShortInt;
  item: Types.PItemRec;
  slot: 0..127;
begin
  for i := C_Equip.WEAPON to C_Equip.BOLT do
    creature^.equipped[i] := nil;
  item := creature^.itemsAddr;
  while item <> nil do begin
    if item^.equipped <> 0 then begin
      slot := CharHlp.BaseItem(item^.itemType)^.slot;
      case Byte(slot) of
        C_Equip.WEAPON..C_Equip.BOOTS: creature^.equipped[slot] := item;
        C_Equip.RING1:
          if creature^.equipped[C_Equip.RING1] <> nil then begin
            if creature^.equipped[C_Equip.RING2] = nil then
              creature^.equipped[C_Equip.RING2] := item;
          end else
            creature^.equipped[C_Equip.RING1] := item;
      end;
      if item^.itemType = 73 then
        creature^.equipped[C_Equip.ARROW] := item;
      if item^.itemType = 28 then
        creature^.equipped[C_Equip.BOLT] := item;
    end;
    item := item^.next;
  end;
end;

{ Rebuild equipment slots (LinkEquipped) and encumbrance, apply strength, dexterity and item adjustments, then
  calculate armor class, rear armor class (no Dexterity or shield), attack level (CharHlp.WarriorLevel for a non-monster
  warrior, else 1) and movement. An equipped Bag of Holding (name component 'Holding') removes up to 5000 coins of
  encumbrance, never leaving less than the equipped items' weight. The weight is summed in 32 bits and stored as at most
  65535. }
procedure RecalcStats(creature: Types.PCharRecord);
var
  j: Byte;
  k: ShortInt;
  item: Types.PItemRec;
  magicBody: Boolean;
  bag: Boolean;
  adj: Types.TAcAdjust;
  c: ShortInt;
  w: LongInt;
  raw: LongInt;
  ringSave: ShortInt;
begin
  CharHlp.LinkEquipped(creature);
  bag := False;
  creature^.numberOfItems := 0;
  item := creature^.itemsAddr;
  creature^.handsEquipped := 0;
  raw := 0;
  GDVars.gEquipWeight := 0;
  while item <> nil do begin
    Inc(creature^.numberOfItems);
    w := CharHlp.ItemWeight(item);
    Inc(raw, w);
    if item^.equipped <> 0 then begin
      Inc(GDVars.gEquipWeight, w);
      { Name component 186 is 'Holding' }
      if item^.nameIds[1] = 186 then
        bag := True;
      creature^.handsEquipped := creature^.handsEquipped + CharHlp.BaseItem(item^.itemType)^.hands;
    end;
    item := item^.next;
  end;
  for c := C_Money.COPPER to C_Money.JEWELRY do
    Inc(raw, creature^.coins[c]);
  for j := 1 to 2 do begin
    creature^.curRollsA[j] := creature^.unarmedRollsA[j];
    creature^.curDiceA[j] := creature^.unarmedDiceA[j];
    creature^.curModA[j] := creature^.unarmedModA[j];
  end;
  { adj: 0 Dexterity, 1 shield, 2 pluses of AC-0 items, 3 best ring, 4 best armor }
  for k := 0 to 4 do
    adj[k] := 0;
  magicBody := False;
  creature^.saveBonus := 0;
  ringSave := 0;
  creature^.acCur := creature^.acBase;
  creature^.movementCur := creature^.movementBase;
  creature^.thac0Cur := creature^.thac0Base;
  adj[0] := AbilAdj.DexterityArmorAdjustment(creature);
  if creature^.equipped[C_Equip.WEAPON] = nil then begin
    creature^.thac0Cur := AbilAdj.StrToHitAdjust(creature) + creature^.thac0Cur;
    creature^.curModA[1] := AbilAdj.StrDamageAdjust(creature) + creature^.curModA[1];
  end;
  CharHlp.WeaponAdjust(creature);
  item := creature^.itemsAddr;
  while item <> nil do begin
    if item^.equipped <> 0 then begin
      CharHlp.ArmorMoveAdjust(creature, item);
      CharHlp.ArmorAdjustHelper(creature, item, @adj, @magicBody, ringSave);
    end;
    item := item^.next;
  end;
  { a Ring of Protection guards saves as well as AC: the best ring counts once, and magical body armor cancels only
    its AC }
  creature^.saveBonus := creature^.saveBonus + ringSave;
  { rings do not add to magical body armor }
  if magicBody then
    adj[3] := 0;
  if bag then begin
    if raw < 5000 then
      raw := 0
    else
      Dec(raw, 5000);
    if raw < GDVars.gEquipWeight then
      raw := GDVars.gEquipWeight;
  end;
  if raw > 65535 then
    raw := 65535;
  creature^.encumbrance := raw;
  CharHlp.EncumbranceAdjust(creature);
  if adj[4] < creature^.acCur then
    adj[4] := creature^.acCur;
  creature^.acCur := 0;
  for k := 0 to 4 do
    creature^.acCur := creature^.acCur + adj[k];
  creature^.acBehind := adj[4] + adj[2] + adj[3] - 1 - 1;
  if (CharHlp.WarriorLevel(creature) > 0) and (creature^.race > C_Race.MONSTER) then
    creature^.attackLevel := CharHlp.WarriorLevel(creature)
  else
    creature^.attackLevel := 1;
end;

{ True when the creature has a Bag of Holding readied (name component 186 is 'Holding'). }
function HasBagOfHolding(creature: Types.PCharRecord): Boolean;
var
  item: Types.PItemRec;
begin
  HasBagOfHolding := False;
  item := creature^.itemsAddr;
  while item <> nil do begin
    if (item^.equipped <> 0) and (item^.nameIds[1] = 186) then
      HasBagOfHolding := True;
    item := item^.next;
  end;
end;

{ The creature's weight in coins before a Bag of Holding takes its share: every item (weight times quantity) and every
  coin, gem and piece of jewelry, as RecalcStats adds them up. }
function RawWeight(creature: Types.PCharRecord): LongInt;
var
  item: Types.PItemRec;
  w: LongInt;
  c: ShortInt;
begin
  w := 0;
  item := creature^.itemsAddr;
  while item <> nil do begin
    Inc(w, CharHlp.ItemWeight(item));
    item := item^.next;
  end;
  for c := C_Money.COPPER to C_Money.JEWELRY do
    Inc(w, creature^.coins[c]);
  RawWeight := w;
end;

function ItemWeight(item: Types.PItemRec): LongInt;
begin
  if item^.quantity > 0 then
    ItemWeight := LongInt(item^.quantity) * item^.weight
  else
    ItemWeight := item^.weight;
end;

{ Clear the first memorized-spell slot holding spell on the creature. }
procedure RemoveSpell(creature: Types.PCharRecord; spell: Byte);
var
  i: Byte;
begin
  i := 0;
  { scan the memorized-spell slots, stopping after the first match }
  while i <= Types.SPELL_SLOT_LAST do begin
    if creature^.memorizedSpells[i] = spell then begin
      creature^.memorizedSpells[i] := 0;
      i := Types.SPELL_SLOT_LAST + 1;
    end;
    Inc(i);
  end;
end;

procedure FreeItemList(var list: Types.PItemRec);
var
  next: Types.PItemRec;
begin
  while list <> nil do begin
    next := list^.next;
    FreeMem(list, SizeOf(Types.TItemRec));
    list := next;
  end;
end;

procedure PrependItemCopy(var list: Types.PItemRec; item: Types.PItemRec);
var
  n: Types.PItemRec;
begin
  GetMem(n, SizeOf(Types.TItemRec));
  n^ := item^;
  n^.next := list;
  list := n;
end;

procedure PrependEffectCopy(var list: Types.PEffectRec; effect: Types.PEffectRec);
var
  n: Types.PEffectRec;
begin
  GetMem(n, SizeOf(Types.TEffectRec));
  n^ := effect^;
  n^.next := list;
  list := n;
end;

procedure ClearTreasure;
begin
  CharHlp.FreeItemList(GDVars.treasureItems);
  FillChar(GDVars.treasureMoney, SizeOf(GDVars.treasureMoney), 0);
end;

{ Unlink an item from the creature's inventory list and free it; a nil item or one not in the list only gets an error
  message. }
procedure RemoveItem(creature: Types.PCharRecord; item: Types.PItemRec);
var
  p: Types.PItemRec;
begin
  if item = nil then
    TextRend.DisplayAndPause(Yellow, 'Nil Item pointer...')
  else begin
    p := creature^.itemsAddr;
    if p = item then
      creature^.itemsAddr := item^.next
    else
      while (p <> nil) and (p^.next <> item) do
        p := p^.next;
    if p = nil then
      TextRend.DisplayAndPause(Yellow, 'Tried to Lose item & couldn''t find it!')
    else begin
      p^.next := item^.next;
      item^.next := nil;
      FreeMem(item, SizeOf(Types.TItemRec));
    end;
  end;
end;

procedure AppendItemCopy(var list: Types.PItemRec; item: Types.PItemRec);
var
  p: Types.PItemRec;
  n: Types.PItemRec;
begin
  GetMem(n, SizeOf(Types.TItemRec));
  Move(item^, n^, SizeOf(Types.TItemRec));
  n^.next := nil;
  p := list;
  if p = nil then
    list := n
  else begin
    while p^.next <> nil do
      p := p^.next;
    p^.next := n;
  end;
end;

{ True when the creature carries effect id; effect is left on the matching node, or nil. }
function HasEffect(creature: Types.PCharRecord; id: Byte; var effect: Types.PEffectRec): Boolean;
var
  found: Boolean;
begin
  found := False;
  effect := creature^.effectsAddr;
  while (effect <> nil) and not found do begin
    if effect^.id = id then
      found := True
    else
      effect := effect^.next;
  end;
  HasEffect := found;
end;

{ Apply damage and update status. More than nine points of overkill kills; lesser overkill leaves the creature dying.
  Exactly zero hit points leaves it unconscious, except an animated creature dies. A creature that is no longer okay or
  animated is taken out of action, and in combat also out of its team count and the initiative order. A dead, stoned or
  gone creature takes no damage, so a small hit on a corpse cannot turn it back into a dying one. }
procedure InflictDamage(creature: Types.PCharRecord; dmg: Byte);
var
  over: Byte;
  remain: Byte;
  wasUp: Boolean;
  hpBefore: Byte;
begin
  if creature^.status in [C_Status.DEAD, C_Status.STONED, C_Status.GONE] then Exit;
  wasUp := creature^.status in [C_Status.OKAY, C_Status.ANIMATED];
  hpBefore := creature^.hpCur;
  over := 0;
  remain := 0;
  if creature^.hpCur >= dmg then
    remain := creature^.hpCur - dmg
  else
    over := dmg - creature^.hpCur;
  if (over > 9) or ((remain = 0) and (creature^.status = C_Status.ANIMATED)) then
    creature^.status := C_Status.DEAD
  else if over > 0 then begin
    creature^.status := C_Status.DYING;
    if GDVars.ifcState = C_Ifc.COMBAT then
      creature^.combatAddr^.overkill := over;
  end else if remain = 0 then
    creature^.status := C_Status.UNCONSCIOUS;
  if not (creature^.status in [C_Status.OKAY, C_Status.ANIMATED]) then begin
    creature^.enabled := 0;
    creature^.hpCur := 0;
    if GDVars.ifcState = C_Ifc.COMBAT then begin
      { a creature already down (dying or unconscious) left its team count when it fell }
      if wasUp then
        Dec(GDVars.teamCount[creature^.hostile]);
      creature^.combatAddr^.initiative := 0;
    end;
  end else
    creature^.hpCur := remain;
  { the statistics (#611), credited to the creature acting }
  Stats.Damaged(GDVars.curChar, creature, hpBefore - creature^.hpCur, wasUp);
end;

{ Return the opposing team index: 1 for a friendly creature (hostile = 0), else 0. }
function EnemyTeam(creature: Types.PCharRecord): ShortInt;
begin
  if creature^.hostile = 0 then
    EnemyTeam := 1
  else
    EnemyTeam := 0;
end;

{ Recount the creatures still in action on each team. }
procedure CountTeams;
var
  p: Types.PCharRecord;
begin
  GDVars.teamCount[0] := 0;
  GDVars.teamCount[1] := 0;
  p := GDVars.creatureList;
  while p <> nil do begin
    if p^.enabled <> 0 then
      Inc(GDVars.teamCount[p^.hostile]);
    p := p^.nextCharAddr;
  end;
end;

{ Build the potential-target list around creature within range, keep only creatures on the opposing team, and copy their
  indices into GDVars.dsPotentialTargetCreature. Return the remaining count. }
function CountTargets(creature: Types.PCharRecord; range: Byte): Byte;
var
  n: Byte;
  cnt: Byte;
  i: Byte;
begin
  Pathing.BuildTargetList(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), range, 255,
                          CbtMap.GetIconSize(creature), GDVars.arenaPtr);
  n := GDVars.targetCount;
  cnt := 0;
  if n > 0 then begin
    for i := 1 to n do
      if CharHlp.EnemyTeam(creature) = GDVars.creatureArr[GDVars.targetList[i].idx]^.hostile then begin
        Inc(cnt);
        Move(GDVars.targetList[i], GDVars.targetList[cnt], SizeOf(GDVars.targetList[i]));
      end;
    n := cnt;
    GDVars.targetCount := cnt;
  end;
  CountTargets := n;
  for i := 1 to n do
    GDVars.dsPotentialTargetCreature[i] := GDVars.targetList[i].idx;
end;

{ Find the distance to another creature by temporarily rebuilding the target list with terrain ignored (distMode 1).
  Restore the previous list afterward. Stored distances are doubled, so halve the result; 255 when other is not in the
  list (nil, or off the map). The list's count is restored with it (SSI left the rebuilt list's count). }
function CalcDistance(creature, other: Types.PCharRecord): Byte;
var
  saved: array[1..255] of Types.TCombatTarget;
  savedCount: Byte;
  i: Byte;
begin
  Move(GDVars.targetList, saved, SizeOf(GDVars.targetList));
  savedCount := GDVars.targetCount;
  GDVars.arenaPtr^.distMode := 1;
  Pathing.BuildTargetList(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 255, 255,
                          CbtMap.GetIconSize(creature), GDVars.arenaPtr);
  GDVars.arenaPtr^.distMode := 0;
  i := 1;
  while (GDVars.creatureArr[GDVars.targetList[i].idx] <> other) and (i < GDVars.targetCount) do
    Inc(i);
  if GDVars.creatureArr[GDVars.targetList[i].idx] = other then
    CalcDistance := GDVars.targetList[i].dist shr 1
  else
    CalcDistance := 255;
  Move(saved, GDVars.targetList, SizeOf(GDVars.targetList));
  GDVars.targetCount := savedCount;
end;

{ Zero the creature's per-round combat state (initiative, spell being cast, guarding, movement). Always returns True. }
function EndActions(creature: Types.PCharRecord): Boolean;
begin
  creature^.combatAddr^.initiative := 0;
  creature^.combatAddr^.spellCast := 0;
  creature^.combatAddr^.guarding := 0;
  creature^.combatAddr^.movement := 0;
  EndActions := True;
end;

{ True when the creature may use an item now: an able character outside an anti-magic area, in camp, outdoors or
  indoors, or in combat while still allowed an item this round. }
function CanUseItems(creature: Types.PCharRecord): Boolean;
begin
  CanUseItems := (creature^.enabled <> 0) and (GDVars.zone0^.antimagic = 0) and
                 ((GDVars.ifcState = C_Ifc.CAMPING) or (GDVars.ifcState = C_Ifc.OUTDOORS) or
                  (GDVars.ifcState = C_Ifc.INDOORS) or
                  ((GDVars.ifcState = C_Ifc.COMBAT) and (creature^.combatAddr^.itemUseAllowed <> 0)));
end;

{ End the creature's round and raise its guarding flag; the caller announces it ('Guarding'). Always returns True. }
function Guard(creature: Types.PCharRecord): Boolean;
begin
  Guard := CharHlp.EndActions(creature);
  creature^.combatAddr^.guarding := 1;
end;

{ Caster level for a spell id: the current character's cleric or magic-user level by casting class (12 for class 2, the
  special class), forced to 6 when cast from an item (GDVars.usingItem) unless the class is 2. }
function GetCasterLevel(spell: Byte): Byte;
begin
  case GDConsts.spellTable[spell].castClass of
    0: GetCasterLevel := GDVars.curChar^.classLevels[C_Level.CLERIC];
    1: GetCasterLevel := GDVars.curChar^.classLevels[C_Level.MAGE];
    2: GetCasterLevel := 12;
  end;
  if GDVars.usingItem and (GDConsts.spellTable[spell].castClass <> 2) then
    GetCasterLevel := 6;
end;

{ True when the readied weapon has a range past 1 (thrown weapons count). }
function HasRangedWeapon(creature: Types.PCharRecord): Boolean;
begin
  if (creature^.equipped[C_Equip.WEAPON] <> nil) and
      (CharHlp.BaseItem(creature^.equipped[C_Equip.WEAPON]^.itemType)^.range > 1) then
    HasRangedWeapon := True
  else
    HasRangedWeapon := False;
end;

{ True when the readied weapon is ranged and carries both C_Item.PROPS_THROWABLE bits (thrown, Strength bonus). }
function HasThrowableWeapon(creature: Types.PCharRecord): Boolean;
begin
  if CharHlp.HasRangedWeapon(creature) and
      ((CharHlp.BaseItem(creature^.equipped[C_Equip.WEAPON]^.itemType)^.props and
        C_Item.PROPS_THROWABLE) = C_Item.PROPS_THROWABLE) then
    HasThrowableWeapon := True
  else
    HasThrowableWeapon := False;
end;

{ Find the item that does the damage for a ranged attack: the readied weapon itself if C_Item.PROP_THROWN, else the
  arrows (equipped[C_Equip.ARROW]) with a bow (C_Item.PROP_ARROWS) or the quarrels (equipped[C_Equip.BOLT]) with a
  crossbow (C_Item.PROP_QUARRELS). A launcher with neither ammunition bit (props exactly C_Item.PROP_DEX_MISSILE +
  C_Item.PROP_FIRES_AMMO) returns True with sel nil; a pure melee weapon or a launcher with no ammunition readied
  returns False. }
function FindDamagingRangedWeapon(creature: Types.PCharRecord; var sel: Types.PItemRec): Boolean;
var
  w: Types.PItemRec;
  props: Byte;
begin
  FindDamagingRangedWeapon := False;
  w := creature^.equipped[C_Equip.WEAPON];
  sel := nil;
  props := 0;
  if w <> nil then begin
    props := CharHlp.BaseItem(w^.itemType)^.props;
    if (props and C_Item.PROP_THROWN) <> 0 then
      sel := w;
    if (props and C_Item.PROP_FIRES_AMMO) <> 0 then begin
      if (props and C_Item.PROP_ARROWS) <> 0 then
        sel := creature^.equipped[C_Equip.ARROW];
      if (props and C_Item.PROP_QUARRELS) <> 0 then
        sel := creature^.equipped[C_Equip.BOLT];
    end;
  end;
  if (sel <> nil) or (props = C_Item.PROP_DEX_MISSILE + C_Item.PROP_FIRES_AMMO) then
    FindDamagingRangedWeapon := True;
end;

function CanTrain(creature: Types.PCharRecord): Boolean;
var
  cls: ShortInt;
  lvl: ShortInt;
begin
  CanTrain := False;
  for cls := C_Level.CLERIC to C_Level.MONK do begin
    lvl := creature^.classLevels[cls];
    { xp[] runs to level 9 }
    if (lvl > 0) and (lvl < 9) then
      if not CharHlp.AtLevelCap(creature, cls) then
        if GDConsts.dsExperienceSpellsClass[cls].xp[lvl + 1] > 0 then
          if GDConsts.dsExperienceSpellsClass[cls].xp[lvl + 1] <= creature^.experience then
            CanTrain := True;
  end;
end;

{ Check the racial level limit for a class. Fighter caps, and the half-elf ranger's, increase with high strength;
  half-elf clerics stop at level 5. Monsters, half-orcs and humans have no limit here. }
function AtLevelCap(creature: Types.PCharRecord; cls: ShortInt): Boolean;
var
  lvl: ShortInt;
begin
  AtLevelCap := False;
  with creature^ do begin
    lvl := classLevels[cls];
    if lvl <= 0 then
      Exit;
    case race of
      C_Race.DWARF:
        if cls = C_Level.FIGHTER then
          if ((lvl = 8) and (strCur = 17)) or ((lvl = 7) and (strCur < 17)) then
            AtLevelCap := True;
      C_Race.ELF:
        if cls = C_Level.FIGHTER then
          if (lvl = 7) or ((lvl = 6) and (strCur = 17)) or ((lvl = 5) and (strCur < 17)) then
            AtLevelCap := True;
      C_Race.GNOME:
        if cls = C_Level.FIGHTER then
          if (lvl = 6) or ((lvl = 5) and (strCur < 18)) then
            AtLevelCap := True;
      C_Race.HALFELF:
        if (cls = C_Level.CLERIC) and (lvl = 5) then
          AtLevelCap := True
        else if (cls = C_Level.FIGHTER) or (cls = C_Level.RANGER) then
          if (lvl = 8) or ((lvl = 7) and (strCur = 17)) or ((lvl = 6) and (strCur < 17)) then
            AtLevelCap := True;
      C_Race.HALFLING:
        if cls = C_Level.FIGHTER then
          if (lvl = 6) or ((lvl = 5) and (strCur = 17)) or ((lvl = 4) and (strCur < 17)) then
            AtLevelCap := True;
    end;
  end;
end;

function WarriorLevel(creature: Types.PCharRecord): ShortInt;
var
  best: ShortInt;
begin
  best := creature^.classLevels[C_Level.FIGHTER];
  if creature^.classLevels[C_Level.PALADIN] > best then
    best := creature^.classLevels[C_Level.PALADIN];
  if creature^.classLevels[C_Level.RANGER] > best then
    best := creature^.classLevels[C_Level.RANGER];
  if best < 0 then
    best := 0;
  WarriorLevel := best;
end;

function ConHpTotal(creature: Types.PCharRecord; con: Byte): Integer;
var
  total: Integer;
  clsCount: Byte;
  cls: ShortInt;
  dice: Byte;
  share: ShortInt;
  warrior: Boolean;
begin
  total := 0;
  clsCount := 0;
  with creature^ do begin
    warrior := (charClass = C_Class.FIGHTER) or (charClass = C_Class.PALADIN) or (charClass = C_Class.RANGER);
    { 7 = High(classLevels) }
    for cls := 0 to 7 do
      if classLevels[cls] > 0 then begin
        Inc(clsCount);
        if con < 3 then
          share := GDConsts.conBonusTbl[3]
        else if con > 20 then
          share := GDConsts.conBonusTbl[20]
        else
          share := GDConsts.conBonusTbl[con];
        if (con > 16) and warrior then
          Inc(share);
        if (con > 17) and warrior then
          Inc(share);
        dice := classLevels[cls];
        { a ranger's first level has two hit dice }
        if cls = C_Level.RANGER then
          Inc(dice);
        Inc(total, dice * share);
      end;
  end;
  if clsCount > 0 then
    total := total div clsCount;
  ConHpTotal := total;
end;

function BaseItem(itemType: Byte): Types.PBaseItemRec;
begin
  { 127 = High(baseItems) }
  if itemType > 127 then
    BaseItem := @GDVars.baseItemsOverflow
  else
    BaseItem := @GDVars.baseItems[itemType];
end;

function IsNpc(creature: Types.PCharRecord): Boolean;
begin
  IsNpc := creature^.npc >= C_Npc.FLAG;
end;

function MayTrade(creature: Types.PCharRecord): Boolean;
begin
  MayTrade := not CharHlp.IsNpc(creature) or (creature^.enabled = 0) or (creature^.status = C_Status.ANIMATED);
end;

function ComesUnderPlayer(creature: Types.PCharRecord): Boolean;
begin
  ComesUnderPlayer := not CharHlp.IsNpc(creature) and (creature^.status <> C_Status.ANIMATED);
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
      ((creature^.classLevels[C_Level.CLERIC] > 0) and (CharHlp.BaseItem(item^.itemType)^.slot = 12)) then
    item^.unidMask := 0;
  ScrollLegible := item^.unidMask = 0;
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

function CastableScroll(creature: Types.PCharRecord; item: Types.PItemRec): Boolean;
begin
  CastableScroll := False;
  if CharHlp.ItemReadable(item) then
    if (item^.equipped <> 0) or (CharHlp.BaseItem(item^.itemType)^.classMask and creature^.itemLimits <> 0) then
      CastableScroll := CharHlp.ScrollLegible(creature, item);
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
      if CharHlp.CastableScroll(creature, item) then
        for i := 1 to SizeOf(item^.spells) do
          if CharHlp.ScrollSpellAt(item, i) <> C_Spell.NONE then
            found := True;
      item := item^.next;
    end;
  end;
  HasScrollSpells := found;
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

end.

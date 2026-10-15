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

procedure PrintItemString(creature: Types.PCharRecord; item: Types.PItemRec; col, row: Byte; isInv, doPrint: Boolean);

procedure DisplayParty(hl: Types.PCharRecord);

procedure PrintArmorClass(creature: Types.PCharRecord; col, row: Byte);

procedure PrintHitPoints(creature: Types.PCharRecord; col, row: Byte; hotPink: Boolean);

procedure DisplayCreatureName(creature: Types.PCharRecord; col, row: Byte; possessive: Boolean);

procedure CombatPrintCreatureInfo(creature: Types.PCharRecord);

function IsHelpless(creature: Types.PCharRecord): Boolean;

{ Point creature's equipment slots at its readied items (RecalcStats does this first; a character just loaded needs it
  alone). }
procedure LinkEquipped(creature: Types.PCharRecord);

procedure RecalcStats(creature: Types.PCharRecord);

function DexterityArmorAdjustment(creature: Types.PCharRecord): ShortInt;

procedure PrintNameString(creature: Types.PCharRecord; s: string; row: Byte; pause: Boolean);

procedure PrintMessageWait(s: string);

procedure RemoveSpell(creature: Types.PCharRecord; spell: Byte);

procedure RemoveItem(creature: Types.PCharRecord; item: Types.PItemRec);

{ Free every item in list and leave it nil. }
procedure FreeItemList(var list: Types.PItemRec);

{ Empty the treasure on the table: free its items and zero its money. }
procedure ClearTreasure;

procedure AddItemCopy(creature: Types.PCharRecord; item: Types.PItemRec);

procedure PrintBottomLine(s: Types.TStr40);

procedure ClearMessageWindow;

procedure CopyIconFacing(cell, half, row: Byte; mirror: Boolean);

procedure BuildIconFacings(cell: Byte);

procedure CombatAnimateMovingIcon(startX, startY, endX, endY: ShortInt; frames, pace: Byte);

procedure PrintNameStringAnim(creature: Types.PCharRecord; effect: Boolean; s: string);

function HasEffect(creature: Types.PCharRecord; id: Byte; var effect: Types.PEffectRec): Boolean;

procedure InflictDamage(creature: Types.PCharRecord; dmg: Byte);

procedure PrintHpRestoreMsg(creature: Types.PCharRecord);

function EnemyTeam(creature: Types.PCharRecord): ShortInt;

procedure CountTeams;

function CountTargets(creature: Types.PCharRecord; range: Byte): Byte;

function CalcDistance(creature, other: Types.PCharRecord): Byte;

function EndActions(creature: Types.PCharRecord): Boolean;

function CanUseItems(creature: Types.PCharRecord): Boolean;

function Guard(creature: Types.PCharRecord): Boolean;

function GetCasterLevel(spell: Byte): Byte;

procedure DrawNoncombatWindows(inset: Boolean);

procedure DisplayNoncombatInterface;

procedure PrintMiscInfo;

procedure DisplayWildernessInterface;

procedure DisplayCombatInterface;

procedure SelectChar(query: Types.TStr40; addExit: Boolean; var sel: Types.PCharRecord);

function HasRangedWeapon(creature: Types.PCharRecord): Boolean;

function HasThrowableWeapon(creature: Types.PCharRecord): Boolean;

function FindDamagingRangedWeapon(creature: Types.PCharRecord; var sel: Types.PItemRec): Boolean;

function AtLevelCap(creature: Types.PCharRecord; cls: ShortInt): Boolean;

{ True when the creature has enough experience to train a level in some class: the training hall's own test (not at the
  racial cap, a next level in the experience table, and the experience for it), ignoring the fee and the hall. }
function CanTrain(creature: Types.PCharRecord): Boolean;

function WeightAllowance(creature: Types.PCharRecord): Integer;

function DexMissileAdjust(creature: Types.PCharRecord): ShortInt;

function StrToHitAdjust(creature: Types.PCharRecord): ShortInt;

function StrDamageAdjust(creature: Types.PCharRecord): ShortInt;

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

implementation

uses Crt, C_Area, C_Item, C_Msg, GDConsts, GDVars, MenuCore, MapView, Pathing, CbtMap, C_Effect, C_Equip, C_Race,
  C_Keys, C_Class, C_Level, C_Status, C_Ifc, C_Money, Stats, Blit, Border, Portrait, SoundDrv, TextRend, Wilds, C_Npc,
  StrUtil;

var
  { zone-1 game state }
  gbvmZone1: Types.PZone1Rec absolute GDVars.zone1;
  { picture animation shown in the view window }
  gAnimData: Types.TAnimRec absolute GDVars.animData;

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
    creature^.thac0Cur := CharHlp.DexMissileAdjust(creature) + creature^.thac0Cur;
  creature^.curModA[1] := CharHlp.BaseItem(wtype)^.dmgSmMod;
  if (CharHlp.BaseItem(wtype)^.props and C_Item.PROP_STR_BONUS) <> 0 then begin
    creature^.thac0Cur := CharHlp.StrToHitAdjust(creature) + creature^.thac0Cur;
    creature^.curModA[1] := CharHlp.StrDamageAdjust(creature) + creature^.curModA[1];
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
  over := LongInt(creature^.encumbrance) - CharHlp.WeightAllowance(creature);
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
procedure PrintItemString(creature: Types.PCharRecord; item: Types.PItemRec; col, row: Byte; isInv, doPrint: Boolean);
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

{ Draw the party roster panel: 'Name' / 'AC HP' headers, then one row per creature -- the name (hl in white, others
  colored by DisplayCreatureName), then AC and HP right-aligned by nudging their columns by their digit counts. Clear
  each row first, and one extra row after the last. }
procedure DisplayParty(hl: Types.PCharRecord);
var
  p: Types.PCharRecord;
  col: Byte;
  row: Byte;
  band: Byte;
begin
  if GDVars.ifcState = C_Ifc.MAIN_MENU then
    col := 1
  else
    col := 17;
  row := 2;
  TextRend.DisplayString(col, row, White, 'Name');
  TextRend.DisplayString(33, row, White, 'AC  HP');
  Inc(row, 2);
  p := GDVars.creatureList;
  while p <> nil do begin
    Border.ClearBox(col, row, 38, row);
    if p = hl then
      TextRend.DisplayString(col, row, White, p^.name)
    else
      CharHlp.DisplayCreatureName(p, col, row, False);
    case p^.acCur of
      0..50: band := 1;
      51..60: band := 2;
      61..69: band := 1;
    else
      band := 0;
    end;
    CharHlp.PrintArmorClass(p, band + 32, row);
    case p^.hpCur of
      0..9: band := 2;
      10..99: band := 1;
    else
      band := 0;
    end;
    CharHlp.PrintHitPoints(p, band + 36, row, False);
    Inc(row);
    p := p^.nextCharAddr;
  end;
  Border.ClearBox(col, row, 38, row);
end;

{ Print the creature's armor class in light green. AC is stored biased by 60, so print Abs(acCur - 60), with a '-'
  prepended for ACs below 0 (acCur > 60). }
procedure PrintArmorClass(creature: Types.PCharRecord; col, row: Byte);
var
  s: String;
begin
  s := StrUtil.NumStr(Abs(creature^.acCur - 60));
  if creature^.acCur > 60 then
    s := '-' + s;
  TextRend.DisplayString(col, row, LightGreen, s);
end;

{ Print the creature's current hit points: yellow when injured, light green at full health, light magenta when hotPink
  is set. }
procedure PrintHitPoints(creature: Types.PCharRecord; col, row: Byte; hotPink: Boolean);
var
  color: Byte;
begin
  if creature^.hpCur < creature^.hpMax then
    color := Yellow
  else
    color := LightGreen;
  if hotPink then
    color := LightMagenta;
  TextRend.DisplayString(col, row, color, StrUtil.NumStr(creature^.hpCur));
end;

{ Show the creature's name, hit points, armor class, equipped weapon and status in the combat information panel. }
procedure CombatPrintCreatureInfo(creature: Types.PCharRecord);
var
  col: Byte;
  row: Byte;
begin
  Border.ClearBox(23, 1, 38, 21);
  row := 1;
  CharHlp.PrintNameString(creature, ' ', row, False);
  Inc(row);
  TextRend.DisplayString(23, row + 1, LightGreen, 'Hitpoints');
  CharHlp.PrintHitPoints(creature, 33, row + 1, False);
  Inc(row, 2);
  TextRend.DisplayString(23, row + 1, LightGreen, 'AC');
  CharHlp.PrintArmorClass(creature, 26, row + 1);
  GDVars.curRow := row + 1;
  if creature^.equipped[C_Equip.WEAPON] <> nil then begin
    Inc(row, 2);
    col := 23;
    CharHlp.PrintItemString(creature, creature^.equipped[C_Equip.WEAPON], 0, 0, False, False);
    TextRend.DisplayMessageWindow(23, row + 1, 38, row + 1 + 1 + 1, LightGreen, True,
                                  creature^.equipped[C_Equip.WEAPON]^.name);
  end;
  row := GDVars.curRow + 1;
  if creature^.enabled = 0 then
    TextRend.DisplayString(23, row + 1, White, GDConsts.statusStrs[creature^.status])
  else if CharHlp.IsHelpless(creature) then
    TextRend.DisplayString(23, row + 1, White, '(Helpless)');
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
  adj[0] := CharHlp.DexterityArmorAdjustment(creature);
  if creature^.equipped[C_Equip.WEAPON] = nil then begin
    creature^.thac0Cur := CharHlp.StrToHitAdjust(creature) + creature^.thac0Cur;
    creature^.curModA[1] := CharHlp.StrDamageAdjust(creature) + creature^.curModA[1];
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

{ Armor class adjustment for the creature's Dexterity (positive is better, as AC is stored biased). }
function DexterityArmorAdjustment(creature: Types.PCharRecord): ShortInt;
var
  d: Byte;
begin
  d := creature^.dexCur;
  case d of
    1..3: DexterityArmorAdjustment := -4;
    4..6: DexterityArmorAdjustment := d - 7;
    15..18: DexterityArmorAdjustment := d - 14;
    19..20: DexterityArmorAdjustment := 4;
    21..23: DexterityArmorAdjustment := 5;
    24..25: DexterityArmorAdjustment := 6;
  else
    DexterityArmorAdjustment := 0;
  end;
end;

{ Missile to-hit adjustment for the creature's Dexterity: -4 below 3, -3 at 3 rising to +3 at 18, then +3..+5 for higher
  scores. }
function DexMissileAdjust(creature: Types.PCharRecord): ShortInt;
var
  d: Byte;
begin
  d := creature^.dexCur;
  case d of
    0..2: DexMissileAdjust := -4;
    3..5: DexMissileAdjust := d - 6;
    16..18: DexMissileAdjust := d - 15;
    19..20: DexMissileAdjust := 3;
    21..23: DexMissileAdjust := 4;
    24..25: DexMissileAdjust := 5;
  else
    DexMissileAdjust := 0;
  end;
end;

{ Map strCur (with exceptional strength at 18) onto the 0..30 combined strength scale used by the strength tables.
  Strength above 25 counts as 25 and exceptional strength above 100 as 18/00. }
function TranslatedStrength(creature: Types.PCharRecord): Byte;
begin
  case creature^.strCur of
    0..17: TranslatedStrength := creature^.strCur;
    18:
      case creature^.strExc of
        0: TranslatedStrength := 18;
        1..50: TranslatedStrength := 19;
        51..75: TranslatedStrength := 20;
        76..90: TranslatedStrength := 21;
        91..99: TranslatedStrength := 22;
      else
        TranslatedStrength := 23;
      end;
    19..25: TranslatedStrength := creature^.strCur + 5;
  else
    TranslatedStrength := 30;
  end;
end;

{ Strength to-hit adjustment over the translated scale; zero unless the creature's strength bonus applies. }
function StrToHitAdjust(creature: Types.PCharRecord): ShortInt;
var
  ts: Byte;
begin
  StrToHitAdjust := 0;
  ts := CharHlp.TranslatedStrength(creature);
  if creature^.useStrength <> 0 then
    case ts of
      1..3: StrToHitAdjust := -3;
      4..5: StrToHitAdjust := -2;
      6..7: StrToHitAdjust := -1;
      17..19: StrToHitAdjust := 1;
      20..22: StrToHitAdjust := 2;
      23..25: StrToHitAdjust := 3;
      26..27: StrToHitAdjust := 4;
      28..30: StrToHitAdjust := ts - 23;
    end;
end;

{ Strength damage adjustment over the translated scale; zero unless the creature's strength bonus applies. }
function StrDamageAdjust(creature: Types.PCharRecord): ShortInt;
var
  ts: Byte;
begin
  StrDamageAdjust := 0;
  ts := CharHlp.TranslatedStrength(creature);
  if creature^.useStrength <> 0 then
    case ts of
      1..2: StrDamageAdjust := -2;
      3..5: StrDamageAdjust := -1;
      16: StrDamageAdjust := 1;
      17..19: StrDamageAdjust := ts - 16;
      20..29: StrDamageAdjust := ts - 17;
      30: StrDamageAdjust := 14;
    end;
end;

{ Strength's encumbrance allowance in coins; translated strength 1..7 gives a negative allowance, while 0 gives zero.
  Strength 19 (translated 24) gets the AD&D 4500, not the 4000 its neighbours' formula gives. }
function WeightAllowance(creature: Types.PCharRecord): Integer;
var
  ts: Byte;
begin
  ts := CharHlp.TranslatedStrength(creature);
  case ts of
    1..3: WeightAllowance := -350;
    4..5: WeightAllowance := -250;
    6..7: WeightAllowance := -150;
    12..13: WeightAllowance := 100;
    14..15: WeightAllowance := 200;
    16: WeightAllowance := 350;
    17..21: WeightAllowance := (ts - 17) * 250 + 500;
    22, 23, 25, 26: WeightAllowance := (ts - 22) * 1000 + 2000;
    24: WeightAllowance := 4500;
    27: WeightAllowance := 7500;
    28..30: WeightAllowance := (ts - 28) * 3000 + 9000;
  else
    WeightAllowance := 0;
  end;
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

{ Copy the item onto the heap and append it to the creature's inventory. The caller checks that there is room. }
procedure AddItemCopy(creature: Types.PCharRecord; item: Types.PItemRec);
var
  p: Types.PItemRec;
  n: Types.PItemRec;
begin
  GetMem(n, SizeOf(Types.TItemRec));
  Move(item^, n^, SizeOf(Types.TItemRec));
  n^.next := nil;
  p := creature^.itemsAddr;
  if p = nil then
    creature^.itemsAddr := n
  else begin
    while p^.next <> nil do
      p := p^.next;
    p^.next := n;
  end;
end;

{ Show a message on the bottom row in light green, wait for a key, then clear the row again. }
procedure PrintBottomLine(s: Types.TStr40);
begin
  Border.ClearBox(0, 24, 39, 24);
  TextRend.DisplayString(0, 24, LightGreen, s);
  TextRend.PauseOnly;
  Border.ClearBox(0, 24, 39, 24);
end;

{ Show "<name> <text>" in the message window: in combat, the combat window from column 23 at row; otherwise the
  full-width bottom window (bordered unless dsSuppressDrawingBorderFlag is set), the name on its first line and the text
  word-wrapped below. With pause, wait for a key and clear the window. }
procedure PrintNameString(creature: Types.PCharRecord; s: string; row: Byte; pause: Boolean);
var
  top: Byte;
begin
  if GDVars.ifcState = C_Ifc.COMBAT then begin
    Border.ClearBox(23, row, 38, 21);
    CharHlp.DisplayCreatureName(creature, 23, row, False);
    TextRend.DisplayMessageWindow(23, row + 1, 38, 21, LightGreen, True, s);
  end else begin
    if GDVars.dsSuppressDrawingBorderFlag <> 0 then
      top := 18
    else begin
      top := C_Msg.MESSAGE_TOP;
      Border.DrawBorder(C_Msg.TEXT_LEFT, top, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, 0);
    end;
    Border.ClearBox(C_Msg.TEXT_LEFT, top, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
    CharHlp.DisplayCreatureName(creature, 1, top + 1, False);
    TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, top + 1 + 1, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, LightGreen, True,
                                  s);
  end;
  if pause then begin
    TextRend.PauseOnly;
    CharHlp.ClearMessageWindow;
  end;
end;

{ Show s in the message window, as PrintNameString does but without the name line, then wait for a key at the
  'Press any key to continue' prompt and clear the prompt. The window keeps the text, and curRow is left on its last
  line. }
procedure PrintMessageWait(s: string);
var
  top: Byte;
begin
  if GDVars.ifcState = C_Ifc.COMBAT then begin
    Border.ClearBox(23, 10, 38, 21);
    TextRend.DisplayMessageWindow(23, 10, 38, 21, LightGreen, True, s);
  end else begin
    if GDVars.dsSuppressDrawingBorderFlag <> 0 then
      top := 18
    else begin
      top := C_Msg.MESSAGE_TOP;
      Border.DrawBorder(C_Msg.TEXT_LEFT, top, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, 0);
    end;
    Border.ClearBox(C_Msg.TEXT_LEFT, top, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
    TextRend.DisplayMessageWindow(C_Msg.TEXT_LEFT, top + 1, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, LightGreen, True, s);
  end;
  TextRend.DisplayAndPause(LightMagenta, 'Press any key to continue');
  Border.ClearBox(0, 24, 39, 24);
end;

{ Clear whichever message window is active (combat or bottom), leaving its border alone. }
procedure ClearMessageWindow;
begin
  if GDVars.ifcState = C_Ifc.COMBAT then
    Border.ClearBox(23, 10, 38, 21)
  else
    Border.ClearBox(C_Msg.TEXT_LEFT, 18, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM);
end;

{ Print the creature's name in light red (out of action, enabled = 0), yellow (hostile), light magenta (ready to
  train) or light cyan (friendly), optionally followed by the possessive 's. }
procedure DisplayCreatureName(creature: Types.PCharRecord; col, row: Byte; possessive: Boolean);
var
  color: Byte;
begin
  if creature^.enabled = 0 then
    color := LightRed
  else if creature^.hostile = 1 then
    color := Yellow
  else if CharHlp.CanTrain(creature) then
    { ready to train, as in Pools of Darkness }
    color := LightMagenta
  else
    color := LightCyan;
  TextRend.DisplayString(col, row, color, creature^.name);
  if possessive then
    TextRend.DisplayString(col + Length(creature^.name), row, color, '''s');
end;

{ Copy one icon half (GDVars.dsIconAnimation[cell, half]) into frame row of the moving-icon sheet
  (GDVars.dsMoveIconSheet), mirrored through a scratch picture when asked. The pixel data copies imgSize bytes; the
  transparency mask copies a quarter of that under EGA. }
procedure CopyIconFacing(cell, half, row: Byte; mirror: Boolean);
var
  tmp: Types.PImgBuf;
  stride4: Word;
  stride: Word;
begin
  stride := GDVars.dsMoveIconSheet^.imgSize;
  stride4 := stride;
  if GDVars.videoMode = Types.vmEGA then
    stride4 := stride4 div 4;
  if mirror then begin
    Blit.AllocPic(24, 3, 1, 1, tmp);
    Blit.MirrorPic(GDVars.dsIconAnimation[cell, half], tmp);
    Move(tmp^.data, GDVars.dsMoveIconSheet^.data[row * stride], stride);
    Move(tmp^.transp^, GDVars.dsMoveIconSheet^.transp^[row * stride4], stride4);
    Blit.FreePic(tmp);
  end else begin
    Move(GDVars.dsIconAnimation[cell, half]^.data, GDVars.dsMoveIconSheet^.data[row * stride], stride);
    Move(GDVars.dsIconAnimation[cell, half]^.transp^, GDVars.dsMoveIconSheet^.transp^[row * stride4], stride4);
  end;
end;

{ Assemble the four-frame facing sheet for an icon: half 0 straight and mirrored, then half 1 mirrored and straight. }
procedure BuildIconFacings(cell: Byte);
begin
  CharHlp.CopyIconFacing(cell, 0, 0, False);
  CharHlp.CopyIconFacing(cell, 0, 1, True);
  CharHlp.CopyIconFacing(cell, 1, 2, True);
  CharHlp.CopyIconFacing(cell, 1, 3, False);
end;

{ Fly an icon from the start cell to the end cell in the combat view. Trace the line at third-of-a-cell resolution
  (Pathing.PathFind sets it up, Pathing.NextPathStep yields one direction per step), scroll the view toward a focus
  point, then walk the icon one 8-pixel column per step: blit the facing frame from the moving-icon sheet, flush, delay,
  restore the background, cycle frames. startX/startY track the current cell. When the walk leaves the 0..18 column
  window before the end, rescroll and repeat; at the end, draw the icon on the end cell. }
procedure CombatAnimateMovingIcon(startX, startY, endX, endY: ShortInt; frames, pace: Byte);
var
  { a 49-cell span takes 148 steps; the last slot stays 8 (no move) for the walk's read one past count }
  steps: array[0..148] of Byte;
  req: Types.TPathReq;
  n: Byte;
  count: Byte;
  frame: Byte;
  lastPass: Boolean;
  done: Boolean;
  camX: ShortInt;
  camY: ShortInt;
  prevX: ShortInt;
  prevY: ShortInt;
  accX: ShortInt;
  accY: ShortInt;
  dirX: ShortInt;
  dirY: ShortInt;
  stepX: ShortInt;
  stepY: ShortInt;
  pixX: ShortInt;
  pixY: ShortInt;
begin
  prevX := startX;
  prevY := startY;
  FillChar(steps, SizeOf(steps), 8);
  FillChar(req, SizeOf(req), 0);
  n := 0;
  frame := 0;
  req.sx := startX * 3;
  req.sy := startY * 3;
  req.ex := endX * 3;
  req.ey := endY * 3;
  Pathing.PathFind(req);
  repeat
    done := not Pathing.NextPathStep(req);
    steps[n] := req.step;
    Inc(n);
    { a longer path than the arena allows is cut short }
    if n >= SizeOf(steps) - 1 then
      done := True;
  until done;
  count := n;
  if count < 2 then Exit;
  dirX := endX - startX;
  dirY := endY - startY;
  if not CbtMap.ViewCoordsValid(startX - GDVars.arenaPtr^.ox, startY - GDVars.arenaPtr^.oy) or
      not CbtMap.ViewCoordsValid(endX - GDVars.arenaPtr^.ox, endY - GDVars.arenaPtr^.oy) then begin
    if (Abs(dirX) <= 6) and (Abs(dirY) <= 6) then begin
      lastPass := True;
      camX := startX + dirX div 2;
      camY := startY + dirY div 2;
    end else begin
      lastPass := False;
      camX := GDVars.arenaPtr^.ox + 3;
      camY := GDVars.arenaPtr^.oy + 3;
    end;
  end else begin
    lastPass := True;
    camX := GDVars.arenaPtr^.ox + 3;
    camY := GDVars.arenaPtr^.oy + 3;
  end;
  CbtMap.ScrollView(camX, camY, 255, 8);
  n := 0;
  accX := 0;
  accY := 0;
  repeat
    pixX := (startX - GDVars.arenaPtr^.ox) * 3 + accX;
    pixY := (startY - GDVars.arenaPtr^.oy) * 3 + accY;
    prevX := startX;
    prevY := startY;
    done := False;
    repeat
      if (pace > 0) or (pixX mod 3 = 0) or (pixY mod 3 = 0) then begin
        Blit.BlitTileClipped(pixX, pixY, frame, 5, GDVars.dsMoveIconSheet, GDVars.dsViewImageBufferPtr);
        Blit.FlushView;
        Delay(pace);
        Blit.BlitTileClipped(pixX, pixY, 0, 0, GDVars.dsIconImageBufferPtr, GDVars.dsViewImageBufferPtr);
        Inc(frame);
        if frame >= frames then
          frame := 0;
      end;
      Inc(n);
      stepX := GDConsts.dirDX[steps[n]];
      stepY := GDConsts.dirDY[steps[n]];
      Inc(pixX, stepX);
      Inc(pixY, stepY);
      if (pixX < 0) or (pixX > 18) or (pixY < 0) or (pixY > 18) then
        done := True;
      if not done and (n < count) then begin
        Inc(accX, stepX);
        Inc(accY, stepY);
        if Abs(accX) = 3 then begin
          Inc(startX, Pathing.SignOf(accX));
          Inc(camX, Pathing.SignOf(accX));
          accX := 0;
        end;
        if Abs(accY) = 3 then begin
          Inc(startY, Pathing.SignOf(accY));
          Inc(camY, Pathing.SignOf(accY));
          accY := 0;
        end;
      end;
    until (n >= count) or done;
    if n < count then begin
      dirX := Pathing.SignOf(prevX - startX);
      dirY := Pathing.SignOf(prevY - startY);
      if dirX <> 0 then begin
        if startX >= GDVars.arenaPtr^.ox + 6 then
          camX := startX + 3
        else if startX <= GDVars.arenaPtr^.ox then
          camX := startX - 3;
      end;
      if dirY <> 0 then begin
        if startY >= GDVars.arenaPtr^.oy + 6 then
          camY := startY + 3
        else if startY <= GDVars.arenaPtr^.oy then
          camY := startY - 3;
      end;
      CbtMap.ScrollView(camX, camY, 255, 8);
    end else begin
      lastPass := True;
      if not CbtMap.ViewCoordsValid(endX - GDVars.arenaPtr^.ox, endY - GDVars.arenaPtr^.oy) then
        CbtMap.ScrollView(endX, endY, 3, 8);
      pixX := (endX - GDVars.arenaPtr^.ox) * 3;
      pixY := (endY - GDVars.arenaPtr^.oy) * 3;
      Blit.BlitTileClipped(pixX, pixY, frame, 5, GDVars.dsMoveIconSheet, GDVars.dsViewImageBufferPtr);
      if pace > 0 then begin
        Blit.FlushView;
        Delay(pace);
        Blit.BlitTileClipped(pixX, pixY, 0, 0, GDVars.dsIconImageBufferPtr, GDVars.dsViewImageBufferPtr);
      end;
    end;
  until lastPass;
  Blit.FlushView;
end;

{ Show "<name> <text>" with the damage or effect flash: build the facings from icon cell 23 (damage) or 22 (effect),
  scroll the creature on screen if needed, play the sound, print, then flash the four facing frames at the creature's
  grid cell (gameDelay + 1 times for an effect, once for damage, which then waits for a key).
  SoundDrv.SoundSetAutoStop(0) keeps the sound driver resident during the flash, then 10 restores per-sound cleanup. Out
  of combat it is just PrintNameString with a pause. }
procedure PrintNameStringAnim(creature: Types.PCharRecord; effect: Boolean; s: string);
var
  gx: ShortInt;
  gy: ShortInt;
  cell: Byte;
  j: Byte;
  i: Byte;
  reps: Byte;
  slot: Byte;
begin
  if GDVars.ifcState = C_Ifc.COMBAT then begin
    SoundDrv.SoundSetAutoStop(0);
    if effect then
      cell := 22
    else
      cell := 23;
    CharHlp.BuildIconFacings(cell);
    if not CbtMap.CombatIconVisible(creature, 1) then
      CbtMap.ScrollView(CbtMap.CombatCellX(creature), CbtMap.CombatCellY(creature), 3, 8);
    if effect then
      SoundDrv.SoundCommand(GDConsts.soundIds.combat[0])
    else
      SoundDrv.SoundCommand(GDConsts.soundIds.damage);
    CharHlp.PrintNameString(creature, s, 10, False);
    if effect then
      reps := GDVars.gameDelay
    else
      reps := 0;
    slot := CbtMap.CombatSlot(creature);
    { slot 0: not on the map, so there is no cell to flash }
    if slot > 0 then begin
      gx := GDVars.gridX[slot] * 3;
      gy := GDVars.gridY[slot] * 3;
      for i := 0 to reps do
        for j := 0 to 3 do begin
          Blit.BlitTileClipped(gx, gy, j, 5, GDVars.dsMoveIconSheet, GDVars.dsViewImageBufferPtr);
          Blit.FlushView;
          Delay(70);
          Blit.BlitTileClipped(gx, gy, 0, 0, GDVars.dsIconImageBufferPtr, GDVars.dsViewImageBufferPtr);
        end;
    end;
    SoundDrv.SoundSetAutoStop(10);
    Blit.FlushView;
    if reps = 0 then
      TextRend.PauseOnly;
  end else
    CharHlp.PrintNameString(creature, s, 10, True);
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

{ Announce that the creature is fully or partially healed, and refresh the party panel outside combat. }
procedure PrintHpRestoreMsg(creature: Types.PCharRecord);
var
  s: Types.TStr40;
begin
  if creature^.hpCur = creature^.hpMax then
    s := 'is fully healed'
  else
    s := 'is partially healed';
  CharHlp.PrintNameString(creature, s, 10, True);
  if GDVars.ifcState <> C_Ifc.COMBAT then
    CharHlp.DisplayParty(GDVars.curChar);
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
  list (nil, or off the map). Note: targetCount is not restored with the list. }
function CalcDistance(creature, other: Types.PCharRecord): Byte;
var
  saved: array[1..255] of Types.TCombatTarget;
  i: Byte;
begin
  Move(GDVars.targetList, saved, SizeOf(GDVars.targetList));
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

{ End the creature's round, raise its guarding flag and announce it. Always returns True. }
function Guard(creature: Types.PCharRecord): Boolean;
begin
  Guard := CharHlp.EndActions(creature);
  creature^.combatAddr^.guarding := 1;
  CharHlp.PrintBottomLine('Guarding');
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

{ Draw the three standard noncombat windows (full screen minus the bottom line, message window, 3D/picture view), plus
  the picture inset border when asked. }
procedure DrawNoncombatWindows(inset: Boolean);
begin
  Border.DrawWindow(1, 1, 38, 22, 0, White, '');
  Border.DrawWindow(C_Msg.TEXT_LEFT, C_Msg.MESSAGE_TOP, C_Msg.TEXT_RIGHT, C_Msg.TEXT_BOTTOM, 0, White, '');
  Border.DrawWindow(1, 1, 15, 15, 0, White, '');
  if inset then
    Border.DrawWindow(3, 3, 13, 13, 0, White, '');
end;

{ Redraw the screen for the current interface state: the main-menu frame; the shop, temple or vault windows with the
  portrait;
  the camp picture, party and status line; the indoor or outdoor map view, party and status line; or the loot picture
  and party. }
procedure DisplayNoncombatInterface;
begin
  case GDVars.ifcState of
    C_Ifc.MAIN_MENU: Border.DrawWindow(1, 1, 38, 22, 0, White, '');
    C_Ifc.SHOP_TEMPLE, C_Ifc.VAULT: begin
      CharHlp.DrawNoncombatWindows(True);
      Portrait.LoadPortraitBufs(GDVars.dsCurrentPortraitHead, GDVars.dsCurrentPortraitHead2);
      Portrait.DisplayPortraitBufs(3, 3, True);
    end;
    C_Ifc.CAMPING: begin
      CharHlp.DrawNoncombatWindows(True);
      Portrait.LoadAnimation('PIC', 29, 0, gAnimData);
      CharHlp.DisplayParty(GDVars.curChar);
      CharHlp.PrintMiscInfo;
    end;
    C_Ifc.INDOORS: begin
      CharHlp.DrawNoncombatWindows(True);
      MapView.DisplayMapView;
      CharHlp.DisplayParty(GDVars.curChar);
      CharHlp.PrintMiscInfo;
    end;
    C_Ifc.OUTDOORS: begin
      CharHlp.DrawNoncombatWindows(False);
      MapView.DisplayMapView;
      CharHlp.DisplayParty(GDVars.curChar);
      CharHlp.PrintMiscInfo;
    end;
    C_Ifc.LOOT: begin
      CharHlp.DrawNoncombatWindows(True);
      Portrait.LoadAnimation('PIC', 1, 0, gAnimData);
      CharHlp.DisplayParty(GDVars.curChar);
    end;
  end;
end;

{ Print the party-window status line on row 15 of the upper-right window: coordinates (omitted when the zone's noAutomap
  is set; above location type 1 they come from the zone-0 party position, +13 for type 3 and +26 for type 4), compass
  facing, the zero-padded HH:MM clock, and the camping or search tag. }
procedure PrintMiscInfo;
var
  x: Byte;
  y: Byte;
  hrs: string[2];
  mins: string[2];
  info: Types.TStr40;
begin
  info := '';
  x := GDVars.gMapX;
  y := GDVars.gMapY;
  if GDVars.gLocType > C_Area.LOC_3D_MAP then begin
    x := GDVars.zone0^.partyX.lo;
    y := GDVars.zone0^.partyY.lo;
    if GDVars.gLocType = C_Area.LOC_WILD_CENTRAL then
      Inc(x, 13);
    if GDVars.gLocType = C_Area.LOC_WILD_EAST then
      Inc(x, 26);
  end;
  hrs := StrUtil.ZeroPad2(GDVars.zone0^.clock.hour);
  { A turn is ten minutes and the minute counter rolls over at ten, so turn * 10 + minute is the minute of the hour (see
    GDConsts.unitScale). }
  mins := StrUtil.ZeroPad2(10 * GDVars.zone0^.clock.turn + GDVars.zone0^.clock.minute);
  if GDVars.zone0^.noAutomap = 0 then
    info := StrUtil.NumStr(x) + ',' + StrUtil.NumStr(y) + ' ';
  info := info + GDConsts.dirNames[GDVars.gFacing] + ' ';
  info := info + hrs + ':' + mins;
  { the STING trace log is on (Ctrl-L), as Curse shows it }
  if GDVars.debugTraceEnabled then
    info := info + '*';
  if GDVars.ifcState = C_Ifc.CAMPING then
    info := info + ' camping'
  else if gbvmZone1^.searchFlags and 1 > 0 then
    info := info + ' search';
  Border.ClearBox(17, 15, 38, 15);
  TextRend.DisplayString(17, 15, LightGreen, info);
end;

{ Switch to the outdoor interface and draw it: the wilderness windows and map views, status line and party. }
procedure DisplayWildernessInterface;
begin
  GDVars.ifcState := C_Ifc.OUTDOORS;
  Wilds.DrawWildWindows;
  MapView.DisplayMapView;
  MapView.DisplayWildMapView;
  CharHlp.PrintMiscInfo;
  CharHlp.DisplayParty(GDVars.curChar);
end;

{ Draw the combat screen: combat palette, the two combat windows, the cleared bottom rows, and a forced rebuild of the
  combat view centered on its current origin + 3. }
procedure DisplayCombatInterface;
begin
  CbtMap.SetCombatPalette;
  Border.DrawWindow(1, 1, 21, 21, 0, Black, '');
  Border.DrawWindow(23, 1, 38, 21, 0, Black, '');
  Border.ClearBox(0, 23, 39, 24);
  CbtMap.ScrollView(GDVars.arenaPtr^.ox + 3, GDVars.arenaPtr^.oy + 3, 255, 8);
end;

{ Let the player pick a character on the horizontal menu, starting from sel: End and Home (also keypad 1 and 7) cycle
  next/previous through the creature list. Return, Exit and Select leave the loop, Exit with sel nil. With addExit,
  Escape (which MenuHorizontal returns as C_Keys.NONE) leaves like Exit; without it there is no way out but choosing,
  and Escape is ignored (a script's WHO needs a character). Does not set the current character. }
procedure SelectChar(query: Types.TStr40; addExit: Boolean; var sel: Types.PCharRecord);
var
  ch: Char;
  ext: Boolean;
  anim: Boolean;
  p: Types.PCharRecord;
  exitStr: Types.TStr40;
begin
  ch := ' ';
  exitStr := '';
  if addExit then
    exitStr := ' Exit';
  { open on Select: the highlight is shared by every menu, and Enter takes it }
  GDVars.horizChoice := 1;
  while not ((ch in [C_Keys.ENTER, C_Keys.ESC, 'E', 'S']) or ((ch = C_Keys.NONE) and addExit)) do
  begin
    CharHlp.DisplayParty(sel);
    if (GDVars.ifcState = C_Ifc.CAMPING) or (GDVars.ifcState = C_Ifc.LOOT) then
      anim := True
    else
      anim := False;
    ch := MenuCore.MenuHorizontal(query + ' ', 'Select' + exitStr, LightMagenta, LightGreen, White, True,
                                  anim, ext);
    p := sel;
    if ext then
      case ch of
        { End: next character, wrapping to the head }
        C_Keys.END_KEY: begin
          p := p^.nextCharAddr;
          if p = nil then
            p := GDVars.creatureList;
        end;
        { Home: previous character, wrapping to the tail }
        C_Keys.HOME: begin
          p := GDVars.creatureList;
          if sel <> GDVars.creatureList then
            while p^.nextCharAddr <> sel do
              p := p^.nextCharAddr
          else
            while p^.nextCharAddr <> nil do
              p := p^.nextCharAddr;
        end;
      end else if ((ch = 'E') or (ch = C_Keys.NONE)) and addExit then
      p := nil;
    sel := p;
  end;
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

end.

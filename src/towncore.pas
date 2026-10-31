{ TownCore -- the town's buildings, game-neutral: the temple's services (the cures, Heal, Neutralize Poison, Raise Dead,
  Resurrection, Remove Curse, Stone to Flesh and Restoration), each one the fleet's most complete version with Pool of
  Radiance's fixes applied. The rules (prices, which services a temple sells, whom Raise Dead and Resurrection may bring
  back and what that costs) come from the game's temple (Temple.TempleRules); the character comes in as a TTempleChar
  the game reads from its own record, and what a service does goes back as a TTempleDeed the game carries out with its
  own effect engine. The screens, the money and the dice are the game's, through a TTempleIO.

  A service's course (TempleService): a refusal (TempleRefusal) ends it unpaid; a character that does not need it
  (TempleNeed) is told why and, where the temple charges, asked whether to have it anyway; then the fee (TempleQuote),
  the roll (TempleDice), the deed (TempleDeed) and its report. The fixes made here for every game:
  - a cure of wounds asks first and says why it would not help, and reports "is not helped." when no hit point came
    back; a cure the character did not need reports "is not helped." too;
  - Raise Dead refuses, before the fee, an elf (the Raise Dead spell cannot reach an elven soul), a race the game's
    rules do not raise, a corpse still poisoned (the poison would kill it again), a character with no Constitution
    left, and one already gone; it rolls resurrection survival on the permanent Constitution, and takes a point of
    Constitution (never below SCORE_MIN);
  - Resurrection, sold in every game, brings back at full hit points with the same survival roll and Constitution
    point; it refuses an elf as Raise Dead does, for an elven soul is beyond it too (only a rod of resurrection or a
    wish brings one back);
  - curing a disease gives back the Strength the disease took (the deed's TA_DISEASE);
  - Stone to Flesh rolls system shock on the current Constitution, and a failure dies;
  - Neutralize Poison brings back a character the poison killed, but not one a wound killed under Slow Poison, nor a
    stoned, gone or animated one.

  What the temple says is TempleText's shared wording unless the game's TTempleIO.Words gives its own line for that
  TM_* message, so each game keeps its own words.

  Repair (#1125), Pools of Darkness's whole-party cure, sold here at the services' prices: RepairPlan lists the
  services a character needs (Neutralize Poison, Raise Dead or Stone to Flesh, a Restoration for each lost level, then
  Heal for wounds, or Cure Blindness and Cure Disease alone), RepairCost prices them, and TempleRepair carries them out
  with no question and no fee, the survival roll and system shock rolled as ever. Pools' own Repair is free and rolls
  neither.

  Carried over from goldbox-tp7's shared/play/towncore.pas, which takes its canonical races from its CharType unit;
  this game has none, so the races TownCore names are declared here, and Temple maps the game's own onto them. Turbo
  Pascal 6, which builds the DOS game, has no const parameters, so the records go by value.

  The unit has no variables and may be overlaid (O+). }
{$O+,F+}
{$I COMPILER.INC}
unit TownCore;

interface

const
  { the canonical races (goldbox-tp7's ids.md section 2, its CharType.RACE_*): the ones the temple's rules name }
  RACE_MONSTER = 0;
  RACE_HUMAN = 1;
  RACE_DWARF = 2;
  RACE_ELF = 3;
  RACE_GNOME = 4;
  RACE_HALFELF = 5;
  RACE_HALFLING = 6;
  RACE_HALFORC = 7;
  RACE_SILVANESTI = 8;
  RACE_QUALINESTI = 9;
  RACE_MOUNTAINDWARF = 10;
  RACE_HILLDWARF = 11;
  RACE_KENDER = 12;

  { the temple's services, in the order its Heal menu lists them }
  TS_CURE_BLIND = 0;
  TS_CURE_DISEASE = 1;
  TS_CURE_LIGHT = 2;
  TS_CURE_SERIOUS = 3;
  TS_CURE_CRITICAL = 4;
  TS_HEAL = 5;
  TS_NEUTRALIZE = 6;
  TS_RAISE = 7;
  TS_RESURRECT = 8;
  TS_REMOVE_CURSE = 9;
  TS_STONE = 10;
  TS_RESTORE = 11;
  TS_LAST = 11;

  { a price that means the temple does not sell the service; 0 is free }
  TP_NONE = -1;

  { the statuses the temple reads and sets: ids.md section 5's canonical ones, which are each temple game's own }
  TC_OKAY = 0;
  TC_ANIMATED = 1;
  TC_TEMPGONE = 2;
  TC_RUNNING = 3;
  TC_UNCONSCIOUS = 4;
  TC_DYING = 5;
  TC_DEAD = 6;
  TC_STONED = 7;
  TC_GONE = 8;

  { TTempleChar.flags: what the game's effects say of the character }
  TF_BLIND = $0001;
  { any disease effect }
  TF_DISEASED = $0002;
  TF_POISONED = $0004;
  { either Slow Poison effect: a death under it was a wound's, not the poison's }
  TF_SLOW_POISON = $0008;
  { a readied cursed item, or Bestow Curse }
  TF_CURSED = $0010;
  { mummy rot, which stops hit points coming back }
  TF_ROT = $0020;
  { a level lost to a drain that Restoration would give back }
  TF_DRAINED = $0040;
  { Feeblemind, which Heal ends }
  TF_FEEBLE = $0080;

  { TTempleDeed.acts, carried out by the game in this order: the effects first (blindness, the disease effects with
    the Strength they took given back, Poisoned and both Slow Poison effects, Animate Dead, Feeblemind with
    Intelligence and Wisdom recalculated, the curse by the game's Remove Curse, a drained level by its Restoration;
    the effect lock held where the game's own cures hold it), then the Constitution, then the status, then the hit
    points, then the counters }
  TA_BLIND = $0001;
  TA_DISEASE = $0002;
  TA_POISON = $0004;
  TA_ANIMATE = $0008;
  TA_FEEBLE = $0010;
  TA_CURSE = $0020;
  TA_RESTORE = $0040;
  { conLoss points off the permanent Constitution, and the maximum hit points they were worth }
  TA_LOSE_CON = $0080;
  { status := deed.status; the character is in play only when it is okay }
  TA_STATUS = $0100;
  { hit points := deed.hp }
  TA_SET_HP = $0200;
  { hit points := the maximum, as it stands after the Constitution }
  TA_FULL_HP = $0400;
  { deed.hp hit points back by the game's healing, which knows the statuses it heals and the maximum }
  TA_HEAL_HP = $0800;
  { the statistics: raised, or died }
  TA_RAISED = $1000;
  TA_DIED = $2000;

  { the temple's words (TempleText), each said after the character's name }
  TM_NONE = 0;
  TM_CURED = 1;
  TM_NOT_HELPED = 2;
  TM_NO_SURVIVE = 3;
  TM_SHOCK = 4;
  TM_NOT_BLIND = 5;
  TM_NOT_DISEASED = 6;
  TM_NOT_WOUNDED = 7;
  TM_IS_DEAD = 8;
  TM_IS_STONED = 9;
  TM_CANNOT_HEAL = 10;
  TM_ROT = 11;
  TM_NOT_DEAD = 12;
  TM_NOT_POISONED = 13;
  TM_NOT_CURSED = 14;
  TM_NOT_STONED = 15;
  TM_NOT_DRAINED = 16;
  TM_GONE = 17;
  TM_STILL_POISONED = 18;
  TM_NO_CON = 19;
  TM_ELF = 20;
  TM_RACE = 21;
  TM_LEVEL = 22;
  TM_RESURRECTED = 23;
  { the services' own words for a cure that worked, where TM_CURED would otherwise serve them all: Cure Blindness;
    a cure of wounds that brought hit points back, or a Heal; a Heal of a wounded character that also ended
    blindness, disease or Feeblemind; Neutralize Poison; Raise Dead; Remove Curse; Stone to Flesh }
  TM_SEES = 24;
  TM_HEALED = 25;
  TM_FULLY_HEALED = 26;
  TM_UNPOISONED = 27;
  TM_RAISED = 28;
  TM_UNCURSED = 29;
  TM_FLESH = 30;
  TM_LAST = 30;
  { not words: the report waits for the hit points (TM_HEALED when they rose, else TM_NOT_HELPED) }
  TM_BY_HP = 255;

type
  { canonical races (RACE_*) }
  TRaceSet = set of 0..31;

  { a temple's rules: the game's temple fills one }
  TTempleRules = record
    { each service's price in the game's coin; 0 free, TP_NONE not sold }
    price: array[0..TS_LAST] of LongInt;
    { the coin, as the quote names it: "gold", "steel" }
    coin: String[12];
    { the races Raise Dead and Resurrection bring back }
    raiseRaces: TRaceSet;
    resurrectRaces: TRaceSet;
    { the least highest class level each brings back; 0 for any }
    raiseMinLevel: Byte;
    resurrectMinLevel: Byte;
    { the points of permanent Constitution each costs, down to AbilAdj.SCORE_MIN }
    raiseConLoss: Byte;
    resurrectConLoss: Byte;
    { both roll resurrection survival on the permanent Constitution }
    survivalRoll: Boolean;
    { a failed survival roll leaves the character gone for good, not dead }
    failGone: Boolean;
    { Stone to Flesh rolls system shock on the current Constitution }
    stoneShock: Boolean;
  end;

  { the character as the temple sees it, read by the game from its record }
  TTempleChar = record
    { TC_* }
    status: Byte;
    hp, hpMax: Integer;
    { permanent and current Constitution }
    conPerm, conCur: Byte;
    { canonical race (RACE_*) }
    race: Byte;
    { its highest class level }
    level: Byte;
    { TF_* }
    flags: Word;
    { the levels Restoration would give back, one each: Repair buys that many }
    drained: Byte;
  end;

  { what a service does: TA_* in acts, with the values they take }
  TTempleDeed = record
    acts: Word;
    status: Byte;
    hp: Integer;
    conLoss: Byte;
    { TM_* }
    msg: Byte;
  end;

  { the game's side of TempleService }
  TTempleLook = procedure(var c: TTempleChar);
  { "<name> <msg>" and "cast cure anyway: "; True for Yes }
  TTempleAsk = function(msg: String): Boolean;
  { the quote, "pay for cure ", and the fee taken from the character or else the pool; True when it was paid }
  TTemplePay = function(quote: String; cost: LongInt): Boolean;
  { "<name> <msg>" in a cleared message window, until a key }
  TTempleSay = procedure(msg: String);
  TTempleDo = procedure(d: TTempleDeed);
  { the game's dice: n dice of sides }
  TTempleRoll = function(n, sides: Byte): Integer;
  { the game's own words for msg (TM_*), or '' for TempleText's }
  TTempleWords = function(msg: Byte): String;
  TTempleIO = record
    Look: TTempleLook;
    Ask: TTempleAsk;
    Pay: TTemplePay;
    Say: TTempleSay;
    Act: TTempleDo;
    Roll: TTempleRoll;
    Words: TTempleWords;
  end;

  { what Repair buys one character: how many of each service it needs, in RepairStep's order }
  TRepairPlan = record
    count: array[0..TS_LAST] of Byte;
    { TM_NONE, or why the temple will not bring the character back (TempleRefusal), which leaves it out of Repair }
    refusal: Byte;
  end;

{ A temple's rules before the game's: every service at TP_NONE, the coin "gold", Raise Dead and Resurrection for
  every race but the elves (the three elven RACE_*) and the monster, any level, a point of Constitution each, the
  survival roll and system shock on, a failure dead rather than gone. }
procedure DefaultRules(var r: TTempleRules);

{ The 1st-edition price list in gold, every service sold: Cure Blindness and Cure Disease 1000; Cure Light, Serious and
  Critical Wounds 100, 350 and 600; Heal 5000; Neutralize Poison 1000; Raise Dead 5500; Resurrection 11000; Remove
  Curse 3500; Stone to Flesh 2000; Restoration 7000. Each price is divided by div (2 for Krynn's steel; 1 for gold). }
procedure StandardPrices(var r: TTempleRules; divisor: Byte);

{ True when the temple sells service svc. }
function Offers(r: TTempleRules; svc: Byte): Boolean;

{ The services' names for the Heal menu: "Cure Blindness" .. "Restoration"; '' past TS_LAST. }
function ServiceName(svc: Byte): String;

{ The temple's shared words for msg (TM_*), each said after the character's name: "is cured." for every cure that
  worked (TM_CURED, TM_SEES .. TM_FLESH). }
function TempleText(msg: Byte): String;

{ A TTempleWords for a game with no words of its own: '' for every msg, so TempleText speaks. }
function NoWords(msg: Byte): String;

{ What the temple says for msg: io.Words's line, or TempleText's when the game has none. }
function TempleWords(io: TTempleIO; msg: Byte): String;

{ "<name> will only cost <cost> <coin> pieces.", the fee's quote. }
function TempleQuote(r: TTempleRules; svc: Byte; cost: LongInt): String;

{ Why the temple will not sell svc to c whatever is paid (TM_GONE, TM_STILL_POISONED, TM_NO_CON, TM_ELF, TM_RACE,
  TM_LEVEL), or TM_NONE. Only Raise Dead and Resurrection refuse, and only a character they would otherwise bring
  back, or one gone. }
function TempleRefusal(r: TTempleRules; svc: Byte; c: TTempleChar): Byte;

{ Why c does not need svc (TM_NOT_BLIND .. TM_NOT_DRAINED, TM_IS_DEAD, TM_IS_STONED, TM_CANNOT_HEAL, TM_ROT), or
  TM_NONE when it would help. }
function TempleNeed(svc: Byte; c: TTempleChar): Byte;

{ The dice svc rolls once paid for c: the cures' d8s and bonus, Heal's 1d4, Raise Dead's and Resurrection's d100 for
  survival, Stone to Flesh's d100 for system shock; n is 0 for none. }
procedure TempleDice(r: TTempleRules; svc: Byte; c: TTempleChar; var n, sides: Byte; var plus: Integer);

{ What svc does for c, paid for, with roll the sum of TempleDice's dice and plus (0 for none). }
procedure TempleDeed(r: TTempleRules; svc: Byte; c: TTempleChar; roll: Integer; var d: TTempleDeed);

{ Sells svc to the game's current character: TempleRefusal, TempleNeed (and the question when the temple charges),
  the fee, the dice, the deed and its report, through io. A service the temple does not sell does nothing. }
procedure TempleService(r: TTempleRules; svc: Byte; io: TTempleIO);

const
  { the services Repair carries out, in the order RepairStep gives them }
  REPAIR_STEPS = 7;

{ Repair's step i (1..REPAIR_STEPS): Neutralize Poison, Raise Dead, Stone to Flesh, Restoration, Heal, Cure Blindness,
  Cure Disease, so that the poison goes before Raise Dead would refuse the corpse, and the hit points are made whole
  last, after Restoration has given back what each level was worth. }
function RepairStep(i: Byte): Byte;

{ What Repair buys c (TRepairPlan), each service once unless noted, and only those the temple sells: Neutralize Poison
  for the poisoned; Raise Dead for the dead, whom the poison's cure did not bring back, and Stone to Flesh for the
  stoned; a Restoration for each lost level (c.drained); then Heal when it is wounded, has mummy rot or is
  feebleminded (it ends blindness and disease too), else Cure Blindness and Cure Disease as it needs them. Nothing for
  the animated dead, whom Raise Dead would bring back only when the player buys it on its own, nor for a character the
  temple refuses to raise (refusal, as TempleRefusal says it) or one gone (TM_GONE). }
procedure RepairPlan(r: TTempleRules; c: TTempleChar; var p: TRepairPlan);

{ The price of plan p: each service's price times the times it is bought. }
function RepairCost(r: TTempleRules; p: TRepairPlan): LongInt;

{ "Repairing the party will cost <cost> <coin> pieces.", Repair's one quote. }
function RepairQuote(r: TTempleRules; cost: LongInt): String;

{ Carries out plan p, paid for already, on the game's current character, with no question: each service's dice (Heal
  rolls none, and gives back every missing hit point), deed and act, in RepairStep's order. A failed survival roll or
  system shock is said and ends the plan; the rest is not done. Says TM_CURED once a plan with anything in it is done.
  Returns the price of the services left undone, for the game to give back. }
function TempleRepair(r: TTempleRules; p: TRepairPlan; io: TTempleIO): LongInt;

implementation

uses AbilAdj;

procedure DefaultRules(var r: TTempleRules);
var
  i: Byte;
begin
  for i := 0 to TS_LAST do
    r.price[i] := TP_NONE;
  r.coin := 'gold';
  r.raiseRaces := [RACE_HUMAN, RACE_DWARF, RACE_GNOME, RACE_HALFELF, RACE_HALFLING, RACE_HALFORC,
    RACE_MOUNTAINDWARF, RACE_HILLDWARF, RACE_KENDER];
  r.resurrectRaces := r.raiseRaces;
  r.raiseMinLevel := 0;
  r.resurrectMinLevel := 0;
  r.raiseConLoss := 1;
  r.resurrectConLoss := 1;
  r.survivalRoll := True;
  r.failGone := False;
  r.stoneShock := True;
end;

procedure StandardPrices(var r: TTempleRules; divisor: Byte);
const
  GOLD: array[0..TS_LAST] of Word = (1000, 1000, 100, 350, 600, 5000, 1000, 5500, 11000, 3500, 2000, 7000);
var
  i: Byte;
begin
  if divisor = 0 then
    divisor := 1;
  for i := 0 to TS_LAST do
    r.price[i] := GOLD[i] div divisor;
end;

function Offers(r: TTempleRules; svc: Byte): Boolean;
begin
  Offers := (svc <= TS_LAST) and (r.price[svc] >= 0);
end;

function ServiceName(svc: Byte): String;
begin
  case svc of
    TS_CURE_BLIND: ServiceName := 'Cure Blindness';
    TS_CURE_DISEASE: ServiceName := 'Cure Disease';
    TS_CURE_LIGHT: ServiceName := 'Cure Light Wounds';
    TS_CURE_SERIOUS: ServiceName := 'Cure Serious Wounds';
    TS_CURE_CRITICAL: ServiceName := 'Cure Critical Wounds';
    TS_HEAL: ServiceName := 'Heal';
    TS_NEUTRALIZE: ServiceName := 'Neutralize Poison';
    TS_RAISE: ServiceName := 'Raise Dead';
    TS_RESURRECT: ServiceName := 'Resurrection';
    TS_REMOVE_CURSE: ServiceName := 'Remove Curse';
    TS_STONE: ServiceName := 'Stone to Flesh';
    TS_RESTORE: ServiceName := 'Restoration';
  else
    ServiceName := '';
  end;
end;

function TempleText(msg: Byte): String;
begin
  case msg of
    TM_CURED, TM_SEES, TM_HEALED, TM_FULLY_HEALED, TM_UNPOISONED, TM_RAISED, TM_UNCURSED, TM_FLESH:
      TempleText := 'is cured.';
    TM_NOT_HELPED: TempleText := 'is not helped.';
    TM_NO_SURVIVE: TempleText := 'does not survive.';
    TM_SHOCK: TempleText := 'DOESN''T SURVIVE THE TRANSFORMATION.';
    TM_NOT_BLIND: TempleText := 'is not blind.';
    TM_NOT_DISEASED: TempleText := 'is not Diseased.';
    TM_NOT_WOUNDED: TempleText := 'is not wounded.';
    TM_IS_DEAD: TempleText := 'is dead.';
    TM_IS_STONED: TempleText := 'is stoned.';
    TM_CANNOT_HEAL: TempleText := 'cannot be healed.';
    TM_ROT: TempleText := 'has mummy rot, which stops healing.';
    TM_NOT_DEAD: TempleText := 'is not dead.';
    TM_NOT_POISONED: TempleText := 'is not poisoned.';
    TM_NOT_CURSED: TempleText := 'is not cursed.';
    TM_NOT_STONED: TempleText := 'is not stoned.';
    TM_NOT_DRAINED: TempleText := 'has lost no levels.';
    TM_GONE: TempleText := 'is beyond help.';
    TM_STILL_POISONED: TempleText := 'is still poisoned.';
    TM_NO_CON: TempleText := 'cannot be raised.';
    TM_ELF: TempleText := 'is an elf and cannot be raised.';
    TM_RACE: TempleText := 'cannot be raised.';
    TM_LEVEL: TempleText := 'is too inexperienced to be raised.';
    TM_RESURRECTED: TempleText := 'is resurrected.';
  else
    TempleText := '';
  end;
end;

function NoWords(msg: Byte): String;
begin
  NoWords := '';
end;

function TempleWords(io: TTempleIO; msg: Byte): String;
var
  s: String;
begin
  s := io.Words(msg);
  if s = '' then
    s := TempleText(msg);
  TempleWords := s;
end;

function TempleQuote(r: TTempleRules; svc: Byte; cost: LongInt): String;
var
  s: String[12];
begin
  Str(cost, s);
  TempleQuote := ServiceName(svc) + ' will only cost ' + s + ' ' + r.coin + ' pieces.';
end;

{ True when c is a corpse Raise Dead or Resurrection works on: dead, or animated dead. }
function IsCorpse(c: TTempleChar): Boolean;
begin
  IsCorpse := (c.status = TC_DEAD) or (c.status = TC_ANIMATED);
end;

function TempleRefusal(r: TTempleRules; svc: Byte; c: TTempleChar): Byte;
var
  races: TRaceSet;
  minLevel: Byte;
begin
  TempleRefusal := TM_NONE;
  if (svc <> TS_RAISE) and (svc <> TS_RESURRECT) then
    Exit;
  if c.status = TC_GONE then begin
    TempleRefusal := TM_GONE;
    Exit;
  end;
  if not IsCorpse(c) then
    Exit;
  if svc = TS_RAISE then begin
    races := r.raiseRaces;
    minLevel := r.raiseMinLevel;
  end else begin
    races := r.resurrectRaces;
    minLevel := r.resurrectMinLevel;
  end;
  if (svc = TS_RAISE) and (c.status = TC_DEAD) and (c.flags and TF_POISONED <> 0) then
    TempleRefusal := TM_STILL_POISONED
  else if c.conPerm = 0 then
    TempleRefusal := TM_NO_CON
  else if not ((c.race <= 31) and (c.race in races)) then begin
    if c.race in [RACE_ELF, RACE_SILVANESTI, RACE_QUALINESTI] then
      TempleRefusal := TM_ELF
    else
      TempleRefusal := TM_RACE;
  end else if c.level < minLevel then
    TempleRefusal := TM_LEVEL;
end;

{ Why a cure of wounds would not heal c: the statuses the games' healing works on are okay, animated, unconscious and
  dying, and then only a wounded one without mummy rot (woundsOnly False, for Heal, which cures the rot and needs no
  wound: only the status counts). }
function NoWoundCure(c: TTempleChar; woundsOnly: Boolean): Byte;
begin
  NoWoundCure := TM_NONE;
  case c.status of
    TC_OKAY, TC_ANIMATED, TC_UNCONSCIOUS, TC_DYING:
      if woundsOnly then begin
        if c.flags and TF_ROT <> 0 then
          NoWoundCure := TM_ROT
        else if c.hp >= c.hpMax then
          NoWoundCure := TM_NOT_WOUNDED;
      end;
    TC_DEAD: NoWoundCure := TM_IS_DEAD;
    TC_STONED: NoWoundCure := TM_IS_STONED;
  else
    NoWoundCure := TM_CANNOT_HEAL;
  end;
end;

function TempleNeed(svc: Byte; c: TTempleChar): Byte;
var
  m: Byte;
begin
  m := TM_NONE;
  case svc of
    TS_CURE_BLIND: if c.flags and TF_BLIND = 0 then m := TM_NOT_BLIND;
    TS_CURE_DISEASE: if c.flags and TF_DISEASED = 0 then m := TM_NOT_DISEASED;
    TS_CURE_LIGHT, TS_CURE_SERIOUS, TS_CURE_CRITICAL: m := NoWoundCure(c, True);
    TS_HEAL: m := NoWoundCure(c, False);
    TS_NEUTRALIZE: if c.flags and TF_POISONED = 0 then m := TM_NOT_POISONED;
    TS_RAISE, TS_RESURRECT: if not IsCorpse(c) then m := TM_NOT_DEAD;
    TS_REMOVE_CURSE: if c.flags and TF_CURSED = 0 then m := TM_NOT_CURSED;
    TS_STONE: if c.status <> TC_STONED then m := TM_NOT_STONED;
    TS_RESTORE: if c.flags and TF_DRAINED = 0 then m := TM_NOT_DRAINED;
  end;
  TempleNeed := m;
end;

procedure TempleDice(r: TTempleRules; svc: Byte; c: TTempleChar; var n, sides: Byte; var plus: Integer);
begin
  n := 0;
  sides := 0;
  plus := 0;
  case svc of
    TS_CURE_LIGHT: begin
        n := 1;
        sides := 8;
      end;
    TS_CURE_SERIOUS: begin
        n := 2;
        sides := 8;
        plus := 1;
      end;
    TS_CURE_CRITICAL: begin
        n := 3;
        sides := 8;
        plus := 3;
      end;
    TS_HEAL: begin
        n := 1;
        sides := 4;
      end;
    TS_RAISE, TS_RESURRECT:
      if r.survivalRoll and IsCorpse(c) then begin
        n := 1;
        sides := 100;
      end;
    TS_STONE:
      if r.stoneShock and (c.status = TC_STONED) then begin
        n := 1;
        sides := 100;
      end;
  end;
end;

{ The Constitution points a raise costs c: loss, but none below SCORE_MIN. }
function ConCost(c: TTempleChar; loss: Byte): Byte;
begin
  if c.conPerm <= AbilAdj.SCORE_MIN then
    ConCost := 0
  else if c.conPerm - loss < AbilAdj.SCORE_MIN then
    ConCost := c.conPerm - AbilAdj.SCORE_MIN
  else
    ConCost := loss;
end;

{ The deed of a paid Raise Dead or Resurrection for corpse c: the survival roll, then back okay at 1 hit point or the
  full maximum, with Animate Dead and the poison effects gone and the Constitution point taken. }
procedure Revive(r: TTempleRules; svc: Byte; c: TTempleChar; roll: Integer; var d: TTempleDeed);
var
  loss: Byte;
begin
  if r.survivalRoll and (roll > AbilAdj.ConResurrectionSurvival(c.conPerm)) then begin
    { a failure: as a death is marked, or gone for good }
    if r.failGone then begin
      d.acts := TA_ANIMATE or TA_STATUS or TA_SET_HP;
      d.status := TC_GONE;
      d.hp := 0;
    end;
    d.msg := TM_NO_SURVIVE;
    Exit;
  end;
  if svc = TS_RAISE then
    loss := r.raiseConLoss
  else
    loss := r.resurrectConLoss;
  d.conLoss := ConCost(c, loss);
  d.acts := TA_ANIMATE or TA_POISON or TA_STATUS or TA_RAISED;
  if d.conLoss > 0 then
    d.acts := d.acts or TA_LOSE_CON;
  d.status := TC_OKAY;
  if svc = TS_RAISE then begin
    d.acts := d.acts or TA_SET_HP;
    d.hp := 1;
    d.msg := TM_RAISED;
  end else begin
    d.acts := d.acts or TA_FULL_HP;
    d.msg := TM_RESURRECTED;
  end;
end;

procedure TempleDeed(r: TTempleRules; svc: Byte; c: TTempleChar; roll: Integer; var d: TTempleDeed);
var
  needed: Boolean;
  missing: Integer;
begin
  d.acts := 0;
  d.status := c.status;
  d.hp := 0;
  d.conLoss := 0;
  needed := TempleNeed(svc, c) = TM_NONE;
  if not needed then
    d.msg := TM_NOT_HELPED
  else
    case svc of
      TS_CURE_BLIND: d.msg := TM_SEES;
      TS_NEUTRALIZE: d.msg := TM_UNPOISONED;
      TS_REMOVE_CURSE: d.msg := TM_UNCURSED;
      TS_STONE: d.msg := TM_FLESH;
    else
      d.msg := TM_CURED;
    end;
  case svc of
    TS_CURE_BLIND: d.acts := TA_BLIND;
    TS_CURE_DISEASE: d.acts := TA_DISEASE;
    TS_CURE_LIGHT, TS_CURE_SERIOUS, TS_CURE_CRITICAL: begin
        d.acts := TA_HEAL_HP;
        if roll < 0 then
          roll := 0;
        d.hp := roll;
        d.msg := TM_BY_HP;
      end;
    TS_HEAL: begin
        { all but roll (1d4) of the missing hit points, none when fewer are missing }
        missing := c.hpMax - c.hp - roll;
        if missing < 0 then
          missing := 0;
        d.acts := TA_BLIND or TA_DISEASE or TA_FEEBLE or TA_HEAL_HP;
        d.hp := missing;
        { fully healed: hit points short and an ailment ended as well }
        if needed then
          if (c.hp < c.hpMax) and (c.flags and (TF_BLIND or TF_DISEASED or TF_FEEBLE) <> 0) then
            d.msg := TM_FULLY_HEALED
          else
            d.msg := TM_HEALED;
      end;
    TS_NEUTRALIZE: begin
        d.acts := TA_POISON;
        { the poison killed it, so curing the poison brings it back; a death under Slow Poison was a wound's, and a
          stoned, gone or animated character stays as it is }
        if (c.flags and TF_POISONED <> 0) and
            not (c.status in [TC_ANIMATED, TC_STONED, TC_GONE, TC_TEMPGONE, TC_RUNNING]) and
            ((c.status <> TC_DEAD) or (c.flags and TF_SLOW_POISON = 0)) then begin
          d.acts := d.acts or TA_STATUS;
          d.status := TC_OKAY;
          if c.hp <= 0 then begin
            d.acts := d.acts or TA_SET_HP;
            d.hp := 1;
          end;
        end;
      end;
    TS_RAISE, TS_RESURRECT:
      if needed and (TempleRefusal(r, svc, c) = TM_NONE) then
        Revive(r, svc, c, roll, d);
    TS_REMOVE_CURSE: d.acts := TA_CURSE;
    TS_STONE:
      if c.status = TC_STONED then begin
        d.acts := TA_STATUS or TA_SET_HP;
        if r.stoneShock and not AbilAdj.SurvivesSystemShock(c.conCur, roll) then begin
          { flesh again, and dead: as a death is marked out of combat }
          d.acts := d.acts or TA_DIED;
          d.status := TC_DEAD;
          d.hp := 0;
          d.msg := TM_SHOCK;
        end else begin
          d.status := TC_OKAY;
          d.hp := 1;
        end;
      end;
    TS_RESTORE: d.acts := TA_RESTORE;
  end;
end;

procedure TempleService(r: TTempleRules; svc: Byte; io: TTempleIO);
var
  c, after: TTempleChar;
  d: TTempleDeed;
  why: Byte;
  cost: LongInt;
  n, sides: Byte;
  plus, roll: Integer;
begin
  if not Offers(r, svc) then
    Exit;
  io.Look(c);
  why := TempleRefusal(r, svc, c);
  if why <> TM_NONE then begin
    io.Say(TempleWords(io, why));
    Exit;
  end;
  cost := r.price[svc];
  why := TempleNeed(svc, c);
  if why <> TM_NONE then
    { a free temple has nothing to lose by saying so; one that charges lets the player pay anyway }
    if cost = 0 then begin
      io.Say(TempleWords(io, why));
      Exit;
    end else if not io.Ask(TempleWords(io, why)) then
      Exit;
  if cost > 0 then
    if not io.Pay(TempleQuote(r, svc, cost), cost) then
      Exit;
  TempleDice(r, svc, c, n, sides, plus);
  roll := plus;
  if n > 0 then
    Inc(roll, io.Roll(n, sides));
  TempleDeed(r, svc, c, roll, d);
  io.Act(d);
  if d.msg = TM_BY_HP then begin
    io.Look(after);
    if after.hp > c.hp then
      d.msg := TM_HEALED
    else
      d.msg := TM_NOT_HELPED;
  end;
  io.Say(TempleWords(io, d.msg));
end;

function RepairStep(i: Byte): Byte;
begin
  case i of
    1: RepairStep := TS_NEUTRALIZE;
    2: RepairStep := TS_RAISE;
    3: RepairStep := TS_STONE;
    4: RepairStep := TS_RESTORE;
    5: RepairStep := TS_HEAL;
    6: RepairStep := TS_CURE_BLIND;
  else
    RepairStep := TS_CURE_DISEASE;
  end;
end;

{ What deed d leaves of c, as far as RepairPlan looks: the status, the hit points and the poison. }
procedure Suppose(var c: TTempleChar; d: TTempleDeed);
begin
  if d.acts and TA_POISON <> 0 then
    c.flags := c.flags and not (TF_POISONED or TF_SLOW_POISON);
  if d.acts and TA_STATUS <> 0 then
    c.status := d.status;
  if d.acts and TA_SET_HP <> 0 then
    c.hp := d.hp;
end;

procedure RepairPlan(r: TTempleRules; c: TTempleChar; var p: TRepairPlan);
var
  s: TTempleChar;
  d: TTempleDeed;
begin
  FillChar(p, SizeOf(p), 0);
  s := c;
  if s.status = TC_GONE then begin
    p.refusal := TM_GONE;
    Exit;
  end;
  if s.status in [TC_ANIMATED, TC_TEMPGONE, TC_RUNNING] then
    Exit;
  if (s.flags and TF_POISONED <> 0) and Offers(r, TS_NEUTRALIZE) then begin
    p.count[TS_NEUTRALIZE] := 1;
    TempleDeed(r, TS_NEUTRALIZE, s, 0, d);
    Suppose(s, d);
  end;
  if s.status = TC_DEAD then begin
    p.refusal := TempleRefusal(r, TS_RAISE, s);
    if (p.refusal <> TM_NONE) or not Offers(r, TS_RAISE) then begin
      { a corpse left dead needs nothing else the temple sells }
      FillChar(p.count, SizeOf(p.count), 0);
      Exit;
    end;
    p.count[TS_RAISE] := 1;
    { as the survival roll is made }
    TempleDeed(r, TS_RAISE, s, 1, d);
    Suppose(s, d);
  end else if (s.status = TC_STONED) and Offers(r, TS_STONE) then begin
    p.count[TS_STONE] := 1;
    { as system shock is survived }
    TempleDeed(r, TS_STONE, s, 1, d);
    Suppose(s, d);
  end;
  if (s.drained > 0) and Offers(r, TS_RESTORE) then
    p.count[TS_RESTORE] := s.drained;
  if Offers(r, TS_HEAL) and (NoWoundCure(s, False) = TM_NONE) and
      ((s.hp < s.hpMax) or (s.flags and (TF_ROT or TF_FEEBLE) <> 0)) then
    p.count[TS_HEAL] := 1
  else begin
    if (s.flags and TF_BLIND <> 0) and Offers(r, TS_CURE_BLIND) then
      p.count[TS_CURE_BLIND] := 1;
    if (s.flags and TF_DISEASED <> 0) and Offers(r, TS_CURE_DISEASE) then
      p.count[TS_CURE_DISEASE] := 1;
  end;
end;

function RepairCost(r: TTempleRules; p: TRepairPlan): LongInt;
var
  i: Byte;
  cost: LongInt;
begin
  cost := 0;
  for i := 0 to TS_LAST do
    if (p.count[i] > 0) and (r.price[i] > 0) then
      Inc(cost, r.price[i] * p.count[i]);
  RepairCost := cost;
end;

function RepairQuote(r: TTempleRules; cost: LongInt): String;
var
  s: String[12];
begin
  Str(cost, s);
  RepairQuote := 'Repairing the party will cost ' + s + ' ' + r.coin + ' pieces.';
end;

function TempleRepair(r: TTempleRules; p: TRepairPlan; io: TTempleIO): LongInt;
var
  c: TTempleChar;
  d: TTempleDeed;
  step, svc, k: Byte;
  n, sides: Byte;
  plus, roll: Integer;
  undone: LongInt;
  failed: Boolean;
  any: Boolean;
begin
  undone := 0;
  failed := False;
  any := False;
  for step := 1 to REPAIR_STEPS do begin
    svc := RepairStep(step);
    for k := 1 to p.count[svc] do
      if failed then begin
        if r.price[svc] > 0 then
          Inc(undone, r.price[svc]);
      end else begin
        any := True;
        io.Look(c);
        roll := 0;
        if svc <> TS_HEAL then begin
          TempleDice(r, svc, c, n, sides, plus);
          roll := plus;
          if n > 0 then
            Inc(roll, io.Roll(n, sides));
        end;
        TempleDeed(r, svc, c, roll, d);
        io.Act(d);
        if (d.msg = TM_NO_SURVIVE) or (d.msg = TM_SHOCK) then begin
          io.Say(TempleWords(io, d.msg));
          failed := True;
        end;
      end;
  end;
  if any and not failed then
    io.Say(TempleWords(io, TM_CURED));
  TempleRepair := undone;
end;

end.

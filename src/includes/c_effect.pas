{ Effect IDs: TEffectRec.id values used by FxEngine.AddEffect, FxEngine.RemoveEffect and CharHlp.HasEffect, and indices
  into EffHndlr's handler table. }
unit C_Effect;

interface

const
  BLESS = 1;
  CURSE = 2;
  UNDEAD_SLAYER = 3;
  TRAIN_START = 4;
  { EffNull handler; item labels mark magic items while any creature has it }
  DETECT_MAGIC = 5;
  FLAME_TONGUE = 6;
  TRAIN_MANUAL = 7;
  PROT_EVIL = 8;
  PROT_GOOD = 9;
  RESIST_COLD = 10;
  CHARM = 11;
  ENLARGE = 12;
  { EffNull handler. }
  REDUCE = 13;
  FRIENDS = 14;
  SLOW_POISON_HIT = 15;
  READ_MAGIC = 16;
  SHIELD = 17;
  GNOME_THAC0 = 18;
  { EffNull handler. }
  FIND_TRAPS = 19;
  RESIST_FIRE = 20;
  SILENCE = 21;
  SLOW_POISON_END = 22;
  SPIRIT_HAMMER = 23;
  SEE_INVISIBLE = 24;
  INVISIBLE = 25;
  DWARF_THAC0 = 26;
  { EffNull handler; readying the Ring of Feather Falling adds it }
  FEATHER_FALL = 27;
  MIRROR_IMAGE = 28;
  ENFEEBLE = 29;
  STINK_COUGH = 30;
  HELPLESS = 31;
  ANIMATE_DEAD = 32;
  BLIND = 33;
  DISEASED = 34;
  { Prayer's bonus alone: +1 to attack and saving throws. PRAYER grants it to the caster's side. }
  ALLIED_PRAYER = 35;
  BESTOW_CURSE = 36;
  BLINKING = 37;
  STRENGTH = 38;
  { EclMenu.MoveExtremes doubles movement on it }
  HASTED = 39;
  CAST_STINK = 40;
  PROT_MISSILES = 41;
  SLOWED = 42;
  DISEASE_STR = 43;
  DISEASE_HP = 44;
  { Shares the effect 8 handler, EffProtEvil. }
  PROT_EVIL_10FT = 45;
  { Shares the effect 9 handler, EffProtGood. }
  PROT_GOOD_10FT = 46;
  DWARF_AC_GIANT = 47;
  GNOME_AC_BUG = 48;
  PRAYER = 49;
  ROT_NO_HEAL = 50;
  { Shares the effect 31 handler, EffHelpless. }
  SNAKE_CHARM = 51;
  PARALYSIS = 52;
  SLEEP = 53;
  { Dragon fear, toned down for the game: the handler does nothing, so the effect only marks the creature and camp lists
    it as Repulsed. The full fear effect is DRAGON_FEAR. }
  DRAGON_AURA = 54;
  POISONED = 55;
  RING_INVIS = 56;
  MUMMY_ROT = 57;
  IMMOBILE = 58;
  TROLL_REGEN = 59;
  RING_FIRE_RES = 61;
  CON_REGEN = 62;
  POISON_HIT0 = 64;
  POISON_HIT4 = 65;
  POISON_HIT2 = 66;
  KREEN_PARA = 67;
  GHOUL_PARA = 68;
  DRIDER_PARA = 69;
  POISON_HIT_M2 = 70;
  { Dust of Disappearance: a stronger form of invisibility than INVISIBLE; camp lists it as Invisible. }
  DUST_DISAPPEAR = 71;
  CAMOUFLAGE = 72;
  REAR_CLAW_RAKE = 73;
  BITE_HOLD = 74;
  BLOOD_DRAIN = 75;
  BLOOD_ATTACH = 76;
  { EffBiteHold applies BITE_HOLD. }
  BITE_ATTACH = 77;
  HEAL_WAKE = 78;
  FIRE_TOUCH = 79;
  ACID_SQUIRT = 80;
  DRAGON_FEAR = 81;
  MUMMY_FEAR = 82;
  PETRIFY_GAZE = 83;
  CHARM_GAZE = 84;
  DRAIN_ONE = 85;
  DRAIN_TWO = 86;
  ROT_TOUCH = 87;
  DRAGON_BREATH = 88;
  DISPLACED = 89;
  CON_PSN_SAVE = 90;
  IMMUNE_MM = 91;
  HALF_FIRE = 93;
  HALF_BASH = 94;
  FIGHT_ON = 95;
  NEED_SILVER = 96;
  CON_SPELL_SAVE = 97;
  REGEN3 = 98;
  CAN_FIGHT_ON = 99;
  TROLL_BURN = 100;
  TROLL_HEAL = 101;
  TROLL_RETURN = 102;
  GASEOUS = 103;
  KREEN_DODGE = 104;
  MAGIC_RES50 = 105;
  MAGIC_RES85 = 106;
  ELF_RESIST = 107;
  NO_SLEEP_CHARM = 108;
  NO_PARALYSIS = 109;
  NO_COLD = 110;
  NO_PARA_POISON = 111;
  NO_FIRE = 112;
  EFREETI_FIRE = 113;
  HALF_ELEC = 114;
  HALF_PIERCE = 115;
  HALF_MAGICAL = 116;
  HOLY_WATER = 117;
  HALF_COLD = 118;
  NEED_MAGIC = 119;
  BOULDER_DODGE = 120;
  ANHKHEG_ACID = 121;
  MUMMY_FIRE = 122;
  SILVER_MAGIC = 123;
  HALF_ELF_RESIST = 124;
  NO_CHARM_POISON = 125;
  GAZE_BLOCK = 126;
  GAZE_REFLECTABLE = 127;
  { Ring of Feather Falling, effect 27 }
  READY_FEATHER_FALL = 128;
  { Ring of Fire Resistance, effect 61 }
  READY_FIRE_RES = 129;
  { Gauntlets of Ogre Power, effect 38 }
  GAUNTLETS = 131;
  ALIGNED_WEAPON = 132;
  { Cloak of Displacement, effect 89 }
  READY_DISPLACEMENT = 133;
  { Cloak of Elvenkind, effect 72 }
  READY_ELVENKIND = 134;
  BOULDER = 135;
  { Spiritual Hammer TItemRec.special, run when unreadied }
  SPIRIT_HAMMER_GONE = 137;
  { Ring of Invisibility, effect 56 }
  READY_RING_INVIS = 139;
  { A paladin has laid on hands today. }
  RECENT_HEAL = 140;
  { A paladin's week of curing disease; the strength counts the cures made. }
  RECENT_CURE = 141;

implementation

end.

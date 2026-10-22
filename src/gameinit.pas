{ Initialize game state, allocate graphics buffers, load shared resources and install spell and effect handlers. }
{$O+,F+,I-}
{$I COMPILER.INC}
unit GameInit;

interface

{ Allocate the GBVM zones and graphics buffers, build the per-row video address tables and reset the game state to its
  defaults, then load the font, symbol sets, tile sets, combat icons and item table, read the settings from POOLOPT.CFG
  (Options.LoadOptions), seed the random numbers (with 1 when NORAND is the second argument) and install the spell and
  effect handlers. }
procedure GameInit2;

{ Puts the game in a new game's state, as at startup: the GBVM banks cleared, the party at (15, 1) facing west in the 3D
  map with no members, the script at its start and the game's statistics cleared. The settings, the loaded pictures and
  wall sets, and their caches, are left alone. GameInit2 calls it; so does the main program after a party is destroyed,
  having freed the party (SaveLoad.FreeParty), before the main menu. }
procedure ResetGameState;

implementation

uses Types, Crt, C_Area, GDConsts, GDVars, Sym8x8, MapTiles, Magic, EffHndlr, C_Dir, Options, Blit, DaxIo, GameIo,
  MenuCore, SoundDrv, TextRend, C_Gbvm, CbtActs, C_Effect, CbtMap, MemShow, CharHlp, CharDisp, EclVars, View3D, HeapErr,
  VidOps, Stats, Explored, MapNotes{$IFDEF FPC}, TpRand{$ENDIF};

var
  { directory saved across resource loading }
  savedDir: Types.TPathStr;
  { ITEMS loading file record }
  itemsFile: file;
  { bytes read from ITEMS }
  itemsRead: Word;

{ Install every spell handler in GDVars.spellFns, the noncombat cast-target menu, and Magic.DragonBreathHandler as
  effect 88's handler; clear effectLock, GDVars.usingItem and GDVars.castTarget, and set dsRedrawInventoryMenuFlag. }
procedure InitSpellFns;
begin
  GDVars.castTargetMenu := Magic.NoncombatCastTargetMenu;
  GDVars.effectLock := 0;
  GDVars.usingItem := False;
  GDVars.castTarget := nil;
  GDVars.dsRedrawInventoryMenuFlag := 1;
  GDVars.spellFns[1] := Magic.BlessHandler;
  GDVars.spellFns[2] := Magic.CurseHandler;
  GDVars.spellFns[3] := Magic.CureLightWoundsHandler;
  GDVars.spellFns[4] := Magic.CauseLightWoundsHandler;
  GDVars.spellFns[5] := Magic.DetectionHandler;
  GDVars.spellFns[6] := Magic.ProtectionHandler;
  GDVars.spellFns[7] := Magic.ProtectionHandler;
  GDVars.spellFns[8] := Magic.ResistColdHandler;
  GDVars.spellFns[9] := Magic.BurningHandsHandler;
  GDVars.spellFns[10] := Magic.CharmPersonHandler;
  GDVars.spellFns[11] := Magic.DetectionHandler;
  GDVars.spellFns[12] := Magic.EnlargeHandler;
  GDVars.spellFns[13] := Magic.ReduceHandler;
  GDVars.spellFns[14] := Magic.FriendsHandler;
  GDVars.spellFns[15] := Magic.MagicMissileHandler;
  GDVars.spellFns[16] := Magic.ProtectionHandler;
  GDVars.spellFns[17] := Magic.ProtectionHandler;
  GDVars.spellFns[18] := Magic.DetectionHandler;
  GDVars.spellFns[19] := Magic.ShieldHandler;
  GDVars.spellFns[20] := Magic.ShockingGraspHandler;
  GDVars.spellFns[21] := Magic.SleepHandler;
  GDVars.spellFns[22] := Magic.DetectionHandler;
  GDVars.spellFns[23] := Magic.HoldPersonHandler;
  GDVars.spellFns[24] := Magic.ResistFireHandler;
  GDVars.spellFns[25] := Magic.SilenceHandler;
  GDVars.spellFns[26] := Magic.SlowPoisonHandler;
  GDVars.spellFns[27] := Magic.SnakeCharmHandler;
  GDVars.spellFns[28] := Magic.SpiritualHammerHandler;
  GDVars.spellFns[29] := Magic.DetectionHandler;
  GDVars.spellFns[30] := Magic.InvisibilityHandler;
  GDVars.spellFns[31] := Magic.KnockHandler;
  GDVars.spellFns[32] := Magic.MirrorImageHandler;
  GDVars.spellFns[33] := Magic.RayOfEnfeeblementHandler;
  GDVars.spellFns[34] := Magic.StinkingCloudHandler;
  GDVars.spellFns[35] := Magic.StrengthHandler;
  GDVars.spellFns[36] := Magic.AnimateDeadHandler;
  GDVars.spellFns[37] := Magic.CureBlindnessHandler;
  GDVars.spellFns[38] := Magic.CauseBlindnessHandler;
  GDVars.spellFns[39] := Magic.CureDiseaseHandler;
  GDVars.spellFns[40] := Magic.CauseDiseaseHandler;
  GDVars.spellFns[41] := Magic.DispelMagicHandler;
  GDVars.spellFns[42] := Magic.PrayerHandler;
  GDVars.spellFns[43] := Magic.RemoveCurseSpell;
  GDVars.spellFns[44] := Magic.BestowCurseHandler;
  GDVars.spellFns[45] := Magic.BlinkHandler;
  GDVars.spellFns[46] := Magic.DispelMagicHandler;
  GDVars.spellFns[47] := Magic.FireballHandler;
  GDVars.spellFns[48] := Magic.HasteHandler;
  GDVars.spellFns[49] := Magic.HoldPersonHandler;
  GDVars.spellFns[50] := Magic.InvisibilityHandler;
  GDVars.spellFns[51] := Magic.LightningBoltHandler;
  GDVars.spellFns[52] := Magic.ProtectionHandler;
  GDVars.spellFns[53] := Magic.ProtectionHandler;
  GDVars.spellFns[54] := Magic.ProtectionHandler;
  GDVars.spellFns[55] := Magic.SlowHandler;
  GDVars.spellFns[56] := Magic.RestorationHandler;
  GDVars.spellFns[57] := Magic.PotionOfSpeedHandler;
  GDVars.spellFns[58] := Magic.KeoghtomsOintmentHandler;
  GDVars.spellFns[59] := Magic.GiantStrengthHandler;
  GDVars.spellFns[60] := Magic.JavelinOfLightningHandler;
  GDVars.spellFns[61] := Magic.WandParalyzationHandler;
  GDVars.spellFns[62] := Magic.PotionOfHealingHandler;
  GDVars.spellFns[63] := Magic.DustDisappearanceHandler;
  GDVars.spellFns[64] := Magic.FireballHandler;
  GDVars.spellFns[65] := Magic.WandMagicMissilesHandler;
  GDVars.spellFns[66] := Magic.UnusedSpellHandler;
  GDVars.spellFns[67] := Magic.ManualBodilyHealthHandler;
  GDVars.effectFns[88] := Magic.DragonBreathHandler;
end;

{ Install the effect handlers. InitSpellFns assigns slot 88 (Magic.DragonBreathHandler); slots 73 and 74 use the CbtActs
  combat action handlers. }
procedure InitEffectHandlers;
begin
  GDVars.effectFns[C_Effect.BLESS] := EffHndlr.EffBless;
  GDVars.effectFns[C_Effect.CURSE] := EffHndlr.EffCurse;
  GDVars.effectFns[C_Effect.UNDEAD_SLAYER] := EffHndlr.EffUndeadSlayer;
  GDVars.effectFns[C_Effect.TRAIN_START] := EffHndlr.EffTrainStart;
  GDVars.effectFns[C_Effect.DETECT_MAGIC] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.FLAME_TONGUE] := EffHndlr.EffFlameTongue;
  GDVars.effectFns[C_Effect.TRAIN_MANUAL] := EffHndlr.EffTrainManual;
  GDVars.effectFns[C_Effect.PROT_EVIL] := EffHndlr.EffProtEvil;
  GDVars.effectFns[C_Effect.PROT_GOOD] := EffHndlr.EffProtGood;
  GDVars.effectFns[C_Effect.RESIST_COLD] := EffHndlr.EffResistCold;
  GDVars.effectFns[C_Effect.CHARM] := EffHndlr.EffCharm;
  GDVars.effectFns[C_Effect.ENLARGE] := EffHndlr.EffExtraStr;
  GDVars.effectFns[C_Effect.REDUCE] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.FRIENDS] := EffHndlr.EffFriends;
  GDVars.effectFns[C_Effect.SLOW_POISON_HIT] := EffHndlr.EffSlowPoisonHit;
  GDVars.effectFns[C_Effect.READ_MAGIC] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.SHIELD] := EffHndlr.EffShield;
  GDVars.effectFns[C_Effect.GNOME_THAC0] := EffHndlr.EffGnomeThac0;
  GDVars.effectFns[C_Effect.FIND_TRAPS] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.RESIST_FIRE] := EffHndlr.EffResistFire;
  GDVars.effectFns[C_Effect.SILENCE] := EffHndlr.EffSilence;
  GDVars.effectFns[C_Effect.SLOW_POISON_END] := EffHndlr.EffSlowPoisonEnd;
  GDVars.effectFns[C_Effect.SPIRIT_HAMMER] := EffHndlr.EffSpiritHammer;
  GDVars.effectFns[C_Effect.SEE_INVISIBLE] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.INVISIBLE] := EffHndlr.EffInvisible;
  GDVars.effectFns[C_Effect.DWARF_THAC0] := EffHndlr.EffDwarfThac0;
  GDVars.effectFns[C_Effect.FEATHER_FALL] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.MIRROR_IMAGE] := EffHndlr.EffMirrorImage;
  GDVars.effectFns[C_Effect.ENFEEBLE] := EffHndlr.EffEnfeeble;
  GDVars.effectFns[C_Effect.STINK_COUGH] := EffHndlr.EffStinkCough;
  GDVars.effectFns[C_Effect.HELPLESS] := EffHndlr.EffHelpless;
  GDVars.effectFns[C_Effect.ANIMATE_DEAD] := EffHndlr.EffAnimateDead;
  GDVars.effectFns[C_Effect.BLIND] := EffHndlr.EffBlind;
  GDVars.effectFns[C_Effect.DISEASED] := EffHndlr.EffDiseased;
  GDVars.effectFns[C_Effect.ALLIED_PRAYER] := EffHndlr.EffAlliedPrayer;
  GDVars.effectFns[C_Effect.BESTOW_CURSE] := EffHndlr.EffBestowCurse;
  GDVars.effectFns[C_Effect.BLINKING] := EffHndlr.EffBlinking;
  GDVars.effectFns[C_Effect.STRENGTH] := EffHndlr.EffExtraStr;
  GDVars.effectFns[C_Effect.HASTED] := EffHndlr.EffHasted;
  GDVars.effectFns[C_Effect.CAST_STINK] := EffHndlr.EffCastStink;
  GDVars.effectFns[C_Effect.PROT_MISSILES] := EffHndlr.EffProtMissiles;
  GDVars.effectFns[C_Effect.SLOWED] := EffHndlr.EffSlowed;
  GDVars.effectFns[C_Effect.DISEASE_STR] := EffHndlr.EffDiseaseStr;
  GDVars.effectFns[C_Effect.DISEASE_HP] := EffHndlr.EffDiseaseHp;
  GDVars.effectFns[C_Effect.PROT_EVIL_10FT] := EffHndlr.EffProtEvil;
  GDVars.effectFns[C_Effect.PROT_GOOD_10FT] := EffHndlr.EffProtGood;
  GDVars.effectFns[C_Effect.DWARF_AC_GIANT] := EffHndlr.EffDwarfAcGiant;
  GDVars.effectFns[C_Effect.GNOME_AC_BUG] := EffHndlr.EffGnomeAcBug;
  GDVars.effectFns[C_Effect.PRAYER] := EffHndlr.EffPrayer;
  GDVars.effectFns[C_Effect.ROT_NO_HEAL] := EffHndlr.EffRotNoHeal;
  GDVars.effectFns[C_Effect.SNAKE_CHARM] := EffHndlr.EffHelpless;
  GDVars.effectFns[C_Effect.PARALYSIS] := EffHndlr.EffHelpless;
  GDVars.effectFns[C_Effect.SLEEP] := EffHndlr.EffHelpless;
  { A milder dragon fear that only marks the creature (camp lists it as Repulsed); the full fear is DRAGON_FEAR. }
  GDVars.effectFns[C_Effect.DRAGON_AURA] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.POISONED] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.RING_INVIS] := EffHndlr.EffRingInvis;
  GDVars.effectFns[C_Effect.MUMMY_ROT] := EffHndlr.EffMummyRot;
  GDVars.effectFns[C_Effect.IMMOBILE] := EffHndlr.EffImmobile;
  GDVars.effectFns[C_Effect.TROLL_REGEN] := EffHndlr.EffTrollRegen;
  GDVars.effectFns[C_Effect.NULL_DAMAGE] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.RING_FIRE_RES] := EffHndlr.EffRingFireRes;
  GDVars.effectFns[C_Effect.CON_REGEN] := EffHndlr.EffConRegen;
  GDVars.effectFns[C_Effect.NULL_TARGET_VETO] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.POISON_HIT0] := EffHndlr.EffPoisonHit0;
  GDVars.effectFns[C_Effect.POISON_HIT4] := EffHndlr.EffPoisonHit4;
  GDVars.effectFns[C_Effect.POISON_HIT2] := EffHndlr.EffPoisonHit2;
  GDVars.effectFns[C_Effect.KREEN_PARA] := EffHndlr.EffKreenPara;
  GDVars.effectFns[C_Effect.GHOUL_PARA] := EffHndlr.EffGhoulPara;
  GDVars.effectFns[C_Effect.DRIDER_PARA] := EffHndlr.EffDriderPara;
  GDVars.effectFns[C_Effect.POISON_HIT_M2] := EffHndlr.EffPoisonHitM2;
  GDVars.effectFns[C_Effect.DUST_DISAPPEAR] := EffHndlr.EffDustDisappear;
  GDVars.effectFns[C_Effect.CAMOUFLAGE] := EffHndlr.EffCamouflage;
  GDVars.effectFns[C_Effect.REAR_CLAW_RAKE] := CbtActs.RearClawRake;
  GDVars.effectFns[C_Effect.BITE_HOLD] := CbtActs.BiteAndHold;
  GDVars.effectFns[C_Effect.BLOOD_DRAIN] := EffHndlr.EffBloodDrain;
  GDVars.effectFns[C_Effect.BLOOD_ATTACH] := EffHndlr.EffBloodAttach;
  GDVars.effectFns[C_Effect.BITE_ATTACH] := EffHndlr.EffBiteHold;
  GDVars.effectFns[C_Effect.HEAL_WAKE] := EffHndlr.EffHealWake;
  GDVars.effectFns[C_Effect.FIRE_TOUCH] := EffHndlr.EffFireTouch;
  GDVars.effectFns[C_Effect.ACID_SQUIRT] := EffHndlr.EffAcidSquirt;
  GDVars.effectFns[C_Effect.DRAGON_FEAR] := EffHndlr.EffDragonFear;
  GDVars.effectFns[C_Effect.MUMMY_FEAR] := EffHndlr.EffMummyFear;
  GDVars.effectFns[C_Effect.PETRIFY_GAZE] := EffHndlr.EffPetrifyGaze;
  GDVars.effectFns[C_Effect.CHARM_GAZE] := EffHndlr.EffCharmGaze;
  GDVars.effectFns[C_Effect.DRAIN_ONE] := EffHndlr.EffDrainOne;
  GDVars.effectFns[C_Effect.DRAIN_TWO] := EffHndlr.EffDrainTwo;
  GDVars.effectFns[C_Effect.ROT_TOUCH] := EffHndlr.EffRotTouch;
  GDVars.effectFns[C_Effect.DISPLACED] := EffHndlr.EffDisplaced;
  GDVars.effectFns[C_Effect.CON_PSN_SAVE] := EffHndlr.EffConPsnSave;
  GDVars.effectFns[C_Effect.IMMUNE_MM] := EffHndlr.EffImmuneMM;
  GDVars.effectFns[92] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.HALF_FIRE] := EffHndlr.EffHalfFire;
  GDVars.effectFns[C_Effect.HALF_BASH] := EffHndlr.EffHalfBash;
  GDVars.effectFns[C_Effect.FIGHT_ON] := EffHndlr.EffFightOn;
  GDVars.effectFns[C_Effect.NEED_SILVER] := EffHndlr.EffNeedSilver;
  GDVars.effectFns[C_Effect.CON_SPELL_SAVE] := EffHndlr.EffConSpellSave;
  GDVars.effectFns[C_Effect.REGEN3] := EffHndlr.EffRegen3;
  GDVars.effectFns[C_Effect.CAN_FIGHT_ON] := EffHndlr.EffCanFightOn;
  GDVars.effectFns[C_Effect.TROLL_BURN] := EffHndlr.EffTrollBurn;
  GDVars.effectFns[C_Effect.TROLL_HEAL] := EffHndlr.EffTrollHeal;
  GDVars.effectFns[C_Effect.TROLL_RETURN] := EffHndlr.EffTrollReturn;
  GDVars.effectFns[C_Effect.GASEOUS] := EffHndlr.EffGaseous;
  GDVars.effectFns[C_Effect.KREEN_DODGE] := EffHndlr.EffKreenDodge;
  GDVars.effectFns[C_Effect.MAGIC_RES50] := EffHndlr.EffMagicRes50;
  GDVars.effectFns[C_Effect.MAGIC_RES85] := EffHndlr.EffMagicRes85;
  GDVars.effectFns[C_Effect.ELF_RESIST] := EffHndlr.EffElfResist;
  GDVars.effectFns[C_Effect.NO_SLEEP_CHARM] := EffHndlr.EffNoSleepCharm;
  GDVars.effectFns[C_Effect.NO_PARALYSIS] := EffHndlr.EffNoParalysis;
  GDVars.effectFns[C_Effect.NO_COLD] := EffHndlr.EffNoCold;
  GDVars.effectFns[C_Effect.NO_PARA_POISON] := EffHndlr.EffNoParaPoison;
  GDVars.effectFns[C_Effect.NO_FIRE] := EffHndlr.EffNoFire;
  GDVars.effectFns[C_Effect.EFREETI_FIRE] := EffHndlr.EffEfreetiFire;
  GDVars.effectFns[C_Effect.HALF_ELEC] := EffHndlr.EffHalfElec;
  GDVars.effectFns[C_Effect.HALF_PIERCE] := EffHndlr.EffHalfPierce;
  GDVars.effectFns[C_Effect.HALF_MAGICAL] := EffHndlr.EffHalfMagical;
  GDVars.effectFns[C_Effect.HOLY_WATER] := EffHndlr.EffHolyWater;
  GDVars.effectFns[C_Effect.HALF_COLD] := EffHndlr.EffHalfCold;
  GDVars.effectFns[C_Effect.NEED_MAGIC] := EffHndlr.EffNeedMagic;
  GDVars.effectFns[C_Effect.BOULDER_DODGE] := EffHndlr.EffBoulderDodge;
  GDVars.effectFns[C_Effect.ANHKHEG_ACID] := EffHndlr.EffAnhkhegAcid;
  GDVars.effectFns[C_Effect.MUMMY_FIRE] := EffHndlr.EffMummyFire;
  GDVars.effectFns[C_Effect.SILVER_MAGIC] := EffHndlr.EffSilverMagic;
  GDVars.effectFns[C_Effect.HALF_ELF_RESIST] := EffHndlr.EffHalfElfResist;
  GDVars.effectFns[C_Effect.NO_CHARM_POISON] := EffHndlr.EffNoCharmPoison;
  GDVars.effectFns[C_Effect.GAZE_BLOCK] := EffHndlr.EffGazeBlock;
  GDVars.effectFns[C_Effect.GAZE_REFLECTABLE] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.READY_FEATHER_FALL] := EffHndlr.EffReadyItem;
  GDVars.effectFns[C_Effect.READY_FIRE_RES] := EffHndlr.EffReadyItem;
  GDVars.effectFns[130] := EffHndlr.EffReadyItem;
  GDVars.effectFns[C_Effect.GAUNTLETS] := EffHndlr.EffGauntlets;
  GDVars.effectFns[C_Effect.ALIGNED_WEAPON] := EffHndlr.EffAlignedWeapon;
  GDVars.effectFns[C_Effect.READY_DISPLACEMENT] := EffHndlr.EffReadyItem;
  GDVars.effectFns[C_Effect.READY_ELVENKIND] := EffHndlr.EffReadyItem;
  GDVars.effectFns[C_Effect.BOULDER] := EffHndlr.EffBoulder;
  GDVars.effectFns[136] := EffHndlr.EffReadyItem;
  GDVars.effectFns[C_Effect.SPIRIT_HAMMER_GONE] := EffHndlr.EffHammerGone;
  GDVars.effectFns[138] := EffHndlr.EffReadyItem;
  GDVars.effectFns[C_Effect.READY_RING_INVIS] := EffHndlr.EffReadyItem;
  GDVars.effectFns[C_Effect.RECENT_HEAL] := EffHndlr.EffNull;
  GDVars.effectFns[C_Effect.RECENT_CURE] := EffHndlr.EffNull;
end;

procedure ResetGameState;
begin
  Explored.Clear;
  MapNotes.Clear;
  FillChar(GDVars.zone0^, SizeOf(GDVars.zone0^), 0);
  FillChar(GDVars.zone1^, SizeOf(GDVars.zone1^), 0);
  FillChar(GDVars.zone2^, SizeOf(GDVars.zone2^), 0);
  FillChar(GDVars.zone3^, SizeOf(GDVars.zone3^), 0);
  GDVars.wallAhead := 0;
  GDVars.eventAtCell := 0;
  GDVars.gMapX := 15;
  GDVars.gMapY := 1;
  GDVars.gFacing := C_Dir.WEST;
  FillChar(GDVars.doorOpen, SizeOf(GDVars.doorOpen), 1);
  GDVars.debugTraceEnabled := False;
  GDVars.bottomLineTaken := False;
  GDVars.loadedSave := 0;
  GDVars.restTicks := 0;
  GDVars.creatureList := nil;
  GDVars.curChar := nil;
  GDVars.eclIp := $9900;
  GDVars.suppressContinuePrompt := 0;
  GDVars.virtualDisk := 1;
  GDVars.prevVirtualDisk := 1;
  GDVars.automapOn := False;
  GDVars.locTypePrev := C_Area.LOC_3D_MAP;
  GDVars.gLocType := C_Area.LOC_3D_MAP;
  GDVars.zone1^[C_Gbvm.PARTY_SIZE] := 0;
  GDVars.dsWildAnimFrame := 0;
  GDVars.vertTop := 1;
  GDVars.duelFlag := False;
  GDVars.dsSuppressDrawingBorderFlag := 0;
  GDVars.dsSearchModeFlag := 0;
  GDVars.dsEcl3dClearFlag := 0;
  GDVars.protNewLine := 0;
  GDVars.eclGraphics := False;
  GDVars.partyDefeated := False;
  GDVars.clipFlag := 1;
  GDVars.sprShown := False;
  GDVars.dsSuppressingInsertDiskFlag := False;
  GDVars.picArcName[0] := #0;
  GDVars.picArcId := 255;
  GDVars.recentSaved := 0;
  GDVars.ceilFloorColorSel := 232;
  GDVars.wallColorSel := 219;
  GDVars.inEncMenu := 0;
  Stats.ResetGame;
end;

procedure GameInit2;
var
  i: Byte;
begin
  GetMem(GDVars.zone0, SizeOf(GDVars.zone0^));
  GetMem(GDVars.zone1, SizeOf(GDVars.zone1^));
  GetMem(GDVars.zone2, SizeOf(GDVars.zone2^));
  GetMem(GDVars.zone3, SizeOf(GDVars.zone3^));
  GetMem(GDVars.gbStrings, SizeOf(GDVars.gbStrings^));
  FillChar(GDVars.gbStrings^, SizeOf(GDVars.gbStrings^), 0);
  GetMem(GDVars.baseItems, SizeOf(GDVars.baseItems^));
  FillChar(GDVars.baseItems^, SizeOf(GDVars.baseItems^), 0);
  { the heap the out-of-memory save needs }
  HeapErr.KeepReserve;
  GetMem(GDVars.gameFont, SizeOf(Types.TFontArr));
  GetMem(GDVars.wallGfx, SizeOf(GDVars.wallGfx^));
  GetMem(GDVars.map3d, SizeOf(Types.TGeoMap));
  Blit.AllocPic(8, 1, 1, 0, GDVars.dsCurrent8x8SymbolPtr2);
  { the 168x168 view area }
  Blit.AllocPic(168, 21, 1, 0, GDVars.dsViewImageBufferPtr);
  { 24x24 save-under block }
  Blit.AllocPic(24, 3, 1, 0, GDVars.dsIconImageBufferPtr);
  FillChar(GDVars.spanActive, SizeOf(GDVars.spanActive), 0);
  FillChar(GDVars.spanScreenOfs, SizeOf(GDVars.spanScreenOfs), 0);
  FillChar(GDVars.spanFirstOfs, SizeOf(GDVars.spanFirstOfs), $FF);
  FillChar(GDVars.spanLastOfs, SizeOf(GDVars.spanLastOfs), 0);
  VidOps.InitRowTables;
  FillChar(GDVars.dsSymbolSetPtrs, SizeOf(GDVars.dsSymbolSetPtrs), 0);
  FillChar(GDVars.ds2dMapTilePtr, SizeOf(GDVars.ds2dMapTilePtr) + SizeOf(GDVars.ds2dMapTilePtr2), 0);
  FillChar(GDVars.dsIconAnimation, SizeOf(GDVars.dsIconAnimation), 0);
  for i := 1 to 2 do begin
    GDVars.dsPortraitCache[i].pictureId := 255;
    GDVars.dsPortraitCache[i].pic := nil;
  end;
  FillChar(GDVars.animData, SizeOf(GDVars.animData), 0);
  GDVars.treasureItems := nil;
  { WALLDEF reload ID 0, symbol slot 1 }
  GDVars.dsWallSetCache[1].wallDefId := 0;
  GDVars.dsWallSetCache[1].symbolSlot := 1;
  for i := 2 to 3 do begin
    { slots 2-3 = empty }
    GDVars.dsWallSetCache[i].wallDefId := -1;
    GDVars.dsWallSetCache[i].symbolSlot := -1;
  end;
  GDVars.portraitsOn := 1;
  GDVars.monsterPics := 1;
  GDVars.musicOn := 1;
  GDVars.soundOn := 1;
  GDVars.quickEnds := 1;
  GDVars.quickMagicOn := 0;
  GDVars.companionOn := 0;
  GDVars.stingHpFlag := 0;
  GDVars.msgDelayFlag := 1;
  GDVars.gameDelay := 1;
  GameInit.ResetGameState;
  GDVars.soundAutoStop := 0;
  SoundDrv.SoundSetAutoStop(100);
  savedDir := GDVars.gameDir;
  GDVars.gameDir[0] := #0;
  TextRend.LoadGameFont;
  TextRend.ClearBottomLine;
  TextRend.DisplayString(0, 24, LightGreen, 'Loading...Please Wait');
  Sym8x8.Load8x8Set(202, 4);
  Sym8x8.Load8x8Set(203, 0);
  Blit.LoadPic('sqrpaci', 1, False, 0, GDVars.ds2dMapTilePtr);
  { the second tile set loads when the wilderness or the ending first needs it (MapTiles.SecondSheet) }
  for i := 0 to 11 do
    MapTiles.LoadIconAnim('COMSPR', i, i + 13);
  MapTiles.LoadIconAnim('COMSPR', 25, 25);
  itemsRead := 0;
  if DaxIo.OpenWithRetry('ITEMS', DaxIo.DataDiskMsg, False, True, itemsFile) then begin
    Seek(itemsFile, 2);
    { This asks for every entry, the overflow entry too; the file must hold the BASE_ITEM_LAST + 1 item types. }
    BlockRead(itemsFile, GDVars.baseItems^, SizeOf(GDVars.baseItems^), itemsRead);
    Close(itemsFile);
  end;
  if (IOResult <> 0) or (itemsRead < (Types.BASE_ITEM_LAST + 1) * SizeOf(Types.TBaseItemRec)) then
    GameIo.FatalError('Unable to read ITEMS.');
  CharHlp.FixWeaponClasses(GDVars.baseItems);
  CharHlp.FixAmmoBits(GDVars.baseItems);
  GDVars.gameDir := savedDir;
  TextRend.ClearBottomLine;
  { the settings, over the defaults above, before the title music }
  Options.LoadOptions;
  { Started with NORAND as the second argument, for testing, the game seeds the random numbers with 1, so two runs given
    the same keys roll the same dice. }
  if ParamStr(2) = 'NORAND' then
    RandSeed := 1
  else
    Randomize;
  { Install spell function pointers. }
  GameInit.InitSpellFns;
  { Install effect function pointers. }
  GameInit.InitEffectHandlers;
  CbtMap.boltTracer := Magic.TraceLightningBolt;
  GameIo.showMemory := MemShow.ShowMemory;
  CharHlp.faultHook := CharDisp.ShowFault;
  EclVars.diskHook := DaxIo.PushState;
  EclVars.wallSetHook := View3D.LoadWallSet;
end;

end.

{ Initialize game state, allocate graphics buffers, load shared resources and install spell and effect handlers. }
{$O+,F+,I-}
{$I COMPILER.INC}
unit GameInit;

interface

{ Allocate the GBVM zones and graphics buffers, build the per-row video address tables and reset the game state to its
  defaults, then load the font, symbol sets, tile sets, combat icons and item table, read the settings from POOLOPT.CFG
  (Options.LoadOptions) and the Bestiary from BESTIARY.DAT (BeastFil.Load), seed the random numbers (with 1 when NORAND
  is the second argument) and install the spell and effect handlers. }
procedure GameInit2;

{ Puts the game in a new game's state, as at startup: the GBVM banks cleared, the party at (15, 1) facing west in the 3D
  map with no members, the script at its start and the game's statistics cleared. The settings, the loaded pictures and
  wall sets, and their caches, are left alone. GameInit2 calls it; so does the main program after a party is destroyed,
  having freed the party (SaveLoad.FreeParty), before the main menu. }
procedure ResetGameState;

implementation

uses Types, Crt, C_AREA, GameDefs, GameVars, Sym8x8, MapTiles, Magic, EffHndlr, C_DIR, Options, Blit, DaxIo, GameIo,
  MenuCore, SoundDrv, TextRend, C_GBVM, CbtActs, C_EFFECT, CbtMap, MemShow, CharHlp, CharDisp, EclVars, View3D,
  HeapErr, VidOps, Stats, CfgFile, Explored, MapNotes, Explore, GameTime, Combat, MapView, EclVm,
  Portrait, BeastFil{$IFDEF FPC}, TpRand{$ENDIF};

{ Install every spell handler in GameVars.spellFns and the noncombat cast-target menu; clear effectLock,
  GameVars.usingItem and GameVars.castTarget, and set redrawInventoryMenuFlag. }
procedure InitSpellFns;
begin
  GameVars.castTargetMenu := Magic.NoncombatCastTargetMenu;
  GameVars.effectLock := 0;
  GameVars.usingItem := False;
  GameVars.castTarget := nil;
  GameVars.redrawInventoryMenuFlag := 1;
  GameVars.spellFns[1] := Magic.BlessHandler;
  GameVars.spellFns[2] := Magic.CurseHandler;
  GameVars.spellFns[3] := Magic.CureLightWoundsHandler;
  GameVars.spellFns[4] := Magic.CauseLightWoundsHandler;
  GameVars.spellFns[5] := Magic.DetectionHandler;
  GameVars.spellFns[6] := Magic.ProtectionHandler;
  GameVars.spellFns[7] := Magic.ProtectionHandler;
  GameVars.spellFns[8] := Magic.ResistColdHandler;
  GameVars.spellFns[9] := Magic.BurningHandsHandler;
  GameVars.spellFns[10] := Magic.CharmPersonHandler;
  GameVars.spellFns[11] := Magic.DetectionHandler;
  GameVars.spellFns[12] := Magic.EnlargeHandler;
  GameVars.spellFns[13] := Magic.ReduceHandler;
  GameVars.spellFns[14] := Magic.FriendsHandler;
  GameVars.spellFns[15] := Magic.MagicMissileHandler;
  GameVars.spellFns[16] := Magic.ProtectionHandler;
  GameVars.spellFns[17] := Magic.ProtectionHandler;
  GameVars.spellFns[18] := Magic.DetectionHandler;
  GameVars.spellFns[19] := Magic.ShieldHandler;
  GameVars.spellFns[20] := Magic.ShockingGraspHandler;
  GameVars.spellFns[21] := Magic.SleepHandler;
  GameVars.spellFns[22] := Magic.DetectionHandler;
  GameVars.spellFns[23] := Magic.HoldPersonHandler;
  GameVars.spellFns[24] := Magic.ResistFireHandler;
  GameVars.spellFns[25] := Magic.SilenceHandler;
  GameVars.spellFns[26] := Magic.SlowPoisonHandler;
  GameVars.spellFns[27] := Magic.SnakeCharmHandler;
  GameVars.spellFns[28] := Magic.SpiritualHammerHandler;
  GameVars.spellFns[29] := Magic.DetectionHandler;
  GameVars.spellFns[30] := Magic.InvisibilityHandler;
  GameVars.spellFns[31] := Magic.KnockHandler;
  GameVars.spellFns[32] := Magic.MirrorImageHandler;
  GameVars.spellFns[33] := Magic.RayOfEnfeeblementHandler;
  GameVars.spellFns[34] := Magic.StinkingCloudHandler;
  GameVars.spellFns[35] := Magic.StrengthHandler;
  GameVars.spellFns[36] := Magic.AnimateDeadHandler;
  GameVars.spellFns[37] := Magic.CureBlindnessHandler;
  GameVars.spellFns[38] := Magic.CauseBlindnessHandler;
  GameVars.spellFns[39] := Magic.CureDiseaseHandler;
  GameVars.spellFns[40] := Magic.CauseDiseaseHandler;
  GameVars.spellFns[41] := Magic.DispelMagicHandler;
  GameVars.spellFns[42] := Magic.PrayerHandler;
  GameVars.spellFns[43] := Magic.RemoveCurseSpell;
  GameVars.spellFns[44] := Magic.BestowCurseHandler;
  GameVars.spellFns[45] := Magic.BlinkHandler;
  GameVars.spellFns[46] := Magic.DispelMagicHandler;
  GameVars.spellFns[47] := Magic.FireballHandler;
  GameVars.spellFns[48] := Magic.HasteHandler;
  GameVars.spellFns[49] := Magic.HoldPersonHandler;
  GameVars.spellFns[50] := Magic.InvisibilityHandler;
  GameVars.spellFns[51] := Magic.LightningBoltHandler;
  GameVars.spellFns[52] := Magic.ProtectionHandler;
  GameVars.spellFns[53] := Magic.ProtectionHandler;
  GameVars.spellFns[54] := Magic.ProtectionHandler;
  GameVars.spellFns[55] := Magic.SlowHandler;
  GameVars.spellFns[56] := Magic.RestorationHandler;
  GameVars.spellFns[57] := Magic.PotionOfSpeedHandler;
  GameVars.spellFns[58] := Magic.KeoghtomsOintmentHandler;
  GameVars.spellFns[59] := Magic.GiantStrengthHandler;
  GameVars.spellFns[60] := Magic.JavelinOfLightningHandler;
  GameVars.spellFns[61] := Magic.WandParalyzationHandler;
  GameVars.spellFns[62] := Magic.PotionOfHealingHandler;
  GameVars.spellFns[63] := Magic.DustDisappearanceHandler;
  GameVars.spellFns[64] := Magic.FireballHandler;
  GameVars.spellFns[65] := Magic.WandMagicMissilesHandler;
  GameVars.spellFns[66] := Magic.UnusedSpellHandler;
  GameVars.spellFns[67] := Magic.ManualBodilyHealthHandler;
end;

{ Install the effect handlers: REAR_CLAW_RAKE and BITE_HOLD are CbtActs' combat actions, and DRAGON_BREATH is Magic's. }
procedure InitEffectHandlers;
begin
  GameVars.effectFns[C_EFFECT.BLESS] := EffHndlr.EffBless;
  GameVars.effectFns[C_EFFECT.CURSE] := EffHndlr.EffCurse;
  GameVars.effectFns[C_EFFECT.UNDEAD_SLAYER] := EffHndlr.EffUndeadSlayer;
  GameVars.effectFns[C_EFFECT.TRAIN_START] := EffHndlr.EffTrainStart;
  GameVars.effectFns[C_EFFECT.DETECT_MAGIC] := EffHndlr.EffNull;
  GameVars.effectFns[C_EFFECT.FLAME_TONGUE] := EffHndlr.EffFlameTongue;
  GameVars.effectFns[C_EFFECT.TRAIN_MANUAL] := EffHndlr.EffTrainManual;
  GameVars.effectFns[C_EFFECT.PROT_EVIL] := EffHndlr.EffProtEvil;
  GameVars.effectFns[C_EFFECT.PROT_GOOD] := EffHndlr.EffProtGood;
  GameVars.effectFns[C_EFFECT.RESIST_COLD] := EffHndlr.EffResistCold;
  GameVars.effectFns[C_EFFECT.CHARM] := EffHndlr.EffCharm;
  GameVars.effectFns[C_EFFECT.ENLARGE] := EffHndlr.EffExtraStr;
  GameVars.effectFns[C_EFFECT.REDUCE] := EffHndlr.EffNull;
  GameVars.effectFns[C_EFFECT.FRIENDS] := EffHndlr.EffFriends;
  GameVars.effectFns[C_EFFECT.SLOW_POISON_HIT] := EffHndlr.EffSlowPoisonHit;
  GameVars.effectFns[C_EFFECT.READ_MAGIC] := EffHndlr.EffNull;
  GameVars.effectFns[C_EFFECT.SHIELD] := EffHndlr.EffShield;
  GameVars.effectFns[C_EFFECT.GNOME_THAC0] := EffHndlr.EffGnomeThac0;
  GameVars.effectFns[C_EFFECT.FIND_TRAPS] := EffHndlr.EffNull;
  GameVars.effectFns[C_EFFECT.RESIST_FIRE] := EffHndlr.EffResistFire;
  GameVars.effectFns[C_EFFECT.SILENCE] := EffHndlr.EffSilence;
  GameVars.effectFns[C_EFFECT.SLOW_POISON_END] := EffHndlr.EffSlowPoisonEnd;
  GameVars.effectFns[C_EFFECT.SPIRIT_HAMMER] := EffHndlr.EffSpiritHammer;
  GameVars.effectFns[C_EFFECT.SEE_INVISIBLE] := EffHndlr.EffNull;
  GameVars.effectFns[C_EFFECT.INVISIBLE] := EffHndlr.EffInvisible;
  GameVars.effectFns[C_EFFECT.DWARF_THAC0] := EffHndlr.EffDwarfThac0;
  GameVars.effectFns[C_EFFECT.FEATHER_FALL] := EffHndlr.EffNull;
  GameVars.effectFns[C_EFFECT.MIRROR_IMAGE] := EffHndlr.EffMirrorImage;
  GameVars.effectFns[C_EFFECT.ENFEEBLE] := EffHndlr.EffEnfeeble;
  GameVars.effectFns[C_EFFECT.STINK_COUGH] := EffHndlr.EffStinkCough;
  GameVars.effectFns[C_EFFECT.HELPLESS] := EffHndlr.EffHelpless;
  GameVars.effectFns[C_EFFECT.ANIMATE_DEAD] := EffHndlr.EffAnimateDead;
  GameVars.effectFns[C_EFFECT.BLIND] := EffHndlr.EffBlind;
  GameVars.effectFns[C_EFFECT.DISEASED] := EffHndlr.EffDiseased;
  GameVars.effectFns[C_EFFECT.ALLIED_PRAYER] := EffHndlr.EffAlliedPrayer;
  GameVars.effectFns[C_EFFECT.BESTOW_CURSE] := EffHndlr.EffBestowCurse;
  GameVars.effectFns[C_EFFECT.BLINKING] := EffHndlr.EffBlinking;
  GameVars.effectFns[C_EFFECT.STRENGTH] := EffHndlr.EffExtraStr;
  GameVars.effectFns[C_EFFECT.HASTED] := EffHndlr.EffHasted;
  GameVars.effectFns[C_EFFECT.CAST_STINK] := EffHndlr.EffCastStink;
  GameVars.effectFns[C_EFFECT.PROT_MISSILES] := EffHndlr.EffProtMissiles;
  GameVars.effectFns[C_EFFECT.SLOWED] := EffHndlr.EffSlowed;
  GameVars.effectFns[C_EFFECT.DISEASE_STR] := EffHndlr.EffDiseaseStr;
  GameVars.effectFns[C_EFFECT.DISEASE_HP] := EffHndlr.EffDiseaseHp;
  GameVars.effectFns[C_EFFECT.PROT_EVIL_10FT] := EffHndlr.EffProtEvil;
  GameVars.effectFns[C_EFFECT.PROT_GOOD_10FT] := EffHndlr.EffProtGood;
  GameVars.effectFns[C_EFFECT.DWARF_AC_GIANT] := EffHndlr.EffDwarfAcGiant;
  GameVars.effectFns[C_EFFECT.GNOME_AC_BUG] := EffHndlr.EffGnomeAcBug;
  GameVars.effectFns[C_EFFECT.PRAYER] := EffHndlr.EffPrayer;
  GameVars.effectFns[C_EFFECT.ROT_NO_HEAL] := EffHndlr.EffRotNoHeal;
  GameVars.effectFns[C_EFFECT.SNAKE_CHARM] := EffHndlr.EffHelpless;
  GameVars.effectFns[C_EFFECT.PARALYSIS] := EffHndlr.EffHelpless;
  GameVars.effectFns[C_EFFECT.SLEEP] := EffHndlr.EffHelpless;
  { A milder dragon fear that only marks the creature (camp lists it as Repulsed); the full fear is DRAGON_FEAR. }
  GameVars.effectFns[C_EFFECT.DRAGON_AURA] := EffHndlr.EffNull;
  GameVars.effectFns[C_EFFECT.POISONED] := EffHndlr.EffNull;
  GameVars.effectFns[C_EFFECT.RING_INVIS] := EffHndlr.EffRingInvis;
  GameVars.effectFns[C_EFFECT.MUMMY_ROT] := EffHndlr.EffMummyRot;
  GameVars.effectFns[C_EFFECT.IMMOBILE] := EffHndlr.EffImmobile;
  GameVars.effectFns[C_EFFECT.TROLL_REGEN] := EffHndlr.EffTrollRegen;
  GameVars.effectFns[C_EFFECT.NULL_DAMAGE] := EffHndlr.EffNull;
  GameVars.effectFns[C_EFFECT.RING_FIRE_RES] := EffHndlr.EffRingFireRes;
  GameVars.effectFns[C_EFFECT.CON_REGEN] := EffHndlr.EffConRegen;
  GameVars.effectFns[C_EFFECT.NULL_TARGET_VETO] := EffHndlr.EffNull;
  GameVars.effectFns[C_EFFECT.POISON_HIT0] := EffHndlr.EffPoisonHit0;
  GameVars.effectFns[C_EFFECT.POISON_HIT4] := EffHndlr.EffPoisonHit4;
  GameVars.effectFns[C_EFFECT.POISON_HIT2] := EffHndlr.EffPoisonHit2;
  GameVars.effectFns[C_EFFECT.KREEN_PARA] := EffHndlr.EffKreenPara;
  GameVars.effectFns[C_EFFECT.GHOUL_PARA] := EffHndlr.EffGhoulPara;
  GameVars.effectFns[C_EFFECT.DRIDER_PARA] := EffHndlr.EffDriderPara;
  GameVars.effectFns[C_EFFECT.POISON_HIT_M2] := EffHndlr.EffPoisonHitM2;
  GameVars.effectFns[C_EFFECT.DUST_DISAPPEAR] := EffHndlr.EffDustDisappear;
  GameVars.effectFns[C_EFFECT.CAMOUFLAGE] := EffHndlr.EffCamouflage;
  GameVars.effectFns[C_EFFECT.REAR_CLAW_RAKE] := CbtActs.RearClawRake;
  GameVars.effectFns[C_EFFECT.BITE_HOLD] := CbtActs.BiteAndHold;
  GameVars.effectFns[C_EFFECT.BLOOD_DRAIN] := EffHndlr.EffBloodDrain;
  GameVars.effectFns[C_EFFECT.BLOOD_ATTACH] := EffHndlr.EffBloodAttach;
  GameVars.effectFns[C_EFFECT.BITE_ATTACH] := EffHndlr.EffBiteHold;
  GameVars.effectFns[C_EFFECT.HEAL_WAKE] := EffHndlr.EffHealWake;
  GameVars.effectFns[C_EFFECT.FIRE_TOUCH] := EffHndlr.EffFireTouch;
  GameVars.effectFns[C_EFFECT.ACID_SQUIRT] := EffHndlr.EffAcidSquirt;
  GameVars.effectFns[C_EFFECT.DRAGON_FEAR] := EffHndlr.EffDragonFear;
  GameVars.effectFns[C_EFFECT.MUMMY_FEAR] := EffHndlr.EffMummyFear;
  GameVars.effectFns[C_EFFECT.PETRIFY_GAZE] := EffHndlr.EffPetrifyGaze;
  GameVars.effectFns[C_EFFECT.CHARM_GAZE] := EffHndlr.EffCharmGaze;
  GameVars.effectFns[C_EFFECT.DRAIN_ONE] := EffHndlr.EffDrainOne;
  GameVars.effectFns[C_EFFECT.DRAIN_TWO] := EffHndlr.EffDrainTwo;
  GameVars.effectFns[C_EFFECT.ROT_TOUCH] := EffHndlr.EffRotTouch;
  GameVars.effectFns[C_EFFECT.DRAGON_BREATH] := Magic.DragonBreathHandler;
  GameVars.effectFns[C_EFFECT.DISPLACED] := EffHndlr.EffDisplaced;
  GameVars.effectFns[C_EFFECT.CON_PSN_SAVE] := EffHndlr.EffConPsnSave;
  GameVars.effectFns[C_EFFECT.IMMUNE_MM] := EffHndlr.EffImmuneMM;
  GameVars.effectFns[92] := EffHndlr.EffNull;
  GameVars.effectFns[C_EFFECT.HALF_FIRE] := EffHndlr.EffHalfFire;
  GameVars.effectFns[C_EFFECT.HALF_BASH] := EffHndlr.EffHalfBash;
  GameVars.effectFns[C_EFFECT.FIGHT_ON] := EffHndlr.EffFightOn;
  GameVars.effectFns[C_EFFECT.NEED_SILVER] := EffHndlr.EffNeedSilver;
  GameVars.effectFns[C_EFFECT.CON_SPELL_SAVE] := EffHndlr.EffConSpellSave;
  GameVars.effectFns[C_EFFECT.REGEN3] := EffHndlr.EffRegen3;
  GameVars.effectFns[C_EFFECT.CAN_FIGHT_ON] := EffHndlr.EffCanFightOn;
  GameVars.effectFns[C_EFFECT.TROLL_BURN] := EffHndlr.EffTrollBurn;
  GameVars.effectFns[C_EFFECT.TROLL_HEAL] := EffHndlr.EffTrollHeal;
  GameVars.effectFns[C_EFFECT.TROLL_RETURN] := EffHndlr.EffTrollReturn;
  GameVars.effectFns[C_EFFECT.GASEOUS] := EffHndlr.EffGaseous;
  GameVars.effectFns[C_EFFECT.KREEN_DODGE] := EffHndlr.EffKreenDodge;
  GameVars.effectFns[C_EFFECT.MAGIC_RES50] := EffHndlr.EffMagicRes50;
  GameVars.effectFns[C_EFFECT.MAGIC_RES85] := EffHndlr.EffMagicRes85;
  GameVars.effectFns[C_EFFECT.ELF_RESIST] := EffHndlr.EffElfResist;
  GameVars.effectFns[C_EFFECT.NO_SLEEP_CHARM] := EffHndlr.EffNoSleepCharm;
  GameVars.effectFns[C_EFFECT.NO_PARALYSIS] := EffHndlr.EffNoParalysis;
  GameVars.effectFns[C_EFFECT.NO_COLD] := EffHndlr.EffNoCold;
  GameVars.effectFns[C_EFFECT.NO_PARA_POISON] := EffHndlr.EffNoParaPoison;
  GameVars.effectFns[C_EFFECT.NO_FIRE] := EffHndlr.EffNoFire;
  GameVars.effectFns[C_EFFECT.EFREETI_FIRE] := EffHndlr.EffEfreetiFire;
  GameVars.effectFns[C_EFFECT.HALF_ELEC] := EffHndlr.EffHalfElec;
  GameVars.effectFns[C_EFFECT.HALF_PIERCE] := EffHndlr.EffHalfPierce;
  GameVars.effectFns[C_EFFECT.HALF_MAGICAL] := EffHndlr.EffHalfMagical;
  GameVars.effectFns[C_EFFECT.HOLY_WATER] := EffHndlr.EffHolyWater;
  GameVars.effectFns[C_EFFECT.HALF_COLD] := EffHndlr.EffHalfCold;
  GameVars.effectFns[C_EFFECT.NEED_MAGIC] := EffHndlr.EffNeedMagic;
  GameVars.effectFns[C_EFFECT.BOULDER_DODGE] := EffHndlr.EffBoulderDodge;
  GameVars.effectFns[C_EFFECT.ANHKHEG_ACID] := EffHndlr.EffAnhkhegAcid;
  GameVars.effectFns[C_EFFECT.MUMMY_FIRE] := EffHndlr.EffMummyFire;
  GameVars.effectFns[C_EFFECT.SILVER_MAGIC] := EffHndlr.EffSilverMagic;
  GameVars.effectFns[C_EFFECT.HALF_ELF_RESIST] := EffHndlr.EffHalfElfResist;
  GameVars.effectFns[C_EFFECT.NO_CHARM_POISON] := EffHndlr.EffNoCharmPoison;
  GameVars.effectFns[C_EFFECT.GAZE_BLOCK] := EffHndlr.EffGazeBlock;
  GameVars.effectFns[C_EFFECT.GAZE_REFLECTABLE] := EffHndlr.EffNull;
  GameVars.effectFns[C_EFFECT.READY_FEATHER_FALL] := EffHndlr.EffReadyItem;
  GameVars.effectFns[C_EFFECT.READY_FIRE_RES] := EffHndlr.EffReadyItem;
  GameVars.effectFns[130] := EffHndlr.EffReadyItem;
  GameVars.effectFns[C_EFFECT.GAUNTLETS] := EffHndlr.EffGauntlets;
  GameVars.effectFns[C_EFFECT.ALIGNED_WEAPON] := EffHndlr.EffAlignedWeapon;
  GameVars.effectFns[C_EFFECT.READY_DISPLACEMENT] := EffHndlr.EffReadyItem;
  GameVars.effectFns[C_EFFECT.READY_ELVENKIND] := EffHndlr.EffReadyItem;
  GameVars.effectFns[C_EFFECT.BOULDER] := EffHndlr.EffBoulder;
  GameVars.effectFns[136] := EffHndlr.EffReadyItem;
  GameVars.effectFns[C_EFFECT.SPIRIT_HAMMER_GONE] := EffHndlr.EffHammerGone;
  GameVars.effectFns[138] := EffHndlr.EffReadyItem;
  GameVars.effectFns[C_EFFECT.READY_RING_INVIS] := EffHndlr.EffReadyItem;
  GameVars.effectFns[C_EFFECT.RECENT_HEAL] := EffHndlr.EffNull;
  GameVars.effectFns[C_EFFECT.RECENT_CURE] := EffHndlr.EffNull;
end;

procedure ResetGameState;
begin
  Explored.Clear;
  MapNotes.Clear;
  FillChar(GameVars.zone0^, SizeOf(GameVars.zone0^), 0);
  FillChar(GameVars.zone1^, SizeOf(GameVars.zone1^), 0);
  FillChar(GameVars.zone2^, SizeOf(GameVars.zone2^), 0);
  FillChar(GameVars.zone3^, SizeOf(GameVars.zone3^), 0);
  GameVars.wallAhead := 0;
  GameVars.eventAtCell := 0;
  GameVars.gMapX := 15;
  GameVars.gMapY := 1;
  GameVars.gFacing := C_DIR.WEST;
  GameVars.debugTraceEnabled := False;
  GameVars.bottomLineTaken := False;
  GameVars.loadedSave := 0;
  GameVars.creatureList := nil;
  GameVars.curChar := nil;
  GameVars.eclIp := C_GBVM.SCRIPT_FIRST;
  GameVars.virtualDisk := 1;
  DaxIo.prevVirtualDisk := 1;
  GameVars.automapOn := False;
  GameVars.locTypePrev := C_AREA.LOC_3D_MAP;
  GameVars.gLocType := C_AREA.LOC_3D_MAP;
  GameVars.vertTop := 1;
  GameVars.duelFlag := False;
  GameVars.suppressDrawingBorderFlag := 0;
  GameVars.eclGraphics := False;
  GameVars.partyDefeated := False;
  GameVars.sprShown := False;
  GameVars.suppressingInsertDiskFlag := False;
  GameVars.recentSaved := 0;
  GameVars.ceilFloorColorSel := 232;
  GameVars.wallColorSel := 219;
  GameVars.inEncMenu := 0;
  Explore.ResetGame;
  GameTime.ResetGame;
  Combat.ResetGame;
  MapView.ResetGame;
  EclVm.ResetGame;
  Portrait.ResetGame;
  Stats.ResetGame;
end;

procedure GameInit2;
var
  i: Byte;
  settings: CfgFile.TSettings;
  { the game folder, set aside while the resources load from the current one }
  savedDir: Types.TPathStr;
  itemsFile: file;
  itemsRead: Word;
begin
  GetMem(GameVars.zone0, SizeOf(GameVars.zone0^));
  GetMem(GameVars.zone1, SizeOf(GameVars.zone1^));
  GetMem(GameVars.zone2, SizeOf(GameVars.zone2^));
  GetMem(GameVars.zone3, SizeOf(GameVars.zone3^));
  GetMem(GameVars.gbStrings, SizeOf(GameVars.gbStrings^));
  FillChar(GameVars.gbStrings^, SizeOf(GameVars.gbStrings^), 0);
  GetMem(CharHlp.baseItems, SizeOf(CharHlp.baseItems^));
  FillChar(CharHlp.baseItems^, SizeOf(CharHlp.baseItems^), 0);
  { the heap the out-of-memory save needs }
  HeapErr.KeepReserve;
  GetMem(GameVars.gameFont, SizeOf(Types.TFontArr));
  GetMem(View3D.wallGfx, SizeOf(View3D.wallGfx^));
  GetMem(GameVars.map3d, SizeOf(Types.TGeoMap));
  Blit.AllocPic(8, 1, 1, 0, GameVars.current8x8SymbolPtr2);
  { the 168x168 view area }
  Blit.AllocPic(168, 21, 1, 0, GameVars.viewImageBufferPtr);
  { 24x24 save-under block }
  Blit.AllocPic(24, 3, 1, 0, GameVars.iconImageBufferPtr);
  FillChar(GameVars.spanActive, SizeOf(GameVars.spanActive), 0);
  FillChar(GameVars.spanScreenOfs, SizeOf(GameVars.spanScreenOfs), 0);
  FillChar(GameVars.spanFirstOfs, SizeOf(GameVars.spanFirstOfs), $FF);
  FillChar(GameVars.spanLastOfs, SizeOf(GameVars.spanLastOfs), 0);
  VidOps.InitRowTables;
  FillChar(GameVars.symbolSetPtrs, SizeOf(GameVars.symbolSetPtrs), 0);
  { the second tile set's pointer, MapTiles.mapTilePtr2, starts nil in MapTiles }
  GameVars.mapTilePtr := nil;
  FillChar(GameVars.iconAnimation, SizeOf(GameVars.iconAnimation), 0);
  for i := 1 to 2 do begin
    GameVars.portraitCache[i].pictureId := 255;
    GameVars.portraitCache[i].pic := nil;
  end;
  FillChar(GameVars.animData, SizeOf(GameVars.animData), 0);
  GameVars.treasureItems := nil;
  { WALLDEF reload ID 0, symbol slot 1 }
  GameVars.wallSetCache[1].wallDefId := 0;
  GameVars.wallSetCache[1].symbolSlot := 1;
  for i := 2 to 3 do begin
    { slots 2-3 = empty }
    GameVars.wallSetCache[i].wallDefId := -1;
    GameVars.wallSetCache[i].symbolSlot := -1;
  end;
  { the settings' defaults, which POOLOPT.CFG is read over below }
  CfgFile.Defaults(settings);
  Options.Apply(settings);
  GameVars.stingHpFlag := 0;
  GameVars.msgDelayFlag := 1;
  GameInit.ResetGameState;
  SoundDrv.soundAutoStop := 0;
  SoundDrv.SoundSetAutoStop(100);
  savedDir := GameVars.gameDir;
  GameVars.gameDir[0] := #0;
  TextRend.LoadGameFont;
  TextRend.ClearBottomLine;
  TextRend.DisplayString(0, 24, LightGreen, 'Loading...Please Wait');
  Sym8x8.Load8x8Set(202, 4);
  Sym8x8.Load8x8Set(203, 0);
  Blit.LoadPic('sqrpaci', 1, False, 0, GameVars.mapTilePtr);
  { the second tile set loads when the wilderness or the ending first needs it (MapTiles.SecondSheet) }
  for i := 0 to 11 do
    MapTiles.LoadIconAnim('COMSPR', i, i + 13);
  MapTiles.LoadIconAnim('COMSPR', 25, 25);
  itemsRead := 0;
  if DaxIo.OpenWithRetry('ITEMS', DaxIo.DataDiskMsg, False, True, itemsFile) then begin
    Seek(itemsFile, 2);
    { This asks for every entry, the overflow entry too; the file must hold the BASE_ITEM_LAST + 1 item types. }
    BlockRead(itemsFile, CharHlp.baseItems^, SizeOf(CharHlp.baseItems^), itemsRead);
    Close(itemsFile);
  end;
  if (IOResult <> 0) or (itemsRead < (Types.BASE_ITEM_LAST + 1) * SizeOf(Types.TBaseItemRec)) then
    GameIo.FatalError('Unable to read ITEMS.');
  CharHlp.FixWeaponClasses(CharHlp.baseItems);
  CharHlp.FixAmmoBits(CharHlp.baseItems);
  GameVars.gameDir := savedDir;
  TextRend.ClearBottomLine;
  { the settings, over the defaults above, before the title music }
  Options.LoadOptions;
  { what the player has learned of the creatures, from every game played (#842), written again on the way out }
  BeastFil.Load;
  GameIo.beforeExit := BeastFil.Flush;
  { Started with NORAND as the second argument, for testing, the game seeds the random numbers with 1, so two runs given
    the same keys roll the same dice. }
  if GameVars.norandArg then
    RandSeed := 1
  else
    Randomize;
  { Install spell function pointers. }
  GameInit.InitSpellFns;
  { Install effect function pointers. }
  GameInit.InitEffectHandlers;
  CbtMap.boltTracer := Magic.TraceBolt;
  CbtMap.aimReport := CbtActs.ReportAreaCatch;
  GameIo.showMemory := MemShow.ShowMemory;
  CharHlp.faultHook := CharDisp.ShowFault;
  EclVars.diskHook := DaxIo.PushState;
  EclVars.wallSetHook := View3D.LoadWallSet;
end;

end.

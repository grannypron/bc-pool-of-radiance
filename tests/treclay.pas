{ Tests the layout of the records saved in character and game files: TCharRecord (NAME.CHA and CHRDATxN.SAV, 285 bytes),
  TItemRec (.ITM, 63 bytes each) and TEffectRec (.SPC, 9 bytes each). Every field's offset is SSI's: the numbers were
  read from this program compiled against SSI's v1.3 source (por-disassembly v13/src, whose field names are the same),
  and a change that moves a field breaks the files SSI's game and earlier saves wrote. The offsets are the disk form's
  (DiskRec): a 64-bit build's 8-byte pointers move the fields in memory, and DiskRec moves them back. }
{$I COMPILER.INC}
program TRecLay;

uses Types, DiskRec, TestKit;

var
  ch: Types.TCharRecord;
  it: Types.TItemRec;
  ef: Types.TEffectRec;

procedure At(expected: LongInt; actual: Word; what: String);
begin
  TestKit.CheckEqualsL(expected, actual, what + ' is at its saved offset');
end;

begin
  TestKit.Start('TRECLAY');
  TestKit.CheckEqualsL(285, DiskRec.CharDiskSize, 'TCharRecord on disk');
  At(0, DiskRec.CharDiskOfs(Ofs(ch.name) - Ofs(ch)), 'TCharRecord.name');
  At(16, DiskRec.CharDiskOfs(Ofs(ch.strCur) - Ofs(ch)), 'TCharRecord.strCur');
  At(17, DiskRec.CharDiskOfs(Ofs(ch.intCur) - Ofs(ch)), 'TCharRecord.intCur');
  At(18, DiskRec.CharDiskOfs(Ofs(ch.wisCur) - Ofs(ch)), 'TCharRecord.wisCur');
  At(19, DiskRec.CharDiskOfs(Ofs(ch.dexCur) - Ofs(ch)), 'TCharRecord.dexCur');
  At(20, DiskRec.CharDiskOfs(Ofs(ch.conCur) - Ofs(ch)), 'TCharRecord.conCur');
  At(21, DiskRec.CharDiskOfs(Ofs(ch.chaCur) - Ofs(ch)), 'TCharRecord.chaCur');
  At(22, DiskRec.CharDiskOfs(Ofs(ch.strExc) - Ofs(ch)), 'TCharRecord.strExc');
  At(23, DiskRec.CharDiskOfs(Ofs(ch.memorizedSpells) - Ofs(ch)), 'TCharRecord.memorizedSpells');
  At(44, DiskRec.CharDiskOfs(Ofs(ch.spellPrepTime) - Ofs(ch)), 'TCharRecord.spellPrepTime');
  At(45, DiskRec.CharDiskOfs(Ofs(ch.thac0Base) - Ofs(ch)), 'TCharRecord.thac0Base');
  At(46, DiskRec.CharDiskOfs(Ofs(ch.race) - Ofs(ch)), 'TCharRecord.race');
  At(47, DiskRec.CharDiskOfs(Ofs(ch.charClass) - Ofs(ch)), 'TCharRecord.charClass');
  At(48, DiskRec.CharDiskOfs(Ofs(ch.age) - Ofs(ch)), 'TCharRecord.age');
  At(50, DiskRec.CharDiskOfs(Ofs(ch.hpMax) - Ofs(ch)), 'TCharRecord.hpMax');
  At(51, DiskRec.CharDiskOfs(Ofs(ch.spellsKnown) - Ofs(ch)), 'TCharRecord.spellsKnown');
  At(107, DiskRec.CharDiskOfs(Ofs(ch.attackLevel) - Ofs(ch)), 'TCharRecord.attackLevel');
  At(108, DiskRec.CharDiskOfs(Ofs(ch.iconDimensions) - Ofs(ch)), 'TCharRecord.iconDimensions');
  At(109, DiskRec.CharDiskOfs(Ofs(ch.saves) - Ofs(ch)), 'TCharRecord.saves');
  At(114, DiskRec.CharDiskOfs(Ofs(ch.movementBase) - Ofs(ch)), 'TCharRecord.movementBase');
  At(115, DiskRec.CharDiskOfs(Ofs(ch.levelHighest) - Ofs(ch)), 'TCharRecord.levelHighest');
  At(116, DiskRec.CharDiskOfs(Ofs(ch.drainedLevels) - Ofs(ch)), 'TCharRecord.drainedLevels');
  At(117, DiskRec.CharDiskOfs(Ofs(ch.drainedHps) - Ofs(ch)), 'TCharRecord.drainedHps');
  At(118, DiskRec.CharDiskOfs(Ofs(ch.levelUndead) - Ofs(ch)), 'TCharRecord.levelUndead');
  At(119, DiskRec.CharDiskOfs(Ofs(ch.thiefSkills) - Ofs(ch)), 'TCharRecord.thiefSkills');
  At(127, DiskRec.CharDiskOfs(Ofs(ch.effectsAddr) - Ofs(ch)), 'TCharRecord.effectsAddr');
  At(131, DiskRec.CharDiskOfs(Ofs(ch.unknown083) - Ofs(ch)), 'TCharRecord.unknown083');
  At(132, DiskRec.CharDiskOfs(Ofs(ch.npc) - Ofs(ch)), 'TCharRecord.npc');
  At(133, DiskRec.CharDiskOfs(Ofs(ch.npcTreasureShare) - Ofs(ch)), 'TCharRecord.npcTreasureShare');
  At(134, DiskRec.CharDiskOfs(Ofs(ch.unknown086) - Ofs(ch)), 'TCharRecord.unknown086');
  At(135, DiskRec.CharDiskOfs(Ofs(ch.unknown087) - Ofs(ch)), 'TCharRecord.unknown087');
  At(136, DiskRec.CharDiskOfs(Ofs(ch.coins) - Ofs(ch)), 'TCharRecord.coins');
  At(150, DiskRec.CharDiskOfs(Ofs(ch.classLevels) - Ofs(ch)), 'TCharRecord.classLevels');
  At(158, DiskRec.CharDiskOfs(Ofs(ch.gender) - Ofs(ch)), 'TCharRecord.gender');
  At(159, DiskRec.CharDiskOfs(Ofs(ch.charType) - Ofs(ch)), 'TCharRecord.charType');
  At(160, DiskRec.CharDiskOfs(Ofs(ch.alignment) - Ofs(ch)), 'TCharRecord.alignment');
  At(161, DiskRec.CharDiskOfs(Ofs(ch.attacks) - Ofs(ch)), 'TCharRecord.attacks');
  At(162, DiskRec.CharDiskOfs(Ofs(ch.attacks2) - Ofs(ch)), 'TCharRecord.attacks2');
  At(163, DiskRec.CharDiskOfs(Ofs(ch.unarmedRollsA) - Ofs(ch)), 'TCharRecord.unarmedRollsA');
  At(165, DiskRec.CharDiskOfs(Ofs(ch.unarmedDiceA) - Ofs(ch)), 'TCharRecord.unarmedDiceA');
  At(167, DiskRec.CharDiskOfs(Ofs(ch.unarmedModA) - Ofs(ch)), 'TCharRecord.unarmedModA');
  At(169, DiskRec.CharDiskOfs(Ofs(ch.acBase) - Ofs(ch)), 'TCharRecord.acBase');
  At(170, DiskRec.CharDiskOfs(Ofs(ch.useStrength) - Ofs(ch)), 'TCharRecord.useStrength');
  At(171, DiskRec.CharDiskOfs(Ofs(ch.randByte) - Ofs(ch)), 'TCharRecord.randByte');
  At(172, DiskRec.CharDiskOfs(Ofs(ch.experience) - Ofs(ch)), 'TCharRecord.experience');
  At(176, DiskRec.CharDiskOfs(Ofs(ch.itemLimits) - Ofs(ch)), 'TCharRecord.itemLimits');
  At(177, DiskRec.CharDiskOfs(Ofs(ch.hpRolled) - Ofs(ch)), 'TCharRecord.hpRolled');
  At(178, DiskRec.CharDiskOfs(Ofs(ch.clericSpells) - Ofs(ch)), 'TCharRecord.clericSpells');
  At(181, DiskRec.CharDiskOfs(Ofs(ch.mageSpells) - Ofs(ch)), 'TCharRecord.mageSpells');
  At(184, DiskRec.CharDiskOfs(Ofs(ch.xpAward) - Ofs(ch)), 'TCharRecord.xpAward');
  At(186, DiskRec.CharDiskOfs(Ofs(ch.xpBonusPerHp) - Ofs(ch)), 'TCharRecord.xpBonusPerHp');
  At(187, DiskRec.CharDiskOfs(Ofs(ch.portraitHead) - Ofs(ch)), 'TCharRecord.portraitHead');
  At(188, DiskRec.CharDiskOfs(Ofs(ch.portraitBody) - Ofs(ch)), 'TCharRecord.portraitBody');
  At(189, DiskRec.CharDiskOfs(Ofs(ch.iconHead) - Ofs(ch)), 'TCharRecord.iconHead');
  At(190, DiskRec.CharDiskOfs(Ofs(ch.iconBody) - Ofs(ch)), 'TCharRecord.iconBody');
  At(191, DiskRec.CharDiskOfs(Ofs(ch.orderNumber) - Ofs(ch)), 'TCharRecord.orderNumber');
  At(192, DiskRec.CharDiskOfs(Ofs(ch.iconSize) - Ofs(ch)), 'TCharRecord.iconSize');
  At(193, DiskRec.CharDiskOfs(Ofs(ch.iconColors) - Ofs(ch)), 'TCharRecord.iconColors');
  At(199, DiskRec.CharDiskOfs(Ofs(ch.numberOfItems) - Ofs(ch)), 'TCharRecord.numberOfItems');
  At(200, DiskRec.CharDiskOfs(Ofs(ch.itemsAddr) - Ofs(ch)), 'TCharRecord.itemsAddr');
  At(204, DiskRec.CharDiskOfs(Ofs(ch.equipped) - Ofs(ch)), 'TCharRecord.equipped');
  At(256, DiskRec.CharDiskOfs(Ofs(ch.handsEquipped) - Ofs(ch)), 'TCharRecord.handsEquipped');
  At(257, DiskRec.CharDiskOfs(Ofs(ch.saveBonus) - Ofs(ch)), 'TCharRecord.saveBonus');
  At(258, DiskRec.CharDiskOfs(Ofs(ch.encumbrance) - Ofs(ch)), 'TCharRecord.encumbrance');
  At(260, DiskRec.CharDiskOfs(Ofs(ch.nextCharAddr) - Ofs(ch)), 'TCharRecord.nextCharAddr');
  At(264, DiskRec.CharDiskOfs(Ofs(ch.combatAddr) - Ofs(ch)), 'TCharRecord.combatAddr');
  At(268, DiskRec.CharDiskOfs(Ofs(ch.status) - Ofs(ch)), 'TCharRecord.status');
  At(269, DiskRec.CharDiskOfs(Ofs(ch.enabled) - Ofs(ch)), 'TCharRecord.enabled');
  At(270, DiskRec.CharDiskOfs(Ofs(ch.hostile) - Ofs(ch)), 'TCharRecord.hostile');
  At(271, DiskRec.CharDiskOfs(Ofs(ch.quickfight) - Ofs(ch)), 'TCharRecord.quickfight');
  At(272, DiskRec.CharDiskOfs(Ofs(ch.thac0Cur) - Ofs(ch)), 'TCharRecord.thac0Cur');
  At(273, DiskRec.CharDiskOfs(Ofs(ch.acCur) - Ofs(ch)), 'TCharRecord.acCur');
  At(274, DiskRec.CharDiskOfs(Ofs(ch.acBehind) - Ofs(ch)), 'TCharRecord.acBehind');
  At(275, DiskRec.CharDiskOfs(Ofs(ch.curAttacks) - Ofs(ch)), 'TCharRecord.curAttacks');
  At(276, DiskRec.CharDiskOfs(Ofs(ch.curAttacks2) - Ofs(ch)), 'TCharRecord.curAttacks2');
  At(277, DiskRec.CharDiskOfs(Ofs(ch.curRollsA) - Ofs(ch)), 'TCharRecord.curRollsA');
  At(279, DiskRec.CharDiskOfs(Ofs(ch.curDiceA) - Ofs(ch)), 'TCharRecord.curDiceA');
  At(281, DiskRec.CharDiskOfs(Ofs(ch.curModA) - Ofs(ch)), 'TCharRecord.curModA');
  At(283, DiskRec.CharDiskOfs(Ofs(ch.hpCur) - Ofs(ch)), 'TCharRecord.hpCur');
  At(284, DiskRec.CharDiskOfs(Ofs(ch.movementCur) - Ofs(ch)), 'TCharRecord.movementCur');
  { the port's own fields (#838) follow the saved bytes, so the files keep SSI's 285 }
  At(285, DiskRec.CharDiskOfs(Ofs(ch.portExt) - Ofs(ch)), 'TCharRecord.portExt');
  At(16, DiskRec.CharDiskOfs(Ofs(ch.stats) - Ofs(ch)), 'TCharRecord.stats');
  At(16, DiskRec.CharDiskOfs(Ofs(ch.genderPad) - Ofs(ch)), 'TCharRecord.genderPad');
  At(158, DiskRec.CharDiskOfs(Ofs(ch.genderSp) - Ofs(ch)), 'TCharRecord.genderSp');
  At(16, DiskRec.CharDiskOfs(Ofs(ch.iconColorsPad) - Ofs(ch)), 'TCharRecord.iconColorsPad');
  At(193, DiskRec.CharDiskOfs(Ofs(ch.iconColors1) - Ofs(ch)), 'TCharRecord.iconColors1');
  At(16, DiskRec.CharDiskOfs(Ofs(ch.viewPad0) - Ofs(ch)), 'TCharRecord.viewPad0');
  At(158, DiskRec.CharDiskOfs(Ofs(ch.genderIdx) - Ofs(ch)), 'TCharRecord.genderIdx');
  At(159, DiskRec.CharDiskOfs(Ofs(ch.viewPad1) - Ofs(ch)), 'TCharRecord.viewPad1');
  At(160, DiskRec.CharDiskOfs(Ofs(ch.alignmentIdx) - Ofs(ch)), 'TCharRecord.alignmentIdx');
  { CbtActs' view of the armor class and attacks: in memory, its fields are the record's (64 bits included) }
  TestKit.CheckEqualsL(Ofs(ch.acCur) - Ofs(ch), Ofs(Types.PAttackPhaseView(@ch)^.acCurArr) - Ofs(ch),
                       'TAttackPhaseView.acCurArr is TCharRecord.acCur');
  TestKit.CheckEqualsL(Ofs(ch.curAttacks) - Ofs(ch), Ofs(Types.PAttackPhaseView(@ch)^.curAtt) - Ofs(ch),
                       'TAttackPhaseView.curAtt is TCharRecord.curAttacks');
  TestKit.CheckEqualsL(63, DiskRec.ItemDiskSize, 'TItemRec on disk');
  At(0, DiskRec.ItemDiskOfs(Ofs(it.name) - Ofs(it)), 'TItemRec.name');
  At(41, DiskRec.ItemDiskOfs(Ofs(it.inUse) - Ofs(it)), 'TItemRec.inUse');
  At(42, DiskRec.ItemDiskOfs(Ofs(it.next) - Ofs(it)), 'TItemRec.next');
  At(46, DiskRec.ItemDiskOfs(Ofs(it.itemType) - Ofs(it)), 'TItemRec.itemType');
  At(47, DiskRec.ItemDiskOfs(Ofs(it.nameIds) - Ofs(it)), 'TItemRec.nameIds');
  At(50, DiskRec.ItemDiskOfs(Ofs(it.plus) - Ofs(it)), 'TItemRec.plus');
  At(51, DiskRec.ItemDiskOfs(Ofs(it.saveBonus) - Ofs(it)), 'TItemRec.saveBonus');
  At(52, DiskRec.ItemDiskOfs(Ofs(it.equipped) - Ofs(it)), 'TItemRec.equipped');
  At(53, DiskRec.ItemDiskOfs(Ofs(it.unidMask) - Ofs(it)), 'TItemRec.unidMask');
  At(54, DiskRec.ItemDiskOfs(Ofs(it.cursed) - Ofs(it)), 'TItemRec.cursed');
  At(55, DiskRec.ItemDiskOfs(Ofs(it.weight) - Ofs(it)), 'TItemRec.weight');
  At(57, DiskRec.ItemDiskOfs(Ofs(it.quantity) - Ofs(it)), 'TItemRec.quantity');
  At(58, DiskRec.ItemDiskOfs(Ofs(it.value) - Ofs(it)), 'TItemRec.value');
  At(60, DiskRec.ItemDiskOfs(Ofs(it.charges) - Ofs(it)), 'TItemRec.charges');
  At(61, DiskRec.ItemDiskOfs(Ofs(it.effect) - Ofs(it)), 'TItemRec.effect');
  At(62, DiskRec.ItemDiskOfs(Ofs(it.special) - Ofs(it)), 'TItemRec.special');
  At(60, DiskRec.ItemDiskOfs(Ofs(it.spells) - Ofs(it)), 'TItemRec.spells');
  TestKit.CheckEqualsL(9, DiskRec.EffectDiskSize, 'TEffectRec on disk');
  At(0, DiskRec.EffectDiskOfs(Ofs(ef.id) - Ofs(ef)), 'TEffectRec.id');
  At(1, DiskRec.EffectDiskOfs(Ofs(ef.duration) - Ofs(ef)), 'TEffectRec.duration');
  At(3, DiskRec.EffectDiskOfs(Ofs(ef.strength) - Ofs(ef)), 'TEffectRec.strength');
  At(4, DiskRec.EffectDiskOfs(Ofs(ef.onRemove) - Ofs(ef)), 'TEffectRec.onRemove');
  At(5, DiskRec.EffectDiskOfs(Ofs(ef.next) - Ofs(ef)), 'TEffectRec.next');
  TestKit.Done;
end.

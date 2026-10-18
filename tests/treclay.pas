{ Tests the layout of the records saved in character and game files: TCharRecord (NAME.CHA and CHRDATxN.SAV, 285
  bytes), TItemRec (.ITM, 63 bytes each) and TEffectRec (.SPC, 9 bytes each). Every field's offset is SSI's: the
  numbers were read from this program compiled against SSI's v1.3 source (por-disassembly v13/src, whose field names
  are the same), and a change that moves a field breaks the files SSI's game and earlier saves wrote. }
{$I COMPILER.INC}
program TRecLay;

uses Types, TestKit;

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
  TestKit.CheckEqualsL(285, SizeOf(Types.TCharRecord), 'SizeOf(TCharRecord)');
  At(0, Ofs(ch.name) - Ofs(ch), 'TCharRecord.name');
  At(16, Ofs(ch.strCur) - Ofs(ch), 'TCharRecord.strCur');
  At(17, Ofs(ch.intCur) - Ofs(ch), 'TCharRecord.intCur');
  At(18, Ofs(ch.wisCur) - Ofs(ch), 'TCharRecord.wisCur');
  At(19, Ofs(ch.dexCur) - Ofs(ch), 'TCharRecord.dexCur');
  At(20, Ofs(ch.conCur) - Ofs(ch), 'TCharRecord.conCur');
  At(21, Ofs(ch.chaCur) - Ofs(ch), 'TCharRecord.chaCur');
  At(22, Ofs(ch.strExc) - Ofs(ch), 'TCharRecord.strExc');
  At(23, Ofs(ch.memorizedSpells) - Ofs(ch), 'TCharRecord.memorizedSpells');
  At(44, Ofs(ch.spellPrepTime) - Ofs(ch), 'TCharRecord.spellPrepTime');
  At(45, Ofs(ch.thac0Base) - Ofs(ch), 'TCharRecord.thac0Base');
  At(46, Ofs(ch.race) - Ofs(ch), 'TCharRecord.race');
  At(47, Ofs(ch.charClass) - Ofs(ch), 'TCharRecord.charClass');
  At(48, Ofs(ch.age) - Ofs(ch), 'TCharRecord.age');
  At(50, Ofs(ch.hpMax) - Ofs(ch), 'TCharRecord.hpMax');
  At(51, Ofs(ch.spellsKnown) - Ofs(ch), 'TCharRecord.spellsKnown');
  At(107, Ofs(ch.attackLevel) - Ofs(ch), 'TCharRecord.attackLevel');
  At(108, Ofs(ch.iconDimensions) - Ofs(ch), 'TCharRecord.iconDimensions');
  At(109, Ofs(ch.saves) - Ofs(ch), 'TCharRecord.saves');
  At(114, Ofs(ch.movementBase) - Ofs(ch), 'TCharRecord.movementBase');
  At(115, Ofs(ch.levelHighest) - Ofs(ch), 'TCharRecord.levelHighest');
  At(116, Ofs(ch.drainedLevels) - Ofs(ch), 'TCharRecord.drainedLevels');
  At(117, Ofs(ch.drainedHps) - Ofs(ch), 'TCharRecord.drainedHps');
  At(118, Ofs(ch.levelUndead) - Ofs(ch), 'TCharRecord.levelUndead');
  At(119, Ofs(ch.thiefSkills) - Ofs(ch), 'TCharRecord.thiefSkills');
  At(127, Ofs(ch.effectsAddr) - Ofs(ch), 'TCharRecord.effectsAddr');
  At(131, Ofs(ch.unknown083) - Ofs(ch), 'TCharRecord.unknown083');
  At(132, Ofs(ch.npc) - Ofs(ch), 'TCharRecord.npc');
  At(133, Ofs(ch.npcTreasureShare) - Ofs(ch), 'TCharRecord.npcTreasureShare');
  At(134, Ofs(ch.unknown086) - Ofs(ch), 'TCharRecord.unknown086');
  At(135, Ofs(ch.unknown087) - Ofs(ch), 'TCharRecord.unknown087');
  At(136, Ofs(ch.coins) - Ofs(ch), 'TCharRecord.coins');
  At(150, Ofs(ch.classLevels) - Ofs(ch), 'TCharRecord.classLevels');
  At(158, Ofs(ch.gender) - Ofs(ch), 'TCharRecord.gender');
  At(159, Ofs(ch.charType) - Ofs(ch), 'TCharRecord.charType');
  At(160, Ofs(ch.alignment) - Ofs(ch), 'TCharRecord.alignment');
  At(161, Ofs(ch.attacks) - Ofs(ch), 'TCharRecord.attacks');
  At(162, Ofs(ch.attacks2) - Ofs(ch), 'TCharRecord.attacks2');
  At(163, Ofs(ch.unarmedRollsA) - Ofs(ch), 'TCharRecord.unarmedRollsA');
  At(165, Ofs(ch.unarmedDiceA) - Ofs(ch), 'TCharRecord.unarmedDiceA');
  At(167, Ofs(ch.unarmedModA) - Ofs(ch), 'TCharRecord.unarmedModA');
  At(169, Ofs(ch.acBase) - Ofs(ch), 'TCharRecord.acBase');
  At(170, Ofs(ch.useStrength) - Ofs(ch), 'TCharRecord.useStrength');
  At(171, Ofs(ch.randByte) - Ofs(ch), 'TCharRecord.randByte');
  At(172, Ofs(ch.experience) - Ofs(ch), 'TCharRecord.experience');
  At(176, Ofs(ch.itemLimits) - Ofs(ch), 'TCharRecord.itemLimits');
  At(177, Ofs(ch.hpRolled) - Ofs(ch), 'TCharRecord.hpRolled');
  At(178, Ofs(ch.clericSpells) - Ofs(ch), 'TCharRecord.clericSpells');
  At(181, Ofs(ch.mageSpells) - Ofs(ch), 'TCharRecord.mageSpells');
  At(184, Ofs(ch.xpAward) - Ofs(ch), 'TCharRecord.xpAward');
  At(186, Ofs(ch.xpBonusPerHp) - Ofs(ch), 'TCharRecord.xpBonusPerHp');
  At(187, Ofs(ch.portraitHead) - Ofs(ch), 'TCharRecord.portraitHead');
  At(188, Ofs(ch.portraitBody) - Ofs(ch), 'TCharRecord.portraitBody');
  At(189, Ofs(ch.iconHead) - Ofs(ch), 'TCharRecord.iconHead');
  At(190, Ofs(ch.iconBody) - Ofs(ch), 'TCharRecord.iconBody');
  At(191, Ofs(ch.orderNumber) - Ofs(ch), 'TCharRecord.orderNumber');
  At(192, Ofs(ch.iconSize) - Ofs(ch), 'TCharRecord.iconSize');
  At(193, Ofs(ch.iconColors) - Ofs(ch), 'TCharRecord.iconColors');
  At(199, Ofs(ch.numberOfItems) - Ofs(ch), 'TCharRecord.numberOfItems');
  At(200, Ofs(ch.itemsAddr) - Ofs(ch), 'TCharRecord.itemsAddr');
  At(204, Ofs(ch.equipped) - Ofs(ch), 'TCharRecord.equipped');
  At(256, Ofs(ch.handsEquipped) - Ofs(ch), 'TCharRecord.handsEquipped');
  At(257, Ofs(ch.saveBonus) - Ofs(ch), 'TCharRecord.saveBonus');
  At(258, Ofs(ch.encumbrance) - Ofs(ch), 'TCharRecord.encumbrance');
  At(260, Ofs(ch.nextCharAddr) - Ofs(ch), 'TCharRecord.nextCharAddr');
  At(264, Ofs(ch.combatAddr) - Ofs(ch), 'TCharRecord.combatAddr');
  At(268, Ofs(ch.status) - Ofs(ch), 'TCharRecord.status');
  At(269, Ofs(ch.enabled) - Ofs(ch), 'TCharRecord.enabled');
  At(270, Ofs(ch.hostile) - Ofs(ch), 'TCharRecord.hostile');
  At(271, Ofs(ch.quickfight) - Ofs(ch), 'TCharRecord.quickfight');
  At(272, Ofs(ch.thac0Cur) - Ofs(ch), 'TCharRecord.thac0Cur');
  At(273, Ofs(ch.acCur) - Ofs(ch), 'TCharRecord.acCur');
  At(274, Ofs(ch.acBehind) - Ofs(ch), 'TCharRecord.acBehind');
  At(275, Ofs(ch.curAttacks) - Ofs(ch), 'TCharRecord.curAttacks');
  At(276, Ofs(ch.curAttacks2) - Ofs(ch), 'TCharRecord.curAttacks2');
  At(277, Ofs(ch.curRollsA) - Ofs(ch), 'TCharRecord.curRollsA');
  At(279, Ofs(ch.curDiceA) - Ofs(ch), 'TCharRecord.curDiceA');
  At(281, Ofs(ch.curModA) - Ofs(ch), 'TCharRecord.curModA');
  At(283, Ofs(ch.hpCur) - Ofs(ch), 'TCharRecord.hpCur');
  At(284, Ofs(ch.movementCur) - Ofs(ch), 'TCharRecord.movementCur');
  At(16, Ofs(ch.stats) - Ofs(ch), 'TCharRecord.stats');
  At(16, Ofs(ch.genderPad) - Ofs(ch), 'TCharRecord.genderPad');
  At(158, Ofs(ch.genderSp) - Ofs(ch), 'TCharRecord.genderSp');
  At(16, Ofs(ch.iconColorsPad) - Ofs(ch), 'TCharRecord.iconColorsPad');
  At(193, Ofs(ch.iconColors1) - Ofs(ch), 'TCharRecord.iconColors1');
  At(16, Ofs(ch.slotsPad) - Ofs(ch), 'TCharRecord.slotsPad');
  At(178, Ofs(ch.slots) - Ofs(ch), 'TCharRecord.slots');
  At(16, Ofs(ch.viewPad0) - Ofs(ch), 'TCharRecord.viewPad0');
  At(158, Ofs(ch.genderIdx) - Ofs(ch), 'TCharRecord.genderIdx');
  At(159, Ofs(ch.viewPad1) - Ofs(ch), 'TCharRecord.viewPad1');
  At(160, Ofs(ch.alignmentIdx) - Ofs(ch), 'TCharRecord.alignmentIdx');
  TestKit.CheckEqualsL(63, SizeOf(Types.TItemRec), 'SizeOf(TItemRec)');
  At(0, Ofs(it.name) - Ofs(it), 'TItemRec.name');
  At(41, Ofs(it.inUse) - Ofs(it), 'TItemRec.inUse');
  At(42, Ofs(it.next) - Ofs(it), 'TItemRec.next');
  At(46, Ofs(it.itemType) - Ofs(it), 'TItemRec.itemType');
  At(47, Ofs(it.nameIds) - Ofs(it), 'TItemRec.nameIds');
  At(50, Ofs(it.plus) - Ofs(it), 'TItemRec.plus');
  At(51, Ofs(it.saveBonus) - Ofs(it), 'TItemRec.saveBonus');
  At(52, Ofs(it.equipped) - Ofs(it), 'TItemRec.equipped');
  At(53, Ofs(it.unidMask) - Ofs(it), 'TItemRec.unidMask');
  At(54, Ofs(it.cursed) - Ofs(it), 'TItemRec.cursed');
  At(55, Ofs(it.weight) - Ofs(it), 'TItemRec.weight');
  At(57, Ofs(it.quantity) - Ofs(it), 'TItemRec.quantity');
  At(58, Ofs(it.value) - Ofs(it), 'TItemRec.value');
  At(60, Ofs(it.charges) - Ofs(it), 'TItemRec.charges');
  At(61, Ofs(it.effect) - Ofs(it), 'TItemRec.effect');
  At(62, Ofs(it.special) - Ofs(it), 'TItemRec.special');
  At(60, Ofs(it.spells) - Ofs(it), 'TItemRec.spells');
  TestKit.CheckEqualsL(9, SizeOf(Types.TEffectRec), 'SizeOf(TEffectRec)');
  At(0, Ofs(ef.id) - Ofs(ef), 'TEffectRec.id');
  At(1, Ofs(ef.duration) - Ofs(ef), 'TEffectRec.duration');
  At(3, Ofs(ef.strength) - Ofs(ef), 'TEffectRec.strength');
  At(4, Ofs(ef.onRemove) - Ofs(ef), 'TEffectRec.onRemove');
  At(5, Ofs(ef.next) - Ofs(ef), 'TEffectRec.next');
  TestKit.Done;
end.

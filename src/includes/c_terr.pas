{ Combat terrain values: types 26..29 are decoration; 30, 31 and 66 represent Stinking Cloud, corpses and Cloudkill. }
{$I COMPILER.INC}
unit C_TERR;

interface

const
  { Stinking Cloud terrain. The AI avoids it unless the mover is animated, coughing or immune to poison. }
  STINKING_CLOUD = 30;
  { Corpse terrain. Save the previous terrain before replacing it; restoration ignores a saved corpse value to avoid
    leaving a second corpse marker. }
  CORPSE = 31;
  { Cloudkill terrain (#1193), past the arena's own: Curse's 28 is a decoration tile in PoR's arenas (a banana peel in
    RANDCOM.DAX, CombatSt.SprinkleRareFeatures). Its art is the stinking cloud's recoloured (MapTiles.CloudkillArt). The
    AI keeps out of it unless the cloud cannot touch the mover (CombatAi.AvoidsCloudkill). }
  CLOUDKILL = 66;
  { the clouds' terrains: a cloud's cell keeps the ground under it in its node (Types.TCloudRec) }
  CLOUDS = [STINKING_CLOUD, CLOUDKILL];

implementation

end.

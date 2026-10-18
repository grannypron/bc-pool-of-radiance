{ Journal text: journal entries 33 to 49. Each item is held in runs of up to 9 lines joined by #13, as string literals
  in code, so the text lives in the overlay and costs no data segment. JrnlList reads it a line at a time. }
{$O+,F+}
{$I COMPILER.INC}
unit Journal3;

interface

{ The number of display lines an item's text takes.
  @param(index The item's place in the Journal list.)
  @returns(The line count, or 0 for an item this unit does not hold.) }
function LineCount(index: Integer): Integer;

{ One run of an item's display lines.
  @param(index The item's place in the Journal list.)
  @param(chunk Which run of up to 9 lines, from 0.)
  @returns(The run's lines separated by #13, or an empty string past the end.) }
function TextChunk(index, chunk: Integer): string;

implementation

function LineCount(index: Integer): Integer;
begin
  case index of
    51: LineCount := 24;
    52: LineCount := 19;
    53: LineCount := 36;
    54: LineCount := 45;
    55: LineCount := 9;
    56: LineCount := 34;
    57: LineCount := 27;
    58: LineCount := 9;
    59: LineCount := 4;
    60: LineCount := 3;
    61: LineCount := 84;
    62: LineCount := 55;
    63: LineCount := 73;
    64: LineCount := 54;
    65: LineCount := 26;
    66: LineCount := 41;
    67: LineCount := 31;
    else LineCount := 0;
  end;
end;

function TextChunk(index, chunk: Integer): string;
begin
  TextChunk := '';
  case index of
    { Entry 33 }
    51:
      case chunk of
        0:
          TextChunk :=
            'AN OFFICIAL LOOKING NOTICE'#13 +
            #13 +
            'YARASH,'#13 +
            #13 +
            '"THE TIME HAS COME FOR YOU'#13 +
            'TO ADD YOUR POWER TO THE'#13 +
            'GROWING LEGIONS OF MY'#13 +
            'FOLLOWERS.'#13 +
            '';
        1:
          TextChunk :=
            'COME AND SUPPLICANT'#13 +
            'YOURSELF TO ME AND I WILL'#13 +
            'REWARD YOU AS AN IMPORTANT'#13 +
            'OFFICER IN MY MAGICAL'#13 +
            'FORCES. YOU WILL SERVE AS'#13 +
            'THE ADVISOR TO THE COHORT'#13 +
            'OF SOLDIERS TO BE BASED AT'#13 +
            'SORCERER''S ISLAND. RESIST'#13 +
            'AND YOU SHALL BE CRUSHED';
        2:
          TextChunk :=
            'BEFORE MY ALMIGHTY POWER. I'#13 +
            'EXPECT YOUR POSITIVE REPLY'#13 +
            'WITHIN THE WEEK."'#13 +
            #13 +
            'SIGNED,'#13 +
            'THE BOSS';
      end;
    { Entry 34 }
    52:
      case chunk of
        0:
          TextChunk :=
            'TOLD IN A TRIUMPHANT TONE.'#13 +
            #13 +
            '"YOU HAVE NO UNDERSTANDING'#13 +
            'OF THE SUBTLETY OF'#13 +
            'TYRANTHRAXUS AND HIS'#13 +
            'ALLIES. HERE YOU HAVE'#13 +
            'TRUSTED ME ENOUGH TO LET'#13 +
            'YOUR GUARD DOWN. NOW YOU'#13 +
            'ARE MY PRISONERS.';
        1:
          TextChunk :=
            #13 +
            '"MY KOBOLD FRIENDS DESERVE'#13 +
            'SOME REWARD FOR THEIR HELP.'#13 +
            'THEREFORE, YOU ARE TO BE'#13 +
            'TAKEN TO THEIR PIT. THERE,'#13 +
            'UNARMED, YOU SHALL FIGHT'#13 +
            'BERSHEERA, MY PET SERPENT.'#13 +
            'HE SHOULD BE HUNGRY NOW,'#13 +
            'MERCHANTS DON''T SATISFY HIM';
        2:
          TextChunk :=
            'FOR LONG."';
      end;
    { Entry 35 }
    53:
      case chunk of
        0:
          TextChunk :=
            'TOLD IN HALTING SPEECH.'#13 +
            #13 +
            '"THANK YOU FOR FREEING US.'#13 +
            'YARASH HAS BEEN'#13 +
            'EXPERIMENTING ON OUR'#13 +
            'PEOPLE, CHANGING THEM IN'#13 +
            'HORRIBLE WAYS. EVERY NIGHT'#13 +
            'WE CARRY OFF ANOTHER LIZARD'#13 +
            'MAN WITH HIS CHEST BURST';
        1:
          TextChunk :=
            'OPEN OR HIS HEAD MANGLED.'#13 +
            'YARASH SAY HE MAKE US LIKE'#13 +
            'SA-HAG-AN. HE ALWAYS SAY'#13 +
            'THAT HE MAKE US STRONGER,'#13 +
            'BETTER HUNTERS. BUT ALL HE'#13 +
            'MAKE US IS DEAD.'#13 +
            #13 +
            '"WE WERE NOT ALLOWED TO'#13 +
            'SPEAK WHEN YARASH WAS';
        2:
          TextChunk :=
            'AROUND. THESE MARKS WERE'#13 +
            'PASSED DOWN TO US AND'#13 +
            'REMIND US OF HOME. THEY'#13 +
            'REPRESENT THE FRIEND WORD'#13 +
            'USED BETWEEN LIZARD MEN OF'#13 +
            'DIFFERENT TRIBES. IF YOU'#13 +
            'MEET LIZARD MEN ON THE'#13 +
            'OUTSIDE, THIS WORD MAY HELP'#13 +
            'YOU."';
        3:
          TextChunk :=
            #13 +
            'THE LIZARD MAN CAREFULLY'#13 +
            'SCRATCHES MARKS INTO THE'#13 +
            'DIRT. YOU RECOGNIZE THE'#13 +
            'MARKS AS TWO RUNES AND A'#13 +
            'PATH SYMBOL.'#13 +
            #13 +
            '(PICTURE: LIZARD MAN''S'#13 +
            'MARKINGS)';
      end;
    { Entry 36 }
    54:
      case chunk of
        0:
          TextChunk :=
            'CAREFULLY PREPARED NOTES.'#13 +
            #13 +
            'NOTE 4: "HE HAS FOOLED ME.'#13 +
            'ALL THIS TIME HE HAS CALLED'#13 +
            'HIMSELF TYRANTHRAXUS THE'#13 +
            'FLAMED ONE. HE EXHIBITED'#13 +
            'HIS FLAME, AND SPOKE OF'#13 +
            'DEEDS ATTRIBUTED TO'#13 +
            'TYRANTHRAXUS. BUT TODAY,';
        1:
          TextChunk :=
            'WHILE HE DID NOT KNOW I WAS'#13 +
            'AROUND, HE REVEALED HIS'#13 +
            'TRUE IDENTITY. HE SPOKE'#13 +
            'INTO THE GREAT POOL IN HIS'#13 +
            'LAIR. I THINK HE SPOKE TO'#13 +
            'LORD BANE HIMSELF. AND HE'#13 +
            'REFERRED TO HIMSELF AS'#13 +
            'MARAM. MARAM, HE OF THE'#13 +
            'GREAT SPEAR, IS ALSO A';
        2:
          TextChunk :=
            'SERVANT OF BANE.'#13 +
            #13 +
            '"WHY WOULD MY LEADER USE A'#13 +
            'FALSE NAME? HE HIDES HIS'#13 +
            'TRUE IDENTITY FROM THE'#13 +
            'WORLD, SO THAT THEY DO NOT'#13 +
            'RESEARCH HIS PAST AND'#13 +
            'DISCOVER HIS WEAKNESSES.'#13 +
            'WHAT IF HE ALSO HIDES HIS';
        3:
          TextChunk :=
            'IDENTITY FROM HIS CLOSEST'#13 +
            'ADVISORS, SO THAT THEY ALSO'#13 +
            'CANNOT KNOW HIS TRUE'#13 +
            'ABILITIES AND WEAKNESSES.'#13 +
            'ANYONE WHO ATTACKED HIM,'#13 +
            'THINKING TO UTILIZE THE'#13 +
            'WEAKNESSES OF TYRANTHRAXUS,'#13 +
            'WOULD BE DESTROYED BY THE'#13 +
            'DIFFERENT POWERS OF MARAM';
        4:
          TextChunk :=
            'OF THE GREAT SPEAR.'#13 +
            #13 +
            '"MY RESEARCH INTO'#13 +
            'TYRANTHRAXUS IS NOW'#13 +
            'USELESS. I MUST SCOUR MY'#13 +
            'RECORDS FOR DETAILS'#13 +
            'CONCERNING MARAM OF THE'#13 +
            'GREAT SPEAR. I HAVE MUCH'#13 +
            'WORK TO DO."';
      end;
    { Entry 37 }
    55:
      case chunk of
        0:
          TextChunk :=
            'A MASSIVE ATLAS DRAWN BY'#13 +
            'THE GREAT MATHEMATICIAN'#13 +
            'TOMARUS.'#13 +
            #13 +
            '(PICTURE 1)'#13 +
            #13 +
            '(PICTURE 2)'#13 +
            #13 +
            '(PICTURE 3)';
      end;
    { Entry 38 }
    56:
      case chunk of
        0:
          TextChunk :=
            'SEVERAL PIECES OF PAPER'#13 +
            'WITH HIGHLY ORGANIZED'#13 +
            'WRITING.'#13 +
            #13 +
            'FACT: WERNER VON URSLINGEN'#13 +
            'IS A RETIRED MERCENARY'#13 +
            'CAPTAIN TURNED BUSINESS'#13 +
            'MAN.'#13 +
            '';
        1:
          TextChunk :=
            'STRONG RUMOR: MOSTLY'#13 +
            'INTERESTED IN THE MILITARY'#13 +
            'ASPECTS OF THE RECONQUEST'#13 +
            'OF PHLAN.'#13 +
            #13 +
            'RUMOR: FOUGHT IN A'#13 +
            'MERCENARY UNIT HIRED BY THE'#13 +
            'BOSS EARLY IN HIS CAREER.'#13 +
            '';
        2:
          TextChunk :=
            'RUMOR: HATES ZHENTARIM'#13 +
            'BECAUSE HE FOUGHT IN A UNIT'#13 +
            'AGAINST THEM SEVERAL TIMES.'#13 +
            #13 +
            'RUMOR: HAS STRONG CONTACTS'#13 +
            'WITH OTHER MERCENARIES AND'#13 +
            'SOME RUFFIANS IN TOWN; NONE'#13 +
            'OF OUR INFORMANTS CONFIRM'#13 +
            'SUCH CONTACT.';
        3:
          TextChunk :=
            #13 +
            'VAGUE RUMOR: VON'#13 +
            'URSLINGEN''S UNIT WAS WIPED'#13 +
            'OUT BY ENEMY MAGIC USERS;'#13 +
            'HE WAS THE ONLY SURVIVOR;'#13 +
            'HE RETIRED AND NOW SECRETLY'#13 +
            'HATES MAGIC USERS.';
      end;
    { Entry 39 }
    57:
      case chunk of
        0:
          TextChunk :=
            'A PRESERVED PARCHMENT'#13 +
            'COVERED WITH GIANT SCRIPT.'#13 +
            #13 +
            '"I AM WRITING TO YOU TO'#13 +
            'DESCRIBE MY FURTHER'#13 +
            'INQUIRIES INTO THE LEGEND'#13 +
            'OF THE POOL OF RADIANCE. IT'#13 +
            'SEEMS THE POOL HAS MOVED'#13 +
            'SEVERAL TIMES. LONG AGO, AT';
        1:
          TextChunk :=
            'LEAST ONE WISE WIZARD'#13 +
            'ACTUALLY MOVED THE POOL'#13 +
            'INTO HIS ABODE FOR A PERIOD'#13 +
            'OF TIME TO STUDY IT.'#13 +
            'HOWEVER, THE POOL SEEMS TO'#13 +
            'RETURN TO ITS ORIGINAL'#13 +
            'LOCATION AFTER EVERY MOVE.'#13 +
            'I AM NOW WATCHING THE DRY'#13 +
            'HOLE THAT IS THE POOL''S';
        2:
          TextChunk :=
            'NATURAL LOCATION. WHEN IT'#13 +
            'RETURNS I WILL BE READY. I'#13 +
            'TRULY BELIEVE THAT THE POOL'#13 +
            'OF RADIANCE IS THE KEY TO'#13 +
            'THE SECRET WISDOM THAT I'#13 +
            'SEEK."'#13 +
            #13 +
            'YOURS IN WISDOM'#13 +
            'SORRASSAR';
      end;
    { Entry 40 }
    58:
      case chunk of
        0:
          TextChunk :=
            'A QUICK NOTE ON AN OFTEN'#13 +
            'USED PIECE OF PAPER.'#13 +
            #13 +
            '"BOTH KOBOLDS AND'#13 +
            'HOBGOBLINS EXIST IN LARGE'#13 +
            'NUMBERS TO THE EAST.'#13 +
            'EXPERIMENTS SHOW NEITHER'#13 +
            'MAKES GOOD BREEDING'#13 +
            'MATERIAL."';
      end;
    { Entry 41 }
    59:
      case chunk of
        0:
          TextChunk :=
            'A CLEAN MAP DRAWN WITH'#13 +
            'EXACT LINES.'#13 +
            #13 +
            '(PICTURE)';
      end;
    { Entry 42 }
    60:
      case chunk of
        0:
          TextChunk :=
            'A SKETCH DRAWING.'#13 +
            #13 +
            '(PICTURE)';
      end;
    { Entry 43 }
    61:
      case chunk of
        0:
          TextChunk :=
            'A LOOSELY WRAPPED SCROLL.'#13 +
            #13 +
            '"ARAMALG-THE-GOOD, PALADIN'#13 +
            'AND BROTHER OF'#13 +
            'TAIMALG-THE-INVINCIBLE, AND'#13 +
            'SARASIM OF TESHWAVE, THE'#13 +
            'HIGH PRIESTESS OF SUNE,'#13 +
            'ATTACKED THE DENIZENS OF'#13 +
            'THE VALHINGEN GRAVEYARD';
        1:
          TextChunk :=
            'WITH A HOLY VENGEANCE. THEY'#13 +
            'CAME IN SEARCH OF TAIMALG'#13 +
            'AND HIS MERCENARY BAND, WHO'#13 +
            'ASSAULTED THE GRAVEYARD AND'#13 +
            'DID NOT RETURN.'#13 +
            #13 +
            '"SARASIM USED HER HOLY'#13 +
            'POWER TO DISSIPATE AND TURN'#13 +
            'THE UNDEAD THAT CONFRONTED';
        2:
          TextChunk :=
            'THEM. ARAMALG WIELDED HIS'#13 +
            'VORPAL SWORD AND SLEW THE'#13 +
            'FEW THAT FOUGHT HER POWER.'#13 +
            #13 +
            '"TOGETHER, ARAMALG AND'#13 +
            'SARASIM PENETRATED THE'#13 +
            'GRAVEYARD TO AN EVIL MARBLE'#13 +
            'CRYPT. THEY FOUND AND'#13 +
            'SPLINTERED AN EMPTY COFFIN,';
        3:
          TextChunk :=
            'BLESSING THE REMAINS AND'#13 +
            'SPRINKLING IT WITH HOLY'#13 +
            'WATER. THEN THEY CONFRONTED'#13 +
            'THE OWNER OF THE COFFIN, A'#13 +
            'CREATURE OF GREAT EVIL AND'#13 +
            'THE LEADER OF THE UNDEAD IN'#13 +
            'VALHINGEN, AN ANCIENT'#13 +
            'VAMPIRE. THE THREE BEGAN A'#13 +
            'FURIOUS MELEE.';
        4:
          TextChunk :=
            #13 +
            '"THE VAMPIRE WAS SWAYED BY'#13 +
            'ARAMALG AND SARASIM''S'#13 +
            'POWER, BUT WOULD NOT BE'#13 +
            'TURNED. THE VAMPIRE'#13 +
            'SHOUTED, "I HAVE DEFEATED'#13 +
            'TAIMALG AND HIS WARRIORS, I'#13 +
            'WILL DEFEAT THE BROTHER OF'#13 +
            'TAIMALG AS WELL!"';
        5:
          TextChunk :=
            #13 +
            '"THE VAMPIRE SUMMONED AN'#13 +
            'ARMY OF RATS AND TRIED TO'#13 +
            'CHARM SARASIM TO HIS SIDE,'#13 +
            'BUT TO NO AVAIL. SARASIM'#13 +
            'RESISTED HIS CHARM AND'#13 +
            'ARAMALG CHARGED THROUGH THE'#13 +
            'MASSED VERMIN. THE VAMPIRE'#13 +
            'FELL BEFORE THE MIGHTY';
        6:
          TextChunk :=
            'BLOWS OF ARAMALG''S HOLY'#13 +
            'SWORD AND SARASIM''S'#13 +
            'ENCHANTED MACE.'#13 +
            #13 +
            '"DEFEATED, THE ANCIENT'#13 +
            'VAMPIRE DISSOLVED INTO GAS'#13 +
            'AND FLED TO HIS COFFIN.'#13 +
            'FINDING THE COFFIN'#13 +
            'DESTROYED HE RETURNED TO';
        7:
          TextChunk :=
            'SOLID FORM AND SCREAMED.'#13 +
            'SEIZING THE MOMENT ARAMALG'#13 +
            'GRABBED THE VAMPIRE AND'#13 +
            'HELD HIM WITH ALL OF HIS'#13 +
            'STRENGTH. SARASIM RAN UP'#13 +
            'AND DROVE AN OAKEN STAKE'#13 +
            'THROUGH THE VAMPIRE''S'#13 +
            'HEART.'#13 +
            '';
        8:
          TextChunk :=
            '"ARAMALG AND SARASIM'#13 +
            'PERFORMED THE PROPER'#13 +
            'RITUALS TO BANISH THE'#13 +
            'VAMPIRE FOREVER. THEN,'#13 +
            'WOUNDED, ARAMALG AND'#13 +
            'SARASIM LEFT VALHINGEN'#13 +
            'GRAVEYARD. IT WAS BEYOND'#13 +
            'THEIR POWER TO COMPLETELY'#13 +
            'CLEANSE THE EVIL PLACE, BUT';
        9:
          TextChunk :=
            'THEY HAD EXTRACTED PROPER'#13 +
            'VENGEANCE FOR THE DEATH OF'#13 +
            'TIAMALG AND HIS TROOPS."';
      end;
    { Entry 44 }
    62:
      case chunk of
        0:
          TextChunk :=
            'A CLEANLY WRITTEN NOTE ON'#13 +
            'STANDARD PAPER FOUND ON THE'#13 +
            'BODY OF A DEAD TRADER.'#13 +
            #13 +
            'ALERAM,'#13 +
            #13 +
            '"HELLO MY GOOD FRIEND. I'#13 +
            'HOPE YOU AND YOUR BROOD ARE'#13 +
            'WELL. I AM TIRED; TIRED OF';
        1:
          TextChunk :=
            'TREKKING THROUGH'#13 +
            'UNSPEAKABLE SWAMPS AND OVER'#13 +
            'UNCLIMBABLE MOUNTAINS TO'#13 +
            'TAKE MY MEAGER WARES TO'#13 +
            'UNGRATEFUL CUSTOMERS.'#13 +
            #13 +
            '"ONLY ONE EVENT HAS SAVED'#13 +
            'THIS YEAR''S SALES. I FOUND'#13 +
            'A CASTLE FULL OF HAPPY FOLK';
        2:
          TextChunk :=
            'WHO WERE VERY GOOD'#13 +
            'CUSTOMERS. THEY WERE'#13 +
            'STARVED FOR GOODS AND NEWS'#13 +
            'FROM THE OUTSIDE WORLD. AND'#13 +
            'WELL THEY SHOULD BE, THEIR'#13 +
            'CASTLE WAS IN THE MIDDLE OF'#13 +
            'A SMALL FOREST, AND THE'#13 +
            'FOREST WAS IN THE MIDDLE OF'#13 +
            'A SWAMP!';
        3:
          TextChunk :=
            #13 +
            '"THESE PEOPLE SEEMED TO'#13 +
            'KNOW NOTHING OF RECENT'#13 +
            'EVENTS. THEY STILL SPOKE OF'#13 +
            'PHLAN AS IF IT WERE IN ITS'#13 +
            'FULL FLOWER. AND THEY PAID'#13 +
            'IN OLD PHLANIAN GOLD'#13 +
            'SOVEREIGNS, DOUBLE THE'#13 +
            'WEIGHT OF THE NEWER GOLD';
        4:
          TextChunk :=
            'COINS!'#13 +
            #13 +
            '"THOUGH THEY WERE OUT OF'#13 +
            'DATE, THEY WERE VERY'#13 +
            'FRIENDLY AND PROSPEROUS. I'#13 +
            'SAW MORE THAN ONE GEM'#13 +
            'GLITTER IN THE SUN, AND'#13 +
            'SEVERAL SWORDS SHOWED A'#13 +
            'FLASH THAT MADE ME THINK';
        5:
          TextChunk :=
            'THEY WERE MAGIC. IF YOU ARE'#13 +
            'WILLING TO DODGE THE VERMIN'#13 +
            'OF THE SWAMP I WOULD ADD'#13 +
            'THIS CASTLE TO YOUR TRADING'#13 +
            'ROUTE. SPEED TO YOUR HORSE,'#13 +
            'STRENGTH TO YOUR ARM, AND'#13 +
            'SKILL TO YOUR TRADING."'#13 +
            #13 +
            'YOUR FRIEND,';
        6:
          TextChunk :=
            'BURACH';
      end;
    { Entry 45 }
    63:
      case chunk of
        0:
          TextChunk :=
            'TOLD IN PERFECT, STYLIZED,'#13 +
            'COMMON.'#13 +
            #13 +
            '"GENERATIONS AGO, FLESH'#13 +
            'THINGS WERE FEWER AND WE'#13 +
            'HARD-SHELLED BEINGS RULED'#13 +
            'THE SHORES OF LAZARA, WHAT'#13 +
            'FLESH THINGS CALL THE'#13 +
            'MOONSEA. WE GATHERED MUCH';
        1:
          TextChunk :=
            'GOLD AND PLATINUM, PLUS'#13 +
            'MANY GEMS FOR DECORATION'#13 +
            'AND TO APPEASE OUR OWN'#13 +
            'GODS. WE ARE QUITE ADEPT AT'#13 +
            'FINDING SUCH TRINKETS AS WE'#13 +
            'MAKE OUR HOME BY BURROWING'#13 +
            'WITH OUR MANDIBLES. WE KNOW'#13 +
            'THE EARTH LIKE NONE OTHER'#13 +
            'CAN.';
        2:
          TextChunk :=
            #13 +
            '"WHEN FLESH THINGS BEGAN TO'#13 +
            'MULTIPLY, WE DID NOT LOOK'#13 +
            'ON THEM AS INTELLIGENT.'#13 +
            'THEY COULD NOT DECIPHER OUR'#13 +
            'GLORIOUS LANGUAGE OF SOUNDS'#13 +
            'AND MOVEMENT AND WE COULD'#13 +
            'NOT FATHOM INTELLIGENT'#13 +
            'COMMUNICATION LIMITED TO';
        3:
          TextChunk :=
            'THEIR FEEBLE SQUEAKS AND'#13 +
            'GRUNTS.'#13 +
            #13 +
            '"AS WE ASSUMED THE FLESH'#13 +
            'CREATURES WERE'#13 +
            'UNINTELLIGENT WE LOOKED ON'#13 +
            'THEM AS SLOW, SOFT, WEAK,'#13 +
            'BUT TASTY, PREY. BUT THE'#13 +
            'PREY SOON CAME RIDING SWIFT';
        4:
          TextChunk :=
            'BEASTS, AND SO WERE NO'#13 +
            'LONGER SLOW. THEN THEY CAME'#13 +
            'IN METAL SHELLS, AND SO'#13 +
            'WERE NO LONGER SOFT. AND'#13 +
            'THEN THEY CAME HURLING'#13 +
            'BALLS OF FIRE AND CLOUDS OF'#13 +
            'STINK, AND SO WERE NO'#13 +
            'LONGER WEAK. OUR GODS TOLD'#13 +
            'US THAT THE FLESH CREATURES';
        5:
          TextChunk :=
            'WOULD MULTIPLY AND THAT OUR'#13 +
            'ONLY HOPE WAS TO RETREAT.'#13 +
            #13 +
            '"WE RETREATED UNDERGROUND,'#13 +
            'INTO CAVERNS CARVED BY OUR'#13 +
            'OWN MANDIBLES. WE ONLY'#13 +
            'VENTURE TO THE SURFACE TO'#13 +
            'GUARD OUR LANDS AND TO FIND'#13 +
            'FOOD LESS POWERFUL THAN';
        6:
          TextChunk :=
            'YOURSELVES. WE HAVE KEPT'#13 +
            'THE LOCATION OF OUR NEST'#13 +
            'SECRET FOR MANY'#13 +
            'GENERATIONS.'#13 +
            #13 +
            '"BUT NOW YOU HAVE COME. YOU'#13 +
            'HAVE DEFEATED OUR WARRIORS,'#13 +
            'EVADED OUR TRAPS. WE ADMIT'#13 +
            'YOUR POWER. WE HAVE NOTHING';
        7:
          TextChunk :=
            'FURTHER TO GAIN BY COMBAT.'#13 +
            'IF YOU WILL LEAVE US IN'#13 +
            'PEACE YOU MAY TAKE THE GOLD'#13 +
            'AND GEMS THAT WERE SACRED'#13 +
            'TO OUR GODS, WE HAVE BEEN'#13 +
            'ABANDONED BY THEM. IF YOU'#13 +
            'WILL NOT LEAVE US IN PEACE'#13 +
            'THEN WE MUST FIGHT TO THE'#13 +
            'LAST. WHAT IS YOUR';
        8:
          TextChunk :=
            'DECISION?"';
      end;
    { Entry 46 }
    64:
      case chunk of
        0:
          TextChunk :=
            'TOLD AS JAUNTY, AFTER'#13 +
            'DINNER CONVERSATION.'#13 +
            #13 +
            '"THIS IS AN OLD STORY THAT'#13 +
            'I FIRST HEARD WHILE SERVING'#13 +
            'AT THE CITADEL OF THE'#13 +
            'RAVEN. DIRG WAS THE USUAL'#13 +
            'BARBARIAN HERO -- THE TYPE'#13 +
            'ABLE TO SNAP FIVE MEN''S';
        1:
          TextChunk :=
            'BACKS WITH HIS BARE HANDS,'#13 +
            'WRESTLE AND TAME THE CLOUD'#13 +
            'HORSES, PIERCE A MAN WITH A'#13 +
            'JAVELIN FROM MANY MILES'#13 +
            'AWAY, AND OTHER EQUALLY'#13 +
            'PREPOSTEROUS THINGS.'#13 +
            #13 +
            'THE STORY GOES THAT DIRG'#13 +
            'AND HIS BAND OF MEN FOUND A';
        2:
          TextChunk :=
            'POOL OF UNFROZEN WATER'#13 +
            'WHILE WANDERING IN THE'#13 +
            'SNOWY WASTES. DIRG''S LITTLE'#13 +
            'PET LIZARD JEZMA GOT TOO'#13 +
            'CLOSE TO THE POOL AND'#13 +
            'DISCOVERED THAT NOT ONLY'#13 +
            'WAS THE WATER NOT FROZEN,'#13 +
            'IT WAS BOILING HOT; SO HOT'#13 +
            'THAT IT COOKED THE SKIN';
        3:
          TextChunk :=
            'RIGHT OFF OF JEZMA.'#13 +
            #13 +
            '"DIRG WAS SO ANGERED HE'#13 +
            'THRUST HIS SPEAR INTO THE'#13 +
            'POOL AND ROILED THE WATERS.'#13 +
            'THE DEMON OF FIRE THAT'#13 +
            'INHABITED THE POOL WAS'#13 +
            'DISTURBED AND ROARED OUT OF'#13 +
            'THE POOL TO DO BATTLE. THE';
        4:
          TextChunk :=
            'DEMON LEAPT FROM MAN TO'#13 +
            'MAN, CONSUMING THEM IN A'#13 +
            'SINGLE TOUCH.'#13 +
            #13 +
            '"BUT THE DEMON OF FIRE'#13 +
            'COULD NOT DEFEAT DIRG.'#13 +
            'NEITHER COULD DIRG FIND A'#13 +
            'WEAPON STRONG ENOUGH TO'#13 +
            'WITHSTAND THE CREATURE''S';
        5:
          TextChunk :=
            'FIRE. AFTER BATTLING FOR AN'#13 +
            'ENTIRE DAY, DIRG FINALLY'#13 +
            'CALLED UPON HIS TOTEM GOD'#13 +
            'FOR AID. WITH THIS MAGICAL'#13 +
            'AID, DIRG WAS ABLE TO TRAP'#13 +
            'THE FLAMING DEMON IN A'#13 +
            'TRIANGLE OF POWER WHERE'#13 +
            'SUPPOSEDLY HE IS EVEN TO'#13 +
            'THIS DAY."';
      end;
    { Entry 47 }
    65:
      case chunk of
        0:
          TextChunk :=
            'A SMALL WRINKLED PARCHMENT'#13 +
            'WITH ROUGHLY SCRATCHED'#13 +
            'NOTES.'#13 +
            #13 +
            '"HOBGOBLINS TRANSFERRED OUT'#13 +
            'OF VALJEVO CASTLE. NOW'#13 +
            'REPLACED BY GIANTS AND'#13 +
            'TROLLS. SOUNDS VERY TOUGH.'#13 +
            '';
        1:
          TextChunk :=
            '"STOJANOW GATE GUARDED BY'#13 +
            'BUGBEARS AND ETTINS. HEARD'#13 +
            'ETTINS DIDN''T LIKE LIGHT.'#13 +
            'MUST BE CHARMED OR'#13 +
            'CONTROLLED. SOUNDS TOUGH!'#13 +
            #13 +
            '"SOME SMUGGLERS SNEAK'#13 +
            'SUPPLIES THROUGH STOJANOW'#13 +
            'GATE TO THE BOSS. MUST';
        2:
          TextChunk :=
            'CHECK IT OUT.'#13 +
            #13 +
            '"OVERHEARD HOBGOBLINS SAY A'#13 +
            'DRAGON SCARED THEM INTO'#13 +
            'LEAVING A NICE LAIR IN THE'#13 +
            'MOUNTAINS OUT EAST.'#13 +
            'COULDN''T HAPPEN TO A NICER'#13 +
            'BUNCH OF CREEPS."';
      end;
    { Entry 48 }
    66:
      case chunk of
        0:
          TextChunk :=
            'SEVERAL PIECES OF PAPER'#13 +
            'WITH HIGHLY ORGANIZED'#13 +
            'WRITING.'#13 +
            #13 +
            'STRONG RUMOR: THE BOSS IS A'#13 +
            'DRAGON OR IS A HUMAN WHO'#13 +
            'CAN TAKE THE FORM OF A'#13 +
            'DRAGON.'#13 +
            '';
        1:
          TextChunk :=
            'VAGUE RUMOR: THE BOSS IS A'#13 +
            'METALLIC DRAGON. NOT'#13 +
            'CONSIDERED LIKELY AS'#13 +
            'METALLIC DRAGONS ARE'#13 +
            '"GOOD".'#13 +
            #13 +
            'FACT: THE BOSS HOLDS'#13 +
            'AUDIENCES IN VALJEVO'#13 +
            'CASTLE. CASTLE IS GUARDED';
        2:
          TextChunk :=
            'BY GROUPS OF BIG STUPID'#13 +
            'MONSTERS, WITH OCCASIONAL'#13 +
            'SMART HUMAN LEADERS.'#13 +
            #13 +
            'RUMOR: THE BOSS DOESN''T'#13 +
            'SPEND FULL TIME AT VALJEVO'#13 +
            'CASTLE.'#13 +
            #13 +
            'FACT: MAZE INSIDE CASTLE';
        3:
          TextChunk :=
            'WALL; PASSWORDS ARE NEEDED'#13 +
            'TO GET PAST CASTLE GATES.'#13 +
            #13 +
            'RUMOR: THE BOSS HAS BEEN'#13 +
            'SENDING OUT MESSENGERS TO'#13 +
            'THE TRIBES OF MONSTERS IN'#13 +
            'THE AREA TO RECRUIT NEW'#13 +
            'UNITS.'#13 +
            '';
        4:
          TextChunk :=
            'VAGUE RUMOR: THE BOSS IS'#13 +
            'RECRUITING NEW UNITS IN'#13 +
            'PREPARATION FOR AN ASSAULT'#13 +
            'TO RETAKE THE CIVILIZED'#13 +
            'SECTIONS OF PHLAN.';
      end;
    { Entry 49 }
    67:
      case chunk of
        0:
          TextChunk :=
            'A LETTER ON CLEAN WHITE'#13 +
            'PAPER IN A STRONG HAND'#13 +
            #13 +
            'TO:'#13 +
            'THE BOSS'#13 +
            'VALJEVO CASTLE, PHLAN'#13 +
            #13 +
            'SIR,'#13 +
            '';
        1:
          TextChunk :=
            '"I CATEGORICALLY REJECT'#13 +
            'YOUR DEMAND THAT I SUBMIT'#13 +
            'MY ISLAND AND MY POWERS TO'#13 +
            'YOUR CONTROL. I AM A FREE'#13 +
            'MAN AND I WILL REMAIN FREE.'#13 +
            'NO PETTY TYRANT CAN ORDER'#13 +
            'ABOUT A TRUE MAGE.'#13 +
            #13 +
            '"IF YOU OR YOUR TROOPS MAKE';
        2:
          TextChunk :=
            'ANY MOVE TOWARD SORCERER''S'#13 +
            'ISLAND I SHALL SEND AN ARMY'#13 +
            'OF MY UNSTOPPABLE AQUATIC'#13 +
            'CREATIONS DOWN THE BARREN'#13 +
            'RIVER AND SINK YOUR'#13 +
            'PRECIOUS CASTLE. UNTIL NOW'#13 +
            'YOU HAVE BEEN BENEATH MY'#13 +
            'NOTICE. IF YOU VALUE YOUR'#13 +
            'EMPIRE, LET US KEEP IT THAT';
        3:
          TextChunk :=
            'WAY."'#13 +
            #13 +
            'SIGNED'#13 +
            'YARASH, THE SORCERER';
      end;
  end;
end;

end.

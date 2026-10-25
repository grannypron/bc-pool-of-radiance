{ Random items: what EclVm's treasure opcode makes from an item kind. Overlaid, and its own unit so treasure loads it
  without Money. }
{$O+,F+}
{$I COMPILER.INC}
unit RandItem;

interface

uses Types;

const
  { the last of randomItemTemplates, 1..TEMPLATE_LAST }
  TEMPLATE_LAST = 19;
  { Random item templates }
  randomItemTemplates: array[1..TEMPLATE_LAST] of Types.TRandomItemTemplate = (
    { Template 1: Potion of Extra Healing }
    (nameIds: (187, 167, 64); weight: 1; value: 800;
     properties: (3, 3, 0)),
    { Template 2: Potion of Giant Strength }
    (nameIds: (239, 167, 64); weight: 1; value: 1100;
     properties: (1, 82, 0)),
    { Template 3: Potion of Healing }
    (nameIds: (185, 167, 64); weight: 1; value: 400;
     properties: (1, 85, 0)),
    { Template 4: Potion of Speed }
    (nameIds: (173, 167, 64); weight: 1; value: 450;
     properties: (1, 80, 0)),
    { Template 5: Scroll of Restoring Levels }
    (nameIds: (240, 167, 65); weight: 1; value: 2100;
     properties: (56, 56, 0)),
    { Template 6: Ring of Feather Falling }
    (nameIds: (238, 167, 66); weight: 1; value: 5000;
     properties: (0, 27, 128)),
    { Template 7: Wand of Lightning }
    (nameIds: (157, 167, 69); weight: 1; value: 6000;
     properties: (20, 51, 0)),
    { Template 8: Wand of Magic Missiles }
    (nameIds: (206, 167, 69); weight: 1; value: 11000;
     properties: (30, 88, 0)),
    { Template 9: Wand of Paralyzation }
    (nameIds: (225, 167, 69); weight: 1; value: 5000;
     properties: (20, 84, 0)),
    { Template 10: Gauntlets of Ogre Power }
    (nameIds: (226, 167, 100); weight: 10; value: 15000;
     properties: (0, 38, 131)),
    { Template 11: Keoghtum's Ointment }
    (nameIds: (0, 111, 182); weight: 1; value: 10000;
     properties: (5, 81, 0)),
    { Template 12: Necklace of Missiles }
    (nameIds: (228, 167, 119); weight: 1; value: 16000;
     properties: (20, 87, 0)),
    { Template 13: Cloak of Displacement }
    (nameIds: (170, 167, 88); weight: 25; value: 17500;
     properties: (0, 89, 133)),
    { Template 14: Javelin of Lightning }
    (nameIds: (157, 167, 21); weight: 20; value: 3000;
     properties: (1, 83, 0)),
    { Template 15: Wand of Fireballs }
    (nameIds: (242, 167, 69); weight: 1; value: 5000;
     properties: (20, 47, 0)),
    { Template 16: Ring of Fire Resistance }
    (nameIds: (205, 167, 66); weight: 1; value: 5000;
     properties: (0, 61, 129)),
    { Template 17: Ring of Invisibility }
    (nameIds: (227, 167, 66); weight: 1; value: 7500;
     properties: (0, 56, 139)),
    { Template 18: Bag of Holding }
    (nameIds: (186, 167, 73); weight: 150; value: 25000;
     properties: (0, 0, 0)),
    { Template 19: Cloak of Elvenkind }
    (nameIds: (229, 167, 88); weight: 25; value: 6000;
     properties: (0, 72, 134)));

procedure GenerateRandomItem(kind: Byte; item: Types.PItemRec);

{ Make item the magic item of randomItemTemplates[template]: its name parts, weight, value and properties, plus
  1 (the Cloak of Displacement's 2). }
procedure ApplyTemplate(item: Types.PItemRec; template: Byte);

implementation

uses C_ITEM, Dice;

{ Roll the magical plus for a random weapon or armor on a d20: 1 (70%), 2 (25%) or 3 (5%). }
function RandomBonus: ShortInt;
var
  r: Byte;
begin
  r := Dice.RollDice(1, 20);
  case r of
    1..14: RandomBonus := 1;
    15..19: RandomBonus := 2;
    else RandomBonus := 3;
  end;
end;

procedure ApplyTemplate(item: Types.PItemRec; template: Byte);
var
  tpl: Types.TRandomItemTemplate;
  j: Byte;
begin
  tpl := randomItemTemplates[template];
  with item^ do begin
    for j := 1 to 3 do
      nameIds[j] := Lo(tpl.nameIds[j]);
    plus := 1;
    saveBonus := 1;
    { the Cloak of Displacement is +2 }
    if template = 13 then begin
      plus := 2;
      saveBonus := 2;
    end;
    weight := tpl.weight;
    quantity := 0;
    value := tpl.value;
    for j := 1 to 3 do
      spells[j] := Lo(tpl.properties[j]);
  end;
end;

{ Build a random item of the given kind. Kinds 1..59, 73, 77 and 93 are weapons and armor, named from their type with a
  plus from RandomBonus and given a weight and value by type. 61 and 62 are magic-user and clerical scrolls holding 1d3
  rolled spells in the spells field. 63, 67, 69..71, 78, 79, 84 and 92 pick one of randomItemTemplates, as does
  a javelin one time in five. Any other kind gets only itemType and the defaults. }
procedure GenerateRandomItem(kind: Byte; item: Types.PItemRec);
var
  r: Byte;
  n: Byte;
  j: Byte;
  template: Byte;
  spell: Byte;
begin
  { clear the whole item record }
  FillChar(item^, SizeOf(Types.TItemRec), 0);
  template := 0;
  with item^ do begin
    unidMask := 6;
    itemType := kind;
    case itemType of
      { C_ITEM.RANDOM_ARMS_KINDS }
      1..59, C_ITEM.ARROW, C_ITEM.BRACERS, C_ITEM.RANDOM_ARMS_LAST: begin
          plus := RandItem.RandomBonus;
          case itemType of
            { one time in five a Javelin of Lightning (template 14); SSI's word index 144 straddled templates 18 and 19,
              making an item named from neither (POR-0165) }
            C_ITEM.JAVELIN: begin
                   r := Dice.RollDice(1, 5);
                   if r = 5 then
                     template := 14;
                   nameIds[3] := 21;
                   nameIds[2] := plus + C_ITEM.NAME_PLUS_BASE;
                 end;
            C_ITEM.QUARREL: begin
                   nameIds[3] := 28;
                   nameIds[2] := plus + C_ITEM.NAME_PLUS_BASE;
                 end;
            50, 51: begin
                   nameIds[3] := itemType;
                   nameIds[2] := 49;
                   nameIds[1] := plus + C_ITEM.NAME_PLUS_BASE;
                   unidMask := 4;
                 end;
            52: begin
                   nameIds[3] := itemType;
                   nameIds[2] := 50;
                   nameIds[1] := plus + C_ITEM.NAME_PLUS_BASE;
                   unidMask := 4;
                 end;
            53..58: begin
                   nameIds[3] := itemType;
                   nameIds[2] := 48;
                   nameIds[1] := plus + C_ITEM.NAME_PLUS_BASE;
                   unidMask := 4;
                 end;
            C_ITEM.ARROW: begin
                   nameIds[3] := 61;
                   nameIds[2] := plus + C_ITEM.NAME_PLUS_BASE;
                 end;
            { bracers: plus 1..3 becomes 4/6/8, named AC 6/4/2 }
            C_ITEM.BRACERS: begin
                   nameIds[3] := 79;
                   nameIds[2] := C_ITEM.NAME_OF;
                   plus := plus * 2 + 2;
                   case plus of
                     4: nameIds[1] := C_ITEM.NAME_AC_6;
                     6: nameIds[1] := C_ITEM.NAME_AC_4;
                     8: nameIds[1] := C_ITEM.NAME_AC_2;
                   end;
                 end;
            C_ITEM.RANDOM_ARMS_LAST: begin
                   nameIds[3] := 66;
                   nameIds[2] := 224;
                   nameIds[1] := plus + C_ITEM.NAME_PLUS_BASE;
                 end;
            else begin
                   nameIds[3] := itemType;
                   nameIds[2] := plus + C_ITEM.NAME_PLUS_BASE;
                 end;
          end;
          saveBonus := 0;
          quantity := 0;
          { weight in coins }
          case itemType of
            1, 13, 14, 35:
              weight := 75;
            2, 20, 29, 31, 32, 33, 39, 42, 44, 46, 59:
              weight := 50;
            3, 24, 40:
              weight := 125;
            4, 15, 23, 34, 43, 45, 51:
              weight := 100;
            5, 12, 17, 19, 50:
              weight := 150;
            6: weight := 15;
            7: weight := 30;
            C_ITEM.DAGGER, C_ITEM.BRACERS:
              weight := 10;
            { ammunition: weight is per piece, as in every placed stack }
            C_ITEM.DART: begin
                 weight := 5;
                 quantity := 5;
               end;
            C_ITEM.QUARREL: begin
                  weight := 3;
                  quantity := 10;
                end;
            C_ITEM.ARROW: begin
                  weight := 4;
                  quantity := 10;
                end;
            10, 26, 36:
              weight := 60;
            11, 16, 25, 27, 41, 47:
              weight := 80;
            18: weight := 175;
            C_ITEM.JAVELIN: weight := 20;
            22, 30:
              weight := 40;
            37: weight := 35;
            38, 53:
              weight := 250;
            52: weight := 200;
            54, 56:
              weight := 400;
            55: weight := 300;
            57: weight := 350;
            58: weight := 450;
            { SSI's arm read 47, 93; 47 is matched above, and Free Pascal rejects a label used twice }
            C_ITEM.RANDOM_ARMS_LAST:
              weight := 1;
            else begin
                   weight := 40;
                   quantity := 10;
                 end;
          end;
          { value in gp = plus * K }
          case itemType of
            59: value := Word(plus) * 2500;
            { per bundle of 20 (ItemBundle) }
            C_ITEM.DART, C_ITEM.QUARREL, C_ITEM.ARROW: value := Word(plus) * 150;
            53, 54: value := Word(plus) * 3000;
            55, 56: value := Word(plus) * 3500;
            57: value := Word(plus) * 4000;
            58: value := Word(plus) * 5000;
            C_ITEM.BRACERS: value := Word(plus) * 3000;
            else value := Word(plus) * 2000;
          end;
        end;
      { scrolls }
      C_ITEM.MAGE_SCROLL, C_ITEM.CLERIC_SCROLL: begin
          n := Dice.RollDice(1, 3);
          if itemType = C_ITEM.MAGE_SCROLL then
            nameIds[3] := 209
          else
            nameIds[3] := 208;
          nameIds[2] := n + 209;
          nameIds[1] := 0;
          plus := 1;
          weight := 25;
          quantity := 0;
          value := 0;
          for j := 1 to n do begin
            r := Dice.RollDice(1, 3);
            if itemType = C_ITEM.MAGE_SCROLL then
              { magic-user spell ids: 9..21, 29..35, 45..55 }
              case r of
                1: spell := Dice.RollDice(1, 13) + 8;
                2: spell := Dice.RollDice(1, 7) + 28;
                3: spell := Dice.RollDice(1, 11) + 44;
              end else
              { clerical spell ids: 1..8, 22..28, 36..44 }
              case r of
                1: spell := Dice.RollDice(1, 8);
                2: spell := Dice.RollDice(1, 7) + 21;
                3: spell := Dice.RollDice(1, 9) + 35;
              end;
            spells[j] := spell;
            value := Word(r) * 300 + value;
          end;
        end;
      63: template := 10;
      67: template := 19;
      69: begin
             r := Dice.RollDice(1, 10);
             case r of
               1: template := 6;
               2..6: template := 16;
               7..10: template := 17;
             end;
           end;
      78: begin
             { one in three each; SSI's roll of 1d3 + 1 never made template 7 and made nothing on a 4 (#817) }
             r := Dice.RollDice(1, 3);
             case r of
               1: template := 7;
               2: template := 9;
               3: template := 15;
             end;
           end;
      79: template := 8;
      84: template := 2;
      92: template := 13;
      71: begin
             { 1d10; SSI's 1d11 made, on an 11, an item with no template: nameless, and nothing to drink (POR-0225) }
             r := Dice.RollDice(1, 10);
             case r of
               1..5: template := 3;
               6..8: template := 1;
               9: template := 4;
               10: template := 11;
             end;
           end;
      70: begin
             r := Dice.RollDice(1, 10);
             case r of
               1..7: template := 12;
               8..10: template := 18;
             end;
           end;
    end;
  end;
  if template <> 0 then
    RandItem.ApplyTemplate(item, template);
end;

end.

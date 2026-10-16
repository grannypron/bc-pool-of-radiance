{ Random items: what EclVm's treasure opcode makes from an item kind. Overlaid, and its own unit so treasure loads it
  without Money. }
{$O+,F+}
unit RandItem;

interface

uses Types;

procedure GenerateRandomItem(kind: Byte; item: Types.PItemRec);

implementation

uses GDConsts, FxEngine;

{ Roll the magical plus for a random weapon or armor on a d20: 1 (70%), 2 (25%) or 3 (5%). }
function RandomBonus: ShortInt;
var
  r: Byte;
begin
  r := FxEngine.RollDice(1, 20);
  case r of
    1..14: RandomBonus := 1;
    15..19: RandomBonus := 2;
    else RandomBonus := 3;
  end;
end;

{ Build a random item of the given kind. Kinds 1..59, 73, 77 and 93 are weapons and armor, named from their type with a
  plus from RandomBonus and given a weight and value by type. 61 and 62 are magic-user and clerical scrolls holding 1d3
  rolled spells in the spells field. 63, 67, 69..71, 78, 79, 84 and 92 pick one of GDConsts.randomItemTemplates, as
  does a javelin one time in five. Any other kind gets only itemType and the defaults. }
procedure GenerateRandomItem(kind: Byte; item: Types.PItemRec);
var
  r: Byte;
  n: Byte;
  j: Byte;
  template: Byte;
  tpl: Types.TRandomItemTemplate;
  spell: Byte;
begin
  { clear the whole item record }
  FillChar(item^, SizeOf(Types.TItemRec), 0);
  template := 0;
  with item^ do begin
    FillChar(spells, SizeOf(spells), 0);
    next := nil;
    equipped := 0;
    unidMask := 6;
    cursed := 0;
    itemType := kind;
    FillChar(nameIds, SizeOf(nameIds), 0);
    case itemType of
      1..59, 73, 77, 93: begin
          plus := RandItem.RandomBonus;
          case itemType of
            { one time in five a Javelin of Lightning (template 14); SSI's word index 144 straddled templates 18
              and 19, making an item named from neither (POR-0165) }
            21: begin
                   r := FxEngine.RollDice(1, 5);
                   if r = 5 then
                     template := 14;
                   nameIds[3] := 21;
                   nameIds[2] := plus + 161;
                 end;
            28: begin
                   nameIds[3] := 28;
                   nameIds[2] := plus + 161;
                 end;
            50, 51: begin
                   nameIds[3] := itemType;
                   nameIds[2] := 49;
                   nameIds[1] := plus + 161;
                   unidMask := 4;
                 end;
            52: begin
                   nameIds[3] := itemType;
                   nameIds[2] := 50;
                   nameIds[1] := plus + 161;
                   unidMask := 4;
                 end;
            53..58: begin
                   nameIds[3] := itemType;
                   nameIds[2] := 48;
                   nameIds[1] := plus + 161;
                   unidMask := 4;
                 end;
            73: begin
                   nameIds[3] := 61;
                   nameIds[2] := plus + 161;
                 end;
            { bracers: plus 1..3 becomes 4/6/8, named AC 6/4/2 }
            77: begin
                   nameIds[3] := 79;
                   nameIds[2] := 167;
                   plus := plus * 2 + 2;
                   case plus of
                     4: nameIds[1] := 221;
                     6: nameIds[1] := 222;
                     8: nameIds[1] := 220;
                   end;
                 end;
            93: begin
                   nameIds[3] := 66;
                   nameIds[2] := 224;
                   nameIds[1] := plus + 161;
                 end;
            else begin
                   nameIds[3] := itemType;
                   nameIds[2] := plus + 161;
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
            8, 77:
              weight := 10;
            { ammunition: weight is per piece, as in every placed stack }
            9: begin
                 weight := 5;
                 quantity := 5;
               end;
            28: begin
                  weight := 3;
                  quantity := 10;
                end;
            73: begin
                  weight := 4;
                  quantity := 10;
                end;
            10, 26, 36:
              weight := 60;
            11, 16, 25, 27, 41, 47:
              weight := 80;
            18: weight := 175;
            21: weight := 20;
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
            { Only 93 reaches this arm; 47 is matched above }
            47, 93:
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
            9, 28, 73: value := Word(plus) * 150;
            53, 54: value := Word(plus) * 3000;
            55, 56: value := Word(plus) * 3500;
            57: value := Word(plus) * 4000;
            58: value := Word(plus) * 5000;
            77: value := Word(plus) * 3000;
            else value := Word(plus) * 2000;
          end;
        end;
      { scrolls }
      61, 62: begin
          n := FxEngine.RollDice(1, 3);
          if itemType = 61 then
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
            r := FxEngine.RollDice(1, 3);
            if itemType = 61 then
              { magic-user spell ids: 9..21, 29..35, 45..55 }
              case r of
                1: spell := FxEngine.RollDice(1, 13) + 8;
                2: spell := FxEngine.RollDice(1, 7) + 28;
                3: spell := FxEngine.RollDice(1, 11) + 44;
              end else
              { clerical spell ids: 1..8, 22..28, 36..44 }
              case r of
                1: spell := FxEngine.RollDice(1, 8);
                2: spell := FxEngine.RollDice(1, 7) + 21;
                3: spell := FxEngine.RollDice(1, 9) + 35;
              end;
            spells[j] := spell;
            value := Word(r) * 300 + value;
          end;
        end;
      63: template := 10;
      67: template := 19;
      69: begin
             r := FxEngine.RollDice(1, 10);
             case r of
               1: template := 6;
               2..6: template := 16;
               7..10: template := 17;
             end;
           end;
      78: begin
             { r is 2..4 vs labels 1..3: 49 is never chosen and r = 4 leaves no template }
             r := FxEngine.RollDice(1, 3) + 1;
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
             { 11 makes nothing }
             r := FxEngine.RollDice(1, 11);
             case r of
               1..5: template := 3;
               6..8: template := 1;
               9: template := 4;
               10: template := 11;
             end;
           end;
      70: begin
             r := FxEngine.RollDice(1, 10);
             case r of
               1..7: template := 12;
               8..10: template := 18;
             end;
           end;
    end;
    if template <> 0 then begin
      tpl := GDConsts.randomItemTemplates[template];
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
end;

end.

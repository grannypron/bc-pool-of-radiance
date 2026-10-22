{ The vault's menu, its own unit so Vault, which ViewChar's Deposit uses, need not use ViewChar. }
{$O+,F+}
{$I COMPILER.INC}
unit VaultMnu;

interface

uses Types;

{ The vault's menu, entered from the New Phlan script (C_Gbvm.ENTER_SHOP set to 2, then a COMBAT with no monsters): the
  merchant's greeting, then View (where Drop deposits), Take (money and items, while there are any), Pool, Share (while
  there is money) and Exit. Its money and items are the treasure pool, read from the session vault on entry and written
  back on Exit. A vault that could not be written keeps them, here to take back, unless the party leaves anyway (the
  session vault is then as it was on entry). }
procedure VaultMenu;

implementation

uses Crt, GDVars, C_Ifc, C_Keys, CharDisp, CharHlp, MenuCore, Money, Party, PostCbt, TextRend, Vault, ViewChar
  {$IFDEF FPC}, TpRand{$ENDIF};

procedure VaultMenu;
var
  menu: Types.TStr40;
  c: Char;
  ext: Boolean;
  hasMoney: Boolean;
  hasItems: Boolean;
  done: Boolean;
begin
  GDVars.ifcState := C_Ifc.VAULT;
  CharDisp.DisplayNoncombatInterface;
  CharDisp.DisplayParty(GDVars.curChar);
  Vault.ReadVault;
  if Vault.WasVisited and (Random(20) = 0) then
    TextRend.ShowMessage(LightGreen, True, 'OH, YOU''RE ALIVE... I MEAN  WELCOME BACK!')
  else
    TextRend.ShowMessage(LightGreen, True, 'WELCOME TO THE HOARDER''S RESPITE. LET ME LIGHTEN YOUR LOAD.');
  done := False;
  repeat
    Money.DetermineTreasure(hasMoney, hasItems);
    menu := 'View';
    if hasMoney or hasItems then
      menu := menu + ' Take';
    menu := menu + ' Pool';
    if hasMoney then
      menu := menu + ' Share';
    menu := menu + ' Exit';
    c := MenuCore.MenuHorizontal('', menu, LightMagenta, LightGreen, White, True, False, ext);
    if ext then begin
      if (c = C_Keys.HOME) or (c = C_Keys.END_KEY) then
        Party.SelectPrevNextChar(c);
    end else
      case c of
        'V': ViewChar.ViewCharMenu(ext);
        'T': if hasMoney or hasItems then begin
               PostCbt.LootTakeMenu(hasMoney, hasItems);
               CharDisp.DisplayNoncombatInterface;
             end;
        'P': Money.PoolMoney;
        'S': if hasMoney then
               Money.ShareMoney;
        'E', C_Keys.NONE:
          done := Vault.WriteVault or
                  (MenuCore.YesNoMenu('Leave anyway? ', Yellow, LightGreen, White) = 'Y');
      end;
    CharDisp.DisplayParty(GDVars.curChar);
  until done;
  CharHlp.ClearTreasure;
end;

end.

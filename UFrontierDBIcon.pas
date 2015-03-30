// ###################################################################################
// #                                                                                 #
// #   Hook na metodê TCustomForm.DoCreate na poziomie ca³ej aplikacji zmieniaj¹cy   #
// #   ikonê aplikacji w zale¿noœci od nazwy bazy danych                             #
// #   (pobranej z okna klasy Tdoa_fmMainForm)                                       #
// #                                                                                 #
// #   UWAGA!  Formatka klasy Tdoa_MainForm musi byæ stworzona jako pierwsza !       #
// #   UWAGA!  Mo¿e siê okazaæ, ¿e gdy ktoœ w dalekiej przysz³oœci spróbuje          #
// #           skompilowaæ ten kod, dostanie AV. BEWARE!                             #
// #   UWAGA!  By podmiana ikon dzia³a³a, nale¿y dodaæ plik z rozszerzeniem RC       #
// #           do projektu                                                           #
// #                                                                                 #
// ###################################################################################

unit UFrontierDBIcon;   // #PCz# 2015-01-21   Z-13327

interface

uses
  Windows, Classes, SysUtils,
  Forms;          // TCustomForm
  
implementation

uses
  doa_MainForm;   // Tdoa_fmMainForm

type
  THookedForm = class(TCustomForm)
    procedure DoCreateWrapper;
  end;

  PPatchEvent = ^TPatchEvent;
  TPatchEvent = packed record   // ASM opcode hack
    Jump: byte;
    Offset: integer;
  end;

  TDBIconAssignment = record
    DBName, IconName: string;
  end;

var
  PatchEvent, OriginalEvent: TPatchEvent;
  PatchPositionEvent: PPatchEvent = nil;

const
  DATABASE_ICONS_ASSIGNMENT: array [0..3] of TDBIconAssignment = ( (DBName: 'EHMMS'; IconName: 'ICO_ESOTIQ'),
                                                                   (DBName: 'EHSMT'; IconName: 'ICO_ESOTIQ'),
                                                                   (DBName: 'FMMS';  IconName: 'ICO_FEMESTAGE'),
                                                                   (DBName: 'FSMT';  IconName: 'ICO_FEMESTAGE') );

procedure HookDoCreate;
var
  ov: Cardinal;
begin
  PatchPositionEvent := PPatchEvent(@THookedForm.DoCreate);
  OriginalEvent := PatchPositionEvent^;
  PatchEvent.Jump := $E9;   // ASM JMP opcode
  PatchEvent.Offset := PChar(@THookedForm.DoCreateWrapper) - PChar(PatchPositionEvent) - 5;
  if not VirtualProtect(PatchPositionEvent, 5, PAGE_EXECUTE_READWRITE, @ov) then
    RaiseLastWin32Error;
  PatchPositionEvent^ := PatchEvent;   // wpiêcie hooka
end;

procedure THookedForm.DoCreateWrapper;
var
  LC: Integer;
  RS: TResourceStream;
begin
  PatchPositionEvent^ := OriginalEvent;
  try
    DoCreate;   // chain do oryginalnego DoCreate, gdzie jest okienko logowania do bazy
  finally
    PatchPositionEvent^ := PatchEvent;
  end;

  if InheritsFrom(Tdoa_fmMainForm) then   // wyci¹ganie nazwy bazy
  begin

    with Tdoa_fmMainForm(Self) do
      if Assigned(MZ_Datamodule) then
        if not MZ_Datamodule.terminating and Assigned(MZ_Datamodule.DefaultSession) then
        begin
          for LC := 0 to High(DATABASE_ICONS_ASSIGNMENT) do
            if Uppercase(DATABASE_ICONS_ASSIGNMENT[LC].DBName) = Uppercase(MZ_Datamodule.DefaultSession.LogonDatabase) then
            begin
              try
                RS := TResourceStream.Create(HInstance, DATABASE_ICONS_ASSIGNMENT[LC].IconName, RT_RCDATA);
                Application.Icon.LoadFromStream(RS);
              finally
                if Assigned(RS) then
                  RS.Free;
              end;
              Break;
            end;
        end;
        
  end;   // if InheritsFrom(Tdoa_fmMainForm) then
end;

initialization
  HookDoCreate;

end.


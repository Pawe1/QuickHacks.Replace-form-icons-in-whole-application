// ###################################################################################
// #                                                                                 #
// #   Hook na metodê TCustomForm.DoCreate na poziomie ca³ej aplikacji koloruj¹cy    #
// #   - w zale¿noœci od nazwy bazy danych (pobranej z okna klasy Tdoa_fmMainForm)   #
// #            wszystkie okna i kontrolki dziedzicz¹ce po klasie TPanel             #
// #                                                                                 #
// #   UWAGA!  Formatka klasy Tdoa_MainForm musi byæ stworzona jako pierwsza !       #
// #   UWAGA!  Mo¿e siê okazaæ, ¿e gdy ktoœ w dalekiej przysz³oœci spróbuje          #
// #           skompilowaæ ten kod pod x64, dostanie cudowne AV. BEWARE!             #
// #   UWAGA!  By podmiana ikon dzia³a³a, nale¿y dodaæ plik z rozszerzeniem RC       #
// #           do projektu                                                           #
// #                                                                                 #
// ###################################################################################

unit ColorHook;   // #PCz# 2015-01-21   Z-13327

interface

uses
  Windows, Classes, SysUtils,
  Forms,          // TCustomForm
  Controls,       // TControl
  ExtCtrls,       // TPanel
  Graphics;       // TColor

implementation

uses
  doa_MainForm;   // Tdoa_fmMainForm

type
  THookedForm = class(TCustomForm)
    procedure HookedDoCreate;
  end;

  PPatchEvent = ^TPatchEvent;
  // asm opcode hack to patch an existing routine
  TPatchEvent = packed record
    Jump: byte;
    Offset: integer;
  end;

  TDatabaseColorTheme = record
    Database: string;
    Color: TColor;
  end;
  TDatabaseColorThemes = array of TDatabaseColorTheme;

var
  PatchForm, OriginalForm: TPatchEvent;
  PatchPositionForm: PPatchEvent = nil;
  CurrentColor: TColor;

const
  DATABASE_COLOR_THEMES: array [0..1] of TDatabaseColorTheme = ( (Database: 'EHMMS'; Color: $00BABAE2),
                                                                 (Database: 'FMMS';  Color: $00BFE0BC) );

procedure MakeItFlippinFabulous(const AControl: TControl; const AColor: TColor);
var
  i : Integer;
begin
  if AControl = nil then
    Exit;
  if AControl is TWinControl then
  begin
    if TWinControl(AControl).ControlCount > 0 then
      for i := 0 to TWinControl(AControl).ControlCount-1 do
        MakeItFlippinFabulous(TWinControl(AControl).Controls[i], AColor);
  end;

  if AControl.InheritsFrom(TPanel) then
    TPanel(AControl).Color := AColor;
end;

procedure PatchCreate;
var
  ov: cardinal;
begin
  PatchPositionForm := PPatchEvent(@THookedForm.DoCreate);
  OriginalForm := PatchPositionForm^;
  PatchForm.Jump := $E9; // Jmp opcode
  PatchForm.Offset := PChar(@THookedForm.HookedDoCreate) - PChar(PatchPositionForm) - 5;
  if not VirtualProtect(PatchPositionForm, 5, PAGE_EXECUTE_READWRITE, @ov) then
    RaiseLastWin32Error;
  PatchPositionForm^ := PatchForm; // enable Hook
end;

procedure THookedForm.HookedDoCreate;
var
  LC: Integer;
  RS: TResourceStream;
begin
     // do what you want before original DoCreate
  PatchPositionForm^ := OriginalForm;
  try
    DoCreate;
  finally
    PatchPositionForm^ := PatchForm;
  end;
     // do what you want after original DoCreate

  if InheritsFrom(Tdoa_fmMainForm) then   // wyci¹ganie nazwy bazy
  begin
    with Tdoa_fmMainForm(Self) do
      if Assigned(MZ_Datamodule) then
        if not MZ_Datamodule.terminating and Assigned(MZ_Datamodule.DefaultSession) then
        begin
          for LC := 0 to High(DATABASE_COLOR_THEMES) do
            if Uppercase(DATABASE_COLOR_THEMES[LC].Database) = Uppercase(MZ_Datamodule.DefaultSession.LogonDatabase) then
            begin
              CurrentColor := DATABASE_COLOR_THEMES[LC].Color;
              try
                RS := TResourceStream.Create(HInstance, 'ICO_' + DATABASE_COLOR_THEMES[LC].Database, RT_RCDATA);
                Application.Icon.LoadFromStream(RS);
              finally
                if Assigned(RS) then
                  RS.Free;
              end;
              Break;
            end;
        end;
  end;   // if InheritsFrom(Tdoa_fmMainForm) then

  if InheritsFrom(TCustomForm) then
  begin
    Color := CurrentColor;
    MakeItFlippinFabulous(Self, Color);
  end;
end;

initialization
  CurrentColor := clBtnFace;
  PatchCreate;

end.

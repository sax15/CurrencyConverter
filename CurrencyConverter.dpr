program CurrencyConverter;

uses
  System.StartUpCopy,
  FMX.Forms,
  FMX.Skia,
  uMain in 'uMain.pas' {frmCurrencyConverter};

{$R *.res}

begin
  GlobalUseSkia := True;
  Application.Initialize;
  Application.CreateForm(TfrmCurrencyConverter, frmCurrencyConverter);
  Application.Run;
end.

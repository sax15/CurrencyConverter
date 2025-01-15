unit uMain;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.ListBox,
  FMX.StdCtrls, FMX.Layouts, FMX.Controls.Presentation, FMX.Edit,
  Xml.XMLDoc, Xml.XMLIntf, System.Generics.Collections, FMX.Memo.Types,
  FMX.ScrollBox, FMX.Memo,
  FMX.VirtualKeyboard, FMX.Platform,
  FMX.Objects, System.IOUtils, IniFiles;

type
  TfrmCurrencyConverter = class(TForm)
    layApp: TLayout;
    edtAmount: TEdit;
    layButton: TLayout;
    labTitle: TLabel;
    labInfo: TLabel;
    Label1: TLabel;
    GridPanelLayout1: TGridPanelLayout;
    Label2: TLabel;
    btnConvert: TButton;
    Label4: TLabel;
    labValue: TLabel;
    cobFromCurrency: TComboBox;
    Label3: TLabel;
    Label5: TLabel;
    btnChangeCurrency: TButton;
    cobToCurrency: TComboBox;
    imgLogo: TImage;
    procedure btnConvertClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure btnChangeCurrencyClick(Sender: TObject);
    procedure edtAmountKeyDown(Sender: TObject; var Key: Word;
      var KeyChar: WideChar; Shift: TShiftState);
  private
    { Private declarations }
    currency: TDictionary<string, Double>;
    procedure DownloadXML();
    procedure ParseXML(XMLDoc: IXMLDocument);
    procedure Convert();
    function ConvertDate(datum: string): string;
    procedure LoadIni();
    procedure SaveIni();
  public
    { Public declarations }
  end;

var
  frmCurrencyConverter: TfrmCurrencyConverter;
const
  exchange_rates_page = 'https://www.bsi.si/_data/tecajnice/dtecbs.xml';

implementation

{$R *.fmx}
uses System.Net.HttpClientComponent, System.JSON, System.Net.HttpClient;


procedure TfrmCurrencyConverter.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  currency.Free;
  SaveIni()
end;

procedure TfrmCurrencyConverter.FormCreate(Sender: TObject);
begin
  currency := TDictionary<string, Double>.Create;
  DownloadXML();
  LoadIni();
  edtAmount.SetFocus;
end;

procedure TfrmCurrencyConverter.LoadIni();
var
  iniFile: TIniFile;
begin
  iniFile := TIniFile.Create(System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetDocumentsPath, 'System.ini'));
  try
    cobFromCurrency.ItemIndex := IniFile.ReadInteger('Settings', 'From Currency', 0);
    cobToCurrency.ItemIndex := iniFile.ReadInteger('Settings', 'To Currency', 1);
  finally
    IniFile.Free;
  end;
end;

procedure TfrmCurrencyConverter.SaveIni();
var
  iniFile: TIniFile;
begin
  iniFile := TIniFile.Create(System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetDocumentsPath, 'System.ini'));
  try
    IniFile.WriteInteger('Settings', 'From Currency', cobFromCurrency.ItemIndex);
    IniFile.WriteInteger('Settings', 'To Currency', cobToCurrency.ItemIndex);
  finally
    IniFile.Free;
  end;
end;

procedure TfrmCurrencyConverter.btnChangeCurrencyClick(Sender: TObject);
var
  i: Integer;
begin
  i := cobFromCurrency.ItemIndex;
  cobFromCurrency.ItemIndex := cobToCurrency.ItemIndex;
  cobToCurrency.ItemIndex := i;
end;

procedure TfrmCurrencyConverter.btnConvertClick(Sender: TObject);
var
  keyboard: IFMXVirtualKeyboardService;
begin
  if (edtAmount.Text <> '') then
  begin
    Convert();
  end;
end;

procedure TfrmCurrencyConverter.DownloadXML();
var
  http_client: TNetHTTPClient;
  XMLDoc: IXMLDocument;
  stream: TMemoryStream;
  localFileName: string;
begin
  http_client := TNetHTTPClient.Create(nil);
  localFileName := TPath.Combine(TPath.GetDocumentsPath, 'DB');
  if NOT TDirectory.Exists(localFileName) then
    TDirectory.CreateDirectory(localFileName);
  localFileName := TPath.Combine(TPath.GetDocumentsPath, 'dtecbs.xml');

  try
    stream := TMemoryStream.Create;
    try
      try
        http_client.Get(exchange_rates_page, stream);
        stream.Position := 0;
        stream.SaveToFile(localFileName);
        XMLDoc := TXMLDocument.Create(nil);
        XMLDoc.LoadFromStream(stream);
        XMLDoc.Active := True;
      except
        on E: Exception do
        begin
          if TFile.Exists(localFileName) then
          begin
            XMLDoc := TXMLDocument.Create(nil);
            XMLDoc.LoadFromFile(localFileName);
            XMLDoc.Active := True;
          end
          else
            raise Exception.Create('XML ni bilo mogoče prenesti in lokalna datoteka ne obstaja.');
        end;
      end;
      ParseXML(XMLDoc);
    finally
      stream.Free;
    end;
  finally
    http_client.Free;
  end;
end;


procedure TfrmCurrencyConverter.edtAmountKeyDown(Sender: TObject; var Key: Word;
  var KeyChar: WideChar; Shift: TShiftState);
var
  keyboard: IFMXVirtualKeyboardService;
begin
  if (Key = 13) AND (edtAmount.Text <> '') then
  begin
    {$IF DEFINED(ANDROID)}
    if TPlatformServices.Current.SupportsPlatformService(IFMXVirtualKeyboardService,Keyboard) then
    begin
      if TVirtualKeyBoardState.Visible in Keyboard.GetVirtualKeyBoardState then
      begin
          keyboard.HideVirtualKeyboard;
      end
    end;
    {$ENDIF}
    Convert();
    exit;
  end;

  {$IF DEFINED(ANDROID)}
    if not (KeyChar in ['0'..'9', '.']) then
    begin
      KeyChar := #0;
    end
    else if (KeyChar  in ['.']) AND (Pos('.', edtAmount.Text) > 0) then
    begin
      KeyChar := #0;
    end;
  {$ENDIF}
  {$IF DEFINED(MSWINDOWS)}
    if not (KeyChar in ['0'..'9', ',']) then
    begin
      KeyChar := #0;
    end
    else if (KeyChar  in [',']) AND (Pos(',', edtAmount.Text) > 0) then
    begin
      KeyChar := #0;
    end;
  {$ENDIF}

end;

procedure TfrmCurrencyConverter.ParseXML(XMLDoc: IXMLDocument);
var
  root_node, tecajnica_node, tecaj_node: IXMLNode;
  currency_code: string;
  exchange_rate: Double;
  format_settings: TFormatSettings;
begin
  format_settings := TFormatSettings.Create;
  format_settings.DecimalSeparator := '.';

  currency.Clear;
  currency.Add('EUR', 1);
  cobFromCurrency.Items.Add('EUR');
  cobToCurrency.Items.Add('EUR');

  root_node := XMLDoc.DocumentElement;
  if Assigned(root_node) and (root_node.NodeName = 'DtecBS') then
  begin
    tecajnica_node := root_node.ChildNodes.FindNode('tecajnica');
    if Assigned(tecajnica_node) then
    begin
      labInfo.Text := 'Tečajnica Banke Slovenije na dan ' + ConvertDate(tecajnica_node.Attributes['datum']);
      tecaj_node := tecajnica_node.ChildNodes.First;
      while Assigned(tecaj_node) do
      begin
        if tecaj_node.NodeName = 'tecaj' then
        begin
          currency_code := tecaj_node.Attributes['oznaka'];
          exchange_rate := StrToFloat(tecaj_node.Text, format_settings);
          currency.Add(currency_code, exchange_rate);
          cobFromCurrency.Items.Add(currency_code);
          cobToCurrency.Items.Add(currency_code);
        end;
        tecaj_node := tecaj_node.NextSibling;
      end;
    end;
  end;
  cobFromCurrency.ItemIndex := 0;
  cobToCurrency.ItemIndex := 1;
end;

procedure TfrmCurrencyConverter.Convert();
var
  amount: Double;
  from_currency, to_currency: string;
  from_exchange_rate, to_exchange_rate, value: Double;
begin
  amount := StrToFloat(edtAmount.Text);
  from_currency := cobFromCurrency.Selected.Text;
  to_currency := cobToCurrency.Selected.Text;
  if (currency.TryGetValue(from_currency, from_exchange_rate)) and
     (currency.TryGetValue(to_currency, to_exchange_rate)) then
  begin
    value := amount * (to_exchange_rate / from_exchange_rate);
    labValue.Text := FormatFloat('#,##0.00', value);
  end
  else
    ShowMessage('Error pn converting.');
end;

function TfrmCurrencyConverter.ConvertDate(datum: string): string;
var
  Leto, Mesec, Dan: string;
begin
  // Preveri, ali je vhodni niz v pričakovani obliki
  if Length(Datum) = 10 then
  begin
    // Razčleni datum na leto, mesec in dan
    Leto := Copy(Datum, 1, 4);
    Mesec := Copy(Datum, 6, 2);
    Dan := Copy(Datum, 9, 2);
    // Sestavi nov niz v obliki 'DD.MM.YYYY'
    Result := Dan + '.' + Mesec + '.' + Leto;
  end
  else
    raise Exception.Create('Neveljavna oblika datuma. Pričakovana oblika je YYYY-MM-DD.');
end;
end.

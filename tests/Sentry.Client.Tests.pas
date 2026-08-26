unit Sentry.Client.Tests;

interface

uses
  DUnitX.TestFramework,
  System.JSON,
  System.SysUtils,
  Sentry.Client,
  Sentry.Transport,
  Sentry.Transport.Fake;

type
  [TestFixture]
  TSentryClientTests = class
  private
    const
      cDSN = 'https://publickey123@sentry.example.com/42';
    var
      FTransport: TFakeSentryTransport;
      FClient: TSentryClient;
    function ExtractEventPayload(const AEnvelope: string): string;
    function CaptureAndParse(const AFingerprint: TArray<string>): TJSONObject;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure CaptureException_EnviaParaURLDerivadaDoDSN;

    [Test]
    procedure CaptureException_SemFingerprint_NaoIncluiCampoNoPayload;

    [Test]
    procedure CaptureException_ComFingerprint_IncluiArrayNoPayload;

    [Test]
    procedure CaptureException_FingerprintComPartesVazias_IgnoraAsVazias;

    [Test]
    procedure CaptureException_FingerprintTodoVazio_NaoIncluiCampo;

    [Test]
    procedure AddTag_ChamadoDuasVezesComMesmaChave_Sobrescreve;

    [Test]
    procedure RemoveBreadcrumb_RemoveTodosOsItens_SemErroEPayloadLimpo;
  end;

implementation

{ TSentryClientTests }

procedure TSentryClientTests.Setup;
begin
  FTransport := TFakeSentryTransport.Create;
  FClient := TSentryClient.Create(cDSN, 'TestApp', 'test', FTransport);
end;

procedure TSentryClientTests.TearDown;
begin
  FClient.Free;
  FTransport := nil;
end;

function TSentryClientTests.ExtractEventPayload(const AEnvelope: string): string;
var
  P1, P2: Integer;
begin
  P1 := Pos(#10, AEnvelope);
  P2 := Pos(#10, AEnvelope, P1 + 1);
  Result := Copy(AEnvelope, P2 + 1, MaxInt);
end;

function TSentryClientTests.CaptureAndParse(const AFingerprint: TArray<string>): TJSONObject;
var
  Ex: Exception;
  PayloadStr: string;
begin
  Ex := Exception.Create('erro de teste');
  try
    FClient.CaptureException(Ex, '12345678900', AFingerprint);
  finally
    Ex.Free;
  end;
  PayloadStr := ExtractEventPayload(FTransport.LastEnvelope);
  Result := TJSONObject.ParseJSONValue(PayloadStr) as TJSONObject;
end;

procedure TSentryClientTests.CaptureException_EnviaParaURLDerivadaDoDSN;
var
  Payload: TJSONObject;
begin
  Payload := CaptureAndParse(nil);
  Payload.Free;
  Assert.AreEqual('https://sentry.example.com/api/42/envelope/', FTransport.LastURL);
end;

procedure TSentryClientTests.CaptureException_SemFingerprint_NaoIncluiCampoNoPayload;
var
  Payload: TJSONObject;
begin
  Payload := CaptureAndParse(nil);
  try
    Assert.IsNull(Payload.Values['fingerprint']);
  finally
    Payload.Free;
  end;
end;

procedure TSentryClientTests.CaptureException_ComFingerprint_IncluiArrayNoPayload;
var
  Payload: TJSONObject;
  Arr: TJSONArray;
begin
  Payload := CaptureAndParse(['{{ default }}', 'ENotaFiscalInvalida', 'ERR-042']);
  try
    Arr := Payload.Values['fingerprint'] as TJSONArray;
    Assert.IsNotNull(Arr);
    Assert.AreEqual(3, Arr.Count);
    Assert.AreEqual('{{ default }}', Arr.Items[0].Value);
    Assert.AreEqual('ENotaFiscalInvalida', Arr.Items[1].Value);
    Assert.AreEqual('ERR-042', Arr.Items[2].Value);
  finally
    Payload.Free;
  end;
end;

procedure TSentryClientTests.CaptureException_FingerprintComPartesVazias_IgnoraAsVazias;
var
  Payload: TJSONObject;
  Arr: TJSONArray;
begin
  Payload := CaptureAndParse(['{{ default }}', '  ', '', 'ERR-042']);
  try
    Arr := Payload.Values['fingerprint'] as TJSONArray;
    Assert.IsNotNull(Arr);
    Assert.AreEqual(2, Arr.Count);
    Assert.AreEqual('{{ default }}', Arr.Items[0].Value);
    Assert.AreEqual('ERR-042', Arr.Items[1].Value);
  finally
    Payload.Free;
  end;
end;

procedure TSentryClientTests.CaptureException_FingerprintTodoVazio_NaoIncluiCampo;
var
  Payload: TJSONObject;
begin
  Payload := CaptureAndParse(['', '   ']);
  try
    Assert.IsNull(Payload.Values['fingerprint']);
  finally
    Payload.Free;
  end;
end;

procedure TSentryClientTests.AddTag_ChamadoDuasVezesComMesmaChave_Sobrescreve;
var
  Payload: TJSONObject;
  Tags: TJSONObject;
begin
  FClient.AddTag('handled', 'no');
  FClient.AddTag('handled', 'yes');
  Payload := CaptureAndParse(nil);
  try
    Tags := Payload.Values['tags'] as TJSONObject;
    Assert.IsNotNull(Tags);
    Assert.AreEqual('yes', Tags.Values['handled'].Value);
  finally
    Payload.Free;
  end;
end;

procedure TSentryClientTests.RemoveBreadcrumb_RemoveTodosOsItens_SemErroEPayloadLimpo;
var
  Payload: TJSONObject;
begin
  FClient.AddBreadcrumb('info', 'cat1', 'msg1', 'info');
  FClient.AddBreadcrumb('info', 'cat2', 'msg2', 'info');
  FClient.AddBreadcrumb('info', 'cat3', 'msg3', 'info');

  FClient.RemoveBreadcrumb;

  Payload := CaptureAndParse(nil);
  try
    Assert.IsNull(Payload.Values['breadcrumbs']);
  finally
    Payload.Free;
  end;
end;

end.

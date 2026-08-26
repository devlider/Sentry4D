unit Sentry.Transport.Fake;

interface

uses
  Sentry.Transport;

type
  TFakeSentryTransport = class(TInterfacedObject, ISentryTransport)
  private
    FLastURL: string;
    FLastAuthHeader: string;
    FLastEnvelope: string;
    FCallCount: Integer;
    FResultToReturn: Boolean;
  public
    constructor Create;
    function Send(const AURL, AAuthHeader, AEnvelope: string): Boolean;

    property LastURL: string read FLastURL;
    property LastAuthHeader: string read FLastAuthHeader;
    property LastEnvelope: string read FLastEnvelope;
    property CallCount: Integer read FCallCount;
    property ResultToReturn: Boolean read FResultToReturn write FResultToReturn;
  end;

implementation

constructor TFakeSentryTransport.Create;
begin
  inherited Create;
  FResultToReturn := True;
end;

function TFakeSentryTransport.Send(const AURL, AAuthHeader, AEnvelope: string): Boolean;
begin
  Inc(FCallCount);
  FLastURL := AURL;
  FLastAuthHeader := AAuthHeader;
  FLastEnvelope := AEnvelope;
  Result := FResultToReturn;
end;

end.

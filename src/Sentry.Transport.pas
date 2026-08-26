unit Sentry.Transport;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Net.HttpClient;

type
  ISentryTransport = interface
    ['{6C6E9B0F-6B0D-4A9B-9A2E-9F4F3C6E7B2C}']
    function Send(const AURL, AAuthHeader, AEnvelope: string): Boolean;
  end;

  THTTPSentryTransport = class(TInterfacedObject, ISentryTransport)
  private
    FHttpClient: THTTPClient;
  public
    constructor Create;
    destructor Destroy; override;
    function Send(const AURL, AAuthHeader, AEnvelope: string): Boolean;
  end;

implementation

constructor THTTPSentryTransport.Create;
begin
  inherited Create;
  FHttpClient := THTTPClient.Create;
  FHttpClient.ConnectionTimeout := 5000;
  FHttpClient.ResponseTimeout := 5000;
end;

destructor THTTPSentryTransport.Destroy;
begin
  FHttpClient.Free;
  inherited;
end;

function THTTPSentryTransport.Send(const AURL, AAuthHeader, AEnvelope: string): Boolean;
var
  Req: TStringStream;
  Resp: IHTTPResponse;
begin
  Req := TStringStream.Create(AEnvelope, TEncoding.UTF8);
  try
    TMonitor.Enter(Self);
    try
      FHttpClient.CustomHeaders['X-Sentry-Auth'] := AAuthHeader;
      FHttpClient.ContentType := 'application/x-sentry-envelope';
      Resp := FHttpClient.Post(AURL, Req);
      Result := Assigned(Resp) and (Resp.StatusCode >= 200) and (Resp.StatusCode < 300);
    finally
      TMonitor.Exit(Self);
    end;
  finally
    Req.Free;
  end;
end;

end.

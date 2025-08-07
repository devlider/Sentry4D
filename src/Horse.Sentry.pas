unit Horse.Sentry;

interface

uses
  System.SysUtils, System.Json, Horse, Sentry.Client, Sentry.Factory;

type
  THorseSentry = reference to procedure(const Req: THorseRequest; const Res: THorseResponse);

function StringToJSONObject(const aJSONString: string): TJSONObject;
function HorseSentry(const ADNS, AAppName, AEnvironment, ARelease: string): THorseCallback;

implementation

var
  SentryClient: TSentryClient;

function HorseSentry(const ADNS, AAppName, AEnvironment, ARelease: string): THorseCallback;
var
  vJson: TJSONObject;
begin
  Result :=
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    begin
      try
        Next();
      except
        on E: Exception do
        begin
          if not Assigned(SentryClient) then
            SentryClient := TSentryFactory.New.DSN(ADNS).ApiName(AAppName).Environment(AEnvironment).Release(ARelease).Build;

          SentryClient.AddTag('transaction', Req.RawWebRequest.Method);

          if not Req.RawWebRequest.URL.Trim.IsEmpty then
            SentryClient.AddTag('url', Req.RawWebRequest.URL);

          SentryClient.AddTag('handled', 'no');

//          if not Req.Body.Trim.IsEmpty then
//          begin
//            vJson := StringToJSONObject(Req.Body);
//            SentryClient.AddBreadcrumb('error', 'body', E.Message, 'error', vJson);
//          end;

          if not Req.PathInfo.Trim.IsEmpty then
            SentryClient.AddTag('path.info', Req.PathInfo);


          SentryClient.CaptureException(E);

          raise;
        end;
      end;
    end;
end;

function StringToJSONObject(const aJSONString: string): TJSONObject;
var
  vJsonValue: TJSONValue;
begin
  try
    vJsonValue := TJSONObject.ParseJSONValue(aJSONString);
    if Assigned(vJsonValue) then
      Result := TJSONObject(vJsonValue)
    else
      raise Exception.Create('Erro ao converter string JSON para TJSONObject.');
  except
    on E: Exception do
    begin
      raise Exception.Create('Erro na conversão de string JSON para TJSONObject: ' + E.Message);
    end;
  end;
end;

end.



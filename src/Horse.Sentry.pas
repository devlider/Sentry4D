unit Horse.Sentry;

interface

uses
  System.SysUtils, System.Json, Horse, Sentry.Client, Sentry.Factory, Util.Json, System.classes;

type
  THorseSentry = reference to procedure(const Req: THorseRequest; const Res: THorseResponse);

function StringToJSONObject(const aJSONString: string): TJSONObject;
function HorseSentry(const ADNS, AAppName, AEnvironment, ARelease: string): THorseCallback;

implementation

var
  SentryClient: TSentryClient;

function HorseSentry(const ADNS, AAppName, AEnvironment, ARelease: string): THorseCallback;
var
  vJsonRes, vJsonBody: TJSONObject;
  s: TStringList;
begin
  Result :=
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    begin
      try
        Next();
      except
        on E: Exception do
        begin
          if (E is EHorseCallbackInterrupted) then
            Exit;

          if not Assigned(SentryClient) then
            SentryClient := TSentryFactory.New.DSN(ADNS).ApiName(AAppName).Environment(AEnvironment).Release(ARelease).Build;

          SentryClient.AddTag('handled', 'yes');
          SentryClient.AddTag('transaction', Req.RawWebRequest.Method);

          if not Req.PathInfo.Trim.IsEmpty then
            SentryClient.AddTag('path.info', Req.PathInfo);

          if not Req.RawWebRequest.URL.Trim.IsEmpty then
            SentryClient.AddTag('url', req.Headers.Items['Host']);

          if E is EHorseException then
          begin
            vJsonRes := EHorseException(E).ToJSONObject;

            if not req.Body.Trim.IsEmpty then
              vJsonBody := TJsonUtil.StringToJSONValue(req.Body) as TJSONObject;

            SentryClient.RemoveBreadcrumb;

            if not req.Body.Trim.IsEmpty then
              SentryClient.AddBreadcrumb('info', 'Body', E.Message, 'info', vJsonBody);

            SentryClient.AddBreadcrumb('error', 'Response', E.Message, 'error', vJsonRes);
          end;

          try
            SentryClient.CaptureException(E);
          except
          end;

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



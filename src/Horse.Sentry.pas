unit Horse.Sentry;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  Horse,
  Sentry.Client,
  Sentry.Factory,
  System.RegularExpressions;

type
  THorseSentry = reference to procedure(const Req: THorseRequest; const Res: THorseResponse);
  TBodyProcessor = function(const ABody: string): string;

function HorseSentry(const ADNS, AAppName, AEnvironment, ARelease: string; ABodyProcessor: TBodyProcessor = nil): THorseCallback;
function StringToJSONObject(const aJSONString: string): TJSONObject;
function ExtrairDocumentoEmitenteComRegex(const JSONString: string): string;

implementation

var
  SentryClient: TSentryClient;

function HorseSentry(const ADNS, AAppName, AEnvironment, ARelease: string;
  ABodyProcessor: TBodyProcessor = nil): THorseCallback;
begin
  Result :=
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      vJsonRes  : TJSONObject;
      vJsonBody : TJSONObject;
      LHasBody  : Boolean;
    begin
      try
        Next();
      except
        on E: Exception do
        begin
          if (E is EHorseCallbackInterrupted) then
            Exit;

          if not Assigned(SentryClient) then
            SentryClient := TSentryFactory.New
                              .DSN(ADNS)
                              .ApiName(AAppName)
                              .Environment(AEnvironment)
                              .Release(ARelease)
                              .Build;

          SentryClient.AddTag('handled', 'no');
          SentryClient.AddTag('transaction', Req.RawWebRequest.Method);
          if not Req.PathInfo.Trim.IsEmpty then
            SentryClient.AddTag('path.info', Req.PathInfo);
          if not Req.RawWebRequest.URL.Trim.IsEmpty then
            SentryClient.AddTag('url', Req.RawWebRequest.URL);

          vJsonRes  := nil;
          vJsonBody := nil;

          try
            if E is EHorseException then
            begin
              vJsonRes := EHorseException(E).ToJSONObject;

              LHasBody := not Req.Body.Trim.IsEmpty;
              if LHasBody then
              begin
                if Assigned(ABodyProcessor) then
                  vJsonBody := StringToJSONObject(ABodyProcessor(Req.Body))
                else
                  vJsonBody := StringToJSONObject(Req.Body);
              end;

              SentryClient.RemoveBreadcrumb;

              if Assigned(vJsonBody) then
                SentryClient.AddBreadcrumb('info', 'Body', E.Message, 'info', vJsonBody);

              if Assigned(vJsonRes) then
                SentryClient.AddBreadcrumb('error', 'Response', E.Message, 'error', vJsonRes);
            end;

            try
              SentryClient.CaptureException(E, ExtrairDocumentoEmitenteComRegex(Req.Body));
            except
            end;
          finally
            if Assigned(vJsonRes) then
              vJsonRes.Free;
            if Assigned(vJsonBody) then
              vJsonBody.Free;
          end;

          raise;
        end;
      end;
    end;
end;

function StringToJSONObject(const aJSONString: string): TJSONObject;
var
  vJsonValue: TJSONValue;
  Obj: TJSONObject;
begin
  vJsonValue := nil;
  try
    vJsonValue := TJSONObject.ParseJSONValue(aJSONString);
    if not Assigned(vJsonValue) then
      Exit(nil);

    if not (vJsonValue is TJSONObject) then
      Exit(nil);

    Obj := TJSONObject(vJsonValue);
    vJsonValue := nil;
    Result := Obj;
  except
    on E: Exception do
    begin
      if Assigned(vJsonValue) then
        vJsonValue.Free;
    end;
  end;
end;

function ExtrairDocumentoEmitenteComRegex(const JSONString: string): string;
var
  Regex: TRegEx;
  Match: TMatch;
  Documento: string;
begin
  Documento := '';

  Regex := TRegEx.Create('"emitente"\s*:\s*\{[^}]*"documento"\s*:\s*"([^"]+)"', [roMultiLine]);
  Match := Regex.Match(JSONString);

  if Match.Success then
    Documento := Match.Groups[1].Value;

  Result := Documento;
end;

end.


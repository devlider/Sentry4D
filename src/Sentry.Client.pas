unit Sentry.Client;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Net.HttpClient,
  System.Generics.Collections,
  System.DateUtils;

type
  TSentryClient = class
  private
    FPublicKey, FSentryHost, FProjectID, FFullURL: string;
    FHttpClient: THTTPClient;
    FAppName, FEnvironment, FRelease: string;
    FTags: TDictionary<string, string>;
    FBreadcrumbs: TJSONArray;
    FAppStartTime: TDateTime;
    procedure ParseDSN(const DSN: string);
    function BuildContexts: TJSONObject;
    function BuildEventPayload(const EventID: string; const E: Exception; UserDoc: string): string;
    function BuildEnvelope(const EventID, Payload: string): string;
    function GeraUUID(ARemoveTraco: Boolean = False):string;
  public
    constructor Create(const DSN, AppName, Environment: string);
    destructor Destroy; override;

    procedure AddTag(const Key: string; const Value: string);
    procedure AddBreadcrumb(const ABreadcrumbType, ACategory, AMessage, ALevel: string; AArgument: TJSONObject = nil);
    procedure RemoveBreadcrumb;
    procedure CaptureException(const E: Exception; AUserDoc: string);

    property Release: string read FRelease write FRelease;
  end;

  function UnixNow: Double;

implementation

uses
  System.Classes,
  {$IFDEF MSWINDOWS}Windows, ComObj, ActiveX{$ELSE}Posix.Unistd{$ENDIF},
  Sentry.SystemInfo;

function UnixNow: Double;
begin
  Result := SecondsBetween(Now, EncodeDate(1970, 1, 1));
end;

constructor TSentryClient.Create(const DSN, AppName, Environment: string);
begin
  inherited Create;
  FAppStartTime := Now;
  FAppName := AppName;
  FEnvironment := Environment;
  FHttpClient := THTTPClient.Create;
  FTags := TDictionary<string, string>.Create;
  FBreadcrumbs := TJSONArray.Create;
  ParseDSN(DSN);
end;

destructor TSentryClient.Destroy;
begin
  FHttpClient.Free;
  FTags.Free;
  FBreadcrumbs.Free;
  inherited;
end;

function TSentryClient.GeraUUID(ARemoveTraco: Boolean): string;
var
  Uid: TGuid;
begin
  if CreateGuid(Uid) = S_FALSE then
    raise Exception.Create('Não foi possivel gerar UUID.');

  if ARemoveTraco then
    result := GuidToString(Uid).Replace('{','',[]).Replace('}','',[]).Replace('-', '', [rfReplaceAll]).ToLower
  else
    result := GuidToString(Uid).Replace('{','',[]).Replace('}','',[]).ToLower;
end;

procedure TSentryClient.ParseDSN(const DSN: string);
var
  s: string; pProto, pAt, pSlash: Integer;
begin
  s := Trim(DSN);
  pProto := Pos('://', s); if pProto = 0 then raise Exception.Create('DSN inválido');
  Delete(s, 1, pProto + 2);
  pAt := Pos('@', s); if pAt = 0 then raise Exception.Create('DSN inválido');
  FPublicKey := Copy(s, 1, pAt - 1);
  Delete(s, 1, pAt);
  pSlash := Pos('/', s); if pSlash = 0 then raise Exception.Create('DSN inválido');
  FSentryHost := Copy(s, 1, pSlash - 1);
  FProjectID := Copy(s, pSlash + 1, High(Integer));
  FFullURL := Format('https://%s/api/%s/envelope/', [FSentryHost, FProjectID]);
end;

procedure TSentryClient.RemoveBreadcrumb;
var
  I: Integer;
begin
  if not Assigned(FBreadcrumbs) then
    Exit;

  for I := 0 to Pred(FBreadcrumbs.Count) do
    FBreadcrumbs.Remove(I);
end;

procedure TSentryClient.AddTag(const Key, Value: string);
begin
  if not FTags.ContainsKey(Key) then
    FTags.Add(Key, Value)
  else
    FTags.Items[Key] := Value;
end;

procedure TSentryClient.AddBreadcrumb(const ABreadcrumbType, ACategory, AMessage, ALevel: string; AArgument: TJSONObject = nil);
var
  Cr, vData : TJSONObject;
  vArguments: TJSONArray;
  ts: Double;
begin
  Cr := TJSONObject.Create;
  ts := UnixNow;
  Cr.AddPair('timestamp', TJSONNumber.Create(ts));
  Cr.AddPair('type', ABreadcrumbType);
  Cr.AddPair('category', ACategory);
  Cr.AddPair('level', ALevel);

  if AMessage <> '' then
    Cr.AddPair('message', AMessage);

  vData := TJSONObject.Create;

  if Assigned(AArgument) then
  begin
    vArguments := TJSONArray.Create;
    vArguments.AddElement(AArgument);

    vData.AddPair('arguments', vArguments);
  end;

  Cr.AddPair('data', vData as TJSONObject);

  FBreadcrumbs.AddElement(Cr);
end;

function TSentryClient.BuildContexts: TJSONObject;
begin
  Result := BuildSystemContexts(FAppStartTime);
end;

function TSentryClient.BuildEventPayload(const EventID: string; const E: Exception; UserDoc: string): string;
var
  Obj, Exo, Exs, TagsObj, ctxt, bread, user: TJSONObject;
  Arr: TJSONArray;
  k: string;
begin
  Obj := TJSONObject.Create;
  try
    Obj.AddPair('event_id', EventID);
    Obj.AddPair('timestamp', DateToISO8601(Now));
    Obj.AddPair('platform', 'delphi');
    Obj.AddPair('environment', FEnvironment);
    if FRelease <> '' then
      Obj.AddPair('release', FRelease);
    Obj.AddPair('server_name', FAppName);
    Obj.AddPair('level', 'error');
    Obj.AddPair('logger', 'delphi-client');

    Exo := TJSONObject.Create;
    Exo.AddPair('type', E.ClassName);
    Exo.AddPair('value', E.Message);
    Arr := TJSONArray.Create; Arr.AddElement(Exo);
    Exs := TJSONObject.Create; Exs.AddPair('values', Arr);
    Obj.AddPair('exception', Exs);

    TagsObj := TJSONObject.Create;
    for k in FTags.Keys do
      TagsObj.AddPair(k, FTags.Items[k]);
    Obj.AddPair('tags', TagsObj);

    if FBreadcrumbs.Count > 0 then
    begin
      bread := TJSONObject.Create;
      bread.AddPair('values', FBreadcrumbs.Clone as TJSONArray);
      Obj.AddPair('breadcrumbs', bread);
    end;

    ctxt := BuildContexts;
    Obj.AddPair('contexts', ctxt);

    user := TJSONObject.Create;
    user.AddPair('document', UserDoc);

    Obj.AddPair('user', user);

    Result := Obj.ToJSON;
  finally
    Obj.Free;
  end;
end;

function TSentryClient.BuildEnvelope(const EventID, Payload: string): string;
var hdr, itm: string; b: TBytes;
begin
  hdr := Format('{"event_id":"%s","sent_at":"%s"}', [EventID, DateToISO8601(Now)]);
  b := TEncoding.UTF8.GetBytes(Payload);
  itm := Format('{"type":"event","length":%d}', [Length(b)]);
  Result := hdr + #10 + itm + #10 + Payload;
end;

procedure TSentryClient.CaptureException(const E: Exception; AUserDoc: string);
var
  ID, Payload, Envelope, AuthH: string;
  Req: TStringStream;
  Resp: IHTTPResponse;
begin
  ID := GeraUUID(True);
  Payload := BuildEventPayload(ID, E, AUserDoc);
  Envelope := BuildEnvelope(ID, Payload);
  AuthH := Format('Sentry sentry_key=%s,sentry_version=7,sentry_client=delphi/1.0', [FPublicKey]);
  Req := TStringStream.Create(Envelope, TEncoding.UTF8);
  try
    FHttpClient.CustomHeaders['X-Sentry-Auth'] := AuthH;
    FHttpClient.ContentType := 'application/x-sentry-envelope';
    Resp := FHttpClient.Post(FFullURL, Req);
  finally
    Req.Free;
  end;
end;

end.


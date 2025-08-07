unit Sentry.Factory;

interface

uses
  System.SysUtils,
  Sentry.Client;

type
  ISentryFactoryClient = interface
    ['{00995265-1AEF-435A-848F-9680AC10AC39}']
    function DSN(const DSN: string): ISentryFactoryClient;
    function ApiName(const AppName: string): ISentryFactoryClient;
    function Environment(const Environment: string): ISentryFactoryClient;
    function Release(const Release: string): ISentryFactoryClient;
    function Build: TSentryClient;
  end;

  TSentryFactory = class
  public
    class function New: ISentryFactoryClient;
  end;

  TSentryFactoryClient = class(TInterfacedObject, ISentryFactoryClient)
  private
    FDSN: string;
    FAppName: string;
    FEnvironment: string;
    FRelease: string;
  public
    function DSN(const DSN: string): ISentryFactoryClient;
    function ApiName(const AppName: string): ISentryFactoryClient;
    function Environment(const Environment: string): ISentryFactoryClient;
    function Release(const Release: string): ISentryFactoryClient;
    function Build: TSentryClient;
  end;

implementation

class function TSentryFactory.New: ISentryFactoryClient;
begin
  Result := TSentryFactoryClient.Create; 
end;

{ TSentryFactoryClient }

function TSentryFactoryClient.DSN(const DSN: string): ISentryFactoryClient;
begin
  FDSN := DSN;
  Result := Self; 
end;

function TSentryFactoryClient.ApiName(const AppName: string): ISentryFactoryClient;
begin
  FAppName := AppName;
  Result := Self; 
end;

function TSentryFactoryClient.Environment(const Environment: string): ISentryFactoryClient;
begin
  FEnvironment := Environment;
  Result := Self; 
end;

function TSentryFactoryClient.Release(const Release: string): ISentryFactoryClient;
begin
  FRelease := Release;
  Result := Self; 
end;

function TSentryFactoryClient.Build: TSentryClient;
begin
  if FDSN = '' then
    raise Exception.Create('DSN is required');
  Result := TSentryClient.Create(FDSN, FAppName, FEnvironment);
  Result.Release := FRelease;
end;

end.

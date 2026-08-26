program Sentry4D.Tests;

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.TestFramework,
  Sentry.Transport.Fake in 'Fakes\Sentry.Transport.Fake.pas',
  Sentry.Client.Tests in 'Sentry.Client.Tests.pas';

var
  Runner: ITestRunner;
  Results: IRunResults;
  Logger: ITestLogger;
begin
  try
    ReportMemoryLeaksOnShutdown := True;
    Runner := TDUnitX.CreateRunner;
    Runner.UseRTTI := True;
    Logger := TDUnitXConsoleLogger.Create(True);
    Runner.AddLogger(Logger);
    Results := Runner.Execute;
    if not Results.AllPassed then
      System.ExitCode := 1;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.

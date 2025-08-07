unit Sentry.SystemInfo;

interface

uses
{$IFDEF MSWINDOWS}
  Sentry.SysInfoWindows,
{$ELSE}
  Sentry.SysInfoLinux,
{$ENDIF}
  System.JSON,
  System.SysUtils,
  System.DateUtils,
  System.Math;

function BuildSystemContexts(AppStartTime: TDateTime): TJSONObject;
function GetCPUDescription: string;
function GetProcessorCoreCount: Integer;
function GetProcessorFrequency: Double;
function GetKernelVersion: string;
function GetBootTime: string;
function GetMemoryInfo(out Total, Free: UInt64): Boolean;
function GetAppMemoryUsage: Int64;
function GetCurrentDateTime: string;

implementation

//uses
//  {$IFDEF MSWINDOWS}
//  Winapi.Windows, Winapi.PsAPI, System.Win.Registry, ActiveX, ComObj,
//  {$ELSE}
//  Sentry.SysInfoLinux,
//  {$ENDIF}
//  System.Classes, System.IOUtils, System.Variants;

function GetCPUDescription: string;
{$IFDEF MSWINDOWS}
var
  vSysInfoWindows: TSysInfoWindows;
begin
  vSysInfoWindows := TSysInfoWindows.Create;
  try
    Result := vSysInfoWindows.GetCPUDescription;
  finally
    FreeAndNil(vSysInfoWindows);
  end;
end;
{$ELSE}
var
  vSysInfoLinux: TSysInfoLinux;
begin
  vSysInfoLinux := TSysInfoLinux.Create;
  try
    Result := vSysInfoLinux.GetCPUDescription;
  finally
    FreeAndNil(vSysInfoLinux);
  end;
end;
{$ENDIF}

function GetProcessorCoreCount: Integer;
{$IFDEF MSWINDOWS}
var
  vSysInfoWindows: TSysInfoWindows;
begin
  vSysInfoWindows := TSysInfoWindows.Create;
  try
    Result := vSysInfoWindows.GetProcessorCoreCount;
  finally
    FreeAndNil(vSysInfoWindows);
  end;
end;
{$ELSE}
var
  vSysInfoLinux: TSysInfoLinux;
begin
  vSysInfoLinux := TSysInfoLinux.Create;
  try
    Result := vSysInfoLinux.GetProcessorCoreCount;
  finally
    FreeAndNil(vSysInfoLinux);
  end;
end;
{$ENDIF}

function GetProcessorFrequency: Double;
{$IFDEF MSWINDOWS}
var
  vSysInfoWindows: TSysInfoWindows;
begin
  vSysInfoWindows := TSysInfoWindows.Create;
  try
    Result := vSysInfoWindows.GetProcessorFrequency;
  finally
    FreeAndNil(vSysInfoWindows);
  end;
end;
{$ELSE}
var
  vSysInfoLinux: TSysInfoLinux;
begin
  vSysInfoLinux := TSysInfoLinux.Create;
  try
    Result := vSysInfoLinux.GetProcessorFrequency;
  finally
    FreeAndNil(vSysInfoLinux);
  end;
end;
{$ENDIF}

function GetKernelVersion: string;
{$IFDEF MSWINDOWS}
var
  vSysInfoWindows: TSysInfoWindows;
begin
  vSysInfoWindows := TSysInfoWindows.Create;
  try
    Result := vSysInfoWindows.GetKernelVersion;
  finally
    FreeAndNil(vSysInfoWindows);
  end;
end;
{$ELSE}
var
  vSysInfoLinux: TSysInfoLinux;
begin
  vSysInfoLinux := TSysInfoLinux.Create;
  try
    Result := vSysInfoLinux.GetKernelVersion;
  finally
    FreeAndNil(vSysInfoLinux);
  end;
end;
{$ENDIF}

function GetBootTime: string;
{$IFDEF MSWINDOWS}
var
  vSysInfoWindows: TSysInfoWindows;
begin
  vSysInfoWindows := TSysInfoWindows.Create;
  try
    Result := vSysInfoWindows.GetBootTime;
  finally
    FreeAndNil(vSysInfoWindows);
  end;
end;
{$ELSE}
var
  vSysInfoLinux: TSysInfoLinux;
begin
  vSysInfoLinux := TSysInfoLinux.Create;
  try
    Result := vSysInfoLinux.GetBootTime;
  finally
    FreeAndNil(vSysInfoLinux);
  end;
end;
{$ENDIF}

function GetMemoryInfo(out Total, Free: UInt64): Boolean;
{$IFDEF MSWINDOWS}
var
  vSysInfoWindows: TSysInfoWindows;
begin
  vSysInfoWindows := TSysInfoWindows.Create;
  try
    Result := vSysInfoWindows.GetMemoryInfo(Total, Free);
  finally
    FreeAndNil(vSysInfoWindows);
  end;
end;
{$ELSE}
var
  vSysInfoLinux: TSysInfoLinux;
begin
  vSysInfoLinux := TSysInfoLinux.Create;
  try
    Result := vSysInfoLinux.GetMemoryInfo(Total, Free);
  finally
    FreeAndNil(vSysInfoLinux);
  end;
end;
{$ENDIF}

function GetAppMemoryUsage: Int64;
{$IFDEF MSWINDOWS}
var
  vSysInfoWindows: TSysInfoWindows;
begin
  vSysInfoWindows := TSysInfoWindows.Create;
  try
    Result := vSysInfoWindows.GetAppMemoryUsage;
  finally
    FreeAndNil(vSysInfoWindows);
  end;
end;
{$ELSE}
var
  vSysInfoLinux: TSysInfoLinux;
begin
  vSysInfoLinux := TSysInfoLinux.Create;
  try
    Result := vSysInfoLinux.GetAppMemoryUsage;
  finally
    FreeAndNil(vSysInfoLinux);
  end;
end;
{$ENDIF}

function GetCurrentDateTime: string;
{$IFDEF MSWINDOWS}
var
  vSysInfoWindows: TSysInfoWindows;
begin
  vSysInfoWindows := TSysInfoWindows.Create;
  try
    Result := vSysInfoWindows.GetCurrentDateTime;
  finally
    FreeAndNil(vSysInfoWindows);
  end;
end;
{$ELSE}
var
  vSysInfoLinux: TSysInfoLinux;
begin
  vSysInfoLinux := TSysInfoLinux.Create;
  try
    Result := vSysInfoLinux.GetCurrentDateTime;
  finally
    FreeAndNil(vSysInfoLinux);
  end;
end;
{$ENDIF}

function BuildSystemContexts(AppStartTime: TDateTime): TJSONObject;
var
  TotalMem, FreeMem: UInt64;
  appc, osctx, devicec, runtimec: TJSONObject;
begin
  appc := TJSONObject.Create;
  try
    appc.AddPair('app_start_time', DateToISO8601(AppStartTime, True));
    appc.AddPair('app_memory', TJSONNumber.Create(GetAppMemoryUsage));
    appc.AddPair('type', 'app');
  except
    appc.Free;
    raise;
  end;

  osctx := TJSONObject.Create;
  try
    osctx.AddPair('name', {$IFDEF MSWINDOWS}'Windows'{$ELSE}'Linux'{$ENDIF});
    osctx.AddPair('kernel_version', GetKernelVersion);
    osctx.AddPair('type', 'os');
  except
    osctx.Free;
    raise;
  end;

  devicec := TJSONObject.Create;
  try
    devicec.AddPair('arch', {$IFDEF CPUX64}'x64'{$ELSE}'x86'{$ENDIF});
    if GetMemoryInfo(TotalMem, FreeMem) then
    begin
      devicec.AddPair('memory_size', TJSONNumber.Create(TotalMem));
      devicec.AddPair('free_memory', TJSONNumber.Create(FreeMem));
    end;
    devicec.AddPair('boot_time', GetBootTime);
    devicec.AddPair('processor_count', TJSONNumber.Create(GetProcessorCoreCount));
    devicec.AddPair('cpu_description', GetCPUDescription);
    devicec.AddPair('processor_frequency', TJSONNumber.Create(GetProcessorFrequency));
    devicec.AddPair('type', 'device');
  except
    devicec.Free;
    raise;
  end;

  runtimec := TJSONObject.Create;
  try
    runtimec.AddPair('runtime', 'Delphi');
    runtimec.AddPair('version', '10.2.3');
    runtimec.AddPair('name', 'Delphi');
    runtimec.AddPair('type', 'runtime');
  except
    runtimec.Free;
    raise;
  end;

  Result := TJSONObject.Create;
  try
    Result.AddPair('app', appc);
    Result.AddPair('os', osctx);
    Result.AddPair('device', devicec);
    Result.AddPair('runtime', runtimec);
  except
    Result.Free;
    raise;
  end;
end;

end.


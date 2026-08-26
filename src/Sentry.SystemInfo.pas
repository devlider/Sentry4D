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

var
  SysInfoService: ISysInfoService;

function GetSysInfoService: ISysInfoService;
begin
  if not Assigned(SysInfoService) then
    {$IFDEF MSWINDOWS}
    SysInfoService := TSysInfoWindows.Create;
    {$ELSE}
    SysInfoService := TSysInfoLinux.Create;
    {$ENDIF}
  Result := SysInfoService;
end;

function GetCPUDescription: string;
begin
  Result := GetSysInfoService.GetCPUDescription;
end;

function GetProcessorCoreCount: Integer;
begin
  Result := GetSysInfoService.GetProcessorCoreCount;
end;

function GetProcessorFrequency: Double;
begin
  Result := GetSysInfoService.GetProcessorFrequency;
end;

function GetKernelVersion: string;
begin
  Result := GetSysInfoService.GetKernelVersion;
end;

function GetBootTime: string;
begin
  Result := GetSysInfoService.GetBootTime;
end;

function GetMemoryInfo(out Total, Free: UInt64): Boolean;
begin
  Result := GetSysInfoService.GetMemoryInfo(Total, Free);
end;

function GetAppMemoryUsage: Int64;
begin
  Result := GetSysInfoService.GetAppMemoryUsage;
end;

function GetCurrentDateTime: string;
begin
  Result := GetSysInfoService.GetCurrentDateTime;
end;

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
    runtimec.AddPair('version', Format('%.1f', [CompilerVersion]));
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


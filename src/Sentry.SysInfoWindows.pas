unit Sentry.SysInfoWindows;

interface

uses
  System.SysUtils, System.Classes, System.DateUtils, System.Math;

type
  ISysInfoService = interface
    ['{A7E69ABF-0F12-4C2B-9BE7-2E6F125D1CD2}']
    function GetCPUDescription: string;
    function GetProcessorCoreCount: Integer;
    function GetProcessorFrequency: Double;
    function GetKernelVersion: string;
    function GetBootTime: string;
    function GetMemoryInfo(out Total, Free: UInt64): Boolean;
    function GetAppMemoryUsage: Int64;
    function GetCurrentDateTime: string;
  end;

  TSysInfoWindows = class(TInterfacedObject, ISysInfoService)
  private
    function DateTimeToISO8601(const ADateTime: TDateTime): string;
  public
    function GetCPUDescription: string;
    function GetProcessorCoreCount: Integer;
    function GetProcessorFrequency: Double;
    function GetKernelVersion: string;
    function GetBootTime: string;
    function GetMemoryInfo(out Total, Free: UInt64): Boolean;
    function GetAppMemoryUsage: Int64;
    function GetCurrentDateTime: string;
  end;

implementation

uses
  Winapi.Windows, Winapi.PsAPI, System.Win.Registry;

const
  ALL_PROCESSOR_GROUPS: WORD = $FFFF;

{ TSysInfoWindows }

function TSysInfoWindows.DateTimeToISO8601(const ADateTime: TDateTime): string;
var
  UTC: TDateTime;
  MilliSeconds: Integer;
begin
  if (ADateTime < EncodeDate(1900, 1, 1)) or (ADateTime > EncodeDate(9999, 12, 31)) then
    Exit('Desconhecido');
  try
    UTC := TTimeZone.Local.ToUniversalTime(ADateTime);
    MilliSeconds := MilliSecondOf(ADateTime);
    if (MilliSeconds >= 0) and (MilliSeconds <= 999) then
      Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', UTC) +
                Format('.%.3d+00:00', [MilliSeconds])
    else
      Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss.000+00:00', UTC);
  except
    Result := 'Desconhecido';
  end;
end;

function TSysInfoWindows.GetCPUDescription: string;
var
  Reg: TRegistry;
begin
  Result := 'Desconhecido';
  try
    Reg := TRegistry.Create;
    try
      Reg.RootKey := HKEY_LOCAL_MACHINE;
      if Reg.OpenKeyReadOnly('HARDWARE\DESCRIPTION\System\CentralProcessor\0') then
      begin
        if Reg.ValueExists('ProcessorNameString') then
          Result := Reg.ReadString('ProcessorNameString');
        Reg.CloseKey;
      end;
    finally
      Reg.Free;
    end;
  except
    Result := 'Desconhecido';
  end;
end;

function TSysInfoWindows.GetProcessorCoreCount: Integer;
var
  Count: DWORD;
  SysInfo: TSystemInfo;
begin
  Result := 0;
  try
    Count := GetActiveProcessorCount(ALL_PROCESSOR_GROUPS);
    if Count = 0 then
    begin
      GetSystemInfo(SysInfo);
      Count := SysInfo.dwNumberOfProcessors;
    end;
    Result := Count;
  except
    GetSystemInfo(SysInfo);
    Result := SysInfo.dwNumberOfProcessors;
  end;
end;

function TSysInfoWindows.GetProcessorFrequency: Double;
var
  Reg: TRegistry;
  MHz: Integer;
begin
  Result := 0.0;
  try
    Reg := TRegistry.Create;
    try
      Reg.RootKey := HKEY_LOCAL_MACHINE;
      if Reg.OpenKeyReadOnly('HARDWARE\DESCRIPTION\System\CentralProcessor\0') then
      begin
        if Reg.ValueExists('~MHz') then
        begin
          MHz := Reg.ReadInteger('~MHz');
          if MHz > 0 then
            Result := RoundTo(MHz / 1000.0, -2);
        end;
        Reg.CloseKey;
      end;
    finally
      Reg.Free;
    end;
  except
    Result := 0.0;
  end;
end;

function TSysInfoWindows.GetKernelVersion: string;
var
  OSInfo: TOSVersionInfoEx;
begin
  Result := 'Desconhecido';
  try
    ZeroMemory(@OSInfo, SizeOf(OSInfo));
    OSInfo.dwOSVersionInfoSize := SizeOf(OSInfo);

    if GetVersionEx(OSInfo) then
      Result := Format('Windows %d.%d Build %d',
        [OSInfo.dwMajorVersion, OSInfo.dwMinorVersion, OSInfo.dwBuildNumber]);
  except
    Result := 'Desconhecido';
  end;
end;

function TSysInfoWindows.GetBootTime: string;
var
  Ticks: UInt64;
  BootTime: TDateTime;
begin
  Result := 'Desconhecido';
  try
    Ticks := GetTickCount64;
    BootTime := TTimeZone.Local.ToUniversalTime(Now) - (Ticks / (1000.0 * 60.0 * 60.0 * 24.0));
    Result := DateTimeToISO8601(BootTime);
  except
    Result := 'Desconhecido';
  end;
end;

function TSysInfoWindows.GetMemoryInfo(out Total, Free: UInt64): Boolean;
var
  MS: TMemoryStatusEx;
begin
  Result := False;
  Total := 0;
  Free := 0;
  try
    MS.dwLength := SizeOf(MS);

    if GlobalMemoryStatusEx(MS) then
    begin
      Total := MS.ullTotalPhys;
      Free := MS.ullAvailPhys;
      Result := True;
    end;
  except
    Result := False;
    Total := 0;
    Free := 0;
  end;
end;

function TSysInfoWindows.GetAppMemoryUsage: Int64;
var
  ProcessHandle: THandle;
  MemCounters: TProcessMemoryCounters;
begin
  Result := 0;
  try
    ProcessHandle := GetCurrentProcess;
    FillChar(MemCounters, SizeOf(MemCounters), 0);
    MemCounters.cb := SizeOf(MemCounters);

    if GetProcessMemoryInfo(ProcessHandle, @MemCounters, SizeOf(MemCounters)) then
      Result := MemCounters.WorkingSetSize;
  except
    Result := 0;
  end;
end;

function TSysInfoWindows.GetCurrentDateTime: string;
begin
  Result := DateTimeToISO8601(Now);
end;

end.

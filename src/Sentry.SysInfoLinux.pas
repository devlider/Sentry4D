unit Sentry.SysInfoLinux;

interface

uses
  System.SysUtils, System.Classes, System.DateUtils, System.Math,
  System.StrUtils;

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

  TSysInfoLinux = class(TInterfacedObject, ISysInfoService)
  private
    function ExecuteCommand(const ACmd: string; const AParams: array of string; out Output: string): Boolean;
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
  ACBRBase, Posix.Stdlib, Posix.Stdio;

const
  libc = 'libc.so.6';

function popen(command: PAnsiChar; mode: PAnsiChar): Pointer; cdecl; external libc name 'popen';
function pclose(stream: Pointer): Integer; cdecl; external libc name 'pclose';
function fgets(s: PAnsiChar; n: Integer; stream: Pointer): PAnsiChar; cdecl; external libc name 'fgets';

{ TSysInfoLinux }

function TSysInfoLinux.ExecuteCommand(const ACmd: string; const AParams: array of string; out Output: string): Boolean;
const
  BufferSize = 1024;
var
  CmdLine: AnsiString;
  Param: string;
  Pipe: Pointer;
  Buffer: array[0..BufferSize - 1] of AnsiChar;
  ReadRes: PAnsiChar;
  SB: TStringBuilder;
  I: Integer;
begin
  Output := '';

  CmdLine := AnsiString(ACmd);
  for I := 0 to High(AParams) do
    CmdLine := CmdLine + ' ' + AnsiString(AParams[I]);
  SB := TStringBuilder.Create;
  try
    Pipe := popen(PAnsiChar(CmdLine), 'r');
    if Pipe <> nil then
    begin
      try
        while True do
        begin
          ReadRes := fgets(@Buffer[0], BufferSize, Pipe);
          if ReadRes = nil then
            Break;
          SB.Append(string(AnsiString(Buffer)));
        end;
      finally
        pclose(Pipe);
      end;
    end;
    Output := SB.ToString.Trim;
    Result := Output <> '';
  finally
    SB.Free;
  end;
end;

function TSysInfoLinux.DateTimeToISO8601(const ADateTime: TDateTime): string;
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

function TSysInfoLinux.GetCPUDescription: string;
var
  Output: string;
  Lines: TArray<string>;
  Line, LTrim: string;
  ColonPos: Integer;
begin
  Result := 'Desconhecido';

  if not ExecuteCommand('/bin/cat', ['/proc/cpuinfo'], Output) then
    Exit;

  Lines := Output.Split([#10, #13], TStringSplitOptions.ExcludeEmpty);
  for Line in Lines do
  begin
    LTrim := Trim(Line);
    if SameText(Copy(LTrim, 1, 10), 'model name') then
    begin
      ColonPos := Pos(':', LTrim);
      if ColonPos > 0 then
      begin
        Result := Trim(Copy(LTrim, ColonPos + 1, MaxInt));
        Break;
      end;
    end;
  end;
end;

function TSysInfoLinux.GetProcessorCoreCount: Integer;
var
  Output: string;
  Lines: TArray<string>;
  Line, LTrim: string;
begin
  Result := 0;

  if not ExecuteCommand('/bin/cat', ['/proc/cpuinfo'], Output) then
    Exit;
  Lines := Output.Split([#10, #13], TStringSplitOptions.ExcludeEmpty);
  for Line in Lines do
  begin
    LTrim := Trim(Line);
    if SameText(Copy(LTrim, 1, 9), 'processor') then
    begin
      Inc(Result);
    end;
  end;
end;

function TSysInfoLinux.GetProcessorFrequency: Double;
var
  Output: string;
  Lines: TArray<string>;
  Line, LTrim: string;
  ColonPos: Integer;
  ValueStr: string;
  MHz: Double;
  FS: TFormatSettings;
begin
  Result := 0.0;

  FS := TFormatSettings.Create('en-US');

  if not ExecuteCommand('/bin/cat', ['/proc/cpuinfo'], Output) then
    Exit;
  Lines := Output.Split([#10, #13], TStringSplitOptions.ExcludeEmpty);
  for Line in Lines do
  begin
    LTrim := Trim(Line);
    if SameText(Copy(LTrim, 1, 6), 'cpu MHz') then
    begin
      ColonPos := Pos(':', LTrim);
      if ColonPos > 0 then
      begin
        ValueStr := Trim(Copy(LTrim, ColonPos + 1, MaxInt));
        ValueStr := StringReplace(ValueStr, ',', '.', [rfReplaceAll]);
        MHz := StrToFloatDef(ValueStr, 0.0, FS);
        if MHz > 0 then
        begin
          Result := RoundTo(MHz / 1000.0, -2);
          Break;
        end;
      end;
    end;
  end;
end;

function TSysInfoLinux.GetKernelVersion: string;
var
  Output: string;
begin
  Result := 'Desconhecido';

  if ExecuteCommand('/bin/uname', ['-r'], Output) then
    Result := Trim(Output);
end;

function TSysInfoLinux.GetBootTime: string;
var
  Output: string;
  Parts: TArray<string>;
  UptimeSeconds: Double;
  CurrentUTC: TDateTime;
  BootTime: TDateTime;
  FS: TFormatSettings;
begin
  Result := 'Desconhecido';

  if not ExecuteCommand('/bin/cat', ['/proc/uptime'], Output) then
    Exit;
  FS := TFormatSettings.Create('en-US');
  Parts := Output.Split([' '], TStringSplitOptions.ExcludeEmpty);
  if Length(Parts) > 0 then
  begin
    UptimeSeconds := StrToFloatDef(Parts[0], -1, FS);
    if UptimeSeconds >= 0 then
    begin
      CurrentUTC := TTimeZone.Local.ToUniversalTime(Now);
      BootTime := CurrentUTC - (UptimeSeconds / (24 * 60 * 60));
      Result := DateTimeToISO8601(BootTime);
    end;
  end;
end;

function TSysInfoLinux.GetMemoryInfo(out Total, Free: UInt64): Boolean;
var
  Output: string;
  Lines: TArray<string>;
  Line: string;
  LTrim: string;
  Parts, Tokens: TArray<string>;
  ValueStr: string;
  FS: TFormatSettings;
  MemTotal, MemFree: Int64;
  s: string;
begin
  Result := False;
  Total := 0;
  Free := 0;

  if not ExecuteCommand('/bin/cat', ['/proc/meminfo'], Output) then
    Exit;
  FS := TFormatSettings.Create('en-US');
  MemTotal := -1;
  MemFree := -1;
  Lines := Output.Split([#10, #13], TStringSplitOptions.ExcludeEmpty);
  for Line in Lines do
  begin
    LTrim := Trim(Line);

    if SameText(Copy(LTrim, 1, 8), 'MemTotal') then
    begin
      Parts := LTrim.Split([':'], 2);
      if Length(Parts) > 1 then
      begin
        ValueStr := Trim(StringReplace(Parts[1], 'kB', '', [rfReplaceAll]));
        Tokens := ValueStr.Split([' ']);
        for s in Tokens do
          if Trim(s) <> '' then
          begin
            MemTotal := StrToInt64Def(s, -1);
            Break;
          end;
      end;
    end
    else if SameText(Copy(LTrim, 1, 7), 'MemFree') then
    begin
      Parts := LTrim.Split([':'], 2);
      if Length(Parts) > 1 then
      begin
        ValueStr := Trim(StringReplace(Parts[1], 'kB', '', [rfReplaceAll]));
        Tokens := ValueStr.Split([' ']);
        for s in Tokens do
          if Trim(s) <> '' then
          begin
            MemFree := StrToInt64Def(s, -1);
            Break;
          end;
      end;
    end;
    if (MemTotal >= 0) and (MemFree >= 0) then
      Break;
  end;
  if (MemTotal >= 0) and (MemFree >= 0) then
  begin
    Total := UInt64(MemTotal) * 1024;
    Free := UInt64(MemFree) * 1024;
    Result := True;
  end;
end;

function TSysInfoLinux.GetAppMemoryUsage: Int64;
var
  Output: string;
  Lines: TArray<string>;
  Line: string;
  LTrim: string;
  Parts, Tokens: TArray<string>;
  ValueStr: string;
  MemValue: Int64;
  s: string;
begin
  Result := 0;
  if not ExecuteCommand('/bin/cat', ['/proc/self/status'], Output) then
    Exit;
  Lines := Output.Split([#10, #13], TStringSplitOptions.ExcludeEmpty);
  for Line in Lines do
  begin
    LTrim := Trim(Line);
    if SameText(Copy(LTrim, 1, 5), 'VmRSS') then
    begin
      Parts := LTrim.Split([':'], 2);
      if Length(Parts) > 1 then
      begin
        ValueStr := Trim(StringReplace(Parts[1], 'kB', '', [rfReplaceAll]));
        Tokens := ValueStr.Split([' ']);
        MemValue := -1;
        for s in Tokens do
        begin
          if Trim(s) <> '' then
          begin
            MemValue := StrToInt64Def(s, -1);
            Break;
          end;
        end;
        if (MemValue >= 0) and (MemValue <= (High(Int64) div 1024)) then
          Result := MemValue * 1024;
      end;
      Break;
    end;
  end;
end;

function TSysInfoLinux.GetCurrentDateTime: string;
begin
  Result := DateTimeToISO8601(Now);
end;

end.

unit uConsoleOutput;

interface

uses
  System.SysUtils, System.Classes;

type
  // Console output utilities
  TConsoleOutput = class
  public
    class procedure WriteLnColored(const Text: string; Color: Byte = 7);
    class procedure WriteProgress(Current, Total: Int64; const Message: string = '');
    class procedure ClearLine;
    class procedure ShowStatistics(const Stats: string);
  end;

  // Progress bar for console display
  TProgressBar = class
  private
    FStartTime: TDateTime;
    FLastUpdate: TDateTime;
    FTotal: Int64;
    FCurrent: Int64;
    FWidth: Integer;

    function FormatTime(Seconds: Int64): string;
    function FormatBytes(Bytes: Int64): string;
  public
    constructor Create(Total: Int64; Width: Integer = 50);

    procedure Update(Current: Int64);
    procedure Finish;

    property Total: Int64 read FTotal;
    property Current: Int64 read FCurrent;
  end;

implementation

{ TConsoleOutput }

class procedure TConsoleOutput.WriteLnColored(const Text: string; Color: Byte);
begin
  {$IFDEF MSWINDOWS}
    // For Windows console, would need Windows unit for SetConsoleTextAttribute
    WriteLn(Text);
  {$ELSE}
    // ANSI codes for other systems
    WriteLn(Text);
  {$ENDIF}
end;

class procedure TConsoleOutput.WriteProgress(Current, Total: Int64;
  const Message: string);
var
  Percent: Integer;
  BarLength: Integer;
  I: Integer;
  ProgressStr: string;
begin
  if Total = 0 then
    Exit;

  Percent := Round((Current * 100) / Total);
  BarLength := (Current * 30) div Total;

  ProgressStr := Format('[', []);
  for I := 0 to 29 do
  begin
    if I < BarLength then
      ProgressStr := ProgressStr + '='
    else
      ProgressStr := ProgressStr + ' ';
  end;
  ProgressStr := ProgressStr + Format('] %d%% (%d/%d)', [Percent, Current, Total]);

  if Message <> '' then
    ProgressStr := ProgressStr + ' - ' + Message;

  Write(#13 + ProgressStr);
end;

class procedure TConsoleOutput.ClearLine;
begin
  Write(#13 + StringOfChar(' ', 80) + #13);
end;

class procedure TConsoleOutput.ShowStatistics(const Stats: string);
begin
  WriteLn('');
  WriteLn('=== Statistics ===');
  WriteLn(Stats);
end;

{ TProgressBar }

constructor TProgressBar.Create(Total: Int64; Width: Integer);
begin
  inherited Create;
  FTotal := Total;
  FWidth := Width;
  FCurrent := 0;
  FStartTime := Now;
  FLastUpdate := FStartTime;
end;

function TProgressBar.FormatTime(Seconds: Int64): string;
var
  Hours, Minutes, Secs: Int64;
begin
  Hours := Seconds div 3600;
  Minutes := (Seconds mod 3600) div 60;
  Secs := Seconds mod 60;

  if Hours > 0 then
    Result := Format('%d:%02d:%02d', [Hours, Minutes, Secs])
  else
    Result := Format('%02d:%02d', [Minutes, Secs]);
end;

function TProgressBar.FormatBytes(Bytes: Int64): string;
const
  KB = 1024;
  MB = KB * 1024;
  GB = MB * 1024;
begin
  if Bytes < KB then
    Result := Format('%d B', [Bytes])
  else if Bytes < MB then
    Result := Format('%.2f KB', [Bytes / KB])
  else if Bytes < GB then
    Result := Format('%.2f MB', [Bytes / MB])
  else
    Result := Format('%.2f GB', [Bytes / GB]);
end;

procedure TProgressBar.Update(Current: Int64);
var
  Percent: Integer;
  BarLength: Integer;
  ProgressStr: string;
  I: Integer;
  ElapsedSeconds, RemainingSeconds: Int64;
  Speed: Double;
  Now: TDateTime;
begin
  FCurrent := Current;
  Now := System.SysUtils.Now;

  // Update every 100ms to avoid flicker
  if (Now - FLastUpdate) * 86400 < 0.1 then
    Exit;

  FLastUpdate := Now;

  if FTotal = 0 then
    Exit;

  Percent := Round((Current * 100) / FTotal);
  BarLength := (Current * FWidth) div FTotal;

  ProgressStr := '[';
  for I := 0 to FWidth - 1 do
  begin
    if I < BarLength then
      ProgressStr := ProgressStr + '='
    else
      ProgressStr := ProgressStr + '-';
  end;
  ProgressStr := ProgressStr + '] ';

  // Calculate speed and remaining time
  ElapsedSeconds := Trunc((Now - FStartTime) * 86400);
  if ElapsedSeconds > 0 then
  begin
    Speed := Current / ElapsedSeconds;
    if Speed > 0 then
      RemainingSeconds := Trunc((FTotal - Current) / Speed)
    else
      RemainingSeconds := 0;
  end
  else
  begin
    Speed := 0;
    RemainingSeconds := 0;
  end;

  ProgressStr := ProgressStr + Format('%3d%% | %s | %s/s | ETA: %s',
    [Percent, FormatBytes(Current), FormatBytes(Trunc(Speed)), FormatTime(RemainingSeconds)]);

  Write(#13 + ProgressStr);
end;

procedure TProgressBar.Finish;
var
  ElapsedSeconds: Int64;
  AvgSpeed: Double;
  TotalTime: TDateTime;
begin
  TotalTime := System.SysUtils.Now - FStartTime;
  ElapsedSeconds := Trunc(TotalTime * 86400);

  if ElapsedSeconds > 0 then
    AvgSpeed := FTotal / ElapsedSeconds
  else
    AvgSpeed := 0;

  WriteLn('');
  WriteLn('Completed: ' + FormatBytes(FTotal) + ' in ' + FormatTime(ElapsedSeconds) +
    ' (' + FormatBytes(Trunc(AvgSpeed)) + '/s)');
end;

end.

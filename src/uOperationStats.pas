unit uOperationStats;

interface

uses
  System.SysUtils, System.DateUtils;

type
  TOperationStats = class
  private
    FStartTime: TDateTime;
    FEndTime: TDateTime;
  public
    BytesProcessed: Int64;
    FilesProcessed: Integer;
    Errors: Integer;

    procedure Start;
    procedure Stop;
    function ElapsedMilliseconds: Int64;
    function ElapsedSeconds: Double;
    function BytesPerSecond: Double;
    function FormatElapsedSeconds: string;
    function FormatBytesPerSecond: string;
  end;

implementation

procedure TOperationStats.Start;
begin
  FStartTime := Now;
  FEndTime := 0;
  BytesProcessed := 0;
  FilesProcessed := 0;
  Errors := 0;
end;

procedure TOperationStats.Stop;
begin
  FEndTime := Now;
end;

function TOperationStats.ElapsedMilliseconds: Int64;
begin
  if FEndTime = 0 then
    Result := MilliSecondsBetween(Now, FStartTime)
  else
    Result := MilliSecondsBetween(FEndTime, FStartTime);
end;

function TOperationStats.ElapsedSeconds: Double;
begin
  Result := ElapsedMilliseconds / 1000.0;
end;

function TOperationStats.BytesPerSecond: Double;
var
  Seconds: Double;
begin
  Seconds := ElapsedSeconds;
  if (Seconds <= 0) or (BytesProcessed <= 0) then
    Result := 0
  else
    Result := BytesProcessed / Seconds;
end;

function TOperationStats.FormatElapsedSeconds: string;
begin
  Result := Format('%.3f s', [ElapsedSeconds]);
end;

function TOperationStats.FormatBytesPerSecond: string;
begin
  Result := Format('%.0f B/s', [BytesPerSecond]);
end;

end.


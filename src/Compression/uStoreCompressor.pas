unit uStoreCompressor;

interface

uses
  System.SysUtils, System.Classes;

type
  // Store compressor - no compression, just copy data
  // Used for already compressed files or when user explicitly requests it
  TStoreCompressor = class
  public
    constructor Create;
    destructor Destroy; override;

    // Compress (actually just copy) input to output
    procedure Compress(Input: TStream; Output: TStream; OnProgress: TNotifyEvent = nil);
    
    // Decompress (actually just copy) input to output
    procedure Decompress(Input: TStream; Output: TStream; OnProgress: TNotifyEvent = nil);
  end;

implementation

{ TStoreCompressor }

constructor TStoreCompressor.Create;
begin
  inherited Create;
end;

destructor TStoreCompressor.Destroy;
begin
  inherited Destroy;
end;

procedure TStoreCompressor.Compress(Input: TStream; Output: TStream; OnProgress: TNotifyEvent = nil);
const
  BUFFER_SIZE = 65536; // 64KB buffer
var
  Buffer: TBytes;
  BytesRead: Integer;
begin
  try
    SetLength(Buffer, BUFFER_SIZE);
    Input.Position := 0;
    
    // Simply copy data from input to output
    while Input.Position < Input.Size do
    begin
      BytesRead := Input.Read(Buffer[0], BUFFER_SIZE);
      if BytesRead > 0 then
        Output.Write(Buffer[0], BytesRead);
      
      if Assigned(OnProgress) then
        OnProgress(Self);
    end;
  except
    on E: Exception do
      raise Exception.Create('Store compression failed: ' + E.Message);
  end;
end;

procedure TStoreCompressor.Decompress(Input: TStream; Output: TStream; OnProgress: TNotifyEvent = nil);
const
  BUFFER_SIZE = 65536; // 64KB buffer
var
  Buffer: TBytes;
  BytesRead: Integer;
begin
  try
    SetLength(Buffer, BUFFER_SIZE);
    Input.Position := 0;
    
    // Simply copy data from input to output
    while Input.Position < Input.Size do
    begin
      BytesRead := Input.Read(Buffer[0], BUFFER_SIZE);
      if BytesRead > 0 then
        Output.Write(Buffer[0], BytesRead);
      
      if Assigned(OnProgress) then
        OnProgress(Self);
    end;
  except
    on E: Exception do
      raise Exception.Create('Store decompression failed: ' + E.Message);
  end;
end;

end.


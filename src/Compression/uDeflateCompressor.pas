unit uDeflateCompressor;

interface

uses
  System.SysUtils, System.Classes, System.ZLib, uSMARTLARKExceptions;

type
  // DEFLATE compressor using zlib library
  // DEFLATE is LZ77 + Huffman coding (same as gzip/zip)
  TDeflateCompressor = class
  private
    FCompressionLevel: Integer;
  public
    constructor Create(CompressionLevel: Integer = 5);
    destructor Destroy; override;

    // Compress input to output using DEFLATE
    procedure Compress(Input: TStream; Output: TStream; OnProgress: TNotifyEvent = nil);
    
    // Decompress input to output using DEFLATE
    procedure Decompress(Input: TStream; Output: TStream; OnProgress: TNotifyEvent = nil);

    property CompressionLevel: Integer read FCompressionLevel write FCompressionLevel;
  end;

implementation

{ TDeflateCompressor }

constructor TDeflateCompressor.Create(CompressionLevel: Integer);
begin
  inherited Create;
  FCompressionLevel := CompressionLevel;
end;

destructor TDeflateCompressor.Destroy;
begin
  inherited Destroy;
end;

procedure TDeflateCompressor.Compress(Input: TStream; Output: TStream; OnProgress: TNotifyEvent = nil);
var
  ZStream: TZCompressionStream;
  CompressionLevel: TZCompressionLevel;
begin
  try
    Input.Position := 0;
    
    // Convert our compression level (0-9) to zlib level (zcNone..zcMax)
    // Map 0-9 to zlib levels: 0=None, 1=Fastest, 2-6=Default, 7-9=Max
    if FCompressionLevel = 0 then
      CompressionLevel := zcNone
    else if FCompressionLevel = 1 then
      CompressionLevel := zcFastest
    else if FCompressionLevel >= 7 then
      CompressionLevel := zcMax
    else
      CompressionLevel := zcDefault;
    
    // Create compression stream
    // In Delphi XE8, TZCompressionStream.Create takes CompressionLevel as parameter
    ZStream := TZCompressionStream.Create(Output, CompressionLevel, 15);
    try
      // Copy input to compression stream
      Input.Position := 0;
      ZStream.CopyFrom(Input, Input.Size);
      
      if Assigned(OnProgress) then
        OnProgress(Self);
    finally
      ZStream.Free;
    end;
  except
    on E: Exception do
      raise ESMARTLARKCompressionException.Create('DEFLATE compression failed: ' + E.Message);
  end;
end;

procedure TDeflateCompressor.Decompress(Input: TStream; Output: TStream; OnProgress: TNotifyEvent = nil);
var
  ZStream: TZDecompressionStream;
begin
  try
    Input.Position := 0;
    
    // Create decompression stream
    ZStream := TZDecompressionStream.Create(Input);
    try
      // Copy decompressed data to output
      Output.CopyFrom(ZStream, 0);
      
      if Assigned(OnProgress) then
        OnProgress(Self);
    finally
      ZStream.Free;
    end;
  except
    on E: Exception do
      raise ESMARTLARKCompressionException.Create('DEFLATE decompression failed: ' + E.Message);
  end;
end;

end.


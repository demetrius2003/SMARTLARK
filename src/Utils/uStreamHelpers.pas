unit uStreamHelpers;

interface

uses
  System.SysUtils, System.Classes, Winapi.Windows, uSMARTLARKExceptions;

type
  TStreamHelper = class
  private
    class procedure ReadExact(Stream: TStream; var Buffer; Count: Integer; const Context: string);
  public
    // Write operations
    class procedure WriteByte(Stream: TStream; Value: Byte);
    class procedure WriteWord(Stream: TStream; Value: WORD);
    class procedure WriteDWord(Stream: TStream; Value: DWORD);
    class procedure WriteInt64(Stream: TStream; Value: Int64);
    class procedure WriteString(Stream: TStream; const Value: string);
    class procedure WriteBytes(Stream: TStream; const Data: TBytes);

    // Read operations
    class function ReadByte(Stream: TStream): Byte;
    class function ReadWord(Stream: TStream): WORD;
    class function ReadDWord(Stream: TStream): DWORD;
    class function ReadInt64(Stream: TStream): Int64;
    class function ReadString(Stream: TStream; Length: WORD): string;
    class function ReadBytes(Stream: TStream; Count: Integer): TBytes;

    // Position operations
    class procedure Align(Stream: TStream; Alignment: Integer);
    class function GetPosition(Stream: TStream): Int64;
    class procedure SetPosition(Stream: TStream; Position: Int64);

    // Utility
    class procedure CopyBytes(Source, Dest: TStream; Count: Int64);
  end;

  // Bit writer for output
  TBitWriter = class
  private
    FStream: TStream;
    FBuffer: Byte;
    FBitPosition: Integer;
  public
    constructor Create(Stream: TStream);
    destructor Destroy; override;

    procedure WriteBit(Value: Boolean);
    procedure WriteBits(Value: UInt64; Count: Integer);
    procedure Flush;

    function BytesWritten: Int64;
  end;

  // Bit reader for input
  TBitReader = class
  private
    FStream: TStream;
    FBuffer: Byte;
    FBitPosition: Integer;
    FEOF: Boolean;

    procedure ReadNextByte;
  public
    constructor Create(Stream: TStream);
    destructor Destroy; override;

    function ReadBit: Boolean;
    function ReadBits(Count: Integer): UInt64;
    function IsEOF: Boolean;
  end;

  // Bit-level stream operations for compression
  TBitStream = class
  private
    FStream: TStream;
    FBuffer: Byte;
    FBitPos: Integer;
    FOwnsStream: Boolean;

    procedure FlushBuffer;
  public
    constructor Create(Stream: TStream; OwnsStream: Boolean = False);
    destructor Destroy; override;

    procedure WriteBit(Value: Boolean);
    procedure WriteBits(Value: Integer; Count: Integer);
    function ReadBit: Boolean;
    function ReadBits(Count: Integer): Integer;
    procedure Flush;
    procedure Reset;

    property Stream: TStream read FStream;
    function GetPosition: Int64;
  end;

  // Stream wrapper that enforces a maximum size on writes
  TBoundedStream = class(TStream)
  private
    FBaseStream: TStream;
    FMaxSize: Int64;
    FOwnsStream: Boolean;
  protected
    function GetSize: Int64; override;
  public
    constructor Create(BaseStream: TStream; MaxSize: Int64; OwnsStream: Boolean = False);
    destructor Destroy; override;

    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;
    procedure SetSize(NewSize: Longint); override;
    procedure SetSize(const NewSize: Int64); override;

    property BaseStream: TStream read FBaseStream;
    property MaxSize: Int64 read FMaxSize;
  end;

implementation

{ TBitWriter }

constructor TBitWriter.Create(Stream: TStream);
begin
  inherited Create;
  FStream := Stream;
  FBuffer := 0;
  FBitPosition := 0;
end;

destructor TBitWriter.Destroy;
begin
  Flush;
  inherited;
end;

procedure TBitWriter.WriteBit(Value: Boolean);
begin
  if Value then
    FBuffer := FBuffer or (1 shl FBitPosition);

  Inc(FBitPosition);
  if FBitPosition = 8 then
  begin
    FStream.Write(FBuffer, 1);
    FBuffer := 0;
    FBitPosition := 0;
  end;
end;

procedure TBitWriter.WriteBits(Value: UInt64; Count: Integer);
var
  I: Integer;
begin
  // Write bits from MSB to LSB (most significant bit first)
  for I := Count - 1 downto 0 do
    WriteBit((Value and (UInt64(1) shl I)) <> 0);
end;

procedure TBitWriter.Flush;
begin
  if FBitPosition > 0 then
  begin
    FStream.Write(FBuffer, 1);
    FBuffer := 0;
    FBitPosition := 0;
  end;
end;

function TBitWriter.BytesWritten: Int64;
begin
  Result := FStream.Position;
  if FBitPosition > 0 then
    Inc(Result);
end;

{ TBitReader }

constructor TBitReader.Create(Stream: TStream);
begin
  inherited Create;
  FStream := Stream;
  FBuffer := 0;
  FBitPosition := 8; // Force read on first access
  FEOF := False;
end;

destructor TBitReader.Destroy;
begin
  inherited;
end;

procedure TBitReader.ReadNextByte;
begin
  if FStream.Read(FBuffer, 1) <> 1 then
  begin
    FEOF := True;
    FBuffer := 0;
  end;
  FBitPosition := 0;
end;

function TBitReader.ReadBit: Boolean;
begin
  if FBitPosition >= 8 then
    ReadNextByte;

  if FEOF then
    Result := False
  else
  begin
    Result := (FBuffer and (1 shl FBitPosition)) <> 0;
    Inc(FBitPosition);
  end;
end;

function TBitReader.ReadBits(Count: Integer): UInt64;
var
  I: Integer;
  BitRead: Boolean;
begin
  Result := 0;
  // Read bits from MSB to LSB (most significant bit first)
  for I := Count - 1 downto 0 do
  begin
    BitRead := ReadBit;
    if FEOF and (I > 0) then
      // If we hit EOF before reading all bits, we have incomplete data
      // This should not happen in normal operation, but handle gracefully
      Break;
    if BitRead then
      Result := Result or (UInt64(1) shl I);
  end;
end;

function TBitReader.IsEOF: Boolean;
begin
  Result := FEOF;
end;

{ TStreamHelper }

class procedure TStreamHelper.WriteByte(Stream: TStream; Value: Byte);
begin
  Stream.Write(Value, SizeOf(Byte));
end;

class procedure TStreamHelper.WriteWord(Stream: TStream; Value: WORD);
var
  W: WORD;
begin
  W := Value; // Already little-endian on x86/x64
  Stream.Write(W, SizeOf(WORD));
end;

class procedure TStreamHelper.WriteDWord(Stream: TStream; Value: DWORD);
var
  D: DWORD;
begin
  D := Value;
  Stream.Write(D, SizeOf(DWORD));
end;

class procedure TStreamHelper.WriteInt64(Stream: TStream; Value: Int64);
var
  I: Int64;
begin
  I := Value;
  Stream.Write(I, SizeOf(Int64));
end;

class procedure TStreamHelper.WriteString(Stream: TStream; const Value: string);
var
  Bytes: TBytes;
  Len: WORD;
begin
  Bytes := TEncoding.UTF8.GetBytes(Value);
  Len := Length(Bytes);
  WriteWord(Stream, Len);
  if Len > 0 then
    Stream.Write(Bytes[0], Len);
end;

class procedure TStreamHelper.WriteBytes(Stream: TStream; const Data: TBytes);
begin
  if Length(Data) > 0 then
    Stream.Write(Data[0], Length(Data));
end;

class procedure TStreamHelper.ReadExact(Stream: TStream; var Buffer; Count: Integer; const Context: string);
var
  BytesRead: Integer;
  StartPos: Int64;
begin
  if Count < 0 then
    raise ESMARTLARKFormatException.CreateFmt(
      'Invalid read size: %d for %s. The archive may be corrupted.',
      ecInvalidSizes, [Count, Context]);

  if Count = 0 then
    Exit;

  StartPos := Stream.Position;
  BytesRead := Stream.Read(Buffer, Count);
  if BytesRead <> Count then
    raise ESMARTLARKFormatException.CreateFmt(
      'Unexpected end of stream while reading %s at position %d (expected %d bytes, got %d). The archive may be corrupted.',
      ecArchiveTooSmall, [Context, StartPos, Count, BytesRead]);
end;

class function TStreamHelper.ReadByte(Stream: TStream): Byte;
begin
  ReadExact(Stream, Result, SizeOf(Byte), 'byte');
end;

class function TStreamHelper.ReadWord(Stream: TStream): WORD;
begin
  ReadExact(Stream, Result, SizeOf(WORD), 'word');
end;

class function TStreamHelper.ReadDWord(Stream: TStream): DWORD;
begin
  ReadExact(Stream, Result, SizeOf(DWORD), 'dword');
end;

class function TStreamHelper.ReadInt64(Stream: TStream): Int64;
begin
  ReadExact(Stream, Result, SizeOf(Int64), 'int64');
end;

class function TStreamHelper.ReadString(Stream: TStream; Length: WORD): string;
const
  MAX_STRING_LENGTH = 260; // MAX_PATH
var
  Bytes: TBytes;
  BytesRead: Integer;
begin
  if Length = 0 then
  begin
    Result := '';
    Exit;
  end;
  
  // Prevent excessive memory allocation - use MAX_PATH as limit
  if Length > MAX_STRING_LENGTH then
    raise ESMARTLARKFormatException.CreateFmt(
      'String length too large: %d (max: %d). The archive may be corrupted.', 
      ecInvalidFileName, [Length, MAX_STRING_LENGTH]);
  
  // Check if enough data is available in stream
  if Stream.Position + Length > Stream.Size then
    raise ESMARTLARKFormatException.CreateFmt(
      'Not enough data to read string. Position: %d, Need: %d, Available: %d. The archive may be corrupted.',
      ecInvalidFileName, [Stream.Position, Length, Stream.Size - Stream.Position]);
  
  SetLength(Bytes, Length);
  BytesRead := Stream.Read(Bytes[0], Length);
  
  if BytesRead < Length then
    raise ESMARTLARKFormatException.CreateFmt(
      'Failed to read string: expected %d bytes, got %d. The archive may be corrupted.',
      ecInvalidFileName, [Length, BytesRead]);
  
  Result := TEncoding.UTF8.GetString(Bytes);
end;

class function TStreamHelper.ReadBytes(Stream: TStream; Count: Integer): TBytes;
begin
  if Count < 0 then
    raise ESMARTLARKFormatException.CreateFmt(
      'Invalid byte count: %d. The archive may be corrupted.',
      ecInvalidSizes, [Count]);

  SetLength(Result, Count);
  if Count > 0 then
    ReadExact(Stream, Result[0], Count, 'byte array');
end;

class procedure TStreamHelper.Align(Stream: TStream; Alignment: Integer);
var
  Pos: Int64;
  Padding: Integer;
  Dummy: Byte;
  I: Integer;
begin
  Pos := Stream.Position;
  Padding := (Alignment - (Pos mod Alignment)) mod Alignment;
  for I := 0 to Padding - 1 do
  begin
    Dummy := 0;
    Stream.Write(Dummy, 1);
  end;
end;

class function TStreamHelper.GetPosition(Stream: TStream): Int64;
begin
  Result := Stream.Position;
end;

class procedure TStreamHelper.SetPosition(Stream: TStream; Position: Int64);
begin
  Stream.Position := Position;
end;

class procedure TStreamHelper.CopyBytes(Source, Dest: TStream; Count: Int64);
const
  BUFFER_SIZE = 65536;
var
  Buffer: TBytes;
  BytesRead: Integer;
  RemainingBytes: Int64;
begin
  if Count < 0 then
    raise ESMARTLARKFormatException.CreateFmt(
      'Invalid byte count: %d. The archive may be corrupted.',
      ecInvalidSizes, [Count]);

  if Count = 0 then
    Exit;

  SetLength(Buffer, BUFFER_SIZE);
  RemainingBytes := Count;

  while RemainingBytes > 0 do
  begin
    if RemainingBytes > BUFFER_SIZE then
      BytesRead := Source.Read(Buffer[0], BUFFER_SIZE)
    else
      BytesRead := Source.Read(Buffer[0], RemainingBytes);

    if BytesRead <= 0 then
      raise ESMARTLARKFormatException.CreateFmt(
        'Unexpected end of stream while copying bytes (need %d more bytes). The archive may be corrupted.',
        ecArchiveTooSmall, [RemainingBytes]);

    Dest.Write(Buffer[0], BytesRead);
    Dec(RemainingBytes, BytesRead);
  end;
end;

{ TBitStream }

constructor TBitStream.Create(Stream: TStream; OwnsStream: Boolean = False);
begin
  inherited Create;
  FStream := Stream;
  FOwnsStream := OwnsStream;
  FBuffer := 0;
  FBitPos := 0;
end;

destructor TBitStream.Destroy;
begin
  if FOwnsStream then
    FStream.Free;
  inherited;
end;

procedure TBitStream.FlushBuffer;
begin
  if FBitPos > 0 then
  begin
    TStreamHelper.WriteByte(FStream, FBuffer);
    FBuffer := 0;
    FBitPos := 0;
  end;
end;

procedure TBitStream.WriteBit(Value: Boolean);
begin
  if Value then
    FBuffer := FBuffer or (1 shl FBitPos);

  Inc(FBitPos);
  if FBitPos = 8 then
    FlushBuffer;
end;

procedure TBitStream.WriteBits(Value: Integer; Count: Integer);
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    WriteBit((Value and (1 shl I)) <> 0);
end;

function TBitStream.ReadBit: Boolean;
begin
  if FBitPos = 0 then
  begin
    FBuffer := TStreamHelper.ReadByte(FStream);
    FBitPos := 0;
  end;

  Result := (FBuffer and (1 shl FBitPos)) <> 0;
  Inc(FBitPos);

  if FBitPos = 8 then
    FBitPos := 0;
end;

function TBitStream.ReadBits(Count: Integer): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Count - 1 do
  begin
    if ReadBit then
      Result := Result or (1 shl I);
  end;
end;

procedure TBitStream.Flush;
begin
  FlushBuffer;
end;

procedure TBitStream.Reset;
begin
  FBuffer := 0;
  FBitPos := 0;
end;

function TBitStream.GetPosition: Int64;
begin
  Result := FStream.Position;
end;

{ TBoundedStream }

constructor TBoundedStream.Create(BaseStream: TStream; MaxSize: Int64; OwnsStream: Boolean = False);
begin
  inherited Create;
  FBaseStream := BaseStream;
  FMaxSize := MaxSize;
  FOwnsStream := OwnsStream;
end;

destructor TBoundedStream.Destroy;
begin
  if FOwnsStream then
    FBaseStream.Free;
  inherited;
end;

function TBoundedStream.GetSize: Int64;
begin
  Result := FBaseStream.Size;
end;

function TBoundedStream.Read(var Buffer; Count: Longint): Longint;
begin
  Result := FBaseStream.Read(Buffer, Count);
end;

function TBoundedStream.Write(const Buffer; Count: Longint): Longint;
var
  NewSize: Int64;
begin
  if Count < 0 then
    raise ESMARTLARKFormatException.CreateFmt(
      'Invalid write size: %d. The archive may be corrupted.',
      ecInvalidSizes, [Count]);

  NewSize := FBaseStream.Position + Count;
  if (FMaxSize >= 0) and (NewSize > FMaxSize) then
    raise ESMARTLARKFormatException.CreateFmt(
      'Decompressed data exceeds expected size (%d bytes). The archive may be corrupted.',
      ecInvalidSizes, [FMaxSize]);

  Result := FBaseStream.Write(Buffer, Count);
end;

function TBoundedStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  Result := FBaseStream.Seek(Offset, Origin);
end;

procedure TBoundedStream.SetSize(NewSize: Longint);
begin
  SetSize(Int64(NewSize));
end;

procedure TBoundedStream.SetSize(const NewSize: Int64);
begin
  if (FMaxSize >= 0) and (NewSize > FMaxSize) then
    raise ESMARTLARKFormatException.CreateFmt(
      'Decompressed data exceeds expected size (%d bytes). The archive may be corrupted.',
      ecInvalidSizes, [FMaxSize]);
  FBaseStream.Size := NewSize;
end;

end.

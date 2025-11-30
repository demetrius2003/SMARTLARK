unit uLZ77Compressor;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, Winapi.Windows;

const
  // LZ77 parameters (classic Lempel-Ziv 1977)
  LZ77_MIN_MATCH = 2;        // Minimum match length
  LZ77_MAX_MATCH = 258;      // Maximum match length
  LZ77_WINDOW_BITS = 15;     // 15 bits = 32KB window
  LZ77_WINDOW_SIZE = 1 shl LZ77_WINDOW_BITS; // 32768

type
  // Match found during compression
  TLZ77Match = record
    Distance: Integer;  // Distance back (1-32768)
    Length: Integer;    // Match length (2-258)
  end;

  // Hash chain node for fast match searching
  THashChain = record
    Position: Integer;
    Next: Integer; // Index of next position with same hash
  end;

  // LZ77 Compressor (classic Lempel-Ziv 1977 algorithm)
  // Uses sliding window and encodes (distance, length) pairs
  TLZ77Compressor = class
  private
    FBufferSize: Integer;
    FMaxChainLength: Integer;
    FWindow: TBytes;
    FWindowPos: Integer;
    FWindowFilled: Integer; // How much data in window
    
    // Hash table for quick match finding
    FHashTable: array[0..65535] of Integer; // 64K hash table
    FHashChain: TArray<THashChain>;
    FHashChainPos: Integer;

    function Hash3(const Data: PByte): Integer;
    function FindBestMatch(const Data: PByte; DataSize: Integer; MaxLen: Integer): TLZ77Match;
    procedure InsertHashChain(Pos: Integer);
  public
    constructor Create(BufferSize: Integer = LZ77_WINDOW_SIZE;
      MaxChainLength: Integer = 512);
    destructor Destroy; override;

    procedure Compress(Input: TStream; Output: TStream; OnProgress: TNotifyEvent = nil);
    procedure Decompress(Input: TStream; Output: TStream; OnProgress: TNotifyEvent = nil);

    property WindowFilled: Integer read FWindowFilled;
  end;

implementation

uses
  uStreamHelpers;

{ TLZ77Compressor }

constructor TLZ77Compressor.Create(BufferSize: Integer = LZ77_WINDOW_SIZE;
  MaxChainLength: Integer = 512);
begin
  inherited Create;
  FBufferSize := BufferSize;
  FMaxChainLength := MaxChainLength;
  SetLength(FWindow, FBufferSize);
  FWindowPos := 0;
  FWindowFilled := 0;
  SetLength(FHashChain, FBufferSize);
  FHashChainPos := 0;
  FillChar(FHashTable, SizeOf(FHashTable), $FF); // -1 in all cells
end;

destructor TLZ77Compressor.Destroy;
begin
  SetLength(FWindow, 0);
  SetLength(FHashChain, 0);
  inherited;
end;

function TLZ77Compressor.Hash3(const Data: PByte): Integer;
var
  B1, B2, B3: Byte;
begin
  B1 := Data^;
  B2 := 0;
  B3 := 0;
  
  if FWindowPos + 1 < FWindowFilled then
    B2 := PByte(NativeInt(Data) + 1)^;
  if FWindowPos + 2 < FWindowFilled then
    B3 := PByte(NativeInt(Data) + 2)^;

  Result := ((B1 shl 16) or (B2 shl 8) or B3) and $FFFF;
end;

procedure TLZ77Compressor.InsertHashChain(Pos: Integer);
var
  HashValue: Integer;
begin
  if Pos + 2 >= FWindowFilled then
    Exit;

  HashValue := Hash3(@FWindow[Pos]);
  
  FHashChain[FHashChainPos].Position := Pos;
  FHashChain[FHashChainPos].Next := FHashTable[HashValue];
  FHashTable[HashValue] := FHashChainPos;
  
  FHashChainPos := (FHashChainPos + 1) mod FBufferSize;
end;

function TLZ77Compressor.FindBestMatch(const Data: PByte; DataSize: Integer;
  MaxLen: Integer): TLZ77Match;
var
  HashValue: Integer;
  ChainPos, MatchPos: Integer;
  ChainLen: Integer;
  MatchLen: Integer;
begin
  Result.Distance := 0;
  Result.Length := 0;

  if DataSize < LZ77_MIN_MATCH then
    Exit;

  if MaxLen > LZ77_MAX_MATCH then
    MaxLen := LZ77_MAX_MATCH;
  if MaxLen > DataSize then
    MaxLen := DataSize;

  HashValue := Hash3(Data);
  ChainPos := FHashTable[HashValue];
  ChainLen := 0;

  while (ChainPos >= 0) and (ChainLen < FMaxChainLength) do
  begin
    MatchPos := FHashChain[ChainPos].Position;
    
    // Skip if same position or invalid
    if MatchPos >= FWindowPos then
    begin
      ChainPos := FHashChain[ChainPos].Next;
      Inc(ChainLen);
      Continue;
    end;

    // Quick check: first three bytes must match
    if (FWindow[MatchPos] <> Data^) or
       (FWindow[(MatchPos + 1) mod FBufferSize] <> PByte(NativeInt(Data) + 1)^) or
       (FWindow[(MatchPos + 2) mod FBufferSize] <> PByte(NativeInt(Data) + 2)^) then
    begin
      ChainPos := FHashChain[ChainPos].Next;
      Inc(ChainLen);
      Continue;
    end;

    // Count match length
    MatchLen := 3;
    while (MatchLen < MaxLen) do
    begin
      if FWindow[(MatchPos + MatchLen) mod FBufferSize] <> PByte(NativeInt(Data) + MatchLen)^ then
        Break;
      Inc(MatchLen);
    end;

    // Update best match
    if MatchLen > Result.Length then
    begin
      Result.Length := MatchLen;
      // Distance is 1-based (1 = 1 byte back)
      Result.Distance := (FWindowPos - MatchPos + FBufferSize) mod FBufferSize;
      if Result.Distance = 0 then
        Result.Distance := FBufferSize; // Wrap around
    end;

    if Result.Length >= MaxLen then
      Break;

    ChainPos := FHashChain[ChainPos].Next;
    Inc(ChainLen);
  end;
end;

procedure TLZ77Compressor.Compress(Input: TStream; Output: TStream; OnProgress: TNotifyEvent = nil);
const
  MAX_BLOCK_SIZE = 65536;
var
  InputBuffer: TBytes;
  OutputBuffer: TBytes;
  InputPos: Integer;
  OutputPos: Integer;
  Match: TLZ77Match;
  I, BytesToRead: Integer;
  B: Byte;
  FlagByte: Byte;
  FlagPos: Integer;
  BitPos: Integer;
begin
  SetLength(InputBuffer, MAX_BLOCK_SIZE);
  SetLength(OutputBuffer, MAX_BLOCK_SIZE * 2);

  BytesToRead := Input.Read(InputBuffer[0], MAX_BLOCK_SIZE);

  while BytesToRead > 0 do
  begin
    InputPos := 0;
    FlagPos := 0;
    BitPos := 0;
    FlagByte := 0;

    // Reserve space for flag byte
    OutputPos := 1;

    while InputPos < BytesToRead do
    begin
      // Try to find match
      Match := FindBestMatch(@InputBuffer[InputPos], BytesToRead - InputPos, LZ77_MAX_MATCH);

      if Match.Length >= LZ77_MIN_MATCH then
      begin
        // Write match: (distance, length) pair
        // Flag bit = 1 means match
        FlagByte := FlagByte or (1 shl BitPos);

        // Write distance (15 bits, 1-based)
        if OutputPos + 2 > Length(OutputBuffer) then
          SetLength(OutputBuffer, Length(OutputBuffer) * 2);
        
        // Distance stored as WORD (little-endian)
        PWord(@OutputBuffer[OutputPos])^ := Match.Distance;
        Inc(OutputPos, 2);

        // Length stored as Byte (2-258, so subtract 2)
        OutputBuffer[OutputPos] := Match.Length - LZ77_MIN_MATCH;
        Inc(OutputPos);

        // Copy matched bytes to window
        for I := 0 to Match.Length - 1 do
        begin
          B := InputBuffer[InputPos + I];
          FWindow[FWindowPos] := B;
          FWindowPos := (FWindowPos + 1) mod FBufferSize;
          if FWindowFilled < FBufferSize then
            Inc(FWindowFilled);
          InsertHashChain((FWindowPos - 1 + FBufferSize) mod FBufferSize);
        end;

        Inc(InputPos, Match.Length);
      end
      else
      begin
        // Write literal byte
        // Flag bit = 0 means literal
        // FlagByte remains unchanged (bit is 0)

        if OutputPos >= Length(OutputBuffer) then
          SetLength(OutputBuffer, Length(OutputBuffer) * 2);
        
        OutputBuffer[OutputPos] := InputBuffer[InputPos];
        Inc(OutputPos);

        // Add literal to window
        B := InputBuffer[InputPos];
        FWindow[FWindowPos] := B;
        FWindowPos := (FWindowPos + 1) mod FBufferSize;
        if FWindowFilled < FBufferSize then
          Inc(FWindowFilled);
        InsertHashChain((FWindowPos - 1 + FBufferSize) mod FBufferSize);

        Inc(InputPos);
      end;

      Inc(BitPos);
      if BitPos >= 8 then
      begin
        // Write flag byte and reset
        OutputBuffer[FlagPos] := FlagByte;
        FlagPos := OutputPos;
        OutputPos := OutputPos + 1; // Reserve space for next flag byte
        FlagByte := 0;
        BitPos := 0;
      end;
    end;

    // Write final flag byte if needed
    if BitPos > 0 then
    begin
      OutputBuffer[FlagPos] := FlagByte;
    end
    else
    begin
      // Remove unused flag byte space
      Dec(OutputPos);
    end;

    // Write compressed block
    Output.Write(OutputBuffer[0], OutputPos);

    // Read next block
    BytesToRead := Input.Read(InputBuffer[0], MAX_BLOCK_SIZE);

    if Assigned(OnProgress) then
      OnProgress(Self);
  end;
end;

procedure TLZ77Compressor.Decompress(Input: TStream; Output: TStream; OnProgress: TNotifyEvent = nil);
const
  MAX_BLOCK_SIZE = 65536;
var
  InputBuffer: TBytes;
  OutputBuffer: TBytes;
  InputPos: Integer;
  OutputPos: Integer;
  BytesToRead: Integer;
  FlagByte: Byte;
  BitPos: Integer;
  Distance: Integer;
  MatchLength: Integer;
  MatchPos: Integer;
  I: Integer;
  B: Byte;
begin
  SetLength(InputBuffer, MAX_BLOCK_SIZE);
  SetLength(OutputBuffer, MAX_BLOCK_SIZE * 2);

  FWindowPos := 0;
  FWindowFilled := 0;

  BytesToRead := Input.Read(InputBuffer[0], MAX_BLOCK_SIZE);

  while BytesToRead > 0 do
  begin
    InputPos := 0;
    OutputPos := 0;
    BitPos := 0;
    FlagByte := 0; // Initialize to avoid W1036 warning

    while InputPos < BytesToRead do
    begin
      // Read flag byte every 8 symbols
      if BitPos = 0 then
      begin
        if InputPos >= BytesToRead then
          Break;
        FlagByte := InputBuffer[InputPos];
        Inc(InputPos);
      end;

      // Check flag bit
      if (FlagByte and (1 shl BitPos)) <> 0 then
      begin
        // Match: read (distance, length) pair
        if InputPos + 2 >= BytesToRead then
          Break;

        Distance := PWord(@InputBuffer[InputPos])^;
        Inc(InputPos, 2);

        if InputPos >= BytesToRead then
          Break;

        MatchLength := Integer(InputBuffer[InputPos]) + LZ77_MIN_MATCH;
        Inc(InputPos);

        // Validate distance
        if (Distance < 1) or (Distance > FBufferSize) then
          Distance := 1;
        if Distance > FWindowFilled then
          Distance := FWindowFilled;
        if Distance = 0 then
          Distance := 1;

        // Calculate match position in window
        MatchPos := (FWindowPos - Distance + FBufferSize) mod FBufferSize;

        // Copy match
        for I := 0 to MatchLength - 1 do
        begin
          B := FWindow[(MatchPos + I) mod FBufferSize];
          
          if OutputPos >= Length(OutputBuffer) then
            SetLength(OutputBuffer, Length(OutputBuffer) * 2);
          OutputBuffer[OutputPos] := B;
          Inc(OutputPos);

          // Add to window
          FWindow[FWindowPos] := B;
          FWindowPos := (FWindowPos + 1) mod FBufferSize;
          if FWindowFilled < FBufferSize then
            Inc(FWindowFilled);
        end;
      end
      else
      begin
        // Literal: read byte
        if InputPos >= BytesToRead then
          Break;

        B := InputBuffer[InputPos];
        Inc(InputPos);

        if OutputPos >= Length(OutputBuffer) then
          SetLength(OutputBuffer, Length(OutputBuffer) * 2);
        OutputBuffer[OutputPos] := B;
        Inc(OutputPos);

        // Add to window
        FWindow[FWindowPos] := B;
        FWindowPos := (FWindowPos + 1) mod FBufferSize;
        if FWindowFilled < FBufferSize then
          Inc(FWindowFilled);
      end;

      Inc(BitPos);
      if BitPos >= 8 then
        BitPos := 0;
    end;

    // Write decompressed block
    if OutputPos > 0 then
      Output.Write(OutputBuffer[0], OutputPos);

    // Read next block
    BytesToRead := Input.Read(InputBuffer[0], MAX_BLOCK_SIZE);

    if Assigned(OnProgress) then
      OnProgress(Self);
  end;
end;

end.


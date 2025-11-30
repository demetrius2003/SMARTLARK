unit uLZSSCompressor;

/// <summary>
/// LZSS (Lempel-Ziv-Storer-Szymanski) compression algorithm implementation.
/// </summary>
/// <remarks>
/// <para>
/// LZSS is a dictionary-based compression algorithm that replaces repeated sequences
/// of data with references to previous occurrences. It uses a sliding window of
/// fixed size (4096 bytes) to maintain a dictionary of recently seen data.
/// </para>
/// <para>
/// Algorithm overview:
/// 1. Maintain a sliding window (4096 bytes) of recently processed data
/// 2. For each input position, search for the longest match in the window
/// 3. If match length >= 3, output a (distance, length) pair
/// 4. Otherwise, output the literal byte
/// 5. Update the window by sliding it forward
/// </para>
/// <para>
/// This implementation uses a hash chain for fast match searching, providing
/// O(1) average case lookup time for finding potential matches.
/// </para>
/// <para>
/// Example:
/// Input: "The quick brown fox jumps over the lazy dog. The quick brown fox..."
/// Output: Literals + (distance=40, length=20) for the repeated "The quick brown fox"
/// </para>
/// </remarks>

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, Winapi.Windows;

const
  /// <summary>Minimum match length required for encoding a match (3 bytes).</summary>
  /// <remarks>Matches shorter than this are encoded as literals.</remarks>
  LZSS_MIN_MATCH = 3;
  
  /// <summary>Maximum match length (258 bytes).</summary>
  /// <remarks>Defined by DEFLATE standard for compatibility.</remarks>
  LZSS_MAX_MATCH = 258;
  
  /// <summary>Number of bits for sliding window size (12 bits = 4096 bytes).</summary>
  LZSS_WINDOW_BITS = 12;
  
  /// <summary>Sliding window size: 2^12 = 4096 bytes.</summary>
  LZSS_WINDOW_SIZE = 1 shl LZSS_WINDOW_BITS; // 4096

type
  /// <summary>
  /// Represents a match found during LZSS compression.
  /// </summary>
  TLZSSMatch = record
    /// <summary>Position of the match in the sliding window (0-4095).</summary>
    Position: Integer;
    /// <summary>Length of the match in bytes (3-258).</summary>
    Length: Integer;
  end;

  /// <summary>
  /// Hash chain node for fast match searching in LZSS algorithm.
  /// </summary>
  /// <remarks>
  /// Hash chains allow O(1) average case lookup for finding potential matches
  /// by grouping positions with the same 3-byte hash value.
  /// </remarks>
  THashChain = record
    /// <summary>Position in the input data.</summary>
    Position: Integer;
    /// <summary>Index of next position with the same hash value (chain link).</summary>
    Next: Integer;
  end;

  /// <summary>
  /// LZSS Compressor using hash chain optimization for fast match searching.
  /// </summary>
  /// <remarks>
  /// This compressor implements the LZSS algorithm with the following features:
  /// - Sliding window of 4096 bytes
  /// - Hash chain for O(1) average match lookup
  /// - Minimum match length of 3 bytes
  /// - Maximum match length of 258 bytes
  /// </remarks>
  TLZSSCompressor = class
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

    /// <summary>
    /// Calculates a hash value for the first 3 bytes of data.
    /// </summary>
    /// <param name="Data">Pointer to the data bytes.</param>
    /// <returns>16-bit hash value (0-65535).</returns>
    /// <remarks>
    /// Uses a simple hash function: (byte0 shl 8) or (byte1 shl 4) or byte2.
    /// This provides good distribution for typical data.
    /// </remarks>
    function Hash3(const Data: PByte): Integer;
    
    /// <summary>
    /// Finds the best match for the current position in the input data.
    /// </summary>
    /// <param name="Data">Pointer to the input data.</param>
    /// <param name="DataSize">Total size of input data.</param>
    /// <param name="MaxLen">Maximum length to search for matches.</param>
    /// <returns>TLZSSMatch containing the best match found, or length=0 if no match.</returns>
    /// <remarks>
    /// Searches the sliding window using hash chains to find the longest match.
    /// Limits search to MaxChainLength positions to balance speed and compression ratio.
    /// </remarks>
    function FindBestMatch(const Data: PByte; DataSize: Integer; MaxLen: Integer): TLZSSMatch;
    
    /// <summary>
    /// Inserts a position into the hash chain.
    /// </summary>
    /// <param name="Pos">Position in the input data to insert.</param>
    /// <remarks>
    /// Updates the hash table and chain to include this position for future match searches.
    /// </remarks>
    procedure InsertHashChain(Pos: Integer);
  public
    /// <summary>
    /// Creates a new LZSS compressor instance.
    /// </summary>
    /// <param name="BufferSize">Size of the sliding window (default: 4096).</param>
    /// <param name="MaxChainLength">Maximum chain length for match searching (default: 512).</param>
    /// <remarks>
    /// Larger buffer sizes provide better compression but use more memory.
    /// Longer chains find better matches but are slower.
    /// </remarks>
    constructor Create(BufferSize: Integer = LZSS_WINDOW_SIZE;
      MaxChainLength: Integer = 512);
    
    /// <summary>
    /// Destroys the compressor and releases resources.
    /// </summary>
    destructor Destroy; override;

    /// <summary>
    /// Compresses input data using LZSS algorithm.
    /// </summary>
    /// <param name="Input">Input stream containing data to compress.</param>
    /// <param name="Output">Output stream where compressed data will be written.</param>
    /// <remarks>
    /// The output format consists of:
    /// - Flag bytes (1 bit per symbol: 0=literal, 1=match)
    /// - Literal bytes (for unmatched data)
    /// - Match pairs (distance, length) for matched sequences
    /// </remarks>
    procedure Compress(Input: TStream; Output: TStream);
    procedure Decompress(Input: TStream; Output: TStream);

    property WindowFilled: Integer read FWindowFilled;
  end;

implementation

{ TLZSSCompressor }

constructor TLZSSCompressor.Create(BufferSize: Integer = LZSS_WINDOW_SIZE;
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

destructor TLZSSCompressor.Destroy;
begin
  SetLength(FWindow, 0);
  SetLength(FHashChain, 0);
  inherited;
end;

function TLZSSCompressor.Hash3(const Data: PByte): Integer;
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

procedure TLZSSCompressor.InsertHashChain(Pos: Integer);
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

function TLZSSCompressor.FindBestMatch(const Data: PByte; DataSize: Integer;
  MaxLen: Integer): TLZSSMatch;
var
  HashValue: Integer;
  ChainPos, MatchPos: Integer;
  ChainLen: Integer;
  MatchLen: Integer;
begin
  Result.Position := 0;
  Result.Length := 0;

  if DataSize < LZSS_MIN_MATCH then
    Exit;

  if MaxLen > LZSS_MAX_MATCH then
    MaxLen := LZSS_MAX_MATCH;
  if MaxLen > DataSize then
    MaxLen := DataSize;

  HashValue := Hash3(Data);
  ChainPos := FHashTable[HashValue];
  ChainLen := 0;

  while (ChainPos >= 0) and (ChainLen < FMaxChainLength) do
  begin
    MatchPos := FHashChain[ChainPos].Position;
    
    // Skip if same position
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
      Result.Position := (FWindowPos - MatchPos + FBufferSize) mod FBufferSize;
    end;

    if Result.Length >= MaxLen then
      Break;

    ChainPos := FHashChain[ChainPos].Next;
    Inc(ChainLen);
  end;
end;

procedure TLZSSCompressor.Compress(Input: TStream; Output: TStream);
const
  MAX_BLOCK_SIZE = 65536;
var
  InputBuffer: TBytes;
  OutputBuffer: TBytes;
  InputPos: Integer;
  OutputPos: Integer;
  Match: TLZSSMatch;
  I, BytesToRead: Integer;
  B: Byte;
begin
  SetLength(InputBuffer, MAX_BLOCK_SIZE);
  SetLength(OutputBuffer, MAX_BLOCK_SIZE * 2);

  BytesToRead := Input.Read(InputBuffer[0], MAX_BLOCK_SIZE);

  while BytesToRead > 0 do
  begin
    InputPos := 0;
    OutputPos := 0;

    while InputPos < BytesToRead do
    begin
      // Try to find match
      Match := FindBestMatch(@InputBuffer[InputPos], BytesToRead - InputPos, LZSS_MAX_MATCH);

      if Match.Length >= LZSS_MIN_MATCH then
      begin
        // Write match: flag (1 byte) + position (2 bytes) + length (1 byte)
        OutputBuffer[OutputPos] := $FF; // Match flag
        Inc(OutputPos);
        OutputBuffer[OutputPos] := Match.Position and $FF;
        OutputBuffer[OutputPos + 1] := (Match.Position shr 8) and $0F;
        OutputBuffer[OutputPos + 1] := OutputBuffer[OutputPos + 1] or ((Match.Length - LZSS_MIN_MATCH) shl 4);
        Inc(OutputPos, 2);

        // Add matched bytes to window
        for I := 0 to Match.Length - 1 do
        begin
          FWindow[FWindowPos] := InputBuffer[InputPos + I];
          if FWindowFilled < FBufferSize then
            Inc(FWindowFilled);
          InsertHashChain(FWindowPos);
          FWindowPos := (FWindowPos + 1) mod FBufferSize;
        end;

        Inc(InputPos, Match.Length);
      end
      else
      begin
        // Literal byte
        B := InputBuffer[InputPos];
        if B = $FF then
          OutputBuffer[OutputPos] := $FE // Escape
        else
          OutputBuffer[OutputPos] := B;
        Inc(OutputPos);

        // Add to window
        FWindow[FWindowPos] := B;
        if FWindowFilled < FBufferSize then
          Inc(FWindowFilled);
        InsertHashChain(FWindowPos);
        FWindowPos := (FWindowPos + 1) mod FBufferSize;

        Inc(InputPos);
      end;

      // Check buffer overflow
      if OutputPos > Length(OutputBuffer) - 10 then
        Break;
    end;

    // Write compressed block
    Output.Write(OutputPos, 4);
    if OutputPos > 0 then
      Output.Write(OutputBuffer[0], OutputPos);

    // Read next block
    BytesToRead := Input.Read(InputBuffer[0], MAX_BLOCK_SIZE);
  end;
end;

procedure TLZSSCompressor.Decompress(Input: TStream; Output: TStream);
var
  InputBuffer: TBytes;
  OutputBuffer: TBytes;
  InputPos, InputSize: Integer;
  OutputPos: Integer;
  BlockSize: DWORD;
  B: Byte;
  MatchPos, MatchLen: Integer;
  I: Integer;
begin
  SetLength(InputBuffer, 65536);
  SetLength(OutputBuffer, LZSS_WINDOW_SIZE * 2);
  OutputPos := 0;

  while Input.Position < Input.Size do
  begin
    // Read block size
    if Input.Read(BlockSize, 4) <> 4 then
      Break;

    if BlockSize = 0 then
      Break;

    // Read block data
    InputSize := Input.Read(InputBuffer[0], BlockSize);
    if InputSize = 0 then
      Break;

    InputPos := 0;

    while InputPos < InputSize do
    begin
      B := InputBuffer[InputPos];
      Inc(InputPos);

      if B = $FF then
      begin
        // Match or escaped literal
        if InputPos + 2 > InputSize then
          Break;

        B := InputBuffer[InputPos];
        Inc(InputPos);

        if B = $FE then
        begin
          // Escaped $FF literal
          OutputBuffer[OutputPos] := $FF;
          Inc(OutputPos);
          FWindow[FWindowPos] := $FF;
          FWindowPos := (FWindowPos + 1) mod FBufferSize;
        end
        else
        begin
          // Match
          MatchPos := B or ((InputBuffer[InputPos] and $0F) shl 8);
          MatchLen := ((InputBuffer[InputPos] shr 4) and $0F) + LZSS_MIN_MATCH;
          Inc(InputPos);

          for I := 0 to MatchLen - 1 do
          begin
            B := FWindow[(MatchPos + I) mod FBufferSize];
            OutputBuffer[OutputPos] := B;
            Inc(OutputPos);
            FWindow[FWindowPos] := B;
            FWindowPos := (FWindowPos + 1) mod FBufferSize;

            if OutputPos >= Length(OutputBuffer) - 10 then
            begin
              // Flush output
              Output.Write(OutputBuffer[0], OutputPos);
              OutputPos := 0;
            end;
          end;
        end;
      end
      else
      begin
        // Literal
        OutputBuffer[OutputPos] := B;
        Inc(OutputPos);
        FWindow[FWindowPos] := B;
        FWindowPos := (FWindowPos + 1) mod FBufferSize;

        if OutputPos >= Length(OutputBuffer) - 10 then
        begin
          Output.Write(OutputBuffer[0], OutputPos);
          OutputPos := 0;
        end;
      end;
    end;
  end;

  // Flush remaining output
  if OutputPos > 0 then
    Output.Write(OutputBuffer[0], OutputPos);
end;

end.

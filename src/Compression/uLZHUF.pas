unit uLZHUF;

/// <summary>
/// LZHUF compression codec combining LZSS and adaptive Huffman coding.
/// </summary>
/// <remarks>
/// <para>
/// LZHUF is a two-stage compression algorithm:
/// 1. LZSS stage: Finds repeated sequences and replaces them with (distance, length) pairs
/// 2. Huffman stage: Encodes the LZSS output (literals and matches) using adaptive Huffman coding
/// </para>
/// <para>
/// Algorithm flow:
/// 1. Process input data with LZSS to find matches
/// 2. Output literals and match markers (HUFFMAN_MATCH_MARKER)
/// 3. For matches, output distance (12 bits) and length (4 bits)
/// 4. Encode all output using adaptive Huffman coding
/// 5. Decoder reverses the process: decode Huffman, then reconstruct LZSS
/// </para>
/// <para>
/// This combination provides better compression than LZSS alone, especially for
/// text and structured data with repeated patterns.
/// </para>
/// <para>
/// Example:
/// Input: "The quick brown fox jumps over the lazy dog. The quick brown fox..."
/// LZSS: "The quick brown fox jumps over the lazy dog. " + (distance=40, length=20)
/// Huffman: Encodes each byte and match marker with variable-length codes
/// </para>
/// </remarks>

interface

uses
  System.SysUtils, System.Classes, System.Math, uHuffmanCoding, uStreamHelpers;

const
  /// <summary>Maximum block size for processing (64 KB).</summary>
  LZHUF_MAX_BLOCK_SIZE = 65536;
  
  /// <summary>LZSS sliding window size (4096 bytes).</summary>
  LZSS_WINDOW_SIZE = 4096;
  
  /// <summary>Minimum match length for LZSS (3 bytes).</summary>
  LZSS_MIN_MATCH = 3;
  
  /// <summary>Maximum match length for LZSS in LZHUF (18 bytes).</summary>
  /// <remarks>Smaller than pure LZSS (258) to optimize bit encoding.</remarks>
  LZSS_MAX_MATCH = 18;
  
  /// <summary>Maximum number of positions to search in hash chain (512).</summary>
  LZSS_SEARCH_LIMIT = 512;

type
  /// <summary>
  /// Represents a match found during LZSS compression in LZHUF.
  /// </summary>
  TLZSSMatch = record
    /// <summary>Position of match in sliding window (0-4095).</summary>
    Position: Integer;
    /// <summary>Length of match in bytes (3-18).</summary>
    Length: Integer;
  end;

  /// <summary>
  /// Main LZHUF codec combining LZSS dictionary compression with adaptive Huffman entropy coding.
  /// </summary>
  /// <remarks>
  /// Provides better compression than LZSS alone by encoding the LZSS output
  /// with adaptive Huffman coding, which adapts to the frequency of literals and matches.
  /// </remarks>
  TLZHUFCodec = class
  private
    FHuffmanEncoder: THuffmanEncoder;
    FHuffmanDecoder: THuffmanDecoder;

    /// <summary>
    /// Encodes input data using LZSS and outputs to Huffman encoder.
    /// </summary>
    /// <param name="Input">Input stream with data to compress.</param>
    /// <param name="Output">Output stream for Huffman-encoded data.</param>
    /// <remarks>
    /// Performs LZSS matching and outputs:
    /// - Literal bytes (encoded with Huffman)
    /// - HUFFMAN_MATCH_MARKER (255) followed by distance (12 bits) and length (4 bits)
    /// - HUFFMAN_END_MARKER (254) at the end
    /// </remarks>
    procedure EncodeLZSSToHuffman(Input: TStream; Output: TStream);
    
    /// <summary>
    /// Decodes Huffman-encoded data and reconstructs LZSS output.
    /// </summary>
    /// <param name="Input">Input stream with Huffman-encoded data.</param>
    /// <param name="Output">Output stream for decompressed data.</param>
    /// <remarks>
    /// Reverses the encoding process:
    /// 1. Decode Huffman symbols
    /// 2. For literals: output directly
    /// 3. For HUFFMAN_MATCH_MARKER: read distance and length, copy from window
    /// 4. Stop at HUFFMAN_END_MARKER
    /// </remarks>
    procedure DecodeLZSSFromHuffman(Input: TStream; Output: TStream);
  public
    /// <summary>
    /// Creates a new LZHUF codec instance.
    /// </summary>
    constructor Create;
    
    /// <summary>
    /// Destroys the codec and releases Huffman encoder/decoder.
    /// </summary>
    destructor Destroy; override;

    /// <summary>
    /// Compresses input data using LZHUF algorithm.
    /// </summary>
    /// <param name="Input">Input stream containing data to compress.</param>
    /// <param name="Output">Output stream where compressed data will be written.</param>
    /// <param name="OnProgress">Optional progress callback (called after each block).</param>
    /// <remarks>
    /// Processes data in blocks of up to 64 KB. For each block:
    /// 1. Performs LZSS compression
    /// 2. Encodes output with adaptive Huffman coding
    /// </remarks>
    procedure Compress(Input: TStream; Output: TStream; OnProgress: TNotifyEvent = nil);
    
    /// <summary>
    /// Decompresses LZHUF-compressed data.
    /// </summary>
    /// <param name="Input">Input stream with compressed data.</param>
    /// <param name="Output">Output stream where decompressed data will be written.</param>
    /// <param name="OnProgress">Optional progress callback (called after each block).</param>
    /// <remarks>
    /// Reverses the compression process:
    /// 1. Decodes Huffman-encoded symbols
    /// 2. Reconstructs LZSS matches and literals
    /// 3. Outputs original data
    /// </remarks>
    procedure Decompress(Input: TStream; Output: TStream; OnProgress: TNotifyEvent = nil);
  end;

implementation

{ TLZHUFCodec }

constructor TLZHUFCodec.Create;
begin
  inherited Create;
  FHuffmanEncoder := THuffmanEncoder.Create;
  FHuffmanDecoder := THuffmanDecoder.Create;
end;

destructor TLZHUFCodec.Destroy;
begin
  FHuffmanEncoder.Free;
  FHuffmanDecoder.Free;
  inherited;
end;

procedure TLZHUFCodec.EncodeLZSSToHuffman(Input: TStream; Output: TStream);
var
  InputBuffer: TBytes;
  Window: TBytes;
  WindowPos: Integer;
  WindowFilled: Integer;
  BitWriter: TBitWriter;
  BytesRead, InputPos: Integer;
  Match: TLZSSMatch;
  Code: THuffmanCode;
  I, J: Integer;
  B: Byte;
  MaxLen, MatchLen: Integer;
  SearchLimit: Integer;
  Distance: Integer;
  WindowSearchPos: Integer;
begin
  SetLength(InputBuffer, LZHUF_MAX_BLOCK_SIZE);
  SetLength(Window, LZSS_WINDOW_SIZE);
  WindowPos := 0;
  WindowFilled := 0;
  
  BitWriter := TBitWriter.Create(Output);

  try
    BytesRead := Input.Read(InputBuffer[0], LZHUF_MAX_BLOCK_SIZE);

    while BytesRead > 0 do
    begin
      InputPos := 0;

      while InputPos < BytesRead do
      begin
        Match.Position := 0;
        Match.Length := 0;

        if InputPos + LZSS_MIN_MATCH <= BytesRead then
        begin
          MaxLen := Min(LZSS_MAX_MATCH, BytesRead - InputPos);
          
          // Ограничить поиск для производительности
          // Ищем максимум LZSS_SEARCH_LIMIT последних байтов
          SearchLimit := Min(WindowFilled, LZSS_SEARCH_LIMIT);
          
          // Искать совпадения в последних SearchLimit байтах окна
          for I := 1 to SearchLimit do
          begin
            // Distance - это расстояние назад от текущей позиции
            Distance := I;
            
            // Вычислить начальную позицию в циклическом окне
            WindowSearchPos := (WindowPos - Distance + LZSS_WINDOW_SIZE) mod LZSS_WINDOW_SIZE;
            
            // Подсчитать длину совпадения
            MatchLen := 0;
            while (MatchLen < MaxLen) and 
                  (InputPos + MatchLen < BytesRead) do
            begin
              if Window[(WindowSearchPos + MatchLen) mod LZSS_WINDOW_SIZE] = InputBuffer[InputPos + MatchLen] then
                Inc(MatchLen)
              else
                Break;
            end;

            // Сохранить лучшее совпадение
            if MatchLen >= LZSS_MIN_MATCH then
            begin
              if MatchLen > Match.Length then
              begin
                Match.Length := MatchLen;
                Match.Position := Distance;
              end;
            end;
          end;
        end;

        if Match.Length >= LZSS_MIN_MATCH then
        begin
          // Записать match токен
          Code := FHuffmanEncoder.Encode(255);
          BitWriter.WriteBits(Code.Code, Code.Length);

          // Записать позицию (12 бит) - расстояние назад (1-4095)
          BitWriter.WriteBits(Match.Position, 12);

          // Записать длину - 3 (4 бита: 3-18 = 0-15)
          BitWriter.WriteBits((Match.Length - LZSS_MIN_MATCH) and 15, 4);

          // Добавить все байты совпадения в окно
          for J := 0 to Match.Length - 1 do
          begin
            Window[WindowPos] := InputBuffer[InputPos + J];
            WindowPos := (WindowPos + 1) mod LZSS_WINDOW_SIZE;
            if WindowFilled < LZSS_WINDOW_SIZE then
              Inc(WindowFilled);
          end;

          Inc(InputPos, Match.Length);
        end
        else
        begin
          // Literal байт
          B := InputBuffer[InputPos];
          Code := FHuffmanEncoder.Encode(B);
          BitWriter.WriteBits(Code.Code, Code.Length);

          // Добавить в окно
          Window[WindowPos] := B;
          WindowPos := (WindowPos + 1) mod LZSS_WINDOW_SIZE;
          if WindowFilled < LZSS_WINDOW_SIZE then
            Inc(WindowFilled);

          Inc(InputPos);
        end;
      end;

      BytesRead := Input.Read(InputBuffer[0], LZHUF_MAX_BLOCK_SIZE);
    end;

    // Write end marker
    Code := FHuffmanEncoder.Encode(254);
    BitWriter.WriteBits(Code.Code, Code.Length);
    
    // Flush writes any remaining bits (including padding)
    // This is important - we need to ensure all data is written
    BitWriter.Flush;

  finally
    BitWriter.Free;
    SetLength(InputBuffer, 0);
    SetLength(Window, 0);
  end;
end;

procedure TLZHUFCodec.DecodeLZSSFromHuffman(Input: TStream; Output: TStream);
var
  BitReader: TBitReader;
  OutputBuffer: TBytes;
  OutputPos: Integer;
  Symbol: Byte;
  MatchDistance, MatchLen, MatchStartPos, I: Integer;
  B: Byte;
  Window: TBytes;
  WindowPos: Integer;
  WindowFilled: Integer;
begin
  SetLength(OutputBuffer, LZHUF_MAX_BLOCK_SIZE);
  SetLength(Window, LZSS_WINDOW_SIZE);
  OutputPos := 0;
  WindowPos := 0;
  WindowFilled := 0;
  Symbol := 0; // Initialize to avoid W1036 warning

  BitReader := TBitReader.Create(Input);

  try
    while True do
    begin
      try
        Symbol := FHuffmanDecoder.DecodeSymbol(BitReader);
      except
        Break;
      end;

      if Symbol = 254 then  // End marker - единственный легальный выход
        Break;

      if Symbol = 255 then  // Match
      begin
        MatchDistance := Integer(BitReader.ReadBits(12));
        
        MatchLen := Integer(BitReader.ReadBits(4)) + LZSS_MIN_MATCH;
        MatchStartPos := (WindowPos - MatchDistance + LZSS_WINDOW_SIZE) mod LZSS_WINDOW_SIZE;
        
        for I := 0 to MatchLen - 1 do
        begin
          B := Window[(MatchStartPos + I) mod LZSS_WINDOW_SIZE];
          OutputBuffer[OutputPos] := B;
          Inc(OutputPos);

          Window[WindowPos] := B;
          WindowPos := (WindowPos + 1) mod LZSS_WINDOW_SIZE;
          if WindowFilled < LZSS_WINDOW_SIZE then
            Inc(WindowFilled);

          if OutputPos >= Length(OutputBuffer) - 10 then
          begin
            Output.Write(OutputBuffer[0], OutputPos);
            OutputPos := 0;
          end;
        end;
      end
      else  // Literal
      begin
        B := Symbol;
        OutputBuffer[OutputPos] := B;
        Inc(OutputPos);

        Window[WindowPos] := B;
        WindowPos := (WindowPos + 1) mod LZSS_WINDOW_SIZE;
        if WindowFilled < LZSS_WINDOW_SIZE then
          Inc(WindowFilled);

        if OutputPos >= Length(OutputBuffer) - 10 then
        begin
          Output.Write(OutputBuffer[0], OutputPos);
          OutputPos := 0;
        end;
      end;
    end;

    if OutputPos > 0 then
      Output.Write(OutputBuffer[0], OutputPos);

  finally
    BitReader.Free;
    SetLength(OutputBuffer, 0);
    SetLength(Window, 0);
  end;
end;

procedure TLZHUFCodec.Compress(Input: TStream; Output: TStream;
  OnProgress: TNotifyEvent = nil);
begin
  try
    FHuffmanEncoder.Reset;
    EncodeLZSSToHuffman(Input, Output);

    if Assigned(OnProgress) then
      OnProgress(Self);
  except
    on E: Exception do
      raise Exception.Create('LZHUF Compression failed: ' + E.Message);
  end;
end;

procedure TLZHUFCodec.Decompress(Input: TStream; Output: TStream;
  OnProgress: TNotifyEvent = nil);
begin
  try
    FHuffmanDecoder.Reset;
    DecodeLZSSFromHuffman(Input, Output);

    if Assigned(OnProgress) then
      OnProgress(Self);
  except
    on E: Exception do
      raise Exception.Create('LZHUF Decompression failed: ' + E.Message);
  end;
end;

end.

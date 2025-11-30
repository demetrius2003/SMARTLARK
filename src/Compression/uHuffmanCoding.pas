unit uHuffmanCoding;

/// <summary>
/// Adaptive Huffman coding implementation for entropy encoding.
/// </summary>
/// <remarks>
/// <para>
/// Huffman coding is a lossless data compression algorithm that assigns variable-length
/// binary codes to symbols based on their frequency of occurrence. More frequent symbols
/// get shorter codes, resulting in compression.
/// </para>
/// <para>
/// This implementation uses adaptive Huffman coding, which means:
/// 1. The frequency table is updated as data is processed
/// 2. The Huffman tree is rebuilt periodically to reflect current frequencies
/// 3. No initial frequency table is needed - it adapts to the data
/// </para>
/// <para>
/// Algorithm overview:
/// 1. Initialize frequency table (all symbols start with frequency 1)
/// 2. For each symbol:
///    a. Encode using current Huffman tree
///    b. Update frequency for this symbol
///    c. Rebuild tree if rebuild interval reached
/// 3. Build Huffman tree using frequency table (bottom-up approach)
/// 4. Generate variable-length codes for each symbol
/// </para>
/// <para>
/// Special markers:
/// - Symbol 254 (HUFFMAN_END_MARKER): End of data marker
/// - Symbol 255 (HUFFMAN_MATCH_MARKER): Indicates a match follows (used in LZHUF)
/// </para>
/// <para>
/// Example:
/// Input: "AAAAABBBC"
/// Frequencies: A=5, B=3, C=1
/// Codes: A=0 (1 bit), B=10 (2 bits), C=11 (2 bits)
/// Output: 0 0 0 0 0 10 10 10 11 (9 bits vs 72 bits original)
/// </para>
/// </remarks>

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, uStreamHelpers;

const
  /// <summary>Size of the alphabet (256 possible byte values).</summary>
  HUFFMAN_ALPHABET_SIZE = 256;
  
  /// <summary>Number of symbols processed before rebuilding the Huffman tree.</summary>
  /// <remarks>
  /// Rebuilding too frequently is slow, rebuilding too rarely reduces compression efficiency.
  /// Current value: 4096 symbols (was 256, increased for better performance).
  /// </remarks>
  HUFFMAN_REBUILD_INTERVAL = 4096;
  
  /// <summary>Maximum code length in bits (32 bits).</summary>
  HUFFMAN_MAX_CODE_LENGTH = 32;
  
  /// <summary>Special marker symbol indicating end of data (254).</summary>
  /// <remarks>This symbol is not included in frequency statistics.</remarks>
  HUFFMAN_END_MARKER = 254;
  
  /// <summary>Special marker symbol indicating a match follows (255).</summary>
  /// <remarks>Used in LZHUF to distinguish matches from literals. Not included in frequency statistics.</remarks>
  HUFFMAN_MATCH_MARKER = 255;

type
  /// <summary>
  /// Node in the Huffman binary tree.
  /// </summary>
  /// <remarks>
  /// Internal nodes have Symbol=-1, leaf nodes contain actual symbol values.
  /// Frequency is the sum of frequencies of all symbols in the subtree.
  /// </remarks>
  THuffmanNode = class
  public
    /// <summary>Symbol value (-1 for internal nodes, 0-255 for leaf nodes).</summary>
    Symbol: Integer;
    /// <summary>Frequency count for this node (sum of subtree for internal nodes).</summary>
    Frequency: Integer;
    /// <summary>Left child node (0 bit path).</summary>
    Left: THuffmanNode;
    /// <summary>Right child node (1 bit path).</summary>
    Right: THuffmanNode;

    /// <summary>
    /// Creates a new Huffman node.
    /// </summary>
    /// <param name="ASymbol">Symbol value (-1 for internal nodes).</param>
    /// <param name="AFrequency">Initial frequency (default: 0).</param>
    constructor Create(ASymbol: Integer = -1; AFrequency: Integer = 0);
    
    /// <summary>
    /// Destroys the node and recursively frees child nodes.
    /// </summary>
    destructor Destroy; override;
  end;

  /// <summary>
  /// Represents a Huffman code (variable-length binary code).
  /// </summary>
  THuffmanCode = record
    /// <summary>The binary code value (up to 64 bits).</summary>
    Code: UInt64;
    /// <summary>Length of the code in bits (1-32).</summary>
    Length: Byte;
  end;

  /// <summary>
  /// Adaptive Huffman encoder for compressing data.
  /// </summary>
  /// <remarks>
  /// Maintains a frequency table and periodically rebuilds the Huffman tree
  /// to adapt to changing data characteristics.
  /// </remarks>
  THuffmanEncoder = class
  private
    FFrequencies: array[0..HUFFMAN_ALPHABET_SIZE-1] of Integer;
    FCodes: array[0..HUFFMAN_ALPHABET_SIZE-1] of THuffmanCode;
    FRoot: THuffmanNode;
    FBlockCounter: Integer;

    /// <summary>
    /// Builds a new Huffman tree from the current frequency table.
    /// </summary>
    /// <remarks>
    /// Uses a bottom-up approach: starts with leaf nodes, repeatedly combines
    /// the two nodes with lowest frequency until a single root node remains.
    /// </remarks>
    procedure BuildTree;
    
    /// <summary>
    /// Recursively generates Huffman codes for all symbols in the tree.
    /// </summary>
    /// <param name="Node">Current node in the tree.</param>
    /// <param name="Code">Current code value (accumulated bits).</param>
    /// <param name="Length">Current code length in bits.</param>
    /// <remarks>
    /// Traverses the tree depth-first, assigning codes: left=0, right=1.
    /// </remarks>
    procedure GenerateCodes(Node: THuffmanNode; Code: UInt64; Length: Byte);
  public
    /// <summary>
    /// Creates a new Huffman encoder with initialized frequency table.
    /// </summary>
    /// <remarks>
    /// All symbols (0-253) are initialized with frequency 1.
    /// Special markers (254, 255) are initialized with frequency 0.
    /// </remarks>
    constructor Create;
    
    /// <summary>
    /// Destroys the encoder and releases the Huffman tree.
    /// </summary>
    destructor Destroy; override;

    /// <summary>
    /// Resets the encoder to initial state.
    /// </summary>
    /// <remarks>
    /// Clears frequency table and rebuilds the Huffman tree.
    /// </remarks>
    procedure Reset;
    
    /// <summary>
    /// Updates the frequency count for a symbol.
    /// </summary>
    /// <param name="Symbol">Symbol to update (0-253, not including markers).</param>
    /// <remarks>
    /// Increments the frequency and triggers tree rebuild if rebuild interval is reached.
    /// Special markers (254, 255) are not updated.
    /// </remarks>
    procedure Update(Symbol: Byte);
    
    /// <summary>
    /// Encodes a symbol using the current Huffman tree.
    /// </summary>
    /// <param name="Symbol">Symbol to encode (0-255).</param>
    /// <returns>Huffman code for the symbol.</returns>
    /// <remarks>
    /// Updates frequency and rebuilds tree if needed. Special markers are not updated.
    /// </remarks>
    function Encode(Symbol: Byte): THuffmanCode;
    
    /// <summary>
    /// Forces a rebuild of the Huffman tree.
    /// </summary>
    /// <remarks>
    /// Useful when you want to ensure the tree reflects current frequencies
    /// before encoding a batch of data.
    /// </remarks>
    procedure RebuildTree;
    
    /// <summary>
    /// Gets the Huffman code for a symbol without updating frequencies.
    /// </summary>
    /// <param name="Symbol">Symbol to get code for (0-255).</param>
    /// <returns>Huffman code for the symbol.</returns>
    /// <remarks>
    /// Does not update frequency or trigger tree rebuild. Use for read-only access.
    /// </remarks>
    function GetCode(Symbol: Byte): THuffmanCode;

    function GetFrequency(Index: Integer): Integer;
    property BlockCounter: Integer read FBlockCounter;
  end;

  THuffmanDecoder = class
  private
    FFrequencies: array[0..HUFFMAN_ALPHABET_SIZE-1] of Integer;
    FRoot: THuffmanNode;
    FBlockCounter: Integer;

    procedure BuildTree;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Reset;
    procedure Update(Symbol: Byte);
    function DecodeSymbol(Reader: TBitReader): Byte;
    procedure RebuildTree;

    function GetFrequency(Index: Integer): Integer;
    property BlockCounter: Integer read FBlockCounter;
  end;

implementation

{ THuffmanNode }

constructor THuffmanNode.Create(ASymbol: Integer; AFrequency: Integer);
begin
  inherited Create;
  Symbol := ASymbol;
  Frequency := AFrequency;
  Left := nil;
  Right := nil;
end;

destructor THuffmanNode.Destroy;
begin
  FreeAndNil(Left);
  FreeAndNil(Right);
  inherited;
end;

{ THuffmanEncoder }

constructor THuffmanEncoder.Create;
var
  I: Integer;
begin
  inherited Create;
  FRoot := nil;
  FBlockCounter := 0;

  for I := 0 to HUFFMAN_ALPHABET_SIZE - 1 do
  begin
    FFrequencies[I] := 1;
    FCodes[I].Code := 0;
    FCodes[I].Length := 0;
  end;

  BuildTree;
end;

destructor THuffmanEncoder.Destroy;
begin
  FreeAndNil(FRoot);
  inherited;
end;

procedure THuffmanEncoder.BuildTree;
var
  Nodes: TList<THuffmanNode>;
  Node1, Node2, Parent: THuffmanNode;
  NewRoot: THuffmanNode;
  I, J: Integer;
  Temp: THuffmanNode;
begin
  // ВАЖНО: Создаём новое дерево ПЕРЕД освобождением старого!
  // Если создание упадёт, старое дерево останется валидным
  Nodes := TList<THuffmanNode>.Create;
  try
    // Create leaf nodes
    for I := 0 to HUFFMAN_ALPHABET_SIZE - 1 do
    begin
      Node1 := THuffmanNode.Create(I, FFrequencies[I]);
      Nodes.Add(Node1);
    end;

    // Build tree
    while Nodes.Count > 1 do
    begin
      // Simple bubble sort for frequency
      for I := 0 to Nodes.Count - 2 do
        for J := I + 1 to Nodes.Count - 1 do
          if Nodes[I].Frequency > Nodes[J].Frequency then
          begin
            Temp := Nodes[I];
            Nodes[I] := Nodes[J];
            Nodes[J] := Temp;
          end;

      Node1 := Nodes[0];
      Node2 := Nodes[1];

      Nodes.Delete(0);
      Nodes.Delete(0);

      Parent := THuffmanNode.Create(-1, Node1.Frequency + Node2.Frequency);
      Parent.Left := Node1;
      Parent.Right := Node2;

      Nodes.Add(Parent);
    end;

    if Nodes.Count > 0 then
      NewRoot := Nodes[0]
    else
      NewRoot := THuffmanNode.Create(-1, 0);

  finally
    Nodes.Free;
  end;

  // Только ПОСЛЕ успешного создания нового дерева освобождаем старое
  if FRoot <> nil then
    FreeAndNil(FRoot);
  
  // NewRoot is always assigned (either from Nodes[0] or created), so use it directly
  FRoot := NewRoot;

  FillChar(FCodes, SizeOf(FCodes), 0);
  GenerateCodes(FRoot, 0, 0);
end;

procedure THuffmanEncoder.GenerateCodes(Node: THuffmanNode; Code: UInt64; Length: Byte);
begin
  if Node = nil then
    Exit;

  if Node.Symbol >= 0 then
  begin
    FCodes[Node.Symbol].Code := Code;
    FCodes[Node.Symbol].Length := Length;
  end
  else
  begin
    if Node.Left <> nil then
      GenerateCodes(Node.Left, Code shl 1, Length + 1);
    if Node.Right <> nil then
      GenerateCodes(Node.Right, (Code shl 1) or 1, Length + 1);
  end;
end;

procedure THuffmanEncoder.Reset;
var
  I: Integer;
begin
  for I := 0 to HUFFMAN_ALPHABET_SIZE - 1 do
    FFrequencies[I] := 1;

  FBlockCounter := 0;
  BuildTree;
end;

procedure THuffmanEncoder.Update(Symbol: Byte);
begin
  Inc(FFrequencies[Symbol]);
  Inc(FBlockCounter);

  if FBlockCounter mod HUFFMAN_REBUILD_INTERVAL = 0 then
    RebuildTree;
end;

function THuffmanEncoder.Encode(Symbol: Byte): THuffmanCode;
begin
  // Берём код из текущего дерева и обновляем счётчики только для обычных символов
  Result := FCodes[Symbol];
  if (Symbol <> HUFFMAN_END_MARKER) and (Symbol <> HUFFMAN_MATCH_MARKER) then
    Update(Symbol);
end;

procedure THuffmanEncoder.RebuildTree;
begin
  BuildTree;
end;

function THuffmanEncoder.GetCode(Symbol: Byte): THuffmanCode;
begin
  Result := FCodes[Symbol];
end;

function THuffmanEncoder.GetFrequency(Index: Integer): Integer;
begin
  if (Index >= 0) and (Index < HUFFMAN_ALPHABET_SIZE) then
    Result := FFrequencies[Index]
  else
    Result := 0;
end;

{ THuffmanDecoder }

constructor THuffmanDecoder.Create;
var
  I: Integer;
begin
  inherited Create;
  FRoot := nil;
  FBlockCounter := 0;

  for I := 0 to HUFFMAN_ALPHABET_SIZE - 1 do
    FFrequencies[I] := 1;

  BuildTree;
end;

destructor THuffmanDecoder.Destroy;
begin
  FreeAndNil(FRoot);
  inherited;
end;

procedure THuffmanDecoder.BuildTree;
var
  Nodes: TList<THuffmanNode>;
  Node1, Node2, Parent: THuffmanNode;
  NewRoot: THuffmanNode;
  I, J: Integer;
  Temp: THuffmanNode;
begin
  // ВАЖНО: Создаём новое дерево ПЕРЕД освобождением старого!
  Nodes := TList<THuffmanNode>.Create;
  try
    for I := 0 to HUFFMAN_ALPHABET_SIZE - 1 do
    begin
      Node1 := THuffmanNode.Create(I, FFrequencies[I]);
      Nodes.Add(Node1);
    end;

    while Nodes.Count > 1 do
    begin
      // Simple bubble sort for frequency
      for I := 0 to Nodes.Count - 2 do
        for J := I + 1 to Nodes.Count - 1 do
          if Nodes[I].Frequency > Nodes[J].Frequency then
          begin
            Temp := Nodes[I];
            Nodes[I] := Nodes[J];
            Nodes[J] := Temp;
          end;

      Node1 := Nodes[0];
      Node2 := Nodes[1];

      Nodes.Delete(0);
      Nodes.Delete(0);

      Parent := THuffmanNode.Create(-1, Node1.Frequency + Node2.Frequency);
      Parent.Left := Node1;
      Parent.Right := Node2;

      Nodes.Add(Parent);
    end;

    if Nodes.Count > 0 then
      NewRoot := Nodes[0]
    else
      NewRoot := THuffmanNode.Create(-1, 0);

  finally
    Nodes.Free;
  end;

  // Только ПОСЛЕ успешного создания освобождаем старое дерево
  if FRoot <> nil then
    FreeAndNil(FRoot);
  
  // NewRoot is always assigned (either from Nodes[0] or created), so use it directly
  FRoot := NewRoot;
end;

procedure THuffmanDecoder.Reset;
var
  I: Integer;
begin
  for I := 0 to HUFFMAN_ALPHABET_SIZE - 1 do
    FFrequencies[I] := 1;

  FBlockCounter := 0;
  BuildTree;
end;

procedure THuffmanDecoder.Update(Symbol: Byte);
begin
  Inc(FFrequencies[Symbol]);
  Inc(FBlockCounter);

  if FBlockCounter mod HUFFMAN_REBUILD_INTERVAL = 0 then
    RebuildTree;
end;

function THuffmanDecoder.GetFrequency(Index: Integer): Integer;
begin
  if (Index >= 0) and (Index < HUFFMAN_ALPHABET_SIZE) then
    Result := FFrequencies[Index]
  else
    Result := 0;
end;

function THuffmanDecoder.DecodeSymbol(Reader: TBitReader): Byte;
var
  Current: THuffmanNode;
begin
  Current := FRoot;

  while Current.Symbol < 0 do
  begin
    if Reader.IsEOF then
    begin
      Result := 0;
      Exit;
    end;
      
    if Reader.ReadBit then
      Current := Current.Right
    else
      Current := Current.Left;

    if Current = nil then
    begin
      Result := 0;
      Exit;
    end;
  end;

  Result := Current.Symbol;
  if (Result <> HUFFMAN_END_MARKER) and (Result <> HUFFMAN_MATCH_MARKER) then
    Update(Result);
end;

procedure THuffmanDecoder.RebuildTree;
begin
  BuildTree;
end;

end.
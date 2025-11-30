unit uLZSSTest;

interface

uses
  System.SysUtils, System.Classes, uLZSSCompressor;

type
  TLZSSTest = class
  public
    class procedure RunAllTests;
    class procedure TestBasicCompression;
    class procedure TestTextData;
    class procedure TestRepetitiveData;
    class procedure TestRoundTrip;
  end;

implementation

{ TLZSSTest }

class procedure TLZSSTest.RunAllTests;
begin
  WriteLn('');
  WriteLn('=== LZSS Compression Tests ===');
  WriteLn('');

  try
    TestBasicCompression;
    TestTextData;
    TestRepetitiveData;
    TestRoundTrip;
    WriteLn('');
    WriteLn('✓ All tests completed!');
  except
    on E: Exception do
      WriteLn('✗ Test failed: ' + E.Message);
  end;
end;

class procedure TLZSSTest.TestBasicCompression;
const
  TEST_DATA = 'The quick brown fox jumps over the lazy dog. ' +
              'The quick brown fox jumps over the lazy dog.';
var
  Compressor: TLZSSCompressor;
  Input, Output: TMemoryStream;
  Ratio: Double;
begin
  WriteLn('[Test 1] Basic Compression Test');
  WriteLn('Input: ' + TEST_DATA);

  Compressor := TLZSSCompressor.Create;
  Input := TMemoryStream.Create;
  Output := TMemoryStream.Create;

  try
    // Write test data to input stream
    Input.Write(PChar(TEST_DATA)^, Length(TEST_DATA));
    Input.Position := 0;

    // Compress
    Compressor.Compress(Input, Output);

    Ratio := (Output.Size * 100.0) / Input.Size;

    WriteLn(Format('Input size: %d bytes', [Input.Size]));
    WriteLn(Format('Output size: %d bytes', [Output.Size]));
    WriteLn(Format('Compression ratio: %.1f%%', [Ratio]));

    if Output.Size < Input.Size then
      WriteLn('✓ Compression successful')
    else
      WriteLn('✗ No compression achieved');

  finally
    Compressor.Free;
    Input.Free;
    Output.Free;
  end;

  WriteLn('');
end;

class procedure TLZSSTest.TestTextData;
const
  TEST_DATA = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. ' +
              'Lorem ipsum dolor sit amet, consectetur adipiscing elit. ' +
              'Lorem ipsum dolor sit amet, consectetur adipiscing elit.';
var
  Compressor: TLZSSCompressor;
  Input, Output: TMemoryStream;
  Ratio: Double;
begin
  WriteLn('[Test 2] Text Data Compression');

  Compressor := TLZSSCompressor.Create;
  Input := TMemoryStream.Create;
  Output := TMemoryStream.Create;

  try
    Input.Write(PChar(TEST_DATA)^, Length(TEST_DATA));
    Input.Position := 0;

    Compressor.Compress(Input, Output);

    Ratio := (Output.Size * 100.0) / Input.Size;

    WriteLn(Format('Input: %d bytes | Output: %d bytes | Ratio: %.1f%%',
      [Input.Size, Output.Size, Ratio]));

    if Ratio < 70 then
      WriteLn('✓ Good compression ratio for text')
    else
      WriteLn('⚠ Compression ratio could be better');

  finally
    Compressor.Free;
    Input.Free;
    Output.Free;
  end;

  WriteLn('');
end;

class procedure TLZSSTest.TestRepetitiveData;
var
  Compressor: TLZSSCompressor;
  Input, Output: TMemoryStream;
  I: Integer;
  B: Byte;
  Ratio: Double;
begin
  WriteLn('[Test 3] Repetitive Data Compression');

  Compressor := TLZSSCompressor.Create;
  Input := TMemoryStream.Create;
  Output := TMemoryStream.Create;

  try
    // Generate repetitive data (AAABBBCCCDDD...etc)
    for I := 0 to 999 do
    begin
      B := (I mod 26) + Ord('A');
      Input.Write(B, 1);
      Input.Write(B, 1);
      Input.Write(B, 1);
    end;

    Input.Position := 0;
    Compressor.Compress(Input, Output);

    Ratio := (Output.Size * 100.0) / Input.Size;

    WriteLn(Format('Input: %d bytes | Output: %d bytes | Ratio: %.1f%%',
      [Input.Size, Output.Size, Ratio]));

    if Ratio < 30 then
      WriteLn('✓ Excellent compression for repetitive data')
    else if Ratio < 50 then
      WriteLn('✓ Good compression for repetitive data')
    else
      WriteLn('⚠ Compression could be better');

  finally
    Compressor.Free;
    Input.Free;
    Output.Free;
  end;

  WriteLn('');
end;

class procedure TLZSSTest.TestRoundTrip;
const
  TEST_DATA = 'The quick brown fox jumps over the lazy dog. ' +
              'Pack my box with five dozen liquor jugs. ' +
              'How vexingly quick daft zebras jump!';
var
  Compressor, Decompressor: TLZSSCompressor;
  Input, Compressed, Decompressed: TMemoryStream;
  InputBytes, OutputBytes: TBytes;
  Match: Boolean;
  I: Integer;
begin
  WriteLn('[Test 4] Compress/Decompress Round-Trip');

  Compressor := TLZSSCompressor.Create;
  Decompressor := TLZSSCompressor.Create;
  Input := TMemoryStream.Create;
  Compressed := TMemoryStream.Create;
  Decompressed := TMemoryStream.Create;

  try
    // Write original data
    Input.Write(PChar(TEST_DATA)^, Length(TEST_DATA));
    Input.Position := 0;

    // Compress
    Compressor.Compress(Input, Compressed);

    // Decompress
    Compressed.Position := 0;
    Decompressor.Decompress(Compressed, Decompressed);

    // Compare
    if Input.Size = Decompressed.Size then
    begin
      Input.Position := 0;
      Decompressed.Position := 0;

      SetLength(InputBytes, Input.Size);
      SetLength(OutputBytes, Decompressed.Size);

      Input.Read(InputBytes[0], Length(InputBytes));
      Decompressed.Read(OutputBytes[0], Length(OutputBytes));

      Match := CompareMem(@InputBytes[0], @OutputBytes[0], Length(InputBytes));

      WriteLn(Format('Original size: %d bytes', [Input.Size]));
      WriteLn(Format('Compressed size: %d bytes', [Compressed.Size]));
      WriteLn(Format('Decompressed size: %d bytes', [Decompressed.Size]));

      if Match then
        WriteLn('✓ Round-trip compression/decompression successful!')
      else
        WriteLn('✗ Data mismatch after decompression');
    end
    else
    begin
      WriteLn(Format('✗ Size mismatch: Original %d, Decompressed %d',
        [Input.Size, Decompressed.Size]));
    end;

  finally
    Compressor.Free;
    Decompressor.Free;
    Input.Free;
    Compressed.Free;
    Decompressed.Free;
  end;

  WriteLn('');
end;

end.

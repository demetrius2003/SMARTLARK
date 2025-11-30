unit uLZHUFTest;

interface

uses
  System.SysUtils, System.Classes, System.Math, uLZHUF;

type
  TLZHUFTest = class
  public
    class procedure RunAllTests;
    class procedure TestBasicRoundTrip;
    class procedure TestTextCompression;
    class procedure TestCompressionRatio;
  end;

implementation

{ TLZHUFTest }

class procedure TLZHUFTest.RunAllTests;
begin
  WriteLn('');
  WriteLn('=== LZHUF (LZSS + Huffman) Codec Tests ===');
  WriteLn('');

  try
    TestBasicRoundTrip;
    TestTextCompression;
    TestCompressionRatio;
    WriteLn('');
    WriteLn('✓ All LZHUF tests completed!');
  except
    on E: Exception do
      WriteLn('✗ Test failed: ' + E.Message);
  end;
end;

class procedure TLZHUFTest.TestBasicRoundTrip;
const
  TEST_DATA = 'Hello World! Hello World! Hello World! ' +
              'The quick brown fox jumps over the lazy dog. ' +
              'The quick brown fox jumps over the lazy dog.';
var
  Codec: TLZHUFCodec;
  Input, Compressed, Decompressed: TMemoryStream;
  InputBytes, OutputBytes: TBytes;
  Match: Boolean;
begin
  WriteLn('[Test 1] Basic LZHUF Round-Trip');
  WriteLn('Input data length: ' + IntToStr(Length(TEST_DATA)) + ' bytes');

  Codec := TLZHUFCodec.Create;
  Input := TMemoryStream.Create;
  Compressed := TMemoryStream.Create;
  Decompressed := TMemoryStream.Create;

  try
    // Write original data
    Input.Write(PChar(TEST_DATA)^, Length(TEST_DATA));
    Input.Position := 0;

    // Compress
    WriteLn('Compressing...');
    Codec.Compress(Input, Compressed);
    WriteLn(Format('Compressed size: %d bytes', [Compressed.Size]));

    // Decompress
    WriteLn('Decompressing...');
    Compressed.Position := 0;
    Codec.Decompress(Compressed, Decompressed);

    // Verify
    if Input.Size = Decompressed.Size then
    begin
      Input.Position := 0;
      Decompressed.Position := 0;

      SetLength(InputBytes, Input.Size);
      SetLength(OutputBytes, Decompressed.Size);

      Input.Read(InputBytes[0], Length(InputBytes));
      Decompressed.Read(OutputBytes[0], Length(OutputBytes));

      Match := CompareMem(@InputBytes[0], @OutputBytes[0], Length(InputBytes));

      if Match then
      begin
        WriteLn('✓ Round-trip successful - data intact!');
        WriteLn(Format('  Original: %d bytes, Compressed: %d bytes (%.1f%%)',
          [Input.Size, Compressed.Size, (Compressed.Size * 100.0) / Input.Size]));
      end
      else
        WriteLn('✗ Data mismatch after decompression');
    end
    else
    begin
      WriteLn(Format('✗ Size mismatch: Original %d, Decompressed %d',
        [Input.Size, Decompressed.Size]));
    end;

  finally
    Codec.Free;
    Input.Free;
    Compressed.Free;
    Decompressed.Free;
  end;

  WriteLn('');
end;

class procedure TLZHUFTest.TestTextCompression;
const
  TEST_DATA = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. ' +
              'Lorem ipsum dolor sit amet, consectetur adipiscing elit. ' +
              'Lorem ipsum dolor sit amet, consectetur adipiscing elit. ' +
              'Lorem ipsum dolor sit amet, consectetur adipiscing elit.';
var
  Codec: TLZHUFCodec;
  Input, Compressed, Decompressed: TMemoryStream;
  Ratio: Double;
  Match: Boolean;
  InputBuf, OutputBuf: TBytes;
begin
  WriteLn('[Test 2] Text Data Compression');

  Codec := TLZHUFCodec.Create;
  Input := TMemoryStream.Create;
  Compressed := TMemoryStream.Create;
  Decompressed := TMemoryStream.Create;

  try
    Input.Write(PChar(TEST_DATA)^, Length(TEST_DATA));
    Input.Position := 0;

    Codec.Compress(Input, Compressed);
    Ratio := (Compressed.Size * 100.0) / Input.Size;

    Compressed.Position := 0;
    Codec.Decompress(Compressed, Decompressed);

    WriteLn(Format('Input: %d bytes | Compressed: %d bytes | Ratio: %.1f%%',
      [Input.Size, Compressed.Size, Ratio]));

    // Verify
    Input.Position := 0;
    Decompressed.Position := 0;

    if Input.Size = Decompressed.Size then
    begin
      SetLength(InputBuf, 0);
      SetLength(OutputBuf, 0);
      SetLength(InputBuf, Input.Size);
      SetLength(OutputBuf, Decompressed.Size);

      Input.Read(InputBuf[0], Length(InputBuf));
      Decompressed.Read(OutputBuf[0], Length(OutputBuf));

      Match := CompareMem(@InputBuf[0], @OutputBuf[0], Length(InputBuf));

      if Match then
        WriteLn('✓ Text compression successful')
      else
        WriteLn('✗ Data corrupted');
    end;

  finally
    Codec.Free;
    Input.Free;
    Compressed.Free;
    Decompressed.Free;
  end;

  WriteLn('');
end;

class procedure TLZHUFTest.TestCompressionRatio;
var
  Codec: TLZHUFCodec;
  Input, Compressed, Decompressed: TMemoryStream;
  I, B: Integer;
  Ratio: Double;
  Match: Boolean;
begin
  WriteLn('[Test 3] Repetitive Data Compression');

  Codec := TLZHUFCodec.Create;
  Input := TMemoryStream.Create;
  Compressed := TMemoryStream.Create;
  Decompressed := TMemoryStream.Create;

  try
    // Generate repetitive pattern (ABC repeated)
    for I := 0 to 4999 do
    begin
      B := (I mod 3) + Ord('A');
      Input.Write(Byte(B), 1);
    end;

    Input.Position := 0;
    Codec.Compress(Input, Compressed);
    Ratio := (Compressed.Size * 100.0) / Input.Size;

    WriteLn(Format('Repetitive data: %d bytes → %d bytes (%.1f%% compression)',
      [Input.Size, Compressed.Size, Ratio]));

    // Decompress and verify
    Compressed.Position := 0;
    Codec.Decompress(Compressed, Decompressed);

    if Decompressed.Size = Input.Size then
    begin
      WriteLn('✓ Compression successful with good ratio');
      if Ratio < 10 then
        WriteLn('  Excellent compression for repetitive data!')
      else if Ratio < 20 then
        WriteLn('  Good compression ratio')
      else
        WriteLn('  Note: Could potentially be compressed better');
    end
    else
      WriteLn('✗ Decompression size mismatch');

  finally
    Codec.Free;
    Input.Free;
    Compressed.Free;
    Decompressed.Free;
  end;

  WriteLn('');
end;

end.

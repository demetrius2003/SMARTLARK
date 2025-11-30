unit uDeflateTest;

interface

uses
  System.SysUtils, System.Classes, System.Math, uDeflateCompressor;

type
  TDeflateTest = class
  public
    class procedure RunAllTests;
    class procedure TestRoundTrip;
    class procedure TestCompressionLevels;
  end;

implementation

{ TDeflateTest }

class procedure TDeflateTest.RunAllTests;
begin
  WriteLn('');
  WriteLn('=== DEFLATE (Zlib) Tests ===');
  WriteLn('');

  try
    TestRoundTrip;
    TestCompressionLevels;
    WriteLn('');
    WriteLn('✓ DEFLATE tests completed!');
  except
    on E: Exception do
      WriteLn('✗ DEFLATE test failed: ' + E.Message);
  end;
end;

class procedure TDeflateTest.TestRoundTrip;
const
  TEST_DATA = 'DEFLATE compression round-trip test. ' +
              'The quick brown fox jumps over the lazy dog. ' +
              'Pack my box with five dozen liquor jugs.';
var
  Codec: TDeflateCompressor;
  Input, Compressed, Decompressed: TMemoryStream;
  InputBytes, OutputBytes: TBytes;
  Match: Boolean;
begin
  WriteLn('[DEFLATE] Round-trip verification');

  Codec := TDeflateCompressor.Create(6);
  Input := TMemoryStream.Create;
  Compressed := TMemoryStream.Create;
  Decompressed := TMemoryStream.Create;
  try
    Input.WriteBuffer(TEST_DATA[1], Length(TEST_DATA));
    Input.Position := 0;

    Codec.Compress(Input, Compressed);
    WriteLn(Format('  Original: %d bytes, Compressed: %d bytes',
      [Input.Size, Compressed.Size]));

    Compressed.Position := 0;
    Codec.Decompress(Compressed, Decompressed);

    if Input.Size = Decompressed.Size then
    begin
      SetLength(InputBytes, Input.Size);
      SetLength(OutputBytes, Decompressed.Size);
      Input.Position := 0;
      Decompressed.Position := 0;
      Input.ReadBuffer(InputBytes[0], Length(InputBytes));
      Decompressed.ReadBuffer(OutputBytes[0], Length(OutputBytes));
      Match := CompareMem(@InputBytes[0], @OutputBytes[0], Length(InputBytes));
      if Match then
        WriteLn('  ✓ Round-trip successful')
      else
        WriteLn('  ✗ Data mismatch after decompression');
    end
    else
      WriteLn(Format('  ✗ Size mismatch: %d <> %d', [Input.Size, Decompressed.Size]));
  finally
    Codec.Free;
    Input.Free;
    Compressed.Free;
    Decompressed.Free;
  end;

  WriteLn('');
end;

class procedure TDeflateTest.TestCompressionLevels;
const
  TEST_DATA = 'Lorem ipsum dolor sit amet, consectetur adipiscing elit. ' +
              'Integer nec odio. Praesent libero. Sed cursus ante dapibus diam. ' +
              'Sed nisi. Nulla quis sem at nibh elementum imperdiet.';
  LEVELS: array[0..2] of Integer = (1, 5, 9);
var
  Level: Integer;
  Codec: TDeflateCompressor;
  Input, Output: TMemoryStream;
  Ratio: Double;
  Idx: Integer;
begin
  WriteLn('[DEFLATE] Compression levels comparison');

  Codec := TDeflateCompressor.Create;
  Input := TMemoryStream.Create;
  Output := TMemoryStream.Create;
  try
    Input.WriteBuffer(TEST_DATA[1], Length(TEST_DATA));

    for Idx := Low(LEVELS) to High(LEVELS) do
    begin
      Level := LEVELS[Idx];
      Codec.CompressionLevel := Level;
      Input.Position := 0;
      Output.Size := 0;
      Codec.Compress(Input, Output);
      Ratio := (Output.Size * 100.0) / Input.Size;
      WriteLn(Format('  Level %d → %d bytes (%.1f%%)',
        [Level, Output.Size, Ratio]));
    end;
  finally
    Codec.Free;
    Input.Free;
    Output.Free;
  end;

  WriteLn('');
end;

end.
 
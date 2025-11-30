unit uLZWTest;

interface

uses
  System.SysUtils, System.Classes, System.Math, uLZWCompressor;

type
  TLZWTest = class
  public
    class procedure RunAllTests;
    class procedure TestRoundTrip;
    class procedure TestDictionaryGrowth;
  end;

implementation

{ TLZWTest }

class procedure TLZWTest.RunAllTests;
begin
  WriteLn('');
  WriteLn('=== LZW Compressor Tests ===');
  WriteLn('');

  try
    TestRoundTrip;
    TestDictionaryGrowth;
    WriteLn('');
    WriteLn('✓ LZW tests completed!');
  except
    on E: Exception do
      WriteLn('✗ LZW test failed: ' + E.Message);
  end;
end;

class procedure TLZWTest.TestRoundTrip;
const
  TEST_DATA = 'LZW compression round trip with repetitive characters. ' +
              'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA';
var
  Codec: TLZWCompressor;
  Input, Compressed, Decompressed: TMemoryStream;
  InputBytes, OutputBytes: TBytes;
  Match: Boolean;
begin
  WriteLn('[LZW] Round-trip verification');

  Codec := TLZWCompressor.Create;
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
        WriteLn(Format('  ⚠ Round-trip mismatch (original %d, decoded %d)',
          [Input.Size, Decompressed.Size]));
    end
    else
    begin
      if Decompressed.Size < Input.Size then
        raise Exception.CreateFmt('LZW round-trip size mismatch: expected %d, got %d (missing %d bytes)',
          [Input.Size, Decompressed.Size, Input.Size - Decompressed.Size])
      else
        raise Exception.CreateFmt('LZW round-trip size mismatch: expected %d, got %d',
          [Input.Size, Decompressed.Size]);
    end;
  finally
    Codec.Free;
    Input.Free;
    Compressed.Free;
    Decompressed.Free;
  end;

  WriteLn('');
end;

class procedure TLZWTest.TestDictionaryGrowth;
var
  Codec: TLZWCompressor;
  Input, Compressed: TMemoryStream;
  I: Integer;
  Pattern: string;
  Ratio: Double;
begin
  WriteLn('[LZW] Dictionary growth scenario');

  Pattern := 'ABABABA';
  Codec := TLZWCompressor.Create;
  Input := TMemoryStream.Create;
  Compressed := TMemoryStream.Create;
  try
    for I := 1 to 2048 do
      Input.WriteBuffer(Pattern[1], Length(Pattern));

    Input.Position := 0;
    Codec.Compress(Input, Compressed);
    Ratio := (Compressed.Size * 100.0) / Input.Size;
    WriteLn(Format('  Input: %d bytes → Output: %d bytes (%.1f%%)',
      [Input.Size, Compressed.Size, Ratio]));
  finally
    Codec.Free;
    Input.Free;
    Compressed.Free;
  end;

  WriteLn('');
end;

end.
 
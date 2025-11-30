unit uLZ77Test;

interface

uses
  System.SysUtils, System.Classes, System.Math, uLZ77Compressor;

type
  TLZ77Test = class
  public
    class procedure RunAllTests;
    class procedure TestRoundTrip;
    class procedure TestRepetitiveData;
  end;

implementation

{ TLZ77Test }

class procedure TLZ77Test.RunAllTests;
begin
  WriteLn('');
  WriteLn('=== LZ77 Compressor Tests ===');
  WriteLn('');

  try
    TestRoundTrip;
    TestRepetitiveData;
    WriteLn('');
    WriteLn('✓ LZ77 tests completed!');
  except
    on E: Exception do
      WriteLn('✗ LZ77 test failed: ' + E.Message);
  end;
end;

class procedure TLZ77Test.TestRoundTrip;
const
  TEST_DATA = 'Classic LZ77 compression round trip. ' +
              'Sphinx of black quartz, judge my vow. ' +
              'The five boxing wizards jump quickly.';
var
  Codec: TLZ77Compressor;
  Input, Compressed, Decompressed: TMemoryStream;
  InputBytes, OutputBytes: TBytes;
  Match: Boolean;
begin
  WriteLn('[LZ77] Round-trip verification');

  Codec := TLZ77Compressor.Create;
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

class procedure TLZ77Test.TestRepetitiveData;
var
  Codec: TLZ77Compressor;
  Input, Compressed: TMemoryStream;
  I: Integer;
  Ratio: Double;
  Value: Byte;
begin
  WriteLn('[LZ77] Repetitive data compression');

  Codec := TLZ77Compressor.Create;
  Input := TMemoryStream.Create;
  Compressed := TMemoryStream.Create;
  try
    for I := 0 to 4095 do
    begin
      Value := Byte(Ord('A') + (I mod 4));
      Input.WriteBuffer(Value, 1);
    end;

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
 
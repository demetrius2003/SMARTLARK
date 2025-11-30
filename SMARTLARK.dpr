program SMARTLARK;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  uSMARTLARKTypes in 'src\uSMARTLARKTypes.pas',
  uSMARTLARKExceptions in 'src\uSMARTLARKExceptions.pas',
  uSMARTLARKArchive in 'src\uSMARTLARKArchive.pas',
  uLZSSCompressor in 'src\Compression\uLZSSCompressor.pas',
  uLZSSTest in 'src\Compression\uLZSSTest.pas',
  uHuffmanCoding in 'src\Compression\uHuffmanCoding.pas',
  uLZHUF in 'src\Compression\uLZHUF.pas',
  uLZHUFTest in 'src\Compression\uLZHUFTest.pas',
  uDeflateTest in 'src\Compression\uDeflateTest.pas',
  uLZ77Test in 'src\Compression\uLZ77Test.pas',
  uLZWTest in 'src\Compression\uLZWTest.pas',
  uStoreCompressor in 'src\Compression\uStoreCompressor.pas',
  uDeflateCompressor in 'src\Compression\uDeflateCompressor.pas',
  uLZWCompressor in 'src\Compression\uLZWCompressor.pas',
  uLZ77Compressor in 'src\Compression\uLZ77Compressor.pas',
  uCRC32 in 'src\Utils\uCRC32.pas',
  uStreamHelpers in 'src\Utils\uStreamHelpers.pas',
  uCommandLine in 'src\uCommandLine.pas',
  uConsoleOutput in 'src\uConsoleOutput.pas',
  uArchiveIntegrationTest in 'src\uArchiveIntegrationTest.pas';

procedure ShowUsage;
begin
  WriteLn('SMARTLARK v2.0 - Console Archiver');
  WriteLn('');
  WriteLn('Usage: SMARTLARK [command] [archive] [files] [options]');
  WriteLn('');
  WriteLn('Commands:');
  WriteLn('  a <archive> <files...>   Add files to archive');
  WriteLn('  x <archive> [files...]   Extract files from archive');
  WriteLn('  l <archive>              List archive contents');
  WriteLn('  d <archive> <files...>   Delete files from archive');
  WriteLn('  t <archive>              Test archive integrity');
  WriteLn('  u <archive> <files...>   Update files in archive');
  WriteLn('');
  WriteLn('Options:');
  WriteLn('  -o <dir>     Output directory for extraction');
  WriteLn('  -r           Recursive directory processing');
  WriteLn('  -c[1-9]      Compression level (1-9)');
  WriteLn('  -m <method>   Compression method: store, lzss, lzhuf, deflate, lzw, lz77');
  WriteLn('  -v           Verbose output');
  WriteLn('  -h           Show this help');
  WriteLn('');
  WriteLn('Examples:');
  WriteLn('  SMARTLARK a archive.lark file1.txt file2.txt');
  WriteLn('  SMARTLARK x archive.lark -o extracted\');
  WriteLn('  SMARTLARK l archive.lark');
  WriteLn('  SMARTLARK t archive.lark');
  WriteLn('');
  WriteLn('Testing:');
  WriteLn('  SMARTLARK test lzss         Run LZSS algorithm tests');
  WriteLn('  SMARTLARK test lzhuf        Run LZHUF codec tests');
  WriteLn('  SMARTLARK test deflate      Run DEFLATE (zlib) tests');
  WriteLn('  SMARTLARK test lz77         Run LZ77 codec tests');
  WriteLn('  SMARTLARK test lzw          Run LZW codec tests');
  WriteLn('  SMARTLARK test archive      Run archive integration tests');
  WriteLn('  SMARTLARK test all          Run all tests');
  WriteLn('');
end;

procedure RunTests(TestType: string);
var
  TestLower: string;
begin
  TestLower := LowerCase(TestType);
  if (TestLower = 'lzss') or (Pos('lzss', TestLower) = 1) then
  begin
    WriteLn('');
    WriteLn('========================================');
    WriteLn('Running LZSS Compression Tests');
    WriteLn('========================================');
    WriteLn('');
    TLZSSTest.RunAllTests;
  end
  else if (TestLower = 'lzhuf') or (Pos('lzhuf', TestLower) = 1) or (TestLower[1] = 'h') then
  begin
    WriteLn('');
    WriteLn('========================================');
    WriteLn('Running LZHUF Codec Tests');
    WriteLn('========================================');
    WriteLn('');
    TLZHUFTest.RunAllTests;
  end
  else if (TestLower = 'deflate') or (Pos('deflate', TestLower) = 1) or (TestLower[1] = 'd') then
  begin
    WriteLn('');
    WriteLn('========================================');
    WriteLn('Running DEFLATE Tests');
    WriteLn('========================================');
    WriteLn('');
    TDeflateTest.RunAllTests;
  end
  else if (TestLower = 'lz77') or (Pos('lz77', TestLower) = 1) then
  begin
    WriteLn('');
    WriteLn('========================================');
    WriteLn('Running LZ77 Tests');
    WriteLn('========================================');
    WriteLn('');
    TLZ77Test.RunAllTests;
  end
  else if (TestLower = 'lzw') or (Pos('lzw', TestLower) = 1) then
  begin
    WriteLn('');
    WriteLn('========================================');
    WriteLn('Running LZW Tests');
    WriteLn('========================================');
    WriteLn('');
    TLZWTest.RunAllTests;
  end
  else if (TestLower = 'archive') or (Pos('archive', TestLower) = 1) then
  begin
    WriteLn('');
    WriteLn('========================================');
    WriteLn('Running Archive Integration Tests');
    WriteLn('========================================');
    WriteLn('');
    TArchiveIntegrationTest.RunAllTests;
  end
  else
    begin
      WriteLn('');
      WriteLn('========================================');
      WriteLn('Running All Tests');
      WriteLn('========================================');
      WriteLn('');

      WriteLn('');
      WriteLn('--- LZSS Tests ---');
      WriteLn('');
      TLZSSTest.RunAllTests;

      WriteLn('');
      WriteLn('--- LZHUF Tests ---');
      WriteLn('');
      TLZHUFTest.RunAllTests;

      WriteLn('');
      WriteLn('--- DEFLATE Tests ---');
      WriteLn('');
      TDeflateTest.RunAllTests;

      WriteLn('');
      WriteLn('--- LZ77 Tests ---');
      WriteLn('');
      TLZ77Test.RunAllTests;

      WriteLn('');
      WriteLn('--- LZW Tests ---');
      WriteLn('');
      TLZWTest.RunAllTests;

      WriteLn('');
      WriteLn('--- Archive Integration Tests ---');
      WriteLn('');
      TArchiveIntegrationTest.RunAllTests;

      WriteLn('');
      WriteLn('========================================');
      WriteLn('All Test Suites Completed');
      WriteLn('========================================');
      WriteLn('');
    end;
end;

function Main: Integer;
var
  CommandLine: TCommandLine;
  ExitCode: Integer;
begin
  try
    CommandLine := TCommandLine.Create;
    try
      if not CommandLine.Parse then
      begin
        ShowUsage;
        ExitCode := 1;
      end
      else
      begin
        ExitCode := CommandLine.Execute;
      end;
    finally
      CommandLine.Free;
    end;

    if ExitCode <> 0 then
      Exit(ExitCode);

  except
    on E: Exception do
    begin
      WriteLn('Error: ' + E.Message);
      Exit(1);
    end;
  end;
  Result := 0;
end;

var
  TestType: string;
  ExitCode: Integer;
begin
  try
    if ParamCount = 0 then
    begin
      // No parameters - show usage
      ShowUsage;
      Halt(0);
    end
    else if (ParamCount >= 1) and (LowerCase(ParamStr(1)) = 'test') then
    begin
      // Test command
      TestType := 'all';
      if ParamCount >= 2 then
        TestType := ParamStr(2);
      RunTests(TestType);
      Halt(0);
    end
    else
    begin
      ExitCode := Main;
      Halt(ExitCode);
    end;

  except
    on E: Exception do
    begin
      WriteLn(ErrOutput, 'Fatal error: ' + E.Message);
      Halt(1);
    end;
  end;
end.


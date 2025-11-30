unit uArchiveIntegrationTest;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils, System.Types,
  uSMARTLARKArchive, uSMARTLARKTypes;

type
  TArchiveIntegrationTest = class
  public
    class procedure RunAllTests;
    class procedure TestCreateArchive;
    class procedure TestAddFiles;
    class procedure TestListFiles;
    class procedure TestExtractFiles;
    class procedure TestDeleteFiles;
    class procedure TestIntegrity;
    class procedure TestRoundTrip;
    class procedure TestRoundTripStore;
    class procedure TestRoundTripDeflate;
    class procedure TestDeflateLevels;
  end;

implementation

class procedure TArchiveIntegrationTest.RunAllTests;
begin
  WriteLn('');
  WriteLn('===========================================');
  WriteLn('SMARTLARK Archive Integration Tests');
  WriteLn('===========================================');
  WriteLn('');

  try
    TestCreateArchive;
    WriteLn('✓ Create Archive Test PASSED');
    WriteLn('');

    TestAddFiles;
    WriteLn('✓ Add Files Test PASSED');
    WriteLn('');

    TestListFiles;
    WriteLn('✓ List Files Test PASSED');
    WriteLn('');

    TestExtractFiles;
    WriteLn('✓ Extract Files Test PASSED');
    WriteLn('');

    TestIntegrity;
    WriteLn('✓ Integrity Test PASSED');
    WriteLn('');

    TestDeleteFiles;
    WriteLn('✓ Delete Files Test PASSED');
    WriteLn('');

    TestRoundTrip;
    WriteLn('✓ Round Trip Test PASSED');
    WriteLn('');

    TestRoundTripStore;
    WriteLn('✓ Round Trip Store Test PASSED');
    WriteLn('');

    TestRoundTripDeflate;
    WriteLn('✓ Round Trip DEFLATE Test PASSED');
    WriteLn('');

    TestDeflateLevels;
    WriteLn('✓ DEFLATE Levels Test PASSED');
    WriteLn('');

    WriteLn('===========================================');
    WriteLn('All tests completed successfully!');
    WriteLn('===========================================');
    WriteLn('');

  except
    on E: Exception do
    begin
      WriteLn('');
      WriteLn('✗ TEST FAILED: ' + E.Message);
      WriteLn('');
    end;
  end;
end;

class procedure TArchiveIntegrationTest.TestCreateArchive;
var
  Archive: TSMARTLARKArchive;
  TestFile: string;
begin
  TestFile := GetCurrentDir + '\test_archive.lark';

  // Clean up if exists
  if FileExists(TestFile) then
    DeleteFile(TestFile);

  Archive := TSMARTLARKArchive.Create;
  try
    Archive.CreateArchive(TestFile);
    Archive.SaveArchive;

    if not FileExists(TestFile) then
      raise Exception.Create('Archive file was not created');

  finally
    Archive.Free;
  end;
end;

class procedure TArchiveIntegrationTest.TestAddFiles;
var
  Archive: TSMARTLARKArchive;
  TestFile: string;
  TestData1, TestData2, TestData3: string;
  File1, File2, File3: string;
  i: Integer;
begin
  TestFile := GetCurrentDir + '\test_archive.lark';

  // Create test files
  File1 := GetCurrentDir + '\test_file1.txt';
  File2 := GetCurrentDir + '\test_file2.txt';
  File3 := GetCurrentDir + '\test_file3.bin';

  TestData1 := 'Hello World! This is test file 1.' + #13#10;
  for i := 1 to 100 do
    TestData1 := TestData1 + 'Line ' + IntToStr(i) + ': Repetitive test data.' + #13#10;

  TestData2 := 'AAABBBCCCDDDEEE';
  for i := 1 to 50 do
    TestData2 := TestData2 + 'AAABBBCCCDDDEEE';

  TestData3 := '';
  for i := 0 to 255 do
    TestData3 := TestData3 + Char(i);
  for i := 1 to 10 do
    TestData3 := TestData3 + TestData3;

  // Write test files
  TFile.WriteAllText(File1, TestData1, TEncoding.UTF8);
  TFile.WriteAllText(File2, TestData2, TEncoding.UTF8);
  TFile.WriteAllBytes(File3, TEncoding.UTF8.GetBytes(TestData3));

  // Add to archive
  Archive := TSMARTLARKArchive.Create;
  try
    Archive.CreateArchive(TestFile);
    Archive.CompressionMethod := cmStore;
    Archive.CompressionLevel := 0;
    try
      Archive.AddFile(File1);
      Archive.AddFile(File2);
      Archive.AddFile(File3);
    except
      on E: Exception do
      begin
        WriteLn('Exception while adding files: ' + E.ClassName + ' - ' + E.Message);
        raise;
      end;
    end;
    Archive.SaveArchive;

    if Archive.GetFileCount <> 3 then
      raise Exception.Create('Expected 3 files in archive, got ' + IntToStr(Archive.GetFileCount));

  finally
    Archive.Free;
  end;

  // Clean up test files
  if FileExists(File1) then DeleteFile(File1);
  if FileExists(File2) then DeleteFile(File2);
  if FileExists(File3) then DeleteFile(File3);
end;

class procedure TArchiveIntegrationTest.TestListFiles;
var
  Archive: TSMARTLARKArchive;
  TestFile: string;
begin
  TestFile := GetCurrentDir + '\test_archive.lark';

  Archive := TSMARTLARKArchive.Create;
  try
    Archive.OpenArchive(TestFile);
    WriteLn('');
    Archive.ListFiles;
  finally
    Archive.Free;
  end;
end;

class procedure TArchiveIntegrationTest.TestExtractFiles;
var
  Archive: TSMARTLARKArchive;
  TestFile: string;
  ExtractDir: string;
  i: Integer;
  Entry: TArchiveFileEntry;
  FileName: string;
  ExtractedFiles: TStringDynArray;
begin
  TestFile := GetCurrentDir + '\test_archive.lark';
  ExtractDir := GetCurrentDir + '\extracted_test';

  // Create extraction directory
  if not TDirectory.Exists(ExtractDir) then
    TDirectory.CreateDirectory(ExtractDir);

  Archive := TSMARTLARKArchive.Create;
  try
    Archive.OpenArchive(TestFile);
    for i := 0 to Archive.GetFileCount - 1 do
    begin
      Entry := Archive.FileEntries[i];
      FileName := ExtractFileName(Entry.FileName);
      Archive.ExtractFile(Entry.FileName, ExtractDir + '\' + FileName);
    end;
  finally
    Archive.Free;
  end;

  // Verify extracted files exist
  ExtractedFiles := TDirectory.GetFiles(ExtractDir);
  if Length(ExtractedFiles) <> 3 then
    raise Exception.Create(Format('Expected 3 extracted files, got %d', [Length(ExtractedFiles)]));

  // Clean up
  TDirectory.Delete(ExtractDir, True);
end;

class procedure TArchiveIntegrationTest.TestIntegrity;
var
  Archive: TSMARTLARKArchive;
  TestFile: string;
begin
  TestFile := GetCurrentDir + '\test_archive.lark';

  Archive := TSMARTLARKArchive.Create;
  try
    Archive.OpenArchive(TestFile);
    WriteLn('');
    Archive.TestIntegrity;
  finally
    Archive.Free;
  end;
end;

class procedure TArchiveIntegrationTest.TestDeleteFiles;
var
  Archive: TSMARTLARKArchive;
  TestFile: string;
  Entry: TArchiveFileEntry;
  FileName: string;
begin
  TestFile := GetCurrentDir + '\test_archive.lark';

  Archive := TSMARTLARKArchive.Create;
  try
    Archive.OpenArchive(TestFile);

    Entry := Archive.FileEntries[0];
    FileName := Entry.FileName;

    Archive.DeleteFile(FileName);
    Archive.SaveArchive;

    if Archive.GetFileCount <> 2 then
      raise Exception.Create(Format('Expected 2 files after delete, got %d', [Archive.GetFileCount]));

  finally
    Archive.Free;
  end;
end;

class procedure TArchiveIntegrationTest.TestRoundTrip;
var
  Archive: TSMARTLARKArchive;
  TestFile: string;
  SourceFile: string;
  SourceData: string;
  ExtractedFile: string;
  ExtractedData: string;
  i: Integer;
  Entry: TArchiveFileEntry;
begin
  TestFile := GetCurrentDir + '\roundtrip_test.lark';
  SourceFile := GetCurrentDir + '\roundtrip_source.txt';
  ExtractedFile := GetCurrentDir + '\roundtrip_extracted.txt';

  // Clean up
  if FileExists(TestFile) then DeleteFile(TestFile);
  if FileExists(SourceFile) then DeleteFile(SourceFile);
  if FileExists(ExtractedFile) then DeleteFile(ExtractedFile);

  // Create test data
  SourceData := '';
  for i := 1 to 1000 do
    SourceData := SourceData + 'This is line ' + IntToStr(i) + ' with some test data.' + #13#10;

  TFile.WriteAllText(SourceFile, SourceData, TEncoding.UTF8);

  // Add to archive
  Archive := TSMARTLARKArchive.Create;
  try
    Archive.CreateArchive(TestFile);
    Archive.CompressionMethod := cmDEFLATE;
    Archive.CompressionLevel := 5;
    Archive.AddFile(SourceFile);
    Archive.SaveArchive;
  finally
    Archive.Free;
  end;

  // Extract from archive
  Archive := TSMARTLARKArchive.Create;
  try
    Archive.OpenArchive(TestFile);
    Entry := Archive.FileEntries[0];
    Archive.ExtractFile(Entry.FileName, ExtractedFile);
  finally
    Archive.Free;
  end;

  // Compare files
  ExtractedData := TFile.ReadAllText(ExtractedFile, TEncoding.UTF8);

  if SourceData <> ExtractedData then
    raise Exception.Create('Round-trip data mismatch');

  // Clean up
  DeleteFile(TestFile);
  DeleteFile(SourceFile);
  DeleteFile(ExtractedFile);
end;

class procedure TArchiveIntegrationTest.TestRoundTripStore;
var
  Archive: TSMARTLARKArchive;
  TestFile, SourceFile, ExtractedFile, SourceData, ExtractedData: string;
  i: Integer;
begin
  TestFile := GetCurrentDir + '\roundtrip_store.lark';
  SourceFile := GetCurrentDir + '\roundtrip_store_source.txt';
  ExtractedFile := GetCurrentDir + '\roundtrip_store_extracted.txt';

  if FileExists(TestFile) then DeleteFile(TestFile);
  if FileExists(SourceFile) then DeleteFile(SourceFile);
  if FileExists(ExtractedFile) then DeleteFile(ExtractedFile);

  SourceData := '';
  for i := 1 to 200 do
    SourceData := SourceData + 'Store line ' + IntToStr(i) + #13#10;
  TFile.WriteAllText(SourceFile, SourceData, TEncoding.UTF8);

  Archive := TSMARTLARKArchive.Create;
  try
    Archive.CreateArchive(TestFile);
    Archive.CompressionMethod := cmStore;
    Archive.AddFile(SourceFile);
    Archive.SaveArchive;
  finally
    Archive.Free;
  end;

  Archive := TSMARTLARKArchive.Create;
  try
    Archive.OpenArchive(TestFile);
    Archive.ExtractFile(Archive.FileEntries[0].FileName, ExtractedFile);
  finally
    Archive.Free;
  end;

  ExtractedData := TFile.ReadAllText(ExtractedFile, TEncoding.UTF8);
  if SourceData <> ExtractedData then
    raise Exception.Create('Store round-trip data mismatch');

  DeleteFile(TestFile);
  DeleteFile(SourceFile);
  DeleteFile(ExtractedFile);
end;

class procedure TArchiveIntegrationTest.TestRoundTripDeflate;
var
  Archive: TSMARTLARKArchive;
  TestFile, SourceFile, ExtractedFile, SourceData, ExtractedData: string;
  i: Integer;
begin
  TestFile := GetCurrentDir + '\roundtrip_deflate.lark';
  SourceFile := GetCurrentDir + '\roundtrip_deflate_source.txt';
  ExtractedFile := GetCurrentDir + '\roundtrip_deflate_extracted.txt';

  if FileExists(TestFile) then DeleteFile(TestFile);
  if FileExists(SourceFile) then DeleteFile(SourceFile);
  if FileExists(ExtractedFile) then DeleteFile(ExtractedFile);

  SourceData := '';
  for i := 1 to 200 do
    SourceData := SourceData + 'Deflate line ' + IntToStr(i) + ' AAAA BBBB CCCC DDDD' + #13#10;
  TFile.WriteAllText(SourceFile, SourceData, TEncoding.UTF8);

  Archive := TSMARTLARKArchive.Create;
  try
    Archive.CreateArchive(TestFile);
    Archive.CompressionMethod := cmDEFLATE;
    Archive.CompressionLevel := 5;
    Archive.AddFile(SourceFile);
    Archive.SaveArchive;
  finally
    Archive.Free;
  end;

  Archive := TSMARTLARKArchive.Create;
  try
    Archive.OpenArchive(TestFile);
    Archive.ExtractFile(Archive.FileEntries[0].FileName, ExtractedFile);
  finally
    Archive.Free;
  end;

  ExtractedData := TFile.ReadAllText(ExtractedFile, TEncoding.UTF8);
  if SourceData <> ExtractedData then
    raise Exception.Create('DEFLATE round-trip data mismatch');

  DeleteFile(TestFile);
  DeleteFile(SourceFile);
  DeleteFile(ExtractedFile);
end;

class procedure TArchiveIntegrationTest.TestDeflateLevels;
var
  Archive: TSMARTLARKArchive;
  TestFileL1, TestFileL5, TestFileL9: string;
  SourceFile: string;
  Data: string;
  I: Integer;
  Size1, Size5, Size9: Int64;
begin
  SourceFile := GetCurrentDir + '\deflate_levels_source.txt';
  TestFileL1 := GetCurrentDir + '\deflate_l1.lark';
  TestFileL5 := GetCurrentDir + '\deflate_l5.lark';
  TestFileL9 := GetCurrentDir + '\deflate_l9.lark';

  if FileExists(TestFileL1) then DeleteFile(TestFileL1);
  if FileExists(TestFileL5) then DeleteFile(TestFileL5);
  if FileExists(TestFileL9) then DeleteFile(TestFileL9);
  if FileExists(SourceFile) then DeleteFile(SourceFile);

  Data := '';
  for I := 1 to 2000 do
    Data := Data + 'Line ' + IntToStr(I) + ' AAAA BBBB CCCC DDDD EEEE FFFF' + #13#10;
  TFile.WriteAllText(SourceFile, Data, TEncoding.UTF8);

  // Level 1
  Archive := TSMARTLARKArchive.Create;
  try
    Archive.CreateArchive(TestFileL1);
    Archive.CompressionMethod := cmDEFLATE;
    Archive.CompressionLevel := 1;
    Archive.AddFile(SourceFile);
    Archive.SaveArchive;
    Size1 := Archive.FileEntries[0].CompressedSize;
  finally
    Archive.Free;
  end;

  // Level 5
  Archive := TSMARTLARKArchive.Create;
  try
    Archive.CreateArchive(TestFileL5);
    Archive.CompressionMethod := cmDEFLATE;
    Archive.CompressionLevel := 5;
    Archive.AddFile(SourceFile);
    Archive.SaveArchive;
    Size5 := Archive.FileEntries[0].CompressedSize;
  finally
    Archive.Free;
  end;

  // Level 9
  Archive := TSMARTLARKArchive.Create;
  try
    Archive.CreateArchive(TestFileL9);
    Archive.CompressionMethod := cmDEFLATE;
    Archive.CompressionLevel := 9;
    Archive.AddFile(SourceFile);
    Archive.SaveArchive;
    Size9 := Archive.FileEntries[0].CompressedSize;
  finally
    Archive.Free;
  end;

  // Sanity: sizes should be non-increasing with level (allow equal)
  if not ((Size1 >= Size5) and (Size5 >= Size9)) then
    raise Exception.Create(Format('DEFLATE sizes not monotonic: L1=%d L5=%d L9=%d', [Size1, Size5, Size9]));

  // Cleanup
  DeleteFile(TestFileL1);
  DeleteFile(TestFileL5);
  DeleteFile(TestFileL9);
  DeleteFile(SourceFile);
end;

end.

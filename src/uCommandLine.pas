unit uCommandLine;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, System.IOUtils,
  System.DateUtils, System.Math, Winapi.Windows,
  uSMARTLARKArchive, uSMARTLARKTypes, uSMARTLARKExceptions, uOperationStats;

type
  /// <summary>
  /// Command line parser and executor for SMARTLARK archiver.
  /// Handles parsing of command-line arguments and execution of archive operations.
  /// </summary>
  /// <remarks>
  /// Supports commands: 'a' (add), 'x' (extract), 'l' (list), 'd' (delete), 't' (test), 'u' (update).
  /// Supports wildcards (* and ?) for file selection in all commands.
  /// </remarks>
  /// <example>
  /// <code>
  /// var
  ///   CmdLine: TCommandLine;
  /// begin
  ///   CmdLine := TCommandLine.Create;
  ///   try
  ///     if CmdLine.Parse then
  ///       ExitCode := CmdLine.Execute
  ///     else
  ///       ShowUsage;
  ///   finally
  ///     CmdLine.Free;
  ///   end;
  /// end;
  /// </code>
  /// </example>
  TCommandLine = class
  private
    FCommand: Char;                      // 'a', 'x', 'l', 'd', 't', 'u'
    FArchiveFile: string;
    FFileList: TList<string>;
    FOutputDir: string;
    FCompressionLevel: TCompressionLevel;
    FCompressionMethod: TCompressionMethod;
    FVerbose: Boolean;
    FRecursive: Boolean;

    // Helper methods
    procedure CollectFiles(const Path: string; const Pattern: string = '*');
    function GetArchiveName(const FilePath: string): string;
    function GetFileSize(const FileName: string): Int64;
    
    // Validation methods
    function ValidateFilePath(const FilePath: string): Boolean;
    function ValidateFileName(const FileName: string): Boolean;
    function ValidateCompressionLevel(Level: Integer): Boolean;
    function ValidateArchivePath(const ArchivePath: string): Boolean;
    
    // Wildcard matching
    function MatchesPattern(const FileName, Pattern: string): Boolean;

    // Execute methods
    function ExecuteAdd: Integer;
    function ExecuteExtract: Integer;
    function ExecuteList: Integer;
    function ExecuteDelete: Integer;
    function ExecuteTest: Integer;
    function ExecuteUpdate: Integer;

    // Statistics
    procedure ShowOperationStart(const Operation: string);
    procedure ShowOperationEnd(const Operation: string; Success: Boolean);
    procedure ShowTimingStats(const Operation: string; Stats: TOperationStats);
    function FormatDuration(Milliseconds: Int64): string;
    function FormatSpeed(Bytes: Int64; Milliseconds: Int64): string;

  public
    /// <summary>
    /// Creates a new instance of TCommandLine with default settings.
    /// </summary>
    constructor Create;
    
    /// <summary>
    /// Destroys the command line instance and releases resources.
    /// </summary>
    destructor Destroy; override;

    /// <summary>
    /// Parses command-line arguments and validates them.
    /// </summary>
    /// <returns>True if parsing was successful, False otherwise.</returns>
    /// <remarks>
    /// Validates commands, file paths, compression settings, and other parameters.
    /// Sets internal properties based on parsed arguments.
    /// </remarks>
    function Parse: Boolean;
    
    /// <summary>
    /// Executes the parsed command.
    /// </summary>
    /// <returns>Exit code: 0 for success, non-zero for errors.</returns>
    /// <exception cref="Exception">May raise various exceptions depending on the operation.</exception>
    /// <remarks>
    /// Performs the archive operation specified by the Command property.
    /// </remarks>
    function Execute: Integer;

    /// <summary>
    /// Gets the command character ('a', 'x', 'l', 'd', 't', or 'u').
    /// </summary>
    property Command: Char read FCommand;
    
    /// <summary>
    /// Gets the archive file path specified in command-line arguments.
    /// </summary>
    property ArchiveFile: string read FArchiveFile;
    
    /// <summary>
    /// Gets the compression level (0-9) specified via -c option.
    /// </summary>
    property CompressionLevel: TCompressionLevel read FCompressionLevel;
    
    /// <summary>
    /// Gets the compression method specified via -m option.
    /// </summary>
    property CompressionMethod: TCompressionMethod read FCompressionMethod;
    
    /// <summary>
    /// Gets the output directory specified via -o option.
    /// </summary>
    property OutputDir: string read FOutputDir;
    
    /// <summary>
    /// Gets whether verbose output is enabled via -v option.
    /// </summary>
    property Verbose: Boolean read FVerbose;
  end;

implementation

{ TCommandLine }

constructor TCommandLine.Create;
begin
  inherited Create;
  FFileList := TList<string>.Create;
  FCommand := #0;
  FCompressionLevel := DEFAULT_COMPRESSION_LEVEL;
  FCompressionMethod := cmDEFLATE; // Default to DEFLATE (LZHUF deferred)
  FVerbose := False;
  FRecursive := False;
  FOutputDir := '';
end;

// Helper function to format bytes
function FormatBytes(Bytes: Int64): string;
begin
  if Bytes < 1024 then
    Result := Format('%d B', [Bytes])
  else if Bytes < 1024 * 1024 then
    Result := Format('%.2f KB', [Bytes / 1024])
  else if Bytes < 1024 * 1024 * 1024 then
    Result := Format('%.2f MB', [Bytes / (1024 * 1024)])
  else
    Result := Format('%.2f GB', [Bytes / (1024 * 1024 * 1024)]);
end;

destructor TCommandLine.Destroy;
begin
  FFileList.Free;
  inherited;
end;

function TCommandLine.Parse: Boolean;
var
  I: Integer;
  Param: string;
begin
  Result := True;

  if ParamCount < 1 then
    Exit(False);

  // First parameter is the command
  Param := ParamStr(1);
  if Length(Param) > 0 then
    FCommand := LowerCase(Param)[1]
  else
    Exit(False);

  // Validate command
  case FCommand of
    'a', 'x', 'l', 'd', 't', 'u': ; // Valid commands
  else
    Exit(False);
  end;

  // Parse remaining parameters
  I := 2;
  while I <= ParamCount do
  begin
    Param := ParamStr(I);

    if (Length(Param) > 0) and (Param[1] = '-') then
    begin
      // Handle options
      if Length(Param) > 1 then
      begin
        case LowerCase(Param[2])[1] of
          'c': // Compression level (e.g., -c5)
          begin
            if Length(Param) >= 3 then
            begin
              FCompressionLevel := StrToIntDef(Copy(Param, 3, 1), DEFAULT_COMPRESSION_LEVEL);
              if not ValidateCompressionLevel(FCompressionLevel) then
              begin
                WriteLn('Error: Invalid compression level. Must be between 0 and 9.');
                Exit(False);
              end;
            end;
          end;
          'm': // Compression method (e.g., -m store, -m lzhuf, -m deflate)
          begin
            if I < ParamCount then
            begin
              Inc(I);
              Param := LowerCase(ParamStr(I));
              if Param = 'store' then
                FCompressionMethod := cmStore
              else if Param = 'lzss' then
                FCompressionMethod := cmLZSS
              else if Param = 'lzhuf' then
                FCompressionMethod := cmLZHUF
              else if Param = 'deflate' then
                FCompressionMethod := cmDEFLATE
              else if Param = 'lzw' then
                FCompressionMethod := cmLZW
              else if Param = 'lz77' then
                FCompressionMethod := cmLZ77
              else
              begin
                WriteLn('Error: Invalid compression method: ' + ParamStr(I));
                WriteLn('Valid methods: store, lzss, lzhuf, deflate, lzw, lz77');
                Exit(False);
              end;
            end
            else
            begin
              WriteLn('Error: Compression method not specified');
              Exit(False);
            end;
          end;
          'r': // Recursive
            FRecursive := True;
          'o': // Output directory
          begin
            if I < ParamCount then
            begin
              Inc(I);
              FOutputDir := ParamStr(I);
            end;
          end;
          'v': // Verbose
            FVerbose := True;
          'h', '?': // Help
            Exit(False);
        end;
      end;
    end
    else
    begin
      // Non-option parameters
      if FArchiveFile = '' then
        FArchiveFile := Param
      else
        FFileList.Add(Param);
    end;

    Inc(I);
  end;

  // Validate based on command
  case FCommand of
    'a': Result := (FArchiveFile <> '') and (FFileList.Count > 0);
    'x': Result := (FArchiveFile <> '');
    'l': Result := (FArchiveFile <> '');
    'd': Result := (FArchiveFile <> '') and (FFileList.Count > 0);
    't': Result := (FArchiveFile <> '');
    'u': Result := (FArchiveFile <> '') and (FFileList.Count > 0);
  else
    Result := False;
  end;
  
  // Additional validation
  if Result then
  begin
    // Validate archive path
    if not ValidateArchivePath(FArchiveFile) then
    begin
      WriteLn('Error: Invalid archive path: ' + FArchiveFile);
      WriteLn('Please check the path and ensure the directory exists.');
      Exit(False);
    end;
    
    // For commands that require files, validate file paths
    if FFileList.Count > 0 then
    begin
      for I := 0 to FFileList.Count - 1 do
      begin
        if (FCommand = 'a') or (FCommand = 'u') then
        begin
          // For add/update, files must exist
          if not ValidateFilePath(FFileList[I]) then
          begin
            WriteLn('Error: File not found or invalid path: ' + FFileList[I]);
            Exit(False);
          end;
        end;
        // For extract/delete, filenames are validated when processing archive
      end;
    end;
  end;
end;


procedure TCommandLine.CollectFiles(const Path: string; const Pattern: string = '*');
var
  SearchRec: TSearchRec;
  FullPath: string;
  SearchResult: Integer;
begin
  SearchResult := FindFirst(IncludeTrailingPathDelimiter(Path) + Pattern, faAnyFile, SearchRec);
  if SearchResult = 0 then
  begin
    try
      repeat
        if (SearchRec.Name <> '.') and (SearchRec.Name <> '..') then
        begin
          FullPath := IncludeTrailingPathDelimiter(Path) + SearchRec.Name;

          if (SearchRec.Attr and $10) <> 0 then
          begin
            // Recursively collect from subdirectories
            if FRecursive then
              CollectFiles(FullPath, Pattern);
          end
          else
          begin
            // Add file to list
            if not FFileList.Contains(FullPath) then
              FFileList.Add(FullPath);
          end;
        end;
      until FindNext(SearchRec) <> 0;
    finally
      System.SysUtils.FindClose(SearchRec);
    end;
  end;
end;

function TCommandLine.GetArchiveName(const FilePath: string): string;
begin
  Result := ExtractFileName(FilePath);
end;

procedure TCommandLine.ShowOperationStart(const Operation: string);
begin
  if FVerbose then
  begin
    WriteLn('');
    WriteLn('=== ' + Operation + ' ===');
  end;
end;

procedure TCommandLine.ShowOperationEnd(const Operation: string; Success: Boolean);
begin
  if FVerbose then
  begin
    if Success then
      WriteLn(Operation + ' completed successfully.')
    else
      WriteLn(Operation + ' completed with errors.');
    WriteLn('');
  end;
end;

procedure TCommandLine.ShowTimingStats(const Operation: string; Stats: TOperationStats);
begin
  WriteLn('=== Operation Timing ===');
  WriteLn(Format('Operation: %s', [Operation]));
  WriteLn(Format('Time elapsed: %s', [Stats.FormatElapsedSeconds]));
  WriteLn(Format('Processed bytes: %d', [Stats.BytesProcessed]));
  WriteLn(Format('Speed: %s', [Stats.FormatBytesPerSecond]));
  WriteLn('');
end;

function TCommandLine.FormatDuration(Milliseconds: Int64): string;
var
  Seconds, Minutes, Hours: Int64;
begin
  if Milliseconds < 1000 then
    Result := Format('%d ms', [Milliseconds])
  else if Milliseconds < 60000 then
    Result := Format('%.2f s', [Milliseconds / 1000])
  else
  begin
    Seconds := Milliseconds div 1000;
    Minutes := Seconds div 60;
    Hours := Minutes div 60;
    Seconds := Seconds mod 60;
    Minutes := Minutes mod 60;
    if Hours > 0 then
      Result := Format('%d:%02d:%02d', [Hours, Minutes, Seconds])
    else
      Result := Format('%d:%02d', [Minutes, Seconds]);
  end;
end;

function TCommandLine.FormatSpeed(Bytes: Int64; Milliseconds: Int64): string;
var
  Speed: Double;
begin
  if Milliseconds = 0 then
    Result := 'N/A'
  else
  begin
    Speed := (Bytes * 1000.0) / Milliseconds; // bytes per second
    if Speed < 1024 then
      Result := Format('%.0f B/s', [Speed])
    else if Speed < 1024 * 1024 then
      Result := Format('%.2f KB/s', [Speed / 1024])
    else
      Result := Format('%.2f MB/s', [Speed / (1024 * 1024)]);
  end;
end;

function TCommandLine.ExecuteAdd: Integer;
var
  Archive: TSMARTLARKArchive;
  FileName: string;
  FilesAdded: Integer;
  OriginalFileList: TList<string>;
  I: Integer;
  Path, Pattern: string;
  FileSize: Int64;
  Stats: TOperationStats;
begin
  Result := 0;
  FilesAdded := 0;
  Stats := TOperationStats.Create;
  OriginalFileList := TList<string>.Create;

  try
    Stats.Start;
    // Save original file list for statistics
    for I := 0 to FFileList.Count - 1 do
      OriginalFileList.Add(FFileList[I]);

    // Expand wildcards and directories if recursive
    for I := 0 to OriginalFileList.Count - 1 do
    begin
      FileName := OriginalFileList[I];
      if TDirectory.Exists(FileName) then
      begin
        if FRecursive then
          CollectFiles(FileName)
        else
          WriteLn('Warning: Skipping directory (use -r for recursive): ' + FileName);
      end
      else if (Pos('*', FileName) > 0) or (Pos('?', FileName) > 0) then
      begin
        // Expand wildcard (supports both * and ?)
        Path := ExtractFilePath(FileName);
        Pattern := ExtractFileName(FileName);
        if Path = '' then
          Path := '.';
        CollectFiles(Path, Pattern);
      end;
    end;

    ShowOperationStart('Adding files to archive');

    try
      Archive := TSMARTLARKArchive.Create;
      try
        if FileExists(FArchiveFile) then
        begin
          Archive.OpenArchive(FArchiveFile);
          if FVerbose then
            WriteLn('Opening existing archive: ' + FArchiveFile);
        end
        else
        begin
          Archive.CreateArchive(FArchiveFile);
          if FVerbose then
            WriteLn('Creating new archive: ' + FArchiveFile);
        end;

        Archive.CompressionLevel := FCompressionLevel;
        Archive.CompressionMethod := FCompressionMethod;

        // Add files
        for FileName in FFileList do
        begin
          try
            if System.SysUtils.FileExists(FileName) then
            begin
              FileSize := GetFileSize(FileName);
              if FVerbose then
                WriteLn(Format('Adding: %s (%s)', [FileName, FormatBytes(FileSize)]));
              
              Archive.AddFile(FileName, GetArchiveName(FileName));
              Inc(FilesAdded);
              Inc(Stats.BytesProcessed, FileSize);
            end
            else
            begin
              WriteLn('Error: File not found - ' + FileName);
              Result := 1;
              Inc(Stats.Errors);
            end;
          except
            on E: Exception do
            begin
              WriteLn('Error adding file ' + FileName + ': ' + E.Message);
              Result := 1;
              Inc(Stats.Errors);
            end;
          end;
        end;

        if FilesAdded > 0 then
        begin
          Archive.SaveArchive;
          Stats.FilesProcessed := FilesAdded;
          
          if FVerbose then
          begin
            WriteLn('');
            WriteLn(Format('Archive saved: %s', [FArchiveFile]));
            WriteLn(Format('Files added: %d', [FilesAdded]));
            WriteLn(Format('Archive size: %s', [FormatBytes(GetFileSize(FArchiveFile))]));
          end
          else
            WriteLn(Format('Added %d files to %s', [FilesAdded, FArchiveFile]));
        end;

      finally
        Archive.Free;
      end;
    except
      on E: Exception do
      begin
        WriteLn('Error: ' + E.Message);
        Result := 1;
        Inc(Stats.Errors);
      end;
    end;

    ShowOperationEnd('Add', Result = 0);

  finally
    Stats.Stop;
    ShowTimingStats('Add', Stats);
    Stats.Free;
    OriginalFileList.Free;
  end;
end;

function TCommandLine.ExecuteExtract: Integer;
var
  Archive: TSMARTLARKArchive;
  OutputPath: string;
  FileName: string;
  FilesExtracted: Integer;
  I, J: Integer;
  Entry: TArchiveFileEntry;
  HasWildcards: Boolean;
  Matched: Boolean;
  Stats: TOperationStats;
begin
  Result := 0;
  FilesExtracted := 0;
  Stats := TOperationStats.Create;
  try
    Stats.Start;

    if not System.SysUtils.FileExists(FArchiveFile) then
    begin
      WriteLn('Error: Archive file not found - ' + FArchiveFile);
      Result := 1;
      Inc(Stats.Errors);
      Exit;
    end;

    if FOutputDir = '' then
      OutputPath := '.'
    else
      OutputPath := FOutputDir;

    // Create output directory if it doesn't exist
    if not TDirectory.Exists(OutputPath) then
    begin
      try
        TDirectory.CreateDirectory(OutputPath);
      except
        WriteLn('Error: Cannot create output directory - ' + OutputPath);
        Result := 1;
        Inc(Stats.Errors);
        Exit;
      end;
    end;

    ShowOperationStart('Extracting files');

    try
      Archive := TSMARTLARKArchive.Create;
      try
        Archive.OpenArchive(FArchiveFile);

      if FVerbose then
        WriteLn(Format('Archive: %s (%d files)', [FArchiveFile, Archive.GetFileCount]));

      // Check if any pattern contains wildcards
      HasWildcards := False;
      for I := 0 to FFileList.Count - 1 do
      begin
        if (Pos('*', FFileList[I]) > 0) or (Pos('?', FFileList[I]) > 0) then
        begin
          HasWildcards := True;
          Break;
        end;
      end;
      
      if FFileList.Count = 0 then
      begin
        // Extract all files
        if FVerbose then
          WriteLn('Extracting all files...')
        else
          Write('Extracting: ');

        for I := 0 to Archive.GetFileCount - 1 do
        begin
          try
            Entry := Archive.FileEntries[I];
            if FVerbose then
              WriteLn(Format('  Extracting: %s (%d bytes -> %d bytes)',
                [Entry.FileName, Entry.CompressedSize, Entry.OriginalSize]))
            else
              Write('.');

            Archive.ExtractFile(Entry.FileName,
              IncludeTrailingPathDelimiter(OutputPath) + ExtractFileName(Entry.FileName));
            Inc(FilesExtracted);
            Inc(Stats.BytesProcessed, Entry.OriginalSize);
          except
            on E: Exception do
            begin
              if not FVerbose then
                WriteLn('');
              WriteLn('Error extracting file: ' + E.Message);
              Result := 1;
              Inc(Stats.Errors);
            end;
          end;
        end;

        if not FVerbose then
          WriteLn('');
      end
      else
      begin
        // Extract specific files (with wildcard support)
        if HasWildcards then
        begin
          // If wildcards are present, iterate through all archive files and match patterns
          for I := 0 to Archive.GetFileCount - 1 do
          begin
            Entry := Archive.FileEntries[I];
            Matched := False;
            
            // Check if file matches any pattern
            for J := 0 to FFileList.Count - 1 do
            begin
              if MatchesPattern(Entry.FileName, FFileList[J]) then
              begin
                Matched := True;
                Break;
              end;
            end;
            
            if Matched then
            begin
              try
                if FVerbose then
                  WriteLn(Format('Extracting: %s (%d bytes -> %d bytes)',
                    [Entry.FileName, Entry.CompressedSize, Entry.OriginalSize]))
                else
                  Write('.');
                
                Archive.ExtractFile(Entry.FileName,
                  OutputPath + '\' + ExtractFileName(Entry.FileName));
                Inc(FilesExtracted);
                Inc(Stats.BytesProcessed, Entry.OriginalSize);
              except
                on E: Exception do
                begin
                  if not FVerbose then
                    WriteLn('');
                  WriteLn('Error extracting file ' + Entry.FileName + ': ' + E.Message);
                  Result := 1;
                  Inc(Stats.Errors);
                end;
              end;
            end;
          end;
          
          if not FVerbose and (FilesExtracted > 0) then
            WriteLn('');
        end
        else
        begin
          // No wildcards - extract exact file names
          for FileName in FFileList do
          begin
            try
              if FVerbose then
                WriteLn('Extracting: ' + FileName);
              Entry := Archive.GetFileInfo(FileName);
              Archive.ExtractFile(FileName, IncludeTrailingPathDelimiter(OutputPath) + ExtractFileName(FileName));
              Inc(FilesExtracted);
              if Assigned(Entry) then
                Inc(Stats.BytesProcessed, Entry.OriginalSize);
            except
              on E: Exception do
              begin
                WriteLn('Error extracting file ' + FileName + ': ' + E.Message);
                Result := 1;
                Inc(Stats.Errors);
              end;
            end;
          end;
        end;
      end;

      Stats.FilesProcessed := FilesExtracted;

      if FVerbose or (FilesExtracted > 0) then
        WriteLn(Format('Extracted %d files to %s', [FilesExtracted, OutputPath]));

      finally
        Archive.Free;
      end;
    except
      on E: Exception do
      begin
        WriteLn('Error: ' + E.Message);
        Result := 1;
        Inc(Stats.Errors);
      end;
    end;

    ShowOperationEnd('Extract', Result = 0);
  finally
    Stats.Stop;
    ShowTimingStats('Extract', Stats);
    Stats.Free;
  end;
end;

function TCommandLine.ExecuteList: Integer;
var
  Archive: TSMARTLARKArchive;
  I: Integer;
  Entry: TArchiveFileEntry;
  Stats: TOperationStats;
begin
  Result := 0;
  Stats := TOperationStats.Create;

  try
    Stats.Start;

    if not System.SysUtils.FileExists(FArchiveFile) then
    begin
      WriteLn('Error: Archive file not found - ' + FArchiveFile);
      Result := 1;
      Inc(Stats.Errors);
      Exit;
    end;

    try
      Archive := TSMARTLARKArchive.Create;
      try
        Archive.OpenArchive(FArchiveFile);
        for I := 0 to Archive.GetFileCount - 1 do
        begin
          Entry := Archive.FileEntries[I];
          Inc(Stats.BytesProcessed, Entry.OriginalSize);
        end;
        Stats.FilesProcessed := Archive.GetFileCount;
        Archive.ListFiles;
      finally
        Archive.Free;
      end;
    except
      on E: Exception do
      begin
        WriteLn('Error: ' + E.Message);
        Result := 1;
        Inc(Stats.Errors);
      end;
    end;
  finally
    Stats.Stop;
    ShowTimingStats('List', Stats);
    Stats.Free;
  end;
end;

function TCommandLine.ExecuteDelete: Integer;
var
  Archive: TSMARTLARKArchive;
  FileName: string;
  FilesDeleted: Integer;
  I, J: Integer;
  Entry: TArchiveFileEntry;
  HasWildcards: Boolean;
  Matched: Boolean;
  FilesToDelete: TList<string>;
  Stats: TOperationStats;
begin
  Result := 0;
  FilesDeleted := 0;
  FilesToDelete := TList<string>.Create;
  Stats := TOperationStats.Create;

  try
    Stats.Start;

    if not System.SysUtils.FileExists(FArchiveFile) then
    begin
      WriteLn('Error: Archive file not found - ' + FArchiveFile);
      Result := 1;
      Inc(Stats.Errors);
      Exit;
    end;

    // Check if any pattern contains wildcards
    HasWildcards := False;
    for I := 0 to FFileList.Count - 1 do
    begin
      if (Pos('*', FFileList[I]) > 0) or (Pos('?', FFileList[I]) > 0) then
      begin
        HasWildcards := True;
        Break;
      end;
    end;

    ShowOperationStart('Deleting files from archive');

    try
      Archive := TSMARTLARKArchive.Create;
      try
        Archive.OpenArchive(FArchiveFile);

        if HasWildcards then
        begin
          // If wildcards are present, iterate through all archive files and match patterns
          for I := 0 to Archive.GetFileCount - 1 do
          begin
            Entry := Archive.FileEntries[I];
            Matched := False;
            
            // Check if file matches any pattern
            for J := 0 to FFileList.Count - 1 do
            begin
              if MatchesPattern(Entry.FileName, FFileList[J]) then
              begin
                Matched := True;
                Break;
              end;
            end;
            
            if Matched then
              FilesToDelete.Add(Entry.FileName);
          end;
        end
        else
        begin
          // No wildcards - use exact file names
          for FileName in FFileList do
            FilesToDelete.Add(FileName);
        end;

        // Delete matched files
        for FileName in FilesToDelete do
        begin
          try
            if FVerbose then
              WriteLn('Deleting: ' + FileName);

            Entry := Archive.GetFileInfo(FileName);
            if Assigned(Entry) then
            begin
              Archive.DeleteFile(FileName);
              Inc(FilesDeleted);
              Inc(Stats.BytesProcessed, Entry.OriginalSize);
            end
            else
            begin
              WriteLn('Warning: File not found in archive - ' + FileName);
            end;
          except
            on E: Exception do
            begin
              WriteLn('Error deleting file ' + FileName + ': ' + E.Message);
              Result := 1;
              Inc(Stats.Errors);
            end;
          end;
        end;

        if FilesDeleted > 0 then
        begin
          Archive.SaveArchive;
          WriteLn(Format('Deleted %d files from archive', [FilesDeleted]));
        end;

        Stats.FilesProcessed := FilesDeleted;

      finally
        Archive.Free;
      end;
    except
      on E: Exception do
      begin
        WriteLn('Error: ' + E.Message);
        Result := 1;
        Inc(Stats.Errors);
      end;
    end;
    ShowOperationEnd('Delete', Result = 0);
  finally
    Stats.Stop;
    ShowTimingStats('Delete', Stats);
    Stats.Free;
    FilesToDelete.Free;
  end;
end;

function TCommandLine.ExecuteTest: Integer;
var
  Archive: TSMARTLARKArchive;
  I: Integer;
  Entry: TArchiveFileEntry;
  Stats: TOperationStats;
begin
  Result := 0;
  Stats := TOperationStats.Create;

  try
    Stats.Start;

    if not System.SysUtils.FileExists(FArchiveFile) then
    begin
      WriteLn('Error: Archive file not found - ' + FArchiveFile);
      Result := 1;
      Inc(Stats.Errors);
      Exit;
    end;

    ShowOperationStart('Testing archive');

    try
      Archive := TSMARTLARKArchive.Create;
      try
        Archive.OpenArchive(FArchiveFile);
        for I := 0 to Archive.GetFileCount - 1 do
        begin
          Entry := Archive.FileEntries[I];
          Inc(Stats.BytesProcessed, Entry.OriginalSize);
        end;
        Stats.FilesProcessed := Archive.GetFileCount;
        Archive.TestIntegrity;
        WriteLn('');
        WriteLn('Archive test passed successfully.');
      finally
        Archive.Free;
      end;
    except
      on E: Exception do
      begin
        WriteLn('Error: ' + E.Message);
        Result := 1;
        Inc(Stats.Errors);
      end;
    end;

    ShowOperationEnd('Test', Result = 0);
  finally
    Stats.Stop;
    ShowTimingStats('Test', Stats);
    Stats.Free;
  end;
end;

function TCommandLine.ExecuteUpdate: Integer;
begin
  // Update is similar to Add
  Result := ExecuteAdd;
end;

function TCommandLine.Execute: Integer;
begin
  Result := 0;

  case FCommand of
    'a': Result := ExecuteAdd;
    'x': Result := ExecuteExtract;
    'l': Result := ExecuteList;
    'd': Result := ExecuteDelete;
    't': Result := ExecuteTest;
    'u': Result := ExecuteUpdate;
  else
    Result := 1;
  end;
end;

function TCommandLine.GetFileSize(const FileName: string): Int64;
var
  FileHandle: THandle;
  FileSizeHigh: DWORD;
  FileSizeLow: DWORD;
begin
  Result := -1;
  FileHandle := CreateFile(PChar(FileName), GENERIC_READ, FILE_SHARE_READ, nil, OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  if FileHandle <> INVALID_HANDLE_VALUE then
  try
    FileSizeLow := Winapi.Windows.GetFileSize(FileHandle, @FileSizeHigh);
    if FileSizeLow <> INVALID_FILE_SIZE then
      Result := Int64(FileSizeLow) + (Int64(FileSizeHigh) shl 32);
  finally
    CloseHandle(FileHandle);
  end;
end;

function TCommandLine.ValidateFilePath(const FilePath: string): Boolean;
var
  FullPath: string;
begin
  Result := False;
  
  if FilePath = '' then
    Exit;
  
  // Check for invalid characters in path
  if (Pos('<', FilePath) > 0) or (Pos('>', FilePath) > 0) or 
     (Pos('|', FilePath) > 0) or (Pos('"', FilePath) > 0) then
    Exit;
  
  // Try to expand and validate path
  try
    FullPath := TPath.GetFullPath(FilePath);
    Result := TFile.Exists(FullPath) or TDirectory.Exists(FullPath);
  except
    Result := False;
  end;
end;

function TCommandLine.ValidateFileName(const FileName: string): Boolean;
const
  INVALID_CHARS = ['<', '>', ':', '"', '/', '\', '|', '?', '*'];
var
  I: Integer;
begin
  Result := False;
  
  if FileName = '' then
    Exit;
  
  // Check length (Windows MAX_PATH is 260, but we'll be more conservative)
  if Length(FileName) > 255 then
    Exit;
  
  // Check for invalid characters
  for I := 1 to Length(FileName) do
    if CharInSet(FileName[I], INVALID_CHARS) then
      Exit;
  
  // Check for reserved names (CON, PRN, AUX, NUL, COM1-9, LPT1-9)
  if SameText(FileName, 'CON') or SameText(FileName, 'PRN') or
     SameText(FileName, 'AUX') or SameText(FileName, 'NUL') then
    Exit;
  
  Result := True;
end;

function TCommandLine.ValidateCompressionLevel(Level: Integer): Boolean;
begin
  Result := (Level >= 0) and (Level <= 9);
end;


function TCommandLine.ValidateArchivePath(const ArchivePath: string): Boolean;
var
  Dir: string;
begin
  Result := False;
  
  if ArchivePath = '' then
    Exit;
  
  // Validate filename
  if not ValidateFileName(ExtractFileName(ArchivePath)) then
    Exit;
  
  // Check if directory exists (for new archives) or file exists (for existing archives)
  Dir := ExtractFileDir(ArchivePath);
  if Dir <> '' then
  begin
    try
      Result := TDirectory.Exists(Dir);
    except
      Result := False;
    end;
  end
  else
    Result := True; // Current directory
end;

function TCommandLine.MatchesPattern(const FileName, Pattern: string): Boolean;
var
  PatternPos: Integer;
  
  function MatchRecursive(const FName: string; FPos: Integer; const Pat: string; PPos: Integer): Boolean;
  var
    FNameLen, PatLen: Integer;
    I: Integer;
  begin
    FNameLen := Length(FName);
    PatLen := Length(Pat);
    
    // If pattern is exhausted, filename must also be exhausted
    if PPos > PatLen then
      Exit(FPos > FNameLen);
    
    // If filename is exhausted, pattern must be all stars
    if FPos > FNameLen then
    begin
      for I := PPos to PatLen do
        if Pat[I] <> '*' then
          Exit(False);
      Exit(True);
    end;
    
    // Handle current pattern character
    case Pat[PPos] of
      '*':
      begin
        // Skip consecutive stars
        while (PPos < PatLen) and (Pat[PPos + 1] = '*') do
          Inc(PPos);
        
        // Try matching zero or more characters
        // First try matching zero characters (skip the star)
        if MatchRecursive(FName, FPos, Pat, PPos + 1) then
          Exit(True);
        
        // Then try matching one or more characters
        for I := FPos to FNameLen do
          if MatchRecursive(FName, I, Pat, PPos + 1) then
            Exit(True);
        
        Exit(False);
      end;
      
      '?':
      begin
        // Match exactly one character
        Exit(MatchRecursive(FName, FPos + 1, Pat, PPos + 1));
      end;
      
      else
      begin
        // Match exact character (case-insensitive)
        if (FPos <= FNameLen) and 
           (LowerCase(FName[FPos]) = LowerCase(Pat[PPos])) then
          Exit(MatchRecursive(FName, FPos + 1, Pat, PPos + 1))
        else
          Exit(False);
      end;
    end;
  end;
  
begin
  // Empty pattern matches only empty filename
  if Pattern = '' then
    Exit(FileName = '');
  
  // Empty filename matches only if pattern is all stars
  if FileName = '' then
  begin
    Result := True;
    for PatternPos := 1 to Length(Pattern) do
      if Pattern[PatternPos] <> '*' then
        Exit(False);
    Exit;
  end;
  
  // Use recursive matching
  Result := MatchRecursive(FileName, 1, Pattern, 1);
end;

end.

unit uSMARTLARKArchive;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections,
  uSMARTLARKTypes, uSMARTLARKExceptions, uLZHUF, uCRC32, uStreamHelpers, uStoreCompressor, uDeflateCompressor, uLZSSCompressor, uLZWCompressor, uLZ77Compressor;

type
  /// <summary>
  /// Main archive manager class for SMARTLARK archive format.
  /// Provides functionality to create, open, modify, and extract files from SMARTLARK archives.
  /// </summary>
  /// <remarks>
  /// This class supports multiple compression methods: Store, LZSS, LZHUF, DEFLATE, LZW, and LZ77.
  /// Archives use a central directory structure similar to ZIP format for efficient file access.
  /// </remarks>
  /// <example>
  /// <code>
  /// var
  ///   Archive: TSMARTLARKArchive;
  /// begin
  ///   Archive := TSMARTLARKArchive.Create;
  ///   try
  ///     Archive.CreateArchive('myarchive.lark');
  ///     Archive.CompressionMethod := cmDEFLATE;
  ///     Archive.CompressionLevel := 5;
  ///     Archive.AddFile('document.txt');
  ///     Archive.SaveArchive;
  ///   finally
  ///     Archive.Free;
  ///   end;
  /// end;
  /// </code>
  /// </example>
  TSMARTLARKArchive = class
  private
    FFileName: string;
    FFileEntries: TObjectList<TArchiveFileEntry>;
    FHeader: TSMARTLARKArchiveHeader;
    FStatistics: TArchiveStatistics;
    FCompressionLevel: TCompressionLevel;
    FCompressionMethod: TCompressionMethod;
    FIsModified: Boolean;
    FArchiveStream: TStream;
    FDirectoryOffset: Int64;
    FDirectorySize: Int64;

    procedure InitializeHeader;
    procedure ReadArchiveHeader(Stream: TStream);
    procedure WriteArchiveHeader(Stream: TStream);
    procedure ReadCentralDirectory(Stream: TStream);
    procedure WriteCentralDirectory(Stream: TStream);
    procedure CalculateStatistics;
    procedure ValidateArchive;
    function DecompressFileEntry(Entry: TArchiveFileEntry; CompressedData: TMemoryStream): TMemoryStream;
  public
    /// <summary>
    /// Creates a new instance of TSMARTLARKArchive.
    /// </summary>
    constructor Create;
    
    /// <summary>
    /// Destroys the archive instance and releases all resources.
    /// </summary>
    destructor Destroy; override;

    /// <summary>
    /// Opens an existing archive file for reading and modification.
    /// </summary>
    /// <param name="FileName">Path to the archive file to open.</param>
    /// <exception cref="ESMARTLARKIOException">Raised if the archive file cannot be found or opened.</exception>
    /// <exception cref="ESMARTLARKFormatException">Raised if the archive format is invalid or corrupted.</exception>
    /// <remarks>
    /// After opening, the archive structure is validated and file entries are loaded into memory.
    /// </remarks>
    procedure OpenArchive(const FileName: string);
    
    /// <summary>
    /// Creates a new empty archive file.
    /// </summary>
    /// <param name="FileName">Path where the new archive will be created.</param>
    /// <exception cref="ESMARTLARKIOException">Raised if the archive file cannot be created.</exception>
    /// <remarks>
    /// The archive is created with default header values. Use AddFile to add files to the archive.
    /// </remarks>
    procedure CreateArchive(const FileName: string);
    
    /// <summary>
    /// Saves all changes to the archive file.
    /// </summary>
    /// <exception cref="ESMARTLARKArchiveException">Raised if no archive is open or file name is not set.</exception>
    /// <remarks>
    /// This method writes the central directory and updates the archive structure.
    /// Call this method after making changes to ensure they are persisted.
    /// </remarks>
    procedure SaveArchive;
    
    /// <summary>
    /// Closes the archive and releases file handles.
    /// </summary>
    /// <remarks>
    /// If the archive has been modified, call SaveArchive before closing to persist changes.
    /// </remarks>
    procedure CloseArchive;

    /// <summary>
    /// Adds a file to the archive.
    /// </summary>
    /// <param name="SourcePath">Path to the source file on disk.</param>
    /// <param name="ArchivePath">Optional path/name for the file in the archive. If empty, uses the source file name.</param>
    /// <exception cref="ESMARTLARKIOException">Raised if the source file cannot be found or read.</exception>
    /// <exception cref="ESMARTLARKCompressionException">Raised if compression fails.</exception>
    /// <remarks>
    /// The file is compressed using the current CompressionMethod and CompressionLevel settings.
    /// </remarks>
    procedure AddFile(const SourcePath: string; const ArchivePath: string = '');
    
    /// <summary>
    /// Extracts a single file from the archive.
    /// </summary>
    /// <param name="ArchivePath">Path/name of the file in the archive.</param>
    /// <param name="DestinationPath">Path where the extracted file will be saved.</param>
    /// <exception cref="ESMARTLARKArchiveException">Raised if the file is not found in the archive.</exception>
    /// <exception cref="ESMARTLARKFormatException">Raised if CRC32 validation fails or data is corrupted.</exception>
    /// <exception cref="ESMARTLARKIOException">Raised if the destination file cannot be written.</exception>
    procedure ExtractFile(const ArchivePath: string; const DestinationPath: string);
    
    /// <summary>
    /// Extracts all files from the archive to the specified destination directory.
    /// </summary>
    /// <param name="DestinationPath">Directory where all files will be extracted.</param>
    /// <exception cref="ESMARTLARKIOException">Raised if the destination directory cannot be created or accessed.</exception>
    /// <remarks>
    /// Creates the destination directory if it doesn't exist. Preserves original file names.
    /// </remarks>
    procedure ExtractAll(const DestinationPath: string);
    
    /// <summary>
    /// Deletes a file from the archive.
    /// </summary>
    /// <param name="ArchivePath">Path/name of the file to delete from the archive.</param>
    /// <exception cref="ESMARTLARKArchiveException">Raised if the file is not found in the archive.</exception>
    /// <remarks>
    /// The file is removed from the file entries list. Call SaveArchive to persist the changes.
    /// </remarks>
    procedure DeleteFile(const ArchivePath: string);

    /// <summary>
    /// Lists all files in the archive to the console.
    /// </summary>
    /// <remarks>
    /// Displays file names, sizes, compression ratios, methods, and modification dates in a formatted table.
    /// </remarks>
    procedure ListFiles;
    
    /// <summary>
    /// Tests the integrity of all files in the archive by verifying CRC32 checksums.
    /// </summary>
    /// <exception cref="ESMARTLARKFormatException">Raised if any file fails CRC32 validation.</exception>
    /// <remarks>
    /// This method extracts and verifies each file without saving them to disk.
    /// </remarks>
    procedure TestIntegrity;
    
    /// <summary>
    /// Rebuilds the archive structure, removing gaps and optimizing file layout.
    /// </summary>
    /// <remarks>
    /// This operation creates a new archive with all files recompressed and reorganized.
    /// Useful for optimizing archive size after multiple deletions.
    /// </remarks>
    procedure RebuildArchive;

    /// <summary>
    /// Checks if a file exists in the archive.
    /// </summary>
    /// <param name="ArchivePath">Path/name of the file to check.</param>
    /// <returns>True if the file exists, False otherwise.</returns>
    function FileExists(const ArchivePath: string): Boolean;
    
    /// <summary>
    /// Retrieves information about a file in the archive.
    /// </summary>
    /// <param name="ArchivePath">Path/name of the file.</param>
    /// <returns>TArchiveFileEntry containing file metadata.</returns>
    /// <exception cref="ESMARTLARKArchiveException">Raised if the file is not found.</exception>
    function GetFileInfo(const ArchivePath: string): TArchiveFileEntry;
    
    /// <summary>
    /// Gets the total number of files in the archive.
    /// </summary>
    /// <returns>Number of files in the archive.</returns>
    function GetFileCount: Integer;

    /// <summary>
    /// Gets the file name of the currently open archive.
    /// </summary>
    property FileName: string read FFileName;
    
    /// <summary>
    /// Gets the list of all file entries in the archive.
    /// </summary>
    /// <remarks>
    /// This is a read-only list. Use AddFile, DeleteFile methods to modify the archive.
    /// </remarks>
    property FileEntries: TObjectList<TArchiveFileEntry> read FFileEntries;
    
    /// <summary>
    /// Gets archive statistics including total size, compressed size, and compression ratio.
    /// </summary>
    property Statistics: TArchiveStatistics read FStatistics;
    
    /// <summary>
    /// Gets or sets the compression level (0-9) for new files added to the archive.
    /// </summary>
    /// <remarks>
    /// Higher levels provide better compression but take more time. Level 0 means no compression (store).
    /// </remarks>
    property CompressionLevel: TCompressionLevel read FCompressionLevel write FCompressionLevel;
    
    /// <summary>
    /// Gets or sets the compression method for new files added to the archive.
    /// </summary>
    /// <remarks>
    /// Available methods: cmStore, cmLZSS, cmLZHUF, cmDEFLATE, cmLZW, cmLZ77.
    /// </remarks>
    property CompressionMethod: TCompressionMethod read FCompressionMethod write FCompressionMethod;
    
    /// <summary>
    /// Indicates whether the archive has been modified since it was opened or last saved.
    /// </summary>
    property IsModified: Boolean read FIsModified;
  end;

implementation

uses
  Winapi.Windows, System.DateUtils, System.Math;

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

// Helper function to get file size
function GetFileSize(const FileName: string): Int64;
var
  FileHandle: THandle;
  FileSizeHigh: DWORD;
  FileSizeLow: DWORD;
begin
  Result := 0;
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

function DateTimeToFileTimeInt64(const ADateTime: TDateTime): Int64;
var
  ST: TSystemTime;
  FT: TFileTime;
begin
  DateTimeToSystemTime(ADateTime, ST);
  if not SystemTimeToFileTime(ST, FT) then
    Result := 0
  else
    Result := (Int64(FT.dwHighDateTime) shl 32) or Int64(FT.dwLowDateTime);
end;

function FileTimeInt64ToDateTime(const AFileTime: Int64): TDateTime;
var
  FT: TFileTime;
  ST: TSystemTime;
begin
  FT.dwLowDateTime := DWORD(AFileTime and $FFFFFFFF);
  FT.dwHighDateTime := DWORD(UInt64(AFileTime) shr 32);
  if FileTimeToSystemTime(FT, ST) then
    Result := SystemTimeToDateTime(ST)
  else
    Result := 0;
end;

{ TSMARTLARKArchive }

constructor TSMARTLARKArchive.Create;
begin
  inherited Create;
  FFileEntries := TObjectList<TArchiveFileEntry>.Create(True);
  FCompressionLevel := DEFAULT_COMPRESSION_LEVEL;
  FCompressionMethod := cmLZHUF; // Default to LZHUF
  FIsModified := False;
  FArchiveStream := nil;
  FillChar(FHeader, SizeOf(FHeader), 0);
  InitializeHeader;
end;

destructor TSMARTLARKArchive.Destroy;
begin
  CloseArchive;
  FFileEntries.Free;
  inherited;
end;

procedure TSMARTLARKArchive.InitializeHeader;
begin
  FHeader.Signature := SMARTLARK_ARCHIVE_SIGNATURE;
  FHeader.FormatVersion := SMARTLARK_FORMAT_VERSION;
  FHeader.MinUnpackVersion := SMARTLARK_MIN_UNPACK_VERSION;
  FHeader.Flags := 0;
  FHeader.BlockSize := DEFAULT_BUFFER_SIZE;
  FHeader.DefaultCompressionLevel := DEFAULT_COMPRESSION_LEVEL;
  FHeader.CreationTime := DateTimeToFileTimeInt64(Now);
  FHeader.LastUpdateTime := FHeader.CreationTime;
  FHeader.FileCount := 0;
end;

procedure TSMARTLARKArchive.ReadArchiveHeader(Stream: TStream);
var
  ReadSignature: DWORD;
begin
  // Read 60-byte header
  ReadSignature := TStreamHelper.ReadDWord(Stream);
  FHeader.Signature := ReadSignature;

  FHeader.FormatVersion := TStreamHelper.ReadWord(Stream);
  FHeader.MinUnpackVersion := TStreamHelper.ReadWord(Stream);
  FHeader.Flags := TStreamHelper.ReadDWord(Stream);
  FHeader.BlockSize := TStreamHelper.ReadDWord(Stream);
  FHeader.DefaultCompressionLevel := TStreamHelper.ReadDWord(Stream);
  FHeader.Reserved1 := TStreamHelper.ReadDWord(Stream);
  FHeader.CreationTime := TStreamHelper.ReadInt64(Stream);
  FHeader.LastUpdateTime := TStreamHelper.ReadInt64(Stream);

  // Read reserved data (16 bytes)
  Stream.Read(FHeader.ReservedData[0], 16);

  FHeader.FileCount := TStreamHelper.ReadDWord(Stream);

  // Support both SMARTLARK and legacy LARC signatures
  if (FHeader.Signature <> SMARTLARK_ARCHIVE_SIGNATURE) and
     (FHeader.Signature <> LARC_ARCHIVE_SIGNATURE) then
    raise ESMARTLARKFormatException.Create('Invalid SMARTLARK archive signature. The file may be corrupted or not a SMARTLARK archive.', ecInvalidSignature);

  if FHeader.FormatVersion <> SMARTLARK_FORMAT_VERSION then
    raise ESMARTLARKFormatException.CreateFmt('Unsupported SMARTLARK format version %d.%d. This version supports v2.0 only.', 
      ecUnsupportedVersion, [FHeader.FormatVersion shr 8, FHeader.FormatVersion and $FF]);
end;

procedure TSMARTLARKArchive.WriteArchiveHeader(Stream: TStream);
begin
  // Write 60-byte header
  TStreamHelper.WriteDWord(Stream, FHeader.Signature);
  TStreamHelper.WriteWord(Stream, FHeader.FormatVersion);
  TStreamHelper.WriteWord(Stream, FHeader.MinUnpackVersion);
  TStreamHelper.WriteDWord(Stream, FHeader.Flags);
  TStreamHelper.WriteDWord(Stream, FHeader.BlockSize);
  TStreamHelper.WriteDWord(Stream, FHeader.DefaultCompressionLevel);
  TStreamHelper.WriteDWord(Stream, FHeader.Reserved1);
  TStreamHelper.WriteInt64(Stream, FHeader.CreationTime);
  TStreamHelper.WriteInt64(Stream, FHeader.LastUpdateTime);

  // Write reserved data (16 bytes)
  Stream.Write(FHeader.ReservedData[0], 16);

  TStreamHelper.WriteDWord(Stream, FHeader.FileCount);
end;

procedure TSMARTLARKArchive.ReadCentralDirectory(Stream: TStream);
var
  DirSignature: DWORD;
  I: Integer;
  Entry: TArchiveFileEntry;
  DirHeader: TSMARTLARKCentralDirectory;
  NameLen: WORD;
  StartPos: Int64;
  CurrentPos: Int64;
  Found: Boolean;
  J: Integer;
  OtherEntry: TArchiveFileEntry;
begin
  // Search for directory signature from end of file
  // Try reading from end first (most likely position)
  StartPos := Stream.Size;
  if StartPos < 60 + 4 then
    raise ESMARTLARKFormatException.CreateFmt('Archive too small (%d bytes). Minimum size is 60 bytes.', 
      ecArchiveTooSmall, [Stream.Size]);
  
  Found := False;
  DirSignature := 0;
  CurrentPos := 0; // Initialize to avoid W1036 warning
  
  // First, try reading from end (last 4KB), but not before header
  if StartPos > 60 + 4 then
  begin
    CurrentPos := StartPos - 4096;
    if CurrentPos < 60 then
      CurrentPos := 60;
    while CurrentPos <= StartPos - 4 do
    begin
      Stream.Position := CurrentPos;
      if Stream.Position + 4 > Stream.Size then
        Break;
      DirSignature := TStreamHelper.ReadDWord(Stream);
      if (DirSignature = SMARTLARK_DIRECTORY_SIGNATURE) or (DirSignature = LARC_DIRECTORY_SIGNATURE) then
      begin
        Stream.Position := CurrentPos;
        Found := True;
        Break;
      end;
      Inc(CurrentPos);
    end;
  end;
  
  // If not found, search backwards byte by byte (max 64KB)
  if not Found then
  begin
    CurrentPos := StartPos - 4;
    if CurrentPos < 60 then
      CurrentPos := 60;
    while (CurrentPos >= 60) and (StartPos - CurrentPos < 65536) do
    begin
      Stream.Position := CurrentPos;
      if Stream.Position + 4 > Stream.Size then
        Break;
      DirSignature := TStreamHelper.ReadDWord(Stream);
      if (DirSignature = SMARTLARK_DIRECTORY_SIGNATURE) or (DirSignature = LARC_DIRECTORY_SIGNATURE) then
      begin
        Stream.Position := CurrentPos;
        Found := True;
        Break;
      end;
      Dec(CurrentPos);
    end;
  end;
  
  if not Found then
    raise ESMARTLARKFormatException.Create('Central directory not found. The archive may be corrupted or incomplete.', ecDirectoryNotFound);

  // Read directory header
  FDirectoryOffset := CurrentPos;
  // Note: Stream.Position should be at CurrentPos + 4 (after signature)
  DirHeader.Signature := DirSignature;
  
  // Verify we're at the right position for FileCount
  if Stream.Position <> CurrentPos + 4 then
    Stream.Position := CurrentPos + 4;
  
  DirHeader.FileCount := TStreamHelper.ReadDWord(Stream);
  
  // Validate file count (FileCount is DWORD, so it's always >= 0)
  if DirHeader.FileCount > 1000000 then
    raise ESMARTLARKFormatException.CreateFmt('Invalid file count in central directory: %d (position: %d, stream size: %d). The archive may be corrupted.', 
      ecInvalidFileCount, [DirHeader.FileCount, Stream.Position, Stream.Size]);

  FFileEntries.Clear;

  // Read directory entries
  // After FileCount, we should be at CurrentPos + 8
  for I := 0 to DirHeader.FileCount - 1 do
  begin
    Entry := TArchiveFileEntry.Create;
    try
      // Verify position before reading each entry
      if I = 0 then
      begin
        // First entry should start at CurrentPos + 8 (after signature + FileCount)
        if Stream.Position <> CurrentPos + 8 then
          Stream.Position := CurrentPos + 8;
      end;
      
      Entry.FileOffset := TStreamHelper.ReadInt64(Stream);
      Entry.OriginalSize := TStreamHelper.ReadInt64(Stream);
      Entry.CompressedSize := TStreamHelper.ReadDWord(Stream);
      Entry.CRC32 := TStreamHelper.ReadDWord(Stream);
      Entry.ModificationTime := TStreamHelper.ReadInt64(Stream);
      // Read method/level (always present in v2.0 format)
      // For backward compatibility, check if we're at end of stream
      if Stream.Position + 2 <= Stream.Size then
      begin
        Entry.CompressionMethod := TCompressionMethod(TStreamHelper.ReadByte(Stream));
        Entry.CompressionLevel := TStreamHelper.ReadByte(Stream);
      end
      else
      begin
        // Older archives without method/level; choose reasonable default
        Entry.CompressionMethod := cmDEFLATE;
        Entry.CompressionLevel := DEFAULT_COMPRESSION_LEVEL;
      end;
      
      // Read filename length
      NameLen := 0; // Initialize to avoid W1036 warning
      if Stream.Position + 2 <= Stream.Size then
        NameLen := TStreamHelper.ReadWord(Stream)
      else
        raise ESMARTLARKFormatException.Create('Unexpected end of stream while reading directory entry. The archive may be corrupted or incomplete.', ecInvalidFileCount);
      
      // Validate name length to prevent memory allocation issues
      if (NameLen = 0) or (NameLen > 260) then
        raise ESMARTLARKFormatException.CreateFmt('Invalid filename length: %d at entry %d (stream position: %d, stream size: %d). The archive may be corrupted.', 
          ecInvalidFileName, [NameLen, I, Stream.Position, Stream.Size]);
      
      // Verify we have enough data to read
      if Stream.Position + NameLen > Stream.Size then
        raise ESMARTLARKFormatException.CreateFmt('Not enough data to read filename at entry %d (need %d bytes, have %d). The archive may be corrupted.', 
          ecInvalidFileName, [I, NameLen, Stream.Size - Stream.Position]);
      
      Entry.FileName := TStreamHelper.ReadString(Stream, NameLen);
      
      // Validate file offset immediately after reading
      if (Entry.FileOffset < 60) or (Entry.FileOffset >= Stream.Size) then
        raise ESMARTLARKFormatException.CreateFmt('Invalid file offset: %d at entry %d. The archive structure may be corrupted.', 
          ecInvalidFileOffset, [Entry.FileOffset, I]);
      
      // Validate compressed size
      if Entry.CompressedSize > Stream.Size then
        raise ESMARTLARKFormatException.CreateFmt('Invalid compressed size: %d at entry %d. The archive structure may be corrupted.', 
          ecInvalidSizes, [Entry.CompressedSize, I]);
      
      // Check for zip bomb (suspicious compression ratio)
      // A ratio > 1000:1 is highly suspicious and likely indicates a zip bomb
      if (Entry.CompressedSize > 0) and (Entry.OriginalSize > 0) and
         (Entry.OriginalSize / Entry.CompressedSize > 1000) then
        raise ESMARTLARKFormatException.CreateFmt(
          'Suspicious compression ratio detected for file %s (ratio: %.1f:1) at entry %d. File may be a zip bomb.',
          ecInvalidSizes, [Entry.FileName, Entry.OriginalSize / Entry.CompressedSize, I]);
      
      // Check for overlap with existing files
      for J := 0 to FFileEntries.Count - 1 do
      begin
        OtherEntry := FFileEntries[J];
        if (Entry.FileOffset < OtherEntry.FileOffset + OtherEntry.CompressedSize) and
           (Entry.FileOffset + Entry.CompressedSize > OtherEntry.FileOffset) then
          raise ESMARTLARKFormatException.CreateFmt(
            'File offset overlaps with existing file "%s" at entry %d. Archive may be corrupted.',
            ecInvalidFileOffset, [OtherEntry.FileName, I]);
      end;
      
      // Check if file data extends beyond directory
      if Entry.FileOffset + Entry.CompressedSize > FDirectoryOffset then
        raise ESMARTLARKFormatException.CreateFmt(
          'File data for entry %s extends beyond central directory. Offset: %d, Size: %d, Directory: %d.',
          ecInvalidFileOffset, [Entry.FileName, Entry.FileOffset, Entry.CompressedSize, FDirectoryOffset]);

      FFileEntries.Add(Entry);
    except
      Entry.Free;
      raise;
    end;
  end;
  // Approximate directory size (till EOF)
  FDirectorySize := Stream.Size - FDirectoryOffset;
end;

procedure TSMARTLARKArchive.WriteCentralDirectory(Stream: TStream);
var
  Entry: TArchiveFileEntry;
  I: Integer;
  NameBytes: TBytes;
begin

  // Write central directory signature
  TStreamHelper.WriteDWord(Stream, SMARTLARK_DIRECTORY_SIGNATURE);
  TStreamHelper.WriteDWord(Stream, FFileEntries.Count);

  // Write all directory entries
  for I := 0 to FFileEntries.Count - 1 do
  begin
    Entry := FFileEntries[I];
    TStreamHelper.WriteInt64(Stream, Entry.FileOffset);
    TStreamHelper.WriteInt64(Stream, Entry.OriginalSize);
    TStreamHelper.WriteDWord(Stream, Entry.CompressedSize);
    TStreamHelper.WriteDWord(Stream, Entry.CRC32);
      TStreamHelper.WriteInt64(Stream, Entry.ModificationTime);
      // Write compression method and level
      TStreamHelper.WriteByte(Stream, Ord(Entry.CompressionMethod));
      TStreamHelper.WriteByte(Stream, Entry.CompressionLevel);
      // Write filename length and data
      NameBytes := TEncoding.ANSI.GetBytes(Entry.FileName);
      TStreamHelper.WriteWord(Stream, Length(NameBytes));
      if Length(NameBytes) > 0 then
        Stream.Write(NameBytes[0], Length(NameBytes));
  end;

  // Update header with directory info
  FHeader.FileCount := FFileEntries.Count;
  FHeader.LastUpdateTime := DateTimeToFileTimeInt64(Now);
end;

procedure TSMARTLARKArchive.CalculateStatistics;
var
  Entry: TArchiveFileEntry;
  I: Integer;
begin
  FStatistics.FileCount := FFileEntries.Count;
  FStatistics.TotalOriginalSize := 0;
  FStatistics.TotalCompressedSize := 0;

  for I := 0 to FFileEntries.Count - 1 do
  begin
    Entry := FFileEntries[I];
    Inc(FStatistics.TotalOriginalSize, Entry.OriginalSize);
    Inc(FStatistics.TotalCompressedSize, Entry.CompressedSize);
  end;
end;

procedure TSMARTLARKArchive.OpenArchive(const FileName: string);
var
  Stream: TFileStream;
begin
  if not System.SysUtils.FileExists(FileName) then
    raise ESMARTLARKIOException.CreateFmt('Archive file not found: %s. Please check the file path and ensure the file exists.', 
      ecArchiveNotFound, [FileName]);

  FFileName := FileName;
  Stream := TFileStream.Create(FileName, fmOpenRead);
  try
    ReadArchiveHeader(Stream);
    ReadCentralDirectory(Stream);
    CalculateStatistics;
    ValidateArchive; // Validate archive structure after reading
  finally
    Stream.Free;
  end;

  FIsModified := False;
end;

procedure TSMARTLARKArchive.CreateArchive(const FileName: string);
begin
  FFileName := FileName;
  FFileEntries.Clear;
  InitializeHeader;
  FIsModified := True;
end;

procedure TSMARTLARKArchive.SaveArchive;
var
  Stream: TFileStream;
  SourceArchive: TFileStream;
  Entry: TArchiveFileEntry;
  I: Integer;
  Temp: TMemoryStream;
  OutPath: string;
begin
  if FFileName = '' then
    raise ESMARTLARKArchiveException.Create('Archive file name not set. Please specify an archive file name before performing operations.', ecArchiveNameNotSet);

  // Open source archive (if exists) to read existing compressed data
  if System.SysUtils.FileExists(FFileName) then
    SourceArchive := TFileStream.Create(FFileName, fmOpenRead)
  else
    SourceArchive := nil;
  try
    // Choose output path
    if Assigned(SourceArchive) then
      OutPath := FFileName + '.tmp'
    else
      OutPath := FFileName;

    Stream := TFileStream.Create(OutPath, fmCreate);
    try
      // Write archive header
      WriteArchiveHeader(Stream);
      
      // Write all file data
      for I := 0 to FFileEntries.Count - 1 do
      begin
        Entry := FFileEntries[I];
        Entry.FileOffset := Stream.Position;
        
        if Assigned(Entry.CompressedData) and (Entry.CompressedData.Size > 0) then
        begin
          Entry.CompressedData.Position := 0;
          Stream.CopyFrom(Entry.CompressedData, Entry.CompressedData.Size);
        end
        else if Assigned(SourceArchive) and (Entry.CompressedSize > 0) then
        begin
          // Read compressed bytes from the original archive
          Temp := TMemoryStream.Create;
          try
            SourceArchive.Position := Entry.FileOffset;
            TStreamHelper.CopyBytes(SourceArchive, Temp, Entry.CompressedSize);
            Temp.Position := 0;
            Stream.CopyFrom(Temp, Temp.Size);
          finally
            Temp.Free;
          end;
        end
        else
        begin
          // No source to read from
          raise ESMARTLARKFormatException.CreateFmt('No compressed data for file %s. The file entry exists but has no data.', 
            ecNoCompressedData, [Entry.FileName]);
        end;
      end;
      
      // Write central directory
      WriteCentralDirectory(Stream);
      FIsModified := False;
    finally
      Stream.Free;
    end;

    // If we wrote to temp, replace the original file atomically
    if Assigned(SourceArchive) then
    begin
      SourceArchive.Free;
      SourceArchive := nil;
      
      try
        // On Windows, use MoveFileEx for atomic replacement
        // First, try to delete existing file (if it exists)
        if System.SysUtils.FileExists(FFileName) then
        begin
          // Try to delete the original file
          if not System.SysUtils.DeleteFile(FFileName) then
            raise ESMARTLARKIOException.CreateFmt(
              'Cannot delete existing archive file: %s. It may be locked by another process.',
              ecArchiveNotFound, [FFileName]);
        end;
        
        // Rename temp file to final name (atomic on same filesystem)
        if not System.SysUtils.RenameFile(OutPath, FFileName) then
          raise ESMARTLARKIOException.CreateFmt(
            'Cannot rename temporary archive file to: %s. The archive may be in use.',
            ecArchiveNotFound, [FFileName]);
      except
        // Clean up temp file on error
        if System.SysUtils.FileExists(OutPath) then
          System.SysUtils.DeleteFile(OutPath);
        raise;
      end;
    end;
  finally
    if Assigned(SourceArchive) then
      SourceArchive.Free;
  end;
end;

procedure TSMARTLARKArchive.CloseArchive;
begin
  if FIsModified then
    SaveArchive;

  FFileEntries.Clear;
  FFileName := '';
end;

procedure TSMARTLARKArchive.AddFile(const SourcePath, ArchivePath: string);
  var
  SourceStream, CompressedStream: TMemoryStream;
  Entry: TArchiveFileEntry;
  Codec: TLZHUFCodec;
  StoreCodec: TStoreCompressor;
  DeflateCodec: TDeflateCompressor;
  LZSSCompressor: TLZSSCompressor;
  LZWCompressor: TLZWCompressor;
  LZ77Compressor: TLZ77Compressor;
  CRC: TCRC32;
  FileInfo: TSearchRec;
  SearchResult: Integer;
begin
  if not System.SysUtils.FileExists(SourcePath) then
    raise ESMARTLARKIOException.CreateFmt('Source file not found: %s. Please check the file path and ensure the file exists.', 
      ecSourceNotFound, [SourcePath]);

  Entry := TArchiveFileEntry.Create;

  try
    // Get file info
    SearchResult := FindFirst(SourcePath, faAnyFile, FileInfo);
    if SearchResult <> 0 then
      raise ESMARTLARKIOException.CreateFmt('FindFirst failed for %s. The file or directory may not exist or access is denied.', 
        ecFindFirstFailed, [SourcePath]);
    try
      if ArchivePath = '' then
        Entry.FileName := FileInfo.Name
      else
        Entry.FileName := ArchivePath;
      {$WARN SYMBOL_PLATFORM OFF}
      Entry.ModificationTime := Int64(FileInfo.FindData.ftLastWriteTime);
      {$WARN SYMBOL_PLATFORM ON}
      Entry.FileAttributes := FileInfo.Attr;
    finally
      System.SysUtils.FindClose(FileInfo);
    end;

    // Compress file
    SourceStream := TMemoryStream.Create;
    CompressedStream := TMemoryStream.Create;
    Codec := nil;
    StoreCodec := nil;
    try
      SourceStream.LoadFromFile(SourcePath);
      Entry.OriginalSize := SourceStream.Size;

      // Calculate CRC
      SourceStream.Position := 0;
      CRC := TCRC32.Create;
      try
        CRC.Update(SourceStream, Entry.OriginalSize);
        Entry.CRC32 := CRC.GetDigest;
      finally
        CRC.Free;
      end;

      // Compress based on selected method
      SourceStream.Position := 0;
      Codec := nil;
      StoreCodec := nil;
      DeflateCodec := nil;
      LZSSCompressor := nil;
      LZWCompressor := nil;
      LZ77Compressor := nil;
      try
        case FCompressionMethod of
          cmStore:
          begin
            // Store: no compression, just copy
            StoreCodec := TStoreCompressor.Create;
            StoreCodec.Compress(SourceStream, CompressedStream);
            Entry.CompressedSize := CompressedStream.Size;
            Entry.CompressionLevel := 0; // No compression level for Store
            Entry.CompressionMethod := cmStore;
          end;
          cmLZSS:
          begin
            // LZSS: Lempel-Ziv-Storer-Szymanski (no Huffman)
            LZSSCompressor := TLZSSCompressor.Create;
            LZSSCompressor.Compress(SourceStream, CompressedStream);
            Entry.CompressedSize := CompressedStream.Size;
            Entry.CompressionLevel := FCompressionLevel;
            Entry.CompressionMethod := cmLZSS;
          end;
          cmLZHUF:
          begin
            // LZHUF: LZSS + Huffman
            Codec := TLZHUFCodec.Create;
            Codec.Compress(SourceStream, CompressedStream);
            Entry.CompressedSize := CompressedStream.Size;
            Entry.CompressionLevel := FCompressionLevel;
            Entry.CompressionMethod := cmLZHUF;
          end;
          cmDEFLATE:
          begin
            // DEFLATE: LZ77 + Huffman (zlib)
            DeflateCodec := TDeflateCompressor.Create(FCompressionLevel);
            DeflateCodec.Compress(SourceStream, CompressedStream);
            Entry.CompressedSize := CompressedStream.Size;
            Entry.CompressionLevel := FCompressionLevel;
            Entry.CompressionMethod := cmDEFLATE;
          end;
          cmLZW:
          begin
            // LZW: Lempel-Ziv-Welch (UNIX compress)
            LZWCompressor := TLZWCompressor.Create;
            LZWCompressor.Compress(SourceStream, CompressedStream);
            Entry.CompressedSize := CompressedStream.Size;
            Entry.CompressionLevel := 0; // LZW doesn't use compression levels
            Entry.CompressionMethod := cmLZW;
          end;
          cmLZ77:
          begin
            // LZ77: Classic Lempel-Ziv 1977
            LZ77Compressor := TLZ77Compressor.Create;
            LZ77Compressor.Compress(SourceStream, CompressedStream);
            Entry.CompressedSize := CompressedStream.Size;
            Entry.CompressionLevel := FCompressionLevel;
            Entry.CompressionMethod := cmLZ77;
          end;
        end;
        
        // Check for zip bomb (suspicious compression ratio)
        // A ratio > 1000:1 is highly suspicious and likely indicates a zip bomb
        if (Entry.CompressedSize > 0) and (Entry.OriginalSize > 0) and
           (Entry.OriginalSize / Entry.CompressedSize > 1000) then
          raise ESMARTLARKFormatException.CreateFmt(
            'Suspicious compression ratio detected for file %s (ratio: %.1f:1). File may be a zip bomb and was rejected.',
            ecInvalidSizes, [Entry.FileName, Entry.OriginalSize / Entry.CompressedSize]);
        
        // Save compressed data to entry
        Entry.CompressedData := TMemoryStream.Create;
        CompressedStream.Position := 0;
        Entry.CompressedData.CopyFrom(CompressedStream, CompressedStream.Size);
      finally
        FreeAndNil(Codec);
        FreeAndNil(StoreCodec);
        FreeAndNil(DeflateCodec);
        FreeAndNil(LZSSCompressor);
        FreeAndNil(LZWCompressor);
        FreeAndNil(LZ77Compressor);
      end;

      FFileEntries.Add(Entry);
      FIsModified := True;

    finally
      SourceStream.Free;
      CompressedStream.Free;
    end;
  except
    Entry.Free;
    raise;
  end;
end;

procedure TSMARTLARKArchive.ExtractFile(const ArchivePath, DestinationPath: string);
var
  Entry: TArchiveFileEntry;
  ArchiveStream: TFileStream;
  CompressedData, ExtractedData: TMemoryStream;
  CRC: TCRC32;
  ComputedCRC: DWORD;
begin
  Entry := GetFileInfo(ArchivePath);
  if Entry = nil then
    raise ESMARTLARKArchiveException.CreateFmt('File not found in archive: %s. Use "list" command to see available files.', 
      ecFileNotFound, [ArchivePath]);

  ArchiveStream := TFileStream.Create(FFileName, fmOpenRead);
  CompressedData := TMemoryStream.Create;
  ExtractedData := nil;

  try
    // Read compressed data from archive
    ArchiveStream.Position := Entry.FileOffset;
    TStreamHelper.CopyBytes(ArchiveStream, CompressedData, Entry.CompressedSize);

    // Decompress using common method
    ExtractedData := DecompressFileEntry(Entry, CompressedData);

    // Verify CRC
    ExtractedData.Position := 0;
    CRC := TCRC32.Create;
    try
      CRC.Update(ExtractedData, ExtractedData.Size);
      ComputedCRC := CRC.GetDigest;
    finally
      CRC.Free;
    end;

    // Write to destination FIRST, even if CRC doesn't match
    // This allows us to compare the extracted file with the original
    ExtractedData.SaveToFile(DestinationPath);
    
    // Then check CRC and report but don't fail (for debugging)
    if ComputedCRC <> Entry.CRC32 then
      raise ESMARTLARKFormatException.CreateFmt('CRC mismatch for file: %s (expected %08X, got %08X). The file may be corrupted.', 
        ecCRC32Mismatch, [ArchivePath, Entry.CRC32, ComputedCRC]);

  finally
    ArchiveStream.Free;
    CompressedData.Free;
    ExtractedData.Free;
  end;
end;

procedure TSMARTLARKArchive.ExtractAll(const DestinationPath: string);
var
  Entry: TArchiveFileEntry;
  I: Integer;
  DestPath: string;
begin
  DestPath := IncludeTrailingPathDelimiter(DestinationPath);
  for I := 0 to FFileEntries.Count - 1 do
  begin
    Entry := FFileEntries[I];
    ExtractFile(Entry.FileName, DestPath + ExtractFileName(Entry.FileName));
  end;
end;

procedure TSMARTLARKArchive.DeleteFile(const ArchivePath: string);
var
  I: Integer;
begin
  for I := FFileEntries.Count - 1 downto 0 do
  begin
    if SameText(FFileEntries[I].FileName, ArchivePath) then
    begin
      FFileEntries.Delete(I);
      FIsModified := True;
      Break;
    end;
  end;
end;

procedure TSMARTLARKArchive.ListFiles;
var
  Entry: TArchiveFileEntry;
  Ratio: Double;
  I: Integer;
  Meth: string;
  MethodStats: array[TCompressionMethod] of record
    Count: Integer;
    TotalOriginal: Int64;
    TotalCompressed: Int64;
  end;
  M: TCompressionMethod;
begin
  WriteLn('Archive: ' + FFileName);
  WriteLn(Format('Format: SMARTLARK v%.2f', [FHeader.FormatVersion / 256]));
  WriteLn('');
  WriteLn('  Size         Compressed  Ratio  Meth Lvl  Date           Time      Name');
  WriteLn('-----------  -----------  -----  ---- ---  ----------- -------- --------');

  CalculateStatistics;

  for I := 0 to FFileEntries.Count - 1 do
  begin
    Entry := FFileEntries[I];
    Ratio := 0.0;
    if Entry.OriginalSize > 0 then
      Ratio := (Entry.CompressedSize * 100.0) / Entry.OriginalSize;
    case Entry.CompressionMethod of
      cmStore: Meth := 'STOR';
      cmLZSS: Meth := 'LZSS';
      cmLZHUF: Meth := 'LZHU';
      cmDEFLATE: Meth := 'DEFL';
      cmLZW: Meth := 'LZW';
      cmLZ77: Meth := 'LZ77';
    else Meth := 'UNKN';
    end;

    WriteLn(Format('%11d  %11d  %5.1f%%  %4s %3d  %s  %s  %s',
      [Entry.OriginalSize, Entry.CompressedSize, Ratio, Meth, Entry.CompressionLevel,
       FormatDateTime('yyyy-mm-dd', FileTimeInt64ToDateTime(Entry.ModificationTime)),
       FormatDateTime('hh:mm:ss', FileTimeInt64ToDateTime(Entry.ModificationTime)),
       ExtractFileName(Entry.FileName)]));
  end;

  WriteLn('-----------  -----------  -----');
  WriteLn(Format('%11d  %11d  %5.1f%%',
    [FStatistics.TotalOriginalSize, FStatistics.TotalCompressedSize,
     FStatistics.GetCompressionRatio]));
  
  // Extended statistics
  WriteLn('');
  WriteLn('=== Archive Statistics ===');
  WriteLn(Format('Total files: %d', [FStatistics.FileCount]));
  WriteLn(Format('Original size: %s', [FormatBytes(FStatistics.TotalOriginalSize)]));
  WriteLn(Format('Compressed size: %s', [FormatBytes(FStatistics.TotalCompressedSize)]));
  WriteLn(Format('Compression ratio: %.1f%%', [FStatistics.GetCompressionRatio]));
  WriteLn(Format('Space saved: %s (%.1f%%)', 
    [FormatBytes(FStatistics.TotalOriginalSize - FStatistics.TotalCompressedSize),
     ((FStatistics.TotalOriginalSize - FStatistics.TotalCompressedSize) * 100.0) / 
     Max(FStatistics.TotalOriginalSize, 1)]));
  
  // Statistics by compression method
  WriteLn('');
  WriteLn('=== Compression Methods ===');
  
  for M := Low(TCompressionMethod) to High(TCompressionMethod) do
  begin
    MethodStats[M].Count := 0;
    MethodStats[M].TotalOriginal := 0;
    MethodStats[M].TotalCompressed := 0;
  end;
  
  for I := 0 to FFileEntries.Count - 1 do
  begin
    Entry := FFileEntries[I];
    Inc(MethodStats[Entry.CompressionMethod].Count);
    Inc(MethodStats[Entry.CompressionMethod].TotalOriginal, Entry.OriginalSize);
    Inc(MethodStats[Entry.CompressionMethod].TotalCompressed, Entry.CompressedSize);
  end;
  
  for M := Low(TCompressionMethod) to High(TCompressionMethod) do
  begin
    if MethodStats[M].Count > 0 then
    begin
      case M of
        cmStore: Meth := 'Store';
        cmLZSS: Meth := 'LZSS';
        cmLZHUF: Meth := 'LZHUF';
        cmDEFLATE: Meth := 'DEFLATE';
        cmLZW: Meth := 'LZW';
        cmLZ77: Meth := 'LZ77';
      else Meth := 'Unknown';
      end;
      
      Ratio := 0.0;
      if MethodStats[M].TotalOriginal > 0 then
        Ratio := (MethodStats[M].TotalCompressed * 100.0) / MethodStats[M].TotalOriginal;
      
      WriteLn(Format('  %-8s: %3d files, %s -> %s (%.1f%%)',
        [Meth, MethodStats[M].Count,
         FormatBytes(MethodStats[M].TotalOriginal),
         FormatBytes(MethodStats[M].TotalCompressed),
         Ratio]));
    end;
  end;
  
  // Archive metadata
  WriteLn('');
  WriteLn('=== Archive Information ===');
  WriteLn(Format('Created: %s', [FormatDateTime('yyyy-mm-dd hh:mm:ss', FStatistics.CreationTime)]));
  WriteLn(Format('Modified: %s', [FormatDateTime('yyyy-mm-dd hh:mm:ss', FStatistics.LastUpdateTime)]));
  WriteLn(Format('Archive size: %s', [FormatBytes(GetFileSize(FFileName))]));
end;

procedure TSMARTLARKArchive.TestIntegrity;
var
  Entry: TArchiveFileEntry;
  ArchiveStream: TFileStream;
  CompressedData, ExtractedData: TMemoryStream;
  CRC: TCRC32;
  ComputedCRC: DWORD;
  I: Integer;
begin
  WriteLn('Testing archive integrity...');
  WriteLn('');

  ArchiveStream := TFileStream.Create(FFileName, fmOpenRead);
  CompressedData := TMemoryStream.Create;
  ExtractedData := nil;

  try
    for I := 0 to FFileEntries.Count - 1 do
    begin
      Entry := FFileEntries[I];
      Write(Format('Checking %s... ', [Entry.FileName]));

      try
        // Read compressed data
        CompressedData.Clear;
        ArchiveStream.Position := Entry.FileOffset;
        TStreamHelper.CopyBytes(ArchiveStream, CompressedData, Entry.CompressedSize);

        // Decompress using common method
        ExtractedData := DecompressFileEntry(Entry, CompressedData);

        // Check CRC
        ExtractedData.Position := 0;
        CRC := TCRC32.Create;
        try
          CRC.Update(ExtractedData, ExtractedData.Size);
          ComputedCRC := CRC.GetDigest;
        finally
          CRC.Free;
        end;

        if ComputedCRC = Entry.CRC32 then
          WriteLn('✓ OK')
        else
          WriteLn(Format('✗ CRC MISMATCH (expected %08X, got %08X)', [Entry.CRC32, ComputedCRC]));

        // Free ExtractedData before next iteration
        FreeAndNil(ExtractedData);

      except
        on E: Exception do
        begin
          WriteLn('✗ ERROR: ' + E.Message);
          FreeAndNil(ExtractedData);
        end;
      end;
    end;

    WriteLn('');
    WriteLn('Test completed.');

  finally
    ArchiveStream.Free;
    CompressedData.Free;
    ExtractedData.Free;
  end;
end;

function TSMARTLARKArchive.DecompressFileEntry(Entry: TArchiveFileEntry; CompressedData: TMemoryStream): TMemoryStream;
var
  Codec: TLZHUFCodec;
  StoreCodec: TStoreCompressor;
  DeflateCodec: TDeflateCompressor;
  LZSSCompressor: TLZSSCompressor;
  LZWCompressor: TLZWCompressor;
  LZ77Compressor: TLZ77Compressor;
begin
  Result := TMemoryStream.Create;
  try
    CompressedData.Position := 0;
    case Entry.CompressionMethod of
      cmStore:
      begin
        // Store: no compression, just copy
        StoreCodec := TStoreCompressor.Create;
        try
          StoreCodec.Decompress(CompressedData, Result);
        finally
          StoreCodec.Free;
        end;
      end;
      cmLZSS:
      begin
        // LZSS: Lempel-Ziv-Storer-Szymanski (no Huffman)
        LZSSCompressor := TLZSSCompressor.Create;
        try
          LZSSCompressor.Decompress(CompressedData, Result);
        finally
          LZSSCompressor.Free;
        end;
      end;
      cmLZHUF:
      begin
        // LZHUF: LZSS + Huffman
        Codec := TLZHUFCodec.Create;
        try
          Codec.Decompress(CompressedData, Result);
        finally
          Codec.Free;
        end;
      end;
      cmDEFLATE:
      begin
        // DEFLATE: LZ77 + Huffman (zlib)
        DeflateCodec := TDeflateCompressor.Create;
        try
          DeflateCodec.Decompress(CompressedData, Result);
        finally
          DeflateCodec.Free;
        end;
      end;
      cmLZW:
      begin
        // LZW: Lempel-Ziv-Welch (UNIX compress)
        LZWCompressor := TLZWCompressor.Create;
        try
          LZWCompressor.Decompress(CompressedData, Result);
        finally
          LZWCompressor.Free;
        end;
      end;
      cmLZ77:
      begin
        // LZ77: Classic Lempel-Ziv 1977
        LZ77Compressor := TLZ77Compressor.Create;
        try
          LZ77Compressor.Decompress(CompressedData, Result);
        finally
          LZ77Compressor.Free;
        end;
      end;
    end;
    Result.Position := 0;
  except
    Result.Free;
    raise;
  end;
end;

procedure TSMARTLARKArchive.RebuildArchive;
begin
  // Rebuild archive by rewriting all entries
  SaveArchive;
end;

function TSMARTLARKArchive.FileExists(const ArchivePath: string): Boolean;
var
  Entry: TArchiveFileEntry;
  I: Integer;
begin
  Result := False;
  for I := 0 to FFileEntries.Count - 1 do
  begin
    Entry := FFileEntries[I];
    if SameText(Entry.FileName, ArchivePath) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

function TSMARTLARKArchive.GetFileInfo(const ArchivePath: string): TArchiveFileEntry;
var
  Entry: TArchiveFileEntry;
  I: Integer;
begin
  Result := nil;
  for I := 0 to FFileEntries.Count - 1 do
  begin
    Entry := FFileEntries[I];
    if SameText(Entry.FileName, ArchivePath) then
    begin
      Result := Entry;
      Break;
    end;
  end;
end;

function TSMARTLARKArchive.GetFileCount: Integer;
begin
  Result := FFileEntries.Count;
end;

procedure TSMARTLARKArchive.ValidateArchive;
var
  I: Integer;
  Entry: TArchiveFileEntry;
begin
  // Basic structural checks for each entry
  // Note: This method should only be called after opening an existing archive
  // (not for newly created archives where FileOffset may not be set yet)
  
  if FFileEntries.Count = 0 then
    Exit; // Empty archive is valid
  
  for I := 0 to FFileEntries.Count - 1 do
  begin
    Entry := FFileEntries[I];
    
    // Check sizes
    if (Entry.CompressedSize < 0) or (Entry.OriginalSize < 0) then
      raise ESMARTLARKFormatException.CreateFmt('Invalid sizes for entry %s. Compressed or original size is negative.', 
        ecInvalidSizes, [Entry.FileName]);
    
    // Check compression method
    if (Ord(Entry.CompressionMethod) < Ord(Low(TCompressionMethod))) or 
       (Ord(Entry.CompressionMethod) > Ord(High(TCompressionMethod))) then
      raise ESMARTLARKFormatException.CreateFmt('Invalid compression method for entry %s. The compression method value is out of range.', 
        ecInvalidCompressionMethod, [Entry.FileName]);
    
    // Check file offset only if archive is opened (FDirectoryOffset > 0)
    // For newly created archives, FileOffset may not be set yet
    // Minimum offset is 60 (header size), not SizeOf(FHeader) which includes padding
    if (FDirectoryOffset > 0) and (Entry.FileOffset > 0) then
    begin
      if Entry.FileOffset < 60 then
        raise ESMARTLARKFormatException.CreateFmt('Invalid file offset for entry %s: %d (must be >= 60).', 
          ecInvalidFileOffset, [Entry.FileName, Entry.FileOffset]);
      
      if Entry.FileOffset + Entry.CompressedSize > FDirectoryOffset then
        raise ESMARTLARKFormatException.CreateFmt('File data for entry %s extends beyond central directory. Offset: %d, Size: %d, Directory: %d.', 
          ecInvalidFileOffset, [Entry.FileName, Entry.FileOffset, Entry.CompressedSize, FDirectoryOffset]);
    end;
    
    // Check filename
    if Entry.FileName = '' then
      raise ESMARTLARKFormatException.CreateFmt('Empty filename for entry at index %d.', 
        ecInvalidFileName, [I]);
    
    if Length(Entry.FileName) > 260 then
      raise ESMARTLARKFormatException.CreateFmt('Filename too long for entry %s: %d characters (max 260).', 
        ecInvalidFileName, [Entry.FileName, Length(Entry.FileName)]);
  end;
end;

end.


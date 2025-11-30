unit uSMARTLARKTypes;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, Winapi.Windows;

const
  // Archive signatures
  SMARTLARK_ARCHIVE_SIGNATURE = $4B52414C;  // 'LARK' (SMARTLARK)
  SMARTLARK_DIRECTORY_SIGNATURE = $444B524C; // 'LRKD' (LARK Directory)
  
  // Legacy LARC signatures for backward compatibility
  LARC_ARCHIVE_SIGNATURE = $4352414C;  // 'LARC' (deprecated, use SMARTLARK_ARCHIVE_SIGNATURE)
  LARC_DIRECTORY_SIGNATURE = $4C415244; // 'LARD' (deprecated, use SMARTLARK_DIRECTORY_SIGNATURE)

  // Compression methods
  COMPRESS_STORE = 0;   // No compression
  COMPRESS_LZSS = 1;    // LZSS only (no Huffman)
  COMPRESS_LZHUF = 2;   // LZSS + Huffman
  COMPRESS_DEFLATE = 3; // DEFLATE (zlib)
  COMPRESS_LZW = 4;     // LZW (UNIX compress)
  COMPRESS_LZ77 = 5;    // LZ77 (classic Lempel-Ziv 1977)

  // Archive flags
  ARCHIVE_FLAG_SFX = $01;       // Self-extracting archive
  ARCHIVE_FLAG_ENCRYPTED = $02; // Encrypted (reserved)
  ARCHIVE_FLAG_DEFLATE = $04;   // Uses DEFLATE instead of LZHUF
  ARCHIVE_FLAG_SHA256 = $08;    // Has SHA256 hashes

  // Compression levels
  MIN_COMPRESSION_LEVEL = 0;
  MAX_COMPRESSION_LEVEL = 9;
  DEFAULT_COMPRESSION_LEVEL = 5;

  // Buffer sizes for different compression levels
  DEFAULT_BUFFER_SIZE = 262144; // 256 KB default block size

  // Version constants
  SMARTLARK_FORMAT_VERSION = $0200;  // v2.0
  SMARTLARK_MIN_UNPACK_VERSION = $0200;
  // Legacy constants for backward compatibility
  LARC_FORMAT_VERSION = SMARTLARK_FORMAT_VERSION;
  LARC_MIN_UNPACK_VERSION = SMARTLARK_MIN_UNPACK_VERSION;

type
  /// <summary>
  /// Compression method enumeration for archive files.
  /// </summary>
  /// <remarks>
  /// Different compression methods offer different trade-offs between compression ratio and speed.
  /// </remarks>
  TCompressionMethod = (
    /// <summary>No compression - files are stored as-is (fastest, no compression).</summary>
    cmStore = COMPRESS_STORE,
    /// <summary>LZSS compression - good balance of speed and compression.</summary>
    cmLZSS = COMPRESS_LZSS,
    /// <summary>LZHUF compression - LZSS combined with Huffman coding (better compression).</summary>
    cmLZHUF = COMPRESS_LZHUF,
    /// <summary>DEFLATE compression - industry standard (zlib, good compression and speed).</summary>
    cmDEFLATE = COMPRESS_DEFLATE,
    /// <summary>LZW compression - dictionary-based compression (good for repetitive data).</summary>
    cmLZW = COMPRESS_LZW,
    /// <summary>LZ77 compression - classic Lempel-Ziv 1977 algorithm.</summary>
    cmLZ77 = COMPRESS_LZ77
  );

  /// <summary>
  /// Compression level type (0-9).
  /// </summary>
  /// <remarks>
  /// Level 0 means no compression (store). Higher levels provide better compression but take more time.
  /// </remarks>
  TCompressionLevel = 0..MAX_COMPRESSION_LEVEL;

  // File attributes (FAT compatible)
  TFileAttributes = set of (
    faReadOnly,      // 0x01
    faHidden,        // 0x02
    faSystem,        // 0x04
    faArchive,       // 0x20
    faDirectory      // 0x10
  );

  /// <summary>
  /// Archive header structure (60 bytes).
  /// </summary>
  /// <remarks>
  /// Located at the beginning of every SMARTLARK archive file.
  /// Contains metadata about the archive format, version, and creation time.
  /// </remarks>
  TSMARTLARKArchiveHeader = record
    /// <summary>Archive signature: $4B52414C ('LARK') for SMARTLARK or $4352414C ('LARC') for legacy format.</summary>
    Signature: DWORD;
    /// <summary>Format version: $0200 = v2.0.</summary>
    FormatVersion: WORD;
    /// <summary>Minimum version required to unpack this archive.</summary>
    MinUnpackVersion: WORD;
    /// <summary>Archive flags (see ARCHIVE_FLAG_* constants).</summary>
    Flags: DWORD;
    /// <summary>Typical block size used for compression (in bytes).</summary>
    BlockSize: DWORD;
    /// <summary>Default compression level (0-9) used for files in this archive.</summary>
    DefaultCompressionLevel: DWORD;
    /// <summary>Reserved field for future use.</summary>
    Reserved1: DWORD;
    /// <summary>Archive creation time in FILETIME format (Windows).</summary>
    CreationTime: Int64;
    /// <summary>Last modification time in FILETIME format (Windows).</summary>
    LastUpdateTime: Int64;
    /// <summary>Reserved data for future extensions (16 bytes).</summary>
    ReservedData: array[0..15] of Byte;
    /// <summary>Number of files in the archive.</summary>
    FileCount: DWORD;
  end;
  // Legacy type alias for backward compatibility
  TLARCArchiveHeader = TSMARTLARKArchiveHeader;

  // File Header (variable size: 2 + NameLen + 40+ bytes)
  TSMARTLARKFileHeader = record
    NameLength: WORD;              // Length of filename (UTF-8)
    FileName: string;              // Filename (UTF-8)
    OriginalSize: Int64;           // Original uncompressed size
    CompressedSize: Int64;         // Compressed data size
    CRC32: DWORD;                  // CRC32 of original file
    ModificationTime: Int64;       // FILETIME format
    FileAttributes: DWORD;         // FAT attributes
    CompressionLevel: Byte;        // 0-9 (0 = store)
    CompressionMethod: Byte;       // See COMPRESS_* constants
    FileFlags: WORD;               // File-specific flags
    Adler32: DWORD;                // Quick integrity check
  end;
  // Legacy type alias for backward compatibility
  TLARCFileHeader = TSMARTLARKFileHeader;

  // Compressed Data Block Header
  TSMARTLARKDataBlock = record
    OriginalSize: DWORD;           // Original block size
    CompressedSize: DWORD;         // Compressed block size
    BlockCRC32: DWORD;             // CRC32 of this block
  end;
  // Legacy type alias for backward compatibility
  TLARCDataBlock = TSMARTLARKDataBlock;

  // Central Directory Entry (variable size)
  TSMARTLARKDirEntry = record
    Offset: Int64;                 // Offset of File Header from start
    Size: DWORD;                   // Size of File Header + Compressed Data
    NameLength: WORD;              // Length of filename
    FileName: string;              // Filename
    CRC32: DWORD;                  // CRC32 of file
    OriginalSize: Int64;           // Original size of file
  end;
  // Legacy type alias for backward compatibility
  TLARCDirEntry = TSMARTLARKDirEntry;

  /// <summary>
  /// Central Directory structure (48+ bytes) located at the end of the archive.
  /// </summary>
  /// <remarks>
  /// <para>
  /// The central directory contains metadata for all files in the archive:
  /// - File names and paths
  /// - Compression information (method, level)
  /// - File sizes (original and compressed)
  /// - CRC32 checksums
  /// - File offsets in the archive
  /// - Modification times and attributes
  /// </para>
  /// <para>
  /// Structure:
  /// [Signature: 4 bytes][FileCount: 4 bytes][Directory Entries...]
  /// Each directory entry is variable-length (depends on filename length).
  /// </para>
  /// <para>
  /// The directory is searched from the end of the file backwards to find
  /// the signature, allowing efficient reading without knowing the exact size.
  /// </para>
  /// </remarks>
  TSMARTLARKCentralDirectory = record
    /// <summary>Directory signature: $444B524C ('LRKD') for SMARTLARK or $4C415244 ('LARD') for legacy.</summary>
    Signature: DWORD;
    /// <summary>Total number of files in the archive.</summary>
    FileCount: DWORD;
    /// <summary>Total size of the archive file in bytes.</summary>
    ArchiveSize: Int64;
    /// <summary>Size of the central directory in bytes.</summary>
    DirectorySize: Int64;
    /// <summary>Byte offset from start of file to the beginning of central directory.</summary>
    DirectoryOffset: DWORD;
    /// <summary>Reserved field for future use.</summary>
    Reserved: DWORD;
    /// <summary>SHA256 hash of the archive (optional, 16 bytes).</summary>
    SHA256Hash: array[0..15] of Byte;
    /// <summary>Checksum of this directory header for integrity verification.</summary>
    HeaderChecksum: DWORD;
  end;
  // Legacy type alias for backward compatibility
  TLARCCentralDirectory = TSMARTLARKCentralDirectory;

  /// <summary>
  /// Represents a file entry in the archive (runtime structure).
  /// </summary>
  /// <remarks>
  /// This class holds metadata about a file stored in the archive, including
  /// compression information, sizes, and file attributes.
  /// </remarks>
  TArchiveFileEntry = class
  public
    /// <summary>File name in the archive (UTF-8 encoded).</summary>
    FileName: string;
    /// <summary>Original uncompressed file size in bytes.</summary>
    OriginalSize: Int64;
    /// <summary>Compressed file size in bytes.</summary>
    CompressedSize: Int64;
    /// <summary>CRC32 checksum of the original file for integrity verification.</summary>
    CRC32: DWORD;
    /// <summary>File modification time in FILETIME format (Windows).</summary>
    ModificationTime: Int64;
    /// <summary>File attributes (FAT compatible: read-only, hidden, system, etc.).</summary>
    FileAttributes: DWORD;
    /// <summary>Compression level used (0-9, where 0 means no compression).</summary>
    CompressionLevel: TCompressionLevel;
    /// <summary>Compression method used for this file.</summary>
    CompressionMethod: TCompressionMethod;
    /// <summary>Byte offset of this file's data in the archive.</summary>
    FileOffset: Int64;
    /// <summary>Indicates whether this entry represents a directory.</summary>
    IsDirectory: Boolean;
    /// <summary>Temporary storage for compressed data during archive operations.</summary>
    CompressedData: TMemoryStream;
    
    /// <summary>
    /// Creates a new TArchiveFileEntry instance.
    /// </summary>
    constructor Create;
    
    /// <summary>
    /// Destroys the entry and releases associated resources.
    /// </summary>
    destructor Destroy; override;
    
    /// <summary>
    /// Assigns values from a TSMARTLARKFileHeader structure.
    /// </summary>
    /// <param name="Source">Source file header to copy from.</param>
    procedure Assign(const Source: TSMARTLARKFileHeader);
    
    /// <summary>
    /// Gets a formatted string with file information.
    /// </summary>
    /// <returns>String containing file name, sizes, compression ratio, and CRC32.</returns>
    function GetInfo: string;
  end;

  /// <summary>
  /// Compression settings for archive operations.
  /// </summary>
  TCompressionSettings = record
    /// <summary>Compression level (0-9).</summary>
    Level: TCompressionLevel;
    /// <summary>Compression method to use.</summary>
    Method: TCompressionMethod;
    /// <summary>Buffer size for compression operations (in bytes).</summary>
    BufferSize: Integer;
    /// <summary>Maximum chain length for LZ-based algorithms.</summary>
    MaxChainLength: Integer;
    /// <summary>Block size for block-based compression (in bytes).</summary>
    BlockSize: Integer;

    class function GetForLevel(Level: TCompressionLevel): TCompressionSettings; static;
  end;

  /// <summary>
  /// Archive statistics containing aggregate information about the archive.
  /// </summary>
  /// <remarks>
  /// Provides summary information about all files in the archive, including
  /// total sizes, compression ratio, and timestamps.
  /// </remarks>
  TArchiveStatistics = record
    /// <summary>Total number of files in the archive.</summary>
    FileCount: Integer;
    /// <summary>Sum of all original (uncompressed) file sizes in bytes.</summary>
    TotalOriginalSize: Int64;
    /// <summary>Sum of all compressed file sizes in bytes.</summary>
    TotalCompressedSize: Int64;
    /// <summary>Overall compression ratio as percentage (100% = no compression).</summary>
    CompressionRatio: Double;
    /// <summary>Archive creation date and time.</summary>
    CreationTime: TDateTime;
    /// <summary>Last modification date and time of the archive.</summary>
    LastUpdateTime: TDateTime;

    /// <summary>
    /// Calculates and returns the compression ratio as a percentage.
    /// </summary>
    /// <returns>Compression ratio: (compressed/original) * 100. Returns 100.0 if original size is 0.</returns>
    function GetCompressionRatio: Double;
  end;

implementation

{ TArchiveFileEntry }

constructor TArchiveFileEntry.Create;
begin
  inherited;
  CompressedData := nil;
  FileOffset := 0;
  IsDirectory := False;
end;

destructor TArchiveFileEntry.Destroy;
begin
  if Assigned(CompressedData) then
    CompressedData.Free;
  inherited;
end;

procedure TArchiveFileEntry.Assign(const Source: TSMARTLARKFileHeader);
begin
  FileName := Source.FileName;
  OriginalSize := Source.OriginalSize;
  CompressedSize := Source.CompressedSize;
  CRC32 := Source.CRC32;
  ModificationTime := Source.ModificationTime;
  FileAttributes := Source.FileAttributes;
  CompressionLevel := Source.CompressionLevel;
  CompressionMethod := TCompressionMethod(Source.CompressionMethod);
  IsDirectory := (Source.FileAttributes and $10) <> 0;
end;

function TArchiveFileEntry.GetInfo: string;
var
  Ratio: Double;
begin
  if OriginalSize > 0 then
    Ratio := (CompressedSize * 100.0) / OriginalSize
  else
    Ratio := 100.0;

  Result := Format('%s | %10d -> %10d (%5.1f%%) | CRC: %08X',
    [FileName, OriginalSize, CompressedSize, Ratio, CRC32]);
end;

{ TCompressionSettings }

class function TCompressionSettings.GetForLevel(
  Level: TCompressionLevel): TCompressionSettings;
begin
  Result.Level := Level;
  Result.Method := cmLZHUF;

  case Level of
    0: begin
      Result.BufferSize := 2048;
      Result.MaxChainLength := 32;
      Result.BlockSize := 65536;
    end;
    1: begin
      Result.BufferSize := 2048;
      Result.MaxChainLength := 32;
      Result.BlockSize := 65536;
    end;
    2: begin
      Result.BufferSize := 4096;
      Result.MaxChainLength := 64;
      Result.BlockSize := 65536;
    end;
    3: begin
      Result.BufferSize := 8192;
      Result.MaxChainLength := 128;
      Result.BlockSize := 131072;
    end;
    4: begin
      Result.BufferSize := 16384;
      Result.MaxChainLength := 256;
      Result.BlockSize := 262144;
    end;
    5: begin
      Result.BufferSize := 32768;
      Result.MaxChainLength := 512;
      Result.BlockSize := 262144;
    end;
    6: begin
      Result.BufferSize := 65536;
      Result.MaxChainLength := 1024;
      Result.BlockSize := 262144;
    end;
    7: begin
      Result.BufferSize := 131072;
      Result.MaxChainLength := 2048;
      Result.BlockSize := 524288;
    end;
    8: begin
      Result.BufferSize := 262144;
      Result.MaxChainLength := 4096;
      Result.BlockSize := 524288;
    end;
  else
    // Level 9
    Result.BufferSize := 524288;
    Result.MaxChainLength := 8192;
    Result.BlockSize := 1048576;
  end;
end;

{ TArchiveStatistics }

function TArchiveStatistics.GetCompressionRatio: Double;
begin
  if TotalOriginalSize > 0 then
    Result := (TotalCompressedSize * 100.0) / TotalOriginalSize
  else
    Result := 100.0;
end;

end.


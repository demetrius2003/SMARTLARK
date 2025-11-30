unit uSMARTLARKExceptions;

interface

uses
  System.SysUtils;

type
  // Error codes for programmatic error handling
  TSMARTLARKErrorCode = (
    ecUnknown = 0,
    ecInvalidSignature = 1001,
    ecUnsupportedVersion = 1002,
    ecArchiveTooSmall = 1003,
    ecDirectoryNotFound = 1004,
    ecInvalidFileCount = 1005,
    ecInvalidFileName = 1006,
    ecInvalidFileOffset = 1007,
    ecFileNotFound = 2001,
    ecArchiveNotFound = 2002,
    ecSourceNotFound = 2003,
    ecFindFirstFailed = 2004,
    ecCRC32Mismatch = 3001,
    ecNoCompressedData = 3002,
    ecInvalidCompressionMethod = 3003,
    ecInvalidSizes = 3004,
    ecArchiveNameNotSet = 4001
  );

  // Base exception class for all SMARTLARK exceptions
  ESMARTLARKException = class(Exception)
  private
    FErrorCode: TSMARTLARKErrorCode;
  public
    constructor Create(const Msg: string); overload;
    constructor Create(const Msg: string; AErrorCode: TSMARTLARKErrorCode); overload;
    constructor CreateFmt(const Msg: string; const Args: array of const); overload;
    constructor CreateFmt(const Msg: string; AErrorCode: TSMARTLARKErrorCode; const Args: array of const); overload;
    property ErrorCode: TSMARTLARKErrorCode read FErrorCode;
  end;

  // Archive-related exceptions
  ESMARTLARKArchiveException = class(ESMARTLARKException)
  public
    constructor Create(const Msg: string); overload;
    constructor Create(const Msg: string; AErrorCode: TSMARTLARKErrorCode); overload;
    constructor CreateFmt(const Msg: string; const Args: array of const); overload;
    constructor CreateFmt(const Msg: string; AErrorCode: TSMARTLARKErrorCode; const Args: array of const); overload;
  end;

  // Compression-related exceptions
  ESMARTLARKCompressionException = class(ESMARTLARKException)
  public
    constructor Create(const Msg: string); overload;
    constructor CreateFmt(const Msg: string; const Args: array of const); overload;
  end;

  // Format/validation exceptions
  ESMARTLARKFormatException = class(ESMARTLARKArchiveException)
  public
    constructor Create(const Msg: string); overload;
    constructor Create(const Msg: string; AErrorCode: TSMARTLARKErrorCode); overload;
    constructor CreateFmt(const Msg: string; const Args: array of const); overload;
    constructor CreateFmt(const Msg: string; AErrorCode: TSMARTLARKErrorCode; const Args: array of const); overload;
  end;

  // I/O exceptions
  ESMARTLARKIOException = class(ESMARTLARKArchiveException)
  public
    constructor Create(const Msg: string); overload;
    constructor Create(const Msg: string; AErrorCode: TSMARTLARKErrorCode); overload;
    constructor CreateFmt(const Msg: string; const Args: array of const); overload;
    constructor CreateFmt(const Msg: string; AErrorCode: TSMARTLARKErrorCode; const Args: array of const); overload;
  end;

implementation

{ ESMARTLARKException }

constructor ESMARTLARKException.Create(const Msg: string);
begin
  Create(Msg, ecUnknown);
end;

constructor ESMARTLARKException.Create(const Msg: string; AErrorCode: TSMARTLARKErrorCode);
begin
  FErrorCode := AErrorCode;
  inherited Create('SMARTLARK: ' + Msg);
end;

constructor ESMARTLARKException.CreateFmt(const Msg: string; const Args: array of const);
begin
  CreateFmt(Msg, ecUnknown, Args);
end;

constructor ESMARTLARKException.CreateFmt(const Msg: string; AErrorCode: TSMARTLARKErrorCode; const Args: array of const);
begin
  FErrorCode := AErrorCode;
  inherited CreateFmt('SMARTLARK: ' + Msg, Args);
end;

{ ESMARTLARKArchiveException }

constructor ESMARTLARKArchiveException.Create(const Msg: string);
begin
  Create(Msg, ecUnknown);
end;

constructor ESMARTLARKArchiveException.Create(const Msg: string; AErrorCode: TSMARTLARKErrorCode);
begin
  FErrorCode := AErrorCode;
  inherited Create('Archive Error: ' + Msg);
end;

constructor ESMARTLARKArchiveException.CreateFmt(const Msg: string; const Args: array of const);
begin
  CreateFmt(Msg, ecUnknown, Args);
end;

constructor ESMARTLARKArchiveException.CreateFmt(const Msg: string; AErrorCode: TSMARTLARKErrorCode; const Args: array of const);
begin
  FErrorCode := AErrorCode;
  inherited CreateFmt('Archive Error: ' + Msg, Args);
end;

{ ESMARTLARKCompressionException }

constructor ESMARTLARKCompressionException.Create(const Msg: string);
begin
  inherited Create('Compression Error: ' + Msg);
end;

constructor ESMARTLARKCompressionException.CreateFmt(const Msg: string; const Args: array of const);
begin
  inherited CreateFmt('Compression Error: ' + Msg, Args);
end;

{ ESMARTLARKFormatException }

constructor ESMARTLARKFormatException.Create(const Msg: string);
begin
  Create(Msg, ecUnknown);
end;

constructor ESMARTLARKFormatException.Create(const Msg: string; AErrorCode: TSMARTLARKErrorCode);
begin
  FErrorCode := AErrorCode;
  inherited Create('Format Error: ' + Msg);
end;

constructor ESMARTLARKFormatException.CreateFmt(const Msg: string; const Args: array of const);
begin
  CreateFmt(Msg, ecUnknown, Args);
end;

constructor ESMARTLARKFormatException.CreateFmt(const Msg: string; AErrorCode: TSMARTLARKErrorCode; const Args: array of const);
begin
  FErrorCode := AErrorCode;
  inherited CreateFmt('Format Error: ' + Msg, Args);
end;

{ ESMARTLARKIOException }

constructor ESMARTLARKIOException.Create(const Msg: string);
begin
  Create(Msg, ecUnknown);
end;

constructor ESMARTLARKIOException.Create(const Msg: string; AErrorCode: TSMARTLARKErrorCode);
begin
  FErrorCode := AErrorCode;
  inherited Create('I/O Error: ' + Msg);
end;

constructor ESMARTLARKIOException.CreateFmt(const Msg: string; const Args: array of const);
begin
  CreateFmt(Msg, ecUnknown, Args);
end;

constructor ESMARTLARKIOException.CreateFmt(const Msg: string; AErrorCode: TSMARTLARKErrorCode; const Args: array of const);
begin
  FErrorCode := AErrorCode;
  inherited CreateFmt('I/O Error: ' + Msg, Args);
end;

end.


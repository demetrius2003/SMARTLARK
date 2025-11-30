unit uCRC32;

interface

uses
  System.SysUtils, System.Classes, Winapi.Windows;

type
  TCRC32 = class
  private
    FTable: array[0..255] of DWORD;
    FCurrent: DWORD;
    FInitialized: Boolean;

    procedure InitializeTable;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Reset;
    procedure Update(const Data: TBytes); overload;
    procedure Update(const Data: PByte; Size: Integer); overload;
    procedure Update(Stream: TStream; Size: Int64 = -1); overload;
    function GetDigest: DWORD;

    class function Calculate(const Data: TBytes): DWORD; overload;
    class function Calculate(const Data: PByte; Size: Integer): DWORD; overload;
    class function Calculate(Stream: TStream; Size: Int64 = -1): DWORD; overload;
  end;

  // Adler-32 checksum (faster than CRC32)
  TAdler32 = class
  private
    FA, FB: DWORD;

    const
      ADLER_BASE = 65521;
      ADLER_BLOCK = 5552;
  public
    constructor Create;

    procedure Reset;
    procedure Update(const Data: TBytes); overload;
    procedure Update(const Data: PByte; Size: Integer); overload;
    function GetDigest: DWORD;

    class function Calculate(const Data: TBytes): DWORD; overload;
    class function Calculate(const Data: PByte; Size: Integer): DWORD; overload;
  end;

implementation

{ TCRC32 }

constructor TCRC32.Create;
begin
  inherited;
  FInitialized := False;
  InitializeTable;
  Reset;
end;

destructor TCRC32.Destroy;
begin
  inherited;
end;

procedure TCRC32.InitializeTable;
var
  i, j: Integer;
  CRC: DWORD;
const
  POLYNOMIAL = $EDB88320;
begin
  if FInitialized then
    Exit;

  for i := 0 to 255 do
  begin
    CRC := i;
    for j := 0 to 7 do
    begin
      if (CRC and 1) <> 0 then
        CRC := (CRC shr 1) xor POLYNOMIAL
      else
        CRC := CRC shr 1;
    end;
    FTable[i] := CRC;
  end;

  FInitialized := True;
end;

procedure TCRC32.Reset;
begin
  FCurrent := $FFFFFFFF;
end;

procedure TCRC32.Update(const Data: TBytes);
begin
  if Length(Data) > 0 then
    Update(PByte(Data), Length(Data));
end;

procedure TCRC32.Update(const Data: PByte; Size: Integer);
var
  i: Integer;
  Byte: PByte;
begin
  Byte := Data;
  for i := 0 to Size - 1 do
  begin
    FCurrent := FTable[(FCurrent xor Byte^) and $FF] xor (FCurrent shr 8);
    Inc(Byte);
  end;
end;

procedure TCRC32.Update(Stream: TStream; Size: Int64 = -1);
const
  BUFFER_SIZE = 65536;
var
  Buffer: TBytes;
  BytesRead: Integer;
  RemainingSize: Int64;
begin
  SetLength(Buffer, BUFFER_SIZE);

  if Size < 0 then
    RemainingSize := Stream.Size - Stream.Position
  else
    RemainingSize := Size;

  while RemainingSize > 0 do
  begin
    if RemainingSize > BUFFER_SIZE then
      BytesRead := Stream.Read(Buffer, 0, BUFFER_SIZE)
    else
      BytesRead := Stream.Read(Buffer, 0, RemainingSize);

    if BytesRead <= 0 then
      Break;

    Update(@Buffer[0], BytesRead);
    Dec(RemainingSize, BytesRead);
  end;
end;

function TCRC32.GetDigest: DWORD;
begin
  Result := FCurrent xor $FFFFFFFF;
end;

class function TCRC32.Calculate(const Data: TBytes): DWORD;
var
  CRC: TCRC32;
begin
  CRC := TCRC32.Create;
  try
    CRC.Update(Data);
    Result := CRC.GetDigest;
  finally
    CRC.Free;
  end;
end;

class function TCRC32.Calculate(const Data: PByte; Size: Integer): DWORD;
var
  CRC: TCRC32;
begin
  CRC := TCRC32.Create;
  try
    CRC.Update(Data, Size);
    Result := CRC.GetDigest;
  finally
    CRC.Free;
  end;
end;

class function TCRC32.Calculate(Stream: TStream; Size: Int64 = -1): DWORD;
var
  CRC: TCRC32;
begin
  CRC := TCRC32.Create;
  try
    CRC.Update(Stream, Size);
    Result := CRC.GetDigest;
  finally
    CRC.Free;
  end;
end;

{ TAdler32 }

constructor TAdler32.Create;
begin
  inherited;
  Reset;
end;

procedure TAdler32.Reset;
begin
  FA := 1;
  FB := 0;
end;

procedure TAdler32.Update(const Data: TBytes);
begin
  if Length(Data) > 0 then
    Update(PByte(Data), Length(Data));
end;

procedure TAdler32.Update(const Data: PByte; Size: Integer);
var
  Pos, Len, I: Integer;
  DataPtr: PByte;
begin
  Pos := 0;

  while Pos < Size do
  begin
    Len := Size - Pos;
    if Len > ADLER_BLOCK then
      Len := ADLER_BLOCK;

    DataPtr := PByte(NativeInt(Data) + Pos);

    for I := 0 to Len - 1 do
    begin
      Inc(FA, DataPtr^);
      Inc(FB, FA);
      Inc(DataPtr);
    end;

    FA := FA mod ADLER_BASE;
    FB := FB mod ADLER_BASE;
    Inc(Pos, Len);
  end;
end;

function TAdler32.GetDigest: DWORD;
begin
  Result := (FB shl 16) or FA;
end;

class function TAdler32.Calculate(const Data: TBytes): DWORD;
var
  Adler: TAdler32;
begin
  Adler := TAdler32.Create;
  try
    Adler.Update(Data);
    Result := Adler.GetDigest;
  finally
    Adler.Free;
  end;
end;

class function TAdler32.Calculate(const Data: PByte; Size: Integer): DWORD;
var
  Adler: TAdler32;
begin
  Adler := TAdler32.Create;
  try
    Adler.Update(Data, Size);
    Result := Adler.GetDigest;
  finally
    Adler.Free;
  end;
end;

end.

unit uLZWCompressor;

interface

uses
  System.SysUtils, System.Classes, System.Generics.Collections, uSMARTLARKExceptions;

type
  // LZW Compressor (UNIX compress algorithm)
  // Lempel-Ziv-Welch dictionary-based compression
  TLZWCompressor = class
  private
    FCodeSize: Integer;        // Current code size in bits (starts at 9, max 16)
    FMaxCode: Integer;        // Maximum code value for current code size
    FNextCode: Integer;       // Next code to assign
    FClearCode: Integer;      // Clear code (reset dictionary)
    FEndCode: Integer;        // End of data code
    
    // Dictionary for compression
    FDictionary: TDictionary<string, Integer>;
    
    // Dictionary for decompression (reverse lookup)
    FDecompDictionary: TList<string>;
    
    procedure InitializeCompression;
    procedure InitializeDecompression;
    
  public
    constructor Create;
    destructor Destroy; override;

    // Compress input to output using LZW
    procedure Compress(Input: TStream; Output: TStream; OnProgress: TNotifyEvent = nil);
    
    // Decompress input to output using LZW
    procedure Decompress(Input: TStream; Output: TStream; OnProgress: TNotifyEvent = nil);
  end;

implementation

uses
  uStreamHelpers;

{ TLZWCompressor }

constructor TLZWCompressor.Create;
begin
  inherited Create;
  FDictionary := TDictionary<string, Integer>.Create;
  FDecompDictionary := TList<string>.Create;
end;

destructor TLZWCompressor.Destroy;
begin
  FDictionary.Free;
  FDecompDictionary.Free;
  inherited Destroy;
end;

procedure TLZWCompressor.InitializeCompression;
var
  I: Integer;
  Ch: Char;
begin
  FDictionary.Clear;
  FCodeSize := 9;
  FMaxCode := (1 shl FCodeSize) - 1;
  FClearCode := 256;
  FEndCode := 257;
  FNextCode := FEndCode + 1;
  
  // Initialize dictionary with single-byte sequences (0-255)
  for I := 0 to 255 do
  begin
    Ch := Chr(I);
    FDictionary.Add(Ch, I);
  end;
end;

procedure TLZWCompressor.InitializeDecompression;
var
  I: Integer;
begin
  FDecompDictionary.Clear;
  FCodeSize := 9;
  FMaxCode := (1 shl FCodeSize) - 1;
  FClearCode := 256;
  FEndCode := 257;
  FNextCode := FEndCode + 1;
  
  // Initialize dictionary with single-byte sequences (0-255)
  FDecompDictionary.Capacity := 4096; // Pre-allocate for efficiency
  for I := 0 to 255 do
    FDecompDictionary.Add(Chr(I));
  
  // Add placeholder for clear and end codes
  FDecompDictionary.Add(''); // 256 - clear code
  FDecompDictionary.Add(''); // 257 - end code
end;

procedure TLZWCompressor.Compress(Input: TStream; Output: TStream; OnProgress: TNotifyEvent = nil);
var
  BitWriter: TBitWriter;
  InputBuffer: TBytes;
  BytesRead: Integer;
  I: Integer;
  CurrentString: string;
  NextChar: Char;
  Code: Integer;
  NewString: string;
begin
  try
    InitializeCompression;
    BitWriter := TBitWriter.Create(Output);
    
    try
      // Write clear code at start
      BitWriter.WriteBits(FClearCode, FCodeSize);
      
      SetLength(InputBuffer, 65536);
      BytesRead := Input.Read(InputBuffer[0], 65536);
      
      if BytesRead = 0 then
      begin
        BitWriter.WriteBits(FEndCode, FCodeSize);
        BitWriter.Flush;
        Exit;
      end;
      
      // Start with first character
      CurrentString := Chr(InputBuffer[0]);
      I := 1;
      
      while BytesRead > 0 do
      begin
        while I < BytesRead do
        begin
          NextChar := Chr(InputBuffer[I]);
          NewString := CurrentString + NextChar;
          
          // Check if string is in dictionary
          if FDictionary.TryGetValue(NewString, Code) then
          begin
            // String exists, extend it
            CurrentString := NewString;
          end
          else
          begin
            // String not found - output code for CurrentString
            if FDictionary.TryGetValue(CurrentString, Code) then
              BitWriter.WriteBits(Code, FCodeSize);
            
            // Add new string to dictionary
            if FNextCode <= FMaxCode then
            begin
              FDictionary.Add(NewString, FNextCode);
              Inc(FNextCode);
              
              // Check if we need to increase code size
              if FNextCode > FMaxCode then
              begin
                if FCodeSize < 16 then
                begin
                  Inc(FCodeSize);
                  FMaxCode := (1 shl FCodeSize) - 1;
                end
                else
                begin
                  // Dictionary full - output clear code and reset
                  BitWriter.WriteBits(FClearCode, FCodeSize);
                  InitializeCompression;
                end;
              end;
            end;
            
            // Start new string with current character
            CurrentString := NextChar;
          end;
          
          Inc(I);
        end;
        
        // Read next block
        BytesRead := Input.Read(InputBuffer[0], 65536);
        I := 0;
        
        if Assigned(OnProgress) then
          OnProgress(Self);
      end;
      
      // Output code for remaining string
      if CurrentString <> '' then
      begin
        if FDictionary.TryGetValue(CurrentString, Code) then
          BitWriter.WriteBits(Code, FCodeSize);
      end;
      
      // Write end code
      BitWriter.WriteBits(FEndCode, FCodeSize);
      BitWriter.Flush;
      
    finally
      BitWriter.Free;
    end;
    
  except
    on E: Exception do
      raise ESMARTLARKCompressionException.Create('LZW compression failed: ' + E.Message);
  end;
end;

procedure TLZWCompressor.Decompress(Input: TStream; Output: TStream; OnProgress: TNotifyEvent = nil);
var
  BitReader: TBitReader;
  OutputBuffer: TBytes;
  OutputPos: Integer;
  Code: Integer;
  OldString, NewString, StringToAdd: string;
  FirstChar: Char;
  CanRead: Boolean;
begin
  try
    InitializeDecompression;
    BitReader := TBitReader.Create(Input);
    SetLength(OutputBuffer, 65536);
    OutputPos := 0;
    
    try
      // Read first code (should be clear code)
      try
        Code := Integer(BitReader.ReadBits(FCodeSize));
      except
        Exit; // Empty stream
      end;
      
      // Skip clear code if present
      if Code = FClearCode then
      begin
        try
          Code := Integer(BitReader.ReadBits(FCodeSize));
        except
          Exit;
        end;
      end;
      
      // Check for end code
      if Code = FEndCode then
        Exit;
      
      // Output first string
      if Code < FDecompDictionary.Count then
      begin
        OldString := FDecompDictionary[Code];
        if Length(OldString) > 0 then
        begin
          for FirstChar in OldString do
          begin
            OutputBuffer[OutputPos] := Ord(FirstChar);
            Inc(OutputPos);
            
            if OutputPos >= Length(OutputBuffer) - 10 then
            begin
              Output.Write(OutputBuffer[0], OutputPos);
              OutputPos := 0;
            end;
          end;
        end;
      end;
      
      // Main decompression loop – rely on end code rather than IsEOF
      while True do
      begin
        CanRead := True;
        try
          Code := Integer(BitReader.ReadBits(FCodeSize));
        except
          CanRead := False;
        end;
        
        if not CanRead then
          Break;
        
        // Check for end code
        if Code = FEndCode then
          Break;
        
        // Check for clear code
        if Code = FClearCode then
        begin
          InitializeDecompression;
          try
            Code := Integer(BitReader.ReadBits(FCodeSize));
          except
            Break;
          end;
          
          if Code = FEndCode then
            Break;
          
          // Output first string after clear
          if Code < FDecompDictionary.Count then
          begin
            OldString := FDecompDictionary[Code];
            for FirstChar in OldString do
            begin
              OutputBuffer[OutputPos] := Ord(FirstChar);
              Inc(OutputPos);
              
              if OutputPos >= Length(OutputBuffer) - 10 then
              begin
                Output.Write(OutputBuffer[0], OutputPos);
                OutputPos := 0;
              end;
            end;
          end;
          Continue;
        end;
        
        // Decode code
        if Code < FDecompDictionary.Count then
        begin
          NewString := FDecompDictionary[Code];
        end
        else if Code = FNextCode then
        begin
          // Special case: code not in dictionary yet
          NewString := OldString;
          if Length(OldString) > 0 then
            NewString := NewString + OldString[1];
        end
        else
        begin
          // Invalid code - likely corrupted data
          Break;
        end;
        
        // Output decoded string
        for FirstChar in NewString do
        begin
          OutputBuffer[OutputPos] := Ord(FirstChar);
          Inc(OutputPos);
          
          if OutputPos >= Length(OutputBuffer) - 10 then
          begin
            Output.Write(OutputBuffer[0], OutputPos);
            OutputPos := 0;
          end;
        end;
        
        // Add new string to dictionary: OldString + FirstChar of NewString
        if FNextCode <= FMaxCode then
        begin
          if Length(OldString) > 0 then
            StringToAdd := OldString + NewString[1]
          else
            StringToAdd := NewString;
            
          FDecompDictionary.Add(StringToAdd);
          Inc(FNextCode);
          
          // Check if we need to increase code size
          if FNextCode > FMaxCode then
          begin
            if FCodeSize < 16 then
            begin
              Inc(FCodeSize);
              FMaxCode := (1 shl FCodeSize) - 1;
            end;
            // else: dictionary full, continue with max code size
          end;
        end;
        
        OldString := NewString;
        
        if Assigned(OnProgress) then
          OnProgress(Self);
      end;
      
      // Flush remaining output
      if OutputPos > 0 then
        Output.Write(OutputBuffer[0], OutputPos);
        
    finally
      BitReader.Free;
      SetLength(OutputBuffer, 0);
    end;
    
  except
    on E: Exception do
      raise ESMARTLARKCompressionException.Create('LZW decompression failed: ' + E.Message);
  end;
end;

end.


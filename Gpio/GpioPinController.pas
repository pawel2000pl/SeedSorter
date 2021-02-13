unit GpioPinController;

{$Mode ObjFpc}

//Gpio map in Raspberry Pi 3 and 4
//https://roboticsbackend.com/wp-content/uploads/2019/05/raspberry-pi-3-pinout.jpg

interface

uses
    SysUtils, BaseUnix;

type

    TGpioDirection = (gdInput, gdOutput);    
    
    TGpioPinController = class
    private
        FID : LongWord;
        FActive : Boolean;
    public
        procedure Open;
        procedure Close;
        procedure SetActive(const AValue : Boolean);
        function GetDirection : TGpioDirection;
        procedure SetDirection(const AValue : TGpioDirection);
        function GetValue : Boolean;
        procedure SetValue(const AValue : Boolean);
    
        property ID : LongWord read FID;
        property Active : Boolean read FActive write SetActive;
        property Direction : TGpioDirection read GetDirection write SetDirection;   
        property Value : Boolean read GetValue write SetValue;

        constructor Create(const GpioID : LongWord);
        destructor Destroy; override;
    end;
    
implementation

function fpTryOpen(const FileName : AnsiString; const Flags : cint; MaxTrials : Integer = 8) : Integer;
var
    dt : QWord;
begin
    dt := 0;
    repeat
        Result := fpOpen(FileName, Flags);
        if dt > 0 then
            sleep(dt);
        dt := dt shl 1 + 1;
        Dec(MaxTrials);
    until (Result <> -1) or (MaxTrials <= 0);
end;

function TGpioPinController.GetValue : Boolean;
var
    fileDesc : Integer;
    StrId : AnsiString;
    status : char;
begin
    if not FActive then
        Exit;
    try
        StrId := IntToStr(ID);
        fileDesc := FpTryOpen('/sys/class/gpio/gpio'+StrId+'/value', O_RDONLY);
        fpRead(fileDesc, status, 1);
        Result := Status = '1';
    finally
        fpClose(fileDesc);
    end;
end;

procedure TGpioPinController.SetValue(const AValue : Boolean);    
const
    CharValues : array[Boolean] of Char = ('0', '1');
var
    fileDesc : Integer;
    StrId : AnsiString;
begin
    if not FActive then
        Exit;
    try
        StrId := IntToStr(ID);
        fileDesc := FpTryOpen('/sys/class/gpio/gpio'+StrId+'/value', O_WRONLY);
        fpWrite(fileDesc, CharValues[AValue], 1);
    finally
        fpClose(fileDesc);
    end;
end;

function TGpioPinController.GetDirection : TGpioDirection;
var
    fileDesc : Integer;
    StrId : AnsiString;
    status : char;
begin
    if not FActive then
        Exit;
    try
        StrId := IntToStr(ID);
        fileDesc := FpTryOpen('/sys/class/gpio/gpio'+StrId+'/direction', O_RDONLY);
        fpRead(fileDesc, status, 1);
        case status of
            'i': Result := gdInput;
            'o': Result := gdOutput;
        end;
    finally
        fpClose(fileDesc);
    end;
end;

procedure TGpioPinController.SetDirection(const AValue : TGpioDirection);
const
    StrDirections : array[TGpioDirection] of array[0..3] of char = ('in'#0, 'out');
var
    fileDesc : Integer;
    StrId : AnsiString;
begin
    if not FActive then
        Exit;
    try
        StrId := IntToStr(ID);
        fileDesc := FpTryOpen('/sys/class/gpio/gpio'+StrId+'/direction', O_WRONLY);        
        fpWrite(fileDesc, StrDirections[AValue], 3);
    finally
        fpClose(fileDesc);
    end;
end;

procedure TGpioPinController.Open;
var
    fileDesc : Integer;
    StrId : AnsiString;
begin
    if FActive then
        Exit;
    try
        StrId := IntToStr(ID);
        fileDesc := FpTryOpen('/sys/class/gpio/export', O_WRONLY);
        fpWrite(fileDesc, StrId[1], Length(StrId));
        FActive := True;
    finally
        fpClose(fileDesc);
    end;  
end;

procedure TGpioPinController.Close;
var
    fileDesc : Integer;
    StrId : AnsiString;
begin
    if not FActive then
        Exit;
    try
        StrId := IntToStr(ID);
        fileDesc := FpTryOpen('/sys/class/gpio/unexport', O_WRONLY);
        fpWrite(fileDesc, StrId[1], Length(StrId));
        FActive := False;
    finally
        fpClose(fileDesc);
    end;
end;

procedure TGpioPinController.SetActive(const AValue : Boolean);
begin
    If AValue = FActive then
        Exit;
    if AValue then
        Open
    else
        Close;
end;

constructor TGpioPinController.Create(const GpioID : LongWord);
begin
    FID := GpioID;
    FActive := False;
end;

destructor TGpioPinController.Destroy; 
begin
    Close;
    inherited;
end;

end.

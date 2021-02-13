unit ElectromagnetConroller;

{$Mode ObjFpc}

interface

uses
    cThreads, SysUtils, Classes, GpioPinController;    

type
    TElectromagnetConroller = class(TThread)
    const 
        Freq = 60;  
        DeltaTime = 1000 div Freq;
        MaxTurnedOnTime = 1000;
    private
        gpio : TGpioPinController;
        FValue : Boolean;
        FTurnedTime : QWord;
        FTerminating : Boolean;
        
        procedure SetValue(const AValue : Boolean);
    public
        property Value : Boolean read FValue write SetValue;


        procedure Push(const Time : Integer = -1);
        procedure Execute; override;
        constructor Create(const Pin : LongWord);
        destructor Destroy; override;
    end;

implementation

procedure TElectromagnetConroller.Execute;
var
    Time : QWord;
begin
    repeat
        Time := GetTickCount64 - FTurnedTime;
        if FValue then
        begin    
            gpio.Value := Time mod DeltaTime < DeltaTime div 2;
            if Time > MaxTurnedOnTime then
                SetValue(False);
        end;    
        sleep(DeltaTime div 2 + 1);
    until FTerminating;    
end;

procedure TElectromagnetConroller.Push(const Time : Integer = -1);
begin
    Value := True;
    if (Time > 0) and (Time < MaxTurnedOnTime) then
    begin
        sleep(Time);
        Value := False;
    end;
end;

procedure TElectromagnetConroller.SetValue(const AValue : Boolean);
begin
    if FValue = AValue then
        Exit;
    FValue := AValue;
    gpio.Value := FValue;    
    FTurnedTime := GetTickCount64;
end;

constructor TElectromagnetConroller.Create(const Pin : LongWord);
begin
    FValue := False;
    gpio := TGpioPinController.Create(Pin);
    gpio.Open;
    gpio.Direction := gdOutput;
    gpio.Value := False;
    inherited Create(False);
end;

destructor TElectromagnetConroller.Destroy; 
begin
    FTerminating := True;
    WaitFor;
    gpio.Free;
    inherited;
end;

end.


unit ElectromagnetConroller;

{$Mode ObjFpc}

interface

uses
    cThreads, SysUtils, Classes, GpioPinController, math;    

type
    TElectromagnetConroller = class(TThread)
    const 
        Freq = 17;  
        DeltaTime = 1000 div Freq;
    private
        gpio : TGpioPinController;
        FTurnedTime : QWord;
        FDelay : Word;
        FValue : Boolean;
        FTerminating : Boolean;
        FState : Boolean;
        
        procedure SetValue(const AValue : Boolean);
    public
        property Value : Boolean read FValue write SetValue;
        property Delay : Word read FDelay write FDelay;

        procedure Push(const Time : Integer = -1);
        procedure Execute; override;
        constructor Create(const Pin : LongWord);
        destructor Destroy; override;
    end;

implementation

procedure TElectromagnetConroller.Execute;
var
    Time : QWord;
    NewState : Boolean;
    k : QWord;
begin
    k := 0;
    repeat
        Inc(k);
        Time := GetTickCount64 - FTurnedTime;
        if Time > Delay then
        begin
            Dec(Time, Delay);
            if FValue then
            begin                
                NewState := Time mod DeltaTime <= DeltaTime div 2;
                if NewState <> FState then
                begin
                    FState := NewState;
                    gpio.Value := FState;
                end;
            end;
        end
          else if k and $FF = 0 then
              gpio.Value := FState; //TODO: sprawdzenie konkurencyjności wątków
        sleep(Max(1, Min(DeltaTime div 2, Time-Delay)));
    until FTerminating;    
end;

procedure TElectromagnetConroller.Push(const Time : Integer = -1);
begin
    Value := True;
    if (Time > 0) then
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
    FTurnedTime := GetTickCount64;
    if (not FValue) or (Delay = 0) then 
    begin
        gpio.Value := FValue;
        FState := FValue;
        Exit;
    end;
end;

constructor TElectromagnetConroller.Create(const Pin : LongWord);
begin
    FValue := False;
    FDelay := 0;
    gpio := TGpioPinController.Create(Pin);
    gpio.Open;
    gpio.Direction := gdOutput;
    gpio.Value := False;
    FState := False;
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


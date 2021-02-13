unit GPIO_Pi;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, BaseUnix;

const
  GPIO_Min = 2;
  GPIO_Max = 27;

type
  TGPIOMode = (gpioINPUT, gpioOUTPUT);
  IndexGPIO = GPIO_Min..GPIO_Max;

function GetGPIO(const I: integer): boolean;
procedure SwithGPIO(const I: integer; const v: boolean);
procedure GpioMode(const i: IndexGPIO; const Mode: TGPIOMode); //Init

procedure GPIO_InitAll(const Mode: TGPIOMode);
procedure GPIO_SetAll(const v: boolean);

implementation

var
  InitIndex: integer;
  IndexAsBuf: array[IndexGPIO] of ansistring; //const
  gpioStatus: array[IndexGPIO] of boolean;

procedure GPIO_InitAll(const Mode: TGPIOMode);
var
  i: integer;
begin
  for i := GPIO_Min to GPIO_Max do
    GpioMode(i, Mode);
end;

procedure GPIO_SetAll(const v: boolean);
var
  i: integer;
begin
  for i := GPIO_Min to GPIO_Max do
    SwithGPIO(i, v);
end;

procedure StopGPIO(const i: IndexGPIO);
var
  fileDesc: integer;
begin
  if gpioStatus[i] then
  begin
    fileDesc := FpOpen('/sys/class/gpio/unexport', O_WrOnly);
    FpWrite(fileDesc, IndexAsBuf[i][1], length(IndexAsBuf[i]));
    FpClose(fileDesc);
    gpioStatus[i] := False;
  end;
end;

procedure GpioMode(const i: IndexGPIO; const Mode: TGPIOMode);
var
  fileDesc: integer;
  t: uInt64;
begin
  if not gpioStatus[i] then //init
  begin
    gpioStatus[i] := True;
    fileDesc := FpOpen('/sys/class/gpio/export', O_WrOnly);
    FpWrite(fileDesc, IndexAsBuf[i][1], length(IndexAsBuf[i]));
    FpClose(fileDesc);

    t := GetTickCount64 + 5000;
    fileDesc := -1;
    while (fileDesc = -1) or (GetTickCount64 >= t) do
      fileDesc := FpOpen('/sys/class/gpio/gpio' + IndexAsBuf[i] + '/direction', O_WRONLY);
  end
  else
    fileDesc := FpOpen('/sys/class/gpio/gpio' + IndexAsBuf[i] + '/direction', O_WRONLY);
  case Mode of
    gpioINPUT: FpWrite(fileDesc, 'in', 2);
    gpioOUTPUT: FpWrite(fileDesc, 'out', 3);
  end;
  FpClose(fileDesc);
end;

procedure SwithGPIO(const I: integer; const v: boolean);
var
  fileDesc: integer;
  vp: char;
begin
  if gpioStatus[i] then
  begin
    fileDesc := FpOpen('/sys/class/gpio/gpio' + IndexAsBuf[i] + '/value', O_WRONLY);
    if v then
      vp := '1'
    else
      vp := '0';
    FpWrite(fileDesc, vp, 1);
    FpClose(fileDesc);
  end;
end;

function GetGPIO(const I: integer): boolean;
var
  fileDesc: integer;
  vp: char;
begin
  if gpioStatus[i] then
  begin
    fileDesc := FpOpen('/sys/class/gpio/gpio' + IndexAsBuf[i] + '/value', O_RDONLY);
    FpRead(fileDesc, vp{%H-}, 1);
    FpClose(fileDesc);
    Result := vp = '1';
  end
  else
    Result := False;
end;

initialization
  for InitIndex := GPIO_Min to GPIO_Max do
  begin
    gpioStatus[InitIndex] := False;
    IndexAsBuf[InitIndex] := IntToStr(InitIndex);
  end;

finalization
    for InitIndex := GPIO_Min to GPIO_Max do
        if gpioStatus[InitIndex] then
            StopGPIO(InitIndex);

end.

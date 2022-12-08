unit YUV2Camera;

{$Mode ObjFpc}

interface

uses
    FPImage, v4l1;

type
    TYUV2Camera = class(TSimpleV4l1Device)
    public
        function GetColor(const X, Y : Integer) : TFPColor;
        constructor Create(const Width, Height : Integer; const Device : AnsiString);
    end;


implementation

function clip(const i : Integer) : Integer; inline;
begin
    if i <= 0 then
        Exit(0);
    if i >= $FFFF then 
        Exit($FFFF);
    Result := i;
end;

function YUY2ToFPColor(const V : PByte; const x, y, Width : Integer) : TFPColor; inline;
const
    Mask = not Integer(1);
var
    i : Integer;
    c, c298, d, e : Integer;
begin
    i := ((y*Width+x) and Mask) shl 1; 
    d := V[i+1] - 128;
    e := V[i+3] - 128;
    if x and 1 = 0 then c := V[i] else c := V[i+2];
    c298 := 298 * c;
    Result.Blue := clip(c298 + 516 * d - 4640); // blue
    Result.Green := clip(c298 - 100 * d - 208 * e - 4640); // green
    Result.Red := clip(c298 + 409 * e - 4640); // red
    Result.Alpha := High(Word);
end;

constructor TYUV2Camera.Create(const Width, Height : Integer; const Device : AnsiString);
begin
    inherited Create(Device, VIDEO_PALETTE_YUYV);
    SetResolution(Width, Height);
end;

function TYUV2Camera.GetColor(const X, Y : Integer) : TFPColor;
begin
    Result := YUY2ToFPColor(GetLastFrame, x, y, Video_Window.width);
end;


end.

    

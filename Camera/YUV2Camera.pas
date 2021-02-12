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
    if i < 0 then
        Exit(0);
    if i > $FFFF then 
        Exit($FFFF);
    Result := i;
end;

function YUY2ToFPColor(const V : PByte; const x, y, Width : Integer) : TFPColor; inline;
var
    i : Integer;
    y0, u0, y1, v0 : Integer;
    c, d, e : Integer;
begin
    i := ((y*Width+x) div 2) shl 2; 
    y0 := V[i];
    u0 := V[i+1];
    y1 := V[i+2];
    v0 := V[i+3];
    
    d := u0 - 128;
    e := v0 - 128;
    if (x and 1) = 0 then
    begin    
        c := y0 - 16;
        Result.Blue := clip(( 298 * c + 516 * d + 128)); // blue
        Result.Green := clip(( 298 * c - 100 * d - 208 * e + 128)); // green
        Result.Red := clip(( 298 * c + 409 * e + 128)); // red
    end else begin
        c := y1 - 16;
        Result.Blue := clip(( 298 * c + 516 * d + 128)); // blue
        Result.Green := clip(( 298 * c - 100 * d - 208 * e + 128)); // green
        Result.Red := clip(( 298 * c + 409 * e + 128)); // red
    end;
    Result.Alpha := 0;
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

    

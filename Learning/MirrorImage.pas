unit MirrorImage;

{$Mode ObjFpc}

interface

uses 
    UniversalImage;

function CreateMirrorImage1(Image : TUniversalImage) : TUniversalImage;  
function CreateMirrorImage2(Image : TUniversalImage) : TUniversalImage;  
function CreateMirrorImage3(Image : TUniversalImage) : TUniversalImage; 
function AddNoiseToImage(Image : TUniversalImage; stdev : Double = 0.005) : TUniversalImage; 

implementation

uses
    FPImage, math;

function AddNoiseToImage(Image : TUniversalImage; stdev : Double) : TUniversalImage; 
var
    x, y : Integer;
    c : TFpColor;
begin
    stdev := stdev * High(Word);
    Result := TUniversalImage.Create(Image.Width, Image.Height);
    for x := 0 to Image.Width-1 do
        for y := 0 to Image.Height-1 do
        begin
            c := Image.DirectColor[Image.Width-x-1, y];
            c.red := EnsureRange(round(c.red + RandG(0, stdev)), 0, High(Word));
            c.green := EnsureRange(round(c.green + RandG(0, stdev)), 0, High(Word));
            c.blue := EnsureRange(round(c.blue + RandG(0, stdev)), 0, High(Word));
            Result.DirectColor[x, y] := c;
        end;
end;

function CreateMirrorImage1(Image : TUniversalImage) : TUniversalImage;  
var
    x, y : Integer;
begin
    Result := TUniversalImage.Create(Image.Width, Image.Height);
    for x := 0 to Image.Width-1 do
        for y := 0 to Image.Height-1 do
            Result.DirectColor[x, y] := Image.DirectColor[Image.Width-x-1, y];
end;

function CreateMirrorImage2(Image : TUniversalImage) : TUniversalImage;  
var
    x, y : Integer;
begin
    Result := TUniversalImage.Create(Image.Width, Image.Height);
    for x := 0 to Image.Width-1 do
        for y := 0 to Image.Height-1 do
            Result.DirectColor[x, y] := Image.DirectColor[x, Image.Height-y-1];
end;
    
function CreateMirrorImage3(Image : TUniversalImage) : TUniversalImage;  
var
    x, y : Integer;
begin
    Result := TUniversalImage.Create(Image.Width, Image.Height);
    for x := 0 to Image.Width-1 do
        for y := 0 to Image.Height-1 do
            Result.DirectColor[x, y] := Image.DirectColor[Image.Width-x-1, Image.Height-y-1];
end;

end.

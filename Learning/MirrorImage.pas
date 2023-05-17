unit MirrorImage;

{$Mode ObjFpc}

interface

uses 
    UniversalImage;

type
  TTrigFilter = record
    sinXAmplitude : Double;
    cosXAmplitude : Double;
    sinXFrequency : Double;
    cosXFrequency : Double;
    sinYAmplitude : Double;
    cosYAmplitude : Double;
    sinYFrequency : Double;
    cosYFrequency : Double;
  end;

function CreateMirrorImage1(Image : TUniversalImage) : TUniversalImage;  
function CreateMirrorImage2(Image : TUniversalImage) : TUniversalImage;  
function CreateMirrorImage3(Image : TUniversalImage) : TUniversalImage; 
function AddNoiseToImage(Image : TUniversalImage; stdev : Double = 0.005) : TUniversalImage; 
function RandomTrigFilter(ampMean, ampStdev, freqMean, freqStdev : Double) : TTrigFilter;
function AddTrigFilterToImage(Image : TUniversalImage; const R, G, B : TTrigFilter) : TUniversalImage; 

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

function RandomTrigFilter(ampMean, ampStdev, freqMean, freqStdev : Double) : TTrigFilter;
begin
  Result.sinXAmplitude := RandG(ampMean, ampStdev);
  Result.cosXAmplitude := RandG(ampMean, ampStdev);
  Result.sinXFrequency := RandG(freqMean, freqStdev);
  Result.cosXFrequency := RandG(freqMean, freqStdev);
  Result.sinYAmplitude := RandG(ampMean, ampStdev);
  Result.cosYAmplitude := RandG(ampMean, ampStdev);
  Result.sinYFrequency := RandG(freqMean, freqStdev);
  Result.cosYFrequency := RandG(freqMean, freqStdev);
end;

function TrigFilterValue(const filter : TTrigFilter; const x, y : Double) : Double;
begin
  Result := filter.sinXAmplitude * sin(x * filter.sinXFrequency) + 
            filter.cosXAmplitude * cos(x * filter.cosXFrequency) + 
            filter.sinYAmplitude * sin(y * filter.sinYFrequency) + 
            filter.cosYAmplitude * cos(y * filter.cosYFrequency);
end;

function AddTrigFilterToImage(Image : TUniversalImage; const R, G, B : TTrigFilter) : TUniversalImage; 
var
    x, y : Integer;
    c : TFpColor;
begin
    Result := TUniversalImage.Create(Image.Width, Image.Height);
    for x := 0 to Image.Width-1 do
        for y := 0 to Image.Height-1 do
        begin
            c := Image.DirectColor[Image.Width-x-1, y];
            c.red := EnsureRange(round(c.red + High(Word) * TrigFilterValue(R, x/Image.Width, y/Image.Height)), 0, High(Word));
            c.green := EnsureRange(round(c.green + High(Word) * TrigFilterValue(G, x/Image.Width, y/Image.Height)), 0, High(Word));
            c.blue := EnsureRange(round(c.blue + High(Word) * TrigFilterValue(B, x/Image.Width, y/Image.Height)), 0, High(Word));
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

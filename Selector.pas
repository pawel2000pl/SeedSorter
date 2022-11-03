unit Selector;

{$mode objfpc}
{$ModeSwitch advancedrecords}   
{$inline on}

//https://pl.wikipedia.org/wiki/Radialna_funkcja_bazowa

interface

uses
    SysUtils, Classes, math, FPImage, UniversalImage, CalcUtils, Incrementations;

type    
    TDoubleRect = record 
        Left, Top, Right, Bottom : Double;
    end;

const
    DefRect : TDoubleRect = (Left:0;Top:0;Right:1;Bottom:1);
    
type
    TColorBayesTable = array[Byte, Byte, Byte] of Double; //128MB
    TColorTable = TColorBayesTable;


    TByteColor = record
        R, G, B : Byte;
        function AssignFPColor(const Color : TFPColor) : TByteColor;
    end;

    TSampleItem = packed record
        Value : int64; //liczba prawda - fałsz
        Count : int64; //liczba wszystkich
        function Average : Double; inline;
        function TrueCount : LongWord; inline;
        function FalseCount : LongWord; inline;
    end;

    TSampleArray = array[Byte, Byte, Byte] of TSampleItem; //256MB

function PrepareImage(const Image : TUniversalImage) : TUniversalImage; //pamięć musi zostać później zwolniona
procedure AddSample(const Verdict : Boolean; Image : TUniversalImage; var SampleArray : TSampleArray);
procedure CreateColorBayesTable(const SampleArray : TSampleArray; var ColorTable : TColorBayesTable);
function Mark(Image : TUniversalImage; const ColorTable : TColorBayesTable; const Rect : TDoubleRect) : Double;

implementation

const
    ShufByte : array[Byte] of Byte = (2,228,241,187,76,73,13,136,150,227,60,165,213,82,237,145,247,87,255,95,134,130,61,141,164,230,43,7,71,204,42,10,184,182,1,142,33,0,52,231,199,201,48,62,171,115,50,9,252,212,91,81,57,126,154,235,37,176,123,181,49,249,28,74,30,112,56,110,175,155,143,234,151,31,88,236,225,179,125,158,243,93,83,190,34,4,106,229,21,66,197,107,240,11,245,172,168,39,35,193,169,18,72,160,8,149,131,156,38,215,94,32,47,86,122,129,144,224,135,132,90,92,221,194,124,104,117,242,53,166,233,152,55,16,157,167,46,114,6,96,217,239,223,51,177,208,20,202,216,210,147,251,161,178,219,188,58,27,174,207,108,222,205,40,63,195,220,192,163,127,162,191,214,183,232,137,26,250,109,209,200,15,170,68,203,98,14,101,36,41,103,84,226,54,75,12,153,146,80,248,120,67,5,206,198,116,22,254,244,59,238,118,102,25,196,100,77,70,186,218,3,85,97,78,29,69,246,159,17,64,189,44,113,121,105,139,185,211,24,148,173,253,23,65,140,45,133,119,138,128,19,89,99,79,180,11);

function TByteColor.AssignFPColor(const Color : TFPColor) : TByteColor;
begin
    R := Color.Red shr 8;
    G := Color.Green shr 8;
    B := Color.Blue shr 8;
    Result := Self;
end;

function TSampleItem.Average : Double;
begin
    Result := Value/Count;
end;

function TSampleItem.TrueCount : LongWord;
begin
    Result := (Value+Count) shr 1;
end;

function TSampleItem.FalseCount : LongWord;
begin
    Result := Count - TrueCount;
end;

function PrepareImage(const Image : TUniversalImage) : TUniversalImage;
const
    CornerOrder : array[0..3, 0..1] of Integer = ((0, 0), (1, 0), (0, 1), (1, 1));
var
    ScaleR, ScaleG, ScaleB, d, empR, empG, empB : Double;
    x, y, i : Integer;
    c : TFPColor;
    CornerColors : array[0..3] of TFPColor;
    CornerColorAver : array[0..2] of Double;
begin
    Result := TUniversalImage.Create(Image.Width, Image.Height);

    CornerColorAver[0] := 0; CornerColorAver[1] := 0; CornerColorAver[2] := 0;
    for i := 0 to 3 do
    begin    
        CornerColors[i] := Image.Colors[CornerOrder[i, 0]*(Image.Width-1), CornerOrder[i, 1]*(Image.Height-1)];
        CornerColorAver[0] += CornerColors[i].Red/3; CornerColorAver[1] += CornerColors[i].Green/3; CornerColorAver[2] += CornerColors[i].Blue/3; 
    end;    
    empR := $F000 / CornerColorAver[0];
    empG := $F000 / CornerColorAver[1];
    empB := $F000 / CornerColorAver[2]; 
        
    for x := 0 to Image.Width-1 do
        for y := 0 to Image.Height-1 do
        begin
            ScaleR := 0; ScaleG := 0; ScaleB := 0;
            for i := 0 to 3 do
            begin    
                d := (x/(Image.Width-1)*CornerOrder[i, 0] + (1-x/(Image.Width-1))*(1-CornerOrder[i, 0])) * (y/(Image.Height-1)*CornerOrder[i, 1] + (1-y/(Image.Height-1))*(1-CornerOrder[i, 1]));
                ScaleR += CornerColorAver[0]/(CornerColors[i].Red+1e-5) * d * empR;
                ScaleG += CornerColorAver[1]/(CornerColors[i].Green+1e-5) * d * empG;
                ScaleB += CornerColorAver[2]/(CornerColors[i].Blue+1e-5) * d * empB;
            end; 
            c := Image.Colors[x, y];
            c.Red := EnsureRange(round(c.Red*ScaleR), 0, $FFFF);
            c.Green := EnsureRange(round(c.Green*ScaleG), 0, $FFFF);
            c.Blue := EnsureRange(round(c.Blue*ScaleB), 0, $FFFF);
            Result.Colors[x, y] := c;
        end;
end;

procedure AddSample(const Verdict : Boolean; Image : TUniversalImage; var SampleArray : TSampleArray);
var
    c : TByteColor;
    x, y, d : Integer;
begin
    d := ifthen(Verdict, 1, -1);
    for x := 0 to Image.Width-1 do
        for y := 0 to Image.Height-1 do
        begin    
            c.AssignFPColor(Image.Colors[x, y]);
            Inc(SampleArray[c.r, c.g, c.b].Value, d);
            Inc(SampleArray[c.r, c.g, c.b].Count);
        end;
end;

procedure SummarizeSample(const SampleArray : TSampleArray; out TrueCount, FalseCount, Count : QWord);
var
    r, g, b : Integer;
begin
    TrueCount := 0;
    FalseCount := 0;
    Count := 0;
    for r := 0 to 255 do
        for g := 0 to 255 do
            for b := 0 to 255 do
            begin
                Inc(TrueCount, SampleArray[r, g, b].TrueCount);
                Inc(FalseCount, SampleArray[r, g, b].FalseCount);
                if SampleArray[r, g, b].Count > 0 then 
                    Inc(Count, SampleArray[r, g, b].Count);
            end;
end;

procedure PutSample(const Value : Double; const r, g, b : Integer;  var ColorTable : TColorBayesTable);
const
    ray = 16;
var
    i : Integer;
    v : TIntVector3;
begin
    i := 0;
    repeat  
        v := GetCoordPriorityByDistance(i) + IntVector3(r, g, b);
        if not (InRange(v[axisX], 0, 255) and InRange(v[axisY], 0, 255) and InRange(v[axisZ], 0, 255)) then
                Continue;
        ColorTable[v[axisX], v[axisY], v[axisZ]] += Value/hypot(1,GetCoordPriorityByDistanceLength(i));
    until GetCoordPriorityByDistanceLength(PreInc(i)) > ray;
end;

procedure Normalize(var ColorTable : TColorBayesTable);
var
    r, g, b : Integer;  
    lv, hv : Double;
begin
    lv := 0; hv := 0;
    for r := 0 to 255 do
        for g := 0 to 255 do
            for b := 0 to 255 do
                if ColorTable[r, g, b] > hv then
                    hv := ColorTable[r, g, b]
                else if ColorTable[r, g, b] < lv then
                    lv := ColorTable[r, g, b];
    
    for r := 0 to 255 do
        for g := 0 to 255 do
            for b := 0 to 255 do
                ColorTable[r, g, b] := (ColorTable[r, g, b] - (hv+lv)/2) / ((hv-lv)/2); 
end;

procedure CreateColorBayesTable(const SampleArray : TSampleArray; var ColorTable : TColorBayesTable);
var
    TrueCount, FalseCount, Count : QWord;
    r, g, b : Integer;
    p : Integer;
begin
    FillByte(ColorTable, SizeOf(ColorTable), 0);
    SummarizeSample(SampleArray, TrueCount, FalseCount, Count);  
    p := 0;
    for r in ShufByte do
    begin    
        for g := 0 to 255 do
            for b := 0 to 255 do
                if SampleArray[r, g, b].Count > 0 then
                    PutSample(SampleArray[r, g, b].Average, r, g, b, ColorTable);
        inc(p);
        writeln(p/256*100:2:2, '%');
    end;
    Normalize(ColorTable);
end;

function Mark(Image : TUniversalImage; const ColorTable : TColorBayesTable; const Rect : TDoubleRect) : Double;
var
    c : TByteColor;
    i, x, y, Count : Integer;

begin
    Count := 0;
    for x := floor(Image.Width * Rect.Left) to floor(Image.Width * Rect.Right)-1 do
        for y := floor(Image.Height * Rect.Top) to floor(Image.Height * Rect.Bottom)-1 do
        begin
            c.AssignFPColor(Image.Colors[x, y]); 
            if ColorTable[c.r, c.g, c.b] > 0 then
            begin 
                Inc(Count);
                Image.Colors[x, y] := FPColor(0, $FFFF, 0, 0);
            end; 
        end;
    Result := Count/(Image.Width*Image.Height*(Rect.Bottom-Rect.Top)*(Rect.Right-Rect.Left)); 
end;

end.

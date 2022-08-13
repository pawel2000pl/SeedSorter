unit VectorizeImage;

{$mode objfpc}{$H+}


interface

uses
  Classes, SysUtils, FPImage, math;

type
  TColorFunction = function(const x, y : Integer) : TFPColor of object;
  TDoubleArray = array of Double;

  { TFPImageColorFunctionHelper }

  TFPImageColorFunctionHelper = class helper for TFPCustomImage
    function GetColorFromHelper(const x, y : Integer) : TFPColor;
  end;

  function Img2Vector(const fun : TColorFunction; const left, top, right, bottom, DestWidth, DestHeight : Integer) : TDoubleArray;
  procedure NormalizeVector(var v : TDoubleArray);
  function RetNormalizeVector(const v : TDoubleArray) : TDoubleArray;
  procedure NormalizeVector01(var v : TDoubleArray);
  procedure NormalizeVectorRGB(var v : TDoubleArray);
  function RetNormalizeVector01(const v : TDoubleArray) : TDoubleArray;
  procedure Vector2Img(const Vector : TDoubleArray; const Width, Height : Integer; Image : TFPCustomImage);
  procedure AddToVector(var Vector : TDoubleArray; const value : Double);

implementation

function Img2Vector(const fun: TColorFunction; const left, top, right, bottom, DestWidth, DestHeight: Integer): TDoubleArray;
const
    OnePerWord = 1.0/High(word);
var
    i, j, tripleIndex, index, imgWidth, imgHeight, offset, tripleDestWidth : Integer;
    counts : array of Integer;
    MaxBufIndex : QWord;
    c : TFPColor;
    changes : Boolean;
begin
    MaxBufIndex := DestWidth * DestHeight;
    tripleDestWidth := 3 * DestWidth;
    imgWidth := right - left + 1;
    imgHeight := bottom - top + 1;
    Result := [];
    Counts := [];
    SetLength(Result, 3*MaxBufIndex);
    SetLength(Counts, MaxBufIndex);
    for i := left to right do
        for j := top to bottom do
        begin
          c := fun(i, j);
          index := QWord((j-top) * DestHeight div ImgHeight * DestWidth + (i-left) * DestWidth div ImgWidth);
          tripleIndex := 3*index;
          Result[tripleIndex] += c.red * OnePerWord;
          Result[tripleIndex+1] += c.green * OnePerWord;
          Result[tripleIndex+2] += c.blue * OnePerWord;
          Inc(Counts[index]);
        end;

    changes := False;
    for i := 0 to MaxBufIndex-1 do
      if Counts[i] > 0 then
      begin
        tripleIndex := 3*i;
        Result[tripleIndex] /= Counts[i];
        Result[tripleIndex+1] /= Counts[i];
        Result[tripleIndex+2] /= Counts[i];
      end else changes:=True;

    index := 0;
    tripleIndex := 0;
    if changes then
      for j := 0 to DestHeight-1 do
        for i := 0 to DestWidth-1 do
        begin
           Inc(index); //index := (j * DestWidth + i);
           Inc(tripleIndex, 3); //tripleIndex := 3*index;
           if counts[index] = 0 then
           begin
              if j > 0 then
              begin
                  offset := tripleIndex - tripleDestWidth; //3*((j-1) * DestWidth + i);
                  Result[tripleIndex] += Result[offset];
                  Result[tripleIndex+1] += Result[offset+1];
                  Result[tripleIndex+2] += Result[offset+2];
                  Inc(counts[index]);
              end;
              if j < DestHeight-1 then
              begin
                  offset := tripleIndex + tripleDestWidth; //3*((j+1) * DestWidth + i);
                  Result[tripleIndex] += Result[offset];
                  Result[tripleIndex+1] += Result[offset+1];
                  Result[tripleIndex+2] += Result[offset+2];
                  Inc(counts[index]);
              end;
              if i > 0 then
              begin
                  offset := tripleIndex - 3; //3*(j * DestWidth + i-1);
                  Result[tripleIndex] += Result[offset];
                  Result[tripleIndex+1] += Result[offset+1];
                  Result[tripleIndex+2] += Result[offset+2];
                  Inc(counts[index]);
              end;
              if i < DestWidth-1 then
              begin
                  offset := tripleIndex + 3; //3*(j * DestWidth + i+1);
                  Result[tripleIndex] += Result[offset];
                  Result[tripleIndex+1] += Result[offset+1];
                  Result[tripleIndex+2] += Result[offset+2];
                  Inc(counts[index]);
              end;
              Result[tripleIndex] /= counts[index];
              Result[tripleIndex+1] /= counts[index];
              Result[tripleIndex+2] /= counts[index];
           end;
        end;
end;

procedure Vector2Img(const Vector : TDoubleArray; const Width, Height : Integer; Image : TFPCustomImage);
var
    i, j : Integer;
    c : TFPColor;
begin
    Image.SetSize(Width, Height);
    for i := 0 to Width-1 do
      for j := 0 to Height-1 do
      begin
         c.red := EnsureRange(round(Vector[3*(j*Width+i)]*High(word)), 0, High(word));
         c.green := EnsureRange(round(Vector[3*(j*Width+i)+1]*High(word)), 0, High(word));
         c.blue := EnsureRange(round(Vector[3*(j*Width+i)+2]*High(word)), 0, High(word));
         Image.Colors[i, j] := c;
      end;
end;

procedure AddToVector(var Vector: TDoubleArray; const value: Double);
var
    i : Integer;
begin
    for i := low(Vector) to High(Vector) do
      Vector[i] += value;
end;

procedure NormalizeVector01(var v : TDoubleArray);
var
    i : Integer;
    minValue, maxValue : Double;
begin
    minValue := math.MinValue(v);
    maxValue := math.MaxValue(v);
    for i := low(v) to High(v) do
        v[i] := (v[i]-minValue)/(maxValue - minValue);
end;

procedure NormalizeVectorRGB(var v: TDoubleArray);
var
    minR, maxR, minG, maxG, minB, maxB : Double;
    tripleI, i : Integer;
begin
    minR := v[0];
    maxR := v[0];
    minG := v[1];
    maxG := v[1];
    minB := v[2];
    maxB := v[2];

    for i := 0 to Length(v) div 3 -1 do
    begin
      tripleI := 3*i;
      if v[tripleI] > maxR then maxR := v[tripleI] else if v[tripleI] < minR then minR := v[tripleI];
      if v[tripleI+1] > maxG then maxG := v[tripleI+1] else if v[tripleI+1] < minG then minG := v[tripleI+1];
      if v[tripleI+2] > maxB then maxB := v[tripleI+2] else if v[tripleI+2] < minB then minB := v[tripleI+2];
    end;

    for i := 0 to Length(v) div 3 -1 do
    begin
      tripleI := 3*i;
      v[tripleI] := (v[tripleI] - minR) / (maxR - minR);
      v[tripleI+1] := (v[tripleI+1] - minG) / (maxG - minG);
      v[tripleI+2] := (v[tripleI+2] - minB) / (maxB - minB);
    end;
end;

function RetNormalizeVector01(const v : TDoubleArray) : TDoubleArray;   
var
    i : Integer;
    minValue, maxValue : Double;
begin
    minValue := math.MinValue(v);
    maxValue := math.MaxValue(v);
    SetLength(Result, Length(v));
    for i := 0 to  Length(v)-1 do
        Result[i] := (v[i]-minValue)/(maxValue - minValue);
end;

procedure NormalizeVector(var v : TDoubleArray);
var
    mean, stddev : float;
    i : Integer;
begin
  mean := 0; stddev := 0;
  MeanAndStdDev(v, mean, stddev);
  for i := 0 to Length(v) do
      v[i] := (v[i]-mean)*2/stddev;
end;

function RetNormalizeVector(const v : TDoubleArray) : TDoubleArray;
var
    mean, stddev : float;
    i : Integer;
begin
  Result := [];
  SetLength(Result, Length(v));
  mean := 0; stddev := 0;
  MeanAndStdDev(v, mean, stddev);
  for i := 0 to Length(v) do
      Result[i] := (v[i]-mean)*2/stddev;
end;

{ TFPImageColorFunctionHelper }

function TFPImageColorFunctionHelper.GetColorFromHelper(const x, y: Integer): TFPColor;
begin
     Exit(Self.Colors[x, y]);
end;

end.


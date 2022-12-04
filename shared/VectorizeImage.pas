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

  TGradientSupressor = array[0..3, 0..2] of Double;
  PGradientSupressor = ^TGradientSupressor;

  { TImageVectorizer }

  TImageVectorizer = class
  type
    TDataItem = record
      NeedUpdate : Boolean;
      Index : Integer;
      SourceX : Integer;
      SourceY : Integer;
      Weight : Double;
    end;
  private
    OutputLength : Integer;
    DataLength : Integer;
    Data : array of TDataItem;
  public
    function Vectorize(const fun : TColorFunction) : TDoubleArray;
    constructor Create(const Left, Top, Right, Bottom, DestWidth, DestHeight : Integer; const Epsilon: Double = 1e-9);
  end;

const DefaultDestValueOfPrepareImage = 0.93;
const DefaultSupressorTimePeriodOfPrepareImage = 3;

  function Img2Vector(const fun : TColorFunction; const left, top, right, bottom, DestWidth, DestHeight : Integer) : TDoubleArray;
  procedure NormalizeVector(var v : TDoubleArray);
  function RetNormalizeVector(const v : TDoubleArray) : TDoubleArray;
  procedure NormalizeVector01(var v : TDoubleArray);
  procedure NormalizeVectorRGB(var v : TDoubleArray);
  function RetNormalizeVector01(const v : TDoubleArray) : TDoubleArray;
  procedure Vector2Img(const Vector : TDoubleArray; const Width, Height : Integer; Image : TFPCustomImage);
  function PrepareImage(const ImageAsVector : TDoubleArray; const Width, Height : Integer; const DestValue : Double = DefaultDestValueOfPrepareImage; const Supressor: PGradientSupressor = nil; const SupressorTimePeriod: Double = DefaultSupressorTimePeriodOfPrepareImage) : TDoubleArray;
  procedure AddToVector(var Vector : TDoubleArray; const value : Double);

implementation

function PrepareImage(const ImageAsVector : TDoubleArray; const Width, Height : Integer; const DestValue : Double; const Supressor: PGradientSupressor; const SupressorTimePeriod: Double) : TDoubleArray;
const
    CornerOrder : array[0..3, 0..1] of Integer = ((0, 0), (1, 0), (0, 1), (1, 1));
var
    d : Double;
    Scale : array[0..2] of Double;
    x, y, i, j, offset : Integer;
    CornerColors : array[0..3, 0..2] of Double;
begin
    Result := [];
    SetLength(Result, Width*Height*3);

    for i := 0 to 3 do
    begin    
        offset := 3*(CornerOrder[i, 1]*(Height-1) * Width + CornerOrder[i, 0]*(Width-1));
        for j := 0 to 2 do
          CornerColors[i, j] := ImageAsVector[offset+j];
    end;    

    if Supressor <> nil then
      for i := 0 to 3 do
        for j := 0 to 2 do
        begin
          Supressor^[i, j] += (CornerColors[i, j]-Supressor^[i, j])/SupressorTimePeriod;
          CornerColors[i, j] := Supressor^[i, j];
        end;
        
    for x := 0 to Width-1 do
        for y := 0 to Height-1 do
        begin
            for j := 0 to 2 do
              Scale[j] := 0;
            for i := 0 to 3 do
            begin    
                d := (x/(Width-1)*CornerOrder[i, 0] + (1-x/(Width-1))*(1-CornerOrder[i, 0])) * 
                     (y/(Height-1)*CornerOrder[i, 1] + (1-y/(Height-1))*(1-CornerOrder[i, 1]));
                for j := 0 to 2 do
                  Scale[j] += 1/(CornerColors[i, j]+1e-5) * DestValue * d;
            end; 
            offset := 3*(y * Width + x);
            for j := 0 to 2 do
              Result[offset+j] := EnsureRange(ImageAsVector[offset]*Scale[j], 0, 1);
        end;
end;

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
          Inc(counts[index]);
        end;

    changes := False;
    for i := 0 to MaxBufIndex-1 do
        if counts[i] > 0 then
        begin
            tripleIndex := 3*i;
            Result[tripleIndex] /= counts[i];
            Result[tripleIndex+1] /= counts[i];
            Result[tripleIndex+2] /= counts[i];
        end else 
            changes:=True;

    index := 0;
    tripleIndex := 0;
    while changes do
    begin
        Changes := False;
        for j := 0 to DestHeight-1 do
            for i := 0 to DestWidth-1 do
            begin
                Inc(index); //index := (j * DestWidth + i);
                Inc(tripleIndex, 3); //tripleIndex := 3*index;
                if counts[index] = 0 then
                begin
                    if (j > 0) and (counts[index-DestWidth]>0) then
                    begin
                        offset := tripleIndex - tripleDestWidth; //3*((j-1) * DestWidth + i);
                        Result[tripleIndex] += Result[offset];
                        Result[tripleIndex+1] += Result[offset+1];
                        Result[tripleIndex+2] += Result[offset+2];
                        Inc(counts[index]);
                    end;
                    if (j < DestHeight-1) and (counts[index+DestWidth]>0) then
                    begin
                        offset := tripleIndex + tripleDestWidth; //3*((j+1) * DestWidth + i);
                        Result[tripleIndex] += Result[offset];
                        Result[tripleIndex+1] += Result[offset+1];
                        Result[tripleIndex+2] += Result[offset+2];
                        Inc(counts[index]);
                    end;
                    if (i > 0) and (counts[index-1]>0) then
                    begin
                        offset := tripleIndex - 3; //3*(j * DestWidth + i-1);
                        Result[tripleIndex] += Result[offset];
                        Result[tripleIndex+1] += Result[offset+1];
                        Result[tripleIndex+2] += Result[offset+2];
                        Inc(counts[index]);
                    end;
                    if (i < DestWidth-1) and (counts[index+1]>0) then
                    begin
                        offset := tripleIndex + 3; //3*(j * DestWidth + i+1);
                        Result[tripleIndex] += Result[offset];
                        Result[tripleIndex+1] += Result[offset+1];
                        Result[tripleIndex+2] += Result[offset+2];
                        Inc(counts[index]);
                    end;
                    if counts[index] > 0 then
                    begin
                        Result[tripleIndex] /= counts[index];
                        Result[tripleIndex+1] /= counts[index];
                        Result[tripleIndex+2] /= counts[index];
                    end else
                        Changes := True;
                end;
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
         c.alpha := High(Word);
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

{ TImageVectorizer }

function TImageVectorizer.Vectorize(const fun : TColorFunction) : TDoubleArray;
var
  i : Integer;
  c : TFPColor;
begin
  Result := [];
  SetLength(Result, OutputLength);
  for i := 0 to DataLength-1 do
    with Data[i] do
    begin
      if NeedUpdate then
        c := fun(SourceX, SourceY);
      Result[Index] += Weight*c.Red;
      Result[Index+1] += Weight*c.Green;
      Result[Index+2] += Weight*c.Blue;
    end;
end;

constructor TImageVectorizer.Create(const Left, Top, Right, Bottom, DestWidth, DestHeight: Integer; const Epsilon: Double);
var
  x, y, ix, iy, i, DestIndex, SourceWidth, SourceHeight, AdditionalSpace : Integer;
  sxa, sya, sxb, syb, WidthScale, HeightScale, AreaScale, w, rx1, ry1, rx2, ry2 : Double;

  PointCount : Integer;
  DestinationIndexes : array of array of array of Integer;
  DestinationWeights : array of array of array of Double;
  DestinationCounts : array of array of Integer;
  Dest : array of Double;
begin
  assert(Epsilon > 0);
  SourceWidth := Right-Left+1;
  SourceHeight := Bottom-Top+1;
  OutputLength := 3 * DestWidth * DestHeight;
  WidthScale := SourceWidth/DestWidth;
  HeightScale := SourceHeight/DestHeight;
  AreaScale := 1/(WidthScale*HeightScale);

  PointCount := 0;
  AdditionalSpace := Ceil(1/WidthScale+1) * Ceil(1/HeightScale+1);
  DestinationIndexes := [];
  DestinationWeights := [];
  DestinationCounts := [];
  SetLength(DestinationIndexes, SourceWidth, SourceHeight, AdditionalSpace);
  SetLength(DestinationWeights, SourceWidth, SourceHeight, AdditionalSpace);
  SetLength(DestinationCounts, SourceWidth, SourceHeight);

  for y := 0 to DestHeight-1 do
  begin
    sya := HeightScale*y;
    syb := sya+HeightScale;
    for x := 0 to DestWidth-1 do
    begin
      sxa := WidthScale*x;
      sxb := sxa+WidthScale;
      DestIndex := y * DestWidth + x;

      for iy := Floor(sya) to Floor(syb) do
        for ix := Floor(sxa) to Floor(sxb) do
        begin
          rx1 := min(sxb, ix+1)-ix;
          ry1 := min(syb, iy+1)-iy;
          rx2 := max(sxa, ix)-ix;
          ry2 := max(sya, iy)-iy;
          w := AreaScale * (rx1-rx2) * (ry1-ry2);
          if w <= Epsilon then
            Continue;
          DestinationIndexes[ix, iy, DestinationCounts[ix, iy]] := DestIndex;
          DestinationWeights[ix, iy, DestinationCounts[ix, iy]] := w;
          Inc(DestinationCounts[ix, iy]);
          Inc(PointCount);
        end;
    end;
  end;

  Data := [];
  Dest := [];
  SetLength(Data, PointCount);
  SetLength(Dest, PointCount);
  DataLength := PointCount;
  PointCount := 0;
  for y := 0 to SourceHeight-1 do
    for x := 0 to SourceWidth-1 do
    begin
      Data[PointCount].NeedUpdate := True;
      for i := 0 to DestinationCounts[x, y]-1 do
        with Data[PointCount] do
        begin
          Index := 3*DestinationIndexes[x, y, i];
          SourceX := x+Left;
          SourceY := y+Right;
          Weight := DestinationWeights[x, y, i]*(1/High(Word));
          Dest[DestinationIndexes[x, y, i]] += DestinationWeights[x, y, i];
          Inc(PointCount);
        end;
    end; 

  for i := 0 to DestWidth*DestHeight-1 do
    Data[i].Weight /= Dest[i];
end;

end.


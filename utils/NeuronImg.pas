unit NeuronImg;

{$Mode ObjFpc}

interface

uses
    Classes, FpImage, UniversalImage;

type

    TSingleColor = array[0..2] of Single;
    PSingleColor = ^TSingleColor;

    TSampleImage = record
        Image : TUniversalImage;
        Verdict : Boolean;
    end;

    TColorFunction = function(const x, y : Integer) : TFPColor of object;
    
    TNeuron = class
    private
        FWidth, FHeight : Integer;
        Inputs : array of array of TSingleColor;
        Addiction : Single;

        function InputAtPosition(const x, y : Single) : PSingleColor;

        procedure AddToInput(const x, y : Single; const Value : TSingleColor);
        function GetInput(const x, y : Single) : TSingleColor;

    public
        procedure SaveToStream(Stream : TStream);
        procedure LoadFromStream(Stream : TStream);

        procedure AddRandomState;
    
        function AnaliseImage(Image : TUniversalImage) : Single;
        function AnaliseImage(const ColorFunction : TColorFunction; const Left, Top, Right, Bottom : Integer) : Single; overload;

        procedure CorrectProbe(Image : TUniversalImage; const ExpectedValue, Speed : Single);
        function Learn(const samples : array of TSampleImage; const Speed : Single = 0.2; const MaxIterations : PtrUInt = $10000; const PrintPercentage : Boolean = False) : Boolean;

        function CreateMap : TUniversalImage;
        
        constructor Create(const AWidth, AHeight : Integer);
        constructor Create(Stream : TStream);
    end;


operator := (const x : TFPColor) : TSingleColor; inline;
operator := (const x : TSingleColor) : TFPColor; inline;

operator * (const a : TSingleColor; const b : Single) : TSingleColor; inline;
operator * (const a : Single; const b : TSingleColor) : TSingleColor; inline;
operator * (const a, b : TSingleColor) : Single; inline;

operator + (const a : TSingleColor; const b : Single) : TSingleColor; inline;
operator + (const a : Single; const b : TSingleColor) : TSingleColor; inline;
operator + (const a, b : TSingleColor) : TSingleColor; inline;

implementation

uses
    Math;
    
function SmoothValue(const x : Single) : Single; inline;
begin
    Exit(sqr(sin(x*pi/2)));
end;

operator := (const x : TFPColor) : TSingleColor;
begin
    Result[0] := x.Red/65535;
    Result[1] := x.Green/65535;
    Result[2] := x.Blue/65535;
end;

operator := (const x : TSingleColor) : TFPColor;
begin
    Result.Red := EnsureRange(round(x[0]*65535), 0, 65535);
    Result.Green := EnsureRange(round(x[1]*65535), 0, 65535);
    Result.Blue := EnsureRange(round(x[2]*65535), 0, 65535);
end;

operator * (const a : TSingleColor; const b : Single) : TSingleColor;
begin
    Result[0] := a[0]*b;
    Result[1] := a[1]*b;
    Result[2] := a[2]*b;
end;

operator * (const a : Single; const b : TSingleColor) : TSingleColor;
begin
    Exit(b*a);
end;

operator * (const a, b : TSingleColor) : Single; 
begin
    Result := a[0]*b[0]+a[1]*b[1]+a[2]*b[2];
end;
    
operator + (const a : TSingleColor; const b : Single) : TSingleColor;
begin
    Result[0] := a[0]+b;
    Result[1] := a[1]+b;
    Result[2] := a[2]+b;
end;

operator + (const a : Single; const b : TSingleColor) : TSingleColor;
begin
    Exit(b+a);
end;

operator + (const a, b : TSingleColor) : TSingleColor; 
begin
    Result[0] := a[0]+b[0];
    Result[1] := a[1]+b[1];
    Result[2] := a[2]+b[2];
end;

procedure TNeuron.SaveToStream(Stream : TStream);
var
    x, y : LongWord;
begin
    Stream.WriteBuffer(Addiction, SizeOf(Addiction));
    Stream.WriteDWord(FWidth);
    Stream.WriteDWord(FHeight);    
    for x := 0 to FWidth-1 do
        for y := 0 to FHeight-1 do
            Stream.WriteBuffer(Inputs[x, y][0], SizeOf(TSingleColor));
end;
    
procedure TNeuron.LoadFromStream(Stream : TStream);
var
    x, y : LongWord;
begin
    Stream.ReadBuffer(Addiction, SizeOf(Addiction));
    FWidth := Stream.ReadDWord;
    FHeight := Stream.ReadDWord;    
    SetLength(Inputs, FWidth, FHeight);
    for x := 0 to FWidth-1 do
        for y := 0 to FHeight-1 do
            Stream.ReadBuffer(Inputs[x, y][0], SizeOf(TSingleColor));
end;
    
function TNeuron.InputAtPosition(const x, y : Single) : PSingleColor;
begin   
    Result := @Inputs[floor(x * FWidth), floor(y * FHeight)];
end;

procedure TNeuron.AddToInput(const x, y : Single; const Value : TSingleColor);
var
    rx, ry : Single;
    ix, iy : Integer;
    fx, fy : Single;
begin
    rx := x * (FWidth-1);
    ry := y * (FHeight-1);
    ix := Floor(rx);
    iy := Floor(ry);
    fx := rx - ix;
    fy := ry - iy;
    
    Inputs[ix+1, iy+1] += Value * fx * fy;
    Inputs[ix+1, iy] += Value * fx * (1-fy);
    Inputs[ix, iy+1] += Value * (1-fx) * fy;
    Inputs[ix, iy] += Value * (1-fx) * (1-fy);     
end;

function TNeuron.GetInput(const x, y : Single) : TSingleColor;
var
    rx, ry : Single;
    ix, iy : Integer;
    fx, fy : Single;
begin
    rx := x * (FWidth-1);
    ry := y * (FHeight-1);
    ix := Floor(rx);
    iy := Floor(ry);
    fx := rx - ix;
    fy := ry - iy;
    Result := Inputs[ix+1, iy+1] * fx * fy + Inputs[ix+1, iy] * fx * (1-fy) + Inputs[ix, iy+1] * (1-fx) * fy + Inputs[ix, iy] * (1-fx) * (1-fy);
end;

procedure TNeuron.AddRandomState;
var
    x, y : Integer;
begin
    for x := 0 to FWidth-1 do
        for y := 0 to FHeight-1 do
        begin
            Inputs[x, y][0] += RandG(0, 1);
            Inputs[x, y][1] += RandG(0, 1);
            Inputs[x, y][2] += RandG(0, 1);
        end;
    Addiction += RandG(0, 1);
end;

function TNeuron.AnaliseImage(Image : TUniversalImage) : Single;
begin
    Exit(AnaliseImage(@Image.GetDirectColor, 0, 0, Image.Width-1, Image.Height-1));
end;

function TNeuron.AnaliseImage(const ColorFunction : TColorFunction; const Left, Top, Right, Bottom : Integer) : Single; 
var
    x, y, w, h : Integer;
begin
    w := Right-Left+1; 
    h := Bottom-Top+1;
    Result := 0;
    for x := Left to Right do
        for y := Top to Bottom do
            Result += GetInput((x-Left)/w, (y-Top)/h)*TSingleColor(ColorFunction(x, y));
    Result := Result / (w*h) + Addiction;
end;

procedure TNeuron.CorrectProbe(Image : TUniversalImage; const ExpectedValue, Speed : Single);
var
    x, y : Integer;
    TrueSpeed : Single;
begin
    TrueSpeed := Speed*FWidth*FHeight/(Image.Width*Image.Height);
    for x := 0 to Image.Width-1 do
        for y := 0 to Image.Height-1 do
            AddToInput(x/Image.Width, y/Image.Height, TSingleColor(Image.DirectColor[x, y]) * TrueSpeed * ExpectedValue);
end;

function TNeuron.Learn(const samples : array of TSampleImage; const Speed : Single; const MaxIterations : PtrUInt; const PrintPercentage : Boolean) : Boolean;
var
    Iterations : PtrUInt;
    Mistakes : Integer;
    d : Single;
    MisSamples : array of TSampleImage;
    Sample : TSampleImage;
    TrueSpeed : Double;
begin
    Iterations := 0;
    
    repeat
        Mistakes := 0;
        SetLength(MisSamples, 0);

        for Sample in Samples do
            if (AnaliseImage(Sample.Image) < 0) <> Sample.Verdict then
            begin
                Inc(Mistakes);
                SetLength(MisSamples, Mistakes);
                MisSamples[Mistakes-1] := Sample;
            end;
        
        TrueSpeed := Speed * (1-Iterations/(1+MaxIterations));
        
        for Sample in MisSamples do
        begin
            if Sample.Verdict then
                d := -1
            else
                d := 1;   
            CorrectProbe(Sample.Image, d, TrueSpeed);
            Addiction += d * Speed;
        end;

        if PrintPercentage then
            writeln(Iterations, #9, 100-Mistakes/Length(Samples)*100:3:2, '%');
        
        Inc(Iterations);
    until (Mistakes = 0) or (Iterations > MaxIterations);

    Result := not (Iterations > MaxIterations);
end;

function TNeuron.CreateMap : TUniversalImage;
var
    x, y : Integer;
    l, h : Single;
begin
    Result := TUniversalImage.Create(FWidth, FHeight);

    h := Inputs[0, 0][0];
    l := h;
    
    for x := 0 to FWidth-1 do
        for y := 0 to FHeight-1 do
        begin
            if l > MinValue(Inputs[x, y]) then
                l := MinValue(Inputs[x, y]);
            if h < MaxValue(Inputs[x, y]) then
                h := MaxValue(Inputs[x, y]);
        end;
            
    for x := 0 to FWidth-1 do
        for y := 0 to FHeight-1 do
            Result.DirectColor[x, y] := (Inputs[x, y]+(-l))*(1/(h-l));
end;

constructor TNeuron.Create(const AWidth, AHeight : Integer);
begin
    FWidth := AWidth;
    FHeight := AHeight;
    SetLength(Inputs, 0);
    SetLength(Inputs, FWidth, FHeight);
    Addiction := 0;
end;

constructor TNeuron.Create(Stream : TStream);
begin
    Create(0, 0);
    LoadFromStream(Stream);
end;

end.
    

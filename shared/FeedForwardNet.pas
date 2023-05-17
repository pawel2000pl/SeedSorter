unit FeedForwardNet;

{$mode ObjFPC}{$H+}
{$IfNDef ASSERTIONS} {$Inline On} {$Optimization AutoInline} {$Endif}
{$WARN 6058 off : Call to subroutine "$1" marked as inline is not inlined}
{$Define SIGMOID_APPROXIMATION}

interface

uses
  Classes, SysUtils;

type

  TDataVector = array of double;
  TSumFunction = function(const a, b: TDataVector): double;

  TConfusionMatrixCell = record
    Count : QWord;
    Partial : Double;
  end;

  TInputDerivate = record
    min, max, mean, stdDev : Extended;
    absoluteMin, absoluteMax, absoluteMean, absoluteStdDev : Extended;
    squaredMin, squaredMax, squaredMean, squaredStdDev : Extended;
  end;

  TConfusionMatrix = array of array of TConfusionMatrixCell;

  { TFeedForwardLayer }

  TFeedForwardLayer = class
  const
    MaxAmplitude = 16;
  private
    fInputCount: integer;
    fNeuronCount: integer;
    fWeights: array of array of Double;
    fBias: array of double;
    fLocker : TMultiReadExclusiveWriteSynchronizer;
  public
    class function ActivateFunction(x: double): double; static; inline;
    class function DerivateOfActivateFunction(x: double): double; static; inline;

    property InputCount : Integer read fInputCount;
    property NeuronCount : Integer read fNeuronCount;

    function DegreeOfFreedomCount : Integer; inline;
    function GetDegreeOfFreedom(Index : Integer) : Double; inline;
    procedure SetDegreeOfFreedom(Index : Integer; AValue : Double); inline;
    property DegreeOfFreedom[Index : Integer] : Double read GetDegreeOfFreedom write SetDegreeOfFreedom;

    function RawWeightsMultiplication(const Data: TDataVector): TDataVector;
    function VectorActivateFunction(const Data: TDataVector): TDataVector;
    function VectorDerivateOfActivateFunction(const Data: TDataVector): TDataVector;
    function ProcessData(const Data: TDataVector): TDataVector; inline;
    function DataToDerivates(const Data: TDataVector): TDataVector; inline;
    procedure CorrectSample(const Data, ExpectedOutput: TDataVector; const Quickness: double); overload;
    function CorrectSample(const Layers: array of TFeedForwardLayer; const Index: integer; const Data, ExpectedOutput: TDataVector;
      const Quickness: double): TDataVector; overload;
    function CorrectInput(const CurrentInput, ExpectedOutput: TDataVector): TDataVector;
    procedure Backpropagation(const Data, ExpectedOutput: TDataVector; const Quickness: double); overload;
    function Backpropagation(const Layers: array of TFeedForwardLayer; const Index: integer; const Data, ExpectedOutput: TDataVector;
      const Quickness: double): TDataVector; overload;

    procedure RandomAll;
    procedure RandomAllAddition(const mean, stddev: double);
    procedure RandomAllMultiplication(const mean, stddev: double);
    procedure SaveToStream(Stream: TStream);
    procedure LoadFromStream(Stream: TStream);

    constructor Create; overload;
    constructor Create(Stream: TStream); overload;
    constructor Create(const AnInputCount: integer; const ANeuronCount: integer); overload;
    destructor Destroy; override;

    function GetHashCode: PtrInt; override;
    function Equals(Obj: TObject): boolean; override;
  end;

  { TFeedForwardNet }

  TFeedForwardNet = class
  type
    TLearnProcedure = procedure(const Data: array of TDataVector; const ExpectedValues: array of TDataVector; const Quickness: double) of object;
    TLearnRecord = record
      method : TLearnProcedure;
      Data : array of TDataVector;
      ExpectedValues : array of TDataVector;
      Quickness : Double;
    end;
    PLearnRecord = ^TLearnRecord;
  private
    fLayers: array of TFeedForwardLayer;
    procedure DisposeLayers;
    class function AsyncLearn(rec : Pointer) : PtrInt; static;
  private
    function GetLayer(Index : Integer): TFeedForwardLayer;
    function SquaredDifference(const Input, Output : TDataVector) : Extended;
    function SumOfSquaredDifferences(const Data: array of TDataVector; const ExpectedValues: array of TDataVector) : Extended;
    function DerivateByDegreeOfFreedom(const Data: array of TDataVector; const ExpectedValues: array of TDataVector; Index : Integer; h : Double = 1e-12) : Double;
    function DerivatesByDegreeOfFreedom(const Data: array of TDataVector; const ExpectedValues: array of TDataVector; const h : Double = 1e-12) : TDataVector;

  public
    function DegreeOfFreedomCount : Integer; inline;
    function GetDegreeOfFreedom(Index : Integer) : Double; inline;
    procedure SetDegreeOfFreedom(Index : Integer; AValue : Double); inline;
    property DegreeOfFreedom[Index : Integer] : Double read GetDegreeOfFreedom write SetDegreeOfFreedom;

    function ProcessData(const Data: TDataVector): TDataVector;

    class procedure AsyncStep(const Data: array of TDataVector; const ExpectedValues: array of TDataVector; const Quickness: double; const Method : TLearnProcedure; const threads : PtrUInt = 8); static;
    procedure LearnStep(const Data: array of TDataVector; const ExpectedValues: array of TDataVector; const Quickness: double);
    procedure BackpropagationStep(const Data: array of TDataVector; const ExpectedValues: array of TDataVector; const Quickness: double);                                       
    procedure RandomLearnStep(const Data: array of TDataVector; const ExpectedValues: array of TDataVector; const Quickness: double); overload;
    procedure RandomLearnStep(const Data: array of TDataVector; const ExpectedValues: array of TDataVector; const Quickness: double; const Proportion : Double); overload;
    procedure LearnByMinimizeError(const Data: array of TDataVector; const ExpectedValues: array of TDataVector; const Quickness: double); //do not use with async

    function CheckNetwork(const Data: array of TDataVector; const ExpectedValues: array of TDataVector; const SumFunction: TSumFunction) : Double;
    function ConfusionMatrix(const Data: array of TDataVector; const ExpectedValues: array of TDataVector) : TConfusionMatrix;
    function GetDataDerivate(const Data: array of TDataVector; const h : Double = 1e-6) : TInputDerivate;
    function GetWageHistogram : TDataVector;

    function ExtractLayers(const First, Last : Integer) : TFeedForwardNet;
    property Layers[Index : Integer] : TFeedForwardLayer read GetLayer;
    function GetLayerCount : Integer;

    procedure RandomAboutOne;
    procedure RandomAll;
    procedure RandomAllAddition(const mean, stddev: double);
    procedure RandomAllMultiplication(const mean, stddev: double);
    procedure SaveToStream(Stream: TStream);
    procedure LoadFromStream(Stream: TStream);
    procedure SaveToFile(const FileName: ansistring);
    procedure LoadFromFile(const FileName: ansistring);
    constructor Create; overload;
    constructor Create(Stream: TStream); overload;
    constructor Create(const Sizes: array of integer); overload;
    destructor Destroy; override;

    function GetHashCode: PtrInt; override;
    function Equals(Obj: TObject): boolean; override;
  end;

  {$If FPC_FULLVERSION >= 30200}
  generic function ToDataVector<T>(const tab: array of T; const range: T): TDataVector; overload;
  generic function ToDataVector<T>(const Ptr: Pointer; const Len : PtrUInt; const range: T): TDataVector; overload;
  {$EndIf}

function SumOfSquaresOfDifferences(const a, b: TDataVector): double;
function SumOfAbsoluteDifferences(const a, b: TDataVector): double;
function SumOfRoundedDifferences(const a, b: TDataVector): double;
function SumOfTriplePointsDifferences(const a, b: TDataVector): double;
function SameMaxIndex(const a, b: TDataVector): double;

function MaxIndex(const x : TDataVector) : Integer;    
function Shuf(const Range : Integer) : specialize TArray<Integer>; 
function sign2(x : Double) : Integer; inline;
function NormalizeData(const Input : TDataVector) : TDataVector;  
function NormalizeData01(const Input: TDataVector): TDataVector;
function SumOfAbsolutes(const Input : TDataVector) : Double;

function ConfusionMatrixToHtml(const ConfusionMatrix : TConfusionMatrix) : AnsiString;
procedure StringToFile(const text, FileName : AnsiString);

operator + (const a, b : TDataVector) : TDataVector; inline;
operator - (const a, b : TDataVector) : TDataVector; inline;
operator * (const a, b : TDataVector) : TDataVector; inline;
operator * (const a : Double; const b : TDataVector) : TDataVector; inline;
operator * (const a : TDataVector; const b : Double) : TDataVector; inline;
operator / (const a : TDataVector; const b : Double) : TDataVector; inline;
function ScalarProduct(const a, b: TDataVector): Double; inline;

operator := (const inputDerivate : TInputDerivate) : AnsiString;

implementation

uses
  Math, crc;

function CubeRoot(x : Double) : Double; inline;
begin
  Exit(Sign(x) * Power(abs(x), 1/3));
end;

operator + (const a, b : TDataVector) : TDataVector;
var
  i, c : Integer;
begin
  Assert(Length(a) = Length(b));
  c := Length(a);
  Result := [];
  SetLength(Result, c);
  for i := 0 to c-1 do
      Result[i] := a[i] + b[i];
end;

operator - (const a, b : TDataVector) : TDataVector;
var
  i, c : Integer;
begin
  Assert(Length(a) = Length(b));
  c := Length(a);
  Result := [];
  SetLength(Result, c);
  for i := 0 to c-1 do
      Result[i] := a[i] - b[i];
end;

operator * (const a, b: TDataVector): TDataVector;
var
  i, c : Integer;
begin
  Assert(Length(a) = Length(b));
  c := Length(a);
  Result := [];
  SetLength(Result, c);
  for i := 0 to c-1 do
      Result[i] := a[i] * b[i];
end;

operator * (const a : Double; const b : TDataVector) : TDataVector;   
begin
  Exit(b*a);
end;

operator * (const a : TDataVector; const b : Double) : TDataVector;   
var
  i, c : Integer;
begin
  c := Length(a);
  Result := [];
  SetLength(Result, c);
  for i := 0 to c-1 do
      Result[i] := a[i] * b;
end;

operator / (const a : TDataVector; const b : Double) : TDataVector;  
begin
  Exit(a*(1/b));
end;

function ScalarProduct(const a, b: TDataVector): Double;
var
  i, c : Integer;
begin
  Result := 0;
  Assert(Length(a) = Length(b));
  c := Length(a);
  for i := 0 to c-1 do
      Result += a[i]*b[i];
end;

operator:=(const inputDerivate: TInputDerivate): AnsiString;
begin
  with inputDerivate do
       Exit(Format('Normal:   max=%.4f, min=%.4f, mean=%.4f, stddev=%.4f'#13#10+
                   'Squared:  max=%.4f, min=%.4f, mean=%.4f, stddev=%.4f'#13#10+
                   'Absolute: max=%.4f, min=%.4f, mean=%.4f, stddev=%.4f'#13#10,
                [max, min, mean, stdDev,
                squaredMax, squaredMin, squaredMean, squaredStdDev,
                absoluteMax, absoluteMin, absoluteMean, absoluteStdDev]));
end;

{$If FPC_FULLVERSION >= 30200}
generic function ToDataVector<T>(const tab: array of T; const range: T): TDataVector;
var
  i, c: PtrUInt;
begin
  Result := [];
  c := Length(tab);
  if c > 0 then
  begin
    SetLength(Result, c);
    for i := 0 to c - 1 do
      Result[i] := tab[i] / range;
  end;
end;

generic function ToDataVector<T>(const Ptr: Pointer; const Len : PtrUInt; const range: T): TDataVector;
type
  TypePtr = ^T;
var
  i : PtrUInt;
begin
  Result := [];
  if len > 0 then
  begin
    SetLength(Result, Len);
    for i := 0 to len - 1 do
      Result[i] := TypePtr(Ptr)[i] / range;
  end;
end;
{$EndIf}

function Shuf(const Range : Integer) : specialize TArray<Integer>;
var
  i, p : Integer;
begin
   Result := [];
   SetLength(Result, Range);
   p := Random(Range);
   for i := 1 to Range-1 do
   begin
     p := (p + Random(Range)) mod Range;
     while Result[p] <> 0 do
     begin
       Inc(p);
       if p >= Range then
          p := 0;
     end;
     Result[p] := i;
   end;
end;

function IsACorrectNumber(const t : array of Double) : Boolean;
var
  d : Double;
begin
  for d in t do
    if IsNan(d) or IsInfinite(d) or IsInfinite(-d) then
       Exit(False);
  Exit(True);
end;

function IfThen(const Condition : Boolean; const IfTrue : AnsiString; const IfFalse : AnsiString = '') : AnsiString; inline; overload;
begin
  If Condition then
     Exit(IfTrue);
  Exit(IfFalse)
end;

function sign2(x : Double) : Integer; inline;
begin
  if x >= 0 then
    Exit(1);
  Exit(-1);
end;

function NormalizeData(const Input: TDataVector): TDataVector;
var
  i, c : Integer;
  s : Double;
begin
  c := Length(Input);
  Result := [];
  SetLength(Result, c);
  s := Sqrt(SumOfSquares(Input));
  for i := 0 to c-1 do
      Result[i] := Input[i] / s;
end;

function NormalizeData01(const Input: TDataVector): TDataVector;
var
  i, c : Integer;
  minV, maxV, d : Double;
begin
    c := Length(Input);
    minV := MinValue(Input);
    maxV := MaxValue(Input);
    if minV <> maxV then
        d := 1/(maxV-minV)
    else
        d := 1;
    Result := [];
    SetLength(Result, c);
    for i := 0 to c-1 do
        Result[i] := (Input[i] - minV) * d;
end;

function SumOfAbsolutes(const Input: TDataVector): Double;
var
  d : Double;
begin
  Result := 0;
  for d in Input do
      Result += abs(d);
end;

function SumOfSquaresOfDifferences(const a, b: TDataVector): double;
var
  i: integer;
begin
  Result := 0;
  for i := 0 to Length(a) - 1 do
    Result += Sqr(a[i] - b[i]);
  Result := Sqrt(Result);
end;

function SumOfAbsoluteDifferences(const a, b: TDataVector): double;
var
  i: integer;
begin
  Result := 0;
  for i := 0 to Length(a) - 1 do
    Result += abs(a[i] - b[i]);
end;

function SumOfRoundedDifferences(const a, b: TDataVector): double;
var
  i: integer;
begin
  Result := 0;
  for i := 0 to Length(a) - 1 do
    Result += abs(round(a[i]) - round(b[i]));
end;

function SumOfTriplePointsDifferences(const a, b: TDataVector): double;
var
  i: integer;
begin
  Result := 0;
  for i := 0 to Length(a) - 1 do
    Result += ifthen(abs(a[i] - b[i]) < 1 / 3, 0, 1);
end;

function MaxIndex(const x : TDataVector) : Integer;
var
  i: integer;
begin
  Result := 0;
  for i := 1 to length(x) - 1 do
    if x[i] > x[Result] then
      Result := i;
end;

function ConfusionMatrixToHtml(const ConfusionMatrix: TConfusionMatrix): AnsiString;
var
  i, j, c : Integer;
  ts : TStringList;
begin
  c := Length(ConfusionMatrix);
  {$IfDef ASSERTIONS}
  for i := 0 to c-1 do
      Assert(Length(ConfusionMatrix) = c);
  {$EndIf}
  ts := TStringList.Create;
  ts.Add('<table style="border:none; background:transparent; text-align:center;" align="center">');
  ts.Add(#9'<tbody>');
  ts.Add(#9#9'<tr>');
  ts.Add(#9#9#9'<td rowspan="2" style="border:none;"></td>');
  ts.Add(#9#9#9'<td style="border:none;width:0.875em"></td>');
  ts.Add(#9#9#9'<td colspan="'+IntToStr(c)+'" style="background:#bbeeee;"><b>Correct condition</b></td>');
  ts.Add(#9#9'</tr>');
  ts.Add(#9#9'<tr>');
  ts.Add(#9#9#9'<td style="background:#eeeeee;"></td>');
  for i := 0 to c -2 do
    ts.Add(#9#9#9'<td style="background:#ccffff;"><b> '+IntToStr(i)+' </b></td>');
  ts.Add(#9#9#9'<td style="background:#ccffff;"><b> Sum </b></td>');
  ts.Add(#9#9'</tr>');
  for i := 0 to c -1 do
  begin
    ts.Add(#9#9'<tr>');
    if i = 0 then
        ts.Add(#9#9#9'<td rowspan="'+IntToStr(c)+'" style="line-height:99%;vertical-align:middle;padding:.4em .4em .2em;background-position:50% .4em !important;min-width:0.875em;max-width:0.875em;width:0.875em;overflow:hidden;background:#eeeebb;"><div style="-webkit-writing-mode: vertical-rl; -o-writing-mode: vertical-rl; -ms-writing-mode: tb-rl;writing-mode: tb-rl; writing-mode: vertical-rl; layout-flow: vertical-ideographic;display: inline-block; -ms-transform: rotate(180deg); -webkit-transform: rotate(180deg); transform: rotate(180deg);;-ms-transform: none ;padding-left:1px;text-align:center;"><b>Actual condition</b></div></td>');
    if i < c-1 then
        ts.Add(#9#9#9'<td style="background:#ffffcc;"><b> '+IntToStr(i)+' </b></td>')
        else
        ts.Add(#9#9#9'<td style="background:#ffffcc;"><b> Sum </b></td>');
    for j := 0 to c -1 do
        if ConfusionMatrix[i, j].Count = 0 then
           ts.Add(#9#9#9'<td style="background:'+ IfThen(j=i,'#ccffcc', '#ffdddd') + ';"> </td>')
        else
           ts.Add(#9#9#9'<td style="background:'+ IfThen(j=i,'#ccffcc', '#ffdddd') + ';"> '+IfThen((j=c-1) or (i=c-1), '<b>')+IntToStr(ConfusionMatrix[i, j].Count)+' <br> '+FormatFloat('0.0000', ConfusionMatrix[i, j].Partial)+IfThen((j=c-1) or (i=c-1), '</b>')+' </td>');
    ts.Add(#9#9'</tr>');
  end;
  ts.Add(#9'</tbody>');
  ts.Add('</table>');

  Result := ts.Text;
  ts.Free;
end;

procedure StringToFile(const text, FileName: AnsiString);
var
  FS : TFileStream;
begin
  FS := TFileStream.Create(FileName, fmCreate);
  FS.WriteBuffer(text[1], Length(text));
  FS.Free;
end;

function SameMaxIndex(const a, b: TDataVector): double;
begin
  if MaxIndex(a) = MaxIndex(b) then
    Exit(0)
  else
    Exit(Length(a));
end;

{ TFeedForwardNet }

procedure TFeedForwardNet.DisposeLayers;
var
  i: integer;
begin
  for i := 0 to Length(fLayers) - 1 do
    if (fLayers[i] <> nil) and Assigned(fLayers[i]) then
      FreeAndNil(fLayers[i]);
  fLayers := [];
end;

class function TFeedForwardNet.AsyncLearn(rec: Pointer): PtrInt;
begin
  with PLearnRecord(rec)^ do
       method(Data, ExpectedValues, Quickness);
  Exit(0);
end;

function TFeedForwardNet.GetLayer(Index : Integer): TFeedForwardLayer;
begin
  Assert(Index < Length(fLayers));
  Assert(Index >= 0);
  Exit(fLayers[Index]);
end;

function TFeedForwardNet.SquaredDifference(const Input, Output: TDataVector): Extended;
var
  R : TDataVector;
  i : Integer;
  s : Extended;
begin
  R := ProcessData(Input);
  Assert(Length(R) = Length(Output));
  s := 0;
  for i := 0 to Length(R)-1 do
      s += Sqr(R[i] - Output[i]);// * Sqr((0.5-Output[i]) / (0.5-R[i]));
  Exit(s);
end;

function TFeedForwardNet.SumOfSquaredDifferences(const Data: array of TDataVector; const ExpectedValues: array of TDataVector): Extended;
var
  i : Integer;
  s : array of Extended;
begin
  Assert(Length(Data) = Length(ExpectedValues));
  s := [];
  SetLength(s, Length(Data));
  for i := 0 to Length(Data) -1 do
      s[i] := Sqr(SquaredDifference(Data[i], ExpectedValues[i]));
  Exit(Sum(s)**(1/4));
end;

function TFeedForwardNet.DerivateByDegreeOfFreedom(const Data: array of TDataVector; const ExpectedValues: array of TDataVector; Index: Integer; h: Double): Double;
var
  OrginalValue : Double;
  a, b, c, d1, d2, d3 : Extended;
begin
  Assert(Index < DegreeOfFreedomCount);
  OrginalValue:=DegreeOfFreedom[Index];
  b := SumOfSquaredDifferences(Data, ExpectedValues);
  DegreeOfFreedom[Index] := OrginalValue + h;
  c := SumOfSquaredDifferences(Data, ExpectedValues);
  DegreeOfFreedom[Index] := OrginalValue - h;
  a := SumOfSquaredDifferences(Data, ExpectedValues);
  DegreeOfFreedom[Index] := OrginalValue;

  d1 := (b-a)/h;
  d2 := (c-b)/h;
  d3 := (c-a)/(2*h);


  if (b > a) and (b > c) then
  begin
    if a < c then
       exit(h);
    Exit(-h);
  end;

  if abs(d1) > abs(d2) then
     d2 := d1;
  if abs(d2) > abs(d3) then
     d3 := d2;
  Exit(d3);
end;

function TFeedForwardNet.DerivatesByDegreeOfFreedom( const Data: array of TDataVector; const ExpectedValues: array of TDataVector; const h: Double): TDataVector;
var
  i, c : Integer;
begin
  c := DegreeOfFreedomCount;
  Result := [];
  SetLength(Result, c);
  for i := 0 to c-1 do
      Result[i] := DerivateByDegreeOfFreedom(Data, ExpectedValues, i, h);
end;

function TFeedForwardNet.DegreeOfFreedomCount: Integer;
var
  i : Integer;
begin
  Result := 0;
  for i := 0 to Length(fLayers)-1 do
      Inc(Result, fLayers[i].DegreeOfFreedomCount);
end;

function TFeedForwardNet.GetDegreeOfFreedom(Index: Integer): Double;
var
  i : Integer;
begin
  for i := 0 to Length(fLayers)-1 do
      If Index < fLayers[i].DegreeOfFreedomCount then
         Exit(fLayers[i].DegreeOfFreedom[Index])
      else
         Dec(Index, fLayers[i].DegreeOfFreedomCount);
  Exit(0);
end;

procedure TFeedForwardNet.SetDegreeOfFreedom(Index: Integer; AValue: Double);
var
  i : Integer;
begin
  for i := 0 to Length(fLayers)-1 do
      If Index < fLayers[i].DegreeOfFreedomCount then
      begin
         fLayers[i].DegreeOfFreedom[Index] := AValue;
         Exit;
      end
      else
         Dec(Index, fLayers[i].DegreeOfFreedomCount);
end;

function TFeedForwardNet.ProcessData(const Data: TDataVector): TDataVector;
var
  i: integer;
begin
  assert(Length(fLayers) > 0);
  Result := fLayers[0].ProcessData(Data);
  for i := 1 to Length(fLayers) - 1 do
    Result := fLayers[i].ProcessData(Result);
end;

class procedure TFeedForwardNet.AsyncStep(const Data: array of TDataVector; const ExpectedValues: array of TDataVector; const Quickness: double; const Method: TLearnProcedure; const threads: PtrUInt);
var
  Records : array of TLearnRecord;
  ThreadsIds : array of TThreadID;
  i, l, c, j, a, b, k : Integer;
begin
  Records := [];
  ThreadsIds := [];
  SetLength(Records, threads);
  SetLength(ThreadsIds, threads);
  l := Length(Data);
  Assert(l = Length(ExpectedValues));
  for i := 0 to Threads-1 do
  begin
    Records[i].method:=Method;
    Records[i].Quickness:=Quickness;
    a := i * l div Threads;
    b := (i+1) * l div Threads -1;
    c := b-a+1;
    SetLength(Records[i].Data, c);
    SetLength(Records[i].ExpectedValues, c);
    k := 0;
    for j := a to b do
    begin
      Records[i].Data[k] := Data[j];
      Records[i].ExpectedValues[k] := ExpectedValues[j];
      Inc(k);
    end;
  end;
  for i := 0 to threads-1 do
      ThreadsIds[i] := BeginThread(@AsyncLearn, @Records[i]);

  for i := 0 to threads-1 do
     WaitForThreadTerminate(ThreadsIds[i], -1);
end;

procedure TFeedForwardNet.LearnStep(const Data: array of TDataVector; const ExpectedValues: array of TDataVector; const Quickness: double);
var
  i: integer;
begin
  assert(Length(fLayers) > 0);
  assert(Length(Data) = length(ExpectedValues));
  if Length(Data) = 0 then
    Exit;
  for i in Shuf(Length(Data)) do
    fLayers[0].CorrectSample(fLayers, 0, Data[i], ExpectedValues[i], Quickness);
end;

procedure TFeedForwardNet.BackpropagationStep(const Data: array of TDataVector; const ExpectedValues: array of TDataVector; const Quickness: double);
var
  i: integer;
begin
  assert(Length(fLayers) > 0);
  assert(Length(Data) = length(ExpectedValues));
  if Length(Data) = 0 then
    Exit;
  for i in Shuf(Length(Data)) do
    fLayers[0].Backpropagation(fLayers, 0, Data[i], ExpectedValues[i], Quickness);
end;

procedure TFeedForwardNet.RandomLearnStep(const Data: array of TDataVector; const ExpectedValues: array of TDataVector; const Quickness: double);
begin
  RandomLearnStep(Data, ExpectedValues, Quickness, 0.5);
end;

procedure TFeedForwardNet.RandomLearnStep(const Data: array of TDataVector; const ExpectedValues: array of TDataVector; const Quickness: double; const Proportion: Double);
var
  i: integer;
begin
  assert(Length(fLayers) > 0);
  assert(Length(Data) = length(ExpectedValues));
  if Length(Data) = 0 then
    Exit;
  for i in Shuf(Length(Data)) do               
    if random < Proportion then
      fLayers[0].CorrectSample(fLayers, 0, Data[i], ExpectedValues[i], Quickness)
    else
      fLayers[0].Backpropagation(fLayers, 0, Data[i], ExpectedValues[i], Quickness);
end;

procedure TFeedForwardNet.LearnByMinimizeError(const Data: array of TDataVector; const ExpectedValues: array of TDataVector; const Quickness: double);
var
  Vector, OriginalValues : TDataVector;
  s, sn, step : Double;
  i, c : Integer;
begin
  Vector := DerivatesByDegreeOfFreedom(Data, ExpectedValues, abs(RandG(Quickness*0.1, Quickness*0.1)));
  c := DegreeOfFreedomCount;
  Assert(Length(Vector) = c);
  OriginalValues := [];
  SetLength(OriginalValues, c);
  for i := 0 to c-1 do
      OriginalValues[i] := DegreeOfFreedom[i];
  s := SumOfSquaredDifferences(Data, ExpectedValues);
  step := Quickness;

  repeat
    for i := 0 to c-1 do
      DegreeOfFreedom[i] := OriginalValues[i] - Vector[i] * step;
    sn := SumOfSquaredDifferences(Data, ExpectedValues);
    if sn <= s then
    begin
      for i := 0 to c-1 do
          OriginalValues[i] := OriginalValues[i] - Vector[i] * step;
      if sn < s then
      begin
        step *= Sqr(2/(sqrt(5)-1));
        s := sn;
      end;
    end;
    step *= (sqrt(5)-1)/2;
  until step < 1e-9;
  for i := 0 to c-1 do
    DegreeOfFreedom[i] := OriginalValues[i]
end;

function TFeedForwardNet.CheckNetwork(const Data: array of TDataVector; const ExpectedValues: array of TDataVector; const SumFunction: TSumFunction): Double;
var
  i, j: integer;
  s : Double;
begin
  assert(Length(fLayers) > 0);
  assert(Length(Data) = length(ExpectedValues));
  if Length(Data) = 0 then
    Exit(0);
  Result := 0;
  for i := 0 to Length(Data) - 1 do
    Result += SumFunction(ExpectedValues[i], ProcessData(Data[i])) / Length(ExpectedValues[i]);

  s := 0;
  for i := 0 to Length(ExpectedValues) - 1 do
      for j := 0 to Length(ExpectedValues[i])-1 do
          s += ExpectedValues[i, j];
  Result /= s;
  Result := 1 - Result;
end;

function TFeedForwardNet.ConfusionMatrix(const Data: array of TDataVector; const ExpectedValues: array of TDataVector): TConfusionMatrix;
var
  i, c, a, b, ld : integer;
begin
  assert(Length(fLayers) > 0);
  assert(Length(Data) > 0);
  assert(Length(Data) = length(ExpectedValues));
  c := Length(ExpectedValues[0]);
  ld := Length(Data);
  if ld = 0 then
    Exit([]);
  Result := [];
  SetLength(Result, c+1, c+1);
  for i := 0 to ld - 1 do
  begin
    Assert(Length(ExpectedValues[i]) = c);
    a := MaxIndex(ProcessData(Data[i]));
    b := MaxIndex(ExpectedValues[i]);
    Inc(Result[a, b].Count);
  end;

  for a := 0 to c-1 do
  begin
      for b := 0 to c-1 do
      begin
        Result[c, b].Count+=Result[a, b].Count;
        Result[a, c].Count+=Result[a, b].Count;
      end;
      Result[c, c].Count+=Result[a, a].Count;
  end;

  for a := 0 to c do
      for b := 0 to c do
          Result[a, b].Partial:=Result[a, b].Count/ld;
end;

function TFeedForwardNet.GetDataDerivate(const Data: array of TDataVector;
  const h: Double): TInputDerivate;
var
  v1, v2, r : TDataVector;
  i, j, k, c, dataLength, dataItemLength : Integer;
  Derivates, SquaredDerivates, AbsoluteDerivates : array of Extended;
begin
  dataLength := Length(Data);
  dataItemLength := Length(Data[0]);
  c := dataLength * dataItemLength;
  Derivates := [];
  SquaredDerivates := [];
  AbsoluteDerivates := [];
  SetLength(Derivates, c);
  SetLength(SquaredDerivates, c);
  SetLength(AbsoluteDerivates, c);
  k := 0;
  for i := 0 to Length(Data)-1 do
  begin
    assert(dataItemLength = Length(Data[i]));
    v1 := Copy(Data[i], 0, dataItemLength);
    v2 := Copy(Data[i], 0, dataItemLength);
    for j := 0 to dataItemLength-1 do
    begin
        v1[j] := Data[i][j]+h;
        v2[j] := Data[i][j]-h;
        r := (ProcessData(v1) - ProcessData(v2)) / (2*h);
        Derivates[k] := Sum(r);
        SquaredDerivates[k] := SumOfSquares(r);
        AbsoluteDerivates[k] := SumOfAbsolutes(r);
        Inc(k);
    end;
  end;
  Result.max:=MaxValue(Derivates);
  Result.squaredMax:=MaxValue(SquaredDerivates);
  Result.absoluteMax:=MaxValue(AbsoluteDerivates);
  Result.min:=MinValue(Derivates);
  Result.squaredMin:=MinValue(SquaredDerivates);
  Result.absoluteMin:=MinValue(AbsoluteDerivates);
  MeanAndStdDev(Derivates, Result.mean, Result.stdDev);
  MeanAndStdDev(SquaredDerivates, Result.squaredMean, Result.squaredStdDev);
  MeanAndStdDev(AbsoluteDerivates, Result.absoluteMean, Result.absoluteStdDev);
end;


function InsertCombSortGetGap(const n : Integer) : Double; inline;
begin
   case n of
        2..1000: Exit(0.2);
        1001..9000000: Exit(0.3);
        else Exit(9/23);
   end;
end;

procedure InsertCombSortF(var tab : array of Double; const n : Integer);
var
    gap, i, j : integer;
    x : Double;
    d : Double;
begin
    d := InsertCombSortGetGap(n);
    gap := round(d**round(logn(d, n)));
    while gap>1 do
    begin
        gap := round(gap*d);
        for i := gap to n-1 do
        begin
            if (tab[i] < tab[i-gap]) then
            begin
                x := tab[i];
                tab[i] := tab[i-gap];
                j := i-gap;
                while ((j >= gap) and (x < tab[j-gap])) do
                begin
                    tab[j] := tab[j-gap];
                    dec(j, gap);
                end;
                tab[j] := x;
            end;
        end;
    end;
end;

function TFeedForwardNet.GetWageHistogram: TDataVector;
var
  i : Integer;
begin
  Result := [];
  SetLength(Result, DegreeOfFreedomCount);
  for i := 0 to Length(Result)-1 do
      Result[i] := GetDegreeOfFreedom(i);
  InsertCombSortF(Result, Length(Result));
end;

function TFeedForwardNet.ExtractLayers(const First, Last: Integer): TFeedForwardNet;
var
  i : Integer;
  MS : TMemoryStream;
  Dimensions : array of Integer;
begin
  Assert(First>=0);
  Assert(First<=Last);
  Assert(Last<Length(fLayers));

  Dimensions := [];
  SetLength(Dimensions, Last-First+2);
  Dimensions[0] := fLayers[First].fInputCount;
  for i := First to Last do
      Dimensions[i-First+1] := fLayers[i].fNeuronCount;
  Result := TFeedForwardNet.Create(Dimensions);
  MS := TMemoryStream.Create;
  for i := First to Last do
  begin
    fLayers[i].SaveToStream(MS);
    MS.Position:=0;
    Result.fLayers[i-First].LoadFromStream(MS);
    MS.Clear;
  end;
  MS.Free;

  {$IfDef ASSERTIONS}
  for i := First to Last-1 do
      Assert(Result.fLayers[i-First].Equals(fLayers[i]));
  {$EndIf}
end;

function TFeedForwardNet.GetLayerCount: Integer;
begin
  Exit(Length(fLayers));
end;

procedure TFeedForwardNet.RandomAboutOne;
const
  maxIt = 1000;
var
  TestData, ExpectedOutput : TDataVector;
  i, k, it : Integer;
  s : Double;
begin
  RandomAll;
  TestData := [];
  SetLength(TestData, fLayers[0].fInputCount);
  ExpectedOutput := [];                       
  SetLength(ExpectedOutput, fLayers[High(fLayers)].fNeuronCount);
  for k := 0 to 15 do
  begin                                                          
    it := 0;
    for i := 0 to Length(ExpectedOutput)-1 do
        ExpectedOutput[i] := Power(abs(RandG(1, 1)), 1/3);
    ExpectedOutput := NormalizeData(ExpectedOutput);
    repeat
       Inc(it);
       s := Sum(ProcessData(TestData));
       LearnStep(TestData, ExpectedOutput, abs(RandG(0, 0.1)));
    until InRange(s, 0.9, 1.1) or (it > maxIt);
  end;
end;

procedure TFeedForwardNet.RandomAll;
var
  l: TFeedForwardLayer;
begin
  for l in fLayers do
    l.RandomAll;
end;

procedure TFeedForwardNet.RandomAllAddition(const mean, stddev: double);
var
  l: TFeedForwardLayer;
begin
  for l in fLayers do
    l.RandomAllAddition(mean, stddev);
end;

procedure TFeedForwardNet.RandomAllMultiplication(const mean, stddev: double);
var
  l: TFeedForwardLayer;
begin
  for l in fLayers do
    l.RandomAllMultiplication(mean, stddev);
end;

procedure TFeedForwardNet.SaveToStream(Stream: TStream);
var
  i: integer;
begin
  Stream.WriteDWord(Length(fLayers));
  for i := 0 to Length(fLayers) - 1 do
    fLayers[i].SaveToStream(Stream);
end;

procedure TFeedForwardNet.LoadFromStream(Stream: TStream);
var
  i, c, oldC: integer;
begin
  c := Stream.ReadDWord;
  oldC := Length(fLayers);

  for i := c to oldC-1 do
    if (fLayers[i] <> nil) and Assigned(fLayers[i]) then
      FreeAndNil(fLayers[i]);
  
  SetLength(fLayers, c);

  for i := 0 to c - 1 do
    if i < oldC then
      fLayers[i].LoadFromStream(Stream)
    else
      fLayers[i] := TFeedForwardLayer.Create(Stream);
end;

procedure TFeedForwardNet.SaveToFile(const FileName: ansistring);
var
  FS: TFileStream;
begin
  FS := TFileStream.Create(FileName, fmCreate);
  SaveToStream(FS);
  FS.Free;
end;

procedure TFeedForwardNet.LoadFromFile(const FileName: ansistring);
var
  FS: TFileStream;
begin
  FS := TFileStream.Create(FileName, fmOpenRead);
  LoadFromStream(FS);
  FS.Free;
end;

constructor TFeedForwardNet.Create;
begin
  fLayers := [];
end;

constructor TFeedForwardNet.Create(Stream: TStream);
begin
  Create;
  LoadFromStream(Stream);
end;

constructor TFeedForwardNet.Create(const Sizes: array of integer);
var
  i, c: integer;
begin
  Create;
  c := Length(Sizes);
  SetLength(fLayers, c - 1);
  for i := 0 to c - 2 do
    fLayers[i] := TFeedForwardLayer.Create(Sizes[i], Sizes[i + 1]);
end;

destructor TFeedForwardNet.Destroy;
begin
  DisposeLayers;
  inherited Destroy;
end;

function TFeedForwardNet.GetHashCode: PtrInt;
var
  i: integer;
  q, h: QWord;
begin
  h := crc64(0, nil, 0);
  for i := 0 to Length(fLayers) - 1 do
  begin
    q := QWord(fLayers[i].GetHashCode());
    h := crc64(h, @Q, sizeOf(q));
  end;
  Exit(PtrInt(h));
end;

function TFeedForwardNet.Equals(Obj: TObject): boolean;
var
  i: integer;
  Another: TFeedForwardNet;
begin
  if obj = self then Exit(True);
  if not (Obj is TFeedForwardNet) then Exit(False);
  Another := Obj as TFeedForwardNet;
  if Length(fLayers) <> Length(Another.fLayers) then Exit(False);
  for i := 0 to Length(fLayers) - 1 do
    if not fLayers[i].Equals(Another.fLayers[i]) then Exit(False);
  Exit(True);
end;

{ TFeedForwardLayer }

{$IfDef SIGMOID_APPROXIMATION}
                                                          
const
 Weights : array of Double =
    (1.0424094510441026528724250965751707553863525390625,
    -1.6172268808167391540564494789578020572662353515625,
    1.48259512044627950189124021562747657299041748046875,
    -0.40678109023665520727064404127304442226886749267578125,
    0.4992991982961161312459807959385216236114501953125);

class function TFeedForwardLayer.ActivateFunction(x: double): double; inline;
var
  dx, adx : Double;
begin
  dx := x + x*x*x;
  adx := abs(dx);
  Result := (Weights[0]  / (adx+2)
            + Weights[1] / (adx+4)
            + Weights[2] / (adx+8)
            + Weights[3] / (adx+16)) * dx
            + Weights[4];
end;     

class function TFeedForwardLayer.DerivateOfActivateFunction(x: double): double; inline;
var
  k, ak, dk, m1, m2, m3, m4 : Double;
begin
  dk := 1+3*x*x;
  k := x+x*x*x;
  ak := abs(k);
  m1 := 2+ak;
  m2 := 4+ak;
  m3 := 8+ak;
  m4 := 16+ak;
  Result :=
   + Weights[0]*2*dk/(m1*m1)
   + Weights[1]*4*dk/(m2*m2)
   + Weights[2]*8*dk/(m3*m3)
   + Weights[3]*16*dk/(m4*m4);
end;

{$else}

class function TFeedForwardLayer.ActivateFunction(x: double): double; inline;
begin
  Exit(1 / (1 + exp(-x)));
end;

class function TFeedForwardLayer.DerivateOfActivateFunction(x: double): double; inline;
begin
  Result :=  1 / (1 + exp(-x));
  Result := Result*(1-Result);
end;

{$endif}

function TFeedForwardLayer.DegreeOfFreedomCount: Integer;
begin
  Exit(fNeuronCount*Succ(fInputCount));
end;

function TFeedForwardLayer.GetDegreeOfFreedom(Index: Integer): Double;
var
  i, j : Word;
begin
  DivMod(Index, fNeuronCount, i{%H-}, j{%H-});
  if i < fInputCount then
     Exit(fWeights[i, j]);
  Exit(fBias[j]);
end;

procedure TFeedForwardLayer.SetDegreeOfFreedom(Index: Integer; AValue: Double);
var
  i, j : Word;
begin
  DivMod(Index, fNeuronCount, i{%H-}, j{%H-});
  if i < fInputCount then
     fWeights[i, j] := AValue
  else
     fBias[j] := AValue;
end;

function TFeedForwardLayer.RawWeightsMultiplication(const Data: TDataVector): TDataVector;
var
  i, j: integer;
  v: double;
begin
  Assert(Length(Data) = fInputCount);
  Result := [];
  SetLength(Result, fNeuronCount);  
  fLocker.Beginread;
  try
    for i := 0 to fNeuronCount - 1 do
    begin
      v := 0;
      for j := 0 to fInputCount - 1 do
        v += Data[j] * fWeights[j, i];
      Result[i] := v + fBias[i];
    end;
  finally
    fLocker.Endread;
  end;
end;

function TFeedForwardLayer.VectorActivateFunction(const Data: TDataVector): TDataVector;
var
  i : Integer;
begin             
  Assert(Length(Data) = fNeuronCount);
  Result := [];
  SetLength(Result, fNeuronCount);
  for i := 0 to fNeuronCount-1 do
      Result[i] := ActivateFunction(Data[i]);
end;

function TFeedForwardLayer.VectorDerivateOfActivateFunction(const Data: TDataVector): TDataVector;
var
  i : Integer;
begin
  Assert(Length(Data) = fNeuronCount);
  Result := [];
  SetLength(Result, fNeuronCount);
  for i := 0 to fNeuronCount-1 do
      Result[i] := DerivateOfActivateFunction(Data[i]);
end;

function TFeedForwardLayer.ProcessData(const Data: TDataVector): TDataVector;
begin
  Exit(VectorActivateFunction(RawWeightsMultiplication(Data)));
end;

function TFeedForwardLayer.DataToDerivates(const Data: TDataVector): TDataVector;
begin
  Exit(VectorDerivateOfActivateFunction(RawWeightsMultiplication(Data)));
end;

procedure TFeedForwardLayer.CorrectSample(const Data, ExpectedOutput: TDataVector; const Quickness: double);
begin
  CorrectSample([self], 0, Data, ExpectedOutput, Quickness);
end;

function TFeedForwardLayer.CorrectSample(const Layers: array of TFeedForwardLayer; const Index: integer; const Data, ExpectedOutput: TDataVector; const Quickness: double): TDataVector;
var
  MyExpectedOutput, Derivates: TDataVector;
  Output: TDataVector;
  i, j : integer;
  difference : double;
begin
  Output := ProcessData(Data);

  if Index < High(Layers) then
    MyExpectedOutput := Layers[Index + 1].CorrectSample(Layers, Index + 1, Output, ExpectedOutput, Quickness)
  else
    MyExpectedOutput := ExpectedOutput;

  Assert(Length(Data) = fInputCount);
  Assert(Length(MyExpectedOutput) = fNeuronCount);

  Derivates := DataToDerivates(Data);

  fLocker.Beginwrite;
  try
    for i := 0 to fNeuronCount - 1 do
    begin
      difference := Derivates[i] * (MyExpectedOutput[i] - Output[i]) * Quickness;
      fBias[i] += difference;
      for j := 0 to fInputCount - 1 do
        fWeights[j, i] += Data[j] * difference;
    end;

    if Random < 0.3 then
      for i := 0 to fNeuronCount - 1 do
      begin
        for j := 0 to fInputCount - 1 do
          if not InRange(fWeights[j, i], -MaxAmplitude, MaxAmplitude) then
            fWeights[j, i] *= CubeRoot(RandG(1, 1));
        if not InRange(fBias[i], -MaxAmplitude, MaxAmplitude) then
          fBias[i] *= CubeRoot(RandG(1, 1));
      end;
  finally
    fLocker.Endwrite;
  end;

  {$IfDef ASSERTIONS}
  for j := 0 to fInputCount - 1 do
      Assert(IsACorrectNumber(fWeights[j]));
  Assert(IsACorrectNumber(fBias));
  {$EndIf}

  if Index = 0 then
    Exit([]);
  Exit(CorrectInput(Data, MyExpectedOutput));
end;

function TFeedForwardLayer.CorrectInput(const CurrentInput, ExpectedOutput: TDataVector): TDataVector;
var
  j : integer;
  RawData, Output : array of double;
  DifferencesAndDerivates: TDataVector;
begin
  Result := [];
  SetLength(Result, fInputCount);
  fLocker.Beginread;
  try
    RawData := RawWeightsMultiplication(CurrentInput);
    Output := VectorActivateFunction(RawData);
    DifferencesAndDerivates := VectorDerivateOfActivateFunction(RawData) * (ExpectedOutput - Output);
    for j := 0 to fInputCount-1 do
      Result[j] := CurrentInput[j] + ScalarProduct(fWeights[j], DifferencesAndDerivates);
  finally
    fLocker.Endread;
  end;
  Assert(IsACorrectNumber(Result));
end;

procedure TFeedForwardLayer.Backpropagation(const Data, ExpectedOutput: TDataVector; const Quickness: double);
begin
  Backpropagation([self], 0, Data, ExpectedOutput, Quickness);
end;

function TFeedForwardLayer.Backpropagation(const Layers: array of TFeedForwardLayer; const Index: integer; const Data, ExpectedOutput: TDataVector;
  const Quickness: double): TDataVector;
var
  Error, Output, Derivates: TDataVector;
  i, j: integer;
  difference, resultLength: double;
begin
  Assert(Length(Data) = fInputCount);
  Output := ProcessData(Data);
  if Index < High(Layers) then
    Error := Layers[Index + 1].Backpropagation(Layers, Index + 1, Output, ExpectedOutput, Quickness)
  else
  begin
    Assert(Length(ExpectedOutput) = fNeuronCount);
    Error := ExpectedOutput - Output;
  end;
                                   
  Assert(Length(Error) = fNeuronCount);

  if Index <> 0 then
  begin
    Result := [];
    SetLength(Result, fInputCount);
    fLocker.Beginread;
    try                             
      for j := 0 to fInputCount - 1 do
        Result[j] := ScalarProduct(Error, fWeights[j]);
    finally
      fLocker.Endread;
    end;
  end;

  resultLength := Sqrt(SumOfSquares(Result)) / fInputCount;
  if resultLength > MaxAmplitude then
     for i := 0 to fInputCount-1 do
         Result[i] /= resultLength;

  Derivates := DataToDerivates(Data);

  fLocker.Beginwrite;
  try
    for i := 0 to fNeuronCount - 1 do
    begin
      difference := Derivates[i] * Error[i] * Quickness;
      fBias[i] += difference;
      for j := 0 to fInputCount - 1 do
        fWeights[j, i] += Data[j] * difference;
    end;
  finally
      fLocker.Endwrite;
  end;

  if Index = 0 then
    Exit([]);
end;

procedure TFeedForwardLayer.RandomAll;
var
  i, j: integer;
begin
  for i := 0 to fNeuronCount - 1 do
  begin
    for j := 0 to fInputCount - 1 do
      fWeights[j, i] += CubeRoot(RandG(0, 1));
    fBias[i] += CubeRoot(RandG(0, 1));
  end;
end;

procedure TFeedForwardLayer.RandomAllAddition(const mean, stddev: double);
var
  i, j: integer;
begin
  for i := 0 to fNeuronCount - 1 do
  begin
    for j := 0 to fInputCount - 1 do
      fWeights[j, i] += CubeRoot(RandG(0, 1));
    fBias[i] += CubeRoot(RandG(mean, stddev));
  end;
end;

procedure TFeedForwardLayer.RandomAllMultiplication(const mean, stddev: double);
var
  i, j: integer;
begin
  for i := 0 to fNeuronCount - 1 do
  begin
    for j := 0 to fInputCount - 1 do
      fWeights[j, i] += CubeRoot(RandG(0, 1));
    fBias[i] *= CubeRoot(RandG(mean, stddev));
  end;
end;

procedure TFeedForwardLayer.SaveToStream(Stream: TStream);
var
  i: integer;
begin
  Stream.WriteDWord(fInputCount);
  Stream.WriteDWord(fNeuronCount);
  for i := 0 to fInputCount - 1 do
    Stream.WriteBuffer(fWeights[i][0], SizeOf(double) * fNeuronCount);
  Stream.WriteBuffer(fBias[0], SizeOf(double) * fNeuronCount);
end;

procedure TFeedForwardLayer.LoadFromStream(Stream: TStream);
var
  i: integer;
begin
  fInputCount := Stream.ReadDWord;
  fNeuronCount := Stream.ReadDWord;
  SetLength(fWeights, fInputCount, fNeuronCount);
  SetLength(fBias, fNeuronCount);
  for i := 0 to fInputCount - 1 do
    Stream.ReadBuffer(fWeights[i][0], SizeOf(double) * fNeuronCount);
  Stream.ReadBuffer(fBias[0], SizeOf(double) * fNeuronCount);
end;

constructor TFeedForwardLayer.Create;
begin
  fInputCount := 0;
  fNeuronCount := 0;
  fWeights := [];
  fBias := [];
  fLocker := TMultiReadExclusiveWriteSynchronizer.Create;
end;

constructor TFeedForwardLayer.Create(Stream: TStream);
begin
  Create;
  LoadFromStream(Stream);
end;

constructor TFeedForwardLayer.Create(const AnInputCount: integer; const ANeuronCount: integer);
begin
  Create;
  fInputCount := AnInputCount;
  fNeuronCount := ANeuronCount;
  SetLength(fWeights, fInputCount, fNeuronCount);
  SetLength(fBias, fNeuronCount);
end;

destructor TFeedForwardLayer.Destroy;
begin
  fLocker.Free;
  inherited Destroy;
end;

function TFeedForwardLayer.GetHashCode: PtrInt;
var
  i: integer;
  h: QWord;
  Name: ansistring;
begin
  Name := ClassName;
  h := crc64(0, nil, 0);
  h := crc64(h, @Name[1], Length(Name));
  h := crc64(h, @fNeuronCount, SizeOf(fNeuronCount));
  h := crc64(h, @fInputCount, SizeOf(fInputCount));
  for i := 0 to fInputCount - 1 do
    h := crc64(h, @fWeights[i][0], fNeuronCount * SizeOf(double));
  h := crc64(h, @fBias[0], fNeuronCount * SizeOf(double));
  Exit(PtrInt(h));
end;

function TFeedForwardLayer.Equals(Obj: TObject): boolean;
var
  Another: TFeedForwardLayer;
  i, j: integer;
begin
  if Obj = self then Exit(True);
  if not (Obj is TFeedForwardLayer) then Exit(False);
  Another := Obj as TFeedForwardLayer;

  if not (fNeuronCount = Another.fNeuronCount) then Exit(False);
  if not (fInputCount = Another.fInputCount) then Exit(False);

  for j := 0 to fNeuronCount - 1 do
  begin
    for i := 0 to fInputCount - 1 do
      if not (fWeights[i][j] = Another.fWeights[i][j]) then
        Exit(False);
    if not (fBias[j] = Another.fBias[j]) then
      Exit(False);
  end;
  Exit(True);
end;

end.

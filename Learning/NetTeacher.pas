unit NetTeacher;

{$Mode ObjFpc}

interface

uses
  Classes, FeedForwardNet;

type
  TGradeFunction = function(const Expected, Current : TDataVector) : Double;

  { TNetwokTeacher }

  TNetwokTeacher = class
  private
    FNetwork : TFeedForwardNet;
    FLearningInput : array of TDataVector; 
    FLearningOutput : array of TDataVector;
    FTestInput : array of TDataVector;
    FTestOutput : array of TDataVector; 
    FQuickness : Double; 
    FGradeFunction : TGradeFunction;
  public
    function Learn : TFeedForwardNet;
    constructor Create(const InputDataSet, OutputDataSet : array of TDataVector;
      TestFraction, Quickness : Double; 
      GradeFunction : TGradeFunction; 
      Network : TFeedForwardNet);
  end;

  { TNetworkLearningThread }

  TNetworkLearningThread = class(TThread)
  private
    FTeacher : TNetwokTeacher;
    FNetwork : TFeedForwardNet;
    FStepCount : PtrUInt;
    FLearningSetGrade : Double;
    FTestSetGrade : Double;
    FQuickness : Double;
    FThreadLabel : AnsiString;
  public
    procedure Execute; override;
    constructor Create(const ThreadLabel : AnsiString; Teacher : TNetwokTeacher; Network : TFeedForwardNet; StepCount : PtrUInt; Quickness : Double);
  end;


procedure LearnStep(net : TFeedForwardNet; 
  const LearningInput, LearningOutput : array of TDataVector;
  Quickness : Double; GradeFunction : TGradeFunction);
function CheckNetwork(Network : TFeedForwardNet; const Expected, Current : array of TDataVector; GradeFunction : TGradeFunction) : Double;

function AlwaysOne(const Expected, Current : TDataVector) : Double;
function MaxIndexHard(const Expected, Current : TDataVector) : Double;
function AverageDistance(const Expected, Current : TDataVector) : Double;
function AverageDifference(const Expected, Current : TDataVector) : Double;

implementation

uses
  SysUtils, Math;

procedure LearnStep(net : TFeedForwardNet; 
  const LearningInput, LearningOutput: array of TDataVector; 
  Quickness: Double; GradeFunction: TGradeFunction);
var
  Outputs : array of TDataVector;
  i : Integer;
  q : Double;
begin
  Assert(Length(LearningInput) = Length(LearningOutput));
  Outputs := [];
  SetLength(Outputs, Length(LearningInput));

  for i := 0 to Length(LearningInput)-1 do
    Outputs[i] := net.ProcessData(LearningInput[i]);
  
  for i in Shuf(Length(LearningInput)) do
  begin
    q := GradeFunction(LearningOutput[i], Outputs[i]) * Quickness;
    if q <> 0 then
      net.LearnStep(LearningInput[i], LearningOutput[i], q);
  end;
end;

function CheckNetwork(Network : TFeedForwardNet; const Expected, Current: array of TDataVector;
 GradeFunction: TGradeFunction): Double;
var
  i : Integer;
begin
  Result := 0;
  for i := 0 to Length(Expected)-1 do
    Result += GradeFunction(Network.ProcessData(Expected[i]), Current[i]);
  Result /= Length(Expected);
end;

function AlwaysOne(const Expected, Current: TDataVector): Double;
begin
  Exit(1.0);
end;

function MaxIndexHard(const Expected, Current: TDataVector): Double;
begin
  Result := specialize IfThen<Double>(MaxIndex(Expected) = MaxIndex(Current), 1, 0);
end;

function AverageDistance(const Expected, Current: TDataVector): Double;
begin
  Result := 1-Sqrt(SumOfSquares(Expected - Current)/Length(Expected));
end;

function SumOfAbs(x : TDataVector) : Double;
var
  d : Double;
begin
  Result := 0;
  for d in x do
    Result += abs(d);
end;

function AverageDifference(const Expected, Current: TDataVector): Double;
begin
  Result := 1-SumOfAbs(Expected - Current)/Length(Expected);
end;

procedure TNetworkLearningThread.Execute;
var
  i : Integer;
begin
  for i := 1 to FStepCount-1 do
    LearnStep(FNetwork, FTeacher.FLearningInput, FTeacher.FLearningOutput, FQuickness, FTeacher.FGradeFunction);
  FLearningSetGrade := CheckNetwork(FNetwork, FTeacher.FLearningInput, FTeacher.FLearningOutput, FTeacher.FGradeFunction);
  FTestSetGrade := CheckNetwork(FNetwork, FTeacher.FTestInput, FTeacher.FTestOutput, FTeacher.FGradeFunction);
end;

constructor TNetworkLearningThread.Create(const ThreadLabel : AnsiString; Teacher: TNetwokTeacher; Network : TFeedForwardNet; StepCount: PtrUInt; Quickness : Double);
begin
  FTeacher := Teacher;
  FStepCount := StepCount;
  FNetwork := Network;
  FQuickness := Quickness;
  FThreadLabel := ThreadLabel;
  inherited Create(False);
end;

function TNetwokTeacher.Learn : TFeedForwardNet;
const
  EpochsPerThread = 16;
  ThreadCount = 8;
  MaxEpochs = 1024;
  MaxNotBetterCount = 16;
  MinTemperature = 1e-12;
  MinDeltaGrade = 1e-4;
var
  Temperature : Extended;
  Network : array of TFeedForwardNet;
  Threads : array of TNetworkLearningThread;
  Temperatures : array of Extended;
  Quicknesses : array of Extended;
  i, epoch, NotBetterCount, BestNetwork : Integer;
  TheBestGrade, BestGrade, CurrentGrade : Double;
  NetworkStamp, TheBestNetworkStamp : TMemoryStream;
begin
  Threads := [];
  SetLength(Threads, ThreadCount);
  Network := [];
  SetLength(Network, ThreadCount);
  Temperatures := [];
  SetLength(Temperatures, ThreadCount);
  Quicknesses := [];
  SetLength(Quicknesses, ThreadCount);
  Temperature := FQuickness;
  NetworkStamp := TMemoryStream.Create;
  TheBestNetworkStamp := TMemoryStream.Create;
  TheBestGrade := 0;
  FNetwork.SaveToStream(NetworkStamp);
  for i := 0 to ThreadCount-1 do
  begin
    NetworkStamp.Position := 0;
    Network[i] := TFeedForwardNet.Create(NetworkStamp);
  end;
  BestNetwork := 0;
  NotBetterCount := 0;

  for epoch := 0 to MaxEpochs-1 do
  begin
    NetworkStamp.Clear;
    Network[BestNetwork].SaveToStream(NetworkStamp);

    for i := 0 to ThreadCount-1 do
    begin
      NetworkStamp.Position := 0;
      Network[i].LoadFromStream(NetworkStamp);
      if (epoch mod 2 = 0) and (Temperature > MinTemperature) then
      begin
        Temperatures[i] := Temperature*sqr((i+ThreadCount/2)/ThreadCount);
        Quicknesses[i] := FQuickness;
      end else
      begin
        Temperatures[i] := Temperature;
        Quicknesses[i] := FQuickness*sqrt((i+ThreadCount/2)/ThreadCount);
      end;
      if (i > 0) and (Temperature > MinTemperature) then
        Network[i].RandomAllAddition(0, Temperatures[i]);
    end;
    
    for i := 0 to ThreadCount-1 do
      Threads[i] := TNetworkLearningThread.Create('Thread '+IntToStr(i), Self, Network[i], EpochsPerThread, Quicknesses[i]);

    BestGrade := 0;
    for i := 0 to ThreadCount-1 do
    begin
      while not Threads[i].Finished do
        TThread.Yield();
      CurrentGrade := (4 * Threads[i].FTestSetGrade + Threads[i].FLearningSetGrade)/5;
      if CurrentGrade >= BestGrade then
      begin
        BestGrade := CurrentGrade;
        BestNetwork := i;
      end;
      FreeAndNil(Threads[i]);
    end;
    Inc(NotBetterCount);
    if BestGrade > TheBestGrade then
    begin
      TheBestNetworkStamp.Clear;
      Network[BestNetwork].SaveToStream(TheBestNetworkStamp);
      if BestGrade > TheBestGrade + MinDeltaGrade then
        NotBetterCount := 0;
      TheBestGrade := BestGrade;
    end;
    Temperature := Temperatures[BestNetwork];
    FQuickness := Quicknesses[BestNetwork];
    writeln(Epoch, #9, NotBetterCount, #9, BestGrade:2:6, #9, Temperature:2:8, #9, FQuickness:2:8, #9, 'Best: ', BestNetwork);

    if NotBetterCount > MaxNotBetterCount then
      Break;
  end;

  for i := 0 to ThreadCount-1 do
    FreeAndNil(Network[i]);
  TheBestNetworkStamp.Position := 0;
  FNetwork.LoadFromStream(TheBestNetworkStamp);
  TheBestNetworkStamp.Free;
  NetworkStamp.Free;
  Result := FNetwork;
end;

constructor TNetwokTeacher.Create(const InputDataSet, 
  OutputDataSet: array of TDataVector; TestFraction, Quickness: Double; 
  GradeFunction: TGradeFunction; Network : TFeedForwardNet);
var
  i, j : Integer;
  TestCount, LearnCount, DataCount : Integer;
begin
  Assert(Length(InputDataSet) = Length(OutputDataSet));
  FGradeFunction := GradeFunction;
  FQuickness := Quickness;
  FNetwork := Network;

  DataCount := Length(InputDataSet);
  TestCount := Round(TestFraction * DataCount);
  LearnCount := DataCount - TestCount;

  FLearningInput := [];
  FLearningOutput := [];
  FTestInput := [];
  FTestOutput := [];
  SetLength(FLearningInput, LearnCount,Length(InputDataSet[0]));
  SetLength(FLearningOutput, LearnCount,Length(OutputDataSet[0]));
  SetLength(FTestInput, TestCount, Length(InputDataSet[0]));
  SetLength(FTestOutput, TestCount, Length(OutputDataSet[0]));

  j := 0;
  for i in Shuf(DataCount) do
  begin
    if j < TestCount then  
    begin
      FTestInput[j] := InputDataSet[i];
      FTestOutput[j] := OutputDataSet[i];
    end else begin
      FLearningInput[j-TestCount] := InputDataSet[i];
      FLearningOutput[j-TestCount] := OutputDataSet[i];
    end;
    Inc(j);
  end; 
end;

end.
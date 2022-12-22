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

implementation

uses
  SysUtils, Math;

procedure TNetworkLearningThread.Execute;
var
  i : Integer;
begin
  for i := 1 to FStepCount-1 do
    FNetwork.LearnStep(FTeacher.FLearningInput, FTeacher.FLearningOutput, FQuickness);
  FLearningSetGrade := FNetwork.CheckNetwork(FTeacher.FLearningInput, FTeacher.FLearningOutput, FTeacher.FGradeFunction);
  FTestSetGrade := FNetwork.CheckNetwork(FTeacher.FTestInput, FTeacher.FTestOutput, FTeacher.FGradeFunction);
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
  EpochsPerThread = 64;
  ThreadCount = 8;
  MaxEpochs = 1024;
  MaxNotBetterCount = 16;
  MinTemperature = 1e-30;
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
  Temperature := FQuickness/256;
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
      if (Temperature > MinTemperature) then
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
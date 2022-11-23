unit Teacher;

{$Mode Fpc}

interface

uses
    FeedForwardNet;

procedure TeachNet(net : TFeedForwardNet; const VectorSamples, VectorOutputs : array of TDataVector; const Quickness, TestFraction : Double);

implementation

uses
    Classes, math;

var 
  RunId : QWord = 0;

procedure TeachNet(net : TFeedForwardNet; const VectorSamples, VectorOutputs : array of TDataVector; const Quickness, TestFraction : Double);
const
    MaxEpoch = 16384;
    MaxIdleEpoch = 64;
var
    bestNet : TMemoryStream;
    LearningInput, LearningOutput, TestInput, TestOutput : array of TDataVector;
    Count, LearnCount, TestCount : Integer;
    DivisionVector : array of Boolean;
    i, j, k : Integer;
    epoch : Integer;
    lastBetterEpoch : Integer;

    LearningGrade, TestGrade : Double;
    LearningBestGrade, TestBestGrade : Double;

    MyRunId : QWord;
begin
    Assert(Length(VectorSamples) = Length(VectorOutputs));
    Count := Length(VectorSamples);
    MyRunId := InterlockedIncrement64(RunId);

    DivisionVector := [];
    SetLength(DivisionVector, Count);
    TestCount := 0;
    LearnCount := 0;
    for i := 0 to Count-1 do
    begin
        DivisionVector[i] := random() <= TestFraction;
        if DivisionVector[i] then
            Inc(TestCount)
        else
            Inc(LearnCount);
    end;

    LearningInput := []; SetLength(LearningInput, LearnCount);
    LearningOutput := []; SetLength(LearningOutput, LearnCount);
    TestInput := []; SetLength(TestInput, TestCount);
    TestOutput := []; SetLength(TestOutput, TestCount);

    j := 0;
    k := 0;
    
    for i := 0 to Count-1 do
    begin
        if DivisionVector[i] then
        begin
            TestInput[k] := VectorSamples[i];
            TestOutput[k] := VectorOutputs[i];
            Inc(k);
        end else begin
            LearningInput[j] := VectorSamples[i];
            LearningOutput[j] := VectorOutputs[i];
            Inc(j);
        end;
    end;
    
    bestNet := TMemoryStream.Create;
    net.SaveToStream(bestNet);

    LearningBestGrade := net.CheckNetwork(LearningInput, LearningOutput, @SumOfRoundedDifferences);
    TestBestGrade := net.CheckNetwork(TestInput, TestOutput, @SumOfRoundedDifferences);
    lastBetterEpoch := 0;
    epoch := 0;
    
    repeat                
        TFeedForwardNet.AsyncStep(LearningInput, LearningOutput, Quickness, @net.RandomLearnStep);
        LearningGrade := net.CheckNetwork(LearningInput, LearningOutput, @SumOfRoundedDifferences);
        TestGrade := net.CheckNetwork(TestInput, TestOutput, @SumOfRoundedDifferences);

        if ((TestGrade >= TestBestGrade) and (LearningGrade > LearningBestGrade)) or ((TestGrade > TestBestGrade) and (LearningGrade >= LearningBestGrade)) then
        begin
            bestNet.Clear;
            net.SaveToStream(bestNet);
            lastBetterEpoch := epoch;
            LearningBestGrade := LearningGrade;
            TestBestGrade := TestGrade;
        end;

        writeln('[', MyRunId:2, '] ', 'Epoch: ', epoch, ', learning accuracy: ', LearningGrade:2:4, ', test accuracy: ', TestGrade:2:4);        
        Flush(StdOut);
        Inc(epoch);        
    until (epoch - lastBetterEpoch > MaxIdleEpoch) or (epoch > MaxEpoch);

    bestNet.Position := 0;
    net.LoadFromStream(bestNet);    

    bestNet.Free;
    writeln('Run ', MyRunId, ': done.');
    Flush(StdOut);
end;

end.

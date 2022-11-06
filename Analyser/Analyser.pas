unit Analyser;

{$Mode ObjFpc}
{$I defines.inc}

interface

uses
    cThreads, SysUtils, Classes, Queues, Math, IniFiles, Locker, 
    FPImage, spidev, v4l1, YUV2Camera, FeedForwardNet, VectorizeImage;

type

    TDoubleRect = record
        Left, Top, Right, Bottom: double;
    end;

    TSeedAnalyser = class
    private
        FQueue: TQueueManager;
        FAnalysisThreads : Integer;
        FNet : TFeedForwardNet;
        FInputImageWidth, FInputImageHeight : Integer;
        FNonResetingFrameCount : QWord;
        FNonResetingAnalisedCount : QWord;

        AnalisedCount : QWord;
        FrameCount : QWord;

        Camera: TYUV2Camera;
        AreaLocker: TLocker;
        FWidth, FHeight: integer;
        FAreaIndex: integer;
        FAreaCount: integer;
        FAreas: array of TDoubleRect;
        FAreaStatus: array of boolean;
        FAreaValue: array of Double;
        {$ifdef PREPARING_IMAGE}
        FGradientSupressors: array of TGradientSupressor;
        {$endif}
        procedure WaitForFrame;
        function GetNextArea: integer;
        procedure Capture;
        procedure Analysis;
        function MarkFromCamera(const Rect: TDoubleRect{$ifdef PREPARING_IMAGE}; const Supressor: PGradientSupressor = nil{$endif}): Double; inline;
    public
        property AreaCount: integer read FAreaCount;
        function GetAreaStatus(const Index: integer): boolean; inline;
        function GetAreaValue(const Index: integer): Double; inline;
        function GetStatus: ansistring;
        function GetAnalysisCount(const Reset : Boolean) : QWord;
        function GetFrameCount(const Reset : Boolean) : QWord;

        constructor Create(const ConfigFile: TIniFile);
        constructor Create(const PathToConfigFile: ansistring = '../config/config.ini');
        destructor Destroy; override;
    end;

implementation

function GetCameraDevice: ansistring;
var
    i: integer;
begin
    for i := 0 to 9 do
    begin
        Result := '/dev/video' + IntToStr(i);
        if FileExists(Result) then
        exit;
    end;
    Result := '';
end;

function TSeedAnalyser.GetAnalysisCount(const Reset : Boolean) : QWord;
begin
    Result := AnalisedCount;
    if Reset then
        AnalisedCount := 0;
end;

function TSeedAnalyser.GetFrameCount(const Reset : Boolean) : QWord;
begin
    Result := FrameCount;
    if Reset then
        FrameCount := 0;
end;

function TSeedAnalyser.MarkFromCamera(const Rect: TDoubleRect{$ifdef PREPARING_IMAGE}; const Supressor: PGradientSupressor{$endif}): Double;
var
    ProcessResults : TDataVector;
begin
    InterlockedIncrement64(AnalisedCount);
    {$ifdef PREPARING_IMAGE}
    ProcessResults := FNet.ProcessData(PrepareImage(Img2Vector(@Camera.GetColor, Round(FWidth*Rect.Left), Round(FHeight*Rect.Top), Round(FWidth*Rect.Right), Round(FHeight*Rect.Bottom), FInputImageWidth, FInputImageHeight), FInputImageWidth, FInputImageHeight, DefaultDestValueOfPrepareImage, Supressor, DefaultSupressorTimePeriodOfPrepareImage));
    {$else}
    ProcessResults := FNet.ProcessData(Img2Vector(@Camera.GetColor, Round(FWidth*Rect.Left), Round(FHeight*Rect.Top), Round(FWidth*Rect.Right), Round(FHeight*Rect.Bottom), FInputImageWidth, FInputImageHeight));
    {$endif}
    Exit(ProcessResults[0]-ProcessResults[1]);
end;

procedure TSeedAnalyser.Capture;
begin
    try
        Camera.GetNextFrame;
        Inc(FNonResetingFrameCount);
        InterlockedIncrement64(FrameCount);
    finally
        FQueue.AddMethod(@Capture);
    end;
end;

procedure TSeedAnalyser.WaitForFrame;
var
    i : Integer;
begin
    i := 0;
    while (FNonResetingAnalisedCount > FAnalysisThreads * FNonResetingFrameCount) and (i<16) do
    begin
        sleep(1);
        Inc(i);
    end;
end;

procedure TSeedAnalyser.Analysis;
var
    i, j: integer;
begin
    try
        WaitForFrame;
        for j := 0 to FAreaCount - 1 do
        begin
            i := GetNextArea;
            FAreaValue[i] := MarkFromCamera(FAreas[i]{$ifdef PREPARING_IMAGE}, @FGradientSupressors[i]{$endif});
            FAreaStatus[i] := FAreaValue[i] > 0;
        end;
        InterlockedIncrement64(FNonResetingAnalisedCount);
    finally
        FQueue.AddMethod(@Analysis);
    end;
end;

function TSeedAnalyser.GetNextArea: integer;
begin
    AreaLocker.Lock;
    Result := FAreaIndex;
    Inc(FAreaIndex);
    if FAreaIndex >= FAreaCount then
        FAreaIndex := 0;
    AreaLocker.Unlock;
end;

function TSeedAnalyser.GetAreaValue(const Index: integer): Double;
begin
    Result := FAreaValue[Index];
end;

function TSeedAnalyser.GetAreaStatus(const Index: integer): boolean;
begin
    Result := FAreaStatus[Index];
end;

function TSeedAnalyser.GetStatus: ansistring;
const
    itc: array[0..1] of char = ('0', '1');
var
    i: integer;
begin
    Result := '';
    for i := 0 to FAreaCount - 1 do
        Result := Result + itc[ifthen(GetAreaStatus(i), 1, 0)];
end;

constructor TSeedAnalyser.Create(const ConfigFile: TIniFile);
var
    i: integer;
    SectionName: ansistring;
    FS : TFileStream;
begin
    FNonResetingFrameCount := 0;
    FNonResetingAnalisedCount := 0;
    FrameCount := 0;
    AnalisedCount := 0;
    FQueue := TQueueManager.Create(1, 1);
    FQueue.RemoveRepeated := False;
    AreaLocker := TLocker.Create;
    FWidth := ConfigFile.ReadInteger('Global', 'Width', 1920);
    FHeight := ConfigFile.ReadInteger('Global', 'Height', 1080);
    Camera := TYUV2Camera.Create(FWidth, FHeight, GetCameraDevice);
    Camera.Open;
    FQueue.AddMethod(@Capture);
    
    FS := TFileStream.Create(ConfigFile.ReadString('Global', 'NetPath', '../config/NetPath.bin'), fmOpenRead);
    FNet := TFeedForwardNet.Create(FS);
    FS.Free;
    FInputImageWidth := ConfigFile.ReadInteger('Global', 'InputImageWidth', 32);
    FInputImageHeight := ConfigFile.ReadInteger('Global', 'InputImageHeight', 32);
    
    FAreaIndex := 0;
    FAreaCount := ConfigFile.ReadInteger('Global', 'DetectAreaCount', 0);
    SetLength(FAreas, FAreaCount);
    SetLength(FAreaStatus, FAreaCount);
    SetLength(FAreaValue, FAreaCount);
    {$ifdef PREPARING_IMAGE}
    SetLength(FGradientSupressors, FAreaCount);
    {$endif}
    for i := 0 to FAreaCount - 1 do
    begin
        SectionName := 'DetectArea' + IntToStr(i);
        FAreas[i].Left := ConfigFile.ReadFloat(SectionName, 'Left', 0);
        FAreas[i].Right := ConfigFile.ReadFloat(SectionName, 'Right', 0);
        FAreas[i].Top := ConfigFile.ReadFloat(SectionName, 'Top', 0);
        FAreas[i].Bottom := ConfigFile.ReadFloat(SectionName, 'Bottom', 0);
    end;
    FAnalysisThreads := max(2, FQueue.CoreCount);
    for i := 0 to FAnalysisThreads-1 do
        FQueue.AddMethod(@Analysis);
end;

constructor TSeedAnalyser.Create(const PathToConfigFile: ansistring);
var
    i: TIniFile;
begin
    randomize;
    i := TIniFile.Create(PathToConfigFile);
    Create(i);
    i.Free;
end;

destructor TSeedAnalyser.Destroy;
begin
    FQueue.Clear;
    Camera.Close;
    Camera.Free;
    FQueue.Free;
    AreaLocker.Free;
    FNet.Free;
    inherited Destroy;
end;

end.

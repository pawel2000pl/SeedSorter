unit Analyser;

{$Mode ObjFpc}

interface

uses
  cThreads, SysUtils, Classes, Queues, Math, IniFiles, Locker,
  FPImage, spidev, v4l1, YUV2Camera, NeuronImg;

type

  TDoubleRect = record
    Left, Top, Right, Bottom: double;
  end;

  TSeedAnalyser = class
  private
    FQueue: TQueueManager;
    FNeuron : TNeuron;
  
    Camera: TYUV2Camera;
    AreaLocker: TLocker;
    FWidth, FHeight: integer;
    FAreaIndex: integer;
    FAreaCount: integer;
    FAreas: array of TDoubleRect;
    FAreaStatus: array of boolean;
    function GetNextArea: integer;
    procedure Capture;
    procedure Analicys;
    function MarkFromCamera(const Rect: TDoubleRect): double; inline;
  public
    property AreaCount: integer read FAreaCount;
    function GetAreaStatus(const Index: integer): boolean; inline;
    function GetStatus: ansistring;

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

function TSeedAnalyser.MarkFromCamera(const Rect: TDoubleRect): double;
begin
  Exit(FNeuron.AnaliseImage(@Camera.GetColor, Round(FWidth*Rect.Left), Round(FHeight*Rect.Top), Round(FWidth*Rect.Right), Round(FHeight*Rect.Bottom)));
end;

procedure TSeedAnalyser.Capture;
begin
  try
    Camera.GetNextFrame;
  finally
    FQueue.AddMethod(@Capture);
  end;
end;

procedure TSeedAnalyser.Analicys;
var
  i, j: integer;
begin
  try
    for j := 0 to FAreaCount - 1 do
    begin
      i := GetNextArea;
      FAreaStatus[i] := MarkFromCamera(FAreas[i]) < 0;
    end;
  finally
    FQueue.AddMethod(@Analicys);
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
  FQueue := TQueueManager.Create(1, 1);
  FQueue.RemoveRepeated := False;
  AreaLocker := TLocker.Create;
  FWidth := ConfigFile.ReadInteger('Global', 'Width', 1920);
  FHeight := ConfigFile.ReadInteger('Global', 'Height', 1080);
  Camera := TYUV2Camera.Create(FWidth, FHeight, GetCameraDevice);
  Camera.Open;
  FQueue.AddMethod(@Capture);
  FS := TFileStream.Create(ConfigFile.ReadString('Global', 'NeuronPath', '../config/Neuron.bin'), fmOpenRead);

  FNeuron := TNeuron.Create(FS);
  FS.Free;
  
  FAreaIndex := 0;
  FAreaCount := ConfigFile.ReadInteger('Global', 'DetectAreaCount', 0);
  SetLength(FAreas, FAreaCount);
  SetLength(FAreaStatus, FAreaCount);
  for i := 0 to FAreaCount - 1 do
  begin
    SectionName := 'DetectArea' + IntToStr(i);
    FAreas[i].Left := ConfigFile.ReadFloat(SectionName, 'Left', 0);
    FAreas[i].Right := ConfigFile.ReadFloat(SectionName, 'Right', 0);
    FAreas[i].Top := ConfigFile.ReadFloat(SectionName, 'Top', 0);
    FAreas[i].Bottom := ConfigFile.ReadFloat(SectionName, 'Bottom', 0);
  end;
  for i := 0 to max(1, FQueue.CoreCount - 1) do
    FQueue.AddMethod(@Analicys);
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
  FQueue.Free;
  Camera.Close;
  Camera.Free;
  AreaLocker.Free;
  inherited Create;
end;

end.

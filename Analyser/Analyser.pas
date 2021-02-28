unit Analyser;

{$Mode ObjFpc}

interface

uses
  cThreads, SysUtils, Classes, Queues, Math, IniFiles, Locker,
  FPImage, spidev, v4l1, YUV2Camera;

type

  TDoubleRect = record
    Left, Top, Right, Bottom: double;
  end;

  TSeedAnalyser = class
  private
    FTable: array[byte, byte, byte] of boolean;
    FQueue: TQueueManager;

    Camera: TYUV2Camera;
    AreaLocker: TLocker;
    FWidth, FHeight: integer;
    FAreaIndex: integer;
    FAreaCount: integer;
    FAreas: array of TDoubleRect;
    FAreaStatus: array of boolean;
    FAreaBorder: double;
    function GetNextArea: integer;
    procedure Capture;
    procedure Analicys;
    function MarkFromCamera(const Rect: TDoubleRect): double;
  public
    property AreaCount: integer read FAreaCount;
    procedure LoadTable(Stream: TStream; const BorderMin: double = 0;
      const BorderMax: double = 1); overload;
    procedure LoadTable(const Path: ansistring; const BorderMin: double = 0;
      const BorderMax: double = 1); overload;
    function GetAreaStatus(const Index: integer): boolean;
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
var
  c: TFPColor;
  x, y, Count: integer;
begin
  Count := 0;
  for x := EnsureRange(round(FWidth * Rect.Left), 0, FWidth)
    to EnsureRange(round(FWidth * Rect.Right), 1, FWidth) - 1 do
    for y := EnsureRange(round(FHeight * Rect.Top), 0, FHeight)
      to EnsureRange(round(FHeight * Rect.Bottom), 1, FHeight) - 1 do
    begin
      c := Camera.GetColor(x, y);
      if FTable[(c.red shr 8) and $FF, (c.green shr 8) and $FF,
        (c.blue shr 8) and $FF] then
        Inc(Count);
    end;
  Result := Count / (FWidth * FHeight * (Rect.Right - Rect.Left) *
    (Rect.Bottom - Rect.Top));
end;

procedure TSeedAnalyser.LoadTable(Stream: TStream; const BorderMin: double = 0;
  const BorderMax: double = 1);
var
  r, g, b: integer;
  d: double;
begin
  for r := 0 to 255 do
    for g := 0 to 255 do
      for b := 0 to 255 do
      begin
        Stream.ReadBuffer(d, SizeOf(d));
        FTable[r, g, b] := InRange(d, BorderMin, BorderMax);
      end;
end;

procedure TSeedAnalyser.LoadTable(const Path: ansistring;
  const BorderMin: double = 0; const BorderMax: double = 1);
var
  FS: TFileStream;
begin
  FS := TFileStream.Create(Path, fmOpenRead);
  FS.Position := 0;
  LoadTable(FS, BorderMin, BorderMax);
  FS.Free;
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
      FAreaStatus[i] := MarkFromCamera(FAreas[i]) > FAreaBorder;
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
begin
  FQueue := TQueueManager.Create(1, 1);
  FQueue.RemoveRepeated := False;
  AreaLocker := TLocker.Create;
  FWidth := ConfigFile.ReadInteger('Global', 'Width', 1920);
  FHeight := ConfigFile.ReadInteger('Global', 'Height', 1080);
  Camera := TYUV2Camera.Create(FWidth, FHeight, GetCameraDevice);
  Camera.Open;
  FQueue.AddMethod(@Capture);
  LoadTable(ConfigFile.ReadString('Global', 'TablePath', '../config/ColorTable.bin'),
    ConfigFile.ReadFloat('Global', 'MinAreaBorder', 0),
    ConfigFile.ReadFloat('Global', 'MaxAreaBorder', 1));

  FAreaBorder := ConfigFile.ReadFloat('Global', 'AreaBorder', 0.0008);
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
  for i := 0 to max(1, FQueue.CoreCount - 2) do
    FQueue.AddMethod(@Analicys);
end;

constructor TSeedAnalyser.Create(const PathToConfigFile: ansistring);
var
  i: TIniFile;
begin
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

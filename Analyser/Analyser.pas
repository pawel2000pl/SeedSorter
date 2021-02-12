unit Analyser;

{$Mode ObjFpc}

interface

uses
    cThreads, SysUtils, Classes, Queues, math, IniFiles, Locker, FPImage, spidev, v4l1, YUV2Camera;

type

    TDoubleRect = record
        Left, Top, Right, Bottom : Double;
    end;
    
    TSeedAnalyser = class
    private
        FTable : array[Byte, Byte, Byte] of Boolean;
        FQueue : TQueueManager;

        Camera : TYUV2Camera;
        AreaLocker : TLocker;
        FWidth, FHeight : Integer;
        FAreaIndex : Integer;
        FAreaCount : Integer;
        FAreas : array of TDoubleRect;
        FAreaStatus : array of Boolean;
        FAreaBorder : Double;
        function GetNextArea : Integer;
        procedure Capture;
        procedure Analicys;
        function MarkFromCamera(const Rect : TDoubleRect) : Double;
    public
        property AreaCount : Integer read FAreaCount;
        procedure LoadTable(Stream : TStream; const BorderMin : Double = 0; const BorderMax : Double = 1); overload;
        procedure LoadTable(const Path : AnsiString; const BorderMin : Double = 0; const BorderMax : Double = 1); overload;
        function GetAreaStatus(const Index : Integer) : Boolean;
        function GetStatus : AnsiString;
            
        constructor Create(const ConfigFile : TIniFile);
        constructor Create(const PathToConfigFile : AnsiString = '../config/config.ini');
        destructor Destroy; override;
    end;

implementation

function GetCameraDevice : AnsiString;
var
    i : Integer;
begin
    for i := 0 to 9 do
    begin
        Result := '/dev/video' + IntToStr(i);
        if FileExists(Result) then
            exit;
    end;
    Result := '';
end;

function TSeedAnalyser.MarkFromCamera(const Rect : TDoubleRect) : Double;
var
    c : TFPColor;
    x, y, Count : Integer;
begin
    Count := 0;
    for x := EnsureRange(round(FWidth*Rect.Left), 0, FWidth-1) to EnsureRange(round(FWidth*Rect.Right), 0, FWidth)-1 do
        for y := EnsureRange(round(FHeight*Rect.Top), 0, FHeight-1) to EnsureRange(round(FHeight*Rect.Bottom), 0, FHeight)-1 do
        begin
            c := Camera.GetColor(x, y);
            if FTable[c.red shr 8, c.green shr 8, c.blue shr 8] then
                Inc(Count);
        end;
    Result := Count/(FWidth*FHeight*(Rect.Right-Rect.Left)*(Rect.Bottom-Rect.Top));
end;

procedure TSeedAnalyser.LoadTable(Stream : TStream; const BorderMin : Double = 0; const BorderMax : Double = 1);
var
    r, g, b : Integer;
    d : Double;
begin
    for r := 0 to 255 do
        for g := 0 to 255 do
            for b := 0 to 255 do
            begin
                Stream.ReadBuffer(d, SizeOf(d));
                FTable[r, g, b] := InRange(d, BorderMin, BorderMax);
            end;
end;

procedure TSeedAnalyser.LoadTable(const Path : AnsiString; const BorderMin : Double = 0; const BorderMax : Double = 1); 
var
    FS : TFileStream;
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
    i, j : Integer;
begin
    try
        for j := 0 to FAreaCount-1 do
        begin
            i := GetNextArea;
            FAreaStatus[i] := MarkFromCamera(FAreas[i]) > FAreaBorder;
        end;
    finally
        FQueue.AddMethod(@Analicys);
    end;
end;

function TSeedAnalyser.GetNextArea : Integer;
begin
    AreaLocker.Lock;
    Result := FAreaIndex;
    Inc(FAreaIndex);
    if FAreaIndex >= FAreaCount then
        FAreaIndex := 0;
    AreaLocker.Unlock;
end;

function TSeedAnalyser.GetAreaStatus(const Index : Integer) : Boolean;
begin
    Result := FAreaStatus[Index];
end;

function TSeedAnalyser.GetStatus : AnsiString;
const
    itc : array[0..1] of Char = ('0', '1');
var
    i : Integer;
begin
    Result := '';
    for i := 0 to FAreaCount -1 do
        Result := Result + itc[ifthen(GetAreaStatus(i), 1, 0)];
end;

constructor TSeedAnalyser.Create(const ConfigFile : TIniFile);
var
    i : Integer;
    SectionName : AnsiString;
begin
    FQueue := TQueueManager.Create(1,1);
    AreaLocker := TLocker.Create;
    FWidth := ConfigFile.ReadInteger('Global', 'Width', 1920);
    FHeight := ConfigFile.ReadInteger('Global', 'Height', 1080);
    Camera := TYUV2Camera.Create(FWidth, FHeight, GetCameraDevice);
    Camera.Open;
    FQueue.AddMethod(@Capture);
    LoadTable(ConfigFile.ReadString('Global', 'TablePath', '../config/ColorTable.bin'), ConfigFile.ReadFloat('Global', 'MinAreaBorder', 0), ConfigFile.ReadFloat('Global', 'MaxAreaBorder', 1));

    FAreaBorder := ConfigFile.ReadFloat('Global', 'AreaBorder', 0.0008);
    FAreaIndex := 0;
    FAreaCount := ConfigFile.ReadInteger('Global', 'DetectAreaCount', 0);
    SetLength(FAreas, FAreaCount);
    SetLength(FAreaStatus, FAreaCount);
    for i := 0 to FAreaCount-1 do
    begin
        SectionName := 'DetectArea'+IntToStr(i);  
        FAreas[i].Left := ConfigFile.ReadFloat(SectionName, 'Left', 0);
        FAreas[i].Right := ConfigFile.ReadFloat(SectionName, 'Right', 0);
        FAreas[i].Top := ConfigFile.ReadFloat(SectionName, 'Top', 0);
        FAreas[i].Bottom := ConfigFile.ReadFloat(SectionName, 'Bottom', 0);
    end;
    for i := 0 to FQueue.CoreCount-1 do
        FQueue.AddMethod(@Analicys);
end;

constructor TSeedAnalyser.Create(const PathToConfigFile : AnsiString);
var
    i : TIniFile;
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


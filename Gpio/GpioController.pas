program GpioController;

{$Mode ObjFpc}

uses
    cThreads, SysUtils, Classes, IniFiles, ElectromagnetConroller, math;

const
    DenyStr = 'Deny';
    AllowedForElectromagnetStr = 'Electromagnet';
    StartProgramStr = 'StartButton';
    StopButton = 'StopButton';
    TrueStr = 'True';
    FalseStr = 'False';
    UsesSectionStr = 'Uses';

var
    ConfigFile : TIniFile;
    Electromagnets : array of TElectromagnetConroller;
    Switches : array of Integer;
    DelayTime : Word;

function ReadString(var s : AnsiString) : Boolean;
var
    chr : Char;
begin
    s := '';
    repeat
        read(chr);
        s := s + chr;
    until chr in [#13, #10, #26, #3];

    Result := not (chr in [#26, #3]);
end;

procedure CopyFile(const Source, Dest : AnsiString);
var
    SrcStream, DstStream : TFileStream;
begin
    SrcStream := TFileStream.Create(Source, fmOpenRead);
    DstStream := TFileStream.Create(Dest, fmCreate);
    SrcStream.Position := 0;
    DstStream.CopyFrom(SrcStream, SrcStream.Size);
    SrcStream.Free;
    DstStream.Free;
end;
    
procedure OpenConfigFile;
var
    ConfigFileName : AnsiString;
    DefaultFileName : AnsiString;
begin

    if (ParamCount > 0) then
        ConfigFileName := ParamStr(1)
    else
        ConfigFileName := GetUserDir + '.seedsorter/GpioConfig.ini';

    DefaultFileName := ExtractFilePath(ParamStr(0)) + 'GpioDefaultConfig.ini';
    if (not FileExists(ConfigFileName)) and FileExists(DefaultFileName) then
        CopyFile(DefaultFileName, ConfigFileName);
    
    ConfigFile := TIniFile.Create(ConfigFileName);
end;

procedure AddElectromagnet(const Gpio : Integer);
var
    c : Integer;
begin
    c := Length(Electromagnets);
    SetLength(Electromagnets, c+1);
    Electromagnets[c] := TElectromagnetConroller.Create(Gpio);
    Electromagnets[c].Delay := DelayTime;
end;

procedure LoadElectromagnets;
var
    Sections : TStringList;
    i, Gpio : Integer;
begin
    Sections := TStringList.Create;
    ConfigFile.ReadSection(UsesSectionStr, Sections);
    for i := 0 to Sections.Count-1 do
        if TryStrToInt(Sections[i], Gpio) and SameText(ConfigFile.ReadString(UsesSectionStr, Sections[i], DenyStr), AllowedForElectromagnetStr) then
            AddElectromagnet(Gpio);
    Sections.Free;
    SetLength(Switches, Length(Electromagnets));
end;

procedure FreeElectromagnets;
var
    i : Integer;
begin
    for i := 0 to Length(Electromagnets)-1 do
        Electromagnets[i].Free;
    SetLength(Electromagnets, 0);
end;

function GetStrFirstDifference(const a, b : AnsiString) : Integer;
var
    i : Integer;
begin
    Result := 0;
    for i := 1 to min(Length(a), Length(b)) do
        if a[i] <> b[i] then
            Exit(i);
end;

procedure ConfigurePin(const Index : Integer);
var
    StrA, StrB : AnsiString;
    DiffIndex : Integer;
begin
    Readln(StrA);
    Electromagnets[Index].Value := True;
    Electromagnets[Index].Push(100);
    StrB := StrA;
    while StrB = StrA do
        Readln(StrB);
    DiffIndex := GetStrFirstDifference(StrA, StrB)-1;
    Switches[DiffIndex] := Index;
    ConfigFile.WriteInteger('Switch', 'Area'+IntToStr(DiffIndex), Index);
end;
    
procedure ConfigurePins;
var
    i : Integer;
begin
    for i := 0 to Length(Electromagnets)-1 do
        ConfigurePin(i);
end;

procedure LoadSwitches;
var
    i : Integer;
begin
    for i := 0 to Length(Electromagnets)-1 do
       Switches[i] := ConfigFile.ReadInteger('Switch', 'Area'+IntToStr(i), 0);    
end;

procedure ProcessString(const Str : AnsiString);
var
    i : Integer;
begin
    for i := 0 to min(Length(Str), Length(Electromagnets))-1 do
        Electromagnets[Switches[i]].Value := Str[i+1] = '1';
end;

procedure Hello(const Delay : LongWord = 100);
var
    Str : AnsiString;
    i, c : Integer;
begin
    c := Length(Electromagnets);
    Str := StringOfChar('0', c);
    for i := 1 to c do
    begin
        Str[i] := '1';
        ProcessString(Str);
        sleep(Delay);
        Str[i] := '0';
    end;    
    for i := c downto 1 do
    begin
        Str[i] := '1';
        ProcessString(Str);
        sleep(Delay);
        Str[i] := '0';
    end;
    ProcessString(Str);
end;

function ProcessInput : Boolean;
var
    Str : AnsiString;
begin
    Result := ReadString(Str);
    if not Result then 
        Exit;
    ProcessString(Str);
end;

begin
    OpenConfigFile;
    LoadElectromagnets;

    DelayTime := 0;
    if not SameText(ConfigFile.ReadString('Configuration', 'NeedConfiguration', TrueStr), FalseStr) then
    begin
        ConfigurePins;
        ConfigFile.WriteString('Configuration', 'NeedConfiguration', FalseStr);
    end;    
    DelayTime := ConfigFile.ReadInteger('Configuration', 'DelayTime', 0);
    LoadSwitches;
    
    ConfigFile.Free;

    Hello(100);
    
    while ProcessInput do;

    Hello(50);
    
    FreeElectromagnets;
end.


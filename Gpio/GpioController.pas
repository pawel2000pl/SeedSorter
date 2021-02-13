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
    
procedure OpenConfigFile;
var
    ConfigFileName : AnsiString;
begin

    if (ParamCount > 0) and (FileExists(ParamStr(1))) then
        ConfigFileName := ParamStr(1)
    else
        ConfigFileName := GetUserDir + '.seedsorter/GpioConfig.ini';
    
    ConfigFile := TIniFile.Create(ConfigFileName);
end;

procedure AddElectromagnet(const Gpio : Integer);
var
    c : Integer;
begin
    c := Length(Electromagnets);
    SetLength(Electromagnets, c+1);
    Electromagnets[c] := TElectromagnetConroller.Create(Gpio);
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
    ConfigFile.WriteInteger('Configuration', IntToStr(DiffIndex), Index);
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
       Switches[i] := ConfigFile.ReadInteger('Configuration', IntToStr(i), 0);    
end;

procedure ProcessString(const Str : AnsiString);
var
    i : Integer;
begin
    for i := 0 to min(Length(Str), Length(Electromagnets))-1 do
        Electromagnets[Switches[i]].Value := Str[i+1] = '1';
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
    
    if not SameText(ConfigFile.ReadString('Configuration', 'NeedConfiguration', TrueStr), FalseStr) then
    begin
        ConfigurePins;
        ConfigFile.WriteString('Configuration', 'NeedConfiguration', FalseStr);
    end;    
    LoadSwitches;
    
    ConfigFile.Free;

    while ProcessInput do;

    FreeElectromagnets;
end.


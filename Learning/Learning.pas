program Learning;

{$Mode ObjFpc}

uses
    SysUtils, Classes, FPImage, UniversalImage, SelectorUtils, math, IniFiles;

type
    TSampleImage = record
        Image : TUniversalImage;
        Verdict : Boolean;
    end;
    
var
    ColorTable : TColorTable;  
    Samples : array of TSampleImage;
    
procedure LoadSamples;
var
    SampleArray : ^TSampleArray;

    procedure LoadSample(const Verdict : Boolean; const FileName : AnsiString);
    var
        image : TUniversalImage;
        c : Integer;
    begin
        image := TUniversalImage.CreateEmpty;
        image.LoadFromFile(FileName);
        c := Length(Samples);
        SetLength(Samples, c+1);
        Samples[c].Image := image;
        Samples[c].Verdict := Verdict;
    end;

    procedure AddSamples;
    var
        i : Integer;   
    begin
        for i := 0 to Length(Samples)-1 do
            AddSample(Samples[i].Verdict, Samples[i].Image, SampleArray^);        
    end;

var
    i, c : Integer;
    s : AnsiString;
    v : Boolean;
begin
    c := ParamCount;
    v := False;
    
    for i := 1 to c do
    begin
        s := ParamStr(i);
        if s = '-t' then
            v := True
        else if s = '-f' then
            v := False
        else if FileExists(s) then
            LoadSample(v, s);
    end;
    SampleArray := AllocMem(SizeOf(TSampleArray));

    FillByte(SampleArray^, SizeOf(TSampleArray), 0);
    AddSamples;
    CreateColorTable(SampleArray^, ColorTable);
    FreeMem(SampleArray);
end; 

procedure FreeSamples;
var
    i : Integer;
begin
    for i := 0 to Length(Samples)-1 do
        Samples[i].Image.Free;
    SetLength(Samples, 0);
end;

procedure SaveColorTableToFile(const FileName : AnsiString);
var
    FS : TFileStream;
begin
    FS := TFileStream.Create(FileName, fmCreate);
    FS.WriteBuffer(ColorTable, SizeOf(ColorTable));
    FS.Free;
end;

procedure SearchBorders;
var
    TestResult : Extended;

    function Test(const Border, Area : Extended) : Boolean;
    var
        i : Integer;
        m : Extended;
    begin
        TestResult := 0;        
        Result := True;
        for i := 0 to Length(Samples)-1 do
        begin            
            m := Mark(Samples[i].Image, ColorTable, False, Border);
            TestResult += ifthen(Samples[i].Verdict, 1, -30) * m;
            if (m>Area) xor Samples[i].Verdict then
                Result := False;
        end;
    end;

    procedure MarkTest(const Border, Area : Extended);
    var
        i : Integer;
        Path : AnsiString;
    begin
        TestResult := 0;        
        Path := GetUserDir + '.seedsorter/Marked/';
        CreateDir(Path);
        for i := 0 to Length(Samples)-1 do
            if Mark(Samples[i].Image, ColorTable, True, Border) > Area then
                Samples[i].Image.SaveToFile(Path + IntToStr(i) + '-rejected.bmp')
                else
                Samples[i].Image.SaveToFile(Path + IntToStr(i) + '.bmp');
    end;

    function GetDifference(const i : Integer) : Extended;
    begin
        Result := 0.1 * exp(-i/3);
    end;

procedure SaveToIni(const Border, Area : Double; FileName : AnsiString = '~/.seedsorter/config.ini');
var
    ConfigFile : TIniFile;
    TablePath : AnsiString;
begin
    FileName := StringReplace(FileName, '~/', GetUserDir, []);
    ConfigFile := TIniFile.Create(FileName);
    ConfigFile.WriteFloat('Global', 'AreaBorder', Area);
    ConfigFile.WriteFloat('Global', 'MinAreaBorder', Border);
    ConfigFile.WriteFloat('Global', 'MaxAreaBorder', 1);

    TablePath := ExtractFilePath(FileName) + 'ColorTable.bin';
    ConfigFile.WriteString('Global', 'TablePath', TablePath);
    ConfigFile.Free;
    SaveColorTableToFile(TablePath);
end;
    
var 
    Border, Area, Difference, d : Extended;    
    i : Integer;
begin
    Difference := 0;
    for i := 1 to 10000 do
    begin    
        if Test((i mod 100)/100, (i div 100)/100) and (TestResult > Difference) then
        begin
            Border := (i mod 100)/100;
            Area := (i div 100)/100;
            Difference := TestResult;
        end;            
    end;

    writeln(ProgressLabel64);
    
    for i := 0 to 1600-1 do
    begin
        if (i mod 25) = 0 then
            Write('#');
        
        d := GetDifference(i);
        if Test(Border+d, Area) and (TestResult > Difference) then
        begin
            Border += d;
            Difference := TestResult;
        end else if Test(Border-d, Area) and (TestResult > Difference) then
        begin
            Border -= d;
            Difference := TestResult;
        end;
        
        if Test(Border, Area+d) and (TestResult > Difference) then
        begin
            Area += d;
            Difference := TestResult;
        end else if Test(Border, Area-d) and (TestResult > Difference) then
        begin
            Area -= d;
            Difference := TestResult;
        end;      
    end;

    writeln;
    Writeln('Done.');
    MarkTest(Border, Area);
    SaveToIni(Border, Area);
end;

begin    
    Writeln('Learning 1/2');
    LoadSamples;
    writeln('Learning 2/2');
    SearchBorders;
    FreeSamples;
    Writeln('Everything has beed saved');
end.


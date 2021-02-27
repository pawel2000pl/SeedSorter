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

procedure MarkTest(const Border, Area : Extended);
var
    i : Integer;
    Path, mal : AnsiString;
    Verdict : Boolean;
begin    
    Path := GetUserDir + '.seedsorter/Marked/';
    CreateDir(Path);
    for i := 0 to Length(Samples)-1 do
    begin
        Verdict := Mark(Samples[i].Image, ColorTable, True, Border) > Area;
        if Verdict <> Samples[i].Verdict then
        begin
            mal := '-mis';
            writeln('Sample n.o. ', i, ' did not pass the test: sould be: ', Samples[i].Verdict, ', but it was: ', Verdict);
        end 
        else
            mal := '';
        if Verdict then
            Samples[i].Image.SaveToFile(Path + IntToStr(i) + mal + '-rejected.bmp')
            else
            Samples[i].Image.SaveToFile(Path + IntToStr(i) + mal + '.bmp');
    end;
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
            TestResult += ifthen(Samples[i].Verdict, 1, -1)*Sign(m-Area);
            if (m>Area) xor Samples[i].Verdict then
                Result := False;
        end;
    end;

    function GetDifference(const i : Integer) : Extended;
    begin
        Result := 0.005 * exp(-i/100);
    end;
    
var 
    Border, Area, Difference, d : Extended;    
    i : Integer;
begin
    writeln('Learning 2');
    writeln(ProgressLabel64);
    Difference := 0;
    TestResult := 0;
    for i := 0 to 10000 do
    begin    
        if (i mod 157) = 0 then
            Write('#');
        if Test((i mod 100)/100, (i div 100)/100) and (TestResult > Difference) then ;
        begin
            Border := (i mod 100)/100;
            Area := (i div 100)/100;
            Difference := TestResult;
        end;            
    end;
    
    writeln;
    writeln('Best difference: ', Difference:2:4);
    writeln('Best border: ', Border:2:4);
    writeln('Best area: ', Area:2:4);

    writeln;
    writeln('Learning 3');
    writeln(ProgressLabel64);
    
    for i := 0 to 1600-1 do
    begin
        if (i mod 25) = 0 then
            Write('#');
        
        d := GetDifference(i);
        if Test(Border+d, Area) and (TestResult > Difference) then
        begin
            Border := EnsureRange(Border+d, 0, 1);
            Difference := TestResult;
        end else if Test(Border-d, Area) and (TestResult > Difference) then
        begin
            Border := EnsureRange(Border-d, 0, 1);
            Difference := TestResult;
        end;
        
        if Test(Border+d, Area+d) and (TestResult > Difference) then
        begin
            Area := EnsureRange(Area+d, 0, 1);
            Border := EnsureRange(Border+d, 0, 1);
            Difference := TestResult;
        end else if Test(Border-d, Area+d) and (TestResult > Difference) then
        begin
            Area := EnsureRange(Area+d, 0, 1);
            Border := EnsureRange(Border-d, 0, 1);
            Difference := TestResult;
        end;
        
        if Test(Border+d, Area-d) and (TestResult > Difference) then
        begin
            Area := EnsureRange(Area-d, 0, 1);
            Border := EnsureRange(Border+d, 0, 1);
            Difference := TestResult;
        end else if Test(Border-d, Area-d) and (TestResult > Difference) then
        begin
            Area := EnsureRange(Area-d, 0, 1);
            Border := EnsureRange(Border-d, 0, 1);
            Difference := TestResult;
        end;
        {
        if Test(Border, Area+d) and (TestResult > Difference) then
        begin
            Area := EnsureRange(Area+d, 0, 1);
            Difference := TestResult;
        end else if Test(Border, Area-d) and (TestResult > Difference) then
        begin
            Area := EnsureRange(Area-d, 0, 1);
            Difference := TestResult;
        end; }     
    end;

    writeln;
    writeln('Best difference: ', Difference:2:4);
    writeln('Best border: ', Border:2:4);
    writeln('Best area: ', Area:2:4);
    
    writeln;
    Writeln('Done.');
    MarkTest(Border, Area);
    SaveToIni(Border, Area);
end;

procedure SearchBorders2;
var
    MinArea, MaxArea : Extended;
    i, IntBorder : Integer;
    m : Extended;
    Border, Area, BestDifference, TestBorder : Extended;
begin
    writeln('Learning 2');
    writeln(ProgressLabel64);
    
    Area := 0.00;
    Border := 0.5;
    BestDifference := 0;
    
    for IntBorder := 1 to 1600 do
    begin
        if (IntBorder mod 25) = 0 then
            Write('#');
        TestBorder := IntBorder / 1600;
        MinArea := 0;
        MaxArea := 1;
        for i := 0 to Length(Samples)-1 do
        begin            
            m := Mark(Samples[i].Image, ColorTable, False, TestBorder);
            if Samples[i].Verdict then
                MinArea := Max(MinArea, m)
            else
                MaxArea := Min(MaxArea, m);
        end;
        if -(MaxArea - MinArea) > BestDifference then
        begin
            BestDifference := -(MaxArea - MinArea);
            Border := TestBorder;
            Area := (MaxArea + MinArea)/2;
        end;
    end;
    
    writeln;
    writeln('Best difference: ', BestDifference:2:4);
    writeln('Best border: ', Border:2:4);
    writeln('Best area: ', Area:2:4);

    MarkTest(Border, Area);
    SaveToIni(Border, Area);
    Writeln('Done');
end;

begin    
    Writeln('Learning 1');
    LoadSamples;
    SearchBorders2;
    FreeSamples;
    Writeln('Everything has beed saved');
end.


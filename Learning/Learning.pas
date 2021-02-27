program Demo;

{$Mode ObjFpc}
{$Define FitSize}

uses
    SysUtils, Classes, FPImage, UniversalImage, NeuronImg, math, IniFiles;

var
    Samples : array of TSampleImage;
    NeuronWidth : Integer = 64;
    NeuronHeight : Integer = 64;

function CreateMirrorImage1(Image : TUniversalImage) : TUniversalImage;  
var
    x, y : Integer;
begin
    Result := TUniversalImage.Create(Image.Width, Image.Height);
    for x := 0 to Image.Width-1 do
        for y := 0 to Image.Height-1 do
            Result.DirectColor[x, y] := Image.DirectColor[Image.Width-x-1, y];
end;

function CreateMirrorImage2(Image : TUniversalImage) : TUniversalImage;  
var
    x, y : Integer;
begin
    Result := TUniversalImage.Create(Image.Width, Image.Height);
    for x := 0 to Image.Width-1 do
        for y := 0 to Image.Height-1 do
            Result.DirectColor[x, y] := Image.DirectColor[x, Image.Height-y-1];
end;
    
function CreateMirrorImage3(Image : TUniversalImage) : TUniversalImage;  
var
    x, y : Integer;
begin
    Result := TUniversalImage.Create(Image.Width, Image.Height);
    for x := 0 to Image.Width-1 do
        for y := 0 to Image.Height-1 do
            Result.DirectColor[x, y] := Image.DirectColor[Image.Width-x-1, Image.Height-y-1];
end;
    
procedure LoadSamples;

    procedure LoadSample(const Verdict : Boolean; const FileName : AnsiString);
    var
        image : TUniversalImage;
        c : Integer;
    begin
        image := TUniversalImage.CreateEmpty;
        image.LoadFromFile(FileName);
        {$IfDef FitSize}
        if Image.Width < NeuronWidth then
            NeuronWidth := Image.Width;
        if Image.Height < NeuronHeight then
            NeuronHeight := Image.Height;
        {$EndIf}
        c := Length(Samples);
        SetLength(Samples, c+4);
        Samples[c].Image := image;
        Samples[c].Verdict := Verdict;
        
        Samples[c+1].Image := CreateMirrorImage1(image);
        Samples[c+1].Verdict := Verdict;
        Samples[c+2].Image := CreateMirrorImage2(image);
        Samples[c+2].Verdict := Verdict;
        Samples[c+3].Image := CreateMirrorImage3(image);
        Samples[c+3].Verdict := Verdict;
    end;

var
    i, c : Integer;
    s : AnsiString;
    v : Boolean;
begin
    c := ParamCount;
    v := False;
    SetLength(Samples, 0);
    
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

end; 

procedure FreeSamples;
var
    i : Integer;
begin
    for i := 0 to Length(Samples)-1 do
        Samples[i].Image.Free;
    SetLength(Samples, 0);
end;

var
    Neuron : TNeuron;
    
procedure SaveToIni(FileName : AnsiString = '~/.seedsorter/config.ini');
var
    ConfigFile : TIniFile;
    TablePath, ImgPath : AnsiString;
    FS : TFileStream;
    Img : TUniversalImage;
begin
    FileName := StringReplace(FileName, '~/', GetUserDir, []);
    ConfigFile := TIniFile.Create(FileName);

    TablePath := ExtractFilePath(FileName) + 'Neuron.bin';
    ImgPath := ExtractFilePath(FileName) + 'map.bmp';
    ConfigFile.WriteString('Global', 'NeuronPath', TablePath);
    ConfigFile.Free;
    FS := TFileStream.Create(TablePath, fmCreate);
    Neuron.SaveToStream(FS);
    FS.Free;
    
    Img := Neuron.CreateMap;
    Img.SaveToFile(ImgPath);
    Img.Free;
end;
   
begin    
    LoadSamples;
    
    {$IfDef FitSize}
    Dec(NeuronWidth);
    Dec(NeuronHeight);
    {$endif}
    
    Writeln('Learning for size: ', NeuronWidth, 'x', NeuronHeight);
    Neuron := TNeuron.Create(NeuronWidth, NeuronHeight);
    //Neuron.AddRandomState;
    Writeln(Neuron.Learn(Samples, 0.1, 3000, True));
    SaveToIni();
    
    Neuron.Free;    
    
    FreeSamples;
    
    Writeln('Done');
end.


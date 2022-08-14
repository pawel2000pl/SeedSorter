program Demo;

{$Mode ObjFpc}
//{$Define FitSize}

uses
    cthreads, SysUtils, Classes, FPImage, UniversalImage, math, IniFiles, FeedForwardNet, VectorizeImage;
    
type
    TSampleImage = record
        Image : TUniversalImage;
        Name : AnsiString;
        Verdict : Boolean;
    end;
    
var
    Samples : array of TSampleImage;
    InputImageWidth : Integer = 32;
    InputImageHeight : Integer = 32;

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
        if Image.Width < InputImageWidth then
            InputImageWidth := Image.Width;
        if Image.Height < InputImageHeight then
            InputImageHeight := Image.Height;
        {$EndIf}
        c := Length(Samples);
        SetLength(Samples, c+4);
        Samples[c].Image := image;
        Samples[c].Verdict := Verdict;
        Samples[c].Name := FileName;
        
        Samples[c+1].Image := CreateMirrorImage1(image);
        Samples[c+1].Verdict := Verdict;
        Samples[c+1].Name := FileName;
        Samples[c+2].Image := CreateMirrorImage2(image);
        Samples[c+2].Verdict := Verdict;
        Samples[c+2].Name := FileName;
        Samples[c+3].Image := CreateMirrorImage3(image);
        Samples[c+3].Verdict := Verdict;
        Samples[c+3].Name := FileName;
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
    Writeln('Found ', Length(Samples), ' samples.');
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
    net : TFeedForwardNet;
    Samples2 : array of TDataVector;
    Outputs2 : array of TDataVector;
    
procedure SaveToIni(FileName : AnsiString = '~/.seedsorter/config.ini');
var
    ConfigFile : TIniFile;
    NetPath, ConfusionPath : AnsiString;
    FS : TFileStream;
    ts : TStringList;
begin
    FileName := StringReplace(FileName, '~/', GetUserDir, []);
    ConfigFile := TIniFile.Create(FileName);

    NetPath := ExtractFilePath(FileName) + 'Net.bin';
    ConfusionPath := ExtractFilePath(FileName) + 'confusion.html';
    ConfigFile.WriteString('Global', 'NetPath', NetPath);
    ConfigFile.WriteInteger('Global', 'InputImageWidth', InputImageWidth);
    ConfigFile.WriteInteger('Global', 'InputImageHeight', InputImageHeight);
    ConfigFile.Free;
    
    FS := TFileStream.Create(NetPath, fmCreate);
    net.SaveToStream(FS);
    FS.Free;
    
    ts := TStringList.Create;
    ts.text := ConfusionMatrixToHtml(net.ConfusionMatrix(Samples2, Outputs2));
    ts.SaveToFile(ConfusionPath);
    ts.Free;
end;


var
    i, epoch : Integer;
    v, vn : Double;
    bestNet : TMemoryStream;
    t : QWord;
begin    
    Randomize;
    LoadSamples;
    
    {$IfDef FitSize}
    Dec(InputImageWidth);
    Dec(InputImageHeight);
    {$endif}
    
    Writeln('Learning for size: ', InputImageWidth, 'x', InputImageHeight);    
    net := TFeedForwardNet.Create([InputImageWidth*InputImageHeight*3, 16, 2]);
    net.RandomAboutOne;

    SetLength(Samples2, Length(Samples));
    SetLength(Outputs2, Length(Samples));
    t := GetTickCount64;
    for i := 0 to Length(Samples)-1 do
    begin
        Samples2[i] := PrepareImage(Img2Vector(@Samples[i].Image.GetColorFromHelper, 0, 0, Samples[i].Image.Width-1, Samples[i].Image.Height-1, InputImageWidth, InputImageHeight), InputImageWidth, InputImageHeight);
        net.ProcessData(Samples2[i]); //only for timing
        Outputs2[i] := [ifthen(Samples[i].Verdict, 1, 0), ifthen(Samples[i].Verdict, 0, 1)];
    end;
    t := GetTickCount64 - t;
    Writeln('Prepared ', Length(Samples), ' samples in ', t, 'ms. Expected APS = ', 1000*Length(Samples)/t:2:4);

    i := 0;
    epoch := 0;
    v := 0;
    bestNet := TMemoryStream.Create;
    net.SaveToStream(bestNet);
    repeat
        net.AsyncStep(Samples2, Outputs2, 0.03, @net.LearnStep);
        vn := net.CheckNetwork(Samples2, Outputs2, @SumOfRoundedDifferences);
        if v < vn then
        begin
            i := 0;
            v := vn;
            bestNet.Free;
            bestNet := TMemoryStream.Create;
            net.SaveToStream(bestNet);
        end;
        Inc(i);
        Inc(epoch);
        writeln('Epoch: ', epoch, ', accuracy: ', vn:2:4);
    until ((v > 0.96) and (i > 64)) or (epoch > 16384);
    if v > vn then
    begin
        net.Free;
        bestNet.Position := 0;
        net := TFeedForwardNet.Create(bestNet);
    end;
    bestNet.Free;

    Writeln;
    writeln(AnsiString(net.GetDataDerivate([Samples2[0], Samples2[High(Samples)]], 1e-3)));
    writeln(AnsiString(net.GetDataDerivate([Samples2[0], Samples2[High(Samples)]], 1e-6)));
    writeln(AnsiString(net.GetDataDerivate([Samples2[0], Samples2[High(Samples)]], 1e-9)));

    SaveToIni();
    net.Free;
           
    FreeSamples;
    
    Writeln('Done');
end.


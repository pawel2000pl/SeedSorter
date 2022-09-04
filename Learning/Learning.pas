program Demo;

{$Mode ObjFpc}

uses
    cthreads, SysUtils, Classes, UniversalImage, math, IniFiles, FeedForwardNet, VectorizeImage, SampleLoader, Teacher;

var
    net : TFeedForwardNet;
    VectorSamples : array of TDataVector;
    VectorOutputs : array of TDataVector;
    
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
    ts.text := ConfusionMatrixToHtml(net.ConfusionMatrix(VectorSamples, VectorOutputs));
    ts.SaveToFile(ConfusionPath);
    ts.Free;
end;


var
    i : Integer;
    t : QWord;
begin    
    Randomize;
    Samples := [];
    LoadSamples;
    
    Writeln('Learning for size: ', InputImageWidth, 'x', InputImageHeight);    
    net := TFeedForwardNet.Create([InputImageWidth*InputImageHeight*3, 16, 9, 2]);
    net.RandomAboutOne;

    SetLength(VectorSamples, Length(Samples));
    SetLength(VectorOutputs, Length(Samples));
    t := GetTickCount64;
    for i := 0 to Length(Samples)-1 do
    begin
        VectorSamples[i] := PrepareImage(Img2Vector(@Samples[i].Image.GetColorFromHelper, 0, 0, Samples[i].Image.Width-1, Samples[i].Image.Height-1, InputImageWidth, InputImageHeight), InputImageWidth, InputImageHeight);
        net.ProcessData(VectorSamples[i]); //only for timing
        VectorOutputs[i] := [ifthen(Samples[i].Verdict, 1, 0), ifthen(Samples[i].Verdict, 0, 1)];
    end;
    t := GetTickCount64 - t;
    Writeln('Prepared ', Length(Samples), ' samples in ', t, 'ms. Expected PPS = ', 1000*Length(Samples)/t:2:4, ' (per thread)');

    TeachNet(net, VectorSamples, VectorOutputs, 0.03, 0.3);

    Writeln;
    writeln(AnsiString(net.GetDataDerivate([VectorSamples[0], VectorSamples[High(Samples)]], 1e-3)));
    writeln(AnsiString(net.GetDataDerivate([VectorSamples[0], VectorSamples[High(Samples)]], 1e-6)));
    writeln(AnsiString(net.GetDataDerivate([VectorSamples[0], VectorSamples[High(Samples)]], 1e-9)));

    SaveToIni();
    net.Free;
           
    FreeSamples;
    
    Writeln('Done');
end.


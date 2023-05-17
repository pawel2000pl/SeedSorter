program Learning;

{$Mode ObjFpc}
{$I defines.inc}

uses
    cthreads, ctypes, SysUtils, Classes, 
    UniversalImage, math, IniFiles, FeedForwardNet, 
    VectorizeImage, SampleLoader, NetTeacher;

const 
    DefaultConfigFileName = '~/.seedsorter/config.ini';

var
    VectorSamples : array of TDataVector;
    VectorOutputs : array of TDataVector;
    
procedure SaveToIni(net: TFeedForwardNet; FileName : AnsiString);
var
    ConfigFile : TIniFile;
    NetPath, ConfusionPath : AnsiString;
    FS : TFileStream;
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
    
    StringToFile(ConfusionMatrixToHtml(net.ConfusionMatrix(VectorSamples, VectorOutputs)), ConfusionPath);
end;

var
    i : Integer;
    t : QWord;
    net : TFeedForwardNet;
    NetDimenstions : array of Integer;
    Teacher : TNetwokTeacher;
begin    
    Randomize;
    Samples := [];
    LoadSamples;
    NetDimenstions := [InputImageWidth*InputImageHeight*3, 6, 6, 2];
    
    Writeln('Learning for size: ', InputImageWidth, 'x', InputImageHeight);    
    net := TFeedForwardNet.Create(NetDimenstions);
    net.RandomAboutOne;

    SetLength(VectorSamples, Length(Samples));
    SetLength(VectorOutputs, Length(Samples));
    t := GetTickCount64;
    for i := 0 to Length(Samples)-1 do
    begin
        {$ifdef PREPARING_IMAGE}
        VectorSamples[i] := PrepareImage(Img2Vector(@Samples[i].Image.GetColorFromHelper, 0, 0, Samples[i].Image.Width-1, Samples[i].Image.Height-1, InputImageWidth, InputImageHeight), InputImageWidth, InputImageHeight);
        {$else}
        VectorSamples[i] := Img2Vector(@Samples[i].Image.GetColorFromHelper, 0, 0, Samples[i].Image.Width-1, Samples[i].Image.Height-1, InputImageWidth, InputImageHeight);
        {$endif}
        net.ProcessData(VectorSamples[i]); //only for timing
        VectorOutputs[i] := [ifthen(Samples[i].Verdict, 0.9999, 0.0001), ifthen(Samples[i].Verdict, 0.0001, 0.9999)];
    end;
    t := GetTickCount64 - t;
    Writeln('Prepared ', Length(Samples), ' samples in ', t, 'ms. Expected PPS = ', 1000*Length(Samples)/t:2:4, ' (per thread)');

    Teacher := TNetwokTeacher.Create(VectorSamples, VectorOutputs, 0.1, 0.03, @SumOfSquaresOfDifferences, net);
    Teacher.Learn();
    Teacher.Free;
    SaveToIni(net, DefaultConfigFileName); 

    Writeln;
    writeln(AnsiString(net.GetDataDerivate([VectorSamples[0], VectorSamples[High(Samples)]], 1e-3)));
    writeln(AnsiString(net.GetDataDerivate([VectorSamples[0], VectorSamples[High(Samples)]], 1e-6)));
    writeln(AnsiString(net.GetDataDerivate([VectorSamples[0], VectorSamples[High(Samples)]], 1e-9)));
    writeln;
    writeln('Accuracy');
    writeln(net.CheckNetwork(VectorSamples, VectorOutputs, @SameMaxIndex):2:4);

    FreeSamples;
    
    Writeln('Done');
end.


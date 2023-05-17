unit SampleLoader;

{$Mode ObjFpc}

interface

uses 
    SysUtils, FPImage, UniversalImage, ImageAugmentation, PostPreOperations;

type
    TSampleImage = record
        Image : TUniversalImage;
        Name : AnsiString;
        Verdict : Boolean;
    end;

var
    Samples : array of TSampleImage;
    InputImageWidth : Integer = 28;
    InputImageHeight : Integer = 32;

procedure LoadSamples;
procedure FreeSamples;
    
implementation

function DeformImage(image : TUniversalImage; mode : Integer) : TUniversalImage;
var
    tmps : array of TUniversalImage;
    tmpIndex, i : Integer;
begin
    tmps := [];
    SetLength(tmps, 8);
    tmpIndex := 0;

    case mode mod 4 of
        0: tmps[PostInc(tmpIndex)] := image;
        1: tmps[PostInc(tmpIndex)] := CreateMirrorImage1(image);
        2: tmps[PostInc(tmpIndex)] := CreateMirrorImage2(image);
        3: tmps[PostInc(tmpIndex)] := CreateMirrorImage3(image);
    end;

    if (mode >= 4) and (mode mod 16 < 8) or (mode mod 8 >= 4) then
      tmps[PostInc(tmpIndex)] := AddNoiseToImage(tmps[tmpIndex-1], 3/256);

    if mode mod 16 >= 8 then  
      tmps[PostInc(tmpIndex)] := AddTrigFilterToImage(tmps[tmpIndex-1], 
        RandomTrigFilter(0, 1/16, 1.8, 1.5),
        RandomTrigFilter(0, 1/16, 1.8, 1.5),
        RandomTrigFilter(0, 1/16, 1.8, 1.5));

    Result := tmps[PreDec(tmpIndex)];
    for i := low(tmps) to high(tmps) do
      if (tmps[i] <> nil) and (tmps[i] <> image) and (tmps[i] <> Result) then
        tmps[i].Free;
end;

procedure LoadSample(const Verdict : Boolean; const FileName : AnsiString);
const
    ReplicationCount = 64;
var
    image : TUniversalImage;
    i, c : Integer;
begin
    image := TUniversalImage.CreateEmpty;
    image.LoadFromFile(FileName);
    
    c := Length(Samples);
    SetLength(Samples, c+ReplicationCount);

    for i := 0 to ReplicationCount-1 do
    begin
        Samples[c+i].Image := DeformImage(image, i);
        Samples[c+i].Verdict := Verdict;
        Samples[c+i].Name := FileName;
    end;
    
end;

procedure LoadSamples;
var
    i, c : Integer;
    s : AnsiString;
    v : Boolean;
begin
    Writeln('Loading samples...');
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

end.

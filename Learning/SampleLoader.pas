unit SampleLoader;

{$Mode ObjFpc}

interface

uses 
    SysUtils, FPImage, UniversalImage, MirrorImage;

type
    TSampleImage = record
        Image : TUniversalImage;
        Name : AnsiString;
        Verdict : Boolean;
    end;

var
    Samples : array of TSampleImage;
    InputImageWidth : Integer = 24;
    InputImageHeight : Integer = 32;

procedure LoadSamples;
procedure FreeSamples;
    
implementation

function DeformImage(image : TUniversalImage; mode : Integer) : TUniversalImage;
var
    img : TUniversalImage;
begin
    case mode of
        0: Result := image;
        1: Result := CreateMirrorImage1(image);
        2: Result := CreateMirrorImage2(image);
        3: Result := CreateMirrorImage3(image);
        else
        begin
            img := DeformImage(image, mode mod 4);
            Result := AddNoiseToImage(img);
            if image <> img then
                img.Free;
        end;
    end;
end;

procedure LoadSample(const Verdict : Boolean; const FileName : AnsiString);
const
    ReplicationCount = 16;
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

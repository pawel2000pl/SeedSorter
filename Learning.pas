program Learning;

{$mode objfpc}

uses
    SysUtils, Classes, Selector, FPImage, UniversalImage;

var
    Image1, Image2 : TUniversalImage;    
    Samples : TSampleArray;
    Colors : TColorBayesTable;
    i : Integer;
    FS : TFileStream;
begin
    FillByte(Samples, SizeOf(Samples), 0);
        writeln('Loading');

    i := 1;
    while FileExists('learning/true/'+IntToStr(i)+'.bmp') do    
    begin    
        Image1 := TUniversalImage.CreateEmpty;
        Image1.LoadFromFile('learning/true/'+IntToStr(i)+'.bmp');
        Image2 := PrepareImage(Image1);
        AddSample(true, Image2, Samples);
        Image2.Free;
        Image1.Free;
        inc(i);
    end;    
    
    i := 1;
    while FileExists('learning/false/'+IntToStr(i)+'.bmp') do    
    begin     
        Image1 := TUniversalImage.CreateEmpty;
        Image1.LoadFromFile('learning/false/'+IntToStr(i)+'.bmp');
        Image2 := PrepareImage(Image1);
        AddSample(false, Image2, Samples);
        Image2.Free;
        Image1.Free;
        inc(i);
    end;    

    writeln('Learning');
    
    CreateColorBayesTable(Samples, Colors);
    FS := TFileStream.Create('conf/Table.bin', fmCreate);
    FS.WriteBuffer(Colors, SizeOf(Colors));
    FS.Free;

    Writeln('Done.');
end.

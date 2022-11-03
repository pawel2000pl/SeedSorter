program Demo;

{$mode objfpc}

uses
    SysUtils, Classes, Selector, FPImage, UniversalImage;


var
    Image1, Image2 : TUniversalImage;
    i : LongWord;
    t : QWord;
    m : Double;
    Samples : TSampleArray;
    Colors : TColorBayesTable;
    FS : TFileStream;
    pb : PDouble;
begin
    FillByte(Samples, SizeOf(Samples), 0);
    
    t := GetTickCount64;

    writeln('Loading');
    
    for i := 1 to 18 do
    begin    
        Image1 := TUniversalImage.CreateEmpty;
        Image1.LoadFromFile('learning/true/'+IntToStr(i)+'.bmp');
        Image2 := PrepareImage(Image1);
        AddSample(true, Image1, Samples);
        Image2.Free;
        Image1.Free;
    end;    
    for i := 1 to 18 do
    begin    
        Image1 := TUniversalImage.CreateEmpty;
        Image1.LoadFromFile('learning/false/'+IntToStr(i)+'.bmp');
        Image2 := PrepareImage(Image1);
        AddSample(false, Image1, Samples);
        Image2.Free;
        Image1.Free;
    end;    

    writeln('Learning');
    
    CreateColorBayesTable(Samples, Colors);
    
    {
    
    FS := TFileStream.Create('conf/Table.bin', fmOpenRead);
    FS.ReadBuffer(Colors, SizeOf(Colors));
    FS.Free;
    }
    Writeln('Testing');
    
    for i := 1 to 50 do
    begin    
        Image1 := TUniversalImage.CreateEmpty;
        Image1.LoadFromFile('tests/input/'+IntToStr(i)+'.bmp');
        
        Image2 := PrepareImage(Image1);
        Image2.SaveToFile('tests/prepared/'+IntToStr(i)+'.bmp');

        m := Mark(Image1, Colors, DefRect);
        writeln(i, #9, m:2:4, #9, m>0.1);
                
        Image1.SaveToFile('tests/results/'+IntToStr(i)+'.bmp');
        Image2.Free;
        Image1.Free;
    end;    
    
end.
    

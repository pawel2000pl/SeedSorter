program SeedSelector;

{$mode objfpc}

uses
    SysUtils, Classes, IniFiles, Selector, FPImage, UniversalImage, Incrementations;

const
    TempPath = '/dev/shm/';

function FileName(const i : Integer) : AnsiString;
begin
    FileName := TempPath + IntToStr(i) + '.jpg';
end;
    
var
    Colors : TColorBayesTable;
    FS : TFileStream;
    i : Integer;
    m, border : Double;
    Image, PreparedImage : TUniversalImage;

    Rect : TDoubleRect;
    Configuration : TIniFile;
begin

    FS := TFileStream.Create('conf/Table.bin', fmOpenRead);
    FS.ReadBuffer(Colors, SizeOf(Colors));
    FS.Free;

    Configuration := TIniFile.Create('conf/configuration.ini');;
    Rect.Left := StrToFloat(Configuration.ReadString('Configuration', 'Left', '0'));
    Rect.Top := StrToFloat(Configuration.ReadString('Configuration', 'Top', '0'));
    Rect.Right := StrToFloat(Configuration.ReadString('Configuration', 'Right', '1'));
    Rect.Bottom := StrToFloat(Configuration.ReadString('Configuration', 'Bottom', '1'));
    border :=  StrToFloat(Configuration.ReadString('Detect', 'Border', '0.1'));
    Configuration.Free;

    i := 1;
    Image := TUniversalImage.CreateEmpty;

    repeat
        if FileExists(FileName(i)) and FileExists(FileName(i+1)) then
        begin
            if not FileExists(FileName(i+2)) then
            begin    
                Image.LoadFromFile(FileName(i));
                PreparedImage := PrepareImage(Image);

                m := Mark(PreparedImage, Colors, Rect);
                //writeln(i, #9, m:2:8, #9, m>border);

                If m>border then
                    writeln(1)
                else
                    writeln(0);
                PreparedImage.Free;
            end;
            DeleteFile(FileName(i));
            inc(i);
        end;
    until FileExists(TempPath + 'CloseSeedSelector');    

    
    While FileExists(FileName(i)) do
        DeleteFile(FileName(PostInc(i)));
    DeleteFile(TempPath + 'CloseSeedSelector');

    Image.Free;

end.

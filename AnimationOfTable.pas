program AanimationOfTable;
{$mode objfpc}

//run: instantfpc AnimationOfTable.pas && echo y | ffmpeg -r 30 -i /dev/shm/image%d.png /dev/shm/video.mp4
//or: instantfpc AnimationOfTable.pas && echo y | ffmpeg -r 30 -i /dev/shm/image%d.png -vf "fps=30,scale=320:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" /dev/shm/video.gif

uses
    SysUtils, Classes, math, FPImage, Selector, UniversalImage;

var
    FS : TFileStream;
    Image : TUniversalImage;
    Colors : TColorTable;
    r, g, b : Integer;
    i, x, y : Integer;
begin
    
    FS := TFileStream.Create('conf/Table.bin', fmOpenRead);
    FS.ReadBuffer(Colors, SizeOf(Colors));
    FS.Free;

    Image := TUniversalImage.Create(256+64,256+32);
    
    for x := 0 to Image.Width-1 do
        for y := 0 to Image.Height-1 do
            Image.DirectColor[x, y] := FpColor($FFFF, $FFFF, $FFFF, 0);

    for b := 0 to 255 do
        for i := 40 to 56 do
            Image.DirectColor[i, b+32] := FPColor(0, 0, b shl 8, 0);
       
    for g := 0 to 255 do
        for i := 8 to 24 do
            Image.DirectColor[g+64, i] := FPColor(0, g shl 8, 0, 0);

    for r := 0 to 255 do
    begin
        Image.DirectColor[8, r+32] := FPColor(r shl 8, 0, 0, 0);
        Image.DirectColor[24, r+32] := FPColor(r shl 8, 0, 0, 0);
        Image.DirectColor[9, r+32] := FPColor(r shl 8, 0, 0, 0);
        Image.DirectColor[23, r+32] := FPColor(r shl 8, 0, 0, 0);
    end;

    for r := 0 to 255 do
    begin    

        for i := 10 to 22 do
            Image.DirectColor[i, r+32] := FPColor(r shl 8, 0, 0, 0);
        
        for g := 0 to 255 do
            for b := 0 to 255 do
                case ifthen(abs(Colors[r, g, b]+0.01)<0.02, 0, sign(Colors[r, g, b])) of
                    -1: Image.DirectColor[g+64, b+32] := FPColor(floor(-$FFFF*Colors[r, g, b]),0,0,0);
                    0: Image.DirectColor[g+64, b+32] := FPColor(0,0,$FFFF,0);                    
                    1: Image.DirectColor[g+64, b+32] := FPColor(0, floor($FFFF*Colors[r, g, b]),0,0);
                end;
        writeln(r);
        Image.SaveToFile('/dev/shm/image'+inttostr(r)+'.png', false);
    end;    
    
    Image.Free;

end.

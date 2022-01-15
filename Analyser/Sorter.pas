program Sorter;

{$Mode ObjFpc}

uses
    cThreads, SysUtils, Analyser, BaseUnix, Unix;

const 
    TerminateFile = '/dev/shm/TerminateSeedSorter';
    MaxErrorCount = 3;

function FreeAnalyser(p : Pointer) : PtrInt;
begin
    (TObject(p^) as TSeedAnalyser).Free;
    TObject(p^) := nil;
    writeln(StdErr, 'Seed analiser disposed');
    Exit(0);
end;
    
var
    SeedAnalyser : TSeedAnalyser;
    time, newTime, fpc, apc : QWord;
    errorCount : QWord;
    
begin
    
    if FileExists(TerminateFile) then
    begin
        DeleteFile(TerminateFile);    
        Exit;
    end;
    
    SeedAnalyser := TSeedAnalyser.Create(GetUserDir+'.seedsorter/config.ini');
    time := GetTickCount64;
    Writeln(StdErr, 'Starting at: ', time);
    errorCount := 0;
    
    repeat
        writeln(SeedAnalyser.GetStatus);
        Flush(StdOut);
        newTime := GetTickCount64;
        if newTime - time >= 1000 then
        begin
            apc := SeedAnalyser.GetAnalicysCount(True);
            fpc := SeedAnalyser.GetFrameCount(True);
            write(StdErr, '[', time, ']'#9);
            Write(StdErr, 'APS=', 1000*apc/((newTime-time)*SeedAnalyser.AreaCount):2:2, #9);
            Write(StdErr, 'FPS=', 1000*fpc/(newTime-time):2:2, #9);
            writeln(StdErr);
            Flush(StdErr);
            time := newTime;
            
            if (fpc = 0) or (apc = 0) then
                Inc(errorCount)
            else
                errorCount := 0;
        end;
        
        sleep(5);
    until FileExists(TerminateFile) or (errorCount >= MaxErrorCount);

    time := GetTickCount64;
    BeginThread(@FreeAnalyser, @SeedAnalyser);
    while (GetTickCount64 - time < 1000) and (SeedAnalyser <> nil) do sleep(1);

    if errorCount >= MaxErrorCount then
    begin
        Writeln(StdErr, 'Restart at: ', GetTickCount64);
        Flush(StdOut);
        Flush(StdErr);
        FpExecV(ParamStr(0), nil);           
    end;
    
    if FileExists(TerminateFile) then
        DeleteFile(TerminateFile);    

    Writeln(StdErr, 'Terminate at: ', GetTickCount64);
end.

program Sorter;

{$Mode ObjFpc}

uses
    cThreads, SysUtils, Analyser, BaseUnix, v4l1;

const 
    TerminateFile = '/dev/shm/TerminateSeedSorter';
    MaxErrorCount = 3;

function FreeAnalyser(p : Pointer) : PtrInt;
begin
    (TObject(p^) as TSeedAnalyser).Free;
    TObject(p^) := nil;
    writeln(StdErr, 'Seed analiser has been disposed');
    Exit(0);
end;

function FreeV4L1(p : Pointer) : PtrInt;
begin
    v4l1.FinitV4L1();
    writeln(StdErr, 'V4L1 has been unloaded');
    boolean(p^) := True;
    Exit(0);
end;

procedure EmergencyRestart();
var
  finished: Boolean;
  time : QWord;
begin
  finished := False;
  time := GetTickCount64;
  BeginThread(@FreeV4L1, @finished);
  while (GetTickCount64 - time < 1000) and (not finished) do sleep(1);

  Writeln(StdErr, 'Restart at: ', GetTickCount64);
  Flush(StdOut);
  Flush(StdErr);
  FpExit(1);  
end;
    
var
    SeedAnalyser : TSeedAnalyser;
    time, newTime, fpc, apc : QWord;
    errorCount : QWord;
    // analises per second, processed [areas] per second, frames per second
    aps, pps, fps : Double;
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
            apc := SeedAnalyser.GetAnalysisCount(True);
            fpc := SeedAnalyser.GetFrameCount(True);
            pps := 1000*apc/(newTime-time);
            fps := 1000*fpc/(newTime-time);
            aps := pps / SeedAnalyser.AreaCount;
            write(StdErr, '[', time, ']'#9);
            Write(StdErr, 'PPS=', pps:2:2, #9);
            Write(StdErr, 'APS=', aps:2:2, #9);
            Write(StdErr, 'FPS=', fps:2:2, #9);
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
      EmergencyRestart();
    
    if FileExists(TerminateFile) then
        DeleteFile(TerminateFile);    

    Writeln(StdErr, 'Terminate at: ', GetTickCount64);

    FpExit(0);
end.

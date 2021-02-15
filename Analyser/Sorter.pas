program Sorter;

{$Mode ObjFpc}

uses
    cThreads, SysUtils, Analyser;

const 
    TerminateFile = '/dev/shm/TerminateSeedSorter';
    
var
    SeedAnalyser : TSeedAnalyser;
begin
    SeedAnalyser := TSeedAnalyser.Create(GetUserDir+'.seedsorter/config.ini');

    repeat
        writeln(SeedAnalyser.GetStatus);
        sleep(5);
    until FileExists(TerminateFile);

    SeedAnalyser.Free;

    DeleteFile(TerminateFile);
end.

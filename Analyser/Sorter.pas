program Sorter;

{$Mode ObjFpc}

uses
    cThreads, SysUtils, Analyser;

var
    SeedAnalyser : TSeedAnalyser;
    i : Integer;
begin
    SeedAnalyser := TSeedAnalyser.Create(GetUserDir+'.seedsorter/config.ini');


    for i := 0 to 1000 do
    begin
        writeln(SeedAnalyser.GetStatus);
        sleep(10);
    end;

    SeedAnalyser.Free;
end.

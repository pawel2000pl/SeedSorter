program CreateService;

{$Mode ObjFpc}

uses
    SysUtils;

begin
    writeln('[Unit]');
    writeln('Description=SeedSorter starter and stoper through GPIO');
    writeln('After=network.target');
    writeln('StartLimitIntervalSec=0');
    writeln;
    
    writeln('[Service]');
    writeln('Type=simple');
    writeln('Restart=always');
    writeln('RestartSec=1');
    writeln('User=', GetEnvironmentVariable('USER'));
    writeln('ExecStart=', ParamStr(0), '/'); //todo
    writeln;
    
    writeln('[Install]');
    writeln('WantedBy=multi-user.target');

    
end.

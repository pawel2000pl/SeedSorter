#!/bin/bash
echo \
"[Unit]
Description=SeedSorter starter and stoper through GPIO
After=network.target
StartLimitIntervalSec=0

[Service]
Type=simple
Restart=always
RestartSec=1
User=`whoami`
ExecStart=$HOME/.seedsorter/Service.sh

[Install]
WantedBy=multi-user.target
"

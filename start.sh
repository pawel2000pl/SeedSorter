#!/bin/bash
instantfpc 'SeedSelector.pas' &
echo 'To close: Ctrl+Z then run "killall ffmpeg" and then "fg"'
sleep 5s
ffmpeg -i '/dev/video0' '/dev/shm/%d.jpg' 2> '/dev/null'
touch '/dev/shm/CloseSeedSelector'

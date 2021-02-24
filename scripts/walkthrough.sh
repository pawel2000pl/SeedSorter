#!/bin/bash

if [ -e "walkthrough" ];
then
    cd ..
fi

cat "scripts/walkthrough/step1.txt"
make configure &> /dev/null
make learn
cat "scripts/walkthrough/step2.txt"

./Analyser/Sorter | ./Gpio/GpioController &

sleep 30s
touch '/dev/shm/TerminateSeedSorter'



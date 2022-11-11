#!/bin/bash

for i in 2 3 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 25 26 27;
do
	echo $i > "/sys/class/gpio/export"
done

sleep 0.4s

for i in 2 3 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 25 26 27;
do
	echo out > "/sys/class/gpio/gpio$i/direction" 
done

sleep 0.4s

for j in `seq 1 100`;
do
    for i in 2 3 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 25 26 27;
    do
        echo 1 > "/sys/class/gpio/gpio$i/value"
    done
    sleep 0.025s
    for i in 2 3 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 25 26 27;
    do
        echo 0 > "/sys/class/gpio/gpio$i/value"
    done
    sleep 0.025s
done;


for i in 2 3 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 25 26 27;
do
	echo $i > "/sys/class/gpio/unexport"
done

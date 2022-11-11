#!/bin/bash

for i in 2 3 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 25 26 27;
do
	echo "Testing gpio$i"
	echo $i > "/sys/class/gpio/export"
	sleep 0.25s
	echo out > "/sys/class/gpio/gpio$i/direction" 
	sleep 0.25s
	for j in `seq 1 30`;
	do
		sleep 0.01s
		echo 1 > "/sys/class/gpio/gpio$i/value"
		sleep 0.01s
		echo 0 > "/sys/class/gpio/gpio$i/value"
		sleep 0.01s
	done
	echo $i > "/sys/class/gpio/unexport"
done


exit

2=Electromagnet
3=Electromagnet
4=StatusLED
5=Electromagnet
6=Electromagnet
7=Electromagnet
8=Electromagnet
9=Electromagnet
10=Electromagnet
11=Electromagnet
12=Electromagnet
13=Electromagnet
14=Electromagnet
15=Electromagnet
16=Electromagnet
17=Electromagnet
18=Electromagnet
19=Electromagnet
20=Electromagnet
21=Electromagnet
22=Electromagnet
23=StartButton
24=StopButton
25=Electromagnet
26=Electromagnet
27=Electromagnet

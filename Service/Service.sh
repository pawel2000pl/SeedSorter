#!/bin/bash

MY_PATH="`dirname \"$0\"`"              
MY_PATH="`( cd \"$MY_PATH\" && pwd )`" 
if [ -z "$MY_PATH" ] ; then
  MY_PATH="/home/pi/.seedsorter"
fi
echo "$MY_PATH"

#MY_PATH="/home/pi/.seedsorter"

 sudo ip address add 192.168.2.1/24 dev `ip address show | grep -P -o "e[tn][hp][0-9]" | head -n 1`

CONFIGURATION_PATH="$MY_PATH/GpioConfig.ini"

#CONFIGURATION_PATH="./GpioConfig.ini"

START_BUTTON=`cat "$CONFIGURATION_PATH" | grep StartButton | cut -f 1 -d "=" | head -n 1`
STOP_BUTTON=`cat "$CONFIGURATION_PATH" | grep StopButton | cut -f 1 -d "=" | head -n 1`

echo $START_BUTTON > /sys/class/gpio/export
echo $STOP_BUTTON > /sys/class/gpio/export

START_BUTTON_PATH="/sys/class/gpio/gpio$START_BUTTON"
STOP_BUTTON_PATH="/sys/class/gpio/gpio$STOP_BUTTON"

sleep 1s

echo in > "$START_BUTTON_PATH/direction"
echo in > "$STOP_BUTTON_PATH/direction"

sleep 1s

#echo Working…

while [ true ];
do
        
    if [ `cat "$START_BUTTON_PATH/value"` == 1 ];
    then
        $MY_PATH/Sorter | $MY_PATH/GpioController &
        #echo Started
        
        while [ `cat "$STOP_BUTTON_PATH/value"` == 0 ];
        do
            sleep 0.1s
        done
        
        #echo Terminated
        touch '/dev/shm/TerminateSeedSorter'
        sleep 1s
    fi
    
    if [ `cat "$STOP_BUTTON_PATH/value"` == 1 ];
    then
        sleep 3s            
        if [ `cat "$STOP_BUTTON_PATH/value"` == 1 ];
        then
            #echo Shutdowning…
            touch '/dev/shm/TerminateSeedSorter'
            sleep 5s
            break
        fi
    fi
    sleep 0.1s
done

#terminating

echo $START_BUTTON > /sys/class/gpio/unexport
echo $STOP_BUTTON > /sys/class/gpio/unexport

sudo shutdown 0
#echo Shutdown

while ( true );  do sleep 1s; done

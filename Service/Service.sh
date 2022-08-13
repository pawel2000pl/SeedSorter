#!/bin/bash

MY_PATH="/home/"`whoami`"/.seedsorter"
cd $MY_PATH

sudo ip address add 192.168.2.1/24 dev `ip address show | grep -P -o "e[tn][hp][0-9]" | head -n 1`

CONFIGURATION_PATH="$MY_PATH/GpioConfig.ini"

START_BUTTON=`cat "$CONFIGURATION_PATH" | grep StartButton | cut -f 1 -d "=" | head -n 1`
STOP_BUTTON=`cat "$CONFIGURATION_PATH" | grep StopButton | cut -f 1 -d "=" | head -n 1`
STATUS_LED=`cat "$CONFIGURATION_PATH" | grep StatusLED | cut -f 1 -d "=" | head -n 1`

echo $START_BUTTON > /sys/class/gpio/export
echo $STOP_BUTTON > /sys/class/gpio/export
echo $STATUS_LED > /sys/class/gpio/export

START_BUTTON_PATH="/sys/class/gpio/gpio$START_BUTTON"
STOP_BUTTON_PATH="/sys/class/gpio/gpio$STOP_BUTTON"
STATUS_LED_PATH="/sys/class/gpio/gpio$STATUS_LED"

sleep 1s

echo in > "$START_BUTTON_PATH/direction"
echo in > "$STOP_BUTTON_PATH/direction"
echo out > "$STATUS_LED_PATH/direction"

sleep 1s

while [ true ];
do
    echo 1 > "$STATUS_LED_PATH/value"    
        
    if [ `cat "$START_BUTTON_PATH/value"` == 1 ];
    then
        $MY_PATH/Sorter | $MY_PATH/GpioController &
        
        while [ `cat "$STOP_BUTTON_PATH/value"` == 0 ];
        do
            echo 1 > "$STATUS_LED_PATH/value"    
            sleep 0.05s
            echo 0 > "$STATUS_LED_PATH/value"    
            sleep 0.05s
        done
        
        touch '/dev/shm/TerminateSeedSorter'
        sleep 1s
    fi
    
    if [ `cat "$STOP_BUTTON_PATH/value"` == 1 ];
    then
        sleep 3s            
        if [ `cat "$STOP_BUTTON_PATH/value"` == 1 ];
        then
            touch '/dev/shm/TerminateSeedSorter'
            sleep 5s
            killall -9 Sorter && killall -9 GpioController
            break
        fi
    fi
    sleep 0.1s
done

#terminating

echo $START_BUTTON > /sys/class/gpio/unexport
echo $STOP_BUTTON > /sys/class/gpio/unexport

for ((i=0;i<15;i++)); 
do
    echo 0 > "$STATUS_LED_PATH/value"    
    sleep 0.05s
    echo 1 > "$STATUS_LED_PATH/value"    
    sleep 0.05s
done    

sudo systemctl poweroff

while ( true ); do sleep 1s; done

#never do this
echo $STATUS_LED > /sys/class/gpio/unexport

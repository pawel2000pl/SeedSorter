#!/bin/bash

MY_PATH="`dirname \"$0\"`"              
MY_PATH="`( cd \"$MY_PATH\" && pwd )`" 
if [ -z "$MY_PATH" ] ; then
  MY_PATH="/home/pi/.seedsorter"
fi
echo "$MY_PATH"

MY_PATH="/home/pi/.seedsorter"

sudo ip address add 192.168.2.1/24 dev `ip address show | grep -P -o "e[tn][hp][0-9]" | head -n 1`

CONFIGURATION_PATH="$MY_PATH/GpioConfig.ini"
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

#TODO: main loop

#terminating

echo $START_BUTTON > /sys/class/gpio/unexport
echo $STOP_BUTTON > /sys/class/gpio/unexport

while ( true );  do sleep 1s; done

#!/bin/bash

DEVICES=`ip address show | cut -f 2 -d " " | cut -f 1 -d ":" | grep -P [0-9]+`
DEVICE_COUNT=`echo $DEVICES | wc -w`

if [ $DEVICE_COUNT -gt 1 ]
then
    echo "Available devices: "
    I=1
    for DEVICE in $DEVICES
    do
        echo $I $DEVICE
        I=`expr $I + 1`
    done
    echo "Enter the number 1 - $DEVICE_COUNT"
    read -p "> " CHOICE
    SELECTED_DEVICE=`echo $DEVICES | cut -f $CHOICE -d " "`
else
    SELECTED_DEVICE=$DEVICES
fi

if [ "$SELECTED_DEVICE" == "" ]
then
    echo "Error: Invaid number"
    exit
fi

echo "Selected device: $SELECTED_DEVICE"

sudo ip address add 192.168.2.2/24 dev $SELECTED_DEVICE
sshpass -p "seedsorter" ssh -XY pi@192.168.2.1 'cd SeedSorter && make configure'
sudo ip address del 192.168.2.2/24 dev $SELECTED_DEVICE

echo "Done"
exit

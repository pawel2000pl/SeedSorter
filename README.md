# Seed sorter
Program for sorting bean seeds
Warning: This software is for embedded use only!

How to run first time:

1. make all
2. make configure (save about 20-40 samples for rejection and for not rejection)
3. make learn

"make run" is curently unavailable but you can run `./Analyser/Sorter | ./Gpio/GpioController`

Software sends square signal (60Hz) on gpio pin when seed for rejection is in a selected area.

Photos of the machine in the future.

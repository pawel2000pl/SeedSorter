#!/bin/bash
mkdir -p ~/.seedsorter
ln -f -s "$PWD/Analyser/Sorter" ~/.seedsorter/Sorter
ln -f -s "$PWD/Gpio/GpioController" ~/.seedsorter/GpioController
cp -n "$PWD/Gpio/GpioDefaultConfig.ini" ~/.seedsorter/GpioConfig.ini
ln -f -s "$PWD/scripts/Service.sh" ~/.seedsorter/Service.sh 

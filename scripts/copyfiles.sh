#!/bin/bash
mkdir -p ~/.seedsorter
ln -f -s "$PWD/Analyser/Sorter" ~/.seedsorter/Sorter
ln -f -s "$PWD/Gpio/GpioController" ~/.seedsorter/GpioController
cp "$PWD/Gpio/GpioDefaultConfig.ini" ~/.seedsorter/GpioConfig.ini
ln -f -s "$PWD/Service/Service.sh" ~/.seedsorter/Service.sh 

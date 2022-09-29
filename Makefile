all: clear Sorter Learning Configurator GpioController wash

Sorter: 
	fpc -O3 -OoAUTOINLINE -Mobjfpc -dUseCThreads -Sh -Si "Analyser/Sorter.pas" "-FuCamera/" "-Fuutils/" "-oSorter"
	
Learning: 
	fpc -O3 -OoAUTOINLINE -Mobjfpc -dUseCThreads -Sh -Si "Learning/Learning.pas" "-Fuutils/" "-oLearning"
	
Configurator:
	lazbuild "Configurator/SeedSorterConfigurator.lpr"	
	
GpioController:
	fpc -O3 -OoAUTOINLINE -Mobjfpc -dUseCThreads -Sh -Si "Gpio/GpioController.pas" "-Fuutils/" "-oGpioController"
	
Service: 	
	chmod u+x "scripts/Service.sh"
	chmod u+x "scripts/copyfiles.sh"
	chmod u+x "scripts/CreateService.sh"
	bash "scripts/copyfiles.sh"
	bash "scripts/CreateService.sh" > "/dev/shm/seedsorter.service"
	sudo mv "/dev/shm/seedsorter.service" "/etc/systemd/system/seedsorter.service"
	sudo systemctl enable seedsorter
	
RemoveService: 
	rm -f "/etc/systemd/system/seedsorter.service"
	
configure:
	./Configurator/SeedSorterConfigurator

learn:
	./Learning/Learning -t `ls ~/.seedsorter/true/*` -f `ls ~/.seedsorter/false/*`	
	
Configurator/SeedSorterConfigurator: Configurator

Analyser/Sorter: Sorter

wash:
	chmod u+x "scripts/clean.sh"
	bash "./scripts/clean.sh" "Analyser"
	bash "./scripts/clean.sh" "Learning"	
	bash "./scripts/clean.sh" "Camera"	
	bash "./scripts/clean.sh" "utils"
	bash "./scripts/clean.sh" "Service"
	bash "./scripts/clean.sh" "Gpio"
	rm -rf "Configurator/lib"
	rm -rf "Configurator/backup"

clean: wash
	rm -f "Configurator/SeedSorterConfigurator"
	rm -f "Analyser/Sorter"
	rm -f "Learning/Learning"
	rm -f "Gpio/GpioController"
	
clear: clean
	
walkthrough:
	chmod u+x "scripts/walkthrough.sh"
	bash "./scripts/walkthrough.sh"
	
install-dependences:
	sudo apt update -y
	sudo apt install -y libv4l-0 libv4l-dev fpc lazarus
	
.DEFAULT: all
.PHONY: install-dependences Learning Sorter Configurator clean clear learn configure GpioController Service RemoveService walkthrough wash all

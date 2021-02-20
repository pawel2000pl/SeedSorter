all: Sorter Learning Configurator GpioController

Sorter: 
	fpc -B -Mobjfpc -dUseCThreads -Sh -Si "Analyser/Sorter.pas" "-FuCamera/" "-Fuutils/" "-oSorter"
	
Learning: 
	fpc -B -Mobjfpc -Sh -Si "Learning/Learning.pas" "-Fuutils/" "-oLearning"
	
Configurator:
	lazbuild "Configurator/SeedSorterConfigurator.lpr"	
	
GpioController:
	fpc -B -Mobjfpc -dUseCThreads -Sh -Si "Gpio/GpioController.pas" "-Fuutils/" "-oGpioController"
	
Service: 	
	bash -c 'mkdir -p ~/.seedsorter'
	bash -c 'cp Analyser/Sorter ~/.seedsorter/Sorter'
	bash -c 'cp Gpio/GpioController ~/.seedsorter/GpioController'
	bash -c 'cp Gpio/GpioDefaultConfig.ini ~/.seedsorter/GpioConfig.ini'
	chmod u+x "Service/Service.sh"
	bash -c 'cp "Service/Service.sh" ~/.seedsorter/'
	instantfpc -B -Mobjfpc -Sh -Si "Service/CreateService.pas" "-oCreateService" > "/dev/shm/seedsorter.service"
	sudo mv "/dev/shm/seedsorter.service" "/etc/systemd/system/seedsorter.service"
	
RemoveService: 
	rm "/etc/systemd/system/seedsorter.service"
	
configure:
	./Configurator/SeedSorterConfigurator

learn:
	./Learning/Learning -t `ls ~/.seedsorter/true/*` -f `ls ~/.seedsorter/false/*`	
	
Configurator/SeedSorterConfigurator: Configurator

Analyser/Sorter: Sorter

clean:
	bash -i "./scripts/clean.sh" "Analyser"
	bash -i "./scripts/clean.sh" "Learning"	
	bash -i "./scripts/clean.sh" "Camera"	
	bash -i "./scripts/clean.sh" "utils"
	bash -i "./scripts/clean.sh" "Service"
	rm -rf "Configurator/lib"
	rm -rf "Configurator/backup"
	rm -f "Configurator/SeedSorterConfigurator"
	rm -f "Analyser/Sorter"
	rm -f "Learning/Learning"
	rm -f "Gpio/GpioController"
	
.PHONY: Learning Sorter Configurator clean learn cofigure GpioController Service RemoveService

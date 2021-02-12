all: Sorter Learning Configurator

Sorter: 
	fpc -B -Mobjfpc -dUseCThreads -Sh -Si "Analyser/Sorter.pas" "-FuCamera/" "-Fuutils/" "-oSorter"
	
Learning: 
	fpc -B -Mobjfpc -Sh -Si "Learning/Learning.pas" "-Fuutils/" "-oLearning"
	
Configurator:
	lazbuild "Configurator/SeedSorterConfigurator.lpr"	
	
configure:
	./Configurator/SeedSorterConfigurator
	
learn:
	./Learning/Learning -t `ls ~/.seedsorter/true/*` -f `ls ~/.seedsorter/false/*`	

clean:
	bash -i "./scripts/clean.sh" "Analyser"
	bash -i "./scripts/clean.sh" "Learning"	
	bash -i "./scripts/clean.sh" "Camera"	
	bash -i "./scripts/clean.sh" "utils"
	rm -rf "Configurator/lib"
	rm -rf "Configurator/backup"
	
.PHONY: Learning Sorter Configurator clean learn cofigure

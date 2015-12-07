# update as necessary.
# Makefile for the final project.

GCC_FLAGS = -g -lm -std=c++11
C = g++

TARGETS = finalProject stepperMotor

all: $(TARGETS)

finalProject: finalProject.cpp EasyPIO.h
	$(C) $(GCC_FLAGS) -o $@ $^

stepperMotor: stepperMotor.cpp EasyPIO.h
	$(C) $(GCC_FLAGS) -o $@ $^

clean:
	rm -f $(TARGETS)

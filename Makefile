# update as necessary.
# Makefile for the final project.

GCC_FLAGS = -g
C = gcc

TARGETS = finalProject stepperMotor

all: $(TARGETS)

finalProject: finalProject.cpp EasyPIO.h
	$(C) $(GCC_FLAGS) -o $@ $^

stepperMotor: stepperMotor.cpp EasyPIO.h
	$(C) $(GCC_FLAGS) -o $@ $^

clean:
	rm -f $(TARGETS)

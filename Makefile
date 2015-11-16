# update as necessary.
# Makefile for the final project.

GCC_FLAGS = -g
C = gcc

TARGETS = finalProject stepperMotor

all: $(TARGETS)

finalProject: finalProject.c EasyPIO.h
	$(C) $(GCC_FLAGS) -o $@ $^

stepperMotor: stepperMotor.c EasyPIO.h
	$(C) $(GCC_FLAGS) -o $@ $^

clean:
	rm -f $(TARGETS)

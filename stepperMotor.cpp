// An example of how to use the stepper motor.

#include "EasyPIO.h"
#include <cstdio>

// Stepper motor pins
#define WIRE1 18
#define WIRE2 23
#define WIRE3 24
#define WIRE4 25

// Where one step ~3.6 degrees.
void oneStepForward(int duration) {
  digitalWrite(WIRE1, 1);
  digitalWrite(WIRE2, 0);
  digitalWrite(WIRE3, 0); 
  digitalWrite(WIRE4, 0);
 
  delayMicros(duration); 
  digitalWrite(WIRE1, 0);
  digitalWrite(WIRE2, 1);
  digitalWrite(WIRE3, 0); 
  digitalWrite(WIRE4, 0);

  delayMicros(duration);
  digitalWrite(WIRE1, 0);
  digitalWrite(WIRE2, 0);
  digitalWrite(WIRE3, 1); 
  digitalWrite(WIRE4, 0);

  delayMicros(duration);
  digitalWrite(WIRE1, 0);
  digitalWrite(WIRE2, 0);
  digitalWrite(WIRE3, 0); 
  digitalWrite(WIRE4, 1);
  delayMicros(duration);
}

void oneStepBackward(int duration) {
  digitalWrite(WIRE1, 0);
  digitalWrite(WIRE2, 0);
  digitalWrite(WIRE3, 0); 
  digitalWrite(WIRE4, 1);
 
  delayMicros(duration); 
  digitalWrite(WIRE1, 0);
  digitalWrite(WIRE2, 0);
  digitalWrite(WIRE3, 1); 
  digitalWrite(WIRE4, 0);

  delayMicros(duration);
  digitalWrite(WIRE1, 0);
  digitalWrite(WIRE2, 1);
  digitalWrite(WIRE3, 0); 
  digitalWrite(WIRE4, 0);

  delayMicros(duration);
  digitalWrite(WIRE1, 1);
  digitalWrite(WIRE2, 0);
  digitalWrite(WIRE3, 0); 
  digitalWrite(WIRE4, 0);
  delayMicros(duration);
}

void moveForwardXDegrees(float degrees, int duration) {
  int numberSteps = int (degrees / 3.6);
  for (int i = 0; i < numberSteps; ++i) {
    oneStepForward(duration);
  }
}

void oscillate(int duration) {
  oneStepForward(duration);
  oneStepBackward(duration);
}
int main() {
 pioInit();

 pinMode(WIRE1, OUTPUT);
 pinMode(WIRE2, OUTPUT);
 pinMode(WIRE3, OUTPUT);
 pinMode(WIRE4, OUTPUT);
 //for (int i = 0; i < 100; ++i) {
 //  oscillate(1000);
 //}
 
 // Goes forward in a complete circle
 moveForwardXDegrees(360, 3000);
 digitalWrite(WIRE1, 0);
 digitalWrite(WIRE4, 0);
}

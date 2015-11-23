#include "EasyPIO.h"
#include <stdio.h>
#include <math.h>
#define PI 3.14159265359

#define LOAD_PIN 26
#define DONE_PIN 19
#define SOUND_PIN 18
#define EXIT_PIN 15

class Harp
{
private:
  float _noteWeights[8];
  void writeNoteValue(int time);
  void playNotes(int dur, int startT);
  
public:
  Harp();
  void runHarp();
  void updateWeights();
  void testScale();
  static const int NOTEFREQ[8]; 
  static const float PWMFREQUENCY = 500000;
  static const int DT = 100;//100us between dac updates for audio
  static const unsigned int numNotes = 8;
};

                  // c   d   e   f   g   a   b   c
const int Harp::NOTEFREQ[] = {262,294,330,349,392,440,494,523};

Harp::Harp(){
	for(int i=0; i<8; ++i) _noteWeights[i] = 0; 
	pinMode(SOUND_PIN, OUTPUT);
	pinMode(EXIT_PIN, INPUT);
}

// Plays combination of notes according to _noteWeights, takes in
// time in us since start
void Harp::writeNoteValue(int t){
  float summedDuty = 0;
  for (int i=0; i<8; ++i){            /// 1mil factor conversion from us->s
    summedDuty += _noteWeights[i]*cos(2*PI*NOTEFREQ[i]*t/1000000); 
  }
  setPWM(PWMFREQUENCY,summedDuty);
}

// Function takes in a duration to play set weights in (us) and a startTime (us)
void Harp::playNotes(int duration, int startTime){
  for (int nowTime = startTime; nowTime < startTime + duration; nowTime += DT){
    writeNoteValue(nowTime);
  }
}
// Function executes SPI transaction with FPGA to update the note weights
// Should also normalize
void Harp::updateWeights(){
  char sendAction = 0x01; // doesn't really matter yet what we send.
  for (int i=0; i<8; ++i){
    _noteWeights[i] = float(spiSendReceive(sendAction))/128.;
    // then normalize
  }
}
// Function for continous operation of the harp playing music. Add exit condition.
void Harp::runHarp(){}

void Harp::testScale() {
  _noteWeights[] = {0,.33,0,0,.33,0,0,.33};
  playNotes(1000000000,0);
  _noteWeights[] = {0,0,0,0,0,.5,0,.5};
  playNotes(1000000000,0);
}
// STRETCH: Send notes + duration to FPGA
// STRETCH: Keep track of length of note.
// STRETCH: Playback and play mode.
int main() {
  pioInit();
  pwmInit();
  spiInit(244000, 0);
  Harp myHarp;
  
  myHarp.testScale();
 
  
}

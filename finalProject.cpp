#include "EasyPIO.h"
#include <stdio.h>
#include <math.h>
#define PI 3.14159265359

#define LOAD_PIN 26
#define DONE_PIN 19
#define SOUND_PIN 4
#define EXIT_PIN 18



// Masks for our strings.
typedef enum{
  STRING0 = 0x01,
  STRING1 = 0x02,
  STRING2 = 0x04,
  STRING3 = 0x08,
  STRING4 = 0x10,
  STRING5 = 0x20,
  STRING6 = 0x40,
  STRING7 = 0x80
} stringMask;

// TODO: SPI communication with FPGA
char getStrings() {
  digitalWrite(LOAD_PIN, 1);
  char send = 0x01; // doesn't really matter yet what we send.
  spiSendReceive(send);
  digitalWrite(LOAD_PIN, 0);

  while(!digitalRead(DONE_PIN));
  
  return spiSendReceive(0);
}

// TODO: Encode notes in a lookup table.
// Since there aren't that many notes
// we're just going to use a case switch.

unsigned int getPitch(char note) {
  switch (note) {
    case 'c': return 262;
    case 'd': return 294;
    case 'e': return 330;
    case 'f': return 349;
    case 'g': return 392;
    case 'a': return 440;
    case 'b': return 494;
    case 'C': return 523; // This is high C
    default: return 0;
  }
}

// Every time this is called,
// plays note for one millisecond. 
void playNote(unsigned int pitch) {
  unsigned int half_period;
  int i;
  
  if (!pitch) return;

  half_period = 500000 / pitch; // pitch to micro.

  // 1000 microseconds in a millisecond.
  for (i = 0; i < 4000 / (half_period * 2); ++i) {
    digitalWrite(SOUND_PIN, 1);
    delayMicros(half_period);
    digitalWrite(SOUND_PIN, 0);
    delayMicros(half_period);
  }
}
// TODO: From FPGA input, choose the right note

void runHarp() {
  while (!digitalRead(EXIT_PIN)) {
    char strings = getStrings();
    char note;
    if (strings & STRING0) 
      note = 'c';
    if (strings & STRING1)
      note = 'd';
    if (strings & STRING2)
      note = 'e';
    if (strings & STRING3)
      note = 'f';
    if (strings & STRING4)
      note = 'g';
    if (strings & STRING5)
      note = 'a';
    if (strings & STRING6)
      note = 'b';
    if (strings & STRING7)
      note = 'C';

    playNote(getPitch(note));
  }
}
// TODO: Make the note sound better + ADC SPI communication
//                                    + amp -> speaker????
class Harp
{
private:
  float _noteWeights[8];
  void writeNotes(int time);
  void playNotes(int dur, int startT);
  void updateWeights();
public:
  Harp(){for(int i=0; i<8; ++i) _noteWeights[i]=0; };
  void runHarp();
                               // c   d   e   f   g   a   b   c
  static const int NOTEFREQ[] = {262,294,330,349,392,440,494,523};
  static const float PWMFREQUENCY = 500000;
  static const int DT = 100;//100us between dac updates for audio

};

// Plays combination of notes according to _noteWeights, takes in
// time in us since start
void Harp::writeNoteValue(int t){
  float summedDuty = 0;
  for (int i=0; i<8; ++i){            /// 1mil factor conversion from us->s
    summedDuty += _noteWeights[i]*cos(2*pi*NOTEFREQ[i]*t/1000000); 
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
    printf("for string %d we get %c",i,spiSendReceive(sendAction));
    // TODO test and continue from here
    // _noteWeights[i] = float(spiSendReceive(sendAction))/128.;
    // then normalize
  }
}
// Function for continous operation of the harp playing music. Add exit condition.
void Harp::srunHarp(){}








void testScale() {
  char array[] =  {'c', 'd', 'e' ,'f', 'g', 'a', 'b', 'C'};
  for (size_t i = 0; i < 8; ++i) {
    unsigned int pitch = getPitch(array[i]);
    for (int time = 0; time < 100; ++time) {
      playNote(pitch); 
    }
    printf("played %c at pitch %d\n", array[i], pitch); 
  }
}
// STRETCH: Send notes + duration to FPGA
// STRETCH: Keep track of length of note.
// STRETCH: Playback and play mode.
int main() {
  pioInit();
  pwmInit();
  spiInit(244000, 0);
  pinMode(LOAD_PIN, OUTPUT);
  pinMode(DONE_PIN, INPUT);
  pinMode(SOUND_PIN, OUTPUT);
  pinMode(EXIT_PIN, INPUT);
  //testScale(); 
  Harp myHarp();
  while(1){
	myHarp.updateWeights();
	delayMicros(100);
  }
  
}

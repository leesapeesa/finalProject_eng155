#include "EasyPIO.h"
#include <stdio.h>
#include <math.h>
#include <algorithm>
#include <array>
#include <vector>

#define PI 3.14159265359

#define LOAD_PIN 26
#define SOUND_PIN 18
#define EXIT_PIN 24
#define PLAY_PIN 25
#define RECORD_PIN 27

class Harp
{
private:
  //std::array<std::array<float, 8>, 12> _allNoteWeights; // for averaging
  std::array<float, 8> _noteWeights;
  //float _noteWeights[8];
  std::vector<std::array<float, 8>> _recordedSong;
  unsigned int _ringBufferIndex;
  void writeNoteValue(unsigned int time);
  void playNotes(int dur, int startT);
  
public:
  Harp();
  void runHarp();
  void updateWeights();
  void testScale();
  void playbackSong();
  static const int NOTEFREQ[8]; 
  static const float PWMFREQUENCY;
  static const int DT = 100;//100us between dac updates for audio
  static const unsigned int numNotes = 8;
};

                            // c   d   e   f   g   a   b   c
const int Harp::NOTEFREQ[] = {120, 200, 280, 380, 480, 580, 680, 880}; // {262,294,330,349,392,440,494,523};
const float Harp::PWMFREQUENCY = 50000;

Harp::Harp(){//:_ringBufferIndex(0){
  for(int i=0; i<8; ++i) _noteWeights[i] = 0;
  // std::fill(_allNoteWeights.begin(), _allNoteWeights.end(), _noteWeights); 
	pinMode(EXIT_PIN, INPUT);
  pinMode(LOAD_PIN, OUTPUT);
  pinMode(RECORD_PIN, INPUT);
  pinMode(PLAY_PIN, INPUT);
}

// Plays combination of notes according to _noteWeights, takes in
// time in us since start
void Harp::writeNoteValue(unsigned int t){
  float summedDuty = 0.5;
  for (int i=0; i<8; ++i){            /// 1mil factor conversion from us->s
    summedDuty += _noteWeights[i]*cos(2*PI*NOTEFREQ[i]*t/1000000); 
  }
  setPWM(PWMFREQUENCY,summedDuty);
 // printf("Duty cycle is %f",summedDuty);
}

// Function takes in a duration to play set weights in (us) and a startTime (us)
void Harp::playNotes(int duration, int startTime){
  for (int nowTime = startTime; nowTime < startTime + duration; nowTime += DT){
    delayMicros(DT);
    writeNoteValue(nowTime);
  }
}
// Function executes SPI transaction with FPGA to update the note weights
// Should also normalize
void Harp::updateWeights(){
  char sendAction = 0x01; // doesn't really matter yet what we send.
  //_noteWeights[7] = spiSendReceive(sendAction);
  //delayMicros(100);
  char notes[8];
  digitalWrite(LOAD_PIN, 1);
  notes[7] = spiSendReceive(sendAction);
  notes[0] = spiSendReceive(sendAction);
  notes[1] = spiSendReceive(sendAction);
  notes[2] = spiSendReceive(sendAction);
  notes[3] = spiSendReceive(sendAction);
  notes[4] = spiSendReceive(sendAction);
  notes[5] = spiSendReceive(sendAction);
  notes[6] = spiSendReceive(sendAction);
  digitalWrite(LOAD_PIN, 0);

  for (int i = 0; i < 8; ++i) {
    _noteWeights[i] = notes[i] & 127;
   // if (i != 7) _noteWeights[i] = 0;
  } //delayMicros(10000); // just for debugging
  // Then normalize.
  
  float sum = 0;
  for (int i = 0; i < 8; ++i) sum +=_noteWeights[i];
  for (int i = 0; i < 8; ++i) {
   if (_noteWeights[i] < 100) _noteWeights[i] == 0;
     _noteWeights[i] = sum == 0 ? 0: _noteWeights[i] / ( 2 * sum);
 }
//  _allNoteWeights[_ringBufferIndex % _allNoteWeights.size()] = _noteWeights;

}

void Harp::playbackSong() {
  int timePassed = 0;
  for (int i = 0; i < _recordedSong.size(); ++i) {
    printf("playing Song %d\n", i);
    delayMicros(DT); 
    _noteWeights = _recordedSong[i];
    writeNoteValue(timePassed);
    timePassed +=  DT;
  }
}

// Function for continous operation of the harp playing music. Add exit condition.
void Harp::runHarp(){
  unsigned long timePassed = 0;
  unsigned long counter = 0;
  while (true) {

    bool isRecording = digitalRead(RECORD_PIN);
    if (digitalRead(PLAY_PIN) && !isRecording) {
       playbackSong();
    }
    if (!isRecording) {
      //_recordedSong.clear();   
    }
    _ringBufferIndex++;
   
    updateWeights();
    /*
    for (int i = 0; i < 8; ++i){
      float sum = 0;
      for (int j = 0; j < _allNoteWeights.size(); ++j) {
        sum += _allNoteWeights[j][i];
      }
      sum /= _allNoteWeights.size();
    //  _noteWeights[i] = (sum < 0.10) ? 0 : sum;
    }
    */
    //printf("The weights of each string are: ");
    //for (int i = 0; i < 8; ++i) {
    //   printf("%f ", _noteWeights[i]);
    //}
    //printf("\n");
    
    if (isRecording) {
   //   if (counter == 20) {
        _recordedSong.push_back(_noteWeights);
        printf("isRecording\n");
        counter = 0;
   //   }
      //printf("_recordedSong size %d \n", _recordedSong.size());
      ++counter;
    }
    delayMicros(DT);
    timePassed += DT;
    writeNoteValue(timePassed);
  }
  printf("exiting\n");
}

void Harp::testScale() {
  float noteset1[] = {.2,0,0,0,0,0,0,0};
  std::copy(noteset1,noteset1+8, _noteWeights.begin());
  playNotes(5000000,0);
  for (int i=0; i<7; ++i){
    std::swap(_noteWeights[i],_noteWeights[i+1]);
    playNotes(5000000,0);
  }
  std::copy(noteset1, noteset1 + 8, _noteWeights.begin());
  _noteWeights[7] = 0.2;

  playNotes(5000000,0);
  
  
  // testing.
}
// STRETCH: Send notes + duration to FPGA
// STRETCH: Keep track of length of note.
// STRETCH: Playback and play mode.
int main() {
  pioInit();
  pwmInit();
  spiInit(244000, 0);

  Harp myHarp; 
  myHarp.runHarp();
 //myHarp.testScale();
  //setPWM(500,.5);
  //delayMicros(10000000);
}

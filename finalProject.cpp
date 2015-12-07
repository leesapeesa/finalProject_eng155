#include "EasyPIO.h"
#include <stdio.h>
#include <math.h>
#include <algorithm>
#include <array>
#include <vector>

#define PI 3.14159265359

#define LOAD_PIN 26
#define SOUND_PIN 18
#define EXIT_PIN 6
#define PLAY_PIN 24
#define RECORD_PIN 25
#define PLAY_LED 4

class Harp
{
private:
  std::array<std::array<float, 8>, 4> _allNoteWeights; // for averaging
  std::array<float, 8> _noteWeights;
  std::vector<std::array<float, 8>> _recordedSong;
  unsigned int _ringBufferIndex;
  void writeNoteValue(unsigned int time); // Output sample over pwm at given time
  void playNotes(int dur, int startT); // writeNoteValues according to _noteWeights for duration dur
  
public:
  Harp();
  void runHarp();
  void updateWeights();
  void testScale();
  void playbackSong();
  void stringDebounce();
  static const int NOTEFREQ[8]; 
  static const float PWMFREQUENCY;
  static const int DT = 100; //100us between dac updates for audio
  static const unsigned int numNotes = 8;
};

                                                                          // c   d   e   f   g   a   b   c
const int Harp::NOTEFREQ[] = {200, 300, 350, 450, 550, 650, 700, 800}; // {262,294,330,349,392,440,494,523};
const float Harp::PWMFREQUENCY = 50000; // Fast enough that we don't need to worry about it

Harp::Harp():_ringBufferIndex(0) {
  for (int i = 0; i < 8; ++i) _noteWeights[i] = 0;
  std::fill(_allNoteWeights.begin(), _allNoteWeights.end(), _noteWeights); 
  pinMode(EXIT_PIN, INPUT);
  pinMode(LOAD_PIN, OUTPUT);
  pinMode(RECORD_PIN, INPUT);
  pinMode(PLAY_PIN, INPUT);
  pinMode(PLAY_LED, OUTPUT);
}

// Plays combination of notes according to _noteWeights, takes in
// time in us since start
void Harp::writeNoteValue (unsigned int t){
  float summedDuty = 0.5;
  float angleMultiplier = 2 * PI * t / 1000000;
  for (int i = 0; i < 8; ++i){            /// 1mil factor conversion from us->s
    summedDuty += _noteWeights[i] * cos(angleMultiplier * NOTEFREQ[i]); 
  }
  setPWM(PWMFREQUENCY,summedDuty); // PWM pin 18 controls audio jack
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
void Harp::updateWeights(){
  char sendAction = 0x01; 
  char notes[8];
  std::array<float, 8> tempNotes;
  digitalWrite(LOAD_PIN, 1);
  for (int i = 0; i < 8; ++i) {
    notes[i] = spiSendReceive(sendAction);
  }
  digitalWrite(LOAD_PIN, 0);
  
  // Normalize the notes. 
  // The sum of all the notes should be between 0 and 0.5 for
  // a relatively okay soundwave.
  // printf("The notes are ");
  float sum = 0;
  for (int i = 0; i < 8; ++i) {
    // If a note is below a certain value, throw it out.
    tempNotes[i] = notes[i] < 120 ? 0 : notes[i];
    sum += tempNotes[i];
  }
  // Then normalize.
  
  for (int i = 0; i < 8; ++i) {
    tempNotes[i] = (sum == 0) ? 0: tempNotes[i] / (2 * sum);
    //printf("%f ", tempNotes[i]);
  }
  //printf("\n");
  
  // A buffer to average the notes and reduce note "bounce".
  _allNoteWeights[_ringBufferIndex % _allNoteWeights.size()] = tempNotes;
  _ringBufferIndex++;
}

// Plays back a recorded song on the speaker.
// Plays at a higher frequency since the delays between the 
// notes are not as long.
void Harp::playbackSong() {
  int timePassed = 0;
  digitalWrite(PLAY_LED, 1);
  for (int i = 0; i < _recordedSong.size(); ++i) {
    printf("playing Song %d\n", i);
    _noteWeights = _recordedSong[i];
    writeNoteValue(timePassed);
    delayMicros(DT * 3);
    timePassed +=  DT * 3;
  }
  digitalWrite(PLAY_LED, 0);
}

void Harp::stringDebounce() {
  // Button debounce.
  for (int i = 0; i < 8; ++i){
    float sum = 0;
    for (int j = 0; j < _allNoteWeights.size(); ++j) {
      sum += _allNoteWeights[j][i];
    }
    sum /= _allNoteWeights.size();
    _noteWeights[i] = sum;
  }
}
// Function for continous operation of the harp playing music.
void Harp::runHarp(){
  unsigned long timePassed = 0;
  unsigned long counter = 0;
  std::vector<std::array<float, 8>> currentlyRecording;
  
  // The first time the recording button is low,
  // the button has just been turned off.
  // We want to save what we currently recorded.
  bool justTurnedOffRecording = false;
  while (true) {
    updateWeights();
    stringDebounce();
    
    bool isRecording = digitalRead(RECORD_PIN);
    
    if (digitalRead(PLAY_PIN) && !isRecording) {
       playbackSong();
    }
    
    if (!isRecording && justTurnedOffRecording) {
      _recordedSong = currentlyRecording;
      currentlyRecording.clear();
      justTurnedOffRecording = false;
    }
    
    if (isRecording) {
      if (!_recordedSong.empty()) _recordedSong.clear();
      currentlyRecording.push_back(_noteWeights);
     // printf("isRecording\n");
      justTurnedOffRecording = true;
    }
    /* 
    printf("The weights of each string are: ");
    for (int i = 0; i < 8; ++i) {
       printf("%f ", _noteWeights[i]);
    }
    printf("\n");
    */
    writeNoteValue(timePassed);
    timePassed += DT;
    delayMicros(DT);
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
  
  // Test two notes at once.
  std::copy(noteset1, noteset1 + 8, _noteWeights.begin());
  _noteWeights[7] = 0.2;

  playNotes(5000000,0);  
}

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

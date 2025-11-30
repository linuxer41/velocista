/**
 * ARCHIVO: motor.h
 * DESCRIPCIÓN: Clases Motor y MotorController para control de motores
 */

#ifndef MOTOR_H
#define MOTOR_H

#include <Arduino.h>
#include "config.h"

enum Location {
  LEFT,
  RIGHT
};

class Motor {
private:
  int pin1, pin2;
  int speed;
  Location location;
  volatile long forwardCount;
  volatile long backwardCount;
  long lastCount;
  unsigned long lastSpeedCheck;
  float currentRPM;
  float targetRPM;
  int encoderAPin, encoderBPin;

public:
  Motor(int p1, int p2, Location loc, int encA, int encB) : pin1(p1), pin2(p2), speed(0), location(loc), forwardCount(0), backwardCount(0), lastCount(0), lastSpeedCheck(0), currentRPM(0), targetRPM(0), encoderAPin(encA), encoderBPin(encB) {
  }

  void init() {
    pinMode(pin1, OUTPUT);
    pinMode(pin2, OUTPUT);
    pinMode(encoderAPin, INPUT_PULLUP);
    pinMode(encoderBPin, INPUT_PULLUP);
  }

  void setSpeed(int s) {
    speed = constrain(s, -MAX_SPEED, MAX_SPEED);
    if (location == LEFT) {
      if (speed >= 0) {
        analogWrite(pin1, speed);
        analogWrite(pin2, 0);
      } else {
        analogWrite(pin1, 0);
        analogWrite(pin2, -speed);
      }
    } else { // RIGHT
      if (speed >= 0) {
        analogWrite(pin1, speed);
        analogWrite(pin2, 0);
      } else {
        analogWrite(pin1, 0);
        analogWrite(pin2, -speed);
      }
    }
  }

  int getSpeed() {
    return speed;
  }


  float getRPM() {
    unsigned long now = millis();
    if (now - lastSpeedCheck < 100) return currentRPM;
    long currentCount = forwardCount - backwardCount;
    long delta = currentCount - lastCount;
    float dt = (now - lastSpeedCheck) / 1000.0;
    currentRPM = (delta / (float)PULSES_PER_REVOLUTION) * 60.0 / dt;
    lastCount = currentCount;
    lastSpeedCheck = now;
    return currentRPM;
  }

  void setTargetRPM(float t) {
    targetRPM = t;
  }

  float getTargetRPM() {
    return targetRPM;
  }

  long getEncoderCount() {
    return forwardCount;
  }

  long getBackwardCount() {
    return backwardCount;
  }

  void updateEncoder() {
    if (location == LEFT) {
      if (digitalRead(encoderBPin)) {
        backwardCount++;  // LEFT motor: B HIGH = backward
      } else {
        forwardCount++;   // LEFT motor: B LOW = forward
      }
    } else {
      if (digitalRead(encoderBPin)) {
        forwardCount++;   // RIGHT motor: B HIGH = forward
      } else {
        backwardCount++;  // RIGHT motor: B LOW = backward
      }
    }
  }
};


#endif
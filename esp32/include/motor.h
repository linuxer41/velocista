#ifndef MOTOR_H
#define MOTOR_H

#include <stdint.h>
#include <driver/gpio.h>
#include <driver/ledc.h>
#include "config.h"

class Motor {
private:
    uint8_t pin1, pin2;
    int16_t speed;
    Location location;
    volatile int32_t forwardCount;
    volatile int32_t backwardCount;
    int32_t lastCount;
    uint32_t lastSpeedCheck;
    float currentRPM;
    float filteredRPM;
    float targetRPM;
    uint8_t encoderAPin, encoderBPin;

public:
    Motor(uint8_t p1, uint8_t p2, Location loc, uint8_t encA, uint8_t encB);
    void init();
    void setSpeed(int s);
    int getSpeed();
    float getRPM();
    float getFilteredRPM();
    void setTargetRPM(float t);
    float getTargetRPM();
    long getEncForwardCount();
    long getEncBackwardCount();
    void updateEncoder();
};

#endif
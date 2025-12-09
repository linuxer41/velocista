#ifndef PID_H
#define PID_H

#include <stdint.h>

class PID {
private:
    float kp, ki, kd;
    float error, lastError, integral, derivative;
    float output;
    float maxOutput, minOutput;

public:
    PID(float p, float i, float d, float maxOut, float minOut);
    void setGains(float p, float i, float d);
    float calculate(float setpoint, float measurement, float dt);
    void reset();
    float getOutput();
    float getError();
    float getIntegral();
    float getDerivative();
    float getProportional();
};

#endif
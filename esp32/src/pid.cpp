#include "pid.h"

PID::PID(float p, float i, float d, float maxOut, float minOut)
    : kp(p), ki(i), kd(d), error(0), lastError(0), integral(0), derivative(0), output(0), maxOutput(maxOut), minOutput(minOut) {}

void PID::setGains(float p, float i, float d) { kp = p; ki = i; kd = d; }

float PID::calculate(float setpoint, float measurement, float dt) {
    error = setpoint - measurement;
    integral += error * dt;
    derivative = (error - lastError) / dt;
    lastError = error;
    output = kp * error + ki * integral + kd * derivative;
    if (output > maxOutput) output = maxOutput;
    if (output < minOutput) output = minOutput;
    return output;
}

void PID::reset() { integral = 0; lastError = 0; derivative = 0; }
float PID::getOutput() { return output; }
float PID::getError() { return error; }
float PID::getIntegral() { return integral; }
float PID::getDerivative() { return derivative; }
float PID::getProportional() { return kp * error; }
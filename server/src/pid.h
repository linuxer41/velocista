/**
 * ARCHIVO: pid.h
 * DESCRIPCIÓN: Clase PID para controlador PID
 */

#ifndef PID_H
#define PID_H


class PID {
private:
  float kp, ki, kd;
  float error, lastError, integral, derivative;
  float output;

public:
  PID(float p, float i, float d) : kp(p), ki(i), kd(d), error(0), lastError(0), integral(0), derivative(0), output(0) {}

  void setGains(float p, float i, float d) {
    kp = p;
    ki = i;
    kd = d;
  }

  float calculate(float setpoint, float measurement, float dt) {
    error = setpoint - measurement;
    integral += error * dt;
    integral = constrain(integral, -1000, 1000); // Limitar integral
    derivative = (error - lastError) / dt;

    output = kp * error + ki * integral + kd * derivative;
    output = constrain(output, -225, 225); // Limitar salida PID
    lastError = error;
    return output;
  }

  void reset() {
    error = 0;
    lastError = 0;
    integral = 0;
    derivative = 0;
    output = 0;
  }

  float getOutput() {
    return output;
  }

  float getError() {
    return error;
  }

  float getIntegral() {
    return integral;
  }

  float getDerivative() {
    return derivative;
  }
};

#endif
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
  bool antiWindupEnabled;
  float maxOutput, minOutput;

public:
  PID(float p, float i, float d) : kp(p), ki(i), kd(d), error(0), lastError(0), integral(0), derivative(0), output(0), antiWindupEnabled(true), maxOutput(225), minOutput(-225) {}

  void setGains(float p, float i, float d) {
    kp = p;
    ki = i;
    kd = d;
  }

  float calculate(float setpoint, float measurement, float dt) {
    error = setpoint - measurement;
    derivative = (error - lastError) / dt;

    // Calcular términos
    float pTerm = kp * error;
    float iTerm = ki * integral;
    float dTerm = kd * derivative;

    // Anti-windup: integración condicional
    if (antiWindupEnabled) {
      float unsaturatedOutput = pTerm + iTerm + dTerm;
      // Solo integrar si no está saturado en la dirección del error
      if ((unsaturatedOutput < maxOutput || error <= 0) && (unsaturatedOutput > minOutput || error >= 0)) {
        integral += error * dt;
        integral = constrain(integral, -1000, 1000);
      }
    } else {
      integral += error * dt;
      integral = constrain(integral, -1000, 1000);
    }

    iTerm = ki * integral;
    output = pTerm + iTerm + dTerm;
    output = constrain(output, minOutput, maxOutput);
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
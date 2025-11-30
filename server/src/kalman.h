/**
 * ARCHIVO: kalman.h
 * DESCRIPCIÓN: Clase Kalman para filtro de posición de línea
 */

#ifndef KALMAN_H
#define KALMAN_H

#include <Arduino.h>

class Kalman {
private:
    float x;  // estimated state
    float p;  // estimate error covariance
    float q;  // process noise
    float r;  // measurement noise

public:
    Kalman(float processNoise, float measurementNoise)
        : x(0.0), p(1.0), q(processNoise), r(measurementNoise) {}

    void update(float measurement) {
        // Predict
        p += q;

        // Update
        float k = p / (p + r);
        x += k * (measurement - x);
        p *= (1 - k);
    }

    float getEstimate() {
        return x;
    }

    void reset() {
        x = 0.0;
        p = 1.0;
    }
};

#endif
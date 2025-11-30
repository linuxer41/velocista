/**
 * ARCHIVO: features.h
 * DESCRIPCIÓN: Clase Features para gestionar filtros y características avanzadas
 */

#ifndef FEATURES_H
#define FEATURES_H

#include <Arduino.h>
#include <string.h>

class Features {
private:
    bool enables[8];
    // Median filter
    float medianBuffer[5];
    int medianCount;
    // Moving average
    float movingBuffer[5];
    float movingSum;
    int movingCount;
    // Kalman
    float kalmanX, kalmanP;
    // Hysteresis
    float hysteresisLast;
    // Low pass
    float lowPassLast;

    // Bubble sort for median
    void sort(float arr[], int n) {
        for (int i = 0; i < n-1; i++) {
            for (int j = 0; j < n-i-1; j++) {
                if (arr[j] > arr[j+1]) {
                    float temp = arr[j];
                    arr[j] = arr[j+1];
                    arr[j+1] = temp;
                }
            }
        }
    }

public:
    Features() : medianCount(0), movingSum(0), movingCount(0), kalmanX(0), kalmanP(1), hysteresisLast(0), lowPassLast(0) {
        memset(medianBuffer, 0, sizeof(medianBuffer));
        memset(movingBuffer, 0, sizeof(movingBuffer));
        memset(enables, 0, sizeof(enables));
    }

    void setEnables(bool e[8]) {
        memcpy(enables, e, sizeof(enables));
    }

    float applySignalFilters(float raw) {
        float current = raw;

        // 0: Median filter (5 samples)
        if (enables[0]) {
            medianBuffer[medianCount] = raw;
            medianCount = (medianCount + 1) % 5;
            if (medianCount == 0) { // buffer full
                float sorted[5];
                memcpy(sorted, medianBuffer, sizeof(sorted));
                sort(sorted, 5);
                current = sorted[2]; // median
            }
        }

        // 1: Moving average (5 samples)
        if (enables[1]) {
            movingSum -= movingBuffer[movingCount];
            movingBuffer[movingCount] = current;
            movingSum += current;
            movingCount = (movingCount + 1) % 5;
            current = movingSum / 5.0;
        }

        // 2: Kalman filter
        if (enables[2]) {
            kalmanP += 0.01; // process noise
            float k = kalmanP / (kalmanP + 0.1); // measurement noise
            kalmanX += k * (current - kalmanX);
            kalmanP *= (1 - k);
            current = kalmanX;
        }

        // 3: Hysteresis (threshold 10)
        if (enables[3]) {
            if (abs(current - hysteresisLast) > 10) {
                hysteresisLast = current;
            } else {
                current = hysteresisLast;
            }
        }

        // 4: Dead zone (threshold 5)
        if (enables[4]) {
            if (abs(current) < 5) current = 0;
        }

        // 5: Low pass (alpha 0.8)
        if (enables[5]) {
            current = 0.8 * lowPassLast + 0.2 * current;
            lowPassLast = current;
        }

        // 6: Adaptive PID - TODO
        // 7: Speed profiling - TODO

        return current;
    }
};

#endif
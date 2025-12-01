/**
 * ARCHIVO: features.h
 * DESCRIPCIÓN: Clase Features para gestionar filtros y características avanzadas
 */

#ifndef FEATURES_H
#define FEATURES_H

#include <Arduino.h>
#include <string.h>
#include "config.h"

class Features {
private:
    FeaturesConfig config;

    // Median filter
    int16_t medianBuffer[2];
    uint8_t medianCount;
    // Moving average
    int16_t movingBuffer[2];
    int32_t movingSum;
    uint8_t movingCount;
    // Kalman
    int16_t kalmanX, kalmanP;
    // Hysteresis
    int16_t hysteresisLast;
    // Low pass
    int16_t lowPassLast;

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
    Features() : medianCount(0), movingSum(0), movingCount(0), kalmanX(0), kalmanP(100), hysteresisLast(0), lowPassLast(0) {
        memset(medianBuffer, 0, sizeof(medianBuffer));
        memset(movingBuffer, 0, sizeof(movingBuffer));
    }

    void setConfig(FeaturesConfig& f) {
        config = f;
    }

    float applySignalFilters(float raw) {
        float current = raw;

        // 0: Median filter (2 samples)
        if (config.medianFilter) {
            medianBuffer[medianCount] = raw * 100;
            medianCount = (medianCount + 1) % 2;
            if (medianCount == 0) { // buffer full
                int16_t a = medianBuffer[0];
                int16_t b = medianBuffer[1];
                if (a > b) {
                    int16_t temp = a;
                    a = b;
                    b = temp;
                }
                current = (a + b) / 2.0 / 100.0;
            }
        }

        // 1: Moving average (2 samples)
        if (config.movingAverage) {
            movingSum -= movingBuffer[movingCount];
            movingBuffer[movingCount] = current * 100;
            movingSum += movingBuffer[movingCount];
            movingCount = (movingCount + 1) % 2;
            current = movingSum / 2.0 / 100.0;
        }

        // 2: Kalman filter
        if (config.kalmanFilter) {
            kalmanP += 1; // 0.01 * 100
            int32_t measurement = current * 100;
            int32_t k = kalmanP * 100 / (kalmanP + 10); // k = P / (P + 0.1) scaled
            kalmanX += k * (measurement - kalmanX) / 100;
            kalmanP = kalmanP * (10000 - k) / 10000; // P *= (1 - k/100)
            current = kalmanX / 100.0;
        }

        // 3: Hysteresis (threshold 10)
        if (config.hysteresis) {
            if (abs(current - hysteresisLast / 100.0) > 10) {
                hysteresisLast = current * 100;
            } else {
                current = hysteresisLast / 100.0;
            }
        }

        // 4: Dead zone (threshold 5)
        if (config.deadZone) {
            if (abs(current) < 5) current = 0;
        }

        // 5: Low pass (alpha 0.8)
        if (config.lowPass) {
            current = 0.8 * (lowPassLast / 100.0) + 0.2 * current;
            lowPassLast = current * 100;
        }


        return current;
    }
};

#endif
#include "features.h"

Features::Features() : config({false, false, false, false, false, false, false, false, false}),
                      medianCount(0), movingSum(0), movingCount(0), kalmanX(0), kalmanP(1000),
                      hysteresisLast(0), lowPassLast(0) {}

void Features::setConfig(FeaturesConfig& f) { config = f; }

void Features::sort(float arr[], int n) {
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

float Features::applySignalFilters(float raw) {
    float result = raw;

    if (config.medianFilter) {
        medianBuffer[medianCount++] = (int16_t)raw;
        if (medianCount >= 3) {
            float sorted[3] = {(float)medianBuffer[0], (float)medianBuffer[1], (float)medianBuffer[2]};
            sort(sorted, 3);
            result = sorted[1];
            medianCount = 0;
        }
    }

    if (config.movingAverage) {
        movingSum -= movingBuffer[movingCount];
        movingBuffer[movingCount] = result;
        movingSum += result;
        movingCount = (movingCount + 1) % 3;
        if (movingCount == 0) {
            result = movingSum / 3.0f;
        }
    }

    if (config.kalmanFilter) {
        float R = 1;
        float Q = 0.1;
        float K = kalmanP / (kalmanP + R);
        kalmanX = kalmanX + K * (result - kalmanX);
        kalmanP = (1 - K) * kalmanP + Q;
        result = kalmanX;
    }

    if (config.hysteresis) {
        if (result > hysteresisLast + 10) result = hysteresisLast + 10;
        else if (result < hysteresisLast - 10) result = hysteresisLast - 10;
        hysteresisLast = result;
    }

    if (config.lowPass) {
        result = 0.8 * lowPassLast + 0.2 * result;
        lowPassLast = result;
    }

    return result;
}
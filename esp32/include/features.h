#ifndef FEATURES_H
#define FEATURES_H

#include <stdint.h>
#include "config.h"

class Features {
private:
    FeaturesConfig config;
    int16_t medianBuffer[3];
    uint8_t medianCount;
    int16_t movingBuffer[3];
    int32_t movingSum;
    uint8_t movingCount;
    int16_t kalmanX, kalmanP;
    int16_t hysteresisLast;
    int16_t lowPassLast;

    void sort(float arr[], int n);

public:
    Features();
    void setConfig(FeaturesConfig& f);
    float applySignalFilters(float raw);
};

#endif
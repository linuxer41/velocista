#ifndef SENSOR_H
#define SENSOR_H

#include <stdint.h>
#include <esp_adc/adc_oneshot.h>
#include "config.h"

class QTR {
private:
    int16_t sensorValues[16];
    int16_t rawSensorValues[16];
    int16_t sensorMin[16];
    int16_t sensorMax[16];

public:
    float linePosition;

    QTR();
    void init();
    void setCalibration(int16_t minVals[], int16_t maxVals[]);
    void read();
    void calibrate();
    int16_t* getSensorValues();
    int16_t* getRawSensorValues();
};

#endif
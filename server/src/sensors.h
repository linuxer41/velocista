/**
 * ARCHIVO: sensors.h
 * DESCRIPCIÓN: Clase QTR para sensores de línea
 */

#ifndef SENSORS_H
#define SENSORS_H

#include <Arduino.h>
#include "eeprom_manager.h"

class QTR {
private:
  int sensorValues[NUM_SENSORS];
  int16_t sensorMin[NUM_SENSORS];
  int16_t sensorMax[NUM_SENSORS];

public:
  float linePosition;
  bool lineFound;


  QTR() : linePosition(0.0), lineFound(false) {
    for (int i = 0; i < NUM_SENSORS; i++) {
      sensorMin[i] = 0;
      sensorMax[i] = 1023;
    }
  }

  void init() {
    pinMode(SENSOR_POWER_PIN, OUTPUT);
    for (int i = 0; i < NUM_SENSORS; i++) {
      pinMode(SENSOR_PINS[i], INPUT);
    }
  }

  void setCalibration(int16_t minVals[], int16_t maxVals[]) {
    for (int i = 0; i < NUM_SENSORS; i++) {
      sensorMin[i] = minVals[i];
      sensorMax[i] = maxVals[i];
    }
  }

  void read() {
    int sum = 0;
    int weightedSum = 0;
    digitalWrite(SENSOR_POWER_PIN, HIGH);
    delayMicroseconds(100);
    for (int i = 0; i < NUM_SENSORS; i++) {
      int val = analogRead(SENSOR_PINS[i]);
      val = map(val, sensorMin[i], sensorMax[i], 0, 1000);
      val = constrain(val, 0, 1000);
      sensorValues[i] = val;
      int weight = 1000 - val;
      weightedSum += i * weight;
      sum += weight;
    }
    digitalWrite(SENSOR_POWER_PIN, LOW);

    if (sum > 0) {
      linePosition = ((float)weightedSum / sum) * 1000.0 - 2500.0;
      lineFound = true;
    } else {
      lineFound = false;
    }
  }

  void calibrate() {
    Serial.println("Calibrando sensores...");
    for (int i = 0; i < NUM_SENSORS; i++) {
      sensorMin[i] = 1023;
      sensorMax[i] = 0;
    }
    unsigned long start = millis();
    digitalWrite(SENSOR_POWER_PIN, HIGH);
    delayMicroseconds(100);
    while (millis() - start < 5000) {  // 5 segundos
      for (int i = 0; i < NUM_SENSORS; i++) {
        int val = analogRead(SENSOR_PINS[i]);
        if (val < sensorMin[i]) sensorMin[i] = val;
        if (val > sensorMax[i]) sensorMax[i] = val;
      }
      delay(10);
    }
    digitalWrite(SENSOR_POWER_PIN, LOW);
    // Save to config
    for (int i = 0; i < NUM_SENSORS; i++) {
      config.sensorMin[i] = sensorMin[i];
      config.sensorMax[i] = sensorMax[i];
    }
    saveConfig();
    Serial.println("Calibracion completada");
  }

  int* getSensorValues() {
    return sensorValues;
  }
};

#endif
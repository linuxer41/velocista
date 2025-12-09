#ifndef TASKS_H
#define TASKS_H

#include <stdint.h>

// Function declarations
void sensorsTask(void* pvParameters);
void motorsTask(void* pvParameters);
void telemetryTask(void* pvParameters);
void commandTask(void* pvParameters);

void leftEncoderISR(void* arg);
void rightEncoderISR(void* arg);

void updateModeLed(unsigned long currentMillis, unsigned long blinkInterval);
TelemetryData buildTelemetryData();
void processCommand(const char* cmd);

#endif
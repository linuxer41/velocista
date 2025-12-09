#include "robot.h"
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <esp_timer.h>
#include <esp_task_wdt.h>
#include <driver/uart.h>
#include <driver/gpio.h>
#include <string.h>
#include <stdio.h>
#include <math.h>

// Utility functions
template <typename T>
T constrain(T val, T min, T max) {
    if (val < min) return min;
    if (val > max) return max;
    return val;
}

// ISR
extern Motor* leftMotorPtr;
extern Motor* rightMotorPtr;

void IRAM_ATTR leftEncoderISR(void* arg) {
    if (leftMotorPtr) leftMotorPtr->updateEncoder();
}

void IRAM_ATTR rightEncoderISR(void* arg) {
    if (rightMotorPtr) rightMotorPtr->updateEncoder();
}

// Functions

void updateModeLed(unsigned long currentMillis, unsigned long blinkInterval) {
    static unsigned long lastLedTime = 0;
    static bool ledState = false;
    if (currentMillis - lastLedTime >= blinkInterval) {
        ledState = !ledState;
        gpio_set_level((gpio_num_t)MODE_LED_PIN, ledState);
        lastLedTime = currentMillis;
    }
}

TelemetryData buildTelemetryData() {
    TelemetryData data;
    if (xSemaphoreTake(sharedData.mutex, pdMS_TO_TICKS(10)) == pdTRUE) {
        int16_t* sensors = sharedData.sensorValues;
        memcpy(data.sensors, sensors, sizeof(data.sensors));

        data.linePos = sharedData.linePosition;
        data.lineError = robot.linePid.getError();
        data.linePidOut = robot.linePid.getOutput();
        data.lineIntegral = robot.linePid.getIntegral();
        data.lineDeriv = robot.linePid.getDerivative();
        data.lineProportional = robot.linePid.getProportional();
        data.lPidOut = robot.leftPid.getOutput();
        data.lError = robot.leftPid.getError();
        data.lIntegral = robot.leftPid.getIntegral();
        data.lDeriv = robot.leftPid.getDerivative();
        data.lProportional = robot.leftPid.getProportional();
        data.rPidOut = robot.rightPid.getOutput();
        data.rError = robot.rightPid.getError();
        data.rProportional = robot.rightPid.getProportional();
        data.rIntegral = robot.rightPid.getIntegral();
        data.rDeriv = robot.rightPid.getDerivative();
        data.uptime = esp_timer_get_time() / 1000;
        data.lRpm = robot.leftMotor.getRPM();
        data.rRpm = robot.rightMotor.getRPM();
        data.lFilteredRpm = robot.leftMotor.getFilteredRPM();
        data.rFilteredRpm = robot.rightMotor.getFilteredRPM();
        data.lTargetRpm = sharedData.leftTargetRPM;
        data.rTargetRpm = sharedData.rightTargetRPM;
        data.lPwm = robot.leftMotor.getSpeed();
        data.rPwm = robot.rightMotor.getSpeed();
        data.encLForward = robot.leftMotor.getEncForwardCount();
        data.encRForward = robot.rightMotor.getEncForwardCount();
        data.encLBackward = robot.leftMotor.getEncBackwardCount();
        data.encRBackward = robot.rightMotor.getEncBackwardCount();
        data.leftSpeedCms = (data.lRpm * M_PI * (config.wheelDiameter / 10.0)) / 60.0;
        data.rightSpeedCms = (data.rRpm * M_PI * (config.wheelDiameter / 10.0)) / 60.0;
        data.battery = 8.4;
        data.loopTime = 0; // TODO
        data.curvature = 0; // TODO
        data.sensorState = (uint8_t)sharedData.sensorState;
        xSemaphoreGive(sharedData.mutex);
    }
    return data;
}

void processCommand(const char* cmd) {
    if (strlen(cmd) == 0) return;

    bool handled = false;
    if (strcmp(cmd, "calibrate") == 0) {
        robot.leftMotor.setSpeed(0);
        robot.rightMotor.setSpeed(0);
        gpio_set_level((gpio_num_t)MODE_LED_PIN, 1);
        printf("Calibrating...\n");
        robot.qtr.calibrate();
        gpio_set_level((gpio_num_t)MODE_LED_PIN, 0);
        printf("Calibration complete.\n");
        handled = true;
    } else if (strcmp(cmd, "save") == 0) {
        robot.saveConfig();
        printf("Config saved.\n");
        handled = true;
    } else if (strcmp(cmd, "reset") == 0) {
        config.restoreDefaults();
        robot.saveConfig();
        robot.linePid.setGains(config.lineKp, config.lineKi, config.lineKd);
        robot.leftPid.setGains(config.leftKp, config.leftKi, config.leftKd);
        robot.rightPid.setGains(config.rightKp, config.rightKi, config.rightKd);
        printf("Config reset.\n");
        handled = true;
    } else if (strcmp(cmd, "help") == 0) {
        printf("Commands: calibrate, save, reset, help\n");
        handled = true;
    }

    if (!handled) {
        printf("Unknown command: %s\n", cmd);
    }
}

// Tasks
void sensorsTask(void* pvParameters) {
    unsigned long lastLineTime = esp_timer_get_time() / 1000;
    while (true) {
        unsigned long currentMillis = esp_timer_get_time() / 1000;
        if (xSemaphoreTake(sharedData.mutex, pdMS_TO_TICKS(10)) == pdTRUE) {
            if (currentMillis - lastLineTime >= config.loopLineMs) {
                lastLineTime = currentMillis;
                if (sharedData.operationMode == MODE_LINE_FOLLOWING) {
                    robot.qtr.read();
                    int16_t* rawSensors = robot.qtr.getRawSensorValues();
                    sharedData.sensorState = NORMAL;

                    float currentPosition = robot.features.applySignalFilters(robot.qtr.linePosition);

                    sharedData.linePosition = currentPosition;
                    memcpy(sharedData.sensorValues, robot.qtr.getSensorValues(), 16 * sizeof(int16_t));
                    memcpy(sharedData.rawSensorValues, rawSensors, 16 * sizeof(int16_t));
                }
            }
            xSemaphoreGive(sharedData.mutex);
        }
        vTaskDelay(pdMS_TO_TICKS(config.loopLineMs));
    }
}

void motorsTask(void* pvParameters) {
    // Subscribe to WDT
    esp_task_wdt_add(NULL);
    unsigned long lastSpeedTime = esp_timer_get_time() / 1000;
    while (true) {
        unsigned long currentMillis = esp_timer_get_time() / 1000;
        if (xSemaphoreTake(sharedData.mutex, pdMS_TO_TICKS(10)) == pdTRUE) {
            if (currentMillis - lastSpeedTime >= config.loopSpeedMs) {
                lastSpeedTime = currentMillis;
                float dtSpeed = config.loopSpeedMs / 1000.0;

                if (sharedData.operationMode == MODE_REMOTE_CONTROL) {
                    sharedData.leftTargetRPM = sharedData.throttle - sharedData.steering;
                    sharedData.rightTargetRPM = sharedData.throttle + sharedData.steering;
                    sharedData.leftTargetRPM = constrain(sharedData.leftTargetRPM, -config.maxRpm, config.maxRpm);
                    sharedData.rightTargetRPM = constrain(sharedData.rightTargetRPM, -config.maxRpm, config.maxRpm);
                } else if (sharedData.operationMode == MODE_LINE_FOLLOWING && sharedData.cascadeMode) {
                    float applyBaseRPM = config.baseRPM;

                    float pidOutput;
                    float error = 0 - sharedData.linePosition;
                    robot.linePid.setGains(config.lineKp, config.lineKi, config.lineKd);
                    pidOutput = robot.linePid.calculate(0, error, dtSpeed);

                    float rpmAdjustment = pidOutput * 0.5;
                    sharedData.leftTargetRPM = applyBaseRPM + rpmAdjustment;
                    sharedData.rightTargetRPM = applyBaseRPM - rpmAdjustment;
                }

                if (sharedData.operationMode == MODE_REMOTE_CONTROL || (sharedData.operationMode == MODE_LINE_FOLLOWING && sharedData.cascadeMode)) {
                    int leftSpeed = robot.leftPid.calculate(sharedData.leftTargetRPM, robot.leftMotor.getFilteredRPM(), dtSpeed);
                    int rightSpeed = robot.rightPid.calculate(sharedData.rightTargetRPM, robot.rightMotor.getFilteredRPM(), dtSpeed);

                    leftSpeed = constrain(leftSpeed, -(int)config.maxPwm, (int)config.maxPwm);
                    rightSpeed = constrain(rightSpeed, -(int)config.maxPwm, (int)config.maxPwm);

                    robot.leftMotor.setSpeed(leftSpeed);
                    robot.rightMotor.setSpeed(rightSpeed);
                } else if (sharedData.operationMode == MODE_IDLE) {
                    int leftSpeed = robot.leftPid.calculate(sharedData.leftTargetRPM, robot.leftMotor.getFilteredRPM(), dtSpeed);
                    int rightSpeed = robot.rightPid.calculate(sharedData.rightTargetRPM, robot.rightMotor.getFilteredRPM(), dtSpeed);

                    leftSpeed = constrain(leftSpeed, -(int)config.maxPwm, (int)config.maxPwm);
                    rightSpeed = constrain(rightSpeed, -(int)config.maxPwm, (int)config.maxPwm);

                    robot.leftMotor.setSpeed(leftSpeed);
                    robot.rightMotor.setSpeed(rightSpeed);
                }

                if (sharedData.operationMode == MODE_LINE_FOLLOWING) {
                    updateModeLed(currentMillis, 100);
                } else if (sharedData.operationMode == MODE_REMOTE_CONTROL) {
                    updateModeLed(currentMillis, 500);
                } else {
                    gpio_set_level((gpio_num_t)MODE_LED_PIN, 0);
                }
            }

            xSemaphoreGive(sharedData.mutex);
        }
        // Reset watchdog
        esp_task_wdt_reset();
        vTaskDelay(pdMS_TO_TICKS(config.loopSpeedMs));
    }
}

void telemetryTask(void* pvParameters) {
    unsigned long lastTelemetryTime = 0;
    while (true) {
        if (xSemaphoreTake(sharedData.mutex, portMAX_DELAY) == pdTRUE) {
            unsigned long currentMillis = esp_timer_get_time() / 1000;
            if (sharedData.telemetryEnabled && (currentMillis - lastTelemetryTime > config.telemetryIntervalMs)) {
                TelemetryData data = buildTelemetryData();
                printf("T:%f,%f,%f,%f\n", data.linePos, data.lRpm, data.rRpm, data.uptime / 1000.0);
                lastTelemetryTime = currentMillis;
            }
            xSemaphoreGive(sharedData.mutex);
        }
        vTaskDelay(pdMS_TO_TICKS(10));
    }
}

void commandTask(void* pvParameters) {
    uint8_t data[BUF_SIZE];
    static uint32_t lastButtonTime = 0;
    while (true) {
        int len = uart_read_bytes(UART_NUM, data, BUF_SIZE, pdMS_TO_TICKS(10));
        if (len > 0) {
            for (int i = 0; i < len; i++) {
                if (data[i] == '\n' || data[i] == '\r') {
                    serBuf[idx] = '\0';
                    if (idx > 0) {
                        processCommand((const char*)serBuf);
                    }
                    idx = 0;
                    lineReady = false;
                } else if (idx < sizeof(serBuf) - 1) {
                    serBuf[idx++] = data[i];
                }
            }
        }

        // Check calibration button
        uint32_t currentTime = esp_timer_get_time() / 1000;
        if (gpio_get_level((gpio_num_t)CALIBRATION_BUTTON_PIN) == 0 && (currentTime - lastButtonTime) > 500) {  // Debounce 500ms
            lastButtonTime = currentTime;
            // Trigger calibration
            robot.leftMotor.setSpeed(0);
            robot.rightMotor.setSpeed(0);
            gpio_set_level((gpio_num_t)MODE_LED_PIN, 1);
            printf("Calibrating sensors via button...\n");
            robot.qtr.calibrate();
            gpio_set_level((gpio_num_t)MODE_LED_PIN, 0);
            printf("Calibration complete.\n");
        }

        vTaskDelay(pdMS_TO_TICKS(10));
    }
}
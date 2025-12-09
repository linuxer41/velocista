#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <freertos/semphr.h>
#include <esp_log.h>
#include <nvs_flash.h>
#include <driver/gpio.h>
#include <driver/uart.h>
#include <esp_timer.h>
#include <string.h>
#include <stdio.h>
#include <math.h>

#include "config.h"
#include "robot.h"
#include "tasks.h"

extern "C" void app_main() {
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    robot.loadConfig();

    robot.init();

    sharedData.linePosition = 0;
    memset(sharedData.sensorValues, 0, 16 * sizeof(int16_t));
    memset(sharedData.rawSensorValues, 0, 16 * sizeof(int16_t));
    sharedData.sensorState = NORMAL;
    sharedData.leftTargetRPM = 0;
    sharedData.rightTargetRPM = 0;
    sharedData.throttle = 0;
    sharedData.steering = 0;
    sharedData.telemetryEnabled = config.telemetry;
    sharedData.operationMode = config.operationMode;
    sharedData.cascadeMode = config.cascadeMode;
    sharedData.mutex = xSemaphoreCreateMutex();

    robot.linePid.setGains(config.lineKp, config.lineKi, config.lineKd);
    robot.leftPid.setGains(config.leftKp, config.leftKi, config.leftKd);
    robot.rightPid.setGains(config.rightKp, config.rightKi, config.rightKd);
    robot.features.setConfig(config.features);
    robot.qtr.setCalibration(config.sensorMin, config.sensorMax);

    printf("Calibrating sensors...\n");
    robot.qtr.calibrate();
    printf("Calibration complete. Mode: %d\n", config.operationMode);

    xTaskCreate(sensorsTask, "Sensors", 4096, NULL, 2, NULL);
    xTaskCreate(motorsTask, "Motors", 4096, NULL, 2, NULL);
    xTaskCreate(telemetryTask, "Telemetry", 4096, NULL, 1, NULL);
    xTaskCreate(commandTask, "Commands", 4096, NULL, 1, NULL);
}
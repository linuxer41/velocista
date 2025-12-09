#include "sensor.h"
#include <string.h>
#include <esp_timer.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <driver/gpio.h>
#include <esp_adc/adc_oneshot.h>

QTR::QTR() : linePosition(0) {
    memset(sensorValues, 0, sizeof(sensorValues));
    memset(rawSensorValues, 0, sizeof(rawSensorValues));
    memset(sensorMin, 0, sizeof(sensorMin));
    memset(sensorMax, 0, sizeof(sensorMax));
}

void QTR::init() {
    // Initialize ADC unit
    adc_oneshot_unit_init_cfg_t init_config = {};
    init_config.unit_id = ADC_UNIT_1;
    init_config.ulp_mode = ADC_ULP_MODE_DISABLE;
    adc_oneshot_new_unit(&init_config, &adc_handle);

    // Configure ADC channel for GPIO34 (ADC1_6)
    adc_oneshot_chan_cfg_t chan_config = {
        .atten = ADC_ATTEN_DB_12,
        .bitwidth = ADC_BITWIDTH_12,
    };
    adc_oneshot_config_channel(adc_handle, ADC_CHANNEL_6, &chan_config);

    // Configure sensor power pin
    gpio_config_t io_conf = {};
    io_conf.intr_type = GPIO_INTR_DISABLE;
    io_conf.mode = GPIO_MODE_OUTPUT;
    io_conf.pin_bit_mask = (1ULL << SENSOR_POWER_PIN);
    io_conf.pull_down_en = GPIO_PULLDOWN_DISABLE;
    io_conf.pull_up_en = GPIO_PULLUP_DISABLE;
    gpio_config(&io_conf);
    gpio_set_level((gpio_num_t)SENSOR_POWER_PIN, 1);

    // Configure multiplexer select pins
    io_conf.pin_bit_mask = (1ULL << MUX_S0) | (1ULL << MUX_S1) | (1ULL << MUX_S2) | (1ULL << MUX_S3);
    gpio_config(&io_conf);
}

void QTR::setCalibration(int16_t minVals[], int16_t maxVals[]) {
    memcpy(sensorMin, minVals, sizeof(sensorMin));
    memcpy(sensorMax, maxVals, sizeof(sensorMax));
}

void QTR::read() {
    for (int i = 0; i < NUM_SENSORS; i++) {
        // Set multiplexer select pins
        gpio_set_level((gpio_num_t)MUX_S0, (i & 0x01));
        gpio_set_level((gpio_num_t)MUX_S1, (i & 0x02) >> 1);
        gpio_set_level((gpio_num_t)MUX_S2, (i & 0x04) >> 2);
        gpio_set_level((gpio_num_t)MUX_S3, (i & 0x08) >> 3);

        // Small delay for settling
        vTaskDelay(pdMS_TO_TICKS(1));

        int raw;
        adc_oneshot_read(adc_handle, ADC_CHANNEL_6, &raw);
        rawSensorValues[i] = raw;
        if (sensorMax[i] > sensorMin[i]) {
            sensorValues[i] = (raw - sensorMin[i]) * 1000 / (sensorMax[i] - sensorMin[i]);
        } else {
            sensorValues[i] = 0;
        }
    }

    int32_t avg = 0;
    int32_t sum = 0;
    for (int i = 0; i < NUM_SENSORS; i++) {
        int32_t value = sensorValues[i];
        avg += value * (i * 1000);
        sum += value;
    }
    if (sum > 0) {
        linePosition = (avg / sum - 8000) / (QTR_POSITION_SCALE * 2);  // Adjust for 16 sensors
    } else {
        linePosition = 0;
    }
}

void QTR::calibrate() {
    memset(sensorMin, 0x7FFF, sizeof(sensorMin));
    memset(sensorMax, 0, sizeof(sensorMax));
    uint32_t start = esp_timer_get_time();
    while ((esp_timer_get_time() - start) < 5000000) {
        for (int i = 0; i < NUM_SENSORS; i++) {
            // Set multiplexer
            gpio_set_level((gpio_num_t)MUX_S0, (i & 0x01));
            gpio_set_level((gpio_num_t)MUX_S1, (i & 0x02) >> 1);
            gpio_set_level((gpio_num_t)MUX_S2, (i & 0x04) >> 2);
            gpio_set_level((gpio_num_t)MUX_S3, (i & 0x08) >> 3);
            vTaskDelay(pdMS_TO_TICKS(1));

            int raw;
            adc_oneshot_read(adc_handle, ADC_CHANNEL_6, &raw);
            if (raw < sensorMin[i]) sensorMin[i] = raw;
            if (raw > sensorMax[i]) sensorMax[i] = raw;
        }
        vTaskDelay(pdMS_TO_TICKS(10));
    }
}

int16_t* QTR::getSensorValues() { return sensorValues; }
int16_t* QTR::getRawSensorValues() { return rawSensorValues; }
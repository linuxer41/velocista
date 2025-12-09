#include "robot.h"
#include "tasks.h"
#include <nvs_flash.h>
#include <esp_log.h>
#include <driver/uart.h>
#include <driver/gpio.h>

Robot::Robot() : leftMotor(MOTOR_LEFT_PIN1, MOTOR_LEFT_PIN2, LEFT, ENCODER_LEFT_A, ENCODER_LEFT_B),
                 rightMotor(MOTOR_RIGHT_PIN1, MOTOR_RIGHT_PIN2, RIGHT, ENCODER_RIGHT_A, ENCODER_RIGHT_B),
                 linePid(DEFAULT_LINE_KP, DEFAULT_LINE_KI, DEFAULT_LINE_KD, LIMIT_MAX_PWM, -LIMIT_MAX_PWM),
                 leftPid(DEFAULT_LEFT_KP, DEFAULT_LEFT_KI, DEFAULT_LEFT_KD, LIMIT_MAX_PWM, -LIMIT_MAX_PWM),
                 rightPid(DEFAULT_RIGHT_KP, DEFAULT_RIGHT_KI, DEFAULT_RIGHT_KD, LIMIT_MAX_PWM, -LIMIT_MAX_PWM) {}

void Robot::init() {
    leftMotor.init();
    rightMotor.init();
    qtr.init();
    features.setConfig(config.features);
    qtr.setCalibration(config.sensorMin, config.sensorMax);

    // Configure calibration button
    gpio_config_t button_conf = {};
    button_conf.intr_type = GPIO_INTR_DISABLE;
    button_conf.mode = GPIO_MODE_INPUT;
    button_conf.pin_bit_mask = (1ULL << CALIBRATION_BUTTON_PIN);
    button_conf.pull_down_en = GPIO_PULLDOWN_DISABLE;
    button_conf.pull_up_en = GPIO_PULLUP_ENABLE;
    gpio_config(&button_conf);

    // Initialize LED pin
    gpio_config_t io_conf = {};
    io_conf.intr_type = GPIO_INTR_DISABLE;
    io_conf.mode = GPIO_MODE_OUTPUT;
    io_conf.pin_bit_mask = (1ULL << MODE_LED_PIN);
    io_conf.pull_down_en = GPIO_PULLDOWN_DISABLE;
    io_conf.pull_up_en = GPIO_PULLUP_DISABLE;
    gpio_config(&io_conf);
    gpio_set_level((gpio_num_t)MODE_LED_PIN, 0);

    // Initialize UART
    uart_config_t uart_config = {
        .baud_rate = 115200,
        .data_bits = UART_DATA_8_BITS,
        .parity = UART_PARITY_DISABLE,
        .stop_bits = UART_STOP_BITS_1,
        .flow_ctrl = UART_HW_FLOWCTRL_DISABLE,
        .rx_flow_ctrl_thresh = 122,
        .source_clk = UART_SCLK_DEFAULT,
        .flags = {}
    };
    uart_param_config(UART_NUM, &uart_config);
    uart_set_pin(UART_NUM, UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE);
    uart_driver_install(UART_NUM, BUF_SIZE * 2, 0, 0, NULL, 0);

    // Initialize ISRs
    leftMotorPtr = &leftMotor;
    rightMotorPtr = &rightMotor;
    gpio_install_isr_service(0);
    gpio_isr_handler_add((gpio_num_t)ENCODER_LEFT_A, leftEncoderISR, nullptr);
    gpio_isr_handler_add((gpio_num_t)ENCODER_RIGHT_A, rightEncoderISR, nullptr);
}

// Global instance
Robot robot;

void Robot::loadConfig() {
    nvs_handle_t nvs_handle;
    esp_err_t err = nvs_open(NVS_NAMESPACE, NVS_READONLY, &nvs_handle);
    if (err != ESP_OK) {
        ESP_LOGI("CONFIG", "NVS open failed, using defaults");
        config.restoreDefaults();
        return;
    }

    size_t size = sizeof(RobotConfig);
    err = nvs_get_blob(nvs_handle, "config", &config, &size);
    if (err != ESP_OK) {
        ESP_LOGI("CONFIG", "NVS get failed, using defaults");
        config.restoreDefaults();
    }
    nvs_close(nvs_handle);
}

void Robot::saveConfig() {
    nvs_handle_t nvs_handle;
    esp_err_t err = nvs_open(NVS_NAMESPACE, NVS_READWRITE, &nvs_handle);
    if (err != ESP_OK) {
        ESP_LOGE("CONFIG", "NVS open failed for save");
        return;
    }

    err = nvs_set_blob(nvs_handle, "config", &config, sizeof(RobotConfig));
    if (err != ESP_OK) {
        ESP_LOGE("CONFIG", "NVS set failed");
    } else {
        nvs_commit(nvs_handle);
    }
    nvs_close(nvs_handle);
}
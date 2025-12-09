#include "motor.h"
#include <esp_timer.h>

Motor::Motor(uint8_t p1, uint8_t p2, Location loc, uint8_t encA, uint8_t encB)
    : pin1(p1), pin2(p2), speed(0), location(loc), forwardCount(0), backwardCount(0), lastCount(0),
      lastSpeedCheck(0), currentRPM(0), filteredRPM(0), targetRPM(0), encoderAPin(encA), encoderBPin(encB) {}

void Motor::init() {
    gpio_config_t io_conf = {};
    io_conf.intr_type = GPIO_INTR_DISABLE;
    io_conf.mode = GPIO_MODE_OUTPUT;
    io_conf.pin_bit_mask = (1ULL << pin1) | (1ULL << pin2);
    io_conf.pull_down_en = GPIO_PULLDOWN_DISABLE;
    io_conf.pull_up_en = GPIO_PULLUP_DISABLE;
    gpio_config(&io_conf);

    io_conf.intr_type = GPIO_INTR_POSEDGE;
    io_conf.mode = GPIO_MODE_INPUT;
    io_conf.pin_bit_mask = (1ULL << encoderAPin);
    io_conf.pull_down_en = GPIO_PULLDOWN_DISABLE;
    io_conf.pull_up_en = GPIO_PULLUP_ENABLE;
    gpio_config(&io_conf);

    ledc_timer_config_t ledc_timer = {
        .speed_mode = LEDC_MODE,
        .duty_resolution = LEDC_DUTY_RES,
        .timer_num = LEDC_TIMER,
        .freq_hz = LEDC_FREQUENCY,
        .clk_cfg = LEDC_AUTO_CLK,
        .deconfigure = false
    };
    ledc_timer_config(&ledc_timer);

    ledc_channel_config_t ledc_channel = {};
    ledc_channel.gpio_num = (gpio_num_t)pin1;
    ledc_channel.speed_mode = LEDC_MODE;
    ledc_channel.channel = (location == LEFT) ? LEDC_LEFT_CHANNEL : LEDC_RIGHT_CHANNEL;
    ledc_channel.intr_type = LEDC_INTR_DISABLE;
    ledc_channel.timer_sel = LEDC_TIMER;
    ledc_channel.duty = 0;
    ledc_channel.hpoint = 0;
    ledc_channel.flags.output_invert = 0;
    ledc_channel_config(&ledc_channel);

    lastSpeedCheck = esp_timer_get_time();
}

void Motor::setSpeed(int s) {
    speed = s;
    if (s > 0) {
        gpio_set_level((gpio_num_t)pin2, 0);
        ledc_set_duty(LEDC_MODE, (location == LEFT) ? LEDC_LEFT_CHANNEL : LEDC_RIGHT_CHANNEL, s);
        ledc_update_duty(LEDC_MODE, (location == LEFT) ? LEDC_LEFT_CHANNEL : LEDC_RIGHT_CHANNEL);
    } else if (s < 0) {
        gpio_set_level((gpio_num_t)pin2, 1);
        ledc_set_duty(LEDC_MODE, (location == LEFT) ? LEDC_LEFT_CHANNEL : LEDC_RIGHT_CHANNEL, -s);
        ledc_update_duty(LEDC_MODE, (location == LEFT) ? LEDC_LEFT_CHANNEL : LEDC_RIGHT_CHANNEL);
    } else {
        ledc_set_duty(LEDC_MODE, (location == LEFT) ? LEDC_LEFT_CHANNEL : LEDC_RIGHT_CHANNEL, 0);
        ledc_update_duty(LEDC_MODE, (location == LEFT) ? LEDC_LEFT_CHANNEL : LEDC_RIGHT_CHANNEL);
    }
}

int Motor::getSpeed() { return speed; }

float Motor::getRPM() {
    uint32_t now = esp_timer_get_time();
    uint32_t dt = now - lastSpeedCheck;
    if (dt > 0) {
        int32_t delta = forwardCount + backwardCount - lastCount;
        currentRPM = (delta * 60.0f * 1000000.0f) / (config.pulsesPerRevolution * dt);
        lastCount = forwardCount + backwardCount;
        lastSpeedCheck = now;
    }
    return currentRPM;
}

float Motor::getFilteredRPM() {
    filteredRPM = 0.9 * filteredRPM + 0.1 * getRPM();
    return filteredRPM;
}

void Motor::setTargetRPM(float t) { targetRPM = t; }
float Motor::getTargetRPM() { return targetRPM; }
long Motor::getEncForwardCount() { return forwardCount; }
long Motor::getEncBackwardCount() { return backwardCount; }

void Motor::updateEncoder() {
    if (speed >= 0) forwardCount += 1;
    else backwardCount += 1;
}
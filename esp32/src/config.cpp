#include "config.h"
#include <string.h>

// Implementations for FeaturesConfig
const char* FeaturesConfig::serialize() {
    static char buf[32];
    sprintf(buf, "%d,%d,%d,%d,%d,%d,%d,%d,%d",
            medianFilter, movingAverage, kalmanFilter, hysteresis, deadZone, lowPass, dynamicLinePid, speedProfiling, turnDirection);
    return buf;
}

bool FeaturesConfig::deserialize(const char* cmd) {
    int vals[9];
    if (sscanf(cmd, "%d,%d,%d,%d,%d,%d,%d,%d,%d",
               &vals[0], &vals[1], &vals[2], &vals[3], &vals[4], &vals[5], &vals[6], &vals[7], &vals[8]) != 9) {
        return false;
    }
    medianFilter = vals[0];
    movingAverage = vals[1];
    kalmanFilter = vals[2];
    hysteresis = vals[3];
    deadZone = vals[4];
    lowPass = vals[5];
    dynamicLinePid = vals[6];
    speedProfiling = vals[7];
    turnDirection = vals[8];
    return true;
}

void FeaturesConfig::setFeature(uint8_t idx, bool value) {
    switch (idx) {
        case 0: medianFilter = value; break;
        case 1: movingAverage = value; break;
        case 2: kalmanFilter = value; break;
        case 3: hysteresis = value; break;
        case 4: deadZone = value; break;
        case 5: lowPass = value; break;
        case 6: dynamicLinePid = value; break;
        case 7: speedProfiling = value; break;
        case 8: turnDirection = value; break;
    }
}

bool FeaturesConfig::getFeature(uint8_t idx) {
    switch (idx) {
        case 0: return medianFilter;
        case 1: return movingAverage;
        case 2: return kalmanFilter;
        case 3: return hysteresis;
        case 4: return deadZone;
        case 5: return lowPass;
        case 6: return dynamicLinePid;
        case 7: return speedProfiling;
        case 8: return turnDirection;
    }
    return false;
}

// Implementation for RobotConfig
void RobotConfig::restoreDefaults() {
    lineKp = DEFAULT_LINE_KP;
    lineKi = DEFAULT_LINE_KI;
    lineKd = DEFAULT_LINE_KD;
    leftKp = DEFAULT_LEFT_KP;
    leftKi = DEFAULT_LEFT_KI;
    leftKd = DEFAULT_LEFT_KD;
    rightKp = DEFAULT_RIGHT_KP;
    rightKi = DEFAULT_RIGHT_KI;
    rightKd = DEFAULT_RIGHT_KD;
    basePwm = DEFAULT_BASE_PWM;
    wheelDiameter = DEFAULT_WHEEL_DIAMETER_MM;
    wheelDistance = DEFAULT_WHEEL_DISTANCE_MM;
    memset(sensorMin, 0, sizeof(sensorMin));
    memset(sensorMax, 0, sizeof(sensorMax));
    rcDeadzone = DEFAULT_RC_DEADZONE;
    rcMaxThrottle = DEFAULT_RC_MAX_THROTTLE;
    rcMaxSteering = DEFAULT_RC_MAX_STEERING;
    cascadeMode = DEFAULT_CASCADE;
    telemetry = DEFAULT_TELEMETRY_ENABLED;
    features = DEFAULT_FEATURES;
    operationMode = DEFAULT_OPERATION_MODE;
    baseRPM = DEFAULT_BASE_RPM;
    maxPwm = DEFAULT_MAX_PWM;
    maxRpm = DEFAULT_MAX_RPM;
    pulsesPerRevolution = DEFAULT_PULSES_PER_REVOLUTION;
    loopLineMs = DEFAULT_LOOP_LINE_MS;
    loopSpeedMs = DEFAULT_LOOP_SPEED_MS;
    telemetryIntervalMs = DEFAULT_TELEMTRY_INTERVAL_MS;
    robotWeight = DEFAULT_ROBOT_WEIGHT;
}

// Global instances
const char* NVS_NAMESPACE = "robot_config";
RobotConfig config;
SharedData sharedData;

// Other globals
adc_oneshot_unit_handle_t adc_handle;
char serBuf[64];
bool lineReady = false;
uint8_t idx = 0;
Motor* leftMotorPtr;
Motor* rightMotorPtr;
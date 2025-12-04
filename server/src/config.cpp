#include "config.h"

// FeaturesConfig implementations
const char* FeaturesConfig::serialize() {
    static char buf[22];
    sprintf(buf, "[%d,%d,%d,%d,%d,%d,%d,%d,%d]", medianFilter, movingAverage, kalmanFilter, hysteresis, deadZone, lowPass, dynamicLinePid, speedProfiling, turnDirection);
    return buf;
}

bool FeaturesConfig::deserialize(const char* cmd) {
    // Parse comma separated values
    char temp[18];
    strcpy(temp, cmd);
    char* token = strtok(temp, ",");
    uint8_t idx = 0;
    while(token && idx < 9) {
      if(*token == '1') {
        setFeature(idx, true);
      } else if(*token == '0') {
        setFeature(idx, false);
      } else {
        return false; // Invalid
      }
      token = strtok(NULL, ",");
      idx++;
    }
    return idx == 9;
}

void FeaturesConfig::setFeature(uint8_t idx, bool value) {
    switch(idx) {
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
    switch(idx) {
      case 0: return medianFilter;
      case 1: return movingAverage;
      case 2: return kalmanFilter;
      case 3: return hysteresis;
      case 4: return deadZone;
      case 5: return lowPass;
      case 6: return dynamicLinePid;
      case 7: return speedProfiling;
      case 8: return turnDirection;
      default: return false;
    }
}

// RobotConfig implementations
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
     basePwm = DEFAULT_BASE_SPEED;
     wheelDiameter = DEFAULT_WHEEL_DIAMETER_MM;
     wheelDistance = DEFAULT_WHEEL_DISTANCE_MM;
     rcDeadzone = DEFAULT_RC_DEADZONE;
     rcMaxThrottle = DEFAULT_RC_MAX_THROTTLE;
     rcMaxSteering = DEFAULT_RC_MAX_STEERING;
     cascadeMode = DEFAULT_CASCADE;
     telemetry = DEFAULT_TELEMETRY_ENABLED;
     features = DEFAULT_FEATURES;
     operationMode = DEFAULT_OPERATION_MODE;
     baseRPM = DEFAULT_BASE_RPM;
     maxPwm = DEFAULT_MAX_SPEED;
     maxRpm = DEFAULT_MAX_RPM;
     pulsesPerRevolution = DEFAULT_PULSES_PER_REVOLUTION;
     loopLineMs = DEFAULT_LOOP_LINE_MS;
     loopSpeedMs = DEFAULT_LOOP_SPEED_MS;
     telemetryIntervalMs = DEFAULT_TELEMTRY_INTERVAL_MS;
     robotWeight = DEFAULT_ROBOT_WEIGHT;
     checksum = 1234567892;
     for (int i = 0; i < 8; i++) {
         sensorMin[i] = 0;
         sensorMax[i] = 1023;
     }
}

// Global config instance
RobotConfig config;

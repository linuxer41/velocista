/**
 * ARCHIVO: command_handler.h
 * DESCRIPCIÓN: Manejador de comandos seriales para el robot (header-only)
 */

#ifndef COMMAND_HANDLER_H
#define COMMAND_HANDLER_H

#include <Arduino.h>
#include "config.h"
#include "motor.h"
#include "sensors.h"
#include "pid.h"
#include "debugger.h"
#include "serial_reader.h"
#include "features.h"
#include "eeprom_manager.h"

// Extern declarations for global variables
extern Motor leftMotor;
extern Motor rightMotor;
extern QTR qtr;
extern PID linePid;
extern PID leftPid;
extern PID rightPid;
extern Debugger debugger;
extern Features features;
extern RobotConfig config;
extern float throttle;
extern float steering;
extern int16_t idleLeftPWM;
extern int16_t idleRightPWM;
extern float idleLeftTargetRPM;
extern float idleRightTargetRPM;

// Forward declaration for buildTelemetryData
TelemetryData buildTelemetryData();

// Estructura para comandos seriales
struct SerialCommand {
    const char* command;
    void (*handler)(const char* params);
};

// Helper function
inline int parseFloatArray(const char* params, float* values, int maxCount) {
    char temp[64];
    strcpy(temp, params);
    char* token = strtok(temp, ",");
    int count = 0;
    while (token && count < maxCount) {
        values[count++] = atof(token);
        token = strtok(NULL, ",");
    }
    return count;
}

// Implementaciones inline de handlers
inline void handleCalibrate(const char* params) {
    leftMotor.setSpeed(0);
    rightMotor.setSpeed(0);
    digitalWrite(MODE_LED_PIN, HIGH);
    debugger.systemMessage(F("Calibrando..."));
    qtr.calibrate();
    digitalWrite(MODE_LED_PIN, LOW);
    debugger.systemMessage(F("Calibración completada."));
}

inline void handleSave(const char* params) {
    saveConfig();
}

inline void handleGetDebug(const char* params) {
    TelemetryData data = buildTelemetryData();
    debugger.sendDebugData(data, config);
}

inline void handleGetTelemetry(const char* params) {
    TelemetryData data = buildTelemetryData();
    debugger.sendTelemetryData(data);
}

inline void handleGetConfig(const char* params) {
    debugger.sendConfigData(config);
}

inline void handleReset(const char* params) {
    config.restoreDefaults();
    saveConfig();
    linePid.setGains(config.lineKp, config.lineKi, config.lineKd);
    leftPid.setGains(config.leftKp, config.leftKi, config.leftKd);
    rightPid.setGains(config.rightKp, config.rightKi, config.rightKd);
}

inline void handleHelp(const char* params) {
    debugger.systemMessage(F("Comandos: calibrate, save, get debug, get telemetry, get config, reset, help"));
    debugger.systemMessage(F("set telemetry 0/1  |  set mode 0/1/2  |  set cascade 0/1"));
    debugger.systemMessage(F("set feature <idx 0-8> 0/1  |  set features 0,1,0,...  |  set line kp,ki,kd  |  set left kp,ki,kd  |  set right kp,ki,kd"));
    debugger.systemMessage(F("set base <pwm>,<rpm>  |  set max <pwm>,<rpm>  |  set weight <g>  |  set samp_rate <line_ms>,<speed_ms>,<telemetry_ms>"));
    debugger.systemMessage(F("set pwm <derecha>,<izquierda>  (solo en modo idle)"));
    debugger.systemMessage(F("set rpm <izquierda>,<derecha>  (solo en modo idle)"));
}

inline void handleSetTelemetry(const char* params) {
    char* end;
    int val = strtol(params, &end, 10);
    if (end == params || *end != '\0') { debugger.systemMessage(F("Falta argumento")); return; }
    config.telemetry = (val == 1);
    saveConfig();
}

inline void handleSetMode(const char* params) {
    char* end;
    int m = strtol(params, &end, 10);
    if (end == params || *end != '\0') { debugger.systemMessage(F("Falta argumento")); return; }
    config.operationMode = (OperationMode)m;
    if (config.operationMode == MODE_REMOTE_CONTROL) {
        throttle = 0; steering = 0;
        leftMotor.setSpeed(0); rightMotor.setSpeed(0);
    } else if (config.operationMode == MODE_IDLE) {
        idleLeftPWM = 0;
        idleRightPWM = 0;
        idleLeftTargetRPM = 0;
        idleRightTargetRPM = 0;
        leftMotor.setSpeed(0); rightMotor.setSpeed(0);
    }
}

inline void handleSetCascade(const char* params) {
    char* end;
    int val = strtol(params, &end, 10);
    if (end == params || *end != '\0') { debugger.systemMessage(F("Falta argumento")); return; }
    config.cascadeMode = (val == 1);
}

inline void handleSetFeature(const char* params) {
    const char* p = params;
    char* end1;
    int idx = strtol(p, &end1, 10);
    if (end1 == p || *end1 != ' ') { debugger.systemMessage(F("Formato: set feature <idx> <0/1>")); return; }
    char* end2;
    int val = strtol(end1 + 1, &end2, 10);
    if (end2 == end1 + 1 || *end2 != '\0' || idx < 0 || idx > 8) { debugger.systemMessage(F("Formato: set feature <idx> <0/1>")); return; }
    config.features.setFeature(idx, val == 1);
    features.setConfig(config.features);
}

inline void handleSetFeatures(const char* params) {
    if (config.features.deserialize(params)) {
        features.setConfig(config.features);
    } else {
        debugger.systemMessage(F("Formato: set features 0,1,0,1,... (9 valores)"));
    }
}

inline void handleSetLine(const char* params) {
    float values[3];
    int count = parseFloatArray(params, values, 3);
    if (count != 3) { debugger.systemMessage(F("Formato: set line kp,ki,kd")); return; }
    config.lineKp = values[0]; config.lineKi = values[1]; config.lineKd = values[2];
    linePid.setGains(values[0], values[1], values[2]);
}

inline void handleSetLeft(const char* params) {
    float values[3];
    int count = parseFloatArray(params, values, 3);
    if (count != 3) { debugger.systemMessage(F("Formato: set left kp,ki,kd")); return; }
    config.leftKp = values[0]; config.leftKi = values[1]; config.leftKd = values[2];
    leftPid.setGains(values[0], values[1], values[2]);
}

inline void handleSetRight(const char* params) {
    float values[3];
    int count = parseFloatArray(params, values, 3);
    if (count != 3) { debugger.systemMessage(F("Formato: set right kp,ki,kd")); return; }
    config.rightKp = values[0]; config.rightKi = values[1]; config.rightKd = values[2];
    rightPid.setGains(values[0], values[1], values[2]);
}

inline void handleSetBase(const char* params) {
    char* comma = strchr(params, ',');
    if (!comma) { debugger.systemMessage(F("Formato: set base <pwm>,<rpm>")); return; }
    int pwm = atoi(params);
    float rpm = atof(comma + 1);
    config.basePwm = constrain(pwm, -LIMIT_MAX_PWM, LIMIT_MAX_PWM);
    config.baseRPM = constrain(rpm, -LIMIT_MAX_RPM, LIMIT_MAX_RPM);
}

inline void handleSetMax(const char* params) {
    char* comma = strchr(params, ',');
    if (!comma) { debugger.systemMessage(F("Formato: set max <pwm>,<rpm>")); return; }
    int pwm = atoi(params);
    float rpm = atof(comma + 1);
    config.maxPwm = constrain(pwm, 0, LIMIT_MAX_PWM);
    config.maxRpm = constrain(rpm, 0, LIMIT_MAX_RPM);
}

inline void handleSetWeight(const char* params) {
    float weight = atof(params);
    if (weight <= 0) { debugger.systemMessage(F("Peso debe ser mayor a 0")); return; }
    config.robotWeight = weight;
    saveConfig();
}

inline void handleSetSampRate(const char* params) {
    char* comma1 = strchr(params, ',');
    if (!comma1) { debugger.systemMessage(F("Formato: set samp_rate <line_ms>,<speed_ms>,<telemetry_ms>")); return; }
    char* comma2 = strchr(comma1 + 1, ',');
    if (!comma2) { debugger.systemMessage(F("Formato: set samp_rate <line_ms>,<speed_ms>,<telemetry_ms>")); return; }
    int lineMs = atoi(params);
    int speedMs = atoi(comma1 + 1);
    int telemetryMs = atoi(comma2 + 1);
    if (lineMs <= 0 || speedMs <= 0 || telemetryMs <= 0) { debugger.systemMessage(F("Valores deben ser mayores a 0")); return; }
    config.loopLineMs = lineMs;
    config.loopSpeedMs = speedMs;
    config.telemetryIntervalMs = telemetryMs;
    saveConfig();
}

inline void handleRc(const char* params) {
    char* comma = strchr(params, ',');
    if (!comma) { debugger.systemMessage(F("Formato: rc throttle,steering")); return; }
    float t = atof(params);
    float s = atof(comma + 1);
    throttle = t;
    steering = s;
}

inline void handleSetPwm(const char* params) {
    if (config.operationMode != MODE_IDLE) {
        debugger.systemMessage(F("Comando solo disponible en modo idle"));
        return;
    }
    char* comma = strchr(params, ',');
    if (!comma) {
        debugger.systemMessage(F("Formato: set pwm <derecha>,<izquierda>"));
        return;
    }
    char* end1;
    int rightVal = strtol(params, &end1, 10);
    if (end1 != comma) {
        debugger.systemMessage(F("Formato: set pwm <derecha>,<izquierda>"));
        return;
    }
    char* end2;
    int leftVal = strtol(comma + 1, &end2, 10);
    if (*end2 != '\0') {
        debugger.systemMessage(F("Formato: set pwm <derecha>,<izquierda>"));
        return;
    }
    idleRightPWM = rightVal;
    idleLeftPWM = leftVal;
}

inline void handleSetRpm(const char* params) {
    if (config.operationMode != MODE_IDLE) {
        debugger.systemMessage(F("Comando solo disponible en modo idle"));
        return;
    }
    char* comma = strchr(params, ',');
    if (!comma) {
        debugger.systemMessage(F("Formato: set rpm <izquierda>,<derecha>"));
        return;
    }
    float leftRPM = atof(params);
    float rightRPM = atof(comma + 1);
    idleLeftTargetRPM = leftRPM;
    idleRightTargetRPM = rightRPM;
    leftPid.reset();
    rightPid.reset();
}

// Array de comandos
SerialCommand commands[] = {
    {"calibrate", handleCalibrate},
    {"save", handleSave},
    {"get debug", handleGetDebug},
    {"get telemetry", handleGetTelemetry},
    {"get config", handleGetConfig},
    {"reset", handleReset},
    {"help", handleHelp},
    {"set telemetry ", handleSetTelemetry},
    {"set mode ", handleSetMode},
    {"set cascade ", handleSetCascade},
    {"set feature ", handleSetFeature},
    {"set features ", handleSetFeatures},
    {"set line ", handleSetLine},
    {"set left ", handleSetLeft},
    {"set right ", handleSetRight},
    {"set base ", handleSetBase},
    {"set max ", handleSetMax},
    {"set weight ", handleSetWeight},
    {"set samp_rate ", handleSetSampRate},
    {"rc ", handleRc},
    {"set pwm ", handleSetPwm},
    {"set rpm ", handleSetRpm},
    {NULL, NULL} // Fin del array
};

#endif
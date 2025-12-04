/**
 * ARCHIVO: robot.h
 * DESCRIPCIÓN: Clase Robot para encapsular la lógica principal del robot
 */

#ifndef ROBOT_H
#define ROBOT_H

#include <Arduino.h>
#include <string.h>
#include "config.h"

enum SensorState { NORMAL, ALL_BLACK, ALL_WHITE };

enum Location {
  LEFT,
  RIGHT
};

// Struct for telemetry data
struct TelemetryData {
  // Posición y modo
  float linePos;
  float curvature;
  uint8_t sensorState;

  // Sensores
  int16_t sensors[8];  // Cambiado de int a int16_t
  uint32_t uptime;  // Cambiado de unsigned long a uint32_t

  // PID de línea
  float linePidOut, lineError, lineIntegral, lineDeriv;

  // PID izquierdo
  float lPidOut, lError, lIntegral, lDeriv;

  // PID derecho
  float rPidOut, rError, rIntegral, rDeriv;

  // Velocidades
  float lRpm, rRpm, lTargetRpm, rTargetRpm;
  int16_t lSpeed, rSpeed;  // Cambiado de int a int16_t

  // Contadores encoder
  int32_t encL, encR, encLBackward, encRBackward;  // Cambiado de long a int32_t

  // Velocidades lineales (cm/s)
  float leftSpeedCms, rightSpeedCms;

  // Sistema
  float battery;
  uint32_t loopTime;  // Cambiado de unsigned long a uint32_t

};

class Motor {
private:
  uint8_t pin1, pin2;  // Reducido de int a uint8_t para pines
  int16_t speed;  // Cambiado de int a int16_t
  Location location;
  volatile int32_t forwardCount;  // Cambiado de long a int32_t
  volatile int32_t backwardCount;  // Cambiado de long a int32_t
  int32_t lastCount;  // Cambiado de long a int32_t
  uint32_t lastSpeedCheck;  // Cambiado de unsigned long a uint32_t
  float currentRPM;
  float filteredRPM;
  float targetRPM;
  uint8_t encoderAPin, encoderBPin;  // Reducido de int a uint8_t para pines

public:
  Motor(uint8_t p1, uint8_t p2, Location loc, uint8_t encA, uint8_t encB);

  void init();

  void setSpeed(int s);

  int getSpeed();

  float getRPM();

  float getFilteredRPM();

  void setTargetRPM(float t);

  float getTargetRPM();

  long getEncoderCount();

  long getBackwardCount();

  void updateEncoder();
};

class PID {
private:
  float kp, ki, kd;
  float error, lastError, integral, derivative;
  float output;
  bool antiWindupEnabled;
  float maxOutput, minOutput;

public:
   PID(float p, float i, float d, float maxOut, float minOut);

  void setGains(float p, float i, float d);

  float calculate(float setpoint, float measurement, float dt);

  void reset();

  float getOutput();

  float getError();

  float getIntegral();

  float getDerivative();
};

class Features {
private:
    FeaturesConfig config;

    // Median filter
    int16_t medianBuffer[3];
    uint8_t medianCount;
    // Moving average
    int16_t movingBuffer[3];
    int32_t movingSum;
    uint8_t movingCount;
    // Kalman
    int16_t kalmanX, kalmanP;
    // Hysteresis
    int16_t hysteresisLast;
    // Low pass
    int16_t lowPassLast;

    // Bubble sort for median
    void sort(float arr[], int n);

public:
    Features();

    void setConfig(FeaturesConfig& f);

    float applySignalFilters(float raw);
};

class QTR {
private:
  int16_t sensorValues[8];  // Reducido de int a int16_t
  int16_t rawSensorValues[8];  // Reducido de int a int16_t
  int16_t sensorMin[8];
  int16_t sensorMax[8];

public:
  float linePosition;

  QTR();

  void init();

  void setCalibration(int16_t minVals[], int16_t maxVals[]);

  void read();

  void calibrate();

  int16_t* getSensorValues();

  int16_t* getRawSensorValues();
};

class Debugger {
public:
  Debugger();

  // Mensaje de sistema (comandos, estados, etc.)
  void systemMessage(const char* msg);

  void systemMessage(const String& msg);

  // Datos de debug telemetry (telemetría reducida)
  void sendTelemetryData(TelemetryData& data, bool endLine = true);

  void sendDebugData(TelemetryData& data, RobotConfig& config);

  // Datos de configuración
  void sendConfigData(RobotConfig& config, bool endLine = true);

  // Confirmación de comando procesado
  void ackMessage(const char* cmd);

};

class SerialReader {
private:
    char serBuf[64];
    bool lineReady;
    uint8_t idx;

public:
    SerialReader();

    void fillBuffer();

    bool getLine(const char **buf);
};

class EEPROMManager {
public:
  EEPROMManager();

  RobotConfig& getConfig();

  void load();

  void save();
};

// Función global para guardar configuración
void saveConfig();

class Robot;

struct SerialCommand {
    const char* command;
    void (*handler)(Robot* self, const char* params);
};

class Robot {
private:
    // Instancias de clases
    Motor leftMotor;
    Motor rightMotor;
    EEPROMManager eeprom;
    QTR qtr;
    PID linePid;
    PID leftPid;
    PID rightPid;
    Debugger debugger;
    SerialReader serialReader;
    Features features;

    // Static pointers for ISRs
    static Motor* leftMotorPtr;
    static Motor* rightMotorPtr;

    // ISR functions
    static void leftEncoderISR();
    static void rightEncoderISR();

    // Variables de estado
    float lastPidOutput;
    unsigned long lastTelemetryTime;
    unsigned long lastLineTime;
    unsigned long lastSpeedTime;
    int16_t lastLinePosition;
    unsigned long loopTime;
    unsigned long loopStartTime;
    float leftTargetRPM;
    float rightTargetRPM;
    float throttle;
    float steering;
    // LED indication
    unsigned long lastLedTime;
    bool ledState;
    // Variables para mejoras dinámicas
    float previousLinePosition;
    float currentCurvature;
    float filteredCurvature; // Filtro para suavizar curvatura
    SensorState currentSensorState;
    int lastTurnDirection; // 1 para derecha, -1 para izquierda
    // Idle mode PWM
    int16_t idleLeftPWM;
    int16_t idleRightPWM;
    // Idle mode RPM targets
    float idleLeftTargetRPM;
    float idleRightTargetRPM;
    
    // Auto-tuning variables
    bool autoTuningActive;
    unsigned long autoTuneStartTime;
    unsigned long autoTuneTestStartTime;
    int currentTestIndex;
    int totalTests;
    float bestIAE;
    float bestKp, bestKi, bestKd;
    float originalKp, originalKi, originalKd;
    float testKp[6], testKi[6], testKd[6];
    float accumulatedIAE;
    int samplesCount;
    float lastPosition;
    float maxDeviation;

    // Funciones auxiliares
    SensorState checkSensorState(int16_t* rawSensors);
    void updateModeLed(unsigned long currentMillis, unsigned long blinkInterval);
    // Command handling
    SerialCommand commands[24];
    static void handleCalibrate(Robot* self, const char* params);
    static void handleAutoTune(Robot* self, const char* params);
    static void handleSave(Robot* self, const char* params);
    static void handleGetDebug(Robot* self, const char* params);
    static void handleGetTelemetry(Robot* self, const char* params);
    static void handleGetConfig(Robot* self, const char* params);
    static void handleReset(Robot* self, const char* params);
    static void handleHelp(Robot* self, const char* params);
    static void handleSetTelemetry(Robot* self, const char* params);
    static void handleSetMode(Robot* self, const char* params);
    static void handleSetCascade(Robot* self, const char* params);
    static void handleSetFeature(Robot* self, const char* params);
    static void handleSetFeatures(Robot* self, const char* params);
    static void handleSetLine(Robot* self, const char* params);
    static void handleSetLeft(Robot* self, const char* params);
    static void handleSetRight(Robot* self, const char* params);
    static void handleSetBase(Robot* self, const char* params);
    static void handleSetMax(Robot* self, const char* params);
    static void handleSetWeight(Robot* self, const char* params);
    static void handleSetSampRate(Robot* self, const char* params);
    static void handleRc(Robot* self, const char* params);
    static void handleSetPwm(Robot* self, const char* params);
    static void handleSetRpm(Robot* self, const char* params);
    static int parseFloatArray(const char* params, float* values, int maxCount);
    
    // Auto-tuning methods
    void performAutoTune(float currentPosition, float dtLine);
    void generateTestParameters();

public:
    Robot();

    void init();
    void run();
    void processCommand(const char* cmd);
    TelemetryData buildTelemetryData();
};

#endif
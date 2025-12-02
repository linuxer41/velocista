#include <EEPROM.h>
#include "config.h"
#include "eeprom_manager.h"
#include "motor.h"
#include "sensors.h"
#include "pid.h"
#include "debugger.h"
#include "serial_reader.h"
#include "features.h"

// ==========================
// ENUMS Y FUNCIONES AUXILIARES
// ==========================
enum SensorState { NORMAL, ALL_BLACK, ALL_WHITE };

SensorState checkSensorState(int16_t* rawSensors) {
    bool allBlack = true;
    bool allWhite = true;
    for(int i = 0; i < NUM_SENSORS; i++) {
        int range = config.sensorMax[i] - config.sensorMin[i];
        if(range > 0) {
            if(rawSensors[i] > config.sensorMin[i] + 0.3 * range) {
                allBlack = false;
            }
            if(rawSensors[i] < config.sensorMax[i] - 0.3 * range) {
                allWhite = false;
            }
        } else {
            allBlack = false;
            allWhite = false;
        }
    }
    if(allBlack) return ALL_BLACK;
    if(allWhite) return ALL_WHITE;
    return NORMAL;
}

// ==========================
// INSTANCIAS DE CLASES
// ==========================
Motor leftMotor(MOTOR_LEFT_PIN1, MOTOR_LEFT_PIN2, LEFT, ENCODER_LEFT_A, ENCODER_LEFT_B);
Motor rightMotor(MOTOR_RIGHT_PIN1, MOTOR_RIGHT_PIN2, RIGHT, ENCODER_RIGHT_A, ENCODER_RIGHT_B);
EEPROMManager eeprom;
QTR qtr;
PID linePid(DEFAULT_LINE_KP, DEFAULT_LINE_KI, DEFAULT_LINE_KD);
PID leftPid(DEFAULT_LEFT_KP, DEFAULT_LEFT_KI, DEFAULT_LEFT_KD);
PID rightPid(DEFAULT_RIGHT_KP, DEFAULT_RIGHT_KI, DEFAULT_RIGHT_KD);
Debugger debugger;
SerialReader serialReader;
Features features;

// ==========================
// VARIABLES GLOBALES
// ==========================
float lastPidOutput = 0;
unsigned long lastTelemetryTime = 0;
unsigned long lastLineTime = 0;
unsigned long lastSpeedTime = 0;
int16_t lastLinePosition = 0;
unsigned long loopTime = 0;
unsigned long loopStartTime = 0;
float leftTargetRPM = 0;
float rightTargetRPM = 0;
float throttle = 0;
float steering = 0;
// LED indication
unsigned long lastLedTime = 0;
bool ledState = false;
// Variables para mejoras dinámicas
float previousLinePosition = 0;
float currentCurvature = 0;
SensorState currentSensorState = NORMAL;
// Idle mode PWM
int16_t idleLeftPWM = 0;
int16_t idleRightPWM = 0;
// Idle mode RPM targets
float idleLeftTargetRPM = 0;
float idleRightTargetRPM = 0;


// ==========================
// FUNCIONES AUXILIARES
// ==========================
TelemetryData buildTelemetryData();


// ==========================
// INTERRUPT SERVICE ROUTINES
// ==========================
void leftEncoderISR() {
  leftMotor.updateEncoder();
}

void rightEncoderISR() {
  rightMotor.updateEncoder();
}

// ==========================
// SETUP
// ==========================
void setup() {
  Serial.begin(115200);
  while (!Serial);

  leftMotor.init();
  rightMotor.init();
  attachInterrupt(digitalPinToInterrupt(ENCODER_LEFT_A), leftEncoderISR, RISING);
  attachInterrupt(digitalPinToInterrupt(ENCODER_RIGHT_A), rightEncoderISR, RISING);
  qtr.init();
  pinMode(MODE_LED_PIN, OUTPUT);
  digitalWrite(MODE_LED_PIN, LOW);  // Start with LED off (idle mode)

  // Cargar configuración (EEPROMManager ya carga valores por defecto si inválidos)

  eeprom.load();
  // Configurar ganancias PID después de cargar
  linePid.setGains(config.lineKp, config.lineKi, config.lineKd);
  leftPid.setGains(config.leftKp, config.leftKi, config.leftKd);
  rightPid.setGains(config.rightKp, config.rightKi, config.rightKd);
  // Configurar features
  features.setConfig(config.features);

  qtr.setCalibration(config.sensorMin, config.sensorMax);

  
  qtr.calibrate();


  char msg[20];  // Reducido de 30 a 20
  sprintf(msg, "Robot iniciado. Modo: %d", config.operationMode);
  debugger.systemMessage(msg);
  lastLineTime = millis();
  lastSpeedTime = millis();
}

// ==========================
// DEBUG Telemetry
// ==========================
TelemetryData buildTelemetryData() {
  TelemetryData data;
  qtr.read();  // Read sensors even in non-line-follower modes
  int16_t* sensors = qtr.getSensorValues();
  memcpy(data.sensors, sensors, sizeof(data.sensors));

  data.linePos = qtr.linePosition;
  data.lineError = linePid.getError();
  data.linePidOut = lastPidOutput;
  data.lineIntegral = linePid.getIntegral();
  data.lineDeriv = linePid.getDerivative();
  data.lPidOut = leftPid.getOutput();
  data.lError = leftPid.getError();
  data.lIntegral = leftPid.getIntegral();
  data.lDeriv = leftPid.getDerivative();
  data.rPidOut = rightPid.getOutput();
  data.rError = rightPid.getError();
  data.rIntegral = rightPid.getIntegral();
  data.rDeriv = rightPid.getDerivative();
  data.uptime = millis();
  data.lRpm = leftMotor.getRPM();
  data.rRpm = rightMotor.getRPM();
  data.lTargetRpm = leftTargetRPM;
  data.rTargetRpm = rightTargetRPM;
  data.lSpeed = leftMotor.getSpeed();
  data.rSpeed = rightMotor.getSpeed();
  data.encL = leftMotor.getEncoderCount();
  data.encR = rightMotor.getEncoderCount();
  data.encLBackward = leftMotor.getBackwardCount();
  data.encRBackward = rightMotor.getBackwardCount();
  data.leftSpeedCms = (data.lRpm * PI * (config.wheelDiameter / 10.0)) / 60.0;
  data.rightSpeedCms = (data.rRpm * PI * (config.wheelDiameter / 10.0)) / 60.0;
  data.battery = analogRead(BATTERY_PIN) * BATTERY_FACTOR;
  data.loopTime = loopTime;
  data.curvature = currentCurvature;
  data.sensorState = (uint8_t)currentSensorState;
  return data;
}

// ==========================
// LOOP PRINCIPAL
// ==========================
void loop() {
  unsigned long currentMillis = millis();

  if (currentMillis - lastLineTime >= config.loopLineMs) {
    lastLineTime = currentMillis;
    float dtLine = config.loopLineMs / 1000.0;

    if (config.operationMode == MODE_LINE_FOLLOWING) {
       qtr.read();
        int16_t* rawSensors = qtr.getRawSensorValues();
        // Verificar estado de sensores
        SensorState state = checkSensorState(rawSensors);
        currentSensorState = state;

        // Calcular curvatura para ajustes dinámicos
       float currentPosition = features.applySignalFilters(qtr.linePosition);
       float curvature = abs(currentPosition - previousLinePosition) / dtLine;
       previousLinePosition = currentPosition;
       currentCurvature = curvature;

       // Ajustes dinámicos de velocidad base
       float applyBaseRPM = config.baseRPM;
       int applyBaseSpeed = config.basePwm;
       if(config.features.speedProfiling) {
         if(curvature > 500 || state == ALL_BLACK) {  // Alta curvatura o pérdida de línea
           applyBaseRPM = max(60.0f, applyBaseRPM - 30.0f);
           applyBaseSpeed = max(100, applyBaseSpeed - 50);
         } else if(curvature < 100) {  // Baja curvatura (recta)
           applyBaseRPM = min(config.baseRPM + 20.0f, applyBaseRPM + 10.0f);
           applyBaseSpeed = min(config.maxPwm, applyBaseSpeed + 20);
         }
       }

       float pidOutput;
       if(state == ALL_BLACK) {
         pidOutput = config.features.turnDirection ? 200 : -200;  // girar según feature: derecha o izquierda
       } else if(state == ALL_WHITE) {
         pidOutput = 200;   // girar a la derecha rápidamente cuando todos los sensores están en blanco
       } else {
         lastLinePosition = currentPosition;
         float error = 0 - lastLinePosition;
         // Ajuste dinámico de ganancias PID basado en curvatura
         if(config.features.dynamicLinePid) {
           float dynamicKp = config.lineKp + curvature * 0.001;  // Factor pequeño para ajuste
           float dynamicKd = config.lineKd + curvature * 0.0005;
           linePid.setGains(dynamicKp, config.lineKi, dynamicKd);
         } else {
           linePid.setGains(config.lineKp, config.lineKi, config.lineKd);
         }
         pidOutput = linePid.calculate(0, error, dtLine);
       }
       lastPidOutput = pidOutput;

      if (config.cascadeMode) {
         // Set target RPMs for cascade control
         float rpmAdjustment = pidOutput * 0.5;
         leftTargetRPM = applyBaseRPM + rpmAdjustment;
         rightTargetRPM = applyBaseRPM - rpmAdjustment;
       } else {
        // Open-loop control
        int leftSpeed = applyBaseSpeed + pidOutput;
        int rightSpeed = applyBaseSpeed - pidOutput;
        leftSpeed = constrain(leftSpeed, -config.maxPwm, config.maxPwm);
        rightSpeed = constrain(rightSpeed, -config.maxPwm, config.maxPwm);
        leftMotor.setSpeed(leftSpeed);
        rightMotor.setSpeed(rightSpeed);
      }
    }
  }

  if (currentMillis - lastSpeedTime >= config.loopSpeedMs) {
    lastSpeedTime = currentMillis;
    loopStartTime = micros();
    float dtSpeed = config.loopSpeedMs / 1000.0;

    if (config.operationMode == MODE_REMOTE_CONTROL) {
      // Always cascade for remote control
      leftTargetRPM = throttle - steering;
      rightTargetRPM = throttle + steering;
    } else if (config.operationMode == MODE_LINE_FOLLOWING && config.cascadeMode) {
      // targetRPMs already set in line loop
    }

    if (config.operationMode == MODE_REMOTE_CONTROL || (config.operationMode == MODE_LINE_FOLLOWING && config.cascadeMode)) {
        // Calculate PID for each motor
        int leftSpeed = leftPid.calculate(leftTargetRPM, leftMotor.getRPM(), dtSpeed);
        int rightSpeed = rightPid.calculate(rightTargetRPM, rightMotor.getRPM(), dtSpeed);

        leftSpeed = constrain(leftSpeed, -config.maxPwm, config.maxPwm);
        rightSpeed = constrain(rightSpeed, -config.maxPwm, config.maxPwm);

        // Actualizar velocidad máxima registrada
        int currentMax = max(abs(leftSpeed), abs(rightSpeed));
        if(currentMax > config.maxPwm) {
          config.maxPwm = currentMax;
          saveConfig();
        }

        leftMotor.setSpeed(leftSpeed);
        rightMotor.setSpeed(rightSpeed);
      } else if (config.operationMode == MODE_IDLE) {
        if (idleLeftTargetRPM != 0 || idleRightTargetRPM != 0) {
          // Idle RPM control with PID
          int leftSpeed = leftPid.calculate(idleLeftTargetRPM, leftMotor.getRPM(), dtSpeed);
          int rightSpeed = rightPid.calculate(idleRightTargetRPM, rightMotor.getRPM(), dtSpeed);

          leftSpeed = constrain(leftSpeed, -config.maxPwm, config.maxPwm);
          rightSpeed = constrain(rightSpeed, -config.maxPwm, config.maxPwm);

          leftMotor.setSpeed(leftSpeed);
          rightMotor.setSpeed(rightSpeed);
        } else {
          // Direct PWM control
          leftMotor.setSpeed(idleLeftPWM);
          rightMotor.setSpeed(idleRightPWM);
        }
      }

    loopTime = micros() - loopStartTime;
   }

   // Telemetry Print (Non-blocking)
   if (config.telemetry && (millis() - lastTelemetryTime > config.telemetryIntervalMs)) {
      TelemetryData data = buildTelemetryData();
      debugger.sendTelemetryData(data);;
     lastTelemetryTime = millis();
   }

   // LED Mode Indication
   if (config.operationMode == MODE_LINE_FOLLOWING) {
     if (currentMillis - lastLedTime >= 100) {
       ledState = !ledState;
       digitalWrite(MODE_LED_PIN, ledState);
       lastLedTime = currentMillis;
     }
   } else if (config.operationMode == MODE_REMOTE_CONTROL) {
     if (currentMillis - lastLedTime >= 500) {
       ledState = !ledState;
       digitalWrite(MODE_LED_PIN, ledState);
       lastLedTime = currentMillis;
     }
   } else {  // MODE_IDLE
     digitalWrite(MODE_LED_PIN, LOW);
   }

   // Serial Commands
   serialReader.fillBuffer();            // recoge bytes
   const char *cmd;
   if (serialReader.getLine(&cmd)) {     // tenemos línea completa
     bool success = false;
     if (strlen(cmd) == 0) return;          // línea vacía

     if (strcmp(cmd, "calibrate") == 0) {
       leftMotor.setSpeed(0);
       rightMotor.setSpeed(0);
       digitalWrite(MODE_LED_PIN, HIGH);  // LED on during calibration
       debugger.systemMessage("Calibrando...");
       qtr.calibrate();
       digitalWrite(MODE_LED_PIN, LOW);   // LED off after calibration
       success = true;
       debugger.systemMessage("Calibración completada.");

     } else if (strcmp(cmd, "save") == 0) {
       saveConfig();
       success = true;

     } else if (strcmp(cmd, "get debug") == 0) {
        TelemetryData data = buildTelemetryData();
        debugger.sendDebugData(data, config);
       success = true;

     } else if (strcmp(cmd, "get telemetry") == 0) {
        TelemetryData data = buildTelemetryData();
        debugger.sendTelemetryData(data);
       success = true;

     } else if (strcmp(cmd, "get config") == 0) {
        debugger.sendConfigData(config);
       success = true;

     } else if (strcmp(cmd, "reset") == 0) {
       // restaurar valores por defecto
       config.restoreDefaults();
       saveConfig();
       linePid.setGains(config.lineKp, config.lineKi, config.lineKd);
       leftPid.setGains(config.leftKp, config.leftKi, config.leftKd);
       rightPid.setGains(config.rightKp, config.rightKi, config.rightKd);
       success = true;

     } else if (strcmp(cmd, "help") == 0) {
       debugger.systemMessage(F("Comandos: calibrate, save, get debug, get telemetry, get config, reset, help"));
       debugger.systemMessage(F("set telemetry 0/1  |  set mode 0/1/2  |  set cascade 0/1"));
       debugger.systemMessage(F("set feature <idx 0-8> 0/1  |  set features 0,1,0,...  |  set line kp,ki,kd  |  set left kp,ki,kd  |  set right kp,ki,kd"));
       debugger.systemMessage(F("set base <pwm>,<rpm>  |  set max <pwm>,<rpm>"));
       debugger.systemMessage(F("set pwm <derecha>,<izquierda>  (solo en modo idle)"));
       debugger.systemMessage(F("set rpm <izquierda>,<derecha>  (solo en modo idle)"));

     // ---------- comandos con parámetros ------------------------------
     } else if (strncmp(cmd, "set telemetry ", 14) == 0) {
       char* end;
       int val = strtol(cmd + 14, &end, 10);
       if (end == cmd + 14 || *end != '\0') { debugger.systemMessage("Falta argumento"); return; }
       config.telemetry = (val == 1);
       saveConfig();
       success = true;

     } else if (strncmp(cmd, "set mode ", 9) == 0) {
       char* end;
       int m = strtol(cmd + 9, &end, 10);
       if (end == cmd + 9 || *end != '\0') { debugger.systemMessage("Falta argumento"); return; }
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
       success = true;

     } else if (strncmp(cmd, "set cascade ", 12) == 0) {
       char* end;
       int val = strtol(cmd + 12, &end, 10);
       if (end == cmd + 12 || *end != '\0') { debugger.systemMessage("Falta argumento"); return; }
       config.cascadeMode = (val == 1);
       success = true;

     } else if (strncmp(cmd, "set feature ", 12) == 0) {
       const char* p = cmd + 12;
       char* end1;
       int idx = strtol(p, &end1, 10);
       if (end1 == p || *end1 != ' ') { debugger.systemMessage("Formato: set feature <idx> <0/1>"); return; }
       char* end2;
       int val = strtol(end1 + 1, &end2, 10);
       if (end2 == end1 + 1 || *end2 != '\0' || idx < 0 || idx > 8) { debugger.systemMessage("Formato: set feature <idx> <0/1>"); return; }
       config.features.setFeature(idx, val == 1);
       features.setConfig(config.features);
       success = true;

     } else if (strncmp(cmd, "set features ", 13) == 0) {
       const char* params = cmd + 13;
       if (config.features.deserialize(params)) {
         features.setConfig(config.features);
         success = true;
       } else {
         debugger.systemMessage("Formato: set features 0,1,0,1,... (9 valores)");
         return;
       }

     } else if (strncmp(cmd, "set line ", 9) == 0) {
       const char* p = cmd + 9;
       float kp = atof(p);
       while (*p && *p != ',') p++;
       if (*p != ',') { debugger.systemMessage("Formato: set line kp,ki,kd"); return; }
       p++;
       float ki = atof(p);
       while (*p && *p != ',') p++;
       if (*p != ',') { debugger.systemMessage("Formato: set line kp,ki,kd"); return; }
       p++;
       float kd = atof(p);
       while (*p && *p != '\0') p++;
       if (*p != '\0') { debugger.systemMessage("Formato: set line kp,ki,kd"); return; }
       config.lineKp = kp; config.lineKi = ki; config.lineKd = kd;
       linePid.setGains(kp, ki, kd);
       success = true;

     } else if (strncmp(cmd, "set left ", 9) == 0) {
       const char* p = cmd + 9;
       float kp = atof(p);
       while (*p && *p != ',') p++;
       if (*p != ',') { debugger.systemMessage("Formato: set left kp,ki,kd"); return; }
       p++;
       float ki = atof(p);
       while (*p && *p != ',') p++;
       if (*p != ',') { debugger.systemMessage("Formato: set left kp,ki,kd"); return; }
       p++;
       float kd = atof(p);
       while (*p && *p != '\0') p++;
       if (*p != '\0') { debugger.systemMessage("Formato: set left kp,ki,kd"); return; }
       config.leftKp = kp; config.leftKi = ki; config.leftKd = kd;
       leftPid.setGains(kp, ki, kd);
       success = true;

     } else if (strncmp(cmd, "set right ", 10) == 0) {
       const char* p = cmd + 10;
       float kp = atof(p);
       while (*p && *p != ',') p++;
       if (*p != ',') { debugger.systemMessage("Formato: set right kp,ki,kd"); return; }
       p++;
       float ki = atof(p);
       while (*p && *p != ',') p++;
       if (*p != ',') { debugger.systemMessage("Formato: set right kp,ki,kd"); return; }
       p++;
       float kd = atof(p);
       while (*p && *p != '\0') p++;
       if (*p != '\0') { debugger.systemMessage("Formato: set right kp,ki,kd"); return; }
       config.rightKp = kp; config.rightKi = ki; config.rightKd = kd;
       rightPid.setGains(kp, ki, kd);
       success = true;

     } else if (strncmp(cmd, "set base ", 9) == 0) {
       const char* params = cmd + 9;
       char* comma = strchr(params, ',');
       if (!comma) { debugger.systemMessage("Formato: set base <pwm>,<rpm>"); return; }
       int pwm = atoi(params);
       float rpm = atof(comma + 1);
       config.basePwm = constrain(pwm, -LIMIT_MAX_PWM, LIMIT_MAX_PWM);
       config.baseRPM = constrain(rpm, -LIMIT_MAX_RPM, LIMIT_MAX_RPM);
       success = true;

     } else if (strncmp(cmd, "set max ", 8) == 0) {
       const char* params = cmd + 8;
       char* comma = strchr(params, ',');
       if (!comma) { debugger.systemMessage("Formato: set max <pwm>,<rpm>"); return; }
       int pwm = atoi(params);
       float rpm = atof(comma + 1);
       config.maxPwm = constrain(pwm, 0, LIMIT_MAX_PWM);
       config.maxRpm = constrain(rpm, 0, LIMIT_MAX_RPM);
       success = true;

     } else if (strncmp(cmd, "rc ", 3) == 0) {
       const char* params = cmd + 3;
       char* comma = strchr(params, ',');
       if (!comma) { debugger.systemMessage("Formato: rc throttle,steering"); return; }
       float t = atof(params);
       float s = atof(comma + 1);
       throttle = t;
       steering = s;
       success = true;

     } else if (strncmp(cmd, "set pwm ", 8) == 0) {
       if (config.operationMode != MODE_IDLE) {
         debugger.systemMessage("Comando solo disponible en modo idle");
         return;
       }
       const char* params = cmd + 8;
       char* comma = strchr(params, ',');
       if (!comma) {
         debugger.systemMessage("Formato: set pwm <derecha>,<izquierda>");
         return;
       }
       char* end1;
       int rightVal = strtol(params, &end1, 10);
       if (end1 != comma) {
         debugger.systemMessage("Formato: set pwm <derecha>,<izquierda>");
         return;
       }
       char* end2;
       int leftVal = strtol(comma + 1, &end2, 10);
       if (*end2 != '\0') {
         debugger.systemMessage("Formato: set pwm <derecha>,<izquierda>");
         return;
       }
       idleRightPWM = rightVal;
       idleLeftPWM = leftVal;
       success = true;

     } else if (strncmp(cmd, "set rpm ", 8) == 0) {
       if (config.operationMode != MODE_IDLE) {
         debugger.systemMessage("Comando solo disponible en modo idle");
         return;
       }
       const char* params = cmd + 8;
       char* comma = strchr(params, ',');
       if (!comma) {
         debugger.systemMessage("Formato: set rpm <izquierda>,<derecha>");
         return;
       }
       float leftRPM = atof(params);
       float rightRPM = atof(comma + 1);
       idleLeftTargetRPM = leftRPM;
       idleRightTargetRPM = rightRPM;
       leftPid.reset();
       rightPid.reset();
       success = true;
     }

     if (success) {
       char ackMsg[50];
       sprintf(ackMsg, " %s", cmd);
       debugger.ackMessage(ackMsg);
     } else {
       debugger.systemMessage("Comando desconocido. Envía 'help'");
     }
   }
}

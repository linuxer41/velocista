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
OperationMode currentMode;
bool telemetry= false;
float lastPidOutput = 0;
unsigned long lastTelemetryTime = 0;
unsigned long lastLineTime = 0;
unsigned long lastSpeedTime = 0;
int lastLinePosition = 0;
unsigned long loopTime = 0;
unsigned long loopStartTime = 0;
float leftTargetRPM = 0;
float rightTargetRPM = 0;
int throttle = 0;
int steering = 0;
// LED indication
unsigned long lastLedTime = 0;
bool ledState = false;
// Variables para mejoras dinámicas
float previousLinePosition = 0;
float dynamicBaseRPM = DEFAULT_BASE_RPM;
int dynamicBaseSpeed = DEFAULT_BASE_SPEED;


// ==========================
// FUNCIONES AUXILIARES
// ==========================
void printDebugInfo();
void printTelemetryInfo();

int freeMemory() {
  extern int __heap_start, *__brkval;
  int v;
  return (int) &v - (__brkval == 0 ? (int) &__heap_start : (int) __brkval);
}


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
  currentMode = config.operationMode;
  // Configurar ganancias PID después de cargar
  linePid.setGains(config.lineKp, config.lineKi, config.lineKd);
  leftPid.setGains(config.leftKp, config.leftKi, config.leftKd);
  rightPid.setGains(config.rightKp, config.rightKi, config.rightKd);
  // Configurar features
  features.setEnables(config.features);
  telemetry = config.telemetry;

  qtr.setCalibration(config.sensorMin, config.sensorMax);

  
  qtr.calibrate();


  char msg[50];
  sprintf(msg, "Robot iniciado. Modo: %d", currentMode);
  debugger.systemMessage(msg);
  lastLineTime = millis();
  lastSpeedTime = millis();
}

// ==========================
// LOOP PRINCIPAL
// ==========================
void loop() {
  unsigned long currentMillis = millis();

  if (currentMillis - lastLineTime >= LOOP_LINE_MS) {
    lastLineTime = currentMillis;
    float dtLine = LOOP_LINE_MS / 1000.0;

    if (currentMode == MODE_LINE_FOLLOWING) {
       qtr.read();
       int* rawSensors = qtr.getRawSensorValues();
       // Verificar si todos los sensores están casi en negro (70% negro)
       bool allBlack = true;
       for(int i = 0; i < NUM_SENSORS; i++) {
         int range = config.sensorMax[i] - config.sensorMin[i];
         if(range > 0) {
           if(rawSensors[i] > config.sensorMin[i] + 0.3 * range) {
             allBlack = false;
             break;
           }
         } else {
           allBlack = false;
           break;
         }
       }
       // Verificar si todos los sensores están casi en blanco (30% blanco)
       bool allWhite = true;
       for(int i = 0; i < NUM_SENSORS; i++) {
         int range = config.sensorMax[i] - config.sensorMin[i];
         if(range > 0) {
           if(rawSensors[i] < config.sensorMax[i] - 0.3 * range) {
             allWhite = false;
             break;
           }
         } else {
           allWhite = false;
           break;
         }
       }

       // Calcular curvatura para ajustes dinámicos
       float currentPosition = features.applySignalFilters(qtr.linePosition);
       float curvature = abs(currentPosition - previousLinePosition) / dtLine;
       previousLinePosition = currentPosition;

       // Ajustes dinámicos de velocidad base
       dynamicBaseRPM = config.baseRPM;
       dynamicBaseSpeed = config.baseSpeed;
       if(config.features.variableSpeed && (curvature > 500 || allBlack)) {  // Alta curvatura o pérdida de línea
         dynamicBaseRPM = max(60.0f, dynamicBaseRPM - 30.0f);
         dynamicBaseSpeed = max(100, dynamicBaseSpeed - 50);
       }

       float pidOutput;
       if(allBlack) {
         pidOutput = config.features.turnDirection ? 200 : -200;  // girar según feature: derecha o izquierda
       } else if(allWhite) {
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
         leftTargetRPM = dynamicBaseRPM + rpmAdjustment;
         rightTargetRPM = dynamicBaseRPM - rpmAdjustment;
       } else {
        // Open-loop control
        int leftSpeed = dynamicBaseSpeed + pidOutput;
        int rightSpeed = dynamicBaseSpeed - pidOutput;
        leftSpeed = constrain(leftSpeed, -MAX_SPEED, MAX_SPEED);
        rightSpeed = constrain(rightSpeed, -MAX_SPEED, MAX_SPEED);
        leftMotor.setSpeed(leftSpeed);
        rightMotor.setSpeed(rightSpeed);
      }
    }
  }

  if (currentMillis - lastSpeedTime >= LOOP_SPEED_MS) {
    lastSpeedTime = currentMillis;
    loopStartTime = micros();
    float dtSpeed = LOOP_SPEED_MS / 1000.0;

    if (currentMode == MODE_REMOTE_CONTROL) {
      // Always cascade for remote control
      leftTargetRPM = throttle - steering;
      rightTargetRPM = throttle + steering;
    } else if (currentMode == MODE_LINE_FOLLOWING && config.cascadeMode) {
      // targetRPMs already set in line loop
    }

    if (currentMode == MODE_REMOTE_CONTROL || (currentMode == MODE_LINE_FOLLOWING && config.cascadeMode)) {
       // Calculate PID for each motor
       int leftSpeed = leftPid.calculate(leftTargetRPM, leftMotor.getRPM(), dtSpeed);
       int rightSpeed = rightPid.calculate(rightTargetRPM, rightMotor.getRPM(), dtSpeed);

       leftSpeed = constrain(leftSpeed, -MAX_SPEED, MAX_SPEED);
       rightSpeed = constrain(rightSpeed, -MAX_SPEED, MAX_SPEED);

       // Actualizar velocidad máxima registrada
       int currentMax = max(abs(leftSpeed), abs(rightSpeed));
       if(currentMax > config.maxSpeed) {
         config.maxSpeed = currentMax;
         saveConfig();
       }

       leftMotor.setSpeed(leftSpeed);
       rightMotor.setSpeed(rightSpeed);
     }

     if (currentMode == MODE_IDLE) {
       leftMotor.setSpeed(0);
       rightMotor.setSpeed(0);
     }

    loopTime = micros() - loopStartTime;
   }

   // Telemetry Print (Non-blocking)
   if (telemetry&& (millis() - lastTelemetryTime > REALTIME_INTERVAL_MS)) {
     printTelemetryInfo();
     lastTelemetryTime = millis();
   }

   // LED Mode Indication
   if (currentMode == MODE_LINE_FOLLOWING) {
     if (currentMillis - lastLedTime >= 100) {
       ledState = !ledState;
       digitalWrite(MODE_LED_PIN, ledState);
       lastLedTime = currentMillis;
     }
   } else if (currentMode == MODE_REMOTE_CONTROL) {
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
       printDebugInfo();
       success = true;

     } else if (strcmp(cmd, "get telemetry") == 0) {
       printTelemetryInfo();
       success = true;

     } else if (strcmp(cmd, "get config") == 0) {
       debugger.configData();
       success = true;

     } else if (strcmp(cmd, "reset") == 0) {
       // restaurar valores por defecto
       config.lineKp = DEFAULT_LINE_KP;
       config.lineKi = DEFAULT_LINE_KI;
       config.lineKd = DEFAULT_LINE_KD;
       config.leftKp  = DEFAULT_LEFT_KP;
       config.leftKi  = DEFAULT_LEFT_KI;
       config.leftKd  = DEFAULT_LEFT_KD;
       config.rightKp = DEFAULT_RIGHT_KP;
       config.rightKi = DEFAULT_RIGHT_KI;
       config.rightKd = DEFAULT_RIGHT_KD;
       config.baseSpeed      = DEFAULT_BASE_SPEED;
       config.baseRPM        = DEFAULT_BASE_RPM;
       config.cascadeMode    = DEFAULT_CASCADE;
       config.telemetry = DEFAULT_TELEMETRY_ENABLED;
       config.features.medianFilter = DEFAULT_FEATURE_ENABLES[0];
       config.features.movingAverage = DEFAULT_FEATURE_ENABLES[1];
       config.features.kalmanFilter = DEFAULT_FEATURE_ENABLES[2];
       config.features.hysteresis = DEFAULT_FEATURE_ENABLES[3];
       config.features.deadZone = DEFAULT_FEATURE_ENABLES[4];
       config.features.lowPass = DEFAULT_FEATURE_ENABLES[5];
       config.features.adaptivePid = DEFAULT_FEATURE_ENABLES[6];
       config.features.speedProfiling = DEFAULT_FEATURE_ENABLES[7];
       config.features.dynamicLinePid = DEFAULT_FEATURE_ENABLES[8];
       config.features.variableSpeed = DEFAULT_FEATURE_ENABLES[9];
       config.features.turnDirection = DEFAULT_FEATURE_ENABLES[10];
       config.operationMode  = DEFAULT_OPERATION_MODE;
       config.maxSpeed = DEFAULT_MAX_SPEED;
       config.checksum       = 1234567891;
       saveConfig();
       linePid.setGains(config.lineKp, config.lineKi, config.lineKd);
       leftPid.setGains(config.leftKp, config.leftKi, config.leftKd);
       rightPid.setGains(config.rightKp, config.rightKi, config.rightKd);
       success = true;

     } else if (strcmp(cmd, "help") == 0) {
       debugger.systemMessage("Comandos: calibrate, save, get debug, get telemetry, get config, reset, help");
       debugger.systemMessage("set telemetry 0/1  |  set mode 0/1/2  |  set cascade 0/1");
       debugger.systemMessage("set feature <idx 0-10> 0/1  |  set features 0,1,0,...  |  set line kp,ki,kd  |  set left kp,ki,kd  |  set right kp,ki,kd");
       debugger.systemMessage("set base speed <value>  |  set base rpm <value>");
       debugger.systemMessage("set pwm <derecha>,<izquierda>  (solo en modo idle)");

     // ---------- comandos con parámetros ------------------------------
     } else if (strncmp(cmd, "set telemetry ", 14) == 0) {
       char* end;
       int val = strtol(cmd + 14, &end, 10);
       if (end == cmd + 14 || *end != '\0') { debugger.systemMessage("Falta argumento"); return; }
       telemetry = (val == 1);
       config.telemetry = telemetry;
       saveConfig();
       success = true;

     } else if (strncmp(cmd, "set mode ", 9) == 0) {
       char* end;
       int m = strtol(cmd + 9, &end, 10);
       if (end == cmd + 9 || *end != '\0') { debugger.systemMessage("Falta argumento"); return; }
       if (m == 0) currentMode = MODE_IDLE;
       else if (m == 1) currentMode = MODE_LINE_FOLLOWING;
       else if (m == 2) currentMode = MODE_REMOTE_CONTROL;
       else { debugger.systemMessage("Modo inválido: 0=idle, 1=line, 2=remote"); return; }
       config.operationMode = currentMode;
       if (currentMode == MODE_REMOTE_CONTROL) {
         throttle = 0; steering = 0;
         leftMotor.setSpeed(0); rightMotor.setSpeed(0);
       } else if (currentMode == MODE_IDLE) {
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
       if (end2 == end1 + 1 || *end2 != '\0' || idx < 0 || idx > 10) { debugger.systemMessage("Formato: set feature <idx> <0/1>"); return; }
       config.features.setFeature(idx, val == 1);
       features.setEnables(config.features);
       success = true;

     } else if (strncmp(cmd, "set features ", 13) == 0) {
       const char* params = cmd + 13;
       if (config.features.deserialize(params)) {
         features.setEnables(config.features);
         success = true;
       } else {
         debugger.systemMessage("Formato: set features 0,1,0,1,... (11 valores)");
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

     } else if (strncmp(cmd, "set base speed ", 15) == 0) {
       char* end;
       int speed = strtol(cmd + 15, &end, 10);
       if (end == cmd + 15 || *end != '\0') { debugger.systemMessage("Falta argumento"); return; }
       config.baseSpeed = speed;
       success = true;

     } else if (strncmp(cmd, "set base rpm ", 13) == 0) {
       float rpm = atof(cmd + 13);
       config.baseRPM = rpm;
       success = true;

     } else if (strncmp(cmd, "rc ", 3) == 0) {
       const char* params = cmd + 3;
       char* comma = strchr(params, ',');
       if (!comma) { debugger.systemMessage("Formato: rc throttle,steering"); return; }
       char* end1;
       int t = strtol(params, &end1, 10);
       if (end1 != comma) { debugger.systemMessage("Formato: rc throttle,steering"); return; }
       char* end2;
       int s = strtol(comma + 1, &end2, 10);
       if (*end2 != '\0') { debugger.systemMessage("Formato: rc throttle,steering"); return; }
       throttle  = constrain(t, -MAX_SPEED, MAX_SPEED);
       steering  = constrain(s, -MAX_SPEED, MAX_SPEED);
       success = true;

     } else if (strncmp(cmd, "set pwm ", 8) == 0) {
       if (currentMode != MODE_IDLE) {
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
       rightMotor.setSpeed(rightVal);
       leftMotor.setSpeed(leftVal);
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

// ==========================
// DEBUG
// ==========================
void printDebugInfo() {
  DebugData data;
  int* sensors = qtr.getSensorValues();
  memcpy(data.sensors, sensors, sizeof(data.sensors));

  data.linePos = qtr.linePosition;
  data.cascade = config.cascadeMode;
  data.mode = currentMode;
  data.uptime = millis();

  // PID línea
  data.lineKp = config.lineKp;
  data.lineKi = config.lineKi;
  data.lineKd = config.lineKd;
  data.linePidOut = lastPidOutput;
  data.lineError = linePid.getError();
  data.lineIntegral = linePid.getIntegral();
  data.lineDeriv = linePid.getDerivative();

  // PID izquierdo
  data.leftKp = config.leftKp;
  data.leftKi = config.leftKi;
  data.leftKd = config.leftKd;
  data.lPidOut = leftPid.getOutput();
  data.lError = leftPid.getError();
  data.lIntegral = leftPid.getIntegral();
  data.lDeriv = leftPid.getDerivative();

  // PID derecho
  data.rightKp = config.rightKp;
  data.rightKi = config.rightKi;
  data.rightKd = config.rightKd;
  data.rPidOut = rightPid.getOutput();
  data.rError = rightPid.getError();
  data.rIntegral = rightPid.getIntegral();
  data.rDeriv = rightPid.getDerivative();

  // Velocidades
  data.lRpm = leftMotor.getRPM();
  data.rRpm = rightMotor.getRPM();
  data.lTargetRpm = leftTargetRPM;
  data.rTargetRpm = rightTargetRPM;
  data.lSpeed = leftMotor.getSpeed();
  data.rSpeed = rightMotor.getSpeed();

  // Sistema
  data.battery = analogRead(BATTERY_PIN) * BATTERY_FACTOR;
  data.loopTime = loopTime;
  data.freeMem = freeMemory();
  data.encL = leftMotor.getEncoderCount();
  data.encR = rightMotor.getEncoderCount();


  debugger.debugData(data);
}

// ==========================
// DEBUG Telemetry
// ==========================
void printTelemetryInfo() {
  DebugData data;
  qtr.read();  // Read sensors even in non-line-follower modes
  int* sensors = qtr.getSensorValues();
  memcpy(data.sensors, sensors, sizeof(data.sensors));

  data.linePos = qtr.linePosition;
  data.lineError = linePid.getError();
  data.linePidOut = lastPidOutput;
  data.lineIntegral = linePid.getIntegral();
  data.lineDeriv = linePid.getDerivative();
  data.lPidOut = leftPid.getOutput();
  data.rPidOut = rightPid.getOutput();
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
  data.baseSpeed = config.baseSpeed;
  data.baseRPM = config.baseRPM;
  data.wheelDiameter = config.wheelDiameter;
  data.wheelDistance = config.wheelDistance;
  data.leftSpeedCms = (data.lRpm * PI * (config.wheelDiameter / 10.0)) / 60.0;
  data.rightSpeedCms = (data.rRpm * PI * (config.wheelDiameter / 10.0)) / 60.0;
  data.battery = analogRead(BATTERY_PIN) * BATTERY_FACTOR;
  data.loopTime = loopTime;
  data.freeMem = freeMemory();
  data.cascade = config.cascadeMode;
  data.mode = currentMode;

  debugger.telemetryData(data);
}
#include <EEPROM.h>
#include "config.h"
#include "eeprom_manager.h"
#include "motor.h"
#include "sensors.h"
#include "pid.h"
#include "debugger.h"

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

// ==========================
// VARIABLES GLOBALES
// ==========================
OperationMode currentMode = MODE_LINE_FOLLOWING;
bool realtimeEnabled = true;
bool cascade = true;
float lastPidOutput = 0;
unsigned long lastRealtimeTime = 0;
unsigned long lastLineTime = 0;
unsigned long lastSpeedTime = 0;
int lastLinePosition = 0;
unsigned long loopTime = 0;
unsigned long loopStartTime = 0;
float leftTargetRPM = 0;
float rightTargetRPM = 0;
int throttle = 0;
int steering = 0;

// ==========================
// FUNCIONES AUXILIARES
// ==========================
void printDebugInfo();
void printRealtimeInfo();

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

  // Cargar configuración (EEPROMManager ya carga valores por defecto si inválidos)

  eeprom.load();
  // Configurar ganancias PID después de cargar
  linePid.setGains(config.lineKp, config.lineKi, config.lineKd);
  leftPid.setGains(config.leftKp, config.leftKi, config.leftKd);
  rightPid.setGains(config.rightKp, config.rightKi, config.rightKd);

  qtr.setCalibration(config.sensorMin, config.sensorMax);

  debugger.systemMessage("Calibrating... Move robot over line.");
  qtr.calibrate();

  debugger.systemMessage("Robot iniciado. Modo: LINEA");
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
      lastLinePosition = qtr.linePosition;

      float pidOutput = linePid.calculate(0, qtr.linePosition, dtLine);
      lastPidOutput = pidOutput;

      if (cascade) {
        // Set target RPMs for cascade control
        float rpmAdjustment = pidOutput * 0.5;
        leftTargetRPM = BASE_RPM - rpmAdjustment;
        rightTargetRPM = BASE_RPM + rpmAdjustment;
      } else {
        // Open-loop control
        int leftSpeed = config.baseSpeed - pidOutput;
        int rightSpeed = config.baseSpeed + pidOutput;
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
    } else if (currentMode == MODE_LINE_FOLLOWING && cascade) {
      // targetRPMs already set in line loop
    }

    if (currentMode == MODE_REMOTE_CONTROL || (currentMode == MODE_LINE_FOLLOWING && cascade)) {
      // Calculate PID for each motor
      int leftSpeed = leftPid.calculate(leftTargetRPM, leftMotor.getRPM(), dtSpeed);
      int rightSpeed = rightPid.calculate(rightTargetRPM, rightMotor.getRPM(), dtSpeed);

      leftSpeed = constrain(leftSpeed, -MAX_SPEED, MAX_SPEED);
      rightSpeed = constrain(rightSpeed, -MAX_SPEED, MAX_SPEED);

      leftMotor.setSpeed(leftSpeed);
      rightMotor.setSpeed(rightSpeed);
    }

    loopTime = micros() - loopStartTime;
  }

  // Realtime Print (Non-blocking)
  if (realtimeEnabled && (millis() - lastRealtimeTime > REALTIME_INTERVAL_MS)) {
    printRealtimeInfo();
    lastRealtimeTime = millis();
  }

  // Serial Commands
  if (Serial.available()) {
    char cmd[64];
    int len = Serial.readBytesUntil('\n', cmd, 63);
    if (len > 0) {
      cmd[len] = 0;
      // trim
      char* p = cmd;
      while (*p && (*p == ' ' || *p == '\t' || *p == '\r')) p++;
      char* start = p;
      p = start + strlen(start) - 1;
      while (p >= start && (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n')) *p-- = 0;
      if (strcmp(start, "calibrate") == 0) {
        leftMotor.setSpeed(0);
        rightMotor.setSpeed(0);
        qtr.calibrate();
        debugger.ackMessage(start);
      } else if (strncmp(start, "set realtime ", 13) == 0) {
        int val = atoi(start + 13);
        realtimeEnabled = (val == 1);
        debugger.ackMessage(start);
      } else if (strncmp(start, "mode ", 5) == 0) {
        int val = atoi(start + 5);
        if (val == 1) currentMode = MODE_LINE_FOLLOWING;
        else if (val == 2) {
          currentMode = MODE_REMOTE_CONTROL;
          throttle = 0;
          steering = 0;
          leftMotor.setSpeed(0);
          rightMotor.setSpeed(0);
        }
        debugger.ackMessage(start);
      } else if (strncmp(start, "cascade ", 8) == 0) {
        int val = atoi(start + 8);
        cascade = (val == 1);
        debugger.ackMessage(start);
      } else if (strncmp(start, "set line ", 9) == 0) {
        String vals = String(start + 9);
        int comma1 = vals.indexOf(',');
        int comma2 = vals.indexOf(',', comma1 + 1);
        if (comma1 > 0 && comma2 > comma1) {
          float kp = vals.substring(0, comma1).toFloat();
          float ki = vals.substring(comma1 + 1, comma2).toFloat();
          float kd = vals.substring(comma2 + 1).toFloat();
          config.lineKp = kp;
          config.lineKi = ki;
          config.lineKd = kd;
          linePid.setGains(kp, ki, kd);
          debugger.ackMessage(start);
        } else {
          debugger.systemMessage("Formato: set line kp,ki,kd");
        }
      } else if (strncmp(start, "set left ", 9) == 0) {
        String vals = String(start + 9);
        int comma1 = vals.indexOf(',');
        int comma2 = vals.indexOf(',', comma1 + 1);
        if (comma1 > 0 && comma2 > comma1) {
          float kp = vals.substring(0, comma1).toFloat();
          float ki = vals.substring(comma1 + 1, comma2).toFloat();
          float kd = vals.substring(comma2 + 1).toFloat();
          config.leftKp = kp;
          config.leftKi = ki;
          config.leftKd = kd;
          leftPid.setGains(kp, ki, kd);
          debugger.ackMessage(start);
        } else {
          debugger.systemMessage("Formato: set left kp,ki,kd");
        }
      } else if (strncmp(start, "set right ", 10) == 0) {
        String vals = String(start + 10);
        int comma1 = vals.indexOf(',');
        int comma2 = vals.indexOf(',', comma1 + 1);
        if (comma1 > 0 && comma2 > comma1) {
          float kp = vals.substring(0, comma1).toFloat();
          float ki = vals.substring(comma1 + 1, comma2).toFloat();
          float kd = vals.substring(comma2 + 1).toFloat();
          config.rightKp = kp;
          config.rightKi = ki;
          config.rightKd = kd;
          rightPid.setGains(kp, ki, kd);
          debugger.ackMessage(start);
        } else {
          debugger.systemMessage("Formato: set right kp,ki,kd");
        }
      } else if (strncmp(start, "rc ", 3) == 0) {
        String vals = String(start + 3);
        int comma = vals.indexOf(',');
        if (comma > 0) {
          int t = vals.substring(0, comma).toInt();
          int s = vals.substring(comma + 1).toInt();
          throttle = constrain(t, -MAX_SPEED, MAX_SPEED);
          steering = constrain(s, -MAX_SPEED, MAX_SPEED);
          debugger.ackMessage(start);
        } else {
          debugger.systemMessage("Formato: rc throttle,steering");
        }
      } else if (strcmp(start, "save") == 0) {
        saveConfig();
        debugger.ackMessage(start);
      } else if (strcmp(start, "telemetry") == 0) {
        printDebugInfo();
        debugger.ackMessage(start);
      } else if (strcmp(start, "realtime") == 0) {
        printRealtimeInfo();
        debugger.ackMessage(start);
      } else if (strcmp(start, "reset") == 0) {
        config.lineKp = DEFAULT_LINE_KP;
        config.lineKi = DEFAULT_LINE_KI;
        config.lineKd = DEFAULT_LINE_KD;
        config.leftKp = DEFAULT_LEFT_KP;
        config.leftKi = DEFAULT_LEFT_KI;
        config.leftKd = DEFAULT_LEFT_KD;
        config.rightKp = DEFAULT_RIGHT_KP;
        config.rightKi = DEFAULT_RIGHT_KI;
        config.rightKd = DEFAULT_RIGHT_KD;
        config.baseSpeed = DEFAULT_BASE_SPEED;
        config.wheelDiameter = WHEEL_DIAMETER_MM;
        config.wheelDistance = WHEEL_DISTANCE_MM;
        config.rcDeadzone = RC_DEADZONE;
        config.rcMaxThrottle = RC_MAX_THROTTLE;
        config.rcMaxSteering = RC_MAX_STEERING;
        for (int i = 0; i < NUM_SENSORS; i++) {
          config.sensorMin[i] = 0;
          config.sensorMax[i] = 1023;
        }
        config.checksum = 1234567891;
        saveConfig();
        linePid.setGains(config.lineKp, config.lineKi, config.lineKd);
        leftPid.setGains(config.leftKp, config.leftKi, config.leftKd);
        rightPid.setGains(config.rightKp, config.rightKi, config.rightKd);
        debugger.ackMessage(start);
      } else if (strcmp(start, "help") == 0) {
        debugger.systemMessage("Comandos disponibles:");
        debugger.systemMessage("calibrate - Calibrar sensores");
        debugger.systemMessage("set realtime 0/1 - Desactivar/activar realtime");
        debugger.systemMessage("telemetry - Enviar datos telemetry completos una vez");
        debugger.systemMessage("realtime - Enviar datos realtime una vez");
        debugger.systemMessage("mode 1/2 - Cambiar modo (1=line, 2=remote)");
        debugger.systemMessage("cascade 0/1 - Control en cascada (0=off, 1=on)");
        debugger.systemMessage("set line kp,ki,kd - Ajustar PID linea (ej: set line 2.0,0.05,0.75)");
        debugger.systemMessage("set left kp,ki,kd - Ajustar PID motor izquierdo");
        debugger.systemMessage("set right kp,ki,kd - Ajustar PID motor derecho");
        debugger.systemMessage("rc throttle,steering - Control remoto (ej: rc 200,50)");
        debugger.systemMessage("save - Guardar configuracion");
        debugger.systemMessage("reset - Restaurar valores por defecto y resetear EEPROM");
        debugger.systemMessage("help - Mostrar esta ayuda");
      } else {
        debugger.systemMessage("Comando desconocido. Envia 'help' para lista de comandos.");
      }
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
  data.cascade = cascade;
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
// DEBUG REALTIME
// ==========================
void printRealtimeInfo() {
  DebugData data;
  int* sensors = qtr.getSensorValues();
  memcpy(data.sensors, sensors, sizeof(data.sensors));

  data.linePos = qtr.linePosition;
  data.lineError = linePid.getError();
  data.uptime = millis();
  data.lRpm = leftMotor.getRPM();
  data.rRpm = rightMotor.getRPM();
  data.lSpeed = leftMotor.getSpeed();
  data.rSpeed = rightMotor.getSpeed();
  data.encL = leftMotor.getEncoderCount();
  data.encR = rightMotor.getEncoderCount();

  debugger.realtimeData(data);
}
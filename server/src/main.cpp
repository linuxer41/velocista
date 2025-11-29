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
OperationMode currentMode;
bool realtimeEnabled = true;
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
  currentMode = config.operationMode;
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

      if (config.cascadeMode) {
         // Set target RPMs for cascade control
         float rpmAdjustment = pidOutput * 0.5;
         leftTargetRPM = config.baseRPM - rpmAdjustment;
         rightTargetRPM = config.baseRPM + rpmAdjustment;
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
    } else if (currentMode == MODE_LINE_FOLLOWING && config.cascadeMode) {
      // targetRPMs already set in line loop
    }

    if (currentMode == MODE_REMOTE_CONTROL || (currentMode == MODE_LINE_FOLLOWING && config.cascadeMode)) {
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
    String command = Serial.readStringUntil('\n');
    command.trim();

    if (command.equalsIgnoreCase("calibrate")) {
      leftMotor.setSpeed(0);
      rightMotor.setSpeed(0);
      qtr.calibrate();
      debugger.ackMessage(command.c_str());
    } else if (command.startsWith("set realtime ")) {
      int val = command.substring(13).toInt();
      realtimeEnabled = (val == 1);
      debugger.ackMessage(command.c_str());
    } else if (command.startsWith("set mode ")) {
      int val = command.substring(9).toInt();
      if (val == 0) currentMode = MODE_LINE_FOLLOWING;
      else if (val == 1) {
        currentMode = MODE_REMOTE_CONTROL;
        throttle = 0;
        steering = 0;
        leftMotor.setSpeed(0);
        rightMotor.setSpeed(0);
      }
      config.operationMode = currentMode;
      debugger.ackMessage(command.c_str());
    } else if (command.startsWith("set cascade ")) {
      int val = command.substring(12).toInt();
      config.cascadeMode = (val == 1);
      debugger.ackMessage(command.c_str());
    } else if (command.startsWith("set line ")) {
      String params = command.substring(9);
      int comma1 = params.indexOf(',');
      int comma2 = params.indexOf(',', comma1 + 1);
      if (comma1 > 0 && comma2 > comma1) {
        float kp = params.substring(0, comma1).toFloat();
        float ki = params.substring(comma1 + 1, comma2).toFloat();
        float kd = params.substring(comma2 + 1).toFloat();
        config.lineKp = kp;
        config.lineKi = ki;
        config.lineKd = kd;
        linePid.setGains(kp, ki, kd);
        debugger.ackMessage(command.c_str());
      } else {
        debugger.systemMessage("Formato: set line kp,ki,kd");
      }
    } else if (command.startsWith("set left ")) {
      String params = command.substring(9);
      int comma1 = params.indexOf(',');
      int comma2 = params.indexOf(',', comma1 + 1);
      if (comma1 > 0 && comma2 > comma1) {
        float kp = params.substring(0, comma1).toFloat();
        float ki = params.substring(comma1 + 1, comma2).toFloat();
        float kd = params.substring(comma2 + 1).toFloat();
        config.leftKp = kp;
        config.leftKi = ki;
        config.leftKd = kd;
        leftPid.setGains(kp, ki, kd);
        debugger.ackMessage(command.c_str());
      } else {
        debugger.systemMessage("Formato: set left kp,ki,kd");
      }
    } else if (command.startsWith("set right ")) {
      String params = command.substring(10);
      int comma1 = params.indexOf(',');
      int comma2 = params.indexOf(',', comma1 + 1);
      if (comma1 > 0 && comma2 > comma1) {
        float kp = params.substring(0, comma1).toFloat();
        float ki = params.substring(comma1 + 1, comma2).toFloat();
        float kd = params.substring(comma2 + 1).toFloat();
        config.rightKp = kp;
        config.rightKi = ki;
        config.rightKd = kd;
        rightPid.setGains(kp, ki, kd);
        debugger.ackMessage(command.c_str());
      } else {
        debugger.systemMessage("Formato: set right kp,ki,kd");
      }
    } else if (command.startsWith("rc ")) {
      String params = command.substring(3);
      int comma = params.indexOf(',');
      if (comma > 0) {
        int t = params.substring(0, comma).toInt();
        int s = params.substring(comma + 1).toInt();
        throttle = constrain(t, -MAX_SPEED, MAX_SPEED);
        steering = constrain(s, -MAX_SPEED, MAX_SPEED);
        debugger.ackMessage(command.c_str());
      } else {
        debugger.systemMessage("Formato: rc throttle,steering");
      }
    } else if (command.equalsIgnoreCase("save")) {
      saveConfig();
      debugger.ackMessage(command.c_str());
    } else if (command.equalsIgnoreCase("telemetry")) {
      printDebugInfo();
      debugger.ackMessage(command.c_str());
    } else if (command.equalsIgnoreCase("realtime")) {
      printRealtimeInfo();
      debugger.ackMessage(command.c_str());
    } else if (command.equalsIgnoreCase("reset")) {
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
      config.cascadeMode = DEFAULT_CASCADE;
      config.operationMode = DEFAULT_OPERATION_MODE;
      config.baseRPM = DEFAULT_BASE_RPM;
      for (int i = 0; i < NUM_SENSORS; i++) {
        config.sensorMin[i] = 0;
        config.sensorMax[i] = 1023;
      }
      config.checksum = 1234567891;
      saveConfig();
      linePid.setGains(config.lineKp, config.lineKi, config.lineKd);
      leftPid.setGains(config.leftKp, config.leftKi, config.leftKd);
      rightPid.setGains(config.rightKp, config.rightKi, config.rightKd);
      debugger.ackMessage(command.c_str());
    } else if (command.equalsIgnoreCase("help")) {
      debugger.systemMessage("Comandos disponibles:");
      debugger.systemMessage("calibrate - Calibrar sensores");
      debugger.systemMessage("set realtime 0/1 - Desactivar/activar realtime");
      debugger.systemMessage("telemetry - Enviar datos telemetry completos una vez");
      debugger.systemMessage("realtime - Enviar datos realtime una vez");
      debugger.systemMessage("set mode 0/1 - Cambiar modo (0=line, 1=remote)");
      debugger.systemMessage("set cascade 0/1 - Control en cascada (0=off, 1=on)");
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
  data.lTargetRpm = leftTargetRPM;
  data.rTargetRpm = rightTargetRPM;
  data.lSpeed = leftMotor.getSpeed();
  data.rSpeed = rightMotor.getSpeed();
  data.encL = leftMotor.getEncoderCount();
  data.encR = rightMotor.getEncoderCount();
  data.cascade = config.cascadeMode;
  data.mode = currentMode;

  debugger.realtimeData(data);
}
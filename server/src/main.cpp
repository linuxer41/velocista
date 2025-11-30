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

String readSerialLine() {
  String s = Serial.readStringUntil('\n');
  s.trim();
  s.toLowerCase();
  return s;
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

  qtr.setCalibration(config.sensorMin, config.sensorMax);


  qtr.calibrate();

  debugger.systemMessage("Robot iniciado. Modo: IDLE");
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
  if (Serial.available()) {
    String command = readSerialLine();
    bool success = false;
    if (command.length() == 0) return;          // línea vacía

    if (command == "calibrate") {
      leftMotor.setSpeed(0);
      rightMotor.setSpeed(0);
      digitalWrite(MODE_LED_PIN, HIGH);  // LED on during calibration
      debugger.systemMessage("Calibrando...");
      qtr.calibrate();
      digitalWrite(MODE_LED_PIN, LOW);   // LED off after calibration
      success = true;
      debugger.systemMessage("Calibración completada.");

    } else if (command == "save") {
      saveConfig();
      success = true;

    } else if (command == "get debug") {
      printDebugInfo();
      success = true;

    } else if (command == "get telemetry") {
      printTelemetryInfo();
      success = true;

    } else if (command == "get config") {
      debugger.configData();
      success = true;

    } else if (command == "reset") {
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
      config.operationMode  = DEFAULT_OPERATION_MODE;
      config.checksum       = 1234567891;
      saveConfig();
      linePid.setGains(config.lineKp, config.lineKi, config.lineKd);
      leftPid.setGains(config.leftKp, config.leftKi, config.leftKd);
      rightPid.setGains(config.rightKp, config.rightKi, config.rightKd);
      success = true;

    } else if (command == "help") {
      debugger.systemMessage("Comandos: calibrate, save, get debug, get telemetry, get config, reset, help");
      debugger.systemMessage("set telemetry 0/1  |  set mode 0/1/2  |  set cascade 0/1");
      debugger.systemMessage("set line kp,ki,kd  |  set left kp,ki,kd  |  set right kp,ki,kd");
      debugger.systemMessage("set base speed <value>  |  set base rpm <value>");
      debugger.systemMessage("rc throttle,steering");

    // ---------- comandos con parámetros ------------------------------
    } else if (command.startsWith("set telemetry ")) {
      if (command.length() < 14) { debugger.systemMessage("Falta argumento"); return; }
      telemetry= (command.substring(13).toInt() == 1);
      success = true;

    } else if (command.startsWith("set mode ")) {
      if (command.length() < 10) { debugger.systemMessage("Falta argumento"); return; }
      int m = command.substring(9).toInt();
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

    } else if (command.startsWith("set cascade ")) {
      if (command.length() < 13) { debugger.systemMessage("Falta argumento"); return; }
      config.cascadeMode = (command.substring(12).toInt() == 1);
      success = true;

    } else if (command.startsWith("set line ")) {
      int coma1 = command.indexOf(',', 9);
      int coma2 = command.indexOf(',', coma1 + 1);
      if (coma1 == -1 || coma2 == -1) {
        debugger.systemMessage("Formato: set line kp,ki,kd"); return;
      }
      float kp = command.substring(9, coma1).toFloat();
      float ki = command.substring(coma1 + 1, coma2).toFloat();
      float kd = command.substring(coma2 + 1).toFloat();
      config.lineKp = kp; config.lineKi = ki; config.lineKd = kd;
      linePid.setGains(kp, ki, kd);
      success = true;

    } else if (command.startsWith("set left ")) {
      int coma1 = command.indexOf(',', 9);
      int coma2 = command.indexOf(',', coma1 + 1);
      if (coma1 == -1 || coma2 == -1) {
        debugger.systemMessage("Formato: set left kp,ki,kd"); return;
      }
      float kp = command.substring(9, coma1).toFloat();
      float ki = command.substring(coma1 + 1, coma2).toFloat();
      float kd = command.substring(coma2 + 1).toFloat();
      config.leftKp = kp; config.leftKi = ki; config.leftKd = kd;
      leftPid.setGains(kp, ki, kd);
      success = true;

    } else if (command.startsWith("set right ")) {
       int coma1 = command.indexOf(',', 10);
       int coma2 = command.indexOf(',', coma1 + 1);
       if (coma1 == -1 || coma2 == -1) {
         debugger.systemMessage("Formato: set right kp,ki,kd"); return;
       }
       float kp = command.substring(10, coma1).toFloat();
       float ki = command.substring(coma1 + 1, coma2).toFloat();
       float kd = command.substring(coma2 + 1).toFloat();
       config.rightKp = kp; config.rightKi = ki; config.rightKd = kd;
       rightPid.setGains(kp, ki, kd);
       success = true;

     } else if (command.startsWith("set base speed ")) {
       if (command.length() < 15) { debugger.systemMessage("Falta argumento"); return; }
       int speed = command.substring(14).toInt();
       config.baseSpeed = speed;
       success = true;

     } else if (command.startsWith("set base rpm ")) {
       if (command.length() < 13) { debugger.systemMessage("Falta argumento"); return; }
       float rpm = command.substring(12).toFloat();
       config.baseRPM = rpm;
       success = true;

     } else if (command.startsWith("rc ")) {
      int coma = command.indexOf(',', 3);
      if (coma == -1) {
        debugger.systemMessage("Formato: rc throttle,steering"); return;
      }
      int t = command.substring(3, coma).toInt();
      int s = command.substring(coma + 1).toInt();
      throttle  = constrain(t, -MAX_SPEED, MAX_SPEED);
      steering  = constrain(s, -MAX_SPEED, MAX_SPEED);
      success = true;

    }

    if (success) { debugger.ackMessage( (" " + command).c_str() ); } else {
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
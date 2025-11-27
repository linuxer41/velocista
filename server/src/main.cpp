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
bool debugEnabled = true;
bool cascade = true;
const float BASE_RPM = 120.0; // Ajusta basado en pruebas (RPM equivalente a baseSpeed)
float lastPidOutput = 0;
unsigned long lastDebugTime = 0;
unsigned long lastPidTime = 0;
int lastLinePosition = 0;
float leftTargetRPM = 0;
float rightTargetRPM = 0;
int throttle = 0;
int steering = 0;

// ==========================
// FUNCIONES AUXILIARES
// ==========================
void printDebugInfo();

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
  Serial.begin(9600);
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
  lastPidTime = micros();
}

// ==========================
// LOOP PRINCIPAL
// ==========================
void loop() {
  // Run PID loop at fixed 250Hz (4ms)
  if (micros() - lastPidTime >= 4000) {
    unsigned long currentTime = micros();
    float dt = (currentTime - lastPidTime) / 1000000.0;
    lastPidTime = currentTime;

    qtr.read();

    lastLinePosition = qtr.linePosition;

    float pidOutput = linePid.calculate(0, qtr.linePosition, dt);
    lastPidOutput = pidOutput;

    // ==========================================
    // MOTOR CONTROL
    // ==========================================
    int leftSpeed = 0;
    int rightSpeed = 0;

    if (cascade) {
      // Closed-loop control using RPM and PID

      if (currentMode == MODE_LINE_FOLLOWING) {
        // Normal Following: Base +/- PID adjustment
        float rpmAdjustment = pidOutput * 0.5; // Scale PID output to RPM (adjust factor)
        leftTargetRPM = BASE_RPM - rpmAdjustment;
        rightTargetRPM = BASE_RPM + rpmAdjustment;
      } else {
        // Remote / Stop
        leftTargetRPM = 0;
        rightTargetRPM = 0;
      }

      // Calculate PID for each motor
      leftSpeed = leftPid.calculate(leftTargetRPM, leftMotor.getRPM(), dt);
      rightSpeed = rightPid.calculate(rightTargetRPM, rightMotor.getRPM(), dt);

    } else {
      // Open-loop control (original behavior)
      leftTargetRPM = 0;
      rightTargetRPM = 0;
      if (currentMode == MODE_LINE_FOLLOWING) {
        // Normal Following: Base +/- PID
        leftSpeed = config.baseSpeed - pidOutput;
        rightSpeed = config.baseSpeed + pidOutput;
      } else {
        // Remote control
        leftSpeed = throttle - steering;
        rightSpeed = throttle + steering;
      }
    }

    // Constrain to PWM limits
    leftSpeed = constrain(leftSpeed, -MAX_SPEED, MAX_SPEED);
    rightSpeed = constrain(rightSpeed, -MAX_SPEED, MAX_SPEED);

    leftMotor.setSpeed(leftSpeed);
    rightMotor.setSpeed(rightSpeed);
  }

  // Debug Print (Non-blocking)
  if (debugEnabled && (millis() - lastDebugTime > 100)) {
    printDebugInfo();
    lastDebugTime = millis();
  }

  // Serial Commands
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    if (cmd == "calibrate") {
      leftMotor.setSpeed(0);
      rightMotor.setSpeed(0);
      qtr.calibrate();
      debugger.ackMessage(cmd);
    } else if (cmd == "debug on") {
      debugEnabled = true;
      debugger.ackMessage(cmd);
    } else if (cmd == "debug off") {
      debugEnabled = false;
      debugger.ackMessage(cmd);
    } else if (cmd == "mode line") {
      currentMode = MODE_LINE_FOLLOWING;
      debugger.ackMessage(cmd);
    } else if (cmd == "mode remote") {
      currentMode = MODE_REMOTE_CONTROL;
      debugger.ackMessage(cmd);
    } else if (cmd == "cascade on") {
      cascade = true;
      debugger.ackMessage(cmd);
    } else if (cmd == "cascade off") {
      cascade = false;
      debugger.ackMessage(cmd);
    } else if (cmd.startsWith("set line ")) {
      String vals = cmd.substring(9);
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
        debugger.ackMessage(cmd);
      } else {
        debugger.systemMessage("Formato: set line kp,ki,kd");
      }
    } else if (cmd.startsWith("set left ")) {
      String vals = cmd.substring(9);
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
        debugger.ackMessage(cmd);
      } else {
        debugger.systemMessage("Formato: set left kp,ki,kd");
      }
    } else if (cmd.startsWith("set right ")) {
      String vals = cmd.substring(10);
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
        debugger.ackMessage(cmd);
      } else {
        debugger.systemMessage("Formato: set right kp,ki,kd");
      }
    } else if (cmd.startsWith("throttle ")) {
      int val = cmd.substring(9).toInt();
      throttle = constrain(val, -MAX_SPEED, MAX_SPEED);
      debugger.ackMessage(cmd);
    } else if (cmd.startsWith("steering ")) {
      int val = cmd.substring(9).toInt();
      steering = constrain(val, -MAX_SPEED, MAX_SPEED);
      debugger.ackMessage(cmd);
    } else if (cmd == "save") {
      saveConfig();
      debugger.ackMessage(cmd);
    } else if (cmd == "telemetry") {
      printDebugInfo();
      debugger.ackMessage(cmd);
    } else if (cmd == "reset") {
      // Restaurar valores por defecto
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
      // Aplicar ganancias
      linePid.setGains(config.lineKp, config.lineKi, config.lineKd);
      leftPid.setGains(config.leftKp, config.leftKi, config.leftKd);
      rightPid.setGains(config.rightKp, config.rightKi, config.rightKd);
      debugger.ackMessage(cmd);
    } else if (cmd == "help") {
      debugger.systemMessage("Comandos disponibles:");
      debugger.systemMessage("calibrate - Calibrar sensores");
      debugger.systemMessage("debug on/off - Activar/desactivar debug");
      debugger.systemMessage("telemetry - Enviar datos debug una vez");
      debugger.systemMessage("mode line/remote - Cambiar modo");
      debugger.systemMessage("cascade on/off - Control en cascada");
      debugger.systemMessage("set line kp,ki,kd - Ajustar PID linea (ej: set line 2.0,0.05,0.75)");
      debugger.systemMessage("set left kp,ki,kd - Ajustar PID motor izquierdo");
      debugger.systemMessage("set right kp,ki,kd - Ajustar PID motor derecho");
      debugger.systemMessage("throttle <valor> - Establecer acelerador (-230 a 230)");
      debugger.systemMessage("steering <valor> - Establecer direccion (-230 a 230)");
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
  int* sensors = qtr.getSensorValues();
  String mode = String(currentMode);
  String debugLine = debugger.buildDebugLine(
    qtr.linePosition, cascade, mode, sensors, millis(),
    config.lineKp, config.lineKi, config.lineKd, lastPidOutput, linePid.getError(), linePid.getIntegral(),
    config.leftKp, config.leftKi, config.leftKd, leftPid.getOutput(), leftPid.getError(), leftPid.getIntegral(),
    config.rightKp, config.rightKi, config.rightKd, rightPid.getOutput(), rightPid.getError(), rightPid.getIntegral(),
    leftMotor.getRPM(), rightMotor.getRPM(), leftTargetRPM, rightTargetRPM, leftMotor.getSpeed(), rightMotor.getSpeed()
  );
  debugger.debugData(debugLine);
}
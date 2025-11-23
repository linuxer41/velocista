#include <EEPROM.h>
#include "config.h"
#include "eeprom_manager.h"
#include "motor.h"
#include "sensors.h"
#include "pid.h"

// ==========================
// INSTANCIAS DE CLASES
// ==========================
Motor leftMotor(MOTOR_LEFT_PIN1, MOTOR_LEFT_PIN2, LEFT, ENCODER_LEFT_A, ENCODER_LEFT_B);
Motor rightMotor(MOTOR_RIGHT_PIN1, MOTOR_RIGHT_PIN2, RIGHT, ENCODER_RIGHT_A, ENCODER_RIGHT_B);
EEPROMManager eeprom;
QTR qtr;
PID leftPid(config.kp, config.ki, config.kd);
PID rightPid(config.kp, config.ki, config.kd);

// ==========================
// VARIABLES GLOBALES
// ==========================
OperationMode currentMode = MODE_LINE_FOLLOWING;
bool debugEnabled = false;
bool closedLoop = false;
const float BASE_RPM = 120.0; // Ajusta basado en pruebas (RPM equivalente a baseSpeed)
float lastPidOutput = 0;
unsigned long lastDebugTime = 0;
unsigned long lastPidTime = 0;
int lastLinePosition = 0;

// ==========================
// FUNCIONES AUXILIARES
// ==========================
void printDebugInfo();

// PID calculation function
float calculatePID(float setpoint, float input) {
  // Fixed dt = 0.004 seconds (4ms)
  float dt = 0.004; 

  static float integral = 0;
  static float prevError = 0;
  
  float error = setpoint - input;
  
  integral += error * dt;
  // Anti-windup
  integral = constrain(integral, -100, 100); 
  
  float derivative = (error - prevError) / dt;
  
  float output = config.kp * error + config.ki * integral + config.kd * derivative;
  
  prevError = error;
  return output;
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

  // Cargar configuración por defecto
  config.kp = DEFAULT_KP;
  config.ki = DEFAULT_KI;
  config.kd = DEFAULT_KD;
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

  qtr.setCalibration(config.sensorMin, config.sensorMax);

  Serial.println("Calibrating... Move robot over line.");
  qtr.calibrate();

  Serial.println("Robot iniciado. Modo: LINEA");
  lastPidTime = micros();
}

// ==========================
// LOOP PRINCIPAL
// ==========================
void loop() {
  // Run PID loop at fixed 250Hz (4ms)
  if (micros() - lastPidTime >= 4000) {
    lastPidTime = micros();
    
    qtr.read();
    
    if (qtr.lineFound) {
      lastLinePosition = qtr.linePosition;
    }

    float pidOutput = calculatePID(0, qtr.linePosition); 
    lastPidOutput = pidOutput;

    // ==========================================
    // MOTOR CONTROL
    // ==========================================
    int leftSpeed = 0;
    int rightSpeed = 0;

    if (closedLoop) {
      // Closed-loop control using RPM and PID
      float leftTargetRPM = 0;
      float rightTargetRPM = 0;

      if (currentMode == MODE_LINE_FOLLOWING) {
        if (!qtr.lineFound) {
          // Line Lost: Spin to find it
          if (lastLinePosition > 0) {
            leftTargetRPM = BASE_RPM;
            rightTargetRPM = -BASE_RPM;
          } else {
            leftTargetRPM = -BASE_RPM;
            rightTargetRPM = BASE_RPM;
          }
        } else {
          // Normal Following: Base +/- PID adjustment
          float rpmAdjustment = pidOutput * 0.5; // Scale PID output to RPM (adjust factor)
          leftTargetRPM = BASE_RPM - rpmAdjustment;
          rightTargetRPM = BASE_RPM + rpmAdjustment;
        }
      } else {
        // Remote / Stop
        leftTargetRPM = 0;
        rightTargetRPM = 0;
      }

      // Calculate PID for each motor
      leftSpeed = leftPid.calculate(leftTargetRPM, leftMotor.getRPM());
      rightSpeed = rightPid.calculate(rightTargetRPM, rightMotor.getRPM());

    } else {
      // Open-loop control (original behavior)
      if (currentMode == MODE_LINE_FOLLOWING) {
        if (!qtr.lineFound) {
          // Line Lost: Spin to find it
          if (lastLinePosition > 0) {
            leftSpeed = 100;
            rightSpeed = -100;
          } else {
            leftSpeed = -100;
            rightSpeed = 100;
          }
        } else {
          // Normal Following: Base +/- PID
          leftSpeed = config.baseSpeed - pidOutput;
          rightSpeed = config.baseSpeed + pidOutput;
        }
      } else {
        // Remote / Stop
        leftSpeed = 0;
        rightSpeed = 0;
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
    } else if (cmd == "debug on") {
      debugEnabled = true;
      Serial.println("Debug activado");
    } else if (cmd == "debug off") {
      debugEnabled = false;
      Serial.println("Debug desactivado");
    } else if (cmd == "mode line") {
      currentMode = MODE_LINE_FOLLOWING;
      Serial.println("Modo: Seguir linea");
    } else if (cmd == "mode remote") {
      currentMode = MODE_REMOTE_CONTROL;
      Serial.println("Modo: Control remoto");
    }
  }
}

// ==========================
// DEBUG
// ==========================
void printDebugInfo() {
  Serial.print("Pos:"); Serial.print(qtr.linePosition);
  Serial.print("|PID:"); Serial.print(lastPidOutput);
  // RPM is only read here for debugging, as requested
  Serial.print("|LRPM:"); Serial.print(leftMotor.getRPM());
  Serial.print("|RRPM:"); Serial.print(rightMotor.getRPM());
  Serial.print("|LSPD:"); Serial.print(leftMotor.getSpeed());
  Serial.print("|RSPD:"); Serial.print(rightMotor.getSpeed());
  Serial.print("|Fnd:"); Serial.print(qtr.lineFound);
  Serial.println();
}
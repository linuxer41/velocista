#include <EEPROM.h>
#include "config.h"
#include "eeprom.h"
#include "motor.h"
#include "sensors.h"

// ==========================
// INSTANCIAS DE CLASES
// ==========================
Motor leftMotor(MOTOR_LEFT_PIN1, MOTOR_LEFT_PIN2, LEFT, ENCODER_LEFT_A, ENCODER_LEFT_B);
Motor rightMotor(MOTOR_RIGHT_PIN1, MOTOR_RIGHT_PIN2, RIGHT, ENCODER_RIGHT_A, ENCODER_RIGHT_B);
EEPROMManager eeprom;
QTR qtr;

// ==========================
// VARIABLES GLOBALES
// ==========================
OperationMode currentMode = MODE_LINE_FOLLOWING;
bool debugEnabled = true;
float lastPidOutput = 0;

// ==========================
// FUNCIONES AUXILIARES
// ==========================
void printDebugInfo();

// PID calculation function
float calculatePID(float setpoint, float input) {
  static float integral = 0;
  static float prevError = 0;
  float error = setpoint - input;
  integral += error * 0.01; // small dt approximation
  integral = constrain(integral, -50, 50);
  float derivative = (error - prevError) / 0.01;
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
  Serial.begin(9600);
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
  // Opcional: cargar de EEPROM si existe
  // config = eeprom.getConfig();

  qtr.setCalibration(config.sensorMin, config.sensorMax);

 qtr.calibrate();

  Serial.println("Robot iniciado. Modo: LINEA");
}

// ==========================
// LOOP PRINCIPAL
// ==========================
void loop() {
  qtr.read();
  float pidOutput = calculatePID(0, qtr.linePosition); // setpoint 0
  lastPidOutput = pidOutput;

  // Control de velocidad (lazo cerrado)
  leftMotor.setTargetRPM((config.baseSpeed / 255.0) * 300.0);
  rightMotor.setTargetRPM((config.baseSpeed / 255.0) * 300.0);
  float leftRPM = leftMotor.getRPM();
  float rightRPM = rightMotor.getRPM();
  float rpmDiff = leftRPM - rightRPM;
  int targetLeftSpeed = config.baseSpeed - SPEED_CORRECTION_K * rpmDiff;
  int targetRightSpeed = config.baseSpeed + SPEED_CORRECTION_K * rpmDiff;
  targetLeftSpeed = constrain(targetLeftSpeed, 0, 255);
  targetRightSpeed = constrain(targetRightSpeed, 0, 255);

  // Control de motores
  if (!qtr.lineFound) {
    leftMotor.setSpeed(100);  // Girar a la derecha
    rightMotor.setSpeed(-100);
  } else {
    leftMotor.setSpeed(constrain(targetLeftSpeed - pidOutput, -MAX_SPEED, MAX_SPEED));
    rightMotor.setSpeed(constrain(targetRightSpeed + pidOutput, -MAX_SPEED, MAX_SPEED));
  }


  if (debugEnabled) {
    printDebugInfo();
  }

  // Procesar comandos seriales
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    if (cmd == "calibrate") {
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

  delay(SENSOR_READ_DELAY);
}


// ==========================
// DEBUG
// ==========================
void printDebugInfo() {
  Serial.print("LinePos: "); Serial.print(qtr.linePosition);
  Serial.print(" | PID: "); Serial.print(lastPidOutput);
  Serial.print(" | LRPM: "); Serial.print(leftMotor.getRPM());
  Serial.print(" | RRPM: "); Serial.print(rightMotor.getRPM());
  Serial.print(" | LSPD: "); Serial.print(leftMotor.getSpeed());
  Serial.print(" | RSPD: "); Serial.print(rightMotor.getSpeed());
  Serial.print(" | SENSORS: [");
  int* sensorValues = qtr.getSensorValues();
  for (int i = 0; i < NUM_SENSORS; i++) {
    Serial.print(sensorValues[i]);
    if (i < NUM_SENSORS - 1) Serial.print(",");
  }
  Serial.println("]");
}
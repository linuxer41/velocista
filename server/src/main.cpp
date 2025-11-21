#include "config.h"

// ==========================
// VARIABLES GLOBALES
// ==========================
RobotConfig config;
OperationMode currentMode = MODE_LINE_FOLLOWING;
bool debugEnabled = true;

// Sensores
int sensorValues[NUM_SENSORS];
int linePosition = 0;
bool lineFound = false;

// Motores
int leftSpeed = 0;
int rightSpeed = 0;
int targetLeftSpeed = 0;
int targetRightSpeed = 0;

// Encoders
volatile long encoderLeftCount = 0;
volatile long encoderRightCount = 0;
long lastLeftCount = 0;
long lastRightCount = 0;
unsigned long lastSpeedCheck = 0;

// PID
float pidError = 0, pidLastError = 0, pidIntegral = 0, pidDerivative = 0;
float pidOutput = 0;

// Control de velocidad
float leftRPM = 0, rightRPM = 0;
float targetRPM = 0;

// ==========================
// FUNCIONES AUXILIARES
// ==========================
void readSensors();
void calculatePID();
void updateMotors();
void updateSpeedControl();
void readEncoders();
void loadConfig();
void saveConfig();
void printDebugInfo();
void calibrateSensors();
void countLeftEncoder();
void countRightEncoder();
// ==========================
// INTERRUPCIONES ENCODERS
// ==========================
void countLeftEncoder() {
  encoderLeftCount++;
}
void countRightEncoder() {
  encoderRightCount++;
}

// ==========================
// SETUP
// ==========================
void setup() {
  Serial.begin(9600);
  while (!Serial);

  pinMode(MOTOR_LEFT_PIN1, OUTPUT);
  pinMode(MOTOR_LEFT_PIN2, OUTPUT);
  pinMode(MOTOR_RIGHT_PIN1, OUTPUT);
  pinMode(MOTOR_RIGHT_PIN2, OUTPUT);
  pinMode(SENSOR_POWER_PIN, OUTPUT);
  digitalWrite(SENSOR_POWER_PIN, HIGH);

  pinMode(ENCODER_LEFT_A, INPUT_PULLUP);
  pinMode(ENCODER_RIGHT_A, INPUT_PULLUP);

  for (int i = 0; i < NUM_SENSORS; i++) {
    pinMode(SENSOR_PINS[i], INPUT);
  }

  attachInterrupt(digitalPinToInterrupt(ENCODER_LEFT_A), countLeftEncoder, CHANGE);
  attachInterrupt(digitalPinToInterrupt(ENCODER_RIGHT_A), countRightEncoder, CHANGE);

  loadConfig();

  Serial.println("Robot iniciado. Modo: LINEA");
}

// ==========================
// LOOP PRINCIPAL
// ==========================
void loop() {
  readSensors();
  calculatePID();

  // Control de velocidad (lazo cerrado)
  updateSpeedControl();

  updateMotors();

  if (debugEnabled) {
    printDebugInfo();
  }

  // Procesar comandos seriales
  if (Serial.available()) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();
    if (cmd == "calibrate") {
      calibrateSensors();
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
// LECTURA DE SENSORES
// ==========================
void readSensors() {
  int sum = 0;
  int weightedSum = 0;
  int activeSensors = 0;

  for (int i = 0; i < NUM_SENSORS; i++) {
    int val = analogRead(SENSOR_PINS[i]);
    val = map(val, config.sensorMin[i], config.sensorMax[i], 0, 1000);
    val = constrain(val, 0, 1000);
    sensorValues[i] = val;

    if (val > 500) {
      weightedSum += i * 1000;
      sum += val;
      activeSensors++;
    }
  }

  if (activeSensors > 0) {
    linePosition = weightedSum / sum - (NUM_SENSORS - 1) * 500;
    lineFound = true;
  } else {
    lineFound = false;
  }
}

// ==========================
// CÁLCULO PID
// ==========================
void calculatePID() {
  if (!lineFound) {
    pidError = 0;
    pidIntegral = 0;
    pidOutput = 0;
    return;
  }

  pidError = linePosition;
  pidIntegral += pidError;
  pidIntegral = constrain(pidIntegral, -1000, 1000); // Limitar integral
  pidDerivative = pidError - pidLastError;

  pidOutput = config.kp * pidError + config.ki * pidIntegral + config.kd * pidDerivative;
  pidLastError = pidError;
}

// ==========================
// CONTROL DE VELOCIDAD (LAZO CERRADO)
// ==========================
void updateSpeedControl() {
  unsigned long now = millis();
  if (now - lastSpeedCheck < 100) return;

  float dt = (now - lastSpeedCheck) / 1000.0;

  long leftDelta = encoderLeftCount - lastLeftCount;
  long rightDelta = encoderRightCount - lastRightCount;

  leftRPM = (leftDelta / (float)PULSES_PER_REVOLUTION) * 60.0 / dt;
  rightRPM = (rightDelta / (float)PULSES_PER_REVOLUTION) * 60.0 / dt;

  lastLeftCount = encoderLeftCount;
  lastRightCount = encoderRightCount;
  lastSpeedCheck = now;

  targetRPM = (config.baseSpeed / 255.0) * 300.0; // estimación RPM max

  float leftError = targetRPM - leftRPM;
  float rightError = targetRPM - rightRPM;

  targetLeftSpeed = constrain(config.baseSpeed + leftError * 2, -MAX_SPEED, MAX_SPEED);
  targetRightSpeed = constrain(config.baseSpeed + rightError * 2, -MAX_SPEED, MAX_SPEED);
}

// ==========================
// ACTUALIZAR MOTORES
// ==========================
void updateMotors() {
  if (!lineFound) {
    leftSpeed = 0;
    rightSpeed = 0;
  } else {
    leftSpeed = constrain(targetLeftSpeed - pidOutput, -MAX_SPEED, MAX_SPEED);
    rightSpeed = constrain(targetRightSpeed + pidOutput, -MAX_SPEED, MAX_SPEED);
  }

  // Izquierda
  if (leftSpeed >= 0) {
    analogWrite(MOTOR_LEFT_PIN1, leftSpeed);
    analogWrite(MOTOR_LEFT_PIN2, 0);
  } else {
    analogWrite(MOTOR_LEFT_PIN1, 0);
    analogWrite(MOTOR_LEFT_PIN2, -leftSpeed);
  }

  // Derecha
  if (rightSpeed >= 0) {
    analogWrite(MOTOR_RIGHT_PIN1, rightSpeed);
    analogWrite(MOTOR_RIGHT_PIN2, 0);
  } else {
    analogWrite(MOTOR_RIGHT_PIN1, 0);
    analogWrite(MOTOR_RIGHT_PIN2, -rightSpeed);
  }
}

// ==========================
// CONFIGURACIÓN EEPROM
// ==========================
void loadConfig() {
  EEPROM.get(EEPROM_CONFIG_ADDR, config);
  if (config.checksum != 1234567890) {
    Serial.println("Config inválida, cargando valores por defecto");
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
    config.checksum = 1234567890;
    saveConfig();
  }
}

void saveConfig() {
  EEPROM.put(EEPROM_CONFIG_ADDR, config);
}

// ==========================
// CALIBRACIÓN SENSORES
// ==========================
void calibrateSensors() {
  Serial.println("Calibrando sensores...");
  for (int i = 0; i < NUM_SENSORS; i++) {
    config.sensorMin[i] = 1023;
    config.sensorMax[i] = 0;
  }
  unsigned long start = millis();
  while (millis() - start < 5000) {  // 5 segundos
    for (int i = 0; i < NUM_SENSORS; i++) {
      int val = analogRead(SENSOR_PINS[i]);
      if (val < config.sensorMin[i]) config.sensorMin[i] = val;
      if (val > config.sensorMax[i]) config.sensorMax[i] = val;
    }
    delay(10);
  }
  saveConfig();
  Serial.println("Calibracion completada");
}

// ==========================
// DEBUG
// ==========================
void printDebugInfo() {
  Serial.print("LinePos: "); Serial.print(linePosition);
  Serial.print(" | PID: "); Serial.print(pidOutput);
  Serial.print(" | LRPM: "); Serial.print(leftRPM);
  Serial.print(" | RRPM: "); Serial.print(rightRPM);
  Serial.print(" | LSPD: "); Serial.print(leftSpeed);
  Serial.print(" | RSPD: "); Serial.print(rightSpeed);
  Serial.print(" | SENSORS: [");
  for (int i = 0; i < NUM_SENSORS; i++) {
    Serial.print(sensorValues[i]);
    if (i < NUM_SENSORS - 1) Serial.print(",");
  }
  Serial.println("]");
}
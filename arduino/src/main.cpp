#include <Arduino.h>

// =============================================================================
// CONSTANTES Y CONFIGURACIONES
// =============================================================================

// Pines para motores DRV8833
#define MOTOR_LEFT_PIN1   10
#define MOTOR_LEFT_PIN2   9
#define MOTOR_RIGHT_PIN1  6
#define MOTOR_RIGHT_PIN2  5

// Sensores de línea (A7-A0, right to left)
#define NUM_SENSORS       8
const int SENSOR_PINS[NUM_SENSORS] = {A0, A1, A2, A3, A4, A5, A6, A7};
#define SENSOR_POWER_PIN  12

// Pines para encoders
#define ENCODER_LEFT_A    2
#define ENCODER_LEFT_B    7
#define ENCODER_RIGHT_A   3
#define ENCODER_RIGHT_B   8

// LED de indicación
#define MODE_LED_PIN      13

// Constantes
const float QTR_POSITION_SCALE = 4000.0f / 3.5f;
const float QTR_CENTER_OFFSET = 3.5f;
const int16_t LIMIT_MAX_PWM = 255;
const float LIMIT_MAX_RPM = 4000.0f;

// PID para línea
const float LINE_KP = 0.500;
const float LINE_KI = 0.000;
const float LINE_KD = 0.000;

// PID para motores
const float MOTOR_KP = 0.590;
const float MOTOR_KI = 0.001;
const float MOTOR_KD_LEFT = 0.0025;
const float MOTOR_KD_RIGHT = 0.050;

// Configuración física
const int16_t PULSES_PER_REVOLUTION = 36;
const float WHEEL_DIAMETER_MM = 30.0f;
const float WHEEL_DISTANCE_MM = 100.0f;
const uint16_t LOOP_LINE_MS = 10;
const uint16_t LOOP_SPEED_MS = 5;

// Velocidades base
const int16_t BASE_SPEED = 150;
const float BASE_RPM = 400.0f;

// Flag para control de lazo cerrado
bool closedLoopEnabled = false;

// Variables globales
volatile long encoderLeftCount = 0;
volatile long encoderRightCount = 0;
unsigned long lastEncoderTime = 0;
float currentRPMLeft = 0.0f;
float currentRPMRight = 0.0f;

// Variables de calibración de sensores
int sensorMinValues[NUM_SENSORS];
int sensorMaxValues[NUM_SENSORS];

// PID variables para línea
float lineError = 0.0f;
float lineLastError = 0.0f;
float lineIntegral = 0.0f;
float lineDerivative = 0.0f;
float lineOutput = 0.0f;

// PID variables para motores
float leftError = 0.0f;
float leftLastError = 0.0f;
float leftIntegral = 0.0f;
float leftDerivative = 0.0f;
float leftOutput = 0.0f;

float rightError = 0.0f;
float rightLastError = 0.0f;
float rightIntegral = 0.0f;
float rightDerivative = 0.0f;
float rightOutput = 0.0f;

// Timers
unsigned long lastLineTime = 0;
unsigned long lastSpeedTime = 0;

// =============================================================================
// FUNCIONES DE ENCODERS
// =============================================================================

void encoderLeftISR() {
  if (digitalRead(ENCODER_LEFT_B) == HIGH) {
    encoderLeftCount++;
  } else {
    encoderLeftCount--;
  }
}

void encoderRightISR() {
  if (digitalRead(ENCODER_RIGHT_B) == HIGH) {
    encoderRightCount++;
  } else {
    encoderRightCount--;
  }
}

// =============================================================================
// FUNCIONES DE SENSORES
// =============================================================================

float readLinePosition() {
  int sensorValues[NUM_SENSORS];
  int total = 0;
  int weightedSum = 0;

  // Leer sensores
  for (int i = 0; i < NUM_SENSORS; i++) {
    sensorValues[i] = analogRead(SENSOR_PINS[i]);
    total += sensorValues[i];
    weightedSum += sensorValues[i] * i;
  }

  if (total == 0) return 0.0f; // Todos los sensores en blanco

  float position = (float)weightedSum / total;
  position = (position - 3.5f) * QTR_POSITION_SCALE / 1000.0f; // Normalizar a -1 a 1

  return constrain(position, -1.0f, 1.0f);
}

// =============================================================================
// FUNCIONES DE MOTORES
// =============================================================================

void setMotorSpeed(int pin1, int pin2, int speed) {
  speed = constrain(speed, -LIMIT_MAX_PWM, LIMIT_MAX_PWM);

  if (speed > 0) {
    analogWrite(pin1, speed);
    analogWrite(pin2, 0);
  } else if (speed < 0) {
    analogWrite(pin1, 0);
    analogWrite(pin2, -speed);
  } else {
    analogWrite(pin1, 0);
    analogWrite(pin2, 0);
  }
}

void calculateRPM() {
  unsigned long currentTime = millis();
  unsigned long deltaTime = currentTime - lastEncoderTime;

  if (deltaTime >= 100) { // Calcular cada 100ms
    float deltaTimeSec = deltaTime / 1000.0f;

    currentRPMLeft = (encoderLeftCount * 60.0f) / (PULSES_PER_REVOLUTION * deltaTimeSec);
    currentRPMRight = (encoderRightCount * 60.0f) / (PULSES_PER_REVOLUTION * deltaTimeSec);

    encoderLeftCount = 0;
    encoderRightCount = 0;
    lastEncoderTime = currentTime;
  }
}

// =============================================================================
// FUNCIONES PID
// =============================================================================

float calculatePID(float error, float &lastError, float &integral, float &derivative,
                   float kp, float ki, float kd, float dt) {
  integral += error * dt;
  integral = constrain(integral, -100.0f, 100.0f); // Limitar integral

  derivative = (error - lastError) / dt;
  lastError = error;

  return kp * error + ki * integral + kd * derivative;
}

// =============================================================================
// CALIBRACIÓN DE SENSORES
// =============================================================================

void calibrateSensors() {
  // Inicializar valores de calibración
  for (int i = 0; i < NUM_SENSORS; i++) {
    sensorMinValues[i] = 1023;
    sensorMaxValues[i] = 0;
  }

  // Calibración durante 5 segundos
  unsigned long startTime = millis();

  while (millis() - startTime < 5000) { // 5 segundos
    // Parpadear LED
    digitalWrite(MODE_LED_PIN, HIGH);
    digitalWrite(SENSOR_POWER_PIN, HIGH); // Encender LEDs de sensores
    delay(100);

    // Leer sensores y actualizar min/max
    for (int i = 0; i < NUM_SENSORS; i++) {
      int value = analogRead(SENSOR_PINS[i]);
      if (value < sensorMinValues[i]) sensorMinValues[i] = value;
      if (value > sensorMaxValues[i]) sensorMaxValues[i] = value;
    }

    digitalWrite(MODE_LED_PIN, LOW);
    digitalWrite(SENSOR_POWER_PIN, LOW); // Apagar LEDs de sensores
    delay(100);
  }

  // Al finalizar calibración, dejar LEDs de sensores encendidos
  digitalWrite(SENSOR_POWER_PIN, HIGH);
  digitalWrite(MODE_LED_PIN, LOW);
}

// =============================================================================
// SETUP
// =============================================================================

void setup() {
  // Configurar pines de motores
  pinMode(MOTOR_LEFT_PIN1, OUTPUT);
  pinMode(MOTOR_LEFT_PIN2, OUTPUT);
  pinMode(MOTOR_RIGHT_PIN1, OUTPUT);
  pinMode(MOTOR_RIGHT_PIN2, OUTPUT);

  // Configurar pines de sensores
  pinMode(SENSOR_POWER_PIN, OUTPUT);

  for (int i = 0; i < NUM_SENSORS; i++) {
    pinMode(SENSOR_PINS[i], INPUT);
  }

  // Configurar pines de encoders
  pinMode(ENCODER_LEFT_A, INPUT_PULLUP);
  pinMode(ENCODER_LEFT_B, INPUT_PULLUP);
  pinMode(ENCODER_RIGHT_A, INPUT_PULLUP);
  pinMode(ENCODER_RIGHT_B, INPUT_PULLUP);

  // Configurar pin del LED
  pinMode(MODE_LED_PIN, OUTPUT);

  // Configurar interrupciones de encoders
  attachInterrupt(digitalPinToInterrupt(ENCODER_LEFT_A), encoderLeftISR, RISING);
  attachInterrupt(digitalPinToInterrupt(ENCODER_RIGHT_A), encoderRightISR, RISING);

  // Calibrar sensores al inicio (5 segundos con LED parpadeando)
  calibrateSensors();

  // Inicializar timers
  lastLineTime = millis();
  lastSpeedTime = millis();
  lastEncoderTime = millis();
}

// =============================================================================
// LOOP PRINCIPAL
// =============================================================================

void loop() {
  unsigned long currentTime = millis();

  // Control de línea (cada LOOP_LINE_MS ms)
  if (currentTime - lastLineTime >= LOOP_LINE_MS) {
    float dt = (currentTime - lastLineTime) / 1000.0f;
    lastLineTime = currentTime;

    // Leer posición de línea
    float position = readLinePosition();

    // Calcular error de línea
    lineError = position;

    // PID de línea
    lineOutput = calculatePID(lineError, lineLastError, lineIntegral, lineDerivative,
                              LINE_KP, LINE_KI, LINE_KD, dt);

    // Limitar corrección
    lineOutput = constrain(lineOutput, -100.0f, 100.0f);
  }

  // Control de velocidad (cada LOOP_SPEED_MS ms)
  if (currentTime - lastSpeedTime >= LOOP_SPEED_MS) {
    float dt = (currentTime - lastSpeedTime) / 1000.0f;
    lastSpeedTime = currentTime;

    int leftPWM, rightPWM;

    if (closedLoopEnabled) {
      // Calcular RPM actuales
      calculateRPM();

      // Velocidades objetivo con corrección de línea
      float targetRPMLeft = BASE_RPM - lineOutput;
      float targetRPMRight = BASE_RPM + lineOutput;

      // Limitar RPM objetivo
      targetRPMLeft = constrain(targetRPMLeft, -LIMIT_MAX_RPM, LIMIT_MAX_RPM);
      targetRPMRight = constrain(targetRPMRight, -LIMIT_MAX_RPM, LIMIT_MAX_RPM);

      // Calcular errores de velocidad
      leftError = targetRPMLeft - currentRPMLeft;
      rightError = targetRPMRight - currentRPMRight;

      // PID de motores
      leftOutput = calculatePID(leftError, leftLastError, leftIntegral, leftDerivative,
                                MOTOR_KP, MOTOR_KI, MOTOR_KD_LEFT, dt);
      rightOutput = calculatePID(rightError, rightLastError, rightIntegral, rightDerivative,
                                 MOTOR_KP, MOTOR_KI, MOTOR_KD_RIGHT, dt);

      // Convertir a PWM
      leftPWM = BASE_SPEED + (int)leftOutput;
      rightPWM = BASE_SPEED + (int)rightOutput;
    } else {
      // Modo abierto: velocidad base con corrección de línea
      leftPWM = BASE_SPEED - (int)lineOutput;
      rightPWM = BASE_SPEED + (int)lineOutput;
    }

    // Limitar PWM
    leftPWM = constrain(leftPWM, -LIMIT_MAX_PWM, LIMIT_MAX_PWM);
    rightPWM = constrain(rightPWM, -LIMIT_MAX_PWM, LIMIT_MAX_PWM);

    // Aplicar a motores
    setMotorSpeed(MOTOR_LEFT_PIN1, MOTOR_LEFT_PIN2, leftPWM);
    setMotorSpeed(MOTOR_RIGHT_PIN1, MOTOR_RIGHT_PIN2, rightPWM);
  }
}
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
float filteredLinePos = 0;

// ==========================
// FILTROS PARA POSICIÓN DE LÍNEA
// ==========================

// Filtro de Media Móvil
// Suaviza las lecturas de posición de línea promediando las últimas N muestras
// Reduce el ruido de alta frecuencia y variaciones rápidas en las mediciones
// Parámetros: Ventana de 5 muestras para balancear suavizado y respuesta
const int MA_WINDOW = 5;
float maBuffer[MA_WINDOW];
int maIndex = 0;
float maSum = 0;
bool maFull = false;

float applyMovingAverage(float newVal) {
  maSum -= maBuffer[maIndex];
  maBuffer[maIndex] = newVal;
  maSum += newVal;
  maIndex = (maIndex + 1) % MA_WINDOW;
  if (!maFull && maIndex == 0) maFull = true;
  return maFull ? maSum / MA_WINDOW : maSum / (maIndex == 0 ? MA_WINDOW : maIndex);
}

// Filtro de Kalman
// Estima el estado real (posición de línea) combinando predicciones y mediciones
// Reduce ruido considerando tanto el ruido del proceso como el de medición
// Parámetros: q=0.01 (ruido de proceso), r=0.1 (ruido de medición)
// Útil para sensores con ruido gaussiano y sistemas con dinámica predecible
struct KalmanFilter {
  float estimate;    // x - estado estimado (posición filtrada)
  float errorCov;    // p - covarianza del error de estimación
  float processNoise; // q - ruido del proceso (incertidumbre en el modelo)
  float measNoise;   // r - ruido de medición (incertidumbre del sensor)
};

KalmanFilter kalmanLine = {0, 1, 0.01, 0.1};

float kalmanUpdate(KalmanFilter &kf, float measurement) {
  // Paso de predicción: aumenta la incertidumbre basada en el ruido del proceso
  kf.errorCov += kf.processNoise;
  
  // Paso de actualización: corrige la estimación con la nueva medición
  float kalmanGain = kf.errorCov / (kf.errorCov + kf.measNoise);
  kf.estimate += kalmanGain * (measurement - kf.estimate);
  kf.errorCov *= (1 - kalmanGain);
  
  return kf.estimate;
}

// Filtro Mediano
// Elimina valores atípicos (outliers) seleccionando el valor central de una ventana ordenada
// Muy efectivo contra ruido impulsivo o lecturas erráticas de sensores
// Parámetros: Ventana de 5 muestras para balancear robustez y retardo
// Ventaja: No distorsiona valores normales, solo elimina extremos
const int MED_WINDOW = 5;
float medBuffer[MED_WINDOW];
int medIndex = 0;

float applyMedian(float newVal) {
  medBuffer[medIndex] = newVal;
  medIndex = (medIndex + 1) % MED_WINDOW;
  
  float sorted[MED_WINDOW];
  memcpy(sorted, medBuffer, sizeof(sorted));
  
  // Ordenamiento burbuja para encontrar la mediana
  for(int i = 0; i < MED_WINDOW - 1; i++) {
    for(int j = 0; j < MED_WINDOW - 1 - i; j++) {
      if(sorted[j] > sorted[j + 1]) {
        float temp = sorted[j];
        sorted[j] = sorted[j + 1];
        sorted[j + 1] = temp;
      }
    }
  }
  
  return sorted[MED_WINDOW / 2];
}

// Filtro de Histéresis
// Evita cambios rápidos y oscilatorios en la posición detectada
// Solo actualiza el valor cuando el cambio supera un umbral significativo
// Parámetros: Umbral de 10 unidades para filtrar ruido menor pero permitir correcciones grandes
// Útil para prevenir "caza" del controlador cerca de la línea ideal
float prevHystPosition = 0;
const float HYSTERESIS_THRESHOLD = 10.0;

float applyHysteresis(float newPos) {
  if (abs(newPos - prevHystPosition) > HYSTERESIS_THRESHOLD) {
    prevHystPosition = newPos;
  }
  return prevHystPosition;
}

// Zona Muerta para Error
// Ignora errores pequeños que no requieren corrección
// Evita que el PID reaccione a ruido menor, reduciendo oscilaciones innecesarias
// Parámetros: Umbral de 5 unidades, ajustable según la sensibilidad deseada
// Beneficio: Mayor estabilidad en condiciones de ruido bajo
const float DEAD_ZONE_THRESHOLD = 5.0;

float applyDeadZone(float error) {
  if (abs(error) < DEAD_ZONE_THRESHOLD) return 0;
  return error;
}

// Filtro Pasa Bajos para Error
// Suaviza cambios rápidos en el error, actuando como un filtro de frecuencia baja
// Reduce la ganancia de altas frecuencias, estabilizando el control
// Parámetros: Alpha=0.8 (alta suavización, respuesta lenta pero estable)
// Fórmula: y[n] = alpha * x[n] + (1-alpha) * y[n-1]
// Mayor alpha = más peso al valor actual, menor filtrado
float lpErrorPrev = 0;
const float LP_ALPHA = 0.8;

float applyLowPass(float newVal) {
  lpErrorPrev = LP_ALPHA * newVal + (1 - LP_ALPHA) * lpErrorPrev;
  return lpErrorPrev;
}

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

  // Inicializar buffers de filtros
  memset(maBuffer, 0, sizeof(maBuffer));
  memset(medBuffer, 0, sizeof(medBuffer));

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

      // Aplicar cadena de filtros a la posición de línea para mejorar estabilidad
      // Secuencia: Media Móvil -> Mediano -> Kalman -> Histéresis
      float rawPos = qtr.linePosition;
      float maPos = applyMovingAverage(rawPos);     // Suaviza ruido de alta frecuencia
      float medPos = applyMedian(maPos);            // Elimina valores atípicos
      float kalPos = kalmanUpdate(kalmanLine, medPos); // Estima posición real
      float hystPos = applyHysteresis(kalPos);      // Evita cambios bruscos
      filteredLinePos = hystPos;
      
      // Calcular error y aplicar filtros adicionales
      // Secuencia: Zona Muerta -> Pasa Bajos
      float error = 0 - hystPos;
      float dzError = applyDeadZone(error);         // Ignora errores pequeños
      float lpError = applyLowPass(dzError);        // Suaviza cambios rápidos
      
      float pidOutput = linePid.calculate(0, lpError, dtLine);
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

  data.linePos = filteredLinePos;
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

  // Datos de filtros para debugging
  data.kalmanEstimate = kalmanLine.estimate;
  data.kalmanCov = kalmanLine.errorCov;
  data.lpAlpha = LP_ALPHA;
  data.dzThreshold = DEAD_ZONE_THRESHOLD;
  data.hystThreshold = HYSTERESIS_THRESHOLD;
  data.maWindow = MA_WINDOW;
  data.medWindow = MED_WINDOW;

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

  data.linePos = filteredLinePos;
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

  // Datos de filtros para debugging
  data.kalmanEstimate = kalmanLine.estimate;
  data.kalmanCov = kalmanLine.errorCov;
  data.lpAlpha = LP_ALPHA;
  data.dzThreshold = DEAD_ZONE_THRESHOLD;
  data.hystThreshold = HYSTERESIS_THRESHOLD;
  data.maWindow = MA_WINDOW;
  data.medWindow = MED_WINDOW;

  debugger.telemetryData(data);
}
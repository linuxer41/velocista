#include <EEPROM.h>
#include "config.h"
#include "eeprom_manager.h"
#include "motor.h"
#include "sensors.h"
#include "pid.h"
#include "debugger.h"
#include "serial_reader.h"
#include "features.h"
#include "command_handler.h"

// ==========================
// ENUMS Y FUNCIONES AUXILIARES
// ==========================
enum SensorState { NORMAL, ALL_BLACK, ALL_WHITE };

SensorState checkSensorState(int16_t* rawSensors) {
    bool allBlack = true;
    bool allWhite = true;
    for(int i = 0; i < NUM_SENSORS; i++) {
        int range = config.sensorMax[i] - config.sensorMin[i];
        if(range > 0) {
            if(rawSensors[i] < config.sensorMax[i] - SENSOR_THRESHOLD * range) {
                allBlack = false;
            }
            if(rawSensors[i] > config.sensorMin[i] + SENSOR_THRESHOLD * range) {
                allWhite = false;
            }
        } else {
            allBlack = false;
            allWhite = false;
        }
    }
    if(allBlack) return ALL_BLACK;
    if(allWhite) return ALL_WHITE;
    return NORMAL;
}

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
float lastPidOutput = 0;
unsigned long lastTelemetryTime = 0;
unsigned long lastLineTime = 0;
unsigned long lastSpeedTime = 0;
int16_t lastLinePosition = 0;
unsigned long loopTime = 0;
unsigned long loopStartTime = 0;
float leftTargetRPM = 0;
float rightTargetRPM = 0;
float throttle = 0;
float steering = 0;
// LED indication
unsigned long lastLedTime = 0;
bool ledState = false;
// Variables para mejoras dinámicas
float previousLinePosition = 0;
float currentCurvature = 0;
float filteredCurvature = 0; // Filtro para suavizar curvatura
SensorState currentSensorState = NORMAL;
int lastTurnDirection = 1; // 1 para derecha, -1 para izquierda
// Idle mode PWM
int16_t idleLeftPWM = 0;
int16_t idleRightPWM = 0;
// Idle mode RPM targets
float idleLeftTargetRPM = 0;
float idleRightTargetRPM = 0;


// ==========================
// FUNCIONES AUXILIARES
// ==========================
TelemetryData buildTelemetryData();





// Función helper para controlar el parpadeo del LED de modo
void updateModeLed(unsigned long currentMillis, unsigned long blinkInterval) {
    if (currentMillis - lastLedTime >= blinkInterval) {
        ledState = !ledState;
        digitalWrite(MODE_LED_PIN, ledState);
        lastLedTime = currentMillis;
    }
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
  // Configurar ganancias PID después de cargar
  linePid.setGains(config.lineKp, config.lineKi, config.lineKd);
  leftPid.setGains(config.leftKp, config.leftKi, config.leftKd);
  rightPid.setGains(config.rightKp, config.rightKi, config.rightKd);
  // Configurar features
  features.setConfig(config.features);

  qtr.setCalibration(config.sensorMin, config.sensorMax);

  
  qtr.calibrate();


  debugger.systemMessage("RObot iniciado. Modo: " + String(config.operationMode));
  lastLineTime = millis();
  lastSpeedTime = millis();
}

// ==========================
// DEBUG Telemetry
// ==========================
TelemetryData buildTelemetryData() {
   TelemetryData data;
   if (config.operationMode == MODE_LINE_FOLLOWING) {
     qtr.read();  // Read sensors only in line-following mode for efficiency
   }
   int16_t* sensors = qtr.getSensorValues();
   memcpy(data.sensors, sensors, sizeof(data.sensors));

  data.linePos = qtr.linePosition;
  data.lineError = linePid.getError();
  data.linePidOut = lastPidOutput;
  data.lineIntegral = linePid.getIntegral();
  data.lineDeriv = linePid.getDerivative();
  data.lPidOut = leftPid.getOutput();
  data.lError = leftPid.getError();
  data.lIntegral = leftPid.getIntegral();
  data.lDeriv = leftPid.getDerivative();
  data.rPidOut = rightPid.getOutput();
  data.rError = rightPid.getError();
  data.rIntegral = rightPid.getIntegral();
  data.rDeriv = rightPid.getDerivative();
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
  data.leftSpeedCms = (data.lRpm * PI * (config.wheelDiameter / 10.0)) / 60.0;
  data.rightSpeedCms = (data.rRpm * PI * (config.wheelDiameter / 10.0)) / 60.0;
  data.battery = analogRead(BATTERY_PIN) * BATTERY_FACTOR;
  data.loopTime = loopTime;
  data.curvature = filteredCurvature;  // Usar curvatura filtrada
  data.sensorState = (uint8_t)currentSensorState;
  return data;
}

// ==========================
// LOOP PRINCIPAL
// ==========================
void loop() {
  unsigned long currentMillis = millis();

  if (currentMillis - lastLineTime >= config.loopLineMs) {
    lastLineTime = currentMillis;
    float dtLine = config.loopLineMs / 1000.0;

    if (config.operationMode == MODE_LINE_FOLLOWING) {
       qtr.read();
        int16_t* rawSensors = qtr.getRawSensorValues();
        // Verificar estado de sensores
        SensorState state = checkSensorState(rawSensors);
        currentSensorState = state;

        // Calcular curvatura para ajustes dinámicos
        // Curvatura = cambio de posición / tiempo, indica qué tan rápido cambia la dirección
       float currentPosition = features.applySignalFilters(qtr.linePosition);
        float curvature = abs(currentPosition - previousLinePosition) / dtLine;
        previousLinePosition = currentPosition;
        currentCurvature = curvature;
        // Aplicar filtro low-pass a la curvatura para suavizar ruido y evitar cambios bruscos
        filteredCurvature = 0.8 * filteredCurvature + 0.2 * curvature;

        // Actualizar dirección del último giro
        if (currentPosition > 10) lastTurnDirection = 1; // derecha
        else if (currentPosition < -10) lastTurnDirection = -1; // izquierda

       // Ajustes dinámicos de velocidad base (Speed Profiling)
       // Reduce velocidad en curvas altas o pérdida de línea para estabilidad y precisión.
       // Aumenta velocidad en rectas para mayor eficiencia y velocidad máxima.
       float applyBaseRPM = config.baseRPM;
       int applyBaseSpeed = config.basePwm;
       if(config.features.speedProfiling) {
         if(filteredCurvature > HIGH_CURVATURE_THRESHOLD || state == ALL_BLACK) {  // Alta curvatura o pérdida de línea
           applyBaseRPM = max(60.0f, applyBaseRPM - 30.0f);
           applyBaseSpeed = max(100, applyBaseSpeed - 50);
         } else if(filteredCurvature < LOW_CURVATURE_THRESHOLD) {  // Baja curvatura (recta)
           applyBaseRPM = min(config.baseRPM + 20.0f, applyBaseRPM + 10.0f);
           applyBaseSpeed = min(config.maxPwm, applyBaseSpeed + 20);
         }
       }

       float pidOutput;
       if(state == ALL_BLACK) {
         // Pérdida de línea (todo negro): giro controlado usando PID con error grande
         // En lugar de cambio brusco, integra con el controlador PID para giro suave
         float turnError = config.features.turnDirection ? -TURN_PID_OUTPUT : TURN_PID_OUTPUT;
         pidOutput = linePid.calculate(0, turnError, dtLine);
       } else if(state == ALL_WHITE) {
         // Pérdida de línea (todo blanco): giro según última dirección de curva
         float turnError = lastTurnDirection * -TURN_PID_OUTPUT;
         pidOutput = linePid.calculate(0, turnError, dtLine);
       } else {
         lastLinePosition = currentPosition;
         float error = 0 - lastLinePosition;
         // Ajuste dinámico de ganancias PID basado en curvatura
         if(config.features.dynamicLinePid) {
           float dynamicKp = config.lineKp + filteredCurvature * 0.001;  // Factor pequeño para ajuste
           float dynamicKd = config.lineKd + filteredCurvature * 0.0005;
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
         leftTargetRPM = applyBaseRPM + rpmAdjustment;
         rightTargetRPM = applyBaseRPM - rpmAdjustment;
       } else {
        // Open-loop control
        int leftSpeed = applyBaseSpeed + pidOutput;
        int rightSpeed = applyBaseSpeed - pidOutput;
        leftSpeed = constrain(leftSpeed, -config.maxPwm, config.maxPwm);
        rightSpeed = constrain(rightSpeed, -config.maxPwm, config.maxPwm);
        leftMotor.setSpeed(leftSpeed);
        rightMotor.setSpeed(rightSpeed);
      }
    }
  }

  if (currentMillis - lastSpeedTime >= config.loopSpeedMs) {
    lastSpeedTime = currentMillis;
    loopStartTime = micros();
    float dtSpeed = config.loopSpeedMs / 1000.0;

    if (config.operationMode == MODE_REMOTE_CONTROL) {
      // Always cascade for remote control
      leftTargetRPM = throttle - steering;
      rightTargetRPM = throttle + steering;
    } else if (config.operationMode == MODE_LINE_FOLLOWING && config.cascadeMode) {
      // targetRPMs already set in line loop
    }

    if (config.operationMode == MODE_REMOTE_CONTROL || (config.operationMode == MODE_LINE_FOLLOWING && config.cascadeMode)) {
        // Calculate PID for each motor
        int leftSpeed = leftPid.calculate(leftTargetRPM, leftMotor.getRPM(), dtSpeed);
        int rightSpeed = rightPid.calculate(rightTargetRPM, rightMotor.getRPM(), dtSpeed);

        leftSpeed = constrain(leftSpeed, -config.maxPwm, config.maxPwm);
        rightSpeed = constrain(rightSpeed, -config.maxPwm, config.maxPwm);

        // Actualizar velocidad máxima registrada
        int currentMax = max(abs(leftSpeed), abs(rightSpeed));
        if(currentMax > config.maxPwm) {
          config.maxPwm = currentMax;
          saveConfig();
        }

        leftMotor.setSpeed(leftSpeed);
        rightMotor.setSpeed(rightSpeed);
      } else if (config.operationMode == MODE_IDLE) {
        if (idleLeftTargetRPM != 0 || idleRightTargetRPM != 0) {
          // Idle RPM control with PID
          int leftSpeed = leftPid.calculate(idleLeftTargetRPM, leftMotor.getRPM(), dtSpeed);
          int rightSpeed = rightPid.calculate(idleRightTargetRPM, rightMotor.getRPM(), dtSpeed);

          leftSpeed = constrain(leftSpeed, -config.maxPwm, config.maxPwm);
          rightSpeed = constrain(rightSpeed, -config.maxPwm, config.maxPwm);

          leftMotor.setSpeed(leftSpeed);
          rightMotor.setSpeed(rightSpeed);
        } else {
          // Direct PWM control
          leftMotor.setSpeed(idleLeftPWM);
          rightMotor.setSpeed(idleRightPWM);
        }
      }

    loopTime = micros() - loopStartTime;
   }

   // Telemetry Print (Non-blocking)
   if (config.telemetry && (millis() - lastTelemetryTime > config.telemetryIntervalMs)) {
      TelemetryData data = buildTelemetryData();
      debugger.sendTelemetryData(data);;
     lastTelemetryTime = millis();
   }

   // LED Mode Indication
   if (config.operationMode == MODE_LINE_FOLLOWING) {
     updateModeLed(currentMillis, 100);
   } else if (config.operationMode == MODE_REMOTE_CONTROL) {
     updateModeLed(currentMillis, 500);
   } else {  // MODE_IDLE
     digitalWrite(MODE_LED_PIN, LOW);
   }

   // Serial Commands
   serialReader.fillBuffer();            // recoge bytes
   const char *cmd;
   if (serialReader.getLine(&cmd)) {     // tenemos línea completa
     if (strlen(cmd) == 0) return;          // línea vacía

     bool handled = false;
     for (int i = 0; commands[i].command != NULL; i++) {
       size_t len = strlen(commands[i].command);
       if (strncmp(cmd, commands[i].command, len) == 0) {
         const char* params = cmd + len;
         commands[i].handler(params);
         handled = true;
         break;
       }
     }

     if (handled) {
       char ackMsg[50];
       sprintf(ackMsg, " %s", cmd);
       debugger.ackMessage(ackMsg);
     } else {
       debugger.systemMessage("Comando desconocido. Envía 'help'");
     }
   }
}

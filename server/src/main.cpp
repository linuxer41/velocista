#include <Arduino.h>
#include <ArduinoJson.h>
#include <EEPROM.h>

// ---------- CONFIGURACIÓN DE PINES ----------
const uint8_t MOT_L1 = 6;  // Motor izq IN1
const uint8_t MOT_L2 = 5;  // Motor izq IN2
const uint8_t MOT_R1 = 10;  // Motor der IN1
const uint8_t MOT_R2 = 9; // Motor der IN2

const uint8_t QTR_PINS[6] = {A0, A1, A2, A3, A4, A5}; // Sensores QTR
const uint8_t QTR_LED = 12; // Control LED IR
const uint8_t CAL_LED = 13; // LED de calibración

const uint8_t ENC_LA = 2; // Encoder izq A
const uint8_t ENC_LB = 3; // Encoder izq B
const uint8_t ENC_RA = 7; // Encoder der A
const uint8_t ENC_RB = 8; // Encoder der B

// ---------- BATERÍA ----------
const uint8_t BAT_PIN = A6;          // Conectar divisor a A6
const float   BAT_R1 = 100000.0;     // 100 kΩ
const float   BAT_R2 = 10000.0;      // 10 kΩ
const float   BAT_RATIO = (BAT_R1 + BAT_R2) / BAT_R2;
const float   BAT_VREF = 1.1;        // Referencia interna
const float   BAT_MIN_V = 6.0;       // Voltaje mínimo (ajustar)
const float   BAT_MAX_V = 8.4;       // Voltaje máximo (ajustar)

float batVoltage = 0;
int batPercent = 0;
uint32_t lastBatRead = 0;

// ---------- VARIABLES DE CONTROL ----------
volatile int32_t encL = 0, encR = 0;
float baseSpeed = 0.8f; // Velocidad base (0-1)
float kp = 1.2f, ki = 0.0f, kd = 0.05f;
float setpoint = 2500.0f; // Centro de línea

// ---------- MODO DE OPERACIÓN ----------
enum Mode : uint8_t {
    LINE_FOLLOW = 0,
    REMOTE_CONTROL = 1,
    SERVO = 2
};
Mode mode = REMOTE_CONTROL;

// ---------- SERVO DISTANCIA ----------
struct ServoDist {
    bool active = false;
    float targetDistance = 0;
    float targetAngle = 0; // grados
    int32_t startEnc = 0;
};
ServoDist servo;

// ---------- CONTROL REMOTO ----------
struct RemoteControl {
   float throttle = 0;    // -1 a 1 (adelante/atrás)
   float turn = 0;        // -1 a 1 (izquierda/derecha)
   float left = 0;        // -1 a 1 (manual izquierdo)
   float right = 0;       // -1 a 1 (manual derecho)
   float direction = 0;   // grados (0-360)
   float acceleration = 0; // 0-1 (velocidad)
};
RemoteControl remote;

// ---------- SERVO ----------

// ---------- CONSTANTES ----------
const float WHEEL_DIAM = 4.5f;     // cm (ajústalo)
const float CM_PER_REV = PI * WHEEL_DIAM;
const int ENCODER_CPR = 358;        // pulsos por vuelta
const float CM_PER_TICK = CM_PER_REV / ENCODER_CPR;
const float CM_PER_DEG = CM_PER_REV / 360.0f; // cm por grado

// ---------- VARIABLES PARA TELEMETRÍA ----------
float rpmL = 0, rpmR = 0;
float speedL = 0, speedR = 0;
float accelL = 0, accelR = 0;
float totalDist = 0;
float leftDist = 0, rightDist = 0;
float lastSpeedL = 0, lastSpeedR = 0;
uint32_t lastTeleTime = 0;
bool telemetryEnabled = true;
float lastPosition = 0;
float lastError = 0;
float lastCorrection = 0;

// ---------- CALIBRACIÓN QTR ----------
uint16_t qtrMin[6] = {0,0,0,0,0,0};
uint16_t qtrMax[6] = {1023,1023,1023,1023,1023,1023};
bool qtrCalibrated = false;

void calibrateQTR() {
    Serial.println(F("Calibrando QTR... mueve el robot sobre línea y fondo"));
    digitalWrite(CAL_LED, HIGH); // Encender LED de calibración
    for (int i = 0; i < 100; i++) {
        for (uint8_t j = 0; j < 6; j++) {
            uint16_t val = analogRead(QTR_PINS[j]);
            if (val < qtrMin[j]) qtrMin[j] = val;
            if (val > qtrMax[j]) qtrMax[j] = val;
        }
        delay(100);
    }
    digitalWrite(CAL_LED, LOW); // Apagar LED de calibración
    Serial.println(F("Calibración lista"));
    qtrCalibrated = true;
}

uint16_t qtr[6];

// ---------- FUNCIONES ----------
void motorWrite(int pwmL, int pwmR) {
  pwmL = constrain(pwmL, -255, 255);
  pwmR = constrain(pwmR, -255, 255);

  if (pwmL >= 0) {
    analogWrite(MOT_L1, pwmL);
    analogWrite(MOT_L2, 0);
  } else {
    analogWrite(MOT_L1, 0);
    analogWrite(MOT_L2, -pwmL);
  }

  if (pwmR >= 0) {
    analogWrite(MOT_R1, pwmR);
    analogWrite(MOT_R2, 0);
  } else {
    analogWrite(MOT_R1, 0);
    analogWrite(MOT_R2, -pwmR);
  }
}

void readQTR() {
  digitalWrite(QTR_LED, HIGH);
  delayMicroseconds(200);
  for (int i = 0; i < 6; i++) {
    uint16_t raw = analogRead(QTR_PINS[i]);
    if (qtrCalibrated) {
      qtr[i] = map(raw, qtrMin[i], qtrMax[i], 0, 1000);
    } else {
      qtr[i] = raw;
    }
  }
  digitalWrite(QTR_LED, LOW);
}

float computePID(float pos) {
  static float prev = 0, integ = 0;
  float err = setpoint - pos;
  integ += err;
  float deriv = err - prev;
  prev = err;
  return kp * err + ki * integ + kd * deriv;
}

// ---------- LECTURA DE BATERÍA ----------
float readBatteryVoltage() {
  uint16_t raw = analogRead(BAT_PIN);
  float vDiv = raw * (BAT_VREF / 1023.0);
  return vDiv * BAT_RATIO;
}

void updateBattery() {
  if (millis() - lastBatRead < 1000) return; // Cada 1 segundo
  lastBatRead = millis();
  
  batVoltage = readBatteryVoltage();
  batPercent = constrain(map(batVoltage * 100, BAT_MIN_V * 100, BAT_MAX_V * 100, 0, 100), 0, 100);
}

// ---------- MODO SERVO DISTANCIA ----------
void startServoDist(float distance, float angle = 0) {
    servo.targetDistance = distance;
    servo.targetAngle = angle;
    servo.startEnc = encL;
    servo.active = true;
    mode = SERVO;
}

void handleServoDist() {
    if (!servo.active) return;
    float done = (encL - servo.startEnc) * CM_PER_TICK;

    // Aplicar corrección angular si hay ángulo objetivo
    float angularCorrection = servo.targetAngle * CM_PER_DEG / 100.0f; // Corrección por cm
    int leftSpeed = (baseSpeed - angularCorrection) * 255;
    int rightSpeed = (baseSpeed + angularCorrection) * 255;
    motorWrite(leftSpeed, rightSpeed);

    if (done >= servo.targetDistance) {
      servo.active = false;
      motorWrite(0, 0);
      JsonDocument statusDoc;
      statusDoc["type"] = "status";
      statusDoc["payload"]["status"] = "servo_completed";
      serializeJson(statusDoc, Serial);
      Serial.println();
      // Queda en modo SERVO esperando siguiente instrucción
    }
}


// ---------- MODO CONTROL REMOTO ----------
void handleRemoteControl() {
   // Si hay comandos de dirección y aceleración
   if (remote.acceleration != 0 && remote.direction >= 0) {
     // Convertir dirección (grados) a componentes izquierda/derecha
     float rad = remote.direction * PI / 180.0f;
     float baseSpeed = remote.acceleration * 255;
     int l = baseSpeed * (1.0f - sin(rad) * 0.5f);
     int r = baseSpeed * (1.0f + sin(rad) * 0.5f);
     motorWrite(l, r);
   }
   // Si hay comandos de autopilot (throttle/turn)
   else if (remote.throttle != 0 || remote.turn != 0) {
     int l = (remote.throttle - remote.turn) * 255;
     int r = (remote.throttle + remote.turn) * 255;
     motorWrite(l, r);
   }
   // Si hay comandos manuales directos (left/right)
   else if (remote.left != 0 || remote.right != 0) {
     motorWrite(remote.left * 255, remote.right * 255);
   }
   else {
     motorWrite(0, 0);
   }
}

// ---------- TELEMETRÍA COMPLETA ----------
void sendTele() {
   static uint32_t lastTime = 0;
   uint32_t now = millis();
   float dt = (now - lastTime) / 1000.0f;
   if (dt == 0) return;
   lastTime = now;

   // Actualizar batería
   updateBattery();

   // RPM
   rpmL = (encL * 60.0f) / (ENCODER_CPR * dt);
   rpmR = (encR * 60.0f) / (ENCODER_CPR * dt);

   // Velocidad lineal (cm/s)
   speedL = (encL * CM_PER_TICK) / dt;
   speedR = (encR * CM_PER_TICK) / dt;

   // Aceleración
   accelL = (speedL - lastSpeedL) / dt;
   accelR = (speedR - lastSpeedR) / dt;
   lastSpeedL = speedL;
   lastSpeedR = speedR;

   // Distancia total e individual
   leftDist += speedL * dt;
   rightDist += speedR * dt;
   totalDist = (leftDist + rightDist) / 2.0f;

   // Enviar JSON
   JsonDocument doc;
   doc["type"] = "telemetry";
   JsonObject payload = doc["payload"].to<JsonObject>();
   payload["timestamp"] = millis();
   payload["mode"] = mode;
   payload["velocity"] = (speedL + speedR) / 2.0f;
   payload["acceleration"] = (accelL + accelR) / 2.0f;
   payload["distance"] = totalDist;
   payload["battery"] = batVoltage;

   JsonObject leftObj = payload["left"].to<JsonObject>();
   leftObj["vel"] = speedL;
   leftObj["acc"] = accelL;
   leftObj["rpm"] = rpmL;
   leftObj["encoder"] = encL;
   leftObj["distance"] = leftDist;

   JsonObject rightObj = payload["right"].to<JsonObject>();
   rightObj["vel"] = speedR;
   rightObj["acc"] = accelR;
   rightObj["rpm"] = rpmR;
   rightObj["encoder"] = encR;
   rightObj["distance"] = rightDist;

   JsonArray qtrArray = payload["qtr"].to<JsonArray>();
   for (int i = 0; i < 6; i++) qtrArray.add(qtr[i]);

   JsonArray pidArray = payload["pid"].to<JsonArray>();
   pidArray.add(kp);
   pidArray.add(ki);
   pidArray.add(kd);

   payload["set_point"] = setpoint;
   payload["base_speed"] = baseSpeed;
   payload["error"] = lastError;
   payload["correction"] = lastCorrection;

   serializeJson(doc, Serial);
   Serial.println();
}

// ---------- JSON HANDLER ----------
void handleCommand (String &cmd) {
  // Process the command


  JsonDocument cmdDoc;
  cmdDoc["type"] = "cmd";
  cmdDoc["payload"]["buffer"] = cmd;
  serializeJson(cmdDoc, Serial);
  Serial.println();
  JsonDocument doc;
  if (deserializeJson(doc, cmd)) return;

  if (doc["mode"].is<int>()) {
    mode = (Mode)doc["mode"].as<int>();
    if (mode == LINE_FOLLOW) calibrateQTR();
  }

  if (doc["pid"].is<JsonArray>()) {
    JsonArray arr = doc["pid"];
    kp = arr[0];
    ki = arr[1];
    kd = arr[2];
  }

  if (doc["speed"]["base"].is<float>()) baseSpeed = doc["speed"]["base"];

  if (doc["eeprom"].is<int>()) {
    EEPROM.put(0, kp);
    EEPROM.put(10, ki);
    EEPROM.put(20, kd);
    EEPROM.put(30, baseSpeed);
    JsonDocument statusDoc;
    statusDoc["type"] = "status";
    statusDoc["payload"]["status"] = "eeprom_saved";
    serializeJson(statusDoc, Serial);
    Serial.println();
  }

  if (doc["telemetry"].is<int>()) {
    if (telemetryEnabled) sendTele();
  }

  if (doc["telemetry_enable"].is<bool>()) {
    telemetryEnabled = doc["telemetry_enable"];
    JsonDocument statusDoc;
    statusDoc["type"] = "status";
    statusDoc["payload"]["status"] = telemetryEnabled ? "telemetry_enabled" : "telemetry_disabled";
    serializeJson(statusDoc, Serial);
    Serial.println();
  }

  if (doc["servo"].is<JsonObject>()) {
    JsonObject servoObj = doc["servo"];
    if (servoObj["distance"].is<float>()) {
      float distance = servoObj["distance"];
      float angle = servoObj["angle"].is<float>() ? servoObj["angle"] : 0;
      startServoDist(distance, angle);
    }
  }

  // Handle remote control commands (both nested and top-level)
  bool remoteUpdated = false;
  if (doc["rc"].is<JsonObject>()) {
    JsonObject rc = doc["rc"];
    // Reset all remote control values first
    remote.throttle = 0;
    remote.turn = 0;
    remote.left = 0;
    remote.right = 0;
    remote.direction = -1; // -1 indica no establecido
    remote.acceleration = 0;

    // Set direction and acceleration if provided (prioridad alta)
    if (rc["direction"].is<float>()) remote.direction = rc["direction"];
    if (rc["acceleration"].is<float>()) remote.acceleration = rc["acceleration"];

    // Set autopilot values if provided
    if (rc["throttle"].is<float>()) remote.throttle = rc["throttle"];
    if (rc["turn"].is<float>()) remote.turn = rc["turn"];

    // Set manual values if provided (these override autopilot)
    if (rc["left"].is<float>()) remote.left = rc["left"];
    if (rc["right"].is<float>()) remote.right = rc["right"];

    remoteUpdated = true;
  } else if (doc["throttle"].is<float>() || doc["turn"].is<float>() || doc["direction"].is<float>() || doc["acceleration"].is<float>() || doc["left"].is<float>() || doc["right"].is<float>()) {
    // Handle top-level remote control keys
    remote.throttle = 0;
    remote.turn = 0;
    remote.left = 0;
    remote.right = 0;
    remote.direction = -1;
    remote.acceleration = 0;

    if (doc["direction"].is<float>()) remote.direction = doc["direction"];
    if (doc["acceleration"].is<float>()) remote.acceleration = doc["acceleration"];
    if (doc["throttle"].is<float>()) remote.throttle = doc["throttle"];
    if (doc["turn"].is<float>()) remote.turn = doc["turn"];
    if (doc["left"].is<float>()) remote.left = doc["left"];
    if (doc["right"].is<float>()) remote.right = doc["right"];

    remoteUpdated = true;
  }

  if (remoteUpdated) {
    mode = REMOTE_CONTROL;
  }

  if (doc["calibrate_qtr"].is<int>()) {
    calibrateQTR();
    JsonDocument statusDoc;
    statusDoc["type"] = "status";
    statusDoc["payload"]["status"] = "qtr_calibrated";
    serializeJson(statusDoc, Serial);
    Serial.println();
  }
}

// ---------- INTERRUPCIONES ----------
void isrL() {
  encL += (digitalRead(ENC_LB) ? 1 : -1);
}
void isrR() {
  encR += (digitalRead(ENC_RB) ? 1 : -1);
}

// ---------- SETUP ----------
void setup() {
   Serial.begin(9600); // Hardware serial para Bluetooth (pines 0 y 1)
   pinMode(QTR_LED, OUTPUT);
   pinMode(CAL_LED, OUTPUT);
   analogReference(INTERNAL); // Referencia 1,1 V para batería

  for (int i = 0; i < 6; i++) pinMode(QTR_PINS[i], INPUT);
  pinMode(BAT_PIN, INPUT);

  attachInterrupt(digitalPinToInterrupt(ENC_LA), isrL, RISING);
  attachInterrupt(digitalPinToInterrupt(ENC_RA), isrR, RISING);

  // Cargar configuración desde EEPROM

    float test;
    EEPROM.get(0, test);
    if (isnan(test) || test > 100 || test < -100) { // basura
        kp = 1.2f; ki = 0.0f; kd = 0.05f; baseSpeed = 0.8f;
        EEPROM.put(0, kp); EEPROM.put(10, ki);
        EEPROM.put(20, kd); EEPROM.put(30, baseSpeed);
    } else {
        EEPROM.get(0, kp); EEPROM.get(10, ki);
        EEPROM.get(20, kd); EEPROM.get(30, baseSpeed);
    }
    if (mode == LINE_FOLLOW) calibrateQTR();


  JsonDocument statusDoc;
  statusDoc["type"] = "status";
  statusDoc["payload"]["status"] = "system_started";
  serializeJson(statusDoc, Serial);
  Serial.println();
}

// ---------- LOOP ----------
void loop() {
  readQTR();
  if (Serial.available()) {
    static String cmdBuffer = "";
    while (Serial.available()) {
      char c = Serial.read();
      if (c == '\n') {
        // Remove \r if present
        if (cmdBuffer.endsWith("\r")) {
          cmdBuffer = cmdBuffer.substring(0, cmdBuffer.length() - 1);
        }
        if (cmdBuffer.length() == 0) continue;
        handleCommand(cmdBuffer);
        cmdBuffer = "";
      } else {
        cmdBuffer += c;
      }
    }
  }
  if(telemetryEnabled && millis() - lastTeleTime >= 1000) {
    lastTeleTime = millis();
    sendTele();
  }

  switch (mode) {
    case LINE_FOLLOW: {
        if (!qtrCalibrated) {
          motorWrite(0, 0);
          break;
        }
        uint32_t sum = 0, wt = 0;
        for (int i = 0; i < 6; i++) {
          uint32_t v = qtr[i];
          uint32_t weight = 1000 - v; // Higher weight on black surfaces (low v)
          wt += weight;
          sum += weight * (i * 1000);
        }
        float pos = (wt > 0) ? (float)sum / wt - 2500.0f : -1;
        if (wt > 0) {
          float corr = computePID(pos);
          lastPosition = pos;
          lastError = setpoint - pos;
          lastCorrection = corr;
          int l = (baseSpeed - corr) * 255;
          int r = (baseSpeed + corr) * 255;
          motorWrite(l, r);
        } else {
          motorWrite(0, 0);
        }
        break;
      }
    case REMOTE_CONTROL:
      handleRemoteControl();
      break;
    case SERVO:
      handleServoDist();
      break;
  }
}
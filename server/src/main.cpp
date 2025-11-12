/*
  Robot seguidor de línea profesional
  Autor: tu nombre
  Hardware: exactamente el esquema original
*/
#include <Arduino.h>
#include <EEPROM.h>
#include <ArduinoJson.h>
#include <TimerOne.h>

// ---------- PINS ORIGINALES ----------
const uint8_t MOT_L1 = 6, MOT_L2 = 5;
const uint8_t MOT_R1 = 10, MOT_R2 = 9;
const uint8_t QTR_PINS[6] = {A0, A1, A2, A3, A4, A5};
const uint8_t QTR_LED = 12, CAL_LED = 13;
const uint8_t ENC_LA = 2, ENC_LB = 7, ENC_RA = 3, ENC_RB = 8;
const uint8_t BAT_PIN = A6;
const uint8_t BUZZER = 4;

// ---------- CONSTANTS ----------
constexpr int32_t  CPR        = 358;
constexpr float    CM_PER_REV = PI * 4.5f;
constexpr float    CM_PER_TICK = CM_PER_REV / CPR;
constexpr float    LOOP_HZ    = 100.0f;
constexpr float    DT         = 1.0f / LOOP_HZ;
constexpr uint16_t EEPROM_ADDR_BASE  = 0;
constexpr uint16_t EEPROM_ADDR_DIAM  = 32;
constexpr uint16_t LOG_ENTRIES       = 1200;   // 1200 * 8 B = 9.6 kB EEPROM
// ---------- BATERÍA ----------
const float BAT_R1 = 100000.0f;     // 100 kΩ
const float BAT_R2 = 10000.0f;      // 10 kΩ
const float BAT_RATIO = (BAT_R1 + BAT_R2) / BAT_R2;
const float BAT_VREF = 1.1f;        // Referencia interna
const float BAT_MIN_V = 6.0f;       // Voltaje mínimo
const float BAT_MAX_V = 8.4f;       // Voltaje máximo

// ---------- ENUMS ----------
enum Mode : uint8_t { LINE_FOLLOW, REMOTE, SERVO };

// ---------- GLOBALS ----------
Mode mode = LINE_FOLLOW;
bool teleEnabled = true;
uint32_t lastTele = 0;
float kpLine = 1.2f, kiLine = 0.0f, kdLine = 0.05f;
float setpointLine = 0.0f;
uint16_t qtr[6], qtrMin[6], qtrMax[6];
bool qtrCalibrated = false;
float baseSpeed = 0.8f;
float leftDist = 0, rightDist = 0;
float lineErr = 0.0f, lineCorr = 0.0f;  // for telemetry
float batVoltage = 0;
int batPercent = 0;
uint32_t lastBatRead = 0;

// ---------- UTILS ----------
inline void led(bool s) { digitalWrite(CAL_LED, s); }
inline void beep(uint8_t n) {
    for (uint8_t i = 0; i < n; i++) {
        tone(BUZZER, 2200, 40);
        delay(60);
    }
}

// ---------- REMOTE CONTROL STRUCT ----------
struct RemoteControl {
    float throttle = 0;
    float turn = 0;
} remote;

// ---------- MOTOR STRUCT ----------
struct Motor {
    const uint8_t in1, in2, encA, encB;
    volatile int32_t ticks = 0;
    float targetRPM = 0, filtRPM = 0;
    float kp = 0.9f, ki = 2.2f, kd = 0.0f, errI = 0, prevErr = 0;
    int16_t pwm = 0;
    float diamCorr = 1.0f;
    float dist = 0.0f;  // accumulated distance in cm
    static constexpr float iwLimit = 500.0f; // anti-windup: max integral (ajusta)
    static constexpr float ALPHA = 0.2f;
    Motor(const uint8_t i1, const uint8_t i2, const uint8_t ea, const uint8_t eb) : in1(i1), in2(i2), encA(ea), encB(eb) {}
    void isr() { ticks += digitalRead(encB) ? 1 : -1; }
    void update(float dt);
    void setRPM(float r) { targetRPM = constrain(r, -300, 300); }
};

Motor left(MOT_L1, MOT_L2, ENC_LA, ENC_LB);
Motor right(MOT_R1, MOT_R2, ENC_RA, ENC_RB);

// ---------- SERVO ----------
struct Servo {
    bool active = 0;
    float tgtDist = 0, tgtVel = 0, startDist = 0;
    void start(float d, float v) {
        tgtDist = d;
        tgtVel = v;
        active = 1;
        startDist = (leftDist + rightDist) / 2;
    }
    void update() {
        if (!active) return;
        float done = (leftDist + rightDist) / 2 - startDist;
        float err = tgtDist - done;
        if (err <= 0) {
            active = 0;
            left.setRPM(0);
            right.setRPM(0);
            beep(1);
            return;
        }
        float vel = constrain(err * 2, 0, tgtVel);
        left.setRPM(vel);
        right.setRPM(vel);
    }
} servo;
// ---------- BUFFER SERIE ----------
#define SER_BUF 128
char serBuf[SER_BUF];
uint8_t serHead = 0;



// ---------- EEPROM ----------
template<typename T> void eepWrite(int addr, T &obj) { EEPROM.put(addr, obj); }
template<typename T> void eepRead (int addr, T &obj) { EEPROM.get(addr, obj); }

// ---------- MOTOR UPDATE ----------
void Motor::update(float dt) {
    /* ---------- 1. Lectura y filtro de velocidad ---------- */
    int32_t delta = ticks;
    ticks = 0;
    float rpm = (delta * 60.0f) / (CPR * dt) * diamCorr;
    filtRPM = ALPHA * rpm + (1 - ALPHA) * filtRPM;

    /* ---------- 2. PID normal ---------- */
    float err = targetRPM - filtRPM;
    float dedt = (err - prevErr) / dt;
    prevErr = err;

    float out = kp * err + ki * errI + kd * dedt;
    pwm = (int16_t)constrain(out, -255, 255);

    /* ---------- 3. Anti-windup (des-satura integrador) ---------- */
    float excess = out - pwm;               // cuanto se recortó
    errI -= excess * ki * dt * 0.5f;        // retroalimenta la integral
    errI = constrain(errI, -iwLimit, iwLimit); // limita integrador

    /* ---------- 4. Acumular distancia ---------- */
    dist += filtRPM * dt * CM_PER_REV / 60.0f;  // cm

    /* ---------- 5. Aplicar PWM ---------- */
    if (pwm >= 0) {
        digitalWrite(in2, LOW);
        analogWrite(in1, pwm);
    } else {
        digitalWrite(in1, LOW);
        analogWrite(in2, -pwm);
    }
}
// ---------- QTR ----------
/* ----------
 *  Lee los 6 sensores reflectivos QTR-1A (o compatibles).
 *  Secuencia:
 *    1. Enciende el LED infrarrojo de iluminación.
 *    2. Espera 200 µs para que la luz y el ADC se estabilicen.
 *    3. Lee cada canal analógico (0-1023) y lo convierte a
 *       rango 0-1000 si ya se ha calibrado.
 *    4. Apaga el LED para ahorrar energía y reducir ruido.
 *
 *  Salida: array global qtr[6]
 *    0   = superficie muy reflectiva (blanco)
 *    1000= superficie poco reflectiva (negro)
 */
void readQTR()
{
    /* 1. Encendemos el LED que ilumina el suelo con IR */
    digitalWrite(QTR_LED, HIGH);

    /* 2. Pausa corta para que la luz se estabilice y los
     *    fototransistores respondan (≈ 200 µs es suficiente) */
    delayMicroseconds(200);

    /* 3. Leemos los 6 canales analógicos ---------------------- */
    for (uint8_t i = 0; i < 6; i++)
    {
        /* Lectura cruda del ADC (0-1023) */
        uint16_t v = analogRead(QTR_PINS[i]);

        /* Si ya calibramos, escalamos el valor al rango 0-1000
         * qtrMin[i] = mínimo visto (más negro)
         * qtrMax[i] = máximo visto (más blanco)
         * constrain evita valores fuera de rango por si acaso */
        if (qtrCalibrated)
            v = map(constrain(v, qtrMin[i], qtrMax[i]),
                    qtrMin[i], qtrMax[i], 0, 1000);

        /* Guardamos el resultado en el array global */
        qtr[i] = v;
    }

    /* 4. Apagamos el LED para ahorrar energía y reducir
     *    interferencias con otros sensores cercanos */
    digitalWrite(QTR_LED, LOW);
}

/* ----------------
 *  Convierte los 6 valores de los sensores QTR (0-1000) en una ÚNICA coordenada
 *  que indica dónde está el CENTRO de la línea negra respecto al centro físico
 *  del robot.
 *
 *  Valor devuelto:
 *    -2500  -> línea muy a la IZQUIERDA (sensor 0)
 *       0   -> línea en el CENTRO (entre sensores 2 y 3)
 *    +2500  -> línea muy a la DERECHA  (sensor 5)
 *
 *  Método: centro de masa ponderada (más negro = más peso).
 */
float computeLinePos()
{
    uint32_t sum = 0;   // Acumula (peso × posición) de cada sensor
    uint32_t wt  = 0;   // Acumula el peso total (para normalizar después)

    /* Recorremos los 6 sensores ------------------------------------------- */
    for (uint8_t i = 0; i < 6; i++)
    {
        /* Cuanto más NEGRO vea el sensor, mayor será su peso.
         * qtr[i] = 0   (blanco)  -> w = 1000
         * qtr[i] = 1000(negro)   -> w = 0
         * Invertimos así:  w = 1000 - qtr[i]  */
        uint16_t w = 1000 - qtr[i];

        wt += w;                 // Suma de pesos (denominador)

        /* i es el índice del sensor (0-5).
         * Lo escalamos a milésimas:  i*1000 -> 0, 1000, 2000, ..., 5000
         * Con esto el centro físico estaría en 2500. */
        sum += w * i * 1000;     // Suma ponderada de posiciones
    }

    /* Evitamos división por cero (todos los sensores en blanco) */
    if (wt == 0) return 0.0f;

    /* Centro de masa en milésimas (0-5000) */
    float centro = (float)sum / wt;

    /* Restamos 2500 para que el centro del robot sea 0 */
    return centro - 2500.0f;
}

// ---------- KALMAN ----------
/* kalmanLine()
 * ------------
 *  Filtro de Kalman de 1ª orden: suaviza la señal de
 *  computeLinePos() sin reducir el ancho de banda de forma
 *  drástica. Ideal para quitar ruido de baja amplitud
 *  producido por imperfecciones del suelo o reflejos.
 *
 *  Variables:
 *    x  : estimación actual (la devuelve)
 *    P  : incertidumbre de la estimación (covarianza)
 *    z  : medida (computeLinePos)
 *    R  : ruido del sensor (30)  – ajustable
 *    Q  : ruido del modelo (2)   – ajustable
 *
 *  Paso a paso:
 *    1. Predicción: x se mantiene, P crece Q
 *    2. Actualización: se corrige con la medida z
 *  Retorno: posición filtrada (misma escala que z)
 */
float kalmanLine()
{
    /* Estado y covarianza: conservados entre llamadas */
    static float x = 0.0f;   // posición estimada (filtrada)
    static float P = 1.0f;   // incertidumbre

    /* 1. Lectura de la medida (ruidoso) */
    float z = computeLinePos();

    /* 2. Ganancia de Kalman K = P / (P + R) */
    float R = 30.0f;         // varianza del sensor (confianza en z)
    float Q = 2.0f;          // varianza del modelo (confianza en x)
    float y = z - x;         // innovación (error de medida)
    float S = P + R;         // covarianza del error
    float K = P / S;         // ganancia (0-1)

    /* 3. Actualización del estado */
    x = x + K * y;           // corrección proporcional a la innovación

    /* 4. Actualización de la covarianza */
    P = (1.0f - K) * P + Q;  // reduce incertidumbre pero añade Q

    /* 5. Devolvemos la estimación filtrada */
    return x;
}

// ---------- LINE PID ----------
/* linePID(float pos)
 * ------------------
 *  PID discreto para el seguimiento de línea.
 *  Entrada: posición de la línea (devuelta por kalmanLine() u otro filtro).
 *  Salida: corrección en RPM que se sumará/restará a los motores.
 *
 *  setpointLine = 0  (línea centrada); se puede cambiar para curvas
 *  LOOP_HZ = 100  =>  dt = 0.01 s
 *
 *  Constantes (ajustables por EEPROM o serial):
 *    kpLine  -> fuerza proporcional (1.2)
 *    kiLine  -> fuerza integral     (0.0)
 *    kdLine  -> fuerza derivativa   (0.05)
 *
 *  Variables internas (conservadas):
 *    prev  -> error anterior (para derivada)
 *    integ -> suma acumulada de errores (integral)
 */
float linePID(float pos)
{
    static float prev = 0, integ = 0;
    /* 1. Error actual: diferencia entre punto deseado y medido */
    float err = setpointLine - pos;          // setpointLine suele ser 0

    /* 2. Parte integral: acumula el error (se saturará externamente si hace falta) */
    integ += err;                            // dt está implícito en kiLine

    /* 3. Parte derivada: velocidad de cambio del error
     *    Como dt = 1/LOOP_HZ, multiplicamos directamente por LOOP_HZ */
    float deriv = (err - prev) * LOOP_HZ;   // (error_now - error_prev) / dt
    prev = err;                             // guardamos para la próxima vuelta

    /* 4. Salida PID: corrección en RPM (se resta/suma a cada motor) */
    return kpLine * err + kiLine * integ + kdLine * deriv;
}

float readBattery();

// ---------- BATERÍA ----------
void updateBattery() {
    if (millis() - lastBatRead < 1000) return; // Cada 1 segundo
    lastBatRead = millis();
    batVoltage = readBattery();
    batPercent = constrain(map(batVoltage * 100, BAT_MIN_V * 100, BAT_MAX_V * 100, 0, 100), 0, 100);
}

// ---------- TELEMETRY ----------
#pragma pack(push,1)
struct Tele {
    uint32_t time;
    int16_t  rpmL, rpmR;   // ×10
    uint16_t pos;          // ×100 (cm con 2 decimales, offset +25)
    uint16_t bat;          // ×1000 (mV)
    uint8_t  mode;
    uint8_t  crc;
};
#pragma pack(pop)

void sendTele() {
    static uint32_t lastTime = 0;
    uint32_t now = millis();
    float dt = (now - lastTime) / 1000.0f;
    if (dt == 0) return;
    lastTime = now;

    // Actualizar batería
    updateBattery();

    // RPM
    float rpmL = (left.ticks * 60.0f) / (CPR * dt);
    float rpmR = (right.ticks * 60.0f) / (CPR * dt);

    // Velocidad lineal (cm/s)
    float speedL = (left.ticks * CM_PER_TICK) / dt;
    float speedR = (right.ticks * CM_PER_TICK) / dt;

    // Distancia total e individual
    leftDist += speedL * dt;
    rightDist += speedR * dt;
    float totalDist = (leftDist + rightDist) / 2.0f;

    // Enviar JSON
    JsonDocument doc;
    doc["type"] = "telemetry";
    JsonObject payload = doc["payload"].to<JsonObject>();
    payload["timestamp"] = millis();
    payload["mode"] = mode;
    payload["velocity"] = (speedL + speedR) / 2.0f;
    payload["acceleration"] = 0.0f; // Placeholder
    payload["distance"] = totalDist;
    payload["battery"] = batVoltage;

    JsonObject leftObj = payload["left"].to<JsonObject>();
    leftObj["vel"] = speedL;
    leftObj["acc"] = 0.0f;
    leftObj["rpm"] = rpmL;
    leftObj["encoder"] = left.ticks;
    leftObj["distance"] = leftDist;
    leftObj["pwm"] = left.pwm;

    JsonObject rightObj = payload["right"].to<JsonObject>();
    rightObj["vel"] = speedR;
    rightObj["acc"] = 0.0f;
    rightObj["rpm"] = rpmR;
    rightObj["encoder"] = right.ticks;
    rightObj["distance"] = rightDist;
    rightObj["pwm"] = right.pwm;

    JsonArray qtrArray = payload["qtr"].to<JsonArray>();
    for (int i = 0; i < 6; i++) qtrArray.add(qtr[i]);

    JsonArray pidArray = payload["pid"].to<JsonArray>();
    pidArray.add(kpLine);
    pidArray.add(kiLine);
    pidArray.add(kdLine);

    payload["set_point"] = setpointLine;
    payload["base_speed"] = baseSpeed;
    payload["error"] = lineErr;
    payload["correction"] = lineCorr;

    serializeJson(doc, Serial);
    Serial.println();

    // Reset ticks for next measurement
    left.ticks = 0;
    right.ticks = 0;
}


float readBattery() {
    uint16_t raw = analogRead(BAT_PIN);
    float vDiv = raw * (BAT_VREF / 1023.0f);
    return vDiv * BAT_RATIO;
}

// ---------- FUNCTIONS DECLARATIONS ----------
void calibrateQTR();
void motorWrite(int, int);
void handleRemote();

// ---------- AUTO-TUNE ----------
void tuneLine() {
    beep(2);
    kpLine = 0; kiLine = 0; kdLine = 0;
    float Ku = 0, Pu = 0.8f;
    float steer = 0;
    for (Ku = 0.1f; Ku < 5; Ku += 0.1f) {
        kpLine = Ku;
        for (uint16_t t = 0; t < 100; t++) {
            readQTR();
            steer = linePID(kalmanLine());
            left.setRPM(60 - steer);
            right.setRPM(60 + steer);
            left.update(DT);
            right.update(DT);
            delay(10);
        }
        if (abs(steer) > 50) break;
    }
    kpLine = 0.6f * Ku;
    kiLine = 2 * kpLine / Pu;
    kdLine = kpLine * Pu / 8;
    eepWrite(EEPROM_ADDR_BASE + 20, kpLine);
    eepWrite(EEPROM_ADDR_BASE + 24, kiLine);
    eepWrite(EEPROM_ADDR_BASE + 28, kdLine);
    beep(3);
}

// ---------- JSON PARSER ----------
void execCmd(const char *json) {
    // Send received command as telemetry
    JsonDocument cmdDoc;
    cmdDoc["type"] = "cmd";
    cmdDoc["payload"]["buffer"] = json;
    serializeJson(cmdDoc, Serial);
    Serial.println();

    JsonDocument doc;
    if (deserializeJson(doc, json)) return;

    if (doc["mode"].is<int>()) {
        mode = (Mode)doc["mode"].as<int>();
        if (mode == LINE_FOLLOW) calibrateQTR();
    }

    if (doc["pid"].is<JsonArray>()) {
        JsonArray arr = doc["pid"];
        kpLine = arr[0];
        kiLine = arr[1];
        kdLine = arr[2];
    }

    if (doc["base_speed"].is<float>()) baseSpeed = doc["base_speed"];
  
    if (doc["eeprom"].is<int>()) {
      EEPROM.put(EEPROM_ADDR_BASE + 20, kpLine);
      EEPROM.put(EEPROM_ADDR_BASE + 24, kiLine);
      EEPROM.put(EEPROM_ADDR_BASE + 28, kdLine);
      EEPROM.put(EEPROM_ADDR_BASE + 12, baseSpeed);
    }

    if (doc["tele"].is<int>()) {
      int teleCmd = doc["tele"];
      if (teleCmd == 2) {  // get once
        sendTele();
      } else if (teleCmd == 1) {  // on
        teleEnabled = true;
      } else if (teleCmd == 0) {  // off
        teleEnabled = false;
      }
    }

    if (doc["qtr"].is<int>()) {
      calibrateQTR();
    }

    if (doc["servo"].is<JsonObject>()) {
      JsonObject servoObj = doc["servo"];
      if (servoObj["distance"].is<float>()) {
        float distance = servoObj["distance"];
        float angle = servoObj["angle"].is<float>() ? servoObj["angle"] : 0;
        servo.start(distance, angle);
        mode = SERVO;
      }
    }

    if (doc["rc"].is<JsonObject>()) {
      JsonObject rc = doc["rc"];
      // Reset only throttle and turn
      remote.throttle = 0;
      remote.turn = 0;

      if (rc["throttle"].is<float>()) remote.throttle = rc["throttle"];
      if (rc["turn"].is<float>()) remote.turn = rc["turn"];
      mode = REMOTE;
    }
}

// ---------- SERIE ----------
void serialEvent() {
    while (Serial.available()) {
        char c = (char)Serial.read();
        if (c == '\n') {
            serBuf[serHead] = 0;
            execCmd(serBuf);
            serHead = 0;
        } else {
            serBuf[serHead++] = c;
            if (serHead >= SER_BUF - 1) serHead = 0;
        }
    }
}


// ---------- SETUP ----------
void setup() {
    Serial.begin(9600);
    analogReference(INTERNAL);
    pinMode(QTR_LED, OUTPUT);
    pinMode(CAL_LED, OUTPUT);
    pinMode(BUZZER, OUTPUT);
    for (uint8_t i = 0; i < 6; i++) pinMode(QTR_PINS[i], INPUT);
    attachInterrupt(digitalPinToInterrupt(ENC_LA), []{left.isr();}, RISING);
    attachInterrupt(digitalPinToInterrupt(ENC_RA), []{right.isr();}, RISING);

    // Cargar valores desde EEPROM
    eepRead(EEPROM_ADDR_BASE, left.kp);
    eepRead(EEPROM_ADDR_BASE + 4, left.ki);
    eepRead(EEPROM_ADDR_BASE + 8, left.kd);
    eepRead(EEPROM_ADDR_BASE + 12, baseSpeed);
    right.kp = left.kp;
    right.ki = left.ki;
    right.kd = left.kd;
    eepRead(EEPROM_ADDR_BASE + 20, kpLine);
    eepRead(EEPROM_ADDR_BASE + 24, kiLine);
    eepRead(EEPROM_ADDR_BASE + 28, kdLine);
    eepRead(EEPROM_ADDR_DIAM, right.diamCorr);

    // Validar valores leídos de EEPROM
    if (left.kp <= 0 || isnan(left.kp)) left.kp = 0.9f;
    if (left.ki < 0 || isnan(left.ki)) left.ki = 2.2f;
    if (left.kd < 0 || isnan(left.kd)) left.kd = 0.0f;
    if (baseSpeed <= 0 || baseSpeed > 1 || isnan(baseSpeed)) baseSpeed = 0.8f;
    if (kpLine < 0 || isnan(kpLine)) kpLine = 1.2f;
    if (kiLine < 0 || isnan(kiLine)) kiLine = 0.0f;
    if (kdLine < 0 || isnan(kdLine)) kdLine = 0.05f;
    right.kp = left.kp;
    right.ki = left.ki;
    right.kd = left.kd;

    Timer1.initialize(10000);
    Timer1.attachInterrupt([]{ left.update(DT); right.update(DT); });
    beep(1);
}

// ---------- LOOP ----------
void loop() {
    static uint32_t t0 = 0;
    if (micros() - t0 >= 10000) {
        t0 = micros();
        readQTR();
        switch (mode) {
            case LINE_FOLLOW: {
                if (!qtrCalibrated) { motorWrite(0, 0); break; }
                float currentPos = kalmanLine();
                float steer = linePID(currentPos);
                lineErr = setpointLine - currentPos;
                lineCorr = steer;
                float base = baseSpeed * 60;
                left.setRPM(base - steer);
                right.setRPM(base + steer);
                break;
            }
            case REMOTE: handleRemote(); break;
            case SERVO: servo.update(); break;
        }
        if (teleEnabled && millis() - lastTele >= 10) { lastTele = millis(); sendTele(); }
    }
}

// ---------- AUX ----------
void motorWrite(int l, int r) {
    left.setRPM(l / 2);
    right.setRPM(r / 2);
}

void handleRemote() {
    if (remote.throttle != 0 || remote.turn != 0) {
        float base = remote.throttle * baseSpeed * 60.0f;
        float steer = remote.turn * baseSpeed * 60.0f;
        left.setRPM(base - steer);
        right.setRPM(base + steer);
    } else {
        // Detener motores si no hay comandos
        left.setRPM(0);
        right.setRPM(0);
    }
}

void calibrateQTR() {
    led(HIGH);
    for (uint16_t i = 0; i < 400; i++) {
        readQTR();
        for (uint8_t j = 0; j < 6; j++) {
            if (qtr[j] < qtrMin[j]) qtrMin[j] = qtr[j];
            if (qtr[j] > qtrMax[j]) qtrMax[j] = qtr[j];
        }
        delay(5);
    }
    qtrCalibrated = true;
    led(LOW);
}
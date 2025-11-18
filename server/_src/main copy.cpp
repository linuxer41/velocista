// /*
//   Robot seguidor de línea profesional
//   Autor: tu nombre
//   Hardware: exactamente el esquema original
// */
// #include <Arduino.h>
// #include <EEPROM.h>
// #include <ArduinoJson.h>
// #include <TimerOne.h>
// #include <PinChangeInterrupt.h>
// #include <avr/wdt.h>

// // ---------- PINS ORIGINALES ----------
// const uint8_t MOT_L_FORWARD = 6, MOT_L_BACKWARD = 5;
// const uint8_t MOT_R_FORWARD = 10, MOT_R_BACKWARD = 9;
// const uint8_t ENC_LA = 2, ENC_RA = 3, ENC_LB = 7, ENC_RB = 8;
// const uint8_t QTR_PINS[6] = {A0, A1, A2, A3, A4, A5};
// const uint8_t QTR_LED = 12, CAL_LED = 13;

// const uint8_t BUZZER = 4;

// // ---------- CONSTANTS ----------
// const int32_t MOTOR_PPR  = 358;
// const float   REDUCTION  = 10.0;
// const int32_t WHEEL_PPR = MOTOR_PPR / REDUCTION;
// const float   PERIMETER  = PI * 4.5f;            // 14.14 cm
// const float    PULSES_PER_CM = WHEEL_PPR / PERIMETER;  // 253.2
// constexpr int32_t  CPR        = WHEEL_PPR;
// constexpr float    CM_PER_REV = PI * 4.5f;
// constexpr float    CM_PER_TICK = CM_PER_REV / CPR;
// constexpr float LOOP_HZ    = 100.0f;
// constexpr float DT         = 1.0f / LOOP_HZ;
// constexpr uint16_t EEPROM_ADDR_BASE  = 0;
// constexpr uint16_t EEPROM_ADDR_DIAM  = 32;
// constexpr uint16_t EEPROM_ADDR_QTR_MIN = 36;
// constexpr uint16_t EEPROM_ADDR_QTR_MAX = 48;
// constexpr uint16_t LOG_ENTRIES       = 1200;   // 1200 * 8 B = 9.6 kB EEPROM

// // ---------- ENUMS ----------
// enum Mode : uint8_t { LINE_FOLLOW, REMOTE, SERVO };
// enum MotorSide : uint8_t { LEFT, RIGHT };

// // ---------- GLOBALS ----------
// Mode mode = LINE_FOLLOW;
// bool teleEnabled = true;
// uint32_t lastTele = 0;
// float kpLine = 1.2f, kiLine = 0.001f, kdLine = 0.05f;
// float setpointLine = 0.0f;
// uint16_t qtr[6], qtrMin[6], qtrMax[6];
// bool qtrCalibrated = true;
// float baseSpeed = 0.6f;
// float leftDist = 0, rightDist = 0;
// float lineErr = 0.0f, lineCorr = 0.0f;  // for telemetry
// float currentPos = 0;

// // ---------- UTILS ----------
// inline void led(bool s) { digitalWrite(CAL_LED, s); }
// inline void beep(uint8_t n) {
//     for (uint8_t i = 0; i < n; i++) {
//         tone(BUZZER, 2200, 40);
//         delay(60);
//     }
// }

// // ---------- REMOTE CONTROL STRUCT ----------
// struct RemoteControl {
//     float throttle = 0;
//     float turn = 0;
// } remote;

// // ---------- FUNCTIONS DECLARATIONS ----------
// float linePID(float pos);

// // ---------- MOTOR STRUCT ----------
// struct Motor {
//     const uint8_t forwardPin, backwardPin, encA, encB;
//     volatile long ticks = 0;
//     volatile long historyTicks = 0;
//     float targetRPM = 0, filtRPM = 0;
//     float kp = 0.9f, ki = 2.2f, kd = 0.0f, errI = 0, prevErr = 0;
//     int16_t pwm = 0;
//     float diamCorr = 1.0f;
//     float dist = 0.0f;  // accumulated distance in cm
//     float speed = 0.0f; // current speed in cm/s
//     MotorSide side;
//     static constexpr float iwLimit = 500.0f; // anti-windup: max integral (ajusta)
//     static constexpr float ALPHA = 0.2f;
//     static bool servoActive;
//     static float servoTgtDist, servoTgtVel;
//     static int32_t servoStartTicksL, servoStartTicksR;
//     Motor(MotorSide s, const uint8_t forwardPin, const uint8_t backwardPin, const uint8_t ea, const uint8_t eb) : forwardPin(forwardPin), backwardPin(backwardPin), encA(ea), encB(eb), side(s) {}
//     void isr() {
//         int dir = (digitalRead(encB) == digitalRead(encA)) ? 1 : -1;
//         ticks += dir;
//         historyTicks += 1;
//     }
//     void update(float dt);
//     void setRPM(float r) {
//          targetRPM = constrain(r, -300, 300);
//     }
// };

// Motor leftMotor(LEFT, MOT_L_FORWARD, MOT_L_BACKWARD, ENC_LA, ENC_LB);
// Motor rightMotor(RIGHT, MOT_R_FORWARD, MOT_R_BACKWARD, ENC_RA, ENC_RB);

// bool Motor::servoActive = false;
// float Motor::servoTgtDist = 0, Motor::servoTgtVel = 0;
// int32_t Motor::servoStartTicksL = 0, Motor::servoStartTicksR = 0;
// // ---------- BUFFER SERIE ----------
// #define SER_BUF 128
// char serBuf[SER_BUF];
// uint8_t serHead = 0;



// // ---------- EEPROM ----------
// template<typename T> void eepWrite(int addr, T &obj) { EEPROM.put(addr, obj); }
// template<typename T> void eepRead (int addr, T &obj) { EEPROM.get(addr, obj); }

// // ---------- MOTOR UPDATE ----------
// void Motor::update(float dt) {
//     /* ---------- 1. Lectura y filtro de velocidad ---------- */
//     int32_t delta = ticks;
//     ticks = 0;
//     float rpm = (delta * 60.0f) / (CPR * dt) * diamCorr;
//     filtRPM = ALPHA * rpm + (1 - ALPHA) * filtRPM;


//     /* ---------- 4. Acumular distancia ---------- */
//     dist += filtRPM * dt * CM_PER_REV / 60.0f;  // cm

//     /* ---------- 5. Calcular velocidad ---------- */
//     speed = filtRPM * CM_PER_REV / 60.0f;  // cm/s

//     if (side == LEFT) {
//         switch (mode) {
//             case LINE_FOLLOW: {
//                 float steer = linePID(currentPos);
//                 lineErr = setpointLine - currentPos;
//                 lineCorr = steer;
//                 leftMotor.pwm = baseSpeed * 255.0f - steer;
//                 rightMotor.pwm = baseSpeed * 255.0f + steer;
//                 break;
//             }
//             case REMOTE: {
//                 if (remote.throttle != 0 || remote.turn != 0) {
//                     float base = remote.throttle * baseSpeed * 255.0f;
//                     float steer = remote.turn * baseSpeed * 255.0f;
//                     leftMotor.pwm = base - steer;
//                     rightMotor.pwm = base + steer;
//                 } else {
//                     leftMotor.pwm = 0;
//                     rightMotor.pwm = 0;
//                 }
//                 break;
//             }
//             case SERVO: {
//                 if (Motor::servoActive) {
//                     float doneL = (leftMotor.ticks - Motor::servoStartTicksL) * CM_PER_TICK;
//                     float doneR = (rightMotor.ticks - Motor::servoStartTicksR) * CM_PER_TICK;
//                     float done = (doneL + doneR) / 2;
//                     float err = Motor::servoTgtDist - done;
//                     if (err <= 0) {
//                         Motor::servoActive = false;
//                         leftMotor.setRPM(0);
//                         rightMotor.setRPM(0);
//                         beep(1);
//                         break;
//                     }
//                     float vel = constrain(err * 2, 0, Motor::servoTgtVel);
//                     leftMotor.pwm = vel * 255.0f / 60.0f;
//                     rightMotor.pwm = vel * 255.0f / 60.0f;
//                 } else {
//                     leftMotor.pwm = 0;
//                     rightMotor.pwm = 0;
//                 }
//                 break;
//             }
//         }
//     }

//     /* ---------- 6. Aplicar PWM ---------- */
//     if (pwm >= 0) {
//         digitalWrite(backwardPin, LOW);
//         analogWrite(forwardPin, pwm);
//     } else {
//         digitalWrite(forwardPin, LOW);
//         analogWrite(backwardPin, -pwm);
//     }

// }
// // ---------- QTR ----------
// /* ----------
//  *  Lee los 6 sensores reflectivos QTR-1A (o compatibles).
//  *  Secuencia:
//  *    1. Enciende el LED infrarrojo de iluminación.
//  *    2. Espera 200 µs para que la luz y el ADC se estabilicen.
//  *    3. Lee cada canal analógico (0-1023) y lo convierte a
//  *       rango 0-1000 si ya se ha calibrado.
//  *    4. Apaga el LED para ahorrar energía y reducir ruido.
//  *
//  *  Salida: array global qtr[6]
//  *    0   = superficie muy reflectiva (blanco)
//  *    1000= superficie poco reflectiva (negro)
//  */
// void readQTR()
// {
//     /* 1. Encendemos el LED que ilumina el suelo con IR */
//     digitalWrite(QTR_LED, HIGH);

//     /* 2. Pausa corta para que la luz se estabilice y los
//      *    fototransistores respondan (≈ 200 µs es suficiente) */
//     delayMicroseconds(200);

//     /* 3. Leemos los 6 canales analógicos ---------------------- */
//     for (uint8_t i = 0; i < 6; i++)
//     {
//         /* Lectura cruda del ADC (0-1023) */
//         uint16_t v = analogRead(QTR_PINS[i]);

//         /* Si ya calibramos, escalamos el valor al rango 0-1000
//          * qtrMin[i] = mínimo visto (más negro)
//          * qtrMax[i] = máximo visto (más blanco)
//          * constrain evita valores fuera de rango por si acaso */
//         if (qtrCalibrated)
//             v = map(constrain(v, qtrMin[i], qtrMax[i]),
//                     qtrMin[i], qtrMax[i], 0, 1000);

//         /* Guardamos el resultado en el array global */
//         qtr[i] = v;
//     }

//     /* 4. Apagamos el LED para ahorrar energía y reducir
//      *    interferencias con otros sensores cercanos */
//     digitalWrite(QTR_LED, LOW);
// }

// /* ----------------
//   *  Convierte los 6 valores de los sensores QTR (0-1000) en una ÚNICA coordenada
//   *  que indica dónde está el CENTRO de la línea negra respecto al centro físico
//   *  del robot.
//   *
//   *  Valor devuelto:
//   *    -2500  -> línea muy a la IZQUIERDA (sensor 0)
//   *       0   -> línea en el CENTRO (entre sensores 2 y 3)
//   *    +2500  -> línea muy a la DERECHA  (sensor 5)
//   *
//   *  Método: centro de masa ponderada (más negro = más peso).
//   */
// float computeLinePos()
// {
//     float sum = 0.0f;   // Suma ponderada de posiciones
//     float wt = 0.0f;    // Suma de pesos

//     /* Recorremos los 6 sensores ------------------------------------------- */
//     for (uint8_t i = 0; i < 6; i++)
//     {
//         float w = qtr[i];  // Peso proporcional a lo negro detectado
//         wt += w;
//         float pos = i * 1000.0f - 2500.0f;  // Posición del sensor
//         sum += w * pos;
//         // Serial.println("Sensor :" + String(i) + " = " + String(w) + " pos = " + String(pos) + " sum = " + String(sum) + " wt = " + String(wt));
//     }

//     /* Evitamos división por cero (todos los sensores en blanco) */
//     if (wt == 0.0f) return 0.0f;

//     /* Centro de masa */
//     return sum / wt;
// }

// // ---------- KALMAN ----------
// /* kalmanLine()
//  * ------------
//  *  Filtro de Kalman de 1ª orden: suaviza la señal de
//  *  computeLinePos() sin reducir el ancho de banda de forma
//  *  drástica. Ideal para quitar ruido de baja amplitud
//  *  producido por imperfecciones del suelo o reflejos.
//  *
//  *  Variables:
//  *    x  : estimación actual (la devuelve)
//  *    P  : incertidumbre de la estimación (covarianza)
//  *    z  : medida (computeLinePos)
//  *    R  : ruido del sensor (30)  – ajustable
//  *    Q  : ruido del modelo (2)   – ajustable
//  *
//  *  Paso a paso:
//  *    1. Predicción: x se mantiene, P crece Q
//  *    2. Actualización: se corrige con la medida z
//  *  Retorno: posición filtrada (misma escala que z)
//  */
// float kalmanLine()
// {
//     /* Estado y covarianza: conservados entre llamadas */
//     static float x = 0.0f;   // posición estimada (filtrada)
//     static float P = 1.0f;   // incertidumbre

//     /* 1. Lectura de la medida (ruidoso) */
//     float z = computeLinePos();

//     /* 2. Ganancia de Kalman K = P / (P + R) */
//     float R = 30.0f;         // varianza del sensor (confianza en z)
//     float Q = 2.0f;          // varianza del modelo (confianza en x)
//     float y = z - x;         // innovación (error de medida)
//     float S = P + R;         // covarianza del error
//     float K = P / S;         // ganancia (0-1)

//     /* 3. Actualización del estado */
//     x = x + K * y;           // corrección proporcional a la innovación

//     /* 4. Actualización de la covarianza */
//     P = (1.0f - K) * P + Q;  // reduce incertidumbre pero añade Q

//     /* 5. Devolvemos la estimación filtrada */
//     return x;
// }

// // ---------- LINE PID ----------
// /* linePID(float pos)
//  * ------------------
//  *  PID discreto para el seguimiento de línea.
//  *  Entrada: posición de la línea (devuelta por kalmanLine() u otro filtro).
//  *  Salida: corrección en PWM que se sumará/restará a los motores.
//  *
//  *  setpointLine = 0  (línea centrada); se puede cambiar para curvas
//  *  LOOP_HZ = 100  =>  dt = 0.01 s
//  *
//  *  Constantes (ajustables por EEPROM o serial):
//  *    kpLine  -> fuerza proporcional (0.08)
//  *    kiLine  -> fuerza integral     (0.0)
//  *    kdLine  -> fuerza derivativa   (0.008)
//  *
//  *  Variables internas (conservadas):
//  *    prev  -> error anterior (para derivada)
//  *    integ -> suma acumulada de errores (integral)
//  */
// float linePID(float pos)
// {
//     static float prev = 0, integ = 0;
//     /* 1. Error actual: diferencia entre punto deseado y medido */
//     float err = setpointLine - pos;          // setpointLine suele ser 0

//     /* 2. Parte integral: acumula el error con anti-windup */
//     integ += err;                            // dt está implícito en kiLine
//     integ = constrain(integ, -1000.0f, 1000.0f); // limita integral

//     /* 3. Parte derivada: velocidad de cambio del error
//      *    Como dt = 1/LOOP_HZ, multiplicamos directamente por LOOP_HZ */
//     float deriv = (err - prev) * LOOP_HZ;   // (error_now - error_prev) / dt
//     prev = err;                             // guardamos para la próxima vuelta

//     /* 4. Salida PID: corrección en PWM (se resta/suma a cada motor) */
//     return kpLine * err + kiLine * integ + kdLine * deriv;
// }

// float readLine(); 

// void sendTele() {
//     // readLine(); 
//     // Distancia total
//     float totalDist = (leftMotor.dist + rightMotor.dist) / 2.0f;

//     // Enviar JSON
//     JsonDocument doc;
//     doc["type"] = "telemetry";
//     JsonObject payload = doc["payload"].to<JsonObject>();
//     payload["timestamp"] = millis();
//     payload["mode"] = mode;
//     payload["velocity"] = (leftMotor.speed + rightMotor.speed) / 2.0f;
//     payload["acceleration"] = 0.0f; // Placeholder
//     payload["distance"] = totalDist;
//     payload["battery"] = 0.0f;

//     JsonObject leftObj = payload["leftMotor"].to<JsonObject>();
//     leftObj["vel"] = leftMotor.speed;
//     leftObj["acc"] = 0.0f;
//     leftObj["rpm"] = leftMotor.filtRPM;
//     leftObj["distance"] = leftMotor.dist;
//     leftObj["pwm"] = leftMotor.pwm;

//     JsonObject rightObj = payload["rightMotor"].to<JsonObject>();
//     rightObj["vel"] = rightMotor.speed;
//     rightObj["acc"] = 0.0f;
//     rightObj["rpm"] = rightMotor.filtRPM;
//     rightObj["distance"] = rightMotor.dist;
//     rightObj["pwm"] = rightMotor.pwm;

//     JsonArray qtrArray = payload["qtr"].to<JsonArray>();
//     for (int i = 0; i < 6; i++) qtrArray.add(qtr[i]);

//     JsonArray pidArray = payload["pid"].to<JsonArray>();
//     pidArray.add(kpLine);
//     pidArray.add(kiLine);
//     pidArray.add(kdLine);

//     payload["set_point"] = setpointLine;
//     payload["base_speed"] = baseSpeed;
//     payload["error"] = lineErr;
//     payload["correction"] = lineCorr;

//     serializeJson(doc, Serial);
//     Serial.println();
// }


// // ---------- FUNCTIONS DECLARATIONS ----------
// void calibrateQTR();
// void motorWrite(int, int);
// void handleRemote();

// // ---------- AUTO-TUNE ----------
// void tuneLine() {
//     beep(2);
//     kpLine = 0; kiLine = 0; kdLine = 0;
//     float Ku = 0, Pu = 0.8f;
//     float steer = 0;
//     for (Ku = 0.1f; Ku < 5; Ku += 0.1f) {
//         kpLine = Ku;
//         for (uint16_t t = 0; t < 100; t++) {
//             readQTR();
//             steer = linePID(kalmanLine()); // steer in PWM
//             leftMotor.pwm = 255 - steer;
//             rightMotor.pwm = 255 + steer;
//             leftMotor.update(DT);
//             rightMotor.update(DT);
//             delay(10);
//         }
//         if (abs(steer) > 50) break;
//     }
//     kpLine = 0.6f * Ku;
//     kiLine = 2 * kpLine / Pu;
//     kdLine = kpLine * Pu / 8;
//     eepWrite(EEPROM_ADDR_BASE + 20, kpLine);
//     eepWrite(EEPROM_ADDR_BASE + 24, kiLine);
//     eepWrite(EEPROM_ADDR_BASE + 28, kdLine);
//     beep(3);
// }

// // ---------- JSON PARSER ----------
// void execCmd(const char *json) {
//     // Send received command as telemetry
//     JsonDocument cmdDoc;
//     cmdDoc["type"] = "cmd";
//     cmdDoc["payload"]["buffer"] = json;
//     serializeJson(cmdDoc, Serial);
//     Serial.println();

//     JsonDocument doc;
//     if (deserializeJson(doc, json)) return;

//     if (doc["mode"].is<int>()) {
//         mode = (Mode)doc["mode"].as<int>();
//         if (mode == LINE_FOLLOW) calibrateQTR();
//     }

//     if (doc["pid"].is<JsonArray>()) {
//         JsonArray arr = doc["pid"];
//         kpLine = arr[0];
//         kiLine = arr[1];
//         kdLine = arr[2];
//     }

//     if (doc["base_speed"].is<float>()) baseSpeed = doc["base_speed"];

//     if (doc["setpoint"].is<float>()) setpointLine = doc["setpoint"];

//     if (doc["eeprom"].is<int>()) {
//       EEPROM.put(EEPROM_ADDR_BASE + 20, kpLine);
//       EEPROM.put(EEPROM_ADDR_BASE + 24, kiLine);
//       EEPROM.put(EEPROM_ADDR_BASE + 28, kdLine);
//       EEPROM.put(EEPROM_ADDR_BASE + 12, baseSpeed);
//     }

//     if (doc["tele"].is<int>()) {
//       int teleCmd = doc["tele"];
//       if (teleCmd == 2) {  // get once
//         sendTele();
//       } else if (teleCmd == 1) {  // on
//         teleEnabled = true;
//       } else if (teleCmd == 0) {  // off
//         teleEnabled = false;
//       }
//     }

//     if (doc["qtr"].is<int>()) {
//       calibrateQTR();
//     }

//     if (doc["factory_reset"].is<int>()) {
//       // Reset motor PID
//       leftMotor.kp = 0.9f;
//       leftMotor.ki = 2.2f;
//       leftMotor.kd = 0.0f;
//       rightMotor.kp = leftMotor.kp;
//       rightMotor.ki = leftMotor.ki;
//       rightMotor.kd = leftMotor.kd;
//       eepWrite(EEPROM_ADDR_BASE, leftMotor.kp);
//       eepWrite(EEPROM_ADDR_BASE + 4, leftMotor.ki);
//       eepWrite(EEPROM_ADDR_BASE + 8, leftMotor.kd);
//       // Reset line PID
//       kpLine = 0.2f;
//       kiLine = 0.001f;
//       kdLine = 0.05f;
//       eepWrite(EEPROM_ADDR_BASE + 20, kpLine);
//       eepWrite(EEPROM_ADDR_BASE + 24, kiLine);
//       eepWrite(EEPROM_ADDR_BASE + 28, kdLine);
//       // Reset baseSpeed
//       baseSpeed = 0.6f;
//       eepWrite(EEPROM_ADDR_BASE + 12, baseSpeed);
//       // Reset diamCorr
//       rightMotor.diamCorr = 1.0f;
//       eepWrite(EEPROM_ADDR_DIAM, rightMotor.diamCorr);
//       // Reset QTR
//       for (uint8_t i = 0; i < 6; i++) {
//         qtrMin[i] = 0;
//         qtrMax[i] = 0;
//       }
//       eepWrite(EEPROM_ADDR_QTR_MIN, qtrMin);
//       eepWrite(EEPROM_ADDR_QTR_MAX, qtrMax);
//       qtrCalibrated = false;
//       beep(3);
//    }

//    if (doc["reset"].is<int>()) {
//        // Software reset using watchdog
//        wdt_enable(WDTO_15MS);
//        while (1) {} // Wait for reset
//    }

//    if (doc["servo"].is<JsonObject>()) {
//       JsonObject servoObj = doc["servo"];
//       if (servoObj["distance"].is<float>()) {
//         float distance = servoObj["distance"];
//         float angle = servoObj["angle"].is<float>() ? servoObj["angle"] : 0;
//         Motor::servoActive = true;
//         Motor::servoTgtDist = distance;
//         Motor::servoTgtVel = angle;
//         Motor::servoStartTicksL = leftMotor.ticks;
//         Motor::servoStartTicksR = rightMotor.ticks;
//         mode = SERVO;
//       }
//     }

//     if (doc["rc"].is<JsonObject>()) {
//       JsonObject rc = doc["rc"];
//       // Reset only throttle and turn
//       remote.throttle = 0;
//       remote.turn = 0;

//       if (rc["throttle"].is<float>()) remote.throttle = rc["throttle"];
//       if (rc["turn"].is<float>()) remote.turn = rc["turn"];
//       mode = REMOTE;
//     }
// }

// // ---------- SERIE ----------
// void serialEvent() {
//     while (Serial.available()) {
//         char c = (char)Serial.read();
//         if (c == '\n') {
//             serBuf[serHead] = 0;
//             execCmd(serBuf);
//             serHead = 0;
//         } else {
//             serBuf[serHead++] = c;
//             if (serHead >= SER_BUF - 1) serHead = 0;
//         }
//     }
// }


// // ---------- SETUP ----------
// void setup() {
//     Serial.begin(9600);
//     analogReference(INTERNAL);
//     pinMode(MOT_L_FORWARD, OUTPUT);
//     pinMode(MOT_L_BACKWARD, OUTPUT);
//     pinMode(MOT_R_FORWARD, OUTPUT);
//     pinMode(MOT_R_BACKWARD, OUTPUT);
//     pinMode(QTR_LED, OUTPUT);
//     pinMode(CAL_LED, OUTPUT);
//     pinMode(BUZZER, OUTPUT);
//     for (uint8_t i = 0; i < 6; i++) pinMode(QTR_PINS[i], INPUT);
//     pinMode(ENC_LA, INPUT_PULLUP);
//     pinMode(ENC_LB, INPUT_PULLUP);
//     pinMode(ENC_RA, INPUT_PULLUP);
//     pinMode(ENC_RB, INPUT_PULLUP);
//     attachInterrupt(digitalPinToInterrupt(ENC_LA), []{leftMotor.isr();}, RISING);
//     attachInterrupt(digitalPinToInterrupt(ENC_RA), []{rightMotor.isr();}, RISING);

//     // Cargar valores desde EEPROM
//     eepRead(EEPROM_ADDR_BASE, leftMotor.kp);
//     eepRead(EEPROM_ADDR_BASE + 4, leftMotor.ki);
//     eepRead(EEPROM_ADDR_BASE + 8, leftMotor.kd);
//     eepRead(EEPROM_ADDR_BASE + 12, baseSpeed);
//     rightMotor.kp = leftMotor.kp;
//     rightMotor.ki = leftMotor.ki;
//     rightMotor.kd = leftMotor.kd;
//     eepRead(EEPROM_ADDR_BASE + 20, kpLine);
//     eepRead(EEPROM_ADDR_BASE + 24, kiLine);
//     eepRead(EEPROM_ADDR_BASE + 28, kdLine);
//     eepRead(EEPROM_ADDR_DIAM, rightMotor.diamCorr);

//     // Cargar calibración QTR
//     eepRead(EEPROM_ADDR_QTR_MIN, qtrMin);
//     eepRead(EEPROM_ADDR_QTR_MAX, qtrMax);
//     bool qtrValid = true;
//     for (uint8_t i = 0; i < 6; i++) {
//         if (qtrMin[i] >= qtrMax[i] || qtrMin[i] > 1023 || qtrMax[i] > 1023 || (qtrMin[i] == 0 && qtrMax[i] == 0)) qtrValid = false;
//     }
//     if (qtrValid) {
//         qtrCalibrated = true;
//     } else {
//         if (mode == LINE_FOLLOW) calibrateQTR();
//     }

//     // Validar diamCorr
//     if (isnan(rightMotor.diamCorr) || rightMotor.diamCorr <= 0) rightMotor.diamCorr = 1.0f;
//     // Validar valores leídos de EEPROM
//     if (leftMotor.kp <= 0 || isnan(leftMotor.kp)) leftMotor.kp = 0.9f;
//     if (leftMotor.ki < 0 || isnan(leftMotor.ki)) leftMotor.ki = 2.2f;
//     if (leftMotor.kd < 0 || isnan(leftMotor.kd)) leftMotor.kd = 0.0f;
//     if (baseSpeed <= 0 || baseSpeed > 1 || isnan(baseSpeed)) baseSpeed = 0.8f;
//     if (kpLine < 0 || isnan(kpLine) || kpLine > 5.0f) kpLine = 0.08f;
//     if (kiLine < 0 || isnan(kiLine) || kiLine > 5.0f) kiLine = 0.0f;
//     if (kdLine < 0 || isnan(kdLine) || kdLine > 1.0f) kdLine = 0.008f;
//     rightMotor.kp = leftMotor.kp;
//     rightMotor.ki = leftMotor.ki;
//     rightMotor.kd = leftMotor.kd;

//     calibrateQTR();

//     Timer1.initialize(10000);
//     Timer1.attachInterrupt([]{ leftMotor.update(DT); rightMotor.update(DT); });
//     beep(1);
// }

// float readLine() { 
//     float currentPos = 0.0f;
//     // lod on QTR
//     digitalWrite(QTR_LED, HIGH);
//     delay(10);
//     for (uint8_t i = 0; i < 6; i++) {
//       currentPos += (float)analogRead(QTR_PINS[i]);
//       Serial.println("Sensor :" + String(i) + " = " + String(analogRead(QTR_PINS[i])));
//     };
//     delay(10);
//     digitalWrite(QTR_LED, LOW);
//     return currentPos / 6.0f;
// }

// // ---------- LOOP ----------
// void loop() {
//     static uint32_t t0 = 0;
//     if (micros() - t0 >= 10000) { //10000
//         t0 = micros();
//         readQTR();
//         currentPos = computeLinePos();
//         if (teleEnabled && millis() - lastTele >= 500) { lastTele = millis(); sendTele(); }
//     }
//     serialEvent(); // Procesar comandos seriales
// }

// // ---------- AUX ----------
// void motorWrite(int l, int r) {
//     leftMotor.pwm = l * 255.0f / 60.0f;
//     rightMotor.pwm = r * 255.0f / 60.0f;
// }

// void handleRemote() {
//     if (remote.throttle != 0 || remote.turn != 0) {
//         float base = remote.throttle * baseSpeed * 255.0f;
//         float steer = remote.turn * baseSpeed * 255.0f;
//         leftMotor.pwm = base - steer;
//         rightMotor.pwm = base + steer;
//     } else {
//         // Detener motores si no hay comandos
//         leftMotor.pwm = 0;
//         rightMotor.pwm = 0;
//     }
// }

// void calibrateQTR() {
//     led(HIGH);
//     for (uint8_t j = 0; j < 6; j++) {
//         qtrMin[j] = 1023;
//         qtrMax[j] = 0;
//     }
//     for (uint16_t i = 0; i < 400; i++) {
//         readQTR();
//         for (uint8_t j = 0; j < 6; j++) {
//             if (qtr[j] < qtrMin[j]) qtrMin[j] = qtr[j];
//             if (qtr[j] > qtrMax[j]) qtrMax[j] = qtr[j];
//         }
//         delay(5);
//     }
//     qtrCalibrated = true;
//     eepWrite(EEPROM_ADDR_QTR_MIN, qtrMin);
//     eepWrite(EEPROM_ADDR_QTR_MAX, qtrMax);
//     led(LOW);
// }
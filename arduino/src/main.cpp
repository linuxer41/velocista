/*
 * Seguidor de Línea - Triple PID (Optimizado, Compatible con PlatformIO)
 * - Optimizado: Programador de intervalo fijo (menos jitter)
 * - Optimizado: Reducción de punto flotante en la lectura del sensor
 */

#include <Arduino.h>

// ----------------------------- CONFIGURACIÓN --------------------------------------
bool debugEnabled = false;   // activar/desactivar impresiones Serial
bool cascadeEnabled = false; // activar/desactivar cascada PID

enum Command {
    CALIBRATE = 1,
    SET_PWM = 2,
    SET_RPM = 3,
    SET_LINE_PID = 4,
    SET_RIGHT_PID = 5,
    SET_LEFT_PID = 6,
    SET_DEBUG = 7,
    SET_CASCADE = 8,
    SET_MODE = 9
};

enum OperationMode {
    IDLE,
    LINE_FOLLOWER
};

constexpr uint8_t ML1 = 10;
constexpr uint8_t ML2 = 9;
constexpr uint8_t MR1 = 6;
constexpr uint8_t MR2 = 5;

constexpr uint8_t SENSOR_COUNT = 8;
constexpr uint8_t SENSOR_PINS[SENSOR_COUNT] = {A0,A1,A2,A3,A4,A5,A6,A7};
constexpr uint8_t SENSOR_LED_PIN = 12;

constexpr uint8_t ENC_L_A = 2;
constexpr uint8_t ENC_L_B = 7; 
constexpr uint8_t ENC_R_A = 3;
constexpr uint8_t ENC_R_B = 4;

constexpr uint8_t STATUS_LED = 13;
constexpr uint8_t START_BUTTON = 8;

constexpr int PPR = 36;  // pulsos por revolución (encoder)
// diametro de ruedas
constexpr float DiamCm = 2.0f;

// Ajusta estos valores a tu robot
constexpr float BASE_PWM = 150.0f;   // base PWM para modo no cascada
constexpr int PWM_MAX = 255;
constexpr float BASE_RPM = 120.0f;  // RPM base para cascada y modo IDLE
constexpr float MAX_RPM = 1900.0f;

// conversión PWM a RPM (ajústala con pruebas)
// constexpr float RPM_PER_PWM = 8.0f;   // 1 PWM aprox. 8 RPM

// Tasas de bucle en microsegundos (para el nuevo programador fijo)
constexpr uint32_t LINE_SAMPLE_RATE_US = 10000;   // 10 ms
constexpr uint32_t ENCODER_SAMPLE_RATE_US = 5000;  // 5 ms
constexpr uint32_t DEBUG_SAMPLE_RATE_US = 100000; // 100 ms

// Constantes PID (ajustadas con Ziegler-Nichols: Ku=0.5, Tu=0.5s)
float LKp = 0.51f, LKi = 0.00f, LKd = 1.12f;  // PID de línea (produce offset PWM)
float MKp_L = 0.55f, MKi_L = 0.0014f, MKd_L = 0.015f; // PID de velocidad izquierda
float MKp_R = 0.55f, MKi_R = 0.0014f, MKd_R = 0.015f; // PID de velocidad derecha

// Parámetros de calibración/lectura
constexpr int CALIB_CYCLES = 500;
constexpr int SENSOR_MIN_SPAN = 40; // si max-min < esto -> sensor inválido

// Limites del integrador (previene windup)
constexpr float LINE_INT_CLAMP = 3000.0f;
constexpr float VEL_INT_CLAMP = 2000.0f;

// Centro de posición
constexpr int LINE_CENTER = 0;

// ------------------------- ESTADO GLOBAL ------------------------------------
volatile int32_t encL = 0;
volatile int32_t encR = 0;

float currentRpmL = 0.0f, currentRpmR = 0.0f;
float targetRpmL = 0.0f, targetRpmR = 0.0f;
float pwmL = 0.0f, pwmR = 0.0f;
float lineOut = 0.0f;

OperationMode currentMode = IDLE;
volatile bool lastButtonState = HIGH;

int minSensor[SENSOR_COUNT];
int maxSensor[SENSOR_COUNT];
float gainSensor[SENSOR_COUNT];
bool sensorValid[SENSOR_COUNT];
bool calibrated = false;

const int weights[SENSOR_COUNT] = {-3500,-2500,-1500,-500,500,1500,2500,3500};

// estado PID de línea
float lineErr = 0.0f, lineInt = 0.0f, linePrev = 0.0f;

// estado PID de velocidad
float rpmErrL = 0.0f, velPrevL = 0.0f, velIntL = 0.0f;
float rpmErrR = 0.0f, velPrevR = 0.0f, velIntR = 0.0f;

// timing
uint32_t lastLoopTime = 0;
uint32_t lastDebugTime = 0;
uint32_t lastRPMTime = 0;

float currentPos = 0.0f;

constexpr uint32_t DEBOUNCE_US = 50000; // 50 ms
static uint32_t lastButtonChange = 0;
static bool buttonState = HIGH;         // estado filtrado

// ------------------------- DECLARACIONES DE FUNCIONES -------------------------
void isrLeftA();
void isrRightA();
void initHardware();
void calibrateSensors();
int readLinePosWeighted(bool debug = false);
float pidLine(float reference, float error);
float pidSpeedL(float reference, float error);
float pidSpeedR(float reference, float error);
void setMotorsPWM(float leftPWM, float rightPWM);
void resetPIDAndSpeeds();

// ----------------------------- INTERRUPCIONES ----------------------------------
void isrLeftA() { encL++; }
void isrRightA() { encR++; }

ISR(PCINT0_vect) {
    uint32_t now = micros();
    bool raw = digitalRead(START_BUTTON);

    if ((now - lastButtonChange) > DEBOUNCE_US) {
        if (raw != buttonState) {
            buttonState = raw;
            if (buttonState == LOW) {          // flanco descendente
                currentMode = (currentMode == IDLE) ? LINE_FOLLOWER : IDLE;
                if (currentMode == LINE_FOLLOWER && !calibrated) {
                    calibrateSensors();
                }
                resetPIDAndSpeeds();
                digitalWrite(STATUS_LED, currentMode == IDLE ? HIGH : LOW);
            }
        }
    }
    lastButtonChange = now;
}

// ----------------------------- SETUP ---------------------------------------
void setup() {
    Serial.begin(115200);
    delay(50);
    Serial.println("Inicio del seguidor de línea (optimizado)");
    initHardware();
    calibrateSensors();
    digitalWrite(STATUS_LED, currentMode == IDLE ? HIGH : LOW);

    lastLoopTime = micros();
    lastDebugTime = micros();
    lastRPMTime = micros();
}

// ------------------------------ LOOP ---------------------------------------
void loop() {
    uint32_t now = micros();

    // Procesar comandos seriales
    if (Serial.available()) {
        bool succes = false;
        int cmd = Serial.parseInt();
        switch (cmd) {
            case CALIBRATE:
                calibrateSensors();
                digitalWrite(STATUS_LED, currentMode == IDLE ? HIGH : LOW);
                succes = true;
                break;
            case SET_DEBUG:
                debugEnabled = Serial.parseInt();
                succes = true;
                break;
            case SET_CASCADE:
                cascadeEnabled = Serial.parseInt();
                succes = true;
                break;
            case SET_LINE_PID:
                LKp = Serial.parseFloat();
                LKi = Serial.parseFloat();
                LKd = Serial.parseFloat();
                succes = true;
                break;
            case SET_RIGHT_PID:
                MKp_R = Serial.parseFloat();
                MKi_R = Serial.parseFloat();
                MKd_R = Serial.parseFloat();
                succes = true;
                break;
            case SET_LEFT_PID:
                MKp_L = Serial.parseFloat();
                MKi_L = Serial.parseFloat();
                MKd_L = Serial.parseFloat();
                succes = true;
                break;
            case SET_PWM:
                {
                    float l = Serial.parseFloat();
                    float r = Serial.parseFloat();
                    if (l != 0 && r != 0) {
                        pwmL = l;
                        pwmR = r;
                        succes = true;
                    } else {
                        succes = false;
                    }
                }
                break;
            case SET_RPM:
                {
                    float rl = Serial.parseFloat();
                    float rr = Serial.parseFloat();
                    targetRpmL = rl;
                    targetRpmR = rr;
                    succes = true;
                }
                break;
            case SET_MODE:
                currentMode = (OperationMode)Serial.parseInt();
                if (currentMode == LINE_FOLLOWER && !calibrated) {
                    calibrateSensors();
                }
                resetPIDAndSpeeds();
                digitalWrite(STATUS_LED, currentMode == IDLE ? HIGH : LOW);
                succes = true;
                break;
            default:
                break;
        }
        if (succes) {
            Serial.print("OK ");
            Serial.println(cmd);
        }
    }

    // Calcular RPMs cada 5 ms
    if (now - lastRPMTime >= ENCODER_SAMPLE_RATE_US) {
        uint32_t dt = now - lastRPMTime;
        if (dt == 0) return;
        lastRPMTime = now;

        static int32_t prevL = 0, prevR = 0;
        noInterrupts();
        int32_t dl = encL - prevL;
        int32_t dr = encR - prevR;
        prevL = encL;
        prevR = encR;
        interrupts();

        currentRpmL = (dl * 60000000.0f / (float)PPR) / (float)dt;
        currentRpmR = (dr * 60000000.0f / (float)PPR) / (float)dt;
    }

    // ------- Control de motores -------
    switch (currentMode) {
    case IDLE:
        if (now - lastLoopTime >= LINE_SAMPLE_RATE_US) {
            lastLoopTime = now;
            currentPos = (float)readLinePosWeighted();
        }
        if (targetRpmL != 0 || targetRpmR != 0) {
            rpmErrL = targetRpmL - currentRpmL;
            rpmErrR = targetRpmR - currentRpmR;
            float pidOutL = pidSpeedL(targetRpmL, rpmErrL);
            float pidOutR = pidSpeedR(targetRpmR, rpmErrR);
            pwmL = BASE_PWM + pidOutL;   // PWM = PWM + PID
            pwmR = BASE_PWM + pidOutR;
        }
        break;

    case LINE_FOLLOWER:
        if (now - lastLoopTime >= LINE_SAMPLE_RATE_US) {
            lastLoopTime = now;
            currentPos = (float)readLinePosWeighted();
            lineErr = LINE_CENTER - currentPos;
            lineOut = pidLine(LINE_CENTER, lineErr);

            if (cascadeEnabled) {
                // Usa cascade control para obtener PWM
                float rpmOffset = lineOut;
                targetRpmL = BASE_RPM + rpmOffset;
                targetRpmR = BASE_RPM - rpmOffset;

                rpmErrL = targetRpmL - currentRpmL;
                rpmErrR = targetRpmR - currentRpmR;

                float pidOutL = pidSpeedL(targetRpmL, rpmErrL);
                float pidOutR = pidSpeedR(targetRpmR, rpmErrR);

                pwmL = BASE_PWM + pidOutL;   // PWM = PWM + PID
                pwmR = BASE_PWM + pidOutR;
            } else {
                // Modo no-cascada: PWM directo
                pwmL = BASE_PWM + lineOut;
                pwmR = BASE_PWM - lineOut;
            }

            // Saturación intermedia
            pwmL = constrain(pwmL, -PWM_MAX, PWM_MAX);
            pwmR = constrain(pwmR, -PWM_MAX, PWM_MAX);
        }
        break;

    default:
        pwmL = 0;
        pwmR = 0;
        break;
    }

    setMotorsPWM(pwmL, pwmR);

    // Debug cada 100 ms
    if (now - lastDebugTime >= DEBUG_SAMPLE_RATE_US) {
        lastDebugTime = now;
        if (debugEnabled) {
            String msg = String(now) + "," + String(currentPos) + "," +
                         String(currentRpmL) + "," + String(currentRpmR) + "," +
                         String(lineOut) + "," + String(pwmL) + "," + String(pwmR);
            Serial.println(msg);
        }
    }
}

// --------------------------- INICIALIZACIÓN DE HARDWARE ---------------------------------
void initHardware() {
    pinMode(ML1, OUTPUT);
    pinMode(ML2, OUTPUT);
    pinMode(MR1, OUTPUT);
    pinMode(MR2, OUTPUT);

    pinMode(SENSOR_LED_PIN, OUTPUT);
    digitalWrite(SENSOR_LED_PIN, HIGH);

    pinMode(ENC_L_A, INPUT_PULLUP);
    pinMode(ENC_R_A, INPUT_PULLUP);
    pinMode(START_BUTTON, INPUT_PULLUP);
    pinMode(STATUS_LED, OUTPUT);

    attachInterrupt(digitalPinToInterrupt(ENC_L_A), isrLeftA, RISING);
    attachInterrupt(digitalPinToInterrupt(ENC_R_A), isrRightA, RISING);

    // Enable pin change interrupt for START_BUTTON (pin 8, PCINT0)
    PCICR |= (1 << PCIE0);
    PCMSK0 |= (1 << PCINT0);

    for (int i = 0; i < SENSOR_COUNT; ++i) {
        minSensor[i] = 1023;
        maxSensor[i] = 0;
        gainSensor[i] = 0.0f;
        sensorValid[i] = false;
    }

    // ensure PWM pins start at 0
    analogWrite(ML1, 0);
    analogWrite(ML2, 0);
    analogWrite(MR1, 0);
    analogWrite(MR2, 0);

    // Set PWM frequency to ~8kHz for quieter motor operation (Timer 1 and Timer 0)
    // TCCR1B = (TCCR1B & 0xF8) | 0x01; // Timer 1 prescaler 1
    // TCCR0B = (TCCR0B & 0xF8) | 0x01; // Timer 0 prescaler 1

    // Optimize ADC for faster sensor readings (prescaler 16)
    ADCSRA = (ADCSRA & 0xF8) | 0x04; // Set ADC prescaler to 16 for ~77kHz sampling
}

// --------------------------- CALIBRACIÓN DE SENSORES -----------------------------
void calibrateSensors() {
    digitalWrite(STATUS_LED, HIGH);
    Serial.println("Calibrando sensores...");

    for (int k = 0; k < CALIB_CYCLES; ++k) {
        for (int i = 0; i < SENSOR_COUNT; ++i) {
            int v = analogRead(SENSOR_PINS[i]);
            if (v < minSensor[i]) minSensor[i] = v;
            if (v > maxSensor[i]) maxSensor[i] = v;
        }
        if (k % 50 == 0) {
            digitalWrite(STATUS_LED, !digitalRead(STATUS_LED));
        }
        delay(10);
    }

    for (int i = 0; i < SENSOR_COUNT; ++i) {
        int span = maxSensor[i] - minSensor[i];
        if (span < SENSOR_MIN_SPAN) {
            sensorValid[i] = false;
            gainSensor[i] = 0.0f;
        } else {
            sensorValid[i] = true;
            gainSensor[i] = 1000.0f / (float)span;
        }
    }

    digitalWrite(STATUS_LED, LOW);
    // impmire valores maximos y minimos
    for (int i = 0; i < SENSOR_COUNT; ++i) {
        Serial.print("Sensor ");
        Serial.print(i);
        Serial.print(" min: ");
        Serial.print(minSensor[i]);
        Serial.print(" max: ");
        Serial.print(maxSensor[i]);
        Serial.print(" gain: ");
        Serial.println(gainSensor[i]);
    }
    Serial.println("Sensores calibrados.");
    calibrated = true;
}

// ----------------------- LEER POSICIÓN DE LÍNEA (ponderada) ---------------------
int readLinePosWeighted(bool debug) {
    long weightedSum = 0;
    long sum = 0;
    if (debug) Serial.print("Lecturas: ");

    for (int i = 0; i < SENSOR_COUNT; ++i) {
        int raw = analogRead(SENSOR_PINS[i]);
        if (!sensorValid[i]) continue;

        if (debug) {
            Serial.print(raw);
            Serial.print(" ");
        }

        int val = (int)(((float)raw - (float)minSensor[i]) * gainSensor[i] + 0.5f);
        if (debug) {
            Serial.print(val);
            Serial.print(" ");
        }

        if (val < 0) val = 0;
        else if (val > 1000) val = 1000;

        weightedSum += (long)val * (long)weights[i];
        sum += val;
    }

    if (sum == 0) return 0;
    int pos = (int)(weightedSum / sum);
    if (debug) {
        Serial.print("Pos: ");
        Serial.println(pos);
    }
    return pos;
}

// ------------------------------- PID DE LÍNEA ----------------------------------
float pidLine(float reference, float error) {
    lineErr = error;
    float der = lineErr - linePrev;
    lineInt += lineErr;

    if (lineInt > LINE_INT_CLAMP) lineInt = LINE_INT_CLAMP;
    else if (lineInt < -LINE_INT_CLAMP) lineInt = -LINE_INT_CLAMP;

    float out = LKp * lineErr + LKi * lineInt + LKd * der;
    linePrev = lineErr;
    return out;
}

// --------------------------- PID VELOCIDAD IZQUIERDA --------------------------------
float pidSpeedL(float reference, float error) {
    rpmErrL = error;
    float der = rpmErrL - velPrevL;
    velIntL += rpmErrL;

    if (velIntL > VEL_INT_CLAMP) velIntL = VEL_INT_CLAMP;
    else if (velIntL < -VEL_INT_CLAMP) velIntL = -VEL_INT_CLAMP;

    float out = MKp_L * rpmErrL + MKi_L * velIntL + MKd_L * der;
    velPrevL = rpmErrL;
    return out;
}

// --------------------------- PID VELOCIDAD DERECHA -------------------------------
float pidSpeedR(float reference, float error) {
    rpmErrR = error;
    float der = rpmErrR - velPrevR;
    velIntR += rpmErrR;

    if (velIntR > VEL_INT_CLAMP) velIntR = VEL_INT_CLAMP;
    else if (velIntR < -VEL_INT_CLAMP) velIntR = -VEL_INT_CLAMP;

    float out = MKp_R * rpmErrR + MKi_R * velIntR + MKd_R * der;
    velPrevR = rpmErrR;
    return out;
}

// ----------------------------- CONTROL DE MOTORES -------------------------------
void setMotorsPWM(float leftPWM, float rightPWM) {
    leftPWM = constrain(leftPWM, -PWM_MAX, PWM_MAX);
    rightPWM = constrain(rightPWM, -PWM_MAX, PWM_MAX);

    if (leftPWM >= 0) {
        analogWrite(ML1, leftPWM);
        analogWrite(ML2, 0);
    } else {
        analogWrite(ML1, 0);
        analogWrite(ML2, -leftPWM);
    }

    if (rightPWM >= 0) {
        analogWrite(MR1, rightPWM);
        analogWrite(MR2, 0);
    } else {
        analogWrite(MR1, 0);
        analogWrite(MR2, -rightPWM);
    }
}

void resetPIDAndSpeeds() {
    // reset speeds
    currentRpmL = 0.0f;
    currentRpmR = 0.0f;
    targetRpmL = 0.0f;
    targetRpmR = 0.0f;
    pwmL = 0.0f;
    pwmR = 0.0f;
    lineOut = 0.0f;

    // reset PID line
    lineErr = 0.0f;
    lineInt = 0.0f;
    linePrev = 0.0f;

    // reset PID speed L
    rpmErrL = 0.0f;
    velPrevL = 0.0f;
    velIntL = 0.0f;

    // reset PID speed R
    rpmErrR = 0.0f;
    velPrevR = 0.0f;
    velIntR = 0.0f;

    currentPos = 0.0f;
}
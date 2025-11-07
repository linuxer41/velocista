#include <PinChangeInterrupt.h>
#include <ArduinoJson.h>
#include <DRV8833.h>
#include <EEPROM.h>
#include <SoftwareSerial.h>

using namespace motor;

// Pines para sensores QTR (6 sensores analógicos de posición 2-7)
const uint8_t QTR_PINS[6] = {14, 15, 16, 17, 18, 19}; // A0(14), A1(15), A2(16), A3(17), A4(18), A5(19)
const uint8_t QTR_IR_PIN = 13; // Pin para controlar el LED IR de los sensores QTR

// Pines para motores DRV8833
const uint8_t MOTOR_LEFT_IN1 = 5;   // Motor izquierdo IN1 (D5)
const uint8_t MOTOR_LEFT_IN2 = 6;   // Motor izquierdo IN2 (D6)
const uint8_t MOTOR_RIGHT_IN1 = 9;  // Motor derecho IN1 (D9)
const uint8_t MOTOR_RIGHT_IN2 = 10; // Motor derecho IN2 (D10)

// Pines para encoders (mix de interrupciones reales y PinChangeInterrupt)
const uint8_t ENC_LEFT_A = 2;   // Encoder izquierdo canal A (interrupción real INT0)
const uint8_t ENC_LEFT_B = 4;   // Encoder izquierdo canal B (para dirección)
const uint8_t ENC_RIGHT_A = 3;  // Encoder derecho canal A (PinChangeInterrupt)
const uint8_t ENC_RIGHT_B = 8;  // Encoder derecho canal B (para dirección)

// Variables de encoders
volatile int16_t countLeft = 0;
volatile int16_t countRight = 0;

// Configuración de encoders
float wheelCircumference = 21.0; // Circunferencia de la rueda en cm (ajustar según tu rueda)
int encoderCPR = 90; // Pulsos por revolución del encoder (ajustar según especificaciones)

// Configuración Bluetooth HC-06 (usar SoftwareSerial en pines diferentes)
const uint8_t BLUETOOTH_RX_PIN = 12; // HC-06 TX -> Arduino pin 12
const uint8_t BLUETOOTH_TX_PIN = 11; // HC-06 RX -> Arduino pin 11
SoftwareSerial bluetoothSerial(BLUETOOTH_RX_PIN, BLUETOOTH_TX_PIN);

// Controlador PID
struct PIDController {
    float Kp = 1.0;
    float Ki = 0.0;
    float Kd = 0.0;
    float setpoint = 2500; // Centro de la línea (0-5000 para 6 sensores)
    float integral = 0;
    float previous_error = 0;
    unsigned long last_time = 0;
};

// Enumeración de modos de operación
enum class OperationMode {
    LINE_FOLLOWING = 0,
    AUTOPILOT = 1,
    MANUAL = 2
};

// Variables globales
PIDController pid;
DRV8833 motorLeft(MOTOR_LEFT_IN1, MOTOR_LEFT_IN2, MOTOR_RIGHT_IN1, MOTOR_RIGHT_IN2, DecayMode::Slow);
DRV8833 motorRight(MOTOR_LEFT_IN1, MOTOR_LEFT_IN2, MOTOR_RIGHT_IN1, MOTOR_RIGHT_IN2, DecayMode::Slow);
uint16_t sensorValues[6]; // Solo 6 sensores (posiciones 2-7 del QTR-8A)
float baseSpeed = 0.8f; // Velocidad base de los motores (0-1 para bipolar)

// Variables para cálculo de velocidad y distancia
unsigned long lastCalculationTime = 0;
float leftSpeed = 0.0; // cm/s
float rightSpeed = 0.0; // cm/s
float totalDistance = 0.0; // cm

// Variables de modo de operación
OperationMode currentMode = OperationMode::LINE_FOLLOWING;

// Variables para modo autopilot (tricycle)
float autopilotThrottle = 0.0f;   // -1.0 (retroceso) a 1.0 (acelerar máximo)
float autopilotBrake = 0.0f;      // 0.0 (sin freno) a 1.0 (freno máximo)
float autopilotTurn = 0.0f;       // -1.0 (girar izquierda) a 1.0 (girar derecha)
float autopilotDirection = 1.0f;  // 1.0 (adelante) o -1.0 (atrás) para dirección de marcha

// Variables para modo manual
float manualLeftSpeed = 0.0f;  // -1.0 a 1.0 para motor izquierdo
float manualRightSpeed = 0.0f; // -1.0 a 1.0 para motor derecho
float manualMaxSpeed = 1.0f;   // Velocidad máxima para modo manual

// Variables para monitoreo de conexión Bluetooth
unsigned long lastBluetoothActivity = 0;
bool bluetoothConnected = false;
int bluetoothErrorCount = 0;
const unsigned long BLUETOOTH_TIMEOUT = 10000; // 10 segundos sin actividad = desconectado

// EEPROM addresses for persistent storage
const int EEPROM_ADDR_CONFIG = 0;
const int EEPROM_MAGIC_NUMBER = 0x1234;

// Structure to store configuration in EEPROM
struct ConfigData {
    int magic;           // Magic number to validate data
    float Kp;            // PID proportional gain
    float Ki;            // PID integral gain  
    float Kd;            // PID derivative gain
    float setpoint;      // Line following setpoint
    float baseSpeed;     // Base speed for line following
    int operationMode;   // Default operation mode
    float wheelCirc;     // Wheel circumference
    int encoderCPR;      // Encoder counts per revolution
};

// Functions to save/load configuration to/from EEPROM
void saveConfigToEEPROM() {
    ConfigData config;
    config.magic = EEPROM_MAGIC_NUMBER;
    config.Kp = pid.Kp;
    config.Ki = pid.Ki;
    config.Kd = pid.Kd;
    config.setpoint = pid.setpoint;
    config.baseSpeed = baseSpeed;
    config.operationMode = static_cast<int>(currentMode);
    config.wheelCirc = wheelCircumference;
    config.encoderCPR = encoderCPR;
    
    // Write structure to EEPROM
    EEPROM.put(EEPROM_ADDR_CONFIG, config);
    bluetoothSerial.println("{\"status\":\"config_saved\",\"message\":\"Configuration saved to EEPROM\"}");
}

bool loadConfigFromEEPROM() {
    ConfigData config;
    EEPROM.get(EEPROM_ADDR_CONFIG, config);
    
    // Validate magic number
    if (config.magic == EEPROM_MAGIC_NUMBER) {
        pid.Kp = config.Kp;
        pid.Ki = config.Ki;
        pid.Kd = config.Kd;
        pid.setpoint = config.setpoint;
        baseSpeed = config.baseSpeed;
        currentMode = static_cast<OperationMode>(config.operationMode);
        wheelCircumference = config.wheelCirc;
        encoderCPR = config.encoderCPR;
        
        bluetoothSerial.println("{\"status\":\"config_loaded\",\"message\":\"Configuration loaded from EEPROM\"}");
        return true;
    } else {
        bluetoothSerial.println("{\"status\":\"config_default\",\"message\":\"Using default configuration\"}");
        return false;
    }
}

// Function to reset configuration to defaults
void resetConfigToDefaults() {
    pid.Kp = 1.0f;
    pid.Ki = 0.0f;
    pid.Kd = 0.0f;
    pid.setpoint = 2500.0f;
    baseSpeed = 0.8f;
    currentMode = OperationMode::LINE_FOLLOWING;
    wheelCircumference = 21.0f;
    encoderCPR = 90;
    
    bluetoothSerial.println("{\"status\":\"config_reset\",\"message\":\"Configuration reset to defaults\"}");
}

// Función para obtener memoria libre aproximada (estimación simple)
int freeMemory() {
    return 2048; // Arduino Nano tiene ~2KB de RAM, estimación básica
}

// Función para verificar estado de conexión Bluetooth
void checkBluetoothStatus() {
    unsigned long currentTime = millis();
    
    // Si hay actividad reciente, la conexión está activa
    if (bluetoothSerial.available() > 0 || (currentTime - lastBluetoothActivity) < BLUETOOTH_TIMEOUT) {
        bluetoothConnected = true;
    } else {
        bluetoothConnected = false;
    }
}

// Función para manejar errores de parsing JSON
void handleCommandError(const String& errorMessage) {
    bluetoothErrorCount++;
    bluetoothSerial.println("{\"status\":\"error\",\"message\":\"" + errorMessage + "\",\"errorCount\":" + String(bluetoothErrorCount) + "}");
    
    // Si hay demasiados errores, reiniciar contadores
    if (bluetoothErrorCount > 10) {
        bluetoothErrorCount = 0;
        bluetoothSerial.println("{\"status\":\"warning\",\"message\":\"Error count reset due to high error rate\"}");
    }
}


// Funciones de interrupción para encoders
void leftEncoderISR() {
    bool b = digitalRead(ENC_LEFT_B);
    countLeft += b ? 1 : -1;
}

void rightEncoderISR() {
    bool b = digitalRead(ENC_RIGHT_B);
    countRight += b ? 1 : -1;
}

// Función para leer sensores QTR con control IR profesional
void readQTRSensors() {
    // Encender LED IR
    digitalWrite(QTR_IR_PIN, HIGH);
    delayMicroseconds(100); // Tiempo para que el LED se estabilice

    // Leer los 6 sensores (posiciones 2-7 del QTR-8A)
    for (int i = 0; i < 6; i++) {
        sensorValues[i] = analogRead(QTR_PINS[i]);
    }

    // Apagar LED IR
    digitalWrite(QTR_IR_PIN, LOW);
}

// Función para calcular la posición de la línea
float calculateLinePosition() {
    uint32_t weightedSum = 0;
    uint16_t totalSum = 0;

    // Usar sensores en posiciones 2-7 (índices 0-5 en nuestro array)
    for (int i = 0; i < 6; i++) {
        // Calcular posición real (2-7) * 1000 para mantener la escala
        weightedSum += (uint32_t)sensorValues[i] * (i + 2) * 1000;
        totalSum += sensorValues[i];
    }

    if (totalSum == 0) return -1; // Línea no detectada

    return (float)weightedSum / totalSum;
}

// Función PID
float computePID(float position) {
    unsigned long current_time = millis();
    float dt = (current_time - pid.last_time) / 1000.0;
    pid.last_time = current_time;

    if (dt == 0) return 0;

    float error = pid.setpoint - position;
    pid.integral += error * dt;
    float derivative = (error - pid.previous_error) / dt;
    pid.previous_error = error;

    return pid.Kp * error + pid.Ki * pid.integral + pid.Kd * derivative;
}

// Función para calcular velocidad en cm/s
void calculateSpeeds() {
    static int16_t lastCountLeft = 0;
    static int16_t lastCountRight = 0;
    static unsigned long lastTime = 0;
    
    unsigned long currentTime = millis();
    float dt = (currentTime - lastTime) / 1000.0; // tiempo en segundos
    
    if (dt > 0) {
        // Calcular velocidad izquierda
        int16_t deltaLeft = countLeft - lastCountLeft;
        leftSpeed = (deltaLeft * wheelCircumference) / (encoderCPR * dt);
        
        // Calcular velocidad derecha
        int16_t deltaRight = countRight - lastCountRight;
        rightSpeed = (deltaRight * wheelCircumference) / (encoderCPR * dt);
        
        // Actualizar distancia total
        totalDistance += abs(deltaLeft + deltaRight) * wheelCircumference / (2 * encoderCPR);
        
        // Actualizar contadores
        lastCountLeft = countLeft;
        lastCountRight = countRight;
        lastTime = currentTime;
    }
}

// Funciones de control de motores para diferentes modos
void controlMotorsLineFollowing(float correction) {
    float leftSpeed = baseSpeed - correction;
    float rightSpeed = baseSpeed + correction;

    // Limitar velocidades a rango bipolar (-1 a 1)
    leftSpeed = constrain(leftSpeed, -1.0f, 1.0f);
    rightSpeed = constrain(rightSpeed, -1.0f, 1.0f);

    // Aplicar velocidades a motores usando bridges
    motorLeft.getBridgeA().setSpeedBipolar(leftSpeed);
    motorRight.getBridgeA().setSpeedBipolar(rightSpeed);
}

void controlMotorsAutopilot() {
    // Control para triciclo: 2 ruedas traseras motorizadas, 1 rueda delantera para dirección
    // El giro se hace diferencial entre las ruedas traseras
    
    float throttle = autopilotThrottle;    // -1.0 a 1.0 (retroceso a avance)
    float brake = autopilotBrake;          // 0.0 a 1.0 (sin freno a freno total)
    float turn = autopilotTurn;            // -1.0 a 1.0 (izquierda a derecha)
    float direction = autopilotDirection;  // 1.0 (adelante) o -1.0 (atrás)
    
    // Velocidad base de las ruedas traseras
    float baseSpeed = throttle * direction;
    
    // Aplicar freno (reduce la velocidad actual)
    if (brake > 0.0f) {
        baseSpeed = baseSpeed * (1.0f - brake);
    }
    
    // Control diferencial para giro
    // Girar izquierda (turn negativo): rueda izquierda más lenta
    // Girar derecha (turn positivo): rueda derecha más lenta
    float turnEffect = 0.5f; // Intensidad del giro diferencial
    float leftSpeed = baseSpeed - (turn * turnEffect);
    float rightSpeed = baseSpeed + (turn * turnEffect);
    
    // Limitar velocidades a rango bipolar (-1 a 1)
    leftSpeed = constrain(leftSpeed, -1.0f, 1.0f);
    rightSpeed = constrain(rightSpeed, -1.0f, 1.0f);
    
    // Aplicar velocidades a motores traseros
    motorLeft.getBridgeA().setSpeedBipolar(leftSpeed);
    motorRight.getBridgeA().setSpeedBipolar(rightSpeed);
}

void controlMotorsManual() {
    // Modo manual: control directo de cada rueda
    float leftSpeed = manualLeftSpeed * manualMaxSpeed;
    float rightSpeed = manualRightSpeed * manualMaxSpeed;
    
    // Limitar velocidades a rango bipolar (-1 a 1)
    leftSpeed = constrain(leftSpeed, -1.0f, 1.0f);
    rightSpeed = constrain(rightSpeed, -1.0f, 1.0f);
    
    // Aplicar velocidades a motores
    motorLeft.getBridgeA().setSpeedBipolar(leftSpeed);
    motorRight.getBridgeA().setSpeedBipolar(rightSpeed);
}

// Control de motores según modo de operación
void controlMotors(float correction) {
    switch (currentMode) {
        case OperationMode::LINE_FOLLOWING:
            controlMotorsLineFollowing(correction);
            break;
        case OperationMode::AUTOPILOT:
            controlMotorsAutopilot();
            break;
        case OperationMode::MANUAL:
            controlMotorsManual();
            break;
    }
}

// Configurar Bluetooth HC-06 (SoftwareSerial)
void setupBluetooth() {
    bluetoothSerial.begin(9600);
    delay(1000);
    
    // Configurar PIN
    bluetoothSerial.print("AT+PIN9876");
    delay(1000);
    
    // Configurar nombre
    bluetoothSerial.print("AT+NAMEVelocistaBot");
    delay(1000);
    
    Serial.println("Bluetooth HC-06 configured");
}

// Configurar pines
void setupPins() {
    // Configurar pines de sensores QTR como entrada
    for (int i = 0; i < 6; i++) {
        pinMode(QTR_PINS[i], INPUT);
    }

    // Configurar pin IR como salida
    pinMode(QTR_IR_PIN, OUTPUT);
    digitalWrite(QTR_IR_PIN, LOW); // Apagar LED IR inicialmente

    // Configurar pines de encoders como entrada
    pinMode(ENC_LEFT_A, INPUT);
    pinMode(ENC_LEFT_B, INPUT);
    pinMode(ENC_RIGHT_A, INPUT);
    pinMode(ENC_RIGHT_B, INPUT);

    // Configurar interrupciones para encoders
    // Motor izquierdo: interrupción real (INT0 en pin 2)
    attachInterrupt(digitalPinToInterrupt(ENC_LEFT_A), leftEncoderISR, RISING);
    // Motor derecho: PinChangeInterrupt (pin 3)
    attachPinChangeInterrupt(digitalPinToPinChangeInterrupt(ENC_RIGHT_A), rightEncoderISR, RISING);
}

void setup() {
    Serial.begin(9600); // Usar hardware serial (pines 0,1)
    setupBluetooth();
    setupPins();

    // Iniciar motores
    motorLeft.begin();
    motorRight.begin();

    // Inicializar variables de modo
    autopilotThrottle = 0.0f;
    autopilotBrake = 0.0f;
    autopilotTurn = 0.0f;
    autopilotDirection = 1.0f;  // Adelante por defecto
    manualLeftSpeed = 0.0f;
    manualRightSpeed = 0.0f;
    manualMaxSpeed = 1.0f;

    // Try to load configuration from EEPROM
    bool configLoaded = loadConfigFromEEPROM();
    if (!configLoaded) {
        // If no valid config in EEPROM, set defaults
        resetConfigToDefaults();
    }

    Serial.println("=== Bot de Velocista con 3 Modos de Operación ===");
    Serial.println("Modos disponibles:");
    Serial.println("  0 = Line Following (seguimiento de línea)");
    Serial.println("  1 = Autopilot (acelerador, freno, direccional)");
    Serial.println("  2 = Manual (control individual de ruedas)");
    Serial.println();
    Serial.println("Modo actual: Line Following (0)");
    Serial.println("Encoder monitoring enabled - Left: D2/D4, Right: D3/D8");
    Serial.println("Connect via Bluetooth to configure and monitor");
    Serial.println("Comandos JSON soportados:");
    Serial.println("  {\"mode\":0}, {\"mode\":1}, {\"mode\":2} - Cambiar modo");
    Serial.println("  {\"getMode\":true} - Obtener modo actual");
    Serial.println("  {\"getStatus\":true} - Obtener estado del sistema");
    Serial.println("  {\"throttle\":value, \"brake\":value, \"turn\":value, \"direction\":value} - Autopilot");
    Serial.println("  {\"emergencyStop\":true} - Parada de emergencia (Autopilot)");
    Serial.println("  {\"park\":true} - Estacionar vehículo (Autopilot)");
    Serial.println("  {\"stop\":true} - Parada normal (Autopilot)");
    Serial.println("  {\"leftSpeed\":value, \"rightSpeed\":value, \"maxSpeed\":value} - Manual");
    Serial.println("  {\"saveConfig\":true} - Guardar configuración en EEPROM");
    Serial.println("  {\"loadConfig\":true} - Cargar configuración desde EEPROM");
    Serial.println("  {\"resetConfig\":true} - Restaurar configuración por defecto");
    Serial.println("================================================");
    
    // Inicializar timestamp de actividad Bluetooth
    lastBluetoothActivity = millis();
}

void loop() {
    // Variables para telemetría
    float correction = 0.0f;
    float position = -1.0f;
    
    // Control según modo de operación
    switch (currentMode) {
        case OperationMode::LINE_FOLLOWING:
            readQTRSensors();
            position = calculateLinePosition();
            correction = computePID(position);
            controlMotorsLineFollowing(correction);
            break;
            
        case OperationMode::AUTOPILOT:
            controlMotorsAutopilot();
            break;
            
        case OperationMode::MANUAL:
            controlMotorsManual();
            break;
    }

    // Calcular velocidades de encoders
    calculateSpeeds();

    // Procesar comandos Bluetooth
    if (bluetoothSerial.available()) {
        String jsonCommand;
        while (bluetoothSerial.available()) {
            jsonCommand += (char)bluetoothSerial.read();
        }
        
        // Actualizar timestamp de actividad
        lastBluetoothActivity = millis();

        JsonDocument doc;
        if (!deserializeJson(doc, jsonCommand)) {
            // Comandos de configuración (auto-saved to EEPROM)
            if (!doc["Kp"].isNull()) {
                pid.Kp = doc["Kp"].as<float>();
                saveConfigToEEPROM();
            }
            if (!doc["Ki"].isNull()) {
                pid.Ki = doc["Ki"].as<float>();
                saveConfigToEEPROM();
            }
            if (!doc["Kd"].isNull()) {
                pid.Kd = doc["Kd"].as<float>();
                saveConfigToEEPROM();
            }
            if (!doc["setpoint"].isNull()) {
                pid.setpoint = doc["setpoint"].as<float>();
                saveConfigToEEPROM();
            }
            if (!doc["baseSpeed"].isNull()) {
                baseSpeed = doc["baseSpeed"].as<float>();
                saveConfigToEEPROM();
            }
            
            // Cambio de modo
            if (!doc["mode"].isNull()) {
                int mode = doc["mode"];
                if (mode == 0) currentMode = OperationMode::LINE_FOLLOWING;
                else if (mode == 1) currentMode = OperationMode::AUTOPILOT;
                else if (mode == 2) currentMode = OperationMode::MANUAL;
                // saveConfigToEEPROM(); // Save mode change
            }
            
            // Controles autopilot
            if (!doc["throttle"].isNull()) {
                float throttleValue = doc["throttle"].as<float>();
                autopilotThrottle = throttleValue;
                if (autopilotThrottle > 1.0f) autopilotThrottle = 1.0f;
                if (autopilotThrottle < -1.0f) autopilotThrottle = -1.0f;
            }
            if (!doc["brake"].isNull()) {
                float brakeValue = doc["brake"].as<float>();
                autopilotBrake = brakeValue;
                if (autopilotBrake > 1.0f) autopilotBrake = 1.0f;
                if (autopilotBrake < 0.0f) autopilotBrake = 0.0f;
            }
            if (!doc["turn"].isNull()) {
                float turnValue = doc["turn"].as<float>();
                autopilotTurn = turnValue;
                if (autopilotTurn > 1.0f) autopilotTurn = 1.0f;
                if (autopilotTurn < -1.0f) autopilotTurn = -1.0f;
            }
            if (!doc["direction"].isNull()) {
                int dirValue = doc["direction"].as<int>();
                autopilotDirection = (dirValue > 0) ? 1.0f : -1.0f;
            }
            
            // Comandos de parada y estacionamiento
            if (!doc["emergencyStop"].isNull()) {
                // Parada de emergencia: detiene todo inmediatamente
                autopilotThrottle = 0.0f;
                autopilotBrake = 1.0f;  // Freno total
                autopilotTurn = 0.0f;   // Dirección recta
                bluetoothSerial.println("{\"status\":\"emergency_stop\",\"message\":\"Parada de emergencia activada\"}");
            }
            if (!doc["park"].isNull()) {
                // Estacionamiento: para suavemente el vehículo
                autopilotThrottle = 0.0f;
                autopilotBrake = 1.0f;  // Freno total para estacionar
                autopilotTurn = 0.0f;   // Dirección recta
                autopilotDirection = 1.0f;  // Dirección adelante
                bluetoothSerial.println("{\"status\":\"parked\",\"message\":\"Vehículo estacionado\"}");
            }
            if (!doc["stop"].isNull()) {
                // Parada normal: reduce velocidad gradualmente
                autopilotThrottle = 0.0f;
                autopilotBrake = 0.8f;  // Freno suave
                autopilotTurn = 0.0f;   // Dirección recta
                bluetoothSerial.println("{\"status\":\"stopped\",\"message\":\"Vehículo detenido\"}");
            }
            
            // Controles manual
            if (!doc["leftSpeed"].isNull()) {
                float leftValue = doc["leftSpeed"].as<float>();
                manualLeftSpeed = leftValue;
                if (manualLeftSpeed > 1.0f) manualLeftSpeed = 1.0f;
                if (manualLeftSpeed < -1.0f) manualLeftSpeed = -1.0f;
            }
            if (!doc["rightSpeed"].isNull()) {
                float rightValue = doc["rightSpeed"].as<float>();
                manualRightSpeed = rightValue;
                if (manualRightSpeed > 1.0f) manualRightSpeed = 1.0f;
                if (manualRightSpeed < -1.0f) manualRightSpeed = -1.0f;
            }
            if (!doc["maxSpeed"].isNull()) {
                float maxValue = doc["maxSpeed"].as<float>();
                manualMaxSpeed = maxValue;
                if (manualMaxSpeed > 1.0f) manualMaxSpeed = 1.0f;
                if (manualMaxSpeed < 0.0f) manualMaxSpeed = 0.0f;
            }
            
            // Consulta de modo
            if (!doc["getMode"].isNull()) {
                JsonDocument response;
                response["currentMode"] = static_cast<int>(currentMode);
                response["modeName"] = (currentMode == OperationMode::LINE_FOLLOWING) ? "Line Following" :
                                     (currentMode == OperationMode::AUTOPILOT) ? "Autopilot" : "Manual";
                serializeJson(response, bluetoothSerial);
                bluetoothSerial.println();
            }
            
            // Consulta de estado Bluetooth
            if (!doc["getStatus"].isNull()) {
                JsonDocument response;
                response["bluetoothConnected"] = bluetoothConnected;
                response["errorCount"] = bluetoothErrorCount;
                response["uptime"] = millis();
                response["freeMemory"] = freeMemory();
                serializeJson(response, bluetoothSerial);
                bluetoothSerial.println();
            }
            
            // Comandos EEPROM
            if (!doc["saveConfig"].isNull()) {
                saveConfigToEEPROM();
            }
            if (!doc["loadConfig"].isNull()) {
                loadConfigFromEEPROM();
            }
            if (!doc["resetConfig"].isNull()) {
                resetConfigToDefaults();
            }
            
            bluetoothSerial.println("{\"status\":\"configured\"}");
        } else {
            bluetoothSerial.println("{\"status\":\"error\",\"message\":\"Invalid JSON\"}");
        }
    }

    // Enviar telemetría cada 100ms
    static unsigned long lastSendTime = 0;
    if (millis() - lastSendTime >= 100) {
        lastSendTime = millis();

        JsonDocument doc;
        doc["operationMode"] = static_cast<int>(currentMode);
        doc["modeName"] = (currentMode == OperationMode::LINE_FOLLOWING) ? "Line Following" :
                         (currentMode == OperationMode::AUTOPILOT) ? "Autopilot" : "Manual";
        
        // Datos específicos por modo
        switch (currentMode) {
            case OperationMode::LINE_FOLLOWING:
                doc["position"] = position;
                doc["error"] = pid.setpoint - position;
                doc["correction"] = correction;
                doc["leftSpeedCmd"] = baseSpeed - correction;
                doc["rightSpeedCmd"] = baseSpeed + correction;
                
                JsonArray sensors = doc["sensors"].to<JsonArray>();
                for (int i = 0; i < 6; i++) {
                    sensors.add(sensorValues[i]);
                }
                break;
                
            case OperationMode::AUTOPILOT:
                doc["throttle"] = autopilotThrottle;
                doc["brake"] = autopilotBrake;
                doc["turn"] = autopilotTurn;
                doc["direction"] = autopilotDirection;
                
                // Estado de parada/estacionamiento
                if (autopilotBrake >= 1.0f && autopilotThrottle == 0.0f && autopilotTurn == 0.0f) {
                    doc["parkingState"] = (autopilotBrake == 1.0f) ? "PARKED" : "STOPPED";
                } else {
                    doc["parkingState"] = "MOVING";
                }
                
                float baseThrottle = autopilotThrottle * autopilotDirection;
                if (autopilotBrake > 0.0f) {
                    baseThrottle *= (1.0f - autopilotBrake);
                }
                doc["leftSpeedCmd"] = baseThrottle - (autopilotTurn * 0.5f);
                doc["rightSpeedCmd"] = baseThrottle + (autopilotTurn * 0.5f);
                
                JsonArray emptySensors = doc["sensors"].to<JsonArray>();
                for (int i = 0; i < 6; i++) {
                    emptySensors.add(0);
                }
                break;
                
            case OperationMode::MANUAL:
                doc["leftSpeed"] = manualLeftSpeed * manualMaxSpeed;
                doc["rightSpeed"] = manualRightSpeed * manualMaxSpeed;
                doc["maxSpeed"] = manualMaxSpeed;
                doc["leftSpeedCmd"] = manualLeftSpeed * manualMaxSpeed;
                doc["rightSpeedCmd"] = manualRightSpeed * manualMaxSpeed;
                
                JsonArray emptySensors2 = doc["sensors"].to<JsonArray>();
                for (int i = 0; i < 6; i++) {
                    emptySensors2.add(0);
                }
                break;
        }
        
        // Datos de encoders (comunes)
        doc["leftEncoderSpeed"] = leftSpeed;
        doc["rightEncoderSpeed"] = rightSpeed;
        doc["leftEncoderCount"] = countLeft;
        doc["rightEncoderCount"] = countRight;
        doc["totalDistance"] = totalDistance;

        serializeJson(doc, bluetoothSerial);
        bluetoothSerial.println();
    }

    delay(10);
}


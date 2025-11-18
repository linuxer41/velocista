/**
 * ARCHIVO: robot_seguidor.ino
 * DESCRIPCIÓN: Archivo principal del robot seguidor de línea
 * FUNCIONALIDAD: Inicialización, loop principal, coordinación de módulos
 */

#include "config.h"
#include "motor_controller.h"
#include "encoder_controller.h"
#include "sensor_array.h"
#include "advanced_pid.h"
#include "odometry.h"
#include "eeprom_manager.h"
#include "intelligent_avoidance.h"
#include "competition_manager.h"
#include "remote_control.h"
#include "communication_handler.h"
#include "data_logger.h"
#include "mode_indicator.h"
#include "state_machine.h"

// =============================================================================
// INSTANCIAS GLOBALES
// =============================================================================

MotorController motorController;
EncoderController encoderController;
SensorArray sensorArray;
AdvancedPID linePID(DEFAULT_KP, DEFAULT_KI, DEFAULT_KD);
Odometry odometry;
EEPROMManager eepromManager;
IntelligentAvoidance obstacleAvoidance(odometry);
CompetitionManager competitionManager;
RemoteControl remoteControl;
CommunicationHandler commHandler(motorController, linePID, competitionManager, remoteControl);
DataLogger dataLogger;
ModeIndicator modeIndicator;
StateMachine stateMachine;

// Configuración global
RobotConfig currentConfig;

// Variables de timing
unsigned long lastOdometryUpdate = 0;
unsigned long lastTelemetry = 0;
unsigned long lastRemoteCheck = 0;
unsigned long lastModeUpdate = 0;
unsigned long lastSensorRead = 0;

// Flags de control
bool calibrationRequested = false;
bool sensorsEnabled = false;

// =============================================================================
// DECLARACIONES FORWARD
// =============================================================================

// Funciones de modos de operación
void executeRemoteControlMode();
void executeCompetitionMode();
void executeDebugMode();
void executeCalibrationMode();

// Funciones auxiliares
void updateCommonSystems();
void updateOdometry();
void executeIntelligentActions(int error, IntelligentAvoidance::AvoidanceAction action);
void executeStateActions(int error);
void followLineWithSpeed(int error, int speed);
void searchForLine();
void avoidObstacle();
void sendOptimizedTelemetry(OperationMode mode);
void performCalibration();

// Funciones de hardware
void setupUltrasonic();
float readDistance();

// =============================================================================
// INTERRUPCIONES ENCODERS
// =============================================================================

// Instancia global para acceso desde ISRs
EncoderController encoderController;

/**
 * Interrupción encoder izquierdo
 */
void encoderLeftISR() {
    encoderController.incrementLeft();
}

/**
 * Interrupción encoder derecho  
 */
void encoderRightISR() {
    encoderController.incrementRight();
}

// =============================================================================
// SETUP - INICIALIZACIÓN
// =============================================================================

void setup() {
    // 1. Inicializar comunicación serial
    Serial.begin(115200);
    delay(1000); // Esperar estabilización
    
    Serial.println("{\"type\":\"system\",\"message\":\"Inicializando Robot Seguidor de Línea Profesional\"}");
    Serial.println("{\"type\":\"system\",\"version\":\"4.0\",\"features\":\"PID_Avanzado,Odometría,Control_Remoto,EEPROM,Evasión_Inteligente\"}");

    // 2. Inicializar hardware
    motorController.initialize();
    encoderController.initialize();
    setupUltrasonic();

    // 3. Cargar configuración de EEPROM
    if (!eepromManager.loadConfig(currentConfig)) {
        eepromManager.initializeDefaultConfig(currentConfig);
        Serial.println("{\"type\":\"eeprom\",\"message\":\"Configuración por defecto cargada\"}");
    }

    // 4. Aplicar configuración cargada
    motorController.setBaseSpeed(currentConfig.baseSpeed);
    linePID.setGains(currentConfig.kp, currentConfig.ki, currentConfig.kd);
    sensorArray.calibrateFromConfig(currentConfig);
    remoteControl.setLimits(currentConfig.rcDeadzone, currentConfig.rcMaxThrottle, currentConfig.rcMaxSteering);

    // 5. Inicializar odometría con valores de EEPROM
    odometry = Odometry(currentConfig.wheelDiameter, currentConfig.wheelDistance);

    // 6. Configurar modo inicial
    competitionManager.setMode(MODE_DEBUG);
    modeIndicator.setMode(MODE_DEBUG);

    // 7. Mostrar configuración inicial
    eepromManager.printConfig(currentConfig);
    
    Serial.println("{\"type\":\"system\",\"message\":\"Inicialización completada - Robot listo\"}");
    Serial.println("{\"type\":\"system\",\"commands\":\"start, stop, set_pid, set_speed, set_mode, calibrate_sensors, get_status\"}");

    lastOdometryUpdate = millis();
    lastSensorRead = millis();
}

// =============================================================================
// LOOP PRINCIPAL
// =============================================================================

void loop() {
    unsigned long currentTime = millis();
    
    // 1. Actualizar indicador de modo (cada 100ms)
    if (currentTime - lastModeUpdate >= 100) {
        modeIndicator.setMode(competitionManager.getCurrentMode());
        modeIndicator.update();
        lastModeUpdate = currentTime;
    }
    
    // 2. Verificar y actualizar modo de operación
    competitionManager.checkMode();
    OperationMode currentMode = competitionManager.getCurrentMode();
    
    // 3. Procesar comandos seriales (si están habilitados)
    if (competitionManager.isSerialEnabled() && Serial.available()) {
        String command = Serial.readStringUntil('\n');
        command.trim();
        commHandler.processCommand(command);
    }
    
    // 4. Manejar calibración si fue solicitada
    if (calibrationRequested) {
        performCalibration();
        calibrationRequested = false;
    }
    
    // 5. Control de alimentación de sensores según modo
    bool shouldEnableSensors = (currentMode != MODE_REMOTE_CONTROL);
    if (sensorsEnabled != shouldEnableSensors) {
        sensorsEnabled = shouldEnableSensors;
        sensorArray.setPower(sensorsEnabled);
    }
    
    // 6. Ejecutar lógica principal según modo de operación
    switch (currentMode) {
        case MODE_REMOTE_CONTROL:
            executeRemoteControlMode();
            break;
        case MODE_COMPETITION:
            executeCompetitionMode();
            break;
        case MODE_DEBUG:
        case MODE_TUNING:
            executeDebugMode();
            break;
        case MODE_CALIBRATION:
            executeCalibrationMode();
            break;
    }
    
    // 7. Actualizaciones de sistemas comunes
    updateCommonSystems();
    
    // 8. Envío de telemetría
    sendOptimizedTelemetry(currentMode);
    
    // 9. Pequeño delay para estabilidad
    delay(10);
}

// =============================================================================
// IMPLEMENTACIÓN MODOS DE OPERACIÓN
// =============================================================================

/**
 * Modo Control Remoto - control manual vía JSON
 */
void executeRemoteControlMode() {
    // Verificar conexión del control remoto
    if (millis() - lastRemoteCheck > 500) {
        remoteControl.checkConnection();
        lastRemoteCheck = millis();
    }
    
    // Aplicar velocidades del control remoto
    if (remoteControl.isConnected()) {
        motorController.tankDrive(remoteControl.getLeftSpeed(), remoteControl.getRightSpeed());
    } else {
        // Timeout - detener motores
        motorController.stopAll();
    }
    
    // Leer sensores para feedback visual (pero no para control)
    if (millis() - lastSensorRead >= 50) {
        sensorArray.readLinePosition();
        lastSensorRead = millis();
    }
}

/**
 * Modo Competencia - máxima performance, telemetría mínima
 */
void executeCompetitionMode() {
    // Leer sensores cada 20ms para respuesta rápida
    if (millis() - lastSensorRead >= 20) {
        int error = sensorArray.readLinePosition();
        int sensorSum = sensorArray.getSensorSum();
        
        // Detección de obstáculos
        float distance = readDistance();
        IntelligentAvoidance::AvoidanceAction avoidanceAction = 
            obstacleAvoidance.evaluateObstacle(distance, motorController.getBaseSpeed());
        
        // Actualizar máquina de estados
        bool criticalObstacle = (avoidanceAction == IntelligentAvoidance::EMERGENCY_STOP);
        stateMachine.updateState(error, sensorSum, criticalObstacle, MODE_COMPETITION);
        
        // Ejecutar acciones
        executeIntelligentActions(error, avoidanceAction);
        
        lastSensorRead = millis();
    }
}

/**
 * Modo Debug/Tuning - funcionalidad completa con telemetría
 */
void executeDebugMode() {
    // Leer sensores cada 30ms
    if (millis() - lastSensorRead >= 30) {
        int error = sensorArray.readLinePosition();
        int sensorSum = sensorArray.getSensorSum();
        
        // Actualizar odometría
        updateOdometry();
        
        // Detección de obstáculos
        float distance = readDistance();
        IntelligentAvoidance::AvoidanceAction avoidanceAction = 
            obstacleAvoidance.evaluateObstacle(distance, motorController.getBaseSpeed());
        
        // Actualizar máquina de estados
        bool criticalObstacle = (avoidanceAction == IntelligentAvoidance::EMERGENCY_STOP);
        stateMachine.updateState(error, sensorSum, criticalObstacle, MODE_DEBUG);
        
        // Ejecutar acciones
        executeIntelligentActions(error, avoidanceAction);
        
        lastSensorRead = millis();
    }
}

/**
 * Modo Calibración - solo lectura de sensores
 */
void executeCalibrationMode() {
    motorController.stopAll();
    
    // Enviar datos de sensores cada 500ms
    if (millis() - lastSensorRead >= 500) {
        Serial.println(sensorArray.getSensorDataJSON());
        lastSensorRead = millis();
    }
}

// =============================================================================
// FUNCIONES AUXILIARES
// =============================================================================

/**
 * Realizar calibración automática de sensores
 */
void performCalibration() {
    Serial.println("{\"type\":\"calibration\",\"message\":\"Iniciando proceso de calibración automática...\"}");
    
    sensorArray.performAutoCalibration();
    
    // Guardar calibración en EEPROM
    sensorArray.saveCalibrationToConfig(currentConfig);
    if (eepromManager.saveConfig(currentConfig)) {
        Serial.println("{\"type\":\"calibration\",\"message\":\"Calibración guardada exitosamente en EEPROM\"}");
    } else {
        Serial.println("{\"type\":\"calibration\",\"message\":\"Error al guardar calibración en EEPROM\"}");
    }
}

/**
 * Actualizar sistemas comunes a todos los modos
 */
void updateCommonSystems() {
    // Actualizar velocidades de encoders
    encoderController.updateVelocities();
    
    // Actualizar odometría (excepto en modo calibración)
    if (competitionManager.getCurrentMode() != MODE_CALIBRATION) {
        updateOdometry();
    }
}

/**
 * Actualizar odometría del robot
 */
void updateOdometry() {
    unsigned long currentTime = millis();
    if (currentTime - lastOdometryUpdate >= 50) { // 20Hz
        odometry.update(encoderController.getLeftCount(), 
                       encoderController.getRightCount(), 
                       currentTime - lastOdometryUpdate);
        lastOdometryUpdate = currentTime;
    }
}

/**
 * Ejecutar acciones considerando evasión de obstáculos
 */
void executeIntelligentActions(int error, IntelligentAvoidance::AvoidanceAction action) {
    switch (action) {
        case IntelligentAvoidance::EMERGENCY_STOP:
            motorController.stopAll();
            break;
        case IntelligentAvoidance::REVERSE:
            motorController.tankDrive(-100, -100);
            break;
        case IntelligentAvoidance::SLOW_DOWN:
            // Reducir velocidad base temporalmente
            followLineWithSpeed(error, motorController.getBaseSpeed() * 0.5);
            break;
        default:
            // Comportamiento normal según estado de la máquina de estados
            executeStateActions(error);
            break;
    }
}

/**
 * Ejecutar acciones según estado actual
 */
void executeStateActions(int error) {
    switch (stateMachine.getCurrentState()) {
        case STATE_FOLLOWING_LINE:
            followLineWithSpeed(error, motorController.getBaseSpeed());
            break;
        case STATE_SEARCHING_LINE:
            searchForLine();
            break;
        case STATE_STOPPED:
            motorController.stopAll();
            break;
        case STATE_TURNING_RIGHT:
            motorController.tankDrive(150, -150);
            break;
        case STATE_TURNING_LEFT:
            motorController.tankDrive(-150, 150);
            break;
        case STATE_SHARP_CURVE:
            followLineWithSpeed(error * 1.3, motorController.getBaseSpeed());
            break;
        case STATE_AVOIDING_OBSTACLE:
            avoidObstacle();
            break;
        case STATE_REMOTE_CONTROL:
            // Los motores se controlan desde executeRemoteControlMode
            break;
    }
}

/**
 * Seguir línea con control PID a velocidad específica
 */
void followLineWithSpeed(int error, int speed) {
    double correction = linePID.compute(error);
    int leftSpeed = speed + correction;
    int rightSpeed = speed - correction;
    motorController.tankDrive(leftSpeed, rightSpeed);
}

/**
 * Buscar línea perdida
 */
void searchForLine() {
    int direction = stateMachine.getSearchDirection();
    motorController.tankDrive(120 * direction, -120 * direction);
}

/**
 * Ejecutar maniobra de evasión de obstáculos
 */
void avoidObstacle() {
    static int avoidPhase = 0;
    static unsigned long phaseStartTime = 0;
    
    if (millis() - phaseStartTime > 500) {
        avoidPhase++;
        phaseStartTime = millis();
    }
    
    switch (avoidPhase) {
        case 0: // Retroceder
            motorController.tankDrive(-150, -150);
            break;
        case 1: // Girar
            motorController.tankDrive(-150, 150);
            break;
        case 2: // Avanzar
            motorController.tankDrive(150, 150);
            break;
        default:
            avoidPhase = 0;
            break;
    }
}

/**
 * Enviar telemetría optimizada según modo
 */
void sendOptimizedTelemetry(OperationMode mode) {
    if (!competitionManager.isSerialEnabled()) return;
    
    unsigned long currentTime = millis();
    if (currentTime - lastTelemetry >= 200) { // 5Hz max
        switch (mode) {
            case MODE_REMOTE_CONTROL:
                Serial.println(remoteControl.getStatusJSON());
                break;
            case MODE_COMPETITION:
                // Telemetría mínima para competencia
                {
                    StaticJsonDocument<128> doc;
                    doc["t"] = currentTime;
                    doc["s"] = stateMachine.getStateString().substring(0,1);
                    doc["d"] = String(readDistance(), 1);
                    String jsonString;
                    serializeJson(doc, jsonString);
                    Serial.println(jsonString);
                }
                break;
            default:
                // Telemetría completa para debugging/tuning
                Serial.println(sensorArray.getSensorDataJSON());
                Serial.println(odometry.getPoseJSON());
                Serial.println(stateMachine.getStateJSON());
                Serial.println(modeIndicator.getStatusJSON());
                
                // Log de datos para análisis
                dataLogger.logData(
                    sensorArray.readLinePosition(), 
                    motorController.getBaseSpeed(), 
                    motorController.getBaseSpeed(),
                    encoderController.getLeftRPM(),
                    encoderController.getRightRPM(),
                    stateMachine.getStateString()
                );
                break;
        }
        lastTelemetry = currentTime;
    }
}

// =============================================================================
// FUNCIONES DE HARDWARE
// =============================================================================

/**
 * Inicializar sensor ultrasónico
 */
void setupUltrasonic() {
    pinMode(TRIG_PIN, OUTPUT);
    pinMode(ECHO_PIN, INPUT);
    digitalWrite(TRIG_PIN, LOW);
}

/**
 * Leer distancia con sensor ultrasónico
 * @return Distancia en cm, 0 si error
 */
float readDistance() {
    digitalWrite(TRIG_PIN, LOW);
    delayMicroseconds(2);
    digitalWrite(TRIG_PIN, HIGH);
    delayMicroseconds(10);
    digitalWrite(TRIG_PIN, LOW);
    
    long duration = pulseIn(ECHO_PIN, HIGH, 30000); // Timeout 30ms
    if (duration == 0) {
        return 0; // Timeout o error
    }
    
    return (duration * 0.0343) / 2.0;
}
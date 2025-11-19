/*********************************************************************
 *  robot_seguidor.ino  –  listo para usar con protocolo robusto
 *  (magic-byte 0xA5 + CRC-16 + ACK)
 *  Copiar-pegar y compilar
 *********************************************************************/

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
#include "mode_indicator.h"
#include "state_machine.h"
#include "models.h"
#include "ultrasonic_interrupt.h"

/* =======================  INSTANCIAS  ======================= */
MotorController        motorController;
EncoderController      encoderController;
SensorArray            sensorArray;
AdvancedPID            linePID(DEFAULT_KP, DEFAULT_KI, DEFAULT_KD);
Odometry               odometry;
EEPROMManager          eepromManager;
IntelligentAvoidance   obstacleAvoidance(odometry);
CompetitionManager     competitionManager;
RemoteControl          remoteControl;
ModeIndicator          modeIndicator;
StateMachine           stateMachine;
UltrasonicInterrupt    ultrasonicSensor;

RobotConfig            currentConfig;

/* ===================  TIMING  =================== */
unsigned long lastOdometryUpdate = 0;
unsigned long lastTelemetry      = 0;
unsigned long lastRemoteCheck    = 0;
unsigned long lastModeUpdate     = 0;
unsigned long lastSensorRead     = 0;

bool calibrationRequested = false;
bool sensorsEnabled       = false;

// Funciones de modos de operación
void executeRemoteControlMode();
void executeCompetitionMode();
void executeDebugMode();
void executeCalibrationMode();

// Funciones auxiliares
void performCalibration();
void updateCommonSystems();
void updateOdometry();
void executeIntelligentActions(int error, IntelligentAvoidance::AvoidanceAction action);
void executeStateActions(int error);
void followLineWithSpeed(int error, int speed);
void searchForLine();
void avoidObstacle();
void sendOptimizedTelemetry(OperationMode mode);
void triggerUltrasonicMeasurement();
float getUltrasonicDistance();
void encoderLeftISR();
void encoderRightISR();

/* ============================================================== */
/* --------------------  SETUP  --------------------------------- */
/* ============================================================== */

void setup()
{
    Serial.begin(9600);
    CommunicationSerializer::sendSystemMessage("Robot Seguidor 4.0 – PID, Odometria, Remoto, EEPROM, Evasion");
    CommunicationSerializer::sendSystemMessage("Comandos: start, stop, set_pid, set_speed, set_mode, calibrate_sensors, get_status");

    motorController.initialize();
    encoderController.initialize();
    ultrasonicSensor.initialize();

    if (!eepromManager.loadConfig(currentConfig))
    {
        eepromManager.initializeDefaultConfig(currentConfig);
    }

    motorController.setBaseSpeed(currentConfig.baseSpeed);
    linePID.setGains(currentConfig.kp, currentConfig.ki, currentConfig.kd);
    sensorArray.calibrateFromConfig(currentConfig);
    remoteControl.setLimits(currentConfig.rcDeadzone, currentConfig.rcMaxThrottle, currentConfig.rcMaxSteering);

    odometry = Odometry(currentConfig.wheelDiameter, currentConfig.wheelDistance);

    competitionManager.setMode(MODE_DEBUG);
    modeIndicator.setMode(MODE_DEBUG);
    CommunicationSerializer::sendModeChange(255, MODE_DEBUG, competitionManager.isSerialEnabled());

    lastOdometryUpdate = millis();
    lastSensorRead     = millis();
}

/* ============================================================== */
/* --------------------  LOOP  ---------------------------------- */
/* ============================================================== */

void loop()
{
    unsigned long t = millis();

    // /* 1. Indicador modo cada 100 ms */
    // if (t - lastModeUpdate >= 100)
    // {
    //     modeIndicator.setMode(competitionManager.getCurrentMode());
    //     modeIndicator.update();
    //     lastModeUpdate = t;
    // }

    // /* 2. Recepción de tramas robustas */
    // CommunicationSerializer::parseStream();

    // /* 3. Cambio de modo */
    // competitionManager.checkMode();
    // OperationMode currentMode = competitionManager.getCurrentMode();

    // /* 4. Calibración si se solicitó */
    // if (calibrationRequested)
    // {
    //     performCalibration();
    //     calibrationRequested = false;
    // }

    // /* 5. Activar/desactivar sensores según modo */
    // bool should = (currentMode != MODE_REMOTE_CONTROL);
    // if (sensorsEnabled != should)
    // {
    //     sensorsEnabled = should;
    //     sensorArray.setPower(sensorsEnabled);
    // }

    // /* 6. Ejecutar lógica del modo */
    // switch (currentMode)
    // {
    //     case MODE_REMOTE_CONTROL:
    //         executeRemoteControlMode();
    //         break;
    //     case MODE_COMPETITION:
    //         executeCompetitionMode();
    //         break;
    //     case MODE_DEBUG:
    //     case MODE_TUNING:
    //         executeDebugMode();
    //         break;
    //     case MODE_CALIBRATION:
    //         executeCalibrationMode();
    //         break;
    // }

    // /* 7. Actualizaciones comunes */
    // updateCommonSystems();
    // ultrasonicSensor.process();
    // sendOptimizedTelemetry(currentMode);

    // delay(10);
}

/* ============================================================== */
/* =================  MODOS DE OPERACIÓN  ======================= */
/* ============================================================== */
void executeRemoteControlMode()
{
    if (millis() - lastRemoteCheck > 500)
    {
        remoteControl.checkConnection();
        lastRemoteCheck = millis();
    }

    if (remoteControl.isConnected())
    {
        motorController.tankDrive(remoteControl.getLeftSpeed(), remoteControl.getRightSpeed());
    }
    else
    {
        motorController.stopAll();
    }

    if (millis() - lastSensorRead >= 50)
    {
        sensorArray.readLinePosition();
        lastSensorRead = millis();
    }
}

void executeCompetitionMode() {
    if (millis() - lastSensorRead >= 20) {
        int error     = sensorArray.readLinePosition();
        int sum       = sensorArray.getSensorSum();
        triggerUltrasonicMeasurement();
        float dist    = getUltrasonicDistance();
        auto action   = obstacleAvoidance.evaluateObstacle(dist, motorController.getBaseSpeed());
        bool critical = (action == IntelligentAvoidance::EMERGENCY_STOP);

        stateMachine.updateState(error, sum, critical, MODE_COMPETITION);
        executeIntelligentActions(error, action);
        lastSensorRead = millis();
    }
}

void executeDebugMode() {
    if (millis() - lastSensorRead >= 30) {
        int error = sensorArray.readLinePosition();
        int sum   = sensorArray.getSensorSum();
        updateOdometry();
        triggerUltrasonicMeasurement();
        float dist  = getUltrasonicDistance();
        auto action = obstacleAvoidance.evaluateObstacle(dist, motorController.getBaseSpeed());
        bool critical = (action == IntelligentAvoidance::EMERGENCY_STOP);

        stateMachine.updateState(error, sum, critical, MODE_DEBUG);
        executeIntelligentActions(error, action);
        lastSensorRead = millis();
    }
}

void executeCalibrationMode() {
    motorController.stopAll();
    if (millis() - lastSensorRead >= 500) {
        int16_t s[6];
        for (int i = 0; i < 6; ++i) s[i] = sensorArray.readCalibratedSensor(i);
        CommunicationSerializer::sendSensorData(millis(), s, sensorArray.readLinePosition(), sensorArray.getSensorSum());
        lastSensorRead = millis();
    }
}

/* ============================================================== */
/* ==================  SISTEMAS AUXILIARES  ===================== */
/* ============================================================== */
void performCalibration() {
    CommunicationSerializer::sendSystemMessage("Autocalibrando…");
    sensorArray.performAutoCalibration();
    sensorArray.saveCalibrationToConfig(currentConfig);
    if (eepromManager.saveConfig(currentConfig))
        CommunicationSerializer::sendSystemMessage("Calibración guardada");
    else
        CommunicationSerializer::sendSystemMessage("Error EEPROM");
}

void updateCommonSystems() {
    encoderController.updateVelocities();
    if (competitionManager.getCurrentMode() != MODE_CALIBRATION)
        updateOdometry();
}

void updateOdometry() {
    unsigned long t = millis();
    if (t - lastOdometryUpdate >= 50) {
        odometry.update(encoderController.getLeftCount(),
                        encoderController.getRightCount(),
                        t - lastOdometryUpdate);
        lastOdometryUpdate = t;
    }
}

void executeIntelligentActions(int error, IntelligentAvoidance::AvoidanceAction action) {
    switch (action) {
        case IntelligentAvoidance::EMERGENCY_STOP: motorController.stopAll(); break;
        case IntelligentAvoidance::REVERSE:        motorController.tankDrive(-100, -100); break;
        case IntelligentAvoidance::SLOW_DOWN:      followLineWithSpeed(error, motorController.getBaseSpeed() * 0.5f); break;
        default:                                   executeStateActions(error); break;
    }
}

void executeStateActions(int error) {
    switch (stateMachine.getCurrentState()) {
        case STATE_FOLLOWING_LINE:  followLineWithSpeed(error, motorController.getBaseSpeed()); break;
        case STATE_SEARCHING_LINE:  searchForLine(); break;
        case STATE_STOPPED:         motorController.stopAll(); break;
        case STATE_TURNING_RIGHT:   motorController.tankDrive(150, -150); break;
        case STATE_TURNING_LEFT:    motorController.tankDrive(-150, 150); break;
        case STATE_SHARP_CURVE:     followLineWithSpeed(error * 1.3f, motorController.getBaseSpeed()); break;
        case STATE_AVOIDING_OBSTACLE: avoidObstacle(); break;
        default: break;
    }
}

void followLineWithSpeed(int error, int speed) {
    double corr = linePID.compute(error);
    motorController.tankDrive(speed + corr, speed - corr);
}

void searchForLine() {
    motorController.tankDrive(120 * stateMachine.getSearchDirection(), -120 * stateMachine.getSearchDirection());
}

void avoidObstacle() {
    static int phase = 0;
    static unsigned long t0 = 0;
    if (millis() - t0 > 500) { phase++; t0 = millis(); }
    switch (phase) {
        case 0: motorController.tankDrive(-150, -150); break;
        case 1: motorController.tankDrive(-150, 150);  break;
        case 2: motorController.tankDrive(150, 150);   break;
        default: phase = 0; break;
    }
}

/* ============================================================== */
/* ======================  TELEMETRÍA  ========================== */
/* ============================================================== */
void sendOptimizedTelemetry(OperationMode mode) {
    if (!competitionManager.isSerialEnabled()) return;
    unsigned long t = millis();
    if (t - lastTelemetry < 200) return;
    lastTelemetry = t;

    switch (mode) {
        case MODE_REMOTE_CONTROL:
            CommunicationSerializer::sendRemoteStatus(remoteControl.isConnected(),
                                                       remoteControl.getLeftSpeed(),
                                                       remoteControl.getRightSpeed());
            break;
        case MODE_COMPETITION:
            triggerUltrasonicMeasurement();
            CommunicationSerializer::sendState(t, stateMachine.getCurrentState(), getUltrasonicDistance());
            break;
        default: {
            int16_t s[6];
            for (int i = 0; i < 6; ++i) s[i] = sensorArray.readCalibratedSensor(i);
            CommunicationSerializer::sendSensorData(t, s, sensorArray.readLinePosition(), sensorArray.getSensorSum());
            CommunicationSerializer::sendOdometry(t, odometry.getX(), odometry.getY(), odometry.getTheta());
            triggerUltrasonicMeasurement();
            CommunicationSerializer::sendState(t, stateMachine.getCurrentState(), getUltrasonicDistance());
            CommunicationSerializer::sendPidTuning(linePID.getKp(), linePID.getKi(), linePID.getKd(), linePID.getIntegral());
            break;
        }
    }
}

/* ============================================================== */
/* ===================  HARDWARE ULTRASÓNICO  =================== */
/* ============================================================== */
void triggerUltrasonicMeasurement() { ultrasonicSensor.triggerMeasurement(); }
float getUltrasonicDistance()       { return ultrasonicSensor.getDistance(); }

/* ============================================================== */
/* =================  INTERRUPCIONES ENCODERS  ================== */
/* ============================================================== */
void encoderLeftISR()  { encoderController.incrementLeft(); }
void encoderRightISR() { encoderController.incrementRight(); }
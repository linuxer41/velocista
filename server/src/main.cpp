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
bool telemetryEnabled     = true;

// Pointers for dispatch
MotorController* motorControllerPtr = &motorController;
EncoderController* encoderControllerPtr = &encoderController;
SensorArray* sensorArrayPtr = &sensorArray;
AdvancedPID* linePIDPtr = &linePID;
Odometry* odometryPtr = &odometry;
EEPROMManager* eepromManagerPtr = &eepromManager;
IntelligentAvoidance* obstacleAvoidancePtr = &obstacleAvoidance;
CompetitionManager* competitionManagerPtr = &competitionManager;
RemoteControl* remoteControlPtr = &remoteControl;
ModeIndicator* modeIndicatorPtr = &modeIndicator;
StateMachine* stateMachinePtr = &stateMachine;
UltrasonicInterrupt* ultrasonicSensorPtr = &ultrasonicSensor;
RobotConfig* currentConfigPtr = &currentConfig;
bool* calibrationRequestedPtr = &calibrationRequested;

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
    delay(1000);
    CommunicationSerializer::sendSystemMessage("Robot Seguidor 4.0 – PID, Odometria, Remoto, EEPROM, Evasion");
    CommunicationSerializer::sendSystemMessage("Comandos: start, stop, set_pid, set_speed, set_mode, calibrate_sensors, get_status, toggle_telemetry");

    motorController.initialize();
    encoderController.initialize();
    sensorArray.initialize();
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

    lastOdometryUpdate = millis();
    lastSensorRead     = millis();

}

/* ============================================================== */
/* --------------------  LOOP  ---------------------------------- */
/* ============================================================== */

void loop()
{
    unsigned long t = millis();

    /* 1. Indicador modo cada 100 ms */
    if (t - lastModeUpdate >= 100)
    {
        modeIndicator.setMode(competitionManager.getCurrentMode());
        modeIndicator.update();
        lastModeUpdate = t;
    }

    /* 2. Recepción de tramas robustas */
    CommunicationSerializer::parseStream();

    /* 3. Cambio de modo */
    competitionManager.checkMode();
    OperationMode currentMode = competitionManager.getCurrentMode();

    /* 4. Calibración si se solicitó */
    if (calibrationRequested)
    {
        performCalibration();
        calibrationRequested = false;
    }

    /* 5. Activar/desactivar sensores según modo */
    bool should = (currentMode != MODE_REMOTE_CONTROL);
    if (sensorsEnabled != should)
    {
        sensorsEnabled = should;
        sensorArray.setPower(sensorsEnabled);
    }

    /* 6. Ejecutar lógica del modo */
    switch (currentMode)
    {
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

    /* 7. Actualizaciones comunes */
    updateCommonSystems();
    ultrasonicSensor.process();
    sendOptimizedTelemetry(currentMode);

    delay(10);
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
    // Unified telemetry will be sent automatically by sendOptimizedTelemetry
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
    if (!competitionManager.isSerialEnabled() || !telemetryEnabled) return;
    unsigned long t = millis();
    if (t - lastTelemetry < 200) return;
    lastTelemetry = t;

    // Trigger ultrasonic measurement
    triggerUltrasonicMeasurement();

    // Collect all telemetry data
    int16_t pwmLeft = motorController.getCurrentLeftPWM();
    int16_t pwmRight = motorController.getCurrentRightPWM();
    float rpmLeft = encoderController.getLeftRPM();
    float rpmRight = encoderController.getRightRPM();
    float distanceTraveled = odometry.getTotalDistance();
    float ultrasonicDistance = getUltrasonicDistance();
    int16_t sensors[6];
    for (int i = 0; i < 6; ++i) sensors[i] = sensorArray.readCalibratedSensor(i);
    int16_t sensorError = sensorArray.readLinePosition();
    int16_t sensorSum = sensorArray.getSensorSum();
    float odomX = odometry.getX();
    float odomY = odometry.getY();
    float odomTheta = odometry.getTheta();
    float pidKp = linePID.getKp();
    float pidKi = linePID.getKi();
    float pidKd = linePID.getKd();
    float pidIntegral = linePID.getIntegral();
    uint8_t remoteConnected = remoteControl.isConnected() ? 1 : 0;
    int16_t remoteLeftSpeed = remoteControl.getLeftSpeed();
    int16_t remoteRightSpeed = remoteControl.getRightSpeed();

    // Send unified telemetry
    TelemetryMessage msg = {
        0, // type (not used)
        t,
        (uint8_t)mode,
        (uint8_t)stateMachine.getCurrentState(),
        pwmLeft,
        pwmRight,
        rpmLeft,
        rpmRight,
        distanceTraveled,
        ultrasonicDistance,
        {sensors[0], sensors[1], sensors[2], sensors[3], sensors[4], sensors[5]},
        sensorError,
        sensorSum,
        odomX,
        odomY,
        odomTheta,
        pidKp,
        pidKi,
        pidKd,
        pidIntegral,
        0.0f, // motorPidKp
        0.0f, // motorPidKi
        0.0f, // motorPidKd
        0.0f, // motorPidIntegral
        remoteConnected,
        remoteLeftSpeed,
        remoteRightSpeed
    };
    CommunicationSerializer::sendUnifiedTelemetry(msg);
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

/* ============================================================== */
/* =================  COMMAND DISPATCH  ========================= */
/* ============================================================== */
void dispatchCommand(String line)
{
    // Parse CSV: type,value1,value2,...
    int commaIndex = line.indexOf(',');
    if (commaIndex == -1)
    {
        return;
    }
    String typeStr = line.substring(0, commaIndex);
    uint8_t type = typeStr.toInt();
    String params = line.substring(commaIndex + 1);

    switch (type)
    {
    case CMD_SET_PID:
    {
        // params: kp,ki,kd
        int idx1 = params.indexOf(',');
        int idx2 = params.indexOf(',', idx1 + 1);
        if (idx1 != -1 && idx2 != -1)
        {
            float kp = params.substring(0, idx1).toFloat();
            float ki = params.substring(idx1 + 1, idx2).toFloat();
            float kd = params.substring(idx2 + 1).toFloat();
            linePIDPtr->setGains(kp, ki, kd);
            currentConfigPtr->kp = kp;
            currentConfigPtr->ki = ki;
            currentConfigPtr->kd = kd;
            eepromManagerPtr->saveConfig(*currentConfigPtr);
            CommunicationSerializer::sendCommandAck(type);
        }
    }
    break;
    case CMD_SET_SPEED:
    {
        // params: speed
        int16_t speed = params.toInt();
        motorControllerPtr->setBaseSpeed(speed);
        currentConfigPtr->baseSpeed = speed;
        eepromManagerPtr->saveConfig(*currentConfigPtr);
        CommunicationSerializer::sendCommandAck(type);
    }
    break;
    case CMD_SET_MODE:
    {
        uint8_t mode = params.toInt();
        competitionManagerPtr->setMode((OperationMode)mode);
        CommunicationSerializer::sendCommandAck(type);
    }
    break;
    case CMD_CALIBRATE:
    {
        *calibrationRequestedPtr = true;
        CommunicationSerializer::sendCommandAck(type);
    }
    break;
    case CMD_START:
    {
        // Assuming start means set to competition mode or something
        competitionManagerPtr->setMode(MODE_COMPETITION);
        CommunicationSerializer::sendCommandAck(type);
    }
    break;
    case CMD_STOP:
    {
        motorControllerPtr->stopAll();
        CommunicationSerializer::sendCommandAck(type);
    }
    break;
    case CMD_GET_STATUS:
    {
        String status = "Mode: " + competitionManagerPtr->getModeString() +
                       ", Speed: " + String(motorControllerPtr->getBaseSpeed()) +
                       ", Serial: " + (competitionManagerPtr->isSerialEnabled() ? "ON" : "OFF") +
                       ", Telemetry: " + (telemetryEnabled ? "ON" : "OFF");
        CommunicationSerializer::sendSystemMessage(status.c_str());
    }
    break;
    case CMD_TOGGLE_TELEMETRY:
    {
        telemetryEnabled = !telemetryEnabled;
        CommunicationSerializer::sendSystemMessage(telemetryEnabled ? "Telemetry enabled" : "Telemetry disabled");
        CommunicationSerializer::sendCommandAck(type);
    }
    break;
    /* … otros comandos … */
    }
}
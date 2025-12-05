#include "robot.h"

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-variable"
#include <EEPROM.h>
#pragma GCC diagnostic pop

// Static pointers for ISRs
Motor* Robot::leftMotorPtr;
Motor* Robot::rightMotorPtr;

// Motor implementations
Motor::Motor(uint8_t p1, uint8_t p2, Location loc, uint8_t encA, uint8_t encB) : pin1(p1), pin2(p2), speed(0), location(loc), forwardCount(0), backwardCount(0), lastCount(0), lastSpeedCheck(0), currentRPM(0), filteredRPM(0), targetRPM(0), encoderAPin(encA), encoderBPin(encB) {
}

void Motor::init() {
    pinMode(pin1, OUTPUT);
    pinMode(pin2, OUTPUT);
    pinMode(encoderAPin, INPUT_PULLUP);
    pinMode(encoderBPin, INPUT_PULLUP);
}

void Motor::setSpeed(int s) {
    speed = constrain(s, -config.maxPwm, config.maxPwm);
    if (location == LEFT) {
      if (speed >= 0) {
        analogWrite(pin1, speed);
        analogWrite(pin2, 0);
      } else {
        analogWrite(pin1, 0);
        analogWrite(pin2, -speed);
      }
    } else { // RIGHT
      if (speed >= 0) {
        analogWrite(pin1, speed);
        analogWrite(pin2, 0);
      } else {
        analogWrite(pin1, 0);
        analogWrite(pin2, -speed);
      }
    }
}

int Motor::getSpeed() {
    return speed;
}

float Motor::getRPM() {
    unsigned long now = millis();
    if (now - lastSpeedCheck < 100) return currentRPM;
    long currentCount = forwardCount - backwardCount;
    long delta = currentCount - lastCount;
    float dt = (now - lastSpeedCheck) / 1000.0;
    currentRPM = (delta / (float)config.pulsesPerRevolution) * 60.0 / dt;
    filteredRPM = 0.9 * filteredRPM + 0.1 * currentRPM;
    lastCount = currentCount;
    lastSpeedCheck = now;
    return currentRPM;
}

float Motor::getFilteredRPM() {
    return filteredRPM;
}

void Motor::setTargetRPM(float t) {
    targetRPM = t;
}

float Motor::getTargetRPM() {
    return targetRPM;
}

long Motor::getEncoderCount() {
    return forwardCount;
}

long Motor::getBackwardCount() {
    return backwardCount;
}

void Motor::updateEncoder() {
    if (location == LEFT) {
      if (digitalRead(encoderBPin)) {
        backwardCount++;  // LEFT motor: B HIGH = backward
      } else {
        forwardCount++;   // LEFT motor: B LOW = forward
      }
    } else {
      if (digitalRead(encoderBPin)) {
        forwardCount++;   // RIGHT motor: B HIGH = forward
      } else {
        backwardCount++;  // RIGHT motor: B LOW = backward
      }
    }
}

// ISR functions
void Robot::leftEncoderISR() {
    if (Robot::leftMotorPtr) Robot::leftMotorPtr->updateEncoder();
}

void Robot::rightEncoderISR() {
    if (Robot::rightMotorPtr) Robot::rightMotorPtr->updateEncoder();
}

Robot::Robot() :
    leftMotor(MOTOR_LEFT_PIN1, MOTOR_LEFT_PIN2, LEFT, ENCODER_LEFT_A, ENCODER_LEFT_B),
    rightMotor(MOTOR_RIGHT_PIN1, MOTOR_RIGHT_PIN2, RIGHT, ENCODER_RIGHT_A, ENCODER_RIGHT_B),
    eeprom(),
    qtr(),
    linePid(DEFAULT_LINE_KP, DEFAULT_LINE_KI, DEFAULT_LINE_KD, LIMIT_MAX_PWM, -LIMIT_MAX_PWM),
    leftPid(DEFAULT_LEFT_KP, DEFAULT_LEFT_KI, DEFAULT_LEFT_KD, LIMIT_MAX_PWM, -LIMIT_MAX_PWM),
    rightPid(DEFAULT_RIGHT_KP, DEFAULT_RIGHT_KI, DEFAULT_RIGHT_KD, LIMIT_MAX_PWM, -LIMIT_MAX_PWM),
    debugger(),
    serialReader(),
    features(),
    lastPidOutput(0),
    lastTelemetryTime(0),
    lastLineTime(0),
    lastSpeedTime(0),
    lastLinePosition(0),
    loopTime(0),
    loopStartTime(0),
    leftTargetRPM(0),
    rightTargetRPM(0),
    throttle(0),
    steering(0),
    lastLedTime(0),
    ledState(false),
    previousLinePosition(0),
    currentCurvature(0),
    filteredCurvature(0),
    currentSensorState(NORMAL),
    lastTurnDirection(1),
    autoTuningActive(false),
    autoTuneStartTime(0),
    autoTuneTestStartTime(0),
    currentTestIndex(0),
    totalTests(0),
    bestIAE(999999.0f),
    bestKp(0), bestKi(0), bestKd(0),
    originalKp(0), originalKi(0), originalKd(0),
    accumulatedIAE(0),
    samplesCount(0),
    lastPosition(0),
    maxDeviation(0)
{
    // Initialize commands
    commands[0] = {"calibrate", &Robot::handleCalibrate};
    commands[1] = {"save", &Robot::handleSave};
    commands[2] = {"get debug", &Robot::handleGetDebug};
    commands[3] = {"get telemetry", &Robot::handleGetTelemetry};
    commands[4] = {"get config", &Robot::handleGetConfig};
    commands[5] = {"reset", &Robot::handleReset};
    commands[6] = {"help", &Robot::handleHelp};
    commands[7] = {"set telemetry ", &Robot::handleSetTelemetry};
    commands[8] = {"set mode ", &Robot::handleSetMode};
    commands[9] = {"set cascade ", &Robot::handleSetCascade};
    commands[10] = {"set feature ", &Robot::handleSetFeature};
    commands[11] = {"set features ", &Robot::handleSetFeatures};
    commands[12] = {"set line ", &Robot::handleSetLine};
    commands[13] = {"set left ", &Robot::handleSetLeft};
    commands[14] = {"set right ", &Robot::handleSetRight};
    commands[15] = {"set base ", &Robot::handleSetBase};
    commands[16] = {"set max ", &Robot::handleSetMax};
    commands[17] = {"set weight ", &Robot::handleSetWeight};
    commands[18] = {"set samp_rate ", &Robot::handleSetSampRate};
    commands[19] = {"rc ", &Robot::handleRc};
    commands[20] = {"set pwm ", &Robot::handleSetPwm};
    commands[21] = {"set rpm ", &Robot::handleSetRpm};
    commands[22] = {"autotune", &Robot::handleAutoTune};
    commands[23] = {NULL, NULL};
}

void Robot::init() {
    Serial.begin(115200);
    while (!Serial);

    leftMotor.init();
    rightMotor.init();
    Robot::leftMotorPtr = &leftMotor;
    Robot::rightMotorPtr = &rightMotor;
    attachInterrupt(digitalPinToInterrupt(ENCODER_LEFT_A), Robot::leftEncoderISR, RISING);
    attachInterrupt(digitalPinToInterrupt(ENCODER_RIGHT_A), Robot::rightEncoderISR, RISING);
    qtr.init();
    pinMode(MODE_LED_PIN, OUTPUT);
    digitalWrite(MODE_LED_PIN, LOW);

    eeprom.load();
    linePid.setGains(config.lineKp, config.lineKi, config.lineKd);
    leftPid.setGains(config.leftKp, config.leftKi, config.leftKd);
    rightPid.setGains(config.rightKp, config.rightKi, config.rightKd);
    features.setConfig(config.features);

    qtr.setCalibration(config.sensorMin, config.sensorMax);

    qtr.calibrate();

    debugger.systemMessage("Robot iniciado. Modo: " + String(config.operationMode));
    lastLineTime = millis();
    lastSpeedTime = millis();
}

void Robot::run() {
    unsigned long currentMillis = millis();

    if (currentMillis - lastLineTime >= config.loopLineMs) {
        lastLineTime = currentMillis;
        float dtLine = config.loopLineMs / 1000.0;

        if (config.operationMode == MODE_LINE_FOLLOWING) {
            qtr.read();
            int16_t* rawSensors = qtr.getRawSensorValues();
            SensorState state = checkSensorState(rawSensors);
            currentSensorState = state;

            float currentPosition = features.applySignalFilters(qtr.linePosition);
            
            // Auto-tuning logic
            if (autoTuningActive) {
                performAutoTune(currentPosition, dtLine);
            }
            
            float curvature = abs(currentPosition - previousLinePosition) / dtLine;
            previousLinePosition = currentPosition;
            currentCurvature = curvature;
            filteredCurvature = 0.8 * filteredCurvature + 0.2 * curvature;

            if (currentPosition > 10) lastTurnDirection = 1;
            else if (currentPosition < -10) lastTurnDirection = -1;

            float applyBaseRPM = config.baseRPM;
            int applyBaseSpeed = config.basePwm;
            if(config.features.speedProfiling) {
                if(filteredCurvature > 500.0f) {
                    applyBaseRPM = max(60.0f, applyBaseRPM - 30.0f);
                    applyBaseSpeed = max(100, applyBaseSpeed - 50);
                } else if(filteredCurvature < 100.0f) {
                    applyBaseRPM = min(config.baseRPM + 20.0f, applyBaseRPM + 10.0f);
                    applyBaseSpeed = min(config.maxPwm, applyBaseSpeed + 20);
                }
            }

            float pidOutput;
            lastLinePosition = currentPosition;
            float error = 0 - lastLinePosition;
            linePid.setGains(config.lineKp, config.lineKi, config.lineKd);
            pidOutput = linePid.calculate(0, error, dtLine);
            lastPidOutput = pidOutput;

            if (config.cascadeMode) {
                float rpmAdjustment = pidOutput * 0.5;
                leftTargetRPM = applyBaseRPM + rpmAdjustment;
                rightTargetRPM = applyBaseRPM - rpmAdjustment;
            } else {
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
            leftTargetRPM = throttle - steering;
            rightTargetRPM = throttle + steering;
            leftTargetRPM = constrain(leftTargetRPM, -config.maxRpm, config.maxRpm);
            rightTargetRPM = constrain(rightTargetRPM, -config.maxRpm, config.maxRpm);
        } else if (config.operationMode == MODE_LINE_FOLLOWING && config.cascadeMode) {
            // targetRPMs already set
        }

        if (config.operationMode == MODE_REMOTE_CONTROL || (config.operationMode == MODE_LINE_FOLLOWING && config.cascadeMode)) {
            int leftSpeed = leftPid.calculate(leftTargetRPM, leftMotor.getFilteredRPM(), dtSpeed);
            int rightSpeed = rightPid.calculate(rightTargetRPM, rightMotor.getFilteredRPM(), dtSpeed);

            leftSpeed = constrain(leftSpeed, -config.maxPwm, config.maxPwm);
            rightSpeed = constrain(rightSpeed, -config.maxPwm, config.maxPwm);

            int currentMax = max(abs(leftSpeed), abs(rightSpeed));
            if(currentMax > config.maxPwm) {
                config.maxPwm = currentMax;
                saveConfig();
            }

            leftMotor.setSpeed(leftSpeed);
            rightMotor.setSpeed(rightSpeed);
        } else if (config.operationMode == MODE_IDLE) {
            int leftSpeed = leftPid.calculate(leftTargetRPM, leftMotor.getFilteredRPM(), dtSpeed);
            int rightSpeed = rightPid.calculate(rightTargetRPM, rightMotor.getFilteredRPM(), dtSpeed);

            leftSpeed = constrain(leftSpeed, -config.maxPwm, config.maxPwm);
            rightSpeed = constrain(rightSpeed, -config.maxPwm, config.maxPwm);

            leftMotor.setSpeed(leftSpeed);
            rightMotor.setSpeed(rightSpeed);
        }

        loopTime = micros() - loopStartTime;
    }

    if (config.telemetry && (millis() - lastTelemetryTime > config.telemetryIntervalMs)) {
        TelemetryData data = buildTelemetryData();
        debugger.sendTelemetryData(data);
        lastTelemetryTime = millis();
    }

    if (config.operationMode == MODE_LINE_FOLLOWING) {
        if (autoTuningActive) {
            updateModeLed(currentMillis, 200); // Faster blink during auto-tuning
        } else {
            updateModeLed(currentMillis, 100);
        }
    } else if (config.operationMode == MODE_REMOTE_CONTROL) {
        updateModeLed(currentMillis, 500);
    } else {
        digitalWrite(MODE_LED_PIN, LOW);
    }

    serialReader.fillBuffer();
    const char *cmd;
    if (serialReader.getLine(&cmd)) {
        if (strlen(cmd) == 0) return;
        processCommand(cmd);
    }
}

// PID implementations
PID::PID(float p, float i, float d, float maxOut, float minOut) : kp(p), ki(i), kd(d), error(0), lastError(0), integral(0), derivative(0), output(0), antiWindupEnabled(true), maxOutput(maxOut), minOutput(minOut) {}

void PID::setGains(float p, float i, float d) {
    kp = p;
    ki = i;
    kd = d;
}

float PID::calculate(float setpoint, float measurement, float dt) {
    error = setpoint - measurement;
    derivative = (error - lastError) / dt;

    // Calcular términos
    float pTerm = kp * error;
    float iTerm = ki * integral;
    float dTerm = kd * derivative;

    // Anti-windup: integración condicional
    if (antiWindupEnabled) {
      float unsaturatedOutput = pTerm + iTerm + dTerm;
      // Solo integrar si no está saturado en la dirección del error
      if ((unsaturatedOutput < maxOutput || error <= 0) && (unsaturatedOutput > minOutput || error >= 0)) {
        integral += error * dt;
        integral = constrain(integral, -1000, 1000);
      }
    } else {
      integral += error * dt;
      integral = constrain(integral, -1000, 1000);
    }

    iTerm = ki * integral;
    output = pTerm + iTerm + dTerm;
    output = constrain(output, minOutput, maxOutput);
    lastError = error;
    return output;
}

void PID::reset() {
    error = 0;
    lastError = 0;
    integral = 0;
    derivative = 0;
    output = 0;
}

float PID::getOutput() {
    return output;
}

float PID::getError() {
    return error;
}

float PID::getIntegral() {
    return integral;
}

float PID::getDerivative() {
    return derivative;
}

// Features implementations
void Features::sort(float arr[], int n) {
    for (int i = 0; i < n-1; i++) {
        for (int j = 0; j < n-i-1; j++) {
            if (arr[j] > arr[j+1]) {
                float temp = arr[j];
                arr[j] = arr[j+1];
                arr[j+1] = temp;
            }
        }
    }
}

Features::Features() : medianCount(0), movingSum(0), movingCount(0), kalmanX(0), kalmanP(100), hysteresisLast(0), lowPassLast(0) {
    memset(medianBuffer, 0, sizeof(medianBuffer));
    memset(movingBuffer, 0, sizeof(movingBuffer));
}

void Features::setConfig(FeaturesConfig& f) {
    config = f;
}

float Features::applySignalFilters(float raw) {
    float current = raw;

    // 0: Median filter (3 samples)
    if (config.medianFilter) {
        medianBuffer[medianCount] = raw * 100;
        medianCount = (medianCount + 1) % 3;
        if (medianCount == 0) { // buffer full
            float arr[3] = {medianBuffer[0] / 100.0, medianBuffer[1] / 100.0, medianBuffer[2] / 100.0};
            sort(arr, 3);
            current = arr[1]; // median
        }
    }

    // 1: Moving average (3 samples)
    if (config.movingAverage) {
        movingSum -= movingBuffer[movingCount];
        movingBuffer[movingCount] = current * 100;
        movingSum += movingBuffer[movingCount];
        movingCount = (movingCount + 1) % 3;
        current = movingSum / 3.0 / 100.0;
    }

    // 2: Kalman filter
    if (config.kalmanFilter) {
        kalmanP += 1; // 0.01 * 100
        int32_t measurement = current * 100;
        int32_t k = kalmanP * 100 / (kalmanP + 10); // k = P / (P + 0.1) scaled
        kalmanX += k * (measurement - kalmanX) / 100;
        kalmanP = kalmanP * (10000 - k) / 10000; // P *= (1 - k/100)
        current = kalmanX / 100.0;
    }

    // 3: Hysteresis (threshold 10)
    if (config.hysteresis) {
        if (abs(current - hysteresisLast / 100.0) > 10) {
            hysteresisLast = current * 100;
        } else {
            current = hysteresisLast / 100.0;
        }
    }

    // 4: Dead zone (threshold 5)
    if (config.deadZone) {
        if (abs(current) < 5) current = 0;
    }

    // 5: Low pass (alpha 0.8)
    if (config.lowPass) {
        current = 0.8 * (lowPassLast / 100.0) + 0.2 * current;
        lowPassLast = current * 100;
    }

    return current;
}

// QTR implementations
QTR::QTR() : linePosition(0.0) {
    for (int i = 0; i < 8; i++) {
      sensorMin[i] = 0;
      sensorMax[i] = 1023;
    }
}

void QTR::init() {
    pinMode(SENSOR_POWER_PIN, OUTPUT);
    for (int i = 0; i < NUM_SENSORS; i++) {
      pinMode(SENSOR_PINS[i], INPUT);
    }
}

void QTR::setCalibration(int16_t minVals[], int16_t maxVals[]) {
    for (int i = 0; i < NUM_SENSORS; i++) {
      sensorMin[i] = minVals[i];
      sensorMax[i] = maxVals[i];
    }
}

void QTR::read() {
    int sum = 0;
    int weightedSum = 0;
    int totalVal = 0;
    digitalWrite(SENSOR_POWER_PIN, HIGH);
    delayMicroseconds(100);
    for (int i = 0; i < NUM_SENSORS; i++) {
      int val = analogRead(SENSOR_PINS[i]);
      rawSensorValues[i] = val;
      int range = sensorMax[i] - sensorMin[i];
      if (range > 0) {
        val = map(val, sensorMin[i], sensorMax[i], 0, 1000);
      } else {
        val = 0; // Default if not calibrated
      }
      val = constrain(val, 0, 1000);
      sensorValues[i] = val;
      totalVal += val;
      int weight = 1000 - val;
      weightedSum += i * weight;
      sum += weight;
    }
    digitalWrite(SENSOR_POWER_PIN, LOW);

    // Calculate line position
    if (sum > 0) {
      linePosition = ((float)weightedSum / sum - QTR_CENTER_OFFSET) * QTR_POSITION_SCALE;
    }
}

void QTR::calibrate() {
    for (int i = 0; i < NUM_SENSORS; i++) {
      sensorMin[i] = 1023;
      sensorMax[i] = 0;
    }
    unsigned long start = millis();
    digitalWrite(SENSOR_POWER_PIN, HIGH);
    delayMicroseconds(100);
    while (millis() - start < 5000) {  // 5 segundos
      for (int i = 0; i < NUM_SENSORS; i++) {
        int val = analogRead(SENSOR_PINS[i]);
        if (val < sensorMin[i]) sensorMin[i] = val;
        if (val > sensorMax[i]) sensorMax[i] = val;
      }
      delay(10);
    }
    digitalWrite(SENSOR_POWER_PIN, LOW);
    // Save to config
    for (int i = 0; i < NUM_SENSORS; i++) {
      config.sensorMin[i] = sensorMin[i];
      config.sensorMax[i] = sensorMax[i];
    }
    saveConfig();
}

int16_t* QTR::getSensorValues() {
    return sensorValues;
}

int16_t* QTR::getRawSensorValues() {
    return rawSensorValues;
}

// Debugger implementations
Debugger::Debugger() {}

void Debugger::systemMessage(const char* msg) {
    Serial.print(F("type:1|"));
    Serial.println(msg);
}

void Debugger::systemMessage(const String& msg) {
    Serial.print(F("type:1|"));
    Serial.println(msg);
}

void Debugger::sendTelemetryData(TelemetryData& data, bool endLine) {
    if (endLine) Serial.print(F("type:4|"));
    Serial.print(F("LINE:["));
    Serial.print(data.linePos, 2); Serial.print(F(","));
    Serial.print(data.lineError, 2); Serial.print(F(","));
    Serial.print(data.lineIntegral, 2); Serial.print(F(","));
    Serial.print(data.lineDeriv, 2); Serial.print(F(","));
    Serial.print(data.linePidOut, 2); Serial.print(F("]"));
    Serial.print(F("|LEFT:["));
    Serial.print(data.lRpm, 2); Serial.print(F(","));
    Serial.print(data.lTargetRpm, 2); Serial.print(F(","));
    Serial.print(data.lSpeed); Serial.print(F(","));
    Serial.print(data.encL); Serial.print(F(","));
    Serial.print(data.encLBackward); Serial.print(F(","));
    Serial.print(data.lError, 2); Serial.print(F(","));
    Serial.print(data.lIntegral, 2); Serial.print(F(","));
    Serial.print(data.lDeriv, 2); Serial.print(F("]"));
    Serial.print(F("|RIGHT:["));
    Serial.print(data.rRpm, 2); Serial.print(F(","));
    Serial.print(data.rTargetRpm, 2); Serial.print(F(","));
    Serial.print(data.rSpeed); Serial.print(F(","));
    Serial.print(data.encR); Serial.print(F(","));
    Serial.print(data.encRBackward); Serial.print(F(","));
    Serial.print(data.rError, 2); Serial.print(F(","));
    Serial.print(data.rIntegral, 2); Serial.print(F(","));
    Serial.print(data.rDeriv, 2); Serial.print(F("]"));
    Serial.print(F("|PID:["));
    Serial.print(data.linePidOut, 2); Serial.print(F(","));
    Serial.print(data.lPidOut, 2); Serial.print(F(","));
    Serial.print(data.rPidOut, 2); Serial.print(F("]"));
    Serial.print(F("|SPEED_CMS:["));
    Serial.print(data.leftSpeedCms, 2); Serial.print(F(","));
    Serial.print(data.rightSpeedCms, 2); Serial.print(F("]"));
    Serial.print(F("|QTR:["));
    Serial.print(data.sensors[0]); Serial.print(F(","));
    Serial.print(data.sensors[1]); Serial.print(F(","));
    Serial.print(data.sensors[2]); Serial.print(F(","));
    Serial.print(data.sensors[3]); Serial.print(F(","));
    Serial.print(data.sensors[4]); Serial.print(F(","));
    Serial.print(data.sensors[5]); Serial.print(F(","));
    Serial.print(data.sensors[6]); Serial.print(F(","));
    Serial.print(data.sensors[7]); Serial.print(F("]"));
    Serial.print(F("|BATT:"));
    Serial.print(data.battery, 2);
    Serial.print(F("|LOOP_US:"));
    Serial.print(data.loopTime);
    Serial.print(F("|UPTIME:"));
    Serial.print(data.uptime);
    Serial.print(F("|CURV:"));
    Serial.print(data.curvature, 2);
    Serial.print(F("|STATE:"));
    Serial.print(data.sensorState);
    if (endLine) Serial.println();
}

void Debugger::sendDebugData(TelemetryData& data, RobotConfig& config) {
    sendConfigData(config, false);
    sendTelemetryData(data);
}

void Debugger::sendConfigData(RobotConfig& config, bool endLine) {
    if (endLine) Serial.print(F("type:3|"));
    Serial.print(F("LINE_K_PID:["));
    Serial.print(config.lineKp, 3); Serial.print(F(","));
    Serial.print(config.lineKi, 3); Serial.print(F(","));
    Serial.print(config.lineKd, 3); Serial.print(F("]"));
    Serial.print(F("|LEFT_K_PID:["));
    Serial.print(config.leftKp, 3); Serial.print(F(","));
    Serial.print(config.leftKi, 3); Serial.print(F(","));
    Serial.print(config.leftKd, 3); Serial.print(F("]"));
    Serial.print(F("|RIGHT_K_PID:["));
    Serial.print(config.rightKp, 3); Serial.print(F(","));
    Serial.print(config.rightKi, 3); Serial.print(F(","));
    Serial.print(config.rightKd, 3); Serial.print(F("]"));
    Serial.print(F("|BASE:["));
    Serial.print(config.basePwm); Serial.print(F(","));
    Serial.print(config.baseRPM, 2); Serial.print(F("]"));
    Serial.print(F("|MAX:["));
    Serial.print(config.maxPwm); Serial.print(F(","));
    Serial.print(config.maxRpm, 2); Serial.print(F("]"));
    Serial.print(F("|WHEELS:["));
    Serial.print(config.wheelDiameter, 1); Serial.print(F(","));
    Serial.print(config.wheelDistance, 1); Serial.print(F("]"));
    Serial.print(F("|MODE:"));
    Serial.print((int)config.operationMode);
    Serial.print(F("|CASCADE:"));
    Serial.print(config.cascadeMode ? F("1") : F("0"));
    Serial.print(F("|TELEMETRY:"));
    Serial.print(config.telemetry ? F("1") : F("0"));
    Serial.print(F("|FEAT_CONFIG:"));
    Serial.print(config.features.serialize());
    Serial.print(F("|WEIGHT:"));
    Serial.print(config.robotWeight, 1);
    Serial.print(F("|SAMP_RATE:["));
    Serial.print(config.loopLineMs); Serial.print(F(","));
    Serial.print(config.loopSpeedMs); Serial.print(F(","));
    Serial.print(config.telemetryIntervalMs); Serial.print(F("]"));
    if (endLine) Serial.println();
}

void Debugger::ackMessage(const char* cmd) {
    Serial.print(F("type:2|ack:"));
    Serial.println(cmd);
}

// SerialReader implementations
SerialReader::SerialReader() : lineReady(false), idx(0) {}

void SerialReader::fillBuffer() {
    while (Serial.available()) {
        char c = Serial.read();
        if (c == '\n' || c == '\r') {
            serBuf[idx] = '\0';
            lineReady = true;
            idx = 0;
            return;
        }
        if (idx < sizeof(serBuf) - 1) serBuf[idx++] = c;
    }
}

bool SerialReader::getLine(const char **buf) {
    if (!lineReady) return false;
    *buf = serBuf;

    // Convertir a minúsculas in-place
    for (char *p = serBuf; *p; ++p) *p = tolower(*p);

    lineReady = false;
    return true;
}

// EEPROMManager implementations
EEPROMManager::EEPROMManager() {
    load();
}

RobotConfig& EEPROMManager::getConfig() {
    return config;
}

void EEPROMManager::load() {
    EEPROM.get(EEPROM_CONFIG_ADDR, config);
    if (config.checksum != 1234567892) {
      Serial.println(F("Checksum EEPROM inválido"));
      config.restoreDefaults();
      save();
    }
}

void EEPROMManager::save() {
    EEPROM.put(EEPROM_CONFIG_ADDR, config);
}

// Función global para guardar configuración
void saveConfig() {
   EEPROM.put(EEPROM_CONFIG_ADDR, config);
}

SensorState Robot::checkSensorState(int16_t* rawSensors) {
    bool allBlack = true;
    bool allWhite = true;
    for(int i = 0; i < NUM_SENSORS; i++) {
        int range = config.sensorMax[i] - config.sensorMin[i];
        if(range > 0) {
            if(rawSensors[i] < config.sensorMax[i] - 0.3f * range) {
                allBlack = false;
            }
            if(rawSensors[i] > config.sensorMin[i] + 0.3f * range) {
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

void Robot::updateModeLed(unsigned long currentMillis, unsigned long blinkInterval) {
    if (currentMillis - lastLedTime >= blinkInterval) {
        ledState = !ledState;
        digitalWrite(MODE_LED_PIN, ledState);
        lastLedTime = currentMillis;
    }
}

TelemetryData Robot::buildTelemetryData() {
    TelemetryData data;
    qtr.read();
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
    data.battery = 8.4;
    data.loopTime = loopTime;
    data.curvature = filteredCurvature;
    data.sensorState = (uint8_t)currentSensorState;
    return data;
}

void Robot::processCommand(const char* cmd) {
    if (strlen(cmd) == 0) return;

    bool handled = false;
    for (int i = 0; commands[i].command != NULL; i++) {
        size_t len = strlen(commands[i].command);
        if (strncmp(cmd, commands[i].command, len) == 0) {
            const char* params = cmd + len;
            commands[i].handler(this, params);
            handled = true;
            break;
        }
    }

    if (handled) {
        char ackMsg[50];
        sprintf(ackMsg, " %s", cmd);
        debugger.ackMessage(ackMsg);
    } else {
        debugger.systemMessage(F("Comando desconocido. Envía 'help'"));
    }
}

int Robot:: parseFloatArray(const char* params, float* values, int maxCount) {
    char temp[64];
    strcpy(temp, params);
    char* token = strtok(temp, ",");
    int count = 0;
    while (token && count < maxCount) {
        values[count++] = atof(token);
        token = strtok(NULL, ",");
    }
    return count;
}

// Handler implementations
void Robot::handleCalibrate(Robot* self, const char* params) {
    self->leftMotor.setSpeed(0);
    self->rightMotor.setSpeed(0);
    digitalWrite(MODE_LED_PIN, HIGH);
    self->debugger.systemMessage(F("Calibrando..."));
    self->qtr.calibrate();
    digitalWrite(MODE_LED_PIN, LOW);
    self->debugger.systemMessage(F("Calibración completada."));
}

void Robot::handleSave(Robot* self, const char* params) {
    saveConfig();
}

void Robot::handleGetDebug(Robot* self, const char* params) {
    TelemetryData data = self->buildTelemetryData();
    self->debugger.sendDebugData(data, config);
}

void Robot::handleGetTelemetry(Robot* self, const char* params) {
    TelemetryData data = self->buildTelemetryData();
    self->debugger.sendTelemetryData(data);
}

void Robot::handleGetConfig(Robot* self, const char* params) {
    self->debugger.sendConfigData(config);
}

void Robot::handleReset(Robot* self, const char* params) {
    // Cancel auto-tuning if active
    if (self->autoTuningActive) {
        self->autoTuningActive = false;
        // Restore original PID values
        config.lineKp = self->originalKp;
        config.lineKi = self->originalKi;
        config.lineKd = self->originalKd;
        self->linePid.setGains(self->originalKp, self->originalKi, self->originalKd);
        self->debugger.systemMessage(F("Auto-tuning cancelado."));
        digitalWrite(MODE_LED_PIN, LOW);
    }
    
    config.restoreDefaults();
    saveConfig();
    self->linePid.setGains(config.lineKp, config.lineKi, config.lineKd);
    self->leftPid.setGains(config.leftKp, config.leftKi, config.leftKd);
    self->rightPid.setGains(config.rightKp, config.rightKi, config.rightKd);
}

void Robot::handleHelp(Robot* self, const char* params) {
    // self->debugger.systemMessage(F("Comandos: calibrate, save, get debug, get telemetry, get config, reset, help, autotune"));
    // self->debugger.systemMessage(F("set telemetry 0/1  |  set mode 0/1/2  |  set cascade 0/1"));
    // self->debugger.systemMessage(F("set feature <idx 0-8> 0/1  |  set features 0,1,0,...  |  set line kp,ki,kd  |  set left kp,ki,kd  |  set right kp,ki,kd"));
    // self->debugger.systemMessage(F("set base <pwm>,<rpm>  |  set max <pwm>,<rpm>  |  set weight <g>  |  set samp_rate <line_ms>,<speed_ms>,<telemetry_ms>"));
    // self->debugger.systemMessage(F("set pwm <derecha>,<izquierda>  (solo en modo idle)"));
    // self->debugger.systemMessage(F("set rpm <izquierda>,<derecha>  (solo en modo idle)"));
}

void Robot::handleSetTelemetry(Robot* self, const char* params) {
    char* end;
    int val = strtol(params, &end, 10);
    if (end == params || *end != '\0') { self->debugger.systemMessage(F("Falta argumento")); return; }
    config.telemetry = (val == 1);
    saveConfig();
}

void Robot::handleSetMode(Robot* self, const char* params) {
    char* end;
    int m = strtol(params, &end, 10);
    if (end == params || *end != '\0') { self->debugger.systemMessage(F("Falta argumento")); return; }
    config.operationMode = (OperationMode)m;
    if (config.operationMode == MODE_REMOTE_CONTROL) {
        self->throttle = 0; self->steering = 0;
        self->leftMotor.setSpeed(0); self->rightMotor.setSpeed(0);
    } else if (config.operationMode == MODE_IDLE) {
        self->leftTargetRPM = 0;
        self->rightTargetRPM = 0;
        self->leftMotor.setSpeed(0); self->rightMotor.setSpeed(0);
    }
}

void Robot::handleSetCascade(Robot* self, const char* params) {
    char* end;
    int val = strtol(params, &end, 10);
    if (end == params || *end != '\0') { self->debugger.systemMessage(F("Falta argumento")); return; }
    config.cascadeMode = (val == 1);
}

void Robot::handleSetFeature(Robot* self, const char* params) {
    const char* p = params;
    char* end1;
    int idx = strtol(p, &end1, 10);
    if (end1 == p || *end1 != ' ') { self->debugger.systemMessage(F("Formato: set feature <idx> <0/1>")); return; }
    char* end2;
    int val = strtol(end1 + 1, &end2, 10);
    if (end2 == end1 + 1 || *end2 != '\0' || idx < 0 || idx > 8) { self->debugger.systemMessage(F("Formato: set feature <idx> <0/1>")); return; }
    config.features.setFeature(idx, val == 1);
    self->features.setConfig(config.features);
}

void Robot::handleSetFeatures(Robot* self, const char* params) {
    if (config.features.deserialize(params)) {
        self->features.setConfig(config.features);
    } else {
        self->debugger.systemMessage(F("Formato: set features 0,1,0,1,... (9 valores)"));
    }
}

void Robot::handleSetLine(Robot* self, const char* params) {
    float values[3];
    int count = self->parseFloatArray(params, values, 3);
    if (count != 3) { self->debugger.systemMessage(F("Formato: set line kp,ki,kd")); return; }
    config.lineKp = values[0]; config.lineKi = values[1]; config.lineKd = values[2];
    self->linePid.setGains(values[0], values[1], values[2]);
}

void Robot::handleSetLeft(Robot* self, const char* params) {
    float values[3];
    int count = self->parseFloatArray(params, values, 3);
    if (count != 3) { self->debugger.systemMessage(F("Formato: set left kp,ki,kd")); return; }
    config.leftKp = values[0]; config.leftKi = values[1]; config.leftKd = values[2];
    self->leftPid.setGains(values[0], values[1], values[2]);
}

void Robot::handleSetRight(Robot* self, const char* params) {
    float values[3];
    int count = self->parseFloatArray(params, values, 3);
    if (count != 3) { self->debugger.systemMessage(F("Formato: set right kp,ki,kd")); return; }
    config.rightKp = values[0]; config.rightKi = values[1]; config.rightKd = values[2];
    self->rightPid.setGains(values[0], values[1], values[2]);
}

void Robot::handleSetBase(Robot* self, const char* params) {
    char* comma = strchr(params, ',');
    if (!comma) { self->debugger.systemMessage(F("Formato: set base <pwm>,<rpm>")); return; }
    int pwm = atoi(params);
    float rpm = atof(comma + 1);
    config.basePwm = constrain(pwm, -LIMIT_MAX_PWM, LIMIT_MAX_PWM);
    config.baseRPM = constrain(rpm, -LIMIT_MAX_RPM, LIMIT_MAX_RPM);
}

void Robot::handleSetMax(Robot* self, const char* params) {
    char* comma = strchr(params, ',');
    if (!comma) { self->debugger.systemMessage(F("Formato: set max <pwm>,<rpm>")); return; }
    int pwm = atoi(params);
    float rpm = atof(comma + 1);
    config.maxPwm = constrain(pwm, 0, LIMIT_MAX_PWM);
    config.maxRpm = constrain(rpm, 0, LIMIT_MAX_RPM);
}

void Robot::handleSetWeight(Robot* self, const char* params) {
    float weight = atof(params);
    if (weight <= 0) { 
        // self->debugger.systemMessage(F("Peso debe ser mayor a 0")); 
        return; 
    }
    config.robotWeight = weight;
    saveConfig();
}

void Robot::handleSetSampRate(Robot* self, const char* params) {
    char* comma1 = strchr(params, ',');
    if (!comma1) { 
        // self->debugger.systemMessage(F("Formato: set samp_rate <line_ms>,<speed_ms>,<telemetry_ms>"));
         return; 
    }
    char* comma2 = strchr(comma1 + 1, ',');
    if (!comma2) { 
        // self->debugger.systemMessage(F("Formato: set samp_rate <line_ms>,<speed_ms>,<telemetry_ms>")); 
        return; 
    }
    int lineMs = atoi(params);
    int speedMs = atoi(comma1 + 1);
    int telemetryMs = atoi(comma2 + 1);
    if (lineMs <= 0 || speedMs <= 0 || telemetryMs <= 0) {
        //  self->debugger.systemMessage(F("Valores deben ser mayores a 0")); 
         return; 
    }
    config.loopLineMs = lineMs;
    config.loopSpeedMs = speedMs;
    config.telemetryIntervalMs = telemetryMs;
    saveConfig();
}

void Robot::handleRc(Robot* self, const char* params) {
    char* comma = strchr(params, ',');
    if (!comma) { 
        // self->debugger.systemMessage(F("Formato: rc throttle,steering"));
        return;
    }
    float t = atof(params);
    float s = atof(comma + 1);
    self->throttle = t;
    self->steering = s;
}

void Robot::handleSetPwm(Robot* self, const char* params) {
    if (config.operationMode != MODE_IDLE) {
        // self->debugger.systemMessage(F("Comando solo disponible en modo idle"));
        return;
    }
    char* comma = strchr(params, ',');
    if (!comma) {
        // self->debugger.systemMessage(F("Formato: set pwm <derecha>,<izquierda>"));
        return;
    }
    // Set target RPM to 0 for PWM mode (stop motors)
    self->leftTargetRPM = 0;
    self->rightTargetRPM = 0;
}

void Robot::handleSetRpm(Robot* self, const char* params) {
    if (config.operationMode != MODE_IDLE) {
        // self->debugger.systemMessage(F("Comando solo disponible en modo idle"));
        return;
    }
    char* comma = strchr(params, ',');
    if (!comma) {
        // self->debugger.systemMessage(F("Formato: set rpm <izquierda>,<derecha>"));
        return;
    }
    float leftRPM = atof(params);
    float rightRPM = atof(comma + 1);
    self->leftTargetRPM = leftRPM;
    self->rightTargetRPM = rightRPM;
    self->leftPid.reset();
    self->rightPid.reset();
}

void Robot::handleAutoTune(Robot* self, const char* params) {
    if (self->autoTuningActive) {
        self->debugger.systemMessage(F("Auto-tuning ya está en proceso."));
        return;
    }
    
    if (config.operationMode != MODE_LINE_FOLLOWING || config.operationMode != MODE_IDLE) {
        self->debugger.systemMessage(F("Auto-tuning solo funciona en modo línea o idle"));
        return;
    }
    
    self->debugger.systemMessage(F("Auto-tuning PID iniciado. Robot debe seguir línea. Proceso: ~3min."));
    
    // Save original values
    self->originalKp = config.lineKp;
    self->originalKi = config.lineKi;
    self->originalKd = config.lineKd;
    
    // Generate test parameters (Ziegler-Nichols inspired)
    self->generateTestParameters();
    
    // Reset auto-tuning variables
    self->autoTuningActive = true;
    self->autoTuneStartTime = millis();
    self->autoTuneTestStartTime = millis();
    self->currentTestIndex = 0;
    self->bestIAE = 999999.0f;
    self->bestKp = self->originalKp;
    self->bestKi = self->originalKi;
    self->bestKd = self->originalKd;
    self->accumulatedIAE = 0;
    self->samplesCount = 0;
    self->lastPosition = 0;
    self->maxDeviation = 0;
    
    // Apply first test parameters
    config.lineKp = self->testKp[0];
    config.lineKi = self->testKi[0];
    config.lineKd = self->testKd[0];
    self->linePid.setGains(config.lineKp, config.lineKi, config.lineKd);
    
    char msg[64];
    snprintf(msg, sizeof(msg), "Probando combinación 1/%d - Kp:%.3f, Ki:%.3f, Kd:%.3f", 
             self->totalTests, (double)config.lineKp, (double)config.lineKi, (double)config.lineKd);
    self->debugger.systemMessage(msg);
}

void Robot::generateTestParameters() {
    // Generate a systematic set of PID parameters to test
    // Based on the original values, test variations around them
    
    float baseKp = config.lineKp;
    float baseKi = config.lineKi;
    float baseKd = config.lineKd;
    
    int count = 0;
    
    // Generate 6 key combinations for memory optimization
    testKp[count] = baseKp * 0.8f;   testKi[count] = baseKi * 1.0f;  testKd[count] = baseKd * 0.8f; count++;
    testKp[count] = baseKp * 1.0f;   testKi[count] = baseKi * 1.0f;  testKd[count] = baseKd * 1.0f; count++;
    testKp[count] = baseKp * 1.2f;   testKi[count] = baseKi * 1.0f;  testKd[count] = baseKd * 1.0f; count++;
    testKp[count] = baseKp * 1.0f;   testKi[count] = baseKi * 1.5f;  testKd[count] = baseKd * 1.0f; count++;
    testKp[count] = baseKp * 1.0f;   testKi[count] = baseKi * 1.0f;  testKd[count] = baseKd * 1.5f; count++;
    testKp[count] = baseKp * 1.2f;   testKi[count] = baseKi * 0.8f;  testKd[count] = baseKd * 1.2f; count++;
    
    totalTests = count;
}

void Robot::performAutoTune(float currentPosition, float dtLine) {
    if (!autoTuningActive) return;
    
    unsigned long currentTime = millis();
    unsigned long testDuration = 3000; // 3 seconds per test (optimized for memory)
    
    // Calculate IAE (Integral Absolute Error)
    float error = abs(currentPosition - 0); // Error from center line
    accumulatedIAE += error * dtLine;
    samplesCount++;
    
    // Track maximum deviation
    float deviation = abs(currentPosition);
    if (deviation > maxDeviation) {
        maxDeviation = deviation;
    }
    
    // Check if test duration exceeded, too much deviation, or line lost
    if (currentTime - autoTuneTestStartTime > testDuration || maxDeviation > 1000) {
        // If we lost the line completely, abort auto-tuning
        if (maxDeviation > 1500) {
            autoTuningActive = false;
            // Restore original values
            config.lineKp = originalKp;
            config.lineKi = originalKi;
            config.lineKd = originalKd;
            linePid.setGains(originalKp, originalKi, originalKd);
            debugger.systemMessage(F("AUTO-TUNING ABORTADO: Robot perdió la línea. Valores originales restaurados."));
            digitalWrite(MODE_LED_PIN, LOW);
            return;
        }
        float averageIAE = accumulatedIAE / samplesCount;
        
        char msg[64];
        snprintf(msg, sizeof(msg), "Test %d/%d - IAE: %.2f (Max dev: %.0f)", 
                 currentTestIndex + 1, totalTests, (double)averageIAE, (double)maxDeviation);
        debugger.systemMessage(msg);
        
        // Check if this is the best configuration so far
        if (averageIAE < bestIAE) {
            bestIAE = averageIAE;
            bestKp = config.lineKp;
            bestKi = config.lineKi;
            bestKd = config.lineKd;
            debugger.systemMessage(F("  *** NUEVO MEJOR RESULTADO ***"));
        }
        
        // Move to next test or finish
        currentTestIndex++;
        
        if (currentTestIndex >= totalTests) {
            // Auto-tuning complete
            autoTuningActive = false;
            
            // Apply best parameters found
            config.lineKp = bestKp;
            config.lineKi = bestKi;
            config.lineKd = bestKd;
            linePid.setGains(bestKp, bestKi, bestKd);
            
            debugger.systemMessage(F("=== AUTO-TUNING COMPLETADO ==="));
            
            char msg[64];
            snprintf(msg, sizeof(msg), "Mejores parámetros encontrados: Kp=%.3f, Ki=%.3f, Kd=%.3f", 
                     (double)bestKp, (double)bestKi, (double)bestKd);
            debugger.systemMessage(msg);
            
            snprintf(msg, sizeof(msg), "IAE final: %.2f", (double)bestIAE);
            debugger.systemMessage(msg);
            
            debugger.systemMessage(F("Parámetros guardados automáticamente."));
            saveConfig(); // Automatically save the new parameters
            
            digitalWrite(MODE_LED_PIN, LOW);
        } else {
            // Start next test
            autoTuneTestStartTime = currentTime;
            accumulatedIAE = 0;
            samplesCount = 0;
            maxDeviation = 0;
            lastPosition = 0;
            
            // Apply new test parameters
            config.lineKp = testKp[currentTestIndex];
            config.lineKi = testKi[currentTestIndex];
            config.lineKd = testKd[currentTestIndex];
            linePid.setGains(config.lineKp, config.lineKi, config.lineKd);
            
            char msg[64];
            snprintf(msg, sizeof(msg), "Probando combinación %d/%d - Kp:%.3f, Ki:%.3f, Kd:%.3f", 
                     currentTestIndex + 1, totalTests, (double)config.lineKp, (double)config.lineKi, (double)config.lineKd);
            debugger.systemMessage(msg);
        }
    }
    
    lastPosition = currentPosition;
}
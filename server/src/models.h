/*********************************************************************
 *  models.h  –  versión simplificada con CSV
 *  Copiar-pegar tal cual en tu proyecto
 *********************************************************************/
#ifndef MODELS_H
#define MODELS_H

#include <Arduino.h>
#include <string.h>

// Global dispatch function
void dispatchCommand(String line);

/* ===================== TUS ENUMS ===================== */
enum MessageType : uint8_t {
    MSG_SYSTEM = 0,
    MSG_COMMAND_ACK = 1,
    MSG_UNIFIED_TELEMETRY = 2
};

enum CommandType : uint8_t {
    CMD_SET_PID = 0,
    CMD_SET_SPEED = 1,
    CMD_SET_MODE = 2,
    CMD_CALIBRATE = 3,
    CMD_START = 4,
    CMD_STOP = 5,
    CMD_GET_STATUS = 6,
    CMD_TOGGLE_TELEMETRY = 7
};
/* ===================================================== */

/* ================= TUS STRUCTS ================ */
struct SystemMessage {  uint8_t type;  char message[64]; };
struct TelemetryMessage {
    uint8_t type;
    uint32_t timestamp;
    uint8_t operationMode;
    uint8_t robotState;
    int16_t pwmLeft;
    int16_t pwmRight;
    float rpmLeft;
    float rpmRight;
    float distanceTraveled;
    float ultrasonicDistance;
    int16_t sensors[6];
    int16_t sensorError;
    int16_t sensorSum;
    float odometryX;
    float odometryY;
    float odometryTheta;
    float linePidKp;
    float linePidKi;
    float linePidKd;
    float linePidIntegral;
    float motorPidKp;
    float motorPidKi;
    float motorPidKd;
    float motorPidIntegral;
    uint8_t remoteConnected;
    int16_t remoteLeftSpeed;
    int16_t remoteRightSpeed;
};
/* -------- comandos entrantes -------- */
struct CommandHeader { uint8_t type; };
struct SetPidCommand { uint8_t type; float kp,ki,kd; };
struct SetSpeedCommand { uint8_t type; int16_t speed; };
struct SetModeCommand { uint8_t type; uint8_t mode; };
struct CalibrateCommand { uint8_t type; };
/* ======================================================== */

class CommunicationSerializer
{
public:
    /* ================= ENVÍO DE MENSAJES ================= */

    static void sendSystemMessage(const char* txt)
    {
        String csv = String(MSG_SYSTEM) + "," + String(txt);
        Serial.println(csv);
    }

    static void sendCommandAck(uint8_t cmdType)
    {
        String csv = String(MSG_COMMAND_ACK) + "," + String(cmdType);
        Serial.println(csv);
    }

    static void sendUnifiedTelemetry(const TelemetryMessage& msg)
    {
        // Add pure noise to sensors for testing
        int16_t noisySensors[6];
        for (int i = 0; i < 6; i++) {
            noisySensors[i] = msg.sensors[i] + 0;
        }

        String csv = String((int)MSG_UNIFIED_TELEMETRY) + "," + String(msg.timestamp) + "," + String(msg.operationMode) + "," + String(msg.robotState) + "," +
                     String(msg.pwmLeft) + "," + String(msg.pwmRight) + "," + String(msg.rpmLeft, 2) + "," + String(msg.rpmRight, 2) + "," +
                     String(msg.distanceTraveled, 2) + "," + String(msg.ultrasonicDistance, 2) + "," +
                    //  String(noisySensors[0]) + "," + String(noisySensors[1]) + "," + String(noisySensors[2]) + "," + String(noisySensors[3]) + "," + String(noisySensors[4]) + "," + String(noisySensors[5]) + "," +
                    //  String(msg.sensorError) + "," + String(msg.sensorSum) + "," + String(msg.odometryX, 2) + "," + String(msg.odometryY, 2) + "," + String(msg.odometryTheta, 2) + "," +
                    //  String(msg.linePidKp, 2) + "," + String(msg.linePidKi, 3) + "," + String(msg.linePidKd, 2) + "," + String(msg.linePidIntegral, 2) + "," +
                    //  String(msg.motorPidKp, 2) + "," + String(msg.motorPidKi, 3) + "," + String(msg.motorPidKd, 2) + "," + String(msg.motorPidIntegral, 2) + "," +
                    //  String(msg.remoteConnected) + "," + String(msg.remoteLeftSpeed) + "," + String(msg.remoteRightSpeed);
        Serial.println(csv);
    }

    /* ------------- RECEPCIÓN (llamar en loop) ------------- */

    static void parseStream()
    {
        while (Serial.available())
        {
            String line = Serial.readStringUntil('\n');
            if (line.length() > 0)
            {
                dispatchCommand(line);
            }
        }
    }

private:
};

#endif   // MODELS_H
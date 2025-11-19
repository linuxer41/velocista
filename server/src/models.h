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
    MSG_SENSOR_DATA = 1,
    MSG_ODOMETRY = 2,
    MSG_STATE = 3,
    MSG_MODE_CHANGE = 4,
    MSG_PID_TUNING = 5,
    MSG_COMPETITION = 6,
    MSG_REMOTE_STATUS = 7,
    MSG_COMMAND_ACK = 8
};

enum CommandType : uint8_t {
    CMD_SET_PID = 0,
    CMD_SET_SPEED = 1,
    CMD_SET_MODE = 2,
    CMD_CALIBRATE = 3,
    CMD_START = 4,
    CMD_STOP = 5,
    CMD_GET_STATUS = 6
};
/* ===================================================== */

/* ================= TUS STRUCTS (intactos) ================ */
struct SystemMessage {  uint8_t type;  char message[64]; };
struct SensorDataMessage {
    uint8_t type;  uint32_t timestamp;  int16_t sensors[6];
    int16_t error; int16_t sum;
};
struct OdometryMessage {
    uint8_t type;  uint32_t timestamp;  float x,y,theta;
};
struct StateMessage {
    uint8_t type;  uint32_t timestamp;  uint8_t state;  float distance;
};
struct ModeChangeMessage {
    uint8_t type;  uint8_t oldMode,newMode,serialEnabled;
};
struct PidTuningMessage {
    uint8_t type;  float kp,ki,kd,integral;
};
struct CompetitionMessage {
    uint8_t type;  uint8_t mode,lapCount;  uint32_t time;
};
struct RemoteStatusMessage {
    uint8_t type;  uint8_t connected;  int16_t leftSpeed,rightSpeed;
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

    static void sendSensorData(uint32_t ts, const int16_t s[6], int16_t err, int16_t sum)
    {
        String csv = String(MSG_SENSOR_DATA) + "," + String(ts);
        for (int i = 0; i < 6; i++)
        {
            csv += "," + String(s[i]);
        }
        csv += "," + String(err) + "," + String(sum);
        Serial.println(csv);
    }

    static void sendOdometry(uint32_t ts, float x, float y, float th)
    {
        String csv = String(MSG_ODOMETRY) + "," + String(ts) + "," + String(x, 6) + "," + String(y, 6) + "," + String(th, 6);
        Serial.println(csv);
    }

    static void sendState(uint32_t ts, uint8_t st, float dist)
    {
        String csv = String(MSG_STATE) + "," + String(ts) + "," + String(st) + "," + String(dist, 6);
        Serial.println(csv);
    }

    static void sendModeChange(uint8_t oldM, uint8_t newM, uint8_t serEn)
    {
        String csv = String(MSG_MODE_CHANGE) + "," + String(oldM) + "," + String(newM) + "," + String(serEn);
        Serial.println(csv);
    }

    static void sendPidTuning(float kp, float ki, float kd, float integ)
    {
        String csv = String(MSG_PID_TUNING) + "," + String(kp, 6) + "," + String(ki, 6) + "," + String(kd, 6) + "," + String(integ, 6);
        Serial.println(csv);
    }

    static void sendCompetition(uint8_t mode, uint32_t time, uint8_t laps)
    {
        String csv = String(MSG_COMPETITION) + "," + String(mode) + "," + String(time) + "," + String(laps);
        Serial.println(csv);
    }

    static void sendRemoteStatus(uint8_t conn, int16_t lSp, int16_t rSp)
    {
        String csv = String(MSG_REMOTE_STATUS) + "," + String(conn) + "," + String(lSp) + "," + String(rSp);
        Serial.println(csv);
    }

    static void sendCommandAck(uint8_t cmdType)
    {
        String csv = String(MSG_COMMAND_ACK) + "," + String(cmdType);
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
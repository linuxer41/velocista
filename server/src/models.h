/**
 * ARCHIVO: models.h
 * DESCRIPCIÓN: Definiciones de mensajes binarios para comunicación
 * FUNCIONALIDAD: Serialización/deserialización binaria, centralización de salida
 */

#ifndef MODELS_H
#define MODELS_H

#include <Arduino.h>

// Tipos de mensajes
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

// Comandos entrantes
enum CommandType : uint8_t {
    CMD_SET_PID = 0,
    CMD_SET_SPEED = 1,
    CMD_SET_MODE = 2,
    CMD_CALIBRATE = 3,
    CMD_START = 4,
    CMD_STOP = 5,
    CMD_GET_STATUS = 6
};

// Estructuras de mensajes salientes
struct SystemMessage {
    uint8_t type;
    char message[64];
};

struct SensorDataMessage {
    uint8_t type;
    uint32_t timestamp;
    int16_t sensors[6];
    int16_t error;
    int16_t sum;
};

struct OdometryMessage {
    uint8_t type;
    uint32_t timestamp;
    float x;
    float y;
    float theta;
};

struct StateMessage {
    uint8_t type;
    uint32_t timestamp;
    uint8_t state;
    float distance;
};

struct ModeChangeMessage {
    uint8_t type;
    uint8_t oldMode;
    uint8_t newMode;
    uint8_t serialEnabled;
};

struct PidTuningMessage {
    uint8_t type;
    float kp;
    float ki;
    float kd;
    float integral;
};

struct CompetitionMessage {
    uint8_t type;
    uint8_t mode;
    uint32_t time;
    uint8_t lapCount;
};

struct RemoteStatusMessage {
    uint8_t type;
    uint8_t connected;
    int16_t leftSpeed;
    int16_t rightSpeed;
};

// Estructuras de comandos entrantes
struct CommandHeader {
    uint8_t type;
};

struct SetPidCommand {
    uint8_t type;
    float kp;
    float ki;
    float kd;
};

struct SetSpeedCommand {
    uint8_t type;
    int16_t speed;
};

struct SetModeCommand {
    uint8_t type;
    uint8_t mode;
};

struct CalibrateCommand {
    uint8_t type;
};

// Clase centralizada para serialización
class CommunicationSerializer {
public:
    // Métodos para enviar mensajes
    static void sendSystemMessage(const char* message) {
        SystemMessage msg;
        msg.type = MSG_SYSTEM;
        strncpy(msg.message, message, sizeof(msg.message) - 1);
        msg.message[sizeof(msg.message) - 1] = '\0';
        writeMessage(&msg, sizeof(msg));
    }

    static void sendSensorData(uint32_t timestamp, const int16_t sensors[6], int16_t error, int16_t sum) {
        SensorDataMessage msg;
        msg.type = MSG_SENSOR_DATA;
        msg.timestamp = timestamp;
        memcpy(msg.sensors, sensors, sizeof(msg.sensors));
        msg.error = error;
        msg.sum = sum;
        writeMessage(&msg, sizeof(msg));
    }

    static void sendOdometry(uint32_t timestamp, float x, float y, float theta) {
        OdometryMessage msg;
        msg.type = MSG_ODOMETRY;
        msg.timestamp = timestamp;
        msg.x = x;
        msg.y = y;
        msg.theta = theta;
        writeMessage(&msg, sizeof(msg));
    }

    static void sendState(uint32_t timestamp, uint8_t state, float distance) {
        StateMessage msg;
        msg.type = MSG_STATE;
        msg.timestamp = timestamp;
        msg.state = state;
        msg.distance = distance;
        writeMessage(&msg, sizeof(msg));
    }

    static void sendModeChange(uint8_t oldMode, uint8_t newMode, uint8_t serialEnabled) {
        ModeChangeMessage msg;
        msg.type = MSG_MODE_CHANGE;
        msg.oldMode = oldMode;
        msg.newMode = newMode;
        msg.serialEnabled = serialEnabled;
        writeMessage(&msg, sizeof(msg));
    }

    static void sendPidTuning(float kp, float ki, float kd, float integral) {
        PidTuningMessage msg;
        msg.type = MSG_PID_TUNING;
        msg.kp = kp;
        msg.ki = ki;
        msg.kd = kd;
        msg.integral = integral;
        writeMessage(&msg, sizeof(msg));
    }

    static void sendCompetition(uint8_t mode, uint32_t time, uint8_t lapCount) {
        CompetitionMessage msg;
        msg.type = MSG_COMPETITION;
        msg.mode = mode;
        msg.time = time;
        msg.lapCount = lapCount;
        writeMessage(&msg, sizeof(msg));
    }

    static void sendRemoteStatus(uint8_t connected, int16_t leftSpeed, int16_t rightSpeed) {
        RemoteStatusMessage msg;
        msg.type = MSG_REMOTE_STATUS;
        msg.connected = connected;
        msg.leftSpeed = leftSpeed;
        msg.rightSpeed = rightSpeed;
        writeMessage(&msg, sizeof(msg));
    }

    static void sendCommandAck(uint8_t commandType) {
        uint8_t msg[2] = {MSG_COMMAND_ACK, commandType};
        writeMessage(msg, sizeof(msg));
    }

    // Método para procesar comandos entrantes (binarios)
    static bool processBinaryCommand(const uint8_t* buffer, size_t length) {
        if (length < 1) return false;
        uint8_t type = buffer[0];
        switch (type) {
            case CMD_SET_PID: {
                if (length < sizeof(SetPidCommand)) return false;
                SetPidCommand* cmd = (SetPidCommand*)buffer;
                // Aquí se aplicaría el comando, pero se deja para main.cpp
                return true;
            }
            case CMD_SET_SPEED: {
                if (length < sizeof(SetSpeedCommand)) return false;
                SetSpeedCommand* cmd = (SetSpeedCommand*)buffer;
                return true;
            }
            case CMD_SET_MODE: {
                if (length < sizeof(SetModeCommand)) return false;
                SetModeCommand* cmd = (SetModeCommand*)buffer;
                return true;
            }
            case CMD_CALIBRATE: {
                if (length < sizeof(CalibrateCommand)) return false;
                return true;
            }
            case CMD_START:
            case CMD_STOP:
            case CMD_GET_STATUS: {
                return true;
            }
            default:
                return false;
        }
    }

private:
    // Funciones auxiliares de serialización
    static void writeMessage(const void* data, size_t size) {
        Serial.write((const uint8_t*)data, size);
    }
};

#endif
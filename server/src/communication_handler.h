/**
 * ARCHIVO: communication_handler.h  
 * DESCRIPCIÓN: Manejo de comunicación serial con JSON
 * FUNCIONALIDAD: Procesamiento de comandos, respuestas, parsing JSON
 */

#ifndef COMMUNICATION_HANDLER_H
#define COMMUNICATION_HANDLER_H

#include <ArduinoJson.h>
#include "motor_controller.h"
#include "advanced_pid.h"
#include "competition_manager.h"
#include "remote_control.h"

class CommunicationHandler {
private:
    MotorController& motorCtrl;
    AdvancedPID& linePID;
    CompetitionManager& compManager;
    RemoteControl& remoteCtrl;
    StaticJsonDocument<1024> jsonDoc;
    
public:
    /**
     * Constructor
     * @param motors Referencia a controlador de motores
     * @param pid Referencia a controlador PID
     * @param compMgr Referencia a gestor de competencia
     * @param remote Referencia a control remoto
     */
    CommunicationHandler(MotorController& motors, AdvancedPID& pid, 
                        CompetitionManager& compMgr, RemoteControl& remote) 
        : motorCtrl(motors), linePID(pid), compManager(compMgr), remoteCtrl(remote) {}
    
    /**
     * Procesar comando recibido por serial
     * @param command Comando en formato String
     */
    void processCommand(const String& command) {
        // Intentar procesar como comando de control remoto primero
        if (remoteCtrl.processCommand(command)) {
            return;
        }
        
        // Procesar como comando JSON general
        if (command.startsWith("{")) {
            processJSONCommand(command);
        } else {
            processSimpleCommand(command);
        }
    }
    
private:
    /**
     * Procesar comando en formato JSON
     * @param jsonStr String con comando JSON
     */
    void processJSONCommand(const String& jsonStr) {
        DeserializationError error = deserializeJson(jsonDoc, jsonStr);
        
        if (error) {
            sendError("Error parsing JSON: " + String(error.c_str()));
            return;
        }
        
        const char* command = jsonDoc["command"];
        if (!command) {
            sendError("No command specified in JSON");
            return;
        }
        
        // Procesar comandos específicos
        if (strcmp(command, "start") == 0) {
            int speed = jsonDoc["speed"] | DEFAULT_BASE_SPEED;
            motorCtrl.setBaseSpeed(speed);
            sendResponse("start", "Robot iniciado con velocidad: " + String(speed));
        }
        else if (strcmp(command, "stop") == 0) {
            motorCtrl.stopAll();
            sendResponse("stop", "Robot detenido");
        }
        else if (strcmp(command, "set_pid") == 0) {
            double kp = jsonDoc["kp"] | DEFAULT_KP;
            double ki = jsonDoc["ki"] | DEFAULT_KI;
            double kd = jsonDoc["kd"] | DEFAULT_KD;
            linePID.setGains(kp, ki, kd);
            sendResponse("set_pid", 
                "PID actualizado - Kp: " + String(kp, 4) + 
                ", Ki: " + String(ki, 4) + 
                ", Kd: " + String(kd, 4));
        }
        else if (strcmp(command, "set_speed") == 0) {
            int speed = jsonDoc["speed"] | DEFAULT_BASE_SPEED;
            motorCtrl.setBaseSpeed(speed);
            sendResponse("set_speed", "Velocidad base establecida: " + String(speed));
        }
        else if (strcmp(command, "set_rc_limits") == 0) {
            int deadzone = jsonDoc["deadzone"] | RC_DEADZONE;
            int maxThrottle = jsonDoc["max_throttle"] | RC_MAX_THROTTLE;
            int maxSteering = jsonDoc["max_steering"] | RC_MAX_STEERING;
            remoteCtrl.setLimits(deadzone, maxThrottle, maxSteering);
            sendResponse("set_rc_limits", 
                "Límites RC actualizados - Deadzone: " + String(deadzone) +
                ", Max Throttle: " + String(maxThrottle) +
                ", Max Steering: " + String(maxSteering));
        }
        else if (strcmp(command, "set_mode") == 0) {
            const char* modeStr = jsonDoc["mode"];
            if (modeStr) {
                setOperationMode(String(modeStr));
            } else {
                sendError("No mode specified");
            }
        }
        else if (strcmp(command, "calibrate_sensors") == 0) {
            sendResponse("calibrate_sensors", "Iniciando calibración de sensores...");
            // La calibración se manejará en el loop principal
        }
        else if (strcmp(command, "get_status") == 0) {
            sendCompleteStatus();
        }
        else if (strcmp(command, "get_sensor_data") == 0) {
            sendResponse("get_sensor_data", "Solicitando datos de sensores...");
        }
        else if (strcmp(command, "reset_odometry") == 0) {
            sendResponse("reset_odometry", "Odometría resetada");
        }
        else if (strcmp(command, "save_config") == 0) {
            sendResponse("save_config", "Configuración guardada en EEPROM");
        }
        else {
            sendError("Comando no reconocido: " + String(command));
        }
    }
    
    /**
     * Procesar comandos simples (legacy)
     * @param command Comando simple
     */
    void processSimpleCommand(const String& command) {
        if (command == "START") {
            motorCtrl.setBaseSpeed(DEFAULT_BASE_SPEED);
            sendResponse("start", "Robot iniciado");
        }
        else if (command == "STOP") {
            motorCtrl.stopAll();
            sendResponse("stop", "Robot detenido");
        }
        else if (command.startsWith("VEL")) {
            int speed = command.substring(4).toInt();
            motorCtrl.setBaseSpeed(speed);
            sendResponse("set_speed", "Velocidad: " + String(speed));
        }
        else if (command == "MODE_RC") {
            compManager.setMode(MODE_REMOTE_CONTROL);
            sendResponse("mode_change", "Modo Control Remoto activado");
        }
        else if (command == "MODE_COMP") {
            compManager.setMode(MODE_COMPETITION);
            sendResponse("mode_change", "Modo Competencia activado");
        }
        else if (command == "MODE_CAL") {
            compManager.setMode(MODE_CALIBRATION);
            sendResponse("mode_change", "Modo Calibración activado");
        }
        else if (command == "STATUS") {
            sendCompleteStatus();
        }
        else {
            sendResponse("error", "Comando no reconocido: " + command);
        }
    }
    
    /**
     * Establecer modo de operación
     * @param modeStr String con nombre del modo
     */
    void setOperationMode(const String& modeStr) {
        if (modeStr == "remote_control") {
            compManager.setMode(MODE_REMOTE_CONTROL);
            sendResponse("set_mode", "Modo Control Remoto activado");
        } else if (modeStr == "competition") {
            compManager.setMode(MODE_COMPETITION);
            sendResponse("set_mode", "Modo Competencia activado");
        } else if (modeStr == "calibration") {
            compManager.setMode(MODE_CALIBRATION);
            sendResponse("set_mode", "Modo Calibración activado");
        } else if (modeStr == "debug") {
            compManager.setMode(MODE_DEBUG);
            sendResponse("set_mode", "Modo Debug activado");
        } else if (modeStr == "tuning") {
            compManager.setMode(MODE_TUNING);
            sendResponse("set_mode", "Modo Tuning activado");
        } else {
            sendError("Modo no válido: " + modeStr);
        }
    }
    
    /**
     * Enviar respuesta JSON
     * @param type Tipo de respuesta
     * @param message Mensaje descriptivo
     */
    void sendResponse(const String& type, const String& message) {
        StaticJsonDocument<256> doc;
        doc["type"] = "response";
        doc["command"] = type;
        doc["message"] = message;
        doc["timestamp"] = millis();
        
        String jsonString;
        serializeJson(doc, jsonString);
        Serial.println(jsonString);
    }
    
    /**
     * Enviar error JSON
     * @param message Mensaje de error
     */
    void sendError(const String& message) {
        StaticJsonDocument<256> doc;
        doc["type"] = "error";
        doc["message"] = message;
        doc["timestamp"] = millis();
        
        String jsonString;
        serializeJson(doc, jsonString);
        Serial.println(jsonString);
    }
    
    /**
     * Enviar estado completo del robot
     */
    void sendCompleteStatus() {
        StaticJsonDocument<512> doc;
        doc["type"] = "complete_status";
        doc["base_speed"] = motorCtrl.getBaseSpeed();
        doc["max_speed"] = motorCtrl.getMaxSpeed();
        doc["mode"] = compManager.getModeString();
        doc["safety"] = motorCtrl.isSafetyEnabled();
        doc["timestamp"] = millis();
        
        String jsonString;
        serializeJson(doc, jsonString);
        Serial.println(jsonString);
    }
};

#endif
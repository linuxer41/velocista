/**
 * ARCHIVO: remote_control.h
 * DESCRIPCIÓN: Sistema de control remoto vía JSON
 * FUNCIONALIDAD: Recepción de comandos, cálculo de velocidades, timeout
 */

#ifndef REMOTE_CONTROL_H
#define REMOTE_CONTROL_H

#include <Arduino.h>
#include <ArduinoJson.h>
#include "config.h"

class RemoteControl {
private:
    // Estructura para datos de control
    struct ControlData {
        int throttle;    // -255 a 255 (velocidad adelante/atrás)
        int steering;    // -255 a 255 (giro izquierda/derecha)
        bool turbo;      // Modo turbo (velocidad aumentada)
        bool brake;      // Freno emergencia
        int leftSpeed;   // Velocidad calculada motor izquierdo
        int rightSpeed;  // Velocidad calculada motor derecho
    };
    
    ControlData currentControl;
    int deadzone;           // Zona muerta para joystick
    int maxThrottle;        // Throttle máximo
    int maxSteering;        // Steering máximo
    unsigned long lastCommandTime; // Tiempo último comando
    bool connected;         // Estado de conexión
    
public:
    /**
     * Constructor - inicializa con valores por defecto
     */
    RemoteControl() {
        reset();
        deadzone = RC_DEADZONE;
        maxThrottle = RC_MAX_THROTTLE;
        maxSteering = RC_MAX_STEERING;
        lastCommandTime = 0;
        connected = false;
    }
    
    /**
     * Resetear datos de control a valores neutros
     */
    void reset() {
        currentControl.throttle = 0;
        currentControl.steering = 0;
        currentControl.turbo = false;
        currentControl.brake = false;
        currentControl.leftSpeed = 0;
        currentControl.rightSpeed = 0;
    }
    
    /**
     * Procesar comando JSON de control remoto
     * @param jsonStr String JSON con datos de control
     * @return true si el comando fue procesado exitosamente
     */
    bool processCommand(const String& jsonStr) {
        StaticJsonDocument<256> doc;
        DeserializationError error = deserializeJson(doc, jsonStr);
        
        if (error) {
            return false;
        }
        
        const char* type = doc["type"];
        if (!type || strcmp(type, "remote_control") != 0) {
            return false;
        }
        
        // Extraer datos del JSON
        currentControl.throttle = doc["throttle"] | 0;
        currentControl.steering = doc["steering"] | 0;
        currentControl.turbo = doc["turbo"] | false;
        currentControl.brake = doc["brake"] | false;
        
        // Validar rangos
        currentControl.throttle = constrain(currentControl.throttle, -255, 255);
        currentControl.steering = constrain(currentControl.steering, -255, 255);
        
        // Aplicar deadzone
        applyDeadzone();
        
        // Calcular velocidades de motores
        calculateMotorSpeeds();
        
        lastCommandTime = millis();
        connected = true;
        
        return true;
    }
    
    /**
     * Aplicar zona muerta a los valores de control
     */
    void applyDeadzone() {
        if (abs(currentControl.throttle) < deadzone) {
            currentControl.throttle = 0;
        }
        if (abs(currentControl.steering) < deadzone) {
            currentControl.steering = 0;
        }
    }
    
    /**
     * Calcular velocidades individuales de motores
     */
    void calculateMotorSpeeds() {
        if (currentControl.brake) {
            // Freno de emergencia - detener motores
            currentControl.leftSpeed = 0;
            currentControl.rightSpeed = 0;
            return;
        }
        
        int throttle = currentControl.throttle;
        int steering = currentControl.steering;
        
        // Aplicar turbo si está activado
        if (currentControl.turbo) {
            throttle = constrain(throttle * 2, -maxThrottle, maxThrottle);
            steering = constrain(steering * 2, -maxSteering, maxSteering);
        }
        
        // Cálculo diferencial para motores (tank drive)
        currentControl.leftSpeed = throttle + steering;
        currentControl.rightSpeed = throttle - steering;
        
        // Limitar velocidades a rangos seguros
        currentControl.leftSpeed = constrain(currentControl.leftSpeed, -maxThrottle, maxThrottle);
        currentControl.rightSpeed = constrain(currentControl.rightSpeed, -maxThrottle, maxThrottle);
    }
    
    /**
     * Verificar timeout de conexión
     */
    void checkConnection() {
        if (millis() - lastCommandTime > 1000) { // Timeout de 1 segundo
            connected = false;
            reset();
        }
    }
    
    // Getters
    int getLeftSpeed() const { return currentControl.leftSpeed; }
    int getRightSpeed() const { return currentControl.rightSpeed; }
    int getThrottle() const { return currentControl.throttle; }
    int getSteering() const { return currentControl.steering; }
    bool isTurboActive() const { return currentControl.turbo; }
    bool isBrakeActive() const { return currentControl.brake; }
    bool isConnected() const { return connected; }
    unsigned long getTimeSinceLastCommand() const { return millis() - lastCommandTime; }
    
    /**
     * Configurar límites de control
     * @param newDeadzone Nueva zona muerta
     * @param newMaxThrottle Nuevo throttle máximo
     * @param newMaxSteering Nuevo steering máximo
     */
    void setLimits(int newDeadzone, int newMaxThrottle, int newMaxSteering) {
        deadzone = newDeadzone;
        maxThrottle = newMaxThrottle;
        maxSteering = newMaxSteering;
    }
    
    /**
     * Generar JSON con estado del control remoto
     * @return String JSON con estado
     */
    String getStatusJSON() {
        StaticJsonDocument<512> doc;
        doc["type"] = "remote_status";
        doc["connected"] = connected;
        doc["throttle"] = currentControl.throttle;
        doc["steering"] = currentControl.steering;
        doc["left_speed"] = currentControl.leftSpeed;
        doc["right_speed"] = currentControl.rightSpeed;
        doc["turbo"] = currentControl.turbo;
        doc["brake"] = currentControl.brake;
        doc["deadzone"] = deadzone;
        doc["max_throttle"] = maxThrottle;
        doc["max_steering"] = maxSteering;
        doc["time_since_last_command"] = millis() - lastCommandTime;
        
        String jsonString;
        serializeJson(doc, jsonString);
        return jsonString;
    }
};

#endif
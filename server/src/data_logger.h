/**
 * ARCHIVO: data_logger.h
 * DESCRIPCIÓN: Sistema de logging de datos para análisis
 * FUNCIONALIDAD: Registro de datos en formato JSON, control de logging
 */

#ifndef DATA_LOGGER_H
#define DATA_LOGGER_H

#include <Arduino.h>
#include <ArduinoJson.h>

class DataLogger {
private:
    unsigned long logStartTime;  // Tiempo de inicio del logging
    bool loggingActive;          // Estado del logging
    unsigned long logInterval;   // Intervalo entre logs (ms)
    unsigned long lastLogTime;   // Último tiempo de log
    
public:
    /**
     * Constructor - inicializa con logging desactivado
     */
    DataLogger() : logStartTime(0), loggingActive(false), logInterval(100), lastLogTime(0) {}
    
    /**
     * Iniciar sistema de logging
     */
    void startLogging() {
        logStartTime = millis();
        loggingActive = true;
        lastLogTime = millis();
        
        // Enviar cabecera con columnas
        StaticJsonDocument<256> doc;
        doc["type"] = "log_header";
        doc["columns"] = "time,error,left_pwm,right_pwm,left_rpm,right_rpm,state";
        doc["interval"] = logInterval;
        doc["start_time"] = logStartTime;
        
        String jsonString;
        serializeJson(doc, jsonString);
        Serial.println(jsonString);
    }
    
    /**
     * Detener sistema de logging
     */
    void stopLogging() {
        loggingActive = false;
        
        StaticJsonDocument<128> doc;
        doc["type"] = "log_stop";
        doc["duration"] = millis() - logStartTime;
        
        String jsonString;
        serializeJson(doc, jsonString);
        Serial.println(jsonString);
    }
    
    /**
     * Registrar datos del robot
     * @param error Error de seguimiento de línea
     * @param leftPWM PWM motor izquierdo
     * @param rightPWM PWM motor derecho
     * @param leftRPM RPM motor izquierdo
     * @param rightRPM RPM motor derecho
     * @param state Estado actual del robot
     */
    void logData(int error, int leftPWM, int rightPWM, float leftRPM, float rightRPM, const String& state) {
        if (!loggingActive) return;
        
        unsigned long currentTime = millis();
        if (currentTime - lastLogTime < logInterval) {
            return; // Esperar hasta que pase el intervalo
        }
        
        StaticJsonDocument<512> doc;
        doc["type"] = "log_data";
        doc["time"] = currentTime - logStartTime;
        doc["error"] = error;
        doc["left_pwm"] = leftPWM;
        doc["right_pwm"] = rightPWM;
        doc["left_rpm"] = round(leftRPM * 10) / 10.0; // 1 decimal
        doc["right_rpm"] = round(rightRPM * 10) / 10.0;
        doc["state"] = state;
        
        String jsonString;
        serializeJson(doc, jsonString);
        Serial.println(jsonString);
        
        lastLogTime = currentTime;
    }
    
    /**
     * Verificar si el logging está activo
     * @return true si el logging está activo
     */
    bool isLoggingActive() const { return loggingActive; }
    
    /**
     * Establecer intervalo de logging
     * @param interval Intervalo en ms
     */
    void setLogInterval(unsigned long interval) { 
        logInterval = interval; 
    }
    
    /**
     * Obtener intervalo actual de logging
     * @return Intervalo en ms
     */
    unsigned long getLogInterval() const { return logInterval; }
    
    /**
     * Obtener duración del logging actual
     * @return Duración en ms
     */
    unsigned long getLogDuration() const { 
        return loggingActive ? millis() - logStartTime : 0; 
    }
};

#endif
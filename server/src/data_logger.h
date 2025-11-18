/**
 * ARCHIVO: data_logger.h
 * DESCRIPCIÓN: Sistema de logging de datos para análisis
 * FUNCIONALIDAD: Registro de datos en formato JSON, control de logging
 */

#ifndef DATA_LOGGER_H
#define DATA_LOGGER_H

#include <Arduino.h>

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
    }
    
    /**
     * Detener sistema de logging
     */
    void stopLogging() {
        loggingActive = false;
    }
    
    /**
     * Registrar datos del robot (simulado, sin logging real)
     */
    void logData(int error, int leftPWM, int rightPWM, float leftRPM, float rightRPM, const String& state) {
        // Logging desactivado para reducir tamaño
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
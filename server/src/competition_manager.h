/**
 * ARCHIVO: competition_manager.h
 * DESCRIPCIÓN: Gestor de modos de operación del robot
 * FUNCIONALIDAD: Cambio entre modos, gestión de tiempos de vuelta
 */

#ifndef COMPETITION_MANAGER_H
#define COMPETITION_MANAGER_H

#include <Arduino.h>
#include "config.h"
#include "models.h"

class CompetitionManager {
private:
    OperationMode currentMode;   // Modo actual de operación
    bool serialEnabled;          // Habilitar comunicación serial
    unsigned long competitionStartTime; // Tiempo inicio competencia
    float lapTimes[10];          // Array de tiempos de vuelta
    int currentLap;              // Vuelta actual
    
public:
    /**
     * Constructor
     */
    CompetitionManager() : currentMode(MODE_DEBUG), serialEnabled(true),
                          currentLap(0) {
        // Inicializar array de tiempos
        for (int i = 0; i < 10; i++) {
            lapTimes[i] = 0.0;
        }

        CommunicationSerializer::sendSystemMessage("Gestor de competencia inicializado");
    }
    
    /**
     * Verificar y cambiar modo de operación
     * Nota: En esta versión, los modos se cambian por comando serial
     */
    void checkMode() {
        // Los modos se cambian por comandos seriales en esta implementación
        // Se puede expandir para usar pulsador físico
    }
    
    /**
     * Establecer modo de operación
     * @param mode Nuevo modo a establecer
     */
    void setMode(OperationMode mode) {
        if (mode == currentMode) return;
        
        OperationMode oldMode = currentMode;
        currentMode = mode;
        
        // Configurar según modo
        switch (mode) {
            case MODE_COMPETITION:
                serialEnabled = false; // Máxima performance
                competitionStartTime = millis();
                currentLap = 0;
                break;
                
            case MODE_REMOTE_CONTROL:
                serialEnabled = true; // Necesita serial para comandos
                break;
                
            case MODE_DEBUG:
            case MODE_TUNING:
            case MODE_CALIBRATION:
                serialEnabled = true; // Comunicación completa
                break;
        }
        
        // Notificar cambio de modo
        if (serialEnabled) {
            // Notificación binaria se maneja desde main.cpp
        }
    }
    
    /**
     * Verificar si comunicación serial está habilitada
     * @return true si serial está habilitado
     */
    bool isSerialEnabled() const { return serialEnabled; }
    
    /**
     * Obtener modo actual de operación
     * @return Modo actual
     */
    OperationMode getCurrentMode() const { return currentMode; }
    
    /**
     * Registrar tiempo de vuelta
     */
    void recordLapTime() {
        if (currentLap < 10) {
            lapTimes[currentLap] = (millis() - competitionStartTime) / 1000.0;
            currentLap++;
            competitionStartTime = millis();
            
            if (serialEnabled) {
                // Skip lap time logging to save space
            }
        }
    }
    
    
    /**
     * Obtener string del modo actual
     * @return String descriptivo del modo
     */
    String getModeString() const {
        return modeToString(currentMode);
    }
    
    /**
     * Obtener tiempo de vuelta específico
     * @param lap Número de vuelta (0-9)
     * @return Tiempo en segundos, 0 si no existe
     */
    float getLapTime(int lap) const {
        if (lap >= 0 && lap < currentLap) {
            return lapTimes[lap];
        }
        return 0.0;
    }
    
    /**
     * Obtener número de vueltas registradas
     * @return Cantidad de vueltas
     */
    int getLapCount() const { return currentLap; }
    
private:
    /**
     * Convertir modo a string
     * @param mode Modo de operación
     * @return String descriptivo
     */
    String modeToString(OperationMode mode) const {
        switch (mode) {
            case MODE_CALIBRATION: return "CALIBRATION";
            case MODE_COMPETITION: return "COMPETITION";
            case MODE_TUNING: return "TUNING";
            case MODE_DEBUG: return "DEBUG";
            case MODE_REMOTE_CONTROL: return "REMOTE_CONTROL";
            default: return "UNKNOWN";
        }
    }
};

#endif
/**
 * ARCHIVO: state_machine.h
 * DESCRIPCIÓN: Máquina de estados del robot seguidor de línea
 * FUNCIONALIDAD: Transiciones entre estados, comportamiento autónomo
 */

#ifndef STATE_MACHINE_H
#define STATE_MACHINE_H

#include <Arduino.h>
#include <ArduinoJson.h>
#include "config.h"

// Estados del robot
enum RobotState {
    STATE_FOLLOWING_LINE,      // Siguiendo línea normal
    STATE_TURNING_RIGHT,       // Giro derecho
    STATE_TURNING_LEFT,        // Giro izquierdo
    STATE_STOPPED,             // Detenido
    STATE_SEARCHING_LINE,      // Buscando línea perdida
    STATE_SHARP_CURVE,         // Curva cerrada
    STATE_AVOIDING_OBSTACLE,   // Evadiendo obstáculo
    STATE_REMOTE_CONTROL       // Controlado remotamente
};

class StateMachine {
private:
    RobotState currentState;    // Estado actual
    unsigned long stateStartTime; // Tiempo de inicio del estado
    unsigned long lineLostTime;  // Tiempo desde que se perdió la línea
    int searchDirection;        // Dirección de búsqueda (-1 o 1)
    OperationMode currentOperationMode; // Modo de operación actual
    
public:
    /**
     * Constructor - inicia en estado detenido
     */
    StateMachine() : currentState(STATE_STOPPED), stateStartTime(0), 
                    lineLostTime(0), searchDirection(1), 
                    currentOperationMode(MODE_DEBUG) {}
    
    /**
     * Actualizar estado basado en sensores y modo
     * @param error Error de seguimiento de línea
     * @param sensorSum Suma de valores de sensores
     * @param obstacleDetected true si hay obstáculo crítico
     * @param opMode Modo de operación actual
     */
    void updateState(int error, int sensorSum, bool obstacleDetected, OperationMode opMode) {
        currentOperationMode = opMode;
        
        // Si estamos en modo control remoto, forzar ese estado
        if (opMode == MODE_REMOTE_CONTROL) {
            if (currentState != STATE_REMOTE_CONTROL) {
                currentState = STATE_REMOTE_CONTROL;
                stateStartTime = millis();
            }
            return;
        }
        
        RobotState newState = currentState;
        
        // Detección de obstáculos tiene prioridad
        if (obstacleDetected && currentState != STATE_AVOIDING_OBSTACLE) {
            newState = STATE_AVOIDING_OBSTACLE;
        } else {
            // Transiciones normales basadas en sensores
            switch (currentState) {
                case STATE_FOLLOWING_LINE:
                    if (sensorSum < 100) {
                        // Línea perdida
                        if (millis() - lineLostTime > 800) {
                            newState = STATE_SEARCHING_LINE;
                            searchDirection = (random(2) == 0) ? 1 : -1;
                        }
                    } else {
                        lineLostTime = millis();
                    }
                    
                    // Detectar curva cerrada
                    if (abs(error) > 1800) {
                        newState = STATE_SHARP_CURVE;
                    }
                    
                    // Detectar intersección (todos los sensores activos)
                    if (sensorSum > 4500) {
                        newState = STATE_STOPPED;
                    }
                    break;
                    
                case STATE_SEARCHING_LINE:
                    // Volver a seguir línea si se encuentra o timeout
                    if (sensorSum > 300 || millis() - lineLostTime > 2000) {
                        newState = STATE_FOLLOWING_LINE;
                        lineLostTime = millis();
                    }
                    break;
                    
                case STATE_SHARP_CURVE:
                    // Volver a seguimiento normal cuando la curva termina
                    if (abs(error) < 1000) {
                        newState = STATE_FOLLOWING_LINE;
                    }
                    break;
                    
                case STATE_STOPPED:
                    // Después de 1 segundo en intersección, girar
                    if (millis() - stateStartTime > 1000) {
                        newState = STATE_TURNING_RIGHT; // Por defecto gira derecha
                    }
                    break;
                    
                case STATE_TURNING_RIGHT:
                case STATE_TURNING_LEFT:
                    // Terminar giro después de 500ms
                    if (millis() - stateStartTime > 500) {
                        newState = STATE_FOLLOWING_LINE;
                    }
                    break;
                    
                case STATE_AVOIDING_OBSTACLE:
                    // Terminar evasión después de 2 segundos
                    if (millis() - stateStartTime > 2000) {
                        newState = STATE_FOLLOWING_LINE;
                    }
                    break;
                    
                case STATE_REMOTE_CONTROL:
                    // Solo sale del modo remoto si cambia el modo de operación
                    if (opMode != MODE_REMOTE_CONTROL) {
                        newState = STATE_STOPPED;
                    }
                    break;
            }
        }
        
        // Cambiar estado si es necesario
        if (newState != currentState) {
            currentState = newState;
            stateStartTime = millis();
            
            // Log de cambio de estado (si el serial está habilitado)
            if (currentOperationMode != MODE_COMPETITION) {
                Serial.println("{\"type\":\"state_change\",\"new_state\":\"" + 
                              getStateString() + "\",\"duration\":" + 
                              String(millis() - stateStartTime) + "}");
            }
        }
    }
    
    /**
     * Obtener estado actual
     * @return Estado actual del robot
     */
    RobotState getCurrentState() const { return currentState; }
    
    /**
     * Obtener string del estado actual
     * @return String descriptivo del estado
     */
    String getStateString() const {
        switch (currentState) {
            case STATE_FOLLOWING_LINE: return "FOLLOWING_LINE";
            case STATE_TURNING_RIGHT: return "TURNING_RIGHT";
            case STATE_TURNING_LEFT: return "TURNING_LEFT";
            case STATE_STOPPED: return "STOPPED";
            case STATE_SEARCHING_LINE: return "SEARCHING_LINE";
            case STATE_SHARP_CURVE: return "SHARP_CURVE";
            case STATE_AVOIDING_OBSTACLE: return "AVOIDING_OBSTACLE";
            case STATE_REMOTE_CONTROL: return "REMOTE_CONTROL";
            default: return "UNKNOWN";
        }
    }
    
    /**
     * Generar JSON con información del estado
     * @return String JSON con datos del estado
     */
    String getStateJSON() const {
        StaticJsonDocument<256> doc;
        doc["type"] = "state";
        doc["state"] = getStateString();
        doc["time_in_state"] = millis() - stateStartTime;
        doc["op_mode"] = operationModeToString(currentOperationMode);
        
        String jsonString;
        serializeJson(doc, jsonString);
        return jsonString;
    }
    
    /**
     * Obtener dirección de búsqueda actual
     * @return 1 para derecha, -1 para izquierda
     */
    int getSearchDirection() const { return searchDirection; }
    
    /**
     * Obtener tiempo en el estado actual
     * @return Tiempo en ms
     */
    unsigned long getStateStartTime() const { return stateStartTime; }
    
    /**
     * Obtener tiempo desde que se perdió la línea
     * @return Tiempo en ms
     */
    unsigned long getLineLostTime() const { return lineLostTime; }
    
private:
    /**
     * Convertir modo de operación a string
     * @param mode Modo de operación
     * @return String descriptivo
     */
    String operationModeToString(OperationMode mode) const {
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
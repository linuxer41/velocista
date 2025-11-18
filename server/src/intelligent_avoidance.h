/**
 * ARCHIVO: intelligent_avoidance.h
 * DESCRIPCIÓN: Sistema de evasión inteligente de obstáculos
 * FUNCIONALIDAD: Evaluación de distancia, estrategias de evasión
 */

#ifndef INTELLIGENT_AVOIDANCE_H
#define INTELLIGENT_AVOIDANCE_H

#include <Arduino.h>
#include <ArduinoJson.h>
#include "config.h"
#include "odometry.h"

class IntelligentAvoidance {
private:
    float safeDistance;          // Distancia segura (cm)
    float criticalDistance;      // Distancia crítica (cm)
    unsigned long lastObstacleTime; // Tiempo último obstáculo detectado
    int avoidanceStrategy;       // Estrategia de evasión actual
    Odometry& odometry;          // Referencia a odometría
    
public:
    // Acciones de evasión
    enum AvoidanceAction {
        NO_OBSTACLE,            // Sin obstáculos
        SLOW_DOWN,              // Reducir velocidad
        TURN_RIGHT,             // Girar a la derecha
        TURN_LEFT,              // Girar a la izquierda
        REVERSE,                // Reversa
        EMERGENCY_STOP          // Parada de emergencia
    };
    
    /**
     * Constructor
     * @param odom Referencia a sistema de odometría
     */
    IntelligentAvoidance(Odometry& odom) : odometry(odom) {
        safeDistance = 20.0;     // 20 cm
        criticalDistance = 10.0; // 10 cm
        lastObstacleTime = 0;
        avoidanceStrategy = 0;
    }
    
    /**
     * Evaluar obstáculo y determinar acción
     * @param distance Distancia medida en cm
     * @param currentSpeed Velocidad actual del robot
     * @return Acción de evasión recomendada
     */
    AvoidanceAction evaluateObstacle(float distance, float currentSpeed) {
        if (distance <= 0) return NO_OBSTACLE;
        
        // Calcular distancia de frenado basada en velocidad actual
        float stoppingDistance = currentSpeed * 0.1 + 5.0;
        
        if (distance < criticalDistance) {
            // Obstáculo muy cercano - acción de emergencia
            lastObstacleTime = millis();
            return EMERGENCY_STOP;
        }
        else if (distance < stoppingDistance) {
            // Obstáculo en distancia de frenado
            lastObstacleTime = millis();
            
            // Decidir estrategia basada en situación
            if (currentSpeed > 100) {
                return REVERSE; // A alta velocidad, mejor retroceder
            }
            
            // Decidir dirección de giro basado en odometría y contexto
            float currentTheta = odometry.getTheta();
            
            // Estrategia: girar hacia el lado "más abierto"
            // Si estamos orientados positivamente, girar izquierda
            if (currentTheta > 0) {
                avoidanceStrategy = 1;
                return TURN_LEFT;
            } else {
                avoidanceStrategy = 2;
                return TURN_RIGHT;
            }
        }
        else if (distance < safeDistance) {
            // Obstáculo en distancia segura - reducir velocidad
            return SLOW_DOWN;
        }
        
        return NO_OBSTACLE;
    }
    
    /**
     * Generar JSON con información de evasión
     * @param distance Distancia medida
     * @param action Acción tomada
     * @return String JSON con datos de evasión
     */
    String getAvoidanceJSON(float distance, AvoidanceAction action) {
        StaticJsonDocument<256> doc;
        doc["type"] = "avoidance";
        doc["distance"] = distance;
        doc["action"] = actionToString(action);
        doc["strategy"] = avoidanceStrategy;
        doc["safe_distance"] = safeDistance;
        doc["critical_distance"] = criticalDistance;
        doc["time_since_obstacle"] = millis() - lastObstacleTime;
        
        String jsonString;
        serializeJson(doc, jsonString);
        return jsonString;
    }
    
    // Getters y setters
    float getSafeDistance() const { return safeDistance; }
    float getCriticalDistance() const { return criticalDistance; }
    void setSafeDistance(float dist) { safeDistance = dist; }
    void setCriticalDistance(float dist) { criticalDistance = dist; }
    
private:
    /**
     * Convertir acción a string
     * @param action Acción de evasión
     * @return String descriptivo
     */
    String actionToString(AvoidanceAction action) {
        switch (action) {
            case NO_OBSTACLE: return "NO_OBSTACLE";
            case SLOW_DOWN: return "SLOW_DOWN";
            case TURN_RIGHT: return "TURN_RIGHT";
            case TURN_LEFT: return "TURN_LEFT";
            case REVERSE: return "REVERSE";
            case EMERGENCY_STOP: return "EMERGENCY_STOP";
            default: return "UNKNOWN";
        }
    }
};

#endif
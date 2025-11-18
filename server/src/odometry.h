/**
 * ARCHIVO: odometry.h
 * DESCRIPCIÓN: Sistema de odometría para tracking de posición
 * FUNCIONALIDAD: Cálculo de posición (x,y,theta), distancia recorrida
 */

#ifndef ODOMETRY_H
#define ODOMETRY_H

#include <Arduino.h>
#include <ArduinoJson.h>
#include "config.h"

class Odometry {
private:
    float x, y, theta;           // Posición y orientación (radianes)
    float totalDistance;         // Distancia total recorrida (mm)
    long leftTotalPulses;        // Pulsos totales encoder izquierdo
    long rightTotalPulses;       // Pulsos totales encoder derecho
    float wheelCircumference;    // Circunferencia de rueda (mm)
    float distancePerPulse;      // Distancia por pulso (mm/pulso)
    float wheelDistance;         // Distancia entre ruedas (mm)
    
public:
    /**
     * Constructor - inicializa odometría
     * @param wheelDiam Diámetro de rueda en mm
     * @param wheelDist Distancia entre ruedas en mm
     */
    Odometry(float wheelDiam = WHEEL_DIAMETER_MM, float wheelDist = WHEEL_DISTANCE_MM) {
        reset();
        wheelCircumference = PI * wheelDiam;
        distancePerPulse = wheelCircumference / PULSES_PER_REVOLUTION;
        wheelDistance = wheelDist;
    }
    
    /**
     * Resetear odometría a posición cero
     */
    void reset() {
        x = 0.0;
        y = 0.0; 
        theta = 0.0;
        totalDistance = 0.0;
        leftTotalPulses = 0;
        rightTotalPulses = 0;
    }
    
    /**
     * Actualizar posición basado en pulsos de encoders
     * @param leftPulses Pulsos encoder izquierdo desde última actualización
     * @param rightPulses Pulsos encoder derecho desde última actualización
     * @param dt Tiempo transcurrido en ms
     */
    void update(long leftPulses, long rightPulses, unsigned long dt) {
        // Actualizar pulsos totales
        leftTotalPulses += leftPulses;
        rightTotalPulses += rightPulses;
        
        // Calcular distancia recorrida por cada rueda
        float leftDistance = leftPulses * distancePerPulse;
        float rightDistance = rightPulses * distancePerPulse;
        
        // Calcular desplazamiento y rotación
        float distance = (leftDistance + rightDistance) / 2.0;
        float deltaTheta = (rightDistance - leftDistance) / wheelDistance;
        
        // Actualizar orientación
        theta += deltaTheta;
        
        // Normalizar ángulo entre -PI y PI
        while (theta > PI) theta -= 2 * PI;
        while (theta < -PI) theta += 2 * PI;
        
        // Actualizar posición
        x += distance * cos(theta);
        y += distance * sin(theta);
        totalDistance += distance;
    }
    
    // Getters
    float getX() const { return x; }
    float getY() const { return y; }
    float getTheta() const { return theta; }
    float getTotalDistance() const { return totalDistance; }
    long getLeftTotalPulses() const { return leftTotalPulses; }
    long getRightTotalPulses() const { return rightTotalPulses; }
    
    /**
     * Generar JSON con datos de posición
     * @return String JSON con pose del robot
     */
    String getPoseJSON() {
        StaticJsonDocument<256> doc;
        doc["type"] = "pose";
        doc["x"] = round(x * 100) / 100.0;  // 2 decimales
        doc["y"] = round(y * 100) / 100.0;
        doc["theta"] = round(theta * 1000) / 1000.0; // 3 decimales
        doc["theta_deg"] = round(theta * 180.0 / PI * 10) / 10.0; // Grados
        doc["distance"] = round(totalDistance * 100) / 100.0;
        doc["left_pulses"] = leftTotalPulses;
        doc["right_pulses"] = rightTotalPulses;
        
        String jsonString;
        serializeJson(doc, jsonString);
        return jsonString;
    }
    
    /**
     * Calcular distancia a punto objetivo
     * @param targetX Coordenada X objetivo
     * @param targetY Coordenada Y objetivo
     * @return Distancia en mm
     */
    float distanceTo(float targetX, float targetY) {
        return sqrt(pow(targetX - x, 2) + pow(targetY - y, 2));
    }
    
    /**
     * Calcular ángulo hacia punto objetivo
     * @param targetX Coordenada X objetivo
     * @param targetY Coordenada Y objetivo
     * @return Ángulo en radianes (diferencia entre orientación actual y objetivo)
     */
    float angleTo(float targetX, float targetY) {
        return atan2(targetY - y, targetX - x) - theta;
    }
};

#endif
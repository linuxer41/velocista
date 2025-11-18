/**
 * ARCHIVO: encoder_controller.h
 * DESCRIPCIÓN: Lectura y procesamiento de encoders de motores
 * FUNCIONALIDAD: Conteo de pulsos, cálculo de RPM, interrupciones
 */

#ifndef ENCODER_CONTROLLER_H
#define ENCODER_CONTROLLER_H

#include <Arduino.h>
#include "config.h"

// Declaraciones forward para interrupciones
void encoderLeftISR();
void encoderRightISR();

class EncoderController {
private:
    volatile long leftCount;     // Contador pulsos encoder izquierdo
    volatile long rightCount;    // Contador pulsos encoder derecho
    unsigned long previousTime;  // Tiempo anterior para cálculo RPM
    float leftRPM;              // RPM motor izquierdo
    float rightRPM;             // RPM motor derecho

public:
    /**
     * Constructor - inicializa contadores en cero
     */
    EncoderController() : leftCount(0), rightCount(0), previousTime(0), leftRPM(0), rightRPM(0) {}
    
    /**
     * Inicializar encoders y configurar interrupciones
     */
    void initialize() {
        // Configurar pines de encoders
        pinMode(ENCODER_LEFT_A, INPUT_PULLUP);
        pinMode(ENCODER_LEFT_B, INPUT_PULLUP);
        pinMode(ENCODER_RIGHT_A, INPUT_PULLUP);
        pinMode(ENCODER_RIGHT_B, INPUT_PULLUP);
        
        // Configurar interrupciones en flanco de subida
        attachInterrupt(digitalPinToInterrupt(ENCODER_LEFT_A), encoderLeftISR, RISING);
        attachInterrupt(digitalPinToInterrupt(ENCODER_RIGHT_A), encoderRightISR, RISING);
        
        previousTime = millis();
        Serial.println("{\"type\":\"encoder\",\"message\":\"Controlador de encoders inicializado\"}");
    }
    
    /**
     * Incrementar contador encoder izquierdo (llamado por ISR)
     */
    void incrementLeft() { leftCount++; }
    
    /**
     * Incrementar contador encoder derecho (llamado por ISR)
     */
    void incrementRight() { rightCount++; }
    
    /**
     * Actualizar velocidades RPM de los motores
     */
    void updateVelocities() {
        unsigned long currentTime = millis();
        unsigned long elapsedTime = currentTime - previousTime;
        
        if (elapsedTime >= 100) { // Actualizar cada 100ms
            // Calcular RPM
            leftRPM = calculateRPM(leftCount, elapsedTime);
            rightRPM = calculateRPM(rightCount, elapsedTime);
            
            // Resetear contadores
            leftCount = 0;
            rightCount = 0;
            previousTime = currentTime;
        }
    }
    
    /**
     * Calcular RPM a partir de pulsos de encoder
     * @param pulses Pulsos contados en el intervalo
     * @param elapsedTime Tiempo transcurrido en ms
     * @return Velocidad en RPM
     */
    float calculateRPM(long pulses, long elapsedTime) {
        if (elapsedTime == 0) return 0;
        
        float revolutions = (float)pulses / PULSES_PER_REVOLUTION;
        float minutes = (float)elapsedTime / 60000.0;
        
        return revolutions / minutes;
    }
    
    // Getters
    float getLeftRPM() const { return leftRPM; }
    float getRightRPM() const { return rightRPM; }
    long getLeftCount() const { return leftCount; }
    long getRightCount() const { return rightCount; }
    
    /**
     * Generar JSON con datos de encoders
     */
    String getStatusJSON() {
        StaticJsonDocument<300> doc;
        doc["type"] = "encoder_status";
        doc["left_rpm"] = leftRPM;
        doc["right_rpm"] = rightRPM;
        doc["left_count"] = leftCount;
        doc["right_count"] = rightCount;
        doc["pulses_per_revolution"] = PULSES_PER_REVOLUTION;
        
        String jsonString;
        serializeJson(doc, jsonString);
        return jsonString;
    }
};

// Instancia global para acceso desde ISRs
extern EncoderController encoderController;

#endif
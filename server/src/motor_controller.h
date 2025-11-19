/**
 * ARCHIVO: motor_controller.h
 * DESCRIPCIÓN: Control de motores con DRV8833
 * FUNCIONALIDAD: Control PWM, movimiento diferencial, seguridad
 */

#ifndef MOTOR_CONTROLLER_H
#define MOTOR_CONTROLLER_H

#include <Arduino.h>
#include "config.h"
#include "models.h"

class MotorController {
private:
    int baseSpeed;        // Velocidad base (0-255)
    int maxSpeed;         // Velocidad máxima permitida
    bool safetyEnabled;   // Habilitar límites de seguridad

public:
    /**
     * Constructor - inicializa con valores por defecto
     */
    MotorController() : baseSpeed(DEFAULT_BASE_SPEED), maxSpeed(MAX_SPEED), safetyEnabled(true) {}
    
    /**
     * Inicializar pines de motores
     */
    void initialize() {
        pinMode(MOTOR_LEFT_PIN1, OUTPUT);
        pinMode(MOTOR_LEFT_PIN2, OUTPUT);
        pinMode(MOTOR_RIGHT_PIN1, OUTPUT);
        pinMode(MOTOR_RIGHT_PIN2, OUTPUT);
        stopAll();
    }
    
    /**
     * Controlar motor izquierdo
     * @param speed Velocidad (-255 a 255), negativo para reversa
     */
    void controlLeftMotor(int speed) {
        if (safetyEnabled) {
            speed = constrain(speed, -maxSpeed, maxSpeed);
        }
        
        if (speed > 0) {
            // Movimiento hacia adelante
            analogWrite(MOTOR_LEFT_PIN1, speed);
            analogWrite(MOTOR_LEFT_PIN2, 0);
        } else if (speed < 0) {
            // Movimiento hacia atrás
            analogWrite(MOTOR_LEFT_PIN1, 0);
            analogWrite(MOTOR_LEFT_PIN2, abs(speed));
        } else {
            // Motor parado
            analogWrite(MOTOR_LEFT_PIN1, 0);
            analogWrite(MOTOR_LEFT_PIN2, 0);
        }
    }
    
    /**
     * Controlar motor derecho
     * @param speed Velocidad (-255 a 255), negativo para reversa
     */
    void controlRightMotor(int speed) {
        if (safetyEnabled) {
            speed = constrain(speed, -maxSpeed, maxSpeed);
        }
        
        if (speed > 0) {
            // Movimiento hacia adelante
            analogWrite(MOTOR_RIGHT_PIN1, speed);
            analogWrite(MOTOR_RIGHT_PIN2, 0);
        } else if (speed < 0) {
            // Movimiento hacia atrás
            analogWrite(MOTOR_RIGHT_PIN1, 0);
            analogWrite(MOTOR_RIGHT_PIN2, abs(speed));
        } else {
            // Motor parado
            analogWrite(MOTOR_RIGHT_PIN1, 0);
            analogWrite(MOTOR_RIGHT_PIN2, 0);
        }
    }
    
    /**
     * Detener ambos motores inmediatamente
     */
    void stopAll() {
        controlLeftMotor(0);
        controlRightMotor(0);
    }
    
    /**
     * Control tipo tanque (velocidades independientes)
     * @param leftSpeed Velocidad motor izquierdo
     * @param rightSpeed Velocidad motor derecho
     */
    void tankDrive(int leftSpeed, int rightSpeed) {
        controlLeftMotor(leftSpeed);
        controlRightMotor(rightSpeed);
    }
    
    /**
     * Control tipo arcade (throttle + steering)
     * @param throttle Velocidad forward/backward
     * @param steering Giro izquierda/derecha
     */
    void arcadeDrive(int throttle, int steering) {
        int leftSpeed = throttle + steering;
        int rightSpeed = throttle - steering;
        tankDrive(leftSpeed, rightSpeed);
    }
    
    // Getters y setters
    void setBaseSpeed(int speed) { baseSpeed = speed; }
    int getBaseSpeed() const { return baseSpeed; }
    int getMaxSpeed() const { return maxSpeed; }
    void setSafety(bool enabled) { safetyEnabled = enabled; }
    bool isSafetyEnabled() const { return safetyEnabled; }
    
};

#endif
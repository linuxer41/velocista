/**
 * ARCHIVO: advanced_pid.h
 * DESCRIPCIÓN: Implementación de control PID avanzado
 * FUNCIONALIDAD: PID con anti-windup, filtro derivativo, límites
 */

#ifndef ADVANCED_PID_H
#define ADVANCED_PID_H

#include <Arduino.h>

class AdvancedPID {
private:
    float kp, ki, kd;            // Ganancias PID
    float kaw;                   // Ganancia anti-windup
    float previousError;         // Error anterior
    float integral;              // Término integral acumulado
    float outputLimit;           // Límite de salida
    float integralLimit;         // Límite del término integral
    float setpoint;              // Punto de referencia
    unsigned long lastTime;      // Último tiempo de cálculo
    
public:
    /**
     * Constructor del controlador PID avanzado
     * @param p Ganancia proporcional
     * @param i Ganancia integral
     * @param d Ganancia derivativa
     * @param aw Ganancia anti-windup (opcional)
     * @param limit Límite de salida (opcional)
     */
    AdvancedPID(float p, float i, float d, float aw = 0.1f, float limit = 255.0f)
        : kp(p), ki(i), kd(d), kaw(aw), previousError(0), integral(0),
          outputLimit(limit), integralLimit(limit/ki), setpoint(0), lastTime(millis()) {}
    
    /**
     * Calcular salida del controlador PID
     * @param input Valor actual del proceso
     * @return Salida del controlador
     */
    float compute(float input) {
        unsigned long now = millis();
        float dt = (now - lastTime) / 1000.0f;
        if (dt == 0) dt = 0.01f; // Evitar división por cero

        float error = setpoint - input;

        // Término proporcional
        float proportional = kp * error;

        // Término integral con anti-windup
        integral += error * dt;

        // Limitar término integral para evitar windup
        if (ki != 0) {
            float maxIntegral = integralLimit / ki;
            integral = constrain(integral, -maxIntegral, maxIntegral);
        }

        float integralTerm = ki * integral;

        // Término derivativo con filtro pasa-bajos
        float derivative = (error - previousError) / dt;

        // Filtro pasa-bajos para derivativo (reduce ruido)
        static float previousDerivative = 0;
        float alpha = 0.7f; // Factor de filtrado
        derivative = alpha * previousDerivative + (1 - alpha) * derivative;
        previousDerivative = derivative;

        float derivativeTerm = kd * derivative;

        // Calcular salida total
        float output = proportional + integralTerm + derivativeTerm;
        output = constrain(output, -outputLimit, outputLimit);

        // Anti-windup back-calculation
        if (output == outputLimit || output == -outputLimit) {
            integral -= kaw * (output - constrain(output, -outputLimit, outputLimit));
        }

        previousError = error;
        lastTime = now;

        return output;
    }
    
    /**
     * Establecer punto de referencia
     * @param sp Nuevo setpoint
     */
    void setSetpoint(float sp) { setpoint = sp; }

    /**
     * Configurar ganancias PID
     * @param p Ganancia proporcional
     * @param i Ganancia integral
     * @param d Ganancia derivativa
     */
    void setGains(float p, float i, float d) {
        kp = p;
        ki = i;
        kd = d;
    }

    /**
     * Establecer límite de salida
     * @param limit Nuevo límite de salida
     */
    void setOutputLimit(float limit) { outputLimit = limit; }
    
    /**
     * Resetear el controlador (integral y error anterior)
     */
    void reset() { 
        previousError = 0; 
        integral = 0; 
    }
    
    
    // Getters para ganancias individuales
    float getKp() const { return kp; }
    float getKi() const { return ki; }
    float getKd() const { return kd; }
    float getIntegral() const { return integral; }
};

#endif
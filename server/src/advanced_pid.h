/**
 * ARCHIVO: advanced_pid.h
 * DESCRIPCIÓN: Implementación de control PID avanzado
 * FUNCIONALIDAD: PID con anti-windup, filtro derivativo, límites
 */

#ifndef ADVANCED_PID_H
#define ADVANCED_PID_H

#include <Arduino.h>
#include <ArduinoJson.h>

class AdvancedPID {
private:
    double kp, ki, kd;           // Ganancias PID
    double kaw;                  // Ganancia anti-windup
    double previousError;        // Error anterior
    double integral;             // Término integral acumulado
    double outputLimit;          // Límite de salida
    double integralLimit;        // Límite del término integral
    double setpoint;             // Punto de referencia
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
    AdvancedPID(double p, double i, double d, double aw = 0.1, double limit = 255.0) 
        : kp(p), ki(i), kd(d), kaw(aw), previousError(0), integral(0), 
          outputLimit(limit), integralLimit(limit/ki), setpoint(0), lastTime(millis()) {}
    
    /**
     * Calcular salida del controlador PID
     * @param input Valor actual del proceso
     * @return Salida del controlador
     */
    double compute(double input) {
        unsigned long now = millis();
        double dt = (now - lastTime) / 1000.0;
        if (dt == 0) dt = 0.01; // Evitar división por cero
        
        double error = setpoint - input;
        
        // Término proporcional
        double proportional = kp * error;
        
        // Término integral con anti-windup
        integral += error * dt;
        
        // Limitar término integral para evitar windup
        if (ki != 0) {
            double maxIntegral = integralLimit / ki;
            integral = constrain(integral, -maxIntegral, maxIntegral);
        }
        
        double integralTerm = ki * integral;
        
        // Término derivativo con filtro pasa-bajos
        double derivative = (error - previousError) / dt;
        
        // Filtro pasa-bajos para derivativo (reduce ruido)
        static double previousDerivative = 0;
        double alpha = 0.7; // Factor de filtrado
        derivative = alpha * previousDerivative + (1 - alpha) * derivative;
        previousDerivative = derivative;
        
        double derivativeTerm = kd * derivative;
        
        // Calcular salida total
        double output = proportional + integralTerm + derivativeTerm;
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
    void setSetpoint(double sp) { setpoint = sp; }
    
    /**
     * Configurar ganancias PID
     * @param p Ganancia proporcional
     * @param i Ganancia integral
     * @param d Ganancia derivativa
     */
    void setGains(double p, double i, double d) { 
        kp = p; 
        ki = i; 
        kd = d; 
    }
    
    /**
     * Establecer límite de salida
     * @param limit Nuevo límite de salida
     */
    void setOutputLimit(double limit) { outputLimit = limit; }
    
    /**
     * Resetear el controlador (integral y error anterior)
     */
    void reset() { 
        previousError = 0; 
        integral = 0; 
    }
    
    /**
     * Obtener ganancias actuales en formato JSON
     * @return String JSON con ganancias PID
     */
    String getTuningJSON() {
        StaticJsonDocument<256> doc;
        doc["type"] = "pid_tuning";
        doc["kp"] = kp;
        doc["ki"] = ki;
        doc["kd"] = kd;
        doc["output_limit"] = outputLimit;
        doc["integral"] = integral;
        doc["setpoint"] = setpoint;
        
        String jsonString;
        serializeJson(doc, jsonString);
        return jsonString;
    }
    
    // Getters para ganancias individuales
    double getKp() const { return kp; }
    double getKi() const { return ki; }
    double getKd() const { return kd; }
    double getIntegral() const { return integral; }
};

#endif
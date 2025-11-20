/**
 * ARCHIVO: sensor_array.h
 * DESCRIPCIÓN: Control de array de 6 sensores reflectivos
 * FUNCIONALIDAD: Lectura calibrada, filtrado, control de alimentación
 */

#ifndef SENSOR_ARRAY_H
#define SENSOR_ARRAY_H

#include <Arduino.h>
#include "config.h"
#include "models.h"

class SensorArray {
private:
    int minValues[NUM_SENSORS];      // Valores mínimos calibrados
    int maxValues[NUM_SENSORS];      // Valores máximos calibrados
    bool calibrated;                 // Estado de calibración
    float filteredValues[NUM_SENSORS]; // Valores filtrados
    float sensorWeights[NUM_SENSORS];  // Pesos para promedio ponderado
    unsigned long lastReadTime;      // Último tiempo de lectura
    bool powerState;                 // Estado alimentación sensores

public:
    /**
     * Constructor - inicializa arrays y configura pines
     */
    SensorArray() : calibrated(false), lastReadTime(0), powerState(false) {}

    /**
     * Inicializar arrays y configurar pines
     */
    void initialize() {
        // Inicializar arrays
        for (int i = 0; i < NUM_SENSORS; i++) {
            minValues[i] = 1023;
            maxValues[i] = 0;
            filteredValues[i] = 0;
            sensorWeights[i] = 1.0;
        }

        // Configurar pesos para sensores centrales (más importantes)
        sensorWeights[2] = 1.2;  // Sensor 2 - más peso
        sensorWeights[3] = 1.2;  // Sensor 3 - más peso

        // Configurar pin de alimentación
        pinMode(SENSOR_POWER_PIN, OUTPUT);
        for (int i = 0; i < NUM_SENSORS; i++) {
            pinMode(SENSOR_PINS[i], INPUT);
        }
        setPower(false); // Iniciar con sensores apagados
    }
    
    /**
     * Encender/apagar alimentación de sensores
     * @param on true para encender, false para apagar
     */
    void setPower(bool on) {
        if (powerState != on) {
            powerState = on;
            digitalWrite(SENSOR_POWER_PIN, on ? HIGH : LOW);

            if (on) {
                delay(10); // Pequeño delay para estabilización de LEDs
            }
        }
    }
    
    /**
     * Obtener estado de alimentación
     * @return true si sensores están encendidos
     */
    bool getPowerState() const { return powerState; }
    
    /**
     * Aplicar filtro pasa-bajos a lecturas de sensores
     */
    void applyLowPassFilter() {
        if (!powerState) return;

        // led on
        digitalWrite(SENSOR_POWER_PIN, HIGH);
        delay(20);
        
        float alpha = 0.7; // Factor de suavizado (0-1)
        for (int i = 0; i < NUM_SENSORS; i++) {
            int rawValue = analogRead(SENSOR_PINS[i]);
            filteredValues[i] = alpha * filteredValues[i] + (1 - alpha) * rawValue;
        }

        // led off
        digitalWrite(SENSOR_POWER_PIN, LOW);
    }
    
    /**
     * Leer sensor individual calibrado
     * @param sensorIndex Índice del sensor (0-5)
     * @return Valor calibrado (0-1000)
     */
    int readCalibratedSensor(int sensorIndex) {
        if (!powerState || !calibrated) return 0;
        
        float value = filteredValues[sensorIndex];
        value = constrain(value, minValues[sensorIndex], maxValues[sensorIndex]);
        return map(value, minValues[sensorIndex], maxValues[sensorIndex], 0, 1000);
    }
    
    /**
     * Leer posición de línea y calcular error
     * @return Error de posición (-2500 a +2500), 0 = línea perdida, 9999 = intersección
     */
    int readLinePosition() {
        if (!powerState) return 0;
        
        applyLowPassFilter(); // Actualizar valores filtrados
        
        int sensorValues[NUM_SENSORS];
        int weightedSum = 0;
        int totalSum = 0;
        int activeSensors = 0;
        
        // Leer todos los sensores calibrados
        for (int i = 0; i < NUM_SENSORS; i++) {
            sensorValues[i] = readCalibratedSensor(i);
            weightedSum += sensorValues[i] * i * 1000 * sensorWeights[i];
            totalSum += sensorValues[i] * sensorWeights[i];
            if (sensorValues[i] > 100) activeSensors++;
        }
        
        // Detectar casos especiales
        if (totalSum < 50) {
            return 0; // Línea perdida - muy poca reflectancia
        }
        
        if (activeSensors >= 5) {
            return 9999; // Intersección detectada - casi todos los sensores activos
        }
        
        // Calcular posición ponderada (0-5000)
        int position = weightedSum / totalSum;
        
        // Convertir a error centrado (-2500 a +2500)
        return position - 2500;
    }
    
    /**
     * Obtener suma total de valores de sensores
     * @return Suma de todos los valores de sensores calibrados
     */
    int getSensorSum() {
        if (!powerState) return 0;
        
        int sum = 0;
        for (int i = 0; i < NUM_SENSORS; i++) {
            sum += readCalibratedSensor(i);
        }
        return sum;
    }
    
    /**
     * Realizar calibración automática de sensores
     */
    void performAutoCalibration() {
        setPower(true);
        calibrated = false;

        CommunicationSerializer::sendSystemMessage("Iniciando calibracion automatica...");
        CommunicationSerializer::sendSystemMessage("Mueva el robot sobre linea negra y areas blancas");
        
        // Girar sobre sí mismo para calibrar todos los sensores
        for (int i = 0; i < 200; i++) {
            for (int s = 0; s < NUM_SENSORS; s++) {
                int value = analogRead(SENSOR_PINS[s]);
                if (value < minValues[s]) minValues[s] = value;
                if (value > maxValues[s]) maxValues[s] = value;
            }
            delay(20); // Pequeño delay entre lecturas
        }
        
        calibrated = true;
        CommunicationSerializer::sendSystemMessage("Calibracion completada exitosamente");

        // Mostrar valores de calibración
        CommunicationSerializer::sendSystemMessage("Valores de calibracion:");
    }
    
    /**
     * Calibrar sensores desde configuración EEPROM
     * @param config Configuración cargada de EEPROM
     */
    void calibrateFromConfig(const RobotConfig& config) {
        for (int i = 0; i < NUM_SENSORS; i++) {
            minValues[i] = config.sensorMin[i];
            maxValues[i] = config.sensorMax[i];
        }
        calibrated = true;
        CommunicationSerializer::sendSystemMessage("Calibracion cargada desde EEPROM");
    }
    
    /**
     * Guardar calibración en configuración
     * @param config Configuración a actualizar
     */
    void saveCalibrationToConfig(RobotConfig& config) {
        for (int i = 0; i < NUM_SENSORS; i++) {
            config.sensorMin[i] = minValues[i];
            config.sensorMax[i] = maxValues[i];
        }
    }
    
    /**
     * Verificar estado de calibración
     * @return true si los sensores están calibrados
     */
    bool isCalibrated() const { return calibrated; }
    
    
    /**
     * Obtener valores mínimos de calibración
     */
    const int* getMinValues() const { return minValues; }
    
    /**
     * Obtener valores máximos de calibración
     */
    const int* getMaxValues() const { return maxValues; }
};

#endif
/**
 * ARCHIVO: sensor_array.h
 * DESCRIPCIÓN: Control de array de 6 sensores reflectivos
 * FUNCIONALIDAD: Lectura calibrada, filtrado, control de alimentación
 */

#ifndef SENSOR_ARRAY_H
#define SENSOR_ARRAY_H

#include <Arduino.h>
#include <ArduinoJson.h>
#include "config.h"

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
    SensorArray() : calibrated(false), lastReadTime(0), powerState(false) {
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
        setPower(false); // Iniciar con sensores apagados
        
        Serial.println("{\"type\":\"sensor\",\"message\":\"Array de sensores inicializado\"}");
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
            
            Serial.println("{\"type\":\"sensor_power\",\"state\":" + String(on ? "true" : "false") + "}");
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
        
        float alpha = 0.7; // Factor de suavizado (0-1)
        for (int i = 0; i < NUM_SENSORS; i++) {
            int rawValue = analogRead(SENSOR_PINS[i]);
            filteredValues[i] = alpha * filteredValues[i] + (1 - alpha) * rawValue;
        }
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
        
        Serial.println("{\"type\":\"calibration\",\"message\":\"Iniciando calibración automática...\"}");
        Serial.println("{\"type\":\"calibration\",\"instruction\":\"Mueva el robot sobre línea negra y áreas blancas\"}");
        
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
        Serial.println("{\"type\":\"calibration\",\"message\":\"Calibración completada exitosamente\"}");
        
        // Mostrar valores de calibración
        Serial.println("{\"type\":\"calibration\",\"message\":\"Valores de calibración:\"}");
        for (int i = 0; i < NUM_SENSORS; i++) {
            Serial.println("{\"type\":\"calibration\",\"sensor\":" + String(i) + 
                          ",\"min\":" + String(minValues[i]) + 
                          ",\"max\":" + String(maxValues[i]) + "}");
        }
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
        Serial.println("{\"type\":\"sensor\",\"message\":\"Calibración cargada desde EEPROM\"}");
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
     * Generar JSON con datos completos de sensores
     * @return String JSON con datos de sensores
     */
    String getSensorDataJSON() {
        StaticJsonDocument<512> doc;
        doc["type"] = "sensor_data";
        doc["power"] = powerState;
        doc["calibrated"] = calibrated;
        
        JsonArray values = doc.createNestedArray("values");
        JsonArray raw_values = doc.createNestedArray("raw_values");
        JsonArray min_array = doc.createNestedArray("min_values");
        JsonArray max_array = doc.createNestedArray("max_values");
        
        for (int i = 0; i < NUM_SENSORS; i++) {
            values.add(readCalibratedSensor(i));
            raw_values.add((int)filteredValues[i]);
            min_array.add(minValues[i]);
            max_array.add(maxValues[i]);
        }
        
        doc["position"] = readLinePosition();
        doc["sum"] = getSensorSum();
        
        String jsonString;
        serializeJson(doc, jsonString);
        return jsonString;
    }
    
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
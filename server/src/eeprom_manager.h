/**
 * ARCHIVO: eeprom_manager.h
 * DESCRIPCIÓN: Gestión de configuración en EEPROM
 * FUNCIONALIDAD: Guardar/cargar configuración, checksum, valores por defecto
 */

#ifndef EEPROM_MANAGER_H
#define EEPROM_MANAGER_H

#include <EEPROM.h>
#include <ArduinoJson.h>
#include "config.h"

class EEPROMManager {
private:
    /**
     * Calcular checksum para verificación de integridad
     * @param config Configuración a verificar
     * @return Checksum calculado
     */
    uint32_t calculateChecksum(const RobotConfig& config) {
        uint32_t checksum = 0;
        const uint8_t* data = (const uint8_t*)&config;
        for (size_t i = 0; i < sizeof(RobotConfig) - sizeof(uint32_t); i++) {
            checksum += data[i];
        }
        return checksum;
    }
    
public:
    /**
     * Guardar configuración en EEPROM
     * @param config Configuración a guardar
     * @return true si se guardó exitosamente
     */
    bool saveConfig(const RobotConfig& config) {
        RobotConfig configToSave = config;
        configToSave.checksum = calculateChecksum(configToSave);
        EEPROM.put(EEPROM_CONFIG_ADDR, configToSave);
        return true;
    }
    
    /**
     * Cargar configuración desde EEPROM
     * @param config Configuración donde cargar los datos
     * @return true si la configuración es válida
     */
    bool loadConfig(RobotConfig& config) {
        EEPROM.get(EEPROM_CONFIG_ADDR, config);
        bool valid = (calculateChecksum(config) == config.checksum);
        
        if (!valid) {
            Serial.println("{\"type\":\"eeprom\",\"message\":\"Configuración EEPROM inválida, usando valores por defecto\"}");
        }
        
        return valid;
    }
    
    /**
     * Inicializar configuración con valores por defecto
     * @param config Configuración a inicializar
     */
    void initializeDefaultConfig(RobotConfig& config) {
        config.kp = DEFAULT_KP;
        config.ki = DEFAULT_KI;
        config.kd = DEFAULT_KD;
        config.baseSpeed = DEFAULT_BASE_SPEED;
        config.wheelDiameter = WHEEL_DIAMETER_MM;
        config.wheelDistance = WHEEL_DISTANCE_MM;
        config.rcDeadzone = RC_DEADZONE;
        config.rcMaxThrottle = RC_MAX_THROTTLE;
        config.rcMaxSteering = RC_MAX_STEERING;
        
        // Valores por defecto para calibración de sensores
        for (int i = 0; i < NUM_SENSORS; i++) {
            config.sensorMin[i] = 1023;
            config.sensorMax[i] = 0;
        }
        
        Serial.println("{\"type\":\"eeprom\",\"message\":\"Configuración por defecto inicializada\"}");
    }
    
    /**
     * Imprimir configuración actual por serial
     * @param config Configuración a imprimir
     */
    void printConfig(const RobotConfig& config) {
        StaticJsonDocument<512> doc;
        doc["type"] = "config";
        doc["kp"] = config.kp;
        doc["ki"] = config.ki;
        doc["kd"] = config.kd;
        doc["base_speed"] = config.baseSpeed;
        doc["wheel_diameter"] = config.wheelDiameter;
        doc["wheel_distance"] = config.wheelDistance;
        doc["rc_deadzone"] = config.rcDeadzone;
        doc["rc_max_throttle"] = config.rcMaxThrottle;
        doc["rc_max_steering"] = config.rcMaxSteering;
        
        JsonArray min_vals = doc.createNestedArray("sensor_min");
        JsonArray max_vals = doc.createNestedArray("sensor_max");
        
        for (int i = 0; i < NUM_SENSORS; i++) {
            min_vals.add(config.sensorMin[i]);
            max_vals.add(config.sensorMax[i]);
        }
        
        String jsonString;
        serializeJson(doc, jsonString);
        Serial.println(jsonString);
    }
    
    /**
     * Borrar configuración EEPROM
     */
    void clearConfig() {
        for (int i = EEPROM_CONFIG_ADDR; i < EEPROM_CONFIG_ADDR + sizeof(RobotConfig); i++) {
            EEPROM.write(i, 0);
        }
        Serial.println("{\"type\":\"eeprom\",\"message\":\"EEPROM borrada\"}");
    }
};

#endif
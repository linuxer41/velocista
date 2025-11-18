/**
 * ARCHIVO: eeprom_manager.h
 * DESCRIPCIÓN: Gestión de configuración en EEPROM
 * FUNCIONALIDAD: Guardar/cargar configuración, checksum, valores por defecto
 */

#ifndef EEPROM_MANAGER_H
#define EEPROM_MANAGER_H

#include <EEPROM.h>
#include "config.h"
#include "models.h"

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
            CommunicationSerializer::sendSystemMessage("Configuracion EEPROM invalida, usando valores por defecto");
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

        CommunicationSerializer::sendSystemMessage("Configuracion por defecto inicializada");
    }
    
    
    /**
     * Borrar configuración EEPROM
     */
    void clearConfig() {
        for (int i = EEPROM_CONFIG_ADDR; i < EEPROM_CONFIG_ADDR + sizeof(RobotConfig); i++) {
            EEPROM.write(i, 0);
        }
        CommunicationSerializer::sendSystemMessage("EEPROM borrada");
    }
};

#endif
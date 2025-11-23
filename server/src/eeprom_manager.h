/**
 * ARCHIVO: eeprom.h
 * DESCRIPCIÓN: Clase EEPROM para gestión de configuración
 */

#ifndef EEPROM_H
#define EEPROM_H

#include <EEPROM.h>
#include <Arduino.h>
#include "config.h"

class EEPROMManager {
public:
  EEPROMManager() {
    load();
  }

  RobotConfig& getConfig() {
    return config;
  }

  void load() {
    EEPROM.get(EEPROM_CONFIG_ADDR, config);
    if (config.checksum != 1234567890) {
      Serial.println("Config inválida, cargando valores por defecto");
      config.kp = DEFAULT_KP;
      config.ki = DEFAULT_KI;
      config.kd = DEFAULT_KD;
      config.baseSpeed = DEFAULT_BASE_SPEED;
      config.wheelDiameter = WHEEL_DIAMETER_MM;
      config.wheelDistance = WHEEL_DISTANCE_MM;
      config.rcDeadzone = RC_DEADZONE;
      config.rcMaxThrottle = RC_MAX_THROTTLE;
      config.rcMaxSteering = RC_MAX_STEERING;
      for (int i = 0; i < NUM_SENSORS; i++) {
        config.sensorMin[i] = 0;
        config.sensorMax[i] = 1023;
      }
      config.checksum = 1234567890;
      save();
    }
  }

  void save() {
    EEPROM.put(EEPROM_CONFIG_ADDR, config);
  }
};

// Función global para guardar configuración
void saveConfig() {
  EEPROM.put(EEPROM_CONFIG_ADDR, config);
}

#endif
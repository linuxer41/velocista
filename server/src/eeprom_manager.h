/**
 * ARCHIVO: eeprom_manager.h
 * DESCRIPCIÓN: Clase EEPROM para gestión de configuración
 */

#ifndef EEPROM_MANAGER_H
#define EEPROM_MANAGER_H

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
    if (config.checksum != 1234567892) {
      // PID para línea
      config.lineKp = DEFAULT_LINE_KP;
      config.lineKi = DEFAULT_LINE_KI;
      config.lineKd = DEFAULT_LINE_KD;
      // PID para motor izquierdo
      config.leftKp = DEFAULT_LEFT_KP;
      config.leftKi = DEFAULT_LEFT_KI;
      config.leftKd = DEFAULT_LEFT_KD;
      // PID para motor derecho
      config.rightKp = DEFAULT_RIGHT_KP;
      config.rightKi = DEFAULT_RIGHT_KI;
      config.rightKd = DEFAULT_RIGHT_KD;
      config.baseSpeed = DEFAULT_BASE_SPEED;
      config.wheelDiameter = WHEEL_DIAMETER_MM;
      config.wheelDistance = WHEEL_DISTANCE_MM;
      config.rcDeadzone = RC_DEADZONE;
      config.rcMaxThrottle = RC_MAX_THROTTLE;
      config.rcMaxSteering = RC_MAX_STEERING;
      config.cascadeMode = DEFAULT_CASCADE;
      config.telemetry= DEFAULT_TELEMETRY_ENABLED;
      memcpy(config.featureEnables, DEFAULT_FEATURE_ENABLES, sizeof(DEFAULT_FEATURE_ENABLES));
      config.operationMode = DEFAULT_OPERATION_MODE;
      config.baseRPM = DEFAULT_BASE_RPM;
      for (int i = 0; i < NUM_SENSORS; i++) {
        config.sensorMin[i] = 0;
        config.sensorMax[i] = 1023;
      }
      config.checksum = 1234567892;
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
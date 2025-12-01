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
      config.restoreDefaults();
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
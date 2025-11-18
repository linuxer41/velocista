/**
 * ARCHIVO: config.h
 * DESCRIPCIÓN: Configuraciones globales, pines y estructuras de datos
 * CONTIENE: Definiciones de pines, constantes, estructuras EEPROM y enums
 */

#ifndef CONFIG_H
#define CONFIG_H

#include <EEPROM.h>
#include <ArduinoJson.h>

// =============================================================================
// CONFIGURACIÓN DE PINES
// =============================================================================

// Pines para controlador DRV8833 - Motores
#define MOTOR_LEFT_PIN1   5
#define MOTOR_LEFT_PIN2   6
#define MOTOR_RIGHT_PIN1  9
#define MOTOR_RIGHT_PIN2  10

// Array de sensores de línea (A0-A5) + Pin de alimentación
#define NUM_SENSORS       6
const int SENSOR_PINS[NUM_SENSORS] = {A0, A1, A2, A3, A4, A5};
#define SENSOR_POWER_PIN  11  // Pin para encender/apagar LEDs de sensores

// Pines para encoders (interrupciones)
#define ENCODER_LEFT_A    2
#define ENCODER_LEFT_B    7
#define ENCODER_RIGHT_A   3
#define ENCODER_RIGHT_B   8

// Sensor ultrasónico (obstáculos)
#define TRIG_PIN          12
#define ECHO_PIN          13

// LEDs de indicación de modo
#define MODE_LED_PIN      13  // LED integrado para indicar modo

// =============================================================================
// CONFIGURACIÓN AVANZADA
// =============================================================================

// Configuración encoders - Motor N20 300RPM con reductor 10:1
const int PULSES_PER_REVOLUTION = 36;
const float WHEEL_DIAMETER_MM = 32.0;   // Diámetro de ruedas en mm
const float WHEEL_DISTANCE_MM = 85.0;   // Distancia entre ruedas en mm
const int MAX_SPEED = 200;              // Velocidad máxima PWM
const int EEPROM_CONFIG_ADDR = 0;       // Dirección EEPROM para configuración

// =============================================================================
// CONFIGURACIÓN CONTROL REMOTO
// =============================================================================

const int RC_DEADZONE = 10;             // Zona muerta para joystick
const int RC_MAX_THROTTLE = 255;        // Throttle máximo
const int RC_MAX_STEERING = 150;        // Steering máximo

// =============================================================================
// CONFIGURACIÓN SENSORES
// =============================================================================

const unsigned long SENSOR_READ_DELAY = 2;  // ms entre lectura de sensores

// =============================================================================
// PARÁMETROS PID POR DEFECTO
// =============================================================================

const double DEFAULT_KP = 2.0;          // Ganancia proporcional
const double DEFAULT_KI = 0.05;         // Ganancia integral  
const double DEFAULT_KD = 0.8;          // Ganancia derivativa
const int DEFAULT_BASE_SPEED = 150;     // Velocidad base

// =============================================================================
// ESTRUCTURA CONFIGURACIÓN EEPROM
// =============================================================================

struct RobotConfig {
  double kp;                            // Ganancia proporcional PID
  double ki;                            // Ganancia integral PID
  double kd;                            // Ganancia derivativa PID
  int baseSpeed;                        // Velocidad base
  float wheelDiameter;                  // Diámetro de rueda en mm
  float wheelDistance;                  // Distancia entre ruedas en mm
  int sensorMin[NUM_SENSORS];           // Valores mínimos de sensores
  int sensorMax[NUM_SENSORS];           // Valores máximos de sensores
  int rcDeadzone;                       // Zona muerta control remoto
  int rcMaxThrottle;                    // Throttle máximo control remoto
  int rcMaxSteering;                    // Steering máximo control remoto
  uint32_t checksum;                    // Checksum para verificación
};

// =============================================================================
// MODOS OPERACIÓN
// =============================================================================

enum OperationMode {
  MODE_CALIBRATION,      // Calibración de sensores
  MODE_COMPETITION,      // Modo competencia (máxima performance)
  MODE_TUNING,           // Ajuste de parámetros PID
  MODE_DEBUG,            // Modo depuración (telemetría completa)
  MODE_REMOTE_CONTROL    // Control remoto por JSON
};

#endif
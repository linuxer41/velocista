/**
 * ARCHIVO: config.h
 * DESCRIPCIÓN: Configuraciones globales, pines y estructuras de datos
 * CONTIENE: Definiciones de pines, constantes, estructuras EEPROM y enums
 */

#ifndef CONFIG_H
#define CONFIG_H



#include <Arduino.h>

// =============================================================================
// CONFIGURACIÓN DE PINES
// =============================================================================

// Pines para controlador DRV8833 - Motores
#define MOTOR_LEFT_PIN1   10
#define MOTOR_LEFT_PIN2   9
#define MOTOR_RIGHT_PIN1  6
#define MOTOR_RIGHT_PIN2  5

// Array de sensores de línea (A5-A0, right to left)
#define NUM_SENSORS       6
const int SENSOR_PINS[NUM_SENSORS] = {A0, A1, A2, A3, A4, A5};
#define SENSOR_POWER_PIN  12  // Pin para encender/apagar LEDs de sensores

// Pines para encoders (interrupciones)
#define ENCODER_LEFT_A    2
#define ENCODER_LEFT_B    7
#define ENCODER_RIGHT_A   3
#define ENCODER_RIGHT_B   8

// Sensor ultrasónico (obstáculos)
// #define TRIG_PIN          12
// #define ECHO_PIN          13

// LEDs de indicación de modo
#define MODE_LED_PIN      13  // LED integrado para indicar modo

// =============================================================================
// ESTRUCTURA CONFIGURACIÓN EEPROM
// =============================================================================

struct RobotConfig {
   float kp;                             // Ganancia proporcional PID
   float ki;                             // Ganancia integral PID
   float kd;                             // Ganancia derivativa PID
   int16_t baseSpeed;                    // Velocidad base
   float wheelDiameter;                  // Diámetro de rueda en mm
   float wheelDistance;                  // Distancia entre ruedas en mm
   int16_t sensorMin[6];                 // Valores mínimos de sensores
   int16_t sensorMax[6];                 // Valores máximos de sensores
   int16_t rcDeadzone;                   // Zona muerta control remoto
   int16_t rcMaxThrottle;                // Throttle máximo control remoto
   int16_t rcMaxSteering;                // Steering máximo control remoto
   uint32_t checksum;                    // Checksum para verificación
};

RobotConfig config;

// =============================================================================
// CONFIGURACIÓN AVANZADA
// =============================================================================

// Configuración encoders - Motor N20 358RPM con reductor 10:1
const int16_t PULSES_PER_REVOLUTION = 36;
const float WHEEL_DIAMETER_MM = 32.0f;  // Diámetro de ruedas en mm
const float WHEEL_DISTANCE_MM = 85.0f;  // Distancia entre ruedas en mm
const int16_t MAX_SPEED = 225;          // Velocidad máxima PWM
const int16_t EEPROM_CONFIG_ADDR = 0;   // Dirección EEPROM para configuración

// =============================================================================
// CONFIGURACIÓN CONTROL REMOTO
// =============================================================================

const int16_t RC_DEADZONE = 10;         // Zona muerta para joystick
const int16_t RC_MAX_THROTTLE = 255;    // Throttle máximo
const int16_t RC_MAX_STEERING = 150;    // Steering máximo

// =============================================================================
// CONFIGURACIÓN SENSORES
// =============================================================================

const uint16_t SENSOR_READ_DELAY = 2;  // ms entre lectura de sensores

// =============================================================================
// PARÁMETROS PID POR DEFECTO
// =============================================================================

const float DEFAULT_KP = 0.01f;          // Ganancia proporcional
const float DEFAULT_KI = 0.02f;         // Ganancia integral
const float DEFAULT_KD = 1.15f;          // Ganancia derivativa
const int16_t DEFAULT_BASE_SPEED = 150; // Velocidad base
const float SPEED_CORRECTION_K = 1.0f;  // Ganancia para corrección de velocidad

// =============================================================================
// MODOS OPERACIÓN
// =============================================================================

enum OperationMode {
  MODE_LINE_FOLLOWING,   // Seguir línea
  MODE_REMOTE_CONTROL    // Control remoto
};

#endif
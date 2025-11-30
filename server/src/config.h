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
// ENUMERACIONES
// =============================================================================

enum OperationMode {
  MODE_IDLE,             // Idle - read sensors only
  MODE_LINE_FOLLOWING,   // Seguir línea
  MODE_REMOTE_CONTROL    // Control remoto
};

// =============================================================================
// ESTRUCTURA CONFIGURACIÓN EEPROM
// =============================================================================

struct RobotConfig {
   // PID para línea
   float lineKp;                         // Ganancia proporcional PID línea
   float lineKi;                         // Ganancia integral PID línea
   float lineKd;                         // Ganancia derivativa PID línea
   // PID para motor izquierdo
   float leftKp;                         // Ganancia proporcional PID motor izq
   float leftKi;                         // Ganancia integral PID motor izq
   float leftKd;                         // Ganancia derivativa PID motor izq
   // PID para motor derecho
   float rightKp;                        // Ganancia proporcional PID motor der
   float rightKi;                        // Ganancia integral PID motor der
   float rightKd;                        // Ganancia derivativa PID motor der
   int16_t baseSpeed;                    // Velocidad base
   float wheelDiameter;                  // Diámetro de rueda en mm
   float wheelDistance;                  // Distancia entre ruedas en mm
   int16_t sensorMin[6];                 // Valores mínimos de sensores
   int16_t sensorMax[6];                 // Valores máximos de sensores
   int16_t rcDeadzone;                   // Zona muerta control remoto
   int16_t rcMaxThrottle;                // Throttle máximo control remoto
   int16_t rcMaxSteering;                // Steering máximo control remoto
   bool cascadeMode;                     // Modo cascada activado/desactivado
   bool telemetry;                // Habilitar/deshabilitar telemetry (0=deshabilitado, 1=habilitado)
   OperationMode operationMode;          // Modo de operación actual
   float baseRPM;                        // RPM base para control de velocidad
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
const int16_t MAX_SPEED = 230;          // Velocidad máxima PWM
const int16_t EEPROM_CONFIG_ADDR = 0;   // Dirección EEPROM para configuración

// =============================================================================
// CONFIGURACIÓN CONTROL REMOTO
// =============================================================================

const int16_t RC_DEADZONE = 10;         // Zona muerta para joystick
const int16_t RC_MAX_THROTTLE = 255;    // Throttle máximo
const int16_t RC_MAX_STEERING = 150;    // Steering máximo

// Batería
const uint8_t BATTERY_PIN = A7;         // Pin para medir voltaje de batería
const float BATTERY_FACTOR = 10.0 / 1023.0; // Factor de conversión (divisor resistivo 2x 10k)

// Tiempos de bucle
const uint16_t LOOP_LINE_MS  = 10;   // 100 Hz para PID de línea
const uint16_t LOOP_SPEED_MS = 5;    // 200 Hz para PID de velocidad

// Velocidad base
const float BASE_RPM = 120.0f; // RPM base para control de velocidad

// Telemetry
const unsigned long REALTIME_INTERVAL_MS = 100; // Intervalo de envío de telemetry en ms

// =============================================================================
// VALORES POR DEFECTO
// =============================================================================

// PID para línea (más agresivo para corrección rápida)
const float DEFAULT_LINE_KP = 2.0;
const float DEFAULT_LINE_KI = 0.01;
const float DEFAULT_LINE_KD = 0.05;

// PID para motores (más agresivo para alcanzar RPM objetivo)
const float DEFAULT_LEFT_KP = 0.5;
const float DEFAULT_LEFT_KI = 0.0;
const float DEFAULT_LEFT_KD = 0.01;

const float DEFAULT_RIGHT_KP = 0.5;
const float DEFAULT_RIGHT_KI = 0.0;
const float DEFAULT_RIGHT_KD = 0.01;

const int16_t DEFAULT_BASE_SPEED = 200;
const bool DEFAULT_CASCADE = true;
const bool DEFAULT_TELEMETRY_ENABLED = true;
#define DEFAULT_OPERATION_MODE MODE_IDLE
const float DEFAULT_BASE_RPM = 120.0f;

// =============================================================================
// ENUMERACIONES
// =============================================================================

#endif
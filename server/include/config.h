/**
 * ARCHIVO: config.h
 * DESCRIPCIÓN: Configuraciones globales, pines y estructuras de datos
 * CONTIENE: Definiciones de pines, constantes, estructuras EEPROM y enums
 */

#ifndef CONFIG_H
#define CONFIG_H



#include <Arduino.h>

// =============================================================================
// CONSTANTES GLOBALES
// =============================================================================

// EEPROM address for config
const int16_t EEPROM_CONFIG_ADDR = 0;

// Constants
const int16_t DEFAULT_RC_DEADZONE = 10;
const int16_t DEFAULT_RC_MAX_THROTTLE = 255;
const int16_t DEFAULT_RC_MAX_STEERING = 150;
const int16_t DEFAULT_PULSES_PER_REVOLUTION = 36;
const float DEFAULT_WHEEL_DIAMETER_MM = 30.0f;
const float DEFAULT_WHEEL_DISTANCE_MM = 100.0f;
const uint16_t DEFAULT_LOOP_LINE_MS = 10;
const uint16_t DEFAULT_LOOP_SPEED_MS = 5;
const unsigned long DEFAULT_TELEMTRY_INTERVAL_MS = 100;
const float DEFAULT_ROBOT_WEIGHT = 135.0f;

// Magic numbers for sensor and control logic

// QTR sensor position calculation constants
const float QTR_POSITION_SCALE = 4000.0f / 3.5f;  // ≈1142.857
const float QTR_CENTER_OFFSET = 3.5f;

// Límites de seguridad para proteger motores
const int16_t LIMIT_MAX_PWM = 255;    // PWM máximo seguro
const float LIMIT_MAX_RPM = 4000.0f;  // RPM máximo seguro

// =============================================================================
// CONFIGURACIÓN DE PINES
// =============================================================================
// Pines para controlador DRV8833 - Motores
#define MOTOR_LEFT_PIN1   10
#define MOTOR_LEFT_PIN2   9
#define MOTOR_RIGHT_PIN1  6
#define MOTOR_RIGHT_PIN2  5

// Array de sensores de línea (A7-A0, right to left)
#define NUM_SENSORS       8
const int SENSOR_PINS[NUM_SENSORS] = {A0, A1, A2, A3, A4, A5, A6, A7};
#define SENSOR_POWER_PIN  12  // Pin para encender/apagar LEDs de sensores

// Pines para encoders (interrupciones)
#define ENCODER_LEFT_A    2
#define ENCODER_LEFT_B    7
#define ENCODER_RIGHT_A   3
#define ENCODER_RIGHT_B   8

// Sensor ultrasónico (obstáculos) - No implementado
// #define TRIG_PIN          11
// #define ECHO_PIN          4

// LEDs de indicación de modo
#define MODE_LED_PIN      13  // LED integrado para indicar modo

// =============================================================================
// VALORES POR DEFECTO
// =============================================================================

// PID para línea (más agresivo para corrección rápida)
const float DEFAULT_LINE_KP = 4.500;
const float DEFAULT_LINE_KI = 0.001;
const float DEFAULT_LINE_KD = 0.150;

// PID para motores (más agresivo para alcanzar RPM objetivo)
const float DEFAULT_LEFT_KP = 0.590;
const float DEFAULT_LEFT_KI = 0.001;
const float DEFAULT_LEFT_KD = 0.0025;

const float DEFAULT_RIGHT_KP = 0.590;
const float DEFAULT_RIGHT_KI = 0.001;
const float DEFAULT_RIGHT_KD = 0.050;

// =============================================================================
// ENUMERACIONES
// =============================================================================

enum OperationMode {
  MODE_IDLE,             // Idle - read sensors only
  MODE_LINE_FOLLOWING,   // Seguir línea
  MODE_REMOTE_CONTROL    // Control remoto
};

// Features configuration class
class FeaturesConfig {
public:
  bool medianFilter : 1;      // 0
  bool movingAverage : 1;     // 1
  bool kalmanFilter : 1;      // 2
  bool hysteresis : 1;        // 3
  bool deadZone : 1;          // 4
  bool lowPass : 1;           // 5
  bool dynamicLinePid : 1;     // 6
  bool speedProfiling : 1;     // 7
  bool turnDirection : 1;     // 8

  // Serialize to string [0,1,0,...]
  const char* serialize();

  // Deserialize from command like "0,1,0,1,1,1,0,1,1"
  bool deserialize(const char* cmd);

  void setFeature(uint8_t idx, bool value);  // Cambiado de int a uint8_t

  bool getFeature(uint8_t idx);  // Cambiado de int a uint8_t
};

// =============================================================================
// VALORES POR DEFECTO
// =============================================================================

const bool DEFAULT_CASCADE = false;
const bool DEFAULT_TELEMETRY_ENABLED = false;
const FeaturesConfig DEFAULT_FEATURES = {false, false, false, false, false, false, false, false, false};
const OperationMode DEFAULT_OPERATION_MODE = MODE_IDLE;
const int16_t DEFAULT_BASE_SPEED = 150;
const float DEFAULT_BASE_RPM = 400.0f;
const int16_t DEFAULT_MAX_SPEED = 250;
const float DEFAULT_MAX_RPM = 2000.0f;


// =============================================================================
// CONFIGURACIÓN EEPROM
// =============================================================================

class RobotConfig {
public:
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
   float rightKi;                         // Ganancia integral PID motor der
   float rightKd;                         // Ganancia derivativa PID motor der
   int16_t basePwm;                    // Velocidad base
   float wheelDiameter;                  // Diámetro de rueda en mm
   float wheelDistance;                  // Distancia entre ruedas en mm
   int16_t sensorMin[8];                 // Valores mínimos de sensores
   int16_t sensorMax[8];                 // Valores máximos de sensores
   int16_t rcDeadzone;                   // Zona muerta control remoto
   int16_t rcMaxThrottle;                // Throttle máximo control remoto
   int16_t rcMaxSteering;                // Steering máximo control remoto
   bool cascadeMode;                     // Modo cascada activado/desactivado
   bool telemetry;                // Habilitar/deshabilitar telemetry (0=deshabilitado, 1=habilitado)
   // Features configuration
   FeaturesConfig features;
   OperationMode operationMode;          // Cambiado de OperationMode a uint8_t
   float baseRPM;                        // RPM base para control de velocidad
   int16_t maxPwm;                         // Cambiado de int a int16_t
   float maxRpm;                         // RPM máximo para control de velocidad
   int16_t pulsesPerRevolution;
   uint16_t loopLineMs;
   uint16_t loopSpeedMs;
   unsigned long telemetryIntervalMs;
   float robotWeight;                    // Peso del robot en gramos
   uint32_t checksum;                    // Checksum para verificación

   void restoreDefaults();
};

// =============================================================================
// ENUMERACIONES
// =============================================================================

// Global config instance
extern RobotConfig config;

#endif
/**
 * ARCHIVO: config.h
 * DESCRIPCIÓN: Configuraciones globales, pines y estructuras de datos para ESP32 con ESP-IDF
 * CONTIENE: Definiciones de pines, constantes, estructuras NVS y enums
 */

#ifndef CONFIG_H
#define CONFIG_H

#include <stdint.h>
#include <string.h>
#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>
#include <esp_adc/adc_oneshot.h>

// =============================================================================
// ENUMERACIONES
// =============================================================================

enum OperationMode {
  MODE_IDLE,             // Idle - read sensors only
  MODE_LINE_FOLLOWING,   // Seguir línea
  MODE_REMOTE_CONTROL    // Control remoto
};

enum SensorState { NORMAL, ALL_BLACK, ALL_WHITE };
enum Location { LEFT, RIGHT };

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
  bool turnDirection : 1;      // 8

  // Serialize to string [0,1,0,...]
  const char* serialize();

  // Deserialize from command like "0,1,0,1,1,1,0,1,1"
  bool deserialize(const char* cmd);

  void setFeature(uint8_t idx, bool value);  // Cambiado de int a uint8_t

  bool getFeature(uint8_t idx);  // Cambiado de int a uint8_t
};

// =============================================================================
// CONFIGURACIÓN DE PINES PARA ESP32
// =============================================================================
// Pines para controlador DRV8833 - Motores
#define MOTOR_LEFT_PIN1   19
#define MOTOR_LEFT_PIN2   21
#define MOTOR_RIGHT_PIN1  22
#define MOTOR_RIGHT_PIN2  23

// Multiplexor 74HC4067 para 16 sensores
#define NUM_SENSORS       16
#define ADC_PIN           34  // GPIO34 (ADC1_6)
#define MUX_S0            35  // Select pins for 74HC4067
#define MUX_S1            32
#define MUX_S2            33
#define MUX_S3            25
#define SENSOR_POWER_PIN  26  // Pin para encender/apagar LEDs IR de sensores

// Pines para encoders (interrupciones)
#define ENCODER_LEFT_A    2
#define ENCODER_LEFT_B    4
#define ENCODER_RIGHT_A   5
#define ENCODER_RIGHT_B   18

// LEDs de indicación de modo
#define MODE_LED_PIN      12  // LED para indicar modo
#define CALIBRATION_BUTTON_PIN 13  // Botón para calibración

// UART
#define UART_NUM UART_NUM_0
#define BUF_SIZE 1024

// LEDC
#define LEDC_TIMER              LEDC_TIMER_0
#define LEDC_MODE               LEDC_LOW_SPEED_MODE
#define LEDC_DUTY_RES           LEDC_TIMER_13_BIT
#define LEDC_FREQUENCY          5000
#define LEDC_LEFT_CHANNEL       LEDC_CHANNEL_0
#define LEDC_RIGHT_CHANNEL      LEDC_CHANNEL_1

// =============================================================================
// CONSTANTES GLOBALES
// =============================================================================

// NVS namespace for ESP-IDF
extern const char* NVS_NAMESPACE;

// Magic numbers for sensor and control logic

// QTR sensor position calculation constants
const float QTR_POSITION_SCALE = 4000.0f / 3.5f;  // ≈1142.857
const float QTR_CENTER_OFFSET = 3.5f;

// Límites de seguridad para proteger motores
const int16_t LIMIT_MAX_PWM = 255;    // PWM máximo seguro
const float LIMIT_MAX_RPM = 4000.0f;  // RPM máximo seguro

// =============================================================================
// VALORES POR DEFECTO
// =============================================================================
// Constants
const int16_t DEFAULT_RC_DEADZONE = 10;
const int16_t DEFAULT_RC_MAX_THROTTLE = 2000;
const int16_t DEFAULT_RC_MAX_STEERING = 1000;
const int16_t DEFAULT_PULSES_PER_REVOLUTION = 36;
const float DEFAULT_WHEEL_DIAMETER_MM = 30.0f;
const float DEFAULT_WHEEL_DISTANCE_MM = 100.0f;
const uint16_t DEFAULT_LOOP_LINE_MS = 10;
const uint16_t DEFAULT_LOOP_SPEED_MS = 5;
const unsigned long DEFAULT_TELEMTRY_INTERVAL_MS = 100;
const float DEFAULT_ROBOT_WEIGHT = 205.0f;

// PID para línea
const float DEFAULT_LINE_KP = 1.500;
const float DEFAULT_LINE_KI = 0.001;
const float DEFAULT_LINE_KD = 0.050;

// PID para motores
const float DEFAULT_LEFT_KP = 0.590;
const float DEFAULT_LEFT_KI = 0.001;
const float DEFAULT_LEFT_KD = 0.0025;

const float DEFAULT_RIGHT_KP = 0.590;
const float DEFAULT_RIGHT_KI = 0.001;
const float DEFAULT_RIGHT_KD = 0.050;

// Configuraciones por defecto
const bool DEFAULT_CASCADE = true;
const bool DEFAULT_TELEMETRY_ENABLED = true;
const FeaturesConfig DEFAULT_FEATURES = {false, false, false, false, false, false, false, false, false};
const OperationMode DEFAULT_OPERATION_MODE = MODE_IDLE;
const int16_t DEFAULT_BASE_PWM = 200;
const float DEFAULT_BASE_RPM = 600.0f;
const int16_t DEFAULT_MAX_PWM = 250;
const float DEFAULT_MAX_RPM = 2000.0f;

// Structs
struct TelemetryData {
    float linePos;
    float curvature;
    uint8_t sensorState;
    int16_t sensors[16];
    uint32_t uptime;
    float linePidOut, lineError, lineIntegral, lineDeriv, lineProportional;
    float lPidOut, lError, lIntegral, lDeriv, lProportional;
    float rPidOut, rError, rProportional, rIntegral, rDeriv;
    float lRpm, rRpm, lFilteredRpm, rFilteredRpm, lTargetRpm, rTargetRpm;
    int16_t lPwm, rPwm;
    int32_t encLForward, encRForward, encLBackward, encRBackward;
    float leftSpeedCms, rightSpeedCms;
    float battery;
    uint32_t loopTime;
};

struct SharedData {
    float linePosition;
    int16_t sensorValues[16];
    int16_t rawSensorValues[16];
    SensorState sensorState;
    float leftTargetRPM;
    float rightTargetRPM;
    float throttle;
    float steering;
    bool telemetryEnabled;
    OperationMode operationMode;
    bool cascadeMode;
    SemaphoreHandle_t mutex;
};

// =============================================================================
// CONFIGURACIÓN PREFERENCES (NVS equivalente para ESP32)
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
   int16_t sensorMin[16];                 // Valores mínimos de sensores
   int16_t sensorMax[16];                 // Valores máximos de sensores
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

// Forward declaration
class Robot;

// Global config instance
extern RobotConfig config;
extern SharedData sharedData;

// Other globals
extern adc_oneshot_unit_handle_t adc_handle;
extern char serBuf[64];
extern bool lineReady;
extern uint8_t idx;
extern class Motor* leftMotorPtr;
extern class Motor* rightMotorPtr;

#endif
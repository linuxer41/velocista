/**
 * ARCHIVO: debugger.h
 * DESCRIPCIÓN: Clase Debugger para manejo centralizado de mensajes seriales
 */

#ifndef DEBUGGER_H
#define DEBUGGER_H

#include <Arduino.h>

// Struct para datos de debug
struct DebugData {
  // Posición y modo
  float linePos;
  bool cascade;
  uint8_t mode;  // Cambiado de OperationMode a uint8_t
  float curvature;
  uint8_t sensorState;

  // Sensores
  int16_t sensors[6];  // Cambiado de int a int16_t
  uint32_t uptime;  // Cambiado de unsigned long a uint32_t

  // PID de línea
  float lineKp, lineKi, lineKd;
  float linePidOut, lineError, lineIntegral, lineDeriv;

  // PID izquierdo
  float leftKp, leftKi, leftKd;
  float lPidOut, lError, lIntegral, lDeriv;

  // PID derecho
  float rightKp, rightKi, rightKd;
  float rPidOut, rError, rIntegral, rDeriv;

  // Velocidades
  float lRpm, rRpm, lTargetRpm, rTargetRpm;
  int16_t lSpeed, rSpeed;  // Cambiado de int a int16_t

  // Velocidades base
  int16_t baseSpeed;  // Cambiado de int a int16_t
  float baseRPM;
  int16_t maxSpeed;  // Cambiado de int a int16_t

  // Ruedas
  float wheelDiameter;
  float wheelDistance;

  // Contadores encoder
  int32_t encLBackward, encRBackward;  // Cambiado de long a int32_t

  // Velocidades lineales (cm/s)
  float leftSpeedCms, rightSpeedCms;

  // Sistema
  float battery;
  uint32_t loopTime;  // Cambiado de unsigned long a uint32_t
  int16_t freeMem;  // Cambiado de int a int16_t
  int32_t encL, encR;  // Cambiado de long a int32_t

};

class Debugger {
public:
  Debugger() {}

  // Mensaje de sistema (comandos, estados, etc.)
  void systemMessage(const char* msg) {
    Serial.print(F("type:1|"));
    Serial.println(msg);
  }


  // Datos de debug telemetry (telemetría reducida)
  void telemetryData(DebugData& data, bool endLine = true) {
    if (endLine) Serial.print(F("type:4|"));
    Serial.print(F("LINE:["));
    Serial.print(data.linePos, 2); Serial.print(F(","));
    Serial.print(data.lineError, 2); Serial.print(F(","));
    Serial.print(data.lineIntegral, 2); Serial.print(F(","));
    Serial.print(data.lineDeriv, 2); Serial.print(F(","));
    Serial.print(data.linePidOut, 2); Serial.print(F("]"));
    Serial.print(F("|LEFT:["));
    Serial.print(data.lRpm, 2); Serial.print(F(","));
    Serial.print(data.lTargetRpm, 2); Serial.print(F(","));
    Serial.print(data.lSpeed); Serial.print(F(","));
    Serial.print(data.encL); Serial.print(F(","));
    Serial.print(data.encLBackward); Serial.print(F("]"));
    Serial.print(F("|RIGHT:["));
    Serial.print(data.rRpm, 2); Serial.print(F(","));
    Serial.print(data.rTargetRpm, 2); Serial.print(F(","));
    Serial.print(data.rSpeed); Serial.print(F(","));
    Serial.print(data.encR); Serial.print(F(","));
    Serial.print(data.encRBackward); Serial.print(F("]"));
    Serial.print(F("|PID:["));
    Serial.print(data.linePidOut, 2); Serial.print(F(","));
    Serial.print(data.lPidOut, 2); Serial.print(F(","));
    Serial.print(data.rPidOut, 2); Serial.print(F("]"));
    Serial.print(F("|SPEED_CMS:["));
    Serial.print(data.leftSpeedCms, 2); Serial.print(F(","));
    Serial.print(data.rightSpeedCms, 2); Serial.print(F("]"));
    Serial.print(F("|QTR:["));
    Serial.print(data.sensors[0]); Serial.print(F(","));
    Serial.print(data.sensors[1]); Serial.print(F(","));
    Serial.print(data.sensors[2]); Serial.print(F(","));
    Serial.print(data.sensors[3]); Serial.print(F(","));
    Serial.print(data.sensors[4]); Serial.print(F(","));
    Serial.print(data.sensors[5]); Serial.print(F("]"));
    Serial.print(F("|BATT:"));
    Serial.print(data.battery, 2);
    Serial.print(F("|LOOP_US:"));
    Serial.print(data.loopTime);
    Serial.print(F("|FREE_MEM:"));
    Serial.print(data.freeMem);
    Serial.print(F("|UPTIME:"));
    Serial.print(data.uptime);
    if (endLine) Serial.println();
  }

  // Datos de configuración
  void configData(bool endLine = true) {
    if (endLine) Serial.print(F("type:3|"));
    Serial.print(F("LINE_K_PID:["));
    Serial.print(config.lineKp, 2); Serial.print(F(","));
    Serial.print(config.lineKi, 2); Serial.print(F(","));
    Serial.print(config.lineKd, 2); Serial.print(F("]"));
    Serial.print(F("|LEFT_K_PID:["));
    Serial.print(config.leftKp, 2); Serial.print(F(","));
    Serial.print(config.leftKi, 2); Serial.print(F(","));
    Serial.print(config.leftKd, 2); Serial.print(F("]"));
    Serial.print(F("|RIGHT_K_PID:["));
    Serial.print(config.rightKp, 2); Serial.print(F(","));
    Serial.print(config.rightKi, 2); Serial.print(F(","));
    Serial.print(config.rightKd, 2); Serial.print(F("]"));
    Serial.print(F("|BASE:["));
    Serial.print(config.baseSpeed); Serial.print(F(","));
    Serial.print(config.baseRPM, 2); Serial.print(F(","));
    Serial.print(config.maxSpeed); Serial.print(F("]"));
    Serial.print(F("|WHEELS:["));
    Serial.print(config.wheelDiameter, 1); Serial.print(F(","));
    Serial.print(config.wheelDistance, 1); Serial.print(F("]"));
    Serial.print(F("|MODE:"));
    Serial.print((int)config.operationMode);
    Serial.print(F("|CASCADE:"));
    Serial.print(config.cascadeMode ? F("1") : F("0"));
    Serial.print(F("|TELEMETRY:"));
    Serial.print(config.telemetry ? F("1") : F("0"));
    Serial.print(F("|FEAT_CONFIG:"));
    Serial.print(config.features.serialize());
    if (endLine) Serial.println();
  }

    // Datos de debug (config + telemetry + debug extra)
  void debugData(DebugData& data) {
    Serial.print(F("type:5|"));
    configData(false);
    telemetryData(data, false);
  }

  
  // Confirmación de comando procesado
  void ackMessage(const char* cmd) {
    Serial.print(F("type:2|ack:"));
    Serial.println(cmd);
  }

};

#endif
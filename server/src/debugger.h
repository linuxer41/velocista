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
  OperationMode mode;

  // Sensores
  int sensors[6];
  unsigned long uptime;

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
  int lSpeed, rSpeed;

  // Velocidades base
  int baseSpeed;
  float baseRPM;

  // Ruedas
  float wheelDiameter;
  float wheelDistance;

  // Contadores encoder
  long encLBackward, encRBackward;

  // Velocidades lineales (cm/s)
  float leftSpeedCms, rightSpeedCms;

  // Sistema
  float battery;
  unsigned long loopTime;
  int freeMem;
  long encL, encR;

  // Filtros de línea
  float kalmanEstimate;
  float kalmanCov;
  float lpAlpha;
  float dzThreshold;
  float hystThreshold;
  int maWindow;
  int medWindow;
};

class Debugger {
public:
  Debugger() {}

  // Mensaje de sistema (comandos, estados, etc.)
  void systemMessage(const char* msg) {
    Serial.print("type:1|");
    Serial.println(msg);
  }

  // Datos de debug (config + telemetry + debug extra)
  void debugData(DebugData& data) {
    Serial.print("type:5|");
    // 1. CONFIG DATA (igual que configData)
    Serial.print("LINE_K_PID:[");
    Serial.print(data.lineKp, 2); Serial.print(",");
    Serial.print(data.lineKi, 2); Serial.print(",");
    Serial.print(data.lineKd, 2); Serial.print("]");
    Serial.print("|LEFT_K_PID:[");
    Serial.print(data.leftKp, 2); Serial.print(",");
    Serial.print(data.leftKi, 2); Serial.print(",");
    Serial.print(data.leftKd, 2); Serial.print("]");
    Serial.print("|RIGHT_K_PID:[");
    Serial.print(data.rightKp, 2); Serial.print(",");
    Serial.print(data.rightKi, 2); Serial.print(",");
    Serial.print(data.rightKd, 2); Serial.print("]");
    Serial.print("|BASE:[");
    Serial.print(data.baseSpeed); Serial.print(",");
    Serial.print(data.baseRPM, 2); Serial.print("]");
    Serial.print("|WHEELS:[");
    Serial.print(data.wheelDiameter, 1); Serial.print(",");
    Serial.print(data.wheelDistance, 1); Serial.print("]");
    Serial.print("|MODE:");
    Serial.print((int)data.mode);
    Serial.print("|CASCADE:");
    Serial.print(data.cascade ? "1" : "0");
    Serial.print("|TELEMETRY:");
    Serial.print(config.telemetry ? "1" : "0");
    // 2. TELEMETRY DATA (igual que telemetryData)
    Serial.print("|LINE:[");
    Serial.print(data.linePos, 2); Serial.print(",");
    Serial.print(data.lineError, 2); Serial.print(",");
    Serial.print(data.lineIntegral, 2); Serial.print(",");
    Serial.print(data.lineDeriv, 2); Serial.print(",");
    Serial.print(data.linePidOut, 2); Serial.print("]");
    Serial.print("|LEFT:[");
    Serial.print(data.lRpm, 2); Serial.print(",");
    Serial.print(data.lTargetRpm, 2); Serial.print(",");
    Serial.print(data.lSpeed); Serial.print(",");
    Serial.print(data.encL); Serial.print(",");
    Serial.print(data.encLBackward); Serial.print(",");
    Serial.print(data.lPidOut, 2); Serial.print(",");
    Serial.print(data.lError, 2); Serial.print(",");
    Serial.print(data.lIntegral, 2); Serial.print(",");
    Serial.print(data.lDeriv, 2); Serial.print("]");
    Serial.print("|RIGHT:[");
    Serial.print(data.rRpm, 2); Serial.print(",");
    Serial.print(data.rTargetRpm, 2); Serial.print(",");
    Serial.print(data.rSpeed); Serial.print(",");
    Serial.print(data.encR); Serial.print(",");
    Serial.print(data.encRBackward); Serial.print(",");
    Serial.print(data.rPidOut, 2); Serial.print(",");
    Serial.print(data.rError, 2); Serial.print(",");
    Serial.print(data.rIntegral, 2); Serial.print(",");
    Serial.print(data.rDeriv, 2); Serial.print("]");
    Serial.print("|PID:[");
    Serial.print(data.linePidOut, 2); Serial.print(",");
    Serial.print(data.lPidOut, 2); Serial.print(",");
    Serial.print(data.rPidOut, 2); Serial.print("]");
    Serial.print("|SPEED_CMS:[");
    Serial.print(data.leftSpeedCms, 2); Serial.print(",");
    Serial.print(data.rightSpeedCms, 2); Serial.print("]");
    Serial.print("|QTR:[");
    Serial.print(data.sensors[0]); Serial.print(",");
    Serial.print(data.sensors[1]); Serial.print(",");
    Serial.print(data.sensors[2]); Serial.print(",");
    Serial.print(data.sensors[3]); Serial.print(",");
    Serial.print(data.sensors[4]); Serial.print(",");
    Serial.print(data.sensors[5]); Serial.print("]");
    Serial.print("|FILTERS:[");
    Serial.print(data.kalmanEstimate, 2); Serial.print(",");
    Serial.print(data.kalmanCov, 3); Serial.print(",");
    Serial.print(data.lpAlpha, 2); Serial.print(",");
    Serial.print(data.dzThreshold, 1); Serial.print(",");
    Serial.print(data.hystThreshold, 1); Serial.print(",");
    Serial.print(data.maWindow); Serial.print(",");
    Serial.print(data.medWindow); Serial.print("]");
    Serial.print("|BATT:");
    Serial.print(data.battery, 2);
    Serial.print("|LOOP_US:");
    Serial.print(data.loopTime);
    Serial.print("|FILTERS:[");
    Serial.print(data.kalmanEstimate, 2); Serial.print(",");
    Serial.print(data.kalmanCov, 3); Serial.print(",");
    Serial.print(data.lpAlpha, 2); Serial.print(",");
    Serial.print(data.dzThreshold, 1); Serial.print(",");
    Serial.print(data.hystThreshold, 1); Serial.print(",");
    Serial.print(data.maWindow); Serial.print(",");
    Serial.print(data.medWindow); Serial.print("]");
    Serial.print("|FREE_MEM:");
    Serial.print(data.freeMem);
    Serial.print("|UPTIME:");
    Serial.println(data.uptime);
  }

  // Datos de debug telemetry (telemetría reducida)
  void telemetryData(DebugData& data) {
    Serial.print("type:4|");
    Serial.print("LINE:[");
    Serial.print(data.linePos, 2); Serial.print(",");
    Serial.print(data.lineError, 2); Serial.print(",");
    Serial.print(data.lineIntegral, 2); Serial.print(",");
    Serial.print(data.lineDeriv, 2); Serial.print(",");
    Serial.print(data.linePidOut, 2); Serial.print("]");
    Serial.print("|LEFT:[");
    Serial.print(data.lRpm, 2); Serial.print(",");
    Serial.print(data.lTargetRpm, 2); Serial.print(",");
    Serial.print(data.lSpeed); Serial.print(",");
    Serial.print(data.encL); Serial.print(",");
    Serial.print(data.encLBackward); Serial.print("]");
    Serial.print("|RIGHT:[");
    Serial.print(data.rRpm, 2); Serial.print(",");
    Serial.print(data.rTargetRpm, 2); Serial.print(",");
    Serial.print(data.rSpeed); Serial.print(",");
    Serial.print(data.encR); Serial.print(",");
    Serial.print(data.encRBackward); Serial.print("]");
    Serial.print("|PID:[");
    Serial.print(data.linePidOut, 2); Serial.print(",");
    Serial.print(data.lPidOut, 2); Serial.print(",");
    Serial.print(data.rPidOut, 2); Serial.print("]");
    Serial.print("|SPEED_CMS:[");
    Serial.print(data.leftSpeedCms, 2); Serial.print(",");
    Serial.print(data.rightSpeedCms, 2); Serial.print("]");
    Serial.print("|QTR:[");
    Serial.print(data.sensors[0]); Serial.print(",");
    Serial.print(data.sensors[1]); Serial.print(",");
    Serial.print(data.sensors[2]); Serial.print(",");
    Serial.print(data.sensors[3]); Serial.print(",");
    Serial.print(data.sensors[4]); Serial.print(",");
    Serial.print(data.sensors[5]); Serial.print("]");
    Serial.print("|BATT:");
    Serial.print(data.battery, 2);
    Serial.print("|LOOP_US:");
    Serial.print(data.loopTime);
    Serial.print("|FREE_MEM:");
    Serial.print(data.freeMem);
    Serial.print("|UPTIME:");
    Serial.println(data.uptime);
  }

  // Datos de configuración
  void configData() {
    Serial.print("type:3|");
    Serial.print("LINE_K_PID:[");
    Serial.print(config.lineKp, 2); Serial.print(",");
    Serial.print(config.lineKi, 2); Serial.print(",");
    Serial.print(config.lineKd, 2); Serial.print("]");
    Serial.print("|LEFT_K_PID:[");
    Serial.print(config.leftKp, 2); Serial.print(",");
    Serial.print(config.leftKi, 2); Serial.print(",");
    Serial.print(config.leftKd, 2); Serial.print("]");
    Serial.print("|RIGHT_K_PID:[");
    Serial.print(config.rightKp, 2); Serial.print(",");
    Serial.print(config.rightKi, 2); Serial.print(",");
    Serial.print(config.rightKd, 2); Serial.print("]");
    Serial.print("|BASE:[");
    Serial.print(config.baseSpeed); Serial.print(",");
    Serial.print(config.baseRPM, 2); Serial.print("]");
    Serial.print("|WHEELS:[");
    Serial.print(config.wheelDiameter, 1); Serial.print(",");
    Serial.print(config.wheelDistance, 1); Serial.print("]");
    Serial.print("|MODE:");
    Serial.print((int)config.operationMode);
    Serial.print("|CASCADE:");
    Serial.print(config.cascadeMode ? "1" : "0");
    Serial.print("|TELEMETRY:");
    Serial.print(config.telemetry ? "1" : "0");
    Serial.println();
  }

  // Confirmación de comando procesado
  void ackMessage(const char* cmd) {
    Serial.print("type:2|ack:");
    Serial.println(cmd);
  }

};

#endif
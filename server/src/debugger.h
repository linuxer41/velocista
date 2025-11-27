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

  // Sistema
  float battery;
  unsigned long loopTime;
  int freeMem;
  long encL, encR;
};

class Debugger {
public:
  Debugger() {}

  // Mensaje de sistema (comandos, estados, etc.)
  void systemMessage(String msg) {
    Serial.print("type:1|");
    Serial.println(msg);
  }

  // Datos de debug (telemetría)
  void debugData(DebugData& data) {
    Serial.print("type:2|");
    Serial.print("LINE_PID:[");
    Serial.print(data.lineKp, 2); Serial.print(",");
    Serial.print(data.lineKi, 2); Serial.print(",");
    Serial.print(data.lineKd, 2); Serial.print(",");
    Serial.print(data.linePos, 2); Serial.print(",");
    Serial.print(data.linePidOut, 2); Serial.print(",");
    Serial.print(data.lineError, 2); Serial.print(",");
    Serial.print(data.lineIntegral, 2); Serial.print(",");
    Serial.print(data.lineDeriv, 2); Serial.print("]");
    Serial.print("|LVEL:[");
    Serial.print(data.lRpm, 2); Serial.print(",");
    Serial.print(data.lTargetRpm, 2); Serial.print(",");
    Serial.print(data.lSpeed); Serial.print(",");
    Serial.print(data.encL); Serial.print("]");
    Serial.print("|RVEL:[");
    Serial.print(data.rRpm, 2); Serial.print(",");
    Serial.print(data.rTargetRpm, 2); Serial.print(",");
    Serial.print(data.rSpeed); Serial.print(",");
    Serial.print(data.encR); Serial.print("]");
    Serial.print("|LEFT_PID:[");
    Serial.print(data.leftKp, 2); Serial.print(",");
    Serial.print(data.leftKi, 2); Serial.print(",");
    Serial.print(data.leftKd, 2); Serial.print(",");
    Serial.print(data.lTargetRpm, 2); Serial.print(",");
    Serial.print(data.lPidOut, 2); Serial.print(",");
    Serial.print(data.lError, 2); Serial.print(",");
    Serial.print(data.lIntegral, 2); Serial.print(",");
    Serial.print(data.lDeriv, 2); Serial.print("]");
    Serial.print("|RIGHT_PID:[");
    Serial.print(data.rightKp, 2); Serial.print(",");
    Serial.print(data.rightKi, 2); Serial.print(",");
    Serial.print(data.rightKd, 2); Serial.print(",");
    Serial.print(data.rTargetRpm, 2); Serial.print(",");
    Serial.print(data.rPidOut, 2); Serial.print(",");
    Serial.print(data.rError, 2); Serial.print(",");
    Serial.print(data.rIntegral, 2); Serial.print(",");
    Serial.print(data.rDeriv, 2); Serial.print("]");
    Serial.print("|QTR:[");
    Serial.print(data.sensors[0]); Serial.print(",");
    Serial.print(data.sensors[1]); Serial.print(",");
    Serial.print(data.sensors[2]); Serial.print(",");
    Serial.print(data.sensors[3]); Serial.print(",");
    Serial.print(data.sensors[4]); Serial.print(",");
    Serial.print(data.sensors[5]); Serial.print("]");
    Serial.print("|CASCADE:");
    Serial.print(data.cascade ? "1" : "0");
    Serial.print("|MODE:");
    Serial.print((int)data.mode);
    Serial.print("|BATT:");
    Serial.print(data.battery, 2);
    Serial.print("|LOOP_US:");
    Serial.print(data.loopTime);
    Serial.print("|UPTIME:");
    Serial.println(data.uptime);
  }

  // Confirmación de comando procesado
  void ackMessage(String cmd) {
    Serial.print("type:3|ack:");
    Serial.println(cmd);
  }

};

#endif
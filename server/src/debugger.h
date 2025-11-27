/**
 * ARCHIVO: debugger.h
 * DESCRIPCIÓN: Clase Debugger para manejo centralizado de mensajes seriales
 */

#ifndef DEBUGGER_H
#define DEBUGGER_H

#include <Arduino.h>

class Debugger {
public:
  Debugger() {}

  // Mensaje de sistema (comandos, estados, etc.)
  void systemMessage(String msg) {
    Serial.print("type:1|");
    Serial.println(msg);
  }

  // Datos de debug (telemetría)
  void debugData(String data) {
    Serial.print("type:2|");
    Serial.println(data);
  }

  // Confirmación de comando procesado
  void ackMessage(String cmd) {
    Serial.print("type:3|ack:");
    Serial.println(cmd);
  }

  // Método para construir línea de debug
  String buildDebugLine(float linePos, bool cascade, String mode,
                      int* sensors, unsigned long uptime,
                      float lineKp, float lineKi, float lineKd, float linePidOut, float lineError, float lineIntegral,
                      float leftKp, float leftKi, float leftKd, float lPidOut, float lError, float lIntegral,
                      float rightKp, float rightKi, float rightKd, float rPidOut, float rError, float rIntegral,
                      float lRpm, float rRpm, float lTargetRpm, float rTargetRpm, int lSpeed, int rSpeed) {
    String line = "LINE_PID:[" + String(lineKp, 2) + "," + String(lineKi, 2) + "," + String(lineKd, 2) + "," +
                  String(linePos, 2) + "," + String(linePidOut, 2) + "," + String(lineError, 2) + "," + String(lineIntegral, 2) + "]" +
                  "|LEFT_VEL:[" + String(lRpm, 2) + "," + String(lTargetRpm, 2) + "," + String(lSpeed) + "]" +
                  "|RIGHT_VEL:[" + String(rRpm, 2) + "," + String(rTargetRpm, 2) + "," + String(rSpeed) + "]" +
                  "|LEFT_PID:[" + String(leftKp, 2) + "," + String(leftKi, 2) + "," + String(leftKd, 2) + "," +
                  String(lTargetRpm, 2) + "," + String(lPidOut, 2) + "," + String(lError, 2) + "," + String(lIntegral, 2) + "]" +
                  "|RIGHT_PID:[" + String(rightKp, 2) + "," + String(rightKi, 2) + "," + String(rightKd, 2) + "," +
                  String(rTargetRpm, 2) + "," + String(rPidOut, 2) + "," + String(rError, 2) + "," + String(rIntegral, 2) + "]" +
                  "|CASCADE:" + String(cascade ? "1" : "0") +
                  "|MODE:" + mode +
                  "|UPTIME:" + String(uptime) +
                  "|QTR:[";
    for(int i = 0; i < 6; i++) {
      line += String(sensors[i]);
      if(i < 5) line += ",";
    }
    line += "]";
    return line;
  }
};

#endif
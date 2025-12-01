/**
 * ARCHIVO: serial_reader.h
 * DESCRIPCIÓN: Clase SerialReader para lectura no bloqueante de comandos seriales
 */

#ifndef SERIAL_READER_H
#define SERIAL_READER_H

#include <Arduino.h>

class SerialReader {
private:
    char serBuf[16];
    bool lineReady;
    uint8_t idx;

public:
    SerialReader() : lineReady(false), idx(0) {}

    void fillBuffer() {
        while (Serial.available()) {
            char c = Serial.read();
            if (c == '\n' || c == '\r') {
                serBuf[idx] = '\0';
                lineReady = true;
                idx = 0;
                return;
            }
            if (idx < sizeof(serBuf) - 1) serBuf[idx++] = c;
        }
    }

    bool getLine(const char **buf) {
        if (!lineReady) return false;
        *buf = serBuf;

        // Convertir a minúsculas in-place
        for (char *p = serBuf; *p; ++p) *p = tolower(*p);

        lineReady = false;
        return true;
    }
};

#endif
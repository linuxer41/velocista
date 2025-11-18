/**
 * ARCHIVO: mode_indicator.h
 * DESCRIPCIÓN: Control de LED indicador de modos de operación
 * FUNCIONALIDAD: Patrones de parpadeo según modo, indicación visual
 */

#ifndef MODE_INDICATOR_H
#define MODE_INDICATOR_H

#include <Arduino.h>
#include <ArduinoJson.h>
#include "config.h"

class ModeIndicator {
private:
    int ledPin;                 // Pin del LED
    OperationMode currentMode;  // Modo actual
    unsigned long lastBlinkTime; // Último tiempo de parpadeo
    bool ledState;              // Estado actual del LED
    
public:
    /**
     * Constructor
     * @param pin Pin del LED (por defecto LED integrado)
     */
    ModeIndicator(int pin = MODE_LED_PIN) : ledPin(pin), currentMode(MODE_DEBUG), 
                                           lastBlinkTime(0), ledState(false) {
        pinMode(ledPin, OUTPUT);
        digitalWrite(ledPin, LOW);
        
        Serial.println("{\"type\":\"indicator\",\"message\":\"Indicador de modo inicializado en pin " + String(pin) + "\"}");
    }
    
    /**
     * Actualizar indicador según modo de operación
     * Debe llamarse frecuentemente en el loop principal
     */
    void update() {
        unsigned long currentTime = millis();
        unsigned long blinkInterval = getBlinkInterval();
        
        if (blinkInterval == 0) {
            // Modo con LED siempre encendido
            if (!ledState) {
                ledState = true;
                digitalWrite(ledPin, HIGH);
            }
            return;
        }
        
        // Control de parpadeo
        if (currentTime - lastBlinkTime >= blinkInterval) {
            ledState = !ledState;
            digitalWrite(ledPin, ledState ? HIGH : LOW);
            lastBlinkTime = currentTime;
        }
    }
    
    /**
     * Cambiar modo de operación
     * @param newMode Nuevo modo a establecer
     */
    void setMode(OperationMode newMode) {
        if (currentMode != newMode) {
            currentMode = newMode;
            lastBlinkTime = millis();
            ledState = false;
            digitalWrite(ledPin, LOW); // Iniciar apagado
            
            Serial.println("{\"type\":\"indicator\",\"mode\":\"" + getModeString() + 
                          "\",\"pattern\":\"" + getPatternDescription() + "\"}");
        }
    }
    
    /**
     * Obtener intervalo de parpadeo según modo
     * @return Intervalo en ms, 0 = siempre encendido
     */
    unsigned long getBlinkInterval() const {
        switch (currentMode) {
            case MODE_CALIBRATION:
                return 500;  // Parpadeo rápido cada 500ms
            case MODE_COMPETITION:
                return 1000; // Parpadeo medio cada 1 segundo
            case MODE_TUNING:
                return 300;  // Parpadeo muy rápido cada 300ms
            case MODE_DEBUG:
                return 0;    // Siempre encendido
            case MODE_REMOTE_CONTROL:
                return 2000; // Parpadeo lento cada 2 segundos
            default:
                return 1000;
        }
    }
    
    /**
     * Obtener descripción del patrón de LED
     * @return String descriptivo
     */
    String getPatternDescription() const {
        switch (currentMode) {
            case MODE_CALIBRATION: return "Parpadeo rápido (500ms)";
            case MODE_COMPETITION: return "Parpadeo medio (1s)";
            case MODE_TUNING: return "Parpadeo muy rápido (300ms)";
            case MODE_DEBUG: return "LED siempre encendido";
            case MODE_REMOTE_CONTROL: return "Parpadeo lento (2s)";
            default: return "Desconocido";
        }
    }
    
    /**
     * Generar JSON con estado del indicador
     * @return String JSON con información del modo
     */
    String getStatusJSON() {
        StaticJsonDocument<256> doc;
        doc["type"] = "mode_indicator";
        doc["mode"] = getModeString();
        doc["led_pin"] = ledPin;
        doc["pattern"] = getPatternDescription();
        doc["interval"] = getBlinkInterval();
        doc["led_state"] = ledState;
        
        String jsonString;
        serializeJson(doc, jsonString);
        return jsonString;
    }
    
    /**
     * Obtener modo actual
     * @return Modo actual
     */
    OperationMode getCurrentMode() const { return currentMode; }
    
    /**
     * Obtener string del modo actual
     * @return String del modo
     */
    String getModeString() const {
        return modeToString(currentMode);
    }
    
private:
    /**
     * Convertir modo a string
     * @param mode Modo de operación
     * @return String descriptivo
     */
    String modeToString(OperationMode mode) const {
        switch (mode) {
            case MODE_CALIBRATION: return "CALIBRATION";
            case MODE_COMPETITION: return "COMPETITION";
            case MODE_TUNING: return "TUNING";
            case MODE_DEBUG: return "DEBUG";
            case MODE_REMOTE_CONTROL: return "REMOTE_CONTROL";
            default: return "UNKNOWN";
        }
    }
};

#endif
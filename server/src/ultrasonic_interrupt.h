/**
 * ARCHIVO: ultrasonic_interrupt.h
 * DESCRIPCIÓN: Control interrupt-based del sensor ultrasónico
 * FUNCIONALIDAD: Medición no-bloqueante usando Timer1 y PCINT
 */

#ifndef ULTRASONIC_INTERRUPT_H
#define ULTRASONIC_INTERRUPT_H

#include <Arduino.h>
#include "config.h"

// Estados del sensor ultrasónico
enum UltrasonicState {
    US_IDLE,
    US_TRIGGERED,
    US_WAITING_ECHO,
    US_MEASURING
};

class UltrasonicInterrupt {
private:
    volatile UltrasonicState state;
    volatile unsigned long echoStartTime;
    volatile unsigned long echoEndTime;
    volatile bool measurementReady;
    volatile float lastDistance;

    static UltrasonicInterrupt* instance; // Para acceso desde ISR

    // Timer1 configuration for 1MHz (1us resolution)
    static const uint16_t TIMER_PRESCALER = 8;
    static const uint16_t TIMER_TOP = 124; // 16MHz/8/125 = 16kHz interrupts

public:
    UltrasonicInterrupt() : state(US_IDLE), measurementReady(false), lastDistance(0) {
        instance = this;
    }

    /**
     * Inicializar sensor con interrupciones
     */
    void initialize() {
        pinMode(TRIG_PIN, OUTPUT);
        pinMode(ECHO_PIN, INPUT);

        // Configurar Timer1 para mediciones precisas
        TCCR1A = 0;
        TCCR1B = 0;
        TIMSK1 = 0;

        // Configurar Pin Change Interrupt para ECHO pin
        *digitalPinToPCMSK(ECHO_PIN) |= bit(digitalPinToPCMSKbit(ECHO_PIN));
        PCIFR |= bit(digitalPinToPCICRbit(ECHO_PIN)); // Clear any pending interrupt
        PCICR |= bit(digitalPinToPCICRbit(ECHO_PIN)); // Enable PCINT

        digitalWrite(TRIG_PIN, LOW);
    }

    /**
     * Iniciar medición no-bloqueante
     */
    void triggerMeasurement() {
        if (state != US_IDLE) return;

        // Enviar pulso de trigger
        digitalWrite(TRIG_PIN, LOW);
        delayMicroseconds(2);
        digitalWrite(TRIG_PIN, HIGH);
        delayMicroseconds(10);
        digitalWrite(TRIG_PIN, LOW);

        state = US_TRIGGERED;
        measurementReady = false;
    }

    /**
     * Obtener última distancia medida
     * @return Distancia en cm, 0 si no hay medición válida
     */
    float getDistance() {
        if (measurementReady) {
            measurementReady = false;
            return lastDistance;
        }
        return 0; // No measurement ready
    }

    /**
     * Verificar si hay medición lista
     */
    bool isMeasurementReady() const {
        return measurementReady;
    }

    /**
     * Procesar estado del sensor (llamar en loop principal)
     */
    void process() {
        static unsigned long triggerTime = 0;

        switch (state) {
            case US_TRIGGERED:
                triggerTime = micros();
                state = US_WAITING_ECHO;
                break;

            case US_WAITING_ECHO:
                // Timeout después de 30ms
                if (micros() - triggerTime > 30000) {
                    state = US_IDLE;
                }
                break;

            case US_MEASURING:
                // Measurement completed in ISR
                break;

            case US_IDLE:
            default:
                // Ready for next measurement
                break;
        }
    }

    // Interrupt Service Routines
    static void handlePinChange() {
        if (instance) {
            instance->onPinChange();
        }
    }

private:
    void onPinChange() {
        uint8_t echoState = digitalRead(ECHO_PIN);
        unsigned long currentTime = micros();

        if (state == US_WAITING_ECHO) {
            if (echoState == HIGH) {
                // Echo started
                echoStartTime = currentTime;
                state = US_MEASURING;
            }
        } else if (state == US_MEASURING) {
            if (echoState == LOW) {
                // Echo ended
                echoEndTime = currentTime;
                unsigned long duration = echoEndTime - echoStartTime;

                if (duration > 100 && duration < 25000) { // Valid range: ~3cm to ~4m
                    lastDistance = (duration * 0.0343) / 2.0;
                    measurementReady = true;
                }

                state = US_IDLE;
            }
        }
    }
};

// Static member initialization
UltrasonicInterrupt* UltrasonicInterrupt::instance = nullptr;

// Pin Change Interrupt Vector
ISR(PCINT2_vect) {
    UltrasonicInterrupt::handlePinChange();
}

#endif
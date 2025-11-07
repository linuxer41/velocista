#pragma once
#include <Arduino.h>

namespace motor {

  // Valor máximo de PWM (255 para la mayoría de placas Arduino)
  constexpr uint16_t MAX_PWM_VAL = 255;

  /**
   * @brief Modo de decaimiento del puente H.
   * - Slow: freno suave, ideal para motores DC.
   * - Fast: freno rápido, útil para detener más bruscamente.
   */
  enum class DecayMode {
    Slow = 0,
    Fast = 1,
  };

  /**
   * @brief Dirección de giro del motor.
   */
  enum class Direction {
    Forward,
    Backward,
  };

  /**
   * @brief Control de un puente H del DRV8833.
   * Permite controlar velocidad, dirección y modo de decaimiento.
   */
  class DRV8833_HBridge {
  public:
    /**
     * @brief Constructor por defecto. Modo de decaimiento: lento.
     * @param in1 Pin IN1 del puente H.
     * @param in2 Pin IN2 del puente H.
     */
    DRV8833_HBridge(uint8_t in1, uint8_t in2)
      : mIn1(in1), mIn2(in2), mDecayMode(DecayMode::Slow) {}

    /**
     * @brief Constructor con modo de decaimiento personalizado.
     * @param in1 Pin IN1 del puente H.
     * @param in2 Pin IN2 del puente H.
     * @param mode Modo de decaimiento.
     */
    DRV8833_HBridge(uint8_t in1, uint8_t in2, DecayMode mode)
      : mIn1(in1), mIn2(in2), mDecayMode(mode) {}

    /**
     * @brief Inicializa los pines y para el motor.
     */
    void begin() {
      pinMode(mIn1, OUTPUT);
      pinMode(mIn2, OUTPUT);
      stop();
    }

    /**
     * @brief Cambia el modo de decaimiento.
     * @param mode Nuevo modo.
     */
    void setDecayMode(DecayMode mode) { mDecayMode = mode; }

    /**
     * @brief Establece velocidad y dirección.
     * @param speed Velocidad entre 0.0 y 1.0.
     * @param dir Dirección del motor.
     */
    void setSpeed(float speed, Direction dir) {
      int pwm = static_cast<int>(constrain(speed, 0.0f, 1.0f) * MAX_PWM_VAL);
      setSpeed(pwm, dir);
    }

    /**
     * @brief Establece velocidad en modo bipolar (-1.0 a 1.0).
     * Valores negativos = atrás, positivos = adelante, 0 = parar.
     */
    void setSpeedBipolar(float speed) {
      if (speed > 0.0f) {
        setSpeed(speed, Direction::Forward);
      } else if (speed < 0.0f) {
        setSpeed(-speed, Direction::Backward);
      } else {
        stop();
      }
    }

    /**
     * @brief Establece velocidad en modo bipolar con enteros.
     */
    void setSpeedBipolar(int speed) {
      setSpeedBipolar(static_cast<float>(speed));
    }

    /**
     * @brief Establece velocidad (0 a MAX_PWM_VAL) y dirección.
     * Aplica el valor inmediatamente.
     */
    void setSpeed(int speed, Direction dir) {
      speed = constrain(speed, 0, MAX_PWM_VAL);
      actual_speed = (mDecayMode == DecayMode::Slow) ? MAX_PWM_VAL - speed : speed;
      current_direction = dir;
      start();
    }

    /**
     * @brief Establece velocidad en dirección adelante.
     */
    void setSpeed(int speed) {
      setSpeed(speed, Direction::Forward);
    }

    /**
     * @brief Arranca el motor con la velocidad y dirección configuradas.
     */
    void start() {
      switch (mDecayMode) {
        case DecayMode::Fast:
          if (current_direction == Direction::Forward) {
            analogWrite(mIn1, actual_speed);
            digitalWrite(mIn2, LOW);
          } else {
            digitalWrite(mIn1, LOW);
            analogWrite(mIn2, actual_speed);
          }
          break;

        case DecayMode::Slow:
          if (current_direction == Direction::Forward) {
            digitalWrite(mIn1, HIGH);
            analogWrite(mIn2, actual_speed);
          } else {
            analogWrite(mIn1, actual_speed);
            digitalWrite(mIn2, HIGH);
          }
          break;
      }
      isrunning = true;
    }

    /**
     * @brief Para el motor.
     */
    void stop() {
      digitalWrite(mIn1, LOW);
      digitalWrite(mIn2, LOW);
      isrunning = false;
    }

    /**
     * @brief Devuelve true si el motor está en marcha.
     */
    bool isRunning() const { return isrunning; }

    /**
     * @brief Devuelve true si el motor está parado.
     */
    bool isStopped() const { return !isrunning; }

  private:
    uint8_t mIn1, mIn2;
    DecayMode mDecayMode;
    int actual_speed = 0;
    Direction current_direction = Direction::Forward;
    bool isrunning = false;
  };

  /**
   * @brief Control completo del chip DRV8833.
   * Incluye dos puentes H para controlar dos motores DC.
   */
  class DRV8833 {
  public:
    /**
     * @brief Constructor por defecto. Modo de decaimiento: lento.
     */
    DRV8833(uint8_t in1, uint8_t in2, uint8_t in3, uint8_t in4)
      : mBridgeA(in1, in2), mBridgeB(in3, in4) {}

    /**
     * @brief Constructor con modo de decaimiento personalizado.
     */
    DRV8833(uint8_t in1, uint8_t in2, uint8_t in3, uint8_t in4, DecayMode mode)
      : mBridgeA(in1, in2, mode), mBridgeB(in3, in4, mode) {}

    /**
     * @brief Inicializa los pines.
     */
    void begin() {
      mBridgeA.begin();
      mBridgeB.begin();
    }

    /**
     * @brief Para ambos motores.
     */
    void stopAll() {
      mBridgeA.stop();
      mBridgeB.stop();
    }

    /**
     * @brief Arranca ambos motores con la velocidad y dirección actuales.
     */
    void startAll() {
      mBridgeA.start();
      mBridgeB.start();
    }

    /**
     * @brief Devuelve el puente H A.
     */
    DRV8833_HBridge& getBridgeA() { return mBridgeA; }

    /**
     * @brief Devuelve el puente H B.
     */
    DRV8833_HBridge& getBridgeB() { return mBridgeB; }

  private:
    DRV8833_HBridge mBridgeA, mBridgeB;
  };

} // namespace motor
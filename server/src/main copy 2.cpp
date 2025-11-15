// /*
//   Robot – recorre 30 cm y para
//   Llanta Ø 4.5 cm → 253.2 pulsos/cm
//   Objetivo: 30 cm → 7596 pulsos
// */
// #include <Arduino.h>
// #include <PinChangeInterrupt.h>

// // ---------- Motores ----------
// const uint8_t MI_IN1 = 5;
// const uint8_t MI_IN2 = 6;
// const uint8_t MD_IN1 = 9;
// const uint8_t MD_IN2 = 10;

// // ---------- Encoders ----------
// const uint8_t DR_A = 7;
// const uint8_t DR_B = 8;
// const uint8_t IZ_A = 2;
// const uint8_t IZ_B = 3;

// // ---------- Constantes ----------
// const int32_t PPR_MOTOR  = 358;
// const float   REDUCCION  = 10.0;
// const int32_t PPR_LLANTA = PPR_MOTOR * REDUCCION;
// const float   PERIMETRO  = PI * 4.5;            // 14.14 cm
// const float    PULSOS_POR_CM = PPR_LLANTA / PERIMETRO;  // 253.2

// const float   DISTANCIA_CM = 30.0;              // cm a recorrer
// const int32_t PULSOS_OBJ   = (int32_t)(DISTANCIA_CM * PULSOS_POR_CM); // 7596

// // ---------- Variables ----------
// volatile int32_t drPulsos = 0, izPulsos = 0;
// volatile bool drDir = true, izDir = true;

// bool viajeTerminado = false;

// // ---------- ISRs ----------
// void drISR() {
//   if (digitalRead(DR_B) != digitalRead(DR_A)) { drPulsos++; drDir = true;  }
//   else                                        { drPulsos--; drDir = false; }
// }
// void izISR() {
//   if (digitalRead(IZ_B) != digitalRead(IZ_A)) { izPulsos++; izDir = true;  }
//   else                                        { izPulsos--; izDir = false; }
// }

// // ---------- Motor ----------
// void setMotorL(int pwm) {
//   pwm = constrain(pwm, -255, 255);
//   if (pwm >= 0) { analogWrite(MI_IN2, -pwm); analogWrite(MI_IN1, 0); }
//   else          { analogWrite(MI_IN1, pwm); analogWrite(MI_IN2, 0); }
// }
// void setMotorR(int pwm) {
//   pwm = constrain(pwm, -255, 255);
//   if (pwm >= 0) { analogWrite(MD_IN1, pwm); analogWrite(MD_IN2, 0); }
//   else          { analogWrite(MD_IN2, -pwm); analogWrite(MD_IN1, 0); }
// }
// void stopMotors() {
//   analogWrite(MI_IN1, 0); analogWrite(MI_IN2, 0);
//   analogWrite(MD_IN1, 0); analogWrite(MD_IN2, 0);
// }

// // ---------- Setup ----------
// void setup() {
//   Serial.begin(9600);
//   pinMode(MI_IN1, OUTPUT); pinMode(MI_IN2, OUTPUT);
//   pinMode(MD_IN1, OUTPUT); pinMode(MD_IN2, OUTPUT);
//   pinMode(DR_A, INPUT_PULLUP); pinMode(DR_B, INPUT_PULLUP);
//   pinMode(IZ_A, INPUT_PULLUP); pinMode(IZ_B, INPUT_PULLUP);
//   attachPCINT(digitalPinToPCINT(DR_A), drISR, RISING);
//   attachInterrupt(digitalPinToInterrupt(IZ_A), izISR, RISING);
//   stopMotors();

//   Serial.print("Recorriendo "); Serial.print(DISTANCIA_CM);
//   Serial.println(" cm …");
//   // arranca suave
//   setMotorL(180);
//   setMotorR(180);
// }

// // ---------- Loop: monitor y parada ----------
// void loop() {
//   static uint32_t tmr = 0;
//   if (millis() - tmr >= 100) {
//     tmr = millis();

//     noInterrupts();
//     int32_t dr = drPulsos;
//     int32_t iz = izPulsos;
//     noInterrupts();

//     float drCm = dr / PULSOS_POR_CM;
//     float izCm = iz / PULSOS_POR_CM;

//     Serial.print("IZ cm: "); Serial.print(izCm, 1);
//     Serial.print("   DR cm: "); Serial.print(drCm, 1);
//     Serial.print("   Total: "); Serial.print((dr + iz) / 2.0 / PULSOS_POR_CM, 1);
//     Serial.println(" cm");

//     // termina cuando cualquiera llegue (o ambas)
//     if (abs(dr) >= PULSOS_OBJ || abs(iz) >= PULSOS_OBJ) {
//       if (!viajeTerminado) {
//         viajeTerminado = true;
//         stopMotors();
//         Serial.println("¡Distancia alcanzada!");
//       }
//     }
//   }
// }
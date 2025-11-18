// #include <Arduino.h>
// #include <EEPROM.h>

// // ---------- PINES ----------
// const uint8_t MOT_L_FORWARD = 6, MOT_L_BACKWARD = 5;
// const uint8_t MOT_R_FORWARD = 10, MOT_R_BACKWARD = 9;
// const uint8_t QTR_PINS[6] = {A0, A1, A2, A3, A4, A5};
// const uint8_t QTR_LED = 12;
// const uint8_t CAL_LED = 13;

// // ---------- PID + EEPROM ----------
// int qtr[6], qtrMin[6], qtrMax[6];
// float kp, ki, kd;
// int baseSpeed;
// float error, lastError, integral, derivative;

// struct PIDEEP {
//   float kp, ki, kd;
//   int speed;
// };
// PIDEEP pidBuf;

// const int EEPROM_ADDR = 0;

// // ---------- LECTURA CALIBRADA ----------
// void readQTR() {
//   digitalWrite(QTR_LED, HIGH);
//   delayMicroseconds(200);
//   for (int i = 0; i < 6; i++) {
//     int v = analogRead(QTR_PINS[i]);
//     v = map(constrain(v, qtrMin[i], qtrMax[i]), qtrMin[i], qtrMax[i], 0, 1000);
//     qtr[i] = v;
//   }
//   digitalWrite(QTR_LED, LOW);
// }

// int getPos() {
//   long sum = 0, tot = 0;
//   for (int i = 0; i < 6; i++) {
//     sum += (long)qtr[i] * (i * 1000 - 2500);
//     tot += qtr[i];
//   }
//   return tot ? sum / tot : 0;
// }

// int computePID(int pos) {
//   error = -pos;
//   integral += error;
//   derivative = error - lastError;
//   lastError = error;
//   integral = constrain(integral, -1000, 1000);
//   return kp * error + ki * integral + kd * derivative;
// }

// void motor(int L, int R) {
//   L = constrain(L, -255, 255);
//   R = constrain(R, -255, 255);
//   if (L >= 0) {
//     analogWrite(MOT_L_FORWARD, L); analogWrite(MOT_L_BACKWARD, 0);
//   } else {
//     analogWrite(MOT_L_FORWARD, 0); analogWrite(MOT_L_BACKWARD, -L);
//   }
//   if (R >= 0) {
//     analogWrite(MOT_R_FORWARD, R); analogWrite(MOT_R_BACKWARD, 0);
//   } else {
//     analogWrite(MOT_R_FORWARD, 0); analogWrite(MOT_R_BACKWARD, -R);
//   }
// }

// void calibrate() {
//   digitalWrite(CAL_LED, HIGH);
//   for (int i = 0; i < 6; i++) qtrMin[i] = 1023, qtrMax[i] = 0;
//   for (int j = 0; j < 400; j++) {
//     digitalWrite(QTR_LED, HIGH); delayMicroseconds(200);
//     for (int i = 0; i < 6; i++) {
//       int v = analogRead(QTR_PINS[i]);
//       qtrMin[i] = min(qtrMin[i], v);
//       qtrMax[i] = max(qtrMax[i], v);
//     }
//     digitalWrite(QTR_LED, LOW); delay(5);
//   }
//   digitalWrite(CAL_LED, LOW);
// }

// void savePID() {
//   pidBuf.kp = kp; pidBuf.ki = ki; pidBuf.kd = kd; pidBuf.speed = baseSpeed;
//   EEPROM.put(EEPROM_ADDR, pidBuf);
// }

// void loadPID() {
//   EEPROM.get(EEPROM_ADDR, pidBuf);
//   if (isnan(pidBuf.kp) || pidBuf.kp < 0 || pidBuf.kp > 5) pidBuf.kp = 0.15;
//   if (isnan(pidBuf.ki) || pidBuf.ki < 0 || pidBuf.ki > 5) pidBuf.ki = 0.01;
//   if (isnan(pidBuf.kd) || pidBuf.kd < 0 || pidBuf.kd > 5) pidBuf.kd = 0.02;
//   if (pidBuf.speed < 50 || pidBuf.speed > 255) pidBuf.speed = 180;
//   kp = pidBuf.kp; ki = pidBuf.ki; kd = pidBuf.kd; baseSpeed = pidBuf.speed;
// }

// void serialTask() {
//   if (!Serial.available()) return;
//   String cmd = Serial.readStringUntil('\n');
//   cmd.trim();
//   if (cmd.startsWith("Kp ")) { kp = cmd.substring(3).toFloat(); savePID(); }
//   else if (cmd.startsWith("Ki ")) { ki = cmd.substring(3).toFloat(); savePID(); }
//   else if (cmd.startsWith("Kd ")) { kd = cmd.substring(3).toFloat(); savePID(); }
//   else if (cmd.startsWith("Speed ")) { baseSpeed = cmd.substring(6).toInt(); savePID(); }
//   else if (cmd == "calibrate") { calibrate(); }
//   else if (cmd == "telemetry") {
//     Serial.print("[");
//     Serial.print(error); Serial.print(",");
//     Serial.print(integral); Serial.print(",");
//     Serial.print(derivative); Serial.print(",");
//     for (int i = 0; i < 6; i++) {
//       Serial.print(qtr[i]);
//       if (i < 5) Serial.print(",");
//     }
//     Serial.println("]");
//   }

//   Serial.print("Kp="); Serial.print(kp);
//   Serial.print(" Ki="); Serial.print(ki);
//   Serial.print(" Kd="); Serial.print(kd);
//   Serial.print(" Speed="); Serial.println(baseSpeed);
// }

// // ---------- SETUP / LOOP ----------
// void setup() {
//   pinMode(QTR_LED, OUTPUT); pinMode(CAL_LED, OUTPUT);
//   pinMode(MOT_L_FORWARD, OUTPUT); pinMode(MOT_L_BACKWARD, OUTPUT);
//   pinMode(MOT_R_FORWARD, OUTPUT); pinMode(MOT_R_BACKWARD, OUTPUT);
//   Serial.begin(9600);
//   loadPID();
//   calibrate();
// }

// void loop() {
//   serialTask();
//   readQTR();
//   int pos = getPos();
//   int corr = computePID(pos);
//   motor(baseSpeed - corr, baseSpeed + corr);
// }
# Bot Velocista Triciclo - 3 Modos de Operación

Robot velocista con Arduino Nano que incluye 3 modos de operación: Line Following, Autopilot (triciclo) y Manual. Sistema optimizado para rendimiento con control Bluetooth en tiempo real.

## 📋 Índice
1. [Habilitación y Conexión](#habilitación-y-conexión)
2. [Modos de Operación](#modos-de-operación)
3. [Comandos Bluetooth](#comandos-bluetooth)
4. [Hardware y Configuración](#hardware-y-configuración)
5. [Telemetría](#telemetría)

---

## 🔧 Habilitación y Conexión

### Componentes del Sistema
- **Microcontrolador**: Arduino Nano (ATmega328P)
- **Sensores**: 6 sensores QTR-8A (posiciones 2-7)
- **Motores**: 2 motores DC traseros
- **Controlador**: DRV8833 (puente H dual)
- **Comunicación**: Bluetooth HC-06
- **Estructura**: Triciclo (2 ruedas traseras motorizadas + 1 rueda delantera libre)

### Conexión de Hardware

#### Sensores QTR-8A
```
QTR Sensor 2 → A0 (Pin 14)
QTR Sensor 3 → A1 (Pin 15)
QTR Sensor 4 → A2 (Pin 16)
QTR Sensor 5 → A3 (Pin 17)
QTR Sensor 6 → A4 (Pin 18)
QTR Sensor 7 → A5 (Pin 19)
QTR IR Control → D13
```

#### Motores DRV8833
```
Motor Izquierdo Trasero:
  IN1 → D5
  IN2 → D6

Motor Derecho Trasero:
  IN1 → D9
  IN2 → D10

Alimentación:
  DRV8833 VM → 7.4V (batería)
  DRV8833 VCC → 5V (Arduino)
```

#### Encoders de Motores
```
Motor Izquierdo:
  Encoder A → D2 (Interrupción real)
  Encoder B → D4

Motor Derecho:
  Encoder A → D7 (PinChangeInterrupt)
  Encoder B → D8
```

#### Bluetooth HC-06
```
HC-06 VCC → 5V
HC-06 GND → GND
HC-06 RX → D1 (Arduino TX)
HC-06 TX → D0 (Arduino RX)
```

### Configuración HC-06
1. **Conecta el HC-06 a Arduino** (pines D0/D1)
2. **Configura via comandos AT**:
   ```
   AT           // Verificar comunicación
   AT+BAUD4     // 9600 bps
   AT+NAMEBotVelocista  // Nombre del dispositivo
   AT+PIN1234   // PIN opcional
   ```

### Memoria No Volátil (EEPROM)
El bot utiliza memoria EEPROM para recordar la configuración incluso cuando se apaga:
- **Auto-guardado**: Los cambios de PID, modo y velocidad se guardan automáticamente
- **Carga automática**: Al encenderse, carga la última configuración guardada
- **Validación**: Verifica la integridad de los datos con número mágico
- **Reset**: Posibilidad de restaurar valores por defecto

### Conexión con Smartphone
1. **Activa Bluetooth** en el smartphone
2. **Busca dispositivos** → "BotVelocista"
3. **Conecta** → Introduce PIN si se configuró
4. **Usa app serie** (como Serial WiFi Terminal) para comunicación

### Alimentación
- **Arduino Nano**: 5V via regulador
- **Motores**: 7.4V LiPo directamente a DRV8833
- **Sensores/HC-06**: 5V desde Arduino

---

## 🚗 Modos de Operación

El robot cuenta con 3 modos seleccionables via Bluetooth:

### Modo 0: Line Following (Seguidor de Línea)
- **Uso**: Seguimiento automático de línea negra
- **Sensores**: Utiliza QTR para detección
- **Control**: PID automático
- **Aplicación**: Carreras de velocistas

### Modo 1: Autopilot (Piloto Automático)
- **Uso**: Control tipo vehículo triciclo
- **Sensores**: NO utiliza sensores
- **Control**: Acelerador, freno, direccional, marcha
- **Lógica**: Diferencial de ruedas traseras
- **Aplicación**: Navegación autónoma sin línea

### Modo 2: Manual (Control Manual)
- **Uso**: Control directo de cada rueda
- **Sensores**: NO utiliza sensores
- **Control**: Velocidad individual de ruedas
- **Aplicación**: Pruebas y debugging

---

## 📡 Comandos Bluetooth

### Cambio de Modo
```json
{"mode": 0}  // Line Following
{"mode": 1}  // Autopilot
{"mode": 2}  // Manual
```

### Consulta de Estado
```json
{"getMode": true}
// Respuesta:
// {"currentMode": 1, "modeName": "Autopilot"}
```

### Modo Line Following - Configuración
```json
// Parámetros PID
{"Kp": 1.2, "Ki": 0.05, "Kd": 0.08}

// Setpoint (posición central de línea)
{"setpoint": 2500}

// Velocidad base (0.0 a 1.0)
{"baseSpeed": 0.7}

// Configuración completa
{
  "mode": 0,
  "Kp": 1.0,
  "Ki": 0.0,
  "Kd": 0.0,
  "setpoint": 2500,
  "baseSpeed": 0.8
}
```

### Modo Autopilot - Controles
```json
// Acelerador/Retroceso (-1.0 a 1.0)
{"throttle": 0.6}     // Acelerar
{"throttle": -0.3}    // Retroceder

// Freno (0.0 sin freno a 1.0 freno total)
{"brake": 0.3}

// Dirección de giro (-1.0 izquierda a 1.0 derecha)
{"turn": 0.5}         // Girar derecha
{"turn": -0.3}        // Girar izquierda

// Dirección de marcha
{"direction": 1}      // Adelante
{"direction": -1}     // Atrás

// Comando completo de movimiento
{
  "mode": 1,
  "throttle": 0.7,
  "brake": 0.0,
  "turn": 0.3,
  "direction": 1
}

// Parada y estacionamiento
{"emergencyStop": true}  // Parada de emergencia - detiene inmediatamente
{"park": true}           // Estacionar - freno total y dirección recta
{"stop": true}           // Parada normal - freno suave

// Ejemplos prácticos:
// Avanzar recto: {"mode": 1, "throttle": 0.6, "turn": 0.0}
// Girar derecha: {"mode": 1, "throttle": 0.5, "turn": 0.4}
// Frenar: {"mode": 1, "throttle": 0.3, "brake": 0.6}
// Retroceder: {"mode": 1, "throttle": -0.4, "direction": -1}
// Estacionar: {"park": true}
// Parada emergencia: {"emergencyStop": true}
```

### Modo Manual - Controles
```json
// Velocidad individual de ruedas (-1.0 a 1.0)
{"leftSpeed": 0.7, "rightSpeed": 0.7}    // Avanzar
{"leftSpeed": -0.5, "rightSpeed": -0.5}  // Retroceder
{"leftSpeed": 0.8, "rightSpeed": 0.2}    // Girar derecha
{"leftSpeed": 0.2, "rightSpeed": 0.8}    // Girar izquierda

// Velocidad máxima global (0.0 a 1.0)
{"maxSpeed": 0.5}

// Comando completo
{
  "mode": 2,
  "leftSpeed": 0.6,
  "rightSpeed": 0.6,
  "maxSpeed": 0.8
}

// Ejemplos prácticos:
// Parar: {"leftSpeed": 0, "rightSpeed": 0}
// Giro en el lugar: {"leftSpeed": 0.8, "rightSpeed": -0.8}
// Control independiente: {"leftSpeed": 0.5, "rightSpeed": 0.8}
```

### Gestión de Configuración (EEPROM)
```json
// Guardar configuración actual en EEPROM
{"saveConfig": true}

// Cargar configuración desde EEPROM
{"loadConfig": true}

// Restaurar valores por defecto
{"resetConfig": true}

// Ejemplos de uso:
// Después de ajustar PID: {"Kp": 1.2, "Ki": 0.05, "Kd": 0.08}  // Se guarda automáticamente
// Cambiar modo: {"mode": 1}  // Se guarda automáticamente
// Recuperar configuración: {"loadConfig": true}
```

---

## ⚙️ Hardware y Configuración

### Pines Arduino Nano
```cpp
// Sensores QTR
const uint8_t QTR_PINS[6] = {14, 15, 16, 17, 18, 19}; // A0-A5
const uint8_t QTR_IR_PIN = 13;

// Motores DRV8833
const uint8_t MOTOR_LEFT_IN1 = 5;   // Motor izquierdo
const uint8_t MOTOR_LEFT_IN2 = 6;
const uint8_t MOTOR_RIGHT_IN1 = 9;  // Motor derecho
const uint8_t MOTOR_RIGHT_IN2 = 10;

// Encoders
const uint8_t ENC_LEFT_A = 2;    // Interrupción real
const uint8_t ENC_LEFT_B = 4;
const uint8_t ENC_RIGHT_A = 7;   // PinChangeInterrupt
const uint8_t ENC_RIGHT_B = 8;

// Bluetooth (Hardware Serial)
const uint8_t BLUETOOTH_RX_PIN = 0; // D0
const uint8_t BLUETOOTH_TX_PIN = 1; // D1
```

### Configuración de Encoders
```cpp
float wheelCircumference = 21.0; // cm (ajustar según tu rueda)
int encoderCPR = 90; // Pulsos por revolución
```

### Parámetros PID Iniciales
```cpp
float Kp = 1.0;        // Ganancia proporcional
float Ki = 0.0;        // Ganancia integral
float Kd = 0.0;        // Ganancia derivativa
float setpoint = 2500; // Centro de línea para 6 sensores
float baseSpeed = 0.8; // 80% velocidad máxima
```

---

## 📊 Telemetría

El robot envía datos cada 100ms en formato JSON:

### Datos Comunes (Todos los Modos)
```json
{
  "operationMode": 1,
  "modeName": "Autopilot",
  "leftEncoderSpeed": 15.2,
  "rightEncoderSpeed": 15.8,
  "leftEncoderCount": 1234,
  "rightEncoderCount": 1267,
  "totalDistance": 245.6,
  "sensors": [0, 0, 0, 0, 0, 0]  // 0 en modos no-lineales
}
```

### Modo Line Following
```json
{
  "operationMode": 0,
  "modeName": "Line Following",
  "position": 2500.0,
  "error": 0.0,
  "correction": 0.15,
  "leftSpeedCmd": 0.65,
  "rightSpeedCmd": 0.95,
  "sensors": [100, 150, 800, 850, 200, 120]
}
```

### Modo Autopilot
```json
{
  "operationMode": 1,
  "modeName": "Autopilot",
  "throttle": 0.6,
  "brake": 0.0,
  "turn": 0.3,
  "direction": 1,
  "parkingState": "MOVING",    // MOVING, STOPPED, PARKED
  "leftSpeedCmd": 0.45,
  "rightSpeedCmd": 0.75
}

// Estado estacionado:
{
  "operationMode": 1,
  "modeName": "Autopilot",
  "throttle": 0.0,
  "brake": 1.0,
  "turn": 0.0,
  "direction": 1,
  "parkingState": "PARKED",
  "leftSpeedCmd": 0.0,
  "rightSpeedCmd": 0.0
}
```

### Modo Manual
```json
{
  "operationMode": 2,
  "modeName": "Manual",
  "leftSpeed": 0.56,
  "rightSpeed": 0.56,
  "maxSpeed": 0.8,
  "leftSpeedCmd": 0.56,
  "rightSpeedCmd": 0.56
}
```

---

## 🛠️ Compilación y Uso

### Dependencias Arduino
- ArduinoJson v7.4.2
- PinChangeInterrupt v1.2.9
- DRV8833.h (incluido)

### Compilación PlatformIO
```bash
pio run --target upload  # Subir firmware
pio device monitor       # Monitor serie
```

### Apps Recomendadas
- **Android**: Serial WiFi Terminal, Bluetooth Terminal
- **iOS**: BlueTool, Network Analyzer
- **PC**: PuTTY, Screen, PlatformIO Monitor

### Ejemplo de Conexión Python
```python
import bluetooth
import json

# Conectar
sock = bluetooth.BluetoothSocket(bluetooth.RFCOMM)
sock.connect(("00:11:22:33:44:55", 1))  # MAC del HC-06

# Cambiar a autopilot y mover
command = {
    "mode": 1,
    "throttle": 0.6,
    "turn": 0.3,
    "direction": 1
}
sock.send(json.dumps(command))

# Recibir telemetría
data = sock.recv(1024)
telemetry = json.loads(data.decode())
print(f"Velocidad: {telemetry['leftEncoderSpeed']:.1f} cm/s")
```

---

## 🎯 Casos de Uso

### Competencia Velocista
```json
{"mode": 0, "Kp": 1.2, "Ki": 0.05, "Kd": 0.08, "baseSpeed": 0.9}
```

### Navegación Autónoma
```json
{"mode": 1, "throttle": 0.7, "turn": 0.0, "direction": 1}
```

### Pruebas de Control
```json
{"mode": 2, "leftSpeed": 0.5, "rightSpeed": 0.8, "maxSpeed": 0.6}
```

### Estacionamiento
```json
{"mode": 1, "throttle": 0.0, "brake": 1.0}  // Freno total
```

---

## ✅ Características Destacadas

- **Triciclo Real**: 2 ruedas traseras motorizadas + 1 rueda delantera libre
- **Sin Sensores en Modos Avanzados**: Mejor rendimiento
- **Control Diferencial**: Giro suave y preciso
- **Bluetooth Robusto**: Comunicación estable 9600 bps
- **Telemetría Completa**: Datos en tiempo real
- **JSON Compatible**: Fácil integración con apps
- **Código Optimizado**: Sin elementos legacy

**¡Tu bot velocista está listo para competir y navegar de forma autónoma!**
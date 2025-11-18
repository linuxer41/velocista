📘 README – API JSON del Robot "Velocista"
Revisado: noviembre-2024
Versión firmware: 2.1 (mejoras en seguidor de línea + factory reset)

1. Objetivo
Documento de referencia para cualquier capa front-end (App móvil, web, desktop) que desee:
Enviar órdenes al robot (modos, PID, rutas, etc.)
Recibir telemetría en tiempo real (motores, sensores, batería, distancias, etc.)
El robot siempre habla por el puerto-serie hardware (0-RX / 1-TX) a 9600 bps.
Cuando BT está emparejado la app solo tiene que abrir el puerto serie estándar del SO; cuando está por USB abrir COMx / /dev/ttyUSB0.

2. Formato general
Entrada → JSON de una sola línea terminada en \n
Salida → JSON de una sola línea terminada en \n
Codificación → UTF-8
Tamaño recomendado ≤ 512 bytes (lado robot)
Claves en inglés descriptivo (camelCase) para facilitar parseo automático

3. Comandos (robot → RECIBE)

| Clave | Tipo | Descripción | Ejemplo |
|-------|------|-------------|---------|
| mode | int | Cambia modo operación (0-2) | {"mode":0} |
| pid | array[float] | Ajusta [Kp, Ki, Kd] | {"pid":[1.2,0.05,0.02]} |
| base_speed | float | Velocidad base 0-1 | {"base_speed":0.7} |
| rc | object | Control remoto: autopilot (throttle/turn) | {"rc":{"throttle":0.5,"turn":-0.3}} |
| servo | object | Modo servo: distancia en cm y ángulo opcional en grados | {"servo":{"distance":30,"angle":45}} |
| eeprom | int 1 | Guarda config actual en EEPROM | {"eeprom":1} |
| tele | int | Control telemetría: 0=off, 1=on, 2=get once | {"tele":1} |
| qtr | int 1 | Calibra sensores QTR (mueve robot sobre línea y fondo) | {"qtr":1} |
| factory_reset | int 1 | Resetea configuración a valores de fábrica | {"factory_reset":1} |

Mensajes de comando (comando recibido):
```json
{"type": "cmd", "payload": {"buffer": "{\"mode\":1}"}}
```

4. Telemetría (robot → ENVÍA)
Se emite automáticamente cada 500 ms.
Ejemplo completo:
```json
{
  "type": "telemetry",
  "payload": {
    "timestamp": 12345,
    "mode": 1,
    "velocity": 9.87,
    "acceleration": 0.5,
    "distance": 833.46,
    "left": {
      "vel": 9.87,
      "acc": 0.5,
      "rpm": 39.7,
      "distance": 833.46,
      "pwm": 150
    },
    "right": {
      "vel": 0,
      "acc": 0.5,
      "rpm": 0,
      "distance": 0,
      "pwm": -50
    },
    "battery": 12.1,
    "qtr": [1000,1000,1000,1000,506,0],
    "pid": [1.2, 0.001, 0.05],
    "set_point": 0,
    "base_speed": 0.6,
    "error": 0,
    "correction": 0
  }
}
```

Descripción de campos:

| Campo | Tipo | Unidad | Significado |
|-------|------|--------|-------------|
| type | string | - | Siempre "telemetry" |
| payload.timestamp | uint32_t | ms | Tiempo desde inicio (millis) |
| payload.mode | int | - | Modo activo (0-2) |
| payload.velocity | float | cm/s | Velocidad promedio |
| payload.acceleration | float | cm/s² | Aceleración promedio |
| payload.distance | float | cm | Distancia total recorrida (odometría) |
| payload.left | object | - | Datos motor izquierdo |
| payload.left.vel | float | cm/s | Velocidad motor izquierdo |
| payload.left.acc | float | cm/s² | Aceleración motor izquierdo |
| payload.left.rpm | float | rpm | RPM motor izquierdo |
| payload.left.distance | float | cm | Distancia recorrida motor izquierdo |
| payload.left.pwm | int16_t | -255..255 | PWM motor izquierdo |
| payload.right | object | - | Datos motor derecho |
| payload.right.vel | float | cm/s | Velocidad motor derecho |
| payload.right.acc | float | cm/s² | Aceleración motor derecho |
| payload.right.rpm | float | rpm | RPM motor derecho |
| payload.right.distance | float | cm | Distancia recorrida motor derecho |
| payload.right.pwm | int16_t | -255..255 | PWM motor derecho |
| payload.battery | float | V | Voltaje de batería |
| payload.qtr[] | array[int] | 0-1000 | Valores de los 6 sensores QTR (calibrados) |
| payload.pid[] | array[float] | - | Ganancias PID [Kp, Ki, Kd] |
| payload.set_point | float | - | Punto de referencia de línea (0-5000) |
| payload.base_speed | float | - | Velocidad base configurada (0-1) |
| payload.error | float | - | Error PID actual |
| payload.correction | float | - | Corrección PID aplicada |

| type | string | - | "cmd" para mensajes de comando |
| payload.buffer | string | - | Comando JSON recibido por serial (sin \r) |

5. Modos de operación

| ID | Nombre | Descripción |
|----|--------|-------------|
| 0 | LINE_FOLLOW | Seguidor de línea PID |
| 1 | REMOTE_CONTROL | Control remoto: autopilot (throttle/turn) o manual (left/right) |
| 2 | SERVO | Modo servo: avanza distancia con giro opcional y espera instrucciones |

Cambio instantáneo: {"mode":2}

6. Control en tiempo real (modo 1 - REMOTE_CONTROL)
6.1 Autopilot
```json
{"rc":{"throttle":0.5,"turn":-0.3}}
```
throttle: -1.0 (atrás) … 0 … +1.0 (adelante)
turn: -1.0 (izq) … 0 … +1.0 (der)


7. Funciones especiales (modo 2 - SERVO)
```json
{"servo":{"distance":30,"angle":45}}
```
Robot avanza 30 cm con giro de 45 grados y se detiene, esperando la siguiente instrucción
Finaliza con: {"type": "status", "payload": {"status": "servo_completed"}}

8. Persistencia en EEPROM
{"eeprom":1} → guarda PID, velocidad-base y modo actual
Se auto-cargan al reiniciar
{"factory_reset":1} → resetea todo a valores de fábrica

9. Referencias de hardware
Puerto serie: 9600,8,N,1 (HW 0-TX / 1-RX)
Bluetooth: emparejar y abrir puerto serie estándar
Divisor batería: 100 kΩ / 10 kΩ → pin A6, relación 11:1
Sensores IR QTR: 6 canales analógicos A0-A5
Encoders: 358 PPR * reducción 10:1, rueda 4,5 cm diámetro → 253 pulsos/cm
Motores:
- Izquierdo: adelante pin 6, atrás pin 5
- Derecho: adelante pin 10, atrás pin 9
Encoders:
- Izquierdo: A pin 7, B pin 8
- Derecho: A pin 2, B pin 3
LED calibración: pin 13
LED QTR: pin 12
Buzzer: pin 4

10. Ejemplo rápido de sesión
```
>> {"mode":0}
<< {"type": "cmd", "payload": {"buffer": "{\"mode\":0}"}}
<< {"type": "telemetry", "payload": {"timestamp": 12345, "mode": 0, "velocity": 9.87, "acceleration": 0.5, "distance": 833.46, "left": {"vel": 9.87, "acc": 0.5, "rpm": 39.7, "distance": 833.46, "pwm": 150}, "right": {"vel": 0, "acc": 0.5, "rpm": 0, "distance": 0, "pwm": -50}, "battery": 12.1, "qtr": [1000,1000,1000,1000,506,0], "pid": [1.2, 0.001, 0.05], "set_point": 0, "base_speed": 0.6, "error": 0, "correction": 0}}

>> {"servo":{"distance":25,"angle":45}}
<< {"type": "cmd", "payload": {"buffer": "{\"servo\":{\"distance\":25,\"angle\":45}}"}}

>> {"rc":{"throttle":0.6,"turn":0.2}}
<< {"type": "cmd", "payload": {"buffer": "{\"rc\":{\"throttle\":0.6,\"turn\":0.2}}"}}
```

¡Listo! Con este documento tu equipo de front-end puede desarrollar la interfaz sin conocer el firmware interno.
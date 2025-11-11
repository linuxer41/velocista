📘 README – API JSON del Robot "Velocista"
Revisado: noviembre-2024
Versión firmware: 2.0 (modos unificados + rc simplificado)

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
| speed.base | float | Velocidad base 0-1 | {"speed":{"base":0.7}} |
| rc | object | Control remoto: dirección (0-360°) + aceleración (0-1), autopilot (throttle/turn) o manual (left/right) | {"rc":{"direction":90,"acceleration":0.5}} o {"rc":{"throttle":0.5,"turn":-0.3}} o {"rc":{"left":0.8,"right":-0.8}} |
| servo | object | Modo servo: distancia en cm y ángulo opcional en grados | {"servo":{"distance":30,"angle":45}} |
| eeprom | int 1 | Guarda config actual en EEPROM | {"eeprom":1} |
| telemetry | int 1 | Solicita telemetría completa una vez | {"telemetry":1} |
| telemetry_enable | bool | Habilita/deshabilita telemetría automática | {"telemetry_enable":false} |
| calibrate_qtr | int 1 | Calibra sensores QTR (mueve robot sobre línea y fondo) | {"calibrate_qtr":1} |

Respuestas rápidas del robot (solo status):
```json
{"type": "status", "payload": {"status": "eeprom_saved"}}
{"type": "status", "payload": {"status": "servo_completed"}}
{"type": "status", "payload": {"status": "system_started"}}
```

Mensajes de comando (comando recibido - solo si telemetría está habilitada):
```json
{"type": "cmd", "payload": {"buffer": "{\"mode\":1}"}}
```

4. Telemetría (robot → ENVÍA)
Se emite automáticamente cada 1000 ms.
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
      "encoder": 23,
      "distance": 833.46
    },
    "right": {
      "vel": 0,
      "acc": 0.5,
      "rpm": 0,
      "encoder": 0,
      "distance": 0
    },
    "battery": 12.1,
    "qtr": [1023,1023,1023,1023,1012,516],
    "pid": [0.01, 0.01, 0.01],
    "set_point": 2500,
    "base_speed": 0.8,
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
| payload.left.encoder | int32_t | ticks | Conteo encoder izquierdo |
| payload.left.distance | float | cm | Distancia recorrida motor izquierdo |
| payload.right | object | - | Datos motor derecho |
| payload.right.vel | float | cm/s | Velocidad motor derecho |
| payload.right.acc | float | cm/s² | Aceleración motor derecho |
| payload.right.rpm | float | rpm | RPM motor derecho |
| payload.right.encoder | int32_t | ticks | Conteo encoder derecho |
| payload.right.distance | float | cm | Distancia recorrida motor derecho |
| payload.battery | float | V | Voltaje de batería |
| payload.qtr[] | array[int] | 0-1023 | Valores crudos de los 6 sensores QTR |
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
6.1 Dirección + Aceleración
```json
{"rc":{"direction":90,"acceleration":0.5}}
```
direction: 0-360 grados (0=adelante, 90=derecha, 180=atrás, 270=izquierda)
acceleration: 0.0 (parado) … 1.0 (máxima velocidad)

6.2 Autopilot
```json
{"rc":{"throttle":0.5,"turn":-0.3}}
```
throttle: -1.0 (atrás) … 0 … +1.0 (adelante)
turn: -1.0 (izq) … 0 … +1.0 (der)

6.3 Manual
```json
{"rc":{"left":0.8,"right":-0.8}}
```
Cada rueda: -1.0 … +1.0

7. Funciones especiales (modo 2 - SERVO)
```json
{"servo":{"distance":30,"angle":45}}
```
Robot avanza 30 cm con giro de 45 grados y se detiene, esperando la siguiente instrucción
Finaliza con: {"type": "status", "payload": {"status": "servo_completed"}}

8. Persistencia en EEPROM
{"eeprom":1} → guarda PID, velocidad-base y modo actual
Se auto-cargan al reiniciar
Respuesta: {"type": "status", "payload": {"status": "eeprom_saved"}}

9. Referencias de hardware
Puerto serie: 9600,8,N,1 (HW 0-TX / 1-RX)
Bluetooth: emparejar y abrir puerto serie estándar
Divisor batería: 100 kΩ / 10 kΩ → pin A6, relación 11:1
Sensores IR: 6 canales analógicos A0-A5
Encoders: 90 PPR, rueda 4,5 cm → 0,039 cm/tick

10. Ejemplo rápido de sesión
```
>> {"mode":0}
<< {"type": "cmd", "payload": {"buffer": "{\"mode\":0}"}}
<< {"type": "status", "payload": {"status": "system_started"}}
<< {"type": "telemetry", "payload": {"timestamp": 12345, "mode": 1, "velocity": 9.87, "acceleration": 0.5, "distance": 833.46, "left": {"vel": 9.87, "acc": 0.5, "rpm": 39.7, "encoder": 23, "distance": 833.46}, "right": {"vel": 0, "acc": 0.5, "rpm": 0, "encoder": 0, "distance": 0}, "battery": 12.1, "qtr": [1023,1023,1023,1023,1012,516], "pid": [0.01, 0.01, 0.01], "set_point": 2500, "base_speed": 0.8, "error": 0, "correction": 0}}

>> {"servo":{"distance":25}}
<< {"type": "cmd", "payload": {"buffer": "{\"servo\":{\"distance\":25}}"}}
<< {"type": "status", "payload": {"status": "servo_completed"}}

>> {"rc":{"direction":90,"acceleration":0.5}}
<< {"type": "cmd", "payload": {"buffer": "{\"rc\":{\"direction\":90,\"acceleration\":0.5}}"}}
>> {"rc":{"throttle":0.6,"turn":0.2}}
<< {"type": "cmd", "payload": {"buffer": "{\"rc\":{\"throttle\":0.6,\"turn\":0.2}}"}}
>> {"rc":{"left":0.5,"right":0.5}}
<< {"type": "cmd", "payload": {"buffer": "{\"rc\":{\"left\":0.5,\"right\":0.5}}"}}
```

¡Listo! Con este documento tu equipo de front-end puede desarrollar la interfaz sin conocer el firmware interno.
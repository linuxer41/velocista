# Line Follower Robot - Control Documentation

## Descripción del Proyecto

Este proyecto implementa un robot seguidor de línea basado en Arduino con control PID avanzado. Incluye modos de seguimiento de línea, control remoto, y configuración ajustable vía comandos seriales.

## Arquitectura del Sistema

### Componentes Principales
- **Sensores**: 6 sensores infrarrojos QTR para detección de línea
- **Motores**: 2 motores DC con encoders para retroalimentación RPM
- **Control**: PID cascada (línea + velocidad) con lazos separados (100Hz línea, 200Hz velocidad)
- **Comunicación**: Serial (9600 baud) para comandos y telemetría
- **Debugger**: Clase centralizada para manejo de mensajes seriales (sistema y debug)

### Modos de Operación
- **LINE FOLLOWING**: Sigue la línea negra usando PID cascada (configurable on/off)
- **REMOTE CONTROL**: Control manual vía throttle/steering (siempre cascada)

## Comandos Seriales

### Configuración y Calibración
```
calibrate          - Calibra los sensores de línea
reset              - Restaura valores por defecto y resetea EEPROM
save               - Guarda configuración actual en EEPROM
```

### Control de Modo
```
set mode 0/1         - Cambia a modo seguimiento de línea (0) o control remoto (1)
set cascade 0/1      - Desactiva/activa control en cascada (solo en modo línea)
```

### Ajuste de PID
```
set line kp,ki,kd   - Configura PID de línea (ej: set line 2.0,0.05,0.75)
set left kp,ki,kd   - Configura PID motor izquierdo (ej: set left 5.0,0.5,0.1)
set right kp,ki,kd  - Configura PID motor derecho (ej: set right 5.0,0.5,0.1)
```

### Control Remoto
```
rc throttle,steering - Control remoto (ej: rc 200,50)
```

### Debug y Telemetría
```
set realtime 0/1    - Desactiva/activa salida continua de realtime
telemetry           - Envía datos de telemetry completos una sola vez
realtime            - Envía datos de realtime una sola vez
help                - Muestra lista de comandos disponibles
```

## Formato de Salida Debug

La salida de realtime se envía cada 100ms cuando está activada:

```
type:4|LINE:[429.30,-225.00]|LEFT:[120.00,232.50,166,1234]|RIGHT:[120.00,7.50,53,5678]|QTR:[687,292,0,0,0,0]|MODE:0|CASCADE:1|UPTIME:5000
```

La salida de telemetry completa se envía con el comando `telemetry`:

```
type:2|LINE_PID:[2.00,0.05,0.75,429.30,-225.00,150.00,50.00,5.25]|LVEL:[120.00,232.50,166,1234]|RVEL:[120.00,7.50,53,5678]|LEFT_PID:[5.00,0.50,0.10,232.50,166.00,112.50,25.00,2.10]|RIGHT_PID:[5.00,0.50,0.10,7.50,53.00,-7.50,15.00,1.85]|QTR:[687,292,0,0,0,0]|CASCADE:1|MODE:0|BATT:7.85|LOOP_US:45|UPTIME:5000
```

Los mensajes de sistema (comandos, estados) usan prefijo `type:1|` (mínimos para no sobrecargar):

```
type:1|Calibrating... Move robot over line.
```

Los datos de telemetry completa usan prefijo `type:2|`:

```
type:2|LINE_PID:[...]|...
```

Los datos de realtime usan prefijo `type:4|`:

```
type:4|LINE:[429.30,-225.00]|LEFT:[120.00,232.50,166,1234]|RIGHT:[120.00,7.50,53,5678]|QTR:[687,292,0,0,0,0]|MODE:0|CASCADE:1|UPTIME:5000
```

Los mensajes de confirmación de comandos usan prefijo `type:3|`:

```
type:3|ack:mode line
```

### Campos de Debug
- **LINE_PID**: [KP,KI,KD,posicion_linea,output,error,integral,derivada] del PID de línea
- **LVEL/RVEL**: [RPM_actual,RPM_objetivo,PWM,encoder_count] izquierdo/derecho
- **LEFT_PID/RIGHT_PID**: [KP,KI,KD,RPM_objetivo,output,error,integral,derivada] del PID de motor
- **QTR**: Valores crudos de los 6 sensores QTR
- **CASCADE**: Control en cascada (1=activado, 0=desactivado, solo en modo línea)
- **MODE**: Modo actual (0=LINE_FOLLOWING, 1=REMOTE_CONTROL)
- **BATT**: Voltaje de batería en V
- **LOOP_US**: Tiempo de ejecución del último ciclo PID en microsegundos
- **UPTIME**: Tiempo desde inicio en ms

### Campos de Realtime
- **LINE**: [posicion_linea,error] de la línea
- **LEFT/RIGHT**: [RPM_actual,RPM_objetivo,PWM,encoder_count] izquierdo/derecho
- **QTR**: Valores crudos de los 6 sensores QTR
- **MODE**: Modo actual (0=LINE_FOLLOWING, 1=REMOTE_CONTROL)
- **CASCADE**: Control en cascada (1=activado, 0=desactivado)
- **UPTIME**: Tiempo desde inicio en ms

## Configuración Inicial

### Valores por Defecto
```cpp
// PID Línea
KP: 2.0, KI: 0.05, KD: 0.75

// PID Motores
KP: 5.0, KI: 0.5, KD: 0.1

// Velocidad base: 200
// Máxima velocidad: 230
```

### Calibración de Sensores
1. Coloca el robot sobre la línea
2. Envía `calibrate`
3. Mueve el robot sobre la superficie blanca y negra
4. La calibración toma 5 segundos

## Interfaz para Desarrollador Frontend

### Conexión Serial
- **Baud Rate**: 9600
- **Puerto**: Depende del sistema (COMx en Windows, /dev/ttyUSBx en Linux)
- **Librería**: Web Serial API (Chrome) o Node.js serialport

### Ejemplo de Comunicación
```javascript
// Conectar
const port = await navigator.serial.requestPort();
await port.open({ baudRate: 9600 });

// Enviar comando
const writer = port.writable.getWriter();
await writer.write(new TextEncoder().encode("set mode 1\n"));

// Leer respuesta
const reader = port.readable.getReader();
const { value } = await reader.read();
console.log(new TextDecoder().decode(value));
```

### Tipos de Mensajes Seriales

El robot envía 4 tipos de mensajes por serial:

1. **type:1|mensaje** - Mensajes de sistema (respuestas a comandos)
2. **type:2|datos** - Datos de telemetry completos
3. **type:3|ack:comando** - Confirmación de comando procesado
4. **type:4|datos** - Datos de realtime (línea, motores, sensores)

### Parsing de Datos
```javascript
function parseSerialMessage(line) {
  if (line.startsWith('type:1|')) {
    // Mensaje de sistema
    const message = line.substring(7);
    handleSystemMessage(message);
  } else if (line.startsWith('type:2|')) {
    // Datos de telemetry completos - parsear arrays
    const data = parseTelemetryData(line.substring(7));
    updateUI(data);
  } else if (line.startsWith('type:3|')) {
    // Confirmación de comando
    const ack = line.substring(7);
    confirmCommand(ack);
  } else if (line.startsWith('type:4|')) {
    // Datos de realtime
    const data = parseRealtimeData(line.substring(7));
    updateRealtimeUI(data);
  }
}

function parseDebugData(debugString) {
  const data = {};
  debugString.split('|').forEach(field => {
    const [key, value] = field.split(':');
    if (value && value.startsWith('[') && value.endsWith(']')) {
      // Parsear array
      data[key] = value.slice(1, -1).split(',').map(Number);
    } else {
      data[key] = isNaN(value) ? value : Number(value);
    }
  });
  return data;
}

// Ejemplo:
// Input: "type:4|LINE:[429.30,-225.00]|LEFT:[120.00,232.50,166,1234]|RIGHT:[120.00,7.50,53,5678]|QTR:[687,292,0,0,0,0]|MODE:0|CASCADE:1|UPTIME:5000"
// Output: { LINE: [429.3, -225], LEFT: [120, 232.5, 166, 1234], RIGHT: [120, 7.5, 53, 5678], QTR: [687, 292, 0, 0, 0, 0], MODE: 0, CASCADE: 1, UPTIME: 5000 }
```

### Recomendaciones para UI
- **Gráfico de línea**: Mostrar posición de línea en tiempo real
- **Barras de PID**: Visualizar ganancias KP/KI/KD ajustables
- **Velocímetros**: RPM actual vs objetivo para cada motor
- **Sensores QTR**: Barra de 6 valores para ver cobertura de línea
- **Controles**: Joystick o sliders para throttle/steering en modo remoto
- **Logs**: Área de texto para mensajes type:1 y confirmaciones

### Comandos Recomendados para UI
1. **Conexión**: Verificar puerto serial disponible
2. **Modo**: Selector LINE/REMOTE con comandos `set mode 0` / `set mode 1`
3. **Cascada**: Toggle para control cascada con `set cascade 0/1`
4. **PID Tuning**: Sliders para KP/KI/KD con envío automático (`set line kp,ki,kd`, `set left kp,ki,kd`, `set right kp,ki,kd`)
5. **Telemetría**: Gráfico en tiempo real de posición, RPM, sensores (`set realtime 1`)
6. **Control Remoto**: Joystick virtual para enviar comandos `rc throttle,steering`
7. **Calibración**: Botón para iniciar calibración con progreso (`calibrate`)
8. **Configuración**: Guardar/cargar configuración (`save`, `reset`)

## Consideraciones Técnicas

### Control PID
- **Cascada**: PID de línea (100Hz) establece RPM objetivo, PID de velocidad (200Hz) mantiene RPM
- **Lazo Cerrado**: Usa encoders para retroalimentación RPM
- **Lazo Abierto**: Control directo PWM (solo en modo línea con cascada desactivada)
- **Modo Remoto**: Siempre cascada para control preciso de velocidad
- **Saturación**: Salidas limitadas a ±230 PWM

### Sensores
- **Rango**: 0-1000 (normalizado)
- **Posición**: Promedio ponderado de sensores
- **Umbral**: Sin línea si valores inconsistentes

### Motores
- **Encoder**: 36 pulsos por revolución
- **RPM**: Calculado cada 100ms
- **Dirección**: PWM positivo/negativo

## Troubleshooting

### Robot no responde
- Verificar conexión serial
- Enviar `help` para confirmar comunicación
- Revisar alimentación de motores

### PID no converge
- Aumentar KP para respuesta más rápida
- Ajustar KD para reducir oscilaciones
- Usar `telemetry` para monitorear PID completo
- Usar `realtime 1` para monitoreo continuo de RPM y sensores

### Sensores no calibrados
- Ejecutar `calibrate`
- Verificar superficie de contraste
- Revisar conexiones de sensores

## Desarrollo y Testing

### Compilación
```bash
pio run  # PlatformIO
```

### Testing
- Usar `set realtime 1` para monitoreo continuo de datos realtime
- `telemetry` para snapshots completos de telemetry
- `realtime` para snapshot único de datos realtime
- `set mode 0/1` para cambiar modos de operación
- `set cascade 0/1` para activar/desactivar control cascada
- `set line/left/right kp,ki,kd` para ajustar PID
- `rc throttle,steering` para control remoto
- `save` para guardar configuración en EEPROM
- `reset` para restaurar valores por defecto

### Logs
Todos los comandos y respuestas se loguean en serial para debugging de interfaz.
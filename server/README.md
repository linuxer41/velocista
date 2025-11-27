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
mode 1/2             - Cambia a modo seguimiento de línea (1) o control remoto (2)
cascade 0/1          - Desactiva/activa control en cascada (solo en modo línea)
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
debug 0/1           - Desactiva/activa salida continua de debug
telemetry           - Envía datos de debug una sola vez
help                - Muestra lista de comandos disponibles
```

## Formato de Salida Debug

La salida de debug se envía cada 500ms cuando está activada:

```
type:2|LINE_PID:[2.00,0.05,0.75,429.30,-225.00,150.00,50.00,5.25]|LVEL:[120.00,232.50,166,1234]|RVEL:[120.00,7.50,53,5678]|LEFT_PID:[5.00,0.50,0.10,232.50,166.00,112.50,25.00,2.10]|RIGHT_PID:[5.00,0.50,0.10,7.50,53.00,-7.50,15.00,1.85]|QTR:[687,292,0,0,0,0]|CASCADE:1|MODE:0|BATT:7.85|LOOP_US:45|UPTIME:5000
```

Los mensajes de sistema (comandos, estados) usan prefijo `type:1|` (mínimos para no sobrecargar):

```
type:1|Calibrating... Move robot over line.
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
await writer.write(new TextEncoder().encode("mode remote\n"));

// Leer respuesta
const reader = port.readable.getReader();
const { value } = await reader.read();
console.log(new TextDecoder().decode(value));
```

### Tipos de Mensajes Seriales

El robot envía 3 tipos de mensajes por serial:

1. **type:1|mensaje** - Mensajes de sistema (respuestas a comandos)
2. **type:2|datos** - Datos de telemetría en tiempo real
3. **type:3|ack:comando** - Confirmación de comando procesado

### Parsing de Datos
```javascript
function parseSerialMessage(line) {
  if (line.startsWith('type:1|')) {
    // Mensaje de sistema
    const message = line.substring(7);
    handleSystemMessage(message);
  } else if (line.startsWith('type:2|')) {
    // Datos de debug - parsear arrays
    const data = parseDebugData(line.substring(7));
    updateUI(data);
  } else if (line.startsWith('type:3|')) {
    // Confirmación de comando
    const ack = line.substring(7);
    confirmCommand(ack);
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
// Input: "type:2|LINE_PID:[2.00,0.05,0.75,429.30,-225.00,150.00,50.00,5.25]|LVEL:[120.00,232.50,166,1234]|..."
// Output: { LINE_PID: [2, 0.05, 0.75, 429.3, -225, 150, 50, 5.25], LVEL: [120, 232.5, 166, 1234], ... }
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
2. **Modo**: Selector LINE/REMOTE
3. **PID Tuning**: Sliders para KP/KI/KD con envío automático
4. **Telemetría**: Gráfico en tiempo real de posición, RPM, sensores
5. **Control Remoto**: Joystick virtual para enviar comandos `rc throttle,steering`
6. **Calibración**: Botón para iniciar calibración con progreso

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
- Usar `telemetry` para monitorear

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
- Usar `debug on` para monitoreo continuo
- `telemetry` para snapshots
- `reset` para estado conocido

### Logs
Todos los comandos y respuestas se loguean en serial para debugging de interfaz.
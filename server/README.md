# Line Follower Robot - Control Documentation

## Descripción del Proyecto

Este proyecto implementa un robot seguidor de línea basado en Arduino con control PID avanzado y mejoras dinámicas. Incluye modos de reposo (idle), seguimiento de línea con ajustes adaptativos, control remoto, y configuración ajustable vía comandos seriales.

## Arquitectura del Sistema

### Componentes Principales
- **Sensores**: 6 sensores infrarrojos QTR para detección de línea
- **Motores**: 2 motores DC con encoders para retroalimentación RPM
- **Control**: PID cascada (línea + velocidad) con lazos separados (100Hz línea, 200Hz velocidad)
- **Comunicación**: Serial (115200 baud) para comandos y telemetría
- **Debugger**: Clase centralizada para manejo de mensajes seriales (sistema y debug)

### Modos de Operación
- **IDLE**: Modo reposo - lee sensores pero no controla motores
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
set mode 0/1/2       - Cambia modo: 0=idle, 1=line following, 2=remote control
set cascade 0/1      - Desactiva/activa control en cascada (solo en modo línea)
```

### Ajuste de PID
```
set line kp,ki,kd   - Configura PID de línea (ej: set line 2.0,0.05,0.75)
set left kp,ki,kd   - Configura PID motor izquierdo (ej: set left 0.29,0.01,0.0025)
set right kp,ki,kd  - Configura PID motor derecho (ej: set right 0.29,0.01,0.0025)
```

### Configuración de Velocidad Base
```
set base <pwm>,<rpm>    - Configura velocidad base PWM y RPM (ej: set base 200,120)
set max <pwm>,<rpm>     - Configura velocidad máxima PWM y RPM (ej: set max 230,300)
set weight <g>          - Configura peso del robot en gramos (ej: set weight 155)
set samp_rate <line_ms>,<speed_ms>,<telemetry_ms> - Configura frecuencias de muestreo de bucles PID y telemetría (ej: set samp_rate 2,1,100)
```

**Límites de Seguridad:**
- PWM máximo: 400 (para protección de motores)
- RPM máximo: 5000 (para protección de motores)
- Los valores se limitan automáticamente si exceden estos límites

### Control Remoto
```
rc throttle,steering - Control remoto (ej: rc 200,50)
```

### Pruebas en Modo Idle
```
set pwm <derecha>,<izquierda> - Establecer PWM directo para pruebas (solo en modo idle, ej: set pwm 220,150)
set rpm <izquierda>,<derecha> - Control RPM con PID para pruebas (solo en modo idle, ej: set rpm 60,60)
```

### Debug y Telemetría
```
set telemetry 0/1    - Desactiva/activa salida continua de telemetry
set feature <idx> 0/1 - Configura habilitación individual de features (0-8)
set features 0,1,0,1,... - Configura todos los features a la vez (9 valores separados por coma)
get debug           - Envía datos de debug completos una sola vez
get telemetry        - Envía datos de telemetry una sola vez
get config          - Envía configuración actual (PID y velocidades base)
help                - Muestra lista de comandos disponibles
```

## Formato de Mensajes Seriales

### type:1 - Mensajes de Sistema
Mensajes informativos del sistema (respuestas a comandos, estados, errores):

```
type:1|Calibrating... Move robot over line.
type:1|Robot iniciado. Modo: IDLE
type:1|Comando desconocido. Envía 'help'
```

### type:2 - Confirmación de Comandos
Confirmaciones de comandos procesados correctamente:

```
type:2|ack:set mode 1
type:2|ack:set telemetry 1
type:2|ack:save
```

### type:3 - Datos de Configuración
Configuración actual del robot (PID, velocidades base, modo, cascada):

```
type:3|LINE_K_PID:[0.900,0.010,0.020]|LEFT_K_PID:[0.590,0.001,0.0025]|RIGHT_K_PID:[0.590,0.001,0.050]|BASE:[200,120.00]|MAX:[230,3000.00]|WHEELS:[32.0,85.0]|WEIGHT:155.0|SAMP_RATE:[2,1,100]|FEAT_CONFIG:[0,1,0,0,1,0,1,1,0]|MODE:1|CASCADE:1|TELEMETRY:1
```

### type:4 - Datos de Telemetry
Datos en tiempo real del robot (línea, motores, sensores):

```
type:4|LINE:[429.30,-225.00,150.50,5.25,150.00]|LEFT:[120.00,232.50,166,1234,567,-2.50,15.25,0.75]|RIGHT:[-85.50,7.50,-53,4567,890,3.20,-8.10,1.45]|PID:[150.00,166.00,53.00]|SPEED_CMS:[15.08,-10.68]|QTR:[687,292,0,0,0,0]|BATT:7.85|LOOP_US:45|UPTIME:5000|CURV:150.25|STATE:0
```

### type:5 - Datos Completos de Debug
Información completa de debugging (config + telemetry + datos PID detallados):

```
type:5|LINE_K_PID:[2.00,0.05,0.75]|LEFT_K_PID:[0.29,0.01,0.0025]|RIGHT_K_PID:[0.29,0.01,0.0025]|BASE:[200,120.00]|MAX:[230,3000.00]|WHEELS:[32.0,85.0]|MODE:1|CASCADE:1|TELEMETRY:1|LINE:[429.30,-225.00,150.50,5.25,150.00]|LEFT:[120.00,232.50,166,1234,567]|RIGHT:[-85.50,7.50,-53,4567,890]|PID:[150.00,166.00,53.00]|SPEED_CMS:[15.08,-10.68]|QTR:[687,292,0,0,0,0]|BATT:7.85|LOOP_US:45|UPTIME:5000|CURV:150.25|STATE:0
```

**Configuración (igual que type:3):**
- **LINE_K_PID**: [KP,KI,KD] ganancias PID de línea
- **LEFT_K_PID/RIGHT_K_PID**: [KP,KI,KD] ganancias PID de motores
- **BASE**: [PWM_base,RPM_base] velocidades base configuradas
- **MAX**: [PWM_max,RPM_max] velocidades máximas configuradas
- **WHEELS**: [diámetro_rueda_mm,distancia_ruedas_mm] dimensiones físicas
- **WEIGHT**: Peso del robot en gramos
- **SAMP_RATE**: [ms_línea,ms_velocidad,ms_telemetría] frecuencias de muestreo de los bucles PID y telemetría en ms
- **MODE**: Modo actual (0=IDLE, 1=LINE_FOLLOWING, 2=REMOTE_CONTROL)
- **CASCADE**: Control en cascada (1=activado, 0=desactivado)
- **TELEMETRY**: Estado de telemetría continua (1=activada, 0=desactivada)
- **FEAT_CONFIG**: [f0,f1,f2,f3,f4,f5,f6,f7,f8] configuración de features (1=habilitado, 0=deshabilitado)

**Telemetry (igual que type:4):**
- **LINE**: [posicion_linea,error,integral,derivada,correccion_aplicada] de la línea
- **LEFT/RIGHT**: [RPM_actual,RPM_objetivo,PWM,encoder_count,encoder_backward,error,integral,derivada] izquierdo/derecho
- **PID**: [output_line,output_izquierdo,output_derecho] salidas PID
- **SPEED_CMS**: [velocidad_izquierda_cm_s,velocidad_derecha_cm_s] velocidades lineales
- **QTR**: [A0,A1,A2,A3,A4,A5] valores calibrados de los 6 sensores QTR (0-1000)
- **BATT**: Voltaje de batería en V
- **LOOP_US**: Tiempo de ejecución del último ciclo PID en microsegundos
- **UPTIME**: Tiempo desde inicio en ms
- **CURV**: Curvatura actual de la línea (unidades/segundo)
- **STATE**: Estado de sensores (0=NORMAL, 1=ALL_BLACK, 2=ALL_WHITE)

### Campos de Debug (type:5)
Contiene todos los campos de configuración, telemetry y datos adicionales de debugging:

**Debug Adicional: No hay campos adicionales redundantes (toda info PID está en telemetry)**

## Configuración Inicial

### Valores por Defecto
```cpp
// PID Línea
KP: 0.900, KI: 0.010, KD: 0.020

// PID Motores
KP: 0.590, KI: 0.001, KD: 0.0025 (izq) / 0.050 (der)

// Velocidad base: 200
// Máxima velocidad: 230
// Peso del robot: 155g
// Telemetry: 1 (activada)
```

### Calibración de Sensores
1. Coloca el robot sobre la línea
2. Envía `calibrate`
3. Mueve el robot sobre la superficie blanca y negra
4. La calibración toma 5 segundos

## Interfaz para Desarrollador Frontend

### Conexión Serial
- **Baud Rate**: 115200
- **Puerto**: Depende del sistema (COMx en Windows, /dev/ttyUSBx en Linux)
- **Librería**: Web Serial API (Chrome) o Node.js serialport

### Ejemplo de Comunicación
```javascript
// Conectar
const port = await navigator.serial.requestPort();
await port.open({ baudRate: 115200 });

// Enviar comando
const writer = port.writable.getWriter();
await writer.write(new TextEncoder().encode("set mode 1\n"));

// Leer respuesta
const reader = port.readable.getReader();
const { value } = await reader.read();
console.log(new TextDecoder().decode(value));
```

### Tipos de Mensajes Seriales

El robot envía 5 tipos de mensajes por serial:

1. **type:1|mensaje** - Mensajes de sistema (respuestas a comandos)
2. **type:2|ack:comando** - Confirmación de comando procesado
3. **type:3|datos** - Datos de configuración (PID, velocidades base, modo, cascada)
4. **type:4|datos** - Datos de telemetry (línea, motores, sensores)
5. **type:5|datos** - Datos completos de debug (config + telemetry + debug extra)

### Parsing de Datos
```javascript
function parseSerialMessage(line) {
  if (line.startsWith('type:1|')) {
    // type:1 - Mensaje de sistema
    const message = line.substring(7);
    handleSystemMessage(message);
  } else if (line.startsWith('type:2|')) {
    // type:2 - Confirmación de comando
    const ack = line.substring(7);
    confirmCommand(ack);
  } else if (line.startsWith('type:3|')) {
    // type:3 - Datos de configuración
    const config = parseConfigData(line.substring(7));
    updateConfigUI(config);
  } else if (line.startsWith('type:4|')) {
    // type:4 - Datos de telemetry
    const data = parseTelemetryData(line.substring(7));
    updateTelemetryUI(data);
  } else if (line.startsWith('type:5|')) {
    // type:5 - Datos completos de debug
    const data = parseTelemetryData(line.substring(7));
    updateDebugUI(data);
  }
}

function parseTelemetryData(debugString) {
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
// Input: "type:4|LINE:[429.30,-225.00,150.50,5.25,150.00]|LEFT:[120.00,232.50,166,1234,567,-2.50,15.25,0.75]|RIGHT:[-85.50,7.50,-53,4567,890,3.20,-8.10,1.45]|PID:[150.00,166.00,53.00]|SPEED_CMS:[15.08,-10.68]|QTR:[687,292,0,0,0,0]|BATT:7.85|LOOP_US:45|UPTIME:5000|CURV:150.25|STATE:0"
// Output: { LINE: [429.3, -225, 150.5, 5.25, 150], LEFT: [120, 232.5, 166, 1234, 567, -2.5, 15.25, 0.75], RIGHT: [-85.5, 7.5, -53, 4567, 890, 3.2, -8.1, 1.45], PID: [150, 166, 53], SPEED_CMS: [15.08, -10.68], QTR: [687, 292, 0, 0, 0, 0], BATT: 7.85, LOOP_US: 45, UPTIME: 5000, CURV: 150.25, STATE: 0 }
```

### Recomendaciones para UI
- **Gráfico de línea**: Mostrar posición de línea en tiempo real
- **Barras de PID**: Visualizar ganancias KP/KI/KD ajustables
- **Velocímetros**: RPM actual vs objetivo para cada motor
- **Sensores QTR**: Barra de 6 valores para ver cobertura de línea
- **Controles**: Joystick o sliders para throttle/steering en modo remoto
- **Modo Idle**: Controles para PWM directo o RPM con PID para debugging
- **Logs**: Área de texto para mensajes type:1 y confirmaciones

### Comandos Recomendados para UI
1. **Conexión**: Verificar puerto serial disponible
2. **Modo**: Selector IDLE/LINE/REMOTE con comandos `set mode 0` / `set mode 1` / `set mode 2`
3. **Cascada**: Toggle para control cascada con `set cascade 0/1`
4. **PID Tuning**: Sliders para KP/KI/KD con envío automático (`set line kp,ki,kd`, `set left kp,ki,kd`, `set right kp,ki,kd`)
5. **Velocidad Base**: Sliders para base PWM y RPM (`set base <pwm>,<rpm>`, `set max <pwm>,<rpm>`)
6. **Telemetría**: Gráfico en tiempo real de posición, RPM, sensores (`set telemetry 1`)
7. **Control Remoto**: Joystick virtual para enviar comandos `rc throttle,steering` (RPM-based)
8. **Modo Idle**: Controles PWM directo (`set pwm <derecha>,<izquierda>`) o RPM con PID (`set rpm <izquierda>,<derecha>`)
9. **Calibración**: Botón para iniciar calibración con progreso (`calibrate`)
10. **Configuración**: Guardar/cargar configuración (`save`, `reset`)

## Consideraciones Técnicas

### Control PID
- **Cascada**: PID de línea (100Hz) establece RPM objetivo, PID de velocidad (200Hz) mantiene RPM
- **Lazo Cerrado**: Usa encoders para retroalimentación RPM
- **Lazo Abierto**: Control directo PWM (solo en modo línea con cascada desactivada)
- **Modo Remoto**: Siempre cascada para control preciso de velocidad
- **Saturación**: Salidas limitadas a ±230 PWM

### Features Avanzadas del Robot
El robot incluye 9 features configurables para optimizar el rendimiento:

#### Filtros para Procesamiento de Señal (Features 0-5)
1. **Filtro Mediano (0)**: Elimina valores atípicos usando una ventana de 3 muestras
2. **Filtro de Media Móvil (1)**: Suaviza las lecturas de posición de línea con una ventana de 3 muestras
3. **Filtro de Kalman (2)**: Estima la posición real considerando ruido de proceso (0.01) y medición (0.1)
4. **Histéresis (3)**: Evita cambios bruscos en la posición con umbral de 10 unidades
5. **Zona Muerta (4)**: Ignora errores menores a 5 unidades para reducir oscilaciones
6. **Filtro Pasa Bajos (5)**: Suaviza el error final con factor alpha de 0.8

#### Features Avanzadas (Features 6-8)
7. **PID Dinámico de Línea (6)**: Ajusta ganancias PID de línea basado en curvatura detectada
8. **Velocidad Variable (7)**: Reduce velocidad en curvas cerradas o pérdida de línea, aumenta en rectas
9. **Dirección de Giro (8)**: Elige dirección de giro cuando se pierde la línea (0=izquierda, 1=derecha)

El PID de línea incluye anti-windup integrado. Los features se aplican únicamente donde corresponde, manteniendo compatibilidad.

### Mejoras Dinámicas Recientes
- **Ajuste Dinámico de PID**: Las ganancias Kp y Kd se ajustan automáticamente basado en la curvatura detectada de la línea para una respuesta más adaptativa.
- **Control de Velocidad Variable**: La velocidad base se reduce en curvas cerradas o pérdida de línea, y aumenta en rectas para mayor velocidad promedio.
- **Logging Avanzado**: Telemetría incluye curvatura y estado de sensores para monitoreo detallado.
- **Optimización de Memoria**: Uso eficiente de tipos de datos (int16_t) y buffers minimalistas.

### Sensores
- **Rango**: 0-1000 (normalizado)
- **Posición**: Promedio ponderado de sensores
- **Umbral**: Sin línea si valores inconsistentes

### Motores
- **Encoder**: 36 pulsos por revolución, dirección determinada comparando canales A y B durante interrupción en A
- **Dirección Encoder**: Si canal A y B tienen el mismo valor (ambos HIGH o ambos LOW) = sentido horario; si difieren = sentido antihorario
- **RPM**: Calculado cada 100ms, puede ser positivo/negativo según dirección real de giro
- **Encoder Count**: Contador acumulado, puede ser positivo/negativo según dirección
- **Dirección**: PWM positivo/negativo para comando, pero dirección real medida por encoders

## Troubleshooting

### Robot no responde
- Verificar conexión serial
- Enviar `help` para confirmar comunicación
- Revisar alimentación de motores

### PID no converge
- Aumentar KP para respuesta más rápida
- Ajustar KD para reducir oscilaciones
- Usar `debug` para monitorear PID completo
- Usar `telemetry 1` para monitoreo continuo de RPM y sensores

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
- Usar `set telemetry 1` para monitoreo continuo de datos telemetry
- `get debug` para snapshots completos de debug
- `get telemetry` para snapshot único de datos telemetry
- `get config` para obtener configuración actual
- `set mode 0/1/2` para cambiar modos: 0=idle, 1=line, 2=remote
- `set cascade 0/1` para activar/desactivar control cascada
- `set line/left/right kp,ki,kd` para ajustar PID
- `set base <pwm>,<rpm>` y `set max <pwm>,<rpm>` para configurar velocidades base y máxima
- `set weight <g>` para configurar peso del robot
- `set samp_rate <line_ms>,<speed_ms>,<telemetry_ms>` para configurar frecuencias de muestreo
- `rc throttle,steering` para control remoto (RPM-based)
- `set pwm <derecha>,<izquierda>` para control PWM directo en modo idle
- `set rpm <izquierda>,<derecha>` para control RPM con PID en modo idle
- `save` para guardar configuración en EEPROM
- `reset` para restaurar valores por defecto

### Logs
Todos los comandos y respuestas se loguean en serial para debugging de interfaz.
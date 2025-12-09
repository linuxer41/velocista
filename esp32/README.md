# Robot Seguidor de Línea ESP32

Este proyecto implementa un robot seguidor de línea utilizando un ESP32 DevKit v1, sensores infrarrojos QTR-8A, motores DC con controlador DRV8833, y algoritmos PID para control de velocidad y dirección.

## Características

- **Microcontrolador**: ESP32 DevKit v1 (ESP32-WROOM-32)
- **Sensores**: 16 sensores infrarrojos via multiplexor 74HC4067 para detección de línea
- **Motores**: 2 motores DC con encoders para retroalimentación de velocidad
- **Control**: PID para seguimiento de línea y control de velocidad
- **Comunicación**: UART para comandos y telemetría
- **Modos**: Seguimiento de línea, control remoto, idle

## Hardware Requerido

- ESP32 DevKit v1
- 16 sensores infrarrojos (ej. QTR-1A o similares)
- Multiplexor analógico 74HC4067
- 2 motores DC con encoders
- Controlador de motores DRV8833
- Batería (7.4V LiPo recomendada)
- Cables y protoboard

## Conexiones de Pines (ESP32 DevKit v1)

### Motores (DRV8833)
- **Motor Izquierdo**:
  - PIN1 (IN1): GPIO 12
  - PIN2 (IN2): GPIO 13
- **Motor Derecho**:
  - PIN1 (IN1): GPIO 14
  - PIN2 (IN2): GPIO 15

### Encoders
- **Encoder Izquierdo**:
  - A: GPIO 2
  - B: GPIO 4
- **Encoder Derecho**:
  - A: GPIO 5
  - B: GPIO 18

### Sensores y Multiplexor 74HC4067
- **ADC**: GPIO 34 (ADC1_6) conectado a salida del multiplexor
- **Select Pins del 74HC4067**:
  - S0: GPIO 35
  - S1: GPIO 36
  - S2: GPIO 37
  - S3: GPIO 38
- **Power Pin**: GPIO 33 (para encender LEDs de sensores)
- **Sensores**: Conectados a canales C0-C15 del 74HC4067

### LED de Modo
- **LED**: GPIO 19

### UART (para comandos y debug)
- **TX**: GPIO 1 (default)
- **RX**: GPIO 3 (default)
- **Baud Rate**: 115200

### Pines por Defecto del ESP32 DevKit v1
- **GPIO 0**: Boot button (pull-up)
- **GPIO 2**: LED integrado
- **GPIO 4**: No conectado
- **GPIO 5**: No conectado
- **GPIO 12-15, 18, 19, 21-23, 25-27, 32-39**: Disponibles
- **GPIO 1, 3**: UART0
- **GPIO 9, 10**: No disponibles (flash)
- **GPIO 6-11**: No disponibles (flash)
- **GPIO 16, 17**: UART2
- **GPIO 34-39**: Solo entrada (ADC)

### Resumen de Pines Utilizados en el Proyecto
- **Motores (DRV8833)**:
  - Izquierdo: GPIO 12 (IN1), 13 (IN2)
  - Derecho: GPIO 14 (IN1), 15 (IN2)
- **Encoders**:
  - Izquierdo: GPIO 2 (A), 4 (B)
  - Derecho: GPIO 5 (A), 18 (B)
- **Sensores (74HC4067)**:
  - ADC: GPIO 34
  - S0: GPIO 35, S1: GPIO 36, S2: GPIO 37, S3: GPIO 38
  - Power: GPIO 33
- **Botón Calibración**: GPIO 25
- **LED Modo**: GPIO 19
- **UART**: GPIO 1 (TX), 3 (RX)

## Instalación y Configuración

1. **Instalar PlatformIO**:
   - Instalar VS Code
   - Instalar extensión PlatformIO

2. **Clonar o descargar el proyecto**:
   ```
   git clone <url-del-repo>
   cd esp32-line-follower
   ```

3. **Conectar el ESP32**:
   - Conectar via USB
   - Verificar puerto en PlatformIO

4. **Compilar y subir**:
   ```
   pio run --target upload
   ```

5. **Monitor serial**:
   ```
   pio device monitor
   ```

## Uso

### Modos de Operación

1. **Idle (por defecto)**: Lee sensores, no mueve motores
2. **Seguimiento de línea**: Sigue la línea negra usando PID
3. **Control remoto**: Control manual via UART

### Comandos UART

- `calibrate`: Calibra sensores (mueve el robot manualmente)
- `save`: Guarda configuración en NVS
- `reset`: Restaura configuración por defecto
- `help`: Muestra comandos disponibles

### Botón de Calibración

- **Botón**: GPIO 25 (con pull-up, presionar conecta a GND)
- Al presionar el botón, se inicia la calibración automática de sensores

### Telemetría

El robot envía datos via UART en formato:
```
T:posicion_linea,rpm_izq,rpm_der,tiempo_up
```

## Configuración PID

Los valores PID se pueden ajustar en `include/config.h`:

- **Línea**: KP=1.5, KI=0.001, KD=0.05
- **Motor Izq**: KP=0.59, KI=0.001, KD=0.0025
- **Motor Der**: KP=0.59, KI=0.001, KD=0.05

## Estructura del Código

- `src/main.cpp`: Punto de entrada, inicialización
- `include/config.h` / `src/config.cpp`: Configuraciones
- `include/motor.h` / `src/motor.cpp`: Control de motores
- `include/sensor.h` / `src/sensor.cpp`: Lectura de sensores
- `include/pid.h` / `src/pid.cpp`: Control PID
- `include/features.h` / `src/features.cpp`: Filtros de señal
- `include/robot.h` / `src/robot.cpp`: Clase principal Robot
- `include/tasks.h` / `src/tasks.cpp`: Tareas FreeRTOS

## Mejoras Implementadas

- Arquitectura modular con clases separadas
- Encapsulación de estado global en clase Robot
- Configuración persistente en NVS
- Filtros de señal (media móvil, Kalman, etc.)
- Control PID con anti-windup
- Manejo de errores básico

## Troubleshooting

- **No compila**: Verificar instalación de ESP-IDF en PlatformIO
- **No conecta**: Verificar puerto COM y drivers CP210x
- **Sensores no calibran**: Mover robot sobre línea negra/blanca durante calibración
- **Motores no giran**: Verificar conexiones DRV8833 y alimentación

## Licencia

Este proyecto es de código abierto. Úsalo bajo tu propio riesgo.

## Contribuciones

Bienvenidas las mejoras y correcciones.
# Aplicación de Control Bluetooth para Seguidor de Línea

Una aplicación Flutter completa para monitorear y controlar robots seguidores de línea Arduino Nano mediante comunicación Bluetooth.

## Resumen

Esta aplicación transforma el sistema original de control TCP basado en PIR/LDR en un **trazador y visualizador** completo para un carro velocista con encoders de motor, soportando sensores QTR de 6 y 8 unidades.

## Características

### 🔗 Comunicación (Plataforma-Dependiente)
- **Android/iOS**: Comunicación Bluetooth Classic vía módulo HC-09
- **Windows**: Comunicación Serial directa (USB/COM)
- **Descubrimiento de Dispositivos**: Bluetooth discovery en móviles, selección de puerto COM en Windows
- **Datos en Tiempo Real**: Recibir telemetría cada 1000ms (configurable)
- **Control Bidireccional**: Enviar comandos JSON y recibir respuestas
- **Reconexión Automática**: Reconexión automática al desconectarse (ambas plataformas)

### 📊 Visualización de Datos en Tiempo Real
- **Estado del Sistema**: Posición, error, detección de línea, velocidades, distancia
- **Visualización Sensores QTR**: Malla visual mostrando todos los valores de sensores (6 o 8 sensores)
- **Control de Motores**: Comandos de motor en tiempo real y retroalimentación de encoders
- **Estadísticas**: Métricas de rendimiento y calidad de seguimiento
- **Historial de Datos**: Almacenar y mostrar lecturas recientes de sensores

### 🎛️ Interfaz de Configuración PID
- **Ajuste en Tiempo Real**: Ajustar parámetros Kp, Ki, Kd en vivo
- **Control de Setpoint**: Configurar objetivos de posición de línea
- **Gestión de Velocidades**: Establecer velocidades base de motores
- **Configuraciones Predefinidas**: Configuración rápida para 6 o 8 sensores
- **Perfiles de Parámetros**: Guardar y cargar diferentes perfiles de ajuste

### 📱 Terminal de Comunicación
- **Monitoreo en Tiempo Real**: Visualización en vivo de comunicación (Bluetooth/Serial)
- **Historial de Mensajes**: Rastrear todos los comandos enviados y datos recibidos
- **Información de Depuración**: Estado de conexión y mensajes de error
- **Registro de Comandos**: Log de mensajes basado en marcas de tiempo
- **Selección de Puerto**: Para Windows, permite elegir puerto COM específico

### 🎮 Modos de Operación

#### Modo 0: LINE_FOLLOW (Seguidor de Línea)
- Control PID automático para seguimiento de línea
- Usa sensores QTR para calcular posición
- Ajusta velocidad de motores basado en error

#### Modo 1: REMOTE_CONTROL (Control Remoto Unificado)
- **Dirección + Aceleración**: Control vectorial (0-360° + 0-1)
- **Autopilot**: Control estilo coche (throttle/turn: -1.0 a +1.0)
- **Manual**: Control directo de ruedas (left/right: -1.0 a +1.0)

#### Modo 2: SERVO_DIST (Distancia con Giro)
- Avanza distancia específica con giro opcional
- Regresa automáticamente al punto de origen
- Finaliza con mensaje de estado

#### Modo 3: POINT_LIST (Lista de Puntos)
- Ejecuta secuencia de distancias y giros
- Formato: "distancia,grados,distancia,grados,..."
- Giro positivo = derecha (diferencial)

### 🔧 Soporte para Sensores QTR de 6 y 8
- **Conteo Dinámico de Sensores**: Detecta automáticamente 6 o 8 sensores
- **Cálculo de Posición**: Promedio ponderado apropiado para ambas configuraciones
- **Mapeo de Pines**: Asignaciones correctas de pines Arduino (A0-A5 para 6 sensores, A0-A7 para 8 sensores)
- **Ajuste de Setpoint**: Cálculo automático de setpoint basado en cantidad de sensores

## Requisitos de Hardware

### Componentes Arduino Nano
- **Microcontrolador**: Arduino Nano (ATmega328P)
- **Sensores**: Array QTR-8A (6 sensores en pines A0-A5 o 8 sensores en A0-A7)
- **Motores**: 2 motores DC con controlador DRV8833
- **Encoders**: Encoders ópticos o magnéticos para retroalimentación de velocidad
- **Bluetooth**: Módulo HC-09 conectado a serial hardware (D0/D1)

### Configuración de Pines

#### 6 Sensores QTR (Configuración Actual)
```
Sensor QTR 2 → A0 (pin 14)
Sensor QTR 3 → A1 (pin 15)
Sensor QTR 4 → A2 (pin 16)
Sensor QTR 5 → A3 (pin 17)
Sensor QTR 6 → A4 (pin 18)
Sensor QTR 7 → A5 (pin 19)
Control QTR IR → D13
```

#### 8 Sensores QTR (Actualización Futura)
```
Sensor QTR 1 → A0 (pin 14)
Sensor QTR 2 → A1 (pin 15)
Sensor QTR 3 → A2 (pin 16)
Sensor QTR 4 → A3 (pin 17)
Sensor QTR 5 → A4 (pin 18)
Sensor QTR 6 → A5 (pin 19)
Sensor QTR 7 → A6 (pin 20)
Sensor QTR 8 → A7 (pin 21)
Control QTR IR → D13
```

#### Control de Motor (DRV8833)
```
Motor Izquierdo:
  IN1 → D5
  IN2 → D6

Motor Derecho:
  IN1 → D9
  IN2 → D10
```

#### Encoders
```
Encoder Izquierdo:
  A → D2 (INT0)
  B → D4

Encoder Derecho:
  A → D7 (PinChange)
  B → D8
```

#### Bluetooth HC-09
```
HC-09 VCC → 5V
HC-09 GND → GND
HC-09 TX → Arduino RX (D0)
HC-09 RX → Arduino TX (D1)
```

## Formato de Datos JSON

### Arduino → Aplicación Telemetría
```json
{
  "type": "telemetry",
  "payload": {
    "mode": 1,
    "speed": 9.87,
    "distance": 833.46,
    "battery": 12.1,
    "sensors": [1023,1023,1023,1023,1012,516],
    "pid": [0.01, 0.01, 0.01],
    "left_rpm": 39.7,
    "right_rpm": 0,
    "left_encoder": 23,
    "right_encoder": 0,
    "position": 2500,
    "error": 0,
    "correction": 0
  }
}
```

### Aplicación → Arduino Comandos

#### Cambio de Modo
```json
{"mode": 0}
```

#### Configuración PID
```json
{"pid": [1.2, 0.05, 0.02]}
```

#### Velocidad Base
```json
{"speed": {"base": 0.7}}
```

#### Control Remoto (Unificado)
```json
// Dirección + Aceleración
{"remote_control": {"direction": 90, "acceleration": 0.5}}

// Autopilot
{"remote_control": {"throttle": 0.5, "turn": -0.3}}

// Manual
{"remote_control": {"left": 0.8, "right": -0.8}}
```

#### Servo Distancia
```json
{"servoDistance": 30, "servoAngle": 45}
```

#### Ruta por Puntos
```json
{"routePoints": "20,0,10,-90,20,0"}
```

#### Otros Comandos
```json
{"eeprom": 1}           // Guardar configuración
{"telemetry": 1}        // Solicitar telemetría única
{"telemetry_enable": false}  // Habilitar/deshabiltar telemetría automática
{"calibrate_qtr": 1}    // Calibrar sensores QTR
```

### Mensajes de Estado
```json
{"type": "status", "payload": {"status": "eeprom_saved"}}
{"type": "status", "payload": {"status": "points_loaded"}}
{"type": "status", "payload": {"status": "servo_distance_completed"}}
{"type": "status", "payload": {"status": "route_completed"}}
{"type": "status", "payload": {"status": "system_started"}}
```

### Eco de Comandos
```json
{"type": "cmd", "payload": {"buffer": "{\"mode\":1}"}}
```

## Estructura de la Aplicación

### Archivos Principales
- `lib/main.dart` - Punto de entrada de la aplicación
- `lib/line_follower_provider.dart` - Gestión de estado (ChangeNotifier)
- `lib/line_follower_home.dart` - Interfaz principal con 4 pestañas
- `lib/bluetooth_client.dart` - Lógica de comunicación Bluetooth
- `lib/arduino_data.dart` - Modelos de datos y análisis

### Pestañas de Interfaz
1. **Pestaña Conectar**: Descubrimiento y conexión de dispositivos (Bluetooth en Android/iOS, Serial en Windows)
2. **Pestaña Dashboard**: Visualización y monitoreo de datos en tiempo real
3. **Pestaña Configuración PID**: Ajuste y configuración de parámetros
4. **Pestaña Terminal**: Monitoreo de comunicación (Bluetooth/Serial)

## Instalación y Configuración

### 1. Dependencias
La aplicación requiere estos paquetes Flutter:
```yaml
flutter_bluetooth_classic_serial: ^1.3.2  # Para Android/iOS
serial_port_win32: ^0.1.0                 # Para Windows Serial
fl_chart: ^1.1.1
shared_preferences: ^2.5.3
provider: ^6.1.5
```

### 2. Permisos de Android
Agregar a `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
```

### 3. Compilar y Ejecutar
```bash
flutter pub get
flutter run
```

## Uso

### 1. Conexión (Plataforma-Dependiente)

#### Android/iOS - Bluetooth:
1. Abrir la aplicación
2. Ir a la pestaña "Conectar"
3. Tocar "Buscar" para descubrir dispositivos Bluetooth
4. Seleccionar dispositivo HC-09 emparejado
5. Conexión establecida automáticamente

#### Windows - Serial:
1. Abrir la aplicación
2. Ir a la pestaña "Conectar"
3. Seleccionar "Modo Serial" o puerto COM disponible
4. Elegir el puerto COM donde está conectado Arduino (ej: COM3)
5. Conexión establecida automáticamente

### 2. Monitoreo en Tiempo Real
1. Ir a la pestaña "Dashboard"
2. Ver estado del sistema, valores de sensores y control de motores
3. Monitorear calidad de seguimiento y estadísticas
4. Verificar retroalimentación de encoders y distancia recorrida

### 3. Ajuste PID
1. Ir a la pestaña "Configuración PID"
2. Ajustar parámetros Kp, Ki, Kd usando deslizadores
3. Modificar setpoint y velocidad base
4. Usar configuraciones predefinidas para 6 o 8 sensores
5. Los cambios se envían inmediatamente vía Bluetooth

### 4. Monitoreo de Terminal
1. Ir a la pestaña "Terminal"
2. Ver log de comunicación en tiempo real (Bluetooth/Serial)
3. Monitorear estado de conexión y recepción de datos
4. En Windows, verificar puerto COM seleccionado
5. Limpiar historial de terminal según sea necesario

## Ejemplos de Configuración

### Configuración PID 6 Sensores
```json
{"pid": [1.0, 0.0, 0.0]}
{"speed": {"base": 0.8}}
```

### Configuración PID 8 Sensores
```json
{"pid": [1.2, 0.05, 0.1]}
{"speed": {"base": 0.75}}
```

### Ejemplos de Sesión Interactiva
```
>> {"mode": 0}
<< {"type": "cmd", "payload": {"buffer": "{\"mode\":0}"}}
<< {"type": "status", "payload": {"status": "system_started"}}

>> {"remote_control": {"direction": 90, "acceleration": 0.5}}
<< {"type": "cmd", "payload": {"buffer": "{\"remote_control\":{\"direction\":90,\"acceleration\":0.5}}"}}

>> {"servoDistance": 25}
<< {"type": "cmd", "payload": {"buffer": "{\"servoDistance\":25}"}}
<< {"type": "status", "payload": {"status": "servo_distance_completed"}}

>> {"routePoints": "20,0,10,-90,20,0"}
<< {"type": "cmd", "payload": {"buffer": "{\"routePoints\":\"20,0,10,-90,20,0\"}"}}
<< {"type": "status", "payload": {"status": "route_completed"}}
```

## Integración con Código Arduino

La aplicación está diseñada para trabajar con el firmware "Velocista" v1.5 que:
- Soporta comunicación JSON bidireccional por puerto serie (9600 bps)
- Implementa 4 modos de operación: LINE_FOLLOW, REMOTE_CONTROL, SERVO_DIST, POINT_LIST
- Envía telemetría automática cada 1000ms (configurable)
- Recibe comandos JSON para control en tiempo real
- Gestiona sensores QTR-8A (6 o 8 sensores) con control IR
- Implementa control PID para seguimiento de línea
- Maneja encoders para medición de velocidad y distancia
- Soporta persistencia de configuración en EEPROM
- Incluye funciones especiales: servo-distancia, rutas por puntos, calibración

### Protocolo de Comunicación
- **Formato**: JSON de una sola línea terminado en \n
- **Codificación**: UTF-8
- **Tamaño máximo**: 512 bytes
- **Claves**: camelCase descriptivo
- **Respuestas**: Telemetría automática + estados específicos + eco de comandos

## Solución de Problemas

### Problemas de Conexión

#### Android/iOS (Bluetooth):
- Asegurar que Bluetooth esté habilitado en el dispositivo
- Verificar que HC-09 esté emparejado y sea detectable
- Verificar fuente de alimentación de Arduino
- Confirmar baud rate correcto (9600)

#### Windows (Serial):
- Verificar que Arduino esté conectado por USB
- Confirmar puerto COM correcto en Administrador de Dispositivos
- Asegurar que ningún otro programa use el puerto
- Verificar drivers USB-Serial estén instalados
- Confirmar baud rate correcto (9600, 8,N,1)

### Problemas de Sensores
- Verificar conexiones QTR-8A
- Verificar control LED IR en D13
- Calibrar valores de sensores (0=línea, 1023=blanco)
- Asegurar condiciones de iluminación apropiadas

### Control de Motores
- Verificar conexiones DRV8833
- Verificar voltaje de fuente de alimentación
- Probar dirección de motor manualmente
- Verificar conexiones de encoders

### Problemas de Rendimiento
- Monitorear fuerza de señal Bluetooth
- Verificar interferencias
- Verificar tasa de transmisión de datos
- Monitorear carga de procesamiento de Arduino

## Mejoras Futuras

1. **Análisis Avanzados**: Gráficos de rendimiento y tendencias
2. **Mapeo de Pista**: Guardar y reproducir configuraciones de pista
3. **Múltiples Robots**: Soporte para múltiples unidades Arduino
4. **Sincronización en la Nube**: Guardar configuraciones en almacenamiento en la nube
5. **Asistencia IA**: Optimización PID basada en ML
6. **Exportar Datos**: Funcionalidad de exportación de datos CSV/JSON
7. **Temas Personalizados**: Opciones de personalización de UI
8. **Control por Voz**: Comandos de voz para operación manos libres

## Licencia

Este proyecto está bajo la Licencia MIT - ver el archivo LICENSE para detalles.

## Contribución

1. Fork del repositorio
2. Crear rama de características (`git checkout -b feature/AmazingFeature`)
3. Confirmar cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a rama (`git push origin feature/AmazingFeature`)
5. Abrir un Pull Request

## Soporte

Para soporte y preguntas:
- Crear un issue en GitHub
- Verificar la sección de solución de problemas
- Revisar documentación de código Arduino
- Contactar al equipo de desarrollo

---

**Versión**: 2.1.0 (Actualizado para API Velocista v1.5)
**Última Actualización**: Noviembre 2024
**Versión Flutter**: 3.5.2+
**Plataforma Objetivo**: Android, iOS, Windows
**Biblioteca Bluetooth**: flutter_bluetooth_classic_serial ^1.3.2 (Android/iOS)
**Biblioteca Serial**: serial_port_win32 ^0.1.0 (Windows)
**Firmware Compatible**: Velocista v1.5 (telemetría extendida)

## 🔄 Migración a flutter_bluetooth_classic_serial

El proyecto ha sido migrado exitosamente de `flutter_bluetooth_serial` a `flutter_bluetooth_classic_serial` para mejorar la estabilidad y compatibilidad con la plataforma.

### Beneficios de la Migración:
- ✅ **Mejor Arquitectura**: API más nueva y estable
- ✅ **Rendimiento Mejorado**: Optimizado para comunicación Bluetooth Classic
- ✅ **Manejo de Errores Mejorado**: Mejor gestión de estado de conexión
- ✅ **API Simplificada**: Métodos simplificados para descubrimiento y conexión de dispositivos
- ✅ **A Prueba de Futuro**: Paquete mejor mantenido y actualizado

### Detalles de Migración:
- **De**: `flutter_bluetooth_serial: ^0.4.0`
- **A**: `flutter_bluetooth_classic_serial: ^1.3.2`
- **Cambios de API**: Importaciones y métodos de conexión actualizados
- **Compatibilidad hacia Atrás**: Todo el análisis de datos permanece idéntico

### Ejemplo de Código (Nueva API):
```dart
import 'package:flutter_bluetooth_classic_serial/flutter_bluetooth_classic.dart';

FlutterBluetoothClassic bluetooth = FlutterBluetoothClassic();

// Verificar estado de Bluetooth
bool isSupported = await bluetooth.isBluetoothSupported();
bool isEnabled = await bluetooth.isBluetoothEnabled();

// Obtener dispositivos emparejados
List<BluetoothDevice> devices = await bluetooth.getPairedDevices();

// Conectar a dispositivo
bool connected = await bluetooth.connect(device.address);

// Escuchar datos
bluetooth.onDataReceived.listen((data) {
  print('Recibido: ${data.asString()}');
});

// Enviar mensaje
await bluetooth.sendString('{"command": "getStatus"}');
```
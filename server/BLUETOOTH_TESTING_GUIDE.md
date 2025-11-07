# Guía de Prueba de Comunicación Bluetooth

## Problemas Solucionados

### 1. **Función setupBluetooth() Descomentada**
- La función de configuración del HC-06 ahora está activa
- Configura PIN (9876) y nombre (VelocistaBot) del módulo Bluetooth

### 2. **Conflictos de Pines Serial Resueltos**
- **ANTES**: Usaba hardware serial (pines 0,1) para Bluetooth Y debugging
- **AHORA**: 
  - Hardware Serial (pines 0,1): Solo para debugging via USB
  - SoftwareSerial (pines 11,12): Solo para comunicación Bluetooth HC-06

### 3. **Conexión de Hardware**
```
HC-06 Pin    → Arduino Pin
VCC         → 5V
GND         → GND
TX          → Pin 12 (Arduino RX para SoftwareSerial)
RX          → Pin 11 (Arduino TX para SoftwareSerial)
```

### 4. **Pines de Encoders Corregidos**
- Encoder derecho canal A: Pin 3 (antes estaba en pin 7)
- Comentarios actualizados para reflejar la configuración correcta

## Nuevas Características de Monitoreo

### 1. **Comando de Estado del Sistema**
```json
{"getStatus": true}
```
**Respuesta:**
```json
{
  "bluetoothConnected": true,
  "errorCount": 0,
  "uptime": 12345,
  "freeMemory": 2048
}
```

### 2. **Monitoreo de Conexión**
- Timeout de 10 segundos sin actividad = desconectado
- Contador de errores de parsing JSON
- Reset automático de contadores si hay muchos errores

### 3. **Mejor Manejo de Errores**
- Detecta JSON inválido
- Cuenta errores y proporciona feedback
- Respuestas JSON estructuradas para todos los comandos

## Procedimiento de Prueba

### Paso 1: Verificar Hardware
1. Conecta el HC-06 según el diagrama de pines
2. Verifica que el LED del HC-06 parpadee (modo pairing)

### Paso 2: Compilar y Cargar
1. Compila el código en PlatformIO
2. Carga al Arduino Nano
3. Abre el monitor serial (9600 baud) para ver el debug

### Paso 3: Conectar por Bluetooth
1. En tu teléfono/PC, busca dispositivos Bluetooth
2. Busca "VelocistaBot"
3. Conecta con PIN: 9876
4. Usa una app de terminal Bluetooth (como Serial WiFi Terminal para Android)

### Paso 4: Probar Comandos Básicos
```json
{"getMode": true}
```
**Debería responder:**
```json
{"currentMode": 0, "modeName": "Line Following"}
```

### Paso 5: Cambiar Modo
```json
{"mode": 1}
```
**Debería responder:**
```json
{"status": "configured"}
```

### Paso 6: Probar Control de Motor (Modo Manual)
```json
{"mode": 2}
{"leftSpeed": 0.5}
{"rightSpeed": 0.5}
```

### Paso 7: Verificar Telemetría
- El sistema envía datos cada 100ms automáticamente
- Incluye modo actual, velocidades, encoders, etc.

## Solución de Problemas

### Si no hay comunicación Bluetooth:

1. **Verificar conexiones:**
   - HC-06 TX → Pin 12
   - HC-06 RX → Pin 11
   - VCC → 5V
   - GND → GND

2. **Verificar configuración HC-06:**
   - LED parpadeando = modo pairing
   - LED fijo = conectado

3. **Probar comandos básicos:**
   - Envía `{"getStatus": true}`
   - Verifica respuesta JSON válida

4. **Verificar en monitor serial:**
   - ¿Aparece "Bluetooth HC-06 configured"?
   - ¿Hay errores de compilación?

### Si hay errores de JSON:
- Verifica que los comandos tengan formato JSON válido
- Usa comillas dobles: `{"comando": "valor"}`
- Evita comas extra al final

### Si los motores no se mueven:
- Verifica alimentación de motores
- Verifica conexiones DRV8833
- Prueba en modo manual con velocidades bajas

## Comandos de Prueba Completos

```json
// 1. Obtener estado del sistema
{"getStatus": true}

// 2. Cambiar a modo autopilot
{"mode": 1}

// 3. Control de velocidad (adelante)
{"throttle": 0.5, "direction": 1}

// 4. Giro a la derecha
{"turn": 0.3}

// 5. Parada de emergencia
{"emergencyStop": true}

// 6. Cambiar a modo manual
{"mode": 2}

// 7. Control individual de motores
{"leftSpeed": 0.3, "rightSpeed": 0.7}

// 8. Guardar configuración
{"saveConfig": true}

// 9. Obtener modo actual
{"getMode": true}
```

## Notas Técnicas

- **Baud rate**: 9600 para both Serial y SoftwareSerial
- **Timeout conexión**: 10 segundos sin actividad
- **Frecuencia telemetría**: 10Hz (cada 100ms)
- **Memoria estimada libre**: ~2KB en Arduino Nano
- **Pines Bluetooth**: 11 (TX), 12 (RX)
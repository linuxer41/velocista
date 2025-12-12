# Seguidor de Línea con PID Triple - Optimizado

Este proyecto implementa un seguidor de línea usando Arduino con PID triple (línea y velocidad izquierda/derecha), optimizado para PlatformIO.

## Características
- PID de línea para corrección de trayectoria
- PID de velocidad para control de motores (opcional cascada)
- Salida CSV para graficación en tiempo real
- Comandos seriales para configuración dinámica
- Optimizado para bajo jitter y alta frecuencia de muestreo

## Configuración Inicial
- DEBUG: Activado por defecto (salida CSV cada 100ms)
- CASCADE: Desactivado por defecto (solo PID de línea)

## Comandos Seriales
Envía comandos vía Serial Monitor (115200 baud) en formato: `comando valor`

| Comando | Descripción | Ejemplo |
|---------|-------------|---------|
| 7 | Activar/desactivar debug (0=off, 1=on) | `7 1` (activa debug) |
| 8 | Activar/desactivar cascada PID (0=off, 1=on) | `8 1` (activa cascada) |
| 4 | Set Line PID (Kp Ki Kd) | `4 0.3 0.0 0.7875` |
| 5 | Set Right PID (Kp Ki Kd) | `5 0.55 0.0014 0.015` |
| 6 | Set Left PID (Kp Ki Kd) | `6 0.55 0.0014 0.015` |

Otros comandos disponibles (CALIBRATE=1, SET_PWM=2, etc.) pero no implementados en loop.

## Salida CSV
Cuando debug está activado, envía cada 100ms:
```
time,pos,rpmL,rpmR
```
- time: millis() desde inicio
- pos: posición de línea (-3500 a 3500)
- rpmL: RPM rueda izquierda
- rpmR: RPM rueda derecha

## Interfaz Web para Control y Graficación
Ejecuta la aplicación web para control en tiempo real y graficación.

### Requisitos
- Python 3.x
- Instala dependencias: `pip install -r requirements.txt`

### Ejecución
1. Compila y sube el código Arduino: `pio run --target upload`
2. Ejecuta la app Python: `python app.py`
3. Abre http://localhost:5000 en tu navegador

### Funcionalidades Web
- Selección de puerto COM
- Conexión/desconexión serial
- Toggle debug y cascada
- Ajuste de ganancias PID en tiempo real
- Gráficos en tiempo real: Posición, RPM, Error de línea

## Graficación con Python (Standalone)
Usa este script para leer Serial y graficar en tiempo real:

```python
import serial
import matplotlib.pyplot as plt
import matplotlib.animation as animation
from collections import deque

# Configura puerto Serial (cambia 'COM3' por tu puerto)
ser = serial.Serial('COM3', 115200, timeout=1)

# Buffers para datos
times = deque(maxlen=100)
positions = deque(maxlen=100)
rpmLs = deque(maxlen=100)
rpmRs = deque(maxlen=100)

fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(10, 8))

def animate(i):
    try:
        line = ser.readline().decode('utf-8').strip()
        if ',' in line:
            parts = line.split(',')
            if len(parts) == 4:
                t, pos, rpmL, rpmR = map(float, parts)
                times.append(t)
                positions.append(pos)
                rpmLs.append(float(rpmL))
                rpmRs.append(float(rpmR))
    except:
        pass

    ax1.clear()
    ax1.plot(times, positions)
    ax1.set_title('Posición de Línea')
    ax1.set_xlabel('Tiempo (ms)')
    ax1.set_ylabel('Posición')

    ax2.clear()
    ax2.plot(times, rpmLs, label='Izquierda')
    ax2.plot(times, rpmRs, label='Derecha')
    ax2.set_title('RPM Ruedas')
    ax2.legend()
    ax2.set_xlabel('Tiempo (ms)')
    ax2.set_ylabel('RPM')

    # Error de línea (opcional: diferencia de posición)
    ax3.clear()
    if len(positions) > 1:
        errors = [p - (-500) for p in positions]  # Centro en -500
        ax3.plot(times, errors)
    ax3.set_title('Error de Línea')
    ax3.set_xlabel('Tiempo (ms)')
    ax3.set_ylabel('Error')

    # Diferencia RPM (opcional)
    ax4.clear()
    if len(rpmLs) > 0:
        diffs = [l - r for l, r in zip(rpmLs, rpmRs)]
        ax4.plot(times, diffs)
    ax4.set_title('Diferencia RPM L-R')
    ax4.set_xlabel('Tiempo (ms)')
    ax4.set_ylabel('Diferencia RPM')

ani = animation.FuncAnimation(fig, animate, interval=100)
plt.tight_layout()
plt.show()
```

### Instrucciones:
1. Conecta Arduino y nota el puerto COM.
2. Ejecuta el script Python (instala `pyserial` y `matplotlib` si no los tienes: `pip install pyserial matplotlib`).
3. En Serial Monitor, envía `7 1` para activar debug.
4. El gráfico se actualizará en tiempo real.

## Compilación
Usa PlatformIO: `pio run`

## Notas
- Ajusta constantes PID según tu robot.
- Para cascada, envía `8 1` y ajusta MKp_L, etc.
- Optimizado para Arduino Nano ATmega328.
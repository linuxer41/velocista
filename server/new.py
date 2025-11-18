#!/usr/bin/env python3
"""
Script Python para comunicación con Arduino optimizado
Maneja serialización/deserialización binaria y WebSocket para interfaz web
Soporta comunicación Serial y Bluetooth
"""

import serial
import struct
import json
import threading
import time
from typing import Dict, Any
from flask import Flask, jsonify, render_template
from flask_socketio import SocketIO, emit


try:
    import bluetooth
    BLUETOOTH_AVAILABLE = True
except ImportError:
    BLUETOOTH_AVAILABLE = False
    print("Bluetooth no disponible - instalar: pip install pybluez")

app = Flask(__name__)
socketio = SocketIO(app)

# Definiciones de tipos de mensaje (igual que en models.h)
MSG_SYSTEM = 0
MSG_SENSOR_DATA = 1
MSG_ODOMETRY = 2
MSG_STATE = 3
MSG_MODE_CHANGE = 4
MSG_PID_TUNING = 5
MSG_COMPETITION = 6
MSG_REMOTE_STATUS = 7
MSG_COMMAND_ACK = 8

# Comandos
CMD_SET_PID = 0
CMD_SET_SPEED = 1
CMD_SET_MODE = 2
CMD_CALIBRATE = 3
CMD_START = 4
CMD_STOP = 5
CMD_GET_STATUS = 6

class ArduinoCommunicator:
    def __init__(self, device='/dev/ttyUSB0', connection_mode='serial', baudrate=115200):
        self.device = device
        self.connection_mode = connection_mode  # 'serial' or 'bluetooth'
        self.baudrate = baudrate
        self.serial_conn = None
        self.running = False

    def connect_device(self):
        """Conectar al dispositivo Arduino (Serial o Bluetooth)"""
        try:
            if self.connection_mode == 'serial':
                self.serial_conn = serial.Serial(self.device, self.baudrate, timeout=1)
                print(f"Conectado a {self.device} via Serial a {self.baudrate} baud")
            elif self.connection_mode == 'bluetooth':
                if not BLUETOOTH_AVAILABLE:
                    print("Bluetooth no disponible")
                    return False
                self.serial_conn = bluetooth.BluetoothSocket(bluetooth.RFCOMM)
                self.serial_conn.connect((self.device, 1))  # Puerto 1 para SPP
                print(f"Conectado a {self.device} via Bluetooth")
            else:
                print(f"Modo de conexión desconocido: {self.connection_mode}")
                return False
            return True
        except Exception as e:
            print(f"Error conectando a {self.device}: {e}")
            return False

    def deserialize_message(self, data: bytes) -> Dict[str, Any]:
        """Deserializar mensaje binario del Arduino"""
        if len(data) < 1:
            return None

        msg_type = data[0]

        try:
            if msg_type == MSG_SYSTEM:
                # SystemMessage: type(1), message(64)
                message = data[1:65].decode('utf-8', errors='ignore').rstrip('\x00')
                return {"type": "system", "message": message}

            elif msg_type == MSG_SENSOR_DATA:
                # SensorDataMessage: type(1), timestamp(4), sensors[6](12), error(2), sum(2)
                timestamp, *sensors, error, sensor_sum = struct.unpack('<L6hl', data[1:25])
                return {
                    "type": "sensor_data",
                    "timestamp": timestamp,
                    "sensors": sensors,
                    "error": error,
                    "sum": sensor_sum
                }

            elif msg_type == MSG_ODOMETRY:
                # OdometryMessage: type(1), timestamp(4), x(4), y(4), theta(4)
                timestamp, x, y, theta = struct.unpack('<Lfff', data[1:21])
                return {
                    "type": "odometry",
                    "timestamp": timestamp,
                    "x": x,
                    "y": y,
                    "theta": theta
                }

            elif msg_type == MSG_STATE:
                # StateMessage: type(1), timestamp(4), state(1), distance(4)
                timestamp, state, distance = struct.unpack('<LBf', data[1:10])
                return {
                    "type": "state",
                    "timestamp": timestamp,
                    "state": state,
                    "distance": distance
                }

            elif msg_type == MSG_MODE_CHANGE:
                # ModeChangeMessage: type(1), oldMode(1), newMode(1), serialEnabled(1)
                old_mode, new_mode, serial_enabled = struct.unpack('<BBB', data[1:4])
                return {
                    "type": "mode_change",
                    "old_mode": old_mode,
                    "new_mode": new_mode,
                    "serial_enabled": serial_enabled
                }

            elif msg_type == MSG_PID_TUNING:
                # PidTuningMessage: type(1), kp(4), ki(4), kd(4), integral(4)
                kp, ki, kd, integral = struct.unpack('<ffff', data[1:17])
                return {
                    "type": "pid_tuning",
                    "kp": kp,
                    "ki": ki,
                    "kd": kd,
                    "integral": integral
                }

            elif msg_type == MSG_COMPETITION:
                # CompetitionMessage: type(1), mode(1), time(4), lapCount(1)
                mode, comp_time, lap_count = struct.unpack('<BLB', data[1:7])
                return {
                    "type": "competition",
                    "mode": mode,
                    "time": comp_time,
                    "lap_count": lap_count
                }

            elif msg_type == MSG_REMOTE_STATUS:
                # RemoteStatusMessage: type(1), connected(1), leftSpeed(2), rightSpeed(2)
                connected, left_speed, right_speed = struct.unpack('<Bhh', data[1:6])
                return {
                    "type": "remote_status",
                    "connected": bool(connected),
                    "left_speed": left_speed,
                    "right_speed": right_speed
                }

            elif msg_type == MSG_COMMAND_ACK:
                # CommandAck: type(1), commandType(1)
                command_type = data[1]
                return {
                    "type": "command_ack",
                    "command_type": command_type
                }

        except struct.error as e:
            print(f"Error deserializando mensaje tipo {msg_type}: {e}")
            return None

        return None

    def serialize_command(self, command: Dict[str, Any]) -> bytes:
        """Serializar comando JSON a binario para Arduino"""
        cmd_type = command.get("type")

        if cmd_type == "set_pid":
            # SetPidCommand: type(1), kp(4), ki(4), kd(4)
            kp = command.get("kp", 0.0)
            ki = command.get("ki", 0.0)
            kd = command.get("kd", 0.0)
            return struct.pack('<Bfff', CMD_SET_PID, kp, ki, kd)

        elif cmd_type == "set_speed":
            # SetSpeedCommand: type(1), speed(2)
            speed = command.get("speed", 0)
            return struct.pack('<Bh', CMD_SET_SPEED, speed)

        elif cmd_type == "set_mode":
            # SetModeCommand: type(1), mode(1)
            mode = command.get("mode", 0)
            return struct.pack('<BB', CMD_SET_MODE, mode)

        elif cmd_type == "calibrate":
            # CalibrateCommand: type(1)
            return struct.pack('<B', CMD_CALIBRATE)

        elif cmd_type == "start":
            return struct.pack('<B', CMD_START)

        elif cmd_type == "stop":
            return struct.pack('<B', CMD_STOP)

        elif cmd_type == "get_status":
            return struct.pack('<B', CMD_GET_STATUS)

        return b''

    def serial_reader(self):
        """Hilo para leer del puerto serial"""
        buffer = b''
        while self.running:
            if self.serial_conn and self.serial_conn.in_waiting:
                try:
                    data = self.serial_conn.read(self.serial_conn.in_waiting)
                    buffer += data

                    # Procesar mensajes completos
                    while len(buffer) >= 1:
                        msg_type = buffer[0]
                        msg_data = None

                        # Determinar tamaño del mensaje basado en tipo
                        if msg_type == MSG_SYSTEM:
                            if len(buffer) >= 65:
                                msg_data = buffer[:65]
                                buffer = buffer[65:]
                        elif msg_type == MSG_SENSOR_DATA:
                            if len(buffer) >= 25:
                                msg_data = buffer[:25]
                                buffer = buffer[25:]
                        elif msg_type == MSG_ODOMETRY:
                            if len(buffer) >= 21:
                                msg_data = buffer[:21]
                                buffer = buffer[21:]
                        elif msg_type == MSG_STATE:
                            if len(buffer) >= 10:
                                msg_data = buffer[:10]
                                buffer = buffer[10:]
                        elif msg_type == MSG_MODE_CHANGE:
                            if len(buffer) >= 4:
                                msg_data = buffer[:4]
                                buffer = buffer[4:]
                        elif msg_type == MSG_PID_TUNING:
                            if len(buffer) >= 17:
                                msg_data = buffer[:17]
                                buffer = buffer[17:]
                        elif msg_type == MSG_COMPETITION:
                            if len(buffer) >= 7:
                                msg_data = buffer[:7]
                                buffer = buffer[7:]
                        elif msg_type == MSG_REMOTE_STATUS:
                            if len(buffer) >= 6:
                                msg_data = buffer[:6]
                                buffer = buffer[6:]
                        elif msg_type == MSG_COMMAND_ACK:
                            if len(buffer) >= 2:
                                msg_data = buffer[:2]
                                buffer = buffer[2:]
                        else:
                            # Tipo desconocido, descartar byte
                            buffer = buffer[1:]
                            continue

                        if msg_data:
                            message = self.deserialize_message(msg_data)
                            if message:
                                self.broadcast_message(message)
                        else:
                            break

                except Exception as e:
                    print(f"Error leyendo serial: {e}")
                    time.sleep(0.1)
            else:
                time.sleep(0.01)

    def broadcast_message(self, message):
        """Enviar mensaje a todos los clientes SocketIO"""
        socketio.emit('data', message)



    def get_serial_ports(self):
        """Obtener lista de puertos seriales disponibles"""
        import serial.tools.list_ports
        ports = serial.tools.list_ports.comports()
        return [{'port': p.device, 'desc': p.description} for p in ports]

    def get_bluetooth_devices(self):
        """Obtener lista de dispositivos Bluetooth disponibles"""
        if not BLUETOOTH_AVAILABLE:
            return []
        try:
            devices = bluetooth.discover_devices(duration=8, lookup_names=True)
            return [{'port': addr, 'desc': name} for addr, name in devices]
        except Exception as e:
            print(f"Error discovering Bluetooth devices: {e}")
            return []



@app.route('/')
def index():
    return render_template('index.html')

@app.route('/set_mode', methods=['POST'])
def set_mode():
    data = request.get_json()
    mode = data.get('mode')
    communicator.connection_mode = mode
    return jsonify({'status': 'ok'})

@app.route('/devices')
def get_devices():
    if communicator.connection_mode == 'serial':
        devices = communicator.get_serial_ports()
    elif communicator.connection_mode == 'bluetooth':
        devices = communicator.get_bluetooth_devices()
    else:
        devices = []
    return jsonify(devices)

@socketio.on('connect')
def handle_connect():
    print("Cliente SocketIO conectado")

@socketio.on('disconnect')
def handle_disconnect():
    print("Cliente SocketIO desconectado")

@socketio.on('connect_device')
def handle_connect_device(data):
    device = data.get('device')
    if device:
        communicator.device = device
        if communicator.connect_device():
            emit('connection_status', {"status": "connected"})
        else:
            emit('connection_status', {"status": "failed"})

@socketio.on('disconnect_serial')
def handle_disconnect_serial():
    communicator.running = False
    if communicator.serial_conn:
        communicator.serial_conn.close()
        communicator.serial_conn = None
    emit('connection_status', {"status": "disconnected"})

@socketio.on('cmd')
def handle_cmd(data):
    try:
        # Process command
        binary_command = communicator.serialize_command(data)
        if binary_command and communicator.serial_conn:
            communicator.serial_conn.write(binary_command)
            print(f"Comando enviado: {data}")
    except Exception as e:
        print(f"Error procesando comando: {e}")

if __name__ == "__main__":
    import sys

    # Argumentos: dispositivo, modo (opcional)
    device = sys.argv[1] if len(sys.argv) > 1 else '/dev/ttyUSB0'
    connection_mode = sys.argv[2] if len(sys.argv) > 2 else 'serial'

    if connection_mode not in ['serial', 'bluetooth']:
        print("Modo de conexión debe ser 'serial' o 'bluetooth'")
        sys.exit(1)

    print(f"Iniciando servidor Flask-SocketIO con {device} via {connection_mode}")

    communicator = ArduinoCommunicator(device=device, connection_mode=connection_mode)
    communicator.running = True
    reader_thread = threading.Thread(target=communicator.serial_reader, daemon=True)
    reader_thread.start()
    socketio.run(app, host='localhost', port=8080)
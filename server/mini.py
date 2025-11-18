from flask import Flask, render_template, request, jsonify
from flask_socketio import SocketIO
import serial
import serial.tools.list_ports
import time
import threading

app = Flask(__name__)
socketio = SocketIO(app)

# Serial connection
ser = None
connected = False
log_messages = []

def log(msg):
    t = time.strftime('%H:%M:%S')
    log_messages.append(f'[{t}] {msg}')
    if len(log_messages) > 100:
        log_messages.pop(0)
    socketio.emit('log', {'data': f'[{t}] {msg}'})

def reader():
    global ser, connected
    while connected and ser:
        try:
            line = ser.readline().decode().strip()
            if line:
                log(f'RX: {line}')
        except Exception as e:
            log(f'RX error: {e}')
            break

def connect_device(device):
    global ser, connected
    try:
        ser = serial.Serial(device, 115200, timeout=0.1)
        connected = True
        socketio.start_background_task(reader)
        log(f'Connected to {device}')
        return True
    except Exception as e:
        log(f'Failed to connect: {e}')
        return False

def disconnect():
    global ser, connected
    connected = False
    if ser:
        ser.close()
        ser = None
    log('Disconnected')

@app.route('/')
def index():
    return render_template('simple.html')

@app.route('/devices')
def devices():
    ports = serial.tools.list_ports.comports()
    return jsonify([{'port': p.device, 'desc': p.description} for p in ports])

@socketio.on('connect_device')
def handle_connect(data):
    device = data.get('device')
    if device:
        connect_device(device)

@socketio.on('disconnect_serial')
def handle_disconnect():
    disconnect()

@socketio.on('cmd')
def handle_cmd(data):
    if ser and connected:
        if 'pid' in data:
            kp, ki, kd = data['pid']
            speed = data.get('base_speed', 180)
            commands = [
                f"Kp {kp}",
                f"Ki {ki}",
                f"Kd {kd}",
                f"Speed {speed}"
            ]
            for cmd in commands:
                ser.write((cmd + '\n').encode())
                log(f'TX: {cmd}')
                time.sleep(0.1)
        elif 'calibrate' in data:
            ser.write(b"calibrate\n")
            log('TX: calibrate')
        elif 'telemetry' in data:
            ser.write(b"telemetry\n")
            log('TX: telemetry')
        else:
            log(f'Unknown cmd: {data}')
    else:
        log('Not connected')

if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=5001, debug=False)
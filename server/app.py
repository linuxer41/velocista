import serial, time, threading, json
from flask import Flask, render_template, jsonify, request
from flask_socketio import SocketIO, emit
import serial.tools.list_ports
try:
    import bluetooth
    BLUETOOTH_AVAILABLE = True
except ImportError:
    BLUETOOTH_AVAILABLE = False
    print("Bluetooth not available")

app = Flask(__name__)
socketio = SocketIO(app)

# ---------- CONFIG ----------
BAUD = 9600
connection_mode = 'serial'  # 'serial' or 'bluetooth'
ser = None
running = False
reader_thread = None

# ---------- LOG ----------
def log(msg):
    t = time.strftime('%H:%M:%S')
    print(f'[{t}] {msg}')
    socketio.emit('log', {'data': f'[{t}] {msg}'})

# ---------- CONNECTION ----------
def connect_device(device):
    global ser, running, reader_thread, connection_mode
    try:
        if connection_mode == 'serial':
            ser = serial.Serial(device, BAUD, timeout=0.1)
        elif connection_mode == 'bluetooth':
            if not BLUETOOTH_AVAILABLE:
                log('Bluetooth not available')
                return False
            ser = bluetooth.BluetoothSocket(bluetooth.RFCOMM)
            ser.connect((device, 1))  # Assuming port 1 for SPP
        else:
            log('Unknown connection mode')
            return False
        running = True
        reader_thread = threading.Thread(target=reader, daemon=True)
        reader_thread.start()
        log(f'Connected to {device} via {connection_mode}')
        return True
    except Exception as e:
        log(f'Failed to connect to {device}: {e}')
        return False

def disconnect_serial():
    global ser, running, reader_thread
    running = False
    if ser:
        ser.close()
        ser = None
    if reader_thread:
        reader_thread.join(timeout=1)
    log('Disconnected')

def get_ports():
    ports = serial.tools.list_ports.comports()
    return [{'port': p.device, 'desc': p.description} for p in ports]

def get_bluetooth_devices():
    if not BLUETOOTH_AVAILABLE:
        return []
    try:
        devices = bluetooth.discover_devices(duration=8, lookup_names=True)
        return [{'port': addr, 'desc': name} for addr, name in devices]
    except Exception as e:
        log(f'Bluetooth discovery error: {e}')
        return []

# ---------- LECTURA SERIE ----------
def reader():
    while running and ser:
        try:
            line = ser.readline().decode().strip()
            if not line: continue
            data = json.loads(line)
            if data.get('type') == 'telemetry':
                log(f'JSON: {line}')
                socketio.emit('telemetry', data['payload'])
            elif data.get('type') == 'cmd':
                log(f'RX CMD: {data["payload"]["buffer"]}')
        except json.JSONDecodeError:
            log(f'RX RAW: {line}')
        except Exception as e:
            log(f'RX error: {e}')

# ---------- ENVÍO ----------
def send_json(obj):
    if not ser:
        log('Not connected')
        return
    txt = json.dumps(obj)
    ser.write((txt + '\n').encode())
    log(f'TX  {txt}')

# ---------- RUTAS ----------
@app.route('/')
def index():
    return render_template('index.html')

@app.route('/devices')
def devices():
    if connection_mode == 'serial':
        return jsonify(get_ports())
    elif connection_mode == 'bluetooth':
        return jsonify(get_bluetooth_devices())
    else:
        return jsonify([])

@app.route('/set_mode', methods=['POST'])
def set_mode():
    global connection_mode
    data = request.get_json()
    mode = data.get('mode')
    if mode in ['serial', 'bluetooth']:
        connection_mode = mode
        log(f'Connection mode set to {mode}')
        return jsonify({'status': 'ok'})
    return jsonify({'status': 'error', 'message': 'Invalid mode'})

@socketio.on('connect_device')
def handle_connect(data):
    device = data.get('device')
    if device:
        connect_device(device)

@socketio.on('disconnect_serial')
def handle_disconnect():
    disconnect_serial()

@socketio.on('cmd')
def handle_cmd(data):
    send_json(data)

# ---------- MAIN ----------
if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=5000, debug=False)
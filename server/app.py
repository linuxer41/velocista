import serial, time, threading, json
from flask import Flask, render_template, jsonify
from flask_socketio import SocketIO, emit
import serial.tools.list_ports

app = Flask(__name__)
socketio = SocketIO(app)

# ---------- CONFIG ----------
BAUD = 9600
ser = None
running = False
reader_thread = None

# ---------- LOG ----------
def log(msg):
    t = time.strftime('%H:%M:%S')
    print(f'[{t}] {msg}')
    socketio.emit('log', {'data': f'[{t}] {msg}'})

# ---------- CONNECTION ----------
def connect_serial(port):
    global ser, running, reader_thread
    try:
        ser = serial.Serial(port, BAUD, timeout=0.1)
        running = True
        reader_thread = threading.Thread(target=reader, daemon=True)
        reader_thread.start()
        log(f'Connected to {port}')
        return True
    except Exception as e:
        log(f'Failed to connect to {port}: {e}')
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

@app.route('/ports')
def ports():
    return jsonify(get_ports())

@socketio.on('connect_serial')
def handle_connect(data):
    port = data.get('port')
    if port:
        connect_serial(port)

@socketio.on('disconnect_serial')
def handle_disconnect():
    disconnect_serial()

@socketio.on('cmd')
def handle_cmd(data):
    send_json(data)

# ---------- MAIN ----------
if __name__ == '__main__':
    socketio.run(app, host='0.0.0.0', port=5000, debug=False)
from flask import Flask, render_template, send_file
from flask_socketio import SocketIO, emit
import serial
import serial.tools.list_ports
import threading
import time
import csv
import os
import matplotlib
matplotlib.use('Agg')  # Usar backend no interactivo
import matplotlib.pyplot as plt
import numpy as np

app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*")

ser = None
serial_thread = None
running = False

saving_data = False
csv_file = None
writer = None

def serial_reader():
    global running, saving_data, writer
    while running:
        if ser and ser.is_open:
            try:
                line = ser.readline().decode('utf-8').strip()
                if line and ',' in line:
                    parts = line.split(',')
                    if len(parts) == 7:
                        data = {
                            'time': float(parts[0]),
                            'pos': float(parts[1]),
                            'rpmL': float(parts[2]),
                            'rpmR': float(parts[3]),
                            'lineOut': float(parts[4]),
                            'pwmL': float(parts[5]),
                            'pwmR': float(parts[6])
                        }
                        socketio.emit('data', data)  # Enviar datos a través de SocketIO
                        if saving_data and writer:
                            writer.writerow([data['time'], data['pos'], data['rpmL'], data['rpmR'], data['lineOut'], data['pwmL'], data['pwmR']])  # Guardar en CSV
            except:
                pass
        time.sleep(0.01)

@app.route('/')
def index():
    return render_template('index.html')

@socketio.on('connect_serial')
def handle_connect_serial(data):
    global ser, serial_thread, running
    port = data['port']
    try:
        ser = serial.Serial(port, 115200, timeout=1)
        running = True
        serial_thread = threading.Thread(target=serial_reader)
        serial_thread.start()
        emit('status', {'message': f'Connected to {port}'})
    except Exception as e:
        emit('status', {'message': f'Error: {str(e)}'})

@socketio.on('disconnect_serial')
def handle_disconnect_serial():
    global ser, running
    running = False
    if ser:
        ser.close()
    emit('status', {'message': 'Disconnected'})

@socketio.on('send_command')
def handle_send_command(data):
    global saving_data, csv_file, writer
    cmd = data['cmd']
    value = data['value']
    if ser and ser.is_open:
        ser.write(f"{cmd} {value}\n".encode())
        emit('status', {'message': f'Enviado: {cmd} {value}'})  # Emitir mensaje de estado
        if cmd == 7:  # debug
            if value == 1:
                saving_data = True
                csv_file = open('data.csv', 'w', newline='')
                writer = csv.writer(csv_file)
                writer.writerow(['time', 'pos', 'rpmL', 'rpmR', 'lineOut', 'pwmL', 'pwmR'])  # Escribir encabezados del CSV
            else:
                saving_data = False
                if csv_file:
                    csv_file.close()
                    csv_file = None
                writer = None

@socketio.on('set_pid')
def handle_set_pid(data):
    pid_type = data['type']  # 'line', 'left', 'right'
    kp = data['kp']
    ki = data['ki']
    kd = data['kd']
    if pid_type == 'line':
        cmd = 4  # SET_LINE_PID
    elif pid_type == 'left':
        cmd = 6  # SET_LEFT_PID
    elif pid_type == 'right':
        cmd = 5  # SET_RIGHT_PID
    if ser and ser.is_open:
        ser.write(f"{cmd} {kp} {ki} {kd}\n".encode())
        emit('status', {'message': f'Set {pid_type} PID: {kp},{ki},{kd}'})

@socketio.on('get_ports')
def handle_get_ports():
    ports = [port.device for port in serial.tools.list_ports.comports()]
    emit('ports', ports)

@socketio.on('generate_plots')
def handle_generate_plots():
    if os.path.exists('data.csv'):
        try:
            data = np.loadtxt('data.csv', delimiter=',', skiprows=1)
            if data.size == 0:
                emit('status', {'message': 'No hay datos para graficar'})
                return
            time = data[:,0]
            pos = data[:,1]
            rpmL = data[:,2]
            rpmR = data[:,3]
            lineOut = data[:,4]
            pwmL = data[:,5]
            pwmR = data[:,6]

            plt.figure(figsize=(12,8))
            plt.subplot(2,2,1)
            plt.plot(time, pos)
            plt.title('Respuesta Escalón de Posición de Línea')
            plt.xlabel('Tiempo (us)')
            plt.ylabel('Posición')

            plt.subplot(2,2,2)
            plt.plot(time, rpmL, label='RPM Izquierda')
            plt.plot(time, rpmR, label='RPM Derecha')
            plt.title('Respuesta Escalón de RPM')
            plt.xlabel('Tiempo (us)')
            plt.ylabel('RPM')
            plt.legend()

            plt.subplot(2,2,3)
            plt.plot(time, pwmL, label='PWM Izquierda')
            plt.plot(time, pwmR, label='PWM Derecha')
            plt.title('Entrada PWM')
            plt.xlabel('Tiempo (us)')
            plt.ylabel('PWM')
            plt.legend()

            plt.subplot(2,2,4)
            plt.plot(time, lineOut)
            plt.title('Salida de Línea')
            plt.xlabel('Tiempo (us)')
            plt.ylabel('Salida')

            plt.tight_layout()
            plt.savefig('plots.png')
            emit('plots_ready')
        except Exception as e:
            emit('status', {'message': f'Error generando gráficos: {str(e)}'})
    else:
        emit('status', {'message': 'No se encontró archivo de datos'})

@app.route('/plots')
def show_plots():
    return '''
    <html>
    <head><title>System Analysis Plots</title></head>
    <body>
    <h1>System Analysis Plots</h1>
    <img src="/plots.png" alt="Plots" style="max-width:100%;">
    <br><a href="/">Back to Control</a>
    </body>
    </html>
    '''

@app.route('/plots.png')
def get_plot():
    return send_file('plots.png', mimetype='image/png')

if __name__ == '__main__':
    socketio.run(app, debug=True)
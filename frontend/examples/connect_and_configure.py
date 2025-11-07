"""Ejemplo: conectar al servidor IoT y configurar parámetros.

Asume que el dispositivo está en modo AP en 192.168.4.1 y escucha en el puerto 80.
"""
import socket
import json
import time

SERVER_IP = '192.168.4.1'
SERVER_PORT = 80


def send_json(sock, obj):
    data = json.dumps(obj).encode('utf-8')
    try:
        sock.sendall(data)
    except Exception as e:
        print('Error enviando datos:', e)


if __name__ == '__main__':
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.settimeout(5)
    try:
        print(f'Conectando a {SERVER_IP}:{SERVER_PORT}...')
        sock.connect((SERVER_IP, SERVER_PORT))
        print('Conectado.')

        # Establecer umbral LDR
        send_json(sock, {"ldrThreshold": 400})
        time.sleep(0.1)

        # Establecer tiempo de espera de movimiento (ms)
        send_json(sock, {"motionTimeoutMs": 45000})
        time.sleep(0.1)

        # Cambiar a modo manual y encender relé
        send_json(sock, {"modeAutomatic": False, "manualRelayState": True})
        time.sleep(0.1)

        # Solicitar estado actual
        send_json(sock, {"command": "getStatus"})
        # Leer respuesta (bloquea hasta recibir)
        resp = sock.recv(2048)
        if resp:
            try:
                status = json.loads(resp.decode('utf-8'))
                print('Estado:', json.dumps(status, indent=2))
            except Exception as e:
                print('Respuesta no JSON o error parseando:', e)

    except Exception as e:
        print('Error de conexión:', e)
    finally:
        try:
            sock.close()
        except:
            pass

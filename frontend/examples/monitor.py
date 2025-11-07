"""Ejemplo: monitor continuo del servidor IoT.

Recibe los JSON periódicos enviados por el servidor y los imprime.
Reconexion automática. Manejo básico de mensajes concatenados.
"""
import socket
import json
import time

SERVER_IP = '192.168.4.1'
SERVER_PORT = 80
RECV_BUF = 4096


def recv_loop(sock):
    buffer = b''
    while True:
        try:
            data = sock.recv(RECV_BUF)
            if not data:
                print('Conexión cerrada por el servidor')
                return
            buffer += data
            # Intentar extraer JSONs desde el buffer
            while True:
                try:
                    # Buscar final sencillo: intentar decodificar todo el buffer
                    text = buffer.decode('utf-8')
                    obj = json.loads(text)
                    print(f"PIR: {obj.get('pir')}, LDR: {obj.get('ldr')}, Relay: {obj.get('relay')}")
                    buffer = b''
                    break
                except json.JSONDecodeError:
                    # No hay JSON completo aún, esperar más datos
                    break
        except socket.timeout:
            continue
        except Exception as e:
            print('Error en receive:', e)
            return


if __name__ == '__main__':
    while True:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(3)
        try:
            print(f'Conectando a {SERVER_IP}:{SERVER_PORT}...')
            sock.connect((SERVER_IP, SERVER_PORT))
            print('Conectado. Esperando datos...')
            recv_loop(sock)
        except Exception as e:
            print('Error de conexión/lectura:', e)
        finally:
            try:
                sock.close()
            except:
                pass
        print('Reconectando en 2s...')
        time.sleep(2)

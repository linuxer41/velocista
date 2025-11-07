import socket
import struct

def main():
    # Crear un socket TCP/IP
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    # Conectar al servidor en la dirección y puerto especificados
    server_address = ('192.168.1.7', 80)
    s.connect(server_address)

    try:
        # Enviar el comando para configurar el índice y la frecuencia
        command = 0x01
        tab_index = 0x01  # Ejemplo de índice de tabulación
        frequency = 0x20  # Ejemplo de frecuencia en Hz

        # Empaquetar los datos en un formato binario
        data = struct.pack('BBB', command, tab_index, frequency)

        # Enviar los datos al servidor
        s.sendall(data)

        # Recibir y mostrar los datos binarios enviados por el servidor
        while True:
            data = s.recv(1024)
            if not data:
                break
            print(f"Received {len(data)} bytes: {data}")

    finally:
        # Cerrar el socket
        s.close()

if __name__ == "__main__":
    main()
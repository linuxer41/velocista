import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'serial_client.dart';
import 'arduino_data.dart';

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setDarkMode(bool isDark) {
    _isDarkMode = isDark;
    notifyListeners();
  }
}

class AppState extends ChangeNotifier {
  // Cliente unificado para Bluetooth y Serial
  late SerialClient _serialClient;

  // Estado de conexión con ValueNotifier
  final ValueNotifier<bool> isConnected = ValueNotifier(false);
  final ValueNotifier<BluetoothDevice?> connectedDevice = ValueNotifier(null);
  final ValueNotifier<String?> connectedSerialPort = ValueNotifier(null);
  final ValueNotifier<String> connectionStatus = ValueNotifier('Desconectado');
  final ValueNotifier<List<BluetoothDevice>> discoveredDevices =
      ValueNotifier([]);
  final ValueNotifier<List<String>> availableSerialPorts = ValueNotifier([]);
  final ValueNotifier<bool> isDiscovering = ValueNotifier(false);
  final ValueNotifier<bool> showDeviceList = ValueNotifier(false);

  // Configuración PID
  final ValueNotifier<ArduinoPIDConfig> pidConfig =
      ValueNotifier(ArduinoPIDConfig());

  // Modo de operación actual
  final ValueNotifier<OperationMode> currentMode =
      ValueNotifier(OperationMode.remoteControl);

  // Tema de la aplicación
  final ValueNotifier<bool> isDarkMode = ValueNotifier(false);

  // Datos de telemetría actuales
  final ValueNotifier<ArduinoData?> currentData = ValueNotifier(null);

  // Datos raw para terminal
  final ValueNotifier<List<String>> rawDataBuffer = ValueNotifier([]);
  final ValueNotifier<List<String>> sentCommandsBuffer = ValueNotifier([]);
  final ValueNotifier<List<String>> receivedDataBuffer = ValueNotifier([]);

  AppState() {
    _initializeSerialClient();
  }

  void _initializeSerialClient() {
    _serialClient = SerialClient(
      onDataReceived: _handleDataReceived,
      onStatusReceived: _handleStatusReceived,
      onCmdReceived: _handleCmdReceived,
      onError: _handleBluetoothError,
      onConnected: _handleConnected,
      onDisconnected: _handleDisconnected,
      onRawDataReceived: _handleRawDataReceived,
      onCommandSent: _handleSentCommand,
    );
  }



  // Actualizar configuración PID
  Future<void> updatePIDConfig(ArduinoPIDConfig newConfig) async {
    pidConfig.value = newConfig;
    notifyListeners();
  }

  // Cambiar modo de operación
  Future<void> changeOperationMode(OperationMode mode) async {
    currentMode.value = mode;
    notifyListeners();
  }

  // Cambiar tema
  void toggleTheme() {
    isDarkMode.value = !isDarkMode.value;
    notifyListeners();
  }

  void setDarkMode(bool isDark) {
    isDarkMode.value = isDark;
    notifyListeners();
  }

  // Iniciar descubrimiento de dispositivos
  Future<void> startDiscovery() async {
    if (isDiscovering.value) return;

    isDiscovering.value = true;
    discoveredDevices.value = [];
    availableSerialPorts.value = [];
    connectionStatus.value = 'Buscando dispositivos...';
    notifyListeners();

    try {
      if (Platform.isWindows) {
        // Serial ports discovery (Windows only)
        final ports = _serialClient.getAvailableSerialPorts();
        availableSerialPorts.value = ports;

        final totalDevices = availableSerialPorts.value.length;
        if (totalDevices > 0) {
          connectionStatus.value = 'Encontrados $totalDevices puertos serial';
        } else {
          connectionStatus.value = 'No se encontraron puertos serial';
        }
      } else {
        // Bluetooth discovery
        final devices = await _serialClient.startBluetoothDiscovery();
        discoveredDevices.value = devices;

        final totalDevices = devices.length;
        if (totalDevices > 0) {
          connectionStatus.value = 'Encontrados $totalDevices dispositivos';
        } else {
          connectionStatus.value = 'No se encontraron dispositivos';
        }
      }
    } catch (e) {
      connectionStatus.value = 'Error en descubrimiento: $e';
    } finally {
      isDiscovering.value = false;
      notifyListeners();
    }
  }

  // Conectar a dispositivo Bluetooth
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      connectionStatus.value = 'Conectando a ${device.name}...';
      connectedDevice.value = device;
      notifyListeners();

      await _serialClient.connectBluetooth(device);
    } catch (e) {
      connectionStatus.value = 'Error de conexión: $e';
      connectedDevice.value = null;
      notifyListeners();
    }
  }

  // Conectar a puerto serial (Windows)
  Future<void> connectToSerialPort(String portName) async {
    try {
      connectionStatus.value = 'Conectando a $portName...';
      connectedSerialPort.value = portName;
      notifyListeners();

      await _serialClient.connectSerial(portName);

      // Double-check connection state after successful connection
      if (_serialClient.isConnected) {
        isConnected.value = true;
        connectionStatus.value = 'Conectado a $portName';
        notifyListeners();
      }
    } catch (e) {
      connectionStatus.value = 'Error de conexión serial: $e';
      connectedSerialPort.value = null;
      isConnected.value = false;
      notifyListeners();
    }
  }

  // Desconectar
  Future<void> disconnect() async {
    if (!isConnected.value) return;

    connectionStatus.value = 'Desconectando...';
    notifyListeners();

    await _serialClient.disconnect();

    // Add a small delay to ensure port is fully released
    await Future.delayed(const Duration(milliseconds: 500));

    isConnected.value = false;
    connectedDevice.value = null;
    connectedSerialPort.value = null;
    connectionStatus.value = 'Desconectado';
    _handleDisconnected();
    notifyListeners();
  }

  // Limpiar dispositivos descubiertos
  void clearDiscoveredDevices() {
    discoveredDevices.value = [];
    notifyListeners();
  }

  // Enviar comando al Arduino
  Future<bool> sendCommand(Map<String, dynamic> command) async {
    if (!isConnected.value) {
      return false;
    }

    try {
      return await _serialClient.sendCommand(command);
    } catch (e) {
      return false;
    }
  }

  // Handlers de Bluetooth
  void _handleDataReceived(dynamic data) {
    // Solo manejar TelemetryData (nuevo formato)
    if (data is TelemetryData) {
      // Convertir TelemetryData a ArduinoData para compatibilidad con UI
      final arduinoData = ArduinoData(
        operationMode: data.mode,
        modeName: data.operationMode.displayName,
        leftEncoderSpeed: data.leftRpm * 0.1047, // Convert RPM to cm/s
        rightEncoderSpeed: data.rightRpm * 0.1047,
        leftEncoderCount: data.leftEncoder,
        rightEncoderCount: data.rightEncoder,
        totalDistance: data.distance,
        sensors: data.sensors,
        position: data.position,
        error: data.error,
        correction: data.correction,
      );
      currentData.value = arduinoData;
      notifyListeners();
    }
  }

  void _handleStatusReceived(StatusMessage status) {
    // Solo mantener el estado de conexión
  }

  void _handleCmdReceived(CmdMessage cmd) {
    // Cmd messages are handled through raw data buffer
  }

  void _handleBluetoothError(String error) {
    connectionStatus.value = 'Error: $error';
    notifyListeners();
  }

  void _handleConnected() {
    isConnected.value = true;
    connectionStatus.value = 'Conectado a ${connectedDevice.value?.name ?? 'Dispositivo'}';
    notifyListeners();
  }

  void _handleDisconnected() {
    isConnected.value = false;
    connectedDevice.value = null;
    connectionStatus.value = 'Desconectado';
    notifyListeners();
  }

  void _handleRawDataReceived(String rawData) {
    // Add to combined buffer
    final currentCombinedBuffer = List<String>.from(rawDataBuffer.value);
    currentCombinedBuffer.add(rawData);
    if (currentCombinedBuffer.length > 500) {
      currentCombinedBuffer.removeRange(0, currentCombinedBuffer.length - 500);
    }
    rawDataBuffer.value = currentCombinedBuffer;

    // Add to received buffer
    final currentReceivedBuffer = List<String>.from(receivedDataBuffer.value);
    currentReceivedBuffer.add(rawData);
    if (currentReceivedBuffer.length > 500) {
      currentReceivedBuffer.removeRange(0, currentReceivedBuffer.length - 500);
    }
    receivedDataBuffer.value = currentReceivedBuffer;
  }

  void _handleSentCommand(String commandData) {
    // Add to combined buffer
    final currentCombinedBuffer = List<String>.from(rawDataBuffer.value);
    currentCombinedBuffer.add(commandData);
    if (currentCombinedBuffer.length > 500) {
      currentCombinedBuffer.removeRange(0, currentCombinedBuffer.length - 500);
    }
    rawDataBuffer.value = currentCombinedBuffer;

    // Add to sent buffer
    final currentSentBuffer = List<String>.from(sentCommandsBuffer.value);
    currentSentBuffer.add(commandData);
    if (currentSentBuffer.length > 500) {
      currentSentBuffer.removeRange(0, currentSentBuffer.length - 500);
    }
    sentCommandsBuffer.value = currentSentBuffer;
  }

  // Getter for device name (supports both Bluetooth and Serial)
  String? get deviceName {
    if (connectedDevice.value != null) return connectedDevice.value!.name;
    if (connectedSerialPort.value != null) return connectedSerialPort.value;
    return null;
  }





  @override
  void dispose() {
    _serialClient.dispose();
    super.dispose();
  }
}

// InheritedWidget for accessing state
class AppInheritedWidget extends InheritedWidget {
  final AppState state;

  const AppInheritedWidget({
    super.key,
    required this.state,
    required super.child,
  });

  static AppState? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<AppInheritedWidget>()
        ?.state;
  }

  @override
  bool updateShouldNotify(AppInheritedWidget oldWidget) {
    return state != oldWidget.state;
  }
}

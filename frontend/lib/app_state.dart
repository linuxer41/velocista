import 'dart:async';
import 'package:flutter/material.dart';
import 'package:bluetooth_classic_multiplatform/bluetooth_classic_multiplatform.dart';
import 'serial_client.dart';
import 'arduino_data.dart';
import 'pages/terminal_page.dart';

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
  final ValueNotifier<String> connectionStatus = ValueNotifier('Desconectado');
  final ValueNotifier<List<BluetoothDevice>> discoveredDevices =
      ValueNotifier([]);
  final ValueNotifier<bool> isDiscovering = ValueNotifier(false);
  final ValueNotifier<bool> showDeviceList = ValueNotifier(false);

  // Configuración PID
  final ValueNotifier<ArduinoPIDConfig> pidConfig =
      ValueNotifier(ArduinoPIDConfig());

  // Modo de operación actual
  final ValueNotifier<OperationMode> currentMode =
      ValueNotifier(OperationMode.idle);

  // Tema de la aplicación
  final ValueNotifier<bool> isDarkMode = ValueNotifier(false);

  // Datos de telemetría actuales
  final ValueNotifier<ArduinoData?> currentData = ValueNotifier(null);

  // Datos raw para terminal
  final ValueNotifier<List<TerminalMessage>> rawDataBuffer = ValueNotifier([]);
  final ValueNotifier<List<TerminalMessage>> sentCommandsBuffer = ValueNotifier([]);
  final ValueNotifier<List<TerminalMessage>> receivedDataBuffer = ValueNotifier([]);

  // ACK notifications
  final ValueNotifier<String?> lastAck = ValueNotifier(null);

  AppState() {
    _initializeSerialClient();
  }

  void _initializeSerialClient() {
    _serialClient = SerialClient(
      onError: _handleBluetoothError,
      onConnected: _handleConnected,
      onDisconnected: _handleDisconnected,
      onDataReceived: _handleRawDataReceived,
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
    // Send command to Arduino
    await sendCommand(ModeChangeCommand(mode).toCommand());
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
    connectionStatus.value = 'Buscando dispositivos...';
    notifyListeners();

    try {
      // Bluetooth discovery
      final devices = await _serialClient.startBluetoothDiscovery();
      discoveredDevices.value = devices;

      final totalDevices = devices.length;
      if (totalDevices > 0) {
        connectionStatus.value = 'Encontrados $totalDevices dispositivos';
      } else {
        connectionStatus.value = 'No se encontraron dispositivos';
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


  // Desconectar
  Future<void> disconnect() async {
    if (!isConnected.value) return;

    connectionStatus.value = 'Desconectando...';
    notifyListeners();

    await _serialClient.disconnect();

    isConnected.value = false;
    connectedDevice.value = null;
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
  Future<bool> sendCommand(String command) async {
    if (!isConnected.value) {
      return false;
    }

    try {
      return await _serialClient.sendCommand(command);
    } catch (e) {
      return false;
    }
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
    // Parse the raw data and handle it
    final line = rawData.trim();
    if (line.isEmpty) return;

    // Add to combined buffer
    final currentCombinedBuffer = List<TerminalMessage>.from(rawDataBuffer.value);
    currentCombinedBuffer.add(TerminalMessage(line, MessageType.received));
    if (currentCombinedBuffer.length > 500) {
      currentCombinedBuffer.removeRange(0, currentCombinedBuffer.length - 500);
    }
    rawDataBuffer.value = currentCombinedBuffer;

    // Add to received buffer
    final currentReceivedBuffer = List<TerminalMessage>.from(receivedDataBuffer.value);
    currentReceivedBuffer.add(TerminalMessage(line, MessageType.received));
    if (currentReceivedBuffer.length > 500) {
      currentReceivedBuffer.removeRange(0, currentReceivedBuffer.length - 500);
    }
    receivedDataBuffer.value = currentReceivedBuffer;

    // Handle different message types
    if (line.startsWith('type:1|')) {
      // System message - just log, no ArduinoData update
      final message = line.substring(7);
      print('System message: $message');
      return;
    } else if (line.startsWith('type:3|')) {
      // Command acknowledgment - just log, no ArduinoData update
      final ack = line.substring(7);
      print('Command ack: $ack');
      lastAck.value = ack; // Notify listeners
      return;
    }

    // Parse data for UI updates (type:2, type:4, or legacy formats)
    try {
      // Try to parse as ArduinoData (handles all formats: typed messages, pipe-separated, JSON)
      final arduinoData = ArduinoData.fromJson(line);
      if (arduinoData != null) {
        currentData.value = arduinoData;
        notifyListeners();
      }
    } catch (e) {
      if (e.toString().contains('JsonUnsupportedObjectError') ||
          e.toString().contains('FormatException')) {
        print('Parse error: $e');
        print('Raw data: "$line"');
      }
    }
  }

  void _handleSentCommand(String commandData) {
    // Add to combined buffer
    final currentCombinedBuffer = List<TerminalMessage>.from(rawDataBuffer.value);
    currentCombinedBuffer.add(TerminalMessage(commandData, MessageType.sent));
    if (currentCombinedBuffer.length > 500) {
      currentCombinedBuffer.removeRange(0, currentCombinedBuffer.length - 500);
    }
    rawDataBuffer.value = currentCombinedBuffer;

    // Add to sent buffer
    final currentSentBuffer = List<TerminalMessage>.from(sentCommandsBuffer.value);
    currentSentBuffer.add(TerminalMessage(commandData, MessageType.sent));
    if (currentSentBuffer.length > 500) {
      currentSentBuffer.removeRange(0, currentSentBuffer.length - 500);
    }
    sentCommandsBuffer.value = currentSentBuffer;
  }

  // Getter for device name
  String? get deviceName {
    if (connectedDevice.value != null) return connectedDevice.value!.name;
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

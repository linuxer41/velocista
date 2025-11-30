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

  // Configuración PID izquierda y derecha
  final ValueNotifier<List<double>?> leftPid = ValueNotifier(null);
  final ValueNotifier<List<double>?> rightPid = ValueNotifier(null);

  // Configuración velocidad base
  final ValueNotifier<double?> baseSpeed = ValueNotifier(null);
  final ValueNotifier<double?> baseRpm = ValueNotifier(null);

  // Estados de toggles
  final ValueNotifier<bool> cascadeEnabled = ValueNotifier(true);
  final ValueNotifier<bool> telemetryEnabled = ValueNotifier(true);

  // Modo de operación actual
  final ValueNotifier<OperationMode> currentMode =
      ValueNotifier(OperationMode.idle);

  // Tema de la aplicación
  final ValueNotifier<bool> isDarkMode = ValueNotifier(false);

  // Datos separados por tipo
  final ValueNotifier<TelemetryData?> telemetryData = ValueNotifier(null);
  final ValueNotifier<DebugData?> debugData = ValueNotifier(null);

  // Datos raw para terminal (todos los tipos)
  final ValueNotifier<SerialData?> currentData = ValueNotifier(null);
  final ValueNotifier<List<TerminalMessage>> rawDataBuffer = ValueNotifier([]);
  final ValueNotifier<List<TerminalMessage>> sentCommandsBuffer =
      ValueNotifier([]);
  final ValueNotifier<List<TerminalMessage>> receivedDataBuffer =
      ValueNotifier([]);

  // Acceleration calculation
  final ValueNotifier<double> acceleration = ValueNotifier(0.0);
  TelemetryData? _previousTelemetryData;
  int _previousTime = 0;

  // Features data (6 filters: MED, MA, KAL, HYS, DZ, LP)
  final ValueNotifier<List<int>?> featConfig = ValueNotifier([1, 1, 1, 1, 1, 1]);

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

  void _handleConnected() async {
    isConnected.value = true;
    connectionStatus.value =
        'Conectado a ${connectedDevice.value?.name ?? 'Dispositivo'}';
    notifyListeners();
    // Send get config on successful connection
    await sendCommand(ConfigRequestCommand().toCommand());
  }

  void _handleDisconnected() {
    isConnected.value = false;
    connectedDevice.value = null;
    connectionStatus.value = 'Desconectado';
    notifyListeners();
  }

  void _handleRawDataReceived(String rawData) {
    // print("handleRawDataReceived: $rawData");
    // Parse the raw data and handle it
    final line = rawData.trim();
    if (line.isEmpty) return;

    // Add to combined buffer
    final currentCombinedBuffer =
        List<TerminalMessage>.from(rawDataBuffer.value);
    currentCombinedBuffer.add(TerminalMessage(line, MessageType.received));
    if (currentCombinedBuffer.length > 500) {
      currentCombinedBuffer.removeRange(0, currentCombinedBuffer.length - 500);
    }
    rawDataBuffer.value = currentCombinedBuffer;

    // Add to received buffer
    final currentReceivedBuffer =
        List<TerminalMessage>.from(receivedDataBuffer.value);
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
      // Command acknowledgment - log and try to parse as config
      final ack = line.substring(7);
      print('Command ack: $ack');
      lastAck.value = ack; // Notify listeners

      // Try to parse as config data
      try {
        final configData = ConfigData.fromSerial("type:3|$ack");
        if (configData != null) {
          // Update operation mode
          if (configData.mode != null) {
            currentMode.value = OperationMode.fromId(configData.mode!);
          }
          // Update PID configs
          if (configData.lineKPid != null && configData.lineKPid!.length >= 3) {
            pidConfig.value = ArduinoPIDConfig(
              kp: configData.lineKPid![0],
              ki: configData.lineKPid![1],
              kd: configData.lineKPid![2],
              setpoint: 2500.0, // Default
              baseSpeed: configData.base != null &&
                      configData.base!.length >= 2
                  ? configData.base![1] / 255.0
                  : 0.8,
            );
          }
          leftPid.value = configData.leftKPid;
          rightPid.value = configData.rightKPid;
          if (configData.base != null) {
            if (configData.base!.length >= 1) baseSpeed.value = configData.base![0];
            if (configData.base!.length >= 2) baseRpm.value = configData.base![1];
          }
          // Update toggle states
          if (configData.cascade != null) {
            cascadeEnabled.value = configData.cascade! == 1;
          }
          if (configData.cascade != null) cascadeEnabled.value = configData.cascade == 1;
          if (configData.telemetry != null) telemetryEnabled.value = configData.telemetry == 1;
          // Update features config
          if (configData.featConfig != null) {
            featConfig.value = List.from(configData.featConfig!);
          }
          // Set currentData to trigger UI updates
          currentData.value = configData;
        }
      } catch (e) {
        // Not config data, ignore
      }
      return;
    }

    try {
      // Try to parse as SerialData (handles all formats: typed messages, pipe-separated, serial)
      final serialData = SerialData.fromSerial(line);
      if (serialData != null) {
        // Set the appropriate ValueNotifier based on data type
        if (serialData is TelemetryData) {
          // Calculate acceleration from RPM changes
          if (_previousTelemetryData != null &&
              serialData.left != null &&
              _previousTelemetryData!.left != null) {
            final currentTime = DateTime.now().millisecondsSinceEpoch;
            final deltaTime = (currentTime - _previousTime) / 1000.0; // seconds
            if (deltaTime > 0) {
              // Convert RPM to m/s (approximation)
              final leftSpeedPrev = _previousTelemetryData!.left![0] *
                  0.036 /
                  3.6; // RPM to km/h to m/s
              final leftSpeedCurr = serialData.left![0] * 0.036 / 3.6;
              acceleration.value = (leftSpeedCurr - leftSpeedPrev) / deltaTime;
            }
          }
          _previousTelemetryData = serialData;
          _previousTime = DateTime.now().millisecondsSinceEpoch;
          telemetryData.value = serialData;
        } else if (serialData is DebugData) {
          debugData.value = serialData;
          // Also set telemetryData for home page to update with telemetry data
          final leftRpm = serialData.left != null && serialData.left!.isNotEmpty ? serialData.left![0] : 0.0;
          final rightRpm = serialData.right != null && serialData.right!.isNotEmpty ? serialData.right![0] : 0.0;
          final leftEncoderCount = serialData.left != null && serialData.left!.length > 3 ? serialData.left![3].toInt() : 0;
          final rightEncoderCount = serialData.right != null && serialData.right!.length > 3 ? serialData.right![3].toInt() : 0;
          telemetryData.value = TelemetryData(
            operationMode: serialData.mode ?? 0,
            modeName: (serialData.mode ?? 0) == 0
                ? 'IDLE'
                : (serialData.mode == 1 ? 'LINE FOLLOWING' : 'REMOTE CONTROL'),
            leftEncoderSpeed: leftRpm,
            rightEncoderSpeed: rightRpm,
            leftEncoderCount: leftEncoderCount,
            rightEncoderCount: rightEncoderCount,
            sensors: serialData.qtr ?? [],
            cascade: (serialData.cascade ?? 1) == 1,
            uptime: serialData.uptime ?? 0,
            line: serialData.line,
            left: serialData.left,
            right: serialData.right,
            pid: serialData.pid,
            speedCms: serialData.speedCms,
            batt: serialData.batt,
            loopUs: serialData.loopUs,
            freeMem: serialData.freeMem,
            featConfig: serialData.featConfig,
          );
          // Update features state if available
          if (serialData.featConfig != null) {
            featConfig.value = List.from(serialData.featConfig!);
          }
        } else if (serialData is ConfigData) {
          // Update PID config from received config data
          if (serialData.lineKPid != null && serialData.lineKPid!.length >= 3) {
            pidConfig.value = ArduinoPIDConfig(
              kp: serialData.lineKPid![0],
              ki: serialData.lineKPid![1],
              kd: serialData.lineKPid![2],
              setpoint: 2500.0, // Default
              baseSpeed: serialData.base != null &&
                      serialData.base!.length >= 2
                  ? serialData.base![1] / 255.0
                  : 0.8,
            );
          }
        }

        // Always update currentData for terminal
        currentData.value = serialData;
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
    final currentCombinedBuffer =
        List<TerminalMessage>.from(rawDataBuffer.value);
    currentCombinedBuffer.add(TerminalMessage(commandData, MessageType.sent));
    if (currentCombinedBuffer.length > 500) {
      currentCombinedBuffer.removeRange(0, currentCombinedBuffer.length - 500);
    }
    rawDataBuffer.value = currentCombinedBuffer;

    // Add to sent buffer
    final currentSentBuffer =
        List<TerminalMessage>.from(sentCommandsBuffer.value);
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

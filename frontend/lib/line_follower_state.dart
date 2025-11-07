import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'bluetooth_client.dart';
import 'arduino_data.dart';

class LineFollowerState extends ChangeNotifier {
  // Cliente Bluetooth
  late BluetoothClient _bluetoothClient;
  
  // Estado de conexión con ValueNotifier
  final ValueNotifier<bool> isConnected = ValueNotifier(false);
  final ValueNotifier<BluetoothDevice?> connectedDevice = ValueNotifier(null);
  final ValueNotifier<String> connectionStatus = ValueNotifier('Desconectado');
  final ValueNotifier<List<BluetoothDevice>> discoveredDevices = ValueNotifier([]);
  final ValueNotifier<bool> isDiscovering = ValueNotifier(false);
  
  // Estado de datos
  final ValueNotifier<ArduinoData?> currentData = ValueNotifier(null);
  final List<ArduinoData> _dataHistory = [];
  final int _maxHistorySize = 100;
  
  // Configuración PID
  final ValueNotifier<ArduinoPIDConfig> pidConfig = ValueNotifier(ArduinoPIDConfig());
  final ValueNotifier<bool> isConfigurationMode = ValueNotifier(false);
  
  // Estadísticas
  final ValueNotifier<DateTime?> connectionStartTime = ValueNotifier(null);
  final ValueNotifier<int> totalDataPackets = ValueNotifier(0);
  final ValueNotifier<double> averageResponseTime = ValueNotifier(0.0);
  final ValueNotifier<double> dataRate = ValueNotifier(0.0);
  final ValueNotifier<String> connectionDuration = ValueNotifier('0s');
  
  // Datos de terminal para monitoreo
  final List<String> _terminalMessages = [];
  final int _maxTerminalMessages = 200; // Increased to handle raw data
  final ValueNotifier<bool> showTerminal = ValueNotifier(false);
  final ValueNotifier<bool> showRawData = ValueNotifier(true); // Control raw data display
  
  // Timer for real-time updates
  Timer? _realtimeUpdateTimer;

  final ValueNotifier<OperationMode> currentMode = ValueNotifier(OperationMode.lineFollowing);

  LineFollowerState() {
    _initializeBluetoothClient();
    _startRealtimeUpdates();
  }

  void _initializeBluetoothClient() {
    _bluetoothClient = BluetoothClient(
      onDataReceived: _handleDataReceived,
      onError: _handleBluetoothError,
      onConnected: _handleConnected,
      onDisconnected: _handleDisconnected,
    );
  }

  void _startRealtimeUpdates() {
    // Update connection time and data rate every second
    _realtimeUpdateTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isConnectedValue) {
        connectionDuration.value = getConnectionDuration();
        dataRate.value = getDataRate();
        notifyListeners();
      }
    });
  }

  // Getters
List<ArduinoData> get dataHistory => List.unmodifiable(_dataHistory);
List<String> get terminalMessages => List.unmodifiable(_terminalMessages);

// Helper getters
bool get _isConnectedValue => isConnected.value;
bool get _isDiscoveringValue => isDiscovering.value;
String get _connectionStatusValue => connectionStatus.value;
List<BluetoothDevice> get _discoveredDevicesValue => discoveredDevices.value;
BluetoothDevice? get _connectedDeviceValue => connectedDevice.value;
ArduinoPIDConfig get _pidConfigValue => pidConfig.value;

// Expose reactive values for UI
double get currentDataRate => dataRate.value;
String get currentConnectionDuration => connectionDuration.value;

  // Manejar datos entrantes con throttling
  Timer? _updateTimer;
  static const Duration _updateThrottle = Duration(milliseconds: 33); // ~30 FPS
  
  void _handleDataReceived(ArduinoData data) {
    currentData.value = data;
    totalDataPackets.value = totalDataPackets.value + 1;
    
    // Agregar al historial (mantener últimos N elementos)
    _dataHistory.add(data);
    if (_dataHistory.length > _maxHistorySize) {
      _dataHistory.removeAt(0);
    }
    
    // Log ALL raw Bluetooth data to terminal in real-time
    _addRawDataToTerminal(data);
    
    // Throttle terminal updates to prevent overwhelming UI
    _throttledTerminalUpdate(data);
    
    // Throttle UI updates to prevent excessive rebuilds
    _throttledNotifyListeners();
  }
  
  void _addRawDataToTerminal(ArduinoData data) {
    // Only add raw data if enabled
    if (!showRawData.value) return;
    
    // Add mode-specific data
    if (data.isLineFollowingMode) {
      _addTerminalMessage('📊 LINE: Pos=${data.position?.toStringAsFixed(1) ?? 'N/A'}, Error=${data.error?.toStringAsFixed(1) ?? 'N/A'}, Corr=${data.correction?.toStringAsFixed(3) ?? 'N/A'}');
      _addTerminalMessage('🔧 LINE: L_Cmd=${data.leftSpeedCmd?.toStringAsFixed(3) ?? 'N/A'}, R_Cmd=${data.rightSpeedCmd?.toStringAsFixed(3) ?? 'N/A'}');
    } else if (data.isAutopilotMode) {
      _addTerminalMessage('🚗 AUTO: Throttle=${data.throttle?.toStringAsFixed(3) ?? 'N/A'}, Brake=${data.brake?.toStringAsFixed(3) ?? 'N/A'}, Turn=${data.turn?.toStringAsFixed(3) ?? 'N/A'}, Dir=${data.direction ?? 'N/A'}');
    } else if (data.isManualMode) {
      _addTerminalMessage('🎮 MANUAL: L_Speed=${data.leftSpeed?.toStringAsFixed(3) ?? 'N/A'}, R_Speed=${data.rightSpeed?.toStringAsFixed(3) ?? 'N/A'}, Max=${data.maxSpeed?.toStringAsFixed(3) ?? 'N/A'}');
    }
    
    _addTerminalMessage('🔧 ENC: L=${data.leftEncoderSpeed.toStringAsFixed(2)}cm/s, R=${data.rightEncoderSpeed.toStringAsFixed(2)}cm/s');
    _addTerminalMessage('📏 DIST: ${data.totalDistance.toStringAsFixed(1)}cm, L_Count=${data.leftEncoderCount}, R_Count=${data.rightEncoderCount}');
    
    // Add sensor data only in line following mode
    if (data.isLineFollowingMode) {
      final sensorString = data.sensors.map((s) => s.toString().padLeft(4, '0')).join(',');
      _addTerminalMessage('🎯 SENSORS: [$sensorString], Count=${data.sensorCount}, Line=${data.isLineDetected ? 'YES' : 'NO'}');
    } else {
      _addTerminalMessage('🎯 SENSORS: Disabled in ${data.mode.displayName} mode');
    }
    
    _addTerminalMessage('─' * 80); // Separator line
  }
  
  void _throttledTerminalUpdate(ArduinoData data) {
    // Only add terminal message every 500ms to reduce overhead
    final now = DateTime.now();
    if (_lastTerminalUpdate == null ||
        now.difference(_lastTerminalUpdate!).inMilliseconds > 500) {
      
      String statusMessage;
      if (data.isLineFollowingMode) {
        statusMessage = '📊 LINE: Pos=${data.position?.toStringAsFixed(1) ?? 'N/A'}, Error=${data.error?.toStringAsFixed(1) ?? 'N/A'}';
      } else if (data.isAutopilotMode) {
        statusMessage = '🚗 AUTO: Throttle=${data.throttle?.toStringAsFixed(2) ?? 'N/A'}, Turn=${data.turn?.toStringAsFixed(2) ?? 'N/A'}';
      } else if (data.isManualMode) {
        statusMessage = '🎮 MANUAL: L=${data.leftSpeed?.toStringAsFixed(2) ?? 'N/A'}, R=${data.rightSpeed?.toStringAsFixed(2) ?? 'N/A'}';
      } else {
        statusMessage = '❓ UNKNOWN: Mode ${data.operationMode}';
      }
      
      _addTerminalMessage(statusMessage);
      _lastTerminalUpdate = now;
    }
  }
  
  DateTime? _lastTerminalUpdate;
  
  void _throttledNotifyListeners() {
    _updateTimer?.cancel();
    _updateTimer = Timer(_updateThrottle, () {
      notifyListeners();
    });
  }

  // Manejar errores Bluetooth
  void _handleBluetoothError(String error) {
    connectionStatus.value = 'Error: $error';
    _addTerminalMessage('❌ Error: $error');
    notifyListeners();
  }

  // Manejar conexión establecida
  Future<void> _handleConnected() async {
    isConnected.value = true;
    connectionStartTime.value = DateTime.now();
    final deviceName = _connectedDeviceValue?.name ?? 'Dispositivo Desconocido';
    connectionStatus.value = 'Conectado a $deviceName';
    _addTerminalMessage('✅ Conectado a $deviceName');
    _addTerminalMessage('📡 Esperando datos del dispositivo...');
    
    notifyListeners();
  }

  // Manejar desconexión
  void _handleDisconnected() {
    isConnected.value = false;
    connectedDevice.value = null;
    connectionStatus.value = 'Desconectado';
    connectionStartTime.value = null;
    _addTerminalMessage('🔌 Desconectado');
    notifyListeners();
  }

  // Iniciar descubrimiento de dispositivos
  Future<void> startDiscovery() async {
    print('🔍 [STATE] StartDiscovery called');
    
    if (_isDiscoveringValue) {
      print('⚠️ [STATE] Discovery already in progress, skipping');
      return;
    }
    
    isDiscovering.value = true;
    discoveredDevices.value = [];
    connectionStatus.value = 'Buscando dispositivos...';
    _addTerminalMessage('🔍 Iniciando descubrimiento de dispositivos...');
    _addTerminalMessage('💡 Tip: Make sure your Arduino Bluetooth module is paired with this device');
    
    print('📱 [STATE] Discovery status: ${connectionStatus.value}');
    notifyListeners();

    try {
      print('🚀 [STATE] Calling _bluetoothClient.startDiscovery()...');
      final devices = await _bluetoothClient.startDiscovery();
      print('📋 [STATE] Discovery returned ${devices.length} devices');
      
      // CRITICAL: Update the device list and notify UI
      print('🔄 [STATE] Updating discovered devices list...');
      discoveredDevices.value = devices;
      print('📱 [STATE] Set discoveredDevices to ${devices.length} devices');
      
      if (devices.isEmpty) {
        connectionStatus.value = 'No se encontraron dispositivos';
        _addTerminalMessage('📱 No se encontraron dispositivos');
        _addTerminalMessage('🔍 DEBUG: Bluetooth client returned empty list');
        _addTerminalMessage('💡 Solution: 1) Enable Bluetooth on Android 2) Pair your Arduino 3) Try again');
        print('❌ [STATE] No devices found');
        
        // IMPORTANT: Always notify listeners even when no devices found
        print('🔔 [STATE] Notifying listeners - no devices found');
        notifyListeners();
      } else {
        connectionStatus.value = 'Encontrados ${devices.length} dispositivos';
        _addTerminalMessage('📱 Encontrados ${devices.length} dispositivos');
        for (int i = 0; i < devices.length; i++) {
          final device = devices[i];
          final deviceInfo = '${device.name ?? 'Unknown'} (${device.address})';
          _addTerminalMessage('   ${i+1}. $deviceInfo');
          print('📱 [STATE] Device $i: $deviceInfo');
        }
        print('✅ [STATE] Successfully found ${devices.length} devices');
        
        // CRITICAL: Always notify listeners when devices are found
        print('🔔 [STATE] Notifying listeners - devices found');
        print('📋 [STATE] Current discoveredDevices count: ${discoveredDevices.value.length}');
        print('📋 [STATE] Devices list: ${discoveredDevices.value.map((d) => d.name).toList()}');
        notifyListeners();
      }
    } catch (e, stackTrace) {
      connectionStatus.value = 'Descubrimiento fallido: $e';
      _addTerminalMessage('❌ Descubrimiento fallido: $e');
      _addTerminalMessage('🔍 DEBUG: Exception details: $e');
      _addTerminalMessage('💡 Troubleshooting: 1) Check Bluetooth is enabled 2) Grant location permission 3) Restart app');
      print('💥 [STATE] Discovery failed with error: $e');
      print('📋 [STATE] Stack trace: $stackTrace');
      
      // CRITICAL: Notify listeners even on error
      print('🔔 [STATE] Notifying listeners - discovery failed');
      notifyListeners();
    } finally {
      isDiscovering.value = false;
      _addTerminalMessage('🏁 [STATE] Discovery completed, setting isDiscovering = false');
      print('🏁 [STATE] Discovery finished, isDiscovering = false');
      print('🔔 [STATE] Notifying listeners - discovery finished');
      notifyListeners();
    }
  }

  // Conectar a dispositivo
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      connectionStatus.value = 'Conectando a ${device.name}...';
      _addTerminalMessage('🔗 Conectando a ${device.name}...');
      connectedDevice.value = device;
      notifyListeners();

      await _bluetoothClient.connectToDevice(device);
      
      // Configuration will be sent automatically in _handleConnected()
    } catch (e) {
      connectionStatus.value = 'Conexión fallida: $e';
      _addTerminalMessage('❌ Conexión fallida: $e');
      connectedDevice.value = null;
      notifyListeners();
    }
  }

  // Desconectar de dispositivo
  Future<void> disconnect() async {
    if (!_isConnectedValue) return;
    
    connectionStatus.value = 'Desconectando...';
    _addTerminalMessage('🔌 Desconectando...');
    notifyListeners();

    await _bluetoothClient.disconnect();
  }

  // Actualizar configuración PID
  Future<void> updatePIDConfig(ArduinoPIDConfig newConfig) async {
    pidConfig.value = newConfig;
    _addTerminalMessage('⚙️ PID actualizado: Kp=${newConfig.kp}, Ki=${newConfig.ki}, Kd=${newConfig.kd}');
    
    if (_isConnectedValue) {
      try {
        final success = await _bluetoothClient.sendConfiguration(newConfig);
        if (success) {
          _addTerminalMessage('✅ Configuración enviada exitosamente');
        } else {
          _addTerminalMessage('❌ Fallo al enviar configuración');
        }
      } catch (e) {
        _addTerminalMessage('❌ Error enviando configuración: $e');
      }
    } else {
      _addTerminalMessage('ℹ️ Configuración guardada (no conectado)');
    }
    
    notifyListeners();
  }

  // Enviar comando personalizado
  Future<bool> sendCommand(Map<String, dynamic> command) async {
    if (!_isConnectedValue) {
      _addTerminalMessage('❌ No conectado - no se puede enviar comando');
      return false;
    }

    try {
      final success = await _bluetoothClient.sendCommand(command);
      if (success) {
        _addTerminalMessage('📤 Comando enviado: ${command.toString()}');
      } else {
        _addTerminalMessage('❌ Fallo al enviar comando - dispositivo no responde');
      }
      return success;
    } catch (e) {
      _addTerminalMessage('❌ Fallo al enviar comando: $e');
      return false;
    }
  }

  // Solicitar estado de Arduino
  Future<void> requestStatus() async {
    final success = await sendCommand({'command': 'getStatus'});
    if (success) {
      _addTerminalMessage('📊 Solicitud de estado enviada');
    } else {
      _addTerminalMessage('❌ Fallo al solicitar estado');
    }
  }

  // Cambiar modo de operación
  Future<void> changeOperationMode(OperationMode mode) async {
    // Don't clear data, just update the mode for UI responsiveness
    final previousMode = currentMode.value;
    
    // Update mode immediately for UI responsiveness
    currentMode.value = mode;
    notifyListeners();
    
    final success = await sendCommand({'mode': mode.id});
    if (success) {
      _addTerminalMessage('🔄 Modo cambiado a: ${mode.displayName}');
      // Data will be updated when Arduino responds with new mode data
    } else {
      _addTerminalMessage('❌ Error al cambiar el modo de operación');
      // Restore previous mode if change failed
      currentMode.value = previousMode;
      notifyListeners();
    }
  }

  // Comandos de seguridad para autopilot
  Future<void> sendEmergencyStop() async {
    final success = await sendCommand({'emergencyStop': true});
    if (success) {
      _addTerminalMessage('🆘 PARADA DE EMERGENCIA ACTIVADA');
    } else {
      _addTerminalMessage('❌ Error al enviar parada de emergencia');
    }
  }

  Future<void> sendParkingBrake() async {
    final success = await sendCommand({'park': true});
    if (success) {
      _addTerminalMessage('🅿️ Freno de estacionamiento activado');
    } else {
      _addTerminalMessage('❌ Error al activar freno de estacionamiento');
    }
  }

  Future<void> sendStopCommand() async {
    final success = await sendCommand({'stop': true});
    if (success) {
      _addTerminalMessage('⏹️ Parada normal activada');
    } else {
      _addTerminalMessage('❌ Error al enviar comando de parada');
    }
  }

  // Limpiar historial de datos
  void clearDataHistory() {
    _dataHistory.clear();
    totalDataPackets.value = 0;
    _addTerminalMessage('🧹 Historial de datos limpiado');
    notifyListeners();
  }

  // Alternar visibilidad del terminal
  void toggleTerminal() {
    showTerminal.value = !showTerminal.value;
    notifyListeners();
  }

  // Limpiar mensajes del terminal
  void clearTerminal() {
    _terminalMessages.clear();
    notifyListeners();
  }

  // Alternar mostrar datos en bruto
  void toggleRawData() {
    showRawData.value = !showRawData.value;
    notifyListeners();
  }

  // Limpiar dispositivos descubiertos
  void clearDiscoveredDevices() {
    discoveredDevices.value = [];
    connectionStatus.value = 'Dispositivos limpiados';
    notifyListeners();
  }

  // Obtener ayuda para problemas de descubrimiento
  String getDiscoveryHelp() {
    return '''
📱 SOLUCIÓN: No aparecen dispositivos Bluetooth

1. ✅ Habilita Bluetooth en tu Android
2. 🔗 Empareja tu Arduino en Configuración > Bluetooth
   - Busca: HC-05, HC-06, ESP32, o nombre de tu módulo
   - Código PIN típico: 1234 o 0000
3. 🔄 Reinicia la app después del emparejamiento
4. 📍 Habilita permisos de ubicación si se solicitan
5. 🔍 Intenta el descubrimiento nuevamente

💡 La app solo muestra dispositivos ya emparejados
''';
  }

  // Agregar mensaje al terminal
  void _addTerminalMessage(String message) {
    final timestamp = DateTime.now().toString().substring(11, 19);
    final logMessage = '[$timestamp] $message';
    
    _terminalMessages.add(logMessage);
    if (_terminalMessages.length > _maxTerminalMessages) {
      _terminalMessages.removeAt(0);
    }
  }

  // Obtener duración de conexión
  String getConnectionDuration() {
    final startTime = connectionStartTime.value;
    if (startTime == null) return 'No conectado';
    
    final duration = DateTime.now().difference(startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  // Obtener tasa de datos (paquetes por segundo)
  double getDataRate() {
    final startTime = connectionStartTime.value;
    final packets = totalDataPackets.value;
    if (startTime == null || packets == 0) return 0.0;
    
    final duration = DateTime.now().difference(startTime);
    final durationInSeconds = duration.inMilliseconds / 1000.0;
    
    if (durationInSeconds <= 0) return 0.0;
    
    return packets / durationInSeconds;
  }

  // Obtener estadísticas de sensores
  Map<String, dynamic> getSensorStatistics() {
    if (_dataHistory.isEmpty) return {};
    
    final recentData = _dataHistory.take(20).toList(); // Últimas 20 lecturas
    
    // Only calculate statistics for line following mode data
    final lineFollowingData = recentData.where((d) => d.isLineFollowingMode).toList();
    
    final Map<String, dynamic> stats = {};
    
    if (lineFollowingData.isNotEmpty) {
      final positions = lineFollowingData.map((d) => d.position!).where((p) => p != null).toList();
      final errors = lineFollowingData.map((d) => d.error!).where((e) => e != null).toList();
      final leftSpeeds = lineFollowingData.map((d) => d.leftSpeedCmd!).where((s) => s != null).toList();
      final rightSpeeds = lineFollowingData.map((d) => d.rightSpeedCmd!).where((s) => s != null).toList();
      
      if (positions.isNotEmpty) {
        stats['position'] = {
          'min': positions.reduce((a, b) => a < b ? a : b),
          'max': positions.reduce((a, b) => a > b ? a : b),
          'avg': positions.reduce((a, b) => a + b) / positions.length,
        };
      }
      
      if (errors.isNotEmpty) {
        stats['error'] = {
          'min': errors.reduce((a, b) => a < b ? a : b),
          'max': errors.reduce((a, b) => a > b ? a : b),
          'avg': errors.reduce((a, b) => a + b) / errors.length,
        };
      }
      
      if (leftSpeeds.isNotEmpty) {
        stats['leftSpeed'] = {
          'min': leftSpeeds.reduce((a, b) => a < b ? a : b),
          'max': leftSpeeds.reduce((a, b) => a > b ? a : b),
          'avg': leftSpeeds.reduce((a, b) => a + b) / leftSpeeds.length,
        };
      }
      
      if (rightSpeeds.isNotEmpty) {
        stats['rightSpeed'] = {
          'min': rightSpeeds.reduce((a, b) => a < b ? a : b),
          'max': rightSpeeds.reduce((a, b) => a > b ? a : b),
          'avg': rightSpeeds.reduce((a, b) => a + b) / rightSpeeds.length,
        };
      }
    }
    
    return stats;
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _realtimeUpdateTimer?.cancel();
    _bluetoothClient.dispose();
    super.dispose();
  }
}

// InheritedWidget for accessing state
class LineFollowerInheritedWidget extends InheritedWidget {
  final LineFollowerState state;

  const LineFollowerInheritedWidget({
    super.key,
    required this.state,
    required super.child,
  });

  static LineFollowerState? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<LineFollowerInheritedWidget>()?.state;
  }

  @override
  bool updateShouldNotify(LineFollowerInheritedWidget oldWidget) {
    return state != oldWidget.state;
  }
}
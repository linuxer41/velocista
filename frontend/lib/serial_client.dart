import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'arduino_data.dart';

// Conditional import for Windows serial support
import 'package:serial_port_win32/serial_port_win32.dart';

/// Unified client for both Bluetooth and Serial communication
/// Provides the same interface for both connection types
class SerialClient {
  // Callbacks for data handling
  final Function(dynamic)? onDataReceived;
  final Function(StatusMessage)? onStatusReceived;
  final Function(CmdMessage)? onCmdReceived;
  final Function(String)? onError;
  final Function()? onConnected;
  final Function()? onDisconnected;
  final Function(String)? onRawDataReceived;
  final Function(String)? onCommandSent;

  // Connection state
  bool _isConnected = false;
  String _connectionStatus = 'Disconnected';
  String? _connectionType; // 'bluetooth' or 'serial'
  String? _connectionIdentifier; // device address or port name

  // Bluetooth components
  final FlutterBlueClassic _bluetooth;
  BluetoothConnection? _bluetoothConnection;
  StreamSubscription? _bluetoothDataSubscription;

  // Serial components (Windows only)
  SerialPort? _serialPort;
  Timer? _serialTimer;

  // Data handling
  String _jsonBuffer = '';

  SerialClient({
    this.onDataReceived,
    this.onStatusReceived,
    this.onCmdReceived,
    this.onError,
    this.onConnected,
    this.onDisconnected,
    this.onRawDataReceived,
    this.onCommandSent,
  }) : _bluetooth = FlutterBlueClassic(usesFineLocation: true);

  /// Get current connection status
  bool get isConnected => _isConnected;

  /// Get connection status string
  String get connectionStatus => _connectionStatus;

  /// Get connection type ('bluetooth' or 'serial')
  String? get connectionType => _connectionType;

  /// Start Bluetooth device discovery
  Future<List<BluetoothDevice>> startBluetoothDiscovery() async {
    print('🔍 [SERIAL_CLIENT] ===== STARTING BLUETOOTH DISCOVERY =====');

    try {
      // Check Bluetooth status first
      final isSupported = await _bluetooth.isSupported;
      final isEnabled = await _bluetooth.isEnabled;

      if (!isSupported) {
        throw Exception('Bluetooth not supported on this device');
      }

      if (!isEnabled) {
        throw Exception(
            'Bluetooth is disabled. Please enable it in system settings.');
      }

      // Get paired devices first
      final pairedDevicesResult = await _bluetooth.bondedDevices;
      final pairedDevices = pairedDevicesResult ?? [];

      // Start scanning for additional devices
      final scanResults = <BluetoothDevice>[];

      // Set up scan results listener
      final subscription = _bluetooth.scanResults.listen((device) {
        if (!scanResults.any((d) => d.address == device.address)) {
          scanResults.add(device);
        }
      });

      // Start scan
      _bluetooth.startScan();

      // Wait for scan to complete
      await Future.delayed(const Duration(seconds: 4));

      // Stop scanning
      _bluetooth.stopScan();
      subscription.cancel();

      // Add paired devices if not already in results
      for (final pairedDevice in pairedDevices) {
        if (!scanResults.any((d) => d.address == pairedDevice.address)) {
          scanResults.add(pairedDevice);
        }
      }

      print(
          '🔍 [SERIAL_CLIENT] ===== BLUETOOTH DISCOVERY COMPLETED ===== (${scanResults.length} devices)');
      return scanResults;
    } catch (e) {
      print('❌ [SERIAL_CLIENT] Bluetooth discovery failed: $e');
      rethrow;
    }
  }

  /// Get available serial ports (Windows only)
  List<String> getAvailableSerialPorts() {
    if (!Platform.isWindows) return [];
    return SerialPort.getAvailablePorts();
  }

  /// Connect via Bluetooth
  Future<void> connectBluetooth(BluetoothDevice device) async {
    if (_isConnected) {
      await disconnect();
    }

    try {
      _connectionStatus = 'Connecting to ${device.name ?? 'Unknown Device'}...';
      _connectionType = 'bluetooth';
      _connectionIdentifier = device.address;

      print(
          '🔗 [SERIAL_CLIENT] Connecting to Bluetooth device: ${device.name} (${device.address})');

      _bluetoothConnection = await _bluetooth.connect(device.address);

      if (_bluetoothConnection == null) {
        throw Exception('Failed to connect to device');
      }

      _isConnected = true;
      _connectionStatus = 'Connected to ${device.name ?? 'Unknown Device'}';
      _setupBluetoothDataListener();

      onConnected?.call();
      print('✅ [SERIAL_CLIENT] Bluetooth connection successful');
    } catch (e) {
      _isConnected = false;
      _connectionType = null;
      _connectionIdentifier = null;
      _connectionStatus = 'Connection failed: $e';
      print('❌ [SERIAL_CLIENT] Bluetooth connection failed: $e');
      onError?.call('Connection failed: $e');
      rethrow;
    }
  }

  /// Connect via Serial (Windows only)
  Future<void> connectSerial(String portName) async {
    if (!Platform.isWindows) {
      throw Exception('Serial connections are only supported on Windows');
    }

    // Always disconnect first to ensure clean state
    if (_isConnected || _serialPort != null) {
      print(
          '🔌 [SERIAL_CLIENT] Disconnecting existing connection before connecting to $portName');
      await disconnect();
      // Add a longer delay to ensure port is fully released
      await Future.delayed(const Duration(milliseconds: 1000));
    }

    try {
      _connectionStatus = 'Connecting to $portName...';
      _connectionType = 'serial';
      _connectionIdentifier = portName;

      print('🔗 [SERIAL_CLIENT] Connecting to serial port: $portName');

      // Create serial port instance
      _serialPort = SerialPort(portName, openNow: false, ByteSize: 8, BaudRate: 9600);

      _serialPort!.open();
      _isConnected = true;
      _connectionStatus = 'Connected to $portName';
      _setupSerialDataListener();

      onConnected?.call();
      print('✅ [SERIAL_CLIENT] Serial connection successful');
    } catch (e) {
      _isConnected = false;
      _connectionType = null;
      _connectionIdentifier = null;
      _connectionStatus = 'Serial connection failed: $e';
      print('❌ [SERIAL_CLIENT] Serial connection failed: $e');
      onError?.call('Serial connection failed: $e');
      rethrow;
    }
  }

  /// Send JSON command
  Future<bool> sendCommand(Map<String, dynamic> command) async {
    if (!_isConnected) {
      onError?.call('Not connected to device');
      return false;
    }

    try {
      final jsonString = jsonEncode(command) + '\n';
      final bytes = utf8.encode(jsonString);

      // Add sent command to terminal
      final now = DateTime.now();
      final timeString =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      onCommandSent?.call('[$timeString] -> $jsonString');

      if (_connectionType == 'bluetooth' && _bluetoothConnection != null) {
        _bluetoothConnection!.writeString(jsonString);
        print('📤 [SERIAL_CLIENT] Bluetooth command sent: $jsonString');
      } else if (_connectionType == 'serial' && _serialPort != null) {
        // Send data via serial using writeBytesFromString
        await _serialPort!.writeBytesFromString(jsonString,
            includeZeroTerminator: false,
            stringConverter: StringConverter.nativeUtf8);
        print('📤 [SERIAL_CLIENT] Serial command sent: $jsonString (${bytes.length} bytes)');
        return true;
      }

      return true;
    } catch (e) {
      onError?.call('Failed to send command: $e');
      print('❌ [SERIAL_CLIENT] Command send error: $e');
      return false;
    }
  }

  /// Disconnect from current connection
  Future<void> disconnect() async {
    print('🔌 [SERIAL_CLIENT] Starting disconnect process...');

    // Cancel subscriptions
    _bluetoothDataSubscription?.cancel();
    _serialTimer?.cancel();

    try {
      if (_connectionType == 'bluetooth' &&
          _bluetoothConnection != null &&
          _bluetoothConnection!.isConnected) {
        print('🔌 [SERIAL_CLIENT] Disconnecting Bluetooth...');
        await _bluetoothConnection!.finish();
        print('✅ [SERIAL_CLIENT] Bluetooth disconnect successful');
      } else if (_connectionType == 'serial' && _serialPort != null) {
        print('🔌 [SERIAL_CLIENT] Disconnecting Serial...');
        try {
          _serialPort!.close();
          print('✅ [SERIAL_CLIENT] Serial disconnect successful');
        } catch (e) {
          print('❌ [SERIAL_CLIENT] Serial close error: $e');
          // Force null even if close fails
        }
      }
    } catch (e) {
      print('❌ [SERIAL_CLIENT] Disconnect error: $e');
    }

    _isConnected = false;
    _connectionType = null;
    _connectionIdentifier = null;
    _bluetoothConnection = null;
    _serialPort = null;
    _jsonBuffer = '';
    _connectionStatus = 'Disconnected';
    onDisconnected?.call();
    print('🔌 [SERIAL_CLIENT] Disconnect completed');
  }

  /// Set up Bluetooth data listener
  void _setupBluetoothDataListener() {
    print('📡 [SERIAL_CLIENT] Setting up Bluetooth data listener...');

    if (_bluetoothConnection == null || _bluetoothConnection!.input == null) {
      print('❌ [SERIAL_CLIENT] Cannot set up Bluetooth data listener');
      return;
    }

    _bluetoothDataSubscription = _bluetoothConnection!.input!.listen(
      (data) {
        try {
          final message = utf8.decode(data);
          print('📡 [SERIAL_CLIENT] Bluetooth data received: "$message"');
          _jsonBuffer += message;
          _processJsonBuffer();
        } catch (e) {
          print('❌ [SERIAL_CLIENT] Bluetooth data handling error: $e');
          onError?.call('Data handling error: $e');
        }
      },
      onError: (error) {
        print('❌ [SERIAL_CLIENT] Bluetooth data stream error: $error');
        onError?.call('Data stream error: $error');
        disconnect();
      },
      onDone: () {
        print('🔌 [SERIAL_CLIENT] Bluetooth data stream ended');
        onDisconnected?.call();
        disconnect();
      },
    );

    print('✅ [SERIAL_CLIENT] Bluetooth data listener set up successfully');
  }

  /// Set up Serial data listener
  void _setupSerialDataListener() {
    print('📡 [SERIAL_CLIENT] Setting up Serial data listener...');

    if (_serialPort == null) {
      print('❌ [SERIAL_CLIENT] Cannot set up Serial data listener - port not available');
      return;
    }

    // Listen to serial data using polling approach
    _serialTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
      if (!_isConnected || _connectionType != 'serial') {
        timer.cancel();
        return;
      }

      try {
        // Read available data
        final data = await _serialPort!.readBytes(1024, timeout: const Duration(milliseconds: 10));
        if (data.isNotEmpty) {
          final message = utf8.decode(data);
          print('📡 [SERIAL_CLIENT] Serial data received: "$message"');
          _jsonBuffer += message;
          _processJsonBuffer();
        }
      } catch (e) {
        print('❌ [SERIAL_CLIENT] Serial data handling error: $e');
        onError?.call('Serial data handling error: $e');
      }
    });

    print('✅ [SERIAL_CLIENT] Serial data listener set up successfully');
  }

  /// Process JSON buffer for complete messages
  void _processJsonBuffer() {
    // Find complete JSON objects in the buffer
    int braceCount = 0;
    int startIndex = 0;
    bool inString = false;
    bool escaped = false;

    for (int i = 0; i < _jsonBuffer.length; i++) {
      final char = _jsonBuffer[i];

      if (escaped) {
        escaped = false;
        continue;
      }

      if (char == '\\') {
        escaped = true;
        continue;
      }

      if (char == '"' && !escaped) {
        inString = !inString;
        continue;
      }

      if (!inString) {
        if (char == '{') {
          if (braceCount == 0) {
            startIndex = i;
          }
          braceCount++;
        } else if (char == '}') {
          braceCount--;
          if (braceCount == 0) {
            // Found complete JSON object
            final jsonString = _jsonBuffer.substring(startIndex, i + 1);
            _processCompleteJsonObject(jsonString);

            // Remove processed part from buffer
            _jsonBuffer = _jsonBuffer.substring(i + 1);
            i = -1; // Reset loop
            braceCount = 0;
            inString = false;
            escaped = false;
          }
        }
      }
    }
  }

  /// Process a complete JSON object
  void _processCompleteJsonObject(String jsonString) {
    final line = jsonString.trim();
    if (line.isEmpty) return;

    print('🔄 [SERIAL_CLIENT] Processing JSON: "$line"');

    // Send complete JSON object to terminal
    final now = DateTime.now();
    final timeString =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
    onRawDataReceived?.call('[$timeString] <- $line');

    // Try to parse as ArduinoMessage wrapper
    final message = ArduinoMessage.fromJson(line);
    if (message != null) {
      print('✅ [SERIAL_CLIENT] Parsed as ArduinoMessage: ${message.type}');
      if (message.isTelemetry) {
        final telemetryData = TelemetryData.fromPayload(message.payload);
        if (telemetryData != null) {
          onDataReceived?.call(telemetryData);
        }
      } else if (message.isStatus) {
        final statusMessage = StatusMessage.fromPayload(message.payload);
        if (statusMessage != null) {
          onStatusReceived?.call(statusMessage);
        }
      } else if (message.isCmd) {
        final cmdMessage = CmdMessage.fromPayload(message.payload);
        if (cmdMessage != null) {
          onCmdReceived?.call(cmdMessage);
        }
      }
      return;
    }

    // Fallback: try to parse as legacy ArduinoData
    try {
      final parsedData = ArduinoData.fromJson(line);
      onDataReceived?.call(parsedData);
      print('✅ [SERIAL_CLIENT] Parsed as legacy ArduinoData');
    } catch (e) {
      if (e.toString().contains('JsonUnsupportedObjectError') ||
          e.toString().contains('FormatException')) {
        print('❌ [SERIAL_CLIENT] JSON parse error: $e');
        print('❌ [SERIAL_CLIENT] Raw JSON: "$line"');
      }
    }
  }

  void dispose() {
    _bluetoothDataSubscription?.cancel();
    _serialTimer?.cancel();
    disconnect();
  }
}

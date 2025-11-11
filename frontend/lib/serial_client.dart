import 'dart:async';
import 'dart:convert';
import 'package:bluetooth_classic_multiplatform/bluetooth_classic_multiplatform.dart';
import 'arduino_data.dart';

/// Bluetooth client for communication
/// Provides interface for Bluetooth connection
class SerialClient {
  // Callbacks for data handling
  final Function(String)? onError;
  final Function()? onConnected;
  final Function()? onDisconnected;
  final Function(String)? onDataReceived;
  final Function(String)? onCommandSent;

  // Connection state
  bool _isConnected = false;
  String _connectionStatus = 'Disconnected';
  String? _connectionType; // 'bluetooth'
  String? _connectionIdentifier; // device address

  // Bluetooth components
  final BluetoothClassicMultiplatform _bluetooth;
  BluetoothConnection? _bluetoothConnection;
  StreamSubscription? _bluetoothDataSubscription;

  // Data handling
  String _lineBuffer = '';

  SerialClient({
    this.onError,
    this.onConnected,
    this.onDisconnected,
    this.onDataReceived,
    this.onCommandSent,
  }) : _bluetooth = BluetoothClassicMultiplatform();

  /// Get current connection status
  bool get isConnected => _isConnected;

  /// Get connection status string
  String get connectionStatus => _connectionStatus;

  /// Get connection type ('bluetooth' or 'serial')
  String? get connectionType => _connectionType;

  /// Start Bluetooth device discovery
  Future<List<BluetoothDevice>> startBluetoothDiscovery() async {
    print('Starting Bluetooth discovery');

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

      print('Bluetooth discovery completed (${scanResults.length} devices)');
      return scanResults;
    } catch (e) {
      print('Bluetooth discovery failed: $e');
      rethrow;
    }
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

      print('Connecting to Bluetooth device: ${device.name} (${device.address})');

      // Connect to the device
      // Note: The library has inconsistent return types across platforms
      // On Android it returns BluetoothConnection, on Windows it may return bool when failed
      dynamic connectionResult;
      try {
        connectionResult = await _bluetooth.connect(device.address);
      } catch (e) {
        // Handle any immediate exceptions from the connect call
        throw Exception('Connection failed: $e');
      }

      // Handle the result based on its type
      print('Connection result type: ${connectionResult.runtimeType}, value: $connectionResult');

      if (connectionResult is BluetoothConnection) {
        _bluetoothConnection = connectionResult;
        print('Got BluetoothConnection object');
      } else if (connectionResult is bool) {
        if (connectionResult == false) {
          throw Exception('Connection failed - device may not be paired or available. Please ensure the device is in pairing mode and try again.');
        } else {
          // On Windows, connect returns true but no BluetoothConnection object
          // This is a critical bug in the bluetooth_classic_multiplatform library on Windows
          // The connection is established at the native level but the Dart code cannot access it
          print('Library bug detected: connect() returned true but no BluetoothConnection object');
          print('This is a known issue with bluetooth_classic_multiplatform on Windows');
          print('The connection was established at the native level but cannot be used from Dart');

          throw Exception('Library bug: bluetooth_classic_multiplatform on Windows returns bool instead of BluetoothConnection. Please report this to the library maintainer or use a different Bluetooth library.');
        }
      } else {
        throw Exception('Connection failed - unexpected result type: ${connectionResult.runtimeType}');
      }

      if (_bluetoothConnection == null) {
        throw Exception('Failed to establish connection - no connection object');
      }

      _isConnected = true;
      _connectionStatus = 'Connected to ${device.name ?? 'Unknown Device'}';
      _setupBluetoothDataListener();

      onConnected?.call();
      print('Bluetooth connection successful');
    } catch (e) {
      _isConnected = false;
      _connectionType = null;
      _connectionIdentifier = null;
      _connectionStatus = 'Connection failed: $e';
      print('Bluetooth connection failed: $e');
      onError?.call('Connection failed: $e');
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
      onCommandSent?.call(jsonString);

      if (_connectionType == 'bluetooth' && _bluetoothConnection != null) {
        _bluetoothConnection!.writeString(jsonString);
        print('Bluetooth command sent: $jsonString');
        return true;
      }

      return true;
    } catch (e) {
      onError?.call('Failed to send command: $e');
      print('Command send error: $e');
      return false;
    }
  }

  /// Disconnect from current connection
  Future<void> disconnect() async {
    print('Starting disconnect process');

    // Cancel subscriptions
    _bluetoothDataSubscription?.cancel();

    try {
      if (_connectionType == 'bluetooth' &&
          _bluetoothConnection != null &&
          _bluetoothConnection!.isConnected) {
        print('Disconnecting Bluetooth');
        await _bluetoothConnection!.finish();
        print('Bluetooth disconnect successful');
      }
    } catch (e) {
      print('Disconnect error: $e');
    }

    _isConnected = false;
    _connectionType = null;
    _connectionIdentifier = null;
    _bluetoothConnection = null;
    _lineBuffer = '';
    _connectionStatus = 'Disconnected';
    onDisconnected?.call();
    print('Disconnect completed');
  }

  /// Set up Bluetooth data listener
  void _setupBluetoothDataListener() {
    print('Setting up Bluetooth data listener');

    if (_bluetoothConnection == null || _bluetoothConnection!.input == null) {
      print('Cannot set up Bluetooth data listener');
      return;
    }

    _bluetoothDataSubscription = _bluetoothConnection!.input!.listen(
      (data) {
        try {
          final message = utf8.decode(data);
          _lineBuffer += message;
          _processLineBuffer();
        } catch (e) {
          print('Bluetooth data handling error: $e');
          onError?.call('Data handling error: $e');
        }
      },
      onError: (error) {
        print('Bluetooth data stream error: $error');
        onError?.call('Data stream error: $error');
        disconnect();
      },
      onDone: () {
        print('Bluetooth data stream ended');
        onDisconnected?.call();
        disconnect();
      },
    );

    print('Bluetooth data listener set up successfully');
  }


  /// Process line buffer for complete lines
  void _processLineBuffer() {
    while (_lineBuffer.contains('\n')) {
      final index = _lineBuffer.indexOf('\n');
      final line = _lineBuffer.substring(0, index).trim();
      if (line.isNotEmpty) {
        _processCompleteJsonObject(line);
      }
      _lineBuffer = _lineBuffer.substring(index + 1);
    }
  }

  /// Process a complete JSON line
  void _processCompleteJsonObject(String jsonString) {
    final line = jsonString.trim();
    if (line.isEmpty) return;

    // Send complete JSON object to callback (raw data)
    onDataReceived?.call(line);
  }

  void dispose() {
    _bluetoothDataSubscription?.cancel();
    disconnect();
  }
}

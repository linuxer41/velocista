import 'dart:async';
import 'dart:convert';
import 'package:bluetooth_classic_multiplatform/bluetooth_classic_multiplatform.dart';

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
      // On Android it returns BluetoothConnection, on Windows it may return bool or int when failed
      dynamic connectionResult;
      try {
        connectionResult = await _bluetooth.connect(device.address);
      } catch (e) {
        // Handle any immediate exceptions from the connect call
        if (e.toString().contains('type \'bool\' is not a subtype of type \'int?\'')) {
          // This is a known issue on Windows with the bluetooth_classic_multiplatform library
          // The library internally tries to cast bool to int?, which fails
          throw Exception('Connection failed due to platform compatibility issue. This is a known problem with the Bluetooth library on Windows. Please try again or check device pairing.');
        }
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
          // On some platforms, connect may return true
          // Try to get the connection object anyway
          print('Connect returned bool true, attempting to get connection object');
          // Some library versions may set the connection internally
          // For now, assume connection failed since we can't get the object
          throw Exception('Connection initialization failed - library returned unexpected result');
        }
      } else if (connectionResult is int) {
        // On Windows, the library may return an int (0 for failure, non-zero for success)
        if (connectionResult == 0) {
          throw Exception('Connection failed - device may not be paired or available. Please ensure the device is in pairing mode and try again.');
        } else {
          // Connection successful, but no connection object returned
          print('Connect returned int $connectionResult, assuming success but no connection object');
          // We'll assume connection is established and try to proceed
          // This is a workaround for platform differences
        }
      } else {
        throw Exception('Connection failed - unexpected result type: ${connectionResult.runtimeType}');
      }

      if (_bluetoothConnection == null) {
        throw Exception('Failed to establish connection - no connection object');
      }

      // Wait a moment for connection to stabilize
      await Future.delayed(const Duration(milliseconds: 500));

      // Set up data listener before marking as connected
      try {
        _setupBluetoothDataListener();
      } catch (e) {
        print('Failed to set up data listener: $e');
        throw Exception('Failed to initialize data communication: $e');
      }

      _isConnected = true;
      _connectionStatus = 'Connected to ${device.name ?? 'Unknown Device'}';

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


  /// Send text command
  Future<bool> sendCommand(String command) async {
    if (!_isConnected) {
      onError?.call('Not connected to device');
      return false;
    }

    try {
      final commandString = '$command\r\n';

      // Add sent command to terminal
      onCommandSent?.call(commandString);

      if (_connectionType == 'bluetooth' && _bluetoothConnection != null) {
        _bluetoothConnection!.writeString(commandString);
        print('Bluetooth command sent: $commandString');
        print('Bluetooth command sent as bytes: ${utf8.encode(commandString).toList().join('- ')}');
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
      throw Exception('Bluetooth connection input stream not available');
    }

    try {
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
    } catch (e) {
      print('Failed to set up Bluetooth data listener: $e');
      throw Exception('Cannot acquire data buffer: $e');
    }
  }


  /// Process line buffer for complete lines
  void _processLineBuffer() {
    while (_lineBuffer.contains('\n')) {
      final index = _lineBuffer.indexOf('\n');
      final line = _lineBuffer.substring(0, index).trim();
      if (line.isNotEmpty) {
        _processCompleteDataLine(line);
      }
      _lineBuffer = _lineBuffer.substring(index + 1);
    }
  }

  /// Process a complete data line
  void _processCompleteDataLine(String dataString) {
    final line = dataString.trim();
    if (line.isEmpty) return;

    // Send complete data line to callback (raw serial data)
    onDataReceived?.call(line);
  }

  void dispose() {
    _bluetoothDataSubscription?.cancel();
    disconnect();
  }
}

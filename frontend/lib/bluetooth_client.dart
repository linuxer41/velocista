import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'arduino_data.dart';

class BluetoothClient {
  // Callbacks for data handling
  final Function(dynamic)? onDataReceived;
  final Function(StatusMessage)? onStatusReceived;
  final Function(String)? onError;
  final Function()? onConnected;
  final Function()? onDisconnected;
  
  // FlutterBlueClassic instance
  final FlutterBlueClassic _bluetooth;
  
  // Connection state
  bool _isConnected = false;
  BluetoothConnection? _connection;
  String? _connectedDeviceAddress;
  String _jsonBuffer = '';
  String _connectionStatus = 'Disconnected';
  
  // Device discovery
  final List<BluetoothDevice> _scanResults = [];
  bool _isScanning = false;
  StreamSubscription? _scanSubscription;
  StreamSubscription? _scanningStateSubscription;
  StreamSubscription? _adapterStateSubscription;
  
  // Data handling
  StreamSubscription? _dataSubscription;

  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  BluetoothClient({
    this.onDataReceived,
    this.onStatusReceived,
    this.onError,
    this.onConnected,
    this.onDisconnected,
  }) : _bluetooth = FlutterBlueClassic(usesFineLocation: true);

  /// Get current connection status (Bluetooth connection only)
  bool get isConnected => _isConnected;
  
  /// Get currently connected device
  BluetoothDevice? get connectedDevice {
    if (_connectedDeviceAddress == null) return null;
    return _scanResults.firstWhere(
      (device) => device.address == _connectedDeviceAddress,
      orElse: () => throw StateError('Device not found'),
    );
  }
  
  /// Get discovered devices list
  List<BluetoothDevice> get discoveredDevices => List.unmodifiable(_scanResults);
  
  /// Check if currently discovering
  bool get isScanning => _isScanning;
  
  /// Get connection status string
  String get connectionStatus => _connectionStatus;

  /// Check if Bluetooth is supported and enabled
  Future<Map<String, bool>> checkBluetoothStatus() async {
    try {
      final isSupported = await _bluetooth.isSupported;
      final isEnabled = await _bluetooth.isEnabled;
      
      return {
        'supported': isSupported,
        'enabled': isEnabled,
      };
    } catch (e) {
      onError?.call('Failed to check Bluetooth status: $e');
      return {'supported': false, 'enabled': false};
    }
  }

  /// Start discovery for Bluetooth devices
  Future<List<BluetoothDevice>> startDiscovery() async {
    print('🔍 [BT_CLIENT] ===== STARTING DEVICE DISCOVERY =====');
    
    if (_isScanning) {
      print('⚠️ [BT_CLIENT] Already scanning, stopping current scan');
      _bluetooth.stopScan();
    }

    _scanResults.clear();
    _isScanning = true;
    _connectionStatus = 'Searching for devices...';
    print('🔍 [BT_CLIENT] Discovery status set to: $_connectionStatus');

    try {
      print('🔍 [BT_CLIENT] Step 1: Checking Bluetooth status...');
      // Check Bluetooth status first
      final status = await checkBluetoothStatus();
      print('📊 [BT_CLIENT] Bluetooth status check result: $status');
      
      if (!status['supported']!) {
        _connectionStatus = 'Bluetooth not supported on this device';
        print('❌ [BT_CLIENT] Bluetooth not supported');
        throw Exception('Bluetooth not supported on this device');
      }
      
      if (!status['enabled']!) {
        _connectionStatus = 'Bluetooth is disabled. Please enable it in system settings.';
        print('❌ [BT_CLIENT] Bluetooth is disabled');
        onError?.call('Bluetooth is disabled. Please enable it in system settings.');
        return [];
      }
      
      print('✅ [BT_CLIENT] Bluetooth is supported and enabled');

      print('📱 [BT_CLIENT] Step 2: Getting paired devices...');
      // Get paired devices first
      final pairedDevicesResult = await _bluetooth.bondedDevices;
      final pairedDevices = pairedDevicesResult ?? [];
      print('📱 [BT_CLIENT] Found ${pairedDevices.length} paired devices');
      for (int i = 0; i < pairedDevices.length; i++) {
        final device = pairedDevices[i];
        print('   ${i+1}. ${device.name ?? 'Unknown'} (${device.address})');
      }
      
      print('🔍 [BT_CLIENT] Step 3: Setting up scan listeners...');
      // Set up scan results listener
      _scanSubscription = _bluetooth.scanResults.listen((device) {
        if (!_scanResults.any((d) => d.address == device.address)) {
          _scanResults.add(device);
          print('📡 [BT_CLIENT] Found device: ${device.name ?? 'Unknown'} (${device.address})');
        }
      }, onError: (error) {
        print('❌ [BT_CLIENT] Scan results error: $error');
      });

      // Set up scanning state listener
      _scanningStateSubscription = _bluetooth.isScanning.listen((isScanning) {
        _isScanning = isScanning;
        if (!isScanning) {
          print('✅ [BT_CLIENT] Scan completed');
        }
      }, onError: (error) {
        print('❌ [BT_CLIENT] Scanning state error: $error');
      });

      // Set up adapter state listener
      _adapterStateSubscription = _bluetooth.adapterState.listen((state) {
        _adapterState = state;
        print('📊 [BT_CLIENT] Adapter state: $state');
      }, onError: (error) {
        print('❌ [BT_CLIENT] Adapter state error: $error');
      });
      
      print('🔍 [BT_CLIENT] Step 4: Starting device scan...');
      // Start scanning
      _bluetooth.startScan();
      print('📡 [BT_CLIENT] Device scan started');
      
      // Wait for scan to find devices
      await Future.delayed(const Duration(seconds: 5));
      
      print('🔍 [BT_CLIENT] Step 5: Stopping scan...');
      // Stop scanning
      _bluetooth.stopScan();
      
      // Add paired devices to results if not already there
      for (final pairedDevice in pairedDevices) {
        if (!_scanResults.any((d) => d.address == pairedDevice.address)) {
          _scanResults.add(pairedDevice);
          print('   ✅ Added paired device: ${pairedDevice.name} (${pairedDevice.address})');
        }
      }
      
      print('📊 [BT_CLIENT] Final device list: ${_scanResults.length} devices');
      
      if (_scanResults.isEmpty) {
        _connectionStatus = 'No devices found. Make sure your Arduino is turned on and discoverable.';
        print('❌ [BT_CLIENT] No devices found: $_connectionStatus');
        onError?.call('No devices found. Make sure your Arduino is turned on and discoverable.');
      } else {
        _connectionStatus = 'Found ${_scanResults.length} device(s)';
        print('✅ [BT_CLIENT] Discovery successful: $_connectionStatus');
      }
      
      print('🔍 [BT_CLIENT] ===== DISCOVERY COMPLETED =====');
      return List.from(_scanResults);
    } catch (e, stackTrace) {
      _connectionStatus = 'Discovery failed: $e';
      print('💥 [BT_CLIENT] Discovery failed: $e');
      print('📋 [BT_CLIENT] Stack trace: $stackTrace');
      onError?.call('Discovery failed: $e. Make sure Bluetooth is enabled and try again.');
      rethrow;
    } finally {
      _isScanning = false;
      print('🏁 [BT_CLIENT] Discovery finished, setting isScanning = false');
    }
  }

  /// Connect to a specific device with improved validation
  Future<void> connectToDevice(BluetoothDevice device) async {
    if (isConnected) {
      print('🔄 [BT_CLIENT] Already connected, disconnecting first...');
      await disconnect();
    }

    try {
      _connectionStatus = 'Connecting to ${device.name ?? 'Unknown Device'}...';
      _connection = null;
      
      print('🔗 [BT_CLIENT] Connecting to ${device.name} (${device.address})');
      
      // Connect to device - this returns a BluetoothConnection
      _connection = await _bluetooth.connect(device.address);
      
      if (_connection == null) {
        throw Exception('Failed to connect to device - flutter_blue_classic returned null');
      }
      
      _connectedDeviceAddress = device.address;
      print('📡 [BT_CLIENT] Bluetooth connection established');
      _isConnected = true;
      _connectionStatus = 'Connected to ${device.name ?? 'Unknown Device'}';
      
      // Set up data listener
      _setupDataListener();
      
      // Mark as connected
      onConnected?.call();
      print('🎉 [BT_CLIENT] Connection successful');
      print('✅ [BT_CLIENT] ===== CONNECTION COMPLETED =====');
      
    } catch (e) {
      _isConnected = false;
      _connection = null;
      _connectedDeviceAddress = null;
      _connectionStatus = 'Connection failed: $e';
      print('❌ [BT_CLIENT] Connection failed: $e');
      onError?.call('Connection failed: $e');
      rethrow;
    }
  }


  /// Set up data listener for incoming data
  void _setupDataListener() {
    print('📡 [BT_CLIENT] Setting up data listener...');
    _dataSubscription?.cancel();

    if (_connection == null) {
      print('❌ [BT_CLIENT] Cannot set up data listener - connection is null');
      return;
    }

    if (_connection!.input == null) {
      print('❌ [BT_CLIENT] Cannot set up data listener - connection input is null');
      return;
    }

    // Throttle telemetry printing to avoid console spam
    DateTime? _lastTelemetryPrint;
    const Duration _telemetryThrottle = Duration(seconds: 2);
    DateTime? _lastRawPrint;

    _dataSubscription = _connection!.input!.listen((data) {
      try {
        // Convert bytes to string
        final message = utf8.decode(data);
        _jsonBuffer += message;

        // Split by newlines and process each line
        final lines = _jsonBuffer.split('\n');
        _jsonBuffer = lines.last; // Keep incomplete line for next iteration

        // Process complete lines
        for (int i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;

          // Try to parse as ArduinoMessage wrapper
          final message = ArduinoMessage.fromJson(line);
          if (message != null) {
            if (message.isTelemetry) {
              final telemetryData = TelemetryData.fromPayload(message.payload);
              if (telemetryData != null) {
                onDataReceived?.call(telemetryData);

                // Print telemetry data every 2 seconds to avoid console spam
                final now = DateTime.now();
                if (_lastTelemetryPrint == null ||
                    now.difference(_lastTelemetryPrint!) >= _telemetryThrottle) {
                  print('📊 [TELEMETRY] ${telemetryData.toString()}');
                  _lastTelemetryPrint = now;
                }
              }
            } else if (message.isStatus) {
              final statusMessage = StatusMessage.fromPayload(message.payload);
              if (statusMessage != null) {
                onStatusReceived?.call(statusMessage);
                print('📢 [STATUS] ${statusMessage.toString()}');
              }
            }
            continue;
          }

          // Fallback: try to parse as legacy ArduinoData
          try {
            final parsedData = ArduinoData.fromJson(line);
            onDataReceived?.call(parsedData);

            // Print telemetry data every 2 seconds to avoid console spam
            final now = DateTime.now();
            if (_lastTelemetryPrint == null ||
                now.difference(_lastTelemetryPrint!) >= _telemetryThrottle) {
              print('📊 [TELEMETRY] ${parsedData.toString()}');
              _lastTelemetryPrint = now;
            }
          } catch (e) {
            // Only log actual parsing errors
            if (e.toString().contains('JsonUnsupportedObjectError') ||
                e.toString().contains('FormatException')) {
              print('❌ [BT_CLIENT] JSON parse error: $e');
            }
          }
        }
      } catch (e) {
        print('❌ [BT_CLIENT] Data handling error: $e');
        onError?.call('Data handling error: $e');
      }
    },
      onError: (error) {
        print('❌ [BT_CLIENT] Data stream error: $error');
        onError?.call('Data stream error: $error');
        disconnect();
      },
      onDone: () {
        print('🔌 [BT_CLIENT] Data stream ended');
        onDisconnected?.call();
        disconnect();
      },
    );

    print('✅ [BT_CLIENT] Data listener set up successfully');
  }

  /// Send JSON configuration to Arduino
  Future<bool> sendConfiguration(ArduinoPIDConfig config) async {
    if (!isConnected || _connection == null) {
      onError?.call('Not connected to device');
      return false;
    }

    try {
      final jsonString = config.toJson();
      _connection!.writeString(jsonString);
      print('⚙️ [BT_CLIENT] Configuration sent: $jsonString');
      return true;
    } catch (e) {
      onError?.call('Failed to send configuration: $e');
      print('❌ [BT_CLIENT] Configuration send error: $e');
      return false;
    }
  }

  /// Send custom JSON command
  Future<bool> sendCommand(Map<String, dynamic> command) async {
    if (!_isConnected || _connection == null) {
      onError?.call('Not connected to device');
      return false;
    }

    try {
      final jsonString = jsonEncode(command);
      _connection!.writeString(jsonString);
      print('📤 [BT_CLIENT] Command sent: $jsonString');
      return true;
    } catch (e) {
      onError?.call('Failed to send command: $e');
      print('❌ [BT_CLIENT] Command send error: $e');
      return false;
    }
  }

  /// Request current status from Arduino
  Future<void> requestStatus() async {
    print('📡 [BT_CLIENT] Requesting status from Arduino...');
    await sendCommand({'command': 'getStatus'});
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    print('🔌 [BT_CLIENT] Starting disconnect process...');
    _dataSubscription?.cancel();
    _scanSubscription?.cancel();
    _scanningStateSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    
    try {
      if (_connection != null && _connection!.isConnected) {
        print('🔌 [BT_CLIENT] Disconnecting from Bluetooth device...');
        await _connection!.finish(); // Gracefully close the connection
        print('✅ [BT_CLIENT] Bluetooth disconnect successful');
      }
    } catch (e) {
      print('❌ [BT_CLIENT] Disconnect error: $e');
    }
    
    _isConnected = false;
    _connection = null;
    _connectedDeviceAddress = null;
    _jsonBuffer = '';
    _connectionStatus = 'Disconnected';
    onDisconnected?.call();
    print('🔌 [BT_CLIENT] Disconnect completed');
  }

  /// Get list of previously paired devices
  Future<List<BluetoothDevice>> getBondedDevices() async {
    try {
      final result = await _bluetooth.bondedDevices;
      return result ?? [];
    } catch (e) {
      onError?.call('Failed to get paired devices: $e');
      return [];
    }
  }

  /// Clear discovered devices list
  void clearDiscoveredDevices() {
    _scanResults.clear();
  }

  /// Get device connection quality indicator
  String getConnectionQuality() {
    if (!isConnected) return 'Disconnected';
    return 'Connected';
  }

  void dispose() {
    _dataSubscription?.cancel();
    _scanSubscription?.cancel();
    _scanningStateSubscription?.cancel();
    _adapterStateSubscription?.cancel();
    disconnect();
  }
}
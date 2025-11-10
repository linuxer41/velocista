import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import 'app_state.dart';

class ConnectionBottomSheet extends StatefulWidget {
  const ConnectionBottomSheet({super.key});

  @override
  State<ConnectionBottomSheet> createState() => _ConnectionBottomSheetState();
}

class _ConnectionBottomSheetState extends State<ConnectionBottomSheet> {
  // Track which device is currently being connected to
  BluetoothDevice? _connectingDevice;
  Timer? _connectionTimeoutTimer;
  static const int _connectionTimeoutSeconds = 10;
  int _remainingTime = _connectionTimeoutSeconds;
  Timer? _countdownTimer;
  AppState? _provider;

  @override
  void initState() {
    super.initState();
    // Listen for connection status changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _provider = AppInheritedWidget.of(context);
      if (_provider != null) {
        _provider!.isConnected.addListener(_handleConnectionStatusChange);
      }
    });
  }

  @override
  void dispose() {
    if (_provider != null) {
      _provider!.isConnected.removeListener(_handleConnectionStatusChange);
    }
    _connectionTimeoutTimer?.cancel();
    super.dispose();
  }

  void _handleConnectionStatusChange() {
    if (_provider != null &&
        _provider!.isConnected.value &&
        _connectingDevice != null) {
      // Connection succeeded, cancel timeout and close the dialog
      _connectionTimeoutTimer?.cancel();
      _countdownTimer?.cancel();
      setState(() {
        _remainingTime = _connectionTimeoutSeconds;
      });
      Navigator.of(context).pop();
    } else if (_provider != null &&
        !_provider!.isConnected.value &&
        _connectingDevice != null) {
      // Connection failed, reset loading state
      setState(() {
        _connectingDevice = null;
        _remainingTime = _connectionTimeoutSeconds;
      });
      _connectionTimeoutTimer?.cancel();
      _countdownTimer?.cancel();
    }
  }

  Future<void> _handleSerialPortTap(String portName, AppState provider) async {
    // Always disconnect first to ensure clean state, even if connecting to the same port
    if (provider.isConnected.value) {
      print(
          '🔄 [CONNECTION] Already connected to ${provider.connectedSerialPort.value ?? 'a port'}, disconnecting first...');

      // Show disconnecting message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Desconectando de ${provider.connectedSerialPort.value ?? 'puerto actual'}...'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Disconnect from current connection first
      await provider.disconnect();

      // Wait longer for serial port to be fully released
      await Future.delayed(const Duration(milliseconds: 1500));
    }

    // Now proceed with connection to the target serial port
    setState(() {
      _connectingDevice = null; // Reset Bluetooth connecting state
    });

    try {
      print('🔗 [CONNECTION] Connecting to serial port: $portName');
      await provider.connectToSerialPort(portName);
      // Connection attempt completed
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de conexión serial: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _handleDeviceTap(
      BluetoothDevice device, AppState provider) async {
    // Check if already connected to a different device
    if (provider.isConnected.value &&
        provider.connectedDevice.value?.address != device.address) {
      print(
          '🔄 [CONNECTION] Already connected to ${provider.connectedDevice.value?.name ?? 'unknown device'}, disconnecting first...');

      // Show disconnecting message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Desconectando de ${provider.connectedDevice.value?.name ?? 'dispositivo actual'}...'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Disconnect from current device first
      await provider.disconnect();

      // Wait a moment for disconnection to complete
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Now proceed with connection to the target device
    if (_connectingDevice != null) return; // Already connecting to a device

    setState(() {
      _connectingDevice = device;
      _remainingTime = _connectionTimeoutSeconds;
    });

    // Start countdown timer for UI
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _connectingDevice != null && _remainingTime > 0) {
        setState(() {
          _remainingTime--;
        });
      }
    });

    // Start timeout timer
    _connectionTimeoutTimer =
        Timer(const Duration(seconds: _connectionTimeoutSeconds), () {
      if (mounted && _connectingDevice != null) {
        // Timeout reached, cancel connection
        provider.disconnect();
        setState(() {
          _connectingDevice = null;
          _remainingTime = _connectionTimeoutSeconds;
        });
        _countdownTimer?.cancel();
        // Show timeout error
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Timeout: No se pudo conectar en 10 segundos. Verifica que el dispositivo esté disponible y cerca.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }
    });

    try {
      print(
          '🔗 [CONNECTION] Connecting to target device: ${device.name ?? 'Unknown'} (${device.address})');
      await provider.connectToDevice(device);
      // Connection attempt completed, timeout will be handled by listener
    } catch (e) {
      // Connection failed immediately, cancel timeout and show error
      _connectionTimeoutTimer?.cancel();
      _countdownTimer?.cancel();
      setState(() {
        _connectingDevice = null;
        _remainingTime = _connectionTimeoutSeconds;
      });
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error de conexión: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = AppInheritedWidget.of(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    height: 4,
                    width: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Content
                  Expanded(
                    child: provider == null
                        ? Center(
                            child: Text(
                              'Error: appState not found',
                              style: theme.textTheme.bodyLarge,
                            ),
                          )
                        : _buildConnectionContent(
                            provider, context, theme, colorScheme),
                  ),
                ],
              ),
              // Loading overlay
              if (provider?.isDiscovering.value == true)
                _buildLoadingOverlay(theme, colorScheme),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingOverlay(ThemeData theme, ColorScheme colorScheme) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Buscando dispositivos...',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionContent(AppState provider, BuildContext context,
      ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                Platform.isWindows ? 'Puertos Serial' : 'Dispositivos Bluetooth',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: provider.isDiscovering,
                    builder: (context, isDiscovering, child) {
                      if (isDiscovering) {
                        // Show loading spinner in header during discovery
                        return const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.orange),
                          ),
                        );
                      } else {
                        return IconButton(
                          icon: Icon(
                            Icons.refresh,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                          onPressed: provider.isConnected.value
                              ? null
                              : provider.startDiscovery,
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _buildDeviceList(provider, theme, colorScheme),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList(
      AppState provider, ThemeData theme, ColorScheme colorScheme) {
    return RepaintBoundary(
      child: ValueListenableBuilder<List<BluetoothDevice>>(
        valueListenable: provider.discoveredDevices,
        builder: (context, devices, child) {
          return ValueListenableBuilder<List<String>>(
            valueListenable: provider.availableSerialPorts,
            builder: (context, serialPorts, child) {
              final totalItems = devices.length + serialPorts.length;

              if (totalItems > 0) {
                return ListView.builder(
                  itemCount: totalItems,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  itemBuilder: (context, index) {
                    if (index < devices.length) {
                      // Bluetooth device
                      final device = devices[index];
                      final isConnected =
                          provider.connectedDevice.value?.address == device.address &&
                              provider.isConnected.value;
                      final isConnecting =
                          _connectingDevice?.address == device.address &&
                              !provider.isConnected.value;

                      return Card(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        elevation: isConnected ? 2 : 1,
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isConnected
                                  ? colorScheme.primaryContainer
                                  : isConnecting
                                      ? Colors.orange.withOpacity(0.2)
                                      : colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: isConnecting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.orange),
                                    ),
                                  )
                                : Icon(
                                    isConnected
                                        ? Icons.bluetooth_connected
                                        : Icons.bluetooth,
                                    color: isConnected
                                        ? colorScheme.primary
                                        : colorScheme.secondary,
                                    size: 16,
                                  ),
                          ),
                          title: Text(
                            device.name ?? 'Dispositivo Desconocido',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isConnected
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'BT: ${device.address}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isConnected
                                          ? colorScheme.primary
                                          : isConnecting
                                              ? Colors.orange
                                              : colorScheme.secondary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isConnected
                                        ? 'Dispositivo Conectado'
                                        : isConnecting
                                            ? 'Conectando... ($_remainingTime s)'
                                            : 'Dispositivo Disponible',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: isConnected
                                          ? colorScheme.primary
                                          : isConnecting
                                              ? Colors.orange
                                              : colorScheme.secondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: isConnected
                              ? Icon(
                                  Icons.check_circle,
                                  color: colorScheme.primary,
                                  size: 18,
                                )
                              : isConnecting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.orange),
                                      ),
                                    )
                                  : Icon(
                                      Icons.arrow_forward_ios,
                                      color: colorScheme.primary,
                                      size: 16,
                                    ),
                          onTap: (isConnected || isConnecting)
                              ? null
                              : () => _handleDeviceTap(device, provider),
                        ),
                      );
                    } else {
                      // Serial port
                      final portIndex = index - devices.length;
                      final portName = serialPorts[portIndex];
                      final isConnected =
                          provider.connectedSerialPort.value == portName &&
                              provider.isConnected.value;

                      return Card(
                        margin:
                            const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        elevation: isConnected ? 2 : 1,
                        child: ListTile(
                          contentPadding:
                              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          leading: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isConnected
                                  ? colorScheme.primaryContainer
                                  : colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              isConnected ? Icons.usb : Icons.settings_input_hdmi,
                              color: isConnected
                                  ? colorScheme.primary
                                  : colorScheme.secondary,
                              size: 16,
                            ),
                          ),
                          title: Text(
                            'Puerto Serial',
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: isConnected
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      portName,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontFamily: 'monospace',
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: isConnected
                                          ? colorScheme.primary
                                          : colorScheme.secondary,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    isConnected
                                        ? 'Puerto Conectado'
                                        : 'Puerto Disponible',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: isConnected
                                          ? colorScheme.primary
                                          : colorScheme.secondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: isConnected
                              ? Icon(
                                  Icons.check_circle,
                                  color: colorScheme.primary,
                                  size: 18,
                                )
                              : Icon(
                                  Icons.arrow_forward_ios,
                                  color: colorScheme.primary,
                                  size: 16,
                                ),
                          onTap: isConnected
                              ? null
                              : () => _handleSerialPortTap(portName, provider),
                        ),
                      );
                    }
                  },
                );
              } else {
                return _buildNoDevicesFoundMessageFullScreen(theme, colorScheme);
              }
            },
          );
        },
      ),
    );
  }

  Widget _buildNoDevicesFoundMessageFullScreen(
      ThemeData theme, ColorScheme colorScheme) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bluetooth_searching,
            size: 64,
            color: colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'No se encontraron dispositivos',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Asegúrate de que tu Arduino esté encendido y que esté emparejado en la configuración de Bluetooth',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          _buildTroubleshootingSteps(theme, colorScheme),
        ],
      ),
    );
  }

  Widget _buildTroubleshootingSteps(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pasos para resolver:',
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        if (Platform.isWindows) ...[
          _buildStepItem(
              '1',
              'Conecta tu Arduino por USB al computador',
              theme,
              colorScheme),
          _buildStepItem('2', 'Asegúrate de que los drivers USB-Serial estén instalados',
              theme, colorScheme),
          _buildStepItem(
              '3',
              'Verifica el puerto COM en Administrador de Dispositivos',
              theme,
              colorScheme),
          _buildStepItem('4', 'Vuelve a esta app y presiona el botón de actualizar',
              theme, colorScheme),
        ] else ...[
          _buildStepItem(
              '1',
              'Enciende tu Arduino y asegúrate de que el LED de Bluetooth parpadee',
              theme,
              colorScheme),
          _buildStepItem('2', 'Ve a Configuración → Bluetooth en tu teléfono',
              theme, colorScheme),
          _buildStepItem('3', 'Activa el Bluetooth si no está habilitado', theme,
              colorScheme),
          _buildStepItem(
              '4',
              'Busca dispositivos disponibles (ej: "HC-05", "Arduino-BT")',
              theme,
              colorScheme),
          _buildStepItem('5', 'Toca "Emparejar" en tu Arduino cuando aparezca',
              theme, colorScheme),
          _buildStepItem(
              '6',
              'Vuelve a esta app y presiona el botón de actualizar',
              theme,
              colorScheme),
        ],
      ],
    );
  }

  Widget _buildStepItem(
      String number, String text, ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

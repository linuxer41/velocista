import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import '../app_state.dart';
import '../arduino_data.dart';

class SettingsPage extends StatefulWidget {
  final AppState appState;
  final ThemeProvider themeProvider;

  const SettingsPage({
    super.key,
    required this.appState,
    required this.themeProvider,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Device discovery button in app bar
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: () => _startDeviceDiscovery(),
              icon: const Icon(Icons.bluetooth_searching, size: 18),
              label: const Text('Buscar'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Theme Settings
            _buildCompactSection('Tema', Icons.palette, _buildThemeToggle()),

            const Divider(),

            // Robot Mode Settings
            _buildCompactSection('Modo Robot', Icons.settings, _buildModeSelection()),

            const Divider(),

            // Connection Settings
            _buildCompactSection('Conexión', Icons.bluetooth, _buildConnectionSettings()),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactSection(String title, IconData icon, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        content,
      ],
    );
  }

  Widget _buildThemeToggle() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  widget.themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Tema Oscuro',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
            Switch(
              value: widget.themeProvider.isDarkMode,
              onChanged: (value) {
                widget.themeProvider.setDarkMode(value);
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeSelection() {
    return ValueListenableBuilder<OperationMode>(
      valueListenable: widget.appState.currentMode,
      builder: (context, currentMode, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: OperationMode.values.map((mode) {
                    final isSelected = mode == currentMode;
                    return FilterChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(mode.icon, size: 16),
                          const SizedBox(width: 4),
                          Text(mode.displayName),
                        ],
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected && !isSelected) {
                          _changeMode(mode);
                        }
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectionSettings() {
    return ValueListenableBuilder<bool>(
      valueListenable: widget.appState.isConnected,
      builder: (context, isConnected, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                          color: isConnected ? Colors.green : Colors.red,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          isConnected ? 'Conectado' : 'Desconectado',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ),
                    if (isConnected)
                      TextButton.icon(
                        onPressed: () => widget.appState.disconnect(),
                        icon: const Icon(Icons.bluetooth_disabled),
                        label: const Text('Desconectar'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      )
                    else
                      const SizedBox.shrink(), // Button moved to top of settings page
                  ],
                ),
                if (isConnected) ...[
                  const SizedBox(height: 12),
                  ValueListenableBuilder<BluetoothDevice?>(
                    valueListenable: widget.appState.connectedDevice,
                    builder: (context, device, child) {
                      return Text(
                        'Dispositivo: ${device?.name ?? 'Desconocido'}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAdvancedSettings() {
    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.save),
                  title: const Text('Guardar Configuración'),
                  subtitle: const Text('Guarda la configuración actual en EEPROM'),
                  trailing: ElevatedButton(
                    onPressed: () => widget.appState.sendCommand({'eeprom': 1}),
                    child: const Text('Guardar'),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.refresh),
                  title: const Text('Solicitar Telemetría'),
                  subtitle: const Text('Obtiene datos actuales del robot'),
                  trailing: ElevatedButton(
                    onPressed: () => widget.appState.sendCommand({'telemetry': 1}),
                    child: const Text('Solicitar'),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.tune),
                  title: const Text('Calibrar Sensores'),
                  subtitle: const Text('Calibra los sensores QTR'),
                  trailing: ElevatedButton(
                    onPressed: () => widget.appState.sendCommand({'calibrate_qtr': 1}),
                    child: const Text('Calibrar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _changeMode(OperationMode mode) async {
    await widget.appState.changeOperationMode(mode);
    await widget.appState.sendCommand({'mode': mode.id});

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Modo cambiado a: ${mode.displayName}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _startDeviceDiscovery() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Buscando dispositivos...'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              const Text('Buscando dispositivos Bluetooth emparejados...'),
              const SizedBox(height: 8),
              const Text(
                'Asegúrate de que tu Arduino esté encendido y emparejado.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

      await widget.appState.startDiscovery();

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show device list automatically if devices found
      if (mounted && widget.appState.discoveredDevices.value.isNotEmpty) {
        widget.appState.showDeviceList.value = true;
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al buscar dispositivos: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}
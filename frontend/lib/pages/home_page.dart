import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../app_state.dart';
import '../arduino_data.dart';
import '../connection_bottom_sheet.dart';
import '../widgets/pid_control.dart';
import '../widgets/remote_control.dart';
import '../widgets/left_pid_control.dart';
import '../widgets/right_pid_control.dart';
import '../widgets/status_bar.dart';
import 'settings_page.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  final ThemeProvider themeProvider;

  const HomePage({super.key, required this.themeProvider});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isRealtimeEnabled = true; // Local state for realtime toggle

  @override
  void initState() {
    super.initState();
    // Show connection modal automatically if not connected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = AppInheritedWidget.of(context);
      if (appState != null) {
        appState.isConnected.addListener(_onConnectionChanged);
        appState.lastAck.addListener(_onAckReceived);
        _checkConnectionAndShowModal();
      }
    });
  }

  @override
  void dispose() {
    final appState = AppInheritedWidget.of(context);
    if (appState != null) {
      appState.isConnected.removeListener(_onConnectionChanged);
      appState.lastAck.removeListener(_onAckReceived);
    }
    super.dispose();
  }

  void _onAckReceived() {
    final appState = AppInheritedWidget.of(context);
    if (appState != null && appState.lastAck.value != null) {
      // Only show snackbar for commands that start with "set"
      if (appState.lastAck.value!.startsWith('set')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Guardado: ${appState.lastAck.value}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      // Reset to avoid repeated snackbars
      appState.lastAck.value = null;
    }
  }

  void _onConnectionChanged() {
    final appState = AppInheritedWidget.of(context);
    if (appState != null && !appState.isConnected.value && mounted) {
      // Show modal when disconnected
      _showConnectionModal();
    }
  }

  void _checkConnectionAndShowModal() {
    final appState = AppInheritedWidget.of(context);
    if (appState != null && !appState.isConnected.value) {
      _showConnectionModal();
    }
  }

  void _showConnectionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false, // Cannot be dismissed by tapping outside
      enableDrag: false, // Cannot be dragged down
      builder: (context) => ConnectionBottomSheet(
        onShowMessage: (message, {Color? backgroundColor, Duration? duration}) {
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: backgroundColor ?? Colors.blue,
              duration: duration ?? const Duration(seconds: 3),
            ),
          );
        },
      ),
    );
  }

  Widget _getControlsWidget(OperationMode mode) {
    final appState = AppInheritedWidget.of(context);
    if (appState == null) return const SizedBox.shrink();

    switch (mode) {
      case OperationMode.idle:
        return _buildIdleControls(appState);
      case OperationMode.lineFollowing:
        return _buildPidTabs(appState);
      case OperationMode.remoteControl:
        return RemoteControl(appState: appState);
    }
  }

  Widget _buildIdleControls(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Modo IDLE - Monitoreo de Sensores',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Space Grotesk',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'En este modo, el robot lee los sensores pero no controla los motores.',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    final calibrateCommand = CalibrateQtrCommand();
                    appState.sendCommand(calibrateCommand.toCommand());
                  },
                  icon: const Icon(Icons.tune, size: 16),
                  label: const Text('Calibrar Sensores', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    final telemetryCommand = TelemetryRequestCommand();
                    appState.sendCommand(telemetryCommand.toCommand());
                  },
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Obtener Telemetría', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    appState.changeOperationMode(OperationMode.lineFollowing);
                  },
                  icon: const Icon(Icons.route, size: 16),
                  label: const Text('Modo Seguidor', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Theme.of(context).colorScheme.tertiary,
                    foregroundColor: Theme.of(context).colorScheme.onTertiary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    appState.changeOperationMode(OperationMode.remoteControl);
                  },
                  icon: const Icon(Icons.gamepad, size: 16),
                  label: const Text('Control Remoto', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                    foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPidTabs(AppState appState) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          _buildBaseSpeedTab(appState),
          TabBar(
            tabs: const [
              Tab(text: 'PID Línea'),
              Tab(text: 'PID Izquierdo'),
              Tab(text: 'PID Derecho'),
            ],
            labelStyle: const TextStyle(fontSize: 12, fontFamily: 'Space Grotesk'),
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          SizedBox(
            height: 200, // Fixed height for the tab content
            child: TabBarView(
              children: [
                _buildLinePidTab(appState),
                LeftPidControl(appState: appState),
                RightPidControl(appState: appState),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBaseSpeedTab(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Configuración Velocidad Base',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Space Grotesk',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildBaseSpeedInput('Velocidad Base', '200', () {
                  // Send base speed command
                  final baseSpeedCommand = BaseSpeedCommand(200.0);
                  appState.sendCommand(baseSpeedCommand.toCommand());
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBaseSpeedInput('RPM Base', '120.0', () {
                  // Send base RPM command
                  final baseRpmCommand = BaseRpmCommand(120.0);
                  appState.sendCommand(baseRpmCommand.toCommand());
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Control toggles and sync button
          Row(
            children: [
              // Cascade Control Toggle
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Cascada',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Transform.scale(
                      scale: 0.8,
                      child: ValueListenableBuilder<ArduinoData?>(
                        valueListenable: appState.currentData,
                        builder: (context, data, child) {
                          final isCascadeEnabled = data?.cascade ?? true;
                          return Switch(
                            value: isCascadeEnabled,
                            onChanged: (value) {
                              final cascadeCommand = CascadeCommand(value);
                              appState.sendCommand(cascadeCommand.toCommand());
                            },
                            activeColor: Theme.of(context).colorScheme.primary,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Realtime Control Toggle
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Realtime',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: _isRealtimeEnabled,
                        onChanged: (value) {
                          setState(() {
                            _isRealtimeEnabled = value;
                          });
                          final realtimeCommand = RealtimeEnableCommand(value);
                          appState.sendCommand(realtimeCommand.toCommand());
                        },
                        activeColor: Theme.of(context).colorScheme.secondary,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ),
              // Sync with Telemetry Icon Button
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sync',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: IconButton(
                        onPressed: () {
                          final telemetryCommand = TelemetryRequestCommand();
                          appState.sendCommand(telemetryCommand.toCommand());
                        },
                        icon: Icon(
                          Icons.sync,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          size: 16,
                        ),
                        tooltip: 'Sincronizar con Telemetry',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBaseSpeedInput(String label, String defaultValue, VoidCallback onSend) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 40,
                child: TextField(
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: defaultValue,
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            SizedBox(
              width: 60,
              height: 40,
              child: ElevatedButton(
                onPressed: onSend,
                child: const Text('Enviar', style: TextStyle(fontSize: 10)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLinePidTab(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Line PID',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Space Grotesk',
            ),
          ),
          const SizedBox(height: 8),

          // PID Parameters
          Row(
            children: [
              Expanded(
                child: _buildPidInput('Kp', '2.0'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPidInput('Ki', '0.05'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPidInput('Kd', '0.75'),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Send line PID command
                final pidCommand = PidCommand(
                  type: 'line',
                  kp: 2.0,
                  ki: 0.05,
                  kd: 0.75,
                );
                appState.sendCommand(pidCommand.toCommand());
              },
              child: const Text('Actualizar PID Línea', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Current Values Display
          ValueListenableBuilder<ArduinoData?>(
            valueListenable: appState.currentData,
            builder: (context, data, child) {
              if (data == null || data.linePid == null) return const SizedBox.shrink();

              return Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estado PID Línea',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Posición: ${data.linePid![3].toStringAsFixed(1)}',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPidInput(String label, String defaultValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 32,
          child: TextField(
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: defaultValue,
              hintStyle: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppInheritedWidget.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                // Status Bar
                StatusBar(appState: appState!, onShowConnectionModal: _showConnectionModal),

                // Gauges Layout
                ValueListenableBuilder<ArduinoData?>(
                  valueListenable: appState.currentData,
                  builder: (context, data, child) {
                    // Use realtime data (type:4) for live displays
                    final leftRpm = data != null && data.leftVel != null && data.leftVel!.length >= 1
                        ? data.leftVel![0] // RPM from realtime data
                        : 0.0;
                    final rightRpm = data != null && data.rightVel != null && data.rightVel!.length >= 1
                        ? data.rightVel![0] // RPM from realtime data
                        : 0.0;
                    final leftSpeed = leftRpm * 0.036; // RPM to km/h
                    final rightSpeed = rightRpm * 0.036; // RPM to km/h
                    final averageSpeed = (leftSpeed + rightSpeed) / 2; // Average speed

                    return Column(
                      children: [
                        // Spacer at top for more space
                        const SizedBox(height: 8),
                        // Large centered speed gauge
                        SizedBox(
                          height: 100,
                          child: Center(
                            child: _buildLargeGauge(averageSpeed, 'km/h',
                                Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Two RPM gauges side by side
                        SizedBox(
                          height: 70,
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildCompactGauge(
                                    'L', leftRpm, 'rpm', Colors.green),
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: _buildCompactGauge(
                                    'R', rightRpm, 'rpm', Colors.green),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Distance and Acceleration
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: ValueListenableBuilder<ArduinoData?>(
                            valueListenable: appState.currentData,
                            builder: (context, data, child) {
                              final distance = data != null
                                  ? (data.totalDistance / 100)
                                      .toStringAsFixed(1)
                                  : '0.0'; // cm to km
                              return Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Distancia',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontFamily: 'Space Grotesk',
                                          ),
                                        ),
                                        Text(
                                          '$distance km',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                            fontFamily: 'Space Grotesk',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Aceleración',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontFamily: 'Space Grotesk',
                                          ),
                                        ),
                                        Text(
                                          '2.1 m/s²', // TODO: Calcular desde cambio de velocidad
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                            fontFamily: 'Space Grotesk',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Sensor status - 8 sensors as bars
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SettingsPage(
                                  appState: appState,
                                  themeProvider: widget.themeProvider,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            height: 70,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant
                                  .withOpacity(0.1),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Sensores QTR',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(8, (index) {
                                    // Only sensors 1-6 (indices 1-6) are active, telemetry sends 6 values for sensors 2-7
                                    final isActive = index >= 1 && index <= 6;
                                    final telemetryIndex = isActive ? index - 1 : -1; // Map to telemetry array (0-5)

                                    final sensorValue = isActive && data != null && telemetryIndex < data.sensors.length
                                        ? data.sensors[telemetryIndex] // Use realtime QTR data
                                        : 0;
                                    final percentage =
                                        (sensorValue / 1023.0).clamp(0.0, 1.0);

                                    return Container(
                                      width: 20,
                                      height: 35,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 1),
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: isActive
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .surfaceVariant
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .surfaceVariant
                                                        .withOpacity(0.3),
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                              child: FractionallySizedBox(
                                                alignment:
                                                    Alignment.bottomCenter,
                                                heightFactor: isActive ? percentage : 0.0,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: isActive
                                                        ? (percentage < 0.3
                                                            ? Colors.red
                                                            : Colors.green)
                                                        : Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant
                                                            .withOpacity(0.3),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            3),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              fontSize: 8,
                                              color: isActive
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant
                                                      .withOpacity(0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // PID and Base Speed
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: ValueListenableBuilder<ArduinoData?>(
                            valueListenable: appState.currentData,
                            builder: (context, data, child) {
                              // Use realtime data for live displays
                              final lineData = data != null && data.linePid != null && data.linePid!.length >= 8
                                  ? data.linePid!
                                  : [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
                              final error = lineData[5]; // error from realtime LINE_PID
                              final correction = lineData[4]; // output from realtime LINE_PID
                              final baseSpeed = data != null ? data.baseSpeed ?? 0.0 : 0.0;

                              return Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Text(
                                        'PID: P=${lineData[0].toStringAsFixed(2)} I=${lineData[1].toStringAsFixed(3)} D=${lineData[2].toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                          fontFamily: 'Space Grotesk',
                                        ),
                                      ),
                                      Text(
                                        'Vel Base: ${(baseSpeed * 100).toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                          fontFamily: 'Space Grotesk',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Text(
                                        'Error: ${error.toStringAsFixed(1)}',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w400,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontFamily: 'Space Grotesk',
                                        ),
                                      ),
                                      Text(
                                        'Corrección: ${correction.toStringAsFixed(1)}',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w400,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontFamily: 'Space Grotesk',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        // Encoder Readings
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: ValueListenableBuilder<ArduinoData?>(
                            valueListenable: appState.currentData,
                            builder: (context, data, child) {
                              // Use realtime data for live encoder readings
                              final leftRpm = data != null && data.leftVel != null && data.leftVel!.length >= 1
                                  ? data.leftVel![0] : 0.0; // RPM from realtime LEFT
                              final leftTargetRpm = data != null && data.leftVel != null && data.leftVel!.length >= 2
                                  ? data.leftVel![1] : 0.0; // Target RPM from realtime LEFT
                              final rightRpm = data != null && data.rightVel != null && data.rightVel!.length >= 1
                                  ? data.rightVel![0] : 0.0; // RPM from realtime RIGHT
                              final rightTargetRpm = data != null && data.rightVel != null && data.rightVel!.length >= 2
                                  ? data.rightVel![1] : 0.0; // Target RPM from realtime RIGHT
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Text(
                                    'Motor Izq: ${leftRpm.toStringAsFixed(1)} / ${leftTargetRpm.toStringAsFixed(1)} RPM',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontFamily: 'Space Grotesk',
                                    ),
                                  ),
                                  Text(
                                    'Motor Der: ${rightRpm.toStringAsFixed(1)} / ${rightTargetRpm.toStringAsFixed(1)} RPM',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontFamily: 'Space Grotesk',
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Dynamic controls based on selected mode
                        ValueListenableBuilder<OperationMode>(
                          valueListenable: appState.currentMode,
                          builder: (context, mode, child) {
                            return _getControlsWidget(mode);
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLargeGauge(double value, String unit, Color color) {
    return SizedBox(
      width: 120,
      height: 120,
      child: SfRadialGauge(
        axes: <RadialAxis>[
          RadialAxis(
            minimum: 0,
            maximum: unit == 'km/h' ? 100 : 5000, // Adjust max based on unit
            showLabels: false,
            showTicks: false,
            axisLineStyle: AxisLineStyle(
              thickness: 14,
              color: Theme.of(context).colorScheme.surfaceVariant,
              thicknessUnit: GaugeSizeUnit.logicalPixel,
            ),
            pointers: <GaugePointer>[
              RangePointer(
                value: value,
                width: 14,
                color: color,
                enableAnimation: true,
                animationDuration: 300,
                cornerStyle: CornerStyle.bothCurve,
              ),
            ],
            annotations: <GaugeAnnotation>[
              GaugeAnnotation(
                widget: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontFamily: 'Space Grotesk',
                      ),
                    ),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFamily: 'Space Grotesk',
                      ),
                    ),
                  ],
                ),
                angle: 90,
                positionFactor: 0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactGauge(
      String title, double value, String unit, Color color) {
    return SizedBox(
      width: 80,
      height: 80,
      child: SfRadialGauge(
        axes: <RadialAxis>[
          RadialAxis(
            minimum: 0,
            maximum: unit == 'km/h' ? 100 : 5000, // Adjust max based on unit
            showLabels: false,
            showTicks: false,
            axisLineStyle: AxisLineStyle(
              thickness: 8,
              color: Theme.of(context).colorScheme.surfaceVariant,
              thicknessUnit: GaugeSizeUnit.logicalPixel,
            ),
            pointers: <GaugePointer>[
              RangePointer(
                value: value,
                width: 8,
                color: color,
                enableAnimation: true,
                animationDuration: 300,
                cornerStyle: CornerStyle.bothCurve,
              ),
            ],
            annotations: <GaugeAnnotation>[
              GaugeAnnotation(
                widget: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontFamily: 'Space Grotesk',
                        ),
                      ),
                    Text(
                      value.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontFamily: 'Space Grotesk',
                      ),
                    ),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFamily: 'Space Grotesk',
                      ),
                    ),
                  ],
                ),
                angle: 90,
                positionFactor: 0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGauge(String title, double value, String unit, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title.isNotEmpty)
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Space Grotesk',
            ),
            textAlign: TextAlign.center,
          ),
        if (title.isNotEmpty) const SizedBox(height: 8),
        SizedBox(
          width: 120,
          height: 120,
          child: SfRadialGauge(
            axes: <RadialAxis>[
              RadialAxis(
                minimum: 0,
                maximum:
                    unit == 'km/h' ? 100 : 5000, // Adjust max based on unit
                showLabels: false,
                showTicks: false,
                axisLineStyle: AxisLineStyle(
                  thickness: 12,
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  thicknessUnit: GaugeSizeUnit.logicalPixel,
                ),
                pointers: <GaugePointer>[
                  RangePointer(
                    value: value,
                    width: 12,
                    color: color,
                    enableAnimation: true,
                    animationDuration: 300,
                    cornerStyle: CornerStyle.bothCurve,
                  ),
                ],
                annotations: <GaugeAnnotation>[
                  GaugeAnnotation(
                    widget: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          value.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontFamily: 'Space Grotesk',
                          ),
                        ),
                        Text(
                          unit,
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontFamily: 'Space Grotesk',
                          ),
                        ),
                      ],
                    ),
                    angle: 90,
                    positionFactor: 0,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

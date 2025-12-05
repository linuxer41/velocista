import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../app_state.dart';
import '../arduino_data.dart';
import '../connection_bottom_sheet.dart';
import '../widgets/remote_control.dart';
import '../widgets/status_bar.dart';

import '../widgets/navigation_menu.dart';
import '../widgets/idle_controls.dart';
import '../widgets/pid_tabs.dart';
import '../widgets/gauges_section.dart';
import '../widgets/motor_info_section.dart';
import '../widgets/config_data_section.dart';
import '../widgets/gauges.dart';

import 'config_page.dart';
import 'terminal_page.dart';
import 'graphs_page.dart';
import 'app_settings_page.dart';

class HomePage extends StatefulWidget {
  final ThemeProvider themeProvider;

  const HomePage({super.key, required this.themeProvider});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late TextEditingController _baseSpeedController;
  late TextEditingController _baseRpmController;
  late TextEditingController _maxSpeedController;

  double _leftPwm = 0.0;
  double _rightPwm = 0.0;
  double _leftRpm = 0.0;
  double _rightRpm = 0.0;

  bool _configExpanded = false;
  bool _syncMotors = false;

  @override
  void initState() {
    super.initState();

    // Initialize controllers
    _baseSpeedController = TextEditingController(text: '200');
    _baseRpmController = TextEditingController(text: '120.0');
    _maxSpeedController = TextEditingController(text: '230');

    // Show connection modal automatically if not connected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = AppInheritedWidget.of(context);
      if (appState != null) {
        appState.isConnected.addListener(_onConnectionChanged);
        appState.lastAck.addListener(_onAckReceived);
        appState.configData.addListener(_updateControllersFromConfig);
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
      appState.configData.removeListener(_updateControllersFromConfig);
    }
    _baseSpeedController.dispose();
    _baseRpmController.dispose();
    _maxSpeedController.dispose();
    super.dispose();
  }

  void _onAckReceived() {
    final appState = AppInheritedWidget.of(context);
    if (appState != null && appState.lastAck.value != null) {
      // Only show snackbar for commands that start with "set"
      if (appState.lastAck.value!.startsWith('set')) {
        // Build enhanced acknowledgment message
        String ackMessage = appState.lastAck.value!;

        // Add features status if available
        if (appState.configData.value?.featConfig != null &&
            appState.configData.value!.featConfig!.length >= 9) {
          final featConfig = appState.configData.value!.featConfig!;
          final features =
              'FEAT_CONFIG:[${featConfig.sublist(0, 9).join(',')}]';
          ackMessage += '|$features';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Guardado: $ackMessage'),
            duration: const Duration(
                seconds: 3), // Extended duration for longer message
          ),
        );
      }
      // Reset to avoid repeated snackbars
      appState.lastAck.value = null;
    }
  }

  void _updateControllersFromConfig() {
    final appState = AppInheritedWidget.of(context);
    if (appState != null) {
      final config = appState.configData.value;
      if (config != null) {
        // Update base speed controllers
        if (config.base != null) {
          if (config.base!.isNotEmpty) {
            _baseSpeedController.text = config.base![0].toStringAsFixed(0);
          }
          if (config.base!.length >= 2) {
            _baseRpmController.text = config.base![1].toStringAsFixed(1);
          }
        }
        // Update max speed controllers
        if (config.max != null) {
          if (config.max!.isNotEmpty) {
            _maxSpeedController.text = config.max![0].toStringAsFixed(0);
          }
        }

      }
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
        return IdleControls(appState: appState);
      case OperationMode.lineFollowing:
        return PidTabs(appState: appState);
      case OperationMode.remoteControl:
        return RemoteControl(appState: appState);
    }
  }
  @override
  Widget build(BuildContext context) {
    final appState = AppInheritedWidget.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: ValueListenableBuilder<OperationMode>(
        valueListenable: appState!.currentMode,
        builder: (context, mode, child) {
          if (mode == OperationMode.remoteControl) {
            // Split screen layout for remote control
            return Stack(
              children: [
                Column(
                  children: [
                    // Top half - scrollable content
                    Expanded(
                      flex: 1,
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            children: [
                              // Status Bar
                              StatusBar(
                                  appState: appState,
                                  onShowConnectionModal: _showConnectionModal),

                // Gauges Layout
                ValueListenableBuilder<TelemetryData?>(
                  valueListenable: appState.telemetryData,
                  builder: (context, data, child) {
                    // Use telemetry data for live displays
                    final leftRpm = (data != null &&
                            data.left != null &&
                            data.left!.isNotEmpty)
                        ? data.left![0] // RPM from telemetry data
                        : 0.0;
                    final rightRpm = (data != null &&
                            data.right != null &&
                            data.right!.isNotEmpty)
                        ? data.right![0] // RPM from telemetry data
                        : 0.0;
                    final leftSpeed = (data != null &&
                            data.speedCms != null &&
                            data.speedCms!.isNotEmpty)
                        ? data.speedCms![0] / 100 // cm/s to m/s
                        : leftRpm * 0.036 / 3.6; // RPM to m/s
                    final rightSpeed = (data != null &&
                            data.speedCms != null &&
                            data.speedCms!.length >= 2)
                        ? data.speedCms![1] / 100 // cm/s to m/s
                        : rightRpm * 0.036 / 3.6; // RPM to m/s
                    final averageSpeed = (leftSpeed + rightSpeed) /
                        2 *
                        3.6; // Average speed in km/h

                    return Column(
                      children: [
                        // Spacer at top for more space
                        const SizedBox(height: 8),
                        // Large centered speed gauge
                        SizedBox(
                          height: 100,
                          child: Center(
                            child: LargeGauge(value: averageSpeed, unit: 'km/h', color: Colors.green,),
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Two RPM gauges side by side
                        SizedBox(
                          height: 70,
                          child: Row(
                            children: [
                              Expanded(
                                child: CompactGauge(title: 'L', value: leftRpm, unit: 'rpm', color: Colors.green,),
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child:  CompactGauge(title: 'R', value: rightRpm, unit: 'rpm', color: Colors.green,),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Distance and Acceleration
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: ValueListenableBuilder<SerialData?>(
                            valueListenable: appState.currentData,
                            builder: (context, data, child) {
                              const distance =
                                  '0.0'; // Not available in new format
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
                                        ValueListenableBuilder<double>(
                                          valueListenable:
                                              appState.acceleration,
                                          builder: (context, accel, child) {
                                            return Text(
                                              '${accel.toStringAsFixed(1)} m/s²',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onSurface,
                                                fontFamily: 'Space Grotesk',
                                              ),
                                            );
                                          },
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
                        ValueListenableBuilder<TelemetryData?>(
                          valueListenable: appState.telemetryData,
                          builder: (context, telemetryData, child) {
                            return Container(
                              height: 70,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withOpacity(0.1),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    'Sensores QTR',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: List.generate(8, (index) {
                                      // Reverse order: sensor 1 on right, sensor 8 on left
                                      final reversedIndex = 7 - index;
                                      // All sensors 1-8 (indices 0-7) are active, telemetry sends values for all sensors
                                      final isActive = true;
                                      final sensorIndex = reversedIndex; // Map to telemetry array (0-7)

                                      final sensorValue = isActive &&
                                              telemetryData != null &&
                                              telemetryData.sensors.length >
                                                  sensorIndex
                                          ? telemetryData.sensors[
                                              sensorIndex] // Use telemetry QTR data
                                          : 0;
                                      final percentage =
                                          (sensorValue / 1023.0)
                                              .clamp(0.0, 1.0);

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
                                                          .surfaceContainerHighest
                                                      : Theme.of(context)
                                                          .colorScheme
                                                          .surfaceContainerHighest
                                                          .withOpacity(0.3),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          3),
                                                ),
                                                child: FractionallySizedBox(
                                                  alignment:
                                                      Alignment.bottomCenter,
                                                  heightFactor: isActive
                                                      ? percentage
                                                      : 0.0,
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: isActive
                                                          ? Colors.black
                                                          : Theme.of(context)
                                                              .colorScheme
                                                              .onSurfaceVariant
                                                              .withOpacity(
                                                                  0.3),
                                                      borderRadius:
                                                          BorderRadius
                                                              .circular(3),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 1),
                                            Column(
                                              children: [
                                                Text(
                                                  '$sensorValue',
                                                  style: TextStyle(
                                                    fontSize: 6,
                                                    color: isActive
                                                        ? Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant
                                                            .withOpacity(0.8)
                                                        : Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant
                                                            .withOpacity(0.3),
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                                Text(
                                                  '${reversedIndex + 1}',
                                                  style: TextStyle(
                                                    fontSize: 7,
                                                    color: isActive
                                                        ? Theme.of(context)
                                                            .colorScheme
                                                            .onSurface
                                                        : Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant
                                                            .withOpacity(0.5),
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      );
                                    }),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        // Motor and Line Following Information
                        MotorInfoSection(appState: appState),
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
        // Fixed remote control at bottom when in remote control mode
        ValueListenableBuilder<OperationMode>(
          valueListenable: appState.currentMode,
          builder: (context, mode, child) {
            if (mode == OperationMode.remoteControl) {
              return Positioned(
                bottom: 20,
                left: 20,
                right: 20,
                child: RemoteControl(appState: appState),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        NavigationMenu(appState: appState),
      ],
    ),
  );
}

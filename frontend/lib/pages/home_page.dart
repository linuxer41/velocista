import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../app_state.dart';
import '../arduino_data.dart';
import '../connection_bottom_sheet.dart';
import '../widgets/remote_control.dart';
import '../widgets/status_bar.dart';
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


  void _openPage(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => page),
    );
  }

  Widget _buildNavigationMenu() {
    final appState = AppInheritedWidget.of(context);
    final menuItems = [
      {'icon': Icons.tune, 'label': 'Ajustes', 'page': const ConfigPage()},
      {'icon': Icons.terminal, 'label': 'Terminal', 'page': TerminalPage(provider: appState!)},
      {'icon': Icons.show_chart, 'label': 'Gráficos', 'page': const GraphsPage()},
      {'icon': Icons.info, 'label': 'Info', 'page': AppSettingsPage(themeProvider: widget.themeProvider)},
    ];

    return Positioned(
      top: 60,
      right: 10,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: menuItems.map((item) {
            return Container(
              margin: const EdgeInsets.symmetric(vertical: 1),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openPage(item['page'] as Widget),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          item['icon'] as IconData,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        const SizedBox(height: 1),
                        Text(
                          item['label'] as String,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Modo Reposo - Monitoreo de Sensores',
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
                  label: const Text('Calibrar Sensores',
                      style: TextStyle(fontSize: 12)),
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
                    final debugCommand = DebugRequestCommand();
                    appState.sendCommand(debugCommand.toCommand());
                  },
                  icon: const Icon(Icons.sync, size: 16),
                  label: const Text('Obtener Debug',
                      style: TextStyle(fontSize: 12)),
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
                  label: const Text('Modo Seguidor',
                      style: TextStyle(fontSize: 12)),
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
                  label: const Text('Control Remoto',
                      style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    foregroundColor:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Debug Motores',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Space Grotesk',
            ),
          ),
          const SizedBox(height: 8),
          DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  tabs: const [
                    Tab(text: 'PWM'),
                    Tab(text: 'RPM'),
                  ],
                  labelStyle: const TextStyle(
                      fontSize: 12, fontFamily: 'Space Grotesk'),
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                SizedBox(
                  height: 160, // Fixed height for tab content
                  child: TabBarView(
                    children: [
                      // PWM Tab
                      Column(
                        children: [
                          const SizedBox(height: 8),
                          // Left PWM Slider
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PWM Izquierdo: ${_leftPwm.toInt()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              ValueListenableBuilder<ConfigData?>(
                                valueListenable: appState.configData,
                                builder: (context, config, child) {
                                  final maxPwm = config?.max != null && config!.max!.isNotEmpty
                                      ? config.max![0].toDouble()
                                      : 250.0;
                                  return Slider(
                                    value: _leftPwm.clamp(-maxPwm, maxPwm),
                                    min: -maxPwm,
                                    max: maxPwm,
                                    divisions: (maxPwm * 2).toInt(),
                                    onChanged: (value) {
                                      setState(() {
                                        _leftPwm = value;
                                        if (_syncMotors) {
                                          _rightPwm = value;
                                        }
                                      });
                                    },
                                    onChangeEnd: (value) {
                                      final pwmCommand = SetPwmCommand(
                                        rightPwm: _rightPwm.toInt(),
                                        leftPwm: _leftPwm.toInt(),
                                      );
                                      print(
                                          'Sending PWM command: ${pwmCommand.toCommand()}');
                                      appState.sendCommand(pwmCommand.toCommand());
                                    },
                                    activeColor: Theme.of(context).colorScheme.primary,
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Right PWM Slider
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PWM Derecho: ${_rightPwm.toInt()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              ValueListenableBuilder<ConfigData?>(
                                valueListenable: appState.configData,
                                builder: (context, config, child) {
                                  final maxPwm = config?.max != null && config!.max!.isNotEmpty
                                      ? config.max![0].toDouble()
                                      : 250.0;
                                  return Slider(
                                    value: _rightPwm.clamp(-maxPwm, maxPwm),
                                    min: -maxPwm,
                                    max: maxPwm,
                                    divisions: (maxPwm * 2).toInt(),
                                    onChanged: (value) {
                                      setState(() {
                                        _rightPwm = value;
                                        if (_syncMotors) {
                                          _leftPwm = value;
                                        }
                                      });
                                    },
                                    onChangeEnd: (value) {
                                      final pwmCommand = SetPwmCommand(
                                        rightPwm: _rightPwm.toInt(),
                                        leftPwm: _leftPwm.toInt(),
                                      );
                                      print(
                                          'Sending PWM command: ${pwmCommand.toCommand()}');
                                      appState.sendCommand(pwmCommand.toCommand());
                                    },
                                    activeColor: Theme.of(context).colorScheme.primary,
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      // RPM Tab
                      Column(
                        children: [
                          const SizedBox(height: 8),
                          // Left RPM Slider
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'RPM Izquierdo: ${_leftRpm.toInt()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              ValueListenableBuilder<ConfigData?>(
                                valueListenable: appState.configData,
                                builder: (context, config, child) {
                                  final maxRpm = config?.max != null && config!.max!.length >= 2
                                      ? config.max![1].toDouble()
                                      : 5000.0;
                                  return Slider(
                                    value: _leftRpm.clamp(-maxRpm, maxRpm),
                                    min: -maxRpm,
                                    max: maxRpm,
                                    divisions: (maxRpm * 2 / 10).toInt(),
                                    onChanged: (value) {
                                      setState(() {
                                        _leftRpm = value;
                                        if (_syncMotors) {
                                          _rightRpm = value;
                                        }
                                      });
                                    },
                                    onChangeEnd: (value) {
                                      final rpmCommand = SetRpmCommand(
                                        leftRpm: _leftRpm.toInt(),
                                        rightRpm: _rightRpm.toInt(),
                                      );
                                      print(
                                          'Sending RPM command: ${rpmCommand.toCommand()}');
                                      appState.sendCommand(rpmCommand.toCommand());
                                    },
                                    activeColor: Theme.of(context).colorScheme.secondary,
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Right RPM Slider
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'RPM Derecho: ${_rightRpm.toInt()}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              ValueListenableBuilder<ConfigData?>(
                                valueListenable: appState.configData,
                                builder: (context, config, child) {
                                  final maxRpm = config?.max != null && config!.max!.length >= 2
                                      ? config.max![1].toDouble()
                                      : 5000.0;
                                  return Slider(
                                    value: _rightRpm.clamp(-maxRpm, maxRpm),
                                    min: -maxRpm,
                                    max: maxRpm,
                                    divisions: (maxRpm * 2 / 10).toInt(),
                                    onChanged: (value) {
                                      setState(() {
                                        _rightRpm = value;
                                        if (_syncMotors) {
                                          _leftRpm = value;
                                        }
                                      });
                                    },
                                    onChangeEnd: (value) {
                                      final rpmCommand = SetRpmCommand(
                                        leftRpm: _leftRpm.toInt(),
                                        rightRpm: _rightRpm.toInt(),
                                      );
                                      print(
                                          'Sending RPM command: ${rpmCommand.toCommand()}');
                                      appState.sendCommand(rpmCommand.toCommand());
                                    },
                                    activeColor: Theme.of(context).colorScheme.secondary,
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: CheckboxListTile(
                  title: const Text(
                    'Sincronizar Motores',
                    style: TextStyle(fontSize: 12),
                  ),
                  value: _syncMotors,
                  onChanged: (value) {
                    setState(() {
                      _syncMotors = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _leftPwm = 0.0;
                      _rightPwm = 0.0;
                      _leftRpm = 0.0;
                      _rightRpm = 0.0;
                    });
                    final pwmCommand = SetPwmCommand(
                      rightPwm: 0,
                      leftPwm: 0,
                    );
                    final rpmCommand = SetRpmCommand(
                      leftRpm: 0,
                      rightRpm: 0,
                    );
                    appState.sendCommand(pwmCommand.toCommand());
                    appState.sendCommand(rpmCommand.toCommand());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  child: const Text('Reset Motores',
                      style: TextStyle(fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPidTabs(AppState appState) {
    return Container(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          _buildBaseSpeedTab(appState),
          const SizedBox(height: 4),
          _buildFeaturesControlBoard(appState),
        ],
      ),
    );
  }

  Widget _buildBaseSpeedTab(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Control toggles and buttons
          Column(
            children: [
              Row(
                children: [
                  // Cascade Control Toggle
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Control en Cascada',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Transform.scale(
                          scale: 0.8,
                          child: ValueListenableBuilder<ConfigData?>(
                            valueListenable: appState.configData,
                            builder: (context, config, child) {
                              final enabled = config?.cascade == 1;
                              return Switch(
                                value: enabled,
                                onChanged: (value) async {
                                  final cascadeCommand = CascadeCommand(value);
                                  await appState
                                      .sendCommand(cascadeCommand.toCommand());
                                  // Refresh config data
                                  await appState.sendCommand(
                                      ConfigRequestCommand().toCommand());
                                },
                                activeThumbColor:
                                    Theme.of(context).colorScheme.primary,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  // telemetry Control Toggle
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Telemetría',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Transform.scale(
                          scale: 0.8,
                          child: ValueListenableBuilder<ConfigData?>(
                            valueListenable: appState.configData,
                            builder: (context, config, child) {
                              final enabled = config?.telemetry == 1;
                              return Switch(
                                value: enabled,
                                onChanged: (value) async {
                                  // Update configData locally for immediate UI feedback
                                  final currentConfig =
                                      appState.configData.value;
                                  if (currentConfig != null) {
                                    final updatedConfig = ConfigData(
                                      lineKPid: currentConfig.lineKPid,
                                      leftKPid: currentConfig.leftKPid,
                                      rightKPid: currentConfig.rightKPid,
                                      base: currentConfig.base,
                                      wheels: currentConfig.wheels,
                                      mode: currentConfig.mode,
                                      cascade: currentConfig.cascade,
                                      telemetry: value ? 1 : 0,
                                      featConfig: currentConfig.featConfig,
                                    );
                                    appState.configData.value = updatedConfig;
                                  }

                                  final telemetryCommand =
                                      TelemetryChangeCommand(value);
                                  await appState.sendCommand(
                                      telemetryCommand.toCommand());
                                  // Small delay to allow Arduino to process the command
                                  await Future.delayed(const Duration(milliseconds: 100));
                                  // Refresh config data to confirm
                                  await appState.sendCommand(
                                      ConfigRequestCommand().toCommand());
                                },
                                activeThumbColor:
                                    Theme.of(context).colorScheme.secondary,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Sync with Telemetry Icon Button
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Sincronizar',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            onPressed: () async {
                              // Call get config to get config data including FEAT_CONFIG
                              final configCommand = ConfigRequestCommand();
                              await appState
                                  .sendCommand(configCommand.toCommand());
                            },
                            icon: Icon(
                              Icons.sync,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
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
                  // Calibrate Button
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Calibrar',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            onPressed: () async {
                              await appState.sendCommand(
                                  ConfigRequestCommand().toCommand());
                              final calibrateCommand = CalibrateQtrCommand();
                              appState
                                  .sendCommand(calibrateCommand.toCommand());
                            },
                            icon: Icon(
                              Icons.adjust,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                              size: 16,
                            ),
                            tooltip: 'Calibrar Sensores',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Save Button
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Grabar',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            onPressed: () async {
                              // Show confirmation dialog
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Confirmar Grabado'),
                                  content: const Text(
                                    'Los valores actuales se guardarán en EEPROM. Una vez que reinicies tu robot, esos valores se guardarán permanentemente.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text('Grabar'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                await appState.sendCommand(
                                    ConfigRequestCommand().toCommand());
                                final saveCommand = EepromSaveCommand();
                                appState.sendCommand(saveCommand.toCommand());
                              }
                            },
                            icon: Icon(
                              Icons.save,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onTertiaryContainer,
                              size: 16,
                            ),
                            tooltip: 'Grabar Configuración',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Autotune Button
                   Expanded(
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Text(
                           'Autotune',
                           style: TextStyle(
                             fontSize: 10,
                             fontWeight: FontWeight.w500,
                             color:
                                 Theme.of(context).colorScheme.onSurfaceVariant,
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
                             onPressed: () async {
                               final autotuneCommand = AutotuneCommand();
                               appState.sendCommand(autotuneCommand.toCommand());
                             },
                             icon: Icon(
                               Icons.auto_fix_high,
                               color: Theme.of(context)
                                   .colorScheme
                                   .onPrimaryContainer,
                               size: 16,
                             ),
                             tooltip: 'Ajustar PID automáticamente',
                             padding: EdgeInsets.zero,
                             constraints: const BoxConstraints(),
                           ),
                         ),
                       ],
                     ),
                   ),
                   // Reset Button
                   Expanded(
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Text(
                           'Resetear',
                           style: TextStyle(
                             fontSize: 10,
                             fontWeight: FontWeight.w500,
                             color:
                                 Theme.of(context).colorScheme.onSurfaceVariant,
                           ),
                         ),
                         Container(
                           width: 32,
                           height: 32,
                           decoration: BoxDecoration(
                             color: Theme.of(context).colorScheme.errorContainer,
                             borderRadius: BorderRadius.circular(6),
                           ),
                           child: IconButton(
                             onPressed: () async {
                               // Show confirmation dialog
                               final confirmed = await showDialog<bool>(
                                 context: context,
                                 builder: (context) => AlertDialog(
                                   title: const Text('Confirmar Reseteo'),
                                   content: const Text(
                                     '¿Está seguro de resetear los valores por defecto y limpiar la EEPROM? Se borrará toda tu configuración.',
                                   ),
                                   actions: [
                                     TextButton(
                                       onPressed: () =>
                                           Navigator.of(context).pop(false),
                                       child: const Text('Cancelar'),
                                     ),
                                     TextButton(
                                       onPressed: () =>
                                           Navigator.of(context).pop(true),
                                       child: const Text('Resetear'),
                                     ),
                                   ],
                                 ),
                               );

                               if (confirmed == true) {
                                 await appState.sendCommand(
                                     ConfigRequestCommand().toCommand());
                                 final resetCommand = FactoryResetCommand();
                                 appState.sendCommand(resetCommand.toCommand());
                               }
                             },
                             icon: Icon(
                               Icons.refresh,
                               color: Theme.of(context)
                                   .colorScheme
                                   .onErrorContainer,
                               size: 16,
                             ),
                             tooltip: 'Resetear Valores',
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
        ],
      ),
    );
  }





  Widget _buildFeaturesControlBoard(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Funciones de Seguimiento de Línea',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Space Grotesk',
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<ConfigData?>(
            valueListenable: appState.configData,
            builder: (context, configData, child) {
              // Always show labels, use default values if featConfig is null
              final currentFeatures = configData?.featConfig ?? [1, 1, 1, 1, 1, 1, 0, 0, 0];

              const featureNames = ['MED', 'MA', 'KAL', 'HYS', 'DZ', 'LP', 'APID', 'SP', 'DIR'];
              const featureDescriptions = [
                'Filtro Mediano',
                'Media Móvil',
                'Filtro Kalman',
                'Histeresis',
                'Zona Muerta',
                'Pasa Bajos',
                'PID Adaptativo',
                'Perfil Velocidad',
                'Dirección Giro'
              ];

              return Column(
                children: [
                  // First row: MED, MA, KAL
                  Row(
                    children: List.generate(3, (index) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          child: Column(
                            children: [
                              Text(
                                featureNames[index],
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                featureDescriptions[index],
                                style: TextStyle(
                                  fontSize: 6,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 2),
                              Switch(
                                value: currentFeatures[index] == 1,
                                onChanged: (value) async {
                                  final newValue = value ? 1 : 0;
                                  // Update configData locally for immediate UI feedback
                                  final currentConfig = appState.configData.value;
                                  if (currentConfig != null && currentConfig.featConfig != null) {
                                    final updatedFeatConfig = List<int>.from(currentConfig.featConfig!);
                                    updatedFeatConfig[index] = newValue;
                                    final updatedConfig = ConfigData(
                                      lineKPid: currentConfig.lineKPid,
                                      leftKPid: currentConfig.leftKPid,
                                      rightKPid: currentConfig.rightKPid,
                                      base: currentConfig.base,
                                      wheels: currentConfig.wheels,
                                      mode: currentConfig.mode,
                                      cascade: currentConfig.cascade,
                                      telemetry: currentConfig.telemetry,
                                      featConfig: updatedFeatConfig,
                                    );
                                    appState.configData.value = updatedConfig;
                                  }

                                  final featureCommand =
                                      FeatureCommand(index, newValue);
                                  await appState.sendCommand(
                                      featureCommand.toCommand());
                                  // Small delay to allow Arduino to process the command
                                  await Future.delayed(const Duration(milliseconds: 100));
                                  // Request fresh config data to sync UI
                                  await appState.sendCommand(
                                      ConfigRequestCommand().toCommand());
                                },
                                activeThumbColor:
                                    Theme.of(context).colorScheme.primary,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  // Second row: HYS, DZ, LP
                  Row(
                    children: List.generate(3, (index) {
                      final actualIndex = index + 3; // 3, 4, 5
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          child: Column(
                            children: [
                              Text(
                                featureNames[actualIndex],
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                featureDescriptions[actualIndex],
                                style: TextStyle(
                                  fontSize: 6,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 2),
                              Switch(
                                value: currentFeatures[actualIndex] == 1,
                                onChanged: (value) async {
                                  final newValue = value ? 1 : 0;
                                  // Update configData locally for immediate UI feedback
                                  final currentConfig = appState.configData.value;
                                  if (currentConfig != null && currentConfig.featConfig != null) {
                                    final updatedFeatConfig = List<int>.from(currentConfig.featConfig!);
                                    updatedFeatConfig[actualIndex] = newValue;
                                    final updatedConfig = ConfigData(
                                      lineKPid: currentConfig.lineKPid,
                                      leftKPid: currentConfig.leftKPid,
                                      rightKPid: currentConfig.rightKPid,
                                      base: currentConfig.base,
                                      wheels: currentConfig.wheels,
                                      mode: currentConfig.mode,
                                      cascade: currentConfig.cascade,
                                      telemetry: currentConfig.telemetry,
                                      featConfig: updatedFeatConfig,
                                    );
                                    appState.configData.value = updatedConfig;
                                  }

                                  final featureCommand =
                                      FeatureCommand(actualIndex, newValue);
                                  await appState.sendCommand(
                                      featureCommand.toCommand());
                                  // Small delay to allow Arduino to process the command
                                  await Future.delayed(const Duration(milliseconds: 100));
                                  // Request fresh config data to sync UI
                                  await appState.sendCommand(
                                      ConfigRequestCommand().toCommand());
                                },
                                activeThumbColor:
                                    Theme.of(context).colorScheme.primary,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  // Third row: APID, SP, DIR
                  Row(
                    children: List.generate(3, (index) {
                      final actualIndex = index + 6; // 6, 7, 8
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          child: Column(
                            children: [
                              Text(
                                featureNames[actualIndex],
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                featureDescriptions[actualIndex],
                                style: TextStyle(
                                  fontSize: 6,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 2),
                              Switch(
                                value: currentFeatures[actualIndex] == 1,
                                onChanged: (value) async {
                                  final newValue = value ? 1 : 0;
                                  // Update configData locally for immediate UI feedback
                                  final currentConfig = appState.configData.value;
                                  if (currentConfig != null && currentConfig.featConfig != null) {
                                    final updatedFeatConfig = List<int>.from(currentConfig.featConfig!);
                                    updatedFeatConfig[actualIndex] = newValue;
                                    final updatedConfig = ConfigData(
                                      lineKPid: currentConfig.lineKPid,
                                      leftKPid: currentConfig.leftKPid,
                                      rightKPid: currentConfig.rightKPid,
                                      base: currentConfig.base,
                                      wheels: currentConfig.wheels,
                                      mode: currentConfig.mode,
                                      cascade: currentConfig.cascade,
                                      telemetry: currentConfig.telemetry,
                                      featConfig: updatedFeatConfig,
                                    );
                                    appState.configData.value = updatedConfig;
                                  }

                                  final featureCommand =
                                      FeatureCommand(actualIndex, newValue);
                                  await appState.sendCommand(
                                      featureCommand.toCommand());
                                  // Small delay to allow Arduino to process the command
                                  await Future.delayed(const Duration(milliseconds: 100));
                                  // Request fresh config data to sync UI
                                  await appState.sendCommand(
                                      ConfigRequestCommand().toCommand());
                                },
                                activeThumbColor:
                                    Theme.of(context).colorScheme.primary,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: ValueListenableBuilder<OperationMode>(
                            valueListenable: appState.currentMode,
                            builder: (context, mode, child) {
                              return ValueListenableBuilder<TelemetryData?>(
                                valueListenable: appState.telemetryData,
                                builder: (context, telemetryData, child) {
                                  return ValueListenableBuilder<DebugData?>(
                                    valueListenable: appState.debugData,
                                    builder: (context, debugData, child) {
                                      // Extract data with defaults
                                      final leftData = telemetryData?.left ??
                                          [
                                            0.0,
                                            0.0,
                                            0.0,
                                            0,
                                            0.0,
                                            0.0,
                                            0.0,
                                            0.0
                                          ];
                                      final rightData = telemetryData?.right ??
                                          [
                                            0.0,
                                            0.0,
                                            0.0,
                                            0,
                                            0.0,
                                            0.0,
                                            0.0,
                                            0.0
                                          ];
                                      final lineData = telemetryData?.line ??
                                          [0.0, 0.0, 0.0, 0.0, 0.0];
                                      final pidData = telemetryData?.pid ?? [0.0, 0.0, 0.0];
                                      final config = appState.configData.value;
                                      final lineKPid = config?.lineKPid ?? [0.900, 0.010, 0.020];
                                      final leftKPid = config?.leftKPid ?? [0.590, 0.001, 0.0025];
                                      final rightKPid = config?.rightKPid ?? [0.590, 0.001, 0.050];
                                      final baseData = config?.base ?? [200.0, 120.0];
                                      final maxData = config?.max ?? [230.0, 300.0];
                                      final wheelsData = config?.wheels ?? [32.0, 85.0];
                                      final weightData = config?.weight ?? 155.0;
                                      final sampRateData = config?.sampRate ?? [2, 1, 100];
                                      final modeData = config?.mode ?? 0;
                                      final cascadeData = config?.cascade ?? 1;
                                      final telemetryConfig = config?.telemetry ?? 0;

                                      // Left motor
                                      final leftRpm = leftData.isNotEmpty
                                          ? leftData[0]
                                          : 0.0;
                                      final leftTargetRpm = leftData.length > 1
                                          ? leftData[1]
                                          : 0.0;
                                      final leftPwm = leftData.length > 2
                                          ? leftData[2]
                                          : 0.0;
                                      final leftEncoder = leftData.length > 3
                                          ? leftData[3].toInt()
                                          : 0;
                                      final leftDirection = leftData.length > 4
                                          ? leftData[4]
                                          : 0.0;
                                      final leftIntegral = leftData.length > 5
                                          ? leftData[5]
                                          : 0.0;
                                      final leftDerivative = leftData.length > 6
                                          ? leftData[6]
                                          : 0.0;
                                      final leftError = leftData.length > 7
                                          ? leftData[7]
                                          : 0.0;

                                      // Right motor
                                      final rightRpm = rightData.isNotEmpty
                                          ? rightData[0]
                                          : 0.0;
                                      final rightTargetRpm =
                                          rightData.length > 1
                                              ? rightData[1]
                                              : 0.0;
                                      final rightPwm = rightData.length > 2
                                          ? rightData[2]
                                          : 0.0;
                                      final rightEncoder = rightData.length > 3
                                          ? rightData[3].toInt()
                                          : 0;
                                      final rightDirection =
                                          rightData.length > 4
                                              ? rightData[4]
                                              : 0.0;
                                      final rightIntegral = rightData.length > 5
                                          ? rightData[5]
                                          : 0.0;
                                      final rightDerivative =
                                          rightData.length > 6
                                              ? rightData[6]
                                              : 0.0;
                                      final rightError = rightData.length > 7
                                          ? rightData[7]
                                          : 0.0;

                                      // Line following
                                      final lineError = lineData.length > 1
                                          ? lineData[1]
                                          : 0.0;
                                      final lineIntegral = lineData.length > 2
                                          ? lineData[2]
                                          : 0.0;
                                      final lineDerivative = lineData.length > 3
                                          ? lineData[3]
                                          : 0.0;

                                      return Column(
                                        children: [
                                          // Motor Information - 3 Column Layout
                                          Row(
                                            children: [
                                              // Left Motor
                                              Expanded(
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  margin: const EdgeInsets.only(
                                                      right: 2),
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHighest
                                                        .withOpacity(0.5),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Motor Izquierdo',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                          fontFamily:
                                                              'Space Grotesk',
                                                        ),
                                                      ),
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        'RPM Actual: ${leftRpm.toStringAsFixed(1)}',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                      Text(
                                                        'RPM Objetivo: ${leftTargetRpm.toStringAsFixed(1)}',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                      Text(
                                                        'PWM Actual: ${leftPwm.toStringAsFixed(0)}',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Encoder: $leftEncoder',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Dirección: ${leftDirection.toStringAsFixed(1)}',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Error: ${leftError.toStringAsFixed(1)}',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Integral: ${leftIntegral.toStringAsFixed(1)}',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Derivada: ${leftDerivative.toStringAsFixed(1)}',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              // Right Motor
                                              Expanded(
                                                child: Container(
                                                  padding:
                                                      const EdgeInsets.all(8),
                                                  margin: const EdgeInsets.only(
                                                      left: 2),
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .surfaceContainerHighest
                                                        .withOpacity(0.5),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        'Motor Derecho',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .onSurface,
                                                          fontFamily:
                                                              'Space Grotesk',
                                                        ),
                                                      ),
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        'RPM Actual: ${rightRpm.toStringAsFixed(1)}',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                      Text(
                                                        'RPM Objetivo: ${rightTargetRpm.toStringAsFixed(1)}',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                      Text(
                                                        'PWM Actual: ${rightPwm.toStringAsFixed(0)}',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Encoder: $rightEncoder',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Dirección: ${rightDirection.toStringAsFixed(1)}',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Error: ${rightError.toStringAsFixed(1)}',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Integral: ${rightIntegral.toStringAsFixed(1)}',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Derivada: ${rightDerivative.toStringAsFixed(1)}',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          // Line Following below motors
                                          if (mode ==
                                              OperationMode.lineFollowing)
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest
                                                    .withOpacity(0.5),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Seguimiento',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .onSurface,
                                                      fontFamily:
                                                          'Space Grotesk',
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              'Posición: ${lineData[0].toStringAsFixed(1)}',
                                                              style: TextStyle(
                                                                fontSize: 9,
                                                                color: Theme.of(context)
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                              ),
                                                            ),
                                                            Text(
                                                              'Error: ${lineData[1].toStringAsFixed(1)}',
                                                              style: TextStyle(
                                                                fontSize: 9,
                                                                color: Theme.of(context)
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                              ),
                                                            ),
                                                            Text(
                                                              'Integral: ${lineData[2].toStringAsFixed(1)}',
                                                              style: TextStyle(
                                                                fontSize: 9,
                                                                color: Theme.of(context)
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              'Derivada: ${lineData[3].toStringAsFixed(1)}',
                                                              style: TextStyle(
                                                                fontSize: 9,
                                                                color: Theme.of(context)
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                              ),
                                                            ),
                                                            Text(
                                                              'Salida PID: ${lineData[4].toStringAsFixed(1)}',
                                                              style: TextStyle(
                                                                fontSize: 9,
                                                                color: Theme.of(context)
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          'Curvatura: ${telemetryData?.curv?.toStringAsFixed(1) ?? '0.0'}',
                                                          style: TextStyle(
                                                            fontSize: 9,
                                                            color: Theme.of(context)
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  // Features status
                                                  ValueListenableBuilder<
                                                      ConfigData?>(
                                                    valueListenable:
                                                        appState.configData,
                                                    builder: (context,
                                                        configData, child) {
                                                      final featConfig = configData?.featConfig;
                                                      if (featConfig == null ||
                                                          featConfig.length !=
                                                              8) {
                                                        return const SizedBox
                                                            .shrink();
                                                      }

                                                      final featureNames = [
                                                        'MED',
                                                        'MA',
                                                        'KAL',
                                                        'HYS',
                                                        'DZ',
                                                        'LP',
                                                        'APID',
                                                        'SP',
                                                        'DIR'
                                                      ];
                                                      final activeFeatures =
                                                          <String>[];

                                                      for (int i = 0;
                                                          i < featConfig.length;
                                                          i++) {
                                                        if (featConfig[i] ==
                                                            1) {
                                                          activeFeatures.add(
                                                              featureNames[i]);
                                                        }
                                                      }

                                                      if (activeFeatures
                                                          .isEmpty) {
                                                        return Text(
                                                          'Features: ninguno activo',
                                                          style: TextStyle(
                                                            fontSize: 8,
                                                            color: Theme.of(
                                                                    context)
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                          ),
                                                        );
                                                      }

                                                      return Text(
                                                        'Features: ${activeFeatures.join(', ')}',
                                                        style: TextStyle(
                                                          fontSize: 8,
                                                          color: Theme.of(
                                                                  context)
                                                              .colorScheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      );
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          const SizedBox(height: 10),
                                          // Config Data - Expandable Accordion
                                          Container(
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .surfaceContainerHighest
                                                  .withOpacity(0.5),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: ExpansionTile(
                                              shape: Border.all(
                                                  width: 0,
                                                  color: Colors.transparent),
                                              title: Text(
                                                'Datos de Configuración',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onSurface,
                                                  fontFamily: 'Space Grotesk',
                                                ),
                                              ),
                                              initiallyExpanded:
                                                  _configExpanded,
                                              onExpansionChanged: (expanded) {
                                                setState(() {
                                                  _configExpanded = expanded;
                                                });
                                              },
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.all(12),
                                                  child: Column(
                                                    children: [
                                                      // 3 Column PID Layout
                                                      Row(
                                                        children: [
                                                          // Línea Column
                                                          Expanded(
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(8),
                                                              margin:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      right: 2),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .surface,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            6),
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                    'Línea',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurface,
                                                                    ),
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                  ),
                                                                  const SizedBox(
                                                                      height:
                                                                          4),
                                                                  Text(
                                                                    'KP: ${lineKPid[0].toStringAsFixed(3)}',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          9,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    'KI: ${lineKPid[1].toStringAsFixed(3)}',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          9,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    'KD: ${lineKPid[2].toStringAsFixed(3)}',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          9,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          // Izquierdo Column
                                                          Expanded(
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(8),
                                                              margin:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          2),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .surface,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            6),
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                    'Izquierdo',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurface,
                                                                    ),
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                  ),
                                                                  const SizedBox(
                                                                      height:
                                                                          4),
                                                                  Text(
                                                                    'KP: ${leftKPid[0].toStringAsFixed(3)}',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          9,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    'KI: ${leftKPid[1].toStringAsFixed(3)}',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          9,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    'KD: ${leftKPid[2].toStringAsFixed(3)}',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          9,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          // Derecho Column
                                                          Expanded(
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(8),
                                                              margin:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      left: 2),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .surface,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            6),
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                    'Derecho',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurface,
                                                                    ),
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                  ),
                                                                  const SizedBox(
                                                                      height:
                                                                          4),
                                                                  Text(
                                                                    'KP: ${rightKPid[0].toStringAsFixed(3)}',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          9,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    'KI: ${rightKPid[1].toStringAsFixed(3)}',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          9,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    'KD: ${rightKPid[2].toStringAsFixed(3)}',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          9,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      // Base, Max and Wheels
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(8),
                                                              margin:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      right: 2),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .surface,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            6),
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                    'Base',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurface,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                      height:
                                                                          4),
                                                                  Text(
                                                                    'rpm: ${baseData[1].toStringAsFixed(1)}',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          9,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    'pwm: ${baseData[0].toStringAsFixed(0)}',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          9,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          Expanded(
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(8),
                                                              margin:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                      horizontal:
                                                                          2),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .surface,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            6),
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                    'Max',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurface,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                      height:
                                                                          4),
                                                                  Text(
                                                                    'rpm: ${maxData[1].toStringAsFixed(1)}',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          9,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    'pwm: ${maxData[0].toStringAsFixed(0)}',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          9,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          Expanded(
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(8),
                                                              margin:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      left: 2),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .surface,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            6),
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                    'Ruedas',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurface,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                      height:
                                                                          4),
                                                                  Text(
                                                                    'Diam.: ${wheelsData[0].toStringAsFixed(2)}',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          9,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    'Sep.: ${wheelsData[1].toStringAsFixed(2)}',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          9,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      // Weight and Sampling Rate
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(8),
                                                              margin:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      right: 2),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .surface,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            6),
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                    'Peso',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurface,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                      height:
                                                                          4),
                                                                  Text(
                                                                    '${weightData.toStringAsFixed(1)} g',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          9,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          Expanded(
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .all(8),
                                                              margin:
                                                                  const EdgeInsets
                                                                      .only(
                                                                      left: 2),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .surface,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            6),
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                    'Muestreo',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurface,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                      height:
                                                                          4),
                                                                  Text(
                                                                    'Línea: ${sampRateData.isNotEmpty ? sampRateData[0] : 2}ms',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          9,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    'Velocidad: ${sampRateData.length > 1 ? sampRateData[1] : 1}ms',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          9,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    'Telemetría: ${sampRateData.length > 2 ? sampRateData[2] : 100}ms',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          9,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      // Operation and Control
                                                      Container(
                                                        width: double.infinity,
                                                        padding:
                                                            const EdgeInsets
                                                                .all(8),
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .surface,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(6),
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Text(
                                                              'Operación y Control',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Theme.of(
                                                                        context)
                                                                    .colorScheme
                                                                    .onSurface,
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                height: 4),
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                  child: Text(
                                                                    'Modo: ${modeData == 0 ? 'Reposo' : modeData == 1 ? 'Seguimiento' : 'Remoto'}',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          9,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                ),
                                                                Expanded(
                                                                  child: Text(
                                                                    'Cascada: ${cascadeData == 1 ? 'Activada' : 'Desactivada'}',
                                                                    style:
                                                                        TextStyle(
                                                                      fontSize:
                                                                          9,
                                                                      color: Theme.of(
                                                                              context)
                                                                          .colorScheme
                                                                          .onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(height: 2),
                                                            Text(
                                                              'Telemetría: ${telemetryConfig == 1 ? 'Activada' : 'Desactivada'}',
                                                              style: TextStyle(
                                                                fontSize: 9,
                                                                color: Theme.of(context)
                                                                    .colorScheme
                                                                    .onSurfaceVariant,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      // Features Status
                                                      ValueListenableBuilder<
                                                          ConfigData?>(
                                                        valueListenable:
                                                            appState.configData,
                                                        builder: (context,
                                                            configData, child) {
                                                          final featConfig = configData?.featConfig;
                                                          if (featConfig ==
                                                                  null ||
                                                              featConfig
                                                                      .length !=
                                                                  9) {
                                                            return const SizedBox
                                                                .shrink();
                                                          }

                                                          return Container(
                                                            width:
                                                                double.infinity,
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(8),
                                                            decoration:
                                                                BoxDecoration(
                                                              color: Theme.of(
                                                                      context)
                                                                  .colorScheme
                                                                  .surface,
                                                              borderRadius:
                                                                  BorderRadius
                                                                      .circular(
                                                                          6),
                                                            ),
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  'Features',
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color: Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .onSurface,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                    height: 4),
                                                                Text(
                                                                  'MED:${featConfig[0]} MA:${featConfig[1]} KAL:${featConfig[2]} HYS:${featConfig[3]} DZ:${featConfig[4]} LP:${featConfig[5]} APID:${featConfig[6]} SP:${featConfig[7]} DIR:${featConfig[8]}',
                                                                  style:
                                                                      TextStyle(
                                                                    fontSize: 8,
                                                                    color: Theme.of(
                                                                            context)
                                                                        .colorScheme
                                                                        .onSurfaceVariant,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
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
          _buildNavigationMenu(),
        ],
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
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
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

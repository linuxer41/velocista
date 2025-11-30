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
  late TextEditingController _baseSpeedController;
  late TextEditingController _baseRpmController;

  late TextEditingController _lineKpController;
  late TextEditingController _lineKiController;
  late TextEditingController _lineKdController;

  bool _configExpanded = false;

  @override
  void initState() {
    super.initState();

    // Initialize controllers
    _baseSpeedController = TextEditingController(text: '200');
    _baseRpmController = TextEditingController(text: '120.0');
    _lineKpController = TextEditingController(text: '2.0');
    _lineKiController = TextEditingController(text: '0.05');
    _lineKdController = TextEditingController(text: '0.75');

    // Show connection modal automatically if not connected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = AppInheritedWidget.of(context);
      if (appState != null) {
        appState.isConnected.addListener(_onConnectionChanged);
        appState.lastAck.addListener(_onAckReceived);
        appState.baseSpeed.addListener(_updateBaseControllers);
        appState.baseRpm.addListener(_updateBaseControllers);
        appState.pidConfig.addListener(_updateLinePidControllers);
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
      appState.baseSpeed.removeListener(_updateBaseControllers);
      appState.baseRpm.removeListener(_updateBaseControllers);
      appState.pidConfig.removeListener(_updateLinePidControllers);
    }
    _baseSpeedController.dispose();
    _baseRpmController.dispose();
    _lineKpController.dispose();
    _lineKiController.dispose();
    _lineKdController.dispose();
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

  void _updateBaseControllers() {
    final appState = AppInheritedWidget.of(context);
    if (appState != null) {
      if (appState.baseSpeed.value != null) {
        _baseSpeedController.text = appState.baseSpeed.value!.toStringAsFixed(0);
      }
      if (appState.baseRpm.value != null) {
        _baseRpmController.text = appState.baseRpm.value!.toStringAsFixed(1);
      }
    }
  }

  void _updateLinePidControllers() {
    final appState = AppInheritedWidget.of(context);
    if (appState != null) {
      final config = appState.pidConfig.value;
      _lineKpController.text = config.kp.toStringAsFixed(2);
      _lineKiController.text = config.ki.toStringAsFixed(3);
      _lineKdController.text = config.kd.toStringAsFixed(2);
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
                        Theme.of(context).colorScheme.surfaceVariant,
                    foregroundColor:
                        Theme.of(context).colorScheme.onSurfaceVariant,
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
      length: 4,
      child: Column(
        children: [
          _buildBaseSpeedTab(appState),
          TabBar(
            tabs: const [
              Tab(text: 'PID Línea'),
              Tab(text: 'PID Izquierdo'),
              Tab(text: 'PID Derecho'),
              Tab(text: 'Filtros'),
            ],
            labelStyle:
                const TextStyle(fontSize: 12, fontFamily: 'Space Grotesk'),
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor:
                Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          SizedBox(
            height: 200, // Fixed height for the tab content
            child: TabBarView(
              children: [
                _buildLinePidTab(appState),
                LeftPidControl(appState: appState),
                RightPidControl(appState: appState),
                _buildFiltersTab(appState),
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
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Transform.scale(
                          scale: 0.8,
                          child: ValueListenableBuilder<bool>(
                            valueListenable: appState.cascadeEnabled,
                            builder: (context, enabled, child) {
                              return Switch(
                                value: enabled,
                                onChanged: (value) {
                                  appState.cascadeEnabled.value = value;
                                  final cascadeCommand = CascadeCommand(value);
                                  appState.sendCommand(cascadeCommand.toCommand());
                                },
                                activeColor: Theme.of(context).colorScheme.primary,
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
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Transform.scale(
                          scale: 0.8,
                          child: ValueListenableBuilder<bool>(
                            valueListenable: appState.telemetryEnabled,
                            builder: (context, enabled, child) {
                              return Switch(
                                value: enabled,
                                onChanged: (value) {
                                  appState.telemetryEnabled.value = value;
                                  final telemetryCommand =
                                      TelemetryEnableCommand(value);
                                  appState.sendCommand(telemetryCommand.toCommand());
                                },
                                activeColor: Theme.of(context).colorScheme.secondary,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                            onPressed: () async {
                              await appState.sendCommand(ConfigRequestCommand().toCommand());
                              final configCommand = ConfigRequestCommand();
                              appState.sendCommand(configCommand.toCommand());
                            },
                            icon: Icon(
                              Icons.sync,
                              color:
                                  Theme.of(context).colorScheme.onPrimaryContainer,
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
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            onPressed: () async {
                              await appState.sendCommand(ConfigRequestCommand().toCommand());
                              final calibrateCommand = CalibrateQtrCommand();
                              appState.sendCommand(calibrateCommand.toCommand());
                            },
                            icon: Icon(
                              Icons.tune,
                              color:
                                  Theme.of(context).colorScheme.onSecondaryContainer,
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
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.tertiaryContainer,
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
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text('Grabar'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                await appState.sendCommand(ConfigRequestCommand().toCommand());
                                final saveCommand = EepromSaveCommand();
                                appState.sendCommand(saveCommand.toCommand());
                              }
                            },
                            icon: Icon(
                              Icons.save,
                              color:
                                  Theme.of(context).colorScheme.onTertiaryContainer,
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
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                      onPressed: () => Navigator.of(context).pop(false),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(context).pop(true),
                                      child: const Text('Resetear'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                await appState.sendCommand(ConfigRequestCommand().toCommand());
                                final resetCommand = FactoryResetCommand();
                                appState.sendCommand(resetCommand.toCommand());
                              }
                            },
                            icon: Icon(
                              Icons.refresh,
                              color:
                                  Theme.of(context).colorScheme.onErrorContainer,
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
          const SizedBox(height: 8),
          // Base speed inputs below the buttons
          Row(
            children: [
              Expanded(
                child: _buildBaseSpeedInput('Velocidad Base', _baseSpeedController, () {
                  final value = double.tryParse(_baseSpeedController.text) ?? 200.0;
                  final baseSpeedCommand = BaseSpeedCommand(value);
                  appState.sendCommand(baseSpeedCommand.toCommand());
                }),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildBaseSpeedInput('RPM Base', _baseRpmController, () {
                  final value = double.tryParse(_baseRpmController.text) ?? 120.0;
                  final baseRpmCommand = BaseRpmCommand(value);
                  appState.sendCommand(baseRpmCommand.toCommand());
                }),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBaseSpeedInput(
      String label, TextEditingController controller, VoidCallback onSend) {
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
                height: 32,
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: controller.text,
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withOpacity(0.5),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide(
                        color: Theme.of(context)
                            .colorScheme
                            .outline
                            .withOpacity(0.3),
                      ),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
              height: 32,
              child: ElevatedButton(
                onPressed: onSend,
                child: const Text('Enviar', style: TextStyle(fontSize: 10)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 4),
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
            'PID Línea',
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
                child: _buildPidInput('Kp', _lineKpController),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPidInput('Ki', _lineKiController),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildPidInput('Kd', _lineKdController),
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
                final kp = double.tryParse(_lineKpController.text) ?? 2.0;
                final ki = double.tryParse(_lineKiController.text) ?? 0.05;
                final kd = double.tryParse(_lineKdController.text) ?? 0.75;
                final pidCommand = PidCommand(
                  type: 'line',
                  kp: kp,
                  ki: ki,
                  kd: kd,
                );
                appState.sendCommand(pidCommand.toCommand());
              },
              child: const Text('Actualizar PID Línea',
                  style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Current Values Display
          ValueListenableBuilder<SerialData?>(
            valueListenable: appState.currentData,
            builder: (context, data, child) {
              if (data is! DebugData) return const SizedBox.shrink();

              final position = data.line != null && data.line!.isNotEmpty ? data.line![0] : 0.0;

              return Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color:
                        Theme.of(context).colorScheme.outline.withOpacity(0.3),
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
                      'Posición: ${position.toStringAsFixed(1)}',
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

  Widget _buildFiltersTab(AppState appState) {
    const filterNames = ['MED', 'MA', 'KAL', 'HYS', 'DZ', 'LP'];
    const filterDescriptions = [
      'Mediano',
      'Media Móvil',
      'Kalman',
      'Histeresis',
      'Zona Muerta',
      'Pasa Bajos'
    ];

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
            'Filtros de Seguimiento de Línea',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Space Grotesk',
            ),
          ),
          const SizedBox(height: 8),
          ValueListenableBuilder<List<int>?>(
            valueListenable: appState.filters,
            builder: (context, filters, child) {
              if (filters == null || filters.length != 6) {
                return const Text('Cargando filtros...');
              }

              return Column(
                children: List.generate(6, (index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                filterNames[index],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              Text(
                                filterDescriptions[index],
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: filters[index] == 1,
                          onChanged: (value) {
                            final newFilters = List<int>.from(filters);
                            newFilters[index] = value ? 1 : 0;
                            appState.filters.value = newFilters;
                            final filtersCommand = FiltersCommand(newFilters);
                            appState.sendCommand(filtersCommand.toCommand());
                          },
                          activeColor: Theme.of(context).colorScheme.primary,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPidInput(String label, TextEditingController controller) {
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
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: controller.text,
              hintStyle: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withOpacity(0.5),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                StatusBar(
                    appState: appState!,
                    onShowConnectionModal: _showConnectionModal),

                // Gauges Layout
                ValueListenableBuilder<TelemetryData?>(
                  valueListenable: appState.telemetryData,
                  builder: (context, data, child) {
                    // Use telemetry data for live displays
                    final leftRpm = (data != null &&
                            data.left != null &&
                            data.left!.length >= 1)
                        ? data.left![0] // RPM from telemetry data
                        : 0.0;
                    final rightRpm = (data != null &&
                            data.right != null &&
                            data.right!.length >= 1)
                        ? data.right![0] // RPM from telemetry data
                        : 0.0;
                    final leftSpeed = (data != null &&
                            data.speedCms != null &&
                            data.speedCms!.length >= 1)
                        ? data.speedCms![0] / 100 // cm/s to m/s
                        : leftRpm * 0.036 / 3.6; // RPM to m/s
                    final rightSpeed = (data != null &&
                            data.speedCms != null &&
                            data.speedCms!.length >= 2)
                        ? data.speedCms![1] / 100 // cm/s to m/s
                        : rightRpm * 0.036 / 3.6; // RPM to m/s
                    final averageSpeed =
                        (leftSpeed + rightSpeed) / 2 * 3.6; // Average speed in km/h

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
                              final distance = '0.0'; // Not available in new format
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
                            return GestureDetector(
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
                                        // Only sensors 1-6 (indices 1-6) are active, telemetry sends values for sensors
                                        final isActive =
                                            index >= 1 && index <= 6;
                                        final sensorIndex = isActive
                                            ? index - 1
                                            : -1; // Map to telemetry array (0-5)

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
                                                            .surfaceVariant
                                                        : Theme.of(context)
                                                            .colorScheme
                                                            .surfaceVariant
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
                                                            ? (percentage < 0.3
                                                                ? Colors.green
                                                                : Colors.red)
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
                            );
                          },
                        ),
                        // Motor and Line Following Information
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                                      final leftData = telemetryData?.left ?? [0.0, 0.0, 0.0, 0, 0.0, 0.0, 0.0, 0.0];
                                      final rightData = telemetryData?.right ?? [0.0, 0.0, 0.0, 0, 0.0, 0.0, 0.0, 0.0];
                                      final lineData = telemetryData?.line ?? [0.0, 0.0, 0.0, 0.0, 0.0];
                                      final lineKPid = debugData?.lineKPid ?? [2.0, 0.05, 0.75];
                                      final leftKPid = debugData?.leftKPid ?? [1.0, 0.0, 0.0];
                                      final rightKPid = debugData?.rightKPid ?? [1.0, 0.0, 0.0];
                                      final baseData = debugData?.base ?? [200.0, 120.0];
                                      final wheelsData = debugData?.wheels ?? [0.0, 0.0];
                                      final modeData = debugData?.mode ?? 0;
                                      final cascadeData = debugData?.cascade ?? 1;

                                      // Left motor
                                      final leftRpm = leftData.isNotEmpty ? leftData[0] : 0.0;
                                      final leftTargetRpm = leftData.length > 1 ? leftData[1] : 0.0;
                                      final leftPwm = leftData.length > 2 ? leftData[2] : 0.0;
                                      final leftEncoder = leftData.length > 3 ? leftData[3].toInt() : 0;
                                      final leftDirection = leftData.length > 4 ? leftData[4] : 0.0;
                                      final leftIntegral = leftData.length > 5 ? leftData[5] : 0.0;
                                      final leftDerivative = leftData.length > 6 ? leftData[6] : 0.0;
                                      final leftError = leftData.length > 7 ? leftData[7] : 0.0;

                                      // Right motor
                                      final rightRpm = rightData.isNotEmpty ? rightData[0] : 0.0;
                                      final rightTargetRpm = rightData.length > 1 ? rightData[1] : 0.0;
                                      final rightPwm = rightData.length > 2 ? rightData[2] : 0.0;
                                      final rightEncoder = rightData.length > 3 ? rightData[3].toInt() : 0;
                                      final rightDirection = rightData.length > 4 ? rightData[4] : 0.0;
                                      final rightIntegral = rightData.length > 5 ? rightData[5] : 0.0;
                                      final rightDerivative = rightData.length > 6 ? rightData[6] : 0.0;
                                      final rightError = rightData.length > 7 ? rightData[7] : 0.0;

                                      // Line following
                                      final lineError = lineData.length > 1 ? lineData[1] : 0.0;
                                      final lineIntegral = lineData.length > 2 ? lineData[2] : 0.0;
                                      final lineDerivative = lineData.length > 3 ? lineData[3] : 0.0;

                                      return Column(
                                        children: [
                                          // Motor Information - 3 Column Layout
                                          Row(
                                            children: [
                                              // Left Motor
                                              Expanded(
                                                child: Container(
                                                  padding: const EdgeInsets.all(8),
                                                  margin: const EdgeInsets.only(right: 2),
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Motor Izquierdo',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                          color: Theme.of(context).colorScheme.onSurface,
                                                          fontFamily: 'Space Grotesk',
                                                        ),
                                                      ),
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        'RPM: ${leftRpm.toStringAsFixed(1)} / ${leftTargetRpm.toStringAsFixed(1)}',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                        ),
                                                      ),
                                                      Text(
                                                        'PWM: ${leftPwm.toStringAsFixed(0)}',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Encoder: $leftEncoder ${leftError > 0 ? '(atrasado)' : leftError < 0 ? '(adelantado)' : ''}',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Dirección: ${leftDirection > 0 ? 'Adelante' : leftDirection < 0 ? 'Atrás' : 'Detenido'}',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        'PID - I: ${leftIntegral.toStringAsFixed(1)}, D: ${leftDerivative.toStringAsFixed(1)}, E: ${leftError.toStringAsFixed(1)}',
                                                        style: TextStyle(
                                                          fontSize: 8,
                                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              // Right Motor
                                              Expanded(
                                                child: Container(
                                                  padding: const EdgeInsets.all(8),
                                                  margin: const EdgeInsets.only(left: 2),
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        'Motor Derecho',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w600,
                                                          color: Theme.of(context).colorScheme.onSurface,
                                                          fontFamily: 'Space Grotesk',
                                                        ),
                                                      ),
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        'RPM: ${rightRpm.toStringAsFixed(1)} / ${rightTargetRpm.toStringAsFixed(1)}',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                        ),
                                                      ),
                                                      Text(
                                                        'PWM: ${rightPwm.toStringAsFixed(0)}',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Encoder: $rightEncoder ${rightError > 0 ? '(atrasado)' : rightError < 0 ? '(adelantado)' : ''}',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                        ),
                                                      ),
                                                      Text(
                                                        'Dirección: ${rightDirection > 0 ? 'Adelante' : rightDirection < 0 ? 'Atrás' : 'Detenido'}',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 3),
                                                      Text(
                                                        'PID - I: ${rightIntegral.toStringAsFixed(1)}, D: ${rightDerivative.toStringAsFixed(1)}, E: ${rightError.toStringAsFixed(1)}',
                                                        style: TextStyle(
                                                          fontSize: 8,
                                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          // Line Following below motors
                                          if (mode == OperationMode.lineFollowing)
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              margin: const EdgeInsets.symmetric(vertical: 4),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Seguimiento',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w600,
                                                      color: Theme.of(context).colorScheme.onSurface,
                                                      fontFamily: 'Space Grotesk',
                                                    ),
                                                  ),
                                                  const SizedBox(height: 3),
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          'Posición: ${lineData[0].toStringAsFixed(1)}',
                                                          style: TextStyle(
                                                            fontSize: 9,
                                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Text(
                                                          'Corrección: ${lineData.length > 4 ? lineData[4].toStringAsFixed(1) : '0.0'}',
                                                          style: TextStyle(
                                                            fontSize: 9,
                                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    'PID - I: ${lineData[2].toStringAsFixed(1)}, D: ${lineData[3].toStringAsFixed(1)}, E: ${lineData[1].toStringAsFixed(1)}',
                                                    style: TextStyle(
                                                      fontSize: 9,
                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          const SizedBox(height: 10),
                                          // Config Data - Expandable Accordion
                                          Container(
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: ExpansionTile(
                                              shape: Border.all(width: 0, color: Colors.transparent),
                                              title: Text(
                                                'Datos de Configuración',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                  fontFamily: 'Space Grotesk',
                                                ),
                                              ),
                                              initiallyExpanded: _configExpanded,
                                              onExpansionChanged: (expanded) {
                                                setState(() {
                                                  _configExpanded = expanded;
                                                });
                                              },
                                              children: [
                                                Padding(
                                                  padding: const EdgeInsets.all(12),
                                                  child: Column(
                                                    children: [
                                                      // 3 Column PID Layout
                                                      Row(
                                                        children: [
                                                          // Línea Column
                                                          Expanded(
                                                            child: Container(
                                                              padding: const EdgeInsets.all(8),
                                                              margin: const EdgeInsets.only(right: 2),
                                                              decoration: BoxDecoration(
                                                                color: Theme.of(context).colorScheme.surface,
                                                                borderRadius: BorderRadius.circular(6),
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  Text(
                                                                    'Línea',
                                                                    style: TextStyle(
                                                                      fontSize: 11,
                                                                      fontWeight: FontWeight.w600,
                                                                      color: Theme.of(context).colorScheme.onSurface,
                                                                    ),
                                                                    textAlign: TextAlign.center,
                                                                  ),
                                                                  const SizedBox(height: 4),
                                                                  Text(
                                                                    'KP: ${lineKPid[0].toStringAsFixed(2)}',
                                                                    style: TextStyle(
                                                                      fontSize: 9,
                                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    'KI: ${lineKPid[1].toStringAsFixed(3)}',
                                                                    style: TextStyle(
                                                                      fontSize: 9,
                                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    'KD: ${lineKPid[2].toStringAsFixed(2)}',
                                                                    style: TextStyle(
                                                                      fontSize: 9,
                                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          // Izquierdo Column
                                                          Expanded(
                                                            child: Container(
                                                              padding: const EdgeInsets.all(8),
                                                              margin: const EdgeInsets.symmetric(horizontal: 2),
                                                              decoration: BoxDecoration(
                                                                color: Theme.of(context).colorScheme.surface,
                                                                borderRadius: BorderRadius.circular(6),
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  Text(
                                                                    'Izquierdo',
                                                                    style: TextStyle(
                                                                      fontSize: 11,
                                                                      fontWeight: FontWeight.w600,
                                                                      color: Theme.of(context).colorScheme.onSurface,
                                                                    ),
                                                                    textAlign: TextAlign.center,
                                                                  ),
                                                                  const SizedBox(height: 4),
                                                                  Text(
                                                                    'KP: ${leftKPid[0].toStringAsFixed(2)}',
                                                                    style: TextStyle(
                                                                      fontSize: 9,
                                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    'KI: ${leftKPid[1].toStringAsFixed(3)}',
                                                                    style: TextStyle(
                                                                      fontSize: 9,
                                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    'KD: ${leftKPid[2].toStringAsFixed(2)}',
                                                                    style: TextStyle(
                                                                      fontSize: 9,
                                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          // Derecho Column
                                                          Expanded(
                                                            child: Container(
                                                              padding: const EdgeInsets.all(8),
                                                              margin: const EdgeInsets.only(left: 2),
                                                              decoration: BoxDecoration(
                                                                color: Theme.of(context).colorScheme.surface,
                                                                borderRadius: BorderRadius.circular(6),
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  Text(
                                                                    'Derecho',
                                                                    style: TextStyle(
                                                                      fontSize: 11,
                                                                      fontWeight: FontWeight.w600,
                                                                      color: Theme.of(context).colorScheme.onSurface,
                                                                    ),
                                                                    textAlign: TextAlign.center,
                                                                  ),
                                                                  const SizedBox(height: 4),
                                                                  Text(
                                                                    'KP: ${rightKPid[0].toStringAsFixed(2)}',
                                                                    style: TextStyle(
                                                                      fontSize: 9,
                                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    'KI: ${rightKPid[1].toStringAsFixed(3)}',
                                                                    style: TextStyle(
                                                                      fontSize: 9,
                                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    'KD: ${rightKPid[2].toStringAsFixed(2)}',
                                                                    style: TextStyle(
                                                                      fontSize: 9,
                                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 8),
                                                      // Base and Wheels
                                                      Row(
                                                        children: [
                                                          Expanded(
                                                            child: Container(
                                                              padding: const EdgeInsets.all(8),
                                                              margin: const EdgeInsets.only(right: 2),
                                                              decoration: BoxDecoration(
                                                                color: Theme.of(context).colorScheme.surface,
                                                                borderRadius: BorderRadius.circular(6),
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  Text(
                                                                    'Base',
                                                                    style: TextStyle(
                                                                      fontSize: 11,
                                                                      fontWeight: FontWeight.w600,
                                                                      color: Theme.of(context).colorScheme.onSurface,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(height: 4),
                                                                  Text(
                                                                    'Velocidad: ${baseData[0].toStringAsFixed(0)}',
                                                                    style: TextStyle(
                                                                      fontSize: 9,
                                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    'RPM: ${baseData[1].toStringAsFixed(1)}',
                                                                    style: TextStyle(
                                                                      fontSize: 9,
                                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          Expanded(
                                                            child: Container(
                                                              padding: const EdgeInsets.all(8),
                                                              margin: const EdgeInsets.only(left: 2),
                                                              decoration: BoxDecoration(
                                                                color: Theme.of(context).colorScheme.surface,
                                                                borderRadius: BorderRadius.circular(6),
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                  Text(
                                                                    'Ruedas',
                                                                    style: TextStyle(
                                                                      fontSize: 11,
                                                                      fontWeight: FontWeight.w600,
                                                                      color: Theme.of(context).colorScheme.onSurface,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(height: 4),
                                                                  Text(
                                                                    'Diámetro: ${wheelsData[0].toStringAsFixed(2)}',
                                                                    style: TextStyle(
                                                                      fontSize: 9,
                                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    'Separación: ${wheelsData[1].toStringAsFixed(2)}',
                                                                    style: TextStyle(
                                                                      fontSize: 9,
                                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                                                        padding: const EdgeInsets.all(8),
                                                        decoration: BoxDecoration(
                                                          color: Theme.of(context).colorScheme.surface,
                                                          borderRadius: BorderRadius.circular(6),
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              'Operación y Control',
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w600,
                                                                color: Theme.of(context).colorScheme.onSurface,
                                                              ),
                                                            ),
                                                            const SizedBox(height: 4),
                                                            Row(
                                                              children: [
                                                                Expanded(
                                                                  child: Text(
                                                                    'Modo: ${modeData == 0 ? 'Reposo' : modeData == 1 ? 'Seguimiento' : 'Remoto'}',
                                                                    style: TextStyle(
                                                                      fontSize: 9,
                                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                ),
                                                                Expanded(
                                                                  child: Text(
                                                                    'Cascada: ${cascadeData == 1 ? 'Activada' : 'Desactivada'}',
                                                                    style: TextStyle(
                                                                      fontSize: 9,
                                                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      // Filters Status
                                                      ValueListenableBuilder<List<int>?>(
                                                        valueListenable: appState.filters,
                                                        builder: (context, filters, child) {
                                                          if (filters == null || filters.length != 6) return const SizedBox.shrink();

                                                          return Container(
                                                            width: double.infinity,
                                                            padding: const EdgeInsets.all(8),
                                                            decoration: BoxDecoration(
                                                              color: Theme.of(context).colorScheme.surface,
                                                              borderRadius: BorderRadius.circular(6),
                                                            ),
                                                            child: Column(
                                                              crossAxisAlignment: CrossAxisAlignment.start,
                                                              children: [
                                                                Text(
                                                                  'Filtros',
                                                                  style: TextStyle(
                                                                    fontSize: 11,
                                                                    fontWeight: FontWeight.w600,
                                                                    color: Theme.of(context).colorScheme.onSurface,
                                                                  ),
                                                                ),
                                                                const SizedBox(height: 4),
                                                                Text(
                                                                  'MED:${filters[0]} MA:${filters[1]} KAL:${filters[2]} HYS:${filters[3]} DZ:${filters[4]} LP:${filters[5]}',
                                                                  style: TextStyle(
                                                                    fontSize: 9,
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

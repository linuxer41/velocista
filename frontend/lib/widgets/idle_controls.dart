import 'package:flutter/material.dart';
import '../app_state.dart';
import '../arduino_data.dart';

class IdleControls extends StatefulWidget {
  final AppState appState;

  const IdleControls({super.key, required this.appState});

  @override
  State<IdleControls> createState() => _IdleControlsState();
}

class _IdleControlsState extends State<IdleControls> {
  double _leftPwm = 0.0;
  double _rightPwm = 0.0;
  double _leftRpm = 0.0;
  double _rightRpm = 0.0;
  final bool _configExpanded = false;
  bool _syncMotors = false;

  @override
  Widget build(BuildContext context) {
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
                    widget.appState.sendCommand(calibrateCommand.toCommand());
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
                    widget.appState.sendCommand(debugCommand.toCommand());
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
                    widget.appState.changeOperationMode(OperationMode.lineFollowing);
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
                    widget.appState.changeOperationMode(OperationMode.remoteControl);
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
                                valueListenable: widget.appState.configData,
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
                                      widget.appState.sendCommand(pwmCommand.toCommand());
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
                                valueListenable: widget.appState.configData,
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
                                      widget.appState.sendCommand(pwmCommand.toCommand());
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
                                valueListenable: widget.appState.configData,
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
                                      widget.appState.sendCommand(rpmCommand.toCommand());
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
                                valueListenable: widget.appState.configData,
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
                                      widget.appState.sendCommand(rpmCommand.toCommand());
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
                    widget.appState.sendCommand(pwmCommand.toCommand());
                    widget.appState.sendCommand(rpmCommand.toCommand());
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
}
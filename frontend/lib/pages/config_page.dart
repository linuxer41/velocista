import 'package:flutter/material.dart';
import '../app_state.dart';
import '../arduino_data.dart';

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  late TextEditingController _baseSpeedController;
  late TextEditingController _baseRpmController;
  late TextEditingController _maxSpeedController;
  late TextEditingController _maxRpmController;

  late TextEditingController _lineKpController;
  late TextEditingController _lineKiController;
  late TextEditingController _lineKdController;

  late TextEditingController _leftKpController;
  late TextEditingController _leftKiController;
  late TextEditingController _leftKdController;

  late TextEditingController _rightKpController;
  late TextEditingController _rightKiController;
  late TextEditingController _rightKdController;

  double _leftPwm = 0.0;
  double _rightPwm = 0.0;
  double _leftRpm = 0.0;
  double _rightRpm = 0.0;

  @override
  void initState() {
    super.initState();

    // Initialize controllers
    _baseSpeedController = TextEditingController(text: '200');
    _baseRpmController = TextEditingController(text: '120.0');
    _maxSpeedController = TextEditingController(text: '230');
    _maxRpmController = TextEditingController(text: '3000');
    _lineKpController = TextEditingController(text: '2.0');
    _lineKiController = TextEditingController(text: '0.05');
    _lineKdController = TextEditingController(text: '0.75');
    _leftKpController = TextEditingController(text: '1.0');
    _leftKiController = TextEditingController(text: '0.0');
    _leftKdController = TextEditingController(text: '0.0');
    _rightKpController = TextEditingController(text: '1.0');
    _rightKiController = TextEditingController(text: '0.0');
    _rightKdController = TextEditingController(text: '0.0');

    // Update controllers from config when available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = AppInheritedWidget.of(context);
      if (appState != null) {
        appState.configData.addListener(_updateControllersFromConfig);
        _updateControllersFromConfig();
      }
    });
  }

  @override
  void dispose() {
    final appState = AppInheritedWidget.of(context);
    if (appState != null) {
      appState.configData.removeListener(_updateControllersFromConfig);
    }
    _baseSpeedController.dispose();
    _baseRpmController.dispose();
    _maxSpeedController.dispose();
    _maxRpmController.dispose();
    _lineKpController.dispose();
    _lineKiController.dispose();
    _lineKdController.dispose();
    _leftKpController.dispose();
    _leftKiController.dispose();
    _leftKdController.dispose();
    _rightKpController.dispose();
    _rightKiController.dispose();
    _rightKdController.dispose();
    super.dispose();
  }

  void _updateControllersFromConfig() {
    final appState = AppInheritedWidget.of(context);
    if (appState != null) {
      final config = appState.configData.value;
      if (config != null) {
        // Update base speed controllers
        if (config.base != null) {
          if (config.base!.length >= 1) {
            _baseSpeedController.text = config.base![0].toStringAsFixed(0);
          }
          if (config.base!.length >= 2) {
            _baseRpmController.text = config.base![1].toStringAsFixed(1);
          }
        }

        // Update max speed controllers
        if (config.max != null) {
          if (config.max!.length >= 1) {
            _maxSpeedController.text = config.max![0].toStringAsFixed(0);
          }
          if (config.max!.length >= 2) {
            _maxRpmController.text = config.max![1].toStringAsFixed(0);
          }
        }

        // Update PID controllers
        if (config.lineKPid != null && config.lineKPid!.length >= 3) {
          _lineKpController.text = config.lineKPid![0].toStringAsFixed(2);
          _lineKiController.text = config.lineKPid![1].toStringAsFixed(3);
          _lineKdController.text = config.lineKPid![2].toStringAsFixed(2);
        }

        if (config.leftKPid != null && config.leftKPid!.length >= 3) {
          _leftKpController.text = config.leftKPid![0].toStringAsFixed(2);
          _leftKiController.text = config.leftKPid![1].toStringAsFixed(3);
          _leftKdController.text = config.leftKPid![2].toStringAsFixed(2);
        }

        if (config.rightKPid != null && config.rightKPid!.length >= 3) {
          _rightKpController.text = config.rightKPid![0].toStringAsFixed(2);
          _rightKiController.text = config.rightKPid![1].toStringAsFixed(3);
          _rightKdController.text = config.rightKPid![2].toStringAsFixed(2);
        }
      }
    }
  }

  Widget _buildBaseSpeedInput(String label, TextEditingController controller) {
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
        SizedBox(
          height: 40,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: controller.text,
              hintStyle: TextStyle(
                fontSize: 14,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withOpacity(0.5),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPidInput(String label, TextEditingController controller) {
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
        SizedBox(
          height: 40,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: controller.text,
              hintStyle: TextStyle(
                fontSize: 14,
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withOpacity(0.5),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBaseSpeedSection(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Velocidades Base',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Space Grotesk',
            ),
          ),
          const SizedBox(height: 12),
          // PWM base and RPM base
          _buildBaseSpeedInput('PWM base', _baseSpeedController),
          const SizedBox(height: 8),
          _buildBaseSpeedInput('RPM base', _baseRpmController),
          const SizedBox(height: 12),
          // Send button
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton.icon(
              onPressed: () => _sendBaseSpeedConfiguration(appState),
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Enviar', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaxSpeedSection(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Velocidades Max',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Space Grotesk',
            ),
          ),
          const SizedBox(height: 12),
          // PWM max and RPM max
          _buildBaseSpeedInput('PWM max', _maxSpeedController),
          const SizedBox(height: 8),
          _buildBaseSpeedInput('RPM max', _maxRpmController),
          const SizedBox(height: 12),
          // Send button
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton.icon(
              onPressed: () => _sendMaxSpeedConfiguration(appState),
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Enviar', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPwmSection(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'PWM',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontFamily: 'Space Grotesk',
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 28,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _leftPwm = 0.0;
                      _rightPwm = 0.0;
                    });
                    _sendPwmConfiguration(appState);
                  },
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Reset', style: TextStyle(fontSize: 10)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // PWM Controls - Left and Right motors
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Izq: ${_leftPwm.toInt()}',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(
                height: 30,
                child: Slider(
                  value: _leftPwm,
                  min: -230,
                  max: 230,
                  divisions: 460,
                  onChanged: (value) {
                    setState(() {
                      _leftPwm = value;
                    });
                  },
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Der: ${_rightPwm.toInt()}',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(
                height: 30,
                child: Slider(
                  value: _rightPwm,
                  min: -230,
                  max: 230,
                  divisions: 460,
                  onChanged: (value) {
                    setState(() {
                      _rightPwm = value;
                    });
                  },
                  activeColor: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: ElevatedButton.icon(
                  onPressed: () => _sendPwmConfiguration(appState),
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Enviar', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRpmSection(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'RPM',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                  fontFamily: 'Space Grotesk',
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 28,
                child: ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _leftRpm = 0.0;
                      _rightRpm = 0.0;
                    });
                    _sendRpmConfiguration(appState);
                  },
                  icon: const Icon(Icons.refresh, size: 14),
                  label: const Text('Reset', style: TextStyle(fontSize: 10)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // RPM Controls - Left and Right motors
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Izq: ${_leftRpm.toInt()}',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(
                height: 30,
                child: Slider(
                  value: _leftRpm,
                  min: -300,
                  max: 300,
                  divisions: 600,
                  onChanged: (value) {
                    setState(() {
                      _leftRpm = value;
                    });
                  },
                  activeColor: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Der: ${_rightRpm.toInt()}',
                style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(
                height: 30,
                child: Slider(
                  value: _rightRpm,
                  min: -300,
                  max: 300,
                  divisions: 600,
                  onChanged: (value) {
                    setState(() {
                      _rightRpm = value;
                    });
                  },
                  activeColor: Theme.of(context).colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: ElevatedButton.icon(
                  onPressed: () => _sendRpmConfiguration(appState),
                  icon: const Icon(Icons.send, size: 16),
                  label: const Text('Enviar', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                    foregroundColor: Theme.of(context).colorScheme.onSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPidSection(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PID',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Space Grotesk',
            ),
          ),
          const SizedBox(height: 16),
          DefaultTabController(
            length: 3,
            child: Column(
              children: [
                TabBar(
                  tabs: const [
                    Tab(text: 'Línea'),
                    Tab(text: 'Motor Izq'),
                    Tab(text: 'Motor Der'),
                  ],
                  labelStyle: const TextStyle(
                      fontSize: 14, fontFamily: 'Space Grotesk'),
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor:
                      Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                SizedBox(
                  height: 200,
                  child: TabBarView(
                    children: [
                      // Line PID Tab
                      Column(
                        children: [
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildPidInput('Kp', _lineKpController),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildPidInput('Ki', _lineKiController),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildPidInput('Kd', _lineKdController),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 36,
                            child: ElevatedButton.icon(
                              onPressed: () => _sendPidConfiguration(appState, 'line'),
                              icon: const Icon(Icons.send, size: 16),
                              label: const Text('Línea', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Left Motor PID Tab
                      Column(
                        children: [
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildPidInput('Kp', _leftKpController),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildPidInput('Ki', _leftKiController),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildPidInput('Kd', _leftKdController),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 36,
                            child: ElevatedButton.icon(
                              onPressed: () => _sendPidConfiguration(appState, 'left'),
                              icon: const Icon(Icons.send, size: 16),
                              label: const Text('Izquierdo', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Right Motor PID Tab
                      Column(
                        children: [
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildPidInput('Kp', _rightKpController),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildPidInput('Ki', _rightKiController),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildPidInput('Kd', _rightKdController),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 36,
                            child: ElevatedButton.icon(
                              onPressed: () => _sendPidConfiguration(appState, 'right'),
                              icon: const Icon(Icons.send, size: 16),
                              label: const Text('Derecho', style: TextStyle(fontSize: 12)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary,
                                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sendBaseSpeedConfiguration(AppState appState) async {
    final baseSpeedValue = double.tryParse(_baseSpeedController.text) ?? 200.0;
    final baseRpmValue = double.tryParse(_baseRpmController.text) ?? 120.0;

    final baseSpeedCommand = BaseSpeedCommand(baseSpeedValue, baseRpmValue);
    await appState.sendCommand(baseSpeedCommand.toCommand());

    // Request fresh config data to sync UI
    await appState.sendCommand(ConfigRequestCommand().toCommand());

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Velocidades base enviadas correctamente'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _sendMaxSpeedConfiguration(AppState appState) async {
    final maxSpeedValue = double.tryParse(_maxSpeedController.text) ?? 230.0;
    final maxRpmValue = double.tryParse(_maxRpmController.text) ?? 3000.0;

    final maxSpeedCommand = MaxSpeedCommand(maxSpeedValue, maxRpmValue);
    await appState.sendCommand(maxSpeedCommand.toCommand());

    // Request fresh config data to sync UI
    await appState.sendCommand(ConfigRequestCommand().toCommand());

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Velocidades max enviadas correctamente'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _sendRpmConfiguration(AppState appState) async {
    final rpmCommand = SetRpmCommand(
      leftRpm: _leftRpm.toInt(),
      rightRpm: _rightRpm.toInt(),
    );
    await appState.sendCommand(rpmCommand.toCommand());

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('RPM enviado correctamente'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _sendPwmConfiguration(AppState appState) async {
    final pwmCommand = SetPwmCommand(
      rightPwm: _rightPwm.toInt(),
      leftPwm: _leftPwm.toInt(),
    );
    await appState.sendCommand(pwmCommand.toCommand());

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PWM enviado correctamente'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }


  void _sendPidConfiguration(AppState appState, String type) async {
    double kp, ki, kd;

    if (type == 'line') {
      kp = double.tryParse(_lineKpController.text) ?? 2.0;
      ki = double.tryParse(_lineKiController.text) ?? 0.05;
      kd = double.tryParse(_lineKdController.text) ?? 0.75;
    } else if (type == 'left') {
      kp = double.tryParse(_leftKpController.text) ?? 1.0;
      ki = double.tryParse(_leftKiController.text) ?? 0.0;
      kd = double.tryParse(_leftKdController.text) ?? 0.0;
    } else if (type == 'right') {
      kp = double.tryParse(_rightKpController.text) ?? 1.0;
      ki = double.tryParse(_rightKiController.text) ?? 0.0;
      kd = double.tryParse(_rightKdController.text) ?? 0.0;
    } else {
      return; // Invalid type
    }

    final pidCommand = PidCommand(type: type, kp: kp, ki: ki, kd: kd);
    await appState.sendCommand(pidCommand.toCommand());

    // Request fresh config data to sync UI
    await appState.sendCommand(ConfigRequestCommand().toCommand());

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PID $type enviado correctamente'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppInheritedWidget.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Velocidades sections in 2 columns
            Row(
              children: [
                Expanded(
                  child: _buildBaseSpeedSection(appState!),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMaxSpeedSection(appState),
                ),
              ],
            ),
            // PWM and RPM sections in 2 columns
            Row(
              children: [
                Expanded(
                  child: _buildPwmSection(appState),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildRpmSection(appState),
                ),
              ],
            ),
            _buildPidSection(appState),
          ],
        ),
      ),
    );
  }
}
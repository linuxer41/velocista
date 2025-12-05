import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../app_state.dart';
import '../arduino_data.dart';
import '../widgets/custom_appbar.dart';

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  bool _isSliderMode = false;

  AppState? _appState;

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

  late TextEditingController _weightController;
  late TextEditingController _lineSampleController;
  late TextEditingController _speedSampleController;
  late TextEditingController _telemetrySampleController;


  @override
  void initState() {
    super.initState();

    // Initialize controllers
    _baseSpeedController = TextEditingController(text: '200');
    _baseRpmController = TextEditingController(text: '120.0');
    _maxSpeedController = TextEditingController(text: '230');
    _maxRpmController = TextEditingController(text: '3000');
    _lineKpController = TextEditingController(text: '0.900');
    _lineKiController = TextEditingController(text: '0.010');
    _lineKdController = TextEditingController(text: '0.020');
    _leftKpController = TextEditingController(text: '0.590');
    _leftKiController = TextEditingController(text: '0.001');
    _leftKdController = TextEditingController(text: '0.0025');
    _rightKpController = TextEditingController(text: '0.590');
    _rightKiController = TextEditingController(text: '0.001');
    _rightKdController = TextEditingController(text: '0.050');
    _weightController = TextEditingController(text: '155.0');
    _lineSampleController = TextEditingController(text: '2');
    _speedSampleController = TextEditingController(text: '1');
    _telemetrySampleController = TextEditingController(text: '100');

    // Update controllers from config when available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _appState = AppInheritedWidget.of(context);
      if (_appState != null) {
        _appState!.configData.addListener(_updateControllersFromConfig);
        _updateControllersFromConfig();
      }
    });
  }

  @override
  void dispose() {
    if (_appState != null) {
      _appState!.configData.removeListener(_updateControllersFromConfig);
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
    _weightController.dispose();
    _lineSampleController.dispose();
    _speedSampleController.dispose();
    _telemetrySampleController.dispose();
    super.dispose();
  }

  void _updateControllersFromConfig() {
    if (_appState != null) {
      final config = _appState!.configData.value;
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
          if (config.max!.length >= 2) {
            _maxRpmController.text = config.max![1].toStringAsFixed(0);
          }
        }

        // Update PID controllers
        if (config.lineKPid != null && config.lineKPid!.length >= 3) {
          _lineKpController.text = config.lineKPid![0].toStringAsFixed(3);
          _lineKiController.text = config.lineKPid![1].toStringAsFixed(3);
          _lineKdController.text = config.lineKPid![2].toStringAsFixed(3);
        }

        if (config.leftKPid != null && config.leftKPid!.length >= 3) {
          _leftKpController.text = config.leftKPid![0].toStringAsFixed(3);
          _leftKiController.text = config.leftKPid![1].toStringAsFixed(3);
          _leftKdController.text = config.leftKPid![2].toStringAsFixed(3);
        }

        if (config.rightKPid != null && config.rightKPid!.length >= 3) {
          _rightKpController.text = config.rightKPid![0].toStringAsFixed(3);
          _rightKiController.text = config.rightKPid![1].toStringAsFixed(3);
          _rightKdController.text = config.rightKPid![2].toStringAsFixed(3);
        }

          // Update weight controller
          if (config.weight != null) {
            _weightController.text = config.weight!.toStringAsFixed(1);
          }

          // Update sampling rate controllers
          if (config.sampRate != null && config.sampRate!.length >= 3) {
            _lineSampleController.text = config.sampRate![0].toString();
            _speedSampleController.text = config.sampRate![1].toString();
            _telemetrySampleController.text = config.sampRate![2].toString();
          }
      }
    }
  }


  Widget _buildPidInput(String label, TextEditingController controller) {
    double max = label == 'Kp' ? 15.0 : 1.0;
    return _buildConfigInput(label, controller, min: 0, max: max, decimals: 3);
  }

  Widget _buildConfigInput(String label, TextEditingController controller, {double? min, double? max, int? decimals}) {
    if (_isSliderMode) {
      double value = double.tryParse(controller.text) ?? 0.0;
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
            height: 30,
            child: Slider(
              value: value.clamp(min ?? 0.0, max ?? 100.0),
              min: min ?? 0.0,
              max: max ?? 100.0,
              divisions: decimals == 3 ? (((max ?? 20.0) - (min ?? 0.0)) / 0.001).toInt() : ((max ?? 100.0) - (min ?? 0.0)).toInt(),
              onChanged: (newValue) {
                setState(() {
                  controller.text = newValue.toStringAsFixed(decimals ?? 0);
                });
              },
              activeColor: Theme.of(context).colorScheme.primary,
            ),
          ),
          Text(
            value.toStringAsFixed(decimals ?? 0),
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    } else {
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
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: decimals == 3 ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,3}'))] : null,
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
  }

  Widget _buildBaseSpeedSection(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
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
          _buildConfigInput('PWM base', _baseSpeedController, min: 0, max: 255, decimals: 0),
          const SizedBox(height: 8),
          _buildConfigInput('RPM base', _baseRpmController, min: 0, max: 5000, decimals: 1),
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
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
          _buildConfigInput('PWM max', _maxSpeedController, min: 0, max: 255, decimals: 0),
          const SizedBox(height: 8),
          _buildConfigInput('RPM max', _maxRpmController, min: 0, max: 5000, decimals: 0),
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



  Widget _buildPidSection(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
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
          // Línea PID
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Línea',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Flexible(
                    flex: 7,
                    child: _buildPidInput('Kp', _lineKpController),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    flex: 6,
                    child: _buildPidInput('Ki', _lineKiController),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    flex: 7,
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
          const SizedBox(height: 16),
          // Motor Izquierdo PID
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Motor Izquierdo',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Flexible(
                    flex: 7,
                    child: _buildPidInput('Kp', _leftKpController),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    flex: 6,
                    child: _buildPidInput('Ki', _leftKiController),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    flex: 7,
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
          const SizedBox(height: 16),
          // Motor Derecho PID
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Motor Derecho',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Flexible(
                    flex: 7,
                    child: _buildPidInput('Kp', _rightKpController),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    flex: 6,
                    child: _buildPidInput('Ki', _rightKiController),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    flex: 7,
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
    );
  }

  Widget _buildWeightAndSamplingSection(AppState appState) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Peso y Muestreo',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Space Grotesk',
            ),
          ),
          const SizedBox(height: 12),
          // Weight input
          _buildConfigInput('Peso (g)', _weightController, min: 0, max: 500, decimals: 1),
          const SizedBox(height: 8),
          // Sampling rates
          Row(
            children: [
              Expanded(
                child: _buildConfigInput('Línea (ms)', _lineSampleController, min: 0, max: 1000, decimals: 0),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildConfigInput('Velocidad (ms)', _speedSampleController, min: 0, max: 1000, decimals: 0),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildConfigInput('Telemetría (ms)', _telemetrySampleController, min: 0, max: 1000, decimals: 0),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Send button
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton.icon(
              onPressed: () => _sendWeightAndSamplingConfiguration(appState),
              icon: const Icon(Icons.send, size: 16),
              label: const Text('Enviar', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.tertiary,
                foregroundColor: Theme.of(context).colorScheme.onTertiary,
              ),
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




  void _sendPidConfiguration(AppState appState, String type) async {
    double kp, ki, kd;

    if (type == 'line') {
      kp = double.tryParse(_lineKpController.text) ?? 0.900;
      ki = double.tryParse(_lineKiController.text) ?? 0.010;
      kd = double.tryParse(_lineKdController.text) ?? 0.020;
    } else if (type == 'left') {
      kp = double.tryParse(_leftKpController.text) ?? 0.590;
      ki = double.tryParse(_leftKiController.text) ?? 0.001;
      kd = double.tryParse(_leftKdController.text) ?? 0.0025;
    } else if (type == 'right') {
      kp = double.tryParse(_rightKpController.text) ?? 0.590;
      ki = double.tryParse(_rightKiController.text) ?? 0.001;
      kd = double.tryParse(_rightKdController.text) ?? 0.050;
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

  void _sendWeightAndSamplingConfiguration(AppState appState) async {
    final weightValue = double.tryParse(_weightController.text) ?? 155.0;
    final lineSampleValue = int.tryParse(_lineSampleController.text) ?? 2;
    final speedSampleValue = int.tryParse(_speedSampleController.text) ?? 1;
    final telemetrySampleValue = int.tryParse(_telemetrySampleController.text) ?? 100;

    final weightCommand = WeightCommand(weightValue);
    await appState.sendCommand(weightCommand.toCommand());

    final sampRateCommand = SampRateCommand(lineSampleValue, speedSampleValue, telemetrySampleValue);
    await appState.sendCommand(sampRateCommand.toCommand());

    // Request fresh config data to sync UI
    await appState.sendCommand(ConfigRequestCommand().toCommand());

    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Peso y muestreo enviados correctamente'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = _appState ?? AppInheritedWidget.of(context);

    if (appState == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: 'Configuración',
              hasBackButton: true,
              actions: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: 0.75,
                      child: Switch(
                        value: _isSliderMode,
                        onChanged: (value) {
                          setState(() {
                            _isSliderMode = value;
                          });
                        },
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Text(
                      'Slider',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Velocidades sections in 2 columns
                    Row(
                      children: [
                        Expanded(
                          child: _buildBaseSpeedSection(appState),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildMaxSpeedSection(appState),
                        ),
                      ],
                    ),
                    _buildPidSection(appState),
                    _buildWeightAndSamplingSection(appState),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
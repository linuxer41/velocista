import 'package:flutter/material.dart';
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
  // Line PID controllers
  final TextEditingController _linePController = TextEditingController(text: '2.0');
  final TextEditingController _lineIController = TextEditingController(text: '0.05');
  final TextEditingController _lineDController = TextEditingController(text: '0.75');

  // Left motor PID controllers
  final TextEditingController _leftPController = TextEditingController(text: '5.0');
  final TextEditingController _leftIController = TextEditingController(text: '0.5');
  final TextEditingController _leftDController = TextEditingController(text: '0.1');

  // Right motor PID controllers
  final TextEditingController _rightPController = TextEditingController(text: '5.0');
  final TextEditingController _rightIController = TextEditingController(text: '0.5');
  final TextEditingController _rightDController = TextEditingController(text: '0.1');

  // Base speed and RPM controllers
  final TextEditingController _baseSpeedController = TextEditingController(text: '200');
  final TextEditingController _baseRpmController = TextEditingController(text: '120.0');

  double _maxSpeed = 80.0;
  double _maxAcceleration = 65.0;

  @override
  void dispose() {
    _linePController.dispose();
    _lineIController.dispose();
    _lineDController.dispose();
    _leftPController.dispose();
    _leftIController.dispose();
    _leftDController.dispose();
    _rightPController.dispose();
    _rightIController.dispose();
    _rightDController.dispose();
    _baseSpeedController.dispose();
    _baseRpmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Compact Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: colorScheme.surface,
              child: Row(
                children: [
                  // Back button
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.arrow_back,
                      color: colorScheme.onSurface,
                      size: 24,
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  // Title
                  Text(
                    'Ajustes',
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Space Grotesk',
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Calibración Section
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              'Calibración',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Space Grotesk',
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.outline.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Presiona el botón para iniciar el proceso de calibración de los sensores del vehículo.',
                                  style: TextStyle(
                                    color: colorScheme.onSurface.withOpacity(0.7),
                                    fontSize: 14,
                                    fontFamily: 'Space Grotesk',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 44,
                                  child: ElevatedButton(
                                    onPressed: _startCalibration,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      foregroundColor: colorScheme.onPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: const Text(
                                      'Iniciar Calibración de Sensores',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Space Grotesk',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // PID Parameters Section
                    Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'Parámetros PID',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Space Grotesk',
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.outline.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                // Line PID
                                Text(
                                  'line pid',
                                  style: TextStyle(
                                    color: colorScheme.onSurface.withOpacity(0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Space Grotesk',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildCompactParameterInput(
                                        'P',
                                        _linePController,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildCompactParameterInput(
                                        'I',
                                        _lineIController,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildCompactParameterInput(
                                        'D',
                                        _lineDController,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Left Motor PID
                                Text(
                                  'left pid',
                                  style: TextStyle(
                                    color: colorScheme.onSurface.withOpacity(0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Space Grotesk',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildCompactParameterInput(
                                        'P',
                                        _leftPController,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildCompactParameterInput(
                                        'I',
                                        _leftIController,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildCompactParameterInput(
                                        'D',
                                        _leftDController,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Right Motor PID
                                Text(
                                  'right pid',
                                  style: TextStyle(
                                    color: colorScheme.onSurface.withOpacity(0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Space Grotesk',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildCompactParameterInput(
                                        'P',
                                        _rightPController,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildCompactParameterInput(
                                        'I',
                                        _rightIController,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildCompactParameterInput(
                                        'D',
                                        _rightDController,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Base Speed and RPM
                                Text(
                                  'Velocidad Base',
                                  style: TextStyle(
                                    color: colorScheme.onSurface.withOpacity(0.7),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'Space Grotesk',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildCompactParameterInput(
                                        'Velocidad',
                                        _baseSpeedController,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildCompactParameterInput(
                                        'RPM',
                                        _baseRpmController,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  height: 40,
                                  child: ElevatedButton(
                                    onPressed: _saveSettings,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: colorScheme.primary,
                                      foregroundColor: colorScheme.onPrimary,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                    child: const Text(
                                      'Guardar',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'Space Grotesk',
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Limits Section
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              'Límites',
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Space Grotesk',
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: colorScheme.outline.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                _buildCompactSlider(
                                  'Velocidad Máxima',
                                  _maxSpeed,
                                  (value) => setState(() => _maxSpeed = value),
                                ),
                                const SizedBox(height: 16),
                                _buildCompactSlider(
                                  'Aceleración Máxima',
                                  _maxAcceleration,
                                  (value) => setState(() => _maxAcceleration = value),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildParameterInput(String label, TextEditingController controller) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.7),
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'Space Grotesk',
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 56,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 16,
              fontFamily: 'Space Grotesk',
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: colorScheme.primary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactParameterInput(String label, TextEditingController controller) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: colorScheme.onSurface.withOpacity(0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            fontFamily: 'Space Grotesk',
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 40,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 14,
              fontFamily: 'Space Grotesk',
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: colorScheme.outline.withOpacity(0.2),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(6),
                borderSide: BorderSide(
                  color: colorScheme.primary,
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlider(String label, double value, ValueChanged<double> onChanged) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.7),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                fontFamily: 'Space Grotesk',
              ),
            ),
            Text(
              '${value.round()}%',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                fontFamily: 'Space Grotesk',
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: colorScheme.primary,
            inactiveTrackColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
            thumbColor: colorScheme.primary,
            overlayColor: colorScheme.primary.withOpacity(0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 100,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactSlider(String label, double value, ValueChanged<double> onChanged) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurface.withOpacity(0.7),
                fontSize: 13,
                fontWeight: FontWeight.w500,
                fontFamily: 'Space Grotesk',
              ),
            ),
            Text(
              '${value.round()}%',
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                fontFamily: 'Space Grotesk',
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            activeTrackColor: colorScheme.primary,
            inactiveTrackColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
            thumbColor: colorScheme.primary,
            overlayColor: colorScheme.primary.withOpacity(0.2),
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
          ),
          child: Slider(
            value: value,
            min: 0,
            max: 100,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _saveSettings() {
    // Send PID commands
    final linePidCommand = PidCommand(
      type: 'line',
      kp: double.tryParse(_linePController.text) ?? 2.0,
      ki: double.tryParse(_lineIController.text) ?? 0.05,
      kd: double.tryParse(_lineDController.text) ?? 0.75,
    );
    widget.appState.sendCommand(linePidCommand.toCommand());

    final leftPidCommand = PidCommand(
      type: 'left',
      kp: double.tryParse(_leftPController.text) ?? 5.0,
      ki: double.tryParse(_leftIController.text) ?? 0.5,
      kd: double.tryParse(_leftDController.text) ?? 0.1,
    );
    widget.appState.sendCommand(leftPidCommand.toCommand());

    final rightPidCommand = PidCommand(
      type: 'right',
      kp: double.tryParse(_rightPController.text) ?? 5.0,
      ki: double.tryParse(_rightIController.text) ?? 0.5,
      kd: double.tryParse(_rightDController.text) ?? 0.1,
    );
    widget.appState.sendCommand(rightPidCommand.toCommand());

    // Send base speed and RPM commands
    final baseSpeedCommand = BaseSpeedCommand(
      double.tryParse(_baseSpeedController.text) ?? 200.0,
    );
    widget.appState.sendCommand(baseSpeedCommand.toCommand());

    final baseRpmCommand = BaseRpmCommand(
      double.tryParse(_baseRpmController.text) ?? 120.0,
    );
    widget.appState.sendCommand(baseRpmCommand.toCommand());

    // Save settings to EEPROM
    final saveCommand = EepromSaveCommand();
    widget.appState.sendCommand(saveCommand.toCommand());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración guardada'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _startCalibration() {
    // Send calibration command
    final command = CalibrateQtrCommand();
    widget.appState.sendCommand(command.toCommand());

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Iniciando calibración de sensores...'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
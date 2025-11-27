import 'package:flutter/material.dart';
import '../app_state.dart';
import '../arduino_data.dart';

class PidControl extends StatefulWidget {
  final AppState appState;

  const PidControl({super.key, required this.appState});

  @override
  State<PidControl> createState() => _PidControlState();
}

class _PidControlState extends State<PidControl> {
  late TextEditingController _kpController;
  late TextEditingController _kiController;
  late TextEditingController _kdController;
  late TextEditingController _setpointController;
  late TextEditingController _baseSpeedController;

  @override
  void initState() {
    super.initState();
    // Initialize with default values
    _kpController = TextEditingController(text: '0.00');
    _kiController = TextEditingController(text: '0.000');
    _kdController = TextEditingController(text: '0.00');
    _setpointController = TextEditingController(text: '2500');
    _baseSpeedController = TextEditingController(text: '0.80');

    // Listen to telemetry data changes
    widget.appState.currentData.addListener(_updateFromTelemetry);
    _updateFromTelemetry(); // Initial update
  }

  @override
  void dispose() {
    widget.appState.currentData.removeListener(_updateFromTelemetry);
    _kpController.dispose();
    _kiController.dispose();
    _kdController.dispose();
    _setpointController.dispose();
    _baseSpeedController.dispose();
    super.dispose();
  }

  void _updateFromTelemetry() {
    final data = widget.appState.currentData.value;
    if (data != null && data.pid != null && data.pid!.length >= 3) {
      // Update controllers with telemetry PID values
      _kpController.text = data.pid![0].toStringAsFixed(2);
      _kiController.text = data.pid![1].toStringAsFixed(3);
      _kdController.text = data.pid![2].toStringAsFixed(2);
      _setpointController.text = (data.position ?? 2500).toStringAsFixed(0);
      _baseSpeedController.text = (data.baseSpeed ?? 0.8).toStringAsFixed(2);
    } else {
      // No telemetry data, show zeros
      _kpController.text = '0.00';
      _kiController.text = '0.000';
      _kdController.text = '0.00';
      _setpointController.text = '2500';
      _baseSpeedController.text = '0.80';
    }
  }


  void _updatePIDConfig() {
    final kp = double.tryParse(_kpController.text) ?? 1.0;
    final ki = double.tryParse(_kiController.text) ?? 0.0;
    final kd = double.tryParse(_kdController.text) ?? 0.0;
    final setpoint = double.tryParse(_setpointController.text) ?? 2500.0;
    final baseSpeed = double.tryParse(_baseSpeedController.text) ?? 0.8;

    final newConfig = ArduinoPIDConfig(
      kp: kp,
      ki: ki,
      kd: kd,
      setpoint: setpoint,
      baseSpeed: baseSpeed,
    );

    widget.appState.updatePIDConfig(newConfig);

    // Send PID command to Arduino (line following PID)
    final pidCommand = PidCommand(
      type: 'line',
      kp: kp,
      ki: ki,
      kd: kd,
    );
    widget.appState.sendCommand(pidCommand.toCommand());
  }

  void _calibrateSensors() {
    final command = CalibrateQtrCommand();
    widget.appState.sendCommand(command.toCommand());
  }

  @override
  Widget build(BuildContext context) {
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
            'PID Config',
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
                child: _buildParameterField(
                  label: 'Kp',
                  controller: _kpController,
                  hint: '1.00',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildParameterField(
                  label: 'Ki',
                  controller: _kiController,
                  hint: '0.000',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildParameterField(
                  label: 'Kd',
                  controller: _kdController,
                  hint: '0.00',
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Setpoint and Base Speed
          Row(
            children: [
              Expanded(
                child: _buildParameterField(
                  label: 'Setpoint',
                  controller: _setpointController,
                  hint: '2500',
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _buildParameterField(
                  label: 'Vel Base',
                  controller: _baseSpeedController,
                  hint: '0.80',
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _updatePIDConfig,
                  child: const Text('Enviar', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: _calibrateSensors,
                  child: const Text('Calibrar', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Current Values Display
          ValueListenableBuilder<ArduinoData?>(
            valueListenable: widget.appState.currentData,
            builder: (context, data, child) {
              if (data == null) return const SizedBox.shrink();

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
                      'Estado',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Err: ${data.error?.toStringAsFixed(1) ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          'Corr: ${data.correction?.toStringAsFixed(1) ?? 'N/A'}',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Calidad: ${data.getTrackingQuality() ?? 'N/A'}',
                      style: TextStyle(
                        fontSize: 10,
                        color: data.getTrackingQuality() == 'Excellent'
                            ? Colors.green
                            : data.getTrackingQuality() == 'Good'
                                ? Colors.blue
                                : Colors.orange,
                        fontWeight: FontWeight.w500,
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

  Widget _buildParameterField({
    required String label,
    required TextEditingController controller,
    required String hint,
  }) {
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
              hintText: hint,
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
}
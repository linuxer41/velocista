import 'package:flutter/material.dart';
import '../app_state.dart';
import '../arduino_data.dart';

class RightPidControl extends StatefulWidget {
  final AppState appState;

  const RightPidControl({super.key, required this.appState});

  @override
  State<RightPidControl> createState() => _RightPidControlState();
}

class _RightPidControlState extends State<RightPidControl> {
  late TextEditingController _kpController;
  late TextEditingController _kiController;
  late TextEditingController _kdController;

  @override
  void initState() {
    super.initState();
    // Initialize with default values for right motor
    _kpController = TextEditingController(text: '5.0');
    _kiController = TextEditingController(text: '0.5');
    _kdController = TextEditingController(text: '0.1');

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
    super.dispose();
  }

  void _updateFromTelemetry() {
    final data = widget.appState.currentData.value;
    if (data != null && data.rightPid != null && data.rightPid!.length >= 3) {
      // Update controllers with telemetry right PID values
      _kpController.text = data.rightPid![0].toStringAsFixed(2);
      _kiController.text = data.rightPid![1].toStringAsFixed(3);
      _kdController.text = data.rightPid![2].toStringAsFixed(2);
    } else {
      // No telemetry data, show defaults
      _kpController.text = '5.0';
      _kiController.text = '0.5';
      _kdController.text = '0.1';
    }
  }

  void _updatePIDConfig() {
    final kp = double.tryParse(_kpController.text) ?? 5.0;
    final ki = double.tryParse(_kiController.text) ?? 0.5;
    final kd = double.tryParse(_kdController.text) ?? 0.1;

    // Send right motor PID command to Arduino
    final pidCommand = PidCommand(
      type: 'right',
      kp: kp,
      ki: ki,
      kd: kd,
    );
    widget.appState.sendCommand(pidCommand.toCommand());
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
            'Right Motor PID',
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
                  hint: '5.0',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildParameterField(
                  label: 'Ki',
                  controller: _kiController,
                  hint: '0.5',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildParameterField(
                  label: 'Kd',
                  controller: _kdController,
                  hint: '0.1',
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _updatePIDConfig,
              child: const Text('Update Right PID', style: TextStyle(fontSize: 12)),
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
            valueListenable: widget.appState.currentData,
            builder: (context, data, child) {
              if (data == null || data.rightPid == null) return const SizedBox.shrink();

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
                      'Right Motor Status',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RPM Target: ${data.rightPid![3].toStringAsFixed(1)}',
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
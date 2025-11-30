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

  @override
  void initState() {
    super.initState();
    // Initialize with default values
    _kpController = TextEditingController(text: '2.0');
    _kiController = TextEditingController(text: '0.05');
    _kdController = TextEditingController(text: '0.75');

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
    if ((data is DebugData &&
        data.lineKPid != null &&
        data.lineKPid!.length >= 3) ||
        (data is ConfigData &&
        data.lineKPid != null &&
        data.lineKPid!.length >= 3)) {
      // Update controllers with config line PID values
      List<double> lineKPid;
      if (data is DebugData) {
        lineKPid = data.lineKPid!;
      } else {
        lineKPid = (data as ConfigData).lineKPid!;
      }
      _kpController.text = lineKPid[0].toStringAsFixed(2);
      _kiController.text = lineKPid[1].toStringAsFixed(3);
      _kdController.text = lineKPid[2].toStringAsFixed(2);
    } else {
      // No config data, show defaults
      _kpController.text = '2.00';
      _kiController.text = '0.05';
      _kdController.text = '0.75';
    }
  }

  void _updatePIDConfig() {
    final kp = double.tryParse(_kpController.text) ?? 2.0;
    final ki = double.tryParse(_kiController.text) ?? 0.05;
    final kd = double.tryParse(_kdController.text) ?? 0.75;

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
            'Configuración PID',
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
                  hint: '2.0',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildParameterField(
                  label: 'Ki',
                  controller: _kiController,
                  hint: '0.05',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildParameterField(
                  label: 'Kd',
                  controller: _kdController,
                  hint: '0.75',
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
                    side: BorderSide(
                        color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Current Values Display
          ValueListenableBuilder<SerialData?>(
            valueListenable: widget.appState.currentData,
            builder: (context, data, child) {
              if (data is! DebugData) return const SizedBox.shrink();

              final position = data.line != null && data.line!.isNotEmpty ? data.line![0] : 0.0;

              return Container(
                padding: const EdgeInsets.all(8),
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
                    const SizedBox(height: 6),
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
}

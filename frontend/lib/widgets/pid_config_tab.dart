import 'package:flutter/material.dart';
import '../line_follower_state.dart';
import '../arduino_data.dart';

class PIDConfigTab extends StatelessWidget {
  final LineFollowerState provider;

  const PIDConfigTab({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPIDControlCard(provider, context),
          const SizedBox(height: 32), // Extra space at bottom
        ],
      ),
    );
  }

  Widget _buildPIDControlCard(LineFollowerState provider, BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Configuración PID',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<ArduinoPIDConfig>(
              valueListenable: provider.pidConfig,
              builder: (context, config, child) {
                return Column(
                  children: [
                    _buildSliderRow('Kp', 0.0, 5.0, config.kp, (value) {
                      _updatePIDConfig(provider, kp: value);
                    }),
                    _buildSliderRow('Ki', 0.0, 1.0, config.ki, (value) {
                      _updatePIDConfig(provider, ki: value);
                    }),
                    _buildSliderRow('Kd', 0.0, 1.0, config.kd, (value) {
                      _updatePIDConfig(provider, kd: value);
                    }),
                    _buildSliderRow(
                      'Punto de Referencia',
                      0.0,
                      config.setpoint == 2500 ? 5000.0 : 7000.0,
                      config.setpoint,
                      (value) {
                        _updatePIDConfig(provider, setpoint: value);
                      }
                    ),
                    _buildSliderRow(
                      'Velocidad Base', 0.0, 1.0, config.baseSpeed,
                      (value) {
                        _updatePIDConfig(provider, baseSpeed: value);
                      }
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliderRow(String label, double min, double max, double value,
      Function(double) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label),
              Text(value.toStringAsFixed(2)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
            onChangeEnd: (value) {
              // Configuration is already updated in real-time
            },
          ),
        ],
      ),
    );
  }

  void _updatePIDConfig(LineFollowerState provider,
      {double? kp,
      double? ki,
      double? kd,
      double? setpoint,
      double? baseSpeed}) {
    final currentConfig = provider.pidConfig.value;
    final config = ArduinoPIDConfig(
      kp: kp ?? currentConfig.kp,
      ki: ki ?? currentConfig.ki,
      kd: kd ?? currentConfig.kd,
      setpoint: setpoint ?? currentConfig.setpoint,
      baseSpeed: baseSpeed ?? currentConfig.baseSpeed,
    );
    provider.updatePIDConfig(config);
  }

}
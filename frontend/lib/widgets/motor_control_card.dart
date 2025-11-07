import 'package:flutter/material.dart';
import '../line_follower_state.dart';
import '../arduino_data.dart';

class MotorControlCard extends StatelessWidget {
  final LineFollowerState provider;

  const MotorControlCard({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Control de Motores',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<ArduinoData?>(
              valueListenable: provider.currentData,
              builder: (context, data, child) {
                if (data != null) {
                  return Column(
                    children: [
                      // Mode indicator
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              data.mode.icon,
                              size: 16,
                              color: colorScheme.onPrimaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              data.mode.displayName,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Encoder speeds
                      Row(
                        children: [
                          Expanded(
                            child: _buildTachometer(
                              'Velocidad Izquierda',
                              data.leftEncoderSpeed.abs(),
                              max: 100,
                              unit: 'cm/s',
                              color: data.leftEncoderSpeed >= 0 ? colorScheme.primary : colorScheme.error,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTachometer(
                              'Velocidad Derecha',
                              data.rightEncoderSpeed.abs(),
                              max: 100,
                              unit: 'cm/s',
                              color: data.rightEncoderSpeed >= 0 ? colorScheme.primary : colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                      // Mode-specific data
                      if (data.isAutopilotMode && (data.throttle != null || data.turn != null)) ...[
                        const SizedBox(height: 16),
                        _buildAutopilotData(data, theme, colorScheme),
                      ] else if (data.isManualMode && (data.leftSpeed != null || data.rightSpeed != null)) ...[
                        const SizedBox(height: 16),
                        _buildManualData(data, theme, colorScheme),
                      ],
                    ],
                  );
                } else {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'No hay datos de motor disponibles',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAutopilotData(ArduinoData data, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        children: [
          Text(
            'Datos Autopilot',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (data.throttle != null)
                _buildDataPoint('Acelerador', '${(data.throttle! * 100).toStringAsFixed(0)}%'),
              if (data.turn != null)
                _buildDataPoint('Dirección', '${(data.turn! * 100).toStringAsFixed(0)}%'),
              if (data.brake != null)
                _buildDataPoint('Freno', '${(data.brake! * 100).toStringAsFixed(0)}%'),
              if (data.direction != null)
                _buildDataPoint('Marcha', data.direction! > 0 ? 'Adelante' : 'Atrás'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManualData(ArduinoData data, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        children: [
          Text(
            'Datos Manual',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              if (data.leftSpeed != null)
                _buildDataPoint('Rueda Izq', '${(data.leftSpeed! * 100).toStringAsFixed(0)}%'),
              if (data.rightSpeed != null)
                _buildDataPoint('Rueda Der', '${(data.rightSpeed! * 100).toStringAsFixed(0)}%'),
              if (data.maxSpeed != null)
                _buildDataPoint('Vel Max', '${(data.maxSpeed! * 100).toStringAsFixed(0)}%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataPoint(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildTachometer(
    String label,
    double value, {
    double max = 100,
    String unit = '',
    Color color = Colors.blue,
  }) {
    final percentage = (value / max).clamp(0.0, 1.0);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Stack(
              alignment: Alignment.center,
              children: [
                // Background circle
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.grey.shade100,
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                  ),
                ),
                // Center text
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    if (unit.isNotEmpty)
                      Text(
                        unit,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ],
        ),
      ),
    );
  }
}
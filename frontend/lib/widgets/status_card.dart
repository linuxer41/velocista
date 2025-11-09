import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import '../app_state.dart';
import '../arduino_data.dart';

class StatusCard extends StatelessWidget {
  final AppState provider;

  const StatusCard({
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
              'Estado del Sistema',
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
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
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
                      // Line Following specific data
                      if (data.isLineFollowingMode) ...[
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: _buildStatusTachometer(
                                'Posición',
                                data.position ?? 0,
                                max: 5000,
                                color: colorScheme.primary,
                                unit: '',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: _buildStatusTachometer(
                                'Error',
                                data.error?.abs() ?? 0,
                                max: 1000,
                                color: (data.error ?? 0) >= 0
                                    ? colorScheme.primary
                                    : colorScheme.secondary,
                                unit: '',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: _buildStatusCard(
                                'Línea',
                                data.isLineDetected ? 'Detectada' : 'Perdida',
                                data.isLineDetected
                                    ? colorScheme.primary
                                    : colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: _buildTachometer(
                                'Velocidad Izq',
                                data.leftSpeedCmd?.abs() ?? 0,
                                max: 1.0,
                                unit: '',
                                color: (data.leftSpeedCmd ?? 0) >= 0
                                    ? colorScheme.primary
                                    : colorScheme.error,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: _buildTachometer(
                                'Velocidad Der',
                                data.rightSpeedCmd?.abs() ?? 0,
                                max: 1.0,
                                unit: '',
                                color: (data.rightSpeedCmd ?? 0) >= 0
                                    ? colorScheme.primary
                                    : colorScheme.error,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: _buildTachometer(
                                'Distancia',
                                data.totalDistance,
                                max: 1000,
                                unit: 'cm',
                                color: colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ]
                      // Autopilot specific data
                      else if (data.isAutopilotMode) ...[
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: _buildStatusTachometer(
                                'Acelerador',
                                data.throttle?.abs() ?? 0,
                                max: 1.0,
                                color: colorScheme.primary,
                                unit: '',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: _buildStatusTachometer(
                                'Dirección',
                                data.turn?.abs() ?? 0,
                                max: 1.0,
                                color: colorScheme.secondary,
                                unit: '',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: _buildStatusTachometer(
                                'Freno',
                                data.brake ?? 0,
                                max: 1.0,
                                color: Colors.orange,
                                unit: '',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: _buildTachometer(
                                'Velocidad Izq',
                                data.leftEncoderSpeed.abs(),
                                max: 100,
                                unit: 'cm/s',
                                color: data.leftEncoderSpeed >= 0
                                    ? colorScheme.primary
                                    : colorScheme.error,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: _buildTachometer(
                                'Velocidad Der',
                                data.rightEncoderSpeed.abs(),
                                max: 100,
                                unit: 'cm/s',
                                color: data.rightEncoderSpeed >= 0
                                    ? colorScheme.primary
                                    : colorScheme.error,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: _buildTachometer(
                                'Distancia',
                                data.totalDistance,
                                max: 1000,
                                unit: 'cm',
                                color: colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                        if (data.direction != null) ...[
                          const SizedBox(height: 16),
                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 6, horizontal: 12),
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: colorScheme.outline),
                              ),
                              child: Text(
                                'Marcha: ${data.direction! > 0 ? "Adelante" : "Atrás"}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ]
                      // Manual specific data
                      else if (data.isManualMode) ...[
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: _buildStatusTachometer(
                                'Rueda Izq',
                                data.leftSpeed?.abs() ?? 0,
                                max: 1.0,
                                color: colorScheme.primary,
                                unit: '',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: _buildStatusTachometer(
                                'Rueda Der',
                                data.rightSpeed?.abs() ?? 0,
                                max: 1.0,
                                color: colorScheme.secondary,
                                unit: '',
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: _buildStatusTachometer(
                                'Vel Max',
                                data.maxSpeed ?? 0,
                                max: 1.0,
                                color: Colors.orange,
                                unit: '',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: _buildTachometer(
                                'Velocidad Izq',
                                data.leftEncoderSpeed.abs(),
                                max: 100,
                                unit: 'cm/s',
                                color: data.leftEncoderSpeed >= 0
                                    ? colorScheme.primary
                                    : colorScheme.error,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: _buildTachometer(
                                'Velocidad Der',
                                data.rightEncoderSpeed.abs(),
                                max: 100,
                                unit: 'cm/s',
                                color: data.rightEncoderSpeed >= 0
                                    ? colorScheme.primary
                                    : colorScheme.error,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child: _buildTachometer(
                                'Distancia',
                                data.totalDistance,
                                max: 1000,
                                unit: 'cm',
                                color: colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      Icon(
                        Icons.sensors_off,
                        size: 48,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Esperando datos del robot velocista...',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'El dispositivo Bluetooth no está enviando datos en el formato correcto o no es un robot velocista',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTachometer(
    String label,
    double value, {
    double max = 100,
    String unit = '',
    Color color = Colors.blue,
  }) {
    final percentage = (value / max).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Stack(
            alignment: Alignment.center,
            children: [
              // Background circle
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade100,
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
              ),
              // Center text
              Text(
                value.toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200, width: 1),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.1),
              border: Border.all(color: color, width: 2),
            ),
            child: Center(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTachometer(
    String label,
    double value, {
    double max = 100,
    String unit = '',
    Color color = Colors.blue,
  }) {
    return _buildStatusTachometer(
      label,
      value,
      max: max,
      color: color,
      unit: unit,
    );
  }
}

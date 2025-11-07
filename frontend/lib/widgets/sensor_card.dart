import 'package:flutter/material.dart';
import '../line_follower_state.dart';
import '../arduino_data.dart';

class SensorCard extends StatelessWidget {
  final LineFollowerState provider;

  const SensorCard({
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
            ValueListenableBuilder<ArduinoData?>(
              valueListenable: provider.currentData,
              builder: (context, data, child) {
                String title;
                if (data == null) {
                  title = 'Sensores QTR (0 sensores)';
                } else if (data.isLineFollowingMode) {
                  title = 'Sensores QTR (${data.sensorCount} sensores) - Línea';
                } else {
                  title = 'Sensores QTR (${data.sensorCount} sensores) - ${data.mode.displayName}';
                }
                
                return Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            ValueListenableBuilder<ArduinoData?>(
              valueListenable: provider.currentData,
              builder: (context, data, child) {
                if (data != null && data.sensors.isNotEmpty) {
                  return _buildSensorGrid(data);
                } else if (data != null && !data.isLineFollowingMode) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sensors_off,
                            size: 48,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Sensores deshabilitados en modo ${data.mode.displayName}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Text(
                        'No hay datos de sensores disponibles',
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

  Widget _buildSensorGrid(ArduinoData data) {
    return RepaintBoundary(
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: false,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          childAspectRatio: 1.2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
        ),
        itemCount: data.sensorCount,
        itemBuilder: (context, index) {
          final value = data.getSensorValue(index);
          final isOnLine = data.isSensorOnLine(index);
          final color = isOnLine ? Colors.red : Colors.green;
          final bgColor = isOnLine ? Colors.red.shade50 : Colors.green.shade50;
          final borderColor = isOnLine ? Colors.red.shade200 : Colors.green.shade200;

          return Container(
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: borderColor, width: 2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'S${index + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.toString(),
                  style: const TextStyle(fontSize: 11),
                ),
                Text(
                  isOnLine ? 'LÍNEA' : 'LIMPIO',
                  style: TextStyle(
                    fontSize: 9,
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
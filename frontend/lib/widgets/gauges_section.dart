import 'package:flutter/material.dart';
import '../app_state.dart';
import '../arduino_data.dart';
import 'gauges.dart';

class GaugesSection extends StatelessWidget {
  final AppState appState;

  const GaugesSection({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TelemetryData?>(
      valueListenable: appState.telemetryData,
      builder: (context, data, child) {
        // Use telemetry data for live displays
        final leftRpm = (data != null &&
                data.left != null &&
                data.left!.isNotEmpty)
            ? data.left![0] // RPM from telemetry data
            : 0.0;
        final rightRpm = (data != null &&
                data.right != null &&
                data.right!.isNotEmpty)
            ? data.right![0] // RPM from telemetry data
            : 0.0;
        final leftSpeed = (data != null &&
                data.speedCms != null &&
                data.speedCms!.isNotEmpty)
            ? data.speedCms![0] / 100 // cm/s to m/s
            : leftRpm * 0.036 / 3.6; // RPM to m/s
        final rightSpeed = (data != null &&
                data.speedCms != null &&
                data.speedCms!.length >= 2)
            ? data.speedCms![1] / 100 // cm/s to m/s
            : rightRpm * 0.036 / 3.6; // RPM to m/s
        final averageSpeed = (leftSpeed + rightSpeed) / 2 * 3.6; // Average speed in km/h

        return Column(
          children: [
            // Spacer at top for more space
            const SizedBox(height: 8),
            // Large centered speed gauge
            SizedBox(
              height: 100,
              child: Center(
                child: LargeGauge(
                  value: averageSpeed,
                  unit: 'km/h',
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 2),
            // Two RPM gauges side by side
            SizedBox(
              height: 70,
              child: Row(
                children: [
                  Expanded(
                    child: CompactGauge(
                      title: 'L',
                      value: leftRpm,
                      unit: 'rpm',
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: CompactGauge(
                      title: 'R',
                      value: rightRpm,
                      unit: 'rpm',
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Distance and Acceleration
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: ValueListenableBuilder<SerialData?>(
                valueListenable: appState.currentData,
                builder: (context, data, child) {
                  const distance = '0.0'; // Not available in new format
                  return Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Distancia',
                              style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontFamily: 'Space Grotesk',
                              ),
                            ),
                            Text(
                              '$distance km',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface,
                                fontFamily: 'Space Grotesk',
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'Aceleración',
                              style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontFamily: 'Space Grotesk',
                              ),
                            ),
                            ValueListenableBuilder<double>(
                              valueListenable: appState.acceleration,
                              builder: (context, accel, child) {
                                return Text(
                                  '${accel.toStringAsFixed(1)} m/s²',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface,
                                    fontFamily: 'Space Grotesk',
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 4),
            // Sensor status - 8 sensors as bars
            ValueListenableBuilder<TelemetryData?>(
              valueListenable: appState.telemetryData,
              builder: (context, telemetryData, child) {
                return Container(
                  height: 70,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withOpacity(0.1),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Sensores QTR',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(8, (index) {
                          // Reverse order: sensor 1 on right, sensor 8 on left
                          final reversedIndex = 7 - index;
                          // All sensors 1-8 (indices 0-7) are active, telemetry sends values for all sensors
                          const isActive = true;
                          final sensorIndex = reversedIndex; // Map to telemetry array (0-7)

                          final sensorValue = isActive &&
                                  telemetryData != null &&
                                  telemetryData.sensors.length > sensorIndex
                              ? telemetryData.sensors[sensorIndex] // Use telemetry QTR data
                              : 0;
                          final percentage = (sensorValue / 1023.0).clamp(0.0, 1.0);

                          return Container(
                            width: 20,
                            height: 35,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            child: Column(
                              children: [
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest
                                          : Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest
                                              .withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.bottomCenter,
                                      heightFactor: isActive ? percentage : 0.0,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: isActive
                                              ? Colors.black
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant
                                                  .withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Column(
                                  children: [
                                    Text(
                                      '$sensorValue',
                                      style: TextStyle(
                                        fontSize: 6,
                                        color: isActive
                                            ? Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant
                                                .withOpacity(0.8)
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant
                                                .withOpacity(0.3),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    Text(
                                      '${reversedIndex + 1}',
                                      style: TextStyle(
                                        fontSize: 7,
                                        color: isActive
                                            ? Theme.of(context)
                                                .colorScheme
                                                .onSurface
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant
                                                .withOpacity(0.5),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}
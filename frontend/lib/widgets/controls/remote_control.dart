import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../../app_state.dart';
import '../../arduino_data.dart';


class RobotControlPanel extends StatelessWidget {
  final AppState provider;
  final ArduinoData data;

  const RobotControlPanel({
    super.key,
    required this.provider,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.surface.withOpacity(0.9),
            colorScheme.surface.withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // 🔭 Estado del robot
          _buildStatusHeader(colorScheme),
          const SizedBox(height: 20),

          // 🧭 Joystick virtual
          _buildJoystick(context),
          const SizedBox(height: 20),

          // 📊 Métricas en tiempo real
          _buildMetricsRow(colorScheme),
        ],
      ),
    );
  }

  Widget _buildStatusHeader(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MODO REMOTO',
              style: TextStyle(
                color: colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            Text(
              'Conectado',
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 12,
              ),
            ),
          ],
        ),
        Icon(Icons.wifi_tethering, color: colorScheme.primary),
      ],
    );
  }

  Widget _buildJoystick(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
          width: 2,
        ),
      ),
      child: GestureDetector(
        onPanUpdate: (details) {
          final renderBox = context.findRenderObject() as RenderBox;
          final localPosition = renderBox.globalToLocal(details.globalPosition);
          final center = const Offset(100, 100);
          final delta = localPosition - center;
          final throttle = (delta.dy / 100).clamp(-1.0, 1.0) * -1;
          final turn = (delta.dx / 100).clamp(-1.0, 1.0);

          provider.sendCommand({
            'remote_control': {
              'throttle': throttle,
              'turn': turn,
            }
          });
        },
        onPanEnd: (_) {
          provider.sendCommand({
            'remote_control': {'throttle': 0, 'turn': 0}
          });
        },
        child: Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                  blurRadius: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricsRow(ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildMetricGauge('Velocidad', data.leftEncoderSpeed, 100, 'cm/s'),
        _buildMetricGauge('Distancia', data.totalDistance, 200, 'cm'),
      ],
    );
  }

  Widget _buildMetricGauge(String label, double value, double max, String unit) {
    return Column(
      children: [
        SizedBox(
          width: 100,
          height: 100,
          child: SfRadialGauge(
            axes: [
              RadialAxis(
                minimum: 0,
                maximum: max,
                showLabels: false,
                showTicks: false,
                startAngle: 180,
                endAngle: 0,
                axisLineStyle: const AxisLineStyle(
                  thickness: 0.1,
                  thicknessUnit: GaugeSizeUnit.factor,
                ),
                pointers: [
                  RangePointer(
                    value: value,
                    width: 0.1,
                    sizeUnit: GaugeSizeUnit.factor,
                    color: Colors.cyanAccent,
                  ),
                  MarkerPointer(
                    value: value,
                    markerType: MarkerType.circle,
                    color: Colors.white,
                  ),
                ],
              ),
            ],
          ),
        ),
        Text(
          '$label\n${value.toStringAsFixed(1)} $unit',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
      ],
    );
  }
}
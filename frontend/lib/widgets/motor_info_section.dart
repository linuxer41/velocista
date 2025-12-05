import 'package:flutter/material.dart';
import '../app_state.dart';
import '../arduino_data.dart';
import 'config_data_section.dart';

class MotorInfoSection extends StatelessWidget {
  final AppState appState;

  const MotorInfoSection({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ValueListenableBuilder<OperationMode>(
        valueListenable: appState.currentMode,
        builder: (context, mode, child) {
          return ValueListenableBuilder<TelemetryData?>(
            valueListenable: appState.telemetryData,
            builder: (context, telemetryData, child) {
              return ValueListenableBuilder<DebugData?>(
                valueListenable: appState.debugData,
                builder: (context, debugData, child) {
                  // Extract data with defaults
                  final leftData = telemetryData?.left ?? [
                    0.0,
                    0.0,
                    0.0,
                    0,
                    0.0,
                    0.0,
                    0.0,
                    0.0
                  ];
                  final rightData = telemetryData?.right ?? [
                    0.0,
                    0.0,
                    0.0,
                    0,
                    0.0,
                    0.0,
                    0.0,
                    0.0
                  ];
                  final lineData = telemetryData?.line ?? [0.0, 0.0, 0.0, 0.0, 0.0];
                  final pidData = telemetryData?.pid ?? [0.0, 0.0, 0.0];
                  final config = appState.configData.value;
                  final lineKPid = config?.lineKPid ?? [0.900, 0.010, 0.020];
                  final leftKPid = config?.leftKPid ?? [0.590, 0.001, 0.0025];
                  final rightKPid = config?.rightKPid ?? [0.590, 0.001, 0.050];
                  final baseData = config?.base ?? [200.0, 120.0];
                  final maxData = config?.max ?? [230.0, 300.0];
                  final wheelsData = config?.wheels ?? [32.0, 85.0];
                  final weightData = config?.weight ?? 155.0;
                  final sampRateData = config?.sampRate ?? [2, 1, 100];
                  final modeData = config?.mode ?? 0;
                  final cascadeData = config?.cascade ?? 1;
                  final telemetryConfig = config?.telemetry ?? 0;

                  // Left motor
                  final leftRpm = leftData.isNotEmpty ? leftData[0] : 0.0;
                  final leftTargetRpm = leftData.length > 1 ? leftData[1] : 0.0;
                  final leftPwm = leftData.length > 2 ? leftData[2] : 0.0;
                  final leftEncoder = leftData.length > 3 ? leftData[3].toInt() : 0;
                  final leftDirection = leftData.length > 4 ? leftData[4] : 0.0;
                  final leftIntegral = leftData.length > 5 ? leftData[5] : 0.0;
                  final leftDerivative = leftData.length > 6 ? leftData[6] : 0.0;
                  final leftError = leftData.length > 7 ? leftData[7] : 0.0;

                  // Right motor
                  final rightRpm = rightData.isNotEmpty ? rightData[0] : 0.0;
                  final rightTargetRpm = rightData.length > 1 ? rightData[1] : 0.0;
                  final rightPwm = rightData.length > 2 ? rightData[2] : 0.0;
                  final rightEncoder = rightData.length > 3 ? rightData[3].toInt() : 0;
                  final rightDirection = rightData.length > 4 ? rightData[4] : 0.0;
                  final rightIntegral = rightData.length > 5 ? rightData[5] : 0.0;
                  final rightDerivative = rightData.length > 6 ? rightData[6] : 0.0;
                  final rightError = rightData.length > 7 ? rightData[7] : 0.0;

                  // Line following
                  final lineError = lineData.length > 1 ? lineData[1] : 0.0;
                  final lineIntegral = lineData.length > 2 ? lineData[2] : 0.0;
                  final lineDerivative = lineData.length > 3 ? lineData[3] : 0.0;

                  return Column(
                    children: [
                      // Motor Information - 3 Column Layout
                      Row(
                        children: [
                          // Left Motor
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.only(right: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Motor Izquierdo',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontFamily: 'Space Grotesk',
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'RPM Actual: ${leftRpm.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    'RPM Objetivo: ${leftTargetRpm.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    'PWM Actual: ${leftPwm.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    'Encoder: $leftEncoder',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    'Dirección: ${leftDirection.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    'Error: ${leftError.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    'Integral: ${leftIntegral.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    'Derivada: ${leftDerivative.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Right Motor
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              margin: const EdgeInsets.only(left: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Motor Derecho',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontFamily: 'Space Grotesk',
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'RPM Actual: ${rightRpm.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    'RPM Objetivo: ${rightTargetRpm.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    'PWM Actual: ${rightPwm.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    'Encoder: $rightEncoder',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    'Dirección: ${rightDirection.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    'Error: ${rightError.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    'Integral: ${rightIntegral.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Text(
                                    'Derivada: ${rightDerivative.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Line Following below motors
                      if (mode == OperationMode.lineFollowing)
                        Container(
                          padding: const EdgeInsets.all(8),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Seguimiento',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  fontFamily: 'Space Grotesk',
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Posición: ${lineData[0].toStringAsFixed(1)}',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        Text(
                                          'Error: ${lineData[1].toStringAsFixed(1)}',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        Text(
                                          'Integral: ${lineData[2].toStringAsFixed(1)}',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Derivada: ${lineData[3].toStringAsFixed(1)}',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        Text(
                                          'Salida PID: ${lineData[4].toStringAsFixed(1)}',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Curvatura: ${telemetryData?.curv?.toStringAsFixed(1) ?? '0.0'}',
                                      style: TextStyle(
                                        fontSize: 9,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              // Features status
                              ValueListenableBuilder<ConfigData?>(
                                valueListenable: appState.configData,
                                builder: (context, configData, child) {
                                  final featConfig = configData?.featConfig;
                                  if (featConfig == null || featConfig.length != 8) {
                                    return const SizedBox.shrink();
                                  }

                                  final featureNames = [
                                    'MED',
                                    'MA',
                                    'KAL',
                                    'HYS',
                                    'DZ',
                                    'LP',
                                    'APID',
                                    'SP',
                                    'DIR'
                                  ];
                                  final activeFeatures = <String>[];

                                  for (int i = 0; i < featConfig.length; i++) {
                                    if (featConfig[i] == 1) {
                                      activeFeatures.add(featureNames[i]);
                                    }
                                  }

                                  if (activeFeatures.isEmpty) {
                                    return Text(
                                      'Features: ninguno activo',
                                      style: TextStyle(
                                        fontSize: 8,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    );
                                  }

                                  return Text(
                                    'Features: ${activeFeatures.join(', ')}',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 10),
                      // Config Data - Expandable Accordion
                      ConfigDataSection(appState: appState),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
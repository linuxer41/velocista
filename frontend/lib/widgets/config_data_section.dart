import 'package:flutter/material.dart';
import '../app_state.dart';
import '../arduino_data.dart';

class ConfigDataSection extends StatefulWidget {
  final AppState appState;

  const ConfigDataSection({super.key, required this.appState});

  @override
  State<ConfigDataSection> createState() => _ConfigDataSectionState();
}

class _ConfigDataSectionState extends State<ConfigDataSection> {
  bool _configExpanded = false;

  @override
  Widget build(BuildContext context) {
    final config = widget.appState.configData.value;
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

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        shape: Border.all(width: 0, color: Colors.transparent),
        title: Text(
          'Datos de Configuración',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
            fontFamily: 'Space Grotesk',
          ),
        ),
        initiallyExpanded: _configExpanded,
        onExpansionChanged: (expanded) {
          setState(() {
            _configExpanded = expanded;
          });
        },
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                // 3 Column PID Layout
                Row(
                  children: [
                    // Línea Column
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(right: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Línea',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'KP: ${lineKPid[0].toStringAsFixed(3)}',
                              style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              'KI: ${lineKPid[1].toStringAsFixed(3)}',
                              style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              'KD: ${lineKPid[2].toStringAsFixed(3)}',
                              style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Izquierdo Column
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Izquierdo',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'KP: ${leftKPid[0].toStringAsFixed(3)}',
                              style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              'KI: ${leftKPid[1].toStringAsFixed(3)}',
                              style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              'KD: ${leftKPid[2].toStringAsFixed(3)}',
                              style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Derecho Column
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(left: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Derecho',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'KP: ${rightKPid[0].toStringAsFixed(3)}',
                              style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              'KI: ${rightKPid[1].toStringAsFixed(3)}',
                              style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              'KD: ${rightKPid[2].toStringAsFixed(3)}',
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
                const SizedBox(height: 8),
                // Base, Max and Wheels
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(right: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Base',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'rpm: ${baseData[1].toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              'pwm: ${baseData[0].toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Max',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'rpm: ${maxData[1].toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              'pwm: ${maxData[0].toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(left: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ruedas',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Diam.: ${wheelsData[0].toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              'Sep.: ${wheelsData[1].toStringAsFixed(2)}',
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
                const SizedBox(height: 8),
                // Weight and Sampling Rate
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(right: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Peso',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${weightData.toStringAsFixed(1)} g',
                              style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(left: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Muestreo',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Línea: ${sampRateData.isNotEmpty ? sampRateData[0] : 2}ms',
                              style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              'Velocidad: ${sampRateData.length > 1 ? sampRateData[1] : 1}ms',
                              style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              'Telemetría: ${sampRateData.length > 2 ? sampRateData[2] : 100}ms',
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
                const SizedBox(height: 8),
                // Operation and Control
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Operación y Control',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Modo: ${modeData == 0 ? 'Reposo' : modeData == 1 ? 'Seguimiento' : 'Remoto'}',
                              style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'Cascada: ${cascadeData == 1 ? 'Activada' : 'Desactivada'}',
                              style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Telemetría: ${telemetryConfig == 1 ? 'Activada' : 'Desactivada'}',
                        style: TextStyle(
                          fontSize: 9,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // Features Status
                ValueListenableBuilder<ConfigData?>(
                  valueListenable: widget.appState.configData,
                  builder: (context, configData, child) {
                    final featConfig = configData?.featConfig;
                    if (featConfig == null || featConfig.length != 9) {
                      return const SizedBox.shrink();
                    }

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Features',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'MED:${featConfig[0]} MA:${featConfig[1]} KAL:${featConfig[2]} HYS:${featConfig[3]} DZ:${featConfig[4]} LP:${featConfig[5]} APID:${featConfig[6]} SP:${featConfig[7]} DIR:${featConfig[8]}',
                            style: TextStyle(
                              fontSize: 8,
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
          ),
        ],
      ),
    );
  }
}
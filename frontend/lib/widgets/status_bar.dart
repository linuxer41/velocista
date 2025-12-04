import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../app_state.dart';
import '../arduino_data.dart';
import '../connection_bottom_sheet.dart';

class StatusBar extends StatelessWidget {
  final AppState appState;
  final VoidCallback onShowConnectionModal;

  const StatusBar(
      {super.key, required this.appState, required this.onShowConnectionModal});

  double _calculateBatteryPercentage(double voltage) {
    const double maxVoltage = 8.8; // 100%
    const double minVoltage = 7.0; // 0%

    if (voltage >= maxVoltage) return 100.0;
    if (voltage <= minVoltage) return 0.0;

    return ((voltage - minVoltage) / (maxVoltage - minVoltage)) * 100.0;
  }

  IconData _getBatteryIcon(double percentage) {
    if (percentage >= 90) return Icons.battery_full;
    if (percentage >= 80) return Icons.battery_6_bar;
    if (percentage >= 60) return Icons.battery_5_bar;
    if (percentage >= 40) return Icons.battery_4_bar;
    if (percentage >= 20) return Icons.battery_3_bar;
    if (percentage >= 10) return Icons.battery_2_bar;
    if (percentage >= 5) return Icons.battery_1_bar;
    return Icons.battery_0_bar;
  }

  Color _getBatteryColor(double percentage) {
    if (percentage >= 50) {
      // Green to Yellow transition (50% to 100%)
      const greenValue = 255;
      final redValue = (percentage - 50) * 5.1; // 0 to 255
      return Color.fromARGB(255, redValue.toInt(), greenValue, 0);
    } else {
      // Red to Yellow transition (0% to 50%)
      const redValue = 255;
      final greenValue = percentage * 5.1; // 0 to 255
      return Color.fromARGB(255, redValue, greenValue.toInt(), 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: ValueListenableBuilder<TelemetryData?>(
        valueListenable: appState.telemetryData,
        builder: (context, telemetryData, child) {
          final batteryVoltage = telemetryData?.batt ?? 7.4;
          final batteryPercentage = _calculateBatteryPercentage(batteryVoltage);
          final isConnected = appState.isConnected.value;

          return Row(
            children: [
              // Left column: Battery and Time
              Row(
                children: [
                  // Battery icon and voltage/percentage
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getBatteryIcon(batteryPercentage),
                        color: _getBatteryColor(batteryPercentage),
                        size: 20,
                      ),
                      // const SizedBox(width: 2),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${batteryVoltage.toStringAsFixed(1)}v',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).colorScheme.onSurface,
                              fontFamily: 'Space Grotesk',
                              height: 1.0,
                            ),
                          ),
                          Text(
                            '${batteryPercentage.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                              fontFamily: 'Space Grotesk',
                              height: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  // Time
                  Text(
                    DateFormat('HH:mm').format(DateTime.now()),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontFamily: 'Space Grotesk',
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              // Right column: Mode selector and Connection indicator
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Mode selector
                    Container(
                      width: 100,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: ValueListenableBuilder<OperationMode>(
                        valueListenable: appState.currentMode,
                        builder: (context, currentMode, child) {
                          // Get short label for current mode
                          String shortLabel;
                          switch (currentMode) {
                            case OperationMode.idle:
                              shortLabel = 'Reposo';
                              break;
                            case OperationMode.lineFollowing:
                              shortLabel = 'Seguidor';
                              break;
                            case OperationMode.remoteControl:
                              shortLabel = 'RC';
                              break;
                          }

                          return PopupMenuButton<OperationMode>(
                            onSelected: (OperationMode mode) async {
                              await appState.changeOperationMode(mode);
                            },
                            itemBuilder: (BuildContext context) =>
                                OperationMode.values
                                    .map((OperationMode mode) {
                              return PopupMenuItem<OperationMode>(
                                value: mode,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(mode.displayName,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                    const SizedBox(height: 2),
                                    Text(mode.description,
                                        style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                                  ],
                                ),
                              );
                            }).toList(),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  currentMode.icon,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  size: 18,
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    shortLabel,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.onSurface,
                                      fontFamily: 'Space Grotesk',
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Theme.of(context).colorScheme.onSurface,
                                  size: 16,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Connection button/status
                    Expanded(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: appState.isConnected,
                        builder: (context, isConnected, child) {
                          return Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isConnected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.2)
                                  : Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: isConnected
                                  ? Border.all(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      width: 1,
                                    )
                                  : null,
                            ),
                            child: InkWell(
                              onTap: onShowConnectionModal,
                              borderRadius: BorderRadius.circular(6),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isConnected
                                        ? Icons.bluetooth_connected
                                        : Icons.bluetooth,
                                    size: 16,
                                    color: isConnected
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                  ),
                                  if (isConnected) ...[
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  appState
                                                              .connectedDevice
                                                              .value
                                                              ?.name
                                                              ?.isNotEmpty ==
                                                          true
                                                      ? appState.connectedDevice
                                                          .value!.name!
                                                      : 'Dispositivo',
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    fontWeight: FontWeight.w600,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary,
                                                    fontFamily: 'Space Grotesk',
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                                Text(
                                                  appState
                                                              .connectedDevice
                                                              .value
                                                              ?.address
                                                              .isNotEmpty ==
                                                          true
                                                      ? appState.connectedDevice
                                                          .value!.address
                                                      : 'Sin ID',
                                                  style: TextStyle(
                                                    fontSize: 6,
                                                    fontWeight: FontWeight.w400,
                                                    color: Theme.of(context)
                                                        .colorScheme
                                                        .primary
                                                        .withOpacity(0.8),
                                                    fontFamily: 'monospace',
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          Container(
                                            width: 20,
                                            height: 20,
                                            decoration: BoxDecoration(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .error
                                                  .withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: IconButton(
                                              onPressed: () async {
                                                await appState.disconnect();
                                              },
                                              icon: Icon(
                                                Icons.bluetooth_disabled,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .error,
                                                size: 12,
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              tooltip: 'Desconectar',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ] else ...[
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Desconectado',
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w600,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                              fontFamily: 'Space Grotesk',
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                          Text(
                                            'Conectar aquí',
                                            style: TextStyle(
                                              fontSize: 6,
                                              fontWeight: FontWeight.w400,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                                  .withOpacity(0.8),
                                              fontFamily: 'Space Grotesk',
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              )
            ],
          );
        },
      ),
    );
  }
}

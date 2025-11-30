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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: ValueListenableBuilder<SerialData?>(
        valueListenable: appState.currentData,
        builder: (context, data, child) {
          final battery = (data is DebugData) ? data.batt ?? 7.4 : 88.0;
          final isConnected = appState.isConnected.value;

          return Row(
            children: [
              // Left column: Battery and Time
              Row(
                children: [
                  // Battery icon and percentage
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.battery_6_bar,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 16,
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${battery.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                              fontFamily: 'Space Grotesk',
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
              // Right column: Action buttons and Connection indicator
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Terminal icon
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: IconButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/terminal');
                          },
                          icon: Icon(
                            Icons.terminal,
                            color: Theme.of(context).colorScheme.onSurface,
                            size: 20,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Mode selector
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: ValueListenableBuilder<OperationMode>(
                          valueListenable: appState.currentMode,
                          builder: (context, currentMode, child) {
                            return PopupMenuButton<OperationMode>(
                              onSelected: (OperationMode mode) async {
                                await appState.changeOperationMode(mode);
                              },
                              itemBuilder: (BuildContext context) =>
                                  OperationMode.values
                                      .map((OperationMode mode) {
                                return PopupMenuItem<OperationMode>(
                                  value: mode,
                                  child: Row(
                                    children: [
                                      Icon(mode.icon, size: 20),
                                      const SizedBox(width: 8),
                                      Text(mode.displayName,
                                          style: const TextStyle(fontSize: 12)),
                                    ],
                                  ),
                                );
                              }).toList(),
                              child: Icon(
                                currentMode.icon,
                                color: Theme.of(context).colorScheme.onSurface,
                                size: 20,
                              ),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            );
                          },
                        ),
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
                                                              ?.isNotEmpty ==
                                                          true
                                                      ? appState.connectedDevice
                                                          .value!.address!
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

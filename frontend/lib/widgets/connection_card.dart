import 'package:flutter/material.dart';
import 'package:flutter_blue_classic/flutter_blue_classic.dart';
import '../line_follower_state.dart';

class ConnectionCard extends StatelessWidget {
  final LineFollowerState provider;
  final VoidCallback onShowConnectionDialog;

  const ConnectionCard({
    super.key,
    required this.provider,
    required this.onShowConnectionDialog,
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
            // Title and Disp. counter on same line
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Conexión',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                InkWell(
                  onTap: onShowConnectionDialog,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.primary.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Disp.',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        ValueListenableBuilder<List<BluetoothDevice>>(
                          valueListenable: provider.discoveredDevices,
                          builder: (context, devices, child) {
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [

                                Text(
                                  '${devices.length}',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.bluetooth,
                                  size: 16,
                                  color: colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right,
                                  color: colorScheme.onSurfaceVariant,
                                  size: 16,
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Connection Info (Only text, no icons)
            Row(
              children: [
                Expanded(
                  child: ValueListenableBuilder<bool>(
                    valueListenable: provider.isConnected,
                    builder: (context, isConnected, child) {
                      if (isConnected) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Device Name
                            ValueListenableBuilder<String>(
                              valueListenable: provider.connectionStatus,
                              builder: (context, status, child) {
                                return Text(
                                  status,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                );
                              },
                            ),
                            const SizedBox(height: 4),
                            // Bluetooth Address
                            ValueListenableBuilder<BluetoothDevice?>(
                              valueListenable: provider.connectedDevice,
                              builder: (context, device, child) {
                                if (device != null) {
                                  return Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'BT: ${device.address}',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            fontFamily: 'monospace',
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        );
                      } else {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Desconectado',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Toque "Disp." para conectar',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        );
                      }
                    },
                  ),
                ),
                // Disconnect Button
                ValueListenableBuilder<bool>(
                  valueListenable: provider.isConnected,
                  builder: (context, isConnected, child) {
                    return isConnected
                        ? Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: ElevatedButton(
                              onPressed: provider.disconnect,
                              child: const Text('Desconectar'),
                            ),
                          )
                        : const SizedBox.shrink();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Connection Statistics
            ValueListenableBuilder<bool>(
              valueListenable: provider.isConnected,
              builder: (context, isConnected, child) {
                if (isConnected) {
                  return Container(
                    padding: const EdgeInsets.all(1),
                    child: Row(
                      children: [
                        Expanded(
                          child: ValueListenableBuilder<double>(
                            valueListenable: provider.dataRate,
                            builder: (context, dataRate, child) {
                              return _buildStatItem(
                                'Transferencia',
                                '${dataRate.toStringAsFixed(1)}/s',
                                Icons.speed,
                                colorScheme.primary,
                                theme,
                              );
                            },
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: colorScheme.outline,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        Expanded(
                          child: ValueListenableBuilder<String>(
                            valueListenable: provider.connectionDuration,
                            builder: (context, connectionDuration, child) {
                              return _buildStatItem(
                                'Tiempo Conexión',
                                connectionDuration,
                                Icons.access_time,
                                colorScheme.primary,
                                theme,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color, ThemeData theme) {
    final colorScheme = theme.colorScheme;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
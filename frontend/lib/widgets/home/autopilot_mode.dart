import 'package:flutter/material.dart';
import '../../app_state.dart';

class RemoteControlModeInterface extends StatelessWidget {
  final AppState provider;

  const RemoteControlModeInterface({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Title
          Text(
            'Control Remoto',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Controla el robot usando acelerador, dirección o control manual',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Controls
          _buildRemoteControl(context, provider),
        ],
      ),
    );
  }

  Widget _buildRemoteControl(BuildContext context, AppState provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // Autopilot controls (throttle/turn)
          Text(
            'Modo Autopilot',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                'Adelante',
                Icons.north,
                Colors.green,
                () => provider.sendCommand({
                  'remote_control': {'throttle': 0.5, 'turn': 0}
                }),
              ),
              _buildControlButton(
                'Frenar',
                Icons.stop,
                Colors.red,
                () => provider.sendCommand({
                  'remote_control': {'throttle': 0, 'turn': 0, 'brake': 1}
                }),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                'Izquierda',
                Icons.west,
                Colors.blue,
                () => provider.sendCommand({
                  'remote_control': {'throttle': 0.3, 'turn': -0.5}
                }),
              ),
              _buildControlButton(
                'Derecha',
                Icons.east,
                Colors.blue,
                () => provider.sendCommand({
                  'remote_control': {'throttle': 0.3, 'turn': 0.5}
                }),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Manual controls (left/right)
          Text(
            'Modo Manual',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                'Izq',
                Icons.arrow_back,
                Colors.orange,
                () => provider.sendCommand({
                  'remote_control': {'left': 0.8, 'right': 0}
                }),
              ),
              _buildControlButton(
                'Der',
                Icons.arrow_forward,
                Colors.orange,
                () => provider.sendCommand({
                  'remote_control': {'left': 0, 'right': 0.8}
                }),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Emergency stop
          _buildControlButton(
            'Parada de Emergencia',
            Icons.warning,
            Colors.red,
            () => provider.sendCommand({
              'remote_control': {'emergencyStop': true}
            }),
            isLarge: true,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onPressed, {
    bool isLarge = false,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: isLarge ? 24 : 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isLarge ? 32 : 24,
          vertical: isLarge ? 20 : 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isLarge ? 16 : 12),
        ),
      ),
    );
  }
}
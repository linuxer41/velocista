import 'package:flutter/material.dart';
import '../../app_state.dart';
import '../pid_config_dialog.dart';

class LineFollowingModeInterface extends StatelessWidget {
  final AppState provider;

  const LineFollowingModeInterface({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Text(
              'Modo Seguidor de Línea',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'El robot sigue automáticamente la línea negra usando sensores PID',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            _buildPIDControlButton(context, provider),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildPIDControlButton(BuildContext context, AppState provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 32),
      child: ElevatedButton.icon(
        onPressed: () => _showPIDConfigDialog(context, provider),
        icon: const Icon(Icons.tune, size: 20),
        label: const Text('Configuración PID'),
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showPIDConfigDialog(BuildContext context, AppState provider) {
    showDialog(
      context: context,
      builder: (context) {
        return PIDConfigDialog(provider: provider);
      },
    );
  }
}
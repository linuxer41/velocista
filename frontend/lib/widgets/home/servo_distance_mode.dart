import 'package:flutter/material.dart';
import '../../app_state.dart';

class ServoDistanceModeInterface extends StatelessWidget {
  final AppState provider;

  const ServoDistanceModeInterface({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Text(
              'Modo Servo Distance',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'El robot avanzará la distancia especificada\ny regresará automáticamente al punto de origen',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            _buildDistanceButtons(context, provider),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceButtons(BuildContext context, AppState provider) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        _buildDistanceButton('10 cm', 10, provider),
        _buildDistanceButton('25 cm', 25, provider),
        _buildDistanceButton('50 cm', 50, provider),
        _buildDistanceButton('100 cm', 100, provider),
      ],
    );
  }

  Widget _buildDistanceButton(String label, double distance, AppState provider) {
    return ElevatedButton.icon(
      onPressed: () => provider.sendCommand({'servoDistance': distance}),
      icon: const Icon(Icons.straighten),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
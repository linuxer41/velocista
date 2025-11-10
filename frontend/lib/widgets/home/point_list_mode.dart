import 'package:flutter/material.dart';
import '../../app_state.dart';

class PointListModeInterface extends StatelessWidget {
  final AppState provider;

  const PointListModeInterface({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Text(
              'Modo Point List',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'El robot recorrerá la secuencia de distancias y giros especificada',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Formato: distancia1,giro1,distancia2,giro2,...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            _buildRouteButtons(context, provider),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteButtons(BuildContext context, AppState provider) {
    return Column(
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            _buildRouteButton('Cuadrado', '20,90,20,90,20,90,20,90', provider),
            _buildRouteButton('Triángulo', '30,120,30,120,30,120', provider),
            _buildRouteButton(
                'Rectángulo', '40,90,20,90,40,90,20,90', provider),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => _showCustomRouteDialog(context, provider),
          icon: const Icon(Icons.edit),
          label: const Text('Ruta Personalizada'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRouteButton(String label, String routePoints, AppState provider) {
    return ElevatedButton(
      onPressed: () => provider.sendCommand({'routePoints': routePoints}),
      child: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  void _showCustomRouteDialog(BuildContext context, AppState provider) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ruta Personalizada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Formato: dist1,giro1,dist2,giro2,...\nEjemplo: 20,90,10,-90,20,0'),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: '20,90,20,90,20,90,20,90',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  provider.sendCommand({'routePoints': controller.text});
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
  }
}
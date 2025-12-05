import 'package:flutter/material.dart';
import '../app_state.dart';

class Point {
  double distance;
  double angle;

  Point({required this.distance, required this.angle});

  @override
  String toString() {
    return '${distance.toStringAsFixed(1)},${angle.toStringAsFixed(0)}';
  }
}

class ServoControl extends StatefulWidget {
  final AppState appState;

  const ServoControl({super.key, required this.appState});

  @override
  State<ServoControl> createState() => _PointListControlState();
}

class _PointListControlState extends State<ServoControl> {
  final List<Point> _points = [];
  final TextEditingController _distanceController = TextEditingController();
  final TextEditingController _angleController = TextEditingController();

  @override
  void dispose() {
    _distanceController.dispose();
    _angleController.dispose();
    super.dispose();
  }

  void _addPoint() {
    final distance = double.tryParse(_distanceController.text);
    final angle = double.tryParse(_angleController.text);

    if (distance != null && angle != null && distance > 0) {
      setState(() {
        _points.add(Point(distance: distance, angle: angle));
        _distanceController.clear();
        _angleController.clear();
      });
    }
  }

  void _removePoint(int index) {
    setState(() {
      _points.removeAt(index);
    });
  }

  void _sendRoute() {
    // Route points command removed in new protocol
    // This functionality is no longer available
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Funcionalidad de rutas no disponible en la nueva versión'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _clearRoute() {
    setState(() {
      _points.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lista de Puntos',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Space Grotesk',
            ),
          ),
          const SizedBox(height: 8),

          // Add Point Section
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Agregar Punto',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: TextField(
                          controller: _distanceController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Dist (cm)',
                            labelStyle: TextStyle(fontSize: 10),
                            hintText: '10.0',
                            hintStyle: TextStyle(fontSize: 10),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: SizedBox(
                        height: 32,
                        child: TextField(
                          controller: _angleController,
                          keyboardType:
                              const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Ángulo (°)',
                            labelStyle: TextStyle(fontSize: 10),
                            hintText: '0',
                            hintStyle: TextStyle(fontSize: 10),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    SizedBox(
                      height: 32,
                      child: ElevatedButton(
                        onPressed: _addPoint,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                        ),
                        child: const Text('+', style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Points List
          if (_points.isNotEmpty) ...[
            Text(
              'Puntos (${_points.length})',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxHeight: 100),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                ),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _points.length,
                itemBuilder: (context, index) {
                  final point = _points[index];
                  return ListTile(
                    dense: true,
                    visualDensity: VisualDensity.compact,
                    leading: CircleAvatar(
                      radius: 12,
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(0.1),
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    title: Text(
                      '${point.distance.toStringAsFixed(1)}cm, ${point.angle.toStringAsFixed(0)}°',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        Icons.delete,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: () => _removePoint(index),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
          ],

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _points.isNotEmpty ? _sendRoute : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  ),
                  child: const Text('Enviar', style: TextStyle(fontSize: 10)),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: OutlinedButton(
                  onPressed: _clearRoute,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    side:
                        BorderSide(color: Theme.of(context).colorScheme.error),
                    foregroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Limpiar', style: TextStyle(fontSize: 10)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Route Preview
          if (_points.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vista Previa',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _points.map((point) => point.toString()).join(' → '),
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Info Text
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Theme.of(context).colorScheme.secondary,
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Secuencia: distancia (cm), ángulo (grados).',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
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

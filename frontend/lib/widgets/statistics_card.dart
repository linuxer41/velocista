import 'package:flutter/material.dart';
import '../app_state.dart';

class StatisticsCard extends StatelessWidget {
  final AppState provider;

  const StatisticsCard({
    super.key,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final stats = provider.getSensorStatistics();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estadísticas (Últimas 20 lecturas)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            if (stats.isNotEmpty) ...[
              _buildStatRow(
                'Promedio Posición',
                stats['position']['avg'].toStringAsFixed(1),
                theme,
                colorScheme,
              ),
              _buildStatRow(
                'Promedio Error',
                stats['error']['avg'].toStringAsFixed(1),
                theme,
                colorScheme,
              ),
              _buildStatRow(
                'Promedio Velocidad Izq',
                stats['leftSpeed']['avg'].toStringAsFixed(2),
                theme,
                colorScheme,
              ),
              _buildStatRow(
                'Promedio Velocidad Der',
                stats['rightSpeed']['avg'].toStringAsFixed(2),
                theme,
                colorScheme,
              ),
            ] else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'No hay estadísticas disponibles',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(
      String label, String value, ThemeData theme, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

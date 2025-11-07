import 'package:flutter/material.dart';
import '../line_follower_state.dart';
import '../arduino_data.dart';
import '../theme_provider.dart';

class CustomFloatingActionButton extends StatefulWidget {
  final LineFollowerState provider;
  final ThemeProvider themeProvider;

  const CustomFloatingActionButton({
    super.key,
    required this.provider,
    required this.themeProvider,
  });

  @override
  State<CustomFloatingActionButton> createState() => _CustomFloatingActionButtonState();
}

class _CustomFloatingActionButtonState extends State<CustomFloatingActionButton>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Always expanded control buttons - icon only with solid colors
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.3),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Theme toggle button - icon only
              _buildControlButton(
                icon: widget.themeProvider.isDarkMode ? Icons.light_mode : Icons.dark_mode,
                onTap: () => _toggleTheme(),
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                shadowColor: const Color(0xFF667eea),
              ),
              const SizedBox(height: 8),
              // Mode change button - icon only
              _buildControlButton(
                icon: Icons.settings,
                onTap: () => _showModeSelectionDialog(),
                gradient: const LinearGradient(
                  colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
                ),
                shadowColor: const Color(0xFFf093fb),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Current mode indicator
        if (widget.provider.isConnected.value)
          ValueListenableBuilder<ArduinoData?>(
            valueListenable: widget.provider.currentData,
            builder: (context, data, child) {
              if (data == null) return const SizedBox.shrink();
              
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: colorScheme.outline,
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      data.mode.icon,
                      size: 16,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      data.mode.displayName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required Gradient gradient,
    required Color shadowColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: shadowColor.withOpacity(0.3 + _pulseAnimation.value * 0.2),
                  blurRadius: 8 + _pulseAnimation.value * 4,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: 24,
              color: Colors.white,
            ),
          );
        },
      ),
    );
  }

  void _toggleTheme() {
    widget.themeProvider.toggleTheme();
    
    // Show feedback message
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.themeProvider.isDarkMode 
                ? 'Cambiado a tema claro' 
                : 'Cambiado a tema oscuro',
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showModeSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cambiar Modo de Operación'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: OperationMode.values.map((mode) {
              return ListTile(
                leading: Icon(mode.icon),
                title: Text(mode.displayName),
                subtitle: _getModeDescription(mode),
                trailing: widget.provider.currentData.value?.mode == mode 
                    ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                    : null,
                onTap: () => _changeMode(mode),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Text? _getModeDescription(OperationMode mode) {
    switch (mode) {
      case OperationMode.lineFollowing:
        return const Text('Seguimiento automático de línea negra');
      case OperationMode.autopilot:
        return const Text('Control tipo vehículo triciclo');
      case OperationMode.manual:
        return const Text('Control directo de cada rueda');
    }
  }

  Future<void> _changeMode(OperationMode mode) async {
    Navigator.of(context).pop();
    
    await widget.provider.changeOperationMode(mode);
    
    // Show success message
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Modo cambiado a ${mode.displayName}'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}
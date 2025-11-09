import 'package:flutter/material.dart';
import '../app_state.dart';
import '../arduino_data.dart';

class ModeControlPanel extends StatefulWidget {
  final AppState provider;

  const ModeControlPanel({
    super.key,
    required this.provider,
  });

  @override
  State<ModeControlPanel> createState() => _ModeControlPanelState();
}

class _ModeControlPanelState extends State<ModeControlPanel> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main mode selector button
        FloatingActionButton(
          onPressed: _showModeSelectionDialog,
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          child: const Icon(Icons.settings),
          tooltip: 'Cambiar modo de operación',
        ),
        const SizedBox(height: 8),

        // Mode indicator when connected
        if (widget.provider.isConnected.value)
          ValueListenableBuilder<ArduinoData?>(
            valueListenable: widget.provider.currentData,
            builder: (context, data, child) {
              if (data == null) return const SizedBox.shrink();

              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colorScheme.outline),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      data.mode.icon,
                      size: 16,
                      color: colorScheme.onPrimaryContainer,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      data.mode.displayName,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

        // Control panels for different modes
        if (widget.provider.isConnected.value) ...[
          const SizedBox(height: 8),
          ValueListenableBuilder<ArduinoData?>(
            valueListenable: widget.provider.currentData,
            builder: (context, data, child) {
              if (data == null) return const SizedBox.shrink();

              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: _isExpanded ? null : 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Close button
                    IconButton(
                      onPressed: () => setState(() => _isExpanded = false),
                      icon: const Icon(Icons.close, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(height: 8),

                    // Mode-specific controls
                    if (data.isLineFollowingMode)
                      _buildLineFollowingControls(data, theme, colorScheme)
                    else if (data.isAutopilotMode)
                      _buildAutopilotControls(data, theme, colorScheme)
                    else if (data.isManualMode)
                      _buildManualControls(data, theme, colorScheme)
                    else if (data.isServoDistanceMode)
                      _buildServoDistanceControls(data, theme, colorScheme)
                    else if (data.isPointListMode)
                      _buildPointListControls(data, theme, colorScheme),
                  ],
                ),
              );
            },
          ),

          // Expand/collapse button
          if (widget.provider.isConnected.value)
            IconButton(
              onPressed: () => setState(() => _isExpanded = !_isExpanded),
              icon: Icon(
                _isExpanded ? Icons.expand_less : Icons.expand_more,
                color: colorScheme.onSurfaceVariant,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ],
    );
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
      case OperationMode.servoDistance:
        return const Text('Avanza X cm y regresa automáticamente');
      case OperationMode.pointList:
        return const Text('Recorre lista de tramos (distancia, giro)');
    }
  }

  Future<void> _changeMode(OperationMode mode) async {
    Navigator.of(context).pop();

    await widget.provider.changeOperationMode(mode);

    setState(() {
      _isExpanded = true;
    });

    // Show success message
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Modo cambiado a ${mode.displayName}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Widget _buildLineFollowingControls(
      ArduinoData data, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        children: [
          Text(
            'Control Line Following',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildControlButton(
                'PID',
                Icons.tune,
                () => _showPidDialog(),
                colorScheme.primary,
              ),
              _buildControlButton(
                'Stop',
                Icons.stop,
                () => _sendStopCommand(),
                Colors.red,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAutopilotControls(
      ArduinoData data, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        children: [
          Text(
            'Control Autopilot',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          // Safety commands (prominent)
          if (widget.provider.currentData.value != null &&
              widget.provider.currentData.value!.isAutopilotMode) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red, width: 2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildControlButton('EMERGENCIA', Icons.emergency,
                      () => _sendEmergencyStop(), Colors.red),
                  const SizedBox(width: 4),
                  _buildControlButton('PARK', Icons.local_parking,
                      () => _sendParkingBrake(), Colors.orange),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          // Regular control buttons
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildControlButton(
                  'Adelante',
                  Icons.north,
                  () => _sendAutopilotCommand(throttle: 0.7, turn: 0),
                  colorScheme.primary),
              _buildControlButton(
                  'Izquierda',
                  Icons.west,
                  () => _sendAutopilotCommand(throttle: 0.5, turn: -0.4),
                  colorScheme.primary),
              _buildControlButton(
                  'Derecha',
                  Icons.east,
                  () => _sendAutopilotCommand(throttle: 0.5, turn: 0.4),
                  colorScheme.primary),
              _buildControlButton(
                  'Frenar', Icons.stop, () => _sendStopCommand(), Colors.red),
              _buildControlButton(
                  'Retroceder',
                  Icons.south,
                  () => _sendAutopilotCommand(throttle: -0.4, turn: 0),
                  Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildManualControls(
      ArduinoData data, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        children: [
          Text(
            'Control Manual',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          // Quick control buttons
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildControlButton(
                  'Adelante',
                  Icons.north,
                  () => _sendManualCommand(leftSpeed: 0.7, rightSpeed: 0.7),
                  colorScheme.primary),
              _buildControlButton(
                  'Izquierda',
                  Icons.west,
                  () => _sendManualCommand(leftSpeed: 0.2, rightSpeed: 0.8),
                  colorScheme.primary),
              _buildControlButton(
                  'Derecha',
                  Icons.east,
                  () => _sendManualCommand(leftSpeed: 0.8, rightSpeed: 0.2),
                  colorScheme.primary),
              _buildControlButton(
                  'Parar', Icons.stop, () => _sendStopCommand(), Colors.red),
              _buildControlButton(
                  'Retroceder',
                  Icons.south,
                  () => _sendManualCommand(leftSpeed: -0.5, rightSpeed: -0.5),
                  Colors.orange),
              _buildControlButton(
                  'Girar en sitio',
                  Icons.rotate_left,
                  () => _sendManualCommand(leftSpeed: 0.8, rightSpeed: -0.8),
                  colorScheme.secondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton(
      String label, IconData icon, VoidCallback onPressed, Color color) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 32),
      ),
    );
  }

  void _showPidDialog() {
    // Navigate to PID configuration tab
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configura los parámetros PID en la pestaña Config PID'),
      ),
    );
  }

  Future<void> _sendStopCommand() async {
    await widget.provider.sendCommand({
      'mode': widget.provider.currentData.value?.operationMode ?? 0,
      'throttle': 0,
      'brake': 1
    });
  }

  Future<void> _sendEmergencyStop() async {
    await widget.provider.sendEmergencyStop();
  }

  Future<void> _sendParkingBrake() async {
    await widget.provider.sendParkingBrake();
  }

  Future<void> _sendAutopilotCommand(
      {double? throttle, double? turn, double? brake, int? direction}) async {
    final command = {
      'mode': OperationMode.autopilot.id,
      if (throttle != null) 'throttle': throttle,
      if (turn != null) 'turn': turn,
      if (brake != null) 'brake': brake,
      if (direction != null) 'direction': direction,
    };

    await widget.provider.sendCommand(command);
  }

  Future<void> _sendManualCommand(
      {double? leftSpeed, double? rightSpeed, double? maxSpeed}) async {
    final command = {
      'mode': OperationMode.manual.id,
      if (leftSpeed != null) 'leftSpeed': leftSpeed,
      if (rightSpeed != null) 'rightSpeed': rightSpeed,
      if (maxSpeed != null) 'maxSpeed': maxSpeed,
    };

    await widget.provider.sendCommand(command);
  }

  Widget _buildServoDistanceControls(
      ArduinoData data, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        children: [
          Text(
            'Control Servo Distance',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildControlButton('10cm', Icons.straighten,
                  () => _sendServoDistance(10), colorScheme.primary),
              _buildControlButton('25cm', Icons.straighten,
                  () => _sendServoDistance(25), colorScheme.primary),
              _buildControlButton('50cm', Icons.straighten,
                  () => _sendServoDistance(50), colorScheme.primary),
              _buildControlButton('100cm', Icons.straighten,
                  () => _sendServoDistance(100), colorScheme.secondary),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPointListControls(
      ArduinoData data, ThemeData theme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outline),
      ),
      child: Column(
        children: [
          Text(
            'Control Point List',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _buildControlButton(
                  'Cuadrado',
                  Icons.crop_square,
                  () => _sendRoutePoints('20,90,20,90,20,90,20,90'),
                  colorScheme.primary),
              _buildControlButton(
                  'Triángulo',
                  Icons.change_history,
                  () => _sendRoutePoints('30,120,30,120,30,120'),
                  colorScheme.primary),
              _buildControlButton('Personalizado', Icons.edit,
                  () => _showRoutePointsDialog(), colorScheme.secondary),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _sendServoDistance(double distance) async {
    await widget.provider.sendServoDistance(distance);
  }

  Future<void> _sendRoutePoints(String routePoints) async {
    await widget.provider.sendRoutePoints(routePoints);
  }

  void _showRoutePointsDialog() {
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
                  _sendRoutePoints(controller.text);
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

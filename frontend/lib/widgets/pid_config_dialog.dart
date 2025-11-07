import 'package:flutter/material.dart';
import '../line_follower_state.dart';
import '../arduino_data.dart';

class PIDConfigDialog extends StatefulWidget {
  final LineFollowerState provider;

  const PIDConfigDialog({
    super.key,
    required this.provider,
  });

  @override
  State<PIDConfigDialog> createState() => _PIDConfigDialogState();
}

class _PIDConfigDialogState extends State<PIDConfigDialog> {
  late TextEditingController _kpController;
  late TextEditingController _kiController;
  late TextEditingController _kdController;
  late TextEditingController _setpointController;
  late TextEditingController _baseSpeedController;

  @override
  void initState() {
    super.initState();
    final config = widget.provider.pidConfig.value;
    _kpController = TextEditingController(text: config.kp.toString());
    _kiController = TextEditingController(text: config.ki.toString());
    _kdController = TextEditingController(text: config.kd.toString());
    _setpointController = TextEditingController(text: config.setpoint.toString());
    _baseSpeedController = TextEditingController(text: config.baseSpeed.toString());
  }

  @override
  void dispose() {
    _kpController.dispose();
    _kiController.dispose();
    _kdController.dispose();
    _setpointController.dispose();
    _baseSpeedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: const Text('Configuración PID'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTextField(
              controller: _kpController,
              label: 'Kp (Proporcional)',
              hint: '1.0',
              icon: Icons.linear_scale,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _kiController,
              label: 'Ki (Integral)',
              hint: '0.0',
              icon: Icons.analytics,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _kdController,
              label: 'Kd (Derivativo)',
              hint: '0.0',
              icon: Icons.speed,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _setpointController,
              label: 'Setpoint (Centro línea)',
              hint: '2500',
              icon: Icons.center_focus_strong,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              controller: _baseSpeedController,
              label: 'Velocidad Base (0-1)',
              hint: '0.8',
              icon: Icons.speed,
            ),
            const SizedBox(height: 24),
            _buildPresetButtons(theme, colorScheme),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _saveConfiguration,
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
    );
  }

  Widget _buildPresetButtons(ThemeData theme, ColorScheme colorScheme) {
    return Column(
      children: [
        Text(
          'Configuraciones Predefinidas',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            _buildPresetButton(
              '6 Sensores',
              () => _loadPreset(6),
              colorScheme.primary,
            ),
            _buildPresetButton(
              '8 Sensores',
              () => _loadPreset(8),
              colorScheme.secondary,
            ),
            _buildPresetButton(
              'Rápido',
              () => _loadPresetValues(1.5, 0.02, 0.12, 2500, 0.9),
              Colors.orange,
            ),
            _buildPresetButton(
              'Lento',
              () => _loadPresetValues(0.8, 0.01, 0.05, 2500, 0.6),
              Colors.blue,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPresetButton(String label, VoidCallback onPressed, Color color) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(0, 36),
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  void _loadPreset(int sensorCount) {
    if (sensorCount == 6) {
      _loadPresetValues(1.0, 0.0, 0.0, 2500, 0.8);
    } else {
      _loadPresetValues(1.0, 0.0, 0.0, 4500, 0.8);
    }
  }

  void _loadPresetValues(double kp, double ki, double kd, double setpoint, double baseSpeed) {
    setState(() {
      _kpController.text = kp.toString();
      _kiController.text = ki.toString();
      _kdController.text = kd.toString();
      _setpointController.text = setpoint.toString();
      _baseSpeedController.text = baseSpeed.toString();
    });
  }

  void _saveConfiguration() {
    try {
      final config = ArduinoPIDConfig(
        kp: double.parse(_kpController.text),
        ki: double.parse(_kiController.text),
        kd: double.parse(_kdController.text),
        setpoint: double.parse(_setpointController.text),
        baseSpeed: double.parse(_baseSpeedController.text),
      );

      widget.provider.updatePIDConfig(config);
      
      Navigator.of(context).pop();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuración PID guardada exitosamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error: Valores inválidos en la configuración'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
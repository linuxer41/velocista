import 'package:flutter/material.dart';
import 'package:flutter_joystick/flutter_joystick.dart';
import '../app_state.dart';
import '../arduino_data.dart';

class RemoteControl extends StatefulWidget {
  final AppState appState;

  const RemoteControl({super.key, required this.appState});

  @override
  State<RemoteControl> createState() => _RemoteControlState();
}

class _RemoteControlState extends State<RemoteControl> {
  double _throttle = 0.0;
  double _turn = 0.0;
  bool _relationEnabled = false; // Local state for relation toggle

  void _onJoystickChanged(StickDragDetails details) {
    setState(() {
      // Map joystick values to throttle and turn
      // details.x: -1 (left) to 1 (right)
      // details.y: -1 (up) to 1 (down)
      _turn = details.x.clamp(-1.0, 1.0);
      _throttle = -details.y.clamp(-1.0, 1.0); // Negative because up should be forward
    });
    _sendCommand();
  }

  void _resetJoystick() {
    setState(() {
      _throttle = 0.0;
      _turn = 0.0;
    });
    _sendCommand();
  }

  void _sendCommand() {
    // Map throttle from -1..1 to 0..5000 RPM (forward only)
    final throttleRpm = ((_throttle + 1) * 2500).round().clamp(0, 5000);
    // Map turn from -1..1 to -5000..5000 RPM
    final steeringRpm = (_turn * 5000).round().clamp(-5000, 5000);

    final command = RcCommand(
      throttle: throttleRpm,
      steering: steeringRpm,
    );
    widget.appState.sendCommand(command.toCommand());
  }

  void _emergencyStop() {
    final command = RcCommand(
      throttle: 0,
      steering: 0,
    );
    widget.appState.sendCommand(command.toCommand());

    // Reset joystick
    _resetJoystick();
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Control Remoto',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Space Grotesk',
            ),
          ),
          const SizedBox(height: 8),

          // Joystick Area
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Joystick(
              mode: JoystickMode.all,
              listener: _onJoystickChanged,
              base: JoystickBase(
                decoration: JoystickBaseDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  drawArrows: true,
                  drawOuterCircle: true,
                ),
                arrowsDecoration: JoystickArrowsDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
                  enableAnimation: true,
                ),
              ),
              stick: JoystickStick(
                decoration: JoystickStickDecoration(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Control Values Display
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Text(
                      'RPM',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${((_throttle + 1) * 2500).round()} RPM',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Text(
                      'Giro',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${(_turn * 5000).round()} RPM',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Emergency Stop Button
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: _emergencyStop,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
                shadowColor: Colors.red.withOpacity(0.3),
              ),
              child: const Text(
                'STOP',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),

          const SizedBox(height: 6),

          // Relation Toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Relación',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _relationEnabled,
                    onChanged: (value) {
                      setState(() {
                        _relationEnabled = value;
                      });
                      final relationCommand = RelationCommand(value);
                      widget.appState.sendCommand(relationCommand.toCommand());
                    },
                    activeThumbColor: Theme.of(context).colorScheme.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // Additional Controls
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    final command = RcCommand(throttle: 0, steering: 0);
                    widget.appState.sendCommand(command.toCommand());
                    _resetJoystick();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
                  ),
                  child: const Text('Stop', style: TextStyle(fontSize: 10)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    final command = RcCommand(throttle: 0, steering: 0);
                    widget.appState.sendCommand(command.toCommand());
                    _resetJoystick();
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
                  ),
                  child: const Text('Park', style: TextStyle(fontSize: 10)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
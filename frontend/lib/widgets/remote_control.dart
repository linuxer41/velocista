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
    final command = RcCommand(
      throttle: (_throttle * 230).round(),
      steering: (_turn * 230).round(),
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
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
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
                  color: Theme.of(context).colorScheme.surfaceVariant,
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
                      'Acel',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${(_throttle * 100).toStringAsFixed(0)}%',
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
                      'Dir',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${(_turn * 100).toStringAsFixed(0)}%',
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
              child: const Text(
                'STOP',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 2,
                shadowColor: Colors.red.withOpacity(0.3),
              ),
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
                  child: const Text('Stop', style: TextStyle(fontSize: 10)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
                  ),
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
                  child: const Text('Park', style: TextStyle(fontSize: 10)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
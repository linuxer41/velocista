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
      // details.x: -1 (left) to 1 (right) - for steering
      // details.y: -1 (up) to 1 (down) - for throttle
      _turn = details.x.clamp(-1.0, 1.0);
      
      // Throttle: -1 (down/reverse) to 1 (up/forward)
      _throttle = -details.y.clamp(-1.0, 1.0);
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
    // Calculate throttle: -4000 to 4000 RPM (forward/backward)
    final throttleRpm = (_throttle * 4000).round().clamp(-4000, 4000);
    
    // Calculate steering proportional to throttle for proper angle control
    // Using 0.2 factor for ~20° angle (as per documentation examples)
    final angleFactor = 0.2;
    final steeringRpm = (_turn * _throttle * 4000 * angleFactor).round().clamp(-2000, 2000);

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
                      'Throttle',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${(_throttle * 4000).round()} RPM',
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
                      'Steering',
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '${(_turn * _throttle * 4000 * 0.2).round()} RPM',
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

          const SizedBox(height: 8),

          // Movement Control Buttons (2x2 Grid)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                // Top row: Straight movement
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Move forward straight: throttle=2000, steering=0
                          final command = RcCommand(throttle: 2000, steering: 0);
                          widget.appState.sendCommand(command.toCommand());
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: BorderSide(color: Theme.of(context).colorScheme.primary),
                        ),
                        icon: Icon(Icons.arrow_upward, size: 16),
                        label: const Text('Avanzar', style: TextStyle(fontSize: 10)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Move backward straight: throttle=-2000, steering=0
                          final command = RcCommand(throttle: -2000, steering: 0);
                          widget.appState.sendCommand(command.toCommand());
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: BorderSide(color: Theme.of(context).colorScheme.primary),
                        ),
                        icon: Icon(Icons.arrow_downward, size: 16),
                        label: const Text('Retroceder', style: TextStyle(fontSize: 10)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Bottom row: Rotation
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Rotate left: throttle=0, steering=-1500 (spin left)
                          final command = RcCommand(throttle: 0, steering: -1500);
                          widget.appState.sendCommand(command.toCommand());
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: BorderSide(color: Theme.of(context).colorScheme.primary),
                        ),
                        icon: Icon(Icons.rotate_left, size: 16),
                        label: const Text('Girar Izq', style: TextStyle(fontSize: 10)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          // Rotate right: throttle=0, steering=1500 (spin right)
                          final command = RcCommand(throttle: 0, steering: 1500);
                          widget.appState.sendCommand(command.toCommand());
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          side: BorderSide(color: Theme.of(context).colorScheme.primary),
                        ),
                        icon: Icon(Icons.rotate_right, size: 16),
                        label: const Text('Girar Der', style: TextStyle(fontSize: 10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../line_follower_state.dart';
import '../arduino_data.dart';

class RemoteControlWidget extends StatefulWidget {
  final LineFollowerState provider;

  const RemoteControlWidget({
    super.key,
    required this.provider,
  });

  @override
  State<RemoteControlWidget> createState() => _RemoteControlWidgetState();
}

class _RemoteControlWidgetState extends State<RemoteControlWidget>
    with TickerProviderStateMixin {
  bool _isForwardPressed = false;
  bool _isBackwardPressed = false;
  bool _isLeftPressed = false;
  bool _isRightPressed = false;
  bool _isBrakePressed = false;
  
  late AnimationController _brakeController;
  late Animation<double> _brakeAnimation;
  
  final double _throttleValue = 0.8;
  final double _turnValue = 0.7;

  @override
  void initState() {
    super.initState();
    _brakeController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _brakeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _brakeController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _brakeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            // Control Layout
            _buildControlLayout(colorScheme),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildControlLayout(ColorScheme colorScheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Turn Left
        _buildControlButton(
          icon: Icons.turn_left,
          isPressed: _isLeftPressed,
          onPressed: () => _handleLeftTurn(),
          onReleased: () => _handleLeftRelease(),
          gradient: const LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        const SizedBox(height: 20),
        // Forward, Brake, Backward row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Forward
            _buildControlButton(
              icon: Icons.keyboard_arrow_up,
              isPressed: _isForwardPressed,
              onPressed: () => _handleForward(),
              onReleased: () => _handleForwardRelease(),
              gradient: const LinearGradient(
                colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
              ),
            ),
            // Brake
            AnimatedBuilder(
              animation: _brakeAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + _brakeAnimation.value * 0.1,
                  child: _buildControlButton(
                    icon: Icons.stop_circle_outlined,
                    isPressed: _isBrakePressed,
                    onPressed: () => _handleBrake(),
                    onReleased: () => _handleBrakeRelease(),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFff416c), Color(0xFFff4b2b)],
                    ),
                    isLarge: true,
                  ),
                );
              },
            ),
            // Backward
            _buildControlButton(
              icon: Icons.keyboard_arrow_down,
              isPressed: _isBackwardPressed,
              onPressed: () => _handleBackward(),
              onReleased: () => _handleBackwardRelease(),
              gradient: const LinearGradient(
                colors: [Color(0xFFfc4a1a), Color(0xFFf7b733)],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        // Turn Right
        _buildControlButton(
          icon: Icons.turn_right,
          isPressed: _isRightPressed,
          onPressed: () => _handleRightTurn(),
          onReleased: () => _handleRightRelease(),
          gradient: const LinearGradient(
            colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
          ),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isPressed,
    required VoidCallback onPressed,
    required VoidCallback onReleased,
    required Gradient gradient,
    bool isLarge = false,
  }) {
    final size = isLarge ? 120.0 : 80.0;
    
    return GestureDetector(
      onTapDown: (_) => onPressed(),
      onTapUp: (_) => onReleased(),
      onTapCancel: onReleased,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(isLarge ? 20 : 16),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
            if (isPressed)
              BoxShadow(
                color: Colors.white.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 0),
              ),
          ],
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: Icon(
          icon,
          size: isLarge ? 48 : 32,
          color: Colors.white,
        ),
      ),
    );
  }

  // Control methods
  void _handleForward() {
    setState(() {
      _isForwardPressed = true;
    });
    _sendCommand(AutopilotCommand(
      throttle: _throttleValue,
      direction: 1,
      turn: _isLeftPressed ? -_turnValue : (_isRightPressed ? _turnValue : 0.0),
    ));
  }

  void _handleForwardRelease() {
    setState(() {
      _isForwardPressed = false;
    });
    _sendCommand(AutopilotCommand(stop: true));
  }

  void _handleBackward() {
    setState(() {
      _isBackwardPressed = true;
    });
    _sendCommand(AutopilotCommand(
      throttle: _throttleValue,
      direction: -1,
      turn: _isLeftPressed ? -_turnValue : (_isRightPressed ? _turnValue : 0.0),
    ));
  }

  void _handleBackwardRelease() {
    setState(() {
      _isBackwardPressed = false;
    });
    _sendCommand(AutopilotCommand(stop: true));
  }

  void _handleLeftTurn() {
    setState(() {
      _isLeftPressed = true;
    });
    if (_isForwardPressed) {
      _sendCommand(AutopilotCommand(
        throttle: _throttleValue,
        direction: 1,
        turn: -_turnValue,
      ));
    } else if (_isBackwardPressed) {
      _sendCommand(AutopilotCommand(
        throttle: _throttleValue,
        direction: -1,
        turn: -_turnValue,
      ));
    }
  }

  void _handleLeftRelease() {
    setState(() {
      _isLeftPressed = false;
    });
    if (_isForwardPressed) {
      _sendCommand(AutopilotCommand(
        throttle: _throttleValue,
        direction: 1,
        turn: 0.0,
      ));
    } else if (_isBackwardPressed) {
      _sendCommand(AutopilotCommand(
        throttle: _throttleValue,
        direction: -1,
        turn: 0.0,
      ));
    } else {
      _sendCommand(AutopilotCommand(stop: true));
    }
  }

  void _handleRightTurn() {
    setState(() {
      _isRightPressed = true;
    });
    if (_isForwardPressed) {
      _sendCommand(AutopilotCommand(
        throttle: _throttleValue,
        direction: 1,
        turn: _turnValue,
      ));
    } else if (_isBackwardPressed) {
      _sendCommand(AutopilotCommand(
        throttle: _throttleValue,
        direction: -1,
        turn: _turnValue,
      ));
    }
  }

  void _handleRightRelease() {
    setState(() {
      _isRightPressed = false;
    });
    if (_isForwardPressed) {
      _sendCommand(AutopilotCommand(
        throttle: _throttleValue,
        direction: 1,
        turn: 0.0,
      ));
    } else if (_isBackwardPressed) {
      _sendCommand(AutopilotCommand(
        throttle: _throttleValue,
        direction: -1,
        turn: 0.0,
      ));
    } else {
      _sendCommand(AutopilotCommand(stop: true));
    }
  }

  void _handleBrake() async {
    setState(() {
      _isBrakePressed = true;
    });
    _brakeController.forward();
    await _sendCommand(AutopilotCommand(brake: 1.0, stop: true));
  }

  void _handleBrakeRelease() {
    setState(() {
      _isBrakePressed = false;
    });
    _brakeController.reverse();
  }

  Future<bool> _sendCommand(AutopilotCommand command) async {
    try {
      return await widget.provider.sendCommand(command.toJson());
    } catch (e) {
      return false;
    }
  }
}
import 'dart:convert';
import 'package:flutter/material.dart';

/// Operation modes for the robot
enum OperationMode {
   lineFollowing(0, 'LINE_FOLLOW', Icons.route),
   autopilot(1, 'AUTO_PILOT', Icons.directions_car),
   manual(2, 'MANUAL', Icons.gamepad),
   servoDistance(3, 'SERVO_DIST', Icons.straighten),
   pointList(4, 'POINT_LIST', Icons.list_alt);

  const OperationMode(this.id, this.displayName, this.icon);
  final int id;
  final String displayName;
  final IconData icon;

  static OperationMode fromId(int id) {
    return OperationMode.values.firstWhere(
      (mode) => mode.id == id,
      orElse: () => OperationMode.lineFollowing,
    );
  }
}

class ArduinoData {
  // Common JSON keys constants
  static const String _keyOperationMode = 'operationMode';
  static const String _keyModeName = 'modeName';
  static const String _keyLeftEncoderSpeed = 'leftEncoderSpeed';
  static const String _keyRightEncoderSpeed = 'rightEncoderSpeed';
  static const String _keyLeftEncoderCount = 'leftEncoderCount';
  static const String _keyRightEncoderCount = 'rightEncoderCount';
  static const String _keyTotalDistance = 'totalDistance';
  static const String _keySensors = 'sensors';

  // Line Following specific keys
  static const String _keyPosition = 'position';
  static const String _keyError = 'error';
  static const String _keyCorrection = 'correction';
  static const String _keyLeftSpeedCmd = 'leftSpeedCmd';
  static const String _keyRightSpeedCmd = 'rightSpeedCmd';

  // Autopilot specific keys
  static const String _keyThrottle = 'throttle';
  static const String _keyBrake = 'brake';
  static const String _keyTurn = 'turn';
  static const String _keyDirection = 'direction';

  // Manual specific keys
  static const String _keyLeftSpeed = 'leftSpeed';
  static const String _keyRightSpeed = 'rightSpeed';
  static const String _keyMaxSpeed = 'maxSpeed';

  // Common data fields
  final int operationMode; // 0=Line Following, 1=Autopilot, 2=Manual
  final String modeName; // Mode name as string
  final double leftEncoderSpeed; // Actual left encoder speed (cm/s)
  final double rightEncoderSpeed; // Actual right encoder speed (cm/s)
  final int leftEncoderCount; // Total left encoder pulses
  final int rightEncoderCount; // Total right encoder pulses
  final double totalDistance; // Total distance traveled (cm)
  final List<int> sensors; // QTR sensor values (0 in non-lineal modes)

  // Line Following specific data
  final double? position; // Line position (2000-7000 for 6 sensors, 1000-8000 for 8)
  final double? error; // Error from setpoint
  final double? correction; // PID correction value
  final double? leftSpeedCmd; // Left motor command speed (-1 to 1)
  final double? rightSpeedCmd; // Right motor command speed (-1 to 1)

  // Autopilot specific data
  final double? throttle; // Acelerador (-1.0 a 1.0)
  final double? brake; // Freno (0.0 a 1.0)
  final double? turn; // Dirección (-1.0 a 1.0)
  final int? direction; // Dirección de marcha (1=adelante, -1=atrás)

  // Manual specific data
  final double? leftSpeed; // Velocidad rueda izquierda (-1.0 a 1.0)
  final double? rightSpeed; // Velocidad rueda derecha (-1.0 a 1.0)
  final double? maxSpeed; // Velocidad máxima global (0.0 a 1.0)

  ArduinoData({
    required this.operationMode,
    required this.modeName,
    required this.leftEncoderSpeed,
    required this.rightEncoderSpeed,
    required this.leftEncoderCount,
    required this.rightEncoderCount,
    required this.totalDistance,
    required this.sensors,
    this.position,
    this.error,
    this.correction,
    this.leftSpeedCmd,
    this.rightSpeedCmd,
    this.throttle,
    this.brake,
    this.turn,
    this.direction,
    this.leftSpeed,
    this.rightSpeed,
    this.maxSpeed,
  });

  /// Parse JSON from Arduino according to the new 3-mode system
  static ArduinoData fromJson(String jsonString) {
    final map = jsonDecode(jsonString);

    return ArduinoData(
      operationMode: map['mode'] ?? map[_keyOperationMode] ?? 0,
      modeName: map['modeName'] ?? map[_keyModeName] ?? 'Unknown',
      leftEncoderSpeed: _parseDoubleValue(map['motors']?['left']?['speed_cm_s'] ?? map[_keyLeftEncoderSpeed]),
      rightEncoderSpeed: _parseDoubleValue(map['motors']?['right']?['speed_cm_s'] ?? map[_keyRightEncoderSpeed]),
      leftEncoderCount: map['sensors']?['encoders']?['left'] ?? map[_keyLeftEncoderCount] ?? 0,
      rightEncoderCount: map['sensors']?['encoders']?['right'] ?? map[_keyRightEncoderCount] ?? 0,
      totalDistance: _parseDoubleValue(map['distance']?['total_cm'] ?? map[_keyTotalDistance]),
      sensors: _parseSensorsData(map['sensors']?['qtr'] ?? map[_keySensors]),
      
      // Line Following specific fields
      position: (map[_keyPosition] is num) 
          ? (map[_keyPosition] as num).toDouble() 
          : double.tryParse('${map[_keyPosition]}'),
      error: (map[_keyError] is num) 
          ? (map[_keyError] as num).toDouble() 
          : double.tryParse('${map[_keyError]}'),
      correction: (map[_keyCorrection] is num) 
          ? (map[_keyCorrection] as num).toDouble() 
          : double.tryParse('${map[_keyCorrection]}'),
      leftSpeedCmd: (map[_keyLeftSpeedCmd] is num) 
          ? (map[_keyLeftSpeedCmd] as num).toDouble() 
          : double.tryParse('${map[_keyLeftSpeedCmd]}'),
      rightSpeedCmd: (map[_keyRightSpeedCmd] is num) 
          ? (map[_keyRightSpeedCmd] as num).toDouble() 
          : double.tryParse('${map[_keyRightSpeedCmd]}'),
      
      // Autopilot specific fields
      throttle: (map[_keyThrottle] is num) 
          ? (map[_keyThrottle] as num).toDouble() 
          : double.tryParse('${map[_keyThrottle]}'),
      brake: (map[_keyBrake] is num) 
          ? (map[_keyBrake] as num).toDouble() 
          : double.tryParse('${map[_keyBrake]}'),
      turn: (map[_keyTurn] is num) 
          ? (map[_keyTurn] as num).toDouble() 
          : double.tryParse('${map[_keyTurn]}'),
      direction: map[_keyDirection] as int?,
      
      // Manual specific fields
      leftSpeed: (map[_keyLeftSpeed] is num) 
          ? (map[_keyLeftSpeed] as num).toDouble() 
          : double.tryParse('${map[_keyLeftSpeed]}'),
      rightSpeed: (map[_keyRightSpeed] is num) 
          ? (map[_keyRightSpeed] as num).toDouble() 
          : double.tryParse('${map[_keyRightSpeed]}'),
      maxSpeed: (map[_keyMaxSpeed] is num) 
          ? (map[_keyMaxSpeed] as num).toDouble() 
          : double.tryParse('${map[_keyMaxSpeed]}'),
    );
  }

  /// Convert to JSON string
  String toJson() {
    final Map<String, Object> map = {
      _keyOperationMode: operationMode,
      _keyModeName: modeName,
      _keyLeftEncoderSpeed: leftEncoderSpeed,
      _keyRightEncoderSpeed: rightEncoderSpeed,
      _keyLeftEncoderCount: leftEncoderCount,
      _keyRightEncoderCount: rightEncoderCount,
      _keyTotalDistance: totalDistance,
      _keySensors: sensors,
    };

    // Add mode-specific fields
    if (operationMode == 0) { // Line Following
      if (position != null) map[_keyPosition] = position!;
      if (error != null) map[_keyError] = error!;
      if (correction != null) map[_keyCorrection] = correction!;
      if (leftSpeedCmd != null) map[_keyLeftSpeedCmd] = leftSpeedCmd!;
      if (rightSpeedCmd != null) map[_keyRightSpeedCmd] = rightSpeedCmd!;
    } else if (operationMode == 1) { // Autopilot
      if (throttle != null) map[_keyThrottle] = throttle!;
      if (brake != null) map[_keyBrake] = brake!;
      if (turn != null) map[_keyTurn] = turn!;
      if (direction != null) map[_keyDirection] = direction!;
    } else if (operationMode == 2) { // Manual
      if (leftSpeed != null) map[_keyLeftSpeed] = leftSpeed!;
      if (rightSpeed != null) map[_keyRightSpeed] = rightSpeed!;
      if (maxSpeed != null) map[_keyMaxSpeed] = maxSpeed!;
    }

    return jsonEncode(map);
  }

  /// Get operation mode enum
  OperationMode get mode => OperationMode.fromId(operationMode);

  /// Get the number of sensors detected
  int get sensorCount => sensors.length;

  /// Check if line is detected (only in line following mode)
  bool get isLineDetected => operationMode == 0 && position != null && position! >= 0;

  /// Get sensor value by index (0-based)
  int getSensorValue(int index) {
    if (index >= 0 && index < sensors.length) {
      return sensors[index];
    }
    return 0;
  }

  /// Get average sensor value
  double get averageSensorValue {
    if (sensors.isEmpty) return 0.0;
    return sensors.reduce((a, b) => a + b) / sensors.length;
  }

  /// Check if sensor at index is on line (dark = low value)
  bool isSensorOnLine(int index) {
    final value = getSensorValue(index);
    return value < 300; // Threshold for line detection
  }

  /// Get line position as percentage (0-100%) - only for line following mode
  double? get positionPercentage {
    if (operationMode != 0 || position == null) return null;
    final maxPos = sensorCount == 6 ? 7000.0 : 8000.0;
    return (position! / maxPos * 100).clamp(0.0, 100.0);
  }

  /// Get sensor values as weighted array for visualization
  List<Map<String, dynamic>> getSensorVisualizationData() {
    final result = <Map<String, dynamic>>[];
    
    for (int i = 0; i < sensorCount; i++) {
      final value = getSensorValue(i);
      final isOnLine = isSensorOnLine(i);
      final percentage = (value / 1023.0 * 100).clamp(0.0, 100.0);
      
      result.add({
        'index': i,
        'sensorNumber': i + 1, // 1-based sensor numbering
        'value': value,
        'isOnLine': isOnLine,
        'percentage': percentage,
        'color': isOnLine ? 'red' : 'green',
        'sensorPin': _getSensorPin(i), // Arduino pin name
      });
    }
    
    return result;
  }

  /// Get the Arduino pin for a sensor index
  String _getSensorPin(int index) {
    // For 6 sensors: A0-A5 (positions 2-7 of QTR-8A)
    // For 8 sensors: A0-A7 (positions 1-8 of QTR-8A)
    if (sensorCount == 6) {
      // Positions 2-7: pins A0-A5
      final pinIndex = index; // 0-5
      return 'A$pinIndex';
    } else if (sensorCount == 8) {
      // Positions 1-8: pins A0-A7
      final pinIndex = index; // 0-7
      return 'A$pinIndex';
    }
    return 'A$index';
  }

  /// Check if the robot is in a good tracking state (only for line following)
  bool isGoodTrackingState() {
    if (!isLineDetected || position == null) return false;
    
    // Check if we have reasonable sensor values
    final nonZeroSensors = sensors.where((val) => val > 100).length;
    final lineSensors = sensors.where((val) => isSensorOnLine(sensors.indexOf(val))).length;
    
    // Good tracking: at least 1-3 sensors on line, and not too many
    return lineSensors >= 1 && lineSensors <= 3 && nonZeroSensors >= 3;
  }

  /// Get tracking quality indicator (only for line following)
  String? getTrackingQuality() {
    if (operationMode != 0) return null;
    if (!isLineDetected) return 'No Line';
    if (!isGoodTrackingState()) return 'Poor';
    if (error != null && error!.abs() < 100) return 'Excellent';
    if (error != null && error!.abs() < 500) return 'Good';
    return 'Fair';
  }

  /// Check if this is line following mode
  bool get isLineFollowingMode => operationMode == 0;
  
  /// Check if this is autopilot mode
  bool get isAutopilotMode => operationMode == 1;
  
  /// Check if this is manual mode
  bool get isManualMode => operationMode == 2;

  /// Check if this is servo distance mode
  bool get isServoDistanceMode => operationMode == 3;

  /// Check if this is point list mode
  bool get isPointListMode => operationMode == 4;

  /// Parse sensors data with better error handling
  static List<int> _parseSensorsData(dynamic sensorsData) {
    if (sensorsData == null) return [];

    try {
      // Handle case where sensors is a List
      if (sensorsData is List) {
        return sensorsData.map((e) => (e is num) ? e.toInt() : int.tryParse('$e') ?? 0).toList();
      }

      // Handle case where sensors is a Map (like {"qtr": [values]})
      if (sensorsData is Map) {
        final qtrData = sensorsData['qtr'];
        if (qtrData is List) {
          return qtrData.map((e) => (e is num) ? e.toInt() : int.tryParse('$e') ?? 0).toList();
        }
      }

      // Fallback: try to convert to string and parse
      final sensorsString = sensorsData.toString();
      if (sensorsString.contains('[') && sensorsString.contains(']')) {
        // Extract array part
        final start = sensorsString.indexOf('[');
        final end = sensorsString.lastIndexOf(']');
        if (start >= 0 && end > start) {
          final arrayPart = sensorsString.substring(start + 1, end);
          final values = arrayPart.split(',').map((s) => int.tryParse(s.trim()) ?? 0).toList();
          return values;
        }
      }

      return [];
    } catch (e) {
      print('Error parsing sensors data: $e, data: $sensorsData');
      return [];
    }
  }

  /// Parse double values with better error handling
  static double _parseDoubleValue(dynamic value) {
    if (value == null) return 0.0;

    if (value is num) {
      return value.toDouble();
    }

    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }

    // Try to convert to string and parse
    return double.tryParse(value.toString()) ?? 0.0;
  }

  @override
  String toString() {
    return 'ArduinoData{mode: $modeName ($operationMode), encoders: L=${leftEncoderSpeed.toStringAsFixed(1)}cm/s, R=${rightEncoderSpeed.toStringAsFixed(1)}cm/s, distance: ${totalDistance.toStringAsFixed(1)}cm}';
  }
}

/// Command classes for different modes
class ModeChangeCommand {
  final OperationMode mode;

  ModeChangeCommand(this.mode);

  Map<String, dynamic> toJson() {
    return {'mode': mode.id};
  }
}

class ServoDistanceCommand {
  final double distance; // Distance in cm

  ServoDistanceCommand(this.distance);

  Map<String, dynamic> toJson() {
    return {'servoDistance': distance};
  }
}

class RoutePointsCommand {
  final String routePoints; // "dist,grados,dist,grados,..."

  RoutePointsCommand(this.routePoints);

  Map<String, dynamic> toJson() {
    return {'routePoints': routePoints};
  }
}

class SpeedBaseCommand {
  final double baseSpeed; // 0-1

  SpeedBaseCommand(this.baseSpeed);

  Map<String, dynamic> toJson() {
    return {'speed': {'base': baseSpeed}};
  }
}

class EepromSaveCommand {
  Map<String, dynamic> toJson() {
    return {'eeprom': 1};
  }
}

class TelemetryRequestCommand {
  Map<String, dynamic> toJson() {
    return {'telemetry': 1};
  }
}

class TelemetryEnableCommand {
  final bool enable;

  TelemetryEnableCommand(this.enable);

  Map<String, dynamic> toJson() {
    return {'telemetry_enable': enable};
  }
}

class CalibrateQtrCommand {
  Map<String, dynamic> toJson() {
    return {'calibrate_qtr': 1};
  }
}

class LineFollowingConfigCommand {
  final double kp;
  final double ki;
  final double kd;
  final double setpoint;
  final double baseSpeed;
  
  LineFollowingConfigCommand({
    this.kp = 1.0,
    this.ki = 0.0,
    this.kd = 0.0,
    this.setpoint = 2500.0,
    this.baseSpeed = 0.8,
  });
  
  Map<String, dynamic> toJson() {
    return {
      'mode': OperationMode.lineFollowing.id,
      'Kp': kp,
      'Ki': ki,
      'Kd': kd,
      'setpoint': setpoint,
      'baseSpeed': baseSpeed,
    };
  }
}

class AutopilotCommand {
  final double? throttle; // -1.0 a 1.0
  final double? brake; // 0.0 a 1.0
  final double? turn; // -1.0 a 1.0
  final int? direction; // 1=adelante, -1=atrás
  final bool? emergencyStop; // Parada de emergencia inmediata
  final bool? park; // Freno de estacionamiento completo
  final bool? stop; // Parada normal controlada
  
  AutopilotCommand({
    this.throttle,
    this.brake,
    this.turn,
    this.direction,
    this.emergencyStop,
    this.park,
    this.stop,
  });
  
  Map<String, dynamic> toJson() {
    final Map<String, Object> map = {
      'mode': OperationMode.autopilot.id,
    };
    if (throttle != null) map['throttle'] = throttle!;
    if (brake != null) map['brake'] = brake!;
    if (turn != null) map['turn'] = turn!;
    if (direction != null) map['direction'] = direction!;
    if (emergencyStop != null) map['emergencyStop'] = emergencyStop!;
    if (park != null) map['park'] = park!;
    if (stop != null) map['stop'] = stop!;
    return map;
  }
}

class ManualCommand {
  final double? leftSpeed; // -1.0 a 1.0
  final double? rightSpeed; // -1.0 a 1.0
  final double? maxSpeed; // 0.0 a 1.0
  
  ManualCommand({
    this.leftSpeed,
    this.rightSpeed,
    this.maxSpeed,
  });
  
  Map<String, dynamic> toJson() {
    final Map<String, Object> map = {
      'mode': OperationMode.manual.id,
    };
    if (leftSpeed != null) map['leftSpeed'] = leftSpeed!;
    if (rightSpeed != null) map['rightSpeed'] = rightSpeed!;
    if (maxSpeed != null) map['maxSpeed'] = maxSpeed!;
    return map;
  }
}

/// PID Configuration for Arduino Line Follower
class ArduinoPIDConfig {
  static const String _keyKp = 'Kp';
  static const String _keyKi = 'Ki';
  static const String _keyKd = 'Kd';
  static const String _keySetpoint = 'setpoint';
  static const String _keyBaseSpeed = 'baseSpeed';

  final double kp; // Proportional gain
  final double ki; // Integral gain
  final double kd; // Derivative gain
  final double setpoint; // Target position
  final double baseSpeed; // Base motor speed (0-1)

  ArduinoPIDConfig({
    this.kp = 1.0,
    this.ki = 0.0,
    this.kd = 0.0,
    this.setpoint = 2500.0, // For 6 sensors
    this.baseSpeed = 0.8,
  });

  /// Parse configuration from JSON
  static ArduinoPIDConfig fromJson(String jsonString) {
    final map = jsonDecode(jsonString);
    
    return ArduinoPIDConfig(
      kp: (map[_keyKp] is num) ? (map[_keyKp] as num).toDouble() : 1.0,
      ki: (map[_keyKi] is num) ? (map[_keyKi] as num).toDouble() : 0.0,
      kd: (map[_keyKd] is num) ? (map[_keyKd] as num).toDouble() : 0.0,
      setpoint: (map[_keySetpoint] is num) ? (map[_keySetpoint] as num).toDouble() : 2500.0,
      baseSpeed: (map[_keyBaseSpeed] is num) ? (map[_keyBaseSpeed] as num).toDouble() : 0.8,
    );
  }

  /// Convert to JSON for sending to Arduino
  String toJson() {
    final map = {
      _keyKp: kp,
      _keyKi: ki,
      _keyKd: kd,
      _keySetpoint: setpoint,
      _keyBaseSpeed: baseSpeed,
    };
    return jsonEncode(map);
  }

  /// Create configuration for 8 sensors
  static ArduinoPIDConfig for8Sensors() {
    return ArduinoPIDConfig(
      setpoint: 4500.0, // Center position for 8 sensors
    );
  }

  /// Create configuration for 6 sensors
  static ArduinoPIDConfig for6Sensors() {
    return ArduinoPIDConfig(
      setpoint: 2500.0, // Center position for 6 sensors
    );
  }
}

/// Base message wrapper for all Arduino communications
class ArduinoMessage {
  final String type;
  final Map<String, dynamic> payload;

  ArduinoMessage({
    required this.type,
    required this.payload,
  });

  static ArduinoMessage? fromJson(String jsonString) {
    try {
      final map = jsonDecode(jsonString);
      if (map.containsKey('type') && map.containsKey('payload')) {
        return ArduinoMessage(
          type: map['type'] as String,
          payload: map['payload'] as Map<String, dynamic>,
        );
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  bool get isTelemetry => type == 'telemetry';
  bool get isStatus => type == 'status';

  @override
  String toString() {
    return 'ArduinoMessage{type: $type, payload: $payload}';
  }
}

/// Telemetry data from Arduino
class TelemetryData {
  final int mode;
  final double speed;
  final double distance;
  final double battery;
  final List<int> sensors;
  final List<double> pid;
  final double leftRpm;
  final double rightRpm;
  final int leftEncoder;
  final int rightEncoder;
  final double? position;
  final double? error;
  final double? correction;

  TelemetryData({
    required this.mode,
    required this.speed,
    required this.distance,
    required this.battery,
    required this.sensors,
    required this.pid,
    required this.leftRpm,
    required this.rightRpm,
    required this.leftEncoder,
    required this.rightEncoder,
    this.position,
    this.error,
    this.correction,
  });

  static TelemetryData? fromPayload(Map<String, dynamic> payload) {
    try {
      return TelemetryData(
        mode: payload['mode'] ?? 0,
        speed: (payload['speed'] as num?)?.toDouble() ?? 0.0,
        distance: (payload['distance'] as num?)?.toDouble() ?? 0.0,
        battery: (payload['battery'] as num?)?.toDouble() ?? 0.0,
        sensors: (payload['sensors'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ?? [],
        pid: (payload['pid'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [0.0, 0.0, 0.0],
        leftRpm: (payload['left_rpm'] as num?)?.toDouble() ?? 0.0,
        rightRpm: (payload['right_rpm'] as num?)?.toDouble() ?? 0.0,
        leftEncoder: payload['left_encoder'] ?? 0,
        rightEncoder: payload['right_encoder'] ?? 0,
        position: (payload['position'] as num?)?.toDouble(),
        error: (payload['error'] as num?)?.toDouble(),
        correction: (payload['correction'] as num?)?.toDouble(),
      );
    } catch (e) {
      return null;
    }
  }

  OperationMode get operationMode => OperationMode.fromId(mode);
  bool get isLineFollowingMode => mode == 0;
  bool get isAutopilotMode => mode == 1;
  bool get isManualMode => mode == 2;
  bool get isServoDistanceMode => mode == 3;
  bool get isPointListMode => mode == 4;

  @override
  String toString() {
    return 'TelemetryData{mode: $mode, speed: ${speed.toStringAsFixed(2)}, distance: ${distance.toStringAsFixed(1)}, battery: ${battery.toStringAsFixed(1)}}';
  }
}

/// Status messages from Arduino
class StatusMessage {
  final String status;

  StatusMessage(this.status);

  static StatusMessage? fromPayload(Map<String, dynamic> payload) {
    try {
      if (payload.containsKey('status') && payload['status'] is String) {
        return StatusMessage(payload['status']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() {
    return 'StatusMessage{status: $status}';
  }
}

// Backward compatibility alias
typedef ArduinoLineFollowerData = ArduinoData;
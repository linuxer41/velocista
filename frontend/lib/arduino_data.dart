import 'dart:convert';

import 'package:flutter/material.dart';

enum OperationMode {
     lineFollowing(0, 'SEGUIDOR DE LÍNEA', Icons.route, 'SEGUID'),
     remoteControl(1, 'CONTROL REMOTO', Icons.gamepad, 'CONTROL');

  const OperationMode(this.id, this.displayName, this.icon, this.shortName);
  final int id;
  final String displayName;
  final IconData icon;
  final String shortName;

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
   final double battery; // Battery percentage
   final bool closedLoop; // Closed loop control enabled

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

   // PID and base speed data
   final List<double>? pid; // [Kp, Ki, Kd]
   final double? baseSpeed; // Base speed (0-1)

  ArduinoData({
    required this.operationMode,
    required this.modeName,
    required this.leftEncoderSpeed,
    required this.rightEncoderSpeed,
    required this.leftEncoderCount,
    required this.rightEncoderCount,
    required this.totalDistance,
    required this.sensors,
    this.battery = 0.0,
    this.closedLoop = true,
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
    this.pid,
    this.baseSpeed,
  });

  /// Parse data from Arduino (supports both JSON and pipe-separated formats)
  static ArduinoData fromJson(String dataString) {
    final trimmed = dataString.trim();

    // Detect format: if starts with '{', it's JSON, else pipe-separated
    if (trimmed.startsWith('{')) {
      return _fromJsonFormat(trimmed);
    } else {
      return _fromPipeFormat(trimmed);
    }
  }

  /// Parse JSON format
  static ArduinoData _fromJsonFormat(String jsonString) {
    final map = jsonDecode(jsonString);

    // Check if it's the new telemetry payload
    if (map.containsKey('type') && map['type'] == 'telemetry') {
      final payload = map['payload'] as Map<String, dynamic>;
      return ArduinoData(
        operationMode: payload['mode'] ?? 0,
        modeName: OperationMode.fromId(payload['mode'] ?? 0).displayName,
        leftEncoderSpeed: (payload['left']?['vel'] as num?)?.toDouble() ?? 0.0,
        rightEncoderSpeed: (payload['right']?['vel'] as num?)?.toDouble() ?? 0.0,
        leftEncoderCount: 0, // Not available in new telemetry
        rightEncoderCount: 0, // Not available in new telemetry
        totalDistance: (payload['distance'] as num?)?.toDouble() ?? 0.0,
        sensors: (payload['qtr'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ?? [],
        battery: (payload['battery'] as num?)?.toDouble() ?? 0.0,
        closedLoop: true, // Assume closed loop for telemetry
        position: (payload['set_point'] as num?)?.toDouble(),
        error: (payload['error'] as num?)?.toDouble(),
        correction: (payload['correction'] as num?)?.toDouble(),
        pid: (payload['pid'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList(),
        baseSpeed: (payload['base_speed'] as num?)?.toDouble(),
      );
    }

    // Fallback to old format parsing
    return ArduinoData(
      operationMode: map['mode'] ?? map[_keyOperationMode] ?? 0,
      modeName: map['modeName'] ?? map[_keyModeName] ?? 'Unknown',
      leftEncoderSpeed: _parseDoubleValue(map['motors']?['left']?['speed_cm_s'] ?? map[_keyLeftEncoderSpeed]),
      rightEncoderSpeed: _parseDoubleValue(map['motors']?['right']?['speed_cm_s'] ?? map[_keyRightEncoderSpeed]),
      leftEncoderCount: map['sensors']?['encoders']?['left'] ?? map[_keyLeftEncoderCount] ?? 0,
      rightEncoderCount: map['sensors']?['encoders']?['right'] ?? map[_keyRightEncoderCount] ?? 0,
      totalDistance: _parseDoubleValue(map['distance']?['total_cm'] ?? map[_keyTotalDistance]),
      sensors: _parseSensorsData(map['sensors']?['qtr'] ?? map[_keySensors]),
      battery: _parseDoubleValue(map['battery'] ?? 0.0),
      closedLoop: true, // Default to closed loop

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

  /// Parse pipe-separated format (new Arduino format)
  static ArduinoData _fromPipeFormat(String pipeString) {
    final dataMap = <String, String>{};

    // Split by '|' and parse key:value pairs
    final pairs = pipeString.split('|');
    for (final pair in pairs) {
      final colonIndex = pair.indexOf(':');
      if (colonIndex > 0) {
        final key = pair.substring(0, colonIndex).trim();
        final value = pair.substring(colonIndex + 1).trim();
        dataMap[key] = value;
      }
    }

    // Parse values
    final pos = double.tryParse(dataMap['Pos'] ?? '0') ?? 0.0;
    final pidCorrection = double.tryParse(dataMap['PID'] ?? '0') ?? 0.0;
    final lRpm = double.tryParse(dataMap['LRPM'] ?? '0') ?? 0.0;
    final rRpm = double.tryParse(dataMap['RRPM'] ?? '0') ?? 0.0;
    final lTargetRpm = double.tryParse(dataMap['LTRPM'] ?? '0') ?? 0.0;
    final rTargetRpm = double.tryParse(dataMap['RTRPM'] ?? '0') ?? 0.0;
    final lPwm = int.tryParse(dataMap['LSPD'] ?? '0') ?? 0;
    final rPwm = int.tryParse(dataMap['RSPD'] ?? '0') ?? 0;
    final closedLoop = (int.tryParse(dataMap['CL'] ?? '1') ?? 1) == 1;
    final modeStr = dataMap['MODE'] ?? 'LINE';
    final sensorsStr = dataMap['SENSORES'] ?? '[]';

    // Parse sensors array
    List<int> sensors = [];
    if (sensorsStr.startsWith('[') && sensorsStr.endsWith(']')) {
      final arrayContent = sensorsStr.substring(1, sensorsStr.length - 1);
      sensors = arrayContent.split(',').map((s) => int.tryParse(s.trim()) ?? 0).toList();
    }

    // Map mode string to operation mode
    int operationMode = 0; // Default to line following
    String modeName = 'LINE FOLLOWING';
    if (modeStr == 'REMOTE') {
      operationMode = 1;
      modeName = 'REMOTE CONTROL';
    }

    // Convert RPM to cm/s (assuming some conversion factor, adjust as needed)
    // For now, use RPM as is, but in cm/s units
    final leftSpeedCmS = lRpm; // TODO: Apply proper conversion
    final rightSpeedCmS = rRpm;

    return ArduinoData(
      operationMode: operationMode,
      modeName: modeName,
      leftEncoderSpeed: leftSpeedCmS,
      rightEncoderSpeed: rightSpeedCmS,
      leftEncoderCount: 0, // Not provided in new format
      rightEncoderCount: 0,
      totalDistance: 0.0, // Not provided, calculate from RPM if needed
      sensors: sensors,
      battery: 0.0, // Not provided
      closedLoop: closedLoop,
      position: pos,
      correction: pidCorrection,
      leftSpeedCmd: lTargetRpm,
      rightSpeedCmd: rTargetRpm,
      leftSpeed: lPwm / 255.0, // PWM to normalized speed
      rightSpeed: rPwm / 255.0,
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
      'battery': battery,
      'closedLoop': closedLoop,
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
  
  /// Check if this is remote control mode
  bool get isRemoteControlMode => operationMode == 1;


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
      // Error parsing sensors data: $e, data: $sensorsData
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
    return {'base_speed': baseSpeed};
  }
}

class EepromSaveCommand {
  Map<String, dynamic> toJson() {
    return {'eeprom': 1};
  }
}

class FactoryResetCommand {
  Map<String, dynamic> toJson() {
    return {'factory_reset': 1};
  }
}

class TelemetryRequestCommand {
  Map<String, dynamic> toJson() {
    return {'tele': 2}; // Get once
  }
}

class TelemetryEnableCommand {
  final bool enable;

  TelemetryEnableCommand(this.enable);

  Map<String, dynamic> toJson() {
    return {'tele': enable ? 1 : 0};
  }
}

class CalibrateQtrCommand {
  Map<String, dynamic> toJson() {
    return {'qtr': 1};
  }
}

class PidCommand {
  final double kp;
  final double ki;
  final double kd;

  PidCommand({
    required this.kp,
    required this.ki,
    required this.kd,
  });

  Map<String, dynamic> toJson() {
    return {
      'pid': [kp, ki, kd],
    };
  }
}

class RcCommand {
  final double throttle; // -1.0 to 1.0
  final double turn; // -1.0 to 1.0

  RcCommand({
    required this.throttle,
    required this.turn,
  });

  Map<String, dynamic> toJson() {
    return {'rc': {'throttle': throttle, 'turn': turn}};
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
  bool get isCmd => type == 'cmd';

  @override
  String toString() {
    return 'ArduinoMessage{type: $type, payload: $payload}';
  }
}

/// Telemetry data from Arduino
class TelemetryData {
  final int timestamp;
  final int mode;
  final double velocity;
  final double acceleration;
  final double distance;
  final MotorData left;
  final MotorData right;
  final double battery;
  final List<int> qtr;
  final List<double> pid;
  final double setPoint;
  final double baseSpeed;
  final double error;
  final double correction;

  TelemetryData({
    required this.timestamp,
    required this.mode,
    required this.velocity,
    required this.acceleration,
    required this.distance,
    required this.left,
    required this.right,
    required this.battery,
    required this.qtr,
    required this.pid,
    required this.setPoint,
    required this.baseSpeed,
    required this.error,
    required this.correction,
  });

  static TelemetryData? fromPayload(Map<String, dynamic> payload) {
    try {
      return TelemetryData(
        timestamp: payload['timestamp'] ?? 0,
        mode: payload['mode'] ?? 0,
        velocity: (payload['velocity'] as num?)?.toDouble() ?? 0.0,
        acceleration: (payload['acceleration'] as num?)?.toDouble() ?? 0.0,
        distance: (payload['distance'] as num?)?.toDouble() ?? 0.0,
        left: MotorData.fromJson(payload['left'] as Map<String, dynamic>? ?? {}),
        right: MotorData.fromJson(payload['right'] as Map<String, dynamic>? ?? {}),
        battery: (payload['battery'] as num?)?.toDouble() ?? 0.0,
        qtr: (payload['qtr'] as List<dynamic>?)?.map((e) => (e as num).toInt()).toList() ?? [],
        pid: (payload['pid'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? [0.0, 0.0, 0.0],
        setPoint: (payload['set_point'] as num?)?.toDouble() ?? 0.0,
        baseSpeed: (payload['base_speed'] as num?)?.toDouble() ?? 0.0,
        error: (payload['error'] as num?)?.toDouble() ?? 0.0,
        correction: (payload['correction'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (e) {
      return null;
    }
  }

  OperationMode get operationMode => OperationMode.fromId(mode);
  bool get isLineFollowingMode => mode == 0;
  bool get isRemoteControlMode => mode == 1;
  bool get isServoMode => mode == 2;

  @override
  String toString() {
    return jsonEncode({
      'type': 'telemetry',
      'payload': {
        'timestamp': timestamp,
        'mode': mode,
        'velocity': velocity,
        'acceleration': acceleration,
        'distance': distance,
        'left': left.toJson(),
        'right': right.toJson(),
        'battery': battery,
        'qtr': qtr,
        'pid': pid,
        'set_point': setPoint,
        'base_speed': baseSpeed,
        'error': error,
        'correction': correction,
      }
    });
  }
}

/// Motor data structure
class MotorData {
  final double vel;
  final double acc;
  final double rpm;
  final double distance;
  final int pwm;

  MotorData({
    required this.vel,
    required this.acc,
    required this.rpm,
    required this.distance,
    required this.pwm,
  });

  static MotorData fromJson(Map<String, dynamic> json) {
    return MotorData(
      vel: (json['vel'] as num?)?.toDouble() ?? 0.0,
      acc: (json['acc'] as num?)?.toDouble() ?? 0.0,
      rpm: (json['rpm'] as num?)?.toDouble() ?? 0.0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      pwm: (json['pwm'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vel': vel,
      'acc': acc,
      'rpm': rpm,
      'distance': distance,
      'pwm': pwm,
    };
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
    return jsonEncode({
      'type': 'status',
      'payload': {
        'status': status,
      }
    });
  }
}

/// Command messages from Arduino
class CmdMessage {
  final String buffer;

  CmdMessage(this.buffer);

  static CmdMessage? fromPayload(Map<String, dynamic> payload) {
    try {
      if (payload.containsKey('buffer') && payload['buffer'] is String) {
        return CmdMessage(payload['buffer']);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  @override
  String toString() {
    return jsonEncode({
      'type': 'cmd',
      'payload': {
        'buffer': buffer,
      }
    });
  }
}

// Backward compatibility alias
typedef ArduinoLineFollowerData = ArduinoData;
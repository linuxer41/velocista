import 'dart:convert';

import 'package:flutter/material.dart';

enum OperationMode {
      idle(0, 'IDLE', Icons.pause_circle, 'IDLE'),
      lineFollowing(1, 'LINE FOLLOWING', Icons.route, 'LINE'),
      remoteControl(2, 'REMOTE CONTROL', Icons.gamepad, 'REMOTE');

   const OperationMode(this.id, this.displayName, this.icon, this.shortName);
   final int id;
   final String displayName;
   final IconData icon;
   final String shortName;

   static OperationMode fromId(int id) {
     return OperationMode.values.firstWhere(
       (mode) => mode.id == id,
       orElse: () => OperationMode.idle,
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
   final bool cascade; // Cascade control enabled
   final double battery; // Battery percentage
   final int uptime; // Time since startup in ms

   // Line Following specific data
   final double? position; // Line position (2000-7000 for 6 sensors, 1000-8000 for 8)
   final double? error; // Error from setpoint
   final double? correction; // PID correction value
   final double? leftSpeedCmd; // Left motor command speed (-1 to 1)
   final double? rightSpeedCmd; // Right motor command speed (-1 to 1)

   // Extended PID data
   final List<double>? linePid; // [KP,KI,KD,posicion_linea,output,error,integral,derivada]
   final List<double>? leftVel; // [RPM_actual,RPM_objetivo,PWM,encoder_count]
   final List<double>? rightVel; // [RPM_actual,RPM_objetivo,PWM,encoder_count]
   final List<double>? leftPid; // [KP,KI,KD,RPM_objetivo,output,error,integral,derivada]
   final List<double>? rightPid; // [KP,KI,KD,RPM_objetivo,output,error,integral,derivada]

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
    this.cascade = true,
    this.uptime = 0,
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
    this.linePid,
    this.leftVel,
    this.rightVel,
    this.leftPid,
    this.rightPid,
  });

  /// Parse data from Arduino (supports typed messages and pipe-separated formats)
  static ArduinoData? fromJson(String dataString) {
    final trimmed = dataString.trim();

    // Handle typed messages (type:1|, type:2|, type:3|, type:4|)
    if (trimmed.startsWith('type:')) {
      return _fromTypedMessageFormat(trimmed);
    }

    // Default to pipe-separated format
    return _fromPipeFormat(trimmed);
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
      cascade: true,
      position: pos,
      correction: pidCorrection,
      leftSpeedCmd: lTargetRpm,
      rightSpeedCmd: rTargetRpm,
      leftSpeed: lPwm / 255.0, // PWM to normalized speed
      rightSpeed: rPwm / 255.0,
    );
  }

  /// Parse realtime data from type:4 messages (simplified data)
  static ArduinoData? _parseRealtimeData(String realtimeString) {
    final dataMap = <String, dynamic>{};

    // Split by '|' and parse key:value pairs
    final pairs = realtimeString.split('|');
    for (final pair in pairs) {
      final colonIndex = pair.indexOf(':');
      if (colonIndex > 0) {
        final key = pair.substring(0, colonIndex).trim();
        final value = pair.substring(colonIndex + 1).trim();
        dataMap[key] = value;
      }
    }

    // Parse key-value pairs

    // Parse MODE
    final mode = int.tryParse(dataMap['MODE'] ?? '0') ?? 0;

    // Parse CASCADE
    final cascade = (int.tryParse(dataMap['CASCADE'] ?? '1') ?? 1) == 1;

    // Parse LINE array: [position, error]
    List<double> lineData = [];
    final lineStr = dataMap['LINE'] ?? '[]';
    if (lineStr.startsWith('[') && lineStr.endsWith(']')) {
      final arrayContent = lineStr.substring(1, lineStr.length - 1);
      lineData = arrayContent.split(',').map((s) => double.tryParse(s.trim()) ?? 0.0).toList();
    }

    // Parse LEFT array: [RPM_actual, RPM_objetivo, PWM, encoder_count]
    List<double> leftData = [];
    final leftStr = dataMap['LEFT'] ?? '[]';
    if (leftStr.startsWith('[') && leftStr.endsWith(']')) {
      final arrayContent = leftStr.substring(1, leftStr.length - 1);
      leftData = arrayContent.split(',').map((s) => double.tryParse(s.trim()) ?? 0.0).toList();
    }

    // Parse RIGHT array: [RPM_actual, RPM_objetivo, PWM, encoder_count]
    List<double> rightData = [];
    final rightStr = dataMap['RIGHT'] ?? '[]';
    if (rightStr.startsWith('[') && rightStr.endsWith(']')) {
      final arrayContent = rightStr.substring(1, rightStr.length - 1);
      rightData = arrayContent.split(',').map((s) => double.tryParse(s.trim()) ?? 0.0).toList();
    }

    // Parse QTR sensors
    List<int> sensors = [];
    final qtrStr = dataMap['QTR'] ?? '[]';
    if (qtrStr.startsWith('[') && qtrStr.endsWith(']')) {
      final arrayContent = qtrStr.substring(1, qtrStr.length - 1);
      sensors = arrayContent.split(',').map((s) => int.tryParse(s.trim()) ?? 0).toList();
    }

    // Parse uptime
    final uptime = int.tryParse(dataMap['UPTIME'] ?? '0') ?? 0;

    // Extract values
    final position = lineData.isNotEmpty ? lineData[0] : 0.0;
    final error = lineData.length > 1 ? lineData[1] : 0.0;
    final leftRpm = leftData.isNotEmpty ? leftData[0] : 0.0;
    final leftTargetRpm = leftData.length > 1 ? leftData[1] : 0.0;
    final leftPwm = leftData.length > 2 ? leftData[2] : 0.0;
    final leftEncoderCount = leftData.length > 3 ? leftData[3] : 0.0;
    final rightRpm = rightData.isNotEmpty ? rightData[0] : 0.0;
    final rightTargetRpm = rightData.length > 1 ? rightData[1] : 0.0;
    final rightPwm = rightData.length > 2 ? rightData[2] : 0.0;
    final rightEncoderCount = rightData.length > 3 ? rightData[3] : 0.0;

    final result = ArduinoData(
      operationMode: mode, // 0=IDLE, 1=LINE_FOLLOWING, 2=REMOTE_CONTROL
      modeName: mode == 0 ? 'IDLE' : (mode == 1 ? 'LINE FOLLOWING' : 'REMOTE CONTROL'),
      leftEncoderSpeed: leftRpm, // RPM as speed
      rightEncoderSpeed: rightRpm,
      leftEncoderCount: leftEncoderCount.toInt(),
      rightEncoderCount: rightEncoderCount.toInt(),
      totalDistance: 0.0, // Not provided in realtime
      sensors: sensors ?? [],
      battery: 0.0, // Not provided in realtime
      cascade: cascade,
      uptime: uptime,
      position: position,
      error: error,
      correction: null, // Not provided in realtime
      leftSpeed: leftPwm / 255.0, // PWM to normalized
      rightSpeed: rightPwm / 255.0,
      leftVel: [leftRpm, leftTargetRpm, leftPwm, leftEncoderCount],
      rightVel: [rightRpm, rightTargetRpm, rightPwm, rightEncoderCount],
    );

    return result;
  }

  /// Parse typed message format (type:1|, type:2|, type:3|, type:4|)
  static ArduinoData? _fromTypedMessageFormat(String messageString) {
    if (messageString.startsWith('type:2|')) {
      // Telemetry data (complete)
      final dataPart = messageString.substring(7); // Remove 'type:2|'
      // return _parseTelemetryData(dataPart);
      return null; // now use realtime
    } else if (messageString.startsWith('type:4|')) {
      // Realtime data (simplified)
      final dataPart = messageString.substring(7); // Remove 'type:4|'
      return _parseRealtimeData(dataPart);
    } else if (messageString.startsWith('type:1|')) {
      // System message - not ArduinoData, return null
      return null;
    } else if (messageString.startsWith('type:3|')) {
      // Command acknowledgment - not ArduinoData, return null
      return null;
    }
    return null;
  }

  /// Parse telemetry data from type:2 messages (complete data)
  static ArduinoData _parseTelemetryData(String telemetryString) {
    final dataMap = <String, dynamic>{};

    // Split by '|' and parse key:value pairs
    final pairs = telemetryString.split('|');
    for (final pair in pairs) {
      final colonIndex = pair.indexOf(':');
      if (colonIndex > 0) {
        final key = pair.substring(0, colonIndex).trim();
        final value = pair.substring(colonIndex + 1).trim();
        dataMap[key] = value;
      }
    }

    // Parse arrays
    final linePid = _parseDoubleArray(dataMap['LINE_PID']);
    final leftVel = _parseDoubleArray(dataMap['LVEL']);
    final rightVel = _parseDoubleArray(dataMap['RVEL']);
    final leftPid = _parseDoubleArray(dataMap['LEFT_PID']);
    final rightPid = _parseDoubleArray(dataMap['RIGHT_PID']);
    final qtr = _parseIntArray(dataMap['QTR']);

    // Parse simple values
    final cascade = (int.tryParse(dataMap['CASCADE'] ?? '1') ?? 1) == 1;
    final mode = int.tryParse(dataMap['MODE'] ?? '0') ?? 0;
    final battery = double.tryParse(dataMap['BATT'] ?? '0.0') ?? 0.0;
    final loopUs = int.tryParse(dataMap['LOOP_US'] ?? '0') ?? 0;
    final uptime = int.tryParse(dataMap['UPTIME'] ?? '0') ?? 0;

    // Extract values from arrays
    double? position, error, correction, leftSpeedCmd, rightSpeedCmd;
    double leftEncoderSpeed = 0.0, rightEncoderSpeed = 0.0;
    int leftEncoderCount = 0, rightEncoderCount = 0;

    if (linePid != null && linePid.length >= 8) {
      // LINE_PID: [KP,KI,KD,posicion_linea,output,error,integral,derivada]
      position = linePid[3]; // posicion_linea
      correction = linePid[4]; // output
      error = linePid[5]; // error
    }

    if (leftVel != null && leftVel.length >= 4) {
      // LVEL: [RPM_actual,RPM_objetivo,PWM,encoder_count]
      leftEncoderSpeed = leftVel[0]; // RPM_actual
      leftSpeedCmd = leftVel[1]; // RPM_objetivo
      leftEncoderCount = leftVel[3].toInt(); // encoder_count
    }

    if (rightVel != null && rightVel.length >= 4) {
      // RVEL: [RPM_actual,RPM_objetivo,PWM,encoder_count]
      rightEncoderSpeed = rightVel[0]; // RPM_actual
      rightSpeedCmd = rightVel[1]; // RPM_objetivo
      rightEncoderCount = rightVel[3].toInt(); // encoder_count
    }

    return ArduinoData(
      operationMode: mode, // 0=IDLE, 1=LINE_FOLLOWING, 2=REMOTE_CONTROL
      modeName: mode == 0 ? 'IDLE' : (mode == 1 ? 'LINE FOLLOWING' : 'REMOTE CONTROL'),
      leftEncoderSpeed: leftEncoderSpeed,
      rightEncoderSpeed: rightEncoderSpeed,
      leftEncoderCount: leftEncoderCount,
      rightEncoderCount: rightEncoderCount,
      totalDistance: 0.0, // Not provided in telemetry
      sensors: qtr ?? [],
      battery: battery,
      cascade: true,
      uptime: uptime,
      position: position,
      error: error,
      correction: correction,
      leftSpeedCmd: leftSpeedCmd,
      rightSpeedCmd: rightSpeedCmd,
      linePid: linePid,
      leftVel: leftVel,
      rightVel: rightVel,
      leftPid: leftPid,
      rightPid: rightPid,
    );
  }

  /// Parse array of doubles from string like "[1.0,2.0,3.0]"
  static List<double>? _parseDoubleArray(dynamic value) {
    if (value is! String) return null;
    final str = value.trim();
    if (!str.startsWith('[') || !str.endsWith(']')) return null;

    final content = str.substring(1, str.length - 1);
    if (content.isEmpty) return [];

    return content.split(',').map((s) => double.tryParse(s.trim()) ?? 0.0).toList();
  }

  /// Parse array of ints from string like "[1,2,3]"
  static List<int>? _parseIntArray(dynamic value) {
    if (value is! String) return null;
    final str = value.trim();
    if (!str.startsWith('[') || !str.endsWith(']')) return null;

    final content = str.substring(1, str.length - 1);
    if (content.isEmpty) return [];

    return content.split(',').map((s) => int.tryParse(s.trim()) ?? 0).toList();
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
      'cascade': cascade,
      'uptime': uptime,
    };

    // Add extended PID data if available
    if (linePid != null) map['linePid'] = linePid!;
    if (leftVel != null) map['leftVel'] = leftVel!;
    if (rightVel != null) map['rightVel'] = rightVel!;
    if (leftPid != null) map['leftPid'] = leftPid!;
    if (rightPid != null) map['rightPid'] = rightPid!;

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

    String toCommand() {
      return 'set mode ${mode.id}';
    }
}




class EepromSaveCommand {
   String toCommand() {
     return 'save';
   }
}

class FactoryResetCommand {
   String toCommand() {
     return 'reset';
   }
}

class TelemetryRequestCommand {
   String toCommand() {
     return 'telemetry';
   }
}

class RealtimeEnableCommand {
   final bool enable;

   RealtimeEnableCommand(this.enable);

   String toCommand() {
     return 'set realtime ${enable ? 1 : 0}';
   }
}

class RealtimeRequestCommand {
   String toCommand() {
     return 'realtime';
   }
}

class CalibrateQtrCommand {
   String toCommand() {
     return 'calibrate';
   }
}

class PidCommand {
   final String type; // 'line', 'left', 'right'
   final double kp;
   final double ki;
   final double kd;

   PidCommand({
     required this.type,
     required this.kp,
     required this.ki,
     required this.kd,
   });

   String toCommand() {
     return 'set $type ${kp.toStringAsFixed(2)},${ki.toStringAsFixed(3)},${kd.toStringAsFixed(2)}';
   }
}

class RcCommand {
    final int throttle; // -230 to 230
    final int steering; // -230 to 230

    RcCommand({
      required this.throttle,
      required this.steering,
    });

    String toCommand() {
      return 'rc ${throttle},${steering}';
    }
}

class CascadeCommand {
      final bool enable; // true to enable cascade, false to disable

      CascadeCommand(this.enable);

      String toCommand() {
        return 'set cascade ${enable ? 1 : 0}';
      }
  }

class BaseSpeedCommand {
    final double value;

    BaseSpeedCommand(this.value);

    String toCommand() {
      return 'set base speed ${value.toStringAsFixed(0)}';
    }
}

class BaseRpmCommand {
    final double value;

    BaseRpmCommand(this.value);

    String toCommand() {
      return 'set base rpm ${value.toStringAsFixed(1)}';
    }
}

class RelationCommand {
    final bool enable;

    RelationCommand(this.enable);

    String toCommand() {
      return 'set relation ${enable ? 1 : 0}';
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


// Backward compatibility alias
typedef ArduinoLineFollowerData = ArduinoData;
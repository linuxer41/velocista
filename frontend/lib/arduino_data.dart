import 'dart:convert';

import 'package:flutter/material.dart';

/// Base class for all serial data types
abstract class SerialData {
  final int type;

  SerialData(this.type);

  /// Parse data from serial string based on type
  static SerialData? fromSerial(String dataString) {
    final trimmed = dataString.trim();

    if (trimmed.startsWith('type:1|')) {
      return SystemMessage.fromSerial(trimmed);
    } else if (trimmed.startsWith('type:2|')) {
      return AckData.fromSerial(trimmed);
    } else if (trimmed.startsWith('type:3|')) {
      return ConfigData.fromSerial(trimmed);
    } else if (trimmed.startsWith('type:4|')) {
      return TelemetryData.fromSerial(trimmed);
    } else if (trimmed.startsWith('type:5|')) {
      return DebugData.fromSerial(trimmed);
    }

    return null;
  }
}

/// System messages (type:1)
class SystemMessage extends SerialData {
  final String message;

  SystemMessage(this.message) : super(1);

  static SystemMessage? fromSerial(String dataString) {
    if (!dataString.startsWith('type:1|')) return null;
    final message = dataString.substring(7).trim();
    return SystemMessage(message);
  }

  @override
  String toString() => 'SystemMessage: $message';
}

/// Command acknowledgments (type:3)
class AckData extends SerialData {
  final String acknowledgment;

  AckData(this.acknowledgment) : super(3);

  static AckData? fromSerial(String dataString) {
    if (!dataString.startsWith('type:3|')) return null;
    final ack = dataString.substring(7).trim();
    return AckData(ack);
  }

  @override
  String toString() => 'AckData: $acknowledgment';
}

/// Configuration data (type:3)
class ConfigData extends SerialData {
  final List<double>? lineKPid;
  final List<double>? leftKPid;
  final List<double>? rightKPid;
  final List<double>? base;
  final List<double>? max;
  final List<double>? wheels;
  final double? weight;
  final List<int>? sampRate;
  final int? mode;
  final int? cascade;
  final int? telemetry;
  final List<int>? featConfig;

  ConfigData({
    this.lineKPid,
    this.leftKPid,
    this.rightKPid,
    this.base,
    this.max,
    this.wheels,
    this.weight,
    this.sampRate,
    this.mode,
    this.cascade,
    this.telemetry,
    this.featConfig,
  }) : super(3);

  static ConfigData? fromSerial(String dataString) {
    if (!dataString.startsWith('type:3|')) return null;
    final dataPart = dataString.substring(7);
    return _parseConfigData(dataPart);
  }

  static ConfigData _parseConfigData(String configString) {
    final dataMap = <String, dynamic>{};

    // Split by '|' and parse key:value pairs
    final pairs = configString.split('|');
    for (final pair in pairs) {
      final colonIndex = pair.indexOf(':');
      if (colonIndex > 0) {
        final key = pair.substring(0, colonIndex).trim();
        final value = pair.substring(colonIndex + 1).trim();
        dataMap[key] = value;
      }
    }

    // Parse arrays
    final lineKPid = _parseDoubleArray(dataMap['LINE_K_PID']);
    final leftKPid = _parseDoubleArray(dataMap['LEFT_K_PID']);
    final rightKPid = _parseDoubleArray(dataMap['RIGHT_K_PID']);
    final base = _parseDoubleArray(dataMap['BASE']);
    final max = _parseDoubleArray(dataMap['MAX']);
    final wheels = _parseDoubleArray(dataMap['WHEELS']);
    final weight = double.tryParse(dataMap['WEIGHT'] ?? '155.0') ?? 155.0;
    final sampRate = _parseIntArray(dataMap['SAMP_RATE']);
    final featConfig = _parseIntArray(dataMap['FEAT_CONFIG']);

    // Parse simple values
    final mode = int.tryParse(dataMap['MODE'] ?? '');
    final cascade = int.tryParse(dataMap['CASCADE'] ?? '');
    final telemetry = int.tryParse(dataMap['TELEMETRY'] ?? '');

    return ConfigData(
      lineKPid: lineKPid,
      leftKPid: leftKPid,
      rightKPid: rightKPid,
      base: base,
      max: max,
      wheels: wheels,
      weight: weight,
      sampRate: sampRate,
      mode: mode,
      cascade: cascade,
      telemetry: telemetry,
      featConfig: featConfig,
    );
  }

  @override
  String toString() =>
      'ConfigData{lineKPid: $lineKPid, leftKPid: $leftKPid, rightKPid: $rightKPid, base: $base, max: $max, wheels: $wheels, weight: $weight, sampRate: $sampRate, mode: $mode, cascade: $cascade, telemetry: $telemetry, featConfig: $featConfig}';
}

enum OperationMode {
  idle(0, 'REPOSO', Icons.pause_circle, 'REPOSO'),
  lineFollowing(1, 'SEGUIDOR DE LÍNEA', Icons.route, 'LÍNEA'),
  remoteControl(2, 'CONTROL REMOTO', Icons.gamepad, 'REMOTO');

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

/// Complete debug data (type:5) - config + telemetry
class DebugData extends SerialData {
  // Config fields
  final List<double>? lineKPid;
  final List<double>? leftKPid;
  final List<double>? rightKPid;
  final List<double>? base;
  final List<double>? max;
  final List<double>? wheels;
  final int? mode;
  final int? cascade;

  // Telemetry fields
  final List<double>? line;
  final List<double>? left;
  final List<double>? right;
  final List<double>? pid;
  final List<double>? speedCms;
  final List<int>? qtr;
  final double? batt;
  final int? loopUs;
  final int? freeMem;
  final int? uptime;

  // Features data
  final List<int>? featConfig;
  final List<dynamic>? featValues;

  DebugData({
    this.lineKPid,
    this.leftKPid,
    this.rightKPid,
    this.base,
    this.max,
    this.wheels,
    this.mode,
    this.cascade,
    this.line,
    this.left,
    this.right,
    this.pid,
    this.speedCms,
    this.qtr,
    this.batt,
    this.loopUs,
    this.freeMem,
    this.uptime,
    this.featConfig,
    this.featValues,
  }) : super(5);

  static DebugData? fromSerial(String dataString) {
    if (!dataString.startsWith('type:5|')) return null;
    final dataPart = dataString.substring(7);
    return _parseDebugData(dataPart);
  }

  static DebugData _parseDebugData(String debugString) {
    final dataMap = <String, dynamic>{};

    // Split by '|' and parse key:value pairs
    final pairs = debugString.split('|');
    for (final pair in pairs) {
      final colonIndex = pair.indexOf(':');
      if (colonIndex > 0) {
        final key = pair.substring(0, colonIndex).trim();
        final value = pair.substring(colonIndex + 1).trim();
        dataMap[key] = value;
      }
    }

    // Parse config arrays
    final lineKPid = _parseDoubleArray(dataMap['LINE_K_PID']);
    final leftKPid = _parseDoubleArray(dataMap['LEFT_K_PID']);
    final rightKPid = _parseDoubleArray(dataMap['RIGHT_K_PID']);
    final base = _parseDoubleArray(dataMap['BASE']);
    final max = _parseDoubleArray(dataMap['MAX']);
    final wheels = _parseDoubleArray(dataMap['WHEELS']);

    // Parse telemetry arrays
    final line = _parseDoubleArray(dataMap['LINE']);
    final left = _parseDoubleArray(dataMap['LEFT']);
    final right = _parseDoubleArray(dataMap['RIGHT']);
    final pid = _parseDoubleArray(dataMap['PID']);
    final speedCms = _parseDoubleArray(dataMap['SPEED_CMS']);
    final qtr = _parseIntArray(dataMap['QTR']);
    final featConfig = _parseIntArray(dataMap['FEAT_CONFIG']) ??
        _parseIntArray(dataMap['FILTERS']);
    final featValues = _parseDynamicArray(dataMap['FEAT_VALUES']);

    // Parse simple values
    final mode = int.tryParse(dataMap['MODE'] ?? '');
    final cascade = int.tryParse(dataMap['CASCADE'] ?? '');
    final batt = double.tryParse(dataMap['BATT'] ?? '0.0') ?? 0.0;
    final loopUs = int.tryParse(dataMap['LOOP_US'] ?? '0') ?? 0;
    final freeMem = int.tryParse(dataMap['FREE_MEM'] ?? '0') ?? 0;
    final uptime = int.tryParse(dataMap['UPTIME'] ?? '0') ?? 0;

    return DebugData(
      lineKPid: lineKPid,
      leftKPid: leftKPid,
      rightKPid: rightKPid,
      base: base,
      max: max,
      wheels: wheels,
      mode: mode,
      cascade: cascade,
      line: line,
      left: left,
      right: right,
      pid: pid,
      speedCms: speedCms,
      qtr: qtr,
      batt: batt,
      loopUs: loopUs,
      freeMem: freeMem,
      uptime: uptime,
      featConfig: featConfig,
      featValues: featValues,
    );
  }

  @override
  String toString() =>
      'DebugData{mode: $mode, cascade: $cascade, batt: $batt, uptime: $uptime}';
}

/// telemetry data (type:4)
class TelemetryData extends SerialData {
  final int operationMode;
  final String modeName;
  final double leftEncoderSpeed;
  final double rightEncoderSpeed;
  final int leftEncoderCount;
  final int rightEncoderCount;
  final List<int> sensors;
  final bool cascade;
  final int uptime;

  // Line Following specific data
  final List<double>? line;

  // Motor data
  final List<double>? left;
  final List<double>? right;
  final List<double>? pid;
  final List<double>? speedCms;
  final double? batt;
  final int? loopUs;
  final int? freeMem;

  // Features data
  final List<int>? featConfig;
  final List<dynamic>? featValues;

  // Line state data
  final double? curv;
  final int? state;

  TelemetryData({
    required this.operationMode,
    required this.modeName,
    required this.leftEncoderSpeed,
    required this.rightEncoderSpeed,
    required this.leftEncoderCount,
    required this.rightEncoderCount,
    required this.sensors,
    this.cascade = true,
    this.uptime = 0,
    this.line,
    this.left,
    this.right,
    this.pid,
    this.speedCms,
    this.batt,
    this.loopUs,
    this.freeMem,
    this.featConfig,
    this.featValues,
    this.curv,
    this.state,
  }) : super(4);

  static TelemetryData? fromSerial(String dataString) {
    if (!dataString.startsWith('type:4|')) return null;
    final dataPart = dataString.substring(7);
    return _parseTelemetryData(dataPart);
  }

  static TelemetryData _parseTelemetryData(String telemetryString) {
    final dataMap = <String, dynamic>{};

    if (telemetryString.trim().startsWith('{')) {
      // JSON format
      final jsonData = jsonDecode(telemetryString);
      dataMap.addAll(jsonData as Map<String, dynamic>);
    } else {
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
    }

    // Parse MODE
    final mode = dataMap['MODE'] is int
        ? dataMap['MODE']
        : int.tryParse(dataMap['MODE']?.toString() ?? '0') ?? 0;

    // Parse CASCADE
    final cascadeValue = dataMap['CASCADE'];
    final cascade = cascadeValue is bool
        ? cascadeValue
        : (cascadeValue is int
            ? cascadeValue == 1
            : (int.tryParse(cascadeValue?.toString() ?? '1') ?? 1) == 1);

    // Parse arrays
    final line = _parseDoubleArray(dataMap['LINE']);
    final left = _parseDoubleArray(dataMap['LEFT']);
    final right = _parseDoubleArray(dataMap['RIGHT']);
    final pid = _parseDoubleArray(dataMap['PID']);
    final speedCms = _parseDoubleArray(dataMap['SPEED_CMS']);
    final qtr = _parseIntArray(dataMap['QTR']);
    final featValues = _parseDynamicArray(dataMap['FEAT_VALUES']);

    // Parse simple values
    final batt = double.tryParse(dataMap['BATT'] ?? '0.0') ?? 0.0;
    final loopUs = int.tryParse(dataMap['LOOP_US'] ?? '0') ?? 0;
    final freeMem = int.tryParse(dataMap['FREE_MEM'] ?? '0') ?? 0;
    final uptime = int.tryParse(dataMap['UPTIME'] ?? '0') ?? 0;
    final curv = double.tryParse(dataMap['CURV'] ?? '0.0') ?? 0.0;
    final state = int.tryParse(dataMap['STATE'] ?? '0') ?? 0;

    // Extract encoder values
    final leftRpm = left != null && left.isNotEmpty ? left[0] : 0.0;
    final rightRpm = right != null && right.isNotEmpty ? right[0] : 0.0;
    final leftEncoderCount =
        left != null && left.length > 3 ? left[3].toInt() : 0;
    final rightEncoderCount =
        right != null && right.length > 3 ? right[3].toInt() : 0;

    return TelemetryData(
      operationMode: mode,
      modeName: mode == 0
          ? 'REPOSO'
          : (mode == 1 ? 'SEGUIDOR DE LÍNEA' : 'CONTROL REMOTO'),
      leftEncoderSpeed: leftRpm,
      rightEncoderSpeed: rightRpm,
      leftEncoderCount: leftEncoderCount,
      rightEncoderCount: rightEncoderCount,
      sensors: qtr ?? [],
      cascade: cascade,
      uptime: uptime,
      line: line,
      left: left,
      right: right,
      pid: pid,
      speedCms: speedCms,
      batt: batt,
      loopUs: loopUs,
      freeMem: freeMem,
      featConfig:
          null, // FEAT_CONFIG removed from telemetry, now only in config
      featValues: featValues,
      curv: curv,
      state: state,
    );
  }

  @override
  String toString() =>
      'TelemetryData{mode: $modeName, encoders: L=${leftEncoderSpeed.toStringAsFixed(1)}, R=${rightEncoderSpeed.toStringAsFixed(1)}}';
}

/// Helper methods for parsing arrays
List<double>? _parseDoubleArray(dynamic value) {
  if (value is! String) return null;
  final str = value.trim();
  if (!str.startsWith('[') || !str.endsWith(']')) return null;

  final content = str.substring(1, str.length - 1);
  if (content.isEmpty) return [];

  return content
      .split(',')
      .map((s) => double.tryParse(s.trim()) ?? 0.0)
      .toList();
}

List<int>? _parseIntArray(dynamic value) {
  if (value is! String) return null;
  final str = value.trim();
  if (!str.startsWith('[') || !str.endsWith(']')) return null;

  final content = str.substring(1, str.length - 1);
  if (content.isEmpty) return [];

  return content.split(',').map((s) => int.tryParse(s.trim()) ?? 0).toList();
}

List<dynamic>? _parseDynamicArray(dynamic value) {
  if (value is! String) return null;
  final str = value.trim();
  if (!str.startsWith('[') || !str.endsWith(']')) return null;

  final content = str.substring(1, str.length - 1);
  if (content.isEmpty) return [];

  return content.split(',').map((s) => s.trim()).toList();
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

class DebugRequestCommand {
  String toCommand() {
    return 'get debug';
  }
}

class TelemetryChangeCommand {
  final bool enable;

  TelemetryChangeCommand(this.enable);

  String toCommand() {
    return 'set telemetry ${enable ? 1 : 0}';
  }
}

class TelemetryRequestCommand {
  String toCommand() {
    return 'get telemetry';
  }
}

class ConfigRequestCommand {
  String toCommand() {
    return 'get config';
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
  final double pwm;
  final double rpm;

  BaseSpeedCommand(this.pwm, this.rpm);

  String toCommand() {
    return 'set base ${pwm.toStringAsFixed(0)},${rpm.toStringAsFixed(1)}';
  }
}

class MaxSpeedCommand {
  final double pwm;
  final double rpm;

  MaxSpeedCommand(this.pwm, this.rpm);

  String toCommand() {
    return 'set max ${pwm.toStringAsFixed(0)},${rpm.toStringAsFixed(1)}';
  }
}

class RelationCommand {
  final bool enable;

  RelationCommand(this.enable);

  String toCommand() {
    return 'set relation ${enable ? 1 : 0}';
  }
}


class FeatureCommand {
  final int index; // Feature index (0-8)
  final int value; // Feature state (0 or 1)

  FeatureCommand(this.index, this.value) {
    if (index < 0 || index > 8) {
      throw ArgumentError('Feature index must be between 0 and 8');
    }
    if (value != 0 && value != 1) {
      throw ArgumentError('Feature value must be 0 or 1');
    }
  }

  String toCommand() {
    return 'set feature $index $value';
  }
}

class SetPwmCommand {
  final int rightPwm;
  final int leftPwm;

  SetPwmCommand({
    required this.rightPwm,
    required this.leftPwm,
  });

  String toCommand() {
    return 'set pwm $rightPwm,$leftPwm';
  }
}

class SetRpmCommand {
  final int leftRpm;
  final int rightRpm;

  SetRpmCommand({
    required this.leftRpm,
    required this.rightRpm,
  });

  String toCommand() {
    return 'set rpm $leftRpm,$rightRpm';
  }
}

class WeightCommand {
  final double weight;

  WeightCommand(this.weight);

  String toCommand() {
    return 'set weight ${weight.toStringAsFixed(1)}';
  }
}

class SampRateCommand {
  final int lineMs;
  final int speedMs;
  final int telemetryMs;

  SampRateCommand(this.lineMs, this.speedMs, this.telemetryMs);

  String toCommand() {
    return 'set samp_rate $lineMs,$speedMs,$telemetryMs';
  }
}

/// PID Configuration for Arduino Line Follower
class ArduinoPIDConfig {
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

  /// Parse configuration from data string
  static ArduinoPIDConfig fromData(String dataString) {
    final map = jsonDecode(dataString);

    return ArduinoPIDConfig(
      kp: (map['Kp'] is num) ? (map['Kp'] as num).toDouble() : 1.0,
      ki: (map['Ki'] is num) ? (map['Ki'] as num).toDouble() : 0.0,
      kd: (map['Kd'] is num) ? (map['Kd'] as num).toDouble() : 0.0,
      setpoint: (map['setpoint'] is num)
          ? (map['setpoint'] as num).toDouble()
          : 2500.0,
      baseSpeed: (map['baseSpeed'] is num)
          ? (map['baseSpeed'] as num).toDouble()
          : 0.8,
    );
  }

  /// Convert to data string for sending
  String toData() {
    final map = {
      'Kp': kp,
      'Ki': ki,
      'Kd': kd,
      'setpoint': setpoint,
      'baseSpeed': baseSpeed,
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


// No backward compatibility aliases needed
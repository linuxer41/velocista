import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import '../app_state.dart';
import '../arduino_data.dart';
import '../connection_bottom_sheet.dart';
import '../widgets/pid_control.dart';
import '../widgets/remote_control.dart';
import 'settings_page.dart';

class HomePage extends StatefulWidget {
  final ThemeProvider themeProvider;

  const HomePage({super.key, required this.themeProvider});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    // Show connection modal automatically if not connected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = AppInheritedWidget.of(context);
      if (appState != null) {
        appState.isConnected.addListener(_onConnectionChanged);
        _checkConnectionAndShowModal();
      }
    });
  }

  @override
  void dispose() {
    final appState = AppInheritedWidget.of(context);
    if (appState != null) {
      appState.isConnected.removeListener(_onConnectionChanged);
    }
    super.dispose();
  }

  void _onConnectionChanged() {
    final appState = AppInheritedWidget.of(context);
    if (appState != null && !appState.isConnected.value && mounted) {
      // Show modal when disconnected
      _showConnectionModal();
    }
  }

  void _checkConnectionAndShowModal() {
    final appState = AppInheritedWidget.of(context);
    if (appState != null && !appState.isConnected.value) {
      _showConnectionModal();
    }
  }

  void _showConnectionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false, // Cannot be dismissed by tapping outside
      enableDrag: false, // Cannot be dragged down
      builder: (context) => const ConnectionBottomSheet(),
    );
  }

  Widget _getControlsWidget(OperationMode mode) {
    final appState = AppInheritedWidget.of(context);
    if (appState == null) return const SizedBox.shrink();

    switch (mode) {
      case OperationMode.lineFollowing:
        return PidControl(appState: appState);
      case OperationMode.remoteControl:
        return RemoteControl(appState: appState);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppInheritedWidget.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: [
                // Status Bar (battery, terminal, connection) - moved above tabs
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: ValueListenableBuilder<ArduinoData?>(
                    valueListenable: appState!.currentData,
                    builder: (context, data, child) {
                      final battery = data != null ? data.battery : 88.0;
                      final isConnected = appState.isConnected.value;

                      return Row(
                        children: [
                          // Battery icon with percentage overlaid
                          SizedBox(
                            width: 28,
                            height: 28,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  Icons.battery_6_bar,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  size: 28,
                                ),
                                Positioned(
                                  bottom: 1,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${battery.toStringAsFixed(0)}',
                                        style: TextStyle(
                                          fontSize: 7,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          fontFamily: 'Space Grotesk',
                                          shadows: [
                                            Shadow(
                                              offset: Offset(1, 1),
                                              blurRadius: 2,
                                              color: Colors.black,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        '%',
                                        style: TextStyle(
                                          fontSize: 5,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                          fontFamily: 'Space Grotesk',
                                          shadows: [
                                            Shadow(
                                              offset: Offset(1, 1),
                                              blurRadius: 2,
                                              color: Colors.black,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Terminal icon
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: IconButton(
                                onPressed: () {
                                  Navigator.pushNamed(context, '/terminal');
                                },
                                icon: Icon(
                                  Icons.terminal,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  size: 20,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Mode selector
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: ValueListenableBuilder<OperationMode>(
                                valueListenable: appState.currentMode,
                                builder: (context, currentMode, child) {
                                  return PopupMenuButton<OperationMode>(
                                    onSelected: (OperationMode mode) async {
                                      await appState.changeOperationMode(mode);
                                    },
                                    itemBuilder: (BuildContext context) =>
                                        OperationMode.values
                                            .map((OperationMode mode) {
                                      return PopupMenuItem<OperationMode>(
                                        value: mode,
                                        child: Row(
                                          children: [
                                            Icon(mode.icon, size: 20),
                                            const SizedBox(width: 8),
                                            Text(mode.displayName,
                                                style: const TextStyle(
                                                    fontSize: 12)),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    child: Icon(
                                      currentMode.icon,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      size: 20,
                                    ),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  );
                                },
                              ),
                            ),
                          ),
                          // Connection button/status on the right
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isConnected
                                      ? Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.2)
                                      : Theme.of(context)
                                          .colorScheme
                                          .primary
                                          .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: isConnected
                                      ? Border.all(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          width: 1,
                                        )
                                      : null,
                                ),
                                child: InkWell(
                                  onTap: _showConnectionModal,
                                  borderRadius: BorderRadius.circular(6),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isConnected
                                            ? Icons.bluetooth_connected
                                            : Icons.bluetooth,
                                        size: 16,
                                        color: isConnected
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                      ),
                                      if (isConnected) ...[
                                        const SizedBox(width: 4),
                                        Flexible(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                appState.connectedDevice.value
                                                        ?.name ??
                                                    'Dispositivo',
                                                style: TextStyle(
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.w600,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary,
                                                  fontFamily: 'Space Grotesk',
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                              Text(
                                                appState.connectedDevice.value
                                                        ?.address ??
                                                    '',
                                                style: TextStyle(
                                                  fontSize: 6,
                                                  fontWeight: FontWeight.w400,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .primary
                                                      .withOpacity(0.8),
                                                  fontFamily: 'monospace',
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ] else ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          'Conectar',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                            fontFamily: 'Space Grotesk',
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Gauges Layout
                ValueListenableBuilder<ArduinoData?>(
                  valueListenable: appState.currentData,
                  builder: (context, data, child) {
                    final leftSpeed = data != null
                        ? (data.leftEncoderSpeed * 0.036)
                        : 0.0; // cm/s to km/h
                    final rightSpeed =
                        data != null ? (data.rightEncoderSpeed * 0.036) : 0.0;
                    final averageSpeed =
                        (leftSpeed + rightSpeed) / 2; // Average speed
                    final leftRpm = data != null
                        ? (data.leftEncoderSpeed / 0.1047)
                        : 0.0; // cm/s back to RPM
                    final rightRpm =
                        data != null ? (data.rightEncoderSpeed / 0.1047) : 0.0;

                    return Column(
                      children: [
                        // Spacer at top for more space
                        const SizedBox(height: 8),
                        // Large centered speed gauge
                        SizedBox(
                          height: 100,
                          child: Center(
                            child: _buildLargeGauge(averageSpeed, 'km/h',
                                Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Two RPM gauges side by side
                        SizedBox(
                          height: 70,
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildCompactGauge(
                                    'L', leftRpm, 'rpm', Colors.green),
                              ),
                              const SizedBox(width: 2),
                              Expanded(
                                child: _buildCompactGauge(
                                    'R', rightRpm, 'rpm', Colors.green),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Distance and Acceleration
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: ValueListenableBuilder<ArduinoData?>(
                            valueListenable: appState.currentData,
                            builder: (context, data, child) {
                              final distance = data != null
                                  ? (data.totalDistance / 100)
                                      .toStringAsFixed(1)
                                  : '0.0'; // cm to km
                              return Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Recorrido',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontFamily: 'Space Grotesk',
                                          ),
                                        ),
                                        Text(
                                          '$distance km',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                            fontFamily: 'Space Grotesk',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Aceleración',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                            fontFamily: 'Space Grotesk',
                                          ),
                                        ),
                                        Text(
                                          '2.1 m/s²', // TODO: Calculate from speed change
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurface,
                                            fontFamily: 'Space Grotesk',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Sensor status - 8 sensors as bars
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => SettingsPage(
                                  appState: appState,
                                  themeProvider: widget.themeProvider,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            height: 70,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceVariant
                                  .withOpacity(0.1),
                            ),
                            child: Column(
                              children: [
                                Text(
                                  'Sensores QTR-QA',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(8, (index) {
                                    // Only sensors 1-6 (indices 1-6) are active, telemetry sends 6 values for sensors 2-7
                                    final isActive = index >= 1 && index <= 6;
                                    final telemetryIndex = isActive ? index - 1 : -1; // Map to telemetry array (0-5)

                                    final sensorValue = isActive && data != null && telemetryIndex < data.sensors.length
                                        ? data.sensors[telemetryIndex]
                                        : 0;
                                    final percentage =
                                        (sensorValue / 1023.0).clamp(0.0, 1.0);

                                    return Container(
                                      width: 20,
                                      height: 35,
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 1),
                                      child: Column(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: isActive
                                                    ? Theme.of(context)
                                                        .colorScheme
                                                        .surfaceVariant
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .surfaceVariant
                                                        .withOpacity(0.3),
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                              ),
                                              child: FractionallySizedBox(
                                                alignment:
                                                    Alignment.bottomCenter,
                                                heightFactor: isActive ? percentage : 0.0,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: isActive
                                                        ? (percentage < 0.3
                                                            ? Colors.red
                                                            : Colors.green)
                                                        : Theme.of(context)
                                                            .colorScheme
                                                            .onSurfaceVariant
                                                            .withOpacity(0.3),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            3),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 1),
                                          Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              fontSize: 8,
                                              color: isActive
                                                  ? Theme.of(context)
                                                      .colorScheme
                                                      .onSurface
                                                  : Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant
                                                      .withOpacity(0.5),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // PID and Base Speed
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: ValueListenableBuilder<ArduinoData?>(
                            valueListenable: appState.currentData,
                            builder: (context, data, child) {
                              final pidValues = data != null && data.pid != null && data.pid!.length >= 3
                                  ? data.pid!
                                  : [0.0, 0.0, 0.0];
                              final baseSpeed = data != null ? data.baseSpeed ?? 0.0 : 0.0;
                              final error = data != null ? data.error ?? 0.0 : 0.0;
                              final correction = data != null ? data.correction ?? 0.0 : 0.0;

                              return Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Text(
                                        'PID: P=${pidValues[0].toStringAsFixed(2)} I=${pidValues[1].toStringAsFixed(3)} D=${pidValues[2].toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                          fontFamily: 'Space Grotesk',
                                        ),
                                      ),
                                      Text(
                                        'Vel Base: ${(baseSpeed * 100).toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                          fontFamily: 'Space Grotesk',
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    children: [
                                      Text(
                                        'Error: ${error.toStringAsFixed(1)}',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w400,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontFamily: 'Space Grotesk',
                                        ),
                                      ),
                                      Text(
                                        'Corrección: ${correction.toStringAsFixed(1)}',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w400,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                          fontFamily: 'Space Grotesk',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        // Encoder Readings
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          child: ValueListenableBuilder<ArduinoData?>(
                            valueListenable: appState.currentData,
                            builder: (context, data, child) {
                              final leftEncoder =
                                  data != null ? data.leftEncoderSpeed : 0.0;
                              final rightEncoder =
                                  data != null ? data.rightEncoderSpeed : 0.0;
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Text(
                                    'Encoder Izq: ${leftEncoder.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontFamily: 'Space Grotesk',
                                    ),
                                  ),
                                  Text(
                                    'Encoder Der: ${rightEncoder.toStringAsFixed(1)}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                      fontFamily: 'Space Grotesk',
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Dynamic controls based on selected mode
                        ValueListenableBuilder<OperationMode>(
                          valueListenable: appState.currentMode,
                          builder: (context, mode, child) {
                            return _getControlsWidget(mode);
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLargeGauge(double value, String unit, Color color) {
    return SizedBox(
      width: 120,
      height: 120,
      child: SfRadialGauge(
        axes: <RadialAxis>[
          RadialAxis(
            minimum: 0,
            maximum: unit == 'km/h' ? 100 : 5000, // Adjust max based on unit
            showLabels: false,
            showTicks: false,
            axisLineStyle: AxisLineStyle(
              thickness: 14,
              color: Theme.of(context).colorScheme.surfaceVariant,
              thicknessUnit: GaugeSizeUnit.logicalPixel,
            ),
            pointers: <GaugePointer>[
              RangePointer(
                value: value,
                width: 14,
                color: color,
                enableAnimation: true,
                animationDuration: 300,
                cornerStyle: CornerStyle.bothCurve,
              ),
            ],
            annotations: <GaugeAnnotation>[
              GaugeAnnotation(
                widget: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      value.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontFamily: 'Space Grotesk',
                      ),
                    ),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFamily: 'Space Grotesk',
                      ),
                    ),
                  ],
                ),
                angle: 90,
                positionFactor: 0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompactGauge(
      String title, double value, String unit, Color color) {
    return SizedBox(
      width: 80,
      height: 80,
      child: SfRadialGauge(
        axes: <RadialAxis>[
          RadialAxis(
            minimum: 0,
            maximum: unit == 'km/h' ? 100 : 5000, // Adjust max based on unit
            showLabels: false,
            showTicks: false,
            axisLineStyle: AxisLineStyle(
              thickness: 8,
              color: Theme.of(context).colorScheme.surfaceVariant,
              thicknessUnit: GaugeSizeUnit.logicalPixel,
            ),
            pointers: <GaugePointer>[
              RangePointer(
                value: value,
                width: 8,
                color: color,
                enableAnimation: true,
                animationDuration: 300,
                cornerStyle: CornerStyle.bothCurve,
              ),
            ],
            annotations: <GaugeAnnotation>[
              GaugeAnnotation(
                widget: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).colorScheme.onSurface,
                          fontFamily: 'Space Grotesk',
                        ),
                      ),
                    Text(
                      value.toStringAsFixed(0),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontFamily: 'Space Grotesk',
                      ),
                    ),
                    Text(
                      unit,
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontFamily: 'Space Grotesk',
                      ),
                    ),
                  ],
                ),
                angle: 90,
                positionFactor: 0,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGauge(String title, double value, String unit, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (title.isNotEmpty)
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Space Grotesk',
            ),
            textAlign: TextAlign.center,
          ),
        if (title.isNotEmpty) const SizedBox(height: 8),
        SizedBox(
          width: 120,
          height: 120,
          child: SfRadialGauge(
            axes: <RadialAxis>[
              RadialAxis(
                minimum: 0,
                maximum:
                    unit == 'km/h' ? 100 : 5000, // Adjust max based on unit
                showLabels: false,
                showTicks: false,
                axisLineStyle: AxisLineStyle(
                  thickness: 12,
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  thicknessUnit: GaugeSizeUnit.logicalPixel,
                ),
                pointers: <GaugePointer>[
                  RangePointer(
                    value: value,
                    width: 12,
                    color: color,
                    enableAnimation: true,
                    animationDuration: 300,
                    cornerStyle: CornerStyle.bothCurve,
                  ),
                ],
                annotations: <GaugeAnnotation>[
                  GaugeAnnotation(
                    widget: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          value.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontFamily: 'Space Grotesk',
                          ),
                        ),
                        Text(
                          unit,
                          style: TextStyle(
                            fontSize: 14,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontFamily: 'Space Grotesk',
                          ),
                        ),
                      ],
                    ),
                    angle: 90,
                    positionFactor: 0,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

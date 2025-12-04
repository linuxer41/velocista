import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../app_state.dart';
import '../widgets/custom_appbar.dart';

class GraphsPage extends StatefulWidget {
  const GraphsPage({super.key});

  @override
  State<GraphsPage> createState() => _GraphsPageState();
}

class _GraphsPageState extends State<GraphsPage> {
  final int maxDataPoints = 100; // Keep last 100 data points for performance

  // PID gains
  List<double>? lineKPid;
  List<double>? leftKPid;
  List<double>? rightKPid;

  // Historical data storage
  final List<double> timestamps = [];
  final List<double> lineErrors = [];
  final List<double> linePositions = [];
  final List<double> lineIntegrals = [];
  final List<double> lineDerivatives = [];
  final List<double> linePidOutputs = [];
  final List<double> leftMotorRpms = [];
  final List<double> leftMotorTargetRpms = [];
  final List<double> leftMotorPwms = [];
  final List<double> leftMotorErrors = [];
  final List<double> leftMotorIntegrals = [];
  final List<double> leftMotorDerivatives = [];
  final List<double> leftMotorPidOutputs = [];
  final List<double> rightMotorRpms = [];
  final List<double> rightMotorTargetRpms = [];
  final List<double> rightMotorPwms = [];
  final List<double> rightMotorErrors = [];
  final List<double> rightMotorIntegrals = [];
  final List<double> rightMotorDerivatives = [];
  final List<double> rightMotorPidOutputs = [];

  bool isCollectingData = true;

  @override
  void initState() {
    super.initState();
    // Setup listener after the widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = AppInheritedWidget.of(context);
      if (appState != null) {
        appState.telemetryData.addListener(_onTelemetryDataReceived);
        appState.configData.addListener(_onConfigDataReceived);
      }
    });
  }

  @override
  void dispose() {
    final appState = AppInheritedWidget.of(context);
    if (appState != null) {
      appState.telemetryData.removeListener(_onTelemetryDataReceived);
      appState.configData.removeListener(_onConfigDataReceived);
    }
    super.dispose();
  }

  void _onConfigDataReceived() {
    final appState = AppInheritedWidget.of(context);
    if (appState == null) return;

    final config = appState.configData.value;
    if (config != null) {
      setState(() {
        lineKPid = config.lineKPid;
        leftKPid = config.leftKPid;
        rightKPid = config.rightKPid;
      });
    }
  }

  void _onTelemetryDataReceived() {
    if (!isCollectingData || !mounted) return;

    final appState = AppInheritedWidget.of(context);
    if (appState == null) return;

    final telemetry = appState.telemetryData.value;
    if (telemetry == null) return;

    final timestamp = DateTime.now().millisecondsSinceEpoch / 1000.0; // seconds

    // Add timestamp
    timestamps.add(timestamp);
    if (timestamps.length > maxDataPoints) {
      timestamps.removeAt(0);
    }

    // Line following data
    if (telemetry.line != null && telemetry.line!.length >= 5) {
      final lineData = telemetry.line!;
      linePositions.add(lineData[0]);
      lineErrors.add(lineData[1]);
      lineIntegrals.add(lineData[2]);
      lineDerivatives.add(lineData[3]);

      // Compute PID output
      double pidOutput = 0.0;
      if (lineKPid != null && lineKPid!.length >= 3) {
        final kp = lineKPid![0];
        final ki = lineKPid![1];
        final kd = lineKPid![2];
        pidOutput = kp * lineData[1] + ki * lineData[2] + kd * lineData[3];
      }
      linePidOutputs.add(pidOutput);
    } else {
      linePositions.add(0.0);
      lineErrors.add(0.0);
      lineIntegrals.add(0.0);
      lineDerivatives.add(0.0);
      linePidOutputs.add(0.0);
    }

    // Left motor data
    if (telemetry.left != null && telemetry.left!.length >= 8) {
      final leftData = telemetry.left!;
      leftMotorRpms.add(leftData[0]);
      leftMotorTargetRpms.add(leftData[1]);
      leftMotorPwms.add(leftData[2]);
      leftMotorErrors.add(leftData[7]);
      leftMotorIntegrals.add(leftData[5]);
      leftMotorDerivatives.add(leftData[6]);

      // Compute PID output
      double pidOutput = 0.0;
      if (leftKPid != null && leftKPid!.length >= 3) {
        final kp = leftKPid![0];
        final ki = leftKPid![1];
        final kd = leftKPid![2];
        pidOutput = kp * leftData[7] + ki * leftData[5] + kd * leftData[6];
      }
      leftMotorPidOutputs.add(pidOutput);
    } else {
      leftMotorRpms.add(0.0);
      leftMotorTargetRpms.add(0.0);
      leftMotorPwms.add(0.0);
      leftMotorErrors.add(0.0);
      leftMotorIntegrals.add(0.0);
      leftMotorDerivatives.add(0.0);
      leftMotorPidOutputs.add(0.0);
    }

    // Right motor data
    if (telemetry.right != null && telemetry.right!.length >= 8) {
      final rightData = telemetry.right!;
      rightMotorRpms.add(rightData[0]);
      rightMotorTargetRpms.add(rightData[1]);
      rightMotorPwms.add(rightData[2]);
      rightMotorErrors.add(rightData[7]);
      rightMotorIntegrals.add(rightData[5]);
      rightMotorDerivatives.add(rightData[6]);

      // Compute PID output
      double pidOutput = 0.0;
      if (rightKPid != null && rightKPid!.length >= 3) {
        final kp = rightKPid![0];
        final ki = rightKPid![1];
        final kd = rightKPid![2];
        pidOutput = kp * rightData[7] + ki * rightData[5] + kd * rightData[6];
      }
      rightMotorPidOutputs.add(pidOutput);
    } else {
      rightMotorRpms.add(0.0);
      rightMotorTargetRpms.add(0.0);
      rightMotorPwms.add(0.0);
      rightMotorErrors.add(0.0);
      rightMotorIntegrals.add(0.0);
      rightMotorDerivatives.add(0.0);
      rightMotorPidOutputs.add(0.0);
    }

    // Trim all lists to maxDataPoints
    _trimLists();

    if (mounted) {
      setState(() {});
    }
  }

  void _trimLists() {
    final lists = [
      lineErrors, linePositions, lineIntegrals, lineDerivatives, linePidOutputs,
      leftMotorRpms, leftMotorTargetRpms, leftMotorPwms, leftMotorErrors,
      leftMotorIntegrals, leftMotorDerivatives, leftMotorPidOutputs,
      rightMotorRpms, rightMotorTargetRpms, rightMotorPwms, rightMotorErrors,
      rightMotorIntegrals, rightMotorDerivatives, rightMotorPidOutputs
    ];

    for (final list in lists) {
      if (list.length > maxDataPoints) {
        list.removeAt(0);
      }
    }
  }

  void _clearData() {
    timestamps.clear();
    lineErrors.clear();
    linePositions.clear();
    lineIntegrals.clear();
    lineDerivatives.clear();
    linePidOutputs.clear();
    leftMotorRpms.clear();
    leftMotorTargetRpms.clear();
    leftMotorPwms.clear();
    leftMotorErrors.clear();
    leftMotorIntegrals.clear();
    leftMotorDerivatives.clear();
    leftMotorPidOutputs.clear();
    rightMotorRpms.clear();
    rightMotorTargetRpms.clear();
    rightMotorPwms.clear();
    rightMotorErrors.clear();
    rightMotorIntegrals.clear();
    rightMotorDerivatives.clear();
    rightMotorPidOutputs.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: 'Gráficos',
              hasBackButton: true,
              actions: [
                IconButton(
                  icon: Icon(isCollectingData ? Icons.pause : Icons.play_arrow),
                  onPressed: () {
                    setState(() {
                      isCollectingData = !isCollectingData;
                    });
                  },
                  tooltip: isCollectingData ? 'Pausar recolección' : 'Reanudar recolección',
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _clearData,
                  tooltip: 'Limpiar datos',
                ),
              ],
            ),
            Expanded(
              child: DefaultTabController(
                length: 3,
                child: Column(
                  children: [
                    const TabBar(
                      tabs: [
                        Tab(text: 'Línea'),
                        Tab(text: 'Motor Izq'),
                        Tab(text: 'Motor Der'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _buildLineGraphs(),
                          _buildLeftMotorGraphs(),
                          _buildRightMotorGraphs(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineGraphs() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGraphCard(
            'Posición',
            _createLineChart(linePositions, timestamps, Colors.blue),
          ),
          const SizedBox(height: 16),
          _buildGraphCard(
            'Error',
            _createLineChart(lineErrors, timestamps, Colors.red),
          ),
          const SizedBox(height: 16),
          _buildGraphCard(
            'Resultado PID',
            _createLineChart(linePidOutputs, timestamps, Colors.teal),
          ),
          const SizedBox(height: 16),
          _buildGraphCard(
            'Componentes PID',
            _createMultiLineChart(
              [lineErrors, lineIntegrals, lineDerivatives],
              timestamps,
              ['Error', 'Integral', 'Derivativo'],
              [Colors.red, Colors.green, Colors.purple],
            ),
            labels: ['Error', 'Integral', 'Derivativo'],
            colors: [Colors.red, Colors.green, Colors.purple],
          ),
        ],
      ),
    );
  }

  Widget _buildLeftMotorGraphs() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGraphCard(
            'RPM',
            _createMultiLineChart(
              [leftMotorRpms, leftMotorTargetRpms],
              timestamps,
              ['Actual', 'Objetivo'],
              [Colors.blue, Colors.green],
            ),
            labels: ['Actual', 'Objetivo'],
            colors: [Colors.blue, Colors.green],
          ),
          const SizedBox(height: 16),
          _buildGraphCard(
            'PWM',
            _createLineChart(leftMotorPwms, timestamps, Colors.orange),
          ),
          const SizedBox(height: 16),
          _buildGraphCard(
            'Resultado PID',
            _createLineChart(leftMotorPidOutputs, timestamps, Colors.teal),
          ),
          const SizedBox(height: 16),
          _buildGraphCard(
            'Componentes PID',
            _createMultiLineChart(
              [leftMotorIntegrals, leftMotorDerivatives],
              timestamps,
              ['Integral', 'Derivativo'],
              [Colors.green, Colors.purple],
            ),
            labels: ['Integral', 'Derivativo'],
            colors: [Colors.green, Colors.purple],
          ),
        ],
      ),
    );
  }

  Widget _buildRightMotorGraphs() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGraphCard(
            'RPM',
            _createMultiLineChart(
              [rightMotorRpms, rightMotorTargetRpms],
              timestamps,
              ['Actual', 'Objetivo'],
              [Colors.blue, Colors.green],
            ),
            labels: ['Actual', 'Objetivo'],
            colors: [Colors.blue, Colors.green],
          ),
          const SizedBox(height: 16),
          _buildGraphCard(
            'PWM',
            _createLineChart(rightMotorPwms, timestamps, Colors.orange),
          ),
          const SizedBox(height: 16),
          _buildGraphCard(
            'Resultado PID',
            _createLineChart(rightMotorPidOutputs, timestamps, Colors.teal),
          ),
          const SizedBox(height: 16),
          _buildGraphCard(
            'Componentes PID',
            _createMultiLineChart(
              [rightMotorIntegrals, rightMotorDerivatives],
              timestamps,
              ['Integral', 'Derivativo'],
              [Colors.green, Colors.purple],
            ),
            labels: ['Integral', 'Derivativo'],
            colors: [Colors.green, Colors.purple],
          ),
        ],
      ),
    );
  }

  Widget _buildGraphCard(String title, Widget chart, {List<String>? labels, List<Color>? colors}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: chart,
            ),
            if (labels != null && colors != null && labels.length == colors.length)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(labels.length, (index) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          color: colors[index],
                        ),
                        const SizedBox(width: 4),
                        Text(labels[index], style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                  )),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _createLineChart(List<double> data, List<double> timeData, Color color) {
    if (data.isEmpty || timeData.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    final spots = List.generate(
      data.length,
      (index) => FlSpot(timeData[index], data[index]),
    );

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
        ],
        minY: data.reduce((a, b) => a < b ? a : b) - 10,
        maxY: data.reduce((a, b) => a > b ? a : b) + 10,
      ),
    );
  }

  Widget _createMultiLineChart(
    List<List<double>> dataLists,
    List<double> timeData,
    List<String> labels,
    List<Color> colors,
  ) {
    if (dataLists.isEmpty || timeData.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    final lineBarsData = <LineChartBarData>[];
    double minY = double.infinity;
    double maxY = double.negativeInfinity;

    for (int i = 0; i < dataLists.length; i++) {
      final data = dataLists[i];
      if (data.isEmpty) continue;

      final spots = List.generate(
        data.length,
        (index) => FlSpot(timeData[index], data[index]),
      );

      lineBarsData.add(
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: colors[i],
          barWidth: 2,
          dotData: const FlDotData(show: false),
        ),
      );

      // Update min/max Y
      final dataMin = data.reduce((a, b) => a < b ? a : b);
      final dataMax = data.reduce((a, b) => a > b ? a : b);
      minY = minY < dataMin ? minY : dataMin;
      maxY = maxY > dataMax ? maxY : dataMax;
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: lineBarsData,
        minY: minY - 10,
        maxY: maxY + 10,
      ),
    );
  }
}
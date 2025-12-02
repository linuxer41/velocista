import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../app_state.dart';

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  final int maxDataPoints = 100; // Keep last 100 data points for performance

  // Historical data storage
  final List<double> timestamps = [];
  final List<double> lineErrors = [];
  final List<double> linePositions = [];
  final List<double> lineIntegrals = [];
  final List<double> lineDerivatives = [];
  final List<double> leftMotorRpms = [];
  final List<double> leftMotorTargetRpms = [];
  final List<double> leftMotorPwms = [];
  final List<double> leftMotorErrors = [];
  final List<double> leftMotorIntegrals = [];
  final List<double> leftMotorDerivatives = [];
  final List<double> rightMotorRpms = [];
  final List<double> rightMotorTargetRpms = [];
  final List<double> rightMotorPwms = [];
  final List<double> rightMotorErrors = [];
  final List<double> rightMotorIntegrals = [];
  final List<double> rightMotorDerivatives = [];

  bool isCollectingData = true;

  @override
  void initState() {
    super.initState();
    // Setup listener after the widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = AppInheritedWidget.of(context);
      if (appState != null) {
        appState.telemetryData.addListener(_onTelemetryDataReceived);
      }
    });
  }

  @override
  void dispose() {
    final appState = AppInheritedWidget.of(context);
    if (appState != null) {
      appState.telemetryData.removeListener(_onTelemetryDataReceived);
    }
    super.dispose();
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
    } else {
      linePositions.add(0.0);
      lineErrors.add(0.0);
      lineIntegrals.add(0.0);
      lineDerivatives.add(0.0);
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
    } else {
      leftMotorRpms.add(0.0);
      leftMotorTargetRpms.add(0.0);
      leftMotorPwms.add(0.0);
      leftMotorErrors.add(0.0);
      leftMotorIntegrals.add(0.0);
      leftMotorDerivatives.add(0.0);
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
    } else {
      rightMotorRpms.add(0.0);
      rightMotorTargetRpms.add(0.0);
      rightMotorPwms.add(0.0);
      rightMotorErrors.add(0.0);
      rightMotorIntegrals.add(0.0);
      rightMotorDerivatives.add(0.0);
    }

    // Trim all lists to maxDataPoints
    _trimLists();

    if (mounted) {
      setState(() {});
    }
  }

  void _trimLists() {
    final lists = [
      lineErrors, linePositions, lineIntegrals, lineDerivatives,
      leftMotorRpms, leftMotorTargetRpms, leftMotorPwms, leftMotorErrors,
      leftMotorIntegrals, leftMotorDerivatives,
      rightMotorRpms, rightMotorTargetRpms, rightMotorPwms, rightMotorErrors,
      rightMotorIntegrals, rightMotorDerivatives
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
    leftMotorRpms.clear();
    leftMotorTargetRpms.clear();
    leftMotorPwms.clear();
    leftMotorErrors.clear();
    leftMotorIntegrals.clear();
    leftMotorDerivatives.clear();
    rightMotorRpms.clear();
    rightMotorTargetRpms.clear();
    rightMotorPwms.clear();
    rightMotorErrors.clear();
    rightMotorIntegrals.clear();
    rightMotorDerivatives.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gráficos de Debug'),
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
            icon: const Icon(Icons.clear),
            onPressed: _clearData,
            tooltip: 'Limpiar datos',
          ),
        ],
      ),
      body: DefaultTabController(
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
    );
  }

  Widget _buildLineGraphs() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildGraphCard(
            'Error de Línea',
            _createLineChart(lineErrors, timestamps, Colors.red),
          ),
          const SizedBox(height: 16),
          _buildGraphCard(
            'Posición de Línea',
            _createLineChart(linePositions, timestamps, Colors.blue),
          ),
          const SizedBox(height: 16),
          _buildGraphCard(
            'Componentes PID - Línea',
            _createMultiLineChart(
              [lineErrors, lineIntegrals, lineDerivatives],
              timestamps,
              ['Error', 'Integral', 'Derivativo'],
              [Colors.red, Colors.green, Colors.purple],
            ),
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
            'RPM Motor Izquierdo',
            _createMultiLineChart(
              [leftMotorRpms, leftMotorTargetRpms],
              timestamps,
              ['Actual', 'Objetivo'],
              [Colors.blue, Colors.green],
            ),
          ),
          const SizedBox(height: 16),
          _buildGraphCard(
            'PWM Motor Izquierdo',
            _createLineChart(leftMotorPwms, timestamps, Colors.orange),
          ),
          const SizedBox(height: 16),
          _buildGraphCard(
            'Error Motor Izquierdo',
            _createLineChart(leftMotorErrors, timestamps, Colors.red),
          ),
          const SizedBox(height: 16),
          _buildGraphCard(
            'Componentes PID - Motor Izq',
            _createMultiLineChart(
              [leftMotorErrors, leftMotorIntegrals, leftMotorDerivatives],
              timestamps,
              ['Error', 'Integral', 'Derivativo'],
              [Colors.red, Colors.green, Colors.purple],
            ),
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
            'RPM Motor Derecho',
            _createMultiLineChart(
              [rightMotorRpms, rightMotorTargetRpms],
              timestamps,
              ['Actual', 'Objetivo'],
              [Colors.blue, Colors.green],
            ),
          ),
          const SizedBox(height: 16),
          _buildGraphCard(
            'PWM Motor Derecho',
            _createLineChart(rightMotorPwms, timestamps, Colors.orange),
          ),
          const SizedBox(height: 16),
          _buildGraphCard(
            'Error Motor Derecho',
            _createLineChart(rightMotorErrors, timestamps, Colors.red),
          ),
          const SizedBox(height: 16),
          _buildGraphCard(
            'Componentes PID - Motor Der',
            _createMultiLineChart(
              [rightMotorErrors, rightMotorIntegrals, rightMotorDerivatives],
              timestamps,
              ['Error', 'Integral', 'Derivativo'],
              [Colors.red, Colors.green, Colors.purple],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphCard(String title, Widget chart) {
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
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
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
            isCurved: false,
            color: color,
            barWidth: 2,
            dotData: FlDotData(show: false),
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
          isCurved: false,
          color: colors[i],
          barWidth: 2,
          dotData: FlDotData(show: false),
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
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
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
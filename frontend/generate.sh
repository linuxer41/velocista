#!/bin/bash

# Crear la estructura de carpetas
mkdir -p lib
mkdir -p lib/src

# Crear los archivos con el código proporcionado

# main.dart
cat <<EOF > lib/main.dart
import 'package:flutter/material.dart';
import 'home_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: HomeScreen(),
    );
  }
}
EOF

# home_screen.dart
cat <<EOF > lib/home_screen.dart
import 'package:flutter/material.dart';
import 'lab_screen.dart';

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Lab Sensors'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Lab 1'),
              Tab(text: 'Lab 2'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            LabScreen(labGroup: 'labgroup1'),
            LabScreen(labGroup: 'labgroup2'),
          ],
        ),
      ),
    );
  }
}
EOF

# lab_screen.dart
cat <<EOF > lib/lab_screen.dart
import 'package:flutter/material.dart';
import 'sensor_chart.dart';
import 'tcp_client.dart';

class LabScreen extends StatefulWidget {
  final String labGroup;

  LabScreen({required this.labGroup});

  @override
  _LabScreenState createState() => _LabScreenState();
}

class _LabScreenState extends State<LabScreen> {
  late TcpClient _tcpClient;
  List<double> _sensor1Data = [];
  List<double> _sensor2Data = [];
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _tcpClient = TcpClient(widget.labGroup, _onDataReceived);
    _tcpClient.connect();
  }

  void _onDataReceived(String data) {
    if (_isPaused) return;

    setState(() {
      if (data.startsWith('sensor1:')) {
        _sensor1Data.add(double.parse(data.split(',')[1].trim()));
      } else if (data.startsWith('sensor2:')) {
        _sensor2Data.add(double.parse(data.split(',')[1].trim()));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SensorChart(data: _sensor1Data),
        ),
        Expanded(
          child: SensorChart(data: _sensor2Data),
        ),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _isPaused = !_isPaused;
            });
          },
          child: Text(_isPaused ? 'Resume' : 'Pause'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _tcpClient.disconnect();
    super.dispose();
  }
}
EOF

# sensor_chart.dart
cat <<EOF > lib/sensor_chart.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class SensorChart extends StatelessWidget {
  final List<double> data;

  SensorChart({required this.data});

  @override
  Widget build(BuildContext context) {
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: data.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value);
            }).toList(),
            isCurved: true,
            colors: [Colors.blue],
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: false,
            ),
            belowBarData: BarAreaData(
              show: false,
            ),
          ),
        ],
        minX: 0,
        maxX: data.length.toDouble() - 1,
        minY: data.reduce(min),
        maxY: data.reduce(max),
        titlesData: FlTitlesData(
          show: false,
        ),
        borderData: FlBorderData(
          show: false,
        ),
      ),
    );
  }
}
EOF

# tcp_client.dart
cat <<EOF > lib/tcp_client.dart
import 'package:socket_io_client/socket_io_client.dart' as IO;

class TcpClient {
  final String labGroup;
  final Function(String) onDataReceived;
  late IO.Socket _socket;

  TcpClient(this.labGroup, this.onDataReceived);

  void connect() {
    _socket = IO.io('http://your_server_ip:80', <String, dynamic>{
      'transports': ['websocket'],
    });

    _socket.on('connect', (_) {
      print('Connected to server');
    });

    _socket.on('data', (data) {
      onDataReceived(data);
    });

    _socket.on('disconnect', (_) {
      print('Disconnected from server');
    });
  }

  void disconnect() {
    _socket.disconnect();
  }
}
EOF



echo "Archivos generados exitosamente."
import 'package:flutter/material.dart';
import 'line_follower_state.dart';
import 'arduino_data.dart';
import 'main.dart';
import 'theme_provider.dart';
import 'widgets/connection_card.dart';
import 'widgets/status_card.dart';
import 'widgets/sensor_card.dart';
import 'widgets/motor_control_card.dart';
import 'widgets/statistics_card.dart';
import 'widgets/pid_config_tab.dart';
import 'widgets/terminal_tab.dart';
import 'widgets/custom_floating_action_button.dart';
import 'widgets/pid_config_dialog.dart';
import 'widgets/remote_control_widget.dart';
import 'connection_bottom_sheet.dart';

class LineFollowerHome extends StatefulWidget {
  final ThemeProvider themeProvider;

  const LineFollowerHome({
    super.key, 
    required this.themeProvider,
  });

  @override
  State<LineFollowerHome> createState() => _LineFollowerHomeState();
}

class _LineFollowerHomeState extends State<LineFollowerHome> {
  int _currentTabIndex = 0; // Start with Dashboard (index 0)

  @override
  void initState() {
    super.initState();
    // Auto-start discovery when app launches
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = LineFollowerInheritedWidget.of(context);
      if (provider != null && !provider.isConnected.value) {
        provider.startDiscovery();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = LineFollowerInheritedWidget.of(context);
    if (provider == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Error: LineFollowerState not found',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildBody(provider)),
          ],
        ),
      ),
      floatingActionButton: CustomFloatingActionButton(
        provider: provider,
        themeProvider: widget.themeProvider,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) => setState(() => _currentTabIndex = index),
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: 'Dashboard'),
          BottomNavigationBarItem(
              icon: Icon(Icons.terminal), label: 'Terminal'),
        ],
      ),
    );
  }

  Widget _buildBody(LineFollowerState provider) {
    switch (_currentTabIndex) {
      case 0:
        return _buildDashboardTab(provider);
      case 1:
        return TerminalTab(provider: provider);
      default:
        return Center(
          child: Text(
            'Unknown tab',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        );
    }
  }

  Widget _buildDashboardTab(LineFollowerState provider) {
    return RepaintBoundary(
      child: Column(
        children: [
          // Sticky Connection Card
          ConnectionCard(
            provider: provider,
            onShowConnectionDialog: _showConnectionDialog,
          ),
          const SizedBox(height: 16),
          
          // Content area - conditionally scrollable with proper state listening
          Expanded(
            child: ValueListenableBuilder<bool>(
              valueListenable: provider.isConnected,
              builder: (context, isConnected, child) {
                return isConnected
                    ? _buildConnectedContent(provider)
                    : _buildDisconnectedContent(provider);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectedContent(LineFollowerState provider) {
    return ValueListenableBuilder<ArduinoData?>(
      valueListenable: provider.currentData,
      builder: (context, data, child) {
        // Show remote control interface for autopilot mode
        if (data != null && data.isAutopilotMode) {
          return RemoteControlWidget(provider: provider);
        }
        
        // Show regular dashboard for other modes
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StatusCard(provider: provider),
              const SizedBox(height: 16),
              
              // PID Configuration Button
              if (data != null && data.isLineFollowingMode)
                _buildPIDControlButton(provider),
              const SizedBox(height: 16),
              
              SensorCard(provider: provider),
              const SizedBox(height: 16),
              
              MotorControlCard(provider: provider),
              const SizedBox(height: 16),
              
              StatisticsCard(provider: provider),
              const SizedBox(height: 32), // Extra space at bottom
            ],
          ),
        );
      },
    );
  }

  Widget _buildDisconnectedContent(LineFollowerState provider) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.info_outline,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          'Conecta tu dispositivo para ver los datos',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Los datos de sensores, motores y estadísticas aparecerán aquí una vez que te conectes al Arduino.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _showConnectionDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ConnectionBottomSheet(),
    );
  }

  Widget _buildPIDControlButton(LineFollowerState provider) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => _showPIDConfigDialog(provider),
        icon: const Icon(Icons.tune, size: 20),
        label: const Text('Configuración PID'),
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  void _showPIDConfigDialog(LineFollowerState provider) {
    showDialog(
      context: context,
      builder: (context) {
        return PIDConfigDialog(provider: provider);
      },
    );
  }
}
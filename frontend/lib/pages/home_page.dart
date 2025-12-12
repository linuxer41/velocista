import 'package:flutter/material.dart';
import 'package:labusfx/widgets/navigation_menu.dart';
import '../app_state.dart';
import '../arduino_data.dart';
import '../connection_bottom_sheet.dart';
import '../widgets/remote_control.dart';
import '../widgets/status_bar.dart';
import '../widgets/idle_controls.dart';
import '../widgets/pid_tabs.dart';
import '../widgets/gauges_section.dart';
import '../widgets/motor_info_section.dart';
import 'terminal_page.dart';
import 'graphs_page.dart';
import 'app_settings_page.dart';


class HomePage extends StatefulWidget {
  final ThemeProvider themeProvider;

  const HomePage({super.key, required this.themeProvider});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late TextEditingController _baseSpeedController;
  late TextEditingController _baseRpmController;
  late TextEditingController _maxSpeedController;

  @override
  void initState() {
    super.initState();

    // Initialize controllers
    _baseSpeedController = TextEditingController(text: '200');
    _baseRpmController = TextEditingController(text: '120.0');
    _maxSpeedController = TextEditingController(text: '230');

    // Show connection modal automatically if not connected
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = AppInheritedWidget.of(context);
      if (appState != null) {
        appState.isConnected.addListener(_onConnectionChanged);
        appState.lastAck.addListener(_onAckReceived);
        appState.configData.addListener(_updateControllersFromConfig);
        _checkConnectionAndShowModal();
      }
    });
  }

  @override
  void dispose() {
    final appState = AppInheritedWidget.of(context);
    if (appState != null) {
      appState.isConnected.removeListener(_onConnectionChanged);
      appState.lastAck.removeListener(_onAckReceived);
      appState.configData.removeListener(_updateControllersFromConfig);
    }
    _baseSpeedController.dispose();
    _baseRpmController.dispose();
    _maxSpeedController.dispose();
    super.dispose();
  }

  void _onAckReceived() {
    final appState = AppInheritedWidget.of(context);
    if (appState != null && appState.lastAck.value != null) {
      // Only show snackbar for commands that start with "set"
      if (appState.lastAck.value!.startsWith('set')) {
        // Build enhanced acknowledgment message
        String ackMessage = appState.lastAck.value!;

        // Add features status if available
        if (appState.configData.value?.featConfig != null &&
            appState.configData.value!.featConfig!.length >= 9) {
          final featConfig = appState.configData.value!.featConfig!;
          final features =
              'FEAT_CONFIG:[${featConfig.sublist(0, 9).join(',')}]';
          ackMessage += '|$features';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Guardado: $ackMessage'),
            duration: const Duration(
                seconds: 3), // Extended duration for longer message
          ),
        );
      }
      // Reset to avoid repeated snackbars
      appState.lastAck.value = null;
    }
  }

  void _updateControllersFromConfig() {
    final appState = AppInheritedWidget.of(context);
    if (appState != null) {
      final config = appState.configData.value;
      if (config != null) {
        // Update base speed controllers
        if (config.base != null) {
          if (config.base!.isNotEmpty) {
            _baseSpeedController.text = config.base![0].toStringAsFixed(0);
          }
          if (config.base!.length >= 2) {
            _baseRpmController.text = config.base![1].toStringAsFixed(1);
          }
        }
        // Update max speed controllers
        if (config.max != null) {
          if (config.max!.isNotEmpty) {
            _maxSpeedController.text = config.max![0].toStringAsFixed(0);
          }
        }

      }
    }
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
      builder: (context) => ConnectionBottomSheet(
        onShowMessage: (message, {Color? backgroundColor, Duration? duration}) {
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: backgroundColor ?? Colors.blue,
              duration: duration ?? const Duration(seconds: 3),
            ),
          );
        },
      ),
    );
  }




  Widget _getControlsWidget(OperationMode mode) {
    final appState = AppInheritedWidget.of(context);
    if (appState == null) return const SizedBox.shrink();

    switch (mode) {
      case OperationMode.idle:
        return IdleControls(appState: appState);
      case OperationMode.lineFollowing:
        return PidTabs(appState: appState);
      case OperationMode.remoteControl:
        return RemoteControl(appState: appState);
    }
  }
  @override
  Widget build(BuildContext context) {
    final appState = AppInheritedWidget.of(context)!;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: StatusBar(
        appState: appState,
        onShowConnectionModal: _showConnectionModal,
      ),
      body: ValueListenableBuilder<OperationMode>(
        valueListenable: appState!.currentMode,
        builder: (context, mode, child) {
          return Stack(
            children: [
              SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      // Gauges
                      GaugesSection(appState: appState),

                      // Motor and Line Following Information
                      MotorInfoSection(appState: appState),

                      const SizedBox(height: 8),

                      // Dynamic controls based on selected mode
                      _getControlsWidget(mode),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: NavigationMenu(menuItems: [
                  {
                    'label': 'Terminal',
                    'icon': Icons.code,
                    'page': TerminalPage(provider: appState,),
                  },
                  {
                    'label': 'Configuración',
                    'icon': Icons.settings,
                    'page': const ConfigPage(),
                  },
                  {
                    'label': 'Gráficos',
                    'icon': Icons.bar_chart,
                    'page': const GraphsPage(),
                  },
                  {
                    'label': 'Info',
                    'icon': Icons.help,
                    'page': AppSettingsPage(themeProvider: widget.themeProvider,),
                  },
                ], onOpenPage: (page) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => page),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
  
}

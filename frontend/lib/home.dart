import 'package:flutter/material.dart';
import 'app_state.dart';
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

class Home extends StatefulWidget {
  final ThemeProvider themeProvider;

  const Home({
    super.key,
    required this.themeProvider,
  });

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  int _currentTabIndex = 0; // Start with Dashboard (index 0)

  @override
  void initState() {
    super.initState();
    // Auto-start discovery when app launches
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = AppInheritedWidget.of(context);
      if (provider != null && !provider.isConnected.value) {
        provider.startDiscovery();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = AppInheritedWidget.of(context);
    if (provider == null) {
      return Scaffold(
        body: Center(
          child: Text(
            'Error: appState not found',
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

  Widget _buildBody(AppState provider) {
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

  Widget _buildDashboardTab(AppState provider) {
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

  Widget _buildConnectedContent(AppState provider) {
    return ValueListenableBuilder<ArduinoData?>(
      valueListenable: provider.currentData,
      builder: (context, data, child) {
        // Show different interfaces based on operation mode
        if (data != null) {
          if (data.isAutopilotMode) {
            return RemoteControlWidget(provider: provider);
          } else if (data.isServoDistanceMode) {
            return _buildServoDistanceInterface(provider);
          } else if (data.isPointListMode) {
            return _buildPointListInterface(provider);
          } else if (data.isManualMode) {
            return _buildManualControlInterface(provider);
          }
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

              // Mode-specific controls
              if (data != null && data.isLineFollowingMode)
                _buildPIDControlButton(provider),
              if (data != null && data.isAutopilotMode)
                _buildAutopilotQuickControls(provider),
              if (data != null && data.isManualMode)
                _buildManualQuickControls(provider),
              if (data != null && data.isServoDistanceMode)
                _buildServoDistanceQuickControls(provider),
              if (data != null && data.isPointListMode)
                _buildPointListQuickControls(provider),
              const SizedBox(height: 16),

              // Speed Base Configuration
              _buildSpeedBaseControl(provider),
              const SizedBox(height: 16),

              // EEPROM Save Button
              _buildEepromControl(provider),
              const SizedBox(height: 16),

              // Telemetry Controls
              _buildTelemetryControls(provider),
              const SizedBox(height: 16),

              // QTR Calibration Button
              _buildQtrCalibrationControl(provider),
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

  Widget _buildDisconnectedContent(AppState provider) {
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

  Widget _buildPIDControlButton(AppState provider) {
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

  void _showPIDConfigDialog(AppState provider) {
    showDialog(
      context: context,
      builder: (context) {
        return PIDConfigDialog(provider: provider);
      },
    );
  }

  Widget _buildServoDistanceInterface(AppState provider) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Text(
              'Modo Servo Distance',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'El robot avanzará la distancia especificada\ny regresará automáticamente al punto de origen',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            _buildDistanceButtons(provider),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildDistanceButtons(AppState provider) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      alignment: WrapAlignment.center,
      children: [
        _buildDistanceButton('10 cm', 10, provider),
        _buildDistanceButton('25 cm', 25, provider),
        _buildDistanceButton('50 cm', 50, provider),
        _buildDistanceButton('100 cm', 100, provider),
      ],
    );
  }

  Widget _buildDistanceButton(
      String label, double distance, AppState provider) {
    return ElevatedButton.icon(
      onPressed: () => provider.sendServoDistance(distance),
      icon: const Icon(Icons.straighten),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildPointListInterface(AppState provider) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Text(
              'Modo Point List',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'El robot recorrerá la secuencia de distancias y giros especificada',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Formato: distancia1,giro1,distancia2,giro2,...',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            _buildRouteButtons(provider),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteButtons(AppState provider) {
    return Column(
      children: [
        Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          children: [
            _buildRouteButton('Cuadrado', '20,90,20,90,20,90,20,90', provider),
            _buildRouteButton('Triángulo', '30,120,30,120,30,120', provider),
            _buildRouteButton(
                'Rectángulo', '40,90,20,90,40,90,20,90', provider),
          ],
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => _showCustomRouteDialog(provider),
          icon: const Icon(Icons.edit),
          label: const Text('Ruta Personalizada'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRouteButton(
      String label, String routePoints, AppState provider) {
    return ElevatedButton(
      onPressed: () => provider.sendRoutePoints(routePoints),
      child: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  void _showCustomRouteDialog(AppState provider) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Ruta Personalizada'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                  'Formato: dist1,giro1,dist2,giro2,...\nEjemplo: 20,90,10,-90,20,0'),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                decoration: const InputDecoration(
                  hintText: '20,90,20,90,20,90,20,90',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.isNotEmpty) {
                  provider.sendRoutePoints(controller.text);
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Enviar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildManualControlInterface(AppState provider) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Text(
              'Modo Manual',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Control directo de cada rueda del robot',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const Spacer(),
            _buildManualControlSliders(provider),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildManualControlSliders(AppState provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        children: [
          // Left wheel control
          _buildWheelControl(
            label: 'Rueda Izquierda',
            icon: Icons.arrow_back,
            onChanged: (value) =>
                _sendManualCommand(leftSpeed: value, rightSpeed: null),
          ),
          const SizedBox(height: 32),
          // Right wheel control
          _buildWheelControl(
            label: 'Rueda Derecha',
            icon: Icons.arrow_forward,
            onChanged: (value) =>
                _sendManualCommand(leftSpeed: null, rightSpeed: value),
          ),
          const SizedBox(height: 32),
          // Quick action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: () =>
                    _sendManualCommand(leftSpeed: 0, rightSpeed: 0),
                icon: const Icon(Icons.stop),
                label: const Text('Parar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () =>
                    _sendManualCommand(leftSpeed: 0.5, rightSpeed: 0.5),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Adelante'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWheelControl({
    required String label,
    required IconData icon,
    required Function(double) onChanged,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
          child: Slider(
            value: 0.0,
            min: -1.0,
            max: 1.0,
            divisions: 20,
            label: '0.0',
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Arrastrar para controlar velocidad',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  void _sendManualCommand({double? leftSpeed, double? rightSpeed}) {
    final provider = AppInheritedWidget.of(context);
    if (provider != null) {
      provider.sendCommand({
        'mode': OperationMode.manual.id,
        if (leftSpeed != null) 'leftSpeed': leftSpeed,
        if (rightSpeed != null) 'rightSpeed': rightSpeed,
      });
    }
  }

  Widget _buildAutopilotQuickControls(AppState provider) {
    return Container(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Controles Rápidos - Autopilot',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => provider.sendCommand({
                        'autopilot': {'throttle': 0.5, 'turn': 0}
                      }),
                      icon: const Icon(Icons.north),
                      label: const Text('Adelante'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => provider.sendCommand({
                        'autopilot': {'throttle': 0, 'turn': 0, 'brake': 1}
                      }),
                      icon: const Icon(Icons.stop),
                      label: const Text('Frenar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualQuickControls(AppState provider) {
    return Container(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Controles Rápidos - Manual',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => provider.sendCommand({
                        'manual': {'left': 0.5, 'right': 0.5}
                      }),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Adelante'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => provider.sendCommand({
                        'manual': {'left': 0, 'right': 0}
                      }),
                      icon: const Icon(Icons.stop),
                      label: const Text('Parar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServoDistanceQuickControls(AppState provider) {
    return Container(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Controles Rápidos - Servo Distance',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => provider.sendServoDistance(25.0),
                      icon: const Icon(Icons.straighten),
                      label: const Text('25cm'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => provider.sendServoDistance(50.0),
                      icon: const Icon(Icons.straighten),
                      label: const Text('50cm'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPointListQuickControls(AppState provider) {
    return Container(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Controles Rápidos - Point List',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () =>
                          provider.sendRoutePoints('20,90,20,90,20,90,20,90'),
                      icon: const Icon(Icons.crop_square),
                      label: const Text('Cuadrado'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showCustomRouteDialog(provider),
                      icon: const Icon(Icons.edit),
                      label: const Text('Personalizado'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedBaseControl(AppState provider) {
    return Container(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Velocidad Base',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Configura la velocidad base del robot (0.0 - 1.0)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: 0.8, // Default value, could be made dynamic
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      label: '0.8',
                      onChanged: (value) {
                        provider.setSpeedBase(value);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '0.8',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEepromControl(AppState provider) {
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => provider.saveToEeprom(),
        icon: const Icon(Icons.save),
        label: const Text('Guardar Configuración en EEPROM'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildTelemetryControls(AppState provider) {
    return Container(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Controles de Telemetría',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => provider.requestTelemetry(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Solicitar Telemetría'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            Theme.of(context).colorScheme.secondary,
                        foregroundColor:
                            Theme.of(context).colorScheme.onSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => provider.setTelemetryEnabled(true),
                      icon: const Icon(Icons.visibility),
                      label: const Text('Habilitar Auto'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => provider.setTelemetryEnabled(false),
                      icon: const Icon(Icons.visibility_off),
                      label: const Text('Deshabilitar Auto'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQtrCalibrationControl(AppState provider) {
    return Container(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () => provider.calibrateQtrSensors(),
        icon: const Icon(Icons.tune),
        label: const Text('Calibrar Sensores QTR'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

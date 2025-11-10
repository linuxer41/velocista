import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';

import '../app_state.dart';
import '../arduino_data.dart';
import '../connection_bottom_sheet.dart';


class HomePage extends StatefulWidget {
  final ThemeProvider themeProvider;
  const HomePage({super.key, required this.themeProvider});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fade = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut));
    _fadeCtrl.forward();

    // Auto-arranque discovery
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startDiscoveryWithLoader();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  /* ----------------------------------------------------------
   *  DISCOVERY CON LOADER (tu lógica original intacta)
   * ---------------------------------------------------------- */
  Future<void> _startDiscoveryWithLoader() async {
    final provider = AppInheritedWidget.of(context);
    if (provider == null || provider.isConnected.value) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _discoveryDialog(),
    );

    try {
      await provider.startDiscovery();
      if (mounted) Navigator.of(context).pop();
      if (mounted && provider.discoveredDevices.value.isNotEmpty) {
        provider.showDeviceList.value = true;
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      if (mounted) _showSnackError(e);
    }
  }

  Widget _discoveryDialog() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return AlertDialog(
      backgroundColor: colorScheme.surfaceContainerHighest,
      title: Text('Buscando dispositivos...',
          style: TextStyle(color: colorScheme.onSurface)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        CircularProgressIndicator(color: colorScheme.primary),
        const SizedBox(height: 16),
        Text('Escaneando Bluetooth emparejado...',
            style: TextStyle(color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: 8),
        Text('Asegúrate de que tu Arduino esté encendido.',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant))
      ]),
    );
  }

  void _showSnackError(Object e) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Error al buscar: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
            label: 'Reintentar', onPressed: _startDiscoveryWithLoader),
      ));

  /* ----------------------------------------------------------
   *  BUILD PRINCIPAL
   * ---------------------------------------------------------- */
  @override
  Widget build(BuildContext context) {
    final provider = AppInheritedWidget.of(context);
    if (provider == null) return _errorBody();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDesktop = Theme.of(context).platform == TargetPlatform.windows ||
        Theme.of(context).platform == TargetPlatform.macOS ||
        Theme.of(context).platform == TargetPlatform.linux;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light
          .copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        body: FadeTransition(
          opacity: _fade,
          child: isDesktop ? _desktopLayout(provider) : _mobileLayout(provider),
        ),
        bottomSheet: ValueListenableBuilder<bool>(
          valueListenable: provider.showDeviceList,
          builder: (_, show, __) {
            if (!show) return const SizedBox();
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const ConnectionBottomSheet(),
              ).then((_) => provider.showDeviceList.value = false);
            });
            return const SizedBox();
          },
        ),
      ),
    );
  }

  /* ==========================================================
    *  LAYOUT ESCRITORIO – 3 COLUMNAS
    * ========================================================== */
   Widget _desktopLayout(AppState p) {
     final theme = Theme.of(context);
     final colorScheme = theme.colorScheme;
     return Row(children: [
       SizedBox(width: 280, child: Column(children: [
             _topBar(p),
             Expanded(child: _leftPanel(p)),
           ])),
       VerticalDivider(width: 1, color: colorScheme.outline.withOpacity(.1)),
       Expanded(child: Column(children: [
             _topBar(p),
             Expanded(child: _centralStage(p)),
           ])),
       VerticalDivider(width: 1, color: colorScheme.outline.withOpacity(.1)),
       SizedBox(width: 300, child: Column(children: [
             _topBar(p),
             Expanded(child: _rightPanel(p)),
           ])),
     ]);
   }

  /* ==========================================================
    *  LAYOUT MÓVIL – DASHBOARD UNIFICADO
    * ========================================================== */
   Widget _mobileLayout(AppState p) => SafeArea(
         child: Container(
           decoration: BoxDecoration(
             gradient: LinearGradient(
               begin: Alignment.topCenter,
               end: Alignment.bottomCenter,
               colors: [
                 Theme.of(context).colorScheme.surface,
                 Theme.of(context).colorScheme.surfaceContainerLowest,
               ],
             ),
           ),
           child: Column(
             children: [
               // Status bar compacto
               _statusBar(p),
               // Dashboard unificado - todo en una sola página
               Expanded(
                 child: Column(
                   children: [
                     // Tachometers siempre visibles
                     Container(
                       padding: const EdgeInsets.all(16),
                       child: ValueListenableBuilder<ArduinoData?>(
                         valueListenable: p.currentData,
                         builder: (_, data, __) => Column(
                           children: [
                             // SPD arriba
                             _compactTachometer('SPD', data?.totalDistance ?? 0, 300),
                             const SizedBox(height: 12),
                             // R y L abajo en 2 columnas
                             Row(
                               children: [
                                 Expanded(child: _compactTachometer('R', data?.rightEncoderSpeed ?? 0, 100)),
                                 const SizedBox(width: 12),
                                 Expanded(child: _compactTachometer('L', data?.leftEncoderSpeed ?? 0, 100)),
                               ],
                             ),
                           ],
                         ),
                       ),
                     ),
                     // Área de control según modo
                     Expanded(
                       child: Container(
                         padding: const EdgeInsets.symmetric(horizontal: 16),
                         child: _centralStage(p),
                       ),
                     ),
                     // Bottom navigation
                     Container(
                       decoration: BoxDecoration(
                         color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.9),
                         border: Border(
                           top: BorderSide(
                             color: Theme.of(context).colorScheme.outline.withOpacity(.2),
                             width: 1,
                           ),
                         ),
                       ),
                       child: SafeArea(
                         top: false,
                         child: _bottomNav(),
                       ),
                     ),
                   ],
                 ),
               ),
             ],
           ),
         ),
       );

  /* ----------------------------------------------------------
   *  WIDGETS COMUNES
   * ---------------------------------------------------------- */
  Widget _topBar(AppState p) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.centerLeft,
      child: Row(children: [
        Icon(Icons.smart_toy, color: colorScheme.primary, size: 32),
        const SizedBox(width: 12),
        Text('Consola Robot',
            style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 22,
                fontWeight: FontWeight.w600)),
        const Spacer(),
        _connectionDot(p),
      ]),
    );
  }

  Widget _connectionDot(AppState p) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: p.isConnected,
      builder: (_, c, __) => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: c ? colorScheme.primary : colorScheme.error,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: (c ? colorScheme.primary : colorScheme.error).withOpacity(.6),
                blurRadius: 10)
          ],
        ),
      ),
    );
  }

  /* ----------------------------------------------------------
   *  PANEL IZQUIERDO
   * ---------------------------------------------------------- */
  Widget _leftPanel(AppState p) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _card(
          title: 'Conexión',
          child: ValueListenableBuilder<bool>(
            valueListenable: p.isConnected,
            builder: (_, c, __) => ListTile(
              leading: Icon(c ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  color: c ? colorScheme.primary : colorScheme.error),
              title: Text(c ? 'Robot vinculado' : 'Sin conexión',
                  style: TextStyle(color: colorScheme.onSurface)),
              subtitle: Text(c ? (p.deviceName ?? '') : 'Toca para vincular',
                  style: TextStyle(color: colorScheme.onSurfaceVariant)),
              onTap: c ? null : _showConnectionDialog,
            ),
          ),
        ),
        const SizedBox(height: 24),
        _card(
          title: 'Modo activo',
          child: ValueListenableBuilder<ArduinoData?>(
            valueListenable: p.currentData,
            builder: (_, d, __) => Text(
              d?.mode.displayName ?? 'Desconectado',
              style: TextStyle(color: colorScheme.primary, fontSize: 18),
            ),
          ),
        ),
      ],
    );
  }

  /* ----------------------------------------------------------
   *  ESCENARIO CENTRAL – INTERFAZ SEGÚN MODO
   * ---------------------------------------------------------- */
  Widget _centralStage(AppState p) =>
      ValueListenableBuilder<bool>(valueListenable: p.isConnected, builder: (_, c, __) {
        if (!c) return _disconnectedPlaceholder();
        return ValueListenableBuilder<ArduinoData?>(
          valueListenable: p.currentData,
          builder: (_, d, __) {
            if (d == null) {
              final theme = Theme.of(context);
              final colorScheme = theme.colorScheme;
              return Center(
                child: CircularProgressIndicator(color: colorScheme.primary));
            }
            if (d.isRemoteControlMode) return _remoteControlPanel(p, d);
            if (d.isLineFollowingMode) return _lineFollowingPanel(p, d);
            if (d.isServoDistanceMode) return _servoPanel(p, d);
            if (d.isPointListMode) return _pointListPanel(p, d);
            return _modeNotActive();
          },
        );
      });

  /* ----------------------------------------------------------
    *  PANEL DERECHO – MÉTRICAS (SIMPLIFICADO)
    * ---------------------------------------------------------- */
   Widget _rightPanel(AppState p) =>
       ValueListenableBuilder<ArduinoData?>(valueListenable: p.currentData, builder: (_, d, __) {
         return ListView(
           padding: const EdgeInsets.all(24),
           children: [
             _card(
               title: 'Estado del Robot',
               child: Column(
                 children: [
                   ListTile(
                     leading: Icon(
                       p.isConnected.value ? Icons.check_circle : Icons.error,
                       color: p.isConnected.value ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.error,
                     ),
                     title: Text(p.isConnected.value ? 'Conectado' : 'Desconectado'),
                     subtitle: Text(p.deviceName ?? 'Sin dispositivo'),
                   ),
                   const Divider(),
                   ListTile(
                     leading: const Icon(Icons.settings),
                     title: const Text('Modo Actual'),
                     subtitle: Text(d?.mode.displayName ?? 'Desconocido'),
                   ),
                 ],
               ),
             ),
           ],
         );
       });

  /* ----------------------------------------------------------
    *  STATUS BAR – COMPACTO COMO TABLERO DE AUTO REAL
    * ---------------------------------------------------------- */
   Widget _statusBar(AppState p) {
     final theme = Theme.of(context);
     final colorScheme = theme.colorScheme;
     return Container(
       height: 140,
       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
       decoration: BoxDecoration(
         color: colorScheme.surfaceContainerHighest.withOpacity(.9),
         border: Border(bottom: BorderSide(color: colorScheme.outline.withOpacity(.3))),
         boxShadow: [
           BoxShadow(
             color: colorScheme.shadow.withOpacity(.1),
             blurRadius: 4,
             offset: const Offset(0, 2),
           ),
         ],
       ),
       child: Column(
         children: [
           // Header compacto
           Row(
             children: [
               // Status indicator
               Container(
                 width: 12,
                 height: 12,
                 decoration: BoxDecoration(
                   color: p.isConnected.value ? colorScheme.primary : colorScheme.error,
                   shape: BoxShape.circle,
                   boxShadow: [
                     BoxShadow(
                       color: (p.isConnected.value ? colorScheme.primary : colorScheme.error).withOpacity(.5),
                       blurRadius: 6,
                     ),
                   ],
                 ),
               ),
               const SizedBox(width: 8),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(
                       p.isConnected.value ? (p.deviceName ?? 'Robot Conectado') : 'Sin Conexión',
                       style: TextStyle(
                         color: colorScheme.onSurface,
                         fontSize: 14,
                         fontWeight: FontWeight.w600,
                       ),
                     ),
                     if (p.isConnected.value)
                       Text(
                         'ID: ${p.connectedDevice.value?.address.toString() ?? p.connectedSerialPort.value ?? 'N/A'}',
                         style: TextStyle(
                           color: colorScheme.onSurfaceVariant,
                           fontSize: 10,
                         ),
                       ),
                   ],
                 ),
               ),
               if (p.isConnected.value)
                 TextButton.icon(
                   onPressed: () => p.disconnect(),
                   icon: Icon(Icons.power_off, size: 16, color: colorScheme.error),
                   label: Text('OFF', style: TextStyle(color: colorScheme.error, fontSize: 12)),
                   style: TextButton.styleFrom(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                     minimumSize: Size.zero,
                   ),
                 )
               else
                 TextButton.icon(
                   onPressed: () => _showConnectionDialog(),
                   icon: Icon(Icons.bluetooth_searching, size: 16, color: colorScheme.primary),
                   label: Text('CONECTAR', style: TextStyle(color: colorScheme.primary, fontSize: 12)),
                   style: TextButton.styleFrom(
                     padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                     minimumSize: Size.zero,
                   ),
                 ),
             ],
           ),
           const SizedBox(height: 8),
           // Tachometers compactos - SIEMPRE VISIBLES
           Column(
             children: [
               // SPD arriba
               _compactTachometer('SPD', p.currentData.value?.totalDistance ?? 0, 300),
               const SizedBox(height: 8),
               // R y L abajo en 2 columnas
               Row(
                 children: [
                   Expanded(child: _compactTachometer('R', p.currentData.value?.rightEncoderSpeed ?? 0, 100)),
                   const SizedBox(width: 8),
                   Expanded(child: _compactTachometer('L', p.currentData.value?.leftEncoderSpeed ?? 0, 100)),
                 ],
               ),
             ],
           ),
         ],
       ),
     );
   }

   Widget _dashboardContent(AppState p) => Container(
         decoration: BoxDecoration(
           gradient: LinearGradient(
             begin: Alignment.topCenter,
             end: Alignment.bottomCenter,
             colors: [
               Theme.of(context).colorScheme.surface,
               Theme.of(context).colorScheme.surfaceContainerLowest,
             ],
           ),
         ),
         child: Column(
           children: [
             Expanded(
               child: Container(
                 padding: const EdgeInsets.symmetric(horizontal: 16),
                 child: _centralStage(p),
               ),
             ),
             // Bottom navigation - más limpio
             Container(
               decoration: BoxDecoration(
                 color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.8),
                 border: Border(
                   top: BorderSide(
                     color: Theme.of(context).colorScheme.outline.withOpacity(.2),
                     width: 1,
                   ),
                 ),
               ),
               child: SafeArea(
                 top: false,
                 child: _bottomNav(),
               ),
             ),
           ],
         ),
       );

  /* ----------------------------------------------------------
    *  NAVEGACIÓN MÓVIL – LIMPIA Y RESPONSIVA
    * ---------------------------------------------------------- */
   Widget _bottomNav() {
     final theme = Theme.of(context);
     final colorScheme = theme.colorScheme;
     return Container(
       height: 60,
       padding: const EdgeInsets.symmetric(horizontal: 16),
       child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
         children: [
           _navItem(Icons.dashboard, 'Dashboard', true), // Always selected on home
           _navItem(Icons.terminal, 'Terminal', false, onPressed: () => Navigator.pushNamed(context, '/terminal')),
           _navItem(Icons.settings, 'Ajustes', false, onPressed: () => Navigator.pushNamed(context, '/settings')),
         ],
       ),
     );
   }

  Widget _navItem(IconData icon, String label, bool isSelected, {VoidCallback? onPressed}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primaryContainer.withOpacity(.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant,
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /* ----------------------------------------------------------
    *  TARJETAS / GAUGES / TACHOMETERS
    * ---------------------------------------------------------- */
   Widget _card({required String title, required Widget child}) {
     final theme = Theme.of(context);
     final colorScheme = theme.colorScheme;
     return Container(
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(
         borderRadius: BorderRadius.circular(16),
         color: colorScheme.surfaceContainerHighest.withOpacity(.3),
         border: Border.all(color: colorScheme.outline.withOpacity(.3)),
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text(title,
               style: TextStyle(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w600)),
           const SizedBox(height: 12),
           child,
         ],
       ),
     );
   }

   Widget _gaugeCard(String label, double value, double max, String unit) =>
       _card(
         title: label,
         child: SizedBox(
           height: 120,
           child: SfRadialGauge(
             axes: [
               RadialAxis(
                 minimum: 0,
                 maximum: max,
                 showLabels: false,
                 showTicks: false,
                 startAngle: 180,
                 endAngle: 0,
                 axisLineStyle: const AxisLineStyle(
                     thickness: 0.1, thicknessUnit: GaugeSizeUnit.factor),
                 pointers: [
                   RangePointer(
                       value: value,
                       width: 0.1,
                       sizeUnit: GaugeSizeUnit.factor,
                       color: Theme.of(context).colorScheme.primary),
                   MarkerPointer(
                       value: value,
                       markerType: MarkerType.circle,
                       color: Theme.of(context).colorScheme.onSurface),
                 ],
               )
             ],
           ),
         ),
       );

   Widget _tachometer(String label, double value, double max, String unit) {
     final theme = Theme.of(context);
     final colorScheme = theme.colorScheme;
     return Container(
       padding: const EdgeInsets.all(8),
       decoration: BoxDecoration(
         borderRadius: BorderRadius.circular(12),
         color: colorScheme.surfaceContainerHighest.withOpacity(.5),
       ),
       child: Column(
         children: [
           Text(
             label,
             style: TextStyle(
               color: colorScheme.onSurface,
               fontSize: 12,
               fontWeight: FontWeight.w500,
             ),
             textAlign: TextAlign.center,
           ),
           const SizedBox(height: 4),
           SizedBox(
             height: 60,
             child: SfRadialGauge(
               axes: [
                 RadialAxis(
                   minimum: 0,
                   maximum: max,
                   showLabels: false,
                   showTicks: false,
                   startAngle: 180,
                   endAngle: 0,
                   axisLineStyle: const AxisLineStyle(
                       thickness: 0.08, thicknessUnit: GaugeSizeUnit.factor),
                   pointers: [
                     RangePointer(
                         value: value,
                         width: 0.08,
                         sizeUnit: GaugeSizeUnit.factor,
                         color: colorScheme.primary),
                     MarkerPointer(
                         value: value,
                         markerType: MarkerType.circle,
                         color: colorScheme.onSurface,
                         markerWidth: 6,
                         markerHeight: 6),
                   ],
                 )
               ],
             ),
           ),
           Text(
             '${value.toStringAsFixed(1)} $unit',
             style: TextStyle(
               color: colorScheme.onSurfaceVariant,
               fontSize: 10,
               fontWeight: FontWeight.w500,
             ),
           ),
         ],
       ),
     );
   }

   Widget _compactTachometer(String label, double value, double max) {
     final theme = Theme.of(context);
     final colorScheme = theme.colorScheme;
     return Container(
       padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
       decoration: BoxDecoration(
         borderRadius: BorderRadius.circular(8),
         color: colorScheme.surfaceContainerHighest.withOpacity(.7),
         border: Border.all(color: colorScheme.outline.withOpacity(.2)),
       ),
       child: Column(
         mainAxisSize: MainAxisSize.min,
         children: [
           Text(
             label,
             style: TextStyle(
               color: colorScheme.onSurface,
               fontSize: 10,
               fontWeight: FontWeight.w600,
             ),
           ),
           const SizedBox(height: 2),
           SizedBox(
             height: 40,
             width: 40,
             child: SfRadialGauge(
               axes: [
                 RadialAxis(
                   minimum: 0,
                   maximum: max,
                   showLabels: false,
                   showTicks: false,
                   startAngle: 180,
                   endAngle: 0,
                   axisLineStyle: const AxisLineStyle(
                       thickness: 0.06, thicknessUnit: GaugeSizeUnit.factor),
                   pointers: [
                     RangePointer(
                         value: value,
                         width: 0.06,
                         sizeUnit: GaugeSizeUnit.factor,
                         color: colorScheme.primary),
                     MarkerPointer(
                         value: value,
                         markerType: MarkerType.circle,
                         color: colorScheme.onSurface,
                         markerWidth: 4,
                         markerHeight: 4),
                   ],
                 )
               ],
             ),
           ),
           Text(
             value.toStringAsFixed(0),
             style: TextStyle(
               color: colorScheme.onSurfaceVariant,
               fontSize: 8,
               fontWeight: FontWeight.w500,
             ),
           ),
         ],
       ),
     );
   }

  /* ----------------------------------------------------------
   *  PLACEHOLDERS MÍNIMOS (para que no falte nada)
   * ---------------------------------------------------------- */
  Widget _disconnectedPlaceholder() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Text('Robot desconectado',
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 18)));
  }

  Widget _modeNotActive() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Text('Modo no activo',
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 18)));
  }

  Widget _errorBody() => const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
            child: Text('Error: AppState no encontrado',
                style: TextStyle(color: Colors.red))),
      );

  /* ----------------------------------------------------------
   *  INTERFACES POR MODO (versión mínima para compilar)
   * ---------------------------------------------------------- */
  Widget _remoteControlPanel(AppState p, ArduinoData d) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _card(
          title: 'Control Remoto',
          child: Column(children: [
            Text('Joystick vendrá aquí',
                style: TextStyle(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                      onPressed: () => p.sendCommand(
                          {'remote_control': {'throttle': 0.5, 'turn': 0}}),
                      icon: const Icon(Icons.north),
                      label: const Text('Adelante')),
                  ElevatedButton.icon(
                      onPressed: () => p.sendCommand(
                          {'remote_control': {'throttle': -0.5, 'turn': 0}}),
                      icon: const Icon(Icons.south),
                      label: const Text('Atrás')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                      onPressed: () => p.sendCommand(
                          {'remote_control': {'throttle': 0.3, 'turn': -0.5}}),
                      icon: const Icon(Icons.west),
                      label: const Text('Izquierda')),
                  ElevatedButton.icon(
                      onPressed: () => p.sendCommand(
                          {'remote_control': {'throttle': 0.3, 'turn': 0.5}}),
                      icon: const Icon(Icons.east),
                      label: const Text('Derecha')),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () =>
                      p.sendCommand({'remote_control': {'emergencyStop': true}}),
                  icon: const Icon(Icons.stop),
                  label: const Text('Emergencia'),
                ),
              ),
            ]),
          ),
        ],
      );
  }

  Widget _lineFollowingPanel(AppState p, ArduinoData d) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Text('Panel Seguidor de Línea – próximamente',
          style: TextStyle(color: colorScheme.onSurfaceVariant)));
  }

  Widget _servoPanel(AppState p, ArduinoData d) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Text('Panel Servo-Distancia – próximamente',
          style: TextStyle(color: colorScheme.onSurfaceVariant)));
  }

  Widget _pointListPanel(AppState p, ArduinoData d) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Text('Panel Lista de Puntos – próximamente',
          style: TextStyle(color: colorScheme.onSurfaceVariant)));
  }

  /* ----------------------------------------------------------
   *  DIÁLOGO CONEXIÓN (tu código original)
   * ---------------------------------------------------------- */
  void _showConnectionDialog() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const ConnectionBottomSheet(),
      );
}
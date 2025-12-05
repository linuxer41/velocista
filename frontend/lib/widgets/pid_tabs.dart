import 'package:flutter/material.dart';
import '../app_state.dart';
import '../arduino_data.dart';

class PidTabs extends StatelessWidget {
  final AppState appState;

  const PidTabs({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          BaseSpeedTab(appState: appState),
          const SizedBox(height: 4),
          FeaturesControlBoard(appState: appState),
        ],
      ),
    );
  }
}

class BaseSpeedTab extends StatelessWidget {
  final AppState appState;

  const BaseSpeedTab({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Control toggles and buttons
          Column(
            children: [
              Row(
                children: [
                  // Cascade Control Toggle
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Control en Cascada',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Transform.scale(
                          scale: 0.8,
                          child: ValueListenableBuilder<ConfigData?>(
                            valueListenable: appState.configData,
                            builder: (context, config, child) {
                              final enabled = config?.cascade == 1;
                              return Switch(
                                value: enabled,
                                onChanged: (value) async {
                                  final cascadeCommand = CascadeCommand(value);
                                  await appState
                                      .sendCommand(cascadeCommand.toCommand());
                                  // Refresh config data
                                  await appState.sendCommand(
                                      ConfigRequestCommand().toCommand());
                                },
                                activeThumbColor:
                                    Theme.of(context).colorScheme.primary,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  // telemetry Control Toggle
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Telemetría',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Transform.scale(
                          scale: 0.8,
                          child: ValueListenableBuilder<ConfigData?>(
                            valueListenable: appState.configData,
                            builder: (context, config, child) {
                              final enabled = config?.telemetry == 1;
                              return Switch(
                                value: enabled,
                                onChanged: (value) async {
                                  // Update configData locally for immediate UI feedback
                                  final currentConfig =
                                      appState.configData.value;
                                  if (currentConfig != null) {
                                    final updatedConfig = ConfigData(
                                      lineKPid: currentConfig.lineKPid,
                                      leftKPid: currentConfig.leftKPid,
                                      rightKPid: currentConfig.rightKPid,
                                      base: currentConfig.base,
                                      wheels: currentConfig.wheels,
                                      mode: currentConfig.mode,
                                      cascade: currentConfig.cascade,
                                      telemetry: value ? 1 : 0,
                                      featConfig: currentConfig.featConfig,
                                    );
                                    appState.configData.value = updatedConfig;
                                  }

                                  final telemetryCommand =
                                      TelemetryChangeCommand(value);
                                  await appState.sendCommand(
                                      telemetryCommand.toCommand());
                                  // Small delay to allow Arduino to process the command
                                  await Future.delayed(const Duration(milliseconds: 100));
                                  // Refresh config data to confirm
                                  await appState.sendCommand(
                                      ConfigRequestCommand().toCommand());
                                },
                                activeThumbColor:
                                    Theme.of(context).colorScheme.secondary,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  // Sync with Telemetry Icon Button
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Sincronizar',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            onPressed: () async {
                              // Call get config to get config data including FEAT_CONFIG
                              final configCommand = ConfigRequestCommand();
                              await appState
                                  .sendCommand(configCommand.toCommand());
                            },
                            icon: Icon(
                              Icons.sync,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onPrimaryContainer,
                              size: 16,
                            ),
                            tooltip: 'Sincronizar con Telemetry',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Calibrate Button
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Calibrar',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .secondaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            onPressed: () async {
                              await appState.sendCommand(
                                  ConfigRequestCommand().toCommand());
                              final calibrateCommand = CalibrateQtrCommand();
                              appState
                                  .sendCommand(calibrateCommand.toCommand());
                            },
                            icon: Icon(
                              Icons.adjust,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSecondaryContainer,
                              size: 16,
                            ),
                            tooltip: 'Calibrar Sensores',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Save Button
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Grabar',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: IconButton(
                            onPressed: () async {
                              // Show confirmation dialog
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Confirmar Grabado'),
                                  content: const Text(
                                    'Los valores actuales se guardarán en EEPROM. Una vez que reinicies tu robot, esos valores se guardarán permanentemente.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(false),
                                      child: const Text('Cancelar'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(true),
                                      child: const Text('Grabar'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                await appState.sendCommand(
                                    ConfigRequestCommand().toCommand());
                                final saveCommand = EepromSaveCommand();
                                appState.sendCommand(saveCommand.toCommand());
                              }
                            },
                            icon: Icon(
                              Icons.save,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onTertiaryContainer,
                              size: 16,
                            ),
                            tooltip: 'Grabar Configuración',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Autotune Button
                   Expanded(
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Text(
                           'Autotune',
                           style: TextStyle(
                             fontSize: 10,
                             fontWeight: FontWeight.w500,
                             color:
                                 Theme.of(context).colorScheme.onSurfaceVariant,
                           ),
                         ),
                         Container(
                           width: 32,
                           height: 32,
                           decoration: BoxDecoration(
                             color: Theme.of(context).colorScheme.primaryContainer,
                             borderRadius: BorderRadius.circular(6),
                           ),
                           child: IconButton(
                             onPressed: () async {
                               final autotuneCommand = AutotuneCommand();
                               appState.sendCommand(autotuneCommand.toCommand());
                             },
                             icon: Icon(
                               Icons.auto_fix_high,
                               color: Theme.of(context)
                                   .colorScheme
                                   .onPrimaryContainer,
                               size: 16,
                             ),
                             tooltip: 'Ajustar PID automáticamente',
                             padding: EdgeInsets.zero,
                             constraints: const BoxConstraints(),
                           ),
                         ),
                       ],
                     ),
                   ),
                   // Reset Button
                   Expanded(
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Text(
                           'Resetear',
                           style: TextStyle(
                             fontSize: 10,
                             fontWeight: FontWeight.w500,
                             color:
                                 Theme.of(context).colorScheme.onSurfaceVariant,
                           ),
                         ),
                         Container(
                           width: 32,
                           height: 32,
                           decoration: BoxDecoration(
                             color: Theme.of(context).colorScheme.errorContainer,
                             borderRadius: BorderRadius.circular(6),
                           ),
                           child: IconButton(
                             onPressed: () async {
                               // Show confirmation dialog
                               final confirmed = await showDialog<bool>(
                                 context: context,
                                 builder: (context) => AlertDialog(
                                   title: const Text('Confirmar Reseteo'),
                                   content: const Text(
                                     '¿Está seguro de resetear los valores por defecto y limpiar la EEPROM? Se borrará toda tu configuración.',
                                   ),
                                   actions: [
                                     TextButton(
                                       onPressed: () =>
                                           Navigator.of(context).pop(false),
                                       child: const Text('Cancelar'),
                                     ),
                                     TextButton(
                                       onPressed: () =>
                                           Navigator.of(context).pop(true),
                                       child: const Text('Resetear'),
                                     ),
                                   ],
                                 ),
                               );

                               if (confirmed == true) {
                                 await appState.sendCommand(
                                     ConfigRequestCommand().toCommand());
                                 final resetCommand = FactoryResetCommand();
                                 appState.sendCommand(resetCommand.toCommand());
                               }
                             },
                             icon: Icon(
                               Icons.refresh,
                               color: Theme.of(context)
                                   .colorScheme
                                   .onErrorContainer,
                               size: 16,
                             ),
                             tooltip: 'Resetear Valores',
                             padding: EdgeInsets.zero,
                             constraints: const BoxConstraints(),
                           ),
                         ),
                       ],
                     ),
                   ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class FeaturesControlBoard extends StatelessWidget {
  final AppState appState;

  const FeaturesControlBoard({super.key, required this.appState});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Funciones de Seguimiento de Línea',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
              fontFamily: 'Space Grotesk',
            ),
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<ConfigData?>(
            valueListenable: appState.configData,
            builder: (context, configData, child) {
              // Always show labels, use default values if featConfig is null
              final currentFeatures = configData?.featConfig ?? [1, 1, 1, 1, 1, 1, 0, 0, 0];

              const featureNames = ['MED', 'MA', 'KAL', 'HYS', 'DZ', 'LP', 'APID', 'SP', 'DIR'];
              const featureDescriptions = [
                'Filtro Mediano',
                'Media Móvil',
                'Filtro Kalman',
                'Histeresis',
                'Zona Muerta',
                'Pasa Bajos',
                'PID Adaptativo',
                'Perfil Velocidad',
                'Dirección Giro'
              ];

              return Column(
                children: [
                  // First row: MED, MA, KAL
                  Row(
                    children: List.generate(3, (index) {
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          child: Column(
                            children: [
                              Text(
                                featureNames[index],
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                featureDescriptions[index],
                                style: TextStyle(
                                  fontSize: 6,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 2),
                              Switch(
                                value: currentFeatures[index] == 1,
                                onChanged: (value) async {
                                  final newValue = value ? 1 : 0;
                                  // Update configData locally for immediate UI feedback
                                  final currentConfig = appState.configData.value;
                                  if (currentConfig != null && currentConfig.featConfig != null) {
                                    final updatedFeatConfig = List<int>.from(currentConfig.featConfig!);
                                    updatedFeatConfig[index] = newValue;
                                    final updatedConfig = ConfigData(
                                      lineKPid: currentConfig.lineKPid,
                                      leftKPid: currentConfig.leftKPid,
                                      rightKPid: currentConfig.rightKPid,
                                      base: currentConfig.base,
                                      wheels: currentConfig.wheels,
                                      mode: currentConfig.mode,
                                      cascade: currentConfig.cascade,
                                      telemetry: currentConfig.telemetry,
                                      featConfig: updatedFeatConfig,
                                    );
                                    appState.configData.value = updatedConfig;
                                  }

                                  final featureCommand =
                                      FeatureCommand(index, newValue);
                                  await appState.sendCommand(
                                      featureCommand.toCommand());
                                  // Small delay to allow Arduino to process the command
                                  await Future.delayed(const Duration(milliseconds: 100));
                                  // Request fresh config data to sync UI
                                  await appState.sendCommand(
                                      ConfigRequestCommand().toCommand());
                                },
                                activeThumbColor:
                                    Theme.of(context).colorScheme.primary,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  // Second row: HYS, DZ, LP
                  Row(
                    children: List.generate(3, (index) {
                      final actualIndex = index + 3; // 3, 4, 5
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          child: Column(
                            children: [
                              Text(
                                featureNames[actualIndex],
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                featureDescriptions[actualIndex],
                                style: TextStyle(
                                  fontSize: 6,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 2),
                              Switch(
                                value: currentFeatures[actualIndex] == 1,
                                onChanged: (value) async {
                                  final newValue = value ? 1 : 0;
                                  // Update configData locally for immediate UI feedback
                                  final currentConfig = appState.configData.value;
                                  if (currentConfig != null && currentConfig.featConfig != null) {
                                    final updatedFeatConfig = List<int>.from(currentConfig.featConfig!);
                                    updatedFeatConfig[actualIndex] = newValue;
                                    final updatedConfig = ConfigData(
                                      lineKPid: currentConfig.lineKPid,
                                      leftKPid: currentConfig.leftKPid,
                                      rightKPid: currentConfig.rightKPid,
                                      base: currentConfig.base,
                                      wheels: currentConfig.wheels,
                                      mode: currentConfig.mode,
                                      cascade: currentConfig.cascade,
                                      telemetry: currentConfig.telemetry,
                                      featConfig: updatedFeatConfig,
                                    );
                                    appState.configData.value = updatedConfig;
                                  }

                                  final featureCommand =
                                      FeatureCommand(actualIndex, newValue);
                                  await appState.sendCommand(
                                      featureCommand.toCommand());
                                  // Small delay to allow Arduino to process the command
                                  await Future.delayed(const Duration(milliseconds: 100));
                                  // Request fresh config data to sync UI
                                  await appState.sendCommand(
                                      ConfigRequestCommand().toCommand());
                                },
                                activeThumbColor:
                                    Theme.of(context).colorScheme.primary,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  // Third row: APID, SP, DIR
                  Row(
                    children: List.generate(3, (index) {
                      final actualIndex = index + 6; // 6, 7, 8
                      return Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          child: Column(
                            children: [
                              Text(
                                featureNames[actualIndex],
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              Text(
                                featureDescriptions[actualIndex],
                                style: TextStyle(
                                  fontSize: 6,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 2),
                              Switch(
                                value: currentFeatures[actualIndex] == 1,
                                onChanged: (value) async {
                                  final newValue = value ? 1 : 0;
                                  // Update configData locally for immediate UI feedback
                                  final currentConfig = appState.configData.value;
                                  if (currentConfig != null && currentConfig.featConfig != null) {
                                    final updatedFeatConfig = List<int>.from(currentConfig.featConfig!);
                                    updatedFeatConfig[actualIndex] = newValue;
                                    final updatedConfig = ConfigData(
                                      lineKPid: currentConfig.lineKPid,
                                      leftKPid: currentConfig.leftKPid,
                                      rightKPid: currentConfig.rightKPid,
                                      base: currentConfig.base,
                                      wheels: currentConfig.wheels,
                                      mode: currentConfig.mode,
                                      cascade: currentConfig.cascade,
                                      telemetry: currentConfig.telemetry,
                                      featConfig: updatedFeatConfig,
                                    );
                                    appState.configData.value = updatedConfig;
                                  }

                                  final featureCommand =
                                      FeatureCommand(actualIndex, newValue);
                                  await appState.sendCommand(
                                      featureCommand.toCommand());
                                  // Small delay to allow Arduino to process the command
                                  await Future.delayed(const Duration(milliseconds: 100));
                                  // Request fresh config data to sync UI
                                  await appState.sendCommand(
                                      ConfigRequestCommand().toCommand());
                                },
                                activeThumbColor:
                                    Theme.of(context).colorScheme.primary,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
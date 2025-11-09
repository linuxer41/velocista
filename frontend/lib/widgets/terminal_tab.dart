import 'dart:convert';
import 'package:flutter/material.dart';
import '../app_state.dart';

class TerminalTab extends StatefulWidget {
  final AppState provider;

  const TerminalTab({
    super.key,
    required this.provider,
  });

  @override
  State<TerminalTab> createState() => _TerminalTabState();
}

class _TerminalTabState extends State<TerminalTab> {
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _commandController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Bluetooth Terminal',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Toggle for raw data
                    ValueListenableBuilder<bool>(
                      valueListenable: widget.provider.showRawData,
                      builder: (context, showRaw, child) {
                        return Switch(
                          value: showRaw,
                          onChanged: (value) {
                            widget.provider.showRawData.value = value;
                          },
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Raw Data',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: widget.provider.clearTerminal,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Command input section
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
              border: Border.all(color: colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enviar Comando',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _commandController,
                        decoration: InputDecoration(
                          hintText: 'Ej: {"mode":1} o {"servoDistance":25}',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ),
                        onSubmitted: (_) => _sendCommand(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: widget.provider.isConnected.value
                          ? _sendCommand
                          : null,
                      icon: const Icon(Icons.send),
                      label: const Text('Enviar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.provider.isConnected.value
                            ? colorScheme.primary
                            : colorScheme.onSurface.withOpacity(0.3),
                        foregroundColor: widget.provider.isConnected.value
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildQuickCommandButton(
                        'Mode 0 (Line)', '{"mode":0}', colorScheme),
                    _buildQuickCommandButton(
                        'Mode 1 (Auto)', '{"mode":1}', colorScheme),
                    _buildQuickCommandButton(
                        'Mode 2 (Manual)', '{"mode":2}', colorScheme),
                    _buildQuickCommandButton(
                        'Mode 3 (Servo)', '{"mode":3}', colorScheme),
                    _buildQuickCommandButton(
                        'Mode 4 (Route)', '{"mode":4}', colorScheme),
                    _buildQuickCommandButton(
                        'Telemetry', '{"telemetry":1}', colorScheme),
                    _buildQuickCommandButton(
                        'Save EEPROM', '{"eeprom":1}', colorScheme),
                    _buildQuickCommandButton(
                        'Calibrate QTR', '{"calibrate_qtr":1}', colorScheme),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ValueListenableBuilder<List<String>>(
                valueListenable:
                    ValueNotifier(widget.provider.terminalMessages),
                builder: (context, messages, child) {
                  // Auto-scroll to bottom when new messages arrive
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_scrollController.hasClients) {
                      _scrollController.animateTo(
                        _scrollController.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                      );
                    }
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: messages.length,
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.all(8.0),
                    itemBuilder: (context, index) {
                      final message = messages[index];
                      // Limit the number of messages displayed to prevent UI overload
                      final maxDisplayMessages = 50;
                      if (messages.length > maxDisplayMessages &&
                          index < messages.length - maxDisplayMessages) {
                        return const SizedBox.shrink(); // Skip older messages
                      }
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8.0, vertical: 2.0),
                        child: SelectableText(
                          message,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCommandButton(
      String label, String command, ColorScheme colorScheme) {
    return OutlinedButton(
      onPressed: widget.provider.isConnected.value
          ? () => _sendQuickCommand(command)
          : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: const Size(0, 32),
        side: BorderSide(
          color: widget.provider.isConnected.value
              ? colorScheme.primary
              : colorScheme.onSurface.withOpacity(0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: widget.provider.isConnected.value
              ? colorScheme.primary
              : colorScheme.onSurface.withOpacity(0.5),
        ),
      ),
    );
  }

  void _sendCommand() {
    final command = _commandController.text.trim();
    if (command.isEmpty) return;

    _sendQuickCommand(command);
    _commandController.clear();
  }

  Future<void> _sendQuickCommand(String command) async {
    if (!widget.provider.isConnected.value) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay conexión Bluetooth activa'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Parse JSON command
      final Map<String, dynamic> parsedCommand;
      if (command.startsWith('{')) {
        // It's a JSON string, parse it
        parsedCommand = Map<String, dynamic>.from(
            command.contains('"') ? jsonDecode(command) : {'raw': command});
      } else {
        // It's a raw string, wrap it
        parsedCommand = {'raw': command};
      }

      final success = await widget.provider.sendCommand(parsedCommand);
      if (success) {
        widget.provider.addTerminalMessage('📤 Comando enviado: $command');
      } else {
        widget.provider
            .addTerminalMessage('❌ Error al enviar comando: $command');
      }
    } catch (e) {
      widget.provider.addTerminalMessage('❌ Error de formato JSON: $command');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error de formato: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
